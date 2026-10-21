## comic_theme.gd — 漫画分镜风的统一样式层
## 墨线 / 网点 / 纸色 / 字体，全部集中在这里，分镜页与分格都从这里取。
## 色板按「都市传说解体中心」调：青底、墨黑、米白、一点血红。
extends RefCounted

# ---- 青与墨 ----
const PAPER := Color(0.216, 0.553, 0.565)      # 页面底：青
const PAPER_DIM := Color(0.176, 0.463, 0.475)
const INK := Color(0.039, 0.078, 0.086)        # 主墨色
const INK_SOFT := Color(0.110, 0.290, 0.298)
const CREAM := Color(0.949, 0.914, 0.847)      # 深色上的文字/高光
const ACCENT := Color(0.824, 0.141, 0.173)     # 强调红：只用在下划线、拟声词、关键框
const WALL := Color(0.031, 0.063, 0.070)       # 页面外的底色（阅读器背景）

const GUTTER := 5.0                            # 分格间隙

static var _font_body: Font = null
static var _font_big: Font = null
static var _tone: Texture2D = null
static var _paper: Texture2D = null


static func _sysfont(names: Array, weight: int) -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names)
	f.font_weight = weight
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return f


static func font_body() -> Font:
	if _font_body == null:
		_font_body = _sysfont(["Microsoft YaHei", "SimHei", "Noto Sans CJK SC", "sans-serif"], 400)
	return _font_body


static func font_big() -> Font:
	if _font_big == null:
		_font_big = _sysfont(["SimHei", "Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"], 800)
	return _font_big


static func tone() -> Texture2D:
	if _tone == null:
		_tone = load("res://assets/ink/tone.png")
	return _tone


static func paper_tex() -> Texture2D:
	if _paper == null:
		_paper = load("res://assets/ink/paper.png")
	return _paper


## 画一格底：纸 / 网点 / 黑板 / 斜线
static func fill(c: CanvasItem, r: Rect2, kind: String) -> void:
	match kind:
		"tone":
			c.draw_rect(r, PAPER)
			if tone():
				c.draw_texture_rect(tone(), r, true)
		"tone_soft":
			c.draw_rect(r, PAPER)
			if tone():
				c.draw_texture_rect(tone(), r, true, Color(1, 1, 1, 0.45))
		"black":
			c.draw_rect(r, INK)
		"dark":
			c.draw_rect(r, INK)
			if tone():
				c.draw_texture_rect(tone(), r, true, Color(1, 1, 1, 0.55))
		_:
			c.draw_rect(r, PAPER)
			if paper_tex():
				# 纸纹在青底上只留一点点颗粒感，别把青底搅浑
				c.draw_texture_rect(paper_tex(), r, true, Color(1, 1, 1, 0.16))
			if tone():
				c.draw_texture_rect(tone(), r, true, Color(1, 1, 1, 0.10))


## 手绘感的墨框：用四条略带抖动的折线，而不是 draw_rect
static func frame(c: CanvasItem, r: Rect2, w: float = 3.0, wobble: float = 0.7, col: Color = INK) -> void:
	var pts := [
		Vector2(r.position.x, r.position.y),
		Vector2(r.end.x, r.position.y),
		Vector2(r.end.x, r.end.y),
		Vector2(r.position.x, r.end.y),
		Vector2(r.position.x, r.position.y),
	]
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		# 中间插一个抖动点，线看起来是手画的
		var mid: Vector2 = (a + b) * 0.5 + Vector2(randf_range(-wobble, wobble), randf_range(-wobble, wobble))
		c.draw_polyline(PackedVector2Array([a, mid, b]), col, w, true)


## 集中在一点的速度线（漫画里最常用的「气势」）
static func speed_lines(c: CanvasItem, r: Rect2, focus: Vector2, count: int, col: Color, thin: bool = true) -> void:
	var seed_v := int(r.position.x * 7 + r.position.y * 13)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for i in range(count):
		var ang: float = rng.randf() * TAU
		var rad: float = maxf(r.size.x, r.size.y) * 1.4
		var p1 := focus + Vector2(cos(ang), sin(ang)) * rad * rng.randf_range(0.30, 0.55)
		var p2 := focus + Vector2(cos(ang), sin(ang)) * rad
		var w: float = rng.randf_range(0.8, 2.2) if thin else rng.randf_range(2.0, 4.5)
		c.draw_line(p1, p2, col, w, true)


## 横向排线（速度/阴影）
static func hatch(c: CanvasItem, r: Rect2, count: int, col: Color, vertical: bool = false) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(r.size.x * 31 + r.size.y)
	for i in range(count):
		var t: float = (i + rng.randf_range(0.2, 0.8)) / float(count)
		if vertical:
			var x: float = r.position.x + r.size.x * t
			c.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), col, rng.randf_range(0.6, 1.6), true)
		else:
			var y: float = r.position.y + r.size.y * t
			c.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), col, rng.randf_range(0.6, 1.6), true)


## 估算一段文字排成框后的自然宽度：中文按 1 字宽、西文按 0.55 字宽。
static func text_width(f: Font, text: String, size: int, cap: float, floor_w: float) -> float:
	var est := 0.0
	for i in range(text.length()):
		var ch := text.substr(i, 1)
		if ch == "
":
			continue
		est += float(size) * (1.0 if ch.unicode_at(0) > 127 else 0.56)
	return clampf(est + 22.0, floor_w, cap)


## 旁白框：暗板 + 米白字 + 左侧红条（解体中心的标记）
static func caption_box(c: CanvasItem, pos: Vector2, text: String, max_w: float, size: int = 13, dark: bool = false) -> Rect2:
	var f := font_body()
	var pad := 8.0
	var inner_w: float = text_width(f, text, size, minf(max_w, 250.0), 96.0)
	var measured: Vector2 = f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, inner_w - pad * 2 - 4, size)
	var h: float = maxf(measured.y, size + 6) + pad * 2
	var r := Rect2(pos, Vector2(inner_w, h))
	c.draw_rect(r, INK)
	c.draw_rect(Rect2(r.position, Vector2(3.0, r.size.y)), ACCENT)
	frame(c, r, 1.5, 0.4, Color(CREAM, 0.85))
	c.draw_multiline_string(f, pos + Vector2(pad + 4, pad + size * 0.85), text,
		HORIZONTAL_ALIGNMENT_LEFT, inner_w - pad * 2 - 4, size, -1, CREAM)
	return r


## 对白气泡：暗板 + 米白边 + 一个三角尾巴 + 自动换行
static func bubble(c: CanvasItem, pos: Vector2, text: String, max_w: float, size: int = 13, tail_dir: int = 1) -> Rect2:
	var f := font_body()
	var pad := 9.0
	var inner_w: float = text_width(f, text, size, minf(max_w, 220.0), 88.0)
	var measured: Vector2 = f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, inner_w - pad * 2, size)
	var h: float = maxf(measured.y, size + 6) + pad * 2
	var r := Rect2(pos, Vector2(inner_w, h))
	var sb := StyleBoxFlat.new()
	sb.bg_color = INK
	sb.border_color = CREAM
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(minf(h, 44) * 0.5))
	c.draw_style_box(sb, r)
	# 尾巴
	var ty: float = r.end.y - 10.0
	var tip := Vector2(r.end.x + 12.0 * tail_dir, ty + 16.0)
	c.draw_colored_polygon(PackedVector2Array([
		Vector2(r.end.x - 4.0 * tail_dir, ty - 8.0),
		Vector2(r.end.x - 4.0 * tail_dir, ty + 8.0),
		tip,
	]), INK)
	c.draw_polyline(PackedVector2Array([
		Vector2(r.end.x - 4.0 * tail_dir, ty - 8.0), tip,
		Vector2(r.end.x - 4.0 * tail_dir, ty + 8.0),
	]), CREAM, 2.0, true)
	c.draw_multiline_string(f, pos + Vector2(pad, pad + size * 0.85), text,
		HORIZONTAL_ALIGNMENT_LEFT, inner_w - pad * 2, size, -1, CREAM)
	return r


## 拟声词：米白描边 + 墨字（或红字），可旋转
static func sfx(c: CanvasItem, pos: Vector2, text: String, size: int = 34, rot: float = -0.16, col: Color = INK) -> void:
	var f := font_big()
	# 描边色永远取和字色相反的一侧，否则深色格上会糊成一个色块
	var edge: Color = INK if col.get_luminance() > 0.5 else CREAM
	c.draw_set_transform(pos, rot)
	for d in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2), Vector2(-1.5, -1.5), Vector2(1.5, 1.5)]:
		c.draw_string(f, d, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, edge)
	c.draw_string(f, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	c.draw_set_transform(Vector2.ZERO, 0.0)


## 竖排拟声词（漫画里从右往左的冲击音）
static func sfx_vertical(c: CanvasItem, pos: Vector2, text: String, size: int = 30, col: Color = INK) -> void:
	var f := font_big()
	var y := 0.0
	for i in range(text.length()):
		var ch := text.substr(i, 1)
		var edge: Color = INK if col.get_luminance() > 0.5 else CREAM
		for d in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
			c.draw_string(f, pos + Vector2(0, y) + d, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, edge)
		c.draw_string(f, pos + Vector2(0, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		y += size * 1.02
