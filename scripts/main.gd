## main.gd — UI 控制器，管理所有游戏屏幕
## 像素复古风主题，用 Godot 原生 UI 节点还原 HTML 版的视觉
extends Control

const GameController := preload("res://scripts/game_controller.gd")
const GameState := preload("res://scripts/game_state.gd")
const DataLoader := preload("res://scripts/data_loader.gd")
const ChoiceVFX := preload("res://scripts/vfx.gd")
const StoryStage := preload("res://scripts/story_stage.gd")
const UIAnim := preload("res://scripts/ui_anim.gd")

# ---- 颜色（星露谷风：羊皮纸面板 + 木框 + 深墨文字）----
const C := {
	"panel": Color(0.961, 0.910, 0.769, 1),   # 羊皮纸
	"panel2": Color(0.898, 0.835, 0.655, 1),  # 羊皮纸（深，用于 hover）
	"line": Color(0.435, 0.278, 0.149, 1),    # 木线
	"txt": Color(0.271, 0.192, 0.110, 1),     # 墨
	"dim": Color(0.482, 0.380, 0.271, 1),     # 淡墨
	"green": Color(0.361, 0.588, 0.220, 1),
	"cyan": Color(0.216, 0.510, 0.588, 1),
	"pink": Color(0.769, 0.325, 0.478, 1),
	"yellow": Color(0.706, 0.486, 0.125, 1),
	"red": Color(0.741, 0.239, 0.196, 1),
	"purple": Color(0.502, 0.337, 0.639, 1),
}

# ---- 演出区（深色土槽）专用配色：浅色才看得清 ----
const STAGE_PAL := {
	"yellow": Color(0.96, 0.80, 0.36),
	"green": Color(0.55, 0.88, 0.36),
	"cyan": Color(0.45, 0.85, 0.90),
	"pink": Color(0.97, 0.60, 0.72),
	"red": Color(0.95, 0.42, 0.36),
	"purple": Color(0.72, 0.55, 0.96),
	"txt": Color(0.93, 0.89, 0.78),
	"dim": Color(0.62, 0.56, 0.45),
}

var screen: VBoxContainer
var age_tag: Label
var gc: GameController
var meta: Dictionary
var current_event: Dictionary = {}
var current_choice: Dictionary = {}  # 本次选择的选项快照（供动画分发读取特征）
var anim_stage: Control  # 底部像素动画演出区（每次渲染重建）
var _prev_core: Dictionary = {}  # 上一次数值快照，供数值滚动动画用
var _choice_busy := false
var _story: Control
var _action_bar: PanelContainer
var _next_dialogue: Button
var _continue: Button
var _backdrop: Control
var _leaf_layer: Control

func _ready() -> void:
	DataLoader.ensure_loaded()
	screen = $MarginContainer/ScrollContainer/VBox/Screen
	age_tag = $MarginContainer/ScrollContainer/VBox/TopBar/AgeTag
	# 顶栏 Logo / 页脚：直接坐在背景画面上，改用墨色才看得清
	var ink: Color = UIAnim.INK
	var ink_dim: Color = UIAnim.INK_DIM
	var logo := $MarginContainer/ScrollContainer/VBox/TopBar/Logo as Label
	logo.add_theme_color_override("font_color", ink)
	logo.add_theme_font_size_override("font_size", 20)
	age_tag.add_theme_color_override("font_color", ink)
	var foot := $MarginContainer/ScrollContainer/VBox/Footer as Label
	foot.add_theme_color_override("font_color", ink_dim)
	foot.text = "选择 → 观看剧情 → 继续人生"

	# 星露谷农场背景（垫在 UI 最底层）＋常驻云/山风/萤火
	($ColorRect as ColorRect).color = Color(0.09, 0.10, 0.20)
	_backdrop = UIAnim.make_backdrop()
	add_child(_backdrop)
	move_child(_backdrop, 1)
	UIAnim.ambient(_backdrop)

	# 全屏飘叶层（在 UI 之上，鼠标穿透）
	_leaf_layer = Control.new()
	_leaf_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_leaf_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_leaf_layer)

	_create_story_actions()
	gc = GameController.new()
	gc.init()
	meta = gc.meta
	gc.game_started.connect(_on_game_started)
	gc.event_picked.connect(_on_event_picked)
	gc.choice_resolved.connect(_on_choice_resolved)
	gc.phase_advanced.connect(_on_phase_advanced)
	gc.game_ended.connect(_on_game_ended)
	render_title()

	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(_leaf_layer):
		UIAnim.leaves_drift(_leaf_layer, 7)

func clear_screen() -> void:
	_choice_busy = false
	_set_story_actions(false)
	($MarginContainer/ScrollContainer as ScrollContainer).scroll_vertical = 0
	for c in screen.get_children():
		screen.remove_child(c)
		c.queue_free()

# 继续按钮独立于 ScrollContainer，长事件和小窗口也能始终点击。
func _create_story_actions() -> void:
	_action_bar = PanelContainer.new()
	_action_bar.name = "StoryActions"
	_action_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_action_bar.offset_left = 12
	_action_bar.offset_right = -12
	_action_bar.offset_top = -62
	_action_bar.offset_bottom = -12
	_action_bar.z_index = 20
	_action_bar.add_theme_stylebox_override("panel", _style(C.panel, C.line, 3))
	add_child(_action_bar)
	_continue = _btn("看完剧情，继续人生 →", C.green, false, _advance_story)
	_continue.custom_minimum_size.y = 48
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	_action_bar.add_child(buttons)
	_next_dialogue = _btn("下一段 / 补全文字", C.txt, false, _next_story_beat)
	_next_dialogue.custom_minimum_size.x = 126
	buttons.add_child(_next_dialogue)
	buttons.add_child(_continue)
	for button in [_next_dialogue, _continue]:
		button.add_theme_stylebox_override("normal", _style(Color("10121d"), Color("bfbec7"), 0))
		button.add_theme_stylebox_override("hover", _style(Color("28283b"), Color("eee8c9"), 0))
		button.add_theme_stylebox_override("pressed", _style(Color("38364b"), Color("eee8c9"), 0))
		button.add_theme_stylebox_override("disabled", _style(Color("12131c"), Color("555664"), 0))
		for role in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(role, Color("efeee5"))
		button.add_theme_color_override("font_disabled_color", Color("777987"))
	_set_story_actions(false)

func _set_story_actions(show_actions: bool) -> void:
	if is_instance_valid(_action_bar):
		_action_bar.visible = show_actions
	$MarginContainer.offset_bottom = -68 if show_actions else 0
	if is_instance_valid(_leaf_layer):
		_leaf_layer.visible = not show_actions

func _process(_delta: float) -> void:
	if _choice_busy and is_instance_valid(_story) and _story.playing:
		_continue.text = "演出中 · %d 秒" % maxi(1, ceili(_story.duration - _story.elapsed))

func _on_story_finished() -> void:
	if not _choice_busy:
		return
	_continue.disabled = false
	_continue.text = "继续人生 →"
	_next_dialogue.disabled = true
	_continue.grab_focus()

func _next_story_beat() -> void:
	if _choice_busy and is_instance_valid(_story):
		_story.advance_dialogue()

func _advance_story() -> void:
	if not _choice_busy or _continue.disabled:
		return
	_continue.disabled = true
	_choice_busy = false
	gc.advance_after_choice(current_event)

func _scroll_to_story(stage: Control) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(stage) and stage == _story and _choice_busy:
		($MarginContainer/ScrollContainer as ScrollContainer).ensure_control_visible(stage)


# ==========================================================
# 标题页
# ==========================================================
func render_title() -> void:
	clear_screen()
	age_tag.text = "准备中"
	var card := _make_card()
	var vb := _cv(card)
	vb.add_child(_make_label("gamelife", C.green, 34, true, 5.0))
	vb.add_child(_make_label("肉鸽 · 文字向 · 人生模拟", C.dim, 12, false, 1.0))
	vb.add_child(_spacer(20))
	vb.add_child(_make_label("你将随机出生在一个地方，\n随机抽到一种出身，随机走上一条人生线。\n你唯一能带走的，是结局和成就。", C.txt, 13))
	vb.add_child(_spacer(22))
	vb.add_child(_btn("开 始 人 生", C.green, true, func(): gc.new_game()))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var dex_n: int = meta.get("endings", {}).size()
	var ach_n: int = meta.get("achievements", {}).size()
	row.add_child(_btn("结局图鉴 %d/%d" % [dex_n, DataLoader.endings().size()], C.dim, false, render_dex))
	row.add_child(_btn("成就 %d/%d" % [ach_n, DataLoader.achievements().size()], C.dim, false, render_ach))
	vb.add_child(row)
	screen.add_child(card)

func _on_game_started(s: GameState) -> void:
	render_roll(s)

# ==========================================================
# 掷骰页
# ==========================================================
func render_roll(s: GameState) -> void:
	clear_screen()
	var card := _make_card()
	var vb := _cv(card)
	vb.add_child(_make_label("正在为你掷骰……", C.dim, 13))
	vb.add_child(_spacer(14))

	var roll_list := VBoxContainer.new()
	roll_list.add_theme_constant_override("separation", 7)
	var items := [
		["出生地", "%s · %s" % [s.province, s.region]],
		["父母职业", s.parent_job.get("name", "")],
		["出生时辰", s.birth_hour.get("name", "")],
		["性 别", s.gender],
		["体 型", s.body.get("name", "")],
		["健康状况", s.health_type.get("name", "")],
	]
	for item in items:
		var ri := _roll_item(item[0], item[1])
		ri.modulate.a = 0.0
		roll_list.add_child(ri)
	vb.add_child(roll_list)

	var tier_wrap := VBoxContainer.new()
	tier_wrap.modulate.a = 0.0
	var tk := s.get_tier_key()
	var tcol: Color = {"lawanle": C.red, "npc": C.dim, "renshangren": C.cyan, "hang": C.yellow}.get(tk, C.green)
	tier_wrap.add_child(_make_label(s.tier.get("name", ""), tcol, 26, true, 3.0))
	tier_wrap.add_child(_make_label(s.tier.get("desc", ""), C.dim, 12))
	tier_wrap.add_child(_spacer(12))
	tier_wrap.add_child(_make_label(DataLoader.regions()[s.region].get("flavor", ""), C.dim, 12))
	tier_wrap.add_child(_make_label(s.parent_job.get("desc", ""), C.cyan, 11))
	tier_wrap.add_child(_make_label(s.birth_hour.get("desc", ""), C.cyan, 11))
	tier_wrap.add_child(_make_label(s.birth_dream, C.purple, 11))
	tier_wrap.add_child(_spacer(8))
	tier_wrap.add_child(_make_label("初始 智力%d 体质%d 魅力%d 运气%d 金钱%d" % [s.intl, s.health, s.charm, s.luck, s.money], C.green, 12))
	tier_wrap.add_child(_spacer(18))
	tier_wrap.add_child(_btn("开始这一生", C.green, true, func():
		s.age = 1
		s.step = 0
		render_main()
	))
	vb.add_child(tier_wrap)
	screen.add_child(card)

	# 动画
	var tw := create_tween()
	for i in range(items.size()):
		tw.tween_property(roll_list.get_child(i), "modulate:a", 1.0, 0.38).set_delay(0.26 * i)
	tw.tween_property(tier_wrap, "modulate:a", 1.0, 0.5).set_delay(0.42)

# ==========================================================
# 主游戏页
# ==========================================================
func render_main() -> void:
	_choice_busy = false
	var s := gc.state
	if s.age >= s.lifespan or s.health <= 0:
		gc.end_game()
		return
	age_tag.text = ""  # 年龄改由下方顶栏展示，清空右上角占位
	# 背景随时辰变化：一辈子被压缩成一天（清晨 → 正午 → 黄昏 → 深夜）
	UIAnim.set_time(_backdrop, UIAnim.time_for_age(s.age))
	if s.age <= 6 and s.family.is_empty():
		s.family = gc.pick(DataLoader.families())
		gc.apply_effects(s.family.get("effects", {}))
	if s.age >= 7 and s.age <= 12 and s.talent.is_empty():
		s.talent = gc.pick(DataLoader.talents())
		gc.apply_effects(s.talent.get("effects", {}))

	var ev := gc.pick_event()
	if ev.is_empty():
		gc.end_game()
		return
	current_event = ev
	clear_screen()

	# ① 顶栏：数值(六维) + 抽象度 + 年龄框
	screen.add_child(_render_status_bar(s))
	var tg := _render_tags(s)
	if tg.get_child_count() > 0:
		screen.add_child(tg)
	else:
		tg.free()

	# ② 事件
	var is_abs := s.line == "absurd" or s.abstract_val >= 86
	var use_alt := s.abstract_val >= 90
	var title: String = ev.get("altTitle", ev.get("title", "")) if (use_alt and ev.has("altTitle")) else ev.get("title", "")
	var text: String = ev.get("altText", ev.get("text", "")) if (use_alt and ev.has("altText")) else ev.get("text", "")
	var choices: Array = ev.get("altChoices", ev.get("choices", [])) if (use_alt and ev.has("altChoices")) else ev.get("choices", [])

	# 分镜必须使用屏幕上实际显示的事件文本（含抽象线替代文本）。
	current_event = ev.duplicate()
	current_event["title"] = title
	current_event["text"] = text

	var banner := ""
	if not s.family.is_empty() and s.age <= 7 and s.step == 0:
		banner += "【%s】%s\n" % [s.family.get("name", ""), s.family.get("desc", "")]
	if not s.talent.is_empty() and s.age == 7:
		banner += "【天赋觉醒 · %s】%s\n" % [s.talent.get("name", ""), s.talent.get("desc", "")]
	if not banner.is_empty():
		banner += "\n"

	var card := _make_card(is_abs)
	var vb := _cv(card)
	var stage_lbl := _make_label(_stage_name(s.age), C.dim, 10)
	var title_lbl := _make_label(title, C.pink if is_abs else C.yellow, 16, true, 0.5)
	var text_lbl := _make_label(banner + text, C.txt, 14)
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var event_head := HBoxContainer.new()
	stage_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_head.add_child(stage_lbl)
	event_head.add_child(_make_age_box(s.age))
	vb.add_child(event_head)
	vb.add_child(title_lbl)
	vb.add_child(text_lbl)
	screen.add_child(card)
	# ② 事件区动画：木牌「哐」地落下 → 正文逐字打字
	UIAnim.signboard_drop(card, 0.0)
	UIAnim.stagger_in([stage_lbl], 0.0, 0.16)
	UIAnim.stagger_in([title_lbl], 0.0, 0.22)
	UIAnim.typewriter(text_lbl, banner + text, 56.0, 0.44)

	# ③ 选项区动画：按钮依次弹入 + 悬浮/按下反馈
	var cb := VBoxContainer.new()
	cb.add_theme_constant_override("separation", 8)
	var btns: Array = []
	for c in choices:
		var b := _choice_btn(c, s)
		UIAnim.hook_button(b, false)
		if not b.disabled:
			b.pressed.connect(_on_choice.bind(c, b))
		cb.add_child(b)
		btns.append(b)
	screen.add_child(_make_label("选择 · 每一步都算数", C.dim, 11))
	screen.add_child(cb)
	UIAnim.choices_in(btns)

	# ④ 像素动画演出区（深色土槽 + 木框，选择后在此播放）
	anim_stage = _make_anim_stage()
	screen.add_child(_make_label("像素剧场 · 每个选择都是一段故事", C.dim, 11))
	screen.add_child(anim_stage)
	_story.configure(gc.state)
	_story.finished.connect(_on_story_finished)

func _on_choice(c: Dictionary, picked: Button = null) -> void:
	if _choice_busy:
		return
	_choice_busy = true
	if picked != null and is_instance_valid(picked):
		UIAnim.stamp(picked, C.green)
	for child in screen.get_children():
		if child is VBoxContainer:
			for btn in child.get_children():
				if btn is Button:
					btn.disabled = true
	var s := gc.state
	current_choice = c
	var before := _capture_core(s)
	_prev_core = before  # 下一次渲染时，顶栏数值从这里滚到新值
	gc.choose(c, current_event)
	var deltas := _diff_core(before, s)
	_play_choice_animation(deltas, str(c.get("result", "")))
	_set_story_actions(true)
	_next_dialogue.disabled = false
	_next_dialogue.grab_focus()
	_continue.disabled = true
	_continue.text = "剧情演出中…"
	_scroll_to_story(anim_stage)

func _on_event_picked(_s: GameState, _ev: Dictionary) -> void:
	pass

func _on_choice_resolved(_s: GameState, _result_text: String) -> void:
	# 结果文本改由底部像素动画演出区展示，此处不再往事件卡追加
	pass

func _on_phase_advanced(_s: GameState) -> void:
	render_main()

# ==========================================================
# 结局页
# ==========================================================
func _on_game_ended(s: GameState, ending: Dictionary, info: Dictionary) -> void:
	render_ending(s, ending, info)

func render_ending(s: GameState, ending: Dictionary, info: Dictionary) -> void:
	clear_screen()
	age_tag.text = "结局"
	var rc: Color = {
		"hang": C.yellow, "renshangren": C.cyan, "npc": C.dim, "lawanle": C.red
	}.get(info.rating, C.green)
	var card := _make_panel()
	var vb := _cv(card)
	vb.add_child(_make_label("%s · %s · %s · %s" % [s.province, s.gender, s.tier.get("name", ""), "正常线" if s.line == "normal" else "抽象线"], C.dim, 11, false, 2.0))
	vb.add_child(_spacer(10))
	vb.add_child(_make_label(ending.get("name", ""), rc, 27, true, 2.0))
	vb.add_child(_make_label("评 级  %s" % _rank_name(info.rating), rc, 12, true, 2.0))
	vb.add_child(_spacer(15))
	vb.add_child(_make_label(ending.get("desc", ""), C.txt, 13))
	vb.add_child(_spacer(14))
	var grid := GridContainer.new()
	grid.columns = 2
	for item in [["寿命", "%d 岁" % s.age], ["死因", s.death_reason],
		["智力", str(s.intl)], ["体质", str(s.health)],
		["魅力", str(s.charm)], ["运气", str(s.luck)],
		["金钱", str(s.money)], ["抽象度", str(s.abstract_val)],
		["综合评分", str(int(info.score))]]:
		grid.add_child(_make_label(item[0], C.dim, 12))
		grid.add_child(_make_label(item[1], C.txt, 12))
	vb.add_child(grid)
	if info.get("first_time", false):
		vb.add_child(_spacer(14))
		vb.add_child(_make_label("★ 新结局解锁！ 图鉴 %d/%d" % [meta.get("endings", {}).size(), DataLoader.endings().size()], C.yellow, 12))
	vb.add_child(_spacer(18))
	vb.add_child(_btn("再来一次", C.green, true, func(): gc.new_game()))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_btn("结局图鉴", C.dim, false, render_dex))
	row.add_child(_btn("返回首页", C.dim, false, render_title))
	vb.add_child(row)
	screen.add_child(card)

# ==========================================================
# 图鉴页
# ==========================================================
func render_dex() -> void:
	clear_screen()
	age_tag.text = "图鉴"
	var card := _make_card()
	var vb := _cv(card)
	vb.add_child(_make_label("结局图鉴 %d/%d" % [meta.get("endings", {}).size(), DataLoader.endings().size()], C.green, 15, true))
	for group in [
		["正常线结局", DataLoader.endings().filter(func(e): return e.get("line") == "normal")],
		["抽象线结局", DataLoader.endings().filter(func(e): return e.get("line") == "absurd")],
		["隐藏结局", DataLoader.endings().filter(func(e): return e.get("hidden", false))],
	]:
		vb.add_child(_spacer(10))
		vb.add_child(_make_label(group[0], C.dim, 12, false, 2.0))
		var grid := GridContainer.new()
		grid.columns = 2
		for e in group[1]:
			var got: bool = meta.get("endings", {}).has(e.get("id"))
			var n: String = str(e.get("name", "")) if got else "？ ？ ？"
			var col := C.purple if (got and e.get("hidden", false)) else (C.txt if got else C.dim)
			grid.add_child(_make_label(n, col, 12, true))
		vb.add_child(grid)
	vb.add_child(_spacer(16))
	vb.add_child(_btn("返回", C.dim, false, func():
		if gc.state and gc.state.age > 0: render_main()
		else: render_title()))
	screen.add_child(card)

# ==========================================================
# 成就页
# ==========================================================
func render_ach() -> void:
	clear_screen()
	age_tag.text = "成就"
	var card := _make_card()
	var vb := _cv(card)
	var an: int = meta.get("achievements", {}).size()
	vb.add_child(_make_label("成就 %d/%d" % [an, DataLoader.achievements().size()], C.green, 15, true))
	vb.add_child(_spacer(12))
	for a in DataLoader.achievements():
		var on: bool = meta.get("achievements", {}).has(a.get("name"))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(_make_label("🏆" if on else "🔒", C.txt if on else C.dim, 17))
		var ib := VBoxContainer.new()
		ib.add_child(_make_label(a.get("name", ""), C.yellow if on else C.dim, 12, true))
		ib.add_child(_make_label(a.get("desc", ""), C.dim, 11))
		row.add_child(ib)
		vb.add_child(row)
	vb.add_child(_spacer(16))
	vb.add_child(_btn("返回", C.dim, false, render_title))
	screen.add_child(card)

# ==========================================================
# UI 辅助
# ==========================================================
## 卡片容器：PanelContainer > VBoxContainer，返回 Panel
func _make_card(absurd: bool = false) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bc := C.green if not absurd else C.purple
	var s := _style(C.panel, bc, 4)
	s.content_margin_left = 16; s.content_margin_top = 18
	s.content_margin_right = 16; s.content_margin_bottom = 18
	p.add_theme_stylebox_override("panel", s)
	var vb := VBoxContainer.new()
	p.add_child(vb)
	return p

func _make_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s := _style(C.panel, C.line, 4)
	s.content_margin_left = 14; s.content_margin_top = 14
	s.content_margin_right = 14; s.content_margin_bottom = 14
	p.add_theme_stylebox_override("panel", s)
	var vb := VBoxContainer.new()
	p.add_child(vb)
	return p

## 获取卡片内部 VBoxContainer 用于添加子节点
func _cv(card: PanelContainer) -> VBoxContainer:
	return card.get_child(0) as VBoxContainer

func _style(bg: Color, border: Color, r: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg; s.border_color = border
	s.set_border_width_all(1); s.set_corner_radius_all(int(r))
	return s

func _make_label(text: String, col: Color, sz: int, bold: bool = false, ls: float = 0.0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", sz)
	if ls > 0:
		l.add_theme_constant_override("spacing", int(ls))
	return l

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func _btn(text: String, col: Color, primary: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_stylebox_override("normal", _style(C.panel, col, 3))
	b.add_theme_stylebox_override("hover", _style(C.panel2, col, 3))
	b.add_theme_stylebox_override("pressed", _style(C.panel2, col, 3))
	b.add_theme_color_override("font_color", col)
	b.add_theme_font_size_override("font_size", 14)
	b.pressed.connect(cb)
	UIAnim.hook_button(b, primary)
	return b

func _choice_btn(c: Dictionary, s: GameState) -> Button:
	var b := Button.new()
	b.text = "▸ " + str(c.get("label", ""))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var col := C.txt
	if c.has("require"):
		for k in c["require"]:
			if s.get_attr(k) < int(c["require"][k]):
				col = C.red
				b.text += "  (%s需 %d)" % [_attr_cn(k), int(c["require"][k])]
				b.disabled = true
				break
	b.add_theme_stylebox_override("normal", _style(C.panel, C.line, 4))
	b.add_theme_stylebox_override("hover", _style(C.panel2, C.green, 4))
	b.add_theme_stylebox_override("pressed", _style(C.panel2, C.green, 4))
	b.add_theme_stylebox_override("disabled", _style(C.panel, C.line, 4))
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_disabled_color", Color(col.r, col.g, col.b, 0.45))
	b.add_theme_font_size_override("font_size", 14)
	return b

func _roll_item(key: String, val: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s := _style(C.panel, C.line, 3)
	s.content_margin_left = 12; s.content_margin_top = 9
	s.content_margin_right = 12; s.content_margin_bottom = 9
	p.add_theme_stylebox_override("panel", s)
	var h := HBoxContainer.new()
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lk := _make_label(key, C.dim, 13)
	lk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(lk)
	h.add_child(_make_label(val, C.yellow, 13, true))
	p.add_child(h)
	return p

func _render_stats(s: GameState) -> GridContainer:
	var c_up: Color = UIAnim.UP
	var c_down: Color = UIAnim.DOWN
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var rows := [
		["🧠 智力", s.intl, "int"], ["💪 体质", s.health, "health"], ["✨ 魅力", s.charm, "charm"],
		["🍀 运气", s.luck, "luck"], ["💰 金钱", s.money, "money"], ["⏳ 寿命", s.lifespan, "lifespan"]
	]
	for i in range(rows.size()):
		var row: Array = rows[i]
		var key: String = str(row[0])
		var val: int = int(row[1])
		var ak: String = str(row[2])
		var from_v: int = int(_prev_core.get(ak, 0))
		var d: int = val - from_v
		var p := PanelContainer.new()
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var st := _style(C.panel, C.line, 3)
		st.content_margin_left = 7; st.content_margin_top = 5
		st.content_margin_right = 7; st.content_margin_bottom = 5
		p.add_theme_stylebox_override("panel", st)
		var h := HBoxContainer.new()
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_theme_constant_override("separation", 2)
		var lk := _make_label(key, C.dim, 11)
		lk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lk.clip_text = true
		h.add_child(lk)
		# 增减标记（选择后闪一下 +3 / -2）
		var dl := _make_label("", c_up, 10, true)
		dl.custom_minimum_size = Vector2(26, 0)
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		dl.clip_text = true
		h.add_child(dl)
		var vl := _make_label(str(val), C.txt, 12, true)
		vl.custom_minimum_size = Vector2(30, 0)
		vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(vl)
		p.add_child(h)
		grid.add_child(p)

		# ① 数值区动画：卡片错峰弹入 + 数字从旧值滚到新值 + 增减标记闪烁
		UIAnim.stat_card_in(p, i)
		var ncol: Color = C.txt
		if d > 0:
			ncol = C.green
		elif d < 0:
			ncol = C.red
		UIAnim.count_up(vl, from_v, val, ncol, 0.07 * float(i))
		if d != 0:
			UIAnim.delta_flash(dl, ("+%d" % d) if d > 0 else str(d),
				c_up if d > 0 else c_down, 0.07 * float(i))
	return grid

func _render_abstract(s: GameState) -> VBoxContainer:
	var vb := VBoxContainer.new()
	var a := s.abstract_val
	var prev_a: int = int(_prev_core.get("abstract", 0))
	var label := "正常人类" if a < 31 else ("有点东西" if a < 61 else ("精神状态受关注" if a < 86 else "已经成佛了"))
	var col := C.pink if a >= 61 else C.cyan
	var head := HBoxContainer.new()
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hl := _make_label("抽象度 %s" % label, col, 11, true)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hl)
	var nl := _make_label("%d/100" % prev_a, C.dim, 11)
	head.add_child(nl)
	vb.add_child(head)
	# 木框凹槽 > 行容器 > 填充条：填充条靠 custom_minimum_size 控宽，
	# 不会被 PanelContainer 拉满（原实现直接把条塞进 PanelContainer，视觉上永远 100%）
	var track := PanelContainer.new()
	track.custom_minimum_size = Vector2(0, 13)
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tsb := _style(Color(0.239, 0.180, 0.125), C.line, 2)
	tsb.set_border_width_all(2)
	tsb.content_margin_left = 2; tsb.content_margin_right = 2
	tsb.content_margin_top = 2; tsb.content_margin_bottom = 2
	track.add_theme_stylebox_override("panel", tsb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	track.add_child(row)
	var fill := PanelContainer.new()
	fill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	fill.custom_minimum_size = Vector2(float(maxi(1, prev_a)) * 4.0, 0)
	fill.add_theme_stylebox_override("panel", _style(col, Color(0, 0, 0, 0), 1))
	row.add_child(fill)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	vb.add_child(track)

	# ① 数值区动画：抽象度条生长 + 数值滚动
	UIAnim.bar_grow(fill, float(maxi(1, prev_a) * 4), float(maxi(1, a) * 4), 0.22)
	if prev_a != a:
		var tw := nl.create_tween()
		tw.tween_method(func(v: float): nl.text = "%d/100" % int(round(v)),
			float(prev_a), float(a), 0.56).set_delay(0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return vb

func _render_tags(s: GameState) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 5)
	var bad := ["债台高筑", "社恐", "网瘾"]
	for t in s.tags:
		var ts := str(t)
		if ts.begins_with("_") or not s.tags[t]:
			continue
		var tp := PanelContainer.new()
		var st := _style(C.panel2, C.line, 2)
		st.content_margin_left = 7; st.content_margin_top = 2
		st.content_margin_right = 7; st.content_margin_bottom = 2
		tp.add_theme_stylebox_override("panel", st)
		tp.add_child(_make_label(ts, C.red if bad.has(ts) else C.cyan, 11))
		hb.add_child(tp)
	return hb

func _stage_name(age: int) -> String:
	if age <= 6: return "童年"
	if age <= 12: return "小学"
	if age <= 18: return "少年"
	if age <= 25: return "青年"
	if age <= 40: return "成年"
	if age <= 60: return "中年"
	return "晚年"

func _rank_name(r: String) -> String:
	return {"hang": "夯", "renshangren": "人上人", "npc": "NPC", "lawanle": "拉完了"}.get(r, r)

func _attr_cn(k: String) -> String:
	return {"int": "智力", "health": "体质", "charm": "魅力", "luck": "运气", "money": "金钱"}.get(k, k)

# ==========================================================
# 顶栏（数值 + 年龄框）
# ==========================================================
const ATTR_CN := {
	"int": "智力", "health": "体质", "charm": "魅力",
	"luck": "运气", "money": "金钱", "abstract": "抽象度", "lifespan": "寿命"
}

func _render_status_bar(s: GameState) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	left.add_child(_render_stats(s))
	left.add_child(_render_abstract(s))
	hb.add_child(left)


	return hb

func _make_age_box(age: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var st := _style(C.panel2, C.yellow, 4)
	st.content_margin_left = 12; st.content_margin_top = 8
	st.content_margin_right = 12; st.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", st)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.add_child(_make_label("年龄", C.dim, 10, false, 1.0))
	v.add_child(_make_label("%d" % age, C.yellow, 20, true))
	p.add_child(v)
	return p

# ==========================================================
# 选择后的“像素动画”演出
# ==========================================================
func _make_anim_stage() -> Control:
	var c := StoryStage.new()
	c.custom_minimum_size = Vector2(0, 420)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_story = c
	return c

## 记录用于对比的核心数值快照
func _capture_core(s: GameState) -> Dictionary:
	return {
		"int": s.intl, "health": s.health, "charm": s.charm, "luck": s.luck,
		"money": s.money, "abstract": s.abstract_val, "lifespan": s.lifespan
	}

## 对比得到本次选择的属性增减量列表
func _diff_core(before: Dictionary, s: GameState) -> Array:
	var after := _capture_core(s)
	var out: Array = []
	for k in after.keys():
		var kk: String = str(k)
		var d: int = int(after[kk]) - int(before.get(kk, after[kk]))
		if d != 0:
			out.append({"key": kk, "name": ATTR_CN.get(kk, kk), "delta": d})
	return out

## 选择后演出：极性闪光 + 主题 VFX + 结果文本 + 浮动增减数字
func _play_choice_animation(deltas: Array, result_text: String) -> void:
	if is_instance_valid(_story):
		_story.configure(gc.state)
		_story.play(current_event, current_choice, deltas)

# ==========================================================
# 选项特征 → 动画类型分发
# ==========================================================
## 优先级：选项 anim 字段 > 事件级专属(字段/精选表/规则) > 净收益特殊 > 单项属性动画
## 事件级动画存在时，只补最强 1 个属性动画（避免舞台级与局部效果视觉打架）
## 性能预算：最多 ChoiceVFX.MAX_LAYERS 个；无匹配时回退 spark
func _pick_anims(deltas: Array, choice: Dictionary, event: Dictionary) -> Array:
	var out: Array = []
	# 作者显式指定优先（数据里写 "anim": "coin" 即可强制指定）
	if choice.has("anim"):
		out.append(str(choice["anim"]))

	# 事件级专属动画：eventAnim 字段 > EVENT_ANIM 精选表 > 规则兜底(A0→glitch / lucky→gamble)
	var ev_anim: String = ChoiceVFX.resolve_event_anim(event)
	var has_ev := not ev_anim.is_empty()
	if has_ev and not out.has(ev_anim):
		out.append(ev_anim)

	var best := {}
	for d in deltas:
		best[str(d["key"])] = int(d["delta"])

	# 净收益（不含抽象度）
	var net := 0
	for k in best:
		if str(k) != "abstract":
			net += int(best[k])

	# 单项属性动画，按变化幅度从大到小排
	var single: Array = []
	if int(best.get("money", 0)) > 0:
		single.append({"t": "coin", "m": absi(int(best["money"]))})
	elif int(best.get("money", 0)) < 0:
		single.append({"t": "bill", "m": absi(int(best["money"]))})
	if int(best.get("int", 0)) > 0:
		single.append({"t": "brain", "m": absi(int(best["int"]))})
	if int(best.get("charm", 0)) > 0:
		single.append({"t": "heart", "m": absi(int(best["charm"]))})
	if int(best.get("health", 0)) > 0:
		single.append({"t": "muscle", "m": absi(int(best["health"]))})
	elif int(best.get("health", 0)) < 0:
		single.append({"t": "decay", "m": absi(int(best["health"]))})
	if int(best.get("luck", 0)) > 0:
		single.append({"t": "clover", "m": absi(int(best["luck"]))})
	if absi(int(best.get("abstract", 0))) >= 4:
		single.append({"t": "psych", "m": absi(int(best["abstract"]))})
	if int(best.get("lifespan", 0)) != 0:
		single.append({"t": "hourglass", "m": 5})
	single.sort_custom(func(a, b): return int(a["m"]) > int(b["m"]))

	if has_ev:
		# 事件级动画主导：舞台级重效果独占；其余补最强 1 个属性动画
		if not ChoiceVFX.is_solo(ev_anim) and not single.is_empty():
			out.append(str(single[0]["t"]))
	else:
		if net >= 6:
			out.append("confetti")
		elif net <= -6:
			out.append("wilt")
		for it in single:
			out.append(str(it["t"]))

	# 去重 + 限量
	var uniq: Array = []
	for a in out:
		if not uniq.has(a):
			uniq.append(a)
	if uniq.is_empty():
		uniq.append("spark")
	return uniq.slice(0, ChoiceVFX.MAX_LAYERS)
