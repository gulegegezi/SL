extends RefCounted
## Binary Variant storage preserves Rect2 panel layouts and full 64-bit RNG state.
## Never enables object deserialization. Meta achievements remain in their own save.
const RUN_PATH := "user://life_comic_v1.save"
const VERSION := 1

static func state_data(state: RefCounted) -> Dictionary:
	var out := {}
	for property in state.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			out[str(property.name)] = state.get(property.name)
	return out.duplicate(true)

static func restore_state(state: RefCounted, values: Dictionary) -> void:
	for property in state.get_property_list():
		var key := str(property.name)
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and values.has(key):
			state.set(key, values[key])

static func save_run(snapshot: Dictionary, path: String = RUN_PATH) -> bool:
	var envelope := {"version": VERSION, "run": snapshot}
	var stream := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if stream == null: return false
	stream.store_var(envelope, false)
	stream.flush()
	var status := stream.get_error()
	stream.close()
	if status != OK: return false
	if FileAccess.file_exists(path):
		if DirAccess.copy_absolute(path, path + ".bak") != OK: return false
	return DirAccess.rename_absolute(path + ".tmp", path) == OK

static func load_run(path: String = RUN_PATH) -> Dictionary:
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate): continue
		var stream := FileAccess.open(candidate, FileAccess.READ)
		if stream == null or stream.get_length() > 32 * 1024 * 1024: continue
		var value = stream.get_var(false)
		stream.close()
		if not value is Dictionary or int(value.get("version", -1)) != VERSION: continue
		var run = value.get("run", {})
		if not run is Dictionary: continue
		if not run.get("state", null) is Dictionary or not run.get("history", null) is Array: continue
		return run
	return {}

static func save_book(snapshot: Dictionary) -> bool:
	if DirAccess.make_dir_recursive_absolute("user://comic_books") != OK: return false
	var path := "user://comic_books/%s.save" % str(snapshot.get("comic", {}).get("seed", 0))
	return save_run(snapshot, path)

static func books() -> Array:
	var out: Array = []
	var directory := DirAccess.open("user://comic_books")
	if directory == null: return out
	for filename in directory.get_files():
		if not filename.ends_with(".save"): continue
		var path := "user://comic_books/" + filename
		var snapshot := load_run(path)
		if snapshot.is_empty(): continue
		out.append({"path": path, "age": int(snapshot.state.get("age", 0)), "pages": snapshot.history.size(), "time": FileAccess.get_modified_time(path)})
	out.sort_custom(func(a, b): return a.time > b.time)
	return out
