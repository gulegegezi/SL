extends RefCounted
## 小道具在分镜坐标内绘制，交互与结果镜头共用同一形状。
const T := preload("res://scripts/comic_theme.gd")
static func ellipse(canvas: CanvasItem, r: Rect2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(32): points.append(r.get_center()+Vector2(cos(i*TAU/32),sin(i*TAU/32))*r.size*0.5)
	canvas.draw_colored_polygon(points,color)
static func draw_on(canvas: CanvasItem, kind: String, r: Rect2, progress: float = 0, decoration: bool = true) -> void:
	var o := r.position
	var s := r.size
	match kind:
		"blanket":
			canvas.draw_rect(Rect2(o+s*0.05,s*0.90),Color("70b4b6"))
			for i in range(3): canvas.draw_line(o+s*Vector2(0.15,0.25+i*0.22),o+s*Vector2(0.85,0.25+i*0.22),T.CREAM,1)
		"photo":
			canvas.draw_rect(r,T.CREAM)
			canvas.draw_rect(Rect2(o+s*0.10,s*Vector2(0.8,0.66)),T.INK_SOFT)
			for x in [0.30,0.65]:
				canvas.draw_circle(o+s*Vector2(x,0.30),s.x*0.10,T.CREAM)
				canvas.draw_rect(Rect2(o+s*Vector2(x-0.08,0.42),s*Vector2(0.16,0.25)),T.ACCENT)
		"key":
			canvas.draw_arc(o+s*0.25,s.x*0.16,0,TAU,12,T.CREAM,3)
			canvas.draw_line(o+s*Vector2(0.35,0.35),o+s*Vector2(0.82,0.82),T.CREAM,3)
			canvas.draw_line(o+s*Vector2(0.72,0.72),o+s*Vector2(0.85,0.59),T.CREAM,3)
		"flashlight":
			canvas.draw_rect(Rect2(o+s*Vector2(0.35,0.22),s*Vector2(0.3,0.70)),T.INK)
			canvas.draw_rect(Rect2(o+s*Vector2(0.2,0.1),s*Vector2(0.6,0.25)),T.CREAM)
		"biscuit":
			canvas.draw_rect(Rect2(o+s*0.15,s*0.7),Color("ddb665"))
			for i in range(4): canvas.draw_circle(o+s*Vector2(0.30+(i%2)*0.3,0.3+floorf(i/2.0)*0.3),1,T.INK)
		"eggs":
			canvas.draw_rect(Rect2(o+s*Vector2(0.05,0.5),s*Vector2(0.9,0.4)),Color("b29484"))
			for x in [0.25,0.5,0.75]: ellipse(canvas,Rect2(o+s*Vector2(x-0.11,0.2),s*Vector2(0.22,0.48)),T.CREAM)
		"plant":
			canvas.draw_rect(Rect2(o+s*Vector2(0.25,0.65),s*Vector2(0.5,0.3)),Color("b29484"))
			canvas.draw_line(o+s*Vector2(0.5,0.7),o+s*Vector2(0.5,0.1),T.PAPER_DIM,2)
			for x in [0.25,0.55]: ellipse(canvas,Rect2(o+s*Vector2(x,0.25),s*Vector2(0.22,0.2)),Color("70b4b6"))
		"fridge":
			canvas.draw_rect(Rect2(o+s*Vector2(0.15,0.05),s*Vector2(0.7,0.9)),T.CREAM)
			canvas.draw_line(o+s*Vector2(0.15,0.4),o+s*Vector2(0.85,0.4),T.INK,2)
			canvas.draw_line(o+s*Vector2(0.7,0.5),o+s*Vector2(0.7,0.7),T.ACCENT,2)
		"badge":
			canvas.draw_line(o+s*Vector2(0.3,0),o+s*Vector2(0.5,0.35),T.ACCENT,2)
			canvas.draw_line(o+s*Vector2(0.7,0),o+s*Vector2(0.5,0.35),T.ACCENT,2)
			canvas.draw_rect(Rect2(o+s*Vector2(0.15,0.35),s*Vector2(0.7,0.6)),T.CREAM)
			canvas.draw_line(o+s*Vector2(0.30,0.65),o+s*Vector2(0.7,0.65),T.INK,2)
		"tooth":
			ellipse(canvas,Rect2(o+s*Vector2(0.2,0.1),s*Vector2(0.6,0.6)),T.CREAM)
			for x in [0.25,0.55]: canvas.draw_rect(Rect2(o+s*Vector2(x,0.4),s*Vector2(0.2,0.5)),T.CREAM)
		"computer":
			canvas.draw_rect(Rect2(o,s*Vector2(1,0.72)),T.INK)
			canvas.draw_rect(Rect2(o+s*Vector2(0.08,0.08),s*Vector2(0.84,0.54)),Color("29637a"))
			for i in range(3): canvas.draw_rect(Rect2(o+s*Vector2(0.14,0.17+i*0.12),s*Vector2(0.58*progress,0.04)),Color("8ed2cb"))
			canvas.draw_rect(Rect2(o+s*Vector2(0.45,0.72),s*Vector2(0.10,0.16)),T.INK)
			canvas.draw_rect(Rect2(o+s*Vector2(-0.08,0.90),s*Vector2(1.16,0.10)),T.PAPER_DIM)
		"bed":
			canvas.draw_rect(Rect2(o,s),Color("426d7e"))
			canvas.draw_rect(Rect2(o+s*0.08,s*Vector2(0.28,0.84)),T.CREAM)
			canvas.draw_rect(Rect2(o+s*Vector2(0.40,0.08),s*Vector2(0.56,0.84)),Color("699c9e"))
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
			if decoration: canvas.draw_line(o+s*Vector2(0.15,0.05),o+s*Vector2(0.55,0.18+progress*0.18),T.CREAM,5)
			if decoration and progress > 0: canvas.draw_arc(o+s*Vector2(0.5,0.35),s.x*0.44,PI,TAU,12,T.CREAM,2)
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
			canvas.draw_circle(o+s*Vector2(0.5,0.90),maxf(0.5,minf(s.x,s.y)*0.04),T.CREAM)
		"meal":
			ellipse(canvas,Rect2(o+s*Vector2(0.08,0.3),s*Vector2(0.84,0.44)),T.CREAM)
			canvas.draw_circle(o+s*Vector2(0.5,0.5),s.x*0.2,Color("ddb665"))
		"book", "letter", "contract":
			canvas.draw_rect(Rect2(o+s*0.08,s*0.84),T.CREAM)
			for i in range(4): canvas.draw_line(o+s*Vector2(0.18,0.22+i*0.15),o+s*Vector2(0.80,0.22+i*0.15),T.INK_SOFT,2)
			if kind == "book": canvas.draw_line(o+s*Vector2(0.5,0.10),o+s*Vector2(0.5,0.90),T.ACCENT,2)
			if progress > 0: canvas.draw_line(o+s*Vector2(0.18,0.8),o+s*Vector2(0.18+0.60*progress,0.7),T.ACCENT,3)
