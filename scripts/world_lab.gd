extends Control
const PanelView := preload("res://scripts/comic_panel.gd")
const Art := preload("res://scripts/comic_art.gd")
const Ink := preload("res://scripts/comic_theme.gd")
var clock := 0.0
var playing := true
var selected := 0
var panels: Array = []
var title: Label
var timeline: HSlider
var selector: OptionButton
var play_button: Button
var stories := [
	["深夜加班", "office", "lead_adult", "npc_boss", [
		["你走进办公室，老板还在等今晚的报表。","walk","","work"],
		["你敲键盘，桌上的咖啡已经凉了。","type","computer","work"],
		["你关掉电脑，拿起包走出办公室。","poweroff","computer","work"]]],
	["第一次上台", "classroom", "lead_teen", "npc_friend", [
		["你走向鼓架，同学们停下说话看过来。","walk","drum","performance"],
		["你举起鼓槌，敲出第一段节拍。","drum","drum","performance"],
		["朋友举起手欢呼，你向台下挥手。","wave","drum","performance"]]],
	["放学借书", "classroom", "lead_child", "npc_teacher", [
		["你走到讲台前，老师把书递来。","walk","book","study"],
		["你伸手接过书，翻到折了角的一页。","raise","book","gift"],
		["你翻开书认真读，朋友凑过来一起看。","read","book","study"]]],
	["把时间留给家人", "home", "lead_middle", "npc_parent", [
		["你拿起手机，接起妈妈打来的电话。","phone","phone","conversation"],
		["你走进家门，桌上留着一碗热饭。","walk","meal","meal"],
		["你坐下吃饭，妈妈终于放下手里的药。","sit","meal","meal"]]],
	["体检那一天", "hospital", "lead_elder", "npc_partner", [
		["你走进诊室，爱人拿着报告在门边等你。","walk","letter","care"],
		["你伸手接过药，把医生的话记在纸上。","raise","medicine","care"],
		["你坐下，爱人把椅子挪到你身旁。","sit","medicine","care"]]],
	["离开熟悉的街道", "park", "lead_youth", "npc_friend", [
		["朋友把临别的信递给你。","raise","letter","gift"],
		["你向朋友挥手，行李箱还放在脚边。","wave","letter","farewell"],
		["你离开公园，朋友站在原地目送你。","walk","","farewell"]]]]

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var bg := ColorRect.new()
	bg.color = Color("101d2b")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var list := OptionButton.new()
	selector = list
	list.position = Vector2(14,12)
	for story in stories: list.add_item(story[0])
	list.item_selected.connect(select)
	add_child(list)
	var button := Button.new()
	play_button = button
	button.text = "播放 / 暂停"
	button.position = Vector2(240,12)
	button.pressed.connect(func(): playing = not playing)
	add_child(button)
	var slider := HSlider.new()
	timeline = slider
	slider.position = Vector2(14,54)
	slider.size = Vector2(460,24)
	slider.max_value = 2.4
	slider.step = 0.05
	slider.value_changed.connect(func(value): playing = false; sample_at(value))
	add_child(slider)
	title = Label.new()
	title.position = Vector2(14,83)
	title.add_theme_font_override("font",Ink.font_body())
	title.add_theme_font_size_override("font_size",14)
	title.text = "建立场景 → 动作发生 → 关系与环境回应"
	add_child(title)
	select(0)
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	if timeline != null: timeline.size.x = maxf(80,size.x-28)
	if selector != null: selector.size = Vector2(maxf(140,size.x-155),34)
	if play_button != null:
		play_button.position.x = maxf(180,size.x-130)
		play_button.size = Vector2(116,34)
	for panel in panels: panel.size.x = maxf(180,size.x-28)

func select(index: int) -> void:
	selected = index
	if selector != null: selector.select(index)
	clock = 0
	for panel in panels: panel.queue_free()
	panels.clear()
	var story: Array = stories[index]
	for i in range(3):
		var row: Array = story[4][i]
		var panel := PanelView.new()
		panel.position = Vector2(14,116+i*252)
		panel.size = Vector2(492,240)
		var spec := {"ink":story[2],"support":story[3],"scene":story[1],"caption":row[0],"action":row[1],"actor":"lead","prop":row[2],"world_mode":row[3],"shot":"wide","shot_locked":true}
		if row[1] == "poweroff": spec.erase("action")
		if i == 2 and row[1] == "walk": spec["caption"] = row[0]
		panel.setup(spec,Art.portrait(story[2],0))
		add_child(panel)
		panels.append(panel)
	sample_at(0)
	_layout()

func sample_at(value: float) -> void:
	clock = clampf(value,0,3.5)
	if timeline != null: timeline.set_value_no_signal(minf(clock,2.4))
	for panel in panels:
		panel._moment_age = minf(clock,2.4)
		if panel.moments.size() > 1:
			# Keep authored compound actions in order instead of freezing the last
			# clause for the whole preview (e.g. switch off, then walk out).
			var index := mini(panel.moments.size()-1,int(clock/2.4*panel.moments.size()))
			panel.current_direction = panel.moments[index].duplicate(true)
			panel._moment_index = index
		panel.set_process(false)
		panel.queue_redraw()

func _process(delta: float) -> void:
	if playing: sample_at(fmod(clock+delta,3.5))
