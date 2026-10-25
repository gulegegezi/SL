## comic_page.gd — 一页漫画
## 页眉（第 N 话 / 年龄 / 全话数） + 不规则分格 + 页脚（格数统计）
extends Control
signal interaction_changed(index: int, progress: Dictionary)
signal cinematic_changed(index: int)
var interactions_enabled := true:
	set(value):
		interactions_enabled = value
		for panel in panels: panel.interactions_enabled = value

const T := preload("res://scripts/comic_theme.gd")
const AudioFX := preload("res://scripts/audio_fx.gd")
const PanelScript := preload("res://scripts/comic_panel.gd")
const Art := preload("res://scripts/comic_art.gd")

const PAGE_W := 492.0
const HEAD_H := 34.0
const FOOT_H := 20.0
const MARGIN := 10.0

var spec: Dictionary = {}
var page_h := 620.0
var blank := false
var panels: Array = []
var _revealing := false
var _reveal_clock := 0.0

static var _ink_cache: Dictionary = {}


static func ink_tex(key: String, frame: int = 0) -> Texture2D:
	if key.is_empty():
		return null
	var mature := Art.portrait(key, frame)
	if mature != null: return mature
	var cache_key := "%s#%d" % [key, frame]
	if _ink_cache.has(cache_key):
		return _ink_cache[cache_key]
	# 都市传说解体中心色板的线稿优先；缺失时回落到原黑白线稿
	var p := "res://assets/ink_umdc/%s_%d.png" % [key, frame]
	if not ResourceLoader.exists(p):
		p = "res://assets/ink/%s_0.png" % key
	var t: Texture2D = load(p) if ResourceLoader.exists(p) else null
	_ink_cache[cache_key] = t
	return t


func build(page: Dictionary, height: float = 620.0) -> void:
	spec = page
	page_h = height
	blank = bool(page.get("blank", false))
	# 像素画风：线稿也要 nearest，放大后是硬边方块而不是糊的
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = Vector2(0, page_h)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if size.x < 1: size.x = PAGE_W
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not resized.is_connected(_reflow): resized.connect(_reflow)
	_build_panels()
	queue_redraw()


func _content_rect() -> Rect2:
	return Rect2(MARGIN, HEAD_H + 6.0, maxf(240, size.x) - MARGIN * 2.0, page_h - HEAD_H - FOOT_H - 12.0)

func _reflow() -> void:
	_build_panels()
	queue_redraw()

func _webtoon_slots() -> Array:
	var data: Array = spec.get("panels", [])
	var heights: Array[float] = []
	var total := 0.0
	for item in data:
		var shot := str(item.get("shot", "medium"))
		var base: float = {"wide": 275.0, "medium": 250.0, "close": 280.0, "extreme": 300.0, "detail": 150.0}.get(shot, 250.0)
		if item.has("interaction"): base = 380.0
		if item.get("presentation","") == "pixel3d": base = maxf(base,350.0)
		if item.get("presentation","") == "comic_insert": base = maxf(base, 360.0)
		if item.has("pixel_interaction"): base = 430.0
		var text_length := str(item.get("caption", "")).length() + str(item.get("bubble", "")).length()
		var columns := maxf(14, (maxf(size.x, 280) - 56) / 15)
		var extra := maxf(0, ceilf(text_length / columns) - 2) * 21
		heights.append(base + extra)
		total += base + extra
	page_h = total + HEAD_H + FOOT_H + 12
	custom_minimum_size.y = page_h
	var out: Array = []
	var y := 0.0
	for height in heights:
		out.append(Rect2(0, y / maxf(total, 1), 1, height / maxf(total, 1)))
		y += height
	return out


func _build_panels() -> void:
	for c in get_children():
		c.queue_free()
	panels.clear()
	var slots: Array = spec.get("slots", []) if blank else _webtoon_slots()
	var content := _content_rect()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(spec.get("no", 1)) * 7919 + int(spec.get("age", 0)) * 131

	for i in range(slots.size()):
		var slot: Rect2 = slots[i]
		var p = PanelScript.new()
		var r := Rect2(content.position + slot.position * content.size, slot.size * content.size)
		# 分格之间留缝：先内缩半个 gutter，再向外多给 3px 让旋转后不漏底
		r = r.grow(-T.GUTTER * 0.5).grow(2.5)
		p.position = r.position
		p.size = r.size
		var data: Dictionary = spec["panels"][i] if i < spec["panels"].size() else {}
		var d := data.duplicate()
		d["idx"] = str(i + 1)
		# 每格轻微旋转，像手工贴上去的
		# 分格内部是「画」出来的线稿 + 网点，不是像素画：用线性采样，否则线条全是台阶
		p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		p.rotation_degrees = 0
		p.pivot_offset = r.size * 0.5
		var key := str(d.get("ink", ""))
		p.setup(d, ink_tex(key, int(d.get("frame", 0))))
		p.interactions_enabled = interactions_enabled
		p.interacted.connect(_panel_interacted.bind(i))
		p.cinematic_finished.connect(_cinematic_finished.bind(i))
		if blank or _revealing: p.set_revealed(false)
		add_child(p)
		panels.append(p)

func _panel_interacted(progress: Dictionary, index: int) -> void:
	spec.panels[index]["interaction_progress"] = progress.duplicate(true)
	interaction_changed.emit(index, progress)

func _cinematic_finished(index: int) -> void:
	spec.panels[index]["cg_progress"] = {"completed":true}
	cinematic_changed.emit(index)


## 逐格把画面「画上去」：新的一页先全是空白框，再一格一格填。
func reveal_panels(step: float = 0.08) -> void:
	if panels.is_empty():
		return
	for i in range(panels.size()):
		var p = panels[i]
		p.set_revealed(false)
	_revealing = true
	_reveal_clock = 0.0
	AudioFX.play(self, "page", 1.0, -3.0)
	set_process(true)

func _process(delta: float) -> void:
	if not _revealing: return
	_reveal_clock += delta
	if _reveal_clock < 0.16: return
	var view := get_viewport_rect()
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			view = ancestor.get_global_rect()
			break
		ancestor = ancestor.get_parent()
	var remaining := false
	for panel in panels:
		if panel.revealed: continue
		remaining = true
		if panel.get_global_rect().position.y < view.end.y - 20:
			panel.set_revealed(true)
			_reveal_clock = 0
			break
	if not remaining:
		_revealing = false
		set_process(false)


func _draw() -> void:
	var width := maxf(240, size.x)
	var page := Rect2(Vector2.ZERO, Vector2(width, page_h))

	if blank:
		# 还没轮到的年份：只铺底色和页边，页眉页脚都不写
		draw_rect(page, Color(T.PAPER, 0.75))
		draw_rect(page, Color(T.INK, 0.45), false, 1.5)
		return

	# 纸
	draw_rect(page, T.PAPER)
	if T.paper_tex():
		draw_texture_rect(T.paper_tex(), page, true, Color(1, 1, 1, 0.12))
	# 页边
	draw_rect(page, T.INK, false, 2.0)

	# 页眉：黑条 + 反白
	var head := Rect2(0, 0, width, HEAD_H)
	draw_rect(head, T.INK)
	var f := T.font_big()
	var no := int(spec.get("no", 1))
	draw_string(f, Vector2(12, HEAD_H - 11), "第 %d 话" % no, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, T.CREAM)
	# 标题下的红杠：解体中心最认得出的一条线
	draw_rect(Rect2(12, HEAD_H - 7, 64, 2), T.ACCENT)
	var mid := "%d 岁 · %s" % [int(spec.get("age", 0)), str(spec.get("stage", ""))]
	draw_string(T.font_body(), Vector2(96, HEAD_H - 12), mid, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, T.CREAM)
	var right := "后页未定"
	draw_string(T.font_body(),
		Vector2(width - 66, HEAD_H - 12), right, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		Color(T.CREAM, 0.75))
	if bool(spec.get("montage", false)):
		draw_string(f, Vector2(width * 0.5 - 34, HEAD_H - 11), "— 略 —", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, T.ACCENT)

	# 页脚
	var foot_y := page_h - FOOT_H + 2.0
	draw_line(Vector2(MARGIN, foot_y - 4), Vector2(width - MARGIN, foot_y - 4), Color(T.CREAM, 0.25), 1.0)
	var n := panels.size()
	draw_string(T.font_body(), Vector2(MARGIN, page_h - 6),
		"本话 %d 格" % n, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(T.CREAM, 0.55))
	draw_string(T.font_body(), Vector2(width - MARGIN - 46, page_h - 6),
		"p.%03d" % no, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(T.CREAM, 0.55))

	# 四角裁切线
	for corner in [Vector2(3, 3), Vector2(width - 3, 3), Vector2(3, page_h - 3), Vector2(width - 3, page_h - 3)]:
		draw_circle(corner, 1.2, T.INK)
