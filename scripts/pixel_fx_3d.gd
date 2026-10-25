extends RefCounted
## pixel_fx_3d.gd — 光影叠加与粒子：把「灯下浮尘、窗外飞虫、光柱、接地影」这些
## 让画面有空气的东西集中在一处，环境与舞台都从这里取。
##
## 全部用程序化几何 + CPUParticles3D，不依赖贴图；GL Compatibility 也能跑。

static func _billboard_material(color: Color, additive: bool = true) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if additive:
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return material


static func _quad(size: Vector2, material: Material) -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = size
	mesh.material = material
	return mesh


## 灯下浮尘：慢速漂移的暖色小点，只在光柱附近生成
static func dust(parent: Node3D, center: Vector3, extents: Vector3, color: Color, amount: int = 34) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "LightDust"
	p.amount = amount
	p.lifetime = 9.0
	p.preprocess = 4.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.position = center
	p.direction = Vector3(0, 1, 0)
	p.spread = 60.0
	p.initial_velocity_min = 0.010
	p.initial_velocity_max = 0.045
	p.gravity = Vector3(0, 0.004, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.8
	p.mesh = _quad(Vector2(0.018, 0.018), _billboard_material(color, true))
	parent.add_child(p)
	return p


## 公园飘絮：向上缓慢飘的暖白点，白天用
static func pollen(parent: Node3D, center: Vector3, extents: Vector3, color: Color, amount: int = 40) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Pollen"
	p.amount = amount
	p.lifetime = 10.0
	p.preprocess = 5.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.position = center
	p.direction = Vector3(0.2, 1, 0)
	p.spread = 35.0
	p.initial_velocity_min = 0.03
	p.initial_velocity_max = 0.10
	p.gravity = Vector3(0.01, 0.02, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	p.mesh = _quad(Vector2(0.022, 0.022), _billboard_material(color, true))
	parent.add_child(p)
	return p


## 落叶：少量、向下、可旋转的方块，给公园一点“季节”
static func leaves(parent: Node3D, center: Vector3, extents: Vector3, color: Color, amount: int = 10) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "FallingLeaves"
	p.amount = amount
	p.lifetime = 11.0
	p.preprocess = 6.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.position = center
	p.direction = Vector3(0.3, -1, 0)
	p.spread = 25.0
	p.initial_velocity_min = 0.06
	p.initial_velocity_max = 0.16
	p.gravity = Vector3(0.02, -0.05, 0)
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.6
	p.angular_velocity_min = -60.0
	p.angular_velocity_max = 60.0
	var material := _billboard_material(color, false)
	p.mesh = _quad(Vector2(0.05, 0.035), material)
	parent.add_child(p)
	return p


## 夜里的萤火/飞虫：极小、缓慢、闪烁（用亮度曲线近似）
static func fireflies(parent: Node3D, center: Vector3, extents: Vector3, color: Color, amount: int = 16) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Fireflies"
	p.amount = amount
	p.lifetime = 6.0
	p.preprocess = 4.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.position = center
	p.direction = Vector3(0, 1, 0)
	p.spread = 180.0
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.14
	p.gravity = Vector3(0, 0.01, 0)
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.6
	var material := _billboard_material(color, true)
	p.mesh = _quad(Vector2(0.02, 0.02), material)
	parent.add_child(p)
	return p


## 接地影：脚下一片压暗的方片，让人物从地板上「坐实」
static func contact_shadow(parent: Node3D, position: Vector3, size: Vector2, alpha: float = 0.34) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.05, 0.09, 0.10, alpha)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = material
	var node := MeshInstance3D.new()
	node.name = "ContactShadow"
	node.mesh = mesh
	node.position = position
	node.rotation_degrees = Vector3(-90, 0, 0)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


## 灯光呼吸：让实用光有一点不稳定的生命，不是死亮
static func breathe(light: Light3D, depth: float = 0.06, speed: float = 2.6) -> void:
	light.set_meta("base_energy", light.light_energy)
	light.set_meta("breath_depth", depth)
	light.set_meta("breath_speed", speed)
	light.set_script(load("res://scripts/pixel_light_breath.gd"))
