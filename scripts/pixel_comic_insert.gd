extends RefCounted
## pixel_comic_insert.gd — 用漫画格子表达「动作演不出来」的内容
##
## 有些剧情是心理、回忆、抽象的（"你还没学会害怕"、"屋里只剩钟声"），
## 让 3D 角色去"演"只会变成站着不动。这类页改成一张双格漫画：
## 旁白框交代事实，气泡放人物的话，人物立绘负责表情。
##
## 图全部复用 comic_art（comic_city 立绘 / comic_expressions），不新增资源。

const T := preload("res://scripts/comic_theme.gd")
const Art := preload("res://scripts/comic_art.gd")


static func draw(panel: Control, area: Rect2, data: Dictionary) -> void:
	if area.size.x < 80.0 or area.size.y < 60.0:
		return
	var panels: Array = data.get("panels", [])
	var gutter := 6.0
	var pad := 8.0
	# 两格：上 58%，下 42%；超过两格的只画前两格（信息密度已经够了）
	var usable := Rect2(area.position + Vector2(4, 4), area.size - Vector2(8, 8))
	var top_h := (usable.size.y - gutter) * 0.58
	var top := Rect2(usable.position, Vector2(usable.size.x, top_h))
	var bottom := Rect2(usable.position + Vector2(0, top_h + gutter),
		Vector2(usable.size.x, usable.size.y - top_h - gutter))
	var rects := [top, bottom]
	for i in range(mini(panels.size(), 2)):
		_draw_panel(panel, rects[i], panels[i], i)


static func _draw_panel(panel: Control, r: Rect2, data: Dictionary, index: int) -> void:
	var dark := str(data.get("bg", "paper")) == "ink"
	var bg := T.INK if dark else T.PAPER
	var fg := T.CREAM if dark else T.INK
	panel.draw_rect(r, bg)
	# 第一格用场景图做「建立镜头」，比放一张大头更像漫画
	var scene_bg: Texture2D = null
	if str(data.get("bg_art", "")) == "scene":
		scene_bg = Art.background(str(data.get("scene", "home")))
	if scene_bg != null:
		var region := Art.cover_region(scene_bg, r.size)
		panel.draw_texture_rect_region(scene_bg, r, region, Color(0.9, 0.95, 1.0, 0.9))
	# 网点
	var step := 7.0
	var row := 0
	var y := r.position.y + 5.0
	while y < r.end.y - 4.0:
		var x := r.position.x + 5.0 + (3.5 if row % 2 == 1 else 0.0)
		while x < r.end.x - 4.0:
			panel.draw_circle(Vector2(x, y), 0.8, Color(fg, 0.10))
			x += step
		y += step
		row += 1

	# 人物立绘：靠右下
	var key := str(data.get("key", "lead_adult"))
	var expression := str(data.get("expression", "normal"))
	var art: Texture2D = null
	if scene_bg == null:
		art = Art.portrait(key, 0, expression)
	var text_w: float = r.size.x * 0.56
	var art_box := Rect2(r.position.x + r.size.x * 0.52, r.position.y + 4.0,
		r.size.x * 0.46, r.size.y - 8.0)
	if art != null:
		var size := art.get_size()
		var fit: float = minf(art_box.size.x / maxf(1.0, size.x), art_box.size.y / maxf(1.0, size.y))
		var dest := Rect2(art_box.position + (art_box.size - size * fit) * 0.5, size * fit)
		panel.draw_texture_rect(art, dest, false)

	# 旁白框
	var font := T.font_body()
	var size_px: int = clampi(int(r.size.x * 0.055), 9, 13)
	var tx: float = r.position.x + 7.0
	var ty: float = r.position.y + 7.0
	var caption := str(data.get("caption", ""))
	if not caption.is_empty():
		var measured: Vector2 = font.get_multiline_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, text_w - 12.0, size_px)
		var h: float = measured.y + 12.0
		var box := Rect2(tx, ty, text_w, h)
		panel.draw_rect(box, bg if dark else Color(T.INK, 0.92))
		panel.draw_rect(Rect2(box.position, Vector2(2.5, box.size.y)), T.ACCENT)
		panel.draw_multiline_string(font, box.position + Vector2(8, 4 + size_px),
			caption, HORIZONTAL_ALIGNMENT_LEFT, text_w - 14.0, size_px, -1, T.CREAM)
		ty += h + 5.0

	# 对话气泡
	var bubble := str(data.get("bubble", ""))
	if not bubble.is_empty() and ty < r.end.y - 24.0:
		var bsize: int = clampi(int(r.size.x * 0.05), 9, 12)
		var bw: float = minf(text_w, r.size.x * 0.54)
		var measured: Vector2 = font.get_multiline_string_size(bubble, HORIZONTAL_ALIGNMENT_LEFT, bw - 16.0, bsize)
		var bh: float = measured.y + 14.0
		var box := Rect2(tx, minf(ty, r.end.y - bh - 6.0), bw, bh)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(T.CREAM, 0.96) if not dark else Color(T.CREAM, 0.92)
		sb.border_color = T.INK
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(int(minf(bh, 28.0) * 0.5))
		panel.draw_style_box(sb, box)
		# 小尾巴
		var tip := Vector2(box.end.x - 6.0, box.end.y + 7.0)
		panel.draw_colored_polygon(PackedVector2Array([
			Vector2(box.end.x - 12.0, box.end.y - 3.0),
			Vector2(box.end.x - 4.0, box.end.y - 1.0),
			tip,
		]), Color(T.CREAM, 0.95))
		panel.draw_multiline_string(font, box.position + Vector2(8, 4 + bsize),
			bubble, HORIZONTAL_ALIGNMENT_LEFT, bw - 16.0, bsize, -1, T.INK)

	# 框
	panel.draw_rect(r, T.INK, false, 2.0)
	panel.draw_rect(r.grow(-3.0), Color(fg, 0.25), false, 1.0)


## 由页面数据判断这一页是否适合用漫画插页
static func fits(spec: Dictionary, age: int, lifespan: int) -> bool:
	if spec.has("comic_insert"):
		return true
	if age > int(lifespan * 0.5):
		return false
	# 没有动作、没有互动、只有旁白：演不出来，交给漫画
	return str(spec.get("action", "idle")) == "idle" and str(spec.get("prop", "")).is_empty() \
		and not spec.has("pixel_interaction")
