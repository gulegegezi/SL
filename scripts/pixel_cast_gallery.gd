extends Control
## F6 on PixelCastGallery.tscn: inspect original assets and play a branching room sample.
const Cast := preload("res://scripts/pixel_cast.gd")
const StoryStage := preload("res://scripts/story_stage.gd")
const State := preload("res://scripts/game_state.gd")
var page := 0
var clock := 0.0
var sample: Control
var sample_controls: HBoxContainer
var font: Font
var sample_state

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	font = ThemeDB.fallback_font
	var title := Label.new()
	title.text = "人生 · 像素素材与演出预览"
	title.position = Vector2(20, 16)
	title.add_theme_font_size_override("font_size", 24)
	add_child(title)
	var tabs := HBoxContainer.new()
	tabs.position = Vector2(20, 58)
	add_child(tabs)
	var names := ["主角人生段", "NPC", "环境", "剧情演出"]
	for i in range(names.size()):
		var button := Button.new()
		button.text = names[i]
		button.pressed.connect(func(): show_page(i))
		tabs.add_child(button)
	sample = StoryStage.new()
	sample.position = Vector2(12, 132)
	sample.size = Vector2(496, 530)
	add_child(sample)
	sample_state = State.new()
	sample_state.age = 26
	sample.configure(sample_state)
	sample_controls = HBoxContainer.new()
	sample_controls.position = Vector2(16, 690)
	add_child(sample_controls)
	for i in range(3):
		var button := Button.new()
		button.text = ["陪妈妈聊聊", "回房休息", "下一句 / 动作"][i]
		if i == 2: button.pressed.connect(func(): sample.advance_dialogue())
		else: button.pressed.connect(func(): play_sample(i))
		sample_controls.add_child(button)
	show_page(0)

func show_page(index: int) -> void:
	page = index
	sample.visible = page == 3
	sample_controls.visible = page == 3
	if page == 3: play_sample(0)
	queue_redraw()

func play_sample(option: int) -> void:
	var event := {"id": "ART_DEMO", "title": "晚饭以后", "text": "妈妈站在灯旁，问起你最近的生活。"}
	var choice := {"label": "陪妈妈聊聊", "result": "你停下脚步，谈起工作的烦恼。妈妈听得很认真，家里的灯还亮着。", "story": "family"} if option == 0 else {"label": "回房休息", "result": "你道了晚安，回到自己的床上。走廊里传来妈妈放轻的脚步声。", "story": "rest"}
	sample.play(event, choice, [])

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func text(at: Vector2, value: String, color := Color("d4d7e2"), font_size := 14) -> void:
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw() -> void:
	if font == null: return
	draw_rect(Rect2(Vector2.ZERO, size), Color("0c101b"))
	text(Vector2(20, 110), ["婴儿—老年 · 待机 / 左步 / 右步 / 说话", "母亲 / 同学 / 老师 / 上司 / 伴侣 / 邻居", "家中 / 教室 / 办公室 / 公园 / 医院 / 纪念园", "选择后：入场 → 动作 → 结果；可点击下一句推进"][page])
	if page <= 1:
		var keys: Array = Cast.STAGES if page == 0 else Cast.ROLES
		var labels := ["婴儿", "幼年", "学龄", "少年", "青年成年", "中年", "老年"] if page == 0 else ["母亲", "同学", "老师", "上司", "伴侣", "邻居"]
		var row_h := 96.0
		for row in range(keys.size()):
			var y := 142 + row * row_h
			draw_rect(Rect2(16, y, 488, 90), Color("171e2e"))
			text(Vector2(24, y + 48), labels[row], Color("efcf8d"), 13)
			for col in range(4):
				var texture := Cast.frame(keys[row], page == 1, col)
				var height := 74.0
				var dimensions := texture.get_size() * (height / texture.get_height())
				draw_texture_rect(texture, Rect2(Vector2(130 + col * 105, y + 82) - Vector2(dimensions.x / 2, dimensions.y), dimensions), false)
	elif page == 2:
		var labels := ["家中的灯", "窗边课桌", "工作的夜晚", "公园长椅", "陪伴与照顾", "记忆留下的地方"]
		for i in range(6):
			var at := Vector2(18 + (i % 2) * 249, 140 + floori(i / 2.0) * 237)
			draw_texture_rect(Cast.room(Cast.ROOMS[i]), Rect2(at, Vector2(235, 210)), false)
			text(at + Vector2(4, 228), labels[i])
	else:
		text(Vector2(20, 760), "两项选择分别进入家人与休息场景。素材预览不修改存档。", Color("8d9cb6"), 13)
