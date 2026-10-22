extends RefCounted
const BASE := "res://assets/comic_city/"
static var _regions: Dictionary = {}
static var _cache: Dictionary = {}
static var _expressions: Dictionary = {}
static var _actions: Dictionary = {}
static var _walking: Dictionary = {}

static func walk_frame(key: String, index: int = 1) -> Texture2D:
	if _walking.is_empty(): _walking = JSON.parse_string(FileAccess.get_file_as_string("res://assets/comic_actions/walk-regions.json"))
	if not _walking.has(key): return null
	var id := "%s:walk:%d" % [key,posmod(index,4)]
	if _cache.has(id): return _cache[id]
	var values: Array = _walking[key].frames[posmod(index,4)]
	var texture := AtlasTexture.new()
	texture.atlas = load("res://assets/comic_actions/walk.png")
	texture.region = Rect2(values[0],values[1],values[2],values[3])
	texture.filter_clip = true
	_cache[id] = texture
	return texture
const ACTION_FRAMES := {"reach":0,"receive":0,"offer":0,"raise":0,"wave":0,"drum":0,"read":1,"phone":2,"sign":3,"draw":3}

static func action_pose(key: String, action: String) -> Texture2D:
	if not ACTION_FRAMES.has(action): return null
	if _actions.is_empty(): _actions = JSON.parse_string(FileAccess.get_file_as_string("res://assets/comic_actions/regions.json"))
	if not _actions.has(key): return null
	var id := key + ":action:" + action
	if _cache.has(id): return _cache[id]
	var data: Dictionary = _actions[key]
	var values: Array = data.frames[int(ACTION_FRAMES[action])]
	var texture := AtlasTexture.new()
	texture.atlas = load("res://assets/comic_actions/"+str(data.file))
	texture.region = Rect2(values[0],values[1],values[2],values[3])
	texture.filter_clip = true
	_cache[id] = texture
	return texture
const EXPRESSION_FRAMES := {"happy": 0, "love": 0, "smug": 0, "cry": 1, "angry": 2, "rage": 2, "shock": 3, "surprise": 3, "panic": 4, "scared": 4, "sleep": 5}

static func background(room: String) -> Texture2D:
	var key := "room:" + room
	if _cache.has(key): return _cache[key]
	var path := "res://assets/rooms/%s.png" % room
	if not ResourceLoader.exists(path): return null
	_cache[key] = load(path)
	return _cache[key]

static func cover_region(texture: Texture2D, viewport_size: Vector2) -> Rect2:
	var source := texture.get_size()
	var ratio := maxf(viewport_size.x / source.x, viewport_size.y / source.y)
	var crop := viewport_size / ratio
	return Rect2((source - crop) * 0.5, crop)

static func portrait(key: String, pose: int, expression: String = "") -> Texture2D:
	if expression in EXPRESSION_FRAMES:
		if _expressions.is_empty():
			_expressions = JSON.parse_string(FileAccess.get_file_as_string("res://assets/comic_expressions/regions.json"))
		if _expressions.has(key):
			var id := "%s:expr:%s" % [key, expression]
			if _cache.has(id): return _cache[id]
			var data: Dictionary = _expressions[key]
			var rect: Array = data.frames[int(EXPRESSION_FRAMES[expression])]
			var image := AtlasTexture.new()
			image.atlas = load("res://assets/comic_expressions/" + str(data.file))
			image.region = Rect2(rect[0], rect[1], rect[2], rect[3])
			image.filter_clip = true
			_cache[id] = image
			return image
	if expression in ["sad", "hurt", "shy", "determined"]: pose = 1
	if _regions.is_empty():
		_regions = JSON.parse_string(FileAccess.get_file_as_string(BASE + "regions.json"))
	if not _regions.has(key): return null
	var cache_key := "%s:%d" % [key, posmod(pose, 2)]
	if _cache.has(cache_key): return _cache[cache_key]
	var entry: Dictionary = _regions[key]
	var region: Array = entry.frames[posmod(pose, 2)]
	var texture := AtlasTexture.new()
	texture.atlas = load(BASE + str(entry.file))
	texture.region = Rect2(region[0], region[1], region[2], region[3])
	texture.filter_clip = true
	_cache[cache_key] = texture
	return texture
