## ChoiceVFX — 选项主题动画库（像素 VFX）
## 设计原则（技美规范）：
##   - 贴图驱动：粒子使用 assets/vfx/ 下的像素素材（来自 GitHub 库 PixelSRPG-Forge），
##     以 TextureRect 呈现；若贴图缺失（未导入/文件丢失）自动回退为 ColorRect 色块，
##     保证任何环境下动画都不会空转
##   - 性能预算：单次选择最多叠加 MAX_LAYERS(3) 个效果；单效果 ≤ 18 个节点
##   - 自清理：每个节点动画结束后 queue_free，无残留
##   - 所有参数集中在各效果函数顶部，便于调参
class_name ChoiceVFX
extends RefCounted

const MAX_LAYERS := 3  # 单次最多叠加的主题效果数（性能预算）

## 独占集合：这些是「舞台级」重效果（全区域/强对比），出现时不再叠加属性动画，
## 避免两套视觉在同一演出区打架。属性变化仍由浮动数字展示，信息不丢失。
const SOLO_ANIMS := ["glitch", "death", "night", "rain", "jackpot"]

static func is_solo(anim: String) -> bool:
	return SOLO_ANIMS.has(anim)

# ==========================================================
# 像素素材（assets/vfx/，取自 GitHub 库 PixelSRPG-Forge）
# ----------------------------------------------------------
# SPRITE_MAP  —— 单图标动画：整个效果的所有粒子共用这张主题像素图
# POOL_ANIMS  —— 粒子群动画：无专属图标，从 14 张素材池 pool_00..13 中轮换取图，
#                使同一次爆发里的每个粒子各不相同（更缤纷）
# ==========================================================
const SPRITE_DIR := "res://assets/vfx/"

const SPRITE_MAP := {
	"coin": "coin.png",
	"bill": "bill.png",
	"heart": "heart.png",
	"muscle": "muscle.png",
	"decay": "decay.png",
	"clover": "clover.png",
	"wilt": "wilt.png",
	"spark": "spark.png",
	"firework": "firework.png",
	"jackpot": "jackpot.png",
	"night": "night.png",
	"heartbreak": "heartbreak.png",
	"gamble": "gamble.png",
	"code": "code.png",
	"smoke": "smoke.png",
	"tag": "tag.png",
	"death": "death.png",
}

const POOL_ANIMS := ["psych", "hourglass", "confetti"]
const POOL_SIZE := 14  # pool_00.png .. pool_13.png

static var _anim := ""              # 当前正在播放的动画（决定取哪张图）
static var _tex_cache: Dictionary = {}   # 文件名 → Texture2D（含 null 负缓存）
static var _pool_cache: Array = []       # 素材池纹理数组
static var _pool_i := 0                  # 素材池轮询下标

# ==========================================================
# 事件级专属动画：id → 动画类型（精选表）
# ----------------------------------------------------------
# 设计原则：只给「人生里程碑 / 高光 / 低谷」配专属动画，
#          普通事件仍走属性特征分发（见 main.gd _pick_anims）。
# 覆盖优先级：选项 anim 字段 > 事件 eventAnim 字段 > 本表 > 规则兜底
# 规则兜底：id 前缀 "A0"（抽象线）→ glitch；line == "lucky" → gamble
# ==========================================================
const EVENT_ANIM := {
	# —— firework 烟花：高光时刻 / 喜事 ——
	"C15": "firework", "N13": "firework", "N24": "firework", "N30": "firework",
	"N42": "firework", "N15": "firework", "S_RETIRE": "firework", "S_HOT": "firework",
	# —— jackpot 金币爆发：暴富 / 横财 ——
	"M01": "jackpot", "M03": "jackpot", "S_LOTTERY": "jackpot", "C04": "jackpot", "C11": "jackpot",
	# —— night 熬夜：深夜 / 通宵 ——
	"P06": "night", "N12": "night", "A004": "night", "A010": "night", "A015": "night",
	"A033": "night", "A038": "night", "M08": "night", "A027": "night",
	"P17": "night", "P21": "night",
	# —— rain 落雨：失意 / 伤感 ——
	"N21": "rain", "M07": "rain", "M04": "rain", "M12": "rain", "N19": "rain",
	"N18": "rain", "N45": "rain", "N36": "rain", "A020": "rain", "N28": "rain", "M16": "rain",
	# —— heartbreak 心碎：情感 ——
	"N11": "heartbreak", "N31": "heartbreak", "A007": "heartbreak",
	"A014": "heartbreak", "A030": "heartbreak", "M05": "heartbreak",
	# —— exam 考试：学业 ——
	"N01": "exam", "N03": "exam", "N04": "exam", "N07": "exam", "N08": "exam",
	"C08": "exam", "C17": "exam", "C18": "exam", "A003": "exam",
	"N38": "exam", "S_XHSD": "exam",
	# —— gamble 骰子：赌运 / 抽卡 ——
	"L06": "gamble", "L14": "gamble", "L17": "gamble", "L24": "gamble",
	"L28": "gamble", "A029": "gamble",
	# —— code 代码雨：AI / 科技 ——
	"A008": "code", "A012": "code", "A023": "code", "A031": "code",
	# —— death 心电图：濒危 / 病痛 / 事故 ——
	"S_NEAR": "death", "S_ICU": "death", "N39": "death",
	"P09": "death", "P11": "death", "P14": "death", "N22": "death",
	# —— smoke 烟雾：颓废 / 烟 ——
	"N34": "smoke", "P16": "smoke",
	# —— run 速度线：逃离 / 奔波 ——
	"C06": "run", "C14": "run", "N25": "run", "M15": "run",
}

## 解析事件级专属动画：显式字段 > 精选表 > 规则兜底；无则返回空串
static func resolve_event_anim(event: Dictionary) -> String:
	if event.is_empty():
		return ""
	if event.has("eventAnim"):
		return str(event["eventAnim"])
	var eid: String = str(event.get("id", ""))
	if EVENT_ANIM.has(eid):
		return str(EVENT_ANIM[eid])
	if eid.begins_with("A0"):
		return "glitch"          # 抽象线整条 → 故障偏移
	if str(event.get("line", "")) == "lucky":
		return "gamble"          # 梗/运气线 → 骰子
	return ""

# ==========================================================
# 主入口
# ==========================================================
## anims: 动画类型字符串数组；tags: 本次新获得的标签（用于 tag 弹泡）
static func play(parent: Control, anims: Array, tags: Array, pal: Dictionary) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	if anims.is_empty():
		return
	var w := parent.size.x
	var h := parent.size.y
	if w <= 0.0:
		w = 320.0
	if h <= 0.0:
		h = 130.0
	_pool_i = 0  # 每次演出从素材池头部重新取图
	for a in anims:
		_dispatch(parent, str(a), tags, w, h, pal)

static func _dispatch(parent: Control, anim: String, tags: Array, w: float, h: float, pal: Dictionary) -> void:
	_anim = anim  # 决定 _ico() 取用哪张像素素材
	match anim:
		"coin": _coin(parent, w, h)
		"bill": _bill(parent, w, h)
		"brain": _brain(parent, w, h)
		"heart": _heart(parent, w, h)
		"muscle": _muscle(parent, w, h)
		"decay": _decay(parent, w, h)
		"clover": _clover(parent, w, h)
		"psych": _psych(parent, w, h)
		"hourglass": _hourglass(parent, w, h)
		"confetti": _confetti(parent, w, h)
		"wilt": _wilt(parent, w, h)
		"tag": _tag(parent, tags, h, pal)
		# ---- 事件级专属动画 ----
		"firework": _firework(parent, w, h)
		"jackpot": _jackpot(parent, w, h)
		"night": _night(parent, w, h)
		"rain": _rain(parent, w, h)
		"heartbreak": _heartbreak(parent, w, h)
		"exam": _exam(parent, w, h)
		"gamble": _gamble(parent, w, h)
		"code": _code(parent, w, h)
		"death": _death(parent, w, h)
		"glitch": _glitch(parent, w, h)
		"smoke": _smoke(parent, w, h)
		"run": _run(parent, w, h)
		_: _spark(parent, w, h)

# ==========================================================
# 素材加载
# ==========================================================
## 加载 assets/vfx/ 下的贴图；失败/缺失返回 null（并负缓存，避免反复 IO）
static func _load_tex(fn: String) -> Texture2D:
	if fn == "":
		return null
	if _tex_cache.has(fn):
		return _tex_cache[fn] as Texture2D
	var path := SPRITE_DIR + fn
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	_tex_cache[fn] = t
	return t

## 从素材池轮换取一张图（一次爆发内每个粒子各不相同）
static func _pool_tex() -> Texture2D:
	if _pool_cache.is_empty():
		for i in range(POOL_SIZE):
			var t := _load_tex("pool_%02d.png" % i)
			if t != null:
				_pool_cache.append(t)
	if _pool_cache.is_empty():
		return null
	var t2: Texture2D = _pool_cache[_pool_i % _pool_cache.size()]
	_pool_i += 1
	return t2

## 当前动画应当使用的像素图（无则 null）
static func _cur_tex() -> Texture2D:
	if POOL_ANIMS.has(_anim):
		return _pool_tex()
	if SPRITE_MAP.has(_anim):
		return _load_tex(str(SPRITE_MAP[_anim]))
	return null

# ==========================================================
# 工具
# ==========================================================
## 色块（结构性元素/无贴图时的回退）
static func _px(parent: Control, pos: Vector2, size: Vector2, col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.size = size
	r.position = pos
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r

## 像素图粒子：优先用贴图（就近取点采样，保留像素锐利），缺失时回退为同尺寸色块。
## col 作为「主题色」以 50% 力度叠加在贴图上，既保留素材本来的色彩，又让主题可读。
static func _ico(parent: Control, pos: Vector2, size: Vector2, col: Color) -> Control:
	var tex := _cur_tex()
	if tex == null:
		return _px(parent, pos, size, col)
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.size = size
	t.position = pos
	t.self_modulate = Color.WHITE.lerp(col, 0.5)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	return t

static func _free(n: Node) -> void:
	if is_instance_valid(n):
		n.queue_free()

# ==========================================================
# 各主题效果
# ==========================================================

## coin — 金钱上涨：金币雨（顶部错峰落下 + 横向漂移）
static func _coin(parent: Control, w: float, h: float) -> void:
	var gold := Color(1.0, 0.82, 0.25)
	var gold2 := Color(1.0, 0.65, 0.10)
	for i in range(12):
		var sz := 7.0 + float(i % 3) * 2.5
		var x := randf() * (w - sz)
		var c := _ico(parent, Vector2(x, -sz - randf() * 30.0), Vector2(sz, sz), gold if i % 2 == 0 else gold2)
		var tw := parent.create_tween()
		var dur := 0.5 + randf() * 0.35
		var t := tw.tween_property(c, "position:y", h * (0.45 + randf() * 0.5), dur)
		t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(c, "position:x", x + randf_range(-14.0, 14.0), dur)
		tw.parallel().tween_property(c, "modulate:a", 0.0, 0.22).set_delay(dur - 0.22)
		tw.finished.connect(_free.bind(c))

## bill — 金钱下降：钞票向上飞散消失
static func _bill(parent: Control, w: float, h: float) -> void:
	var g := Color(0.30, 0.85, 0.45)
	for i in range(8):
		var x := randf() * (w - 10.0)
		var r := _ico(parent, Vector2(x, h - 12.0), Vector2(10, 10), g)
		r.modulate.a = 0.0
		var tw := parent.create_tween()
		tw.tween_property(r, "modulate:a", 1.0, 0.1)
		tw.parallel().tween_property(r, "position:y", h * 0.18 + randf() * 20.0, 0.55)
		tw.parallel().tween_property(r, "position:x", x + randf_range(-16.0, 16.0), 0.55)
		tw.tween_property(r, "modulate:a", 0.0, 0.3)
		tw.finished.connect(_free.bind(r))

## brain — 智力上涨：灯泡光圈 + 脑电波折线
static func _brain(parent: Control, w: float, h: float) -> void:
	var pur := Color(0.63, 0.42, 1.0)
	var cx := w * 0.5
	# 灯泡光圈
	var ring := _px(parent, Vector2(cx - 9.0, 16.0), Vector2(18, 18), Color(1.0, 0.95, 0.5, 0.0))
	ring.pivot_offset = Vector2(9, 9)
	var tw := parent.create_tween()
	tw.tween_property(ring, "color:a", 0.6, 0.18)
	tw.parallel().tween_property(ring, "scale", Vector2(1.5, 1.5), 0.5)
	tw.tween_property(ring, "color:a", 0.0, 0.4)
	tw.finished.connect(_free.bind(ring))
	# 脑电波（Line2D，1 个节点画完整波形）
	var pts := PackedVector2Array()
	for i in range(11):
		pts.append(Vector2(cx - 45.0 + float(i) * 9.0, 46.0 + (8.0 if i % 2 == 0 else -8.0)))
	var ln := Line2D.new()
	ln.points = pts
	ln.width = 3.0
	ln.default_color = pur
	ln.joint_mode = Line2D.LINE_JOINT_ROUND
	ln.modulate.a = 0.0
	parent.add_child(ln)
	var t2 := parent.create_tween()
	t2.tween_property(ln, "modulate:a", 1.0, 0.1)
	t2.tween_property(ln, "modulate:a", 0.0, 0.45).set_delay(0.25)
	t2.finished.connect(_free.bind(ln))

## heart — 魅力上涨：粉色像素上升流（左右交错）
static func _heart(parent: Control, w: float, h: float) -> void:
	var pink := Color(1.0, 0.37, 0.82)
	var pink2 := Color(1.0, 0.62, 0.90)
	for i in range(10):
		var tt := float(i) / 9.0
		var side := 1.0 if i % 2 == 0 else -1.0
		var x := w * 0.5 + sin(tt * PI) * (w * 0.26) * side
		var y := h - 14.0 - tt * (h - 48.0)
		var r := _ico(parent, Vector2(x, y), Vector2(9, 9), pink if i % 2 == 0 else pink2)
		r.modulate.a = 0.0
		var tw := parent.create_tween()
		tw.tween_property(r, "modulate:a", 1.0, 0.1).set_delay(0.05 * i)
		tw.parallel().tween_property(r, "position:y", y - 26.0, 0.7).set_delay(0.05 * i)
		tw.parallel().tween_property(r, "position:x", x + randf_range(-6.0, 6.0), 0.7).set_delay(0.05 * i)
		tw.tween_property(r, "modulate:a", 0.0, 0.3).set_delay(0.05 * i + 0.5)
		tw.finished.connect(_free.bind(r))

## muscle — 体质上涨：力量脉冲双环（中心向外扩散）
static func _muscle(parent: Control, w: float, h: float) -> void:
	var green := Color(0.22, 1.0, 0.53)
	var c := Vector2(w * 0.5, h * 0.55)
	for i in range(2):
		var r := _ico(parent, c - Vector2(10, 10), Vector2(20, 20), green)
		r.modulate.a = 0.0
		var tw := parent.create_tween()
		tw.tween_property(r, "modulate:a", 0.85, 0.1).set_delay(0.14 * i)
		tw.parallel().tween_property(r, "size", Vector2(46, 46), 0.5).set_delay(0.14 * i)
		tw.parallel().tween_property(r, "position", c - Vector2(23, 23), 0.5).set_delay(0.14 * i)
		tw.parallel().tween_property(r, "modulate:a", 0.0, 0.5).set_delay(0.14 * i)
		tw.finished.connect(_free.bind(r))

## decay — 体质下降：红闪 + 舞台抖动 + 红色斜向碎片
static func _decay(parent: Control, w: float, h: float) -> void:
	var red := Color(1.0, 0.30, 0.37)
	var ov := _px(parent, Vector2.ZERO, Vector2(w, h), Color(red.r, red.g, red.b, 0.0))
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	var tw := parent.create_tween()
	tw.tween_property(ov, "color:a", 0.22, 0.08)
	tw.tween_property(ov, "color:a", 0.0, 0.32)
	tw.finished.connect(_free.bind(ov))
	# 抖动（横向小幅横跳）
	var sh := parent.create_tween()
	for i in range(4):
		sh.tween_property(ov, "position:x", 4.0 if i % 2 == 0 else -4.0, 0.04)
	sh.tween_property(ov, "position:x", 0.0, 0.04)
	# 碎片上抛
	for i in range(8):
		var x := w * 0.5 + randf_range(-30.0, 30.0)
		var r := _ico(parent, Vector2(x, h * 0.55), Vector2(8, 8), red)
		var tw2 := parent.create_tween()
		var t := tw2.tween_property(r, "position", Vector2(x + randf_range(-24.0, 24.0), h * 0.15), 0.55)
		t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw2.parallel().tween_property(r, "modulate:a", 0.0, 0.5).set_delay(0.2)
		tw2.finished.connect(_free.bind(r))

## clover — 运气上涨：青色方块绕中心自转 + 星点
static func _clover(parent: Control, w: float, h: float) -> void:
	var cyan := Color(0.31, 0.89, 1.0)
	var c := Vector2(w * 0.5, h * 0.55)
	for i in range(8):
		var ang := TAU * float(i) / 8.0
		var r := _ico(parent, c + Vector2(cos(ang), sin(ang)) * 17.0 - Vector2(4, 4), Vector2(9, 9), cyan)
		r.pivot_offset = r.size * 0.5
		var tw := parent.create_tween()
		var t := tw.tween_property(r, "rotation", TAU, 0.6)
		t.set_trans(Tween.TRANS_LINEAR)
		tw.parallel().tween_property(r, "modulate:a", 0.0, 0.6).set_delay(0.25)
		tw.finished.connect(_free.bind(r))

## psych — 抽象度大变（|Δ|≥12）：彩虹螺旋粒子
static func _psych(parent: Control, w: float, h: float) -> void:
	var hue := [
		Color(1.0, 0.30, 0.80), Color(0.60, 0.40, 1.0), Color(0.30, 0.90, 1.0),
		Color(0.30, 1.00, 0.60), Color(1.00, 0.85, 0.30)
	]
	var c := Vector2(w * 0.5, h * 0.62)
	for i in range(14):
		var ang := float(i) * 0.9
		var rad := 8.0 + float(i) * 3.0
		var r := _ico(parent, c + Vector2(cos(ang), sin(ang)) * rad, Vector2(8, 8), hue[i % hue.size()])
		r.pivot_offset = r.size * 0.5
		var tgt := c + Vector2(cos(ang + 2.2), sin(ang + 2.2)) * (rad + 26.0)
		var tw := parent.create_tween()
		var t := tw.tween_property(r, "position", tgt, 0.7)
		t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(r, "rotation", 3.0, 0.7)
		tw.parallel().tween_property(r, "modulate:a", 0.0, 0.7).set_delay(0.2)
		tw.finished.connect(_free.bind(r))

## hourglass — 寿命变化：金色细沙流下 + 底部沙堆
static func _hourglass(parent: Control, w: float, h: float) -> void:
	var sand := Color(1.0, 0.85, 0.45)
	var cx := w * 0.5
	for i in range(10):
		var r := _ico(parent, Vector2(cx - 3.0 + randf_range(-7.0, 7.0), 20.0), Vector2(7, 7), sand)
		var tw := parent.create_tween()
		var t := tw.tween_property(r, "position:y", h - 26.0, 0.45 + randf() * 0.3)
		t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(r, "modulate:a", 0.0, 0.4).set_delay(0.25)
		tw.finished.connect(_free.bind(r))
	var pile := _px(parent, Vector2(cx - 14.0, h - 9.0), Vector2(28, 6), sand)
	pile.modulate.a = 0.0
	var t2 := parent.create_tween()
	t2.tween_property(pile, "modulate:a", 0.8, 0.2).set_delay(0.3)
	t2.tween_property(pile, "modulate:a", 0.0, 0.5).set_delay(0.7)
	t2.finished.connect(_free.bind(pile))

## confetti — 净收益 ≥ +6：五彩纸屑雨
static func _confetti(parent: Control, w: float, h: float) -> void:
	var cols := [
		Color(1.0, 0.30, 0.40), Color(1.0, 0.85, 0.30), Color(0.30, 1.00, 0.55),
		Color(0.30, 0.90, 1.00), Color(0.65, 0.40, 1.00)
	]
	for i in range(18):
		var x := randf() * w
		var r := _ico(parent, Vector2(x, -9.0 - randf() * 20.0), Vector2(9, 9), cols[i % cols.size()])
		r.pivot_offset = r.size * 0.5
		var tw := parent.create_tween()
		var dur := 0.8 + randf() * 0.5
		var t := tw.tween_property(r, "position:y", h + 10.0, dur)
		t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(r, "position:x", x + randf_range(-30.0, 30.0), dur)
		tw.parallel().tween_property(r, "rotation", randf_range(-6.0, 6.0), dur)
		tw.finished.connect(_free.bind(r))

## wilt — 净损失 ≤ -6：舞台压暗 + 灰褐碎片下坠
static func _wilt(parent: Control, w: float, h: float) -> void:
	var ov := _px(parent, Vector2.ZERO, Vector2(w, h), Color(0.25, 0.22, 0.20, 0.0))
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	var tw := parent.create_tween()
	tw.tween_property(ov, "color:a", 0.3, 0.3)
	tw.tween_property(ov, "color:a", 0.0, 0.6).set_delay(0.3)
	tw.finished.connect(_free.bind(ov))
	var brown := Color(0.55, 0.42, 0.30)
	for i in range(12):
		var x := randf() * w
		var r := _ico(parent, Vector2(x, h * 0.5), Vector2(8, 8), brown)
		r.pivot_offset = r.size * 0.5
		var t2 := parent.create_tween()
		var t := t2.tween_property(r, "position:y", h + 6.0, 0.7 + randf() * 0.3)
		t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t2.parallel().tween_property(r, "rotation", randf_range(-4.0, 4.0), 0.7)
		t2.parallel().tween_property(r, "modulate:a", 0.0, 0.6).set_delay(0.25)
		t2.finished.connect(_free.bind(r))

## tag — 获得标签：圆角标签泡从底部弹出再回落（左侧带像素图标）
static func _tag(parent: Control, tags: Array, h: float, pal: Dictionary) -> void:
	var yc: Color = pal.get("yellow", Color.YELLOW)
	var tag_tex := _load_tex(str(SPRITE_MAP["tag"]))
	for i in range(min(tags.size(), 2)):
		var p := PanelContainer.new()
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.09, 0.11, 0.14, 0.92)
		st.border_color = yc
		st.set_border_width_all(1)
		st.set_corner_radius_all(4)
		st.content_margin_left = 8
		st.content_margin_right = 8
		st.content_margin_top = 4
		st.content_margin_bottom = 4
		p.add_theme_stylebox_override("panel", st)
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		if tag_tex != null:
			var ic := TextureRect.new()
			ic.texture = tag_tex
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			ic.custom_minimum_size = Vector2(14, 14)
			ic.self_modulate = yc
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(ic)
		var l := Label.new()
		l.text = ("" if tag_tex != null else "🏷 ") + str(tags[i])
		l.add_theme_color_override("font_color", yc)
		l.add_theme_font_size_override("font_size", 13)
		box.add_child(l)
		p.add_child(box)
		p.position = Vector2(12.0 + float(i) * 10.0, h + 6.0)
		parent.add_child(p)
		var tw := parent.create_tween()
		var t := tw.tween_property(p, "position:y", h - 42.0 - float(i) * 26.0, 0.28)
		t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "position:y", h - 6.0, 0.3).set_delay(0.95)
		tw.tween_property(p, "modulate:a", 0.0, 0.25).set_delay(1.2)
		tw.finished.connect(_free.bind(p))

## spark — 默认（无特征匹配）：像素爆点
static func _spark(parent: Control, w: float, h: float) -> void:
	var col := Color(0.31, 0.89, 1.0)
	var base := Vector2(w * 0.5 - 4.0, h - 24.0)
	for i in range(14):
		var px := _ico(parent, base, Vector2(9, 9), col)
		var ang := TAU * float(i) / 14.0
		var dist := 34.0 + float(i % 4) * 16.0
		var tgt := Vector2(base.x + cos(ang) * dist, base.y - absf(sin(ang)) * dist)
		var tw := parent.create_tween()
		var t := tw.tween_property(px, "position", tgt, 0.5)
		t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(px, "modulate:a", 0.0, 0.5)
		tw.finished.connect(_free.bind(px))

# ==========================================================
# 事件级专属动画（精选：人生里程碑 / 高光 / 低谷）
# 每个函数 ≤18 节点，程序化生成，结束后自清理
# ==========================================================

## firework — 高光时刻：三处烟花依次绽放
static func _firework(parent: Control, w: float, h: float) -> void:
	var cols := [
		Color(1.0, 0.30, 0.40), Color(1.0, 0.85, 0.30), Color(0.30, 0.90, 1.00),
		Color(0.65, 0.40, 1.00), Color(0.30, 1.00, 0.60)
	]
	for f in range(3):
		var c := Vector2(w * (0.30 + 0.20 * float(f)), h * (0.34 + 0.14 * float(f % 2)))
		for i in range(6):
			var ang := TAU * float(i) / 6.0 + float(f) * 0.5
			var r := _ico(parent, c - Vector2(4, 4), Vector2(9, 9), cols[(f + i) % cols.size()])
			r.pivot_offset = r.size * 0.5
			var dist := 22.0 + float(i % 3) * 9.0
			var tgt := c + Vector2(cos(ang), sin(ang)) * dist - Vector2(4, 4)
			var tw := parent.create_tween()
			var t := tw.tween_property(r, "position", tgt, 0.5).set_delay(0.2 * float(f))
			t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(r, "modulate:a", 0.0, 0.5).set_delay(0.2 * float(f) + 0.12)
			tw.finished.connect(_free.bind(r))

## jackpot — 一夜暴富：金币雨 + 中心金光爆开
static func _jackpot(parent: Control, w: float, h: float) -> void:
	var gold := Color(1.0, 0.82, 0.25)
	var gold2 := Color(1.0, 0.62, 0.10)
	for i in range(12):
		var sz := 8.0 + float(i % 3) * 2.0
		var x := randf() * (w - sz)
		var c := _ico(parent, Vector2(x, -sz - randf() * 26.0), Vector2(sz, sz), gold if i % 2 == 0 else gold2)
		var tw := parent.create_tween()
		var dur := 0.45 + randf() * 0.3
		var t := tw.tween_property(c, "position:y", h * (0.5 + randf() * 0.42), dur)
		t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(c, "position:x", x + randf_range(-10.0, 10.0), dur)
		tw.parallel().tween_property(c, "modulate:a", 0.0, 0.2).set_delay(dur - 0.2)
		tw.finished.connect(_free.bind(c))
	var burst := _px(parent, Vector2(w * 0.5 - 20.0, h * 0.42), Vector2(40, 40), Color(1.0, 0.9, 0.5, 0.0))
	burst.pivot_offset = Vector2(20, 20)
	var tb := parent.create_tween()
	tb.tween_property(burst, "color:a", 0.55, 0.12)
	tb.parallel().tween_property(burst, "scale", Vector2(2.2, 2.2), 0.5)
	tb.tween_property(burst, "color:a", 0.0, 0.4)
	tb.finished.connect(_free.bind(burst))

## night — 熬夜：全屏压暗 + 月亮升起 + 闭眼
static func _night(parent: Control, w: float, h: float) -> void:
	var ov := _px(parent, Vector2.ZERO, Vector2(w, h), Color(0.04, 0.06, 0.20, 0.0))
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	var tw := parent.create_tween()
	tw.tween_property(ov, "color:a", 0.55, 0.35)
	tw.tween_property(ov, "color:a", 0.32, 0.5)
	tw.finished.connect(_free.bind(ov))
	var moon := _ico(parent, Vector2(w * 0.74, 14.0), Vector2(22, 22), Color(0.98, 0.96, 0.80))
	moon.modulate.a = 0.0
	var tm := parent.create_tween()
	tm.tween_property(moon, "modulate:a", 0.95, 0.25)
	tm.parallel().tween_property(moon, "position:y", 4.0, 0.6)
	tm.tween_property(moon, "modulate:a", 0.0, 0.5).set_delay(1.0)
	tm.finished.connect(_free.bind(moon))
	for i in range(2):
		var x := w * (0.42 + 0.16 * float(i))
		var eye := _px(parent, Vector2(x, h * 0.44), Vector2(7, 2), Color(0.90, 0.90, 0.95))
		eye.modulate.a = 0.0
		var te := parent.create_tween()
		te.tween_property(eye, "modulate:a", 0.8, 0.2).set_delay(0.3)
		te.tween_property(eye, "modulate:a", 0.0, 0.4).set_delay(1.1)
		te.finished.connect(_free.bind(eye))

## rain — 落雨：冷蓝压暗 + 斜向雨丝
static func _rain(parent: Control, w: float, h: float) -> void:
	var ov := _px(parent, Vector2.ZERO, Vector2(w, h), Color(0.20, 0.26, 0.34, 0.0))
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	var tw := parent.create_tween()
	tw.tween_property(ov, "color:a", 0.35, 0.3)
	tw.tween_property(ov, "color:a", 0.0, 0.7)
	tw.finished.connect(_free.bind(ov))
	var blue := Color(0.45, 0.65, 0.90)
	for i in range(14):
		var x := randf() * w
		var y := -10.0 - randf() * 30.0
		var ln := _px(parent, Vector2(x, y), Vector2(2, 9), Color(blue.r, blue.g, blue.b, 0.92))
		var dur := 0.42 + randf() * 0.25
		var tr := parent.create_tween()
		tr.tween_property(ln, "modulate:a", 0.85, 0.06)
		tr.parallel().tween_property(ln, "position:y", h + 8.0, dur)
		tr.parallel().tween_property(ln, "position:x", x - 18.0, dur)
		tr.tween_property(ln, "modulate:a", 0.0, 0.14)
		tr.finished.connect(_free.bind(ln))

## heartbreak — 心碎：粉色心形像素裂成两半向两侧坠开
static func _heartbreak(parent: Control, w: float, h: float) -> void:
	var pink := Color(1.0, 0.37, 0.60)
	var cx := w * 0.5
	var cy := h * 0.46
	for half in range(2):
		var dir := -1.0 if half == 0 else 1.0
		for i in range(5):
			var ox := dir * (3.0 + float(i % 3) * 5.0)
			var oy := -7.0 + float(i) * 5.0
			var r := _ico(parent, Vector2(cx + ox, cy + oy), Vector2(9, 9), pink)
			r.pivot_offset = r.size * 0.5
			var tw := parent.create_tween()
			var t := tw.tween_property(r, "position", Vector2(cx + ox + dir * 26.0, cy + oy + 22.0), 0.6)
			t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(r, "rotation", dir * 1.2, 0.6)
			tw.parallel().tween_property(r, "modulate:a", 0.0, 0.5).set_delay(0.22)
			tw.finished.connect(_free.bind(r))

## exam — 考试：试卷从右滑入 + 答题线依次划出
static func _exam(parent: Control, w: float, h: float) -> void:
	var paper := _px(parent, Vector2(w, h * 0.20), Vector2(w * 0.40, h * 0.56), Color(0.93, 0.94, 0.97))
	var tw := parent.create_tween()
	var t := tw.tween_property(paper, "position:x", w * 0.56, 0.32)
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(paper, "modulate:a", 0.0, 0.3).set_delay(0.9)
	tw.finished.connect(_free.bind(paper))
	for i in range(4):
		var ln := _px(parent, Vector2(w * 0.58, h * 0.32 + float(i) * 10.0), Vector2(0, 2), Color(0.30, 0.36, 0.48))
		var tw2 := parent.create_tween()
		tw2.tween_property(ln, "size:x", w * 0.34, 0.16).set_delay(0.40 + 0.08 * float(i))
		tw2.tween_property(ln, "modulate:a", 0.0, 0.25).set_delay(1.0)
		tw2.finished.connect(_free.bind(ln))

## gamble — 赌运/抽卡：两颗骰子旋转减速 + 定格金光
static func _gamble(parent: Control, w: float, h: float) -> void:
	var cx := w * 0.5
	var cy := h * 0.5
	for i in range(2):
		var c := Vector2(cx - 24.0 + float(i) * 48.0, cy - 14.0)
		var die := _ico(parent, c, Vector2(28, 28), Color(0.95, 0.95, 0.98))
		die.pivot_offset = die.size * 0.5
		var tw := parent.create_tween()
		var t := tw.tween_property(die, "rotation", TAU * (1.5 + float(i)), 0.5)
		t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(die, "self_modulate", Color(1.0, 0.83, 0.30), 0.12)
		tw.tween_property(die, "modulate:a", 0.0, 0.35).set_delay(0.2)
		tw.finished.connect(_free.bind(die))
	var pip := _px(parent, Vector2(cx - 3.0, cy - 3.0), Vector2(6, 6), Color(1.0, 0.83, 0.30, 0.0))
	var tp := parent.create_tween()
	tp.tween_property(pip, "color:a", 0.9, 0.2).set_delay(0.5)
	tp.tween_property(pip, "color:a", 0.0, 0.3).set_delay(0.4)
	tp.finished.connect(_free.bind(pip))

## code — 代码雨：绿色像素字符列自顶落下
static func _code(parent: Control, w: float, h: float) -> void:
	var green := Color(0.30, 1.0, 0.55)
	for i in range(10):
		var x := randf() * w
		var col := green if i % 3 != 0 else Color(0.70, 1.0, 0.80)
		var r := _ico(parent, Vector2(x, -8.0 - randf() * 40.0), Vector2(7, 9), col)
		var tw := parent.create_tween()
		var dur := 0.5 + randf() * 0.4
		var t := tw.tween_property(r, "position:y", h + 6.0, dur)
		t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(r, "modulate:a", 0.0, dur * 0.5).set_delay(dur * 0.6)
		tw.finished.connect(_free.bind(r))

## death — 濒危：黑幕压暗 + 心电图跳动后拉平
static func _death(parent: Control, w: float, h: float) -> void:
	var ov := _px(parent, Vector2.ZERO, Vector2(w, h), Color(0.0, 0.0, 0.02, 0.0))
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	var tw := parent.create_tween()
	tw.tween_property(ov, "color:a", 0.55, 0.35)
	tw.tween_property(ov, "color:a", 0.34, 0.55)
	tw.finished.connect(_free.bind(ov))
	var pts := PackedVector2Array()
	var cx := w * 0.5
	var base_y := h * 0.5
	var bumps := [0.0, 12.0, -20.0, 8.0, 0.0]
	for i in range(21):
		var x := cx - 90.0 + float(i) * 9.0
		var y := base_y
		if i >= 6 and i <= 10:
			y = base_y - float(bumps[i - 6])
		pts.append(Vector2(x, y))
	var ln := Line2D.new()
	ln.points = pts
	ln.width = 2.5
	ln.default_color = Color(1.0, 0.35, 0.40)
	ln.joint_mode = Line2D.LINE_JOINT_ROUND
	ln.modulate.a = 0.0
	parent.add_child(ln)
	var t2 := parent.create_tween()
	t2.tween_property(ln, "modulate:a", 1.0, 0.12)
	t2.parallel().tween_property(ln, "position:y", 3.0, 1.0)
	t2.tween_property(ln, "modulate:a", 0.0, 0.4).set_delay(0.55)
	t2.finished.connect(_free.bind(ln))
	# 拉平后浮出像素图标，强化「止息」语义
	var mark := _ico(parent, Vector2(cx + 92.0, base_y - 16.0), Vector2(22, 22), Color(1.0, 0.45, 0.50))
	mark.modulate.a = 0.0
	var t3 := parent.create_tween()
	t3.tween_property(mark, "modulate:a", 0.95, 0.35).set_delay(0.55)
	t3.parallel().tween_property(mark, "position:y", base_y - 24.0, 1.0).set_delay(0.55)
	t3.tween_property(mark, "modulate:a", 0.0, 0.4).set_delay(0.5)
	t3.finished.connect(_free.bind(mark))

## glitch — 抽象/故障：RGB 色带横移错位（两波）
static func _glitch(parent: Control, w: float, h: float) -> void:
	var cols := [
		Color(1.0, 0.25, 0.35), Color(0.30, 1.0, 0.60), Color(0.30, 0.85, 1.0),
		Color(1.0, 0.35, 0.90), Color(1.0, 0.85, 0.30)
	]
	for i in range(10):
		var dir := 1.0 if i % 2 == 0 else -1.0
		var r := _px(parent, Vector2(dir * -30.0, randf() * (h - 7.0)), Vector2(w * 0.5, 3.0 + float(i % 2) * 3.0), cols[i % cols.size()])
		r.modulate.a = 0.0
		var tw := parent.create_tween()
		tw.tween_property(r, "modulate:a", 0.75, 0.05).set_delay(0.16 * float(i / 5))
		tw.parallel().tween_property(r, "position:x", w * 0.5 + dir * 42.0, 0.2).set_delay(0.16 * float(i / 5))
		tw.tween_property(r, "modulate:a", 0.0, 0.22).set_delay(0.16 * float(i / 5))
		tw.finished.connect(_free.bind(r))

## smoke — 颓废/烟：灰色烟团上升扩散
static func _smoke(parent: Control, w: float, h: float) -> void:
	var grey := Color(0.55, 0.55, 0.58)
	for i in range(9):
		var x := w * 0.5 + randf_range(-40.0, 40.0)
		var sz := 9.0 + randf() * 7.0
		var r := _ico(parent, Vector2(x, h - 16.0), Vector2(sz, sz), Color(grey.r, grey.g, grey.b, 0.85))
		r.pivot_offset = r.size * 0.5
		var dur := 0.7 + randf() * 0.4
		var tw := parent.create_tween()
		tw.tween_property(r, "modulate:a", 0.6, 0.15).set_delay(0.05 * float(i))
		tw.parallel().tween_property(r, "position:y", h * 0.25 - randf() * 20.0, dur).set_delay(0.05 * float(i))
		tw.parallel().tween_property(r, "position:x", x + randf_range(-22.0, 22.0), dur).set_delay(0.05 * float(i))
		tw.parallel().tween_property(r, "scale", Vector2(1.8, 1.8), dur).set_delay(0.05 * float(i))
		tw.tween_property(r, "modulate:a", 0.0, 0.35)
		tw.finished.connect(_free.bind(r))

## run — 逃离/奔波：横向速度线自右向左扫过
static func _run(parent: Control, w: float, h: float) -> void:
	var col := Color(0.85, 0.88, 0.95)
	for i in range(8):
		var y := h * 0.2 + float(i) * (h * 0.6 / 7.0)
		var ln := _px(parent, Vector2(w, y), Vector2(40.0 + randf() * 50.0, 2), Color(col.r, col.g, col.b, 0.95))
		var dur := 0.32 + randf() * 0.2
		var tw := parent.create_tween()
		tw.tween_property(ln, "modulate:a", 0.8, 0.05).set_delay(0.03 * float(i))
		tw.parallel().tween_property(ln, "position:x", -70.0, dur).set_delay(0.03 * float(i))
		tw.tween_property(ln, "modulate:a", 0.0, 0.12)
		tw.finished.connect(_free.bind(ln))
