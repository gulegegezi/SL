## main.gd — UI 控制器，管理所有游戏屏幕
## 像素复古风主题，用 Godot 原生 UI 节点还原 HTML 版的视觉
extends Control

const GameController := preload("res://scripts/game_controller.gd")
const GameState := preload("res://scripts/game_state.gd")
const DataLoader := preload("res://scripts/data_loader.gd")
const ComicDirector := preload("res://scripts/comic_director.gd")
const ComicPage := preload("res://scripts/comic_page.gd")
const ComicTheme := preload("res://scripts/comic_theme.gd")
const AudioFX := preload("res://scripts/audio_fx.gd")
const CrtOverlay := preload("res://scripts/crt_overlay.gd")
const ComicArchive := preload("res://scripts/comic_archive.gd")

# ---- 颜色 ----
const C := {
	"panel": Color(0.043, 0.106, 0.117, 1),
	"panel2": Color(0.063, 0.161, 0.173, 1),
	"line": Color(0.110, 0.290, 0.298, 1),
	"txt": Color(0.914, 0.875, 0.788, 1),
	"dim": Color(0.498, 0.651, 0.639, 1),
	"green": Color(0.435, 0.827, 0.769, 1),
	"cyan": Color(0.663, 0.894, 0.871, 1),
	"pink": Color(0.788, 0.627, 0.659, 1),
	"yellow": Color(0.847, 0.702, 0.416, 1),
	"red": Color(0.824, 0.141, 0.173, 1),
	"purple": Color(0.624, 0.714, 0.788, 1),
}

var screen: VBoxContainer
var age_tag: Label
var gc: GameController
var meta: Dictionary
var current_event: Dictionary = {}
# ---- 漫画分镜状态 ----
var _comic: Dictionary = {}      # 本局的分镜参数（每局随机）
var _page_no: int = 0            # 话数
var _skipped: Array = []         # 待合并为「提笔带过」的年份
var _last_result: String = ""    # 最近一次选择的结果文案
var _busy: bool = false
# ---- 竖向滚动的漫画流 ----
var _strip: bool = false
var _strip_pages: VBoxContainer = null
var _blanks: Array = []
var _status_node: Control = null
var _status_layer: PanelContainer = null
var _status_box: VBoxContainer = null
var _action_layer: PanelContainer = null
var _action_box: VBoxContainer = null
var _action_scroll: ScrollContainer
var _scroll: ScrollContainer = null
var _history: Array = []
var _after_choice := false
var _restoring := false
var _advance_busy := false
var _scroll_tween: Tween
var _reader_tools: HBoxContainer
var archive_path := ComicArchive.RUN_PATH
var autosave_enabled := true
var _completed := false
var _readonly_archive := false

func _ready() -> void:
	AudioFX.play_music(self, "title")
	DataLoader.ensure_loaded()
	screen = $MarginContainer/ScrollContainer/VBox/Screen
	age_tag = $MarginContainer/ScrollContainer/VBox/TopBar/AgeTag
	_scroll = $MarginContainer/ScrollContainer
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = false
	_scroll.scroll_deadzone = 10
	_scroll.gui_input.connect(_reader_input)
	_build_action_layer()
	$MarginContainer/ScrollContainer/VBox/Footer.modulate = C.dim
	gc = GameController.new()
	gc.init()
	meta = gc.meta
	gc.game_started.connect(_on_game_started)
	gc.event_picked.connect(_on_event_picked)
	gc.choice_resolved.connect(_on_choice_resolved)
	gc.phase_advanced.connect(_on_phase_advanced)
	gc.game_ended.connect(_on_game_ended)
	# CRT 叠层最后加，保证盖在内容之上
	add_child(CrtOverlay.new())
	resized.connect(_layout_reader)
	render_title()

func clear_screen() -> void:
	for c in screen.get_children():
		c.queue_free()
	_strip = false
	if _scroll_tween != null: _scroll_tween.kill()
	_blanks.clear()
	_strip_pages = null
	_status_node = null
	if _status_layer != null:
		_status_layer.visible = false
	if _action_layer != null:
		_action_layer.visible = false
		for c in _action_box.get_children():
			c.queue_free()
	var mc := get_node_or_null("MarginContainer")
	if mc != null:
		mc.add_theme_constant_override("margin_bottom", 24)
		mc.add_theme_constant_override("margin_top", 10)
	if _reader_tools != null: _reader_tools.hide()
	$MarginContainer/ScrollContainer/VBox/TopBar.show()


## 底部固定操作条：选项不跟着漫画滚走
func _build_action_layer() -> void:
	_action_layer = PanelContainer.new()
	_action_layer.visible = false
	_action_layer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_action_layer.offset_left = 8
	_action_layer.offset_right = -8
	_action_layer.offset_top = -196
	_action_layer.offset_bottom = -8
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(ComicTheme.INK, 0.95)
	sb.border_color = Color(ComicTheme.CREAM, 0.75)
	sb.set_border_width_all(2)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_action_layer.add_theme_stylebox_override("panel", sb)
	_action_box = VBoxContainer.new()
	_action_box.add_theme_constant_override("separation", 6)
	_action_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_scroll = ScrollContainer.new()
	_action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_action_scroll.follow_focus = true
	_action_scroll.add_child(_action_box)
	_action_layer.add_child(_action_scroll)
	add_child(_action_layer)

	# 固定状态条：数值不跟着漫画滚走
	_status_layer = PanelContainer.new()
	_status_layer.visible = false
	_status_layer.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_status_layer.offset_left = 8
	_status_layer.offset_right = -8
	_status_layer.offset_top = 8
	_status_layer.offset_bottom = 66
	_status_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_layer.add_theme_stylebox_override("panel", _status_style())
	_status_box = VBoxContainer.new()
	_status_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_layer.add_child(_status_box)
	add_child(_status_layer)
	_reader_tools = HBoxContainer.new()
	_reader_tools.add_theme_constant_override("separation", 8)
	_reader_tools.position = Vector2(14, 10)
	var name_label := _ink_label("人生未完 / LIFE IN INK", ComicTheme.CREAM, 13, true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reader_tools.add_child(name_label)
	for title in ["存档", "书签"]:
		var button := Button.new()
		button.text = title
		button.add_theme_font_override("font", ComicTheme.font_body())
		button.pressed.connect(save_current if title == "存档" else _return_to_title)
		_reader_tools.add_child(button)
	add_child(_reader_tools)
	_reader_tools.hide()
	_status_layer.offset_top = 48
	_status_layer.offset_bottom = 115

# ==========================================================
# 标题页
# ==========================================================
func render_title() -> void:
	clear_screen()
	age_tag.text = "漫画人生 · 整合版"
	var card := _make_card()
	var vb := _cv(card)
	vb.add_child(_make_label("折痕与歪楼", C.green, 30, true, 2.0))
	vb.add_child(_make_label("把一生，画成一本漫画", C.dim, 14, false, 1.0))
	vb.add_child(_spacer(20))
	vb.add_child(_make_label("从第一声啼哭，到最后一页留白。\n向下翻阅，选择、相遇和旧事逐格成画。\n每一生约 18–24 个重点事件，支线在其中相遇。", C.txt, 13))
	vb.add_child(_spacer(22))
	vb.add_child(_btn("折痕与歪楼 · 开始新的一生", C.green, true, func(): _open_life_comic(false)))
	if FileAccess.file_exists("user://life_comic_v1.save"):
		vb.add_child(_btn("继续阅读 · 上次的漫画书签", C.cyan, true, func(): _open_life_comic(true)))
	vb.add_child(_btn("从第一声开始 · 加长出生序章", C.dim, false, func():
		get_tree().set_meta("life_comic_prologue", true)
		_open_life_comic(false)))
	vb.add_child(_btn("完结漫画书架", C.dim, false, render_comic_shelf))
	vb.add_child(_btn("附录 · 早期版本与图鉴", C.dim, false, render_legacy_menu))
	vb.add_child(_wrap_label("每一生有不同的留白。健康改变篇幅，选择留下性格。\n向下阅读，走过的年份将逐格成画。", C.dim, 12))
	screen.add_child(card)

func render_legacy_menu() -> void:
	clear_screen()
	var card := _make_card()
	var vb := _cv(card)
	vb.add_child(_make_label("附录 · 制作沿革", C.green, 24, true))
	vb.add_child(_wrap_label("主线已整合旧事件与跨年龄支线。这里保留早期规则下的玩法与旧存档。", C.dim, 13))
	vb.add_child(_btn("早期短篇 · 14–20 次抉择", C.dim, false, func(): gc.new_game()))
	vb.add_child(_btn("早期长篇 · 原版数值规则", C.dim, false, func(): gc.new_game(false)))
	if not ComicArchive.load_run(archive_path).is_empty(): vb.add_child(_btn("继续早期版本存档", C.cyan, false, resume_saved))
	vb.add_child(_btn("早期版本完结书架", C.dim, false, render_books))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var dex_n: int = meta.get("endings", {}).size()
	var ach_n: int = meta.get("achievements", {}).size()
	row.add_child(_btn("结局图鉴 %d/%d" % [dex_n, DataLoader.endings().size()], C.dim, false, render_dex))
	row.add_child(_btn("成就 %d/%d" % [ach_n, DataLoader.achievements().size()], C.dim, false, render_ach))
	vb.add_child(row)
	vb.add_child(_btn("返回漫画人生", C.green, true, render_title))
	screen.add_child(card)

func render_comic_shelf() -> void:
	clear_screen()
	var card := _make_card()
	var vb := _cv(card)
	vb.add_child(_make_label("完结漫画书架", C.green, 24, true))
	var count := 0
	if DirAccess.dir_exists_absolute("user://comic_books"):
		for filename in DirAccess.get_files_at("user://comic_books"):
			if not filename.ends_with(".save"): continue
			var path := "user://comic_books/" + filename
			var file := FileAccess.open(path, FileAccess.READ)
			if file == null: continue
			var book: Variant = file.get_var(false)
			if not book is Dictionary or not book.get("terminal", {}) is Dictionary or book.get("terminal", {}).is_empty(): continue
			count += 1
			vb.add_child(_btn("%d 岁 · %d 页 · 第 %d 本" % [book.get("age", 0), book.get("pages", []).size(), count], C.cyan, false, func():
				get_tree().set_meta("life_comic_archive", path)
				_open_life_comic(true)))
	if count == 0: vb.add_child(_wrap_label("还没有完结的漫画。读完的一生，会自动留在这里。", C.dim, 14))
	vb.add_child(_btn("返回首页", C.green, true, render_title))
	screen.add_child(card)

func _open_life_comic(resume_book: bool) -> void:
	AudioFX.play_music(self, "story")
	get_tree().set_meta("life_comic_resume",resume_book)
	get_tree().change_scene_to_file("res://scenes/LifeComic.tscn")

func _on_game_started(s: GameState) -> void:
	_comic = ComicDirector.new_run(gc.rng)
	_history.clear()
	_skipped.clear()
	_page_no = 0
	_after_choice = false
	_busy = false
	_advance_busy = false
	_last_result = ""
	current_event = {}
	_completed = false
	_readonly_archive = false
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
	tier_wrap.add_child(_wrap_label(s.tier.get("desc", ""), C.dim, 12))
	tier_wrap.add_child(_spacer(12))
	tier_wrap.add_child(_wrap_label(DataLoader.regions()[s.region].get("flavor", ""), C.dim, 12))
	tier_wrap.add_child(_make_label(s.parent_job.get("desc", ""), C.cyan, 11))
	tier_wrap.add_child(_make_label(s.birth_hour.get("desc", ""), C.cyan, 11))
	tier_wrap.add_child(_make_label(s.birth_dream, C.purple, 11))
	tier_wrap.add_child(_spacer(8))
	tier_wrap.add_child(_make_label("初始 智力%d 体质%d 魅力%d 运气%d 金钱%d" % [s.intl, s.health, s.charm, s.luck, s.money], C.green, 12))
	tier_wrap.add_child(_spacer(18))
	tier_wrap.add_child(_btn("开始这一生", C.green, true, func():
		s.age = 1; s.step = 0; render_main()))
	vb.add_child(tier_wrap)
	screen.add_child(card)

	# 动画
	var tw := create_tween()
	for i in range(items.size()):
		tw.tween_property(roll_list.get_child(i), "modulate:a", 1.0, 0.38).set_delay(0.26 * i)
	tw.tween_property(tier_wrap, "modulate:a", 1.0, 0.5).set_delay(0.42)

# ==========================================================
# 主游戏页 —— 漫画分镜
# ==========================================================
func render_main() -> void:
	var s := gc.state
	if s.age >= s.lifespan or s.health <= 0:
		gc.end_game()
		return
	age_tag.text = "%d 岁" % s.age
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
	if _comic.is_empty():
		_comic = ComicDirector.new_run(gc.rng)

	# 开局的两年一定有画面：还没进入人生就「提笔带过」会很突兀
	var montage_this := _page_no >= 2 and ComicDirector.can_montage(ev, s) and ComicDirector.should_montage(s, _comic, gc.rng)
	# Flush quiet intervals before the next ordinary chapter, keeping ages in order.
	if not montage_this and not _skipped.is_empty():
		_strip_begin()
		_page_no += 1
		_append_life_page(ComicDirector.build_montage(s, _skipped, gc.rng, _page_no), 470)
		_skipped.clear()
	if montage_this:
		_render_montage(ev)
	else:
		_render_page(ev)

# ==========================================================
# 竖向漫画流
# ==========================================================
func _strip_begin() -> void:
	if _strip:
		return
	clear_screen()
	_strip = true
	$MarginContainer/ScrollContainer/VBox/TopBar.hide()
	var mc := get_node_or_null("MarginContainer")
	if mc != null:
		mc.add_theme_constant_override("margin_bottom", 210)
	if _action_layer != null:
		_action_layer.visible = true
	if _status_layer != null:
		_status_layer.visible = true
	if mc != null:
		mc.add_theme_constant_override("margin_top", 126)
	_reader_tools.show()
	_strip_pages = VBoxContainer.new()
	_strip_pages.add_theme_constant_override("separation", 38)
	screen.add_child(_strip_pages)
	_add_blank()
	_add_blank()
	_layout_reader()


## 还没轮到的年份：一页空白分镜，等人生活到那里再填
func _add_blank() -> void:
	if _strip_pages == null:
		return
	var pg = ComicPage.new()
	pg.build({
		"no": 0, "age": 0, "stage": "", "series": 1, "blank": true,
		"slots": [Rect2(0, 0, 1, 0.5), Rect2(0, 0.5, 1, 0.5)],
		"panels": [{}, {}],
	}, 420.0)
	var wrap := VBoxContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_child(pg)
	_strip_pages.add_child(wrap)
	_blanks.append(wrap)


## 把新的一页填进第一个空白位，再在末尾补一个新的空白
func _append_life_page(spec: Dictionary, h: float) -> Control:
	if not _restoring: _history.append({"spec": spec.duplicate(true), "height": h})
	var wrap := _comic_page_node(spec, h)
	var page_view = wrap.get_child(0)
	if not _restoring:
		var record: Dictionary = _history[-1]
		page_view.interaction_changed.connect(func(index, progress):
			record.spec.panels[index]["interaction_progress"] = progress
			_autosave())
	else:
		page_view.interactions_enabled = not _readonly_archive and not _after_choice and str(spec.get("event_id", "")) == str(current_event.get("id", ""))
		if page_view.interactions_enabled:
			page_view.interaction_changed.connect(func(index, progress):
				spec.panels[index]["interaction_progress"] = progress
				_autosave())
	var idx := -1
	if not _blanks.is_empty():
		var b = _blanks.pop_front()
		idx = b.get_index()
		b.queue_free()
	_strip_pages.add_child(wrap)
	if idx >= 0:
		_strip_pages.move_child(wrap, idx)
	_add_blank()
	var pg = wrap.get_child(0)
	if not _restoring and pg != null and pg.has_method("reveal_panels"):
		pg.reveal_panels()
	if not _restoring: _scroll_to(wrap)
	return wrap


func _refresh_status() -> void:
	if _status_box == null:
		return
	for c in _status_box.get_children():
		c.queue_free()
	_fill_status(_status_box, gc.state)


func _set_action(node: Control) -> void:
	if _action_box == null:
		return
	for c in _action_box.get_children():
		c.queue_free()
	_action_box.add_child(node)
	_action_scroll.scroll_vertical = 0
	call_deferred("_layout_reader")


## 往下一格一格滑：像手机上看纵向漫画
func _scroll_to(node: Control) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if _scroll == null or not is_instance_valid(node):
		return
	var target := int(node.global_position.y - _scroll.global_position.y + _scroll.scroll_vertical) - 6
	if _scroll_tween != null: _scroll_tween.kill()
	_scroll_tween = create_tween()
	_scroll_tween.tween_property(_scroll, "scroll_vertical", maxi(0, target), 0.62).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_scroll_tween.finished.connect(_autosave)


## 正常一页：本话 = 这一岁的事件
func _render_page(ev: Dictionary) -> void:
	_after_choice = false
	var s := gc.state
	_strip_begin()
	_page_no += 1
	_refresh_status()
	var spec := ComicDirector.build(s, ev, _comic, gc.rng, _page_no)
	_append_life_page(spec, 540.0)
	_set_action(_choice_column(ev))
	_set_footer("第 %d 话 · 本话 %d 格 · 选一个，往下翻" % [_page_no, spec["panels"].size()])
	if s.short_mode: _set_footer("关键抉择 · 画中物件可互动，也可直接选择")
	_autosave()

## 提笔带过：不画过程，只留一格说明
func _render_montage(ev: Dictionary) -> void:
	var s := gc.state
	var choices: Array = ev.get("choices", []).filter(func(c): return gc.choice_visible(c) and gc.choice_lock_hint(c).is_empty())
	if choices.size() > 0:
		var pickc: Dictionary = choices[gc.rng.randi_range(0, choices.size() - 1)]
		gc.choose(pickc, current_event)     # 自动选一个，数值照常结算
	_skipped.append({
		"age": int(s.age),
		"title": str(ev.get("title", "")),
		"result": _last_result,
	})
	if _skipped.size() > 3:
		_skipped = _skipped.slice(_skipped.size() - 3)

	# 只跳一年就先不画：攒够两年再合成一页「提笔带过」，节奏才不碎
	if _skipped.size() < 2:
		gc.advance_after_choice(current_event)
		return

	_strip_begin()
	_page_no += 1
	_refresh_status()
	var spec := ComicDirector.build_montage(s, _skipped, gc.rng, _page_no)
	var merged := _skipped.size()
	_skipped = []
	_append_life_page(spec, 470.0)
	var btn := _ink_btn_text("▶ 继续（带过 %d 段日常）" % merged, ComicTheme.ACCENT)
	btn.pressed.connect(_advance_page)
	_set_action(_action_wrap(btn))
	_set_footer("第 %d 话 · 这一段被提笔带过" % _page_no)
	_after_choice = true
	_autosave()

## 选择后的结果页
func _render_result(ev: Dictionary, c: Dictionary) -> void:
	AudioFX.play(self, "result", 1.0, -3.0)
	_after_choice = true
	var s := gc.state
	_strip_begin()
	_refresh_status()
	var result_choice := c.duplicate(true)
	if ev.has("scene"): result_choice["scene"] = ev.scene
	var spec := ComicDirector.build_result(s, result_choice, _last_result, gc.rng, _page_no)
	_append_life_page(spec, 520.0)
	var btn := _ink_btn_text("▶ 继续", ComicTheme.ACCENT)
	btn.pressed.connect(_advance_page)
	_set_action(_action_wrap(btn))
	_set_footer("第 %d 话 · 结果" % _page_no)
	_autosave()

func _action_wrap(node: Control) -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.add_child(node)
	return vb


func _on_comic_choice(c: Dictionary) -> void:
	if _busy or _after_choice or not gc.choice_visible(c) or not gc.choice_lock_hint(c).is_empty():
		return
	_busy = true
	for page_wrap in _strip_pages.get_children():
		if page_wrap.get_child_count() > 0 and page_wrap.get_child(0).has_method("reveal_panels"):
			page_wrap.get_child(0).interactions_enabled = false
	for button in _action_box.find_children("*", "Button", true, false): button.disabled = true
	gc.choose(c, current_event)
	await get_tree().create_timer(0.10).timeout
	_render_result(current_event, c)
	_busy = false

func _on_choice_resolved(_s: GameState, result_text: String) -> void:
	_last_result = result_text

func _on_event_picked(_s: GameState, _ev: Dictionary) -> void:
	pass

func _on_phase_advanced(_s: GameState) -> void:
	_advance_busy = false
	render_main()

# ---- 漫画页组装 ----
func _comic_page_node(spec: Dictionary, h: float) -> Control:
	var wrap := VBoxContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pg = ComicPage.new()
	pg.build(spec, h)
	wrap.add_child(pg)
	return wrap

## 顶部状态条：也用墨线风格，不用原来的圆角卡片
func _comic_status(s: GameState) -> Control:
	var box := PanelContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_stylebox_override("panel", _status_style())
	var vb := VBoxContainer.new()
	_fill_status(vb, s)
	box.add_child(vb)
	return box


func _status_style() -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = ComicTheme.INK
	st.border_color = Color(ComicTheme.CREAM, 0.8)
	st.set_border_width_all(2)
	st.content_margin_left = 8; st.content_margin_top = 5
	st.content_margin_right = 8; st.content_margin_bottom = 5
	return st


## 状态条的内容（数值行 + 抽象度刻度），固定条与页内条共用
func _fill_status(vb: VBoxContainer, s: GameState) -> void:
	vb.add_theme_constant_override("separation", 3)
	var persona := ComicDirector.persona_bias(s)
	var disposition := "性格未定" if persona == 0 else ("偏向行动与相遇" if persona > 0 else "偏向独白与观察")
	var title := _ink_label("%02d 岁  /  第 %02d 话  ·  %s" % [s.age, _page_no, disposition], ComicTheme.CREAM, 12, true)
	title.tooltip_text = "体质改变未来分镜密度；性格改变叙述节奏；寿命与健康决定终章。"
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vb.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for item in [["智", s.intl], ["体", s.health], ["魅", s.charm], ["运", s.luck], ["钱", s.money], ["寿", s.lifespan]]:
		var chip := _ink_label("%s %s" % [item[0], item[1]], ComicTheme.CREAM, 11, true)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(chip)
	vb.add_child(row)

	# 抽象度：一条墨线刻度
	var a: int = s.health
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 7)
	bar.draw.connect(func():
		var w: float = bar.size.x
		bar.draw_rect(Rect2(0, 2, w, 3), Color(ComicTheme.CREAM, 0.18))
		bar.draw_rect(Rect2(0, 2, w * clampf(a / 20.0, 0, 1), 3), ComicTheme.ACCENT if a <= 5 else ComicTheme.CREAM)
	)
	vb.add_child(bar)

func _choice_column(ev: Dictionary) -> VBoxContainer:
	var cb := VBoxContainer.new()
	cb.add_theme_constant_override("separation", 7)
	var head := _ink_label("这一格，由你落笔  /  CHOOSE", ComicTheme.CREAM, 11)
	head.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cb.add_child(head)
	var unlocked := 0
	for c in ev.get("choices", []):
		if not gc.choice_visible(c): continue
		var b := _ink_choice_btn(c, gc.state)
		if not b.disabled:
			unlocked += 1
			b.pressed.connect(_on_comic_choice.bind(c))
		cb.add_child(b)
	if unlocked == 0:
		var wait := _ink_btn_text("▶ 暂时放下，继续生活", ComicTheme.ACCENT)
		wait.pressed.connect(_on_comic_choice.bind({"label": "暂时放下", "effects": {}, "result": "你把这个问题留给未来，眼前的生活仍在继续。"}))
		cb.add_child(wait)
	return cb

func _ink_label(text: String, col: Color, sz: int, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", sz)
	if bold:
		l.add_theme_font_override("font", ComicTheme.font_big())
	else:
		l.add_theme_font_override("font", ComicTheme.font_body())
	return l

func _ink_btn_text(text: String, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_override("font", ComicTheme.font_big())
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", ComicTheme.CREAM)
	b.add_theme_color_override("font_hover_color", ComicTheme.CREAM)
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_border_width_all(2)
	sb.border_color = ComicTheme.INK
	sb.content_margin_left = 10; sb.content_margin_top = 8
	sb.content_margin_right = 10; sb.content_margin_bottom = 8
	var sb2 := sb.duplicate()
	sb2.bg_color = ComicTheme.INK
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb2)
	b.add_theme_stylebox_override("pressed", sb2)
	return b

func _ink_choice_btn(c: Dictionary, s: GameState) -> Button:
	var b := Button.new()
	b.text = "▶  " + str(c.get("label", ""))
	b.tooltip_text = str(c.get("label", ""))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for property in b.get_property_list():
		if str(property.name) == "autowrap_mode": b.set("autowrap_mode", TextServer.AUTOWRAP_WORD_SMART)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.mouse_entered.connect(func():
		if not b.disabled: AudioFX.play(self, "move", 1.0, -5.0))
	b.add_theme_font_override("font", ComicTheme.font_body())
	b.add_theme_font_size_override("font_size", 14)
	var col := ComicTheme.CREAM
	var lock := gc.choice_lock_hint(c)
	if not lock.is_empty():
		b.disabled = true
		b.text += " （%s）" % lock
	if c.has("require"):
		for k in c["require"]:
			if s.get_attr(k) < int(c["require"][k]):
				col = ComicTheme.ACCENT
				b.text += "　（%s需 %d）" % [_attr_cn(k), int(c["require"][k])]
				b.disabled = true
				break
	var normal := StyleBoxFlat.new()
	normal.bg_color = ComicTheme.INK
	normal.border_color = Color(ComicTheme.CREAM, 0.65)
	normal.set_border_width_all(2)
	normal.content_margin_left = 14; normal.content_margin_top = 7
	normal.content_margin_right = 10; normal.content_margin_bottom = 7
	var hover := normal.duplicate()
	hover.bg_color = ComicTheme.ACCENT
	hover.border_color = ComicTheme.CREAM
	var dis := normal.duplicate()
	dis.bg_color = Color(ComicTheme.INK, 0.55)
	dis.border_color = Color(ComicTheme.CREAM, 0.2)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("disabled", dis)
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_hover_color", ComicTheme.CREAM)
	b.add_theme_color_override("font_disabled_color", Color(ComicTheme.CREAM, 0.3))
	# 左侧红条：和标题下的红杠是同一个记号
	var bar := ColorRect.new()
	bar.color = ComicTheme.ACCENT
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	bar.offset_right = 4.0
	bar.offset_top = 3.0
	bar.offset_bottom = -3.0
	b.add_child(bar)
	return b

func _reader_input(event: InputEvent) -> void:
	if event is InputEventPanGesture or event is InputEventScreenDrag or (event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]):
		if _scroll_tween != null: _scroll_tween.kill()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and autosave_enabled and _strip:
		save_current()

func _layout_reader() -> void:
	if not _strip or _action_layer == null: return
	_reader_tools.size.x = maxf(200, size.x - 28)
	var wanted := clampf(_action_box.get_combined_minimum_size().y + 24, 72, minf(270, size.y * 0.40))
	_action_layer.offset_top = -wanted - 8
	var mc := get_node_or_null("MarginContainer")
	if mc != null:
		mc.add_theme_constant_override("margin_bottom", int(wanted + 22))
		mc.add_theme_constant_override("margin_top", 124)

func _advance_page() -> void:
	if _advance_busy or not _after_choice: return
	_advance_busy = true
	for button in _action_box.find_children("*", "Button", true, false): button.disabled = true
	_after_choice = false
	gc.advance_after_choice(current_event)

func _snapshot() -> Dictionary:
	return {"state": ComicArchive.state_data(gc.state), "comic": _comic.duplicate(true),
		"history": _history.duplicate(true), "event": current_event.duplicate(true),
		"page_no": _page_no, "after_choice": _after_choice, "result": _last_result,
		"skipped": _skipped.duplicate(true), "rng_seed": gc.rng.seed, "rng_state": gc.rng.state,
		"scroll": _scroll.scroll_vertical, "completed": _completed}

func _autosave() -> void:
	if autosave_enabled and (not _busy or _after_choice) and not _readonly_archive and not _restoring and gc.state != null and not _history.is_empty():
		ComicArchive.save_run(_snapshot(), archive_path)

func save_current() -> void:
	if gc.state == null or not _strip or _busy: return
	if _readonly_archive:
		_set_footer("这本人生已经归档，翻阅不会改变当前书签")
		return
	if ComicArchive.save_run(_snapshot(), archive_path):
		_set_footer("书签已保存 · 已画的分镜与随机序列都会保留")
	else:
		_set_footer("书签保存失败，请检查存储空间")

func _return_to_title() -> void:
	if _busy: return
	save_current()
	render_title()

func resume_saved(book_path: String = "") -> void:
	var saved := ComicArchive.load_run(archive_path if book_path.is_empty() else book_path)
	if saved.is_empty(): return
	clear_screen()
	gc.state = GameState.new()
	ComicArchive.restore_state(gc.state, saved.state)
	gc.rng.seed = int(saved.get("rng_seed", 0))
	gc.rng.state = int(saved.get("rng_state", 0))
	_comic = saved.get("comic", {}).duplicate(true)
	_history = saved.history.duplicate(true)
	current_event = saved.get("event", {}).duplicate(true)
	_page_no = int(saved.get("page_no", 0))
	_after_choice = bool(saved.get("after_choice", false))
	_last_result = str(saved.get("result", ""))
	_skipped = saved.get("skipped", []).duplicate(true)
	_busy = false
	_advance_busy = false
	_completed = bool(saved.get("completed", false))
	_readonly_archive = not book_path.is_empty()
	_restoring = true
	_strip_begin()
	_refresh_status()
	for entry in _history: _append_life_page(entry.spec, float(entry.height))
	_restoring = false
	if bool(saved.get("completed", false)):
		var back := _ink_btn_text("这一生已完结 · 返回书架", ComicTheme.ACCENT)
		back.pressed.connect(render_title)
		_set_action(_action_wrap(back))
	elif _after_choice:
		var next := _ink_btn_text("▶ 继续", ComicTheme.ACCENT)
		next.pressed.connect(_advance_page)
		_set_action(_action_wrap(next))
	else:
		_set_action(_choice_column(current_event))
	_set_footer("书签已恢复 · 向上可回看已绘的人生")
	await get_tree().process_frame
	await get_tree().process_frame
	_scroll.scroll_vertical = int(saved.get("scroll", 0))

func render_books() -> void:
	clear_screen()
	var card := _make_card()
	var box := _cv(card)
	box.add_child(_make_label("留在书架上的人生", C.cyan, 24, true))
	box.add_child(_wrap_label("重新翻阅不会改变正在进行的人生。", C.dim, 12))
	for book in ComicArchive.books():
		box.add_child(_btn("%d 岁 · %d 张漫画页" % [book.age, book.pages], C.txt, false, resume_saved.bind(str(book.path))))
	box.add_child(_btn("返回首页", C.dim, false, render_title))
	screen.add_child(card)

func _set_footer(t: String) -> void:
	var f := get_node_or_null("MarginContainer/ScrollContainer/VBox/Footer")
	if f:
		f.text = t
		f.add_theme_color_override("font_color", Color(0.72, 0.70, 0.64))

# ==========================================================
# 结局页
# ==========================================================
func _on_game_ended(s: GameState, ending: Dictionary, info: Dictionary) -> void:
	AudioFX.play_music(self, "ending")
	AudioFX.play(self, "ending", 1.0, -2.0)
	if not _skipped.is_empty():
		_page_no += 1
		_append_life_page(ComicDirector.build_montage(s, _skipped, gc.rng, _page_no), 470)
		_skipped.clear()
	_after_choice = true
	_completed = true
	if autosave_enabled and not _history.is_empty():
		var snapshot := _snapshot()
		snapshot["completed"] = true
		ComicArchive.save_run(snapshot, archive_path)
		ComicArchive.save_book(snapshot)
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
	var drawn := 0
	for entry in _history: drawn += entry.spec.get("panels", []).size()
	vb.add_child(_spacer(10))
	vb.add_child(_make_label("这一生留下 %d 话 · %d 张漫画页 · %d 格记忆" % [_page_no, _history.size(), drawn], C.cyan, 12))
	if info.get("first_time", false):
		vb.add_child(_spacer(14))
		vb.add_child(_make_label("★ 新结局解锁！ 图鉴 %d/%d" % [meta.get("endings", {}).size(), DataLoader.endings().size()], C.yellow, 12))
	vb.add_child(_spacer(18))
	vb.add_child(_btn("从头翻阅这一生", C.cyan, false, resume_saved))
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
			var n: String = e.get("name", "") if got else "？ ？ ？"
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

func _wrap_label(text: String, col: Color, sz: int) -> Label:
	"""长文本专用：不换行的 Label 最小宽度 = 整段文字宽度，会把卡片撑出 520 宽视口。"""
	var l := _make_label(text, col, sz)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
