extends RefCounted
## 对话显示模板：原文仍保留「名字：台词」，这里只拆分显示层。
## 打字机负责正文；名牌和状态从一开始保持稳定，避免逐字跳动。
const T := preload("res://scripts/comic_theme.gd")


static func copy(raw: String, visible: int = -1, fallback_speaker: String = "") -> Dictionary:
	var separator := raw.find("：")
	if separator < 0: separator = raw.find(":")
	var body_start := separator + 1 if separator >= 0 else 0
	var speaker := fallback_speaker
	if speaker.is_empty() and separator > 0: speaker = raw.left(separator)
	if speaker.is_empty(): speaker = "你"
	var count := raw.length() if visible < 0 else clampi(visible,0,raw.length())
	var shown_start := mini(count,body_start)
	return {
		"speaker": speaker,
		"full": raw.substr(body_start),
		"shown": raw.substr(shown_start,maxi(0,count-body_start)),
		"done": count >= raw.length(),
	}


static func draw_chrome(c: CanvasItem, rect: Rect2, model: Dictionary, clock: float, reduced_motion: bool) -> void:
	var f := T.font_body()
	var tag_size := 10 if rect.size.x >= 150 else 9
	var speaker := str(model.get("speaker","你"))
	var name_width := f.get_string_size(speaker,HORIZONTAL_ALIGNMENT_LEFT,-1,tag_size).x
	var tag := Rect2(rect.position+Vector2(10,-7),Vector2(minf(rect.size.x-42,name_width+22),16))
	c.draw_rect(tag,T.INK)
	c.draw_rect(Rect2(tag.position,Vector2(3,tag.size.y)),T.ACCENT)
	T.frame(c,tag,1.0,0.2,Color(T.CREAM,0.88))
	c.draw_string(f,tag.position+Vector2(9,11.5),speaker,HORIZONTAL_ALIGNMENT_LEFT,tag.size.x-12,tag_size,T.CREAM)
	var done := bool(model.get("done",false))
	var status := "▼" if done else "···"
	var alpha := 0.85
	if not done and not reduced_motion: alpha = 0.55+sin(clock*7.0)*0.25
	c.draw_string(f,rect.position+Vector2(rect.size.x-22,13),status,HORIZONTAL_ALIGNMENT_LEFT,16,10,Color(T.CREAM,alpha))
