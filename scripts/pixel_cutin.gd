extends RefCounted
## pixel_cutin.gd — 动作漫画弹窗
##
## 动作触发的那一刻，不靠 3D 动画硬演，而是弹一张「漫画分格」：
## 斜切的墨框 + 网点 + 动作立绘 + 竖排拟声词 + 一行标题。
## 复用 comic_actions / comic_expressions 的现成图，不新增资源。
##
## 时间轴（默认 1.8s）：
##   0.00–0.24 弹出（0.72→1.06 倍，带回弹）
##   0.24–0.42 落定（1.06→1.00）
##   0.42–1.45 停留
##   1.45–1.80 收走（淡出 + 轻微放大）

const T := preload("res://scripts/comic_theme.gd")
const Art := preload("res://scripts/comic_art.gd")

const DURATION := 1.8
const HOLD_END := 1.45


static func active(t: float) -> bool:
	return t >= 0.0 and t < DURATION


static func draw(panel: Control, area: Rect2, t: float, data: Dictionary) -> void:
	if not active(t) or area.size.x < 40.0:
		return
	var alpha: float = smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(HOLD_END, DURATION, t))
	if alpha <= 0.01:
		return
	# 弹出：先冲过 1.0，再回落到 1.0
	var pop: float = clampf(t / 0.24, 0.0, 1.0)
	var scale: float = lerpf(0.72, 1.06, ease(pop, -1.9))
	if t > 0.24:
		scale = lerpf(1.06, 1.0, clampf((t - 0.24) / 0.18, 0.0, 1.0))
	var rot: float = lerpf(-0.14, -0.045, clampf(t / 0.3, 0.0, 1.0))
	var w: float = area.size.x * 0.84
	var h: float = minf(area.size.y * 0.70, w * 0.62)
	var center: Vector2 = area.position + area.size * 0.5
	var ink := Color(T.INK, alpha)
	var cream := Color(T.CREAM, alpha)
	panel.draw_set_transform(center, rot, Vector2(scale, scale))
	var frame := Rect2(-w * 0.5, -h * 0.5, w, h)

	# 影子 + 纸边 + 墨框
	panel.draw_rect(Rect2(frame.position + Vector2(6, 7), frame.size), Color(0.0, 0.0, 0.0, 0.45 * alpha))
	panel.draw_rect(frame, cream)
	panel.draw_rect(frame.grow(-4.0), ink, false, 1.5)
	panel.draw_rect(frame.grow(-1.0), ink, false, 3.0)

	# 网点：斜向排布的小点，给「印刷」的底
	var step := 7.0
	var y := frame.position.y + 10.0
	var row := 0
	while y < frame.end.y - 34.0:
		var x := frame.position.x + 10.0 + (step * 0.5 if row % 2 == 1 else 0.0)
		while x < frame.end.x - 64.0:
			panel.draw_circle(Vector2(x, y), 0.9, Color(T.INK, 0.12 * alpha))
			x += step
		y += step
		row += 1

	# 动作立绘：优先动作帧，没有就用表情立绘
	var key := str(data.get("key", "lead_adult"))
	var action := str(data.get("action", ""))
	var expression := str(data.get("expression", "normal"))
	var art: Texture2D = Art.action_pose(key, action)
	if art == null:
		art = Art.portrait(key, 0, expression)
	if art != null:
		var box := Rect2(frame.position.x + w * 0.30, frame.position.y + 6.0, w * 0.66, h - 38.0)
		var tex_size := art.get_size()
		var fit: float = minf(box.size.x / maxf(1.0, tex_size.x), box.size.y / maxf(1.0, tex_size.y))
		var dest := Rect2(box.position + (box.size - tex_size * fit) * 0.5, tex_size * fit)
		panel.draw_texture_rect(art, dest, false, Color(1, 1, 1, alpha))

	# 竖排拟声词
	var sfx := str(data.get("sfx", "！"))
	var big := T.font_big()
	var sx: float = frame.position.x + 22.0
	var sy: float = frame.position.y + 40.0
	for i in range(sfx.length()):
		var ch := sfx.substr(i, 1)
		panel.draw_string(big, Vector2(sx, sy), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(T.ACCENT, alpha))
		sy += 32.0

	# 标题条
	var strip := Rect2(frame.position.x + 6.0, frame.end.y - 34.0, frame.size.x - 12.0, 28.0)
	panel.draw_rect(strip, Color(T.INK, 0.92 * alpha))
	panel.draw_rect(Rect2(strip.position, Vector2(3.0, strip.size.y)), Color(T.ACCENT, alpha))
	var title := str(data.get("title", ""))
	var body := T.font_body()
	panel.draw_string(body, Vector2(strip.position.x + 10.0, strip.position.y + 19.0), title,
		HORIZONTAL_ALIGNMENT_LEFT, strip.size.x - 70.0, 13, cream)
	panel.draw_string(body, Vector2(strip.end.x - 54.0, strip.position.y + 19.0), "动作",
		HORIZONTAL_ALIGNMENT_RIGHT, -1, 10, Color(T.CREAM, 0.55 * alpha))

	panel.draw_set_transform(Vector2.ZERO)


## 招式 → 拟声词：没有数据时按动作兜底
static func sfx_for(action: String) -> String:
	return {
		"drum": "咚",
		"draw": "唰",
		"sign": "唰",
		"read": "哗",
		"phone": "嗡",
		"wave": "嗨",
		"reach": "！",
		"receive": "…",
		"offer": "给",
		"raise": "！",
	}.get(action, "！")
