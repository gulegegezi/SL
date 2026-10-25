extends Control
## Presentation-only conversation. The life simulation owns choices and outcomes.
signal finished(progress: Dictionary)
const PixelPanel := preload("res://scripts/comic_panel.gd")
const ThemeKit := preload("res://scripts/comic_theme.gd")
const DialogueBox := preload("res://scripts/dialogue_box.gd")
var lines: Array = []
var index := 0
var panel: Control
var stage_area: Control
var box: Control
var heading: Label
var next_button: Button
var history: AcceptDialog
var initial_progress: Dictionary = {}
var completed := false
var _closing := false
var voice: AudioStreamPlayer
var muted := false
var _last_character := 0
var _sound_wait := 0.0

func configure(page: Dictionary) -> void:
	lines = page.get("panels",[]).duplicate(true)
	initial_progress = page.get("conversation_progress",{}).duplicate(true)
	index = 0 if initial_progress.get("completed",false) else clampi(int(initial_progress.get("line",0)),0,maxi(0,lines.size()-1))

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color("101f29")
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,12)
	add_child(margin)
	var column := VBoxContainer.new(); margin.add_child(column)
	heading = Label.new()
	heading.add_theme_font_override("font",ThemeKit.font_body())
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(heading)
	stage_area = Control.new()
	stage_area.size_flags_vertical = SIZE_EXPAND_FILL
	column.add_child(stage_area)
	box = DialogueBox.new()
	box.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	box.offset_top = -156
	box.offset_left = 6
	box.offset_right = -6
	box.offset_bottom = -6
	stage_area.add_child(box)
	next_button = add_button(column,"",advance)
	var row := HBoxContainer.new(); column.add_child(row)
	add_button(row,"对话记录",show_history)
	add_button(row,"返回漫画",close)
	var sound_button := add_button(column,"字音：开",func():
		muted = not muted)
	sound_button.pressed.connect(func(): sound_button.text = "字音：关" if muted else "字音：开")
	voice = AudioStreamPlayer.new()
	voice.stream = preload("res://scripts/audio_fx.gd")._tone(460,0.035,0.15,false)
	voice.volume_db = -15
	add_child(voice)
	history = AcceptDialog.new()
	history.title = "已经读过的对话"
	history.add_theme_font_override("font",ThemeKit.font_body())
	add_child(history)
	history.visibility_changed.connect(func():
		if not history.visible and is_instance_valid(panel):
			panel.spec["conversation_paused"] = false
			panel.set_process(true))
	show_line()
	if not initial_progress.get("completed",false):
		panel.visible_characters = clampi(int(initial_progress.get("characters",0)),0,panel._full_text.length())
	next_button.grab_focus()

func add_button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 46
	button.size_flags_horizontal = SIZE_EXPAND_FILL
	button.add_theme_font_override("font",ThemeKit.font_body())
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func show_line() -> void:
	if lines.is_empty(): close(); return
	var spec: Dictionary = lines[index].duplicate(true)
	for field in ["pixel_cg","pixel_interaction","interaction","interaction_progress","cg_progress","comic_insert"]: spec.erase(field)
	# The reader keeps its illustrations; spoken sequences need a persistent stage.
	if not str(spec.get("ink", "")).is_empty(): spec["presentation"] = "pixel3d"
	spec["conversation_mode"] = true
	# 文字交给屏幕上的对话框，格子里只留画面
	spec["hide_text"] = true
	# Keep the room and cast alive across utterances with the same staging.
	if is_instance_valid(panel):
		for field in ["scene","support","ink","prop"]:
			if panel.spec.get(field) != spec.get(field):
				if is_instance_valid(panel.pixel_stage): panel.pixel_stage.release_world()
				break
		panel.setup(spec,null)
	else:
		panel = PixelPanel.new()
		panel.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		panel.setup(spec,null)
		stage_area.add_child(panel)
		panel.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				advance(); panel.accept_event())
	panel.interactions_enabled = false
	# 文字交给对话框，格子里只留画面
	if is_instance_valid(box):
		box.move_to_front()
		var spoken := str(spec.get("bubble", ""))
		var narr := str(spec.get("caption", ""))
		var line := spoken if spoken != "" else narr
		var who := str(spec.get("speaker_label", ""))
		if who == "旁白": who = ""
		box.show_line(line, who)
	_last_character = 0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_revealed(false); panel.set_revealed(true)
	heading.text = "%d / %d · %s" % [index+1,lines.size(),spec.get("speaker_label","旁白")]

func _process(delta: float) -> void:
	if not is_instance_valid(panel): return
	var typing: bool = panel.visible_characters < panel._full_text.length()
	_sound_wait = maxf(0,_sound_wait-delta)
	if panel.visible_characters > _last_character:
		if not muted and not history.visible and _sound_wait <= 0 and not panel._full_text.contains("一言不发"):
			var pitch := 0.82+float(posmod(str(panel.spec.get("actor","lead")).hash(),5))*0.10
			preload("res://scripts/audio_fx.gd").play(self, "blip", pitch, -4.0)
			_sound_wait = 0.075
		_last_character = panel.visible_characters
	if is_instance_valid(box):
		box.set_progress(panel.visible_characters)
	next_button.text = "显示整句 · 点击画面 / 空格" if typing else ("下一句 ▾" if index < lines.size()-1 else "对话结束 · 返回漫画")

func advance() -> void:
	if _closing or history.visible or not is_instance_valid(panel): return
	if panel.visible_characters < panel._full_text.length():
		panel.reveal_all_text()
		_last_character = panel.visible_characters
		return
	if index+1 >= lines.size(): completed = true; close(); return
	index += 1
	show_line()

func snapshot() -> Dictionary:
	return {"line":index,"characters":panel.visible_characters if is_instance_valid(panel) else 0,"completed":completed}

func close() -> void:
	if _closing: return
	_closing = true
	finished.emit(snapshot())
	queue_free()

func history_text() -> String:
	var text := ""
	for i in range(index+1):
		var line: Dictionary = lines[i]
		var words := str(line.get("caption",""))+str(line.get("bubble",""))
		if i == index and is_instance_valid(panel): words = words.left(maxi(0,panel.visible_characters-(1 if not str(line.get("bubble","")).is_empty() else 0)))
		text += words+"\n\n"
	return text

func show_history() -> void:
	panel.set_process(false)
	panel.spec["conversation_paused"] = true
	var old := history.get_node_or_null("Transcript")
	if old != null: history.remove_child(old); old.queue_free()
	var transcript := RichTextLabel.new()
	transcript.name = "Transcript"
	transcript.bbcode_enabled = false
	transcript.text = history_text()
	transcript.add_theme_font_override("normal_font",ThemeKit.font_body())
	transcript.custom_minimum_size = Vector2(maxf(220,minf(size.x-60,600)),maxf(160,minf(size.y-150,450)))
	history.add_child(transcript)
	history.popup_centered()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE: close(); get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_SPACE,KEY_ENTER]: advance(); get_viewport().set_input_as_handled()
