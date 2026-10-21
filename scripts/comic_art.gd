extends RefCounted
const BASE := "res://assets/comic_city/"
static var _regions: Dictionary = {}
static var _cache: Dictionary = {}

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

static func portrait(key: String, pose: int) -> Texture2D:
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
