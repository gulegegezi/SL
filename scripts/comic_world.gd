extends RefCounted
## A scene has a location, an ensemble and a physical consequence, even without narration.
const Art := preload("res://scripts/comic_art.gd")
const Objects := preload("res://scripts/comic_objects.gd")
const InkTheme := preload("res://scripts/comic_theme.gd")
const Interaction := preload("res://scripts/comic_interaction.gd")
const Motion := preload("res://scripts/comic_motion.gd")
const Gesture := preload("res://scripts/comic_gesture.gd")
static var textures: Dictionary = {}

static func pixel_texture(texture: Texture2D, height: int) -> Texture2D:
	# Atlas regions share a RID; use the region resource identity to keep ages/NPCs distinct.
	var id := str(texture.get_instance_id())+":"+str(height)
	if textures.has(id): return textures[id]
	var image := texture.get_image()
	if image == null: return texture
	image.resize(maxi(1,roundi(float(image.get_width())*height/image.get_height())),height,Image.INTERPOLATE_NEAREST)
	# Render-time palette reduction: the source artwork stays intact.
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x,y)
			if color.a < 0.4: color.a = 0
			else:
				color.r = roundf(color.r*7)/7; color.g = roundf(color.g*7)/7; color.b = roundf(color.b*7)/7; color.a = 1
			image.set_pixel(x,y,color)
	textures[id] = ImageTexture.create_from_image(image)
	return textures[id]

static func enabled(spec: Dictionary) -> bool:
	return not str(spec.get("ink", "")).is_empty() and spec.get("presentation", "world") == "world"

static func plan(spec: Dictionary) -> Dictionary:
	var text := str(spec.get("caption", "")) + str(spec.get("bubble", ""))
	var scene := str(spec.get("scene", "home"))
	var mode := "conversation"
	for row in [["performance", ["鼓", "舞台", "演出"]], ["work", ["加班", "电脑", "键盘", "老板"]], ["study", ["书", "试卷", "考试", "作业"]], ["care", ["病", "医生", "药", "体检"]], ["meal", ["吃", "饭", "面", "厨房"]], ["farewell", ["告别", "离开", "走出", "车站"]], ["gift", ["递", "接过", "抓", "玩具"]]]:
		for word in row[1]:
			if text.contains(word): mode = row[0]; break
		if mode != "conversation": break
	var support := str(spec.get("support", ""))
	var explicit_support := not support.is_empty()
	if support.is_empty():
		support = {"office":"npc_boss", "classroom":"npc_teacher", "home":"npc_parent", "bedroom":"npc_partner", "hospital":"npc_mate", "grave":"npc_partner"}.get(scene,"npc_friend")
	for row in [["npc_parent",["妈妈","母亲"]],["npc_mate",["爸爸","父亲"]],["npc_boss",["老板","上司"]],["npc_teacher",["老师"]],["npc_partner",["伴侣","爱人"]],["npc_friend",["朋友","同学"]]]:
		for word in row[1]:
			if not explicit_support and text.contains(word): support = row[0]; break
	return {"scene":scene,"mode":str(spec.get("world_mode",mode)),"support":support,
		"prop":str(spec.get("interaction",{}).get("prop",spec.get("prop",{"study":"book","work":"computer","meal":"meal","care":"medicine","performance":"drum","gift":"toy"}.get(mode,""))))}

static func sprite(key: String, action: String, frame: int, expression: String) -> Texture2D:
	if key == "infant_infant": key = "lead_child"
	var path := "res://assets/chars/%s_%s_%d_%s.png" % [key,action,frame,expression]
	if not ResourceLoader.exists(path): path = "res://assets/chars/%s_%s_%d_normal.png" % [key,action,frame]
	if not ResourceLoader.exists(path): path = "res://assets/chars/%s_idle_0_normal.png" % key
	if not ResourceLoader.exists(path): return null
	if not textures.has(path): textures[path] = load(path)
	return textures[path]

static func pose(action: String, time: float, settled: bool) -> Dictionary:
	var moving := not settled and time < 1.7
	var progress := 1.0 if settled else smoothstep(0.0,1.7,time)
	var clip := "idle"
	if action == "walk": clip = "walk" if moving else "idle"
	elif action in ["wave","raise","sit"]: clip = action
	elif action in ["phone","read","sign","draw","receive","offer","drum","type"]: clip = "raise"
	var count := 4 if clip in ["walk","wave"] else 3
	var frame := int(time*8)%count if moving else (2 if clip == "raise" else 0)
	return {"clip":clip,"frame":frame,"progress":progress,"moving":moving}

static func actor(c: CanvasItem, key: String, foot: Vector2, action: String, time: float, expression: String, flip: bool, settled: bool, scale: float = 2, canvas_scale: float = 1) -> Rect2:
	var p := pose(action,time,settled)
	var gesture := Gesture.sample(action,time,settled)
	if int(gesture.frame) == 3 and expression in ["angry","rage","sad","cry","hurt","panic","scared"]: gesture.frame = 2
	var detailed := Art.walk_frame(key,int(p.frame)) if action == "walk" and p.moving else null
	if detailed == null: detailed = Art.ensemble_frame(key,int(gesture.frame))
	var tex: Texture2D
	if key == "infant_infant":
		var infant := Art.portrait(key,0,expression)
		tex = pixel_texture(infant,40) if infant != null else null
	elif detailed != null: tex = pixel_texture(detailed,64)
	else:
		var full_body := sprite(key,p.clip,p.frame,expression)
		tex = pixel_texture(full_body,64) if full_body != null else null
	if tex == null: return Rect2()
	var zoom := scale/2.0
	zoom *= float({"lead_child":0.74,"lead_teen":0.90,"infant_infant":0.56}.get(key,1.0))
	var dimensions := (tex.get_size()*zoom).round()
	var offset: Vector2 = Vector2(gesture.offset)*zoom
	if flip: offset.x = -offset.x
	var anchor := (foot+offset).round()
	var local := Rect2(Vector2(-dimensions.x/2,-dimensions.y),dimensions)
	var rect := Rect2(anchor+local.position,dimensions)
	c.draw_rect(Rect2(Vector2(foot.x-dimensions.x*0.32,foot.y-2).round(),Vector2(dimensions.x*0.64,3)),Color("101e2b99"))
	var angle := -float(gesture.angle) if flip else float(gesture.angle)
	var stretch: Vector2 = gesture.scale
	c.draw_set_transform(anchor*canvas_scale,angle,stretch*Vector2(-1 if flip else 1,1)*canvas_scale)
	c.draw_texture_rect(tex,local,false)
	c.draw_set_transform(Vector2.ZERO,0,Vector2.ONE*canvas_scale)
	return rect

static func caption_height(spec: Dictionary, size: Vector2, completed: bool) -> float:
	var caption := str(spec.get("caption",""))
	if completed and spec.has("interaction"): caption += "\n"+str(spec.interaction.get("reveal",""))
	if caption.is_empty(): return 12
	var font_size := 15 if size.x >= 230 else (11 if size.x >= 165 else 10)
	return InkTheme.font_body().get_multiline_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,maxf(30,size.x-46),font_size).y+39

static func composition(spec: Dictionary, size: Vector2, completed: bool = false) -> Dictionary:
	var top := 42.0 if spec.has("interaction") else 12.0
	var bubble := str(spec.get("bubble",""))
	if not bubble.is_empty():
		top += InkTheme.font_body().get_multiline_string_size(bubble,HORIZONTAL_ALIGNMENT_LEFT,maxf(30,minf(size.x-44,192)),13).y+26
	var bottom := minf(size.y-48,caption_height(spec,size,completed))
	var area := Rect2(10,top,maxf(1,size.x-20),maxf(32,size.y-top-bottom))
	var height := minf(area.size.y*0.83,area.size.x*0.43)
	return {"area":area,"height":height,"foot_y":area.end.y-5,
		"lead":Vector2(area.position.x+area.size.x*0.37,area.end.y-5),
		"support":Vector2(area.position.x+area.size.x*0.77,area.end.y-9)}

static func interaction_rect(panel: Control, target: bool = false) -> Rect2:
	var layout := composition(panel.spec,panel.size,panel.interaction_done)
	var prop := str(panel.spec.get("interaction",{}).get("prop","letter"))
	var dimensions := Vector2(32,32)
	if prop == "phone": dimensions = Vector2(20,32)
	if prop == "drum": dimensions = Vector2(54,43)
	var center: Vector2 = layout.lead+Vector2(20,-float(layout.height)*0.25)
	if not target and panel.spec.get("interaction",{}).get("kind","") == "drag": center = layout.support+Vector2(-18,-float(layout.height)*0.35)
	var rect := Rect2((center-dimensions/2).round(),dimensions)
	rect.position.x = clampf(rect.position.x,12,maxf(12,panel.size.x-dimensions.x-12))
	rect.position.y = clampf(rect.position.y,float(layout.area.position.y),maxf(float(layout.area.position.y),float(layout.area.end.y)-dimensions.y))
	return rect

static func settled_object_rect(panel: Control, body: Rect2, prop: String) -> Rect2:
	var destination := Rect2(body.position+body.size*Vector2(0.80,0.42),Vector2(28,32))
	if prop == "phone": destination = Rect2(body.position+body.size*Vector2(0.66,0.40),Vector2(12,21))
	if prop == "drum": destination = Rect2(body.position+body.size*Vector2(0.68,0.70),Vector2(64,51))
	var area: Rect2 = composition(panel.spec,panel.size,panel.interaction_done).area
	destination.size = destination.size.min(area.size)
	destination.position.x = clampf(destination.position.x,area.position.x,area.end.x-destination.size.x)
	destination.position.y = clampf(destination.position.y,area.position.y,area.end.y-destination.size.y)
	return destination

static func draw_scene(panel: Control, r: Rect2) -> void:
	var config := plan(panel.spec)
	var direction: Dictionary = panel.current_direction
	var action := str(direction.get("action","idle"))
	var speaking := str(direction.get("actor","lead"))
	if speaking != "lead": config.support = "npc_"+speaking
	var directed_action := action
	if speaking != "lead": action = "idle"
	var time: float = panel._moment_age
	var settled: bool = panel.reduced_motion or panel._moment_age >= 2.4
	var interactive: bool = panel.spec.has("interaction")
	if interactive:
		action = Motion.interaction_kind(panel.spec.interaction)
		time = minf(2.4,Interaction.action_time(panel))
		settled = panel.interaction_done and (panel.reduced_motion or time >= 2.4)
	# Integer enlargement of an actual low resolution stage keeps visible square pixels.
	var pixel := 2
	var s := r.size/float(pixel)
	var layout := composition(panel.spec,r.size,panel.interaction_done)
	# Drawing is performed by the panel; no viewport texture or extra scene tree per frame.
	panel.draw_set_transform(Vector2.ZERO,0,Vector2.ONE*pixel)
	backdrop(panel,s,config.scene,time,settled)
	var floor_y := float(layout.foot_y)/pixel
	var lead_x := float(layout.lead.x)/pixel
	var support_x := float(layout.support.x)/pixel
	var travel := float(pose(action,time,settled).progress)
	if action == "walk":
		lead_x = lerpf(s.x*0.12,s.x*0.51,travel)
		if bool(direction.get("exit",false)): lead_x = lerpf(s.x*0.40,s.x*1.12,travel)
	var reaction := Gesture.response(config.mode,action,time)
	var support_action := str(reaction.action)
	var support_time := float(reaction.time)
	if speaking != "lead": support_action = directed_action
	var support_expr := str(direction.get("expr","normal")) if speaking != "lead" else "normal"
	var actor_scale := float(layout.height)/64
	if action == "phone":
		panel.draw_rect(Rect2(s.x*0.64,13,s.x*0.32,floor_y-10),Color("153244"))
		panel.draw_line(Vector2(s.x*0.64,13),Vector2(s.x*0.60,floor_y),Color("70b4b6"),2)
		panel.draw_string(InkTheme.font_body(),Vector2(s.x*0.68,25),"电话另一端",HORIZONTAL_ALIGNMENT_LEFT,-1,8,InkTheme.CREAM)
	if not bool(panel.spec.get("world_solo",false)):
		actor(panel,config.support,Vector2(support_x,floor_y-4),support_action,time if speaking != "lead" else support_time,support_expr,true,settled,actor_scale,pixel)
	# Classmates / audience give public scenes a visible social context.
	if not bool(panel.spec.get("world_solo",false)) and (config.scene == "classroom" or config.mode == "performance"):
		actor(panel,"npc_friend",Vector2(s.x*0.14,floor_y-10),"sit",time,"normal",false,settled,actor_scale*0.62,pixel)
		actor(panel,"npc_partner" if config.scene == "classroom" else "npc_mate",Vector2(s.x*0.90,floor_y-10),"wave" if config.mode == "performance" else "sit",time+0.2,"normal",true,settled,actor_scale*0.62,pixel)
	var body := actor(panel,str(panel.spec.ink),Vector2(lead_x,floor_y),action,time,str(direction.get("expr","normal")),false,settled,actor_scale,pixel)
	panel._actor_render = {"rect":Rect2(body.position*pixel,body.size*pixel),"baked":true,"world":true}
	# Contact marks and a brief trailing stroke support the action instead of
	# running an unrelated full-screen effect over the dialogue.
	if not settled and action in Gesture.ACTIVE and time >= 0.62 and time < 0.90:
		var contact_at := body.position+body.size*Vector2(0.92,0.42)
		for i in range(3): panel.draw_line(contact_at+Vector2(3+i*3,-4),contact_at+Vector2(6+i*4,-9),Color("dbbf98"),1)
	var object := str(config.prop)
	if not interactive and not str(direction.get("prop","")).is_empty(): object = str(direction.prop)
	var contact := smoothstep(0.2,1.2,time) if not settled else 1.0
	if config.mode in ["study","work","meal","care"]:
		var table := Rect2(Vector2(s.x*0.30,floor_y-14),Vector2(s.x*0.40,9))
		panel.draw_rect(table,Color("173743"))
		panel.draw_rect(Rect2(table.position,Vector2(table.size.x,3)),Color("b29484"))
		for x in [table.position.x+4,table.end.x-7]: panel.draw_rect(Rect2(x,table.end.y,3,15),Color("111e2a"))
	if not object.is_empty() and not interactive:
		var at := Vector2(lead_x+8,floor_y-23)
		if object in ["computer","drum"]: at.x = s.x*0.45
		if object == "phone": at = body.position+body.size*Vector2(0.66,0.40)
		elif config.mode == "gift": at = Vector2(lerpf(support_x-15,body.position.x+body.size.x*0.80,contact),body.position.y+body.size.y*0.42)
		elif object in ["book","letter","contract","toy","pencil"]: at = body.position+body.size*Vector2(0.80,0.42)
		var object_size := Vector2(19,19)
		if object == "phone": object_size = Vector2(8,13)
		if object == "computer": object_size = Vector2(30,24); at.y -= 13
		Objects.draw_on(panel,object,Rect2(at.round(),object_size),contact)
		if object == "drum" and action == "drum":
			for i in range(2):
				var beat := 0.0 if settled else sin(time*18+i*PI)*6
				panel.draw_line(at+Vector2(-5+i*16,-6+beat),at+Vector2(6+i*8,5),Color("e5c695"),2)
		if object == "meal":
			for i in range(3):
				var rise := 3.0 if settled else fmod(time*6+i*3,9)
				panel.draw_line((at+Vector2(5+i*4,2-rise)).round(),(at+Vector2(6+i*4,-2-rise)).round(),Color("c2cebd99"),1)
		var powered_off := action == "poweroff" and contact >= 0.5
		for i in range(mini(panel._moment_index+1,panel.moments.size())):
			if str(panel.moments[i].action) == "poweroff": powered_off = i < panel._moment_index or contact >= 0.5
			elif str(panel.moments[i].action) == "type": powered_off = false
		if object == "computer" and powered_off:
			panel.draw_rect(Rect2(at+object_size*Vector2(0.08,0.08),object_size*Vector2(0.84,0.54)),Color("12232c"))
		if config.mode == "work" and action == "type":
			for i in range(3): panel.draw_rect(Rect2(at+Vector2(5,4+i*3),Vector2(9*contact,1)),Color("48c1b4"))
	if config.mode == "performance" and action in ["drum","wave"]:
		for i in range(3):
			var at := Vector2(lead_x+20+i*12,floor_y-35-float(i%2)*10)
			if not settled: at.y -= fmod(time*12+i*7,18)
			panel.draw_line(at,at+Vector2(0,-7),Color("f1b564"),2)
			panel.draw_rect(Rect2(at-Vector2(3,0),Vector2(4,3)),Color("f1b564"))
	# Environmental outcome survives as a readable final tableau in the archive.
	if config.mode == "work" and action in ["type","sign"]:
		panel.draw_rect(Rect2(s.x*0.28,floor_y-23,10,9),Color("d8b498"))
		for i in range(3): panel.draw_line(Vector2(s.x*0.62,floor_y-16-i*3),Vector2(s.x*0.68,floor_y-16-i*3),Color("d5d4bc"),2)
	if config.mode == "care":
		panel.draw_rect(Rect2(s.x*0.62,floor_y-26,15,12),Color("d5e3ce"))
		panel.draw_rect(Rect2(s.x*0.62+6,floor_y-24,3,8),Color("bf535a"))
		panel.draw_rect(Rect2(s.x*0.62+3,floor_y-21,9,2),Color("bf535a"))
	if config.mode == "farewell":
		panel.draw_rect(Rect2(lead_x-16,floor_y-12,9,12),Color("a54f4f"))
		panel.draw_line(Vector2(lead_x-13,floor_y-15),Vector2(lead_x-9,floor_y-15),Color("e4c3a3"),1)
	# Foreground silhouettes establish depth without obscuring faces.
	panel.draw_rect(Rect2(0,s.y*0.80,6,s.y*0.20),Color("122632"))
	panel.draw_rect(Rect2(s.x-9,s.y*0.76,9,s.y*0.24),Color("122632"))
	panel.draw_set_transform(Vector2.ZERO)
	if interactive: draw_interactive(panel,r,object,time)
	if int(direction.get("intensity",0)) >= 3:
		var at := Vector2(r.size.x*0.42,r.size.y*0.19)
		panel.draw_string(InkTheme.font_big(),at,str(direction.get("sfx","？！")),HORIZONTAL_ALIGNMENT_LEFT,-1,24,InkTheme.ACCENT)
		var focus := str(panel.spec.ink) if speaking == "lead" else str(config.support)
		var portrait := Art.portrait(focus,0,str(direction.get("expr","shock")))
		if portrait != null:
			var inset := Rect2(12,38,60,66)
			panel.draw_rect(inset.grow(3),InkTheme.ACCENT)
			panel.draw_rect(inset,InkTheme.INK)
			var pixel_portrait := pixel_texture(portrait,32)
			var dimensions := pixel_portrait.get_size()*minf(54.0/pixel_portrait.get_width(),62.0/pixel_portrait.get_height())
			panel.draw_texture_rect(pixel_portrait,Rect2(inset.get_center()-dimensions/2,dimensions),false)

static func backdrop(c: CanvasItem, s: Vector2, room: String, time: float, settled: bool) -> void:
	var background := Art.background(room)
	c.draw_rect(Rect2(Vector2.ZERO,s),Color("1c5865"))
	if background != null: c.draw_texture_rect_region(background,Rect2(Vector2.ZERO,s),Art.cover_region(background,s),Color("7baeb8"))
	var horizon := s.y*0.57
	c.draw_rect(Rect2(0,horizon,s.x,s.y-horizon),Color("223a48bb"))
	for i in range(9): c.draw_line(Vector2(i*s.x/8,horizon),Vector2((i-4)*s.x/4+s.x/2,s.y),Color("47616b66"),1)
	for i in range(5): c.draw_line(Vector2(0,horizon+i*i*2),Vector2(s.x,horizon+i*i*2),Color("61717b55"),1)
	if room in ["home","bedroom","hospital","classroom","office"]:
		c.draw_rect(Rect2(s.x*0.07,12,35,maxf(22,horizon-22)),Color("102b3d"))
		c.draw_rect(Rect2(s.x*0.07+3,15,29,maxf(16,horizon-28)),Color("55a4af"))
		c.draw_line(Vector2(s.x*0.07+17,15),Vector2(s.x*0.07+17,horizon-10),Color("263d4c"),2)
		c.draw_rect(Rect2(s.x*0.84,16,24,horizon-10),Color("172938"))
		c.draw_rect(Rect2(s.x*0.84+3,19,18,horizon-16),Color("375764"))
		c.draw_rect(Rect2(s.x*0.84+4,horizon*0.7,2,2),Color("dda784"))
	if room == "office":
		for i in range(4):
			var at := Vector2(s.x*0.29+i*21,20)
			c.draw_rect(Rect2(at,Vector2(17,13)),Color("0b2537"))
			c.draw_rect(Rect2(at+Vector2(2,2),Vector2(13,9)),Color("4a96a6"))
	if room == "classroom":
		c.draw_rect(Rect2(s.x*0.28,15,s.x*0.45,30),Color("173c40"))
		for i in range(3): c.draw_line(Vector2(s.x*0.33,21+i*6),Vector2(s.x*0.50+i*6,21+i*6),Color("b6c6b4"),1)
	if room in ["park","grave"]:
		for i in range(3):
			var x := s.x*(0.10+i*0.37)
			c.draw_rect(Rect2(x,20,5,horizon),Color("183638"))
			c.draw_rect(Rect2(x-14,12,34,24),Color("235d57"))
			c.draw_rect(Rect2(x-8,6,23,14),Color("367f6b"))
		if room == "grave": c.draw_rect(Rect2(s.x*0.57,horizon-20,17,29),Color("8a9fa2"))
	else:
		# Slow dust through window light; a frozen sample is used for reduced motion.
		for i in range(9):
			var shift := 0.0 if settled else fmod(time*3+i*7,17)
			c.draw_rect(Rect2(Vector2(18+i*7,31+i*5+shift).round(),Vector2.ONE),Color("d0c5a877"))

static func draw_interactive(panel: Control, r: Rect2, prop: String, time: float) -> void:
	var box := interaction_rect(panel)
	if panel.interaction_dragging: box.position += panel.interaction_offset
	if panel.interaction_done:
		var body: Rect2 = panel._actor_render.get("rect",Rect2())
		var destination := settled_object_rect(panel,body,prop)
		var reach := 1.0 if panel.reduced_motion else smoothstep(0.1,0.95,time)
		box = Rect2(box.position.lerp(destination.position,reach),box.size.lerp(destination.size,reach))
	Objects.draw_on(panel,prop,box,smoothstep(0,1.3,time))
	if prop == "drum" and panel.interaction_done:
		for i in range(2):
			var beat := 0.0 if panel.reduced_motion or time >= 2.4 else sin(time*18+i*PI)*7
			panel.draw_line(box.position+Vector2(-8+i*24,-12+beat),box.position+Vector2(18+i*12,12),InkTheme.CREAM,3)
	if panel.spec.interaction.get("kind","") == "drag" and not panel.interaction_done: panel.draw_rect(interaction_rect(panel,true),InkTheme.CREAM,false,2)
	var text := "✓ 已完成 · 可继续选择" if panel.interaction_done else str(panel.spec.interaction.get("hint","点击道具"))+" · 可略过"
	panel.draw_rect(Rect2(8,8,r.size.x-16,26),InkTheme.INK)
	panel.draw_string(InkTheme.font_body(),Vector2(14,27),text,HORIZONTAL_ALIGNMENT_LEFT,r.size.x-25,13,InkTheme.CREAM)
	if panel.interaction_holding: panel.draw_rect(Rect2(9,36,(r.size.x-18)*panel.interaction_amount,4),InkTheme.ACCENT)
