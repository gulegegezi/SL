extends Control
## F6：独立演出预览，不改人生数值和存档。
const PanelView := preload("res://scripts/comic_panel.gd")
const Art := preload("res://scripts/comic_art.gd")
var cards: Array = []
var reduced := false
var samples := [
	["转折", "你微笑着，突然震惊得说不出话。", "你没有哭，只是放下了手机。"],
	["人物", "你微笑着，妈妈突然大哭起来。", "爸爸吃惊地望着你。"],
	["道具", "你拿起笔签字。", "你给妈妈打电话，窗外下雨了。"],
	["静默", "你睡着了，窗外下雨了。", "你没有哭，也不再害怕。"]
]
var selected := 0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var bg := ColorRect.new()
	bg.color = Color("102a33")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var title := Label.new()
	title.text = "文本 × 表情 · 漫画演出预览"
	title.position = Vector2(18, 16)
	title.add_theme_font_override("font", preload("res://scripts/comic_theme.gd").font_body())
	title.add_theme_font_size_override("font_size", 22)
	add_child(title)
	var row := HBoxContainer.new()
	row.position = Vector2(18, 58)
	add_child(row)
	for i in range(samples.size()):
		var button := Button.new()
		button.text = samples[i][0]
		button.custom_minimum_size = Vector2(76, 36)
		button.pressed.connect(show_sample.bind(i))
		row.add_child(button)
	var replay := Button.new()
	replay.text = "重播"
	replay.pressed.connect(func(): show_sample(selected))
	row.add_child(replay)
	var toggle := CheckButton.new()
	toggle.text = "减少动态效果"
	toggle.position = Vector2(18, 104)
	toggle.toggled.connect(func(v): reduced = v; show_sample(selected))
	add_child(toggle)
	show_sample(0)

func show_sample(index: int) -> void:
	selected = index
	for card in cards:
		remove_child(card)
		card.queue_free()
	cards.clear()
	for i in range(2):
		var card := PanelView.new()
		card.position = Vector2(18, 158 + i * 352)
		card.size = Vector2(484, 330)
		card.reduced_motion = reduced
		add_child(card)
		card.setup({"caption": samples[index][i + 1], "ink": "lead_adult", "shot": "close", "scene": "home", "tone": "paper"}, Art.portrait("lead_adult", 0))
		card.set_revealed(false)
		card.set_revealed(true)
		cards.append(card)
