## DataLoader — 加载 game_data.json 并提供类型化访问
## 首次使用前调用 ensure_loaded()，之后只读
extends RefCounted

static var data: Dictionary = {}
static var opening: Dictionary = {}
static var loaded: bool = false

static func ensure_loaded() -> void:
	if loaded:
		return
	var path := "res://data/game_data.json"
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("DataLoader: cannot open " + path)
		return
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if not (parsed is Dictionary):
		push_error("DataLoader: JSON parse failed")
		return
	var parsed_dict: Dictionary = parsed
	data = parsed_dict
	_load_opening()
	loaded = true

## 序章/分支节点与主数据分文件存放，便于单独编辑剧情树。
static func _load_opening() -> void:
	var path := "res://data/story_opening.json"
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		opening = {}
		push_warning("DataLoader: no opening story at " + path)
		return
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if not (parsed is Dictionary):
		opening = {}
		push_error("DataLoader: opening story JSON parse failed")
		return
	opening = parsed

# ---- 便捷访问器 ----
static func regions() -> Dictionary: return data.get("REGIONS", {})
static func region_keys() -> Array: return regions().keys()
static func body_types() -> Array: return data.get("BODY_TYPES", [])
static func health_types() -> Array: return data.get("HEALTH_TYPES", [])
static func tiers() -> Array: return data.get("TIERS", [])
static func families() -> Array: return data.get("FAMILIES", [])
static func talents() -> Array: return data.get("TALENTS", [])
static func parent_jobs() -> Array: return data.get("PARENT_JOBS", [])
static func birth_hours() -> Array: return data.get("BIRTH_HOURS", [])
static func birth_dreams() -> Array: return data.get("BIRTH_DREAMS", [])
static func endings() -> Array: return data.get("ENDINGS", [])
static func achievements() -> Array: return data.get("ACHIEVEMENTS", [])
static func events() -> Array: return data.get("EVENTS", [])
static func xhsd_provinces() -> Array: return data.get("XHSD_PROVINCES", [])

## 按条件获取事件（供 pickEvent 使用）
static func events_by_filter(filter_fn: Callable) -> Array:
	var result: Array = []
	for e in events():
		if filter_fn.call(e):
			result.append(e)
	return result

static func find_event(eid: String) -> Dictionary:
	for e in events():
		if e.get("id", "") == eid:
			return e
	return {}

# ---- 序章 / 分支剧情 ----
static func opening_data() -> Dictionary: return opening
static func opening_nodes() -> Dictionary: return opening.get("nodes", {})
static func opening_title() -> String: return str(opening.get("title", ""))

## 普通线与抽象线各有独立开头；缺省回到 normal。
static func opening_start(line: String) -> String:
	var starts: Dictionary = opening.get("start", {})
	if starts.has(line):
		return str(starts[line])
	return str(starts.get("normal", ""))

## 分支节点优先查序章文件，再查普通事件，这样随机事件也能 next 到后续节点。
static func find_story_node(eid: String) -> Dictionary:
	var nodes: Dictionary = opening_nodes()
	if nodes.has(eid):
		return nodes[eid]
	return find_event(eid)
