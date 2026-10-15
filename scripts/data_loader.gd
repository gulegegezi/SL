## DataLoader — 加载 game_data.json 并提供类型化访问
## 首次使用前调用 ensure_loaded()，之后只读
extends RefCounted

static var data: Dictionary = {}
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
	loaded = true

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
