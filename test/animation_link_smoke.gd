extends SceneTree
## 剧情 × 动画数据联动：过场里的每个 action/expr 都能在 data/frames.json 与 assets/chars 中找到。
const Data := preload("res://scripts/data_loader.gd")
const SpriteKit := preload("res://scripts/sprite_kit.gd")
const PixelCast := preload("res://scripts/pixel_cast.gd")

func _initialize() -> void:
	call_deferred("run")

func _age_for(eid: String) -> int:
	match eid:
		"OP01": return 1
		"V03": return 30
		"V13": return 40
		_: return 30

func _key(role: String, age: int) -> String:
	if role == "lead":
		return SpriteKit.key_for(SpriteKit.stage_for_age(age), false)
	return SpriteKit.key_for(role, true)

func _idle_faces(key: String) -> Array:
	var actions: Dictionary = SpriteKit.frames_data().get("actions", {}).get(key, {})
	return actions.get("idle", {}).get("faces", [])

func run() -> void:
	Data.ensure_loaded()
	var frames := SpriteKit.frames_data()
	assert(not frames.is_empty(), "frames.json should load")
	assert(int(frames.get("char_canvas", [0, 0])[0]) == 24)
	assert(float(frames.get("fps", {}).get("walk", 0)) == 9.0)

	var cutscenes := Data.cutscene_map()
	assert(cutscenes.size() >= 3)
	var seen_actions := {}
	var seen_faces := {}
	for eid in cutscenes:
		var cut: Dictionary = cutscenes[eid]
		var age := _age_for(str(eid))
		assert(SpriteKit.scene(str(cut.get("bg", "home"))) != null, "missing bg for " + str(eid))
		var cast: Array = cut.get("cast", [])
		var by_role := {}
		for c in cast:
			var role := str(c.get("role", "lead"))
			by_role[role] = c
			var key := _key(role, age)
			assert(SpriteKit.frames_data().get("actions", {}).has(key), "no frame data for " + key)
			var act := str(c.get("action", "idle"))
			assert(SpriteKit.action_count(key, act) > 0, "%s cast action missing %s/%s" % [eid, key, act])
			seen_actions[act] = true
			var face := SpriteKit.norm_face(str(c.get("face", "normal")))
			assert(_idle_faces(key).has(face) or face == "normal", "%s cast face missing %s/%s" % [eid, key, face])

		for b in cut.get("beats", []):
			var face_role := str(b.get("face", "lead"))
			var expr := SpriteKit.norm_face(str(b.get("expr", "normal")))
			seen_faces[expr] = true
			var face_key := _key(face_role, age)
			var faces := _idle_faces(face_key)
			assert(faces.has(expr) or expr == "normal", "%s beat face missing %s/%s" % [eid, face_key, expr])

			if b.has("action"):
				var target := str(b.get("target", face_role))
				var target_key := _key(target, age)
				var action := str(b["action"])
				assert(SpriteKit.action_count(target_key, action) > 0,
					"%s beat action missing %s/%s" % [eid, target_key, action])
				seen_actions[action] = true
			if b.has("target"):
				assert(by_role.has(str(b["target"])), "%s beat target not in cast: %s" % [eid, str(b["target"])])

	# 至少接入了两种真正的动作，而不是只有 idle。
	assert(seen_actions.has("wave"), "should use wave action")
	assert(seen_actions.has("raise"), "should use raise action")
	assert(seen_faces.has("surprise"), "should use surprise expression")
	assert(seen_faces.has("blink"), "should use blink expression")

	# 贴图确实能取到：全身体帧 + 头部立绘裁切。
	assert(SpriteKit.action_frame("lead_adult", "idle", 0, "happy") != null)
	assert(SpriteKit.action_frame("lead_adult", "walk", 1, "normal") != null)
	assert(SpriteKit.action_frame("npc_friend", "wave", 2, "normal") != null)
	assert(SpriteKit.frame_portrait("lead_adult", "shy") != null)
	assert(SpriteKit.frame_portrait("lead_adult", "blink") != null)
	assert(SpriteKit.frame_portrait("npc_friend", "normal") != null)

	print("PASS: story cutscene actions/faces resolve against frames.json and assets/chars")
	quit()
