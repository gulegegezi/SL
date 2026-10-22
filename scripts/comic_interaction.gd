extends RefCounted
const T := preload("res://scripts/comic_theme.gd")
const Art := preload("res://scripts/comic_art.gd")
const Objects := preload("res://scripts/comic_objects.gd")

static func object_rect(size: Vector2) -> Rect2:
	return Rect2(size*Vector2(0.42,0.24),Vector2(minf(94,size.x*0.25),84))

static func target_rect(size: Vector2) -> Rect2:
	return Rect2(size*Vector2(0.70,0.43),Vector2(minf(94,size.x*0.25),84))

static func draw_scene(panel: Control, r: Rect2) -> void:
	var config: Dictionary = panel.spec.get("interaction",{})
	var done: bool = panel.interaction_done
	var body_h := r.size.y*0.50
	var progress: float = panel.interaction_amount
	var dragging: bool = str(config.get("kind","")) == "drag"
	var lead_x := 0.80 if dragging else 0.20
	var npc_x := 0.20 if dragging else 0.80
	var speaking := str(panel.current_direction.get("actor","lead"))
	var expression := str(panel.current_direction.get("expr","normal"))
	var lead := Art.portrait(str(panel.spec.get("ink","lead_adult")),0,expression if speaking == "lead" else "normal")
	var supporting := str(panel.spec.get("support", "npc_friend"))
	var npc := Art.portrait(supporting,0,expression if speaking != "lead" else "normal")
	var bob := sin(minf(0.9,panel._interaction_clock)*PI/0.9)*5 if done and not panel.reduced_motion else 0.0
	for actor in [[lead,lead_x,bob],[npc,npc_x,0]]:
		if actor[0] == null: continue
		var dimensions: Vector2 = actor[0].get_size()*minf(body_h/actor[0].get_height(),r.size.x*0.38/actor[0].get_width())
		panel.draw_texture_rect(actor[0],Rect2(Vector2(r.size.x*float(actor[1])-dimensions.x*0.5,r.size.y*0.69-dimensions.y-float(actor[2])),dimensions),false)
	var object_box := object_rect(r.size)
	if done and str(config.get("prop","")) == "phone":
		object_box.position = r.size*Vector2(0.27,0.25)
	if str(config.get("kind","")) == "drag":
		var destination := target_rect(r.size)
		panel.draw_rect(destination,T.CREAM,false,1)
		if done: object_box.position = destination.position
		elif panel.interaction_dragging: object_box.position += panel.interaction_offset
	if dragging and (panel.interaction_dragging or done):
		var hand := object_box.get_center()+Vector2(object_box.size.x*0.36,10)
		panel.draw_line(hand+Vector2(0,8),hand+Vector2(13,33),T.INK,12)
		panel.draw_line(hand+Vector2(0,8),hand+Vector2(13,33),T.CREAM,7)
		panel.draw_rect(Rect2(hand-Vector2(5,3),Vector2(13,16)),T.CREAM)
	var prop_progress := progress
	if done and str(config.get("prop","")) == "drum" and panel._interaction_clock < 0.8 and not panel.reduced_motion:
		prop_progress = sin(panel._interaction_clock*24)*0.5+0.5
	Objects.draw_on(panel,str(config.get("prop","letter")),object_box,prop_progress)
	if done and str(config.get("prop","")) == "phone":
		panel.draw_string(T.font_big(),object_box.position-Vector2(10,5),"…",HORIZONTAL_ALIGNMENT_LEFT,-1,22,T.CREAM)
	var hint := "✓ 已看过 · 可继续选择" if done else str(config.get("hint","点击画面")) + " · 可略过"
	panel.draw_rect(Rect2(8,9,r.size.x-16,28),T.INK)
	panel.draw_string(T.font_body(),Vector2(16,28),hint,HORIZONTAL_ALIGNMENT_LEFT,r.size.x-28,13,T.CREAM)
	if panel.interaction_holding:
		panel.draw_rect(Rect2(10,39,r.size.x-20,4),T.INK)
		panel.draw_rect(Rect2(10,39,(r.size.x-20)*progress,4),T.CREAM)
