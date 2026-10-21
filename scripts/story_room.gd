extends RefCounted
const PixelCast := preload("res://scripts/pixel_cast.gd")
const BACKGROUNDS := {"nursery": "home", "living": "home", "bedroom": "bedroom", "classroom": "classroom", "office": "office", "hospital": "hospital", "park": "park"}
## 独立场景布景；共享像素绘制与人物系统，使用原创色板和道具。
const NAMES := {"nursery": "抓周 · 家中的午后", "classroom": "教室 · 窗边的课桌", "office": "办公室 · 灯下的工位", "hospital": "医院 · 走廊尽头", "agency": "售楼处 · 一张合同", "chapel": "婚礼 · 两个人的仪式", "park": "公园 · 长椅旁", "living": "客厅 · 熟悉的灯光", "bedroom": "卧室 · 属于自己的时间", "stage": "小剧场 · 聚光灯下", "river": "河岸 · 水面的回声", "garden": "菜园 · 泥土与新芽", "playground": "操场 · 向前一步", "station": "车站 · 下一站"}

static func draw(s) -> void:
	s.box(0, 0, s.size.x, s.size.y, "080910")
	s.draw_set_transform(s.map_origin, 0, Vector2.ONE * s.map_scale)
	var room: String = s.shot.room
	var outside := room in ["park", "river", "garden", "playground", "station"]
	s.box(0, 0, 320, 192, "10121e")
	if BACKGROUNDS.has(room):
		s.draw_texture_rect(PixelCast.room(BACKGROUNDS[room]), Rect2(0, 0, 320, 192), false)
		# Persistent furnishings remain visible after life choices.
		if room in ["nursery", "living", "bedroom"] and int(s.world.home_level) > 0:
			s.icon("spark", Vector2(278, 105), 12)
		if room in ["nursery", "living", "bedroom"] and bool(s.world.child):
			PixelCast.draw_actor(s, "child", false, Vector2(252, 157), 27, s.clock)
	elif outside: exterior(s, room)
	else: interior(s, room)
	# 同一场景内连续走位，再操作目标道具，最后停留呈现结果。
	var arrival := Vector2(142, 143)
	if room in ["park", "chapel"]: arrival = Vector2(143, 140)
	if room == "river": arrival = Vector2(161, 144)
	if room == "garden": arrival = Vector2(129, 142)
	var p: Vector2 = Vector2(53, 172).lerp(arrival, smoothstep(0.0, 1.0, s.beat_progress)) if s.beat_index == 0 else arrival
	if s.beat_index == 2 and s.mode == "refuse": p = arrival.lerp(Vector2(74, 162), s.beat_progress)
	if s.beat_index == 1 and s.mode in ["sport", "explore", "walk"]: p.x += sin(s.beat_progress * TAU) * 26
	if s.beat_index == 1 and s.mode == "music": p.y -= absf(sin(s.clock * 6)) * 4
	if room in ["nursery", "classroom", "office", "hospital", "agency", "chapel", "park", "living"]:
		var npc := Vector2(211, 135)
		if room == "nursery": npc = Vector2(211, 143)
		avatar(s, npc, "b095ae", true)
		if room == "hospital": avatar(s, Vector2(235, 134), "d9ddd8", true)
	if s.mode == "rest" and s.beat_index > 0:
		var bed: Vector2 = s.map_origin + Vector2(177, 66) * s.map_scale
		s.draw_set_transform(bed, -PI * 0.5, Vector2.ONE * s.map_scale)
		PixelCast.draw_actor(s, PixelCast.stage_for_age(s.age), false, Vector2.ZERO, 44, s.clock)
		s.draw_set_transform(s.map_origin, 0, Vector2.ONE * s.map_scale)
	else:
		avatar(s, p, "cbad6b" if s.age < 18 else "7f9eb0", false)
	if s.beat_index >= 1: interaction(s, room, p)
	if room == "nursery": nursery_table(s, p)
	if s.beat_index == 2 and s.mode == "romance":
		s.icon("heart", Vector2(176, 94 - sin(s.clock * 3) * 2), 13)
	if s.beat_index == 2 and s.mode == "work": s.icon("coin", p + Vector2(5, -44), 14)
	# 入场短淡入；不切断中间动作与结果镜头。
	if s.beat_index == 0 and s.beat_time < 0.25:
		s.draw_rect(Rect2(0, 0, 320, 192), Color(0, 0, 0, 1 - s.beat_time / 0.25))
	s.draw_set_transform(Vector2.ZERO)
	var dialogue_y: float = s.caption.position.y - 10
	s.box(8, dialogue_y, s.size.x - 16, s.size.y - dialogue_y - 34, "e5e4dc")
	s.box(10, dialogue_y + 2, s.size.x - 20, s.size.y - dialogue_y - 38, "07080d")
	# 独立肖像槽，头像也随人物年龄变化。
	s.box(19, dialogue_y + 15, 27, 32, "2e3344")
	var portrait := PixelCast.portrait(PixelCast.stage_for_age(s.age), false, s.beat_index == 1)
	if portrait != null:
		s.draw_texture_rect(portrait, Rect2(20, dialogue_y + 16, 25, 30), false)

static func avatar(s, pos: Vector2, shirt: String, npc: bool) -> void:
	var role: String = PixelCast.stage_for_age(s.age)
	if npc:
		role = {"nursery": "parent", "classroom": "teacher", "office": "boss", "hospital": "parent", "agency": "boss", "chapel": "partner", "park": "friend", "living": "parent"}.get(s.shot.room, "friend")
	var walking: bool = not npc and (s.beat_index == 0 or (s.beat_index == 1 and s.mode in ["sport", "explore", "walk"]) or (s.beat_index == 2 and s.mode == "refuse"))
	var speaking: bool = not walking and s.beat_index == 1
	var height := 25.0 if role == "infant" else 44.0
	PixelCast.draw_actor(s, role, npc, pos, height, s.clock, walking, speaking)

static func interior(s, room: String) -> void:
	var wall := "2d2940"
	var floor := "474054"
	if room in ["nursery", "living", "bedroom"]: wall = "3f3449"; floor = "665064"
	if room in ["hospital", "classroom"]: wall = "293b48"; floor = "4c5b66"
	s.box(17, 10, 286, 174, "080b14")
	s.box(24, 16, 272, 48, wall)
	s.box(24, 65, 272, 111, floor)
	s.box(24, 61, 272, 5, "a4a2b2")
	s.box(24, 66, 272, 2, "171c2a")
	for row in range(9):
		for col in range(15):
			s.box(25 + col * 18, 69 + row * 12, 17, 11, floor)
			s.box(25 + col * 18, 79.5 + row * 12, 17, 0.5, "353344")
			if room in ["nursery", "living", "bedroom"]:
				s.box(28 + col * 18 + row % 2 * 3, 73 + row * 12, 8, 0.5, "7a6070")
	# 门口、窗、窗帘与墙上相框。
	s.box(43, 170, 28, 8, "aaa0ad")
	s.box(48, 172, 18, 3, "ded4d0")
	s.box(49, 24, 39, 30, "141b30")
	s.box(52, 27, 33, 24, "637b9c")
	s.box(54, 29, 13, 9, "9eb4c2")
	s.box(68, 27, 1, 24, "ded2c1")
	s.box(52, 39, 33, 1, "ded2c1")
	s.box(46, 22, 6, 33, "71618a")
	s.box(85, 22, 6, 33, "71618a")
	for i in range(3): s.box(47 + i * 1.5, 24, 0.5, 29, "a491aa")
	s.box(244, 28, 20, 23, "a48d79")
	s.box(247, 31, 14, 17, "615677")
	s.box(250, 37, 4, 6, "d1b89f")
	if bool(s.world.partner): s.box(255, 37, 4, 6, "b5a1b8")
	if bool(s.world.child): s.box(253, 43, 3, 3, "e3bc76")
	if room in ["living", "nursery", "bedroom"] and int(s.world.home_level) > 0:
		s.box(266, 142, 13, 10, "9a7680")
		s.box(271, 120, 2, 23, "8c9e8c")
		for i in range(4): s.box(264 + i % 2 * 7, 122 + i * 4, 8, 2, "a6b39c")
	if room == "nursery":
		for i in range(4):
			s.box(85 + i * 7, 146 - i % 2 * 5, 6, 6, ["a692ad", "a4b4b3", "c3ae86", "918fa9"][i])
			s.box(86 + i * 7, 146 - i % 2 * 5, 4, 1, "d1c8bc")
	match room:
		"classroom":
			s.box(108, 22, 104, 33, "b4ab9c")
			s.box(111, 25, 98, 27, "213b3c")
			for i in range(5): s.box(119, 31 + i * 3, 35 + (i % 2) * 20, 0.5, "a7bbb2")
			for x in [102, 162, 222]: desk(s, Vector2(x, 145), "book")
		"office":
			for x in [104, 164, 224]: desk(s, Vector2(x, 141), "screen")
			s.box(123, 26, 80, 17, "101a27")
			s.box(129, 30, 68, 1, "9bb8bd")
		"hospital":
			s.box(162, 80, 57, 43, "b2bab9")
			s.box(165, 82, 51, 8, "e0ddd1")
			s.box(165, 92, 51, 27, "7e9eae")
			s.box(130, 28, 12, 28, "e4ddd0")
			s.box(122, 36, 28, 12, "e4ddd0")
			s.box(234, 78, 20, 19, "202d3e")
			s.box(237, 82, 14, 11, "7caeaa")
			s.box(241, 97, 2, 21, "acb0b3")
		"agency":
			desk(s, Vector2(164, 142), "contract")
			for x in [115, 164, 213]:
				s.box(x, 25, 35, 27, "b1a39a")
				s.box(x + 3, 28, 29, 21, "696881")
				s.box(x + 10, 36, 14, 11, "d1bf9e")
		"chapel":
			s.box(145, 66, 35, 108, "875b6f")
			for y in [88, 119, 150]:
				for x in [57, 232]:
					s.box(x, y, 28, 8, "8b7280")
					s.box(x, y, 28, 1, "c9abb1")
			for x in [135, 185]:
				s.box(x, 73, 5, 16, "d2c5b0")
				s.box(x, 68, 5, 5, "f4df9c")
		"stage":
			s.box(54, 64, 212, 85, "67566e")
			s.box(54, 149, 212, 7, "aa8a9c")
			for x in [35, 258]:
				s.box(x, 16, 28, 132, "633647")
				for i in range(5): s.box(x + i * 5, 17, 2, 131, "8e4c60")
		"bedroom":
			s.box(129, 83, 62, 53, "957f83")
			s.box(132, 86, 56, 12, "e0d8cb")
			s.box(132, 100, 56, 31, "7b7f9c")
			desk(s, Vector2(224, 134), "screen")
		_:
			s.box(119, 115, 92, 40, "8c7084")
			s.box(123, 119, 84, 32, "75657e")
			if room != "nursery": desk(s, Vector2(162, 143), "book")
	# 书架的藏书随求学经历增多。
	if room != "chapel" and room != "stage":
		s.box(29, 79, 27, 48, "2b2836")
		for row in range(3):
			s.box(30, 88 + row * 13, 25, 2, "a48a7b")
			for i in range(5): s.box(32 + i * 4, 81 + row * 13, 3, 7, ["ae9a91", "798b9d", "aaa57b", "9384a1", "6c9493"][i])

static func desk(s, p: Vector2, prop: String) -> void:
	s.box(p.x - 3, p.y + 2, 43, 5, "292630")
	s.box(p.x, p.y - 20, 37, 21, "775a57")
	s.box(p.x, p.y - 20, 37, 2, "bd9d8b")
	s.box(p.x + 3, p.y, 3, 12, "50424c")
	s.box(p.x + 31, p.y, 3, 12, "50424c")
	if prop == "screen":
		s.box(p.x + 10, p.y - 36, 23, 17, "202535")
		s.box(p.x + 12, p.y - 34, 19, 12, "698e9c")
		for i in range(3): s.box(p.x + 14, p.y - 31 + i * 3, 10 - i * 2, 0.5, "c2d3c9")
	else:
		s.box(p.x + 7, p.y - 24, 23, 6, "ded6bd")
		for i in range(3): s.box(p.x + 10, p.y - 23 + i * 1.5, 15, 0.5, "93929c")

static func nursery_table(s, p: Vector2) -> void:
	desk(s, Vector2(161, 145), "book")
	for i in range(3):
		var selected: bool = ["pen", "coin", "phone"][i] == s.shot.prop
		var x: float = 165 + i * 10
		var y := 119.0
		if selected and s.beat_index >= 1:
			var lift: float = minf(s.beat_progress * 2, 1) if s.beat_index == 1 else 1.0
			x = lerpf(x, p.x + 9, lift)
			y = lerpf(y, p.y - 22, lift)
		if i == 0:
			s.box(x, y - 7, 1.5, 9, "e4d39a")
			s.box(x, y + 2, 1.5, 1, "5c535f")
		elif i == 1: s.icon("coin", Vector2(x - 1, y - 5), 8)
		else:
			s.box(x - 1, y - 8, 5, 9, "292a3d")
			s.box(x, y - 6, 3, 5, "9ab6bd")

static func interaction(s, room: String, p: Vector2) -> void:
	if s.mode == "fish":
		s.draw_line(p + Vector2(9, -20), p + Vector2(31, -45), Color("c2b49b"), 1.5)
		s.draw_line(p + Vector2(31, -45), Vector2(233, 148), Color("d2cad0"), 0.5)
		s.box(231, 148 + sin(s.clock * 4), 3, 2, "e3bdab")
	if s.mode == "farm":
		s.box(p.x + 9, p.y - 14, 7, 10, "8ba6b2")
		for i in range(5): s.box(p.x + 17 + i * 2, p.y - 10 + i * 2, 0.5, 2, "c5e0dd")
	if s.mode == "medical":
		s.box(p.x + 8, p.y - 15, 8, 10, "d3d3d0")
		s.box(p.x + 11, p.y - 12, 2, 5, "a6768c")
	if s.mode == "music":
		for i in range(3):
			var x: float = p.x + 12 + i * 9
			var y: float = p.y - 37 - sin(s.clock * 3 + i) * 3
			s.box(x, y, 1, 8, "d7c8df")
			s.box(x - 2, y + 6, 3, 2, "d7c8df")
	if room == "agency" and s.beat_index == 2 and s.mode == "move":
		s.box(p.x + 10, p.y - 20, 4, 3, "e3d19c")
		s.box(p.x + 12, p.y - 18, 1, 7, "e3d19c")
	if room == "agency" and s.beat_index == 1 and s.mode == "move":
		# 签名逐渐落在合同上，随后结果镜头拿到钥匙。
		s.box(179, 119, 8 * s.beat_progress, 0.5, "5e596d")
		s.box(183, 120.5, 6 * s.beat_progress, 0.5, "5e596d")

static func exterior(s, room: String) -> void:
	s.box(12, 14, 296, 165, "262b3e")
	s.box(12, 100, 296, 79, "3a424c")
	for i in range(110): s.box(17 + (i * 43) % 285, 104 + (i * 29) % 71, 1, 0.5, "61626c")
	for i in range(20): s.box(20 + i * 15, 83 + i % 3 * 2, 2, 17, "202535")
	if room == "river":
		s.box(199, 94, 109, 85, "3b546e")
		for i in range(28): s.box(203 + (i * 19) % 99, 100 + (i * 11) % 74, 4, 0.5, "8a9db1")
		s.box(191, 94, 7, 85, "7a7384")
	elif room == "garden":
		for r in range(3):
			for c in range(6):
				s.box(100 + c * 22, 104 + r * 23, 17, 13, "6d5260")
				s.box(104 + c * 22, 107 + r * 23, 9, 0.5, "b18e95")
				if int(s.world.crops) > 0:
					s.box(107 + c * 22, 99 + r * 23, 2, 10, "8da488")
					s.box(104 + c * 22, 101 + r * 23, 8, 2, "a9b999")
	elif room == "playground":
		for i in range(4): s.draw_rect(Rect2(60 + i * 11, 105 + i * 7, 212 - i * 22, 62 - i * 14), Color("9b93a1"), false, 0.5)
	elif room == "station":
		s.box(30, 27, 260, 67, "50546c")
		for i in range(6):
			s.box(45 + i * 39, 39, 26, 28, "222a3e")
			s.box(47 + i * 39, 41, 22, 11, "8c9db0")
		s.box(30, 83, 260, 4, "b5a4aa")
	else:
		s.box(155, 128, 77, 8, "9b8191")
		s.box(155, 138, 77, 5, "bba2a5")
		s.box(160, 144, 3, 16, "676173")
		s.box(223, 144, 3, 16, "676173")
	for p in [Vector2(35, 80), Vector2(277, 83)]:
		s.tree_at(p.x, p.y, false, int(s.age / 8.0) % 4 == 3)
	# 黄昏灯光与远处窗户，保留安静的空白。
	s.box(69, 53, 3, 69, "8b8597")
	s.box(63, 44, 15, 12, "d7d0bf")
	s.box(65, 46, 11, 8, "f1e5b5")

