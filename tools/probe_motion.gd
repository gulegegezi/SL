extends SceneTree
## 动作引擎实测：A) 姿态采样率 B) 走位连续性 C) 动作切换是否有过渡。
## 用法：godot --headless --path . --script res://tools/probe_motion.gd

const PanelScript := preload("res://scripts/comic_panel.gd")
const Run := preload("res://scripts/life_comic_run.gd")
const Pages := preload("res://scripts/life_comic_pages.gd")

func _initialize() -> void:
	call_deferred("run")

func _tex_id(node) -> int:
	return node.sprite.texture.get_instance_id() if node.sprite.texture != null else 0

func run() -> void:
	root.size = Vector2i(900, 700)
	var life = Run.new(); life.start(39)
	life.s.pending = {}; life.s.age = 30; life.begin("LC11")
	var spec: Dictionary = Pages.make(life).panels[-1].duplicate(true)
	spec["action"] = "walk"
	spec["support"] = "npc_friend"
	var panel = PanelScript.new()
	panel.size = Vector2(880, 670)
	panel.setup(spec, null)
	root.add_child(panel)
	panel.revealed = true
	for i in range(4): await process_frame
	var stage = panel.pixel_stage
	stage.set_process(false)
	panel.set_process(false)

	print("--- A. 姿态采样（2.4 秒动作，60fps 调用）---")
	for action in ["walk", "talk", "wave", "sit", "phone", "draw"]:
		var last := 0
		var swaps := 0
		var frames := {}
		var steps := int(2.4 * 60.0)
		for i in range(steps):
			var t := float(i) / 60.0
			stage.lead.pose(action, t, action == "talk", false)
			var id := _tex_id(stage.lead)
			frames[id] = true
			if last != 0 and id != last: swaps += 1
			last = id
		print("  %-6s 换图 %2d 次 (%.2f 次/秒)，用到 %d 张不同的图" % [action, swaps, swaps / 2.4, frames.size()])

	print("--- B. 走位（4 秒，60fps）---")
	panel.current_direction["action"] = "walk"
	panel._moment_age = 0.0
	var dt := 1.0 / 60.0
	var last_pos: Vector3 = stage.lead.position
	var last_vel := Vector3.ZERO
	var max_jump := 0.0
	var max_accel := 0.0
	var sum_accel := 0.0
	var n := 0
	var swaps := 0
	var last_tex := _tex_id(stage.lead)
	for i in range(int(4.0 * 60.0)):
		panel._moment_age += dt
		stage._process(dt)
		var pos: Vector3 = stage.lead.position
		var vel: Vector3 = (pos - last_pos) / dt
		var accel: float = (vel - last_vel).length() / dt
		if i > 3:
			max_jump = maxf(max_jump, (pos - last_pos).length())
			max_accel = maxf(max_accel, accel)
			sum_accel += accel
			n += 1
		var id := _tex_id(stage.lead)
		if id != last_tex:
			swaps += 1
			last_tex = id
		last_pos = pos
		last_vel = vel
	print("  位移: 单帧最大 %.4f m" % max_jump)
	print("  加速度: 峰值 %.1f m/s²，平均 %.2f m/s²" % [max_accel, sum_accel / maxf(1.0, float(n))])
	print("  走位期间换图 %d 次 (%.1f 次/秒)" % [swaps, swaps / 4.0])

	print("--- C. 动作切换 ---")
	stage.lead.pose("walk", 0.5)
	var a := _tex_id(stage.lead)
	stage.lead.pose("sit", 0.0)
	var b := _tex_id(stage.lead)
	print("  walk→sit：第 0 帧就换图？ %s" % str(a != b))
	stage.lead.pose("sit", 0.01)
	print("  sit 第 2 帧仍是同一张？ %s" % str(_tex_id(stage.lead) == b))
	quit()
