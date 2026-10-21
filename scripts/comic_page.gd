## comic_page.gd — 一页漫画
## 页眉（第 N 话 / 年龄 / 全话数） + 不规则分格 + 页脚（格数统计）
extends Control

const T := preload("res://scripts/comic_theme.gd")
const PanelScript := preload("res://scripts/comic_panel.gd")

const PAGE_W := 492.0
const HEAD_H := 34.0
const FOOT_H := 20.0
const MARGIN := 10.0

var spec: Dictionary = {}
var page_h := 620.0
var panels: Array = []

static var _ink_cache: Dictionary = {}


static func ink_tex(key: String, frame: int = 0) -> Texture2D:
	if key.is_empty():
		return null
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
	# 像素画风：线稿也要 nearest，放大后是硬边方块而不是糊的
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = Vector2(PAGE_W, page_h)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_panels()
	queue_redraw()


func _content_rect() -> Rect2:
	return Rect2(MARGIN, HEAD_H + 6.0, PAGE_W - MARGIN * 2.0, page_h - HEAD_H - FOOT_H - 12.0)


func _build_panels() -> void:
	for c in get_children():
		c.queue_free()
	panels.clear()
	var slots: Array = spec.get("slots", [])
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
		p.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		p.rotation_degrees = rng.randf_range(-0.9, 0.9)
		p.pivot_offset = r.size * 0.5
		var key := str(d.get("ink", ""))
		p.setup(d, ink_tex(key, int(d.get("frame", 0))))
		add_child(p)
		panels.append(p)


func _draw() -> void:
	var page := Rect2(Vector2.ZERO, Vector2(PAGE_W, page_h))

	# 纸
	draw_rect(page, T.PAPER)
	if T.paper_tex():
		draw_texture_rect(T.paper_tex(), page, true, Color(1, 1, 1, 0.12))
	# 页边
	draw_rect(page, T.INK, false, 2.0)

	# 页眉：黑条 + 反白
	var head := Rect2(0, 0, PAGE_W, HEAD_H)
	draw_rect(head, T.INK)
	var f := T.font_big()
	var no := int(spec.get("no", 1))
	draw_string(f, Vector2(12, HEAD_H - 11), "第 %d 话" % no, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, T.CREAM)
	# 标题下的红杠：解体中心最认得出的一条线
	draw_rect(Rect2(12, HEAD_H - 7, 64, 2), T.ACCENT)
	var mid := "%d 岁 · %s" % [int(spec.get("age", 0)), str(spec.get("stage", ""))]
	draw_string(T.font_body(), Vector2(96, HEAD_H - 12), mid, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, T.CREAM)
	var right := "全 %d 话" % int(spec.get("series", 1))
	draw_string(T.font_body(),
		Vector2(PAGE_W - 78, HEAD_H - 12), right, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
		Color(T.CREAM, 0.75))
	if bool(spec.get("montage", false)):
		draw_string(f, Vector2(PAGE_W * 0.5 - 34, HEAD_H - 11), "— 略 —", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, T.ACCENT)

	# 页脚
	var foot_y := page_h - FOOT_H + 2.0
	draw_line(Vector2(MARGIN, foot_y - 4), Vector2(PAGE_W - MARGIN, foot_y - 4), Color(T.CREAM, 0.25), 1.0)
	var n := panels.size()
	draw_string(T.font_body(), Vector2(MARGIN, page_h - 6),
		"本话 %d 格" % n, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(T.CREAM, 0.55))
	draw_string(T.font_body(), Vector2(PAGE_W - MARGIN - 46, page_h - 6),
		"p.%03d" % no, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(T.CREAM, 0.55))

	# 四角裁切线
	for corner in [Vector2(3, 3), Vector2(PAGE_W - 3, 3), Vector2(3, page_h - 3), Vector2(PAGE_W - 3, page_h - 3)]:
		draw_circle(corner, 1.2, T.INK)
