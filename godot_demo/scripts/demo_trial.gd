extends Control
## 经典 Demo 的 Godot 移植：序章分支 + 人生池 + 镜头推拉 / letterbox / 闪白 / 结果镜头。
## 逻辑沿用 GameController 的 choose/_next_phase，人物与场景走最新的 pixel_cast。

const CutsceneStage := preload("res://scripts/cutscene_stage.gd")
const DataLoader := preload("res://scripts/data_loader.gd")
const GameState := preload("res://scripts/game_state.gd")
const GameController := preload("res://scripts/game_controller.gd")

var state: GameState
var gc: GameController
var stage: CutsceneStage
var header: Label
var stats: Label
var tags: Label
var summary: Label
var end_title: Label
var restart_btn: Button
var bar_top: ColorRect
var bar_bottom: ColorRect
var flash: ColorRect

var phase := "prologue"  # prologue | prologue_result | life | life_result | end
var current_event: Dictionary = {}
var current_cut: Dictionary = {}
var pending_next := ""
var seen: Dictionary = {}
var turn := 0
var ended := false
var memories: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	DataLoader.ensure_loaded()
	_build_ui()
	_restart()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("080a12")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 10
	root.offset_top = 6
	root.offset_right = -10
	root.offset_bottom = -6
	root.add_theme_constant_override("separation", 4)
	add_child(root)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	root.add_child(top)
	header = Label.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color("f0e6cc"))
	top.add_child(header)
	restart_btn = Button.new()
	restart_btn.text = "重开"
	restart_btn.pressed.connect(_restart)
	top.add_child(restart_btn)

	stage = CutsceneStage.new()
	stage.custom_minimum_size = Vector2(0, 490)
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 不抢满整列高度：场景+对话框之后立刻接数值/标签，避免中间一大段黑缝。
	stage.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	root.add_child(stage)
	stage.finished.connect(_on_finished)

	bar_top = ColorRect.new()
	bar_top.color = Color.BLACK
	bar_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar_top.offset_bottom = 0
	stage.add_child(bar_top)
	bar_bottom = ColorRect.new()
	bar_bottom.color = Color.BLACK
	bar_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar_bottom.offset_top = 0
	stage.add_child(bar_bottom)
	flash = ColorRect.new()
	flash.color = Color.WHITE
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.modulate.a = 0.0
	stage.add_child(flash)

	stats = Label.new()
	stats.add_theme_font_size_override("font_size", 12)
	stats.add_theme_color_override("font_color", Color("b9c6d8"))
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(stats)
	tags = Label.new()
	tags.add_theme_font_size_override("font_size", 11)
	tags.add_theme_color_override("font_color", Color("8fd4ff"))
	tags.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(tags)
	end_title = Label.new()
	end_title.visible = false
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_title.add_theme_font_size_override("font_size", 26)
	root.add_child(end_title)
	summary = Label.new()
	summary.visible = false
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_font_size_override("font_size", 14)
	summary.add_theme_color_override("font_color", Color("e8e3d2"))
	summary.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(summary)

func _restart() -> void:
	state = GameState.new()
	state.line = "normal"
	state.age = 0
	# 对齐 HTML demo 的初始值：6/7/5/6，金钱 20，抽象 10，寿命 78。
	state.intl = 6
	state.health = 7
	state.charm = 5
	state.luck = 6
	state.money = 20
	state.abstract_val = 10
	state.abstract_peaked = 10
	state.abstract_dropped = 10
	state.lifespan = 78
	gc = GameController.new()
	gc.init()
	gc.state = state
	seen.clear()
	turn = 0
	ended = false
	phase = "prologue"
	memories.clear()
	summary.visible = false
	end_title.visible = false
	stats.visible = true
	tags.visible = true
	stage.visible = true
	_set_bars(false)
	_show_prologue(DataLoader.opening_start("normal"))

# ==========================================================
# 序章
# ==========================================================
func _show_prologue(id: String) -> void:
	var node := DataLoader.find_story_node(id).duplicate(true)
	if node.is_empty():
		_start_life()
		return
	current_event = node
	current_cut = _cut_for(node)
	phase = "prologue"
	_configure(node, current_cut)
	_update_hud()

func _start_life() -> void:
	phase = "life"
	state.age = maxi(1, state.age)
	turn = 0
	_next_life()

func _next_life() -> void:
	if state.age >= state.lifespan or state.health <= 0 or turn >= 34:
		_end_demo()
		return
	var ev := _pick_life_event()
	if ev.is_empty():
		_end_demo()
		return
	seen[str(ev.get("id", ""))] = true
	turn += 1
	current_event = ev
	current_cut = _cut_for(ev)
	phase = "life"
	_configure(ev, current_cut)
	_update_hud()

func _advance_life() -> void:
	state.age += 1 + (1 if gc.rng.randf() < 0.35 else 0)
	gc._next_phase(0)
	_next_life()

# ==========================================================
# 选择结算
# ==========================================================
func _on_finished(choice: Dictionary) -> void:
	if phase == "prologue" or phase == "life":
		gc.choose(choice, current_event)
		gc.state.story_queue.clear()
		memories.append(str(choice.get("memory", choice.get("label", ""))))
		pending_next = str(gc._resolve_next(choice.get("next", current_event.get("next", null))))
		var was_prologue := phase == "prologue"
		phase = "prologue_result" if was_prologue else "life_result"
		_configure(_result_event(), _result_cut(choice), _continue_choices(_result_event()))
		_set_bars(true)
		_flash(_flash_color(choice))
		_update_hud()
	elif phase == "prologue_result":
		_set_bars(false)
		if pending_next.is_empty():
			_start_life()
		else:
			_show_prologue(pending_next)
	elif phase == "life_result":
		_set_bars(false)
		_advance_life()

func _result_event() -> Dictionary:
	return {
		"id": str(current_event.get("id", "")) + "_result",
		"choices": [{"label": "继续", "result": "", "effects": {}}],
	}

func _continue_choices(ev: Dictionary) -> Array:
	return [{"choice": ev["choices"][0], "locked": false, "hint": "", "continue": true}]

func _result_cut(choice: Dictionary) -> Dictionary:
	var cast: Array = []
	for c in current_cut.get("cast", []):
		var cc: Dictionary = c.duplicate(true)
		cc.erase("from")
		cc.erase("walk_time")
		cast.append(cc)
	var cam: Dictionary = (current_cut.get("camera", {}) as Dictionary).duplicate(true)
	cam["zoom"] = float(cam.get("zoom", 1.0)) + 0.06
	var beats: Array = [{"speaker": "旁白", "face": "lead", "expr": "normal",
		"text": _fill_text(str(choice.get("result", "")))}]
	var reactions: Dictionary = current_cut.get("reactions", {})
	for b in reactions.get(str(choice.get("label", "")), []):
		var rb: Dictionary = b.duplicate(true)
		rb["text"] = _fill_text(str(rb.get("text", "")))
		beats.append(rb)
	return {
		"bg": str(current_cut.get("bg", "home")),
		"cast": cast,
		"camera": cam,
		"beats": beats,
	}

# ==========================================================
# 画面与选项
# ==========================================================
func _configure(ev: Dictionary, cut: Dictionary, choices: Array = []) -> void:
	if choices.is_empty():
		choices = _enrich_choices(ev)
	stage.configure(ev, cut, state, choices)
	stage.play()

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

func _cut_for(ev: Dictionary) -> Dictionary:
	var existing := DataLoader.cutscene_for(str(ev.get("id", "")))
	if not existing.is_empty():
		var copy: Dictionary = existing.duplicate(true)
		_fill_beats(copy)
		return copy
	var cut := _generic_cut(ev)
	_fill_beats(cut)
	return cut

func _fill_beats(cut: Dictionary) -> void:
	for b in cut.get("beats", []):
		b["text"] = _fill_text(str(b.get("text", "")))

func _fill_text(text: String) -> String:
	for eid in state.choice_log:
		text = text.replace("{choice:%s}" % str(eid), str(state.choice_log[eid]))
	return text

func _generic_cut(ev: Dictionary) -> Dictionary:
	var bg := _bg_for(ev)
	return {
		"bg": bg,
		"cast": [
			{"role": "lead", "x": 58, "y": 62, "action": "idle", "face": "normal"},
			{"role": _npc_for(bg), "x": 118, "y": 62, "action": "idle", "face": "normal"},
		],
		"camera": {"zoom": 1.2, "x": 85, "y": 48},
		"beats": [{"speaker": "旁白", "face": "lead", "expr": "normal", "text": str(ev.get("text", ev.get("title", "")))}],
	}

func _bg_for(ev: Dictionary) -> String:
	var eid := str(ev.get("id", ""))
	var pool: Array
	if state.age <= 2:
		pool = ["home"]
	elif state.age <= 6:
		pool = ["home"]
	elif state.age <= 12:
		pool = ["home", "classroom", "park"]
	elif state.age <= 18:
		pool = ["classroom", "park", "home"]
	elif state.age <= 30:
		pool = ["office", "park", "home"]
	elif state.age <= 55:
		pool = ["office", "home", "hospital", "park"]
	else:
		pool = ["home", "park", "hospital", "grave"]
	return str(pool[absi(hash(eid)) % pool.size()])

func _npc_for(bg: String) -> String:
	match bg:
		"classroom": return "teacher"
		"office": return "boss"
		"park": return "friend"
		"grave": return "mate"
		"hospital": return "parent"
		_: return "parent"

func _pick_life_event() -> Dictionary:
	var pool: Array = []
	for e in DataLoader.events():
		var eid := str(e.get("id", ""))
		if seen.has(eid):
			continue
		var eline := str(e.get("line", "common"))
		if eline != "common" and eline != state.line and eline != "lucky":
			continue
		if not gc._cond_matches(e.get("cond", {})):
			continue
		pool.append(e)
	if pool.is_empty():
		seen.clear()
		return _pick_life_event()
	var total := 0.0
	for e in pool:
		total += maxf(1.0, float(e.get("weight", 10)))
	var r := gc.rng.randf() * total
	for e in pool:
		r -= maxf(1.0, float(e.get("weight", 10)))
		if r <= 0.0:
			return e
	return pool[pool.size() - 1]

# ==========================================================
# HUD / 特效 / 结算
# ==========================================================
func _update_hud() -> void:
	var chapter := "序章"
	if phase.begins_with("life"):
		chapter = "人生"
	elif not current_event.is_empty():
		chapter = str(current_event.get("chapter", current_event.get("title", "序章")))
	header.text = "%s · %d 岁 · 第 %d 幕" % [chapter, state.age, maxi(1, turn + 1)]
	stats.text = "智力 %d · 体质 %d · 魅力 %d · 运气 %d · 金钱 %d · 抽象 %d · 寿命 %d" % [
		state.intl, state.health, state.charm, state.luck, state.money, state.abstract_val, state.lifespan,
	]
	var names: Array = []
	for t in state.tags:
		var s := str(t)
		if not s.begins_with("_"):
			names.append(s)
	tags.text = "标签：" + ("、".join(names) if not names.is_empty() else "—")

func _set_bars(on: bool) -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(bar_top, "offset_bottom", 26.0 if on else 0.0, 0.16)
	tw.tween_property(bar_bottom, "offset_top", -26.0 if on else 0.0, 0.16)

func _flash_color(choice: Dictionary) -> Color:
	var net := 0
	for k in choice.get("effects", {}):
		if str(k) != "abstract":
			net += int(choice["effects"][k])
	return Color(1, 1, 1) if net >= 0 else Color(0, 0, 0)

func _flash(color: Color) -> void:
	flash.color = color
	flash.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(flash, "modulate:a", 0.55, 0.06)
	tw.tween_property(flash, "modulate:a", 0.0, 0.22)

func _end_demo() -> void:
	phase = "end"
	ended = true
	_set_bars(false)
	stage.visible = false
	stats.visible = false
	tags.visible = false
	summary.visible = true
	header.text = "结算 · %d 岁" % state.age
	var score := state.intl * 3 + state.health * 3 + state.charm * 2 + state.luck + int(state.money / 10.0) + int(state.abstract_val * 0.4)
	var rank := "拉完了"
	if state.age >= 15:
		if score >= 110: rank = "夯"
		elif score >= 80: rank = "人上人"
		elif score >= 50: rank = "NPC"
	var why := "身体先撑不住了" if state.health <= 0 else ("活到了寿命上限" if state.age >= state.lifespan else "这一局先到这里")
	var lines: Array = ["%d 岁 · 综合分 %d" % [state.age, score], why, ""]
	lines.append("智力 %d ｜ 体质 %d ｜ 魅力 %d ｜ 运气 %d" % [state.intl, state.health, state.charm, state.luck])
	lines.append("金钱 %d ｜ 抽象度 %d ｜ 寿命 %d" % [state.money, state.abstract_val, state.lifespan])
	var names: Array = []
	for t in state.tags:
		var s := str(t)
		if not s.begins_with("_"):
			names.append(s)
	if not names.is_empty():
		lines.append("标签：" + "、".join(names))
	if not memories.is_empty():
		lines.append("")
		lines.append("你记住的瞬间：")
		for m in memories.slice(maxi(0, memories.size() - 8), memories.size()):
			lines.append("· " + str(m))
	summary.text = "\n".join(lines)
	end_title.text = rank
	end_title.add_theme_color_override("font_color", _rank_color(rank))
	end_title.visible = true


func _rank_color(rank: String) -> Color:
	match rank:
		"夯": return Color("ffd166")
		"人上人": return Color("8fd4ff")
		"NPC": return Color("c9c9d4")
		_: return Color("ff8a8a")
