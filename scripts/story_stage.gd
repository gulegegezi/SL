extends Control
## 一个贯穿整局人生的俯视像素小镇。选择分为行走、行动、结果三个镜头。
signal finished
const Director := preload("res://scripts/story_director.gd")
const DURATION := 5.8
const TITLES := {"study": "读书与求学", "work": "工作与谋生", "sport": "锻炼身体", "social": "结识朋友", "sad": "独自消化心事", "rest": "回家休息", "celebrate": "庆祝收获", "walk": "继续前行", "farm": "照料菜园", "medical": "看病与治疗", "move": "安顿新家", "romance": "相遇与相爱", "music": "练习与表演", "game": "屏幕前的时光", "family": "陪伴家人", "explore": "出门走走", "refuse": "留在自己的生活里", "fish": "河边垂钓", "grasp": "抓周的选择"}
var mode := "walk"
var elapsed := 0.0
var playing := false
var heading: Label
var caption: Label
var changes: Label
var props: Dictionary = {}
var world: Dictionary = {}
var shot: Dictionary = {}
var age := 1
var money := 0
var start := Vector2(61, 85)
var actor := Vector2(61, 85)
var target := Vector2(61, 85)
var committed := false
var result_changes := ""
var map_origin := Vector2.ZERO
var map_scale := 1.0
var clock := 0.0

func _ready() -> void:
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for key in ["coin", "heart", "spark", "muscle", "clover"]:
		props[key] = load("res://assets/vfx/%s.png" % key)
	heading = _label("生活小镇", 13, Color("f5d895"))
	heading.position = Vector2(14, 10)
	caption = _label("每一个选择，都会留在你的生活里。", 13, Color("fff0cf"))
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	changes = _label("", 11, Color("b6de8d"))
	resized.connect(_layout)
	if world.is_empty(): world = Director.make_world()
	_layout()

func configure(state) -> void:
	if state.story_world.is_empty(): state.story_world = Director.make_world()
	world = state.story_world
	age = state.age
	money = state.money
	actor = world.position
	if not playing:
		heading.text = "%d 岁 · %s · 第 %d 段人生" % [age, season_name(), world.memories.size() + 1]
	queue_redraw()

func _label(value: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	add_child(l)
	return l

func _layout() -> void:
	if caption == null: return
	map_scale = minf((size.x - 16) / 320.0, (size.y - 157) / 192.0)
	map_origin = Vector2((size.x - 320 * map_scale) / 2, 37)
	caption.position = Vector2(14, 43 + 192 * map_scale)
	caption.size = Vector2(size.x - 28, 88)
	changes.position = Vector2(14, size.y - 25)
	changes.size = Vector2(size.x - 28, 20)
	changes.clip_text = true

func season_name() -> String:
	return ["春日", "盛夏", "金秋", "初雪"][int(age / 8.0) % 4]

static func resolve(ev: Dictionary, choice: Dictionary, deltas: Array) -> String:
	var explicit: String = str(choice.get("story", ""))
	if TITLES.has(explicit):
		return explicit
	# 先匹配选项与结果，避免同一事件的相反选项播放相同剧情。
	var text: String = str(choice.get("text", choice.get("label", ""))) + str(choice.get("result", ""))
	var rules := [
		["rest", ["休息", "睡", "躺", "养病", "医院"]],
		["sad", ["失去", "失败", "分手", "哭", "孤独", "受伤", "病倒", "去世"]],
		["study", ["学习", "读书", "考试", "作业", "学校", "大学", "补习"]],
		["work", ["工作", "打工", "加班", "赚钱", "创业", "公司", "上班", "编程"]],
		["sport", ["运动", "跑", "锻炼", "健身", "球"]],
		["social", ["朋友", "恋", "结婚", "陪", "交流", "约会", "家人"]],
		["celebrate", ["中奖", "成功", "奖励", "庆祝", "发财"]],
	]
	for rule in rules:
		for word in rule[1]:
			if text.contains(word):
				return rule[0]
	for d in deltas:
		if int(d.get("delta", 0)) > 0:
			match str(d.get("key", "")):
				"int": return "study"
				"money": return "work"
				"health": return "sport"
				"charm": return "social"
	return "walk"


func play(ev: Dictionary, choice: Dictionary, deltas: Array) -> void:
	shot = Director.plan(ev, choice, resolve(ev, choice, deltas))
	mode = shot.action
	if age < 6 and mode == "study":
		shot.place = "home"
		shot.target = Director.PLACES.home
	start = actor
	target = shot.target
	elapsed = 0.0
	playing = true
	committed = false
	caption.text = "你的选择：" + str(shot.label)
	changes.text = ""
	var items: PackedStringArray = []
	for d in deltas:
		items.append("%s %+d" % [str(d.get("name", "")), int(d.get("delta", 0))])
	result_changes = " · ".join(items)
	queue_redraw()

func _process(delta: float) -> void:
	clock += delta
	if playing:
		elapsed += delta
		if elapsed < 1.8:
			heading.text = "%d 岁 / 前往%s" % [age, Director.NAMES[shot.place]]
			var progress := clampf(elapsed / 1.8, 0, 1)
			var p1 := Vector2(start.x, 105)
			var p2 := Vector2(target.x, 105)
			if progress < 0.25: actor = start.lerp(p1, progress * 4)
			elif progress < 0.75: actor = p1.lerp(p2, (progress - 0.25) * 2)
			else: actor = p2.lerp(target, (progress - 0.75) * 4)
		elif elapsed < 4.1:
			actor = target
			heading.text = "%d 岁 / %s" % [age, TITLES.get(mode, "生活片段")]
			caption.text = str(shot.event) + "\n正在做：" + str(shot.label)
		else:
			actor = target
			if not committed:
				Director.remember(world, shot, age, money)
				committed = true
			heading.text = "%d 岁 / %s · %s" % [age, season_name(), Director.NAMES[shot.place]]
			caption.text = str(shot.result)
			changes.text = result_changes
		if elapsed >= DURATION:
			playing = false
			finished.emit()
	queue_redraw()

func box(x: float, y: float, w: float, h: float, color: String) -> void:
	draw_rect(Rect2(roundf(x), roundf(y), w, h), Color(color))

func tree_at(x: float, y: float, autumn: bool, snow: bool) -> void:
	box(x - 9, y - 1, 22, 6, "54804c")
	box(x - 2, y - 14, 5, 17, "886443")
	var dark := "b06441" if autumn else "346d4b"
	var light := "dba34d" if autumn else "6c9b50"
	if snow: light = "dee7dc"
	box(x - 12, y - 26, 25, 14, dark)
	box(x - 8, y - 34, 17, 24, dark)
	box(x - 10, y - 28, 19, 11, light)
	box(x - 6, y - 33, 12, 8, light)
	box(x - 7, y - 24, 4, 4, "f1cf70" if autumn else "8bb465")

func building(x: float, y: float, kind: String, level: int) -> void:
	box(x + 5, y + 5, 62, 12, "5d784b")
	box(x, y - 29, 60, 37, "d5b788")
	box(x + 3, y - 27, 54, 34, "edce9a")
	for i in range(3): box(x + 2, y - 22 + i * 9, 56, 1, "d7b281")
	var roof := "9c5a47"
	if kind == "school": roof = "597d83"
	if kind == "office": roof = "74668a"
	if level >= 2: roof = "5a7191"
	for i in range(6):
		box(x - 5 + i * 4, y - 29 - i * 4, 70 - i * 8, 4, roof)
		box(x - 5 + i * 4, y - 29 - i * 4, 70 - i * 8, 1, "e2a76c" if kind == "home" else "8fa5a0")
	box(x + 22, y - 14, 15, 22, "765a48")
	box(x + 25, y - 12, 9, 20, "9a7550")
	box(x + 31, y - 3, 2, 2, "edd28a")
	for wx in [7, 43]:
		box(x + wx - 1, y - 21, 12, 14, "7b6851")
		box(x + wx, y - 20, 10, 12, "99c5c2")
		box(x + wx + 4, y - 20, 2, 12, "e9d0a0")
		box(x + wx, y - 15, 10, 2, "e9d0a0")
	if kind == "school":
		box(x + 23, y - 36, 14, 8, "ecdcb0")
		box(x + 29, y - 35, 1, 5, "5b7774")
		box(x + 29, y - 31, 4, 1, "5b7774")
	if level > 0:
		box(x - 11, y - 13, 11, 22, "c8b487")
		box(x - 14, y - 16, 17, 4, roof)
		box(x + 53, y - 55, 7, 17, "b39888")
		var smoke_y := fmod(clock * 5, 14)
		box(x + 53 + sin(clock) * 2, y - 60 - smoke_y, 5, 5, "dce3ca")
	# 花盆随住宅升级出现。
	if kind == "home" and level > 0:
		for fx in [3, 48]:
			box(x + fx, y + 3, 8, 5, "ac7659")
			box(x + fx + 3, y - 3, 2, 7, "679050")
			box(x + fx + 1, y - 5, 6, 4, "e8a39b")

func person(pos: Vector2, shirt: String, npc: bool = false) -> void:
	var x := pos.x
	var y := pos.y
	var is_moving := playing and elapsed < 1.8
	var phase := clock * 10
	var swing := sin(phase) * 2 if is_moving else 0.0
	var small := age < 13 and not npc
	var old := age >= 60 and not npc
	var height := 16 if small else 22
	box(x - 6, y, 13, 3, "58724c")
	box(x - 4, y - 5, 3, 6 + swing, "454b63")
	box(x + 2, y - 5, 3, 6 - swing, "454b63")
	box(x - 5, y - height + 8, 11, height - 12, shirt)
	box(x - 4, y - height, 9, 8, "edbd8d")
	var hair := "c8c4b6" if old else "53424b"
	box(x - 5, y - height - 2, 11, 4, hair)
	box(x - 5, y - height + 1, 2, 4, hair)
	box(x + 2, y - height + 4, 1, 2, "3d3d4c")
	if playing and elapsed >= 1.8 and elapsed < 4.1 and not npc:
		var hand := sin(phase) * 2
		box(x + 5, y - height + 9 + hand, 5, 3, "edbd8d")
	else:
		box(x - 7, y - height + 9 + swing, 3, 7, "edbd8d")
		box(x + 6, y - height + 9 - swing, 3, 7, "edbd8d")
	if old:
		box(x + 9, y - 9, 2, 12, "826843")

func furniture() -> void:
	var x := target.x
	var y := target.y
	match mode:
		"study", "work":
			box(x + 9, y - 9, 23, 3, "956e4c")
			box(x + 11, y - 6, 2, 8, "785f46")
			box(x + 28, y - 6, 2, 8, "785f46")
			box(x + 12, y - 18, 16, 9, "eee3b8" if mode == "study" else "3d5567")
			box(x + 14, y - 16, 12, 5, "b6cdc0")
		"game":
			box(x + 7, y - 16, 15, 11, "38485e")
			box(x + 9, y - 14, 11, 7, "8eb898")
		"farm":
			box(x + 6, y - 7, 4, 7, "8ea8ac")
			box(x + 9, y - 8, 5, 2, "a3c1bd")
			for i in range(4): box(x + 13 + i * 2, y - 4 + i * 2, 1, 3, "bce0db")
		"grasp":
			box(x + 6, y - 7, 31, 4, "a88053")
			box(x + 8, y - 3, 3, 8, "8f6c4b")
			box(x + 32, y - 3, 3, 8, "8f6c4b")
			var lift := -absf(sin(clock * 5)) * 5
			if shot.prop == "coin": icon("coin", Vector2(x + 12, y - 18 + lift), 12)
			elif shot.prop == "phone":
				box(x + 14, y - 20 + lift, 7, 12, "414d60")
				box(x + 15, y - 18 + lift, 5, 7, "8fbcb4")
			else:
				box(x + 15, y - 20 + lift, 2, 13, "e1bd6c")
				box(x + 15, y - 7 + lift, 2, 2, "484a4f")
		"fish":
			draw_line(Vector2(x + 6, y - 12), Vector2(x + 25, y - 35), Color("b89965"), 2)
			draw_line(Vector2(x + 25, y - 35), Vector2(x + 32, y + 6), Color("e5d7ac"), 1)
			box(x + 30, y + 4, 4, 3, "d3a06b")
		"medical":
			box(x + 10, y - 16, 16, 13, "eee8d6")
			box(x + 16, y - 14, 3, 9, "cf7974")
			box(x + 13, y - 11, 9, 3, "cf7974")
		"music":
			box(x + 10, y - 22, 2, 10, "f6df9a")
			box(x + 12, y - 22, 7, 2, "f6df9a")
			box(x + 7, y - 14, 5, 3, "f6df9a")
		"rest":
			box(x - 8, y + 2, 26, 4, "ac7f5d")
			box(x - 6, y - 6, 23, 8, "a6bbc1")
		"refuse":
			box(x - 5, y - 32, 16, 10, "eee2be")
			for i in range(3): box(x - 2 + i * 4, y - 27, 2, 2, "85775c")
		"social", "family", "romance":
			person(target + Vector2(21, 1), "b48ca1", true)
			if mode == "romance": icon("heart", target + Vector2(5, -39), 13)
		"sport":
			box(x + 11, y - 4, 7, 7, "e5c58c")
			box(x + 14, y - 4, 2, 7, "987754")
		"move":
			box(x + 9, y - 7, 12, 10, "c29c65")
			box(x + 14, y - 7, 2, 10, "e7c38c")

func icon(key: String, pos: Vector2, sz: float) -> void:
	if props.has(key): draw_texture_rect(props[key], Rect2(pos.round(), Vector2(sz, sz)), false)

func _draw() -> void:
	box(0, 0, size.x, size.y, "293f42")
	box(1, 1, size.x - 2, size.y - 2, "314c4c")
	if world.is_empty(): return
	draw_set_transform(map_origin, 0, Vector2.ONE * map_scale)
	var season := int(age / 8.0) % 4
	var snow := season == 3
	var autumn := season == 2
	var grass: String = ["7ca459", "6b9a50", "a5a05b", "c9d6c7"][season]
	var grass2: String = ["85ad61", "73a456", "afa964", "d5dfce"][season]
	box(0, 0, 320, 192, grass)
	for row in range(12):
		for col in range(20):
			if (row * 7 + col * 11) % 5 == 0: box(col * 16, row * 16, 16, 16, grass2)
			if (row * 17 + col * 7) % 9 == 0:
				box(col * 16 + 5, row * 16 + 7, 2, 2, "e6ce91" if autumn else "adc47b")
	# 土路连接全部地点，建筑和树木带侧面与投影。
	box(0, 99, 320, 15, "b69d70")
	box(0, 101, 320, 10, "d2bb8b")
	for path_x in [61, 158, 260]:
		box(path_x - 5, 65, 11, 113, "c8b082")
		box(path_x - 3, 66, 7, 111, "d7c294")
	for i in range(34): box((i * 41) % 320, 103 + i % 7, 2, 1, "b39b71")
	# 河岸与闪烁的水面。
	box(225, 133, 88, 54, "bdba7c")
	box(231, 138, 82, 43, "629ea5")
	box(237, 143, 76, 34, "76b0b5")
	for i in range(10):
		var ripple := sin(clock * 2 + i) * 2
		box(240 + (i * 17) % 64 + ripple, 146 + (i * 9) % 27, 8, 1, "add2c6")
	# 南侧菜园从荒地到作物，是选择留下的永久变化。
	box(23, 133, 70, 46, "8d704e")
	for r in range(3):
		for c in range(5):
			var px := 28 + c * 13
			var py := 140 + r * 12
			box(px, py, 9, 5, "785b43")
			if int(world.crops) > 0:
				box(px + 4, py - 3 - int(world.crops), 2, 7 + int(world.crops), "648549")
				box(px + 1, py - 2, 7, 2, "90b25c")
				if int(world.crops) >= 2: box(px + 3, py - 5, 4, 4, "e0ad64")
	# 小镇地标按人生阶段生长，地图坐标持续不变。
	building(31, 74, "home", int(world.home_level))
	if age >= 6 or int(world.visits.get("school", 0)) > 0 or (playing and shot.place == "school"):
		building(128, 65, "school", 0)
	else:
		tree_at(148, 63, autumn, snow)
		tree_at(173, 79, autumn, snow)
	if age >= 18 or int(world.career) > 0 or (playing and shot.place == "office"):
		building(230, 71, "office", 1 if int(world.career) >= 2 else 0)
	else:
		tree_at(244, 70, autumn, snow)
		tree_at(275, 77, autumn, snow)
	# 广场的长椅、灯、花圃。
	box(126, 143, 59, 29, "c8b68c")
	box(137, 149, 31, 4, "9b7752")
	box(137, 155, 31, 3, "af8658")
	box(141, 158, 2, 7, "705e49")
	box(162, 158, 2, 7, "705e49")
	box(186, 126, 3, 37, "69644e")
	box(182, 122, 11, 9, "eedba0")
	for i in range(4):
		box(112 + i * 7, 166, 4, 6, "668749")
		box(111 + i * 7, 164, 5, 3, "dca29c")
	for i in range(15):
		box(i * 22, 185, 3, 7, "a18759")
		box(i * 22, 187, 22, 2, "c6ad7b")
	for p in [Vector2(12, 50), Vector2(103, 64), Vector2(206, 58), Vector2(309, 68), Vector2(13, 170), Vector2(211, 173)]:
		tree_at(p.x, p.y, autumn, snow)
	var font := ThemeDB.fallback_font
	for place in ["home", "school", "office", "garden", "pond"]:
		if place == "school" and age < 6 and int(world.visits.get("school", 0)) == 0: continue
		if place == "office" and age < 18 and int(world.career) == 0: continue
		var lp: Vector2 = Director.PLACES[place]
		draw_string(font, lp + Vector2(-13, 14), Director.NAMES[place], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("3c5143"))
	# 邻居总在；朋友、伴侣、孩子由经历留下。
	person(Vector2(191 + sin(clock * 0.3) * 7, 117), "87a2b2", true)
	for i in range(int(world.friends)):
		person(Vector2(132 + i * 16, 130 + i % 2 * 8), "b3929b", true)
	if bool(world.partner): person(Vector2(79, 86), "c198aa", true)
	if bool(world.child):
		box(45, 91, 6, 9, "d9ae67")
		box(45, 85, 6, 6, "e6bc90")
	# 运动与探索在到达后继续移动，其他动作在目的地操作道具。
	var shown_actor := actor
	if playing and elapsed >= 1.8 and elapsed < 4.1 and mode in ["sport", "explore", "walk"]:
		shown_actor += Vector2(sin((elapsed - 1.8) * 3) * 14, cos((elapsed - 1.8) * 3) * 3)
	var acting := playing and elapsed >= 1.8 and elapsed < 4.1
	if acting and mode == "music": shown_actor.y -= absf(sin(clock * 8)) * 3
	if not (acting and mode == "rest"):
		person(shown_actor, "c49b58" if age < 18 else ("7f9eb0" if age < 60 else "b3a292"))
	else:
		box(target.x - 8, target.y - 9, 8, 7, "edbd8d")
	if acting and mode == "medical": person(target + Vector2(28, 0), "ede7cf", true)
	if playing and elapsed >= 1.8 and elapsed < 4.1: furniture()
	if playing and elapsed >= 4.1:
		var icon_key: String = {"study": "spark", "work": "coin", "social": "heart", "romance": "heart", "sport": "muscle", "farm": "clover", "celebrate": "clover"}.get(mode, "")
		icon(icon_key, actor + Vector2(-7, -38 - sin(clock * 4) * 2), 14)
	if playing and mode == "sad":
		for i in range(38):
			box((i * 47) % 320, fmod(i * 23 + clock * 80, 185), 1, 4, "b3cecf")
	if snow:
		for i in range(24): box(fmod(i * 31 + clock * 3, 320), fmod(i * 29 + clock * 8, 190), 2, 2, "edf0dc")
	draw_set_transform(Vector2.ZERO)
