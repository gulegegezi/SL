extends Control
## 三岁前试玩：把序章 + 1/2 岁事件串成一段可玩的对白动画。
## 每个场景 = 一段 CutsceneStage 对白 + 事件自带的选项；选项结果再用一段旁白镜头收尾。

const CutsceneStage := preload("res://scripts/cutscene_stage.gd")
const DataLoader := preload("res://scripts/data_loader.gd")
const GameState := preload("res://scripts/game_state.gd")
const GameController := preload("res://scripts/game_controller.gd")

var seq: Dictionary = {}
var scenes: Array = []
var state: GameState
var gc: GameController
var stage: Control
var header: Label
var summary: Label
var index := -1
var phase := "scene"  # scene | result | end
var current_event: Dictionary = {}
var current_cut: Dictionary = {}
var current_choice: Dictionary = {}
var memories: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	DataLoader.ensure_loaded()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/story_demo_pre3.json"))
	seq = parsed if parsed is Dictionary else {}
	scenes = seq.get("scenes", [])

	var bg := ColorRect.new()
	bg.color = Color("080a12")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 12
	root.offset_top = 8
	root.offset_right = -12
	root.offset_bottom = -8
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	header = Label.new()
	header.add_theme_font_size_override("font_size", 15)
	header.add_theme_color_override("font_color", Color("f0e6cc"))
	root.add_child(header)

	stage = CutsceneStage.new()
	stage.custom_minimum_size = Vector2(0, 460)
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(stage)
	stage.finished.connect(_on_finished)

	summary = Label.new()
	summary.visible = false
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_font_size_override("font_size", 15)
	summary.add_theme_color_override("font_color", Color("e8e3d2"))
	summary.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(summary)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	root.add_child(bar)
	var restart := Button.new()
	restart.text = "重新播放"
	restart.pressed.connect(_reset)
	bar.add_child(restart)
	var back := Button.new()
	back.text = "返回主菜单"
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Main.tscn"))
	bar.add_child(back)

	_reset()

func _reset() -> void:
	index = -1
	phase = "scene"
	memories.clear()
	state = GameState.new()
	state.line = "normal"
	state.age = 0
	gc = GameController.new()
	gc.init()
	gc.state = state
	stage.visible = true
	summary.visible = false
	_next_scene()

func _next_scene() -> void:
	index += 1
	if index >= scenes.size():
		_show_end()
		return
	var entry: Dictionary = scenes[index]
	state.age = int(entry.get("age", 0))
	current_event = DataLoader.find_story_node(str(entry.get("event", ""))).duplicate(true)
	current_cut = DataLoader.cutscene_for(str(entry.get("cutscene", ""))).duplicate(true)
	if current_event.is_empty() or current_cut.is_empty():
		push_warning("story demo: missing event/cutscene for " + str(entry))
		_next_scene()
		return
	for b in current_cut.get("beats", []):
		b["text"] = _fill_text(str(b.get("text", "")))
	phase = "scene"
	stage.configure(current_event, current_cut, state, _enrich_choices(current_event))
	stage.play()
	_update_header()

func _on_finished(choice: Dictionary) -> void:
	if phase == "scene":
		current_choice = choice
		gc.choose(choice, current_event)
		gc.state.story_queue.clear()
		memories.append(str(choice.get("memory", choice.get("label", ""))))
		var result_text := _fill_text(str(choice.get("result", "")))
		var beats: Array = [{"speaker": "旁白", "face": "lead", "expr": "normal", "text": result_text}]
		var reactions: Dictionary = current_cut.get("reactions", {})
		for b in reactions.get(str(choice.get("label", "")), []):
			var rb: Dictionary = b.duplicate(true)
			rb["text"] = _fill_text(str(rb.get("text", "")))
			beats.append(rb)
		var cast: Array = []
		for c in current_cut.get("cast", []):
			var cc: Dictionary = c.duplicate(true)
			cc.erase("from")
			cc.erase("walk_time")
			cast.append(cc)
		var cam: Dictionary = (current_cut.get("camera", {}) as Dictionary).duplicate(true)
		cam["zoom"] = float(cam.get("zoom", 1.0)) + 0.06
		var cut := {
			"bg": str(current_cut.get("bg", "home")),
			"cast": cast,
			"camera": cam,
			"beats": beats,
		}
		var ev := {
			"id": str(current_event.get("id", "")) + "_result",
			"choices": [{"label": "继续", "result": "", "effects": {}}],
		}
		phase = "result"
		stage.configure(ev, cut, state, [{"choice": ev["choices"][0], "locked": false, "hint": ""}])
		stage.play()
		header.text = "三岁前 · %s · 结果" % str(scenes[index].get("chapter", ""))
	elif phase == "result":
		_next_scene()

func _update_header() -> void:
	if index >= 0 and index < scenes.size():
		header.text = "三岁前 · %s · 第 %d/%d 幕 · 年龄 %d" % [
			str(scenes[index].get("chapter", "")), index + 1, scenes.size(), state.age,
		]
	elif phase == "end":
		header.text = "三岁前 · 完"

func _show_end() -> void:
	phase = "end"
	index = scenes.size()
	stage.visible = false
	summary.visible = true
	header.text = "三岁前 · 完"
	var end_info: Dictionary = seq.get("end", {})
	var lines: Array = [str(end_info.get("text", ""))]
	lines.append("")
	lines.append("你记住的瞬间：")
	for m in memories:
		lines.append("· " + str(m))
	var tag_names: Array = []
	for t in state.tags:
		var s := str(t)
		if not s.begins_with("_"):
			tag_names.append(s)
	if not tag_names.is_empty():
		lines.append("")
		lines.append("留下的性格：" + "、".join(tag_names))
	var rel: Array = []
	for who in state.relations:
		var v := int(state.relations[who])
		if v != 0:
			rel.append("%s %s%d" % [str(who), "+" if v > 0 else "", v])
	if not rel.is_empty():
		lines.append("羁绊：" + "、".join(rel))
	lines.append("")
	lines.append("年龄：3 岁。故事从这里开始分岔。")
	summary.text = "\n".join(lines)

func _enrich_choices(ev: Dictionary) -> Array:
	var out: Array = []
	for c in ev.get("choices", []):
		if not gc.choice_available(c):
			continue
		var locked := false
		var hint := ""
		if c.has("requireRelations"):
			for who in c["requireRelations"]:
				if gc.state.get_relation(str(who)) < int(c["requireRelations"][who]):
					locked = true
					hint = str(c.get("requireHint", "需要和%s更亲近" % str(who)))
					break
		if not locked and c.has("requireTags"):
			for t in c["requireTags"]:
				if not gc.state.has_tag(str(t)):
					locked = true
					hint = str(c.get("requireHint", "需要先经历一些事"))
					break
		out.append({"choice": c, "locked": locked, "hint": hint})
	if out.is_empty():
		out.append({"choice": {"label": "继续", "result": "", "effects": {}}, "locked": false, "hint": ""})
	return out

func _fill_text(text: String) -> String:
	for eid in state.choice_log:
		text = text.replace("{choice:%s}" % str(eid), str(state.choice_log[eid]))
	return text
