## main.gd — UI 控制器，管理所有游戏屏幕
## 像素复古风主题，用 Godot 原生 UI 节点还原 HTML 版的视觉
extends Control

const GameController := preload("res://scripts/game_controller.gd")
const GameState := preload("res://scripts/game_state.gd")
const DataLoader := preload("res://scripts/data_loader.gd")
const ChoiceVFX := preload("res://scripts/vfx.gd")

# ---- 颜色 ----
const C := {
	"panel": Color(0.071, 0.086, 0.110, 1),
	"panel2": Color(0.090, 0.110, 0.141, 1),
	"line": Color(0.141, 0.173, 0.220, 1),
	"txt": Color(0.788, 0.831, 0.886, 1),
	"dim": Color(0.400, 0.451, 0.541, 1),
	"green": Color(0.224, 1.0, 0.533, 1),
	"cyan": Color(0.310, 0.890, 1.0, 1),
	"pink": Color(1.0, 0.373, 0.824, 1),
	"yellow": Color(1.0, 0.827, 0.310, 1),
	"red": Color(1.0, 0.302, 0.369, 1),
	"purple": Color(0.627, 0.420, 1.0, 1),
}

var screen: VBoxContainer
var age_tag: Label
var gc: GameController
var meta: Dictionary
var current_event: Dictionary = {}
var current_choice: Dictionary = {}  # 本次选择的选项快照（供动画分发读取特征）
var anim_stage: Control  # 底部像素动画演出区（每次渲染重建）

func _ready() -> void:
	DataLoader.ensure_loaded()
	screen = $MarginContainer/ScrollContainer/VBox/Screen
	age_tag = $MarginContainer/ScrollContainer/VBox/TopBar/AgeTag
	$MarginContainer/ScrollContainer/VBox/Footer.modulate = C.dim
	gc = GameController.new()
	gc.init()
	meta = gc.meta
	gc.game_started.connect(_on_game_started)
	gc.event_picked.connect(_on_event_picked)
	gc.choice_resolved.connect(_on_choice_resolved)
	gc.phase_advanced.connect(_on_phase_advanced)
	gc.game_ended.connect(_on_game_ended)
	render_title()

func clear_screen() -> void:
	for c in screen.get_children():
		c.queue_free()

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
	var s := gc.state
	if s.age >= s.lifespan or s.health <= 0:
		gc.end_game()
		return
	age_tag.text = ""  # 年龄改由下方顶栏展示，清空右上角占位
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

	# ② 事件
	var is_abs := s.line == "absurd" or s.abstract_val >= 86
	var use_alt := s.abstract_val >= 90
	var title: String = ev.get("altTitle", ev.get("title", "")) if (use_alt and ev.has("altTitle")) else ev.get("title", "")
	var text: String = ev.get("altText", ev.get("text", "")) if (use_alt and ev.has("altText")) else ev.get("text", "")
	var choices: Array = ev.get("altChoices", ev.get("choices", [])) if (use_alt and ev.has("altChoices")) else ev.get("choices", [])

	var banner := ""
	if not s.family.is_empty() and s.age <= 7 and s.step == 0:
		banner += "【%s】%s\n" % [s.family.get("name", ""), s.family.get("desc", "")]
	if not s.talent.is_empty() and s.age == 7:
		banner += "【天赋觉醒 · %s】%s\n" % [s.talent.get("name", ""), s.talent.get("desc", "")]
	if not banner.is_empty():
		banner += "\n"

	var card := _make_card(is_abs)
	var vb := _cv(card)
	vb.add_child(_make_label(_stage_name(s.age), C.dim, 10))
	vb.add_child(_make_label(title, C.pink if is_abs else C.yellow, 16, true, 0.5))
	vb.add_child(_make_label(banner + text, C.txt, 14))
	screen.add_child(card)

	# ③ 选项
	var cb := VBoxContainer.new()
	cb.add_theme_constant_override("separation", 8)
	for c in choices:
		var b := _choice_btn(c, s)
		if not b.disabled:
			b.pressed.connect(_on_choice.bind(c))
		cb.add_child(b)
	screen.add_child(cb)

	# ④ 像素动画演出区（选择后在此播放）
	anim_stage = _make_anim_stage()
	screen.add_child(anim_stage)

func _on_choice(c: Dictionary) -> void:
	for child in screen.get_children():
		if child is VBoxContainer:
			for btn in child.get_children():
				if btn is Button:
					btn.disabled = true
	var s := gc.state
	current_choice = c
	var before := _capture_core(s)
	gc.choose(c, current_event)
	var deltas := _diff_core(before, s)
	_play_choice_animation(deltas, str(c.get("result", "")))
	await get_tree().create_timer(1.35).timeout
	gc.advance_after_choice(current_event)

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
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for row in [["🧠 智力", s.intl], ["💪 体质", s.health], ["✨ 魅力", s.charm],
		["🍀 运气", s.luck], ["💰 金钱", s.money], ["⏳ 寿命", s.lifespan]]:
		var p := PanelContainer.new()
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var st := _style(C.panel, C.line, 3)
		st.content_margin_left = 8; st.content_margin_top = 5
		st.content_margin_right = 8; st.content_margin_bottom = 5
		p.add_theme_stylebox_override("panel", st)
		var h := HBoxContainer.new()
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var lk := _make_label(row[0], C.dim, 12)
		lk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(lk)
		h.add_child(_make_label(str(row[1]), C.txt, 12, true))
		p.add_child(h)
		grid.add_child(p)
	return grid

func _render_abstract(s: GameState) -> VBoxContainer:
	var vb := VBoxContainer.new()
	var a := s.abstract_val
	var label := "正常人类" if a < 31 else ("有点东西" if a < 61 else ("精神状态受关注" if a < 86 else "已经成佛了"))
	var col := C.pink if a >= 61 else C.cyan
	var head := HBoxContainer.new()
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hl := _make_label("抽象度 %s" % label, col, 11, true)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hl)
	head.add_child(_make_label("%d/100" % a, C.dim, 11))
	vb.add_child(head)
	var bar_bg := PanelContainer.new()
	bar_bg.custom_minimum_size = Vector2(0, 9)
	bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_bg.add_theme_stylebox_override("panel", _style(Color(0.039, 0.051, 0.067), Color(0, 0, 0, 0), 2))
	var fill := PanelContainer.new()
	fill.custom_minimum_size = Vector2(maxi(1, a) * 5, 9)
	fill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	fill.add_theme_stylebox_override("panel", _style(col, Color(0, 0, 0, 0), 2))
	bar_bg.add_child(fill)
	vb.add_child(bar_bg)
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

	hb.add_child(_make_age_box(s.age))
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
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 130)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	if anim_stage == null or not is_instance_valid(anim_stage):
		return
	for ch in anim_stage.get_children():
		ch.queue_free()

	var w := anim_stage.size.x
	if w <= 0.0:
		w = 320.0
	var h := anim_stage.size.y
	if h <= 0.0:
		h = 130.0
	var cx := w * 0.5

	var net := 0
	for d in deltas:
		if str(d["key"]) != "abstract":
			net += int(d["delta"])
	var col := C.green if net > 0 else (C.red if net < 0 else C.cyan)

	# 1. 全区域极性闪光（最底层）
	var flash := ColorRect.new()
	flash.color = Color(col.r, col.g, col.b, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anim_stage.add_child(flash)
	var t0 := create_tween()
	t0.tween_property(flash, "color:a", 0.20, 0.12)
	t0.tween_property(flash, "color:a", 0.0, 0.42)
	t0.finished.connect(func():
		if is_instance_valid(flash):
			flash.queue_free())

	# 2. 主题 VFX：每个选项"相应的动画"（按本次选择特征分发，最多 3 层）
	var anims := _pick_anims(deltas, current_choice, current_event)
	var new_tags: Array = []
	for t in current_choice.get("tags", []):
		if gc.state.has_tag(str(t)):
			new_tags.append(str(t))
	ChoiceVFX.play(anim_stage, anims, new_tags, C)

	# 3. 结果文本（最上层）
	if not result_text.is_empty():
		var rt := _make_label(result_text, C.txt, 13, true)
		rt.position = Vector2(12, 8)
		rt.custom_minimum_size = Vector2(w - 24, 0)
		rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rt.modulate.a = 0.0
		anim_stage.add_child(rt)
		var t1 := create_tween()
		t1.tween_property(rt, "modulate:a", 1.0, 0.18)

	# 4. 浮动增减数字（精确信息层，位于主题 VFX 之上）
	var y0 := 48.0
	for i in range(deltas.size()):
		var d: Dictionary = deltas[i]
		var dv := int(d["delta"])
		var dcol := C.green if dv > 0 else C.red
		var lbl := _make_label("%+d %s" % [dv, str(d["name"])], dcol, 15, true)
		lbl.position = Vector2(cx - 46.0 + float(i % 3 - 1) * 70.0, y0)
		lbl.modulate.a = 0.0
		anim_stage.add_child(lbl)
		var tp := create_tween()
		tp.set_parallel(true)
		tp.tween_property(lbl, "modulate:a", 1.0, 0.15).set_delay(0.06 * i)
		tp.tween_property(lbl, "position:y", y0 - 24.0, 0.7).set_delay(0.06 * i)
		var tf := create_tween()
		tf.tween_property(lbl, "modulate:a", 0.0, 0.3).set_delay(0.06 * i + 0.55)

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
