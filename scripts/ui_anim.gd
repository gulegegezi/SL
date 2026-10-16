## ui_anim.gd — 星露谷风 UI 区域动画库
## ----------------------------------------------------------
## 按手绘模板把主界面切成四个区域，每个区域配一套「语义相符」的动画：
##   ① 数值区：卡片依次弹入 + 数字从旧值滚到新值 + 增减标闪烁 + 抽象度条生长
##   ② 事件区：木牌「哐」地落下（BACK 过冲）+ 正文逐字打字机 + 页脚飘叶
##   ③ 选项区：按钮错峰弹入 + 悬浮抬升 + 按下下沉 + 选中盖章闪光
##   ④ 演出区：深色土槽 + 木框 + 暖色星露谷化配色 + 萤火/光点
##   背景    ：农场天空/云/山丘/草地，随时（年龄）昼夜变化
##
## 全部程序化生成（含运行时 Image → ImageTexture 生成像素贴图），零外部资源依赖
## 所有函数均为 static，调用方传入父节点即可；父节点若是 Container，
## 只使用 modulate / scale / custom_minimum_size（Container 不接管这三个属性），
## 避免与容器布局打架。
class_name UIAnim
extends RefCounted

# ==========================================================
# 星露谷色板
# ==========================================================
const WOOD := Color(0.44, 0.28, 0.15)
const WOOD_DK := Color(0.27, 0.16, 0.08)
const WOOD_LT := Color(0.65, 0.45, 0.24)

const PARCH := Color(0.96, 0.91, 0.77)
const PARCH_DK := Color(0.90, 0.84, 0.66)
const INK := Color(0.27, 0.19, 0.11)
const INK_DIM := Color(0.48, 0.38, 0.27)

const GRASS := Color(0.40, 0.63, 0.27)
const GRASS_LT := Color(0.58, 0.80, 0.36)
const HILL_FAR := Color(0.44, 0.61, 0.54)
const HILL_NEAR := Color(0.31, 0.50, 0.30)

const GOLD := Color(0.96, 0.77, 0.32)
const GOLD_DK := Color(0.62, 0.42, 0.14)

const SD_GREEN := Color(0.42, 0.68, 0.26)
const SD_RED := Color(0.82, 0.29, 0.24)
const SD_PINK := Color(0.93, 0.56, 0.68)

# 演出区（深色土槽）上专用的高对比「涨 / 跌」色
const UP := Color(0.53, 0.87, 0.35)
const DOWN := Color(0.95, 0.40, 0.33)

const LEAF := Color(0.55, 0.74, 0.28)
const LEAF2 := Color(0.89, 0.59, 0.22)
const PETAL := Color(0.95, 0.64, 0.74)

const SOIL := Color(0.19, 0.16, 0.13)
const SOIL_LT := Color(0.25, 0.21, 0.16)
const SOIL_DK := Color(0.14, 0.12, 0.10)

const FIREFLY := Color(1.0, 0.94, 0.58)
const CLOUD := Color(0.99, 0.97, 0.93)

# 天空四段渐变色（上 / 下）
const SKY_DAWN_T := Color(0.35, 0.41, 0.66)
const SKY_DAWN_B := Color(0.96, 0.73, 0.55)
const SKY_DAY_T := Color(0.39, 0.71, 0.94)
const SKY_DAY_B := Color(0.83, 0.94, 0.99)
const SKY_DUSK_T := Color(0.34, 0.29, 0.55)
const SKY_DUSK_B := Color(0.98, 0.62, 0.37)
const SKY_NIGHT_T := Color(0.06, 0.08, 0.21)
const SKY_NIGHT_B := Color(0.19, 0.19, 0.37)

const GROUND_H := 118.0  # 草地占屏高

# ==========================================================
# 运行时像素贴图生成
# ==========================================================
## 圆形光球（太阳 / 月亮），边缘按距离柔化
static func _orb_tex(r: int, col: Color, use_moon: bool = false) -> ImageTexture:
	var d := r * 2 + 1
	var img := Image.create_empty(d, d, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var cf := float(r)
	for x in range(d):
		for y in range(d):
			var dx := float(x) - cf
			var dy := float(y) - cf
			var dd := sqrt(dx * dx + dy * dy)
			if dd > cf:
				continue
			if use_moon:
				# 月牙：挖掉偏右上的圆
				var mx := dx - cf * 0.62
				var my := dy + cf * 0.30
				if mx * mx + my * my <= cf * cf * 0.86:
					continue
			var edge := clampf((cf - dd) / 1.8, 0.0, 1.0)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, edge))
	return ImageTexture.create_from_image(img)

## 山丘剪影：三层正弦叠加生成山脊线，顶部再加一条亮色草边
static func _hill_tex(w: int, h: int, col: Color, seedv: int) -> ImageTexture:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = seedv
	var p1 := rng.randf() * TAU
	var p2 := rng.randf() * TAU
	var p3 := rng.randf() * TAU
	var f1 := 0.016 + rng.randf() * 0.020
	var f2 := 0.052 + rng.randf() * 0.030
	var f3 := 0.135 + rng.randf() * 0.060
	var tops := PackedInt32Array()
	for x in range(w):
		var fx := float(x)
		var n := sin(fx * f1 + p1) * 0.55 + sin(fx * f2 + p2) * 0.28 + sin(fx * f3 + p3) * 0.10
		var top := int(clampf((0.62 - n * 0.44) * float(h), 1.0, float(h - 2)))
		tops.append(top)
		for y in range(top, h):
			img.set_pixel(x, y, col)
	var lip := Color(minf(col.r + 0.17, 1.0), minf(col.g + 0.17, 1.0), minf(col.b + 0.10, 1.0))
	for x in range(w):
		img.set_pixel(x, tops[x], lip)
	return ImageTexture.create_from_image(img)

## 像素云：若干重叠椭圆
static func _cloud_tex(w: int, h: int, seedv: int) -> ImageTexture:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = seedv
	var n := rng.randi_range(3, 5)
	var cxs := PackedFloat32Array()
	var cys := PackedFloat32Array()
	var crs := PackedFloat32Array()
	for i in range(n):
		cxs.append(rng.randf_range(0.26, 0.74) * float(w))
		cys.append(rng.randf_range(0.38, 0.62) * float(h))
		crs.append(rng.randf_range(0.15, 0.29) * float(h))
	for x in range(w):
		for y in range(h):
			for i in range(n):
				var dx := float(x) - cxs[i]
				var dy := (float(y) - cys[i]) * 1.75
				var r := crs[i]
				if dx * dx + dy * dy <= r * r:
					img.set_pixel(x, y, CLOUD)
					break
	return ImageTexture.create_from_image(img)

## 草地：底色 + 深浅草簇 + 零星小花
static func _grass_tex(w: int, h: int, seedv: int) -> ImageTexture:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(GRASS)
	var rng := RandomNumberGenerator.new()
	rng.seed = seedv
	var dark := Color(0.31, 0.51, 0.20)
	for i in range(int(float(w) * 0.5)):
		var x := rng.randi_range(0, w - 1)
		var hh := rng.randi_range(2, maxi(3, int(float(h) * 0.42)))
		var col := GRASS_LT if rng.randf() < 0.55 else dark
		for k in range(hh):
			var y := h - 1 - k
			if y >= 0:
				img.set_pixel(x, y, col)
	var flowers := [SD_PINK, GOLD, Color(0.72, 0.80, 0.96), Color(0.95, 0.95, 0.90)]
	for i in range(int(float(w) * 0.06)):
		var x2 := rng.randi_range(0, w - 1)
		var y2 := rng.randi_range(int(float(h) * 0.55), h - 1)
		var fc: Color = flowers[rng.randi_range(0, flowers.size() - 1)]
		img.set_pixel(x2, y2, fc)
	return ImageTexture.create_from_image(img)

# ==========================================================
# 工具
# ==========================================================
static func _px(parent: Control, pos: Vector2, size: Vector2, col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.size = size
	r.position = pos
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r

## 建一个带 _bg 标记的方块（演出区重建底景时只清这类节点，不动 VFX 粒子）
static func _bgpx(parent: Control, pos: Vector2, size: Vector2, col: Color) -> ColorRect:
	var r := _px(parent, pos, size, col)
	r.set_meta("_bg", true)
	return r

## 复用同名 tween：先把上一次同类动画 kill 掉，避免多个 tween 抢同一个属性
static func _retween(n: Node, key: String) -> Tween:
	if n.has_meta(key):
		var old: Variant = n.get_meta(key)
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	var tw := n.create_tween()
	n.set_meta(key, tw)
	return tw

## 让节点的缩放中心保持在自身中心
static func _center_pivot(c: Control) -> void:
	c.pivot_offset = c.size * 0.5
	c.resized.connect(func(): c.pivot_offset = c.size * 0.5)

static func _tex_rect(parent: Control, tex: Texture2D, a_left: float, a_top: float,
		a_right: float, a_bottom: float, o_left: float, o_top: float,
		o_right: float, o_bottom: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.anchor_left = a_left
	t.anchor_top = a_top
	t.anchor_right = a_right
	t.anchor_bottom = a_bottom
	t.offset_left = o_left
	t.offset_top = o_top
	t.offset_right = o_right
	t.offset_bottom = o_bottom
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	return t

# ==========================================================
# 背景：星露谷农场（随年龄昼夜变化）
# ==========================================================
## age → 一天中的时刻（0 清晨 … 1 深夜），把一辈子压缩成一天
static func time_for_age(age: int) -> float:
	return clampf(float(age) / 78.0, 0.0, 1.0)

static func make_backdrop() -> Control:
	var root := Control.new()
	root.name = "Backdrop"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_FULL_RECT)

	# --- 天空（GradientTexture2D，颜色由 set_time 改写）---
	var grad := Gradient.new()
	grad.set_color(0, SKY_DAWN_T)
	grad.set_color(1, SKY_DAWN_B)
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_LINEAR
	gt.fill_from = Vector2(0.0, 0.0)
	gt.fill_to = Vector2(0.0, 1.0)
	gt.width = 4
	gt.height = 128
	var sky := _tex_rect(root, gt, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0)
	sky.name = "Sky"

	# --- 太阳 / 月亮 ---
	var sun := _tex_rect(root, _orb_tex(11, Color(1.0, 0.94, 0.66)), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 26.0, 26.0)
	sun.name = "Sun"

	# --- 云（3 朵，横向漂移）---
	for i in range(3):
		var cw := 70 + i * 22
		var chh := 26 + i * 6
		var cl := _tex_rect(root, _cloud_tex(cw, chh, 9100 + i * 37),
			0.0, 0.0, 0.0, 0.0, 0.0, 0.0, float(cw), float(chh))
		cl.name = "Cloud%d" % i
		cl.modulate.a = 0.55 + 0.15 * float(i)

	# --- 远山 / 近山 ---
	var hf := _tex_rect(root, _hill_tex(170, 46, HILL_FAR, 20261016),
		0.0, 1.0, 1.0, 1.0, 0.0, -(GROUND_H + 116.0), 0.0, -GROUND_H)
	hf.name = "HillFar"
	var hn := _tex_rect(root, _hill_tex(170, 34, HILL_NEAR, 771),
		0.0, 1.0, 1.0, 1.0, 0.0, -(GROUND_H + 62.0), 0.0, -GROUND_H + 10.0)
	hn.name = "HillNear"

	# --- 草地 ---
	var gnd := _tex_rect(root, _grass_tex(170, 40, 5150),
		0.0, 1.0, 1.0, 1.0, 0.0, -GROUND_H, 0.0, 0.0)
	gnd.name = "Ground"

	# --- 木栅栏（草地前沿一排，纯色块拼）---
	var fence := Control.new()
	fence.name = "Fence"
	fence.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fence.anchor_left = 0.0
	fence.anchor_right = 1.0
	fence.anchor_top = 1.0
	fence.anchor_bottom = 1.0
	fence.offset_left = 0.0
	fence.offset_right = 0.0
	fence.offset_top = -GROUND_H - 4.0
	fence.offset_bottom = -GROUND_H + 26.0
	root.add_child(fence)

	# --- 昼夜染色层 ---
	var tint := _px(root, Vector2.ZERO, Vector2(0.0, 0.0), Color(0.05, 0.06, 0.20, 0.0))
	tint.name = "Tint"
	tint.set_anchors_preset(Control.PRESET_FULL_RECT)

	# --- 萤火（夜间才亮）---
	var ff := Control.new()
	ff.name = "Fireflies"
	ff.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ff.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(ff)
	ff.modulate.a = 0.0

	root.resized.connect(_backdrop_relayout.bind(root))
	_backdrop_relayout(root)
	return root

## 背景尺寸变化后重排栅栏 + 重摆太阳
static func _backdrop_relayout(root: Control) -> void:
	var w := root.size.x
	if w <= 0.0:
		w = 520.0
	var fence := root.get_node_or_null("Fence") as Control
	if fence != null:
		for ch in fence.get_children():
			ch.queue_free()
		var step := 26.0
		var n := int(w / step) + 2
		for i in range(n):
			var x := float(i) * step
			_bgpx(fence, Vector2(x, 0.0), Vector2(4.0, 30.0), WOOD)
			_bgpx(fence, Vector2(x, 0.0), Vector2(4.0, 2.0), WOOD_LT)
		_bgpx(fence, Vector2(0.0, 8.0), Vector2(w, 4.0), WOOD)
		_bgpx(fence, Vector2(0.0, 22.0), Vector2(w, 3.0), WOOD)
	# 云初始位置
	for i in range(3):
		var cl := root.get_node_or_null("Cloud%d" % i) as TextureRect
		if cl != null and cl.position.x <= 0.0:
			cl.position = Vector2(w * (0.10 + 0.34 * float(i)), 58.0 + 62.0 * float(i))

## 依时刻 t 改写天空/太阳/染色/萤火
static func set_time(bg: Control, t: float) -> void:
	if bg == null or not is_instance_valid(bg):
		return
	var tt := clampf(t, 0.0, 1.0)
	var w := bg.size.x
	var h := bg.size.y
	if w <= 0.0:
		w = 520.0
	if h <= 0.0:
		h = 900.0

	var sky := bg.get_node_or_null("Sky") as TextureRect
	if sky != null:
		var gt := sky.texture as GradientTexture2D
		if gt != null and gt.gradient != null:
			gt.gradient.set_color(0, _sky_col(tt, true))
			gt.gradient.set_color(1, _sky_col(tt, false))

	var is_night := tt > 0.72
	var sun := bg.get_node_or_null("Sun") as TextureRect
	if sun != null:
		var is_sun_tex: bool = bool(sun.get_meta("_is_sun", true))
		if is_night and is_sun_tex:
			sun.texture = _orb_tex(11, Color(0.93, 0.95, 1.0), true)
			sun.set_meta("_is_sun", false)
		elif not is_night and not is_sun_tex:
			sun.texture = _orb_tex(11, Color(1.0, 0.94, 0.66))
			sun.set_meta("_is_sun", true)
		# 沿弧线升落：t=0 地平线左侧 → t=0.5 高空 → t=1 右侧落下
		var px := lerpf(w * 0.08, w * 0.90, tt)
		var py := h * 0.42 - sin(PI * tt) * h * 0.27
		sun.position = Vector2(px, py)
		sun.modulate.a = 1.0
		var warm := Color(1.0, 0.97, 0.90).lerp(Color(1.0, 0.78, 0.52), clampf((absf(tt - 0.5) - 0.18) / 0.32, 0.0, 1.0))
		sun.modulate = warm

	# 山丘/草地随夜色压暗偏蓝
	var night_mul := Color(1.0, 1.0, 1.0).lerp(Color(0.52, 0.58, 0.86), clampf((tt - 0.55) / 0.45, 0.0, 1.0))
	for nm in PackedStringArray(["HillFar", "HillNear", "Ground"]):
		var nd := bg.get_node_or_null(nm) as TextureRect
		if nd != null:
			nd.modulate = night_mul
	var fence := bg.get_node_or_null("Fence") as Control
	if fence != null:
		fence.modulate = night_mul

	# 云随夜色变淡
	for i in range(3):
		var cl := bg.get_node_or_null("Cloud%d" % i) as TextureRect
		if cl != null:
			cl.modulate.a = (0.55 + 0.15 * float(i)) * lerpf(1.0, 0.25, clampf((tt - 0.6) / 0.4, 0.0, 1.0))

	var tint := bg.get_node_or_null("Tint") as ColorRect
	if tint != null:
		var na := clampf((tt - 0.60) / 0.32, 0.0, 1.0) * 0.44
		tint.color = Color(0.04, 0.05, 0.19, na)

	var ff := bg.get_node_or_null("Fireflies") as Control
	if ff != null:
		ff.modulate.a = clampf((tt - 0.64) / 0.26, 0.0, 1.0)

static func _sky_col(t: float, top_side: bool) -> Color:
	if top_side:
		if t < 0.42:
			return SKY_DAWN_T.lerp(SKY_DAY_T, clampf(t / 0.42, 0.0, 1.0))
		if t < 0.68:
			return SKY_DAY_T.lerp(SKY_DUSK_T, clampf((t - 0.42) / 0.26, 0.0, 1.0))
		return SKY_DUSK_T.lerp(SKY_NIGHT_T, clampf((t - 0.68) / 0.32, 0.0, 1.0))
	if t < 0.42:
		return SKY_DAWN_B.lerp(SKY_DAY_B, clampf(t / 0.42, 0.0, 1.0))
	if t < 0.68:
		return SKY_DAY_B.lerp(SKY_DUSK_B, clampf((t - 0.42) / 0.26, 0.0, 1.0))
	return SKY_DUSK_B.lerp(SKY_NIGHT_B, clampf((t - 0.68) / 0.32, 0.0, 1.0))

## 云飘动 + 山丘轻微起伏 + 萤火（常驻，只建一次）
static func ambient(bg: Control) -> void:
	if bg == null or not is_instance_valid(bg):
		return
	for i in range(3):
		var cl := bg.get_node_or_null("Cloud%d" % i) as TextureRect
		if cl != null:
			var w := bg.size.x
			if w <= 0.0:
				w = 520.0
			var tw := cl.create_tween()
			tw.set_loops()
			var dur := 58.0 + 22.0 * float(i)
			tw.tween_property(cl, "position:x", w + 90.0, dur)
			tw.tween_callback(func():
				cl.position.x = -120.0)
	for nm in ["HillFar", "HillNear"]:
		var nd := bg.get_node_or_null(nm) as TextureRect
		if nd != null:
			var base := nd.offset_top
			var tw2 := nd.create_tween()
			tw2.set_loops()
			tw2.tween_property(nd, "offset_top", base - 3.0, 3.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw2.tween_property(nd, "offset_top", base, 3.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var ff := bg.get_node_or_null("Fireflies") as Control
	if ff != null:
		fireflies(ff, 12)

# ==========================================================
# ① 数值区动画
# ==========================================================
## 属性卡错峰弹入
static func stat_card_in(card: Control, idx: int) -> void:
	_center_pivot(card)
	card.modulate.a = 0.0
	card.scale = Vector2(0.80, 0.80)
	var tw := _retween(card, "_in")
	var d := 0.055 * float(idx)
	tw.tween_property(card, "modulate:a", 1.0, 0.22).set_delay(d)
	tw.parallel().tween_property(card, "scale", Vector2.ONE, 0.36).set_delay(d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## 数字从 from_v 滚到 to_v；涨绿跌红（星露谷的绿/红是自然色，不含股市语义）
static func count_up(lbl: Label, from_v: int, to_v: int, col: Color, delay: float = 0.0) -> void:
	lbl.add_theme_color_override("font_color", col)
	if from_v == to_v:
		lbl.text = str(to_v)
		_center_pivot(lbl)
		var tb := _retween(lbl, "_bump")
		tb.tween_property(lbl, "scale", Vector2(1.18, 1.18), 0.10).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tb.tween_property(lbl, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		return
	lbl.text = str(from_v)
	_center_pivot(lbl)
	var tw := _retween(lbl, "_count")
	tw.tween_method(func(v: float): lbl.text = str(int(round(v))),
			float(from_v), float(to_v), 0.46).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var tb := _retween(lbl, "_bump")
	tb.tween_property(lbl, "scale", Vector2(1.22, 1.22), 0.12).set_delay(delay + 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tb.tween_property(lbl, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## 增减标记：在数值旁闪一下「+3」/「-2」
static func delta_flash(lbl: Label, txt: String, col: Color, delay: float = 0.0) -> void:
	lbl.text = txt
	lbl.add_theme_color_override("font_color", col)
	lbl.modulate.a = 0.0
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "modulate:a", 1.0, 0.14).set_delay(delay)
	tw.tween_property(lbl, "modulate:a", 1.0, 0.75)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.40)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.40)

## 抽象度条生长 + 尖端高光
static func bar_grow(fill: Control, from_w: float, to_w: float, delay: float = 0.0) -> void:
	var hgt := fill.custom_minimum_size.y
	if hgt <= 0.0:
		hgt = 9.0
	fill.custom_minimum_size = Vector2(from_w, hgt)
	var tw := _retween(fill, "_bar")
	tw.tween_method(func(v: float): fill.custom_minimum_size = Vector2(v, hgt),
			from_w, to_w, 0.52).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## 整数倍错峰淡入（用于标题行、标签行等一组节点）
static func stagger_in(nodes: Array, step: float = 0.07, delay: float = 0.0) -> void:
	for i in range(nodes.size()):
		var n: Control = nodes[i]
		_center_pivot(n)
		n.modulate.a = 0.0
		n.scale = Vector2(0.90, 0.90)
		var tw := _retween(n, "_in")
		var d := delay + step * float(i)
		tw.tween_property(n, "modulate:a", 1.0, 0.24).set_delay(d)
		tw.parallel().tween_property(n, "scale", Vector2.ONE, 0.34).set_delay(d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ==========================================================
# ② 事件区动画
# ==========================================================
## 木牌落下：纵向展开 + BACK 过冲 + 落地横晃
static func signboard_drop(card: Control, delay: float = 0.0) -> void:
	card.pivot_offset = Vector2.ZERO
	card.modulate.a = 0.0
	card.scale = Vector2(1.0, 0.05)
	var t1 := card.create_tween()
	t1.tween_property(card, "modulate:a", 1.0, 0.16).set_delay(delay)
	var t2 := card.create_tween()
	t2.tween_property(card, "scale:y", 1.0, 0.42).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var t3 := _retween(card, "_shake")
	t3.tween_property(card, "scale:x", 1.035, 0.055).set_delay(delay + 0.40)
	t3.tween_property(card, "scale:x", 0.982, 0.070)
	t3.tween_property(card, "scale:x", 1.0, 0.080)

## 打字机：逐字显示
static func typewriter(lbl: Label, full_text: String, cps: float = 52.0, delay: float = 0.45) -> void:
	lbl.text = full_text
	lbl.visible_characters = 0
	var n := float(full_text.length())
	if n <= 0.0:
		return
	var dur := maxf(0.18, n / maxf(1.0, cps))
	var tw := lbl.create_tween()
	tw.tween_method(func(v: float): lbl.visible_characters = int(round(v)), 0.0, n, dur).set_delay(delay)

# ==========================================================
# ③ 选项区动画
# ==========================================================
static func choices_in(btns: Array) -> void:
	for i in range(btns.size()):
		var b: Control = btns[i]
		_center_pivot(b)
		b.modulate.a = 0.0
		b.scale = Vector2(0.94, 0.70)
		var tw := _retween(b, "_state")
		var d := 0.13 + 0.055 * float(i)
		tw.tween_property(b, "modulate:a", 1.0, 0.20).set_delay(d)
		tw.parallel().tween_property(b, "scale", Vector2.ONE, 0.34).set_delay(d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## 悬浮抬升 / 按下下沉；主按钮改为缓慢呼吸
static func hook_button(btn: Button, primary: bool = false) -> void:
	_center_pivot(btn)
	btn.mouse_entered.connect(func(): _btn_state(btn, "hover"))
	btn.mouse_exited.connect(func(): _btn_state(btn, "idle"))
	btn.button_down.connect(func(): _btn_state(btn, "press"))
	btn.button_up.connect(func(): _btn_state(btn, "hover"))
	if primary:
		var tw := _retween(btn, "_breath")
		tw.set_loops()
		tw.tween_property(btn, "modulate", Color(1.10, 1.08, 0.92, 1.0), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(btn, "modulate", Color(1.0, 1.0, 1.0, 1.0), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

static func _btn_state(btn: Control, state: String) -> void:
	if btn is Button and (btn as Button).disabled:
		return
	var tw := _retween(btn, "_state")
	btn.modulate.a = 1.0
	match state:
		"hover":
			tw.tween_property(btn, "scale", Vector2(1.035, 1.035), 0.13).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		"press":
			tw.tween_property(btn, "scale", Vector2(0.972, 0.952), 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_:
			tw.tween_property(btn, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## 选中盖章：暖色闪光 + ✔ 章印拍下
static func stamp(btn: Button, col: Color) -> void:
	var w := btn.size.x
	if w <= 0.0:
		w = 300.0
	var fl := ColorRect.new()
	fl.color = Color(col.r, col.g, col.b, 0.0)
	fl.set_anchors_preset(Control.PRESET_FULL_RECT)
	fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(fl)
	var tf := fl.create_tween()
	tf.tween_property(fl, "color:a", 0.34, 0.08)
	tf.tween_property(fl, "color:a", 0.0, 0.46)
	tf.finished.connect(fl.queue_free)

	var l := Label.new()
	l.text = "✔"
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", 20)
	l.position = Vector2(w - 30.0, maxf(0.0, (btn.size.y - 22.0) * 0.5))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.pivot_offset = Vector2(11.0, 11.0)
	l.scale = Vector2(2.6, 2.6)
	l.rotation = -0.35
	l.modulate.a = 0.0
	btn.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.07)
	tw.parallel().tween_property(l, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "rotation", 0.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.34).set_delay(0.75)
	tw.finished.connect(l.queue_free)

# ==========================================================
# ④ 演出区动画
# ==========================================================
## 深色土槽 + 木框（重建式：只清 _bg 标记节点，VFX 粒子不受影响）
static func stage_backdrop(stage: Control) -> void:
	for ch in stage.get_children():
		if ch.has_meta("_bg"):
			ch.queue_free()
	var w := stage.size.x
	var h := stage.size.y
	if w <= 0.0:
		w = 320.0
	if h <= 0.0:
		h = 140.0

	_bgpx(stage, Vector2.ZERO, Vector2(w, h), SOIL)
	# 土壤横向纹理
	var rows := int(h / 9.0) + 1
	for i in range(rows):
		var c := SOIL_LT if i % 2 == 0 else SOIL_DK
		_bgpx(stage, Vector2(0.0, float(i) * 9.0), Vector2(w, 1.0), Color(c.r, c.g, c.b, 0.6))
	# 石子颗粒
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261016
	for i in range(int(w / 6.0)):
		var g := rng.randf_range(0.24, 0.42)
		_bgpx(stage, Vector2(rng.randf_range(3.0, maxf(4.0, w - 5.0)), rng.randf_range(4.0, maxf(5.0, h - 5.0))),
			Vector2(rng.randf_range(1.0, 2.6), rng.randf_range(1.0, 2.6)), Color(g, g * 0.94, g * 0.82))
	wood_frame(stage)

## 木框 + 内侧高光 + 四角木钉
static func wood_frame(stage: Control) -> void:
	var w := stage.size.x
	var h := stage.size.y
	if w <= 0.0:
		w = 320.0
	if h <= 0.0:
		h = 140.0
	var t := 4.0
	_bgpx(stage, Vector2.ZERO, Vector2(w, t), WOOD)
	_bgpx(stage, Vector2(0.0, h - t), Vector2(w, t), WOOD)
	_bgpx(stage, Vector2.ZERO, Vector2(t, h), WOOD)
	_bgpx(stage, Vector2(w - t, 0.0), Vector2(t, h), WOOD)
	# 内侧高光（左上两条，模拟受光）
	var hi := Color(WOOD_LT.r, WOOD_LT.g, WOOD_LT.b, 0.55)
	_bgpx(stage, Vector2(t, t), Vector2(w - t * 2.0, 1.0), hi)
	_bgpx(stage, Vector2(t, t), Vector2(1.0, h - t * 2.0), hi)
	# 外侧暗边
	_bgpx(stage, Vector2(0.0, h - 1.0), Vector2(w, 1.0), Color(WOOD_DK.r, WOOD_DK.g, WOOD_DK.b, 0.8))
	_bgpx(stage, Vector2(w - 1.0, 0.0), Vector2(1.0, h), Color(WOOD_DK.r, WOOD_DK.g, WOOD_DK.b, 0.8))
	# 四角木钉
	_bgpx(stage, Vector2(t + 2.0, t + 2.0), Vector2(5.0, 5.0), GOLD_DK)
	_bgpx(stage, Vector2(w - t - 7.0, t + 2.0), Vector2(5.0, 5.0), GOLD_DK)
	_bgpx(stage, Vector2(t + 2.0, h - t - 7.0), Vector2(5.0, 5.0), GOLD_DK)
	_bgpx(stage, Vector2(w - t - 7.0, h - t - 7.0), Vector2(5.0, 5.0), GOLD_DK)

## 选择后的暖色光点四散（垫在主题 VFX 之下）
static func soft_burst(parent: Control, w: float, h: float, col: Color) -> void:
	var cx := w * 0.5
	var cy := h * 0.5
	for i in range(10):
		var ang := TAU * float(i) / 10.0
		var p := _px(parent, Vector2(cx - 2.5, cy - 2.5), Vector2(5.0, 5.0), col)
		p.pivot_offset = p.size * 0.5
		var dist := 30.0 + float(i % 3) * 18.0
		var tw := p.create_tween()
		tw.tween_property(p, "position", Vector2(cx - 2.5 + cos(ang) * dist, cy - 2.5 + sin(ang) * dist), 0.46).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(p, "modulate:a", 0.0, 0.46)
		tw.parallel().tween_property(p, "rotation", randf_range(-3.0, 3.0), 0.46)
		tw.finished.connect(p.queue_free)

## 暖色微光粒：在演出区缓慢上浮
static func embers(parent: Control, w: float, h: float, n: int = 8) -> void:
	for i in range(n):
		var p := _px(parent, Vector2(randf_range(6.0, maxf(7.0, w - 6.0)), h - randf_range(4.0, 20.0)),
			Vector2(2.0, 2.0), GOLD)
		p.modulate.a = 0.0
		var tw := p.create_tween()
		tw.set_loops()
		var dur := 1.5 + randf() * 1.4
		tw.tween_property(p, "modulate:a", 0.85, dur * 0.35).set_delay(randf() * 0.6)
		tw.parallel().tween_property(p, "position:y", h * 0.15, dur).set_delay(randf() * 0.4)
		tw.tween_property(p, "modulate:a", 0.0, dur * 0.4)

## 全屏飘叶（页脚随时间缓缓飘落，循环）
static func leaves_drift(parent: Control, n: int = 7) -> void:
	var w := parent.size.x
	var h := parent.size.y
	if w <= 0.0:
		w = 520.0
	if h <= 0.0:
		h = 900.0
	var cols := [LEAF, LEAF2, PETAL]
	for i in range(n):
		var sz := 4.0 + randf() * 4.0
		var p := _px(parent, Vector2(randf() * w, -14.0), Vector2(sz, sz), cols[i % cols.size()])
		p.pivot_offset = p.size * 0.5
		p.modulate.a = 0.0
		var tw := p.create_tween()
		tw.set_loops()
		var dur := 8.0 + randf() * 6.0
		var x0 := p.position.x
		tw.tween_property(p, "modulate:a", 0.85, 0.4)
		tw.parallel().tween_property(p, "position", Vector2(x0 + randf_range(-80.0, 80.0), h + 18.0), dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(p, "rotation", randf_range(3.0, 8.0), dur)
		tw.parallel().tween_property(p, "modulate:a", 0.0, dur * 0.3).set_delay(dur * 0.7)
		tw.tween_callback(func(): p.position = Vector2(randf() * w, -14.0))

## 萤火虫（夜间）：缓飘 + 明灭
static func fireflies(parent: Control, n: int = 10) -> void:
	var w := parent.size.x
	var h := parent.size.y
	if w <= 0.0:
		w = 520.0
	if h <= 0.0:
		h = 900.0
	for i in range(n):
		var p := _px(parent, Vector2(randf_range(10.0, maxf(11.0, w - 10.0)), randf_range(h * 0.34, h * 0.96)),
			Vector2(3.0, 3.0), FIREFLY)
		p.modulate.a = 0.0
		var y0 := p.position.y
		var x0 := p.position.x
		var tw := p.create_tween()
		tw.set_loops()
		var dur := 1.8 + randf() * 1.9
		tw.tween_property(p, "modulate:a", 0.95, dur * 0.36)
		tw.parallel().tween_property(p, "position", Vector2(x0 + randf_range(-26.0, 26.0), y0 - randf_range(12.0, 40.0)), dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(p, "modulate:a", 0.0, dur * 0.5)
		tw.tween_callback(func():
			p.position = Vector2(randf_range(10.0, maxf(11.0, w - 10.0)), randf_range(h * 0.34, h * 0.96)))
