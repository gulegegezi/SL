extends Control
const PanelView := preload("res://scripts/comic_panel.gd")
const Art := preload("res://scripts/comic_art.gd")
const Motion := preload("res://scripts/comic_motion.gd")
const ThemeInk := preload("res://scripts/comic_theme.gd")
var cards: Array = []
var clock := 0.0
var playing := true
var selected := 0
var ink_key := "lead_adult"
var reduced := false
var slider: HSlider
var phase_label: Label
var samples := [
	["递接","receive","toy","妈妈把玩具递来，你伸手接住。"],
	["翻阅","read","book","你翻开作品集，认真读完这一页。"],
	["电话","phone","phone","你拿起手机，举到耳边听朋友说话。"],
	["写字","sign","letter","你拿起笔签字，另一只手按住信纸。"],
	["敲鼓","drum","drum","你举起鼓槌，两只手交替敲出节拍。"],
	["走路","walk","","你走进房间，停下脚步。"],
	["挥手","wave","","你抬起手，向门口的朋友挥手。"],
	["坐下","sit","","你坐下，把一天的疲惫慢慢放下。"]]

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = ThemeInk.WALL
	add_child(background)
	var label := Label.new()
	label.text = "人物行动 · 起手 / 接触 / 动作 / 收势"
	label.position = Vector2(16,12)
	label.add_theme_font_override("font",ThemeInk.font_body())
	label.add_theme_font_size_override("font_size",19)
	add_child(label)
	var row := HBoxContainer.new()
	row.position = Vector2(16,46)
	add_child(row)
	for i in range(samples.size()):
		var button := Button.new()
		button.text = samples[i][0]
		button.custom_minimum_size = Vector2(55,34)
		button.pressed.connect(select.bind(i))
		row.add_child(button)
	var ages := OptionButton.new()
	ages.position = Vector2(16,88)
	for name in ["婴儿","童年","少年","青年","成年","中年","老年","妈妈","朋友","老板"]: ages.add_item(name)
	ages.select(4)
	ages.item_selected.connect(func(index):
		ink_key = ["infant_infant","lead_child","lead_teen","lead_youth","lead_adult","lead_middle","lead_elder","npc_parent","npc_friend","npc_boss"][index]
		select(selected))
	add_child(ages)
	var pause := Button.new()
	pause.text = "播放 / 暂停"
	pause.position = Vector2(140,88)
	pause.pressed.connect(func(): playing = not playing)
	add_child(pause)
	var low := CheckButton.new()
	low.text = "减少动态"
	low.position = Vector2(288,85)
	low.toggled.connect(func(value): reduced = value; select(selected))
	add_child(low)
	phase_label = Label.new()
	phase_label.position = Vector2(16,130)
	phase_label.add_theme_font_override("font",ThemeInk.font_body())
	add_child(phase_label)
	slider = HSlider.new()
	slider.position = Vector2(200,132)
	slider.size = Vector2(296,22)
	slider.max_value = Motion.DURATION
	slider.step = 0.01
	slider.value_changed.connect(func(value): clock = value; playing = false; sample_at(clock))
	add_child(slider)
	select(0)

func select(index: int) -> void:
	selected = index
	clock = 0
	for card in cards:
		remove_child(card)
		card.queue_free()
	cards.clear()
	for i in range(2):
		var card := PanelView.new()
		card.position = Vector2(16,170+i*358)
		card.size = Vector2(488,338)
		card.reduced_motion = reduced
		add_child(card)
		var spec := {"caption":samples[index][3],"ink":ink_key,"action":samples[index][1],"prop":samples[index][2],"actor":"lead","expr":"normal","shot":"medium","shot_locked":true,"tone":"paper","scene":"home"}
		if i == 0 and str(samples[index][1]) not in ["walk","wave","sit"]:
			spec["stage_action"] = true
			spec["support"] = "npc_parent" if index == 0 else "npc_friend"
			spec["interaction"] = {"kind":"drag" if index == 0 else "tap","prop":samples[index][2],"action":samples[index][1],"hint":"动作对照","reveal":""}
		card.setup(spec,Art.portrait(ink_key,0))
		card.finish_reveal()
		card.interaction_done = true
		card.interactions_enabled = false
		cards.append(card)
	sample_at(0)

func sample_at(time: float) -> void:
	clock = time
	var phase: String = Motion.sample(str(samples[selected][1]),time,reduced).phase
	phase_label.text = {"anticipation":"起手","reach":"伸手 / 靠近","contact":"接触 / 行动","settle":"收势"}.get(phase,phase)+"  %.2fs" % time
	slider.set_value_no_signal(time)
	for card in cards:
		card._moment_age = Motion.DURATION if reduced else time
		card._interaction_clock = Motion.DURATION if reduced else time
		card._age = time
		card.queue_redraw()

func _process(delta: float) -> void:
	if not playing or reduced: return
	var next := clock+delta
	if next > Motion.DURATION+0.7: next = 0
	sample_at(minf(next,Motion.DURATION))
	clock = next
