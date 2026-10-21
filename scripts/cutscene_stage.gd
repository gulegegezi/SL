extends Control
## Undertale 式剧情过场：背景贴图 + 分件立绘角色 + 底部对话框（名字/立绘/逐字）+ 心形光标选择。
## 事件有对应过场定义时，用它替换原来的「文字卡 + 按钮 + 三镜头小剧场」。

signal finished(choice: Dictionary)

const SpriteKit := preload("res://scripts/sprite_kit.gd")
const AudioFX := preload("res://scripts/audio_fx.gd")
const BeatDirector := preload("res://scripts/beat_director.gd")

const BG := Vector2(160, 90)
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
var cur_face: Texture2D
var view_scale := 3.0
var origin := Vector2.ZERO

# ---- 逐帧动作 / 镜头 / 节拍 ----
var actors: Dictionary = {}      # role -> {action, expr, clock}
var cam_zoom := 1.0
var cam_focus := Vector2(80, 45)
var cam_target_zoom := 1.0
var cam_target_focus := Vector2(80, 45)
var hold_timer := 0.0            # 先动起来，再开口
var type_acc := 0.0
var weather := ""                # 文字里说的天气：雨/雪/风/夜
# ---- 夸张漫画面：冲击帧 ----
var impact := 0.0
var impact_flash := 0.0
var impact_sfx := ""
var shake := 0.0
var motion_role := ""            # 正在做动作的人
var motion_timer := 0.0          # 文本没喊停，动作再延续一会儿

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
	actors.clear()
	for c in cast:
		actors[str(c.get("role", "lead"))] = {"action": "idle", "expr": "normal", "clock": 0.0}
	var cam: Dictionary = cutscene.get("camera", {})
	cam_zoom = float(cam.get("zoom", 1.0))
	cam_target_zoom = cam_zoom
	cam_focus = Vector2(float(cam.get("x", 80)), float(cam.get("y", 45)))
	cam_target_focus = cam_focus
	_layout()
	queue_redraw()

func play() -> void:
	beat_index = -1
	in_choices = false
	choice_index = 0
	visible_chars = 0
	finished_once = false
	hold_timer = 0.0
	type_acc = 0.0
	for k in actors:
		actors[k]["action"] = "idle"
		actors[k]["expr"] = "normal"
		actors[k]["clock"] = 0.0
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
	var role := str(beat.get("face", "lead"))
	var text_now := str(beat.get("text", ""))
	var w := BeatDirector.weather_for(text_now)
	if w == "clear":
		weather = ""
	elif w != "":
		weather = w
	var d := BeatDirector.direction(beat, role)
	var explicit := not str(beat.get("action", "")).strip_edges().is_empty()
	if str(d["action"]) == "idle" and not explicit and motion_timer > 0.0 and motion_role == role:
		# 上一拍还在走/挥手，这一句没说停，就让动作再延续一会儿（表情照常更新）
		_set_actor(role, _action_of(role), str(d["expr"]))
	else:
		_set_actor(role, str(d["action"]), str(d["expr"]))
		if str(d["action"]) != "idle":
			motion_role = role
			motion_timer = 1.4
		else:
			motion_role = ""
			motion_timer = 0.0
	hold_timer = float(d["hold"])
	if role == "lead":
		lead_expr = str(d["expr"])
		cur_face = SpriteKit.face(SpriteKit.stage_for_age(age), str(d["expr"]), false)
	else:
		cur_face = SpriteKit.face(role, str(d["expr"]), true)
	# 镜头往说话的人身上压；旁白拉远
	var ax := 80.0
	var who := _cast_by_role(role)
	if not who.is_empty():
		ax = float(who.get("x", 80))
	var base := float((cut.get("camera", {}) as Dictionary).get("zoom", 1.0))
	var shot := BeatDirector.shot_for(beat, ax, base)
	cam_target_zoom = float(shot["zoom"])
	cam_target_focus = Vector2(float(shot["x"]), float(shot["y"]))
	# 夸张表情配一记冲击帧：白闪 + 集中线 + 抖屏 + 拟声词
	var imp := BeatDirector.impact_for(str(d["expr"]))
	if not imp.is_empty():
		impact = 1.0
		impact_flash = float(imp.get("flash", 0.0))
		impact_sfx = str(imp.get("sfx", ""))
		shake = float(imp.get("shake", 0.0))
		cam_zoom += float(imp.get("punch", 0.0))
		hold_timer = maxf(hold_timer, 0.34)


func _action_of(role: String) -> String:
	var a: Dictionary = actors.get(role, {})
	return str(a.get("action", "idle"))


func _cast_by_role(role: String) -> Dictionary:
	for c in cast:
		if str(c.get("role", "")) == role:
			return c
	return {}


func _set_actor(role: String, action: String, expr: String) -> void:
	var a: Dictionary = actors.get(role, {"action": "idle", "expr": "normal", "clock": 0.0})
	if str(a.get("action", "")) != action:
		a["clock"] = 0.0
	var who := _cast_by_role(role)
	if action == "walk" and not a.has("dir"):
		a["dir"] = 1.0 if float(who.get("x", 80)) < 80.0 else -1.0
	a["action"] = action
	a["expr"] = expr
	actors[role] = a

func _enter_choices() -> void:
	in_choices = true
	choice_index = 0
	while choice_index < choices.size() and _locked(choice_index):
		choice_index += 1
	visible_chars = -1
	queue_redraw()

func _process(delta: float) -> void:
	clock += delta
	# 镜头缓动：不瞬间跳过去
	impact = maxf(0.0, impact - delta * 1.6)
	shake = maxf(0.0, shake - delta * 26.0)
	var k := 1.0 - exp(-delta * 7.0)
	cam_zoom = lerpf(cam_zoom, cam_target_zoom, k)
	cam_focus = cam_focus.lerp(cam_target_focus, k)
	if in_choices or beat_index < 0:
		queue_redraw()
		return
	for key in actors:
		var a: Dictionary = actors[key]
		a["clock"] = float(a.get("clock", 0.0)) + delta
		if str(a.get("action", "")) == "walk":
			# 朝远离画面中心的方向走，走到边就停住
			var off := float(a.get("offset_x", 0.0)) + float(a.get("dir", 1)) * 26.0 * delta
			a["offset_x"] = clampf(off, -52.0, 52.0)
	if motion_timer > 0.0:
		motion_timer -= delta
		if motion_timer <= 0.0 and motion_role != "":
			_set_actor(motion_role, "idle", str(actors.get(motion_role, {}).get("expr", "normal")))
			motion_role = ""
	# 动作起手：先让人动起来，再开口
	if hold_timer > 0.0:
		hold_timer -= delta
		queue_redraw()
		return
	var full := _current_text()
	if visible_chars < full.length():
		type_acc -= delta
		if type_acc <= 0.0:
			var ch := full.substr(visible_chars, 1)
			visible_chars += 1
			type_acc = BeatDirector.char_delay(ch)
			if not BeatDirector.is_pause(ch) and ch.strip_edges() != "":
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
	view_scale = maxf(2.0, floorf(minf(sx, sy)))
	var cw := BG.x * view_scale
	var ch := BG.y * view_scale
	origin = Vector2((size.x - cw) / 2.0, (avail_h - ch) / 2.0 + 6.0)

# ==========================================================
# 绘制
# ==========================================================
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("000000"))
	if bg_tex != null:
		# 背景和人物放在同一个 camera 变换里：推近时人和景一起走，不会互相漂
		var s := view_scale * cam_zoom
		var screen_focus := origin + cam_focus * view_scale
		var offset := screen_focus - cam_focus * s
		if shake > 0.0:
			offset += Vector2(sin(clock * 140.0), cos(clock * 117.0)) * shake * impact
		draw_set_transform(offset, 0.0, Vector2(s, s))
		draw_texture_rect(bg_tex, Rect2(Vector2.ZERO, BG), false)
		for c in cast:
			_draw_cast(c)
		draw_set_transform(Vector2.ZERO)
		_draw_weather()
		_draw_impact()
		_draw_cutin()
	if beat_index >= 0 or in_choices:
		_draw_box()

## 大脸特写：夸张表情在 24x36 的小人身上看不清，就切一张漫画式的反应大脸
func _draw_cutin() -> void:
	if impact < 0.15 or cur_face == null:
		return
	var r := Rect2(origin, BG * view_scale)
	var w := 150.0
	var rect := Rect2(r.end.x - w - 10.0 + (1.0 - impact) * 46.0, r.position.y + 10.0, w, w * 0.82)
	draw_rect(rect.grow(3.0), Color(0, 0, 0, 0.88 * impact))
	draw_rect(rect.grow(3.0), Color(1, 1, 1, impact), false, 2.0)
	draw_texture_rect_region(cur_face, rect, Rect2(4, 0, 16, 13), Color(1, 1, 1, minf(1.0, impact * 1.3)))


## 冲击帧：白闪、集中线、拟声词 —— 漫画里「这一格要有冲击力」的那套
func _draw_impact() -> void:
	if impact <= 0.0 or bg_tex == null:
		return
	var r := Rect2(origin, BG * view_scale)
	if impact_flash > 0.0:
		draw_rect(r, Color(1, 1, 1, impact_flash * impact))
	if shake > 0.0 or impact_flash > 0.0:
		var center := r.get_center()
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		var reach := r.size.length() * 0.8
		for i in range(34):
			var ang: float = rng.randf() * TAU
			var p0: Vector2 = center + Vector2(cos(ang), sin(ang)) * reach * 0.22
			var p1: Vector2 = center + Vector2(cos(ang), sin(ang)) * reach
			draw_line(p0, p1, Color(0, 0, 0, 0.55 * impact), rng.randf_range(1.0, 3.0))
	if impact_sfx != "":
		var f := ThemeDB.fallback_font
		var sz := int(44 + 16 * impact)
		var pos := Vector2(r.position.x + 26.0, r.position.y + 104.0)
		for d in [Vector2(-3, 0), Vector2(3, 0), Vector2(0, -3), Vector2(0, 3)]:
			draw_string(f, pos + d, impact_sfx, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(1, 1, 1, minf(1.0, impact * 2.0)))
		draw_string(f, pos, impact_sfx, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0, 0, 0, minf(1.0, impact * 2.4)))


## 天气跟着文字走：说了雨就下雨，说停了就停
func _draw_weather() -> void:
	if weather.is_empty() or bg_tex == null:
		return
	var r := Rect2(origin, BG * view_scale)
	if weather == "night":
		draw_rect(r, Color(0.02, 0.03, 0.10, 0.38))
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261021
	if weather == "rain":
		for i in range(52):
			var x: float = r.position.x + fmod(rng.randf() * r.size.x + clock * 70.0, r.size.x)
			var y: float = r.position.y + fmod(rng.randf() * r.size.y + clock * 430.0, r.size.y)
			draw_line(Vector2(x, y), Vector2(x - 5.0, y + 13.0), Color(0.78, 0.88, 1.0, 0.32), 1.0)
	elif weather == "snow":
		for i in range(44):
			var sx: float = r.position.x + fmod(rng.randf() * r.size.x + sin(clock * 0.8 + i) * 12.0, r.size.x)
			var sy: float = r.position.y + fmod(rng.randf() * r.size.y + clock * 34.0, r.size.y)
			draw_circle(Vector2(sx, sy), 1.6, Color(1, 1, 1, 0.55))
	elif weather == "wind":
		for i in range(16):
			var wy: float = r.position.y + rng.randf() * r.size.y
			var wx: float = r.position.x + fmod(rng.randf() * r.size.x + clock * 230.0, r.size.x)
			draw_line(Vector2(wx, wy), Vector2(wx + 20.0, wy), Color(1, 1, 1, 0.16), 1.0)


func _draw_cast(c: Dictionary) -> void:
	var role := str(c.get("role", "lead"))
	var is_npc := role != "lead"
	var key := role if is_npc else SpriteKit.stage_for_age(age)
	var a: Dictionary = actors.get(role, {"action": "idle", "expr": "normal", "clock": 0.0})
	var action := str(a.get("action", "idle"))
	var expr := str(a.get("expr", "normal"))
	if action == "idle" and _blink_phase(key):
		expr = "blink"
	var lookup := ("npc_" + key) if is_npc else key
	var n := int(SpriteKit.action_info(lookup, action).get("n", 1))
	var fps := SpriteKit.action_fps(action)
	var idx := 0
	if n > 1:
		idx = int(float(a.get("clock", 0.0)) * fps) % n
		if action == "idle" and expr != "normal" and expr != "blink":
			# 有情绪的这一拍停在烘焙了表情的第 0 帧，别让脸在两帧之间跳回无表情
			idx = 0
	var tex := SpriteKit.frame(key, action, idx, expr, is_npc)
	var foot := Vector2(float(c.get("x", 80)) + float(a.get("offset_x", 0.0)), float(c.get("y", 64)))
	var rect := Rect2(foot - Vector2(CHAR.x * 0.5, CHAR.y), CHAR)
	# 不是这一拍说话的人压暗一点：文字和画面指向同一张脸
	var speaking := true
	if beat_index >= 0 and beat_index < beats.size():
		speaking = role == str(beats[beat_index].get("face", "lead"))
	var tint := Color(1, 1, 1, 1) if (speaking or in_choices) else Color(1, 1, 1, 0.72)
	if tex != null:
		draw_texture_rect(tex, rect, false, tint)
	else:
		for t in SpriteKit.compose(key, is_npc, expr):
			if t != null:
				draw_texture_rect(t, rect, false, tint)


## 眨眼：idle 第 0 帧里有 blink 表情，隔几秒闪一下
func _blink_phase(key: String) -> bool:
	var off := float(absi(hash(key)) % 7) * 0.6
	return fmod(clock + off, 4.2) < 0.10

func _draw_box() -> void:
	var box := Rect2(8.0, size.y - BOX_H - 8.0, size.x - 16.0, BOX_H)
	draw_rect(box, Color("000000"))
	draw_rect(box, Color("ffffff"), false, 2.0)
	var face_sz := 62.0
	var face_rect := Rect2(box.position + Vector2(12, 14), Vector2(face_sz, face_sz))
	draw_rect(face_rect, Color("202028"))
	if cur_face != null:
		draw_texture_rect(cur_face, face_rect, false)
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
