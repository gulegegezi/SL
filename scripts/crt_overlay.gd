## crt_overlay.gd — 老显示器叠层：扫描线 + 暗角。
## 纯绘制、不吃输入；盖在游戏最上层，让整屏统一成「隔着一块旧屏幕」的质感。
extends Control

const SCAN_ALPHA := 0.10
const SCAN_STEP := 3.0
const VIGNETTE_ALPHA := 0.16


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func _draw() -> void:
	var s := size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	# 扫描线：每 3px 一条 1px 暗线
	var y := 0.0
	while y < s.y:
		draw_rect(Rect2(0.0, y, s.x, 1.0), Color(0.0, 0.0, 0.0, SCAN_ALPHA))
		y += SCAN_STEP
	# 暗角：四边由外向内递减的几层，模拟屏幕边缘压暗
	var bands := 18
	for i in range(bands):
		var t := float(i) / float(bands)
		var a := VIGNETTE_ALPHA * (1.0 - t) * (1.0 - t)
		var w := 3.0 + i * 3.4
		draw_rect(Rect2(0.0, 0.0, s.x, w), Color(0.0, 0.0, 0.0, a))
		draw_rect(Rect2(0.0, s.y - w, s.x, w), Color(0.0, 0.0, 0.0, a))
		draw_rect(Rect2(0.0, 0.0, w, s.y), Color(0.0, 0.0, 0.0, a))
		draw_rect(Rect2(s.x - w, 0.0, w, s.y), Color(0.0, 0.0, 0.0, a))
