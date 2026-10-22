extends RefCounted
## A scene has a location, an ensemble and a physical consequence, even without narration.
const Art := preload("res://scripts/comic_art.gd")
const Objects := preload("res://scripts/comic_objects.gd")
const InkTheme := preload("res://scripts/comic_theme.gd")
const Interaction := preload("res://scripts/comic_interaction.gd")
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
	var support := str(spec.get("support", ""))
	if support.is_empty():
		support = {"office":"npc_boss", "classroom":"npc_teacher", "home":"npc_parent", "bedroom":"npc_partner", "hospital":"npc_mate", "grave":"npc_partner"}.get(scene,"npc_friend")
	for row in [["npc_parent",["妈妈","母亲"]],["npc_mate",["爸爸","父亲"]],["npc_boss",["老板","上司"]],["npc_teacher",["老师"]],["npc_partner",["伴侣","爱人"]],["npc_friend",["朋友","同学"]]]:
		for word in row[1]:
			if text.contains(word): support = row[0]; break
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

static func actor(c: CanvasItem, key: String, foot: Vector2, action: String, time: float, expression: String, flip: bool, settled: bool, scale: int = 2) -> Rect2:
	var p := pose(action,time,settled)
	var detailed := Art.walk_frame(key,int(p.frame) if action == "walk" else 1)
	var tex: Texture2D
	var npc := key.begins_with("npc_")
	if key == "infant_infant": tex = pixel_texture(Art.portrait(key,0,expression),40)
	elif detailed != null: tex = pixel_texture(detailed,64)
	elif npc:
		var portrait := Art.portrait(key,0,expression)
		tex = pixel_texture(portrait,28) if portrait != null else null
	else: tex = sprite(key,p.clip,p.frame,expression)
	if tex == null: return Rect2()
	var zoom := scale/2.0
	var dimensions := (tex.get_size()*zoom).round()
	var full_height := (64*zoom) if npc else dimensions.y
	var top := foot-Vector2(dimensions.x/2,full_height)
	if action == "sit": top.y += 9*float(p.progress)
	if action == "wave" and not settled: top.y -= roundf(absf(sin(time*6))*2)
	var rect := Rect2((foot-Vector2(dimensions.x/2,dimensions.y)).round(),dimensions)
	rect.position = top.round()
	c.draw_rect(Rect2(foot.round()+Vector2(-12,-2),Vector2(24,4)),Color("101e2b99"))
	if npc:
		var coat := top+Vector2(dimensions.x*0.5-10,23*zoom)
		var cloth := Color({"npc_parent":"765766","npc_friend":"2c5369","npc_boss":"233948","npc_teacher":"3d6765","npc_mate":"5b676d","npc_partner":"766153"}.get(key,"315968"))
		c.draw_rect(Rect2(coat.round(),Vector2(20*zoom,21*zoom)),Color("142b39"))
		c.draw_rect(Rect2((coat+Vector2(2,0)*zoom).round(),Vector2(16*zoom,20*zoom)),cloth)
		c.draw_rect(Rect2((coat+Vector2(8,0)*zoom).round(),Vector2(4*zoom,10*zoom)),Color("acb4b1"))
		for button in range(3): c.draw_rect(Rect2((coat+Vector2(10,11+button*3)*zoom).round(),Vector2.ONE*zoom),Color("98a9a4"))
		for side in [-3,18]:
			c.draw_rect(Rect2((coat+Vector2(side,2)*zoom).round(),Vector2(5*zoom,15*zoom)),cloth)
			c.draw_rect(Rect2((coat+Vector2(side+1,17)*zoom).round(),Vector2(3*zoom,4*zoom)),Color("dabba4"))
		var leg := top+Vector2(dimensions.x*0.5-8,44*zoom)
		for x in [0,10]:
			c.draw_rect(Rect2((leg+Vector2(x*zoom,0)).round(),Vector2(7*zoom,20*zoom)),Color("152539"))
			c.draw_rect(Rect2((leg+Vector2((x+1)*zoom,0)).round(),Vector2(2*zoom,17*zoom)),Color("354457"))
			c.draw_rect(Rect2((leg+Vector2(x*zoom-2,17*zoom)).round(),Vector2(10*zoom,4*zoom)),Color("0a1928"))
	if detailed != null and not (action == "walk" and bool(p.moving)):
		var cut := roundf(dimensions.y*0.73)
		c.draw_texture_rect_region(tex,Rect2(rect.position,Vector2(dimensions.x,cut)),Rect2(Vector2.ZERO,Vector2(tex.get_width(),tex.get_height()*0.73)))
		for side in [-6,2]:
			var leg := (Vector2(foot.x+side*zoom,top.y+cut-1)).round()
			c.draw_rect(Rect2(leg,Vector2(6*zoom,full_height-cut)),Color("24354a"))
			c.draw_line(leg+Vector2(2,1),leg+Vector2(2,full_height-cut-3),Color("3f5163"),1)
			c.draw_rect(Rect2(Vector2(leg.x-2,foot.y-3).round(),Vector2(9*zoom,3)),Color("0a1928"))
	else: c.draw_texture_rect(tex,rect,false)
	# Articulated pixel sleeves and palms show actions even on a standing full-body frame.
	if action in ["raise","wave","phone","read","sign","draw","receive","offer","drum","type"]:
		var shoulder := top+Vector2(dimensions.x*0.72,full_height*0.38)
		var reach := 1.0 if settled else smoothstep(0.1,0.9,time)
		var hand := shoulder+Vector2(12,-10 if action in ["phone","wave"] else 13)*reach
		if action == "wave" and not settled: hand.x += roundf(sin(time*14)*4)
		if action in ["drum","type","sign","draw"] and not settled: hand.y += roundf(sin(time*18)*4)
		var elbow := shoulder.lerp(hand,0.55)+Vector2(3,4)
		for segment in [[shoulder,elbow],[elbow,hand]]:
			c.draw_line(segment[0].round(),segment[1].round(),Color("10283b"),5)
			c.draw_line(segment[0].round(),segment[1].round(),Color("558c9c"),3)
		c.draw_rect(Rect2(hand.round()-Vector2(2,2),Vector2(4,4)),Color("e6c4aa"))
	return rect

static func draw_scene(panel: Control, r: Rect2) -> void:
	var config := plan(panel.spec)
	var direction: Dictionary = panel.current_direction
	var action := str(direction.get("action","idle"))
	var speaking := str(direction.get("actor","lead"))
	var directed_action := action
	if speaking != "lead": action = "idle"
	var time: float = panel._moment_age
	var settled: bool = panel.reduced_motion or panel._moment_age >= 2.4
	var interactive: bool = panel.spec.has("interaction")
	if interactive:
		action = str(panel.spec.interaction.get("action", {"phone":"phone","book":"read","drum":"drum","letter":"sign","contract":"sign"}.get(config.prop,"raise")))
		time = Interaction.action_time(panel)
		settled = panel.reduced_motion and panel.interaction_done
	# Integer enlargement of an actual low resolution stage keeps visible square pixels.
	var pixel := maxi(1,int(r.size.x/240))
	var s := r.size/float(pixel)
	# Drawing is performed by the panel; no viewport texture or extra scene tree per frame.
	panel.draw_set_transform(Vector2.ZERO,0,Vector2.ONE*pixel)
	backdrop(panel,s,config.scene,time,settled)
	var floor_y := s.y*0.72
	var lead_x := s.x*0.39
	var support_x := s.x*0.76
	var travel := float(pose(action,time,settled).progress)
	if action == "walk":
		lead_x = lerpf(s.x*0.12,s.x*0.51,travel)
		if bool(direction.get("exit",false)): lead_x = lerpf(s.x*0.40,s.x*1.12,travel)
	var support_action := "idle"
	if config.mode == "gift": support_action = "raise"
	if config.mode == "farewell": support_action = "wave"
	if config.mode == "performance": support_action = "wave" if time > 0.8 else "idle"
	if config.mode == "care": support_x -= travel*s.x*0.12; support_action = "raise"
	if config.mode == "work": support_x -= travel*s.x*0.10
	if speaking != "lead": support_action = directed_action
	var support_expr := str(direction.get("expr","normal")) if speaking != "lead" else "normal"
	var actor_scale := maxi(1,roundi(s.y/64*0.52*2))
	if action == "phone":
		panel.draw_rect(Rect2(s.x*0.64,13,s.x*0.32,floor_y-10),Color("153244"))
		panel.draw_line(Vector2(s.x*0.64,13),Vector2(s.x*0.60,floor_y),Color("70b4b6"),2)
		panel.draw_string(InkTheme.font_body(),Vector2(s.x*0.68,25),"电话另一端",HORIZONTAL_ALIGNMENT_LEFT,-1,8,InkTheme.CREAM)
	actor(panel,config.support,Vector2(support_x,floor_y-8),support_action,time+0.35,support_expr,true,settled,actor_scale)
	# Classmates / audience give public scenes a visible social context.
	if config.scene == "classroom" or config.mode == "performance":
		actor(panel,"npc_friend",Vector2(s.x*0.14,floor_y-15),"sit",time,"normal",false,settled,maxi(1,actor_scale-1))
		actor(panel,"npc_mate",Vector2(s.x*0.90,floor_y-13),"wave" if config.mode == "performance" else "sit",time+0.2,"normal",true,settled,maxi(1,actor_scale-1))
	var body := actor(panel,str(panel.spec.ink),Vector2(lead_x,floor_y),action,time,str(direction.get("expr","normal")),false,settled,actor_scale)
	panel._actor_render = {"rect":Rect2(body.position*pixel,body.size*pixel),"baked":true,"world":true}
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
		if object == "phone": at = body.position+body.size*Vector2(0.80,0.25)
		elif config.mode == "gift": at.x = lerpf(support_x-15,lead_x+8,contact)
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
		if config.mode == "work":
			for i in range(3): panel.draw_rect(Rect2(at+Vector2(5,4+i*3),Vector2(9*contact,1)),Color("48c1b4"))
	if config.mode == "performance" and action in ["drum","wave"]:
		for i in range(3):
			var at := Vector2(lead_x+20+i*12,floor_y-35-float(i%2)*10)
			if not settled: at.y -= fmod(time*12+i*7,18)
			panel.draw_line(at,at+Vector2(0,-7),Color("f1b564"),2)
			panel.draw_rect(Rect2(at-Vector2(3,0),Vector2(4,3)),Color("f1b564"))
	# Environmental outcome survives as a readable final tableau in the archive.
	if config.mode == "work" and action == "poweroff": panel.draw_rect(Rect2(s.x*0.44,floor_y-32,23,15),Color("12232c"))
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
			panel.draw_texture_rect(pixel_portrait,Rect2(inset.position+Vector2(3,2),Vector2(54,62)),false)

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
	var box := Interaction.object_rect(r.size,prop)
	if panel.interaction_dragging: box.position += panel.interaction_offset
	if panel.interaction_done:
		var body: Rect2 = panel._actor_render.get("rect",Rect2())
		var destination := Rect2(body.position+body.size*Vector2(0.75,0.54),Vector2(28,32))
		if prop == "phone": destination = Rect2(body.position+body.size*Vector2(0.82,0.24),Vector2(12,21))
		if prop == "drum": destination = Rect2(body.position+body.size*Vector2(0.68,0.70),Vector2(64,51))
		var reach := 1.0 if panel.reduced_motion else smoothstep(0.1,0.95,time)
		box = Rect2(box.position.lerp(destination.position,reach),box.size.lerp(destination.size,reach))
	Objects.draw_on(panel,prop,box,smoothstep(0,1.3,time))
	if prop == "drum" and panel.interaction_done:
		for i in range(2):
			var beat := 0.0 if panel.reduced_motion else sin(time*18+i*PI)*7
			panel.draw_line(box.position+Vector2(-8+i*24,-12+beat),box.position+Vector2(18+i*12,12),InkTheme.CREAM,3)
	if panel.spec.interaction.get("kind","") == "drag" and not panel.interaction_done: panel.draw_rect(Interaction.target_rect(r.size),InkTheme.CREAM,false,2)
	var text := "✓ 已完成 · 可继续选择" if panel.interaction_done else str(panel.spec.interaction.get("hint","点击道具"))+" · 可略过"
	panel.draw_rect(Rect2(8,8,r.size.x-16,26),InkTheme.INK)
	panel.draw_string(InkTheme.font_body(),Vector2(14,27),text,HORIZONTAL_ALIGNMENT_LEFT,r.size.x-25,13,InkTheme.CREAM)
	if panel.interaction_holding: panel.draw_rect(Rect2(9,36,(r.size.x-18)*panel.interaction_amount,4),InkTheme.ACCENT)
