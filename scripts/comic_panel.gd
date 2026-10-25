## comic_panel.gd — 单个分格
## 一格 = 底（纸/网点/黑） + 角色线稿（按镜别裁切） + 旁白框 / 气泡 / 拟声词 + 墨框
extends Control

const T := preload("res://scripts/comic_theme.gd")
const AudioFX := preload("res://scripts/audio_fx.gd")
const Art := preload("res://scripts/comic_art.gd")
const SemanticPlan := preload("res://scripts/comic_performance.gd")
const Interaction := preload("res://scripts/comic_interaction.gd")
const Motion := preload("res://scripts/comic_motion.gd")
const Actor := preload("res://scripts/comic_actor.gd")
const World := preload("res://scripts/comic_world.gd")
const PixelStage := preload("res://scripts/pixel_stage_view.gd")
const ComicInsert := preload("res://scripts/pixel_comic_insert.gd")
const Dialogue := preload("res://scripts/comic_dialogue.gd")
var pixel_stage: Node
signal interacted(progress: Dictionary)
signal cinematic_finished
var interactions_enabled := true:
	set(value):
		interactions_enabled = value
		if not value:
			interaction_holding = false
			interaction_dragging = false
var interaction_done := false
var interaction_amount := 0.0
var interaction_dragging := false
var interaction_holding := false
var interaction_offset := Vector2.ZERO
var _drag_start := Vector2.ZERO
var _pointer_captured := false
var _interaction_clock := Motion.DURATION
var _actor_render: Dictionary = {}

var spec: Dictionary = {}
var ink: Texture2D = null
## 面板「画没画上去」：空白格只留框，等剧情推进再逐格填
var revealed := true
var current_direction: Dictionary = {}
var moments: Array = []
var visible_characters := 0
var impact_count := 0
var reduced_motion := false
var _moment_index := -1
var _age := 0.0
var _moment_age := 0.0
var _next_token := 0.0
var _hold := 0.0
var _impact_left := 0.0
var _full_text := ""
var _base_ink := ""
var _weather := ""
var _sfx_gate := 0.0

func _ready() -> void:
	# Godot enables an overridden _process when entering the tree. Respect the
	# settled state prepared by setup() before add_child(), especially in archives.
	set_process(revealed and (visible_characters < _full_text.length() or _interaction_clock < Motion.DURATION))
	if _uses_pixel():
		pixel_stage = PixelStage.new()
		add_child(pixel_stage)
		pixel_stage.setup(self)
		if spec.has("pixel_interaction"): mouse_filter = Control.MOUSE_FILTER_PASS

func _uses_pixel() -> bool:
	return spec.get("presentation","") == "pixel3d" and not str(spec.get("ink","")).is_empty()

func reveal_all_text() -> void:
	visible_characters = _full_text.length()
	_hold = 0
	if not moments.is_empty(): _activate(moments.size()-1,false)
	queue_redraw()

func setup(p: Dictionary, ink_tex: Texture2D) -> void:
	_moment_index = -1
	_hold = 0
	_impact_left = 0
	impact_count = 0
	spec = SemanticPlan.panel(p)
	ink = ink_tex
	_base_ink = str(spec.get("ink", ""))
	moments = spec.get("performance", [])
	_full_text = str(spec.get("caption", "")) + ("\n" + str(spec.bubble) if not str(spec.get("bubble", "")).is_empty() else "")
	visible_characters = _full_text.length()
	if not moments.is_empty(): _activate(moments.size() - 1, false)
	set_process(false)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	interaction_done = bool(spec.get("interaction_progress",{}).get("completed",false))
	_interaction_clock = Motion.DURATION
	interaction_holding = false
	interaction_dragging = false
	interaction_offset = Vector2.ZERO
	_pointer_captured = false
	interaction_amount = 1.0 if interaction_done else 0.0
	if spec.has("interaction"): mouse_filter = Control.MOUSE_FILTER_PASS
	queue_redraw()


func set_revealed(v: bool) -> void:
	if revealed == v:
		return
	revealed = v
	if v:
		_hold = 0
		visible_characters = 0
		_moment_index = -1
		_age = 0
		_moment_age = 0
		_next_token = 0
		_impact_left = 0
		impact_count = 0
		current_direction = SemanticPlan.analyse("")
		ink = Art.portrait(_base_ink, 0)
		if _full_text.is_empty() and not moments.is_empty(): _activate(0)
	set_process(v)
	queue_redraw()

func _activate(index: int, animated: bool = true) -> void:
	var next: Dictionary = moments[index]
	var continuing := animated and _moment_index >= 0 and str(current_direction.get("actor","lead")) == str(next.get("actor","lead")) and str(current_direction.get("action","idle")) == str(next.get("action","idle"))
	_moment_index = index
	if not continuing: _moment_age = 0
	current_direction = moments[index].duplicate(true)
	_weather = ""
	for previous in range(index + 1):
		var kind := str(moments[previous].get("weather", ""))
		if kind == "clear": _weather = ""
		elif not kind.is_empty(): _weather = kind
	if not animated: _moment_age = Motion.DURATION
	var role := str(current_direction.get("actor", "lead"))
	var key := _base_ink if role == "lead" else "npc_" + role
	if not _base_ink.is_empty(): ink = Art.portrait(key, int(spec.get("frame", 0)), str(current_direction.expr))
	if animated and int(current_direction.get("intensity", 0)) >= 3 and impact_count == 0:
		impact_count += 1
		_impact_left = 0.5
		_hold = 0.18

func _process(delta: float) -> void:
	if not revealed: return
	_interaction_clock += delta
	if interaction_holding and interactions_enabled and not interaction_done:
		interaction_amount = minf(1, interaction_amount + delta/0.8)
		if interaction_amount >= 1: complete_interaction()
	_age += delta
	_moment_age += delta
	_sfx_gate = maxf(0.0, _sfx_gate - delta)
	_impact_left = maxf(0, _impact_left - delta)
	if _hold > 0:
		_hold -= delta
	else:
		_next_token -= delta
		var guard := 0
		while _next_token <= 0 and visible_characters < _full_text.length() and guard < 256:
			guard += 1
			while _moment_index + 1 < moments.size() and visible_characters >= int(moments[_moment_index + 1].trigger):
				if _moment_index >= 0:
					var next: Dictionary = moments[_moment_index+1]
					var changed := str(next.get("action","idle")) != str(current_direction.get("action","idle")) or str(next.get("actor","lead")) != str(current_direction.get("actor","lead"))
					var minimum := Motion.minimum_time(Motion.kind(current_direction))
					if changed and _moment_age < minimum:
						_hold = minimum-_moment_age
						break
				_activate(_moment_index + 1)
			if _hold > 0: break
			var ch := _full_text.substr(visible_characters, 1)
			visible_characters += 1
			# 逐字音：标点与空白不出声，并做 55ms 节流，避免一页几十个音叠在一起
			if not bool(spec.get("hide_text", false)) and _sfx_gate <= 0.0 and ch.strip_edges() != "" and ch not in ["。", "！", "？", "…", "，", "；"]:
				_sfx_gate = 0.055
				AudioFX.speak(self, str(spec.get("actor", "lead")) != "lead")
			_next_token += 0.22 if ch in ["。", "！", "？", "…"] else (0.10 if ch in ["，", "；", "\n"] else 0.025)
	if visible_characters >= _full_text.length() and _moment_age >= Motion.DURATION and _impact_left <= 0 and not interaction_holding and _interaction_clock >= Motion.DURATION:
		set_process(false)
	queue_redraw()

func complete_interaction() -> void:
	if interaction_done or not interactions_enabled: return
	interaction_done = true
	interaction_amount = 1
	_interaction_clock = 1.6 if interaction_holding else (0.82 if interaction_dragging else 0.0)
	interaction_dragging = false
	interaction_holding = false
	spec["interaction_progress"] = {"completed":true}
	interacted.emit(spec.interaction_progress.duplicate(true))
	set_process(true)
	queue_redraw()

func interaction_object_rect() -> Rect2:
	return World.interaction_rect(self) if World.enabled(spec) else Interaction.object_rect(size,str(spec.get("interaction",{}).get("prop","")))

func interaction_target_rect() -> Rect2:
	return World.interaction_rect(self,true) if World.enabled(spec) else Interaction.target_rect(size)

func _gui_input(event: InputEvent) -> void:
	if is_instance_valid(pixel_stage) and pixel_stage.handle_input(event):
		accept_event()
		return
	# Consume the matching release even when press already completed a tap/hold.
	# Otherwise a parent ScrollContainer receives an unmatched release.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and _pointer_captured:
		_pointer_captured = false
		if interaction_dragging:
			if interaction_target_rect().grow(12).has_point(event.position): complete_interaction()
			else: interaction_offset = Vector2.ZERO; interaction_amount = 0
		interaction_dragging = false
		interaction_holding = false
		queue_redraw()
		accept_event()
		return
	if not interactions_enabled or interaction_done or not revealed or not spec.has("interaction"): return
	var kind := str(spec.interaction.get("kind","tap"))
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and interaction_object_rect().grow(14).has_point(event.position):
			_pointer_captured = true
			finish_reveal()
			if kind in ["tap","reveal"]: complete_interaction()
			elif kind == "drag": interaction_dragging = true; _drag_start = event.position
			elif kind == "hold": interaction_holding = true; interaction_amount = 0; set_process(true)
			accept_event()
		elif not event.pressed:
			if interaction_dragging:
				if interaction_target_rect().grow(12).has_point(event.position): complete_interaction()
				else: interaction_offset = Vector2.ZERO; interaction_amount = 0
			interaction_dragging = false
			interaction_holding = false
			queue_redraw()
	elif event is InputEventMouseMotion and interaction_dragging:
		interaction_offset = event.position - _drag_start
		interaction_amount = clampf(interaction_offset.x / maxf(1,size.x*0.28),0,1)
		queue_redraw()
		accept_event()

func finish_reveal() -> void:
	_hold = 0
	visible_characters = _full_text.length()
	if not moments.is_empty(): _activate(moments.size() - 1, false)
	_moment_age = Motion.DURATION
	_interaction_clock = Motion.DURATION
	_impact_left = 0
	set_process(false)
	queue_redraw()


func _draw() -> void:
	_actor_render = {}
	var r := Rect2(Vector2.ZERO, size)
	var tone_kind := str(spec.get("tone", "paper"))
	var dark := tone_kind == "black"
	T.fill(self, r, tone_kind)

	if revealed and str(spec.get("presentation", "")) == "text":
		_draw_text_page(r, dark)
	elif revealed and spec.has("comic_insert"):
		ComicInsert.draw(self, r.grow(-8.0), spec.comic_insert)
	elif revealed:
		var background := Art.background(str(spec.get("scene", "")))
		if background != null and not World.enabled(spec) and not _uses_pixel():
			var region := Art.cover_region(background,r.size)
			var camera := 1.0
			if not reduced_motion:
				var action := Motion.kind(current_direction)
				var time := _moment_age
				if bool(spec.get("stage_action",false)):
					action = Motion.interaction_kind(spec.get("interaction",{}))
					time = Interaction.action_time(self)
				camera = float(Motion.sample(action,time).camera)
			var cropped := region.size/camera
			region = Rect2(region.position+(region.size-cropped)*0.5,cropped)
			draw_texture_rect_region(background,r,region,Color(0.25,0.8,0.85,0.42))
		if not World.enabled(spec) and not _uses_pixel(): _draw_weather(r)
		if not World.enabled(spec) and not _uses_pixel() and str(spec.get("shot", "")) == "wide":
			var supporting_key := str(spec.get("support", "")) if str(current_direction.get("actor", "lead")) == "lead" else _base_ink
			var supporting := Art.portrait(supporting_key, 0)
			if supporting != null:
				var height := r.size.y * 0.73
				var dimensions := supporting.get_size() * (height / supporting.get_height())
				draw_texture_rect(supporting, Rect2(Vector2(r.size.x * 0.75 - dimensions.x * 0.5, r.end.y - dimensions.y), dimensions), false, Color(0.5, 0.8, 0.8))
		if _uses_pixel():
			if is_instance_valid(pixel_stage): pixel_stage.draw_on()
		elif World.enabled(spec):
			World.draw_scene(self,r)
			_draw_weather(r)
		elif bool(spec.get("stage_action",false)):
			Interaction.draw_scene(self,r)
		else:
			_draw_ink(r, dark)
			_draw_prop(r)
			_draw_gesture(r)
			_draw_impact(r)

	# 墨框（黑板格用纸色描边，否则黑框看不见）
	var frame_col: Color = T.CREAM if dark else T.INK
	T.frame(self, r.grow(-1.5), 3.0, 0.8, frame_col)
	# 内框细线（印刷感）
	if size.x > 120:
		T.frame(self, r.grow(-7.0), 1.0, 0.5, Color(frame_col, 0.35))

	if revealed and (spec.has("comic_insert") or str(spec.get("presentation", "")) == "text"):
		pass
	elif revealed:
		_draw_text(r, dark)
	else:
		# 空白格：只有框和一个「未发生」，像还没画上去的一格
		var f := T.font_body()
		draw_string(f, Vector2(0, r.size.y * 0.5 + 4), "未发生",
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10, Color(frame_col, 0.30))


# ----------------------------------------------------------
## 纯文本叙事：大字号、宽行距、引文用红杠，不用 3D
## 说话人 → 立绘 key。「妈妈」「爸爸」这类中文称谓按角色映射，
## 映射不到就用格子的 support / ink 兜底。
static func speaker_key(speaker: String, spec: Dictionary) -> String:
	var table := {
		"你": str(spec.get("ink", "lead_adult")), "我": str(spec.get("ink", "lead_adult")),
		"妈妈": "npc_parent", "母亲": "npc_parent",
		"爸爸": "npc_mate", "父亲": "npc_mate",
		"老师": "npc_teacher", "班主任": "npc_teacher",
		"同桌": "npc_friend", "同学": "npc_friend", "朋友": "npc_friend", "老同学": "npc_friend",
		"室友": "npc_friend", "熟人": "npc_friend",
		"医生": "npc_teacher", "管理员": "npc_teacher",
		"老板": "npc_boss", "同事": "npc_boss",
		"伴侣": "npc_partner", "对方": "npc_partner",
	}
	if table.has(speaker):
		return str(table[speaker])
	var support := str(spec.get("support", ""))
	if support.begins_with("npc_"):
		return support
	return str(spec.get("ink", "lead_adult"))


## 对话框：贴住格子下沿，深底浅字，长旁白都在框里说完
func _draw_dialogue_box(r: Rect2, text: String, bubble: String, layout: String) -> void:
	# 参照《传说之下》的规格：不透明黑底、3px 纯白直角框、正文以「* 」起行、
	# 一页三行、打完右下角闪 ▼。长文分页，不再靠缩小字号硬塞进一屏。
	var f := T.font_body()
	var size: int = 16 if r.size.x >= 320 else 14
	var pad := 14.0
	var border := 3.0
	var line_h := float(size) + 8.0

	var speaker := ""
	var spoken := bubble
	if not bubble.is_empty():
		var at := bubble.find("：")
		if at > 0:
			speaker = bubble.substr(0, at)
			spoken = bubble.substr(at + 1)
	if speaker == "旁白":
		speaker = ""

	# 旁白与台词合成一段；行首「* 」只加一次。
	# 数据里常写「旁白：」，而星号已经表明了旁白身份，重复就删掉。
	var lead := text.strip_edges()
	for prefix in ["旁白：", "旁白:", "旁白 "]:
		if lead.begins_with(prefix):
			lead = lead.substr(prefix.length()).strip_edges()
			break
	var body := "* " + lead
	var cap_len := text.length()
	if not spoken.strip_edges().is_empty():
		body += "
" + spoken.strip_edges()

	# 已显示到正文的哪个位置（正文比「旁白+台词」多了 2 个星号字符，台词去掉了「谁：」）
	var body_shown := 2 + mini(visible_characters, cap_len)
	if not spoken.strip_edges().is_empty() and visible_characters > cap_len:
		body_shown += 1 + mini(visible_characters - cap_len - 1, spoken.strip_edges().length())
	body_shown = clampi(body_shown, 0, body.length())

	var portrait: Texture2D = null
	if not speaker.is_empty():
		var key := speaker_key(speaker, spec)
		if not key.is_empty():
			portrait = Art.portrait(key, 0)

	var box_h := pad * 2.0 + line_h * 3.0
	var box := Rect2(r.position.x + 8.0, r.end.y - 8.0 - box_h, r.size.x - 16.0, box_h)

	var text_x := box.position.x + pad + border
	var text_w := box.size.x - (text_x - box.position.x) - pad - border
	var face_w := 0.0
	if portrait != null:
		face_w = clampf(box_h - pad, 56.0, 110.0)
		text_w -= face_w + 10.0

	var lines := _wrap_lines_manual(body, maxf(60.0, text_w), size)
	var offsets: Array = []
	var acc := 0
	for line in lines:
		offsets.append(acc)
		acc += str(line).length()
	var total_chars := acc
	# 定位当前页：三行一页
	var line_index := 0
	for i in range(offsets.size()):
		if body_shown > int(offsets[i]):
			line_index = i
	var page := line_index / 3
	var page_start := page * 3
	var page_end := mini(page_start + 3, lines.size())
	var page_limit := total_chars
	if page_end < lines.size():
		page_limit = int(offsets[page_end])
	var visible := clampi(body_shown, 0, page_limit)

	# 框：黑底 + 直角白框
	draw_rect(box, Color(0.02, 0.02, 0.03))
	draw_rect(box.grow(-border * 0.5), T.CREAM, false, border)

	# 左侧立绘（可选）：方形，贴框内左下
	if portrait != null:
		var ts := portrait.get_size()
		var side := minf(face_w, box_h - pad * 2.0)
		var dest := Rect2(box.position.x + pad + border, box.get_center().y - side * 0.5, side, side)
		draw_rect(dest, Color(0.06, 0.07, 0.09))
		draw_texture_rect(portrait, dest.grow(-2.0), false)
		draw_rect(dest, Color(T.CREAM, 0.45), false, 1.0)

	# 名牌：压在框的左上沿
	if not speaker.is_empty():
		var ns := f.get_string_size(speaker, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		var plate := Rect2(Vector2(box.position.x + pad, box.position.y - 10.0), ns + Vector2(16, 6))
		draw_rect(plate, Color(0.02, 0.02, 0.03))
		draw_rect(plate, T.CREAM, false, 2.0)
		draw_string(f, Vector2(plate.position.x + 8, plate.position.y + 11), speaker,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.98, 0.94, 0.80))

	# 正文：只画当前页，且只画到当前进度
	var y := box.position.y + pad + size
	for i in range(page_start, page_end):
		var line := str(lines[i])
		var take := clampi(visible - int(offsets[i]), 0, line.length())
		if take > 0:
			draw_string(f, Vector2(text_x, y), line.substr(0, take),
				HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.98, 0.97, 0.93))
		y += line_h

	# ▼：整段读完才出现
	if body_shown >= total_chars:
		var tip := Vector2(box.end.x - pad - 8.0, box.end.y - pad - 4.0)
		draw_colored_polygon(PackedVector2Array([
			tip + Vector2(-6, -7), tip + Vector2(6, -7), tip + Vector2(0, -1)
		]), T.CREAM)


func _draw_text_page(r: Rect2, dark: bool) -> void:
	var f := T.font_body()
	var big := T.font_big()
	var pad := 18.0
	var size: int = clampi(int(r.size.x * 0.047), 15, 20)
	# 文本页固定纸色底 + 墨字：比网点底清楚，长文也不累眼
	draw_rect(r, T.CREAM)
	var fg := T.INK
	var heading := str(spec.get("heading", ""))
	var body := str(spec.get("caption", ""))
	if not heading.is_empty() and body.find(heading) >= 0:
		heading = ""
	var quote := str(spec.get("bubble", ""))
	var y: float = r.position.y + pad + size
	if not heading.is_empty():
		draw_string(big, Vector2(r.position.x + pad, y), heading,
			HORIZONTAL_ALIGNMENT_LEFT, r.size.x - pad * 2, size + 3, T.ACCENT if not dark else T.CREAM)
		y += size + 20
	for line in _wrap_lines_manual(body, r.size.x - pad * 2, size):
		draw_string(f, Vector2(r.position.x + pad, y), line,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, fg)
		y += size + 9
	if not quote.is_empty():
		y += 10
		var qlines := _wrap_lines_manual(quote, r.size.x - pad * 2 - 14, size - 1)
		var qh := qlines.size() * (size + 9)
		draw_rect(Rect2(r.position.x + pad, y - size, 3.0, qh), T.ACCENT)
		for line in qlines:
			draw_string(f, Vector2(r.position.x + pad + 12, y), line,
				HORIZONTAL_ALIGNMENT_LEFT, -1, size - 1, Color(fg, 0.92))
			y += size + 9


func _wrap_lines_manual(text: String, width: float, size: int) -> Array:
	var out: Array = []
	var f := T.font_body()
	for para in text.split(char(10)):
		var line := ""
		for i in range(para.length()):
			var ch := para.substr(i, 1)
			var test := line + ch
			if not line.is_empty() and f.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
				out.append(line)
				line = ch
			else:
				line = test
		out.append(line)
	return out


func _draw_ink(r: Rect2, dark: bool) -> void:
	var acting := Motion.kind(current_direction)
	if acting in Motion.NAMED and not _base_ink.is_empty() and str(spec.get("shot","")) != "detail":
		var role := str(current_direction.get("actor","lead"))
		var key := _base_ink if role == "lead" else "npc_"+role
		var foot := Vector2(r.size.x*0.5,r.size.y*0.84)
		var actor_height := r.size.y*0.78
		if acting == "drum": foot.y = r.size.y*0.70; actor_height = r.size.y*0.64
		if acting == "walk":
			var travel: float = Motion.sample("walk",_moment_age,reduced_motion).travel
			foot.x += travel*r.size.x*0.9 if bool(current_direction.get("exit",false)) else (travel-1)*r.size.x*0.40
		_actor_render = Actor.draw_actor(self,key,foot,actor_height,r.size.x*0.84,acting,_moment_age,str(current_direction.get("expr","normal")),false,Color.WHITE,reduced_motion,str(current_direction.get("prop","")))
		if not _actor_render.is_empty(): return
	var shot := str(spec.get("shot", "wide"))
	# 黑格先铺速度线，再把米白人物压上去：读起来像「暗场里的剪影」
	if dark and _impact_left > 0:
		T.speed_lines(self, r.grow(-3), r.get_center(), 52, Color(T.CREAM, 0.22), true)
	if ink == null or shot == "detail":
		if not dark:
			T.hatch(self, r.grow(-6), 14, Color(T.INK, 0.18))
		return

	var tw := float(ink.get_width())
	var th := float(ink.get_height())
	var src := Rect2(0, 0, tw, th)
	var h := 0.0
	var cx := r.size.x * 0.5
	var top := 0.0
	var anchor_bottom := true

	# 关键：远景/中景按「脚贴格底」放，特写按「头顶贴格顶」放。
	# 全用脚贴底的话，一放大头就被推到画面上方格外面 —— 只剩一片头发。
	match shot:
		"wide":
			h = r.size.y * 0.86
			cx = r.size.x * 0.37
		"medium":
			h = r.size.y * 0.98
			cx = r.size.x * 0.58
		"close":
			h = r.size.y * 1.28
			top = -r.size.y * 0.03
			anchor_bottom = false
			cx = r.size.x * 0.55
		"extreme":
			h = r.size.y * 1.7
			top = -r.size.y * 0.16
			anchor_bottom = false
			cx = r.size.x * 0.5
		_:
			h = r.size.y * 0.8

	var dx: float = float(spec.get("dx", 0.0))
	if shot == "medium":
		cx = r.size.x * (0.5 + dx)
	var w: float = h * (src.size.x / src.size.y)
	# 窄格按高度算会横向溢出 → 改成按宽度收，避免只看到脸中间一条
	if w > r.size.x * 1.04:
		w = r.size.x * 1.04
		h = w * (src.size.y / src.size.x)
	var y: float = (r.size.y + 4.0 - h) if anchor_bottom else top
	var dest := Rect2(Vector2(cx - w * 0.5, y), Vector2(w, h))
	var action := str(current_direction.get("action", "idle"))
	var progress := smoothstep(0, 0.85, _moment_age)
	if not reduced_motion:
		if action == "walk":
			dest.position.x += progress * r.size.x * 0.8 if bool(current_direction.get("exit", false)) else (progress - 1) * r.size.x * 0.55
		elif action == "sit": dest.position.y += progress * 24
		elif action == "nod": dest.position.y += sin(minf(_moment_age,1)*PI)*5
		elif action in ["wave", "raise", "phone", "sign", "type"]:
			dest.position.y -= sin(minf(_moment_age, 1) * PI) * 5
		if _impact_left > 0: dest.position.x += sin(_age * 65) * 2 * (_impact_left / 0.5)

	# 镜别辅助线：特写给速度线，远景给地平线排线
	match shot:
		"close", "extreme":
			if _impact_left > 0:
				T.speed_lines(self, r.grow(-4), Vector2(dest.get_center().x, dest.position.y + h * 0.28), 42, Color(T.INK if not dark else T.CREAM, 0.4))
		"wide":
			T.hatch(self, Rect2(0, r.size.y * 0.80, r.size.x, r.size.y * 0.20), 12,
				Color(T.INK if not dark else T.CREAM, 0.22))

	if action == "sleep":
		var center := Vector2(r.size.x * 0.37, r.size.y * 0.50)
		var head_region := Rect2(0,0,ink.get_width(),ink.get_height()*0.62)
		var sleeping_size := head_region.size * (r.size.x * 0.38 / head_region.size.y)
		draw_rect(Rect2(r.size.x*0.12,r.size.y*0.21,r.size.x*0.76,r.size.y*0.60),Color("759a97"))
		draw_rect(Rect2(r.size.x*0.15,r.size.y*0.26,r.size.x*0.38,r.size.y*0.50),T.CREAM)
		draw_set_transform(center, -PI * 0.5)
		draw_texture_rect_region(ink, Rect2(-sleeping_size * 0.5, sleeping_size), head_region)
		draw_set_transform(Vector2.ZERO)
		return
	var flip := bool(spec.get("flip", false))
	if flip:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
		draw_texture_rect_region(ink, Rect2(Vector2(-dest.end.x, dest.position.y), dest.size), src)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 1))
	else:
		draw_texture_rect_region(ink, dest, src)

func _draw_weather(r: Rect2) -> void:
	if _weather == "night": draw_rect(r, Color(0.02, 0.03, 0.1, 0.16))
	if _weather not in ["rain", "snow", "wind"]: return
	var rng := RandomNumberGenerator.new()
	rng.seed = 773
	for i in range(24):
		var x := rng.randf() * r.size.x
		var y := fmod(rng.randf() * r.size.y + _age * (60 if _weather == "rain" else 12), r.size.y)
		if _weather == "rain": draw_line(Vector2(x,y), Vector2(x-4,y+13), Color(T.CREAM,0.32), 1)
		elif _weather == "snow": draw_rect(Rect2(x,y,2,2), Color(T.CREAM,0.6))
		else: draw_line(Vector2(x,y),Vector2(x+30,y-3),Color(T.CREAM,0.24),1)

func _draw_prop(r: Rect2) -> void:
	var prop := str(current_direction.get("prop", ""))
	if not _actor_render.is_empty() and Motion.kind(current_direction) == "drum":
		Actor.drumming(self,_actor_render.rect,_moment_age,reduced_motion)
		return
	if bool(_actor_render.get("baked",false)) and str(current_direction.get("action","")) in ["phone","sign","read"]: return
	var at := Vector2(r.size.x * 0.74, r.size.y * 0.40)
	if not _actor_render.is_empty():
		var body: Rect2 = _actor_render.rect
		var sample: Dictionary = _actor_render.sample
		var hand := body.position+body.size*Vector2(0.67,0.77)
		if prop == "phone": hand = body.position+body.size*Vector2(0.26,0.30)
		at = at.lerp(hand-Vector2(35,25),float(sample.reach))
	if str(spec.get("shot", "")) == "detail" and not prop.is_empty() and prop != "bed":
		var dimensions := Vector2(45,73) if prop == "phone" else Vector2(100,70)
		var zoom := minf(2.4, r.size.y * 0.55 / dimensions.y)
		draw_set_transform(Vector2(r.size.x * 0.5, r.size.y * 0.43) - dimensions * zoom * 0.5, 0, Vector2.ONE * zoom)
		at = Vector2.ZERO
	match prop:
		"toy", "eraser", "pencil", "drum", "clock", "medicine", "letter", "meal":
			preload("res://scripts/comic_objects.gd").draw_on(self,prop,Rect2(at,Vector2(100,90)),minf(1,_moment_age))
		"contract":
			draw_rect(Rect2(at,Vector2(100,70)),T.CREAM)
			for row in range(3): draw_line(at+Vector2(9,12+row*12),at+Vector2(86,12+row*12),T.INK_SOFT,1)
			var length := minf(1,_moment_age/0.8)*50
			draw_line(at+Vector2(18,58),at+Vector2(18+length,52),T.ACCENT,2)
			draw_line(at+Vector2(18+length,52),at+Vector2(40+length,25),T.INK,4)
		"phone":
			draw_rect(Rect2(at,Vector2(45,73)),T.INK)
			draw_rect(Rect2(at+Vector2(3,7),Vector2(39,55)),T.PAPER_DIM)
			draw_circle(at+Vector2(22,67),2,T.CREAM)
		"book":
			draw_colored_polygon(PackedVector2Array([at,at+Vector2(46,5),at+Vector2(46,64),at+Vector2(0,59)]),T.CREAM)
			draw_colored_polygon(PackedVector2Array([at+Vector2(46,5),at+Vector2(92,0),at+Vector2(92,59),at+Vector2(46,64)]),Color("a0c2bc"))
			for row in range(4): draw_line(at+Vector2(8,15+row*9),at+Vector2(38,18+row*9),T.INK_SOFT,1)
		"computer":
			draw_rect(Rect2(at,Vector2(100,62)),T.INK)
			draw_rect(Rect2(at+Vector2(5,5),Vector2(90,48)),T.PAPER_DIM)
			draw_rect(Rect2(at+Vector2(-8,64),Vector2(116,8)),T.CREAM)
			if str(current_direction.get("action", "")) == "poweroff":
				draw_rect(Rect2(at+Vector2(5,5),Vector2(90,48)),Color(T.INK,clampf(_moment_age,0,1)))
			else:
				for row in range(3): draw_line(at+Vector2(15,15+row*10),at+Vector2(65+sin(_age*5)*6,15+row*10),T.CREAM,1)
		"bed":
			var bed := Rect2(r.size.x*0.58,r.size.y*0.23,r.size.x*0.28,r.size.y*0.56)
			draw_rect(bed,T.INK_SOFT)
			draw_line(bed.position+Vector2(5,6),bed.position+Vector2(bed.size.x-5,6),T.CREAM,2)
			draw_line(bed.position+Vector2(bed.size.x-7,10),bed.end-Vector2(7,7),Color(T.CREAM,0.3),1)
	draw_set_transform(Vector2.ZERO)

func _draw_impact(r: Rect2) -> void:
	if _impact_left <= 0 or reduced_motion: return
	T.speed_lines(self,r,r.get_center(),32,Color(T.CREAM,0.20))
	if _impact_left > 0.43: draw_rect(r,Color(1,1,1,0.08))
	if ink != null:
		var inset := Rect2(r.size.x*0.65,12,r.size.x*0.31,r.size.y*0.40)
		draw_rect(inset,T.INK)
		draw_texture_rect_region(ink,inset,Rect2(0,0,ink.get_width(),ink.get_height()*0.63))
		draw_rect(inset,T.CREAM,false,2)

func _draw_gesture(r: Rect2) -> void:
	var action := str(current_direction.get("action", ""))
	if not _actor_render.is_empty():
		if Motion.kind(current_direction) == "drum": return
		if bool(_actor_render.get("baked",false)): return
		var body: Rect2 = _actor_render.rect
		var sample: Dictionary = _actor_render.sample
		var shoulder := body.position+body.size*Vector2(0.36,0.60)
		if action == "wave":
			Actor.arm(self,shoulder,body.position+body.size*Vector2(0.20,0.35)+Vector2(float(sample.hand)*14,0),-18,Color("193c47"),false)
		elif action in ["raise","read","sign","type","poweroff","put_down"]:
			var hand := body.position+body.size*Vector2(0.68,0.80)+Vector2(float(sample.stroke)*3,0)
			Actor.arm(self,shoulder,shoulder.lerp(hand,float(sample.hand)),-16,Color("193c47"))
			if action in ["read","type"]:
				Actor.arm(self,body.position+body.size*Vector2(0.70,0.61),hand+Vector2(-44,4),18,Color("193c47"))
		return
	if action not in ["wave", "raise"]: return
	var at := Vector2(r.size.x * 0.22, r.size.y * 0.36)
	if not reduced_motion and _moment_age < 1.0: at.x += sin(_moment_age * 14) * 6
	draw_line(at+Vector2(8,26),at+Vector2(28,54),T.INK,10)
	draw_line(at+Vector2(8,26),at+Vector2(28,54),T.CREAM,6)
	draw_rect(Rect2(at,Vector2(17,26)),T.INK)
	draw_rect(Rect2(at+Vector2(2,2),Vector2(13,22)),T.CREAM)
	for finger in range(4):
		draw_rect(Rect2(at+Vector2(finger*4,-8+finger%2*2),Vector2(3,13)),T.CREAM)
	for i in range(3): draw_line(at+Vector2(-11-i*4,-5),at+Vector2(-7-i*4,13),Color(T.CREAM,0.6),1)


# ----------------------------------------------------------
func _draw_text(r: Rect2, dark: bool) -> void:
	# 对话模式下文字改由 DialogueBox 承担，格子里只留画面
	if bool(spec.get("hide_text", false)):
		return
	var cap := str(spec.get("caption", ""))
	var caption_length := cap.length()
	var bub := str(spec.get("bubble", ""))
	var shown_cap := cap.substr(0, visible_characters)
	if interaction_done and spec.has("interaction"):
		var discovery := str(spec.interaction.get("reveal",""))
		cap += "\n" + discovery
		shown_cap += "\n" + discovery
	if interaction_done and spec.has("pixel_interaction"):
		var discovery := "发现："+str(spec.pixel_interaction.get("reveal",""))
		cap += "\n"+discovery
		shown_cap += "\n"+discovery
	var dialogue := Dialogue.copy(bub,maxi(0,visible_characters-caption_length-1),str(spec.get("speaker_label","")))
	var shown_bub := str(dialogue.shown)
	if str(spec.get("box", "")) == "dialogue" or (str(spec.get("text_channel", "")) == "dialogue" and not bub.is_empty()):
		_draw_dialogue_box(r, shown_cap, shown_bub, cap)
		return
	var sfx_s := str(current_direction.get("sfx", "")) if not _full_text.is_empty() else str(spec.get("sfx", ""))
	var shot := str(spec.get("shot", "wide"))
	var pad := 8.0
	var col := T.CREAM if dark else T.INK
	# 小格用更小的字号：13px 的旁白框在 5 格版里会盖掉大半格
	var cap_sz := 15
	if r.size.x < 230:
		cap_sz = 11
	if r.size.x < 165:
		cap_sz = 10

	# 黑格里文字反白，所以旁白框改成「透明底 + 白字」
	if not cap.is_empty():
		if dark and not World.enabled(spec):
			_draw_caption_dark(r, shown_cap, pad, cap)
		else:
			# 旁白统一压在格子下沿：角色头部永远在格子上方，压上面必定盖脸
			var f := T.font_body()
			var box_w: float = r.size.x - pad * 2 - 8
			var measured: Vector2 = f.get_multiline_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, box_w - 14, cap_sz)
			var y: float = r.end.y - measured.y - pad * 2 - 11
			if spec.has("pixel_interaction"): y -= 34
			T.caption_box(self, Vector2(r.position.x + pad, y), shown_cap, box_w, cap_sz, false, cap)

	if not bub.is_empty():
		var bw: float = minf(r.size.x - pad * 2 - 10, 210.0)
		var bub_sz := 14 if bw > 170 else 11
		var f2 := T.font_body()
		var m2: Vector2 = f2.get_multiline_string_size(bub, HORIZONTAL_ALIGNMENT_LEFT, bw - 18, bub_sz)
		var bh: float = maxf(m2.y, 19) + 18
		var bx: float = r.position.x + r.size.x - bw - pad - 8
		var by: float = r.position.y + pad + (0.0 if cap.is_empty() else 34.0)
		if shot == "close" or shot == "extreme":
			bx = r.position.x + pad
			by = r.position.y + pad
		if str(spec.get("text_channel","")) == "dialogue":
			# 名牌和气泡跟随当前说话拍，而不是停留在面板最初的说话人。
			var actor := str(current_direction.get("actor",spec.get("actor","lead")))
			bx = r.position.x + pad if actor == "lead" else r.end.x - bw - pad - 8
		var bubble_rect := T.bubble(self,Vector2(bx,by),shown_bub,bw,bub_sz,-1 if bx < r.get_center().x else 1,str(dialogue.full))
		Dialogue.draw_chrome(self,bubble_rect,dialogue,_age,reduced_motion)

	if not sfx_s.is_empty():
		if bool(spec.get("vertical", false)):
			# 竖排拟声词靠右放下，别顶到格边被裁掉
			T.sfx_vertical(self, Vector2(r.end.x - 40.0, r.position.y + 14.0), sfx_s, 26,
				T.ACCENT)
		else:
			var sz: int = clampi(int(r.size.x * 0.16), 22, 46)
			T.sfx(self, Vector2(r.size.x * 0.74, r.size.y * 0.24), sfx_s, sz, -0.14,
				T.ACCENT)
	# 页码角标
	var f3 := T.font_body()
	draw_string(f3, Vector2(r.end.x - 22, r.end.y - 8), str(spec.get("idx", "")),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(col, 0.45))


func _draw_caption_dark(r: Rect2, text: String, pad: float, full_text: String = "") -> void:
	var f := T.font_body()
	var inner: float = r.size.x - pad * 2 - 16
	var sz := 15 if r.size.x > 180 else 13
	var m: Vector2 = f.get_multiline_string_size(full_text if not full_text.is_empty() else text, HORIZONTAL_ALIGNMENT_CENTER, inner, sz)
	var y: float = r.get_center().y - m.y * 0.5 + sz
	draw_multiline_string(f, Vector2(r.position.x + pad + 8, y), text,
		HORIZONTAL_ALIGNMENT_CENTER, inner, sz, -1, T.CREAM)
