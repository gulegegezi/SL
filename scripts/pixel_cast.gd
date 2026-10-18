extends RefCounted
## Generated source atlases stay intact; alpha-bounded regions share a fixed foot anchor.
const BASE := "res://assets/portraits_v2/"
const STAGES := ["infant", "child", "teen", "youth", "adult", "middle", "elder"]
const ROLES := ["parent", "friend", "teacher", "boss", "partner", "mate"]
const ROOMS := ["home", "classroom", "office", "park", "hospital", "grave"]
const BEDROOM_TILE := 1      # bedroom.png 图集里带床+书桌的那一格
const ROOM_CROP_OFF := 170   # 512x512 房间格的上方留白，裁成 16:9 视野
const ROOM_CROP_H := 288
static var _regions: Dictionary = {}
static var _cache: Dictionary = {}

static func stage_for_age(age: int) -> String:
	if age <= 2: return "infant"
	if age <= 6: return "child"
	if age <= 12: return "teen"
	if age <= 18: return "youth"
	if age <= 40: return "adult"
	if age <= 60: return "middle"
	return "elder"

static func frame_index(clock: float, walking: bool, speaking: bool) -> int:
	if walking: return [0, 1, 0, 2][int(clock * 7.0) % 4]
	if speaking: return 3 if int(clock * 4.0) % 2 == 0 else 0
	return 0

static func frame(key: String, npc: bool, index: int = 0) -> Texture2D:
	if _regions.is_empty():
		_regions = JSON.parse_string(FileAccess.get_file_as_string(BASE + "regions.json"))
	var prefix := "npc" if npc else ("infant" if key == "infant" else "lead")
	var id := prefix + ":" + key
	if not _regions.has(id): return null
	var cache_key := "%s:%d" % [id, index]
	if _cache.has(cache_key): return _cache[cache_key]
	var entry: Dictionary = _regions[id]
	var values: Array = entry.frames[clampi(index, 0, 3)]
	var atlas := AtlasTexture.new()
	atlas.atlas = load(BASE + str(entry.file))
	atlas.region = Rect2(values[0], values[1], values[2], values[3])
	atlas.filter_clip = true
	_cache[cache_key] = atlas
	return atlas

static func portrait(key: String, npc: bool, speaking: bool = false) -> Texture2D:
	var body := frame(key, npc, 3 if speaking else 0) as AtlasTexture
	if body == null: return null
	var face := AtlasTexture.new()
	face.atlas = body.atlas
	face.region = Rect2(body.region.position, Vector2(body.region.size.x, body.region.size.y * 0.46))
	face.filter_clip = true
	return face

static func room(name: String) -> Texture2D:
	var key := "room:" + name
	if _cache.has(key): return _cache[key]
	# bedroom.png 也是一张 1536x1024 的图集（3 列 2 行），必须按格子切，
	# 直接 load 整张会把 6 个房间一次性铺出去。
	var file := "environment-atlas.png"
	var index := ROOMS.find(name)
	if name == "bedroom":
		file = "bedroom.png"
		index = BEDROOM_TILE
	if index < 0: return null
	var atlas := AtlasTexture.new()
	atlas.atlas = load(BASE + file)
	atlas.region = Rect2((index % 3) * 512, floori(index / 3.0) * 512, 512, 512)
	atlas.filter_clip = true
	_cache[key] = atlas
	return atlas

## 过场用 16:9 视野：从 512x512 房间格里裁掉上方留白，人物和背景共用同一个场景缩放。
static func room_view(name: String) -> Texture2D:
	var key := "room_view:" + name
	if _cache.has(key): return _cache[key]
	var full := room(name) as AtlasTexture
	if full == null: return null
	var view := AtlasTexture.new()
	view.atlas = full.atlas
	view.region = Rect2(full.region.position.x, full.region.position.y + ROOM_CROP_OFF, 512, ROOM_CROP_H)
	view.filter_clip = true
	_cache[key] = view
	return view

static func draw_actor(canvas: CanvasItem, key: String, npc: bool, foot: Vector2, height: float, clock: float, walking: bool = false, speaking: bool = false) -> void:
	var texture := frame(key, npc, frame_index(clock, walking, speaking))
	if texture == null: return
	var scale := height / texture.get_height()
	var dimensions := texture.get_size() * scale
	canvas.draw_texture_rect(texture, Rect2((foot - Vector2(dimensions.x * 0.5, dimensions.y)).round(), dimensions), false)
