## comic_panel.gd — 单个分格
## 一格 = 底（纸/网点/黑） + 角色线稿（按镜别裁切） + 旁白框 / 气泡 / 拟声词 + 墨框
extends Control

const T := preload("res://scripts/comic_theme.gd")

var spec: Dictionary = {}
var ink: Texture2D = null
## 面板「画没画上去」：空白格只留框，等剧情推进再逐格填
var revealed := true


func setup(p: Dictionary, ink_tex: Texture2D) -> void:
	spec = p
	ink = ink_tex
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func set_revealed(v: bool) -> void:
	if revealed == v:
		return
	revealed = v
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var tone_kind := str(spec.get("tone", "paper"))
	var dark := tone_kind == "black"
	T.fill(self, r, tone_kind)

	if revealed:
		_draw_ink(r, dark)

	# 墨框（黑板格用纸色描边，否则黑框看不见）
	var frame_col: Color = T.CREAM if dark else T.INK
	T.frame(self, r.grow(-1.5), 3.0, 0.8, frame_col)
	# 内框细线（印刷感）
	if size.x > 120:
		T.frame(self, r.grow(-7.0), 1.0, 0.5, Color(frame_col, 0.35))

	if revealed:
		_draw_text(r, dark)
	else:
		# 空白格：只有框和一个「未发生」，像还没画上去的一格
		var f := T.font_body()
		draw_string(f, Vector2(0, r.size.y * 0.5 + 4), "未发生",
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10, Color(frame_col, 0.30))


# ----------------------------------------------------------
func _draw_ink(r: Rect2, dark: bool) -> void:
	var shot := str(spec.get("shot", "wide"))
	# 黑格先铺速度线，再把米白人物压上去：读起来像「暗场里的剪影」
	if dark:
		T.speed_lines(self, r.grow(-3), r.get_center(), 52, Color(T.CREAM, 0.22), true)
	if ink == null or shot == "detail":
		if not dark:
			T.hatch(self, r.grow(-6), 14, Color(T.INK, 0.18))
		return

	var tw := float(ink.get_width())
	var th := float(ink.get_height())
	var src := Rect2(0, 0, tw, th)
	var h := 0.0
	var cx := r.size.x * 0.5
	var top := 0.0
	var anchor_bottom := true

	# 关键：远景/中景按「脚贴格底」放，特写按「头顶贴格顶」放。
	# 全用脚贴底的话，一放大头就被推到画面上方格外面 —— 只剩一片头发。
	match shot:
		"wide":
			h = r.size.y * 0.72
		"medium":
			h = r.size.y * 0.98
			cx = r.size.x * 0.58
		"close":
			h = r.size.y * 1.42
			top = -r.size.y * 0.03
			anchor_bottom = false
			cx = r.size.x * 0.55
		"extreme":
			h = r.size.y * 2.10
			top = -r.size.y * 0.16
			anchor_bottom = false
			cx = r.size.x * 0.5
		_:
			h = r.size.y * 0.8

	var dx: float = float(spec.get("dx", 0.0))
	if shot == "wide" or shot == "medium":
		cx = r.size.x * (0.5 + dx)
	var w: float = h * (src.size.x / src.size.y)
	# 窄格按高度算会横向溢出 → 改成按宽度收，避免只看到脸中间一条
	if w > r.size.x * 1.04:
		w = r.size.x * 1.04
		h = w * (src.size.y / src.size.x)
	var y: float = (r.size.y + 4.0 - h) if anchor_bottom else top
	var dest := Rect2(Vector2(cx - w * 0.5, y), Vector2(w, h))

	# 镜别辅助线：特写给速度线，远景给地平线排线
	match shot:
		"close", "extreme":
			T.speed_lines(self, r.grow(-4), Vector2(dest.get_center().x, dest.position.y + h * 0.28),
				42, Color(T.INK if not dark else T.CREAM, 0.5))
		"wide":
			T.hatch(self, Rect2(0, r.size.y * 0.80, r.size.x, r.size.y * 0.20), 12,
				Color(T.INK if not dark else T.CREAM, 0.22))

	var flip := bool(spec.get("flip", false))
	if flip:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
		draw_texture_rect_region(ink, Rect2(Vector2(-dest.end.x, dest.position.y), dest.size), src)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 1))
	else:
		draw_texture_rect_region(ink, dest, src)


# ----------------------------------------------------------
func _draw_text(r: Rect2, dark: bool) -> void:
	var cap := str(spec.get("caption", ""))
	var bub := str(spec.get("bubble", ""))
	var sfx_s := str(spec.get("sfx", ""))
	var shot := str(spec.get("shot", "wide"))
	var pad := 8.0
	var col := T.CREAM if dark else T.INK
	# 小格用更小的字号：13px 的旁白框在 5 格版里会盖掉大半格
	var cap_sz := 13
	if r.size.x < 230:
		cap_sz = 11
	if r.size.x < 165:
		cap_sz = 10

	# 黑格里文字反白，所以旁白框改成「透明底 + 白字」
	if not cap.is_empty():
		if dark:
			_draw_caption_dark(r, cap, pad)
		else:
			# 旁白统一压在格子下沿：角色头部永远在格子上方，压上面必定盖脸
			var f := T.font_body()
			var box_w: float = r.size.x - pad * 2 - 8
			var measured: Vector2 = f.get_multiline_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, box_w - 14, cap_sz)
			var y: float = r.end.y - measured.y - pad * 2 - 11
			T.caption_box(self, Vector2(r.position.x + pad, y), cap, box_w, cap_sz, false)

	if not bub.is_empty():
		var bw: float = minf(r.size.x - pad * 2 - 10, 210.0)
		var bub_sz := 13 if bw > 170 else 11
		var f2 := T.font_body()
		var m2: Vector2 = f2.get_multiline_string_size(bub, HORIZONTAL_ALIGNMENT_LEFT, bw - 18, 13)
		var bh: float = maxf(m2.y, 19) + 18
		var bx: float = r.position.x + r.size.x - bw - pad - 8
		var by: float = r.position.y + pad + (0.0 if cap.is_empty() else 34.0)
		if shot == "close" or shot == "extreme":
			bx = r.position.x + pad
			by = r.position.y + pad
		T.bubble(self, Vector2(bx, by), bub, bw, bub_sz, -1 if bx < r.get_center().x else 1)

	if not sfx_s.is_empty():
		if bool(spec.get("vertical", false)):
			# 竖排拟声词靠右放下，别顶到格边被裁掉
			T.sfx_vertical(self, Vector2(r.end.x - 40.0, r.position.y + 14.0), sfx_s, 26,
				T.ACCENT)
		else:
			var sz: int = clampi(int(r.size.x * 0.16), 22, 46)
			T.sfx(self, Vector2(r.position.x + 12.0, r.end.y - 16.0), sfx_s, sz, -0.14,
				T.ACCENT)
	# 页码角标
	var f3 := T.font_body()
	draw_string(f3, Vector2(r.end.x - 22, r.end.y - 8), str(spec.get("idx", "")),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(col, 0.45))


func _draw_caption_dark(r: Rect2, text: String, pad: float) -> void:
	var f := T.font_body()
	var inner: float = r.size.x - pad * 2 - 16
	var sz := 15 if r.size.x > 180 else 13
	var m: Vector2 = f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, inner, sz)
	var y: float = r.get_center().y - m.y * 0.5 + sz
	draw_multiline_string(f, Vector2(r.position.x + pad + 8, y), text,
		HORIZONTAL_ALIGNMENT_CENTER, inner, sz, -1, T.CREAM)
