extends Node3D
## Flat painted actors staged in a lit 3D world. No voxel body geometry.
const Art := preload("res://scripts/comic_art.gd")
const Fx := preload("res://scripts/pixel_fx_3d.gd")
const ActionModule := preload("res://scripts/pixel_action_module.gd")
var hand_anchor: Node3D
var left_hand_anchor: Node3D
var sprite: Sprite3D
var height := 1.8
var is_newborn := false
var character_key := "lead_adult"
var expression := "normal"
var action := "idle"
var _time := 0.0
var _reduced := false
var _frame := 0
var _width := 0.7
var _bob := 0.0
var _lean := 0.0
var _drop := 0.0
var _flip := false

func setup(key: String, age: int, _palette: Dictionary = {}) -> void:
	character_key = key
	is_newborn = age <= 1 and not key.begins_with("npc_")
	height = 0.48 if is_newborn else (1.12 if age <= 6 else (1.45 if age <= 12 else 1.8))
	if key.begins_with("npc_"): height = 1.75
	if key == "npc_naiwa": height = 0.95
	sprite = Sprite3D.new()
	sprite.name = "PaintedPixelCharacter"
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = true
	sprite.double_sided = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.5
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(sprite)
	hand_anchor = Node3D.new(); hand_anchor.name = "RightGrip"; add_child(hand_anchor)
	left_hand_anchor = Node3D.new(); left_hand_anchor.name = "LeftGrip"; add_child(left_hand_anchor)
	# 接地影：脚下一片压暗，人物才像站在地板上而不是浮着
	var shadow := Fx.contact_shadow(self, Vector3(0.0, 0.02, 0.03),
		Vector2(0.46, 0.33) * (height / 1.8), 0.34)
	shadow.name = "FeetContactShadow"
	pose("idle",0)

func set_expression(value: String) -> void:
	expression = value

func pose(value: String, time: float, speaking: bool = false, reduced_motion: bool = false, speed_ratio: float = 1.0) -> void:
	action = value; _time = time; _reduced = reduced_motion
	_frame = 0
	var texture: Texture2D
	if character_key == "npc_naiwa":
		texture = load("res://assets/chars/npc_naiwa_idle_0_normal.png")
	elif is_newborn:
		texture = Art.portrait("infant_infant",0)
	elif action == "walk":
		texture = Art.walk_frame(character_key,0 if reduced_motion else int(time*8)%4)
	if texture == null:
		if action in ["offer","receive","raise","read","phone","draw","drum"] and time > 0.25: _frame = 2
		elif action in ["wave","celebrate"]: _frame = 3
		elif action == "walk" or speaking: _frame = 1 if reduced_motion else int(time*5)%2
		elif expression in ["happy","love","smug"]: _frame = 3
		texture = Art.ensemble_frame(character_key,_frame)
	if texture == null: texture = Art.portrait(character_key,0)
	if texture == null: texture = Art.ensemble_frame("lead_adult",0)
	sprite.texture = texture
	sprite.pixel_size = height/float(texture.get_height())
	_width = texture.get_width()*sprite.pixel_size
	# 动作模组：起伏 / 前倾 / 下沉由统一参数决定，帧只管换图
	var mv := ActionModule.sample(action, time, speed_ratio, reduced_motion or is_newborn)
	_bob = float(mv["bob"])
	_lean = deg_to_rad(float(mv["lean"]))
	_drop = float(mv["drop"])

func face_camera(camera: Camera3D, flip: bool) -> void:
	_flip = flip
	sprite.flip_h = flip
	# Feet stay on the stage; the artwork plane stays parallel to the camera.
	# Move the plane's centre along camera-up, not world-up, to avoid floating feet.
	sprite.global_basis = camera.global_basis
	if absf(_lean) > 0.0001:
		# 前倾：绕视线轴转一点点，读起来是「身体在动」而不是平移
		sprite.global_basis = sprite.global_basis.rotated(sprite.global_basis.z, _lean)
	sprite.global_position = global_position+camera.global_basis.y*(height*0.5+_bob-_drop)
	var reach := 0.36 if _frame == 2 else 0.10
	var sign_x := -1.0 if flip else 1.0
	var grip := Vector3(sign_x*_width*reach,height*(0.58 if _frame == 2 else 0.42)+_bob,0.025)
	if is_newborn: grip = Vector3(sign_x*0.10,0.18,0.02)
	hand_anchor.global_position = global_position+camera.global_basis*grip
	left_hand_anchor.global_position = global_position+camera.global_basis*Vector3(-sign_x*_width*.14,height*.43+_bob,.025)
