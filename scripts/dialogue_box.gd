extends Control
## Undertale 式对话框（受控版）：只负责「长什么样」，逐字进度由外部传入。
##
## 参考的做法（不是素材）：黑底、直角白框、每行以「* 」开头、每页三行、
## 打完一页右下角闪 ▼。打字机的时间轴与 blip 由调用方（单格）驱动，
## 这样对话框不会和已有逐字逻辑各跑一套计时。
##
## 用法：
##   box.show_line("你今天迟到了。", "老师")
##   box.set_progress(panel.visible_characters)   # 每帧喂一次
##   box.is_line_done()                            # 整句读完

const ThemeKit := preload("res://scripts/comic_theme.gd")

const PAD := 14.0
const BORDER := 3.0
const LINE_GAP := 6.0
const FONT_SIZE := 15
const LINES_PER_PAGE := 3

var text := ""
var speaker := ""
var portrait: Texture2D = null

var _lines: Array = []        # 排版后的行
var _line_starts: Array = []  # 每行在原文里的起始下标
var _page := 0
var _shown := 0
var _blink := 0.0
var _layout_width := -1.0


func _ready() -> void:
	set_process(true)
	mouse_filter = MOUSE_FILTER_STOP


func show_line(value: String, who: String = "", face: Texture2D = null) -> void:
	text = value.strip_edges()
	speaker = who
	portrait = face
	_page = 0
	_shown = 0
	_blink = 0.0
	_layout()
	queue_redraw()


## 外部逐字进度（0..text.length()）
func set_progress(chars: int) -> void:
	var clamped := clampi(chars, 0, text.length())
	var page := _page_of_char(clamped)
	if clamped != _shown or page != _page:
		_shown = clamped
		_page = page
		queue_redraw()


func is_line_done() -> bool:
	return _shown >= text.length()


func page_index() -> int:
	return _page


func page_count() -> int:
	return maxi(1, ceili(float(_lines.size()) / float(LINES_PER_PAGE)))


func full_text() -> String:
	return text


# ==========================================================
# 排版
# ==========================================================
func _text_rect() -> Rect2:
	var left := PAD + BORDER
	if portrait != null:
		left += minf(size.y * 0.42, 96.0) + 8.0
	return Rect2(left, PAD + BORDER, maxf(40.0, size.x - left - PAD - BORDER), size.y - PAD * 2.0 - BORDER)


func _layout() -> void:
	_lines.clear()
	_line_starts.clear()
	var font := ThemeKit.font_body()
	var limit := _text_rect().size.x
	# 「* 」只出现在第一行；后续行用两个空格对齐，和原作一致
	var buffer := "* "
	var width := 0.0
	var index := 0
	for i in range(text.length()):
		var ch := text.substr(i, 1)
		if ch == "\n":
			_lines.append(buffer)
			_line_starts.append(maxi(0, index - buffer.length() + 2))
			buffer = "  "
			width = 0.0
			continue
		var advance := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		if width + advance > limit and buffer.strip_edges() != "":
			_lines.append(buffer)
			_line_starts.append(maxi(0, index - buffer.length() + 2))
			buffer = "  "
			width = 0.0
		buffer += ch
		width += advance
		index += 1
	if buffer.strip_edges() != "":
		_lines.append(buffer)
		_line_starts.append(maxi(0, index - buffer.length() + 2))
	if _lines.is_empty():
		_lines.append("* ")
		_line_starts.append(0)
	_layout_width = size.x
	_page = _page_of_char(_shown)
	# 第一行从原文 0 开始
	if _line_starts.size() > 0:
		_line_starts[0] = 0


## 已显示 chars 个字符时，处于第几页
func _page_of_char(chars: int) -> int:
	var line := 0
	for i in range(_lines.size()):
		if chars <= int(_line_starts[i]):
			break
		line = i
	return clampi(line / LINES_PER_PAGE, 0, page_count() - 1)


# ==========================================================
# 绘制
# ==========================================================
func _process(delta: float) -> void:
	_blink += delta
	if is_line_done() and _blink > 0.55:
		_blink = 0.0
		queue_redraw()


func _draw() -> void:
	# 首次 show_line 时控件宽度还是 0，排版会把每两个字断一行；
	# 等真正拿到宽度后重排一次。
	if not is_equal_approx(size.x, _layout_width):
		_layout()
	var rect := Rect2(Vector2.ZERO, size)
	# 黑底 + 直角白框：原作的框没有圆角、没有阴影
	draw_rect(rect, Color(0.02, 0.02, 0.03))
	draw_rect(rect.grow(-BORDER * 0.5), Color(0.98, 0.97, 0.93), false, BORDER)

	var font := ThemeKit.font_body()
	var tr := _text_rect()

	# 左侧立绘（可选）：方形、顶对齐
	if portrait != null:
		var side := minf(tr.position.x - PAD - BORDER - 8.0, tr.size.y)
		var at := Vector2(PAD + BORDER, PAD + BORDER)
		draw_rect(Rect2(at, Vector2(side, side)), Color(0.06, 0.07, 0.09))
		draw_texture_rect(portrait, Rect2(at + Vector2(2, 2), Vector2(side - 4, side - 4)), false)

	# 说话人名牌：压在框的左上沿
	if speaker != "":
		var name_size := font.get_string_size(speaker, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		var plate := Rect2(Vector2(PAD, -10.0), name_size + Vector2(16, 6))
		draw_rect(plate, Color(0.02, 0.02, 0.03))
		draw_rect(plate, Color(0.98, 0.97, 0.93), false, 2.0)
		draw_string(font, Vector2(PAD + 8, 1), speaker, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			Color(0.98, 0.94, 0.80))

	# 文本：只画当前页，且只画到当前进度
	var first_line := _page * LINES_PER_PAGE
	var page_end := text.length()
	if first_line + LINES_PER_PAGE < _lines.size():
		page_end = int(_line_starts[first_line + LINES_PER_PAGE])
	var visible := clampi(_shown, 0, page_end)
	var y := tr.position.y + FONT_SIZE
	for i in range(first_line, mini(first_line + LINES_PER_PAGE, _lines.size())):
		var line := str(_lines[i])
		var line_start: int = int(_line_starts[i])
		# 行首的「* 」或缩进是两个装饰字，不计入原文进度，所以要 +2
		var shown_src := clampi(visible - line_start, 0, maxi(0, line.length() - 2))
		var take := 0 if shown_src <= 0 else mini(line.length(), shown_src + 2)
		if take > 0:
			draw_string(font, Vector2(tr.position.x, y), line.substr(0, take),
				HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(0.98, 0.97, 0.93))
		y += FONT_SIZE + LINE_GAP

	# 右下 ▼：整句打完才出现，约 1Hz 闪烁
	if is_line_done() and fmod(_blink, 1.1) < 0.65:
		var tip := Vector2(size.x - PAD - 10.0, size.y - PAD - 9.0)
		draw_colored_polygon(PackedVector2Array([
			tip + Vector2(-7, -6), tip + Vector2(7, -6), tip + Vector2(0, 2)
		]), Color(0.98, 0.97, 0.93))
