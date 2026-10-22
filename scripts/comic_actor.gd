extends RefCounted
const Art := preload("res://scripts/comic_art.gd")
const Motion := preload("res://scripts/comic_motion.gd")
const T := preload("res://scripts/comic_theme.gd")
const Objects := preload("res://scripts/comic_objects.gd")

static func drumming(canvas: CanvasItem, body: Rect2, time: float, reduced: bool = false, position: Rect2 = Rect2()) -> void:
	var sample := Motion.sample("drum",time,reduced)
	var size := Vector2(minf(96,body.size.x*0.34),minf(76,body.size.y*0.36))
	var drum := Rect2(body.position+body.size*Vector2(0.50,0.82),size)
	if position.has_area(): drum = position
	Objects.draw_on(canvas,"drum",drum,0,false)
	var strike := drum.position+drum.size*Vector2(0.5,0.30)
	var stroke := float(sample.stroke)
	var hand_a := strike+Vector2(-24,-12-stroke*7)
	var hand_b := strike+Vector2(25,-12+stroke*7)
	arm(canvas,body.position+body.size*Vector2(0.28,0.78),hand_a,14,Color("193c47"))
	arm(canvas,body.position+body.size*Vector2(0.73,0.79),hand_b,-14,Color("193c47"))
	canvas.draw_line(hand_a,strike+Vector2(-8,-stroke*7),T.CREAM,3)
	canvas.draw_line(hand_b,strike+Vector2(12,stroke*7),T.CREAM,3)
	if absf(stroke) > 0.65:
		for i in range(3): canvas.draw_line(strike+Vector2(i*9-9,-9),strike+Vector2(i*13-13,-17),T.CREAM,2)

static func baked_action(action: String, prop: String) -> String:
	if action == "read" and prop not in ["book",""]: return ""
	if action == "drum": return "" # Drumsticks need freely articulated arms.
	if action == "wave": return ""
	return action

static func texture_rect(texture: Texture2D, foot: Vector2, height: float, max_width: float) -> Rect2:
	var scale := minf(height/texture.get_height(),max_width/texture.get_width())
	var dimensions := texture.get_size()*scale
	return Rect2(foot-Vector2(dimensions.x*0.5,dimensions.y),dimensions)

static func draw_actor(canvas: CanvasItem, key: String, foot: Vector2, height: float, max_width: float, action: String, time: float, expression: String = "normal", flip: bool = false, tint: Color = Color.WHITE, reduced: bool = false, prop: String = "") -> Dictionary:
	var sample := Motion.sample(action,time,reduced)
	height *= float(sample.camera)
	max_width *= float(sample.camera)
	var base := Art.portrait(key,0,expression)
	if base == null: return {}
	if action == "walk" and expression not in ["cry","rage","shock","panic","sleep"]:
		var moving := not reduced and time >= 0.22 and time < 1.85
		var step := int((time-0.22)*7) % 4 if moving else 1
		var walking := Art.walk_frame(key,step)
		if walking != null:
			var anchor := foot+Vector2(sample.offset)
			var bounds := texture_rect(walking,Vector2.ZERO,height,max_width)
			Objects.ellipse(canvas,Rect2(anchor-Vector2(bounds.size.x*0.32,2),Vector2(bounds.size.x*0.64,7)),Color(T.INK,0.38))
			canvas.draw_set_transform(anchor,0,Vector2(-1,1) if flip else Vector2.ONE)
			canvas.draw_texture_rect(walking,bounds,false,tint)
			canvas.draw_set_transform(Vector2.ZERO)
			return {"rect":Rect2(anchor+bounds.position,bounds.size),"baked":true,"blend":1.0,"sample":sample,"foot":anchor,"walk_frame":step}
	var action_texture := Art.action_pose(key,baked_action(action,prop))
	if expression in ["cry","rage","shock","panic","sleep"]: action_texture = null
	# Pixel keyframes cut at hand contact; alpha morphing would create double faces.
	var blend := 1.0 if action_texture != null and float(sample.reach) >= 0.88 else 0.0
	var offset: Vector2 = sample.offset
	var angle := float(sample.angle)
	if flip: offset.x = -offset.x; angle = -angle
	var anchor := foot+offset
	canvas.draw_set_transform(anchor,angle,Vector2(-1,1) if flip else Vector2.ONE)
	var base_rect := texture_rect(base,Vector2.ZERO,height,max_width)
	if blend < 1: canvas.draw_texture_rect(base,base_rect,false,Color(tint,tint.a*(1-blend)))
	var bounds := base_rect
	if action_texture != null and blend > 0:
		bounds = texture_rect(action_texture,Vector2.ZERO,height,max_width)
		if action in ["sign","draw"]:
			draw_writing(canvas,action_texture,bounds,sample,Color(tint,tint.a*blend))
		else: canvas.draw_texture_rect(action_texture,bounds,false,Color(tint,tint.a*blend))
	canvas.draw_set_transform(Vector2.ZERO)
	var world := Rect2(anchor+bounds.position,bounds.size)
	return {"rect":world,"baked":action_texture != null and blend > 0.95,"blend":blend,"sample":sample,"foot":anchor}

static func draw_writing(canvas: CanvasItem, texture: Texture2D, dest: Rect2, sample: Dictionary, tint: Color) -> void:
	var source := Rect2(Vector2.ZERO,texture.get_size())
	var split_y := 0.76
	var split_x := 0.59
	canvas.draw_texture_rect_region(texture,Rect2(dest.position,dest.size*Vector2(1,split_y)),Rect2(source.position,source.size*Vector2(1,split_y)),tint)
	var lower := dest.position+Vector2(0,dest.size.y*split_y)
	var writing := Rect2(lower,dest.size*Vector2(split_x,1-split_y))
	writing.position += Vector2(float(sample.stroke)*1.5,absf(float(sample.stroke))*0.5)
	canvas.draw_texture_rect_region(texture,writing,Rect2(Vector2(0,source.size.y*split_y),source.size*Vector2(split_x,1-split_y)),tint)
	canvas.draw_texture_rect_region(texture,Rect2(lower+Vector2(dest.size.x*split_x,0),dest.size*Vector2(1-split_x,1-split_y)),Rect2(source.size*Vector2(split_x,split_y),source.size*Vector2(1-split_x,1-split_y)),tint)
	var written := float(sample.work)
	if written > 0:
		var at := dest.position+dest.size*Vector2(0.44,0.96)
		canvas.draw_line(at,at+Vector2(dest.size.x*0.18*written,-3),T.ACCENT,1.5)

## Two-link sleeve/forearm with an elbow, wrist and separate fingertips.
static func arm(canvas: CanvasItem, shoulder: Vector2, hand: Vector2, bend: float, sleeve: Color, grip: bool = true) -> void:
	var delta := hand-shoulder
	var elbow := shoulder+delta*0.50+Vector2(-delta.y,delta.x).normalized()*bend
	for segment in [[shoulder,elbow],[elbow,hand]]:
		canvas.draw_line(segment[0].round(),segment[1].round(),T.INK,13)
	canvas.draw_line(shoulder.round(),elbow.round(),sleeve,9)
	canvas.draw_line(elbow.round(),hand.round(),T.CREAM,7)
	canvas.draw_circle(hand.round(),5,T.INK)
	canvas.draw_circle(hand.round(),3.5,T.CREAM)
	if not grip:
		for i in range(3): canvas.draw_line(hand+Vector2(i*3-3,0),hand+Vector2(i*3-3,-7),T.CREAM,2)
