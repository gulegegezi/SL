extends Node
## Visible comic panels own small, real 3D worlds. Offscreen worlds are released.
const EnvironmentKit := preload("res://scripts/pixel_environment_3d.gd")
const ActorRig := preload("res://scripts/pixel_billboard_actor.gd")
const InkTheme := preload("res://scripts/comic_theme.gd")
const Grade := preload("res://shaders/pixel_grade.gdshader")
const PropKit := preload("res://scripts/pixel_prop_3d.gd")
const CutIn := preload("res://scripts/pixel_cutin.gd")
const Dialogue := preload("res://scripts/comic_dialogue.gd")
static var live_viewports := 0
const MAX_LIVE := 4
var panel: Control
var viewport: SubViewport
var world: Node3D
var camera: Camera3D
var lead: Node3D
var npc: Node3D
var object: Node3D
var prop_kind := ""
var prop_rest := Vector3(-0.10,0.8,0.6)
var clock := 0.0
var offscreen_time := 0.0
var interaction_time := -1.0
var interacted := false
var cutin_time := -1.0
var cutin_armed := true
var cutin_data: Dictionary = {}
var cg_time := -1.0
var cg_started := false
var cg_finished := false
var cg: Dictionary = {}
var _active_previous := false
var _last_size := Vector2.ZERO
var _screen_rect := Rect2()
var _target_rect := Rect2()
var _render_offset := Vector2.ZERO
# ---- 平滑走位：速度、朝向、步态相位 ----
var _vel := {"lead": Vector3.ZERO, "npc": Vector3.ZERO}
var _yaw := {"lead": 0.2, "npc": -0.45}
var _phase := {"lead": 0.0, "npc": 0.0}
const LEAD_POS := Vector3(-1.1,0,0.8)
const LEAD_WALK_POS := Vector3(-0.72,0,1.35)
const LEAD_NPC_INTERACT_POS := Vector3(0.05,0,0.8)
const LEAD_PROP_INTERACT_POS := Vector3(-0.65,0,1.05)
const NPC_POS := Vector3(1.15,0,0)
const PROP_POS := Vector3(-0.10,0.8,0.6)
const FRIDGE_POS := Vector3(-3.55,0,0.15)
const FRIDGE_INTERACT_POS := Vector3(-2.70,0,1.00)
const BENCH_POS := Vector3(0.40,0,-1.75)
const BENCH_INTERACT_POS := Vector3(-0.20,0,-0.55)
const ACTOR_CLEARANCE := 0.82
const PROP_CLEARANCE := 0.70
const CAMERA_POS := Vector3(6,5,8)
const CAMERA_LOOK := Vector3(0,0.9,0)

func setup(owner_panel: Control) -> void:
	panel = owner_panel
	cg = panel.spec.get("pixel_cg",{}).duplicate(true)
	interacted = bool(panel.spec.get("interaction_progress",{}).get("completed",false))
	if interacted: interaction_time = 4.0
	cg_finished = bool(panel.spec.get("cg_progress",{}).get("completed",false))
	set_process(true)

func _exit_tree() -> void:
	if is_instance_valid(viewport): live_viewports = maxi(0,live_viewports-1)

func on_screen() -> bool:
	if not is_instance_valid(panel) or not panel.is_visible_in_tree() or not panel.revealed: return false
	var bounds: Rect2 = panel.get_viewport_rect()
	var ancestor := panel.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			bounds = bounds.intersection(ancestor.get_global_rect())
		ancestor = ancestor.get_parent()
	return bounds.intersects(panel.get_global_rect())

func _process(delta: float) -> void:
	if not on_screen():
		offscreen_time += delta
		if is_instance_valid(viewport):
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			if offscreen_time > 0.35: release_world()
		return
	offscreen_time = 0
	if not is_instance_valid(viewport):
		if live_viewports >= MAX_LIVE: return
		create_world()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	clock += delta
	if not panel.interactions_enabled and interaction_time >= 0 and not interacted: interaction_time = -1
	if interaction_time >= 0 and not interacted:
		interaction_time += delta
		# 动作接触的一刻：弹一张漫画分格，代替昂贵的 3D 动作表演
		if cutin_armed and interaction_time >= 1.25:
			cutin_armed = false
			_trigger_cutin()
		if interaction_time >= 3.6:
			interacted = true
			panel.interaction_done = true
			panel.spec["interaction_progress"] = {"completed":true,"id":panel.spec.get("pixel_interaction",{}).get("id","")}
			_reaction_bump()
			panel.interacted.emit(panel.spec.interaction_progress.duplicate(true))
	if not cg.is_empty() and not cg_started and not cg_finished and not panel.reduced_motion:
		cg_started = true
		cg_time = 0
	if cg_time >= 0:
		cg_time += delta
		if cg_time > float(cg.get("duration",8))+0.7: skip_cg()
	if cutin_time >= 0.0:
		cutin_time += delta
		if cutin_time >= CutIn.DURATION:
			cutin_time = -1.0
	update_size()
	update_camera()
	update_actors(delta)
	update_target()
	panel.queue_redraw()

func release_world() -> void:
	if not is_instance_valid(viewport): return
	viewport.queue_free()
	viewport = null
	world = null
	_last_size = Vector2.ZERO
	live_viewports = maxi(0,live_viewports-1)

func create_world() -> void:
	viewport = SubViewport.new()
	viewport.name = "Pixel3DViewport"
	viewport.own_world_3d = true
	viewport.transparent_bg = false
	viewport.size = Vector2i(256,180)
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.positional_shadow_atlas_size = 1024
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	live_viewports += 1
	world = EnvironmentKit.build(str(panel.spec.get("scene","home")),str(panel.spec.get("pixel_variant","day")))
	viewport.add_child(world)
	var palette: Dictionary = EnvironmentKit.palette(str(panel.spec.get("pixel_variant","day")))
	lead = ActorRig.new()
	world.add_child(lead)
	lead.setup(str(panel.spec.get("ink","lead_adult")),int(panel.spec.get("age",25)),palette)
	lead.position = LEAD_POS
	lead.rotation.y = 0.2
	if int(panel.spec.get("age",25)) <= 1:
		var cradle := MeshInstance3D.new()
		var cradle_mesh := BoxMesh.new()
		cradle_mesh.size = Vector3(1.2,0.14,1.55)
		cradle.mesh = cradle_mesh
		cradle.position = LEAD_POS+Vector3(0,0.57,0)
		var cradle_material := StandardMaterial3D.new()
		cradle_material.albedo_color = palette.get("paper",Color("dddbc3"))
		cradle.material_override = cradle_material
		world.add_child(cradle)
		for x in [-0.48,0.48]:
			for z in [-0.60,0.60]:
				var leg := MeshInstance3D.new()
				var leg_mesh := BoxMesh.new()
				leg_mesh.size = Vector3(0.07,0.5,0.07)
				leg.mesh = leg_mesh
				leg.material_override = cradle_material
				leg.position = LEAD_POS+Vector3(x,0.25,z)
				world.add_child(leg)
	if not bool(panel.spec.get("world_solo",false)) and str(panel.spec.get("support","none")) != "none":
		npc = ActorRig.new()
		world.add_child(npc)
		npc.setup(str(panel.spec.support),38,palette)
		npc.position = NPC_POS
		npc.rotation.y = -0.45
	else: npc = null
	prop_kind = str(panel.spec.get("pixel_interaction",{}).get("prop",panel.spec.get("prop","")))
	object = build_prop(prop_kind,palette)
	world.add_child(object)
	prop_rest = PROP_POS
	if prop_kind == "fridge": prop_rest = FRIDGE_POS
	elif prop_kind == "bench": prop_rest = BENCH_POS
	elif prop_kind == "plant": prop_rest.y = 0.70
	if int(panel.spec.get("age",25)) <= 1: prop_rest = LEAD_POS+Vector3(0.2,0.84,0.12)
	object.position = prop_rest
	object.visible = not prop_kind.is_empty()
	if object.visible and prop_kind not in ["fridge","bench"] and int(panel.spec.get("age",25)) > 1:
		var plinth := MeshInstance3D.new()
		var plinth_mesh := BoxMesh.new()
		plinth_mesh.size = Vector3(0.55,0.06,0.48)
		plinth.mesh = plinth_mesh
		plinth.position = Vector3(-0.10,0.67,0.60)
		var plinth_material := StandardMaterial3D.new()
		plinth_material.albedo_color = palette.get("wood",Color("8f6a50"))
		plinth.material_override = plinth_material
		world.add_child(plinth)
		for x in [-0.22,0.22]:
			for z in [-0.18,0.18]:
				var leg := MeshInstance3D.new()
				var mesh := BoxMesh.new()
				mesh.size = Vector3(0.045,0.64,0.045)
				leg.mesh = mesh
				leg.position = Vector3(-0.10+x,0.32,0.60+z)
				leg.material_override = plinth_material
				world.add_child(leg)
	camera = Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.7
	camera.position = CAMERA_POS
	camera.look_at(CAMERA_LOOK)
	camera.current = true
	var grading_layer := CanvasLayer.new()
	viewport.add_child(grading_layer)
	var grading := ColorRect.new()
	grading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grade_material := ShaderMaterial.new()
	grade_material.shader = Grade
	var preset: Dictionary = _grade_preset(str(panel.spec.get("scene","home")), str(panel.spec.get("pixel_variant","day")))
	for uniform_name in preset:
		grade_material.set_shader_parameter(uniform_name, preset[uniform_name])
	grading.material = grade_material
	grading_layer.add_child(grading)
	update_size()
	update_actors()

static func build_prop(kind: String, palette: Dictionary) -> Node3D:
	return PropKit.build(kind,palette)

func art_rect() -> Rect2:
	var text_size: Vector2 = panel.size
	var top := 12.0
	var bubble: String = panel.spec.get("bubble","")
	var dialogue_text := str(Dialogue.copy(bubble).full)
	if not bubble.is_empty(): top += InkTheme.font_body().get_multiline_string_size(dialogue_text,HORIZONTAL_ALIGNMENT_LEFT,maxf(30,minf(text_size.x-44,192)),14).y+22
	var cap: String = panel.spec.get("caption","")
	if interacted and panel.spec.has("pixel_interaction"): cap += "\n发现："+str(panel.spec.pixel_interaction.get("reveal",""))
	var bottom := 12.0 if cap.is_empty() else InkTheme.font_body().get_multiline_string_size(cap,HORIZONTAL_ALIGNMENT_LEFT,maxf(30,text_size.x-46),15).y+40
	if panel.spec.has("pixel_interaction"): bottom += 34
	return Rect2(10,top,maxf(32,text_size.x-20),maxf(60,text_size.y-top-bottom))

func update_size() -> void:
	_screen_rect = art_rect()
	var scale := maxi(2,ceili(_screen_rect.size.x/320.0))
	var pixels := Vector2i(maxi(32,floori(_screen_rect.size.x/scale)),maxi(24,floori(_screen_rect.size.y/scale)))
	var fitted := Vector2(pixels)*scale
	_screen_rect.position += (_screen_rect.size-fitted)*0.5
	_screen_rect.size = fitted
	if _last_size != _screen_rect.size:
		_last_size = _screen_rect.size
		viewport.size = pixels

func update_target() -> void:
	var target: Vector3 = NPC_POS+Vector3(0,0.9,0) if panel.spec.get("pixel_interaction",{}).get("target","prop") == "npc" and is_instance_valid(npc) else object.global_position
	var projected := camera.unproject_position(target)
	var at := _screen_rect.position+_render_offset+projected/Vector2(viewport.size)*_screen_rect.size
	_target_rect = Rect2(at-Vector2(28,32),Vector2(56,64))

func update_camera() -> void:
	var position := CAMERA_POS
	var focus := CAMERA_LOOK
	var zoom := 5.7
	if cg_time >= 0 and not panel.reduced_motion:
		var shots: Array = cg.get("shots",[])
		if not shots.is_empty():
			var previous: Dictionary = shots[0]
			var next: Dictionary = shots[-1]
			for shot in shots:
				if float(shot.at) <= cg_time: previous = shot
				elif float(shot.at) > cg_time:
					next = shot
					break
			var blend := smoothstep(float(previous.at),maxf(float(previous.at)+0.01,float(next.at)),cg_time)
			position = v3(previous.position).lerp(v3(next.position),blend)
			focus = v3(previous.look_at).lerp(v3(next.look_at),blend)
			zoom = lerpf(float(previous.size),float(next.size),blend)
			var return_mix := smoothstep(float(cg.duration),float(cg.duration)+0.65,cg_time)
			position = position.lerp(CAMERA_POS,return_mix)
			focus = focus.lerp(CAMERA_LOOK,return_mix)
			zoom = lerpf(zoom,5.7,return_mix)
	camera.position = position
	camera.look_at(focus)
	camera.size = zoom
	# View-aligned pixel grid plus screen-space remainder: stable panning without
	# rounding the actor animation. Rotation/zoom still reproject the 3D scene.
	var unit := camera.project_position(Vector2(1,0),1).distance_to(camera.project_position(Vector2.ZERO,1))
	var local := camera.basis.inverse()*camera.position
	var snapped := Vector3(snappedf(local.x,unit),snappedf(local.y,unit),local.z)
	var remainder := local-snapped
	camera.position = camera.basis*snapped
	_render_offset = Vector2(-remainder.x,remainder.y)/unit*(_screen_rect.size.x/viewport.size.x)

static func v3(value: Array) -> Vector3:
	return Vector3(float(value[0]),float(value[1]),float(value[2]))

func update_actors(delta: float = 0.016) -> void:
	var action: String = panel.current_direction.get("action",panel.spec.get("action","idle"))
	var time: float = panel._moment_age
	var speaker: String = panel.spec.get("actor","lead")
	var lead_action := action if speaker == "lead" else "idle"
	var npc_action := action if speaker != "lead" else "idle"
	var base := LEAD_POS
	if lead_action == "walk":
		base = LEAD_POS.lerp(LEAD_WALK_POS,smoothstep(0,1.6,time))
		if time >= 1.6: lead_action = "idle"
	if interaction_time >= 0:
		var interaction: Dictionary = panel.spec.get("pixel_interaction",{})
		var progress := smoothstep(0,1.25,interaction_time)
		var interact_pos := LEAD_PROP_INTERACT_POS
		if interaction.get("target","") == "npc": interact_pos = LEAD_NPC_INTERACT_POS
		elif prop_kind == "fridge": interact_pos = FRIDGE_INTERACT_POS
		elif prop_kind == "bench": interact_pos = BENCH_INTERACT_POS
		base = LEAD_POS.lerp(interact_pos,progress)
		lead_action = "walk" if interaction_time < 1.25 else str(interaction.get("action","talk"))
		time = interaction_time if interaction_time < 1.25 else maxf(0,interaction_time-1.25)
		npc_action = "receive" if lead_action == "offer" else ("offer" if lead_action == "receive" else "talk")
	elif cg_time >= 0 and not bool(cg.get("preserve_result_action",false)):
		for shot in cg.get("shots",[]):
			if float(shot.at) <= cg_time: lead_action = str(shot.get("action",lead_action)); time = cg_time-float(shot.at)
	if int(panel.spec.get("age",25)) <= 1:
		base = LEAD_POS+Vector3(0,0.65,0)
	else:
		base = _safe_lead_target(base)
	# 平滑走位：不是直接设位置，而是给一个目标点，让速度去追
	var moved := _arrive(lead, base, "lead", delta)
	if moved > 0.0004:
		_phase["lead"] += moved * 1.6
	var speed := moved / maxf(delta, 0.0001)
	if lead_action == "walk" and speed < 0.05:
		# 原地走（CG 里的赶路镜头）：相位也要继续走，画面不能定格
		_phase["lead"] += delta * 2.2
	var staging_yaw: float = lerp_angle(0.2, 1.9, smoothstep(0, 1.25, interaction_time)) if interaction_time >= 0 else 0.2
	var to_target: Vector3 = base - lead.position
	var target_yaw := staging_yaw
	if to_target.length() > 0.08:
		target_yaw = atan2(to_target.x, to_target.z)
	_yaw["lead"] = lerp_angle(float(_yaw["lead"]), target_yaw, 1.0 - exp(-delta * 9.0))
	lead.rotation.y = float(_yaw["lead"]) if not lead.is_newborn else 0.2
	var speed_ratio: float = clampf(speed / 1.1, 0.45, 1.6)
	var talking: bool = panel.spec.get("text_channel","") == "dialogue" and panel.visible_characters < panel._full_text.length()
	if panel.spec.get("conversation_paused",false) or panel._full_text.contains("一言不发"): talking = false
	if panel.spec.get("conversation_mode",false) and panel.spec.get("text_channel","") == "dialogue":
		if speaker == "lead": npc_action = "listen"
		else: lead_action = "listen"
		time = clock
	lead.set_expression(str(panel.current_direction.get("expr","normal")) if speaker == "lead" else "normal")
	var lead_time: float = clock if lead_action == "idle" else (float(_phase["lead"]) if lead_action == "walk" else time)
	lead.pose(lead_action, lead_time, talking and speaker == "lead", panel.reduced_motion, speed_ratio)
	if is_instance_valid(npc):
		var npc_yaw: float = lerp_angle(-0.45, -1.0, smoothstep(0, 1.25, interaction_time)) if interaction_time >= 0 else -0.45
		_yaw["npc"] = lerp_angle(float(_yaw["npc"]), npc_yaw, 1.0 - exp(-delta * 8.0))
		npc.rotation.y = float(_yaw["npc"])
		npc.set_expression(str(panel.current_direction.get("expr","normal")) if speaker != "lead" else "normal")
		npc.pose(npc_action,clock if npc_action == "idle" else maxf(0,time-0.25),talking and speaker != "lead",panel.reduced_motion)
	lead.face_camera(camera,false)
	if is_instance_valid(npc): npc.face_camera(camera,true)
	# Evaluate grips after posing; receiving moves toward the receiver, not away.
	object.position = prop_rest
	if object.visible and PropKit.handheld(prop_kind):
		var grip: Vector3 = lead.hand_anchor.global_position
		if interaction_time >= 1.25 and lead_action in ["receive","read","phone","draw","offer"]:
			var transfer := smoothstep(1.25,2.4,interaction_time)
			object.global_position = prop_rest.lerp(grip,transfer)
			if lead_action == "offer" and panel.spec.pixel_interaction.get("target","") == "npc" and is_instance_valid(npc):
				object.global_position = grip.lerp(npc.hand_anchor.global_position,smoothstep(1.65,2.9,interaction_time))
		elif interaction_time < 0:
			var actor: Node3D = lead if speaker == "lead" or not is_instance_valid(npc) else npc
			if action in ["read","phone","draw","offer","receive"]: object.global_position = actor.hand_anchor.global_position

## 走位终点保持在人物和家具外，避免纸片身体插进桌台或另一名角色。
func _safe_lead_target(target: Vector3) -> Vector3:
	var safe := target
	for _iteration in range(2):
		if is_instance_valid(object) and object.visible:
			var clearance := PROP_CLEARANCE
			if prop_kind == "fridge": clearance = 1.0
			elif prop_kind == "bench": clearance = 1.20
			safe = _push_out_xz(safe, Vector3(prop_rest.x, target.y, prop_rest.z), clearance)
		if is_instance_valid(npc):
			safe = _push_out_xz(safe, Vector3(npc.position.x, target.y, npc.position.z), ACTOR_CLEARANCE)
	return safe

static func _push_out_xz(point: Vector3, obstacle: Vector3, clearance: float) -> Vector3:
	var offset := Vector2(point.x-obstacle.x, point.z-obstacle.z)
	if offset.length() >= clearance: return point
	var direction := offset.normalized() if offset.length() > 0.001 else Vector2(0,1)
	var pushed := Vector2(obstacle.x,obstacle.z)+direction*clearance
	return Vector3(pushed.x,point.y,pushed.y)

## 走近-落位：按距离给期望速度，速度再缓动过去，起步/刹车都不会瞬移
func _arrive(node: Node3D, target: Vector3, key: String, delta: float) -> float:
	var before := node.position
	if before.distance_to(target) < 0.003:
		node.position = target
		_vel[key] = Vector3.ZERO
		return 0.0
	# 大卡顿帧按小步进积分，既不错过碰撞区，也不会一步冲过终点。
	var remaining := maxf(0.0,delta)
	while remaining > 0.0:
		var step := minf(remaining,1.0/60.0)
		remaining -= step
		var offset := target-node.position
		var dist := offset.length()
		if dist < 0.003:
			node.position = target
			_vel[key] = Vector3.ZERO
			break
		var desired: Vector3 = offset/dist*minf(2.6,dist*7.0)
		_vel[key] = (_vel[key] as Vector3).lerp(desired,1.0-exp(-step*10.0))
		var motion: Vector3 = (_vel[key] as Vector3)*step
		if motion.length() >= dist:
			node.position = target
			_vel[key] = Vector3.ZERO
			break
		node.position += motion
	return node.position.distance_to(before)


## 场景互动：物件被照料/打开/触碰时给一点物理反馈
func _reaction_bump() -> void:
	if not is_instance_valid(object):
		return
	if PropKit.handheld(prop_kind):
		return
	var tw := create_tween()
	tw.tween_property(object, "rotation:z", 0.10, 0.20)
	tw.parallel().tween_property(object, "scale", Vector3(1.05, 0.97, 1.05), 0.18)
	tw.tween_property(object, "rotation:z", 0.0, 0.55)
	tw.parallel().tween_property(object, "scale", Vector3.ONE, 0.55)


func perform_interaction() -> bool:
	if not panel.interactions_enabled or not panel.spec.has("pixel_interaction") or interacted or (interaction_time >= 0 and interaction_time < 3.6): return false
	interaction_time = 0
	cutin_armed = true
	skip_cg()
	return true

## 动作 → 漫画弹窗：动作帧 + 竖排拟声词 + 一行标题，全部复用现有图
func _trigger_cutin() -> void:
	var it: Dictionary = panel.spec.get("pixel_interaction", {})
	var action := str(it.get("action", ""))
	if action.is_empty():
		action = {"phone": "phone", "book": "read", "pencil": "draw", "drum": "drum",
			"letter": "receive", "meal": "raise"}.get(str(it.get("prop", "")), "reach")
	var key := str(panel.spec.get("ink", "lead_adult"))
	if str(panel.spec.get("actor", "lead")) != "lead":
		key = str(panel.spec.get("support", key))
	var expr := str(panel.current_direction.get("expr", "normal"))
	var override: Dictionary = panel.spec.get("pixel_cutin", {})
	cutin_data = {
		"key": str(override.get("key", key)),
		"action": str(override.get("action", action)),
		"expression": str(override.get("expression", expr)),
		"title": str(override.get("title", it.get("label", "动作"))),
		"sfx": str(override.get("sfx", CutIn.sfx_for(action))),
	}
	cutin_time = 0.0


func replay_cg() -> void:
	if cg.is_empty(): return
	cg_started = true
	cg_finished = false
	cg_time = 0

func skip_cg() -> void:
	if cg.is_empty(): return
	var was_finished := cg_finished
	cg_time = -1
	cg_finished = true
	panel.spec["cg_progress"] = {"completed":true}
	if not was_finished: panel.cinematic_finished.emit()

func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _target_rect.grow(8).has_point(event.position) or Rect2(12,panel.size.y-36,panel.size.x-24,28).has_point(event.position): return perform_interaction()
	return false

func draw_on() -> void:
	if not is_instance_valid(viewport): return
	panel.draw_texture_rect(viewport.get_texture(),Rect2(_screen_rect.position+_render_offset,_screen_rect.size),false)
	if panel.spec.get("conversation_mode",false) and panel.spec.get("text_channel","") == "dialogue":
		var actor: Node3D = lead if panel.spec.get("actor","lead") == "lead" or not is_instance_valid(npc) else npc
		var head: Vector3 = actor.global_position+camera.global_basis.y*(actor.height+0.13)
		var at := _screen_rect.position+_render_offset+camera.unproject_position(head)/Vector2(viewport.size)*_screen_rect.size
		panel.draw_circle(at,4,Color("efbd76"))
		panel.draw_string(InkTheme.font_body(),at+Vector2(8,4),str(panel.spec.get("speaker_label","")),HORIZONTAL_ALIGNMENT_LEFT,90,12,Color("ffe2a0"))
	if not panel.spec.get("conversation_mode",false): CutIn.draw(panel, _screen_rect, cutin_time, cutin_data)
	if panel.spec.has("pixel_interaction"):
		var words: String = panel.spec.pixel_interaction.get("label","观察")
		if interacted: words = "✓ 已观察 · "+words
		elif interaction_time >= 0: words = "正在靠近……"
		else: words = "◇ "+words+" · 点击人物或物件"
		var font := InkTheme.font_body()
		var y := panel.size.y-28
		panel.draw_rect(Rect2(10,y-15,panel.size.x-20,30),Color("152b32"))
		panel.draw_string(font,Vector2(17,y+4),words,HORIZONTAL_ALIGNMENT_LEFT,panel.size.x-35,11,Color("efc478"))
		if not interacted and interaction_time < 0 and panel.interactions_enabled:
			panel.draw_arc(_target_rect.get_center(),17,0,TAU,20,Color("efc478"),1.5)
	if cg_time >= 0:
		panel.draw_string(InkTheme.font_body(),_screen_rect.position+Vector2(8,16),"特别镜头 · "+str(cg.get("title","")),HORIZONTAL_ALIGNMENT_LEFT,_screen_rect.size.x-16,12,Color("f3dda9"))


## 每个场景一套后处理参数：办公室的冷、家里的暖、医院的白、公园的开阔。
## 参考《八方旅人》的移轴景深、《风来之国》的暖灯冷影、《旅行青蛙》的低对比柔光。
static func _grade_preset(scene: String, variant: String) -> Dictionary:
	var night: bool = variant == "night"
	var preset := {
		"strength": 0.72,
		"dof_strength": 0.58,
		"focus_center": 0.56,
		"focus_width": 0.22,
		"bloom_strength": 0.18,
		"bloom_threshold": 0.78,
		"vignette": 0.24,
		"warm_cast": 0.30,
		"haze": 0.10,
		"haze_color": Vector3(0.145, 0.247, 0.286),
	}
	match scene:
		"office":
			preset["warm_cast"] = -0.12          # 荧光灯下偏冷
			preset["bloom_strength"] = 0.26
			preset["focus_width"] = 0.20
		"hospital":
			preset["warm_cast"] = -0.28          # 病房的临床白
			preset["vignette"] = 0.34
			preset["bloom_strength"] = 0.22
			preset["haze"] = 0.14
		"park":
			preset["dof_strength"] = 0.44        # 室外景深远一点，别把人糊掉
			preset["focus_width"] = 0.30
			preset["vignette"] = 0.22
			preset["warm_cast"] = 0.34
			preset["bloom_strength"] = 0.24
			preset["haze"] = 0.16
			preset["haze_color"] = Vector3(0.176, 0.286, 0.294)
		"classroom":
			preset["warm_cast"] = 0.20
			preset["bloom_strength"] = 0.26
		_:
			preset["warm_cast"] = 0.38           # 家里最暖
	if night:
		preset["bloom_strength"] = float(preset["bloom_strength"]) + 0.10
		preset["warm_cast"] = float(preset["warm_cast"]) + 0.10
		preset["vignette"] = float(preset["vignette"]) + 0.06
		preset["haze"] = float(preset["haze"]) + 0.04
	return preset
