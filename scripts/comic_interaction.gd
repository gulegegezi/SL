extends RefCounted
const T := preload("res://scripts/comic_theme.gd")
const Motion := preload("res://scripts/comic_motion.gd")
const Actor := preload("res://scripts/comic_actor.gd")
const Objects := preload("res://scripts/comic_objects.gd")

static func object_rect(size: Vector2, prop: String = "") -> Rect2:
	if prop == "drum": return Rect2(size*Vector2(0.44,0.60),Vector2(minf(94,size.x*0.25),70))
	return Rect2(size*Vector2(0.42,0.24),Vector2(minf(94,size.x*0.25),84))

static func target_rect(size: Vector2) -> Rect2:
	return Rect2(size*Vector2(0.70,0.43),Vector2(minf(94,size.x*0.25),84))

static func action_time(panel: Control) -> float:
	if panel.interaction_done:
		if panel.reduced_motion: return Motion.DURATION
		return panel._interaction_clock
	if panel.interaction_holding: return panel.interaction_amount*1.6
	if panel.interaction_dragging: return 0.22+panel.interaction_amount*0.60
	return 0.0

static func draw_scene(panel: Control, r: Rect2) -> void:
	var config: Dictionary = panel.spec.get("interaction",{})
	var done: bool = panel.interaction_done
	var prop := str(config.get("prop","letter"))
	var dragging := str(config.get("kind","")) == "drag"
	var action := Motion.interaction_kind(config)
	var time := action_time(panel)
	var sample := Motion.sample(action,time,panel.reduced_motion and done)
	var lead_x := 0.77 if dragging else 0.32
	var npc_x := 0.18 if dragging else 0.82
	var height := r.size.y*0.56
	var max_width := r.size.x*(0.46 if dragging else 0.56)
	var foot := r.size*Vector2(lead_x,0.72)
	var support := str(panel.spec.get("support","npc_friend"))
	var expression := str(panel.current_direction.get("expr","normal")) if str(panel.current_direction.get("actor","lead")) == "lead" else "normal"
	var desk := Rect2(r.size*Vector2(0.28,0.51),r.size*Vector2(0.48,0.19))
	panel.draw_rect(desk,T.INK_SOFT)
	panel.draw_line(desk.position,desk.position+Vector2(desk.size.x,0),T.CREAM,2)
	var npc_action := "offer" if dragging else "nod"
	var npc_time := minf(Motion.DURATION,time+0.25) if done else (0.65 if dragging else 0.0)
	Actor.draw_actor(panel,support,r.size*Vector2(npc_x,0.70),height*0.83,r.size.x*0.35,npc_action,npc_time,"normal",dragging,Color(0.73,0.87,0.86),panel.reduced_motion)
	var lead := Actor.draw_actor(panel,str(panel.spec.get("ink","lead_adult")),foot,height,max_width,action,time,expression,dragging,Color.WHITE,panel.reduced_motion and done,prop)
	if lead.is_empty(): return
	var object_box := object_rect(r.size,prop)
	var bounds: Rect2 = lead.rect
	var contact := bounds.position+bounds.size*Vector2(0.52,0.79)
	if dragging:
		var destination := target_rect(r.size)
		if not done: panel.draw_rect(destination,T.CREAM,false,1)
		if panel.interaction_dragging: object_box.position += panel.interaction_offset
		elif done:
			var lift := smoothstep(0.82,1.5,time)
			object_box.size = object_box.size.lerp(Vector2(58,52),lift)
			object_box.position = destination.position.lerp(contact-object_box.size*0.5,lift)
	elif action == "phone":
		contact = bounds.position+bounds.size*Vector2(0.30,0.31)
		object_box.position = object_box.position.lerp(contact-object_box.size*0.35,float(sample.reach))
	elif action in ["read","draw"]:
		object_box.position = object_box.position.lerp(contact-object_box.size*0.5,float(sample.reach))
	var baked := bool(lead.baked) and action in ["phone","read","draw","sign"]
	if not baked and action != "drum":
		var hand := object_box.get_center()+Vector2(object_box.size.x*0.27,10)
		if time > 0.18 or panel.interaction_dragging:
			var shoulder := bounds.position+bounds.size*Vector2(0.65 if dragging else 0.38,0.57)
			Actor.arm(panel,shoulder,shoulder.lerp(hand,float(sample.reach)),18 if dragging else -18,Color("193c47"),bool(sample.contact))
		var progress := float(sample.reach)
		if action == "drum": progress = float(sample.stroke)*0.5+0.5 if bool(sample.contact) else 0
		Objects.draw_on(panel,prop,object_box,progress)
	if action == "read" and bool(sample.contact) and time < 1.9 and not panel.reduced_motion:
		var page := bounds.position+bounds.size*Vector2(0.48,0.74)
		var turn := sin(clampf((time-0.82)/1.08,0,1)*PI)
		panel.draw_colored_polygon(PackedVector2Array([page,page+Vector2(22*turn,-18),page+Vector2(22*turn,13),page+Vector2(0,22)]),Color(T.CREAM,0.85))
	if action == "drum":
		Actor.drumming(panel,bounds,time,panel.reduced_motion,object_box)
	if done and prop == "phone": panel.draw_string(T.font_big(),bounds.position+Vector2(bounds.size.x*0.85,30),"…",HORIZONTAL_ALIGNMENT_LEFT,-1,22,T.CREAM)
	var hint := "✓ 已看过 · 可继续选择" if done else str(config.get("hint","点击画面"))+" · 可略过"
	panel.draw_rect(Rect2(8,9,r.size.x-16,28),T.INK)
	panel.draw_string(T.font_body(),Vector2(16,28),hint,HORIZONTAL_ALIGNMENT_LEFT,r.size.x-28,13,T.CREAM)
	if panel.interaction_holding:
		panel.draw_rect(Rect2(10,39,r.size.x-20,4),T.INK)
		panel.draw_rect(Rect2(10,39,(r.size.x-20)*panel.interaction_amount,4),T.CREAM)
