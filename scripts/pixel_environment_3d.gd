extends RefCounted
const Fx := preload("res://scripts/pixel_fx_3d.gd")
## The Fold palette: ink teal shadows, warm amber light, terracotta punctuation.
## All scenery is actual shallow, block-built 3D geometry. Character standing
## lanes at (-1.1, 0, 0.8) and (1.15, 0, 0) are deliberately left unobstructed.

static func palette(variant: String = "day") -> Dictionary:
	var colors := {
		"ink": Color("172e38"), "shadow": Color("284750"),
		"wall": Color("718c87"), "mid": Color("53766f"),
		"wood": Color("8f6a50"), "floor": Color("89968a"),
		"accent": Color("bc6652"), "warm": Color("efbd76"),
		"light": Color("ffe2a0"), "fog": Color("243f49"),
		"paper": Color("dddbc3"), "leaf": Color("456a59"),
		"sky": Color("7babb0"), "metal": Color("52757c")
	}
	match variant:
		"night":
			colors["wall"] = Color("405b67")
			colors["floor"] = Color("586c70")
			colors["sky"] = Color("304f6f")
			colors["fog"] = Color("132b3b")
		"stage":
			colors["wall"] = Color("62576a")
			colors["mid"] = Color("4d646a")
			colors["floor"] = Color("786e70")
			colors["sky"] = Color("787e9a")
			colors["accent"] = Color("d18165")
		"quiet":
			colors["wall"] = Color("8d9b96")
			colors["floor"] = Color("989d8a")
			colors["sky"] = Color("a2b8ad")
			colors["accent"] = Color("ac8268")
	return colors

static func build(scene: String, variant: String = "day") -> Node3D:
	var root := Node3D.new()
	root.name = "PixelEnvironment"
	var context := {"root": root, "colors": palette(variant), "materials": {}, "scene": scene}
	root.set_meta("scene", scene)
	root.set_meta("palette_variant", variant)
	_ground(context, scene == "park")
	if scene != "park":
		_architecture(context, scene, variant)
	match scene:
		"classroom": _classroom(context)
		"office": _office(context)
		"hospital": _hospital(context)
		"park": _park(context)
		_: _home(context)
	_foreground(context, scene)
	_atmosphere(context, variant, scene)
	_lighting(context, variant, scene == "park")
	var mesh_count := 0
	for child in root.get_children():
		if child is GeometryInstance3D:
			mesh_count += 1
	root.set_meta("mesh_count", mesh_count)
	return root


# ==========================================================
# 程序化材质：给方块加一层像素细节，去掉「塑料玩具」的平涂感
# 32x32、最近邻采样、随材质缓存
# ==========================================================
static var _textures: Dictionary = {}


static func _detail_texture(kind: String) -> Texture2D:
	if _textures.has(kind):
		return _textures[kind]
	var size := 32
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var n := float((x * 73 + y * 151 + x * y * 7) % 97) / 97.0
			var shade := 1.0
			match kind:
				"floor":
					# 砖缝：每 16 像素一条
					if x % 16 == 0 or y % 16 == 0:
						shade = 0.80
					else:
						shade = 0.96 + n * 0.08
				"wall":
					# 竖向抹灰痕
					shade = 0.93 + n * 0.10
					if x % 8 == 0:
						shade *= 0.95
				"wood":
					# 横向木纹 + 偶发深色结
					shade = 0.94 + n * 0.09
					if y % 6 == 0:
						shade *= 0.93
					if (x * 3 + y * 5) % 61 == 0:
						shade *= 0.82
				_:
					shade = 1.0
			var v: int = clampi(int(255.0 * shade), 0, 255)
			image.set_pixel(x, y, Color8(v, v, v, 255))
	var texture := ImageTexture.create_from_image(image)
	_textures[kind] = texture
	return texture


static func _material(context: Dictionary, color: Color, glow: float = 0.0, detail: String = "") -> StandardMaterial3D:
	var key := color.to_html() + ":" + str(glow) + ":" + detail
	var materials: Dictionary = context["materials"]
	if materials.has(key):
		return materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.93
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if not detail.is_empty():
		material.albedo_texture = _detail_texture(detail)
		material.uv1_scale = Vector3(1.0, 1.0, 1.0)
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	materials[key] = material
	return material

static func _box(context: Dictionary, label: String, position: Vector3, dimensions: Vector3, color: Color, glow: float = 0.0, detail: String = "") -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.name = label
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	piece.mesh = mesh
	piece.material_override = _material(context, color, glow, detail)
	piece.position = position
	context["root"].add_child(piece)
	return piece

static func _ground(context: Dictionary, outdoors: bool) -> void:
	var p: Dictionary = context["colors"]
	_box(context, "RaisedDioramaFoundation", Vector3(0, -0.20, 0.35), Vector3(9.0, 0.4, 7.0), p.ink)
	var tile_mesh := BoxMesh.new()
	tile_mesh.size = Vector3(0.99, 0.025, 0.99)
	var tile_material := StandardMaterial3D.new()
	tile_material.vertex_color_use_as_albedo = true
	tile_material.roughness = 1.0
	tile_material.albedo_texture = _detail_texture("floor")
	tile_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	tile_mesh.material = tile_material
	var tiles := MultiMesh.new()
	tiles.transform_format = MultiMesh.TRANSFORM_3D
	tiles.use_colors = true
	tiles.mesh = tile_mesh
	tiles.instance_count = 63
	for row in range(7):
		for col in range(9):
			var index := row * 9 + col
			var base: Color = p.leaf if outdoors else p.floor
			if outdoors and (col >= 3 and col <= 5):
				base = p.wood.lerp(p.paper, 0.36)
			var shade := 0.05 if (col + row) % 2 == 0 else -0.035
			tiles.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(col - 4.0, 0.0125, row - 2.65)))
			tiles.set_instance_color(index, base.lightened(shade))
	var floor_tiles := MultiMeshInstance3D.new()
	floor_tiles.name = "GroundTiles"
	floor_tiles.multimesh = tiles
	context["root"].add_child(floor_tiles)
	# A warm inlay anchors the foreground without hiding feet or interaction props.
	if not outdoors:
		_box(context, "FloorInlay", Vector3(0, 0.030, 1.55), Vector3(5.8, 0.012, 0.055), p.warm.darkened(0.3))

static func _architecture(context: Dictionary, scene: String, variant: String) -> void:
	var p: Dictionary = context["colors"]
	_box(context, "BackWall", Vector3(0, 1.6, -2.8), Vector3(9, 3.2, 0.20), p.wall, 0.0, "wall")
	_box(context, "LeftReturnWall", Vector3(-4.4, 1.6, -1.0), Vector3(0.2, 3.2, 3.6), p.wall.darkened(0.15), 0.0, "wall")
	_box(context, "BackSkirting", Vector3(0, 0.16, -2.66), Vector3(8.8, 0.24, 0.08), p.shadow)
	_box(context, "LeftSkirting", Vector3(-4.26, 0.16, -1.0), Vector3(0.08, 0.24, 3.6), p.shadow)
	_box(context, "BackCornice", Vector3(0, 3.10, -2.62), Vector3(8.8, 0.13, 0.19), p.ink)
	for x in [-4.1, 0.25, 4.1]:
		_box(context, "WallPost", Vector3(x, 1.6, -2.64), Vector3(0.09, 3.0, 0.12), p.mid)
	var win_x := -2.5
	if scene == "classroom":
		win_x = -3.15
	var window_width := 1.45 if scene == "classroom" else 2.25
	_box(context, "WindowRecess", Vector3(win_x, 2.0, -2.64), Vector3(window_width + 0.22, 1.65, 0.13), p.ink)
	_box(context, "WindowLight", Vector3(win_x, 2.0, -2.54), Vector3(window_width, 1.45, 0.08), p.sky, 0.55 if variant == "night" else 0.22)
	_box(context, "WindowMullion", Vector3(win_x, 2.0, -2.47), Vector3(0.07, 1.45, 0.08), p.paper)
	_box(context, "WindowCrossbar", Vector3(win_x, 2.0, -2.47), Vector3(window_width, 0.065, 0.08), p.paper)
	_box(context, "DeepWindowSill", Vector3(win_x, 1.22, -2.36), Vector3(window_width + 0.3, 0.12, 0.45), p.paper)
	if scene != "classroom":
		_box(context, "CurtainLeft", Vector3(win_x - window_width * 0.47, 2.12, -2.37), Vector3(0.28, 1.7, 0.15), p.accent.darkened(0.18))
		_box(context, "CurtainRight", Vector3(win_x + window_width * 0.47, 2.12, -2.37), Vector3(0.28, 1.7, 0.15), p.accent)
		_box(context, "CurtainRod", Vector3(win_x, 3.0, -2.37), Vector3(window_width + 0.55, 0.07, 0.08), p.ink)
	_box(context, "SidePictureFrame", Vector3(-4.26, 2.05, -0.6), Vector3(0.09, 0.9, 0.70), p.wood)
	_box(context, "SidePicture", Vector3(-4.20, 2.05, -0.6), Vector3(0.035, 0.71, 0.52), p.warm.darkened(0.20))

static func _table(context: Dictionary, center: Vector3, width: float = 1.8, depth: float = 0.8) -> void:
	var p: Dictionary = context["colors"]
	_box(context, "TableTop", center + Vector3(0, 0.82, 0), Vector3(width, 0.12, depth), p.wood, 0.0, "wood")
	for dx in [-1.0, 1.0]:
		for dz in [-1.0, 1.0]:
			_box(context, "TableLeg", center + Vector3(dx * (width * 0.5 - 0.11), 0.38, dz * (depth * 0.5 - 0.11)), Vector3(0.10, 0.76, 0.10), p.shadow)

static func _chair(context: Dictionary, center: Vector3, color: Color) -> void:
	var p: Dictionary = context["colors"]
	_box(context, "ChairSeat", center + Vector3(0, 0.48, 0), Vector3(0.62, 0.12, 0.57), color)
	_box(context, "ChairBack", center + Vector3(0, 0.86, -0.23), Vector3(0.62, 0.65, 0.1), color)
	for dx in [-0.23, 0.23]:
		_box(context, "ChairFeet", center + Vector3(dx, 0.22, 0), Vector3(0.08, 0.44, 0.43), p.shadow)

static func _plant(context: Dictionary, center: Vector3, scale: float = 1.0) -> void:
	var p: Dictionary = context["colors"]
	_box(context, "Planter", center + Vector3(0, 0.22, 0) * scale, Vector3(0.43, 0.44, 0.43) * scale, p.accent)
	_box(context, "PlanterSoil", center + Vector3(0, 0.45, 0) * scale, Vector3(0.35, 0.03, 0.35) * scale, p.ink)
	_box(context, "PlantStem", center + Vector3(0, 0.78, 0) * scale, Vector3(0.08, 0.68, 0.08) * scale, p.wood)
	for index in range(5):
		var angle := float(index) * 2.4
		var offset := Vector3(cos(angle) * 0.18, 0.72 + index * 0.09, sin(angle) * 0.17)
		_box(context, "PixelLeaves", center + offset * scale, Vector3(0.33, 0.16, 0.28) * scale, p.leaf.lightened(index * 0.045))

static func _books(context: Dictionary, center: Vector3, count: int = 5) -> void:
	var p: Dictionary = context["colors"]
	var colors: Array = [p.accent, p.mid, p.paper, p.warm, p.shadow]
	for index in range(count):
		var height := 0.30 + (index % 3) * 0.045
		_box(context, "BookSpine", center + Vector3(index * 0.12, height * 0.5, 0), Vector3(0.10, height, 0.25), colors[index % colors.size()])

static func _shelf(context: Dictionary, center: Vector3) -> void:
	var p: Dictionary = context["colors"]
	_box(context, "BookcaseBack", center + Vector3(0, 1.05, 0), Vector3(1.45, 2.1, 0.15), p.shadow)
	for side in [-0.72, 0.72]:
		_box(context, "BookcaseSide", center + Vector3(side, 1.05, 0.15), Vector3(0.10, 2.1, 0.50), p.wood)
	for level in range(4):
		_box(context, "BookcaseShelf", center + Vector3(0, 0.12 + level * 0.64, 0.15), Vector3(1.45, 0.09, 0.50), p.wood)
		if level < 3:
			_books(context, center + Vector3(-0.51, 0.18 + level * 0.64, 0.25), 5)

static func _lamp(context: Dictionary, center: Vector3) -> void:
	var p: Dictionary = context["colors"]
	_box(context, "LampFoot", center + Vector3(0, 0.04, 0), Vector3(0.35, 0.08, 0.28), p.ink)
	_box(context, "LampStem", center + Vector3(0, 0.30, 0), Vector3(0.055, 0.55, 0.055), p.metal)
	_box(context, "LampShade", center + Vector3(0, 0.60, 0), Vector3(0.46, 0.15, 0.28), p.warm, 0.35)

static func _home(context: Dictionary) -> void:
	var p: Dictionary = context["colors"]
	_box(context, "SofaBase", Vector3(-1.9, 0.37, -1.82), Vector3(2.65, 0.52, 0.82), p.mid)
	_box(context, "SofaBack", Vector3(-1.9, 0.85, -2.12), Vector3(2.65, 0.65, 0.24), p.shadow)
	for x in [-3.14, -0.66]:
		_box(context, "SofaArm", Vector3(x, 0.64, -1.82), Vector3(0.20, 0.52, 0.92), p.mid)
	for x in [-2.56, -1.24]:
		_box(context, "SofaCushion", Vector3(x, 0.68, -1.71), Vector3(1.14, 0.17, 0.58), p.mid.lightened(0.12))
	_box(context, "TerracottaPillow", Vector3(-2.63, 0.98, -1.97), Vector3(0.44, 0.44, 0.18), p.accent)
	_table(context, Vector3(2.65, 0, -1.60), 1.65, 0.85)
	_lamp(context, Vector3(3.1, 0.90, -1.65))
	_books(context, Vector3(2.1, 0.90, -1.65), 4)
	_shelf(context, Vector3(3.05, 0, -2.35))
	_box(context, "FamilyPhotoFrame", Vector3(1.05, 2.14, -2.64), Vector3(0.75, 0.62, 0.09), p.wood)
	_box(context, "FamilyPhotoMat", Vector3(1.05, 2.14, -2.57), Vector3(0.57, 0.44, 0.04), p.paper)
	_box(context, "FamilyPhotoSilhouette", Vector3(1.05, 2.10, -2.53), Vector3(0.30, 0.24, 0.02), p.mid)
	_plant(context, Vector3(-3.55, 0, 1.50), 1.1)
	_plant(context, Vector3(3.65, 0, 2.25), 0.8)
	_box(context, "FloorMatBorder", Vector3(-0.25, 0.035, 1.0), Vector3(3.8, 0.025, 2.2), p.shadow)
	_box(context, "WovenMat", Vector3(-0.25, 0.050, 1.0), Vector3(3.6, 0.018, 2.0), p.accent.darkened(0.34))

static func _classroom(context: Dictionary) -> void:
	var p: Dictionary = context["colors"]
	_box(context, "ChalkboardFrame", Vector3(0.5, 2.05, -2.59), Vector3(3.95, 1.65, 0.18), p.wood)
	_box(context, "Chalkboard", Vector3(0.5, 2.05, -2.46), Vector3(3.71, 1.42, 0.08), p.ink)
	for line in range(4):
		_box(context, "ChalkNotes", Vector3(-0.52 + line * 0.10, 2.48 - line * 0.25, -2.40), Vector3(1.65 - line * 0.21, 0.024, 0.016), p.paper.darkened(line * 0.06))
	_box(context, "ChalkTray", Vector3(0.5, 1.21, -2.34), Vector3(4.0, 0.09, 0.3), p.wood)
	for x in [-2.7, 2.7]:
		_table(context, Vector3(x, 0, -0.85), 1.5, 0.85)
		_chair(context, Vector3(x, 0, -1.61), p.mid)
		_books(context, Vector3(x - 0.45, 0.90, -0.88), 3)
		_table(context, Vector3(x, 0, 1.9), 1.5, 0.85)
		_chair(context, Vector3(x, 0, 1.13), p.wood)
	_box(context, "ClockFrame", Vector3(3.45, 2.45, -2.59), Vector3(0.55, 0.55, 0.12), p.shadow)
	_box(context, "ClockFace", Vector3(3.45, 2.45, -2.51), Vector3(0.44, 0.44, 0.04), p.paper)
	_box(context, "ClockMinute", Vector3(3.45, 2.53, -2.47), Vector3(0.025, 0.19, 0.025), p.ink)
	_box(context, "ClockHour", Vector3(3.52, 2.45, -2.47), Vector3(0.14, 0.025, 0.025), p.ink)
	_plant(context, Vector3(-3.75, 0, -2.0), 0.8)

static func _office(context: Dictionary) -> void:
	var p: Dictionary = context["colors"]
	for x in [-2.55, 1.3]:
		_table(context, Vector3(x, 0, -1.65), 2.35, 0.95)
		_box(context, "MonitorFoot", Vector3(x, 0.93, -1.7), Vector3(0.48, 0.06, 0.30), p.ink)
		_box(context, "MonitorStand", Vector3(x, 1.12, -1.9), Vector3(0.09, 0.37, 0.09), p.metal)
		_box(context, "MonitorCasing", Vector3(x, 1.45, -1.9), Vector3(1.04, 0.67, 0.13), p.ink)
		_box(context, "MonitorScreen", Vector3(x, 1.45, -1.82), Vector3(0.92, 0.55, 0.025), p.sky, 0.22)
		_box(context, "Keyboard", Vector3(x, 0.91, -1.35), Vector3(0.71, 0.05, 0.23), p.paper)
		_box(context, "Mug", Vector3(x + 0.83, 1.02, -1.5), Vector3(0.19, 0.25, 0.19), p.accent)
		_chair(context, Vector3(x - 0.2, 0, -0.64), p.shadow)
	_box(context, "FilingCabinet", Vector3(3.45, 0.83, -1.80), Vector3(0.95, 1.66, 0.84), p.metal)
	for index in range(3):
		_box(context, "DrawerFace", Vector3(3.45, 0.33 + index * 0.51, -1.35), Vector3(0.81, 0.42, 0.055), p.mid)
		_box(context, "DrawerHandle", Vector3(3.45, 0.34 + index * 0.51, -1.30), Vector3(0.24, 0.045, 0.06), p.paper)
	_box(context, "Noticeboard", Vector3(0.35, 2.25, -2.60), Vector3(0.8, 0.75, 0.07), p.wood)
	for index in range(3):
		_box(context, "PinnedNotice", Vector3(0.18 + index * 0.17, 2.32 - (index % 2) * 0.25, -2.54), Vector3(0.2, 0.25, 0.02), p.paper)
	_plant(context, Vector3(-3.7, 0, 1.8), 1.25)
	_plant(context, Vector3(3.45, 1.67, -1.80), 0.5)

static func _hospital(context: Dictionary) -> void:
	var p: Dictionary = context["colors"]
	_box(context, "BedFrame", Vector3(-2.50, 0.50, -0.95), Vector3(1.60, 0.20, 2.30), p.metal)
	_box(context, "BedMattress", Vector3(-2.50, 0.68, -0.95), Vector3(1.49, 0.25, 2.19), p.paper)
	_box(context, "BedBlanket", Vector3(-2.50, 0.84, -0.55), Vector3(1.47, 0.09, 1.36), p.mid.lightened(0.22))
	_box(context, "BedPillow", Vector3(-2.50, 0.88, -1.72), Vector3(0.91, 0.18, 0.44), p.paper.lightened(0.1))
	for z in [-2.1, 0.2]:
		_box(context, "BedEndRail", Vector3(-2.50, 0.95, z), Vector3(1.65, 0.08, 0.08), p.metal)
		for x in [-3.26, -1.74]:
			_box(context, "BedLeg", Vector3(x, 0.52, z), Vector3(0.08, 1.04, 0.08), p.metal)
	_table(context, Vector3(2.65, 0, -1.7), 2.05, 0.90)
	_box(context, "MedicalFolder", Vector3(2.4, 0.92, -1.65), Vector3(0.5, 0.055, 0.4), p.accent)
	_box(context, "MedicalPaper", Vector3(2.4, 0.952, -1.65), Vector3(0.43, 0.015, 0.34), p.paper)
	_lamp(context, Vector3(3.26, 0.90, -1.85))
	_chair(context, Vector3(2.8, 0, -0.65), p.mid)
	_box(context, "ScreenPole", Vector3(-3.62, 1.22, 0.45), Vector3(0.06, 2.44, 0.06), p.metal)
	_box(context, "CurtainSideRail", Vector3(-3.68, 2.48, -0.9), Vector3(0.055, 0.055, 3.0), p.paper)
	_box(context, "CurtainEndRail", Vector3(-2.5, 2.48, 0.57), Vector3(2.42, 0.055, 0.055), p.paper)
	_box(context, "FoldedPrivacyCurtain", Vector3(-3.65, 1.46, -0.95), Vector3(0.13, 1.85, 2.68), p.mid)
	_box(context, "MedicalWallPanel", Vector3(1.3, 2.2, -2.60), Vector3(0.78, 0.9, 0.08), p.paper)
	_box(context, "WallPanelCrossA", Vector3(1.3, 2.2, -2.54), Vector3(0.48, 0.12, 0.04), p.accent)
	_box(context, "WallPanelCrossB", Vector3(1.3, 2.2, -2.54), Vector3(0.12, 0.48, 0.04), p.accent)
	_plant(context, Vector3(3.65, 0, 1.9), 0.75)

static func _tree(context: Dictionary, center: Vector3, height: float) -> void:
	var p: Dictionary = context["colors"]
	_box(context, "TreeTrunk", center + Vector3(0, height * 0.40, 0), Vector3(0.27, height * 0.8, 0.27), p.wood.darkened(0.18))
	_box(context, "TreeBranch", center + Vector3(0.23, height * 0.64, 0), Vector3(0.65, 0.18, 0.18), p.wood)
	for index in range(4):
		var offset := Vector3((index % 2) * 0.72 - 0.36, height * 0.73 + index * 0.16, (index / 2) * 0.55 - 0.28)
		_box(context, "TreeCanopy", center + offset, Vector3(1.12, 0.66, 0.94), p.leaf.lightened(index * 0.06))

static func _park(context: Dictionary) -> void:
	var p: Dictionary = context["colors"]
	for x in [-3.5, -1.75, 0.0, 1.75, 3.5]:
		_box(context, "FencePost", Vector3(x, 0.60, -2.35), Vector3(0.13, 1.20, 0.13), p.shadow)
	for y in [0.38, 0.86]:
		_box(context, "FenceRail", Vector3(0, y, -2.35), Vector3(8.0, 0.10, 0.09), p.wood)
	# Background blocks read as a distant town silhouette; they have real depth.
	for index in range(7):
		var height := 1.35 + (index % 3) * 0.39
		_box(context, "DistantTown", Vector3(-4.0 + index * 1.30, height * 0.5, -3.35), Vector3(1.12, height, 0.66), p.fog.lerp(p.wall, 0.2 + (index % 2) * 0.10))
	_tree(context, Vector3(-3.1, 0, -1.45), 3.0)
	_tree(context, Vector3(3.3, 0, -1.6), 3.5)
	_box(context, "ParkBenchSeat", Vector3(-0.1, 0.52, -1.2), Vector3(2.3, 0.12, 0.58), p.wood)
	for index in range(3):
		_box(context, "ParkBenchBackSlat", Vector3(-0.1, 0.82 + index * 0.19, -1.45), Vector3(2.3, 0.13, 0.08), p.wood.lightened(index * 0.04))
	for x in [-0.95, 0.75]:
		_box(context, "ParkBenchFoot", Vector3(x, 0.25, -1.2), Vector3(0.10, 0.50, 0.53), p.ink)
	_box(context, "StreetlightStem", Vector3(2.3, 1.30, -1.8), Vector3(0.09, 2.60, 0.09), p.ink)
	_box(context, "StreetlightCap", Vector3(2.3, 2.67, -1.8), Vector3(0.45, 0.10, 0.42), p.shadow)
	_box(context, "StreetlightGlass", Vector3(2.3, 2.48, -1.8), Vector3(0.29, 0.30, 0.29), p.warm, 0.6)
	for x in [-3.45, 3.5]:
		_box(context, "ForegroundFlowerbed", Vector3(x, 0.13, 2.30), Vector3(1.45, 0.26, 1.20), p.shadow)
		for index in range(5):
			_box(context, "FlowerCluster", Vector3(x - 0.5 + index * 0.25, 0.41 + (index % 2) * 0.10, 2.30), Vector3(0.25, 0.35, 0.40), p.leaf)
			_box(context, "WarmBlossom", Vector3(x - 0.5 + index * 0.25, 0.60 + (index % 2) * 0.10, 2.27), Vector3(0.19, 0.10, 0.18), p.accent if index % 2 else p.warm)

static func _lighting(context: Dictionary, variant: String, outdoors: bool) -> void:
	var p: Dictionary = context["colors"]
	var world := WorldEnvironment.new()
	world.name = "TealAmberEnvironment"
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = p.fog.darkened(0.25)
	sky_material.sky_horizon_color = p.fog.lerp(p.wall, 0.35)
	sky_material.ground_bottom_color = p.ink.darkened(0.2)
	sky_material.ground_horizon_color = p.fog.lerp(p.wall, 0.18)
	sky_material.sun_angle_max = 0.0
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = p.sky
	environment.ambient_light_energy = 0.33 if variant == "night" else 0.37
	# 深度雾：按实际 3D 距离衰减（屏幕空间做不到的真景深线索）
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = p.fog.lerp(p.sky, 0.30)
	environment.fog_density = 0.18 if outdoors else 0.10
	environment.fog_depth_begin = 4.5 if outdoors else 6.0
	environment.fog_depth_end = 13.0 if outdoors else 12.0
	environment.fog_depth_curve = 1.4
	environment.fog_sky_affect = 0.12
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.84
	world.environment = environment
	context["root"].add_child(world)
	var key_light := DirectionalLight3D.new()
	key_light.name = "WarmRakingSun"
	key_light.rotation_degrees = Vector3(-48, -32, 0)
	key_light.light_color = p.light
	key_light.light_energy = 0.50 if variant == "night" else 0.82
	key_light.shadow_enabled = true
	key_light.directional_shadow_max_distance = 30.0
	context["root"].add_child(key_light)
	# 冷侧补光：从窗口方向过来，压住阴面但不留硬影
	var fill_light := DirectionalLight3D.new()
	fill_light.name = "CoolWindowFill"
	fill_light.rotation_degrees = Vector3(-24, 148, 0)
	fill_light.light_color = p.sky.lerp(p.light, 0.18)
	fill_light.light_energy = 0.12 if variant == "night" else 0.16
	fill_light.shadow_enabled = false
	context["root"].add_child(fill_light)
	# 轮廓光：从角色背后打，让人物从背景里「剥」出来
	var rim_light := DirectionalLight3D.new()
	rim_light.name = "WarmRimLight"
	rim_light.rotation_degrees = Vector3(-12, 8, 0)
	rim_light.light_color = p.light
	rim_light.light_energy = 0.42 if variant == "night" else 0.34
	rim_light.shadow_enabled = false
	context["root"].add_child(rim_light)
	var practical := OmniLight3D.new()
	practical.name = "WarmPracticalLight"
	practical.position = Vector3(2.3, 2.4, -1.5) if outdoors else Vector3(2.6, 2.0, -0.8)
	practical.light_color = p.warm
	practical.light_energy = 1.05 if variant == "night" else 0.55
	practical.omni_range = 6.4
	practical.omni_attenuation = 1.7
	practical.shadow_enabled = true
	context["root"].add_child(practical)
	Fx.breathe(practical, 0.07, 2.2)

	# 第二盏实用光：办公室/教室是屏幕冷光，家里是床头暖光，公园是另一盏路灯
	var secondary := OmniLight3D.new()
	secondary.name = "SecondaryPracticalLight"
	var cool: Color = p.sky.lerp(p.light, 0.25)
	match str(context.get("scene", "home")):
		"office", "classroom":
			secondary.position = Vector3(1.55, 1.15, -1.95)
			secondary.light_color = cool
			secondary.light_energy = 0.82 if variant == "night" else 0.52
			secondary.omni_range = 3.4
		"park":
			secondary.position = Vector3(-2.3, 2.35, -1.4)
			secondary.light_color = p.warm
			secondary.light_energy = 1.05 if variant == "night" else 0.45
			secondary.omni_range = 5.6
		_:
			secondary.position = Vector3(-2.45, 1.55, -0.35)
			secondary.light_color = p.warm.lerp(p.light, 0.35)
			secondary.light_energy = 0.92 if variant == "night" else 0.50
			secondary.omni_range = 4.0
	secondary.omni_attenuation = 1.5
	secondary.shadow_enabled = false
	context["root"].add_child(secondary)
	Fx.breathe(secondary, 0.10, 3.1)

	# 地面反弹光：从下方把地板、裙板、裤腿提一点，避免下半身死黑
	var bounce := OmniLight3D.new()
	bounce.name = "FloorBounce"
	bounce.position = Vector3(0.0, 0.28, 0.9)
	bounce.light_color = p.floor.lerp(p.light, 0.42)
	bounce.light_energy = 0.34 if variant == "night" else 0.25
	bounce.omni_range = 4.6
	bounce.omni_attenuation = 1.9
	bounce.shadow_enabled = false
	context["root"].add_child(bounce)


# ==========================================================
# 前景层：贴着镜头的一层剪影，负责「框景」与视差
# 左右两侧各留出角色站位（-1.1 / +1.15），不遮挡人物
# ==========================================================
static func _foreground(context: Dictionary, scene: String) -> void:
	var p: Dictionary = context["colors"]
	if scene == "park":
		# 近景树干 + 草丛：镜头前的遮挡，读起来比远景更「有空气」
		_box(context, "NearTrunk", Vector3(-3.55, 1.15, 2.55), Vector3(0.34, 2.30, 0.34), p.ink.lerp(p.wood, 0.28))
		for index in range(3):
			_box(context, "NearFrond", Vector3(-3.55 + (index - 1) * 0.26, 2.15 + index * 0.10, 2.52),
				Vector3(0.72, 0.26, 0.30), p.leaf.darkened(0.45 + index * 0.05))
		_box(context, "NearRightPost", Vector3(3.62, 0.85, 2.62), Vector3(0.22, 1.70, 0.22), p.ink.lerp(p.wood, 0.2))
		for index in range(6):
			_box(context, "ForeGrass", Vector3(-3.4 + index * 0.34, 0.16, 2.85 + (index % 2) * 0.10),
				Vector3(0.16, 0.34 + (index % 3) * 0.08, 0.14), p.leaf.darkened(0.55))
		for index in range(5):
			_box(context, "ForeGrassRight", Vector3(2.55 + index * 0.28, 0.14, 2.88),
				Vector3(0.15, 0.30 + (index % 2) * 0.10, 0.13), p.leaf.darkened(0.6))
		return
	# 室内：左侧垂下的帘边、右侧吊篮，压住画面四角
	# 前景只留给「家」：办公室/教室/医院里不该出现灌木。
	# 竖直的布幔在这一机位会读成一根柱子，所以用低矮的叶片剪影。
	if scene != "home":
		_box(context, "ForeSillShadow", Vector3(0, 0.06, 2.90), Vector3(9.0, 0.10, 0.30), p.ink)
		return
	for index in range(4):
		_box(context, "ForeLeaf", Vector3(-4.20 + index * 0.30, 0.38 + (index % 2) * 0.16, 3.00),
			Vector3(0.46, 0.34, 0.20), p.leaf.darkened(0.62 - index * 0.03))
	_box(context, "ForeLeafStem", Vector3(-3.90, 0.22, 3.00), Vector3(0.10, 0.44, 0.10), p.ink)
	_box(context, "HangingPot", Vector3(3.86, 2.36, 2.86), Vector3(0.30, 0.22, 0.30), p.accent.darkened(0.55))
	for index in range(4):
		var spread := (index - 1.5) * 0.16
		_box(context, "HangingVine", Vector3(3.86 + spread, 1.99 - index * 0.15, 2.86),
			Vector3(0.11, 0.38, 0.11), p.leaf.darkened(0.55 + index * 0.04))
	_box(context, "ForeSillShadow", Vector3(0, 0.06, 2.90), Vector3(9.0, 0.10, 0.30), p.ink)


# ==========================================================
# 氛围：地面光池 / 窗光柱 / 浮尘 / 墙角压暗
# ==========================================================
static func _radial_texture() -> GradientTexture2D:
	# 加法混合里 alpha 不参与运算：渐变必须做在 RGB 上（白→黑），
	# 否则整块 quad 会被原样加上去 —— 地面上会出现一块纯白方块。
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(0, 0, 0, 1))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.02)
	texture.width = 64
	texture.height = 64
	return texture


static func _linear_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(0, 0, 0, 1))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.width = 8
	texture.height = 64
	return texture


## 柔光材质：径向/线性衰减在着色器里算，不依赖贴图 ——
## 之前用 GradientTexture2D 配加法混合，整块 quad 会被原样加上去，地面出现纯白方块。
const SOFT_LIGHT := preload("res://shaders/soft_light.gdshader")


static func _soft_light_material(color: Color, intensity: float, shape: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SOFT_LIGHT
	material.set_shader_parameter("tint", color)
	material.set_shader_parameter("intensity", intensity)
	material.set_shader_parameter("shape", shape)
	return material


## 躺在地上的柔光圆盘：灯下的「暖光落点」
static func _light_pool(context: Dictionary, center: Vector3, radius: float, color: Color) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(radius * 2.0, radius * 2.0)
	var piece := MeshInstance3D.new()
	piece.name = "FloorLightPool"
	piece.mesh = quad
	piece.material_override = _soft_light_material(color, 0.24, 0)
	piece.rotation_degrees = Vector3(-90, 0, 0)
	piece.position = Vector3(center.x, 0.035, center.z)
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	context["root"].add_child(piece)


## 从窗口斜射下来的光柱
static func _light_shaft(context: Dictionary, from: Vector3, size: Vector2, tilt: float, color: Color) -> void:
	var quad := QuadMesh.new()
	quad.size = size
	var piece := MeshInstance3D.new()
	piece.name = "WindowLightShaft"
	piece.mesh = quad
	piece.material_override = _soft_light_material(color, 0.30, 1)
	piece.rotation_degrees = Vector3(0, 0, tilt)
	piece.position = from
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	context["root"].add_child(piece)


static func _atmosphere(context: Dictionary, variant: String, scene: String) -> void:
	var p: Dictionary = context["colors"]
	var night: bool = variant == "night"
	# 灯下光池：位置与 _lighting 里的实用光对齐
	if scene == "park":
		_light_pool(context, Vector3(2.3, 0, -1.8), 1.20, Color(p.light, 1.0) * (0.09 if not night else 0.20))
		_light_pool(context, Vector3(-1.1, 0, 0.8), 1.05, Color(p.sky, 1.0) * 0.10)
	else:
		var lamp_at := Vector3(2.6, 0, -0.8) if scene not in ["classroom", "hospital"] else Vector3(-2.4, 0, -0.4)
		_light_pool(context, lamp_at, 1.55, Color(p.light, 1.0) * (0.13 if not night else 0.24))
		# 窗口漏进来的冷光，落在地上一小片
		_light_pool(context, Vector3(-2.5, 0, -1.3), 1.20, Color(p.sky, 1.0) * 0.10)
		# 第二盏实用光的地面落点：和 _lighting 里的副灯位置对齐，叠出第二层光
		if scene in ["office", "classroom"]:
			_light_pool(context, Vector3(1.55, 0, -1.55), 0.95, Color(p.light, 1.0) * (0.10 if not night else 0.16))
		else:
			_light_pool(context, Vector3(-2.45, 0, -0.35), 1.15, Color(p.warm, 1.0) * (0.10 if not night else 0.16))
		_light_shaft(context, Vector3(-2.5, 1.35, -1.05), Vector2(1.45, 1.9),
			-16.0 if scene != "classroom" else -20.0, Color(p.light, 1.0) * (0.10 if not night else 0.15))
	# 浮尘：只在有光的地方飘
	if scene == "park":
		# 飘絮 + 少量落叶；夜里换成萤火
		Fx.pollen(context["root"], Vector3(0.4, 0.9, 0.2), Vector3(4.2, 1.1, 2.2), Color(p.light, 0.45), 44)
		Fx.leaves(context["root"], Vector3(0.4, 2.0, 0.4), Vector3(4.0, 0.8, 2.0), p.leaf.lightened(0.22), 9)
		if night:
			Fx.fireflies(context["root"], Vector3(0.6, 0.9, 0.3), Vector3(3.6, 0.8, 2.0),
				Color(1.0, 0.93, 0.62, 0.9), 18)
	else:
		# 窗口附近再补一层更细的尘，让光柱里「有东西在动」
		Fx.dust(context["root"], Vector3(-1.05, 1.15, -1.15), Vector3(1.5, 0.7, 0.9),
			Color(p.light, 0.34), 24)
		# 第二道更淡、角度不同的光柱：两层叠在一起才有体积
		_light_shaft(context, Vector3(-1.72, 1.24, -1.02), Vector2(0.95, 1.72),
			-24.0 if scene != "classroom" else -28.0, Color(p.light, 1.0) * (0.05 if not night else 0.075))
	# 墙角压暗：一条贴着墙根的暗带，让墙与地分开
	_box(context, "CornerShade", Vector3(0, 0.40, -2.69), Vector3(8.7, 0.62, 0.02), p.ink.lerp(p.wall, 0.25))
