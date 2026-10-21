extends RefCounted
## 分件立绘与场景贴图的加载/缓存。
## 角色 PNG 为 24x36 同画布分件：legL/legR/torso/armL/armR/head(含 head_happy/sad/shock)。
## NPC 只有 base head，没有表情变体；场景 PNG 为 160x90。

const LEAD_STAGES := ["child", "teen", "youth", "adult", "middle", "elder"]
const NPC_ROLES := ["boss", "friend", "mate", "parent", "partner", "teacher"]
const EXPR_PARTS := {
	"neutral": "head", "normal": "head", "happy": "head_happy", "sad": "head_sad",
	"shock": "head_shock", "angry": "head_angry", "surprise": "head_surprise",
	"scared": "head_scared", "determined": "head_determined", "shy": "head_shy",
	"hurt": "head_hurt", "blink": "head_blink", "smug": "head_smug",
	"panic": "head_panic", "cry": "head_cry", "dead": "head_dead",
	"love": "head_love", "rage": "head_rage",
}

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
	var part := str(EXPR_PARTS.get(expr, "head"))
	var path := ("res://assets/chars/npc_%s_%s.png" if is_npc else "res://assets/chars/lead_%s_%s.png") % [role, part]
	if ResourceLoader.exists(path):
		return tex(path)
	return npc_part(role, "head") if is_npc else lead_part(role, "head")

static func scene(name: String) -> Texture2D:
	var detailed := preload("res://scripts/pixel_cast.gd").room(name)
	if detailed != null: return detailed
	return tex("res://assets/scenes/scene_%s.png" % name)

## 保持 master 的剧情资源校验 API；旧动画保留其独立 shock 图。
static func norm_face(expr: String) -> String:
	if expr in ["", "neutral"]: return "normal"
	if expr == "shock": return "surprise"
	return expr

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


# ==========================================================
# 逐帧动作（data/frames.json）
# ==========================================================
static var _frame_json: Dictionary = {}

static func frame_defs() -> Dictionary:
	if _frame_json.is_empty():
		var raw := FileAccess.get_file_as_string("res://data/frames.json")
		_frame_json = JSON.parse_string(raw) if not raw.is_empty() else {}
	return _frame_json

static func action_info(key: String, action: String) -> Dictionary:
	var actions: Dictionary = frame_defs().get("actions", {})
	var per: Dictionary = actions.get(key, {})
	return per.get(action, {})

static func action_fps(action: String) -> float:
	var fps: Dictionary = frame_defs().get("fps", {})
	return float(fps.get(action, 8))

## 取某一帧：表情只烘焙在第 0 帧，其余帧回落到 normal。
static func frame(key: String, action: String, index: int, expr: String = "normal", is_npc: bool = false) -> Texture2D:
	var k := ("npc_" + key) if is_npc else key
	var info := action_info(k, action)
	var n := int(info.get("n", 0))
	if n <= 0:
		return null
	var idx := clampi(index, 0, n - 1)
	var faces: Array = info.get("faces", ["normal"])
	var face := expr if faces.has(expr) else "normal"
	if idx != 0:
		face = "normal"
	var p := "res://assets/chars/%s_%s_%d_%s.png" % [k, action, idx, face]
	if ResourceLoader.exists(p):
		return tex(p)
	p = "res://assets/chars/%s_%s_%d_normal.png" % [k, action, idx]
	return tex(p) if ResourceLoader.exists(p) else null
