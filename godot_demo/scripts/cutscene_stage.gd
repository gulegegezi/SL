extends Control
## Undertale 式剧情过场：背景贴图 + 分件立绘角色 + 底部对话框（名字/立绘/逐字）+ 心形光标选择。
## 事件有对应过场定义时，用它替换原来的「文字卡 + 按钮 + 三镜头小剧场」。

signal finished(choice: Dictionary)

const SpriteKit := preload("res://scripts/sprite_kit.gd")
const AudioFX := preload("res://scripts/audio_fx.gd")
const PixelCast := preload("res://scripts/pixel_cast.gd")

const BG := Vector2(160, 90)
const SCENE_FLOOR_Y := 62.0
const CHAR := Vector2(24, 36)
const BOX_MIN_H := 92.0
const BOX_H := BOX_MIN_H
const BOX_PAD := 12.0
const FACE_SIZE := 62.0
const TEXT_SIZE := 13
const CHOICE_LINE_H := 22.0
## 逐字节奏：标点处留气口，读起来才像人在说话（约 23 字/秒）。
const TYPE_SPEED := 0.042
const PAUSE_LONG := ["。", "！", "？", "…"]
const PAUSE_SHORT := ["，", "、", "：", "；"]

var event: Dictionary = {}
var cut: Dictionary = {}
var state = null
var age := 1

var beats: Array = []
var choices: Array = []
var cast: Array = []
var bg_tex: Texture2D
var heart_tex: Texture2D

var beat_index := -1
var in_choices := false
var auto_continue := false
var choice_index := 0
var visible_chars := 0
var blip_timer := 0.0
var type_acc := 0.0
var line_h := 19.0
var finished_once := false
var clock := 0.0

var lead_expr := "neutral"
var lead_action := "idle"
var anim_clock := 0.0
var cur_face: Texture2D
var view_scale := 3.0
var origin := Vector2.ZERO

var _blip_player: AudioStreamPlayer
var _select_player: AudioStreamPlayer
var font: Font

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	font = ThemeDB.fallback_font
	line_h = font.get_height(TEXT_SIZE)
	heart_tex = load("res://assets/vfx/heart.png")
	_blip_player = AudioStreamPlayer.new()
	_blip_player.stream = AudioFX.blip()
	add_child(_blip_player)
	_select_player = AudioStreamPlayer.new()
	_select_player.stream = AudioFX.confirm()
	add_child(_select_player)
	resized.connect(_layout)
	call_deferred("grab_focus")

## choice_list 由 main 传入：每个元素是 {"choice": 原始选项, "locked": bool, "hint": 提示}。
## 兼容直接传原始选项数组（测试用），此时视为全部解锁。
func configure(ev: Dictionary, cutscene: Dictionary, s, choice_list: Array = []) -> void:
	event = ev
	cut = cutscene
	state = s
	age = int(s.age)
	beats = cutscene.get("beats", [])
	choices = choice_list
	if choices.is_empty():
		choices = [{"choice": {"label": "继续", "result": "", "effects": {}}, "locked": false, "hint": ""}]
	# 结果是「读完之后点一下继续」，不是真正的选择：不要摆一个只有一个选项的菜单。
	auto_continue = choices.size() == 1 and bool(choices[0].get("continue", false))
	cast = cutscene.get("cast", [])
	bg_tex = SpriteKit.scene_view(str(cutscene.get("bg", "home")))
	lead_expr = "neutral"
	lead_action = "idle"
	anim_clock = 0.0
	_layout()
	queue_redraw()

func play() -> void:
	clock = 0.0
	anim_clock = 0.0
	beat_index = -1
	in_choices = false
	choice_index = 0
	visible_chars = 0
	finished_once = false
	_next_beat()

# ==========================================================
# 公共推进接口（鼠标/键盘也走这里，测试可直接调用）
# ==========================================================
func advance() -> void:
	if finished_once or in_choices or beat_index < 0:
		return
	if visible_chars < _display_text().length():
		visible_chars = _display_text().length()
	else:
		_next_beat()

func move_choice(delta: int) -> void:
	if not in_choices or finished_once or choices.is_empty():
		return
	var n := choices.size()
	for _k in range(n):
		choice_index = wrapi(choice_index + delta, 0, n)
		if not _locked(choice_index):
			break
	_blip_player.play()
	queue_redraw()

func confirm() -> void:
	if not in_choices or finished_once or choices.is_empty():
		return
	if _locked(choice_index):
		return
	finished_once = true
	_select_player.play()
	finished.emit(_choice_dict(choice_index))

func _choice_dict(i: int) -> Dictionary:
	return choices[i].get("choice", choices[i])

func _locked(i: int) -> bool:
	return bool(choices[i].get("locked", false))

func _hint(i: int) -> String:
	return str(choices[i].get("hint", ""))

func _label(i: int) -> String:
	return str(_choice_dict(i).get("label", ""))

# ==========================================================
# 内部流程
# ==========================================================
func _current_text() -> String:
	if beat_index >= 0 and beat_index < beats.size():
		return str(beats[beat_index].get("text", ""))
	return ""

## 传说之下式：旁白没有名字，正文以「* 」开头；角色说话显示名字。
func _speaker_name() -> String:
	if in_choices or beat_index < 0 or beat_index >= beats.size():
		return ""
	var n := str(beats[beat_index].get("speaker", ""))
	return "" if n == "旁白" else n

func _display_text() -> String:
	var t := _current_text()
	if t.is_empty():
		return t
	if _speaker_name().is_empty():
		return "* " + t
	return t

func _next_beat() -> void:
	beat_index += 1
	if beat_index < beats.size():
		visible_chars = 0
		blip_timer = 0.0
		type_acc = 0.0
		_apply_beat(beats[beat_index])
	elif auto_continue:
		# 结果镜头没有可选的项：读完最后一句就直接交回控制。
		visible_chars = -1
		finished_once = true
		finished.emit(_choice_dict(0))
	else:
		_enter_choices()
	queue_redraw()

func _apply_beat(beat: Dictionary) -> void:
	var face_role := str(beat.get("face", "lead"))
	var expr := SpriteKit.norm_face(str(beat.get("expr", "neutral")))
	var action := str(beat.get("action", ""))
	var target := str(beat.get("target", face_role))
	if action != "":
		_set_action(target, action)
	if face_role == "lead":
		lead_expr = expr
	cur_face = _portrait(face_role, expr)

## 把动作写给 lead 或某个 cast 角色；动作会保持到下一次显式切换。
func _set_action(role: String, action: String) -> void:
	if role == "lead":
		lead_action = action
		return
	for c in cast:
		if str(c.get("role", "")) == role:
			c["action"] = action
			return

## 对话框立绘：使用最新 SL 库角色图集（PixelCast.portrait）。
## 最新素材只有「静止 / 说话抬手」两种立绘，expr 作为语义提示映射到说话帧。
func _portrait(role: String, expr: String) -> Texture2D:
	var is_npc := role != "lead"
	var visual := _visual_role(role) if is_npc else PixelCast.stage_for_age(age)
	var speaking := _expr_is_speaking(expr)
	var portrait := PixelCast.portrait(visual, is_npc, speaking)
	if portrait != null:
		return portrait
	return SpriteKit.face(visual, expr, is_npc)

func _expr_is_speaking(expr: String) -> bool:
	return SpriteKit.norm_face(expr) in ["happy", "sad", "angry", "surprise", "scared", "determined", "hurt", "shy"]

func _visual_role(role: String) -> String:
	# The existing V13 cast uses generic 'parent' for the father.
	return "mate" if role == "parent" and str(event.get("id", "")) == "V13" else role

func _enter_choices() -> void:
	in_choices = true
	choice_index = 0
	while choice_index < choices.size() and _locked(choice_index):
		choice_index += 1
	visible_chars = -1
	queue_redraw()

func _process(delta: float) -> void:
	clock += delta
	anim_clock += delta
	if in_choices or beat_index < 0:
		queue_redraw()
		return
	var full := _display_text()
	if visible_chars < full.length():
		type_acc -= delta
		if type_acc <= 0.0:
			var ch := full.substr(visible_chars, 1)
			visible_chars += 1
			type_acc = _char_delay(ch)
			if not _is_pause(ch) and ch.strip_edges() != "":
				_blip_player.play()
	queue_redraw()

## 标点不是「停顿 0.045 秒」，而是留一个气口：句末最长，逗号次之。
func _char_delay(ch: String) -> float:
	if ch in PAUSE_LONG:
		return 0.26
	if ch in PAUSE_SHORT:
		return 0.11
	if ch == "\n":
		return 0.18
	if ch == " ":
		return 0.02
	return TYPE_SPEED

func _is_pause(ch: String) -> bool:
	return ch in PAUSE_LONG or ch in PAUSE_SHORT or ch == "\n"

# ==========================================================
# 布局
# ==========================================================
func _layout() -> void:
	var box_reserve := BOX_MIN_H + 18.0
	var avail_w := size.x - 16.0
	var avail_h := size.y - box_reserve
	if avail_h <= 0.0 or avail_w <= 0.0:
		return
	# 只按宽度定缩放：翻页时对话框变高，场景不该跟着缩放，否则每句话都跳一下。
	view_scale = maxf(1.0, minf(floorf(avail_w / BG.x), floorf(avail_h / BG.y)))
	var cw := BG.x * view_scale
	var ch := BG.y * view_scale
	# 场景按「最小对话框高度」居中，之后对话框只向下长，场景永远不动。
	var content_h := ch + box_reserve
	origin = Vector2((size.x - cw) / 2.0, maxf(4.0, (size.y - content_h) / 2.0 + 4.0))

# ==========================================================
# 绘制
# ==========================================================
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("000000"))
	if bg_tex != null:
		# 场景缩放：背景与人物放在同一个 camera 变换里，只缩放一次，比例不会互相漂移。
		var cam: Dictionary = cut.get("camera", {})
		var zoom := maxf(0.5, float(cam.get("zoom", 1.0)))
		var focus := Vector2(float(cam.get("x", BG.x * 0.5)), float(cam.get("y", 45)))
		var s := view_scale * zoom
		var screen_focus := origin + focus * view_scale
		var offset := screen_focus - focus * s
		draw_set_transform(offset, 0.0, Vector2(s, s))
		draw_texture_rect(bg_tex, Rect2(Vector2.ZERO, BG), false)
		for c in cast:
			_draw_cast(c)
		draw_set_transform(Vector2.ZERO)
	if beat_index >= 0 or in_choices:
		_draw_box()

func _draw_cast(c: Dictionary) -> void:
	var role := str(c.get("role", "lead"))
	var is_npc := role != "lead"
	var key := _visual_role(role) if is_npc else PixelCast.stage_for_age(age)
	var foot := Vector2(float(c.get("x", 80)), float(c.get("y", SCENE_FLOOR_Y)))
	var entering := false
	if c.has("from"):
		var from := Vector2(float(c["from"][0]), float(c["from"][1]))
		var dur := maxf(0.2, float(c.get("walk_time", 1.0)))
		var t := clampf(anim_clock / dur, 0.0, 1.0)
		foot = from.lerp(foot, smoothstep(0.0, 1.0, t))
		entering = t < 1.0
	elif not is_npc and beat_index == 0 and clock < 0.9 and not in_choices:
		foot.x -= 18.0 * (1.0 - smoothstep(0.0, 0.9, clock))
		entering = true
	var action := str(c.get("action", "idle"))
	if role == "lead":
		action = lead_action
	var walking := entering or action == "walk"
	# 最新 SL 库角色只有 4 帧：静止 / 两帧走 / 说话抬手。
	# wave/raise 复用「说话抬手」帧；sit 没有专用帧，退回静止。
	var speaking := action in ["wave", "raise"]
	if beat_index >= 0 and beat_index < beats.size() and not in_choices:
		var beat: Dictionary = beats[beat_index]
		if str(beat.get("face", "lead")) == role and visible_chars < _current_text().length():
			speaking = true
	var height := 24.0 if key == "infant" else 36.0
	# 脚底软阴影：和人物一起受 camera 缩放，角色才像踩在房间地面上。
	var shadow_w := 14.0 if key == "infant" else 18.0
	for i in range(3):
		var sw := shadow_w * (1.0 - i * 0.16)
		draw_rect(Rect2(foot.x - sw * 0.5, foot.y - 1.0 + i * 1.2, sw, 1.2),
			Color(0, 0, 0, 0.20 - i * 0.05))
	# 在 camera 变换内绘制：foot/height 都是 160x90 场景坐标，和背景同倍缩放。
	_draw_actor_frame(key, is_npc, foot, height, walking, speaking)

## 4 帧图集 + 子帧位移 / 眨眼 / 说话口型，补出更接近传说之下的少帧节奏。
func _draw_actor_frame(key: String, is_npc: bool, foot: Vector2, height: float,
		walking: bool, speaking: bool) -> void:
	var index := PixelCast.frame_index(clock, walking, speaking)
	var texture := PixelCast.frame(key, is_npc, index)
	if texture == null:
		return
	# 12fps 量化：位移动画也踩在「画格」上，而不是 60fps 连续飘。
	# 图集只有 4 帧，量化 + 逐帧上下浮动能把「帧数感」补回来。
	var q := floorf(clock * 12.0) / 12.0
	var bob := 0.0
	if walking:
		bob = -absf(sin(q * 12.0)) * 1.6
	elif speaking:
		bob = -absf(sin(q * 7.0)) * 1.0
	else:
		bob = -roundf(absf(sin(q * 2.0)))
	var dim := texture.get_size() * (height / maxf(1.0, texture.get_height()))
	var rect := Rect2((foot + Vector2(0, bob) - Vector2(dim.x * 0.5, dim.y)).round(), dim)
	draw_texture_rect(texture, rect, false)
	if not walking:
		var seed_off := float(absi(hash(key)) % 7) * 0.6
		if fmod(q + seed_off, 4.2) < 0.09:
			var eye_y := rect.position.y + rect.size.y * 0.30
			draw_rect(Rect2(rect.position.x + rect.size.x * 0.28, eye_y,
				rect.size.x * 0.44, maxf(1.0, rect.size.y * 0.022)), Color(0.08, 0.09, 0.12, 0.9))
	if speaking:
		var mouth_y := rect.position.y + rect.size.y * 0.42
		var mouth_h := 1.0 if int(q * 10.0) % 2 == 0 else 2.0
		draw_rect(Rect2(rect.position.x + rect.size.x * 0.38, mouth_y,
			rect.size.x * 0.24, maxf(1.0, mouth_h)), Color(0.22, 0.10, 0.10, 0.65))

## 一帧的排版：谁在说话、有没有立绘、正文占几行、对话框多高。
## 绘制与点击命中都用这一份，避免「看到的」和「点到的」不是同一块。
func _box_metrics() -> Dictionary:
	var box_x := 8.0
	var box_w := size.x - 16.0
	var box_y := origin.y + BG.y * view_scale + 8.0
	if in_choices:
		# 选项要占地：提示语最多两行，不显示立绘和名字，整行都留给选项。
		var text := ""
		if not beats.is_empty():
			var bi := clampi(beat_index, 0, beats.size() - 1)
			text = str(beats[bi].get("text", ""))
		var tx := box_x + 18.0
		var tw := box_w - 32.0
		var lines := _wrap_lines(text, tw, 2)
		var text_top := box_y + 16.0
		var opt_top := text_top + lines * line_h + 10.0
		var h := opt_top - box_y + choices.size() * CHOICE_LINE_H + 10.0
		return {"box": Rect2(box_x, box_y, box_w, maxf(BOX_MIN_H, h)),
			"text_x": tx, "text_w": tw, "name": "", "text": text, "lines": lines,
			"has_face": false, "text_top": text_top, "opt_top": opt_top, "prompt": true}
	var name := _speaker_name()
	var text := _display_text()
	var has_face := not name.is_empty() and cur_face != null
	var text_x := (box_x + 12.0 + FACE_SIZE + 14.0) if has_face else (box_x + 18.0)
	var text_w := box_w - (text_x - box_x) - 16.0
	var lines := _wrap_lines(text, text_w, 5)
	var text_top := box_y + (46.0 if has_face else 20.0)
	var h := (text_top - box_y) + lines * line_h + 12.0
	return {"box": Rect2(box_x, box_y, box_w, maxf(BOX_MIN_H, h)),
		"text_x": text_x, "text_w": text_w, "name": name, "text": text, "lines": lines,
		"has_face": has_face, "text_top": text_top, "opt_top": 0.0, "prompt": false}

func _wrap_lines(text: String, width: float, cap: int) -> int:
	if text.is_empty() or width <= 8.0:
		return 1
	var sz := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, TEXT_SIZE)
	return clampi(roundi(sz.y / maxf(1.0, line_h)), 1, cap)

func _box_rect() -> Rect2:
	return _box_metrics()["box"]

func _draw_box() -> void:
	var m := _box_metrics()
	var box: Rect2 = m["box"]
	draw_rect(box, Color("000000"))
	draw_rect(box, Color("ffffff"), false, 2.0)
	if bool(m["has_face"]):
		var face_rect := Rect2(box.position + Vector2(12, 12), Vector2(FACE_SIZE, FACE_SIZE))
		draw_rect(face_rect, Color("202028"))
		if cur_face != null:
			var tex_size := cur_face.get_size()
			var fit := minf(FACE_SIZE / maxf(1.0, tex_size.x), FACE_SIZE / maxf(1.0, tex_size.y))
			var dest_size := tex_size * fit
			var dest := Rect2(face_rect.position + (Vector2(FACE_SIZE, FACE_SIZE) - dest_size) * 0.5, dest_size)
			draw_texture_rect(cur_face, dest, false)
		draw_rect(face_rect, Color("ffffff"), false, 1.0)
	var name := str(m["name"])
	if not name.is_empty():
		draw_string(font, Vector2(float(m["text_x"]), box.position.y + 26.0), name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("fff2c8"))
	var text := str(m["text"])
	var shown := text if visible_chars < 0 else text.substr(0, visible_chars)
	draw_multiline_string(font, Vector2(float(m["text_x"]), float(m["text_top"])), shown,
		HORIZONTAL_ALIGNMENT_LEFT, float(m["text_w"]), TEXT_SIZE, int(m["lines"]), Color("ffffff"))
	if bool(m["prompt"]):
		_draw_choices(box, float(m["opt_top"]), float(m["text_x"]))
	elif visible_chars >= text.length() and (beat_index + 1 < beats.size() or auto_continue):
		draw_string(font, Vector2(box.end.x - 18.0, box.end.y - 12.0), "▾",
			HORIZONTAL_ALIGNMENT_RIGHT, -1, 12, Color("ffffff"))

func _draw_choices(box: Rect2, opt_top: float, text_x: float) -> void:
	if choices.is_empty():
		return
	for i in range(choices.size()):
		var line_y := opt_top + i * CHOICE_LINE_H
		var locked := _locked(i)
		var label := _label(i)
		if locked:
			label += "  （%s）" % _hint(i)
		if i == choice_index and not locked:
			if heart_tex != null:
				draw_texture_rect(heart_tex, Rect2(text_x - 22.0, line_y + 4.0, 13.0, 13.0), false)
			else:
				draw_rect(Rect2(text_x - 20.0, line_y + 6.0, 8.0, 8.0), Color("ff3b3b"))
		var col := Color("ffffff") if not locked else Color("8f8f9a")
		draw_string(font, Vector2(text_x, line_y + 15.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)

# ==========================================================
# 输入
# ==========================================================
func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if in_choices:
			_pick_choice_at(ev.position)
		else:
			advance()
		accept_event()
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_ENTER, KEY_SPACE, KEY_Z:
				if in_choices: confirm()
				else: advance()
			KEY_UP, KEY_W: move_choice(-1)
			KEY_DOWN, KEY_S: move_choice(1)
		accept_event()

func _pick_choice_at(pos: Vector2) -> void:
	var m := _box_metrics()
	var box: Rect2 = m["box"]
	var text_x := float(m["text_x"])
	var opt_top := float(m["opt_top"])
	for i in range(choices.size()):
		if _locked(i):
			continue
		var r := Rect2(text_x - 26.0, opt_top + i * CHOICE_LINE_H - 2.0,
			box.end.x - text_x, CHOICE_LINE_H)
		if r.has_point(pos):
			choice_index = i
			confirm()
			return
