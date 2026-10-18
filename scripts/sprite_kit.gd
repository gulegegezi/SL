extends RefCounted
## 分件立绘与场景贴图的加载/缓存。
## 角色 PNG 为 24x36 同画布分件：legL/legR/torso/armL/armR/head(含 head_happy/sad/shock)。
## NPC 只有 base head，没有表情变体；场景 PNG 为 160x90。

const LEAD_STAGES := ["child", "teen", "youth", "adult", "middle", "elder"]
const NPC_ROLES := ["boss", "friend", "mate", "parent", "partner", "teacher"]
const EXPR_PARTS := {"neutral": "head", "happy": "head_happy", "sad": "head_sad", "shock": "head_shock"}
const PixelCast := preload("res://scripts/pixel_cast.gd")

static var _cache: Dictionary = {}

static func tex(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var t: Texture2D = load(path)
	_cache[path] = t
	return t

static func lead_part(stage: String, part: String) -> Texture2D:
	return tex("res://assets/chars/lead_%s_%s.png" % [stage, part])

static func npc_part(role: String, part: String) -> Texture2D:
	return tex("res://assets/chars/npc_%s_%s.png" % [role, part])

## 对话框立绘：主角按年龄取阶段；NPC 无表情变体，恒用 base head。
static func face(role: String, expr: String, is_npc: bool) -> Texture2D:
	var portrait := PixelCast.portrait(role, is_npc, expr == "happy")
	if portrait != null: return portrait
	if is_npc:
		return npc_part(role, "head")
	return lead_part(role, EXPR_PARTS.get(expr, "head"))

static func scene(name: String) -> Texture2D:
	var detailed := PixelCast.room(name)
	if detailed != null: return detailed
	return tex("res://assets/scenes/scene_%s.png" % name)

## 过场用的 16:9 房间视野，人物与背景共用一套场景缩放。
static func scene_view(name: String) -> Texture2D:
	var view := PixelCast.room_view(name)
	if view != null: return view
	return scene(name)

static func stage_for_age(age: int) -> String:
	if age <= 6: return "child"
	if age <= 12: return "teen"
	if age <= 18: return "youth"
	if age <= 40: return "adult"
	if age <= 60: return "middle"
	return "elder"

## 组装绘制顺序：腿 → 身 → 手 → 头（头在最上）。全部叠加在同一 24x36 画布。
static func compose(stage_or_role: String, is_npc: bool, expr: String) -> Array:
	var parts := ["legL", "legR", "torso", "armL", "armR"]
	var out: Array = []
	for p in parts:
		out.append(npc_part(stage_or_role, p) if is_npc else lead_part(stage_or_role, p))
	# Legacy composition needs its original full-canvas head layer.
	out.append(npc_part(stage_or_role, "head") if is_npc else lead_part(stage_or_role, EXPR_PARTS.get(expr, "head")))
	return out

# ==========================================================
# 逐帧动画数据（data/frames.json）
# ==========================================================
static var _frames: Dictionary = {}
static var _portrait_cache: Dictionary = {}

static func frames_data() -> Dictionary:
	if _frames.is_empty():
		var txt := FileAccess.get_file_as_string("res://data/frames.json")
		var parsed: Variant = JSON.parse_string(txt)
		if parsed is Dictionary:
			_frames = parsed
	return _frames

## data/frames.json 的 key 是 lead_adult / npc_parent；场景里用的是 adult / parent。
static func key_for(stage_or_role: String, is_npc: bool) -> String:
	return ("npc_" + stage_or_role) if is_npc else ("lead_" + stage_or_role)

## 剧情里的 neutral/shock 映射到 frames.json 的 normal/surprise。
static func norm_face(expr: String) -> String:
	match expr:
		"", "neutral": return "normal"
		"shock": return "surprise"
		_: return expr

static func action_count(key: String, action: String) -> int:
	var actions: Dictionary = frames_data().get("actions", {})
	var a: Dictionary = actions.get(key, {})
	if not a.has(action):
		return 0
	return int(a[action].get("n", 0))

static func action_fps(action: String) -> float:
	return float(frames_data().get("fps", {}).get(action, 6))

## 取一帧：assets/chars/{key}_{action}_{index}_{face}.png。
## 帧表是稀疏的（例如 idle_2 只有 blink），逐级回退保证任何 (index, face) 都能取到图。
static func action_frame(key: String, action: String, index: int, face: String = "normal") -> Texture2D:
	var actions: Dictionary = frames_data().get("actions", {})
	var a: Dictionary = actions.get(key, {})
	if not a.has(action):
		return null
	var n: int = int(a[action].get("n", 0))
	if n <= 0:
		return null
	var faces: Array = a[action].get("faces", ["normal"])
	var f := norm_face(face)
	if not faces.has(f):
		f = "normal"
	var i: int = posmod(index, n)
	var candidates := [
		"res://assets/chars/%s_%s_%d_%s.png" % [key, action, i, f],
		"res://assets/chars/%s_%s_0_%s.png" % [key, action, f],
		"res://assets/chars/%s_%s_%d_normal.png" % [key, action, i],
		"res://assets/chars/%s_%s_0_normal.png" % [key, action],
	]
	for path in candidates:
		if ResourceLoader.exists(path):
			return tex(path)
	return null

## 对话框立绘：从 idle 帧裁出头部（上 15px），保留 10 种表情。
static func frame_portrait(key: String, face: String) -> Texture2D:
	var f := norm_face(face)
	var cache_key := key + ":" + f
	if _portrait_cache.has(cache_key):
		return _portrait_cache[cache_key]
	var base := action_frame(key, "idle", 0, f)
	if base == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = base
	atlas.region = Rect2(0, 0, 24, 15)
	atlas.filter_clip = true
	_portrait_cache[cache_key] = atlas
	return atlas

## 在 CanvasItem 上画一帧逐帧动作；返回 false 表示该 key/action 没有帧数据。
static func draw_action(canvas: CanvasItem, key: String, is_npc: bool, foot: Vector2,
		height: float, action: String, face: String, t: float) -> bool:
	var data_key := key_for(key, is_npc)
	var n := action_count(data_key, action)
	if n <= 0:
		return false
	var index := int(t * action_fps(action))
	var texture := action_frame(data_key, action, index, face)
	if texture == null:
		return false
	var s := height / 36.0
	var w := 24.0 * s
	var h := 36.0 * s
	var rect := Rect2((foot - Vector2(w * 0.5, h)).round(), Vector2(w, h))
	canvas.draw_texture_rect(texture, rect, false)
	return true
