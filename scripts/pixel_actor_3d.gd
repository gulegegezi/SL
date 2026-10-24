extends Node3D
## A small articulated voxel actor. The actor's origin is always the floor contact;
## staging owns world movement/facing while pose() only moves this local skeleton.
## Positive Z is the face direction. No billboard, texture atlas or external asset.

var hand_anchor: Node3D
var left_hand_anchor: Node3D
var height: float = 1.82
var character_key: String = "lead_adult"
var is_newborn: bool = false
var expression: String = "normal"
var _root: Node3D
var _hips: Node3D
var _torso: Node3D
var _head: Node3D
var _arms: Array[Node3D] = []
var _elbows: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _knees: Array[Node3D] = []
var _eyes: Array[Node3D] = []
var _brows: Array[Node3D] = []
var _mouth: Node3D
var _hip_y: float = 0.84
var _leg_length: float = 0.72
var _materials: Dictionary = {}
var _is_naiwa: bool = false

func setup(key: String, age: int, palette: Dictionary = {}) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_arms.clear(); _elbows.clear(); _legs.clear(); _knees.clear()
	_eyes.clear(); _brows.clear(); _materials.clear()
	character_key = key
	_is_naiwa = false
	is_newborn = age <= 1 and not key.begins_with("npc_")
	if is_newborn:
		_setup_newborn(palette)
		return
	var stage: String = key.trim_prefix("lead_").trim_prefix("infant_")
	var npc: bool = key.begins_with("npc_")
	var role: String = key.trim_prefix("npc_")
	if npc and role == "naiwa":
		_setup_naiwa(palette)
		return
	if npc:
		stage = "elder" if age >= 65 else "adult"
	elif not stage in ["infant", "child", "teen", "youth", "adult", "middle", "elder"]:
		stage = "infant" if age <= 2 else ("child" if age <= 6 else ("teen" if age <= 12 else ("youth" if age <= 18 else ("adult" if age <= 40 else ("middle" if age <= 60 else "elder")))))
	var child_scale: float = {"infant":0.49, "child":0.63, "teen":0.79, "youth":0.94}.get(stage, 1.0)
	var head_ratio: float = 1.14 if stage in ["infant", "child"] else (1.05 if stage == "teen" else 1.0)
	height = (1.49 + 0.485 * head_ratio) * child_scale
	_root = _joint(self, "VoxelSkeleton", Vector3.ZERO)
	_root.scale = Vector3.ONE * child_scale
	var ink: Color = _color(palette, "ink", Color("233a42"))
	var teal: Color = _color(palette, "teal", _color(palette, "mid", Color("41696b")))
	var amber: Color = _color(palette, "amber", _color(palette, "warm", Color("d4a35f")))
	var rust: Color = _color(palette, "terracotta", _color(palette, "accent", Color("a45e4e")))
	var cream: Color = _color(palette, "cream", _color(palette, "light", Color("e7dcc1")))
	var skin: Color = _color(palette, "skin", Color("d6a884"))
	var coat: Color = amber if stage in ["infant", "child"] else teal
	var hair: Color = ink.darkened(0.25)
	if stage == "elder": hair = Color("a9b5ae")
	if stage == "middle": coat = Color("58716c")
	if npc:
		coat = {"parent":rust, "mate":teal.darkened(0.17), "friend":amber, "teacher":teal.lightened(0.13), "boss":ink, "partner":rust.lightened(0.1)}.get(role, teal)
		if role in ["parent", "partner"]: hair = Color("543e39") if stage != "elder" else Color("b5afa1")
	var trousers: Color = ink.darkened(0.08)
	_hip_y = 0.82
	_leg_length = 0.72
	_hips = _joint(_root, "Hips", Vector3(0, _hip_y, 0))
	_box(_hips, "Waist", Vector3(0.34, 0.19, 0.25), Vector3(0, 0.015, 0), trousers)
	_box(_hips, "Belt", Vector3(0.36, 0.05, 0.27), Vector3(0, 0.10, 0), ink)
	_box(_hips, "Buckle", Vector3(0.055, 0.045, 0.025), Vector3(0, 0.10, 0.15), amber)
	_torso = _joint(_hips, "Spine", Vector3(0, 0.13, 0))
	_box(_torso, "Coat", Vector3(0.45, 0.49, 0.29), Vector3(0, 0.22, 0), coat)
	_box(_torso, "Shirt", Vector3(0.15, 0.42, 0.025), Vector3(0, 0.255, 0.158), cream)
	_box(_torso, "CoatHem", Vector3(0.47, 0.07, 0.31), Vector3(0, 0.005, 0), coat.darkened(0.20))
	for side in [-1.0, 1.0]:
		var lapel: MeshInstance3D = _box(_torso, "Lapel", Vector3(0.07, 0.23, 0.035), Vector3(side * 0.085, 0.34, 0.177), coat.lightened(0.16))
		lapel.rotation.z = side * -0.23
		_box(_torso, "Pocket", Vector3(0.10, 0.055, 0.025), Vector3(side * 0.15, 0.15, 0.17), coat.darkened(0.13))
	_box(_torso, "Neck", Vector3(0.13, 0.11, 0.14), Vector3(0, 0.51, 0), skin.darkened(0.08))
	if npc and role in ["teacher", "boss"]:
		_box(_torso, "Tie", Vector3(0.046, 0.28, 0.025), Vector3(0, 0.30, 0.18), rust)
	elif stage in ["child", "teen", "youth"]:
		_box(_torso, "Scarf", Vector3(0.29, 0.075, 0.33), Vector3(0, 0.44, 0), rust)
		_box(_torso, "ScarfTail", Vector3(0.07, 0.17, 0.035), Vector3(0.07, 0.32, 0.19), rust.lightened(0.12))
	_build_head(stage, role, npc, skin, hair, ink, cream)
	for i in range(2):
		var side: float = -1.0 if i == 0 else 1.0
		var arm: Node3D = _joint(_torso, "LeftShoulder" if i == 0 else "RightShoulder", Vector3(side * 0.285, 0.40, 0))
		_arms.append(arm)
		_box(arm, "UpperSleeve", Vector3(0.16, 0.29, 0.20), Vector3(0, -0.12, 0), coat)
		var elbow: Node3D = _joint(arm, "Elbow", Vector3(0, -0.26, 0))
		_elbows.append(elbow)
		_box(elbow, "LowerSleeve", Vector3(0.14, 0.23, 0.17), Vector3(0, -0.105, 0), coat.darkened(0.09))
		_box(elbow, "Cuff", Vector3(0.15, 0.045, 0.18), Vector3(0, -0.22, 0), cream)
		_box(elbow, "Hand", Vector3(0.125, 0.12, 0.14), Vector3(0, -0.28, 0.01), skin)
		var anchor: Node3D = _joint(elbow, "Grip", Vector3(0, -0.29, 0.08))
		if i == 1: hand_anchor = anchor
		else: left_hand_anchor = anchor
		var leg: Node3D = _joint(_hips, "LeftHip" if i == 0 else "RightHip", Vector3(side * 0.115, -0.045, 0))
		_legs.append(leg)
		_box(leg, "Thigh", Vector3(0.17, 0.34, 0.22), Vector3(0, -0.17, 0), trousers)
		var knee: Node3D = _joint(leg, "Knee", Vector3(0, -0.34, 0))
		_knees.append(knee)
		_box(knee, "Shin", Vector3(0.145, 0.32, 0.19), Vector3(0, -0.15, 0), trousers.lightened(0.06))
		_box(knee, "Sock", Vector3(0.15, 0.06, 0.20), Vector3(0, -0.30, 0), cream.darkened(0.17))
		_box(knee, "Shoe", Vector3(0.19, 0.105, 0.33), Vector3(0, -0.375, 0.055), ink.darkened(0.34))
		_box(knee, "Sole", Vector3(0.195, 0.03, 0.335), Vector3(0, -0.415, 0.055), ink.darkened(0.51))
	pose("idle", 0)

func _setup_naiwa(palette: Dictionary) -> void:
	# 奶蛙：圆胖的黄青蛙，蹲坐在地，不是人形骨架。
	# 仍保留四肢/眼/眉关节，让 pose() 的通用动画（眨眼、摆手、坐下）照常工作。
	_is_naiwa = true
	var ink: Color = _color(palette, "ink", Color("233a42"))
	var yellow := Color("e6c34a")
	var yellow_dark := yellow.darkened(0.14)
	var belly := Color("f6e7ae")
	var cheek := Color("e2a06b")
	height = 0.92
	_hip_y = 0.30
	_leg_length = 0.20
	_root = _joint(self, "VoxelFrog", Vector3.ZERO)
	_hips = _joint(_root, "Hips", Vector3(0, _hip_y, 0))
	_box(_hips, "LowerBody", Vector3(0.62, 0.36, 0.52), Vector3(0, 0.02, 0), yellow)
	_box(_hips, "BellyPatch", Vector3(0.42, 0.26, 0.05), Vector3(0, 0.0, 0.27), belly)
	_torso = _joint(_hips, "Spine", Vector3(0, 0.19, 0))
	_box(_torso, "UpperBody", Vector3(0.54, 0.30, 0.48), Vector3(0, 0.08, 0), yellow)
	_box(_torso, "BackStripe", Vector3(0.30, 0.10, 0.06), Vector3(0, 0.10, -0.24), yellow_dark)
	_head = _joint(_torso, "Head", Vector3(0, 0.22, 0))
	for i in range(2):
		var side: float = -1.0 if i == 0 else 1.0
		var eye: Node3D = _joint(_head, "Eye", Vector3(side * 0.16, 0.10, 0.02))
		_eyes.append(eye)
		_box(eye, "EyeBump", Vector3(0.17, 0.15, 0.17), Vector3.ZERO, yellow)
		_box(eye, "Sclera", Vector3(0.105, 0.10, 0.05), Vector3(0, 0.01, 0.085), Color("f7f2df"))
		_box(eye, "Pupil", Vector3(0.045, 0.062, 0.03), Vector3(0, 0.005, 0.115), ink.darkened(0.2))
		_box(eye, "Glint", Vector3(0.016, 0.018, 0.012), Vector3(-0.02, 0.03, 0.128), Color("ffffff"))
		var brow: Node3D = _joint(_head, "Brow", Vector3(side * 0.16, 0.185, 0.06))
		_brows.append(brow)
		_box(brow, "Eyebrow", Vector3(0.10, 0.018, 0.02), Vector3.ZERO, yellow_dark)
		_box(_head, "Cheek", Vector3(0.075, 0.045, 0.02), Vector3(side * 0.22, -0.015, 0.235), cheek)
	_mouth = _box(_head, "Smile", Vector3(0.24, 0.030, 0.02), Vector3(0, -0.03, 0.245), Color("7a5148"))
	# 两只前鳍小手
	for i in range(2):
		var side: float = -1.0 if i == 0 else 1.0
		var arm: Node3D = _joint(_torso, "LeftFlipper" if i == 0 else "RightFlipper", Vector3(side * 0.30, 0.02, 0.08))
		_arms.append(arm)
		_box(arm, "Flipper", Vector3(0.11, 0.24, 0.13), Vector3(0, -0.09, 0.02), yellow)
		_box(arm, "FlipperTip", Vector3(0.13, 0.07, 0.15), Vector3(0, -0.21, 0.04), yellow_dark)
		var elbow: Node3D = _joint(arm, "Elbow", Vector3(0, -0.14, 0.02))
		_elbows.append(elbow)
	# 两只贴地后脚
	for i in range(2):
		var side: float = -1.0 if i == 0 else 1.0
		var leg: Node3D = _joint(_hips, "LeftFoot" if i == 0 else "RightFoot", Vector3(side * 0.24, -0.10, 0.10))
		_legs.append(leg)
		var knee: Node3D = _joint(leg, "Knee", Vector3(0, -0.06, 0.08))
		_knees.append(knee)
		_box(knee, "Foot", Vector3(0.15, 0.09, 0.32), Vector3(0, -0.11, 0.10), yellow_dark)
	pose("idle", 0)

func _setup_newborn(palette: Dictionary) -> void:
	# Mattress contact is y=0. The head lies toward -Z; the face looks up +Y.
	# A newborn is not a scaled standing adult, even when the story says "walk".
	height = 0.36
	var skin: Color = _color(palette, "skin", Color("dbb08e"))
	var cream: Color = _color(palette, "cream", _color(palette, "light", Color("e7dcc1")))
	var teal: Color = _color(palette, "teal", _color(palette, "mid", Color("41696b")))
	var ink: Color = _color(palette, "ink", Color("233a42"))
	_root = _joint(self, "NewbornSkeleton", Vector3.ZERO)
	_hips = _joint(_root, "RestingBody", Vector3.ZERO)
	_torso = _joint(_hips, "BreathingBlanket", Vector3.ZERO)
	_box(_torso, "SwaddleBase", Vector3(0.33, 0.12, 0.57), Vector3(0, 0.06, 0.055), teal)
	_box(_torso, "SwaddleFold", Vector3(0.29, 0.12, 0.42), Vector3(0, 0.155, 0.10), cream)
	_box(_torso, "SwaddleWrap", Vector3(0.30, 0.035, 0.11), Vector3(0, 0.22, 0.12), cream.darkened(0.13))
	_box(_torso, "BlanketEdge", Vector3(0.34, 0.035, 0.075), Vector3(0, 0.12, 0.29), teal.lightened(0.20))
	_head = _joint(_torso, "NewbornHead", Vector3(0, 0.21, -0.265))
	_head.rotation.x = -PI * 0.5
	_box(_head, "RoundFace", Vector3(0.255, 0.23, 0.21), Vector3.ZERO, skin)
	_box(_head, "BabyCheeks", Vector3(0.285, 0.10, 0.215), Vector3(0, -0.035, 0), skin.lightened(0.035))
	_box(_head, "SoftHair", Vector3(0.14, 0.03, 0.14), Vector3(-0.015, 0.13, -0.025), ink.darkened(0.20))
	for i in range(2):
		var side: float = -1.0 if i == 0 else 1.0
		_box(_head, "Ear", Vector3(0.035, 0.055, 0.04), Vector3(side * 0.145, 0, 0), skin)
		var eye: Node3D = _joint(_head, "Eye", Vector3(side * 0.058, 0.026, 0.11))
		_eyes.append(eye)
		_box(eye, "BabyEye", Vector3(0.035, 0.025, 0.01), Vector3.ZERO, ink)
		var brow: Node3D = _joint(_head, "Brow", Vector3(side * 0.058, 0.06, 0.11))
		_brows.append(brow)
		_box(brow, "BabyBrow", Vector3(0.04, 0.009, 0.01), Vector3.ZERO, skin.darkened(0.28))
		var arm: Node3D = _joint(_torso, "BabyArm", Vector3(side * 0.125, 0.14, -0.105))
		_arms.append(arm)
		_box(arm, "Sleeve", Vector3(0.075, 0.10, 0.08), Vector3(0, -0.045, 0), cream)
		var elbow: Node3D = _joint(arm, "BabyElbow", Vector3(0, -0.085, 0))
		_elbows.append(elbow)
		_box(elbow, "SmallForearm", Vector3(0.065, 0.07, 0.065), Vector3(0, -0.035, 0), skin)
		_box(elbow, "SmallHand", Vector3(0.07, 0.06, 0.065), Vector3(0, -0.09, 0), skin.lightened(0.035))
		var anchor: Node3D = _joint(elbow, "Grip", Vector3(0, -0.105, 0.02))
		if i == 1: hand_anchor = anchor
		else: left_hand_anchor = anchor
		var leg: Node3D = _joint(_hips, "BabyLeg", Vector3(side * 0.075, 0.08, 0.15))
		_legs.append(leg)
		var knee: Node3D = _joint(leg, "BabyKnee", Vector3(0, -0.06, 0))
		_knees.append(knee)
		_box(knee, "Sock", Vector3(0.07, 0.08, 0.07), Vector3(0, -0.07, 0), cream)
	_box(_head, "SmallNose", Vector3(0.025, 0.022, 0.025), Vector3(0, -0.008, 0.12), skin.lightened(0.06))
	_mouth = _box(_head, "Mouth", Vector3(0.034, 0.012, 0.01), Vector3(0, -0.06, 0.113), Color("9e645c"))
	pose("sleep", 0)

func _pose_newborn(action: String, time: float, speaking: bool, reduced_motion: bool) -> void:
	var motion: float = 0.0 if reduced_motion else 1.0
	var wave: float = sin(time * 2.1) * motion
	_torso.scale.y = 1.0 + wave * 0.012
	_head.rotation = Vector3(-PI * 0.5 + sin(time * 1.3) * 0.015 * motion, 0, 0)
	var reaching: bool = action in ["reach", "raise", "take", "receive", "offer"]
	for i in range(2):
		var side: float = -1.0 if i == 0 else 1.0
		var kick: float = sin(time * 2.0 + float(i) * 1.4) * motion
		_arms[i].rotation = Vector3(-PI * 0.5 + (0.32 if reaching else 0.0) + wave * 0.04, 0, side * (0.38 + kick * 0.08))
		_elbows[i].rotation.x = -0.25 + kick * 0.10
		_legs[i].rotation.x = -PI * 0.5 + kick * 0.09
		_knees[i].rotation.x = 0.12 + maxf(0.0, kick) * 0.10
		_eyes[i].scale.y = 0.15 if action == "sleep" or fmod(time, 4.5) > 4.3 else 1.0
		_brows[i].rotation.z = side * -0.12 if expression in ["cry", "sad", "hurt"] else 0.0
	_mouth.scale.y = 1.0 + absf(sin(time * 5.0)) * 1.2 * motion if speaking else 1.0

func _build_head(stage: String, role: String, npc: bool, skin: Color, hair: Color, ink: Color, cream: Color) -> void:
	_head = _joint(_torso, "Head", Vector3(0, 0.54, 0))
	var big_head: float = 1.14 if stage in ["infant", "child"] else (1.05 if stage == "teen" else 1.0)
	_head.scale = Vector3.ONE * big_head
	_box(_head, "Face", Vector3(0.37, 0.35, 0.31), Vector3(0, 0.17, 0), skin)
	_box(_head, "Jaw", Vector3(0.29, 0.10, 0.28), Vector3(0, 0.015, 0.01), skin.darkened(0.035))
	_box(_head, "HairBack", Vector3(0.42, 0.35, 0.13), Vector3(0, 0.23, -0.14), hair)
	_box(_head, "HairCrown", Vector3(0.42, 0.11, 0.35), Vector3(0, 0.385, -0.015), hair)
	_box(_head, "HairTop", Vector3(0.29, 0.05, 0.28), Vector3(-0.035, 0.46, -0.02), hair.lightened(0.06))
	# Stepped asymmetric locks provide a pixel silhouette rather than a single cube.
	for i in range(5):
		var x: float = -0.16 + float(i) * 0.075
		var length: float = [0.12, 0.15, 0.10, 0.07, 0.11][i]
		_box(_head, "Fringe", Vector3(0.075, length, 0.07), Vector3(x, 0.35 - length * 0.4, 0.17), hair.lightened(float(i % 2) * 0.045))
	if npc and role in ["parent", "partner"]:
		_box(_head, "HairTail", Vector3(0.17, 0.23, 0.16), Vector3(0.15, 0.12, -0.20), hair)
	for i in range(2):
		var side: float = -1.0 if i == 0 else 1.0
		_box(_head, "Ear", Vector3(0.055, 0.09, 0.08), Vector3(side * 0.205, 0.16, 0.015), skin.darkened(0.05))
		var eye: Node3D = _joint(_head, "Eye", Vector3(side * 0.083, 0.20, 0.161))
		_eyes.append(eye)
		_box(eye, "Sclera", Vector3(0.070, 0.055, 0.018), Vector3.ZERO, cream.lightened(0.08))
		_box(eye, "Pupil", Vector3(0.029, 0.048, 0.015), Vector3(-side * 0.008, 0, 0.013), ink.darkened(0.22))
		_box(eye, "Glint", Vector3(0.012, 0.013, 0.01), Vector3(-side * 0.014, 0.012, 0.024), cream)
		var brow: Node3D = _joint(_head, "Brow", Vector3(side * 0.083, 0.25, 0.17))
		_brows.append(brow)
		_box(brow, "Eyebrow", Vector3(0.078, 0.016, 0.018), Vector3.ZERO, hair)
		if npc and role in ["teacher", "boss"] or stage == "elder":
			_box(_head, "GlassesTop", Vector3(0.10, 0.012, 0.018), Vector3(side * 0.083, 0.235, 0.191), ink)
			_box(_head, "GlassesBottom", Vector3(0.10, 0.012, 0.018), Vector3(side * 0.083, 0.161, 0.191), ink)
			_box(_head, "GlassesOuter", Vector3(0.012, 0.08, 0.018), Vector3(side * 0.132, 0.20, 0.191), ink)
	_box(_head, "Nose", Vector3(0.045, 0.05, 0.048), Vector3(0, 0.145, 0.18), skin.lightened(0.055))
	_mouth = _box(_head, "Mouth", Vector3(0.060, 0.015, 0.018), Vector3(0, 0.075, 0.165), Color("744b46"))
	if stage in ["middle", "elder"]:
		_box(_head, "CheekLine", Vector3(0.065, 0.012, 0.012), Vector3(0.12, 0.13, 0.165), skin.darkened(0.17))

func set_expression(value: String) -> void:
	expression = value

func pose(action: String, time: float, speaking: bool = false, reduced_motion: bool = false) -> void:
	if not is_instance_valid(_root): return
	if is_newborn:
		_pose_newborn(action, maxf(time, 0.0), speaking, reduced_motion)
		return
	var t: float = maxf(time, 0.0)
	var motion: float = 0.0 if reduced_motion else 1.0
	var onset: float = smoothstep(0.0, 0.35, t) if not reduced_motion else 1.0
	var pulse: float = sin(t * 3.0) * motion
	_root.position = Vector3.ZERO
	_root.rotation = Vector3.ZERO
	_hips.position.y = _hip_y
	_hips.rotation = Vector3.ZERO
	_torso.rotation = Vector3(0.012 * pulse, 0, 0)
	_head.rotation = Vector3(0, sin(t * 1.1) * 0.025 * motion, 0)
	for i in range(2):
		_arms[i].rotation = Vector3(0, 0, (-1.0 if i == 0 else 1.0) * 0.065)
		_elbows[i].rotation = Vector3(-0.08, 0, 0)
		_legs[i].rotation = Vector3.ZERO
		_knees[i].rotation = Vector3.ZERO
	match action:
		"walk", "run", "approach", "leave":
			var cycle: float = t * (11.0 if action == "run" else 7.5)
			var stride: float = sin(cycle) * 0.36 * motion * onset
			for i in range(2):
				var sign_side: float = 1.0 if i == 0 else -1.0
				_legs[i].rotation.x = stride * sign_side
				_knees[i].rotation.x = maxf(0.0, -sin(cycle + float(i) * PI)) * 0.37 * motion * onset
				_arms[i].rotation.x = -stride * sign_side * 0.8
			_hips.position.y += absf(sin(cycle)) * 0.022 * motion
			_torso.rotation.z = sin(cycle) * 0.025 * motion
		"give", "offer", "reach", "raise", "receive", "take", "hand_over":
			var extension: float = onset
			_arms[1].rotation = Vector3(-0.85 * extension, 0.05, -0.12 * extension)
			_elbows[1].rotation.x = -0.35 - 0.25 * extension
			_torso.rotation.x = 0.06 * extension
			if action in ["receive", "take"]:
				_arms[0].rotation = Vector3(-0.65 * extension, 0, 0.16)
				_elbows[0].rotation.x = -0.55 * extension
		"read", "book", "inspect":
			_arms[0].rotation.x = -0.42 * onset
			_arms[1].rotation.x = -0.42 * onset
			_elbows[0].rotation.x = -1.05 * onset
			_elbows[1].rotation.x = -1.05 * onset
			_head.rotation.x = 0.19 * onset
		"phone":
			_arms[1].rotation = Vector3(-0.32 * onset, 0, 0.4 * onset)
			_elbows[1].rotation.x = -2.35 * onset
			_head.rotation.z = -0.08 * onset
		"wave", "celebrate":
			_arms[1].rotation = Vector3(-0.25, 0, 2.3 * onset + sin(t * 6.0) * 0.2 * motion)
			_elbows[1].rotation.x = -0.55 * onset
			if action == "celebrate":
				_arms[0].rotation.z = -2.3 * onset
				_root.position.y = maxf(0.0, sin(t * 5.0)) * 0.075 * motion
		"drum", "type", "sign", "draw", "work":
			for i in range(2):
				var tap: float = sin(t * (10.0 if action == "drum" else 7.0) + float(i) * PI) * motion
				_arms[i].rotation.x = -0.64 * onset
				_elbows[i].rotation.x = (-0.60 + tap * (0.43 if action == "drum" else 0.10)) * onset
			_head.rotation.x = 0.14 * onset
		"sit", "rest", "sleep":
			_hips.position.y -= (0.06 if _is_naiwa else 0.27) * onset
			for i in range(2):
				if not _is_naiwa:
					_legs[i].rotation.x = -1.25 * onset
					_knees[i].rotation.x = 1.25 * onset
				_arms[i].rotation.x = -0.24 * onset
				_elbows[i].rotation.x = -0.65 * onset
			if action == "sleep": _head.rotation.x = 0.38 * onset
		"nod":
			_head.rotation.x = maxf(0.0, sin(t * 5.0)) * 0.22 * motion
		"put_down", "poweroff":
			_arms[1].rotation.x = -0.55 * onset
			_elbows[1].rotation.x = -0.35 * onset
			_torso.rotation.x = 0.15 * onset
		"eat":
			_arms[1].rotation.x = -0.55 * onset
			_elbows[1].rotation.x = (-1.9 + sin(t * 2.2) * 0.35 * motion) * onset
		"talk", "chat", "inquire", "persuade":
			_arms[1].rotation.x = (-0.25 - 0.12 * pulse) * onset
			_elbows[1].rotation.x = (-0.9 + 0.16 * pulse) * onset
			_head.rotation.z = 0.035 * pulse
		"sad", "cry", "hurt":
			_torso.rotation.x = 0.13 * onset
			_head.rotation.x = 0.21 * onset
		"shock", "scared":
			_torso.rotation.x = -0.11 * onset
			_arms[0].rotation.z = -0.25 * onset
			_arms[1].rotation.z = 0.25 * onset
	# Speech and facial acting stay distinct from the body action.
	var blink: bool = fmod(t + 0.41, 4.7) > 4.54 and not reduced_motion
	for eye in _eyes:
		eye.scale.y = 0.12 if blink or action == "sleep" else 1.0
		if expression in ["shock", "panic", "scared"]: eye.scale.y = 1.2
	for i in range(_brows.size()):
		var side: float = -1.0 if i == 0 else 1.0
		_brows[i].rotation.z = 0.0
		if expression in ["angry", "rage", "determined"]: _brows[i].rotation.z = side * 0.23
		if expression in ["sad", "hurt", "cry", "scared"]: _brows[i].rotation.z = side * -0.20
	_mouth.scale.y = 1.0 + (absf(sin(t * 11.0)) * 2.5 if speaking and not reduced_motion else 0.0)
	_mouth.scale.x = 1.25 if expression in ["happy", "love", "smug"] else 1.0
	if speaking: _head.rotation.x += sin(t * 3.5) * 0.025 * motion
	if action in ["walk", "run", "approach", "leave"]:
		# Correct only the local hips: the supporting shoe remains on the floor
		# while staging advances the actor. No world-space position is overwritten.
		var lowest: float = INF
		for i in range(2):
			for toe in [-0.1125, 0.2225]:
				var sole: Vector3 = _legs[i].transform * (_knees[i].transform * Vector3(0, -0.43, toe))
				lowest = minf(lowest, _hips.position.y + sole.y)
		_hips.position.y -= lowest

func _joint(parent: Node3D, label: String, at: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = label
	parent.add_child(node)
	node.position = at
	return node

func _box(parent: Node3D, label: String, dimensions: Vector3, at: Vector3, tint: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	node.mesh = mesh
	var color_key: String = tint.to_html()
	if not _materials.has(color_key):
		var material := StandardMaterial3D.new()
		material.albedo_color = tint
		material.roughness = 0.94
		material.metallic_specular = 0.15
		_materials[color_key] = material
	node.material_override = _materials[color_key]
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(node)
	node.position = at
	return node

func _color(palette: Dictionary, key: String, fallback: Color) -> Color:
	var value: Variant = palette.get(key, fallback)
	return value if value is Color else Color.from_string(str(value), fallback)
