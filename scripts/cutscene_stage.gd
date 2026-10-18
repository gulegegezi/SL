extends Control
## Undertale 式剧情过场：背景贴图 + 分件立绘角色 + 底部对话框（名字/立绘/逐字）+ 心形光标选择。
## 事件有对应过场定义时，用它替换原来的「文字卡 + 按钮 + 三镜头小剧场」。

signal finished(choice: Dictionary)

const SpriteKit := preload("res://scripts/sprite_kit.gd")
const AudioFX := preload("res://scripts/audio_fx.gd")
const PixelCast := preload("res://scripts/pixel_cast.gd")

const BG := Vector2(160, 120)
const CHAR := Vector2(24, 36)
const BOX_H := 92.0

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
var choice_index := 0
var visible_chars := 0
var blip_timer := 0.0
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
	cast = cutscene.get("cast", [])
	bg_tex = SpriteKit.scene(str(cutscene.get("bg", "home")))
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
	if visible_chars < _current_text().length():
		visible_chars = _current_text().length()
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

func _next_beat() -> void:
	beat_index += 1
	if beat_index < beats.size():
		visible_chars = 0
		blip_timer = 0.0
		_apply_beat(beats[beat_index])
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

## 对话框立绘：优先用 frames.json 的 10 表情头部，失败再退回 PixelCast/分件头。
func _portrait(role: String, expr: String) -> Texture2D:
	var is_npc := role != "lead"
	var visual := _visual_role(role) if is_npc else PixelCast.stage_for_age(age)
	if visual != "infant":
		var frame_face := SpriteKit.frame_portrait(SpriteKit.key_for(visual, is_npc), expr)
		if frame_face != null:
			return frame_face
	return SpriteKit.face(visual, expr, is_npc)

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
	if visible_chars < _current_text().length():
		blip_timer -= delta
		if blip_timer <= 0.0:
			blip_timer = 0.045
			visible_chars += 1
			_blip_player.play()
	queue_redraw()

# ==========================================================
# 布局
# ==========================================================
func _layout() -> void:
	var box_reserve := BOX_H + 18.0
	var avail_w := size.x - 16.0
	var avail_h := size.y - box_reserve
	if avail_h <= 0.0 or avail_w <= 0.0:
		return
	var sx := avail_w / BG.x
	var sy := avail_h / BG.y
	view_scale = maxf(1.0, floorf(minf(sx, sy)))
	var cw := BG.x * view_scale
	var ch := BG.y * view_scale
	origin = Vector2((size.x - cw) / 2.0, (avail_h - ch) / 2.0 + 6.0)

# ==========================================================
# 绘制
# ==========================================================
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("000000"))
	if bg_tex != null:
		draw_texture_rect(bg_tex, Rect2(origin, BG * view_scale), false)
		for c in cast:
			_draw_cast(c)
	if beat_index >= 0 or in_choices:
		_draw_box()

func _draw_cast(c: Dictionary) -> void:
	var role := str(c.get("role", "lead"))
	var is_npc := role != "lead"
	var key := _visual_role(role) if is_npc else PixelCast.stage_for_age(age)
	var foot := Vector2(float(c.get("x", 80)), float(c.get("y", 76)))
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
	var face := SpriteKit.norm_face(str(c.get("face", "normal")))
	if role == "lead":
		action = lead_action
		face = SpriteKit.norm_face(lead_expr)
	if entering:
		action = "walk"
		face = "normal"
	var height := 24.0 if key == "infant" else 36.0
	var foot_px := origin + foot * view_scale
	var drawn := false
	if key != "infant":
		drawn = SpriteKit.draw_action(self, key, is_npc, foot_px, height * view_scale, action, face, anim_clock)
	if not drawn:
		PixelCast.draw_actor(self, key, is_npc, foot_px, height * view_scale, clock, entering, false)

func _draw_box() -> void:
	var box := Rect2(8.0, size.y - BOX_H - 8.0, size.x - 16.0, BOX_H)
	draw_rect(box, Color("000000"))
	draw_rect(box, Color("ffffff"), false, 2.0)
	var face_sz := 62.0
	var face_rect := Rect2(box.position + Vector2(12, 14), Vector2(face_sz, face_sz))
	draw_rect(face_rect, Color("202028"))
	if cur_face != null:
		var tex_size := cur_face.get_size()
		var fit := minf(face_sz / maxf(1.0, tex_size.x), face_sz / maxf(1.0, tex_size.y))
		var dest_size := tex_size * fit
		var dest := Rect2(face_rect.position + (Vector2(face_sz, face_sz) - dest_size) * 0.5, dest_size)
		draw_texture_rect(cur_face, dest, false)
	draw_rect(face_rect, Color("ffffff"), false, 1.0)
	var tx := face_rect.end.x + 12.0
	var tw := box.end.x - tx - 12.0
	var name := ""
	var text := ""
	if in_choices:
		name = "选择"
		text = _current_text()
	else:
		name = str(beats[beat_index].get("speaker", ""))
		text = _current_text()
	draw_string(font, Vector2(tx, face_rect.position.y + 8.0), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("fff2c8"))
	var shown := text if visible_chars < 0 else text.substr(0, visible_chars)
	draw_multiline_string(font, Vector2(tx, face_rect.position.y + 30.0), shown,
		HORIZONTAL_ALIGNMENT_LEFT, tw, 14, 2, Color("ffffff"))
	if in_choices:
		_draw_choices(box)
	elif visible_chars >= text.length() and beat_index + 1 < beats.size():
		draw_string(font, Vector2(box.end.x - 18.0, box.end.y - 14.0), "▾",
			HORIZONTAL_ALIGNMENT_RIGHT, -1, 12, Color("ffffff"))

func _draw_choices(box: Rect2) -> void:
	if choices.is_empty():
		return
	var line_h := 20.0
	var start_y := box.end.y - 14.0 - choices.size() * line_h
	for i in range(choices.size()):
		var line_y := start_y + i * line_h
		var locked := _locked(i)
		var label := _label(i)
		if locked:
			label += "  （%s）" % _hint(i)
		if i == choice_index and not locked:
			if heart_tex != null:
				draw_texture_rect(heart_tex, Rect2(box.position.x + 14.0, line_y + 4.0, 13.0, 13.0), false)
			else:
				draw_rect(Rect2(box.position.x + 16.0, line_y + 6.0, 8.0, 8.0), Color("ff3b3b"))
		var col := Color("ffffff") if not locked else Color("8f8f9a")
		draw_string(font, Vector2(box.position.x + 34.0, line_y + 15.0), label,
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
	var box := Rect2(8.0, size.y - BOX_H - 8.0, size.x - 16.0, BOX_H)
	var line_h := 20.0
	var start_y := box.end.y - 14.0 - choices.size() * line_h
	for i in range(choices.size()):
		if _locked(i):
			continue
		var r := Rect2(box.position.x + 12.0, start_y + i * line_h, box.size.x - 24.0, line_h)
		if r.has_point(pos):
			choice_index = i
			confirm()
			return
