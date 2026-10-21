## SaveManager — 用 FileAccess 替代 localStorage 存取进度
extends RefCounted

const SAVE_PATH := "user://gamelife_save.json"

static func default_meta() -> Dictionary:
	return {
		"endings": {},
		"achievements": {},
		"provincesBorn": {},
		"plays": 0,
		"best": null
	}

static func load_meta() -> Dictionary:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return default_meta()
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		return default_meta()
	# 合并默认值防止缺字段
	var result := default_meta()
	for k in parsed:
		result[k] = parsed[k]
	return result

static func save_meta(meta: Dictionary) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot write to " + SAVE_PATH)
		return
	f.store_string(JSON.stringify(meta))
	f.close()

## 清除存档（用于调试）
static func clear() -> void:
	DirAccess.remove_absolute(SAVE_PATH)
