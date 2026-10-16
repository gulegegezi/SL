extends Control
## 像素小剧场：角色由整数网格绘制，道具复用 SL 中的 PixelSRPG-Forge 素材。
signal finished
const TITLES := {"study": "伏案学习", "work": "努力工作", "sport": "向前奔跑", "social": "相遇与陪伴", "sad": "雨中独行", "rest": "好好休息", "celebrate": "收获时刻", "walk": "继续前行"}
var mode := "walk"
var elapsed := 0.0
var playing := false
var caption: Label
var heading: Label
var changes: Label
var props: Dictionary = {}

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for key in ["coin", "heart", "spark", "muscle", "clover"]:
		props[key] = load("res://assets/vfx/%s.png" % key)
	heading = _label("人生剧场 / 等待你的选择", 13, Color("eac989"))
	heading.position = Vector2(16, 12)
	caption = _label("选择一个选项，看看接下来会发生什么。", 14, Color("fff0cf"))
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	changes = _label("", 12, Color("b6de8d"))
	resized.connect(_layout)
	_layout()

func _label(value: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	add_child(l)
	return l

func _layout() -> void:
	if caption == null:
		return
	caption.position = Vector2(16, size.y - 92)
	caption.size = Vector2(size.x - 32, 64)
	changes.position = Vector2(16, size.y - 26)
	changes.size.x = size.x - 32
	changes.clip_text = true

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
	mode = resolve(ev, choice, deltas)
	elapsed = 0.0
	playing = true
	heading.text = "人生剧场 / " + str(TITLES[mode])
	caption.text = str(choice.get("result", "你做出了选择，人生继续向前。"))
	var items: PackedStringArray = []
	for d in deltas:
		items.append("%s %+d" % [str(d.get("name", "")), int(d.get("delta", 0))])
	changes.text = " · ".join(items)
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	if playing and elapsed >= 3.2:
		playing = false
		heading.text = "人生剧场 / " + str(TITLES[mode]) + " · 已演出"
		finished.emit()
	queue_redraw()

func box(x: float, y: float, w: float, h: float, color: String) -> void:
	draw_rect(Rect2(roundf(x), roundf(y), w, h), Color(color))

func person(x: float, y: float, shirt: String, pose: String, phase: float) -> void:
	var bounce := 0.0
	if playing and pose in ["sport", "celebrate", "walk"]:
		bounce = -absf(sin(phase)) * 5.0
	y += bounce
	box(x - 14, y + 1, 30, 4, "26392e")
	box(x - 9, y - 54, 21, 18, "f0ba87")
	box(x - 12, y - 58, 24, 9, "493744")
	box(x - 12, y - 52, 6, 12, "493744")
	box(x + 6, y - 46, 3, 3, "302e3e")
	box(x - 9, y - 35, 21, 23, shirt)
	var swing := sin(phase) * 6.0 if playing else 0.0
	box(x - 9, y - 12, 8, 13 + swing, "354458")
	box(x + 4, y - 12, 8, 13 - swing, "354458")
	if pose in ["study", "work"]:
		box(x + 10, y - 29 + (sin(phase) * 2.0 if playing else 0.0), 19, 6, "f0ba87")
	elif pose == "celebrate":
		box(x - 18, y - 48, 6, 22, shirt)
		box(x + 13, y - 48, 6, 22, shirt)
	else:
		box(x - 15, y - 32 + swing, 6, 20, shirt)
		box(x + 12, y - 32 - swing, 6, 20, shirt)

func _draw() -> void:
	var w := size.x
	var ground := size.y - 110.0
	box(0, 0, w, size.y, "253c43")
	box(3, 3, w - 6, size.y - 6, "304e53")
	box(8, 40, w - 16, ground - 40, "628484" if mode != "sad" else "4e6076")
	for i in range(7):
		var x := float(i) * 83.0
		box(x, 70 + (i % 3) * 13, 56, ground - 70, "50716c")
		box(x + 10, 88 + (i % 3) * 13, 8, 12, "b9c79b")
	box(8, ground, w - 16, 12, "91a66b")
	box(8, ground + 12, w - 16, 8, "5c6349")
	box(8, ground + 20, w - 16, 2, "c5a56c")
	var phase := elapsed * 9.0 if playing else 0.0
	var x := w * 0.44
	if mode in ["walk", "sport", "sad"] and playing:
		x = lerpf(w * 0.25, w * 0.7, minf(elapsed / 3.2, 1.0))
	if mode == "rest":
		box(x - 43, ground - 22, 104, 22, "aa795d")
		box(x - 40, ground - 32, 24, 10, "eee2bf")
		box(x - 15, ground - 35, 68, 27, "819fa7")
		box(x - 35, ground - 42, 18, 14, "f0ba87")
	else:
		person(x, ground, "dba257", mode, phase)
	if mode in ["study", "work"]:
		box(x + 22, ground - 22, 66, 6, "bb8f68")
		box(x + 26, ground - 16, 6, 16, "795a51")
		box(x + 74, ground - 16, 6, 16, "795a51")
		box(x + 34, ground - 44, 36, 22, "ddd5a6" if mode == "study" else "344654")
		box(x + 38, ground - 40, 28, 13, "fff0c2" if mode == "study" else "96c8b9")
	if mode == "social":
		person(x + 80, ground, "b18ebc", mode, -phase)
	if mode == "sad":
		for i in range(28):
			var rx := fmod(float(i * 47), maxf(w - 24, 1.0)) + 12
			var ry := fmod(float(i * 23) + elapsed * 100.0, maxf(ground - 50, 1.0)) + 46
			box(rx, ry, 2, 8, "b8ccd5")
	var icon_key: String = {"study": "spark", "work": "coin", "sport": "muscle", "social": "heart", "celebrate": "clover"}.get(mode, "")
	if props.has(icon_key):
		var lift := sin(elapsed * 3.0) * 4.0
		draw_texture_rect(props[icon_key], Rect2(w * 0.7, 58 + lift, 32, 32), false)
