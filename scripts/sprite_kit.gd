extends RefCounted
## 分件立绘与场景贴图的加载/缓存。
## 角色 PNG 为 24x36 同画布分件：legL/legR/torso/armL/armR/head(含 head_happy/sad/shock)。
## NPC 只有 base head，没有表情变体；场景 PNG 为 160x90。

const LEAD_STAGES := ["child", "teen", "youth", "adult", "middle", "elder"]
const NPC_ROLES := ["boss", "friend", "mate", "parent", "partner", "teacher", "naiwa"]
const EXPR_PARTS := {"neutral": "head", "happy": "head_happy", "sad": "head_sad", "shock": "head_shock"}

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
	if is_npc:
		return npc_part(role, "head")
	return lead_part(role, EXPR_PARTS.get(expr, "head"))

static func scene(name: String) -> Texture2D:
	return tex("res://assets/scenes/scene_%s.png" % name)

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
	out.append(face(stage_or_role, expr, is_npc))
	return out
