extends RefCounted
## 小道具在分镜坐标内绘制，交互与结果镜头共用同一形状。
const T := preload("res://scripts/comic_theme.gd")
static func ellipse(canvas: CanvasItem, r: Rect2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(32): points.append(r.get_center()+Vector2(cos(i*TAU/32),sin(i*TAU/32))*r.size*0.5)
	canvas.draw_colored_polygon(points,color)
static func draw_on(canvas: CanvasItem, kind: String, r: Rect2, progress: float = 0) -> void:
	var o := r.position
	var s := r.size
	match kind:
		"toy":
			canvas.draw_circle(o+s*Vector2(0.3,0.25),s.x*0.14,T.CREAM)
			canvas.draw_circle(o+s*Vector2(0.7,0.25),s.x*0.14,T.CREAM)
			canvas.draw_circle(o+s*0.5,s.x*0.34,T.CREAM)
			for x in [0.39,0.61]: canvas.draw_circle(o+s*Vector2(x,0.46),3,T.INK)
			canvas.draw_circle(o+s*Vector2(0.5,0.62),4,T.ACCENT)
		"eraser":
			canvas.draw_rect(Rect2(o+s*0.15,s*0.65),T.CREAM)
			canvas.draw_rect(Rect2(o+s*Vector2(0.15,0.15),s*Vector2(0.24,0.65)),T.ACCENT)
		"pencil":
			canvas.draw_line(o+s*Vector2(0.22,0.78),o+s*Vector2(0.75,0.22),T.CREAM,10)
			canvas.draw_line(o+s*Vector2(0.22,0.78),o+s*Vector2(0.13,0.88),T.INK,5)
		"drum":
			canvas.draw_rect(Rect2(o+s*Vector2(0.1,0.38),s*Vector2(0.8,0.43)),T.ACCENT)
			ellipse(canvas,Rect2(o+s*Vector2(0.1,0.20),s*Vector2(0.8,0.36)),T.CREAM)
			for x in [0.2,0.5,0.8]: canvas.draw_line(o+s*Vector2(x,0.48),o+s*Vector2(x,0.80),T.INK,2)
			canvas.draw_line(o+s*Vector2(0.15,0.05),o+s*Vector2(0.55,0.18+progress*0.18),T.CREAM,5)
			if progress > 0: canvas.draw_arc(o+s*Vector2(0.5,0.35),s.x*0.44,PI,TAU,12,T.CREAM,2)
		"clock":
			canvas.draw_circle(r.get_center(),s.x*0.38,T.CREAM)
			canvas.draw_arc(r.get_center(),s.x*0.38,0,TAU,32,T.INK,3)
			canvas.draw_line(r.get_center(),o+s*Vector2(0.5,0.24),T.INK,3)
			canvas.draw_line(r.get_center(),o+s*Vector2(0.70,0.5),T.ACCENT,3)
		"medicine":
			for i in range(7):
				var cell := Rect2(o+Vector2((i%4)*s.x/4.0, floori(i/4.0)*s.y/2.0),Vector2(s.x/4.0-3,s.y/2.0-3))
				canvas.draw_rect(cell,T.CREAM)
				canvas.draw_circle(cell.get_center(),3,T.ACCENT)
		"phone":
			canvas.draw_rect(Rect2(o+s*Vector2(0.25,0),s*Vector2(0.50,1)),T.INK)
			canvas.draw_rect(Rect2(o+s*Vector2(0.29,0.08),s*Vector2(0.42,0.72)),T.PAPER_DIM)
			canvas.draw_circle(o+s*Vector2(0.5,0.90),3,T.CREAM)
		"meal":
			ellipse(canvas,Rect2(o+s*Vector2(0.08,0.3),s*Vector2(0.84,0.44)),T.CREAM)
			canvas.draw_circle(o+s*Vector2(0.5,0.5),s.x*0.2,Color("ddb665"))
		"book", "letter", "contract":
			canvas.draw_rect(Rect2(o+s*0.08,s*0.84),T.CREAM)
			for i in range(4): canvas.draw_line(o+s*Vector2(0.18,0.22+i*0.15),o+s*Vector2(0.80,0.22+i*0.15),T.INK_SOFT,2)
			if kind == "book": canvas.draw_line(o+s*Vector2(0.5,0.10),o+s*Vector2(0.5,0.90),T.ACCENT,2)
			if progress > 0: canvas.draw_line(o+s*Vector2(0.18,0.8),o+s*Vector2(0.18+0.60*progress,0.7),T.ACCENT,3)
