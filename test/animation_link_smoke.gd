extends SceneTree
## 剧情 × 最新 SL 库角色技术：过场里的 cast/action/expr 必须能落到 pixel_cast.gd 的图集上。
const Data := preload("res://scripts/data_loader.gd")
const PixelCast := preload("res://scripts/pixel_cast.gd")
const SpriteKit := preload("res://scripts/sprite_kit.gd")

const ACTIONS := ["idle", "walk", "wave", "raise", "sit"]
const EXPRESSIONS := ["normal", "happy", "sad", "angry", "surprise", "scared", "determined", "shy", "hurt", "blink"]

func _initialize() -> void:
	call_deferred("run")

func _age_for(eid: String) -> int:
	match eid:
		"OP01": return 1
		"V03": return 30
		"V13": return 40
		_: return 30

func _stage_key(eid: String) -> String:
	return PixelCast.stage_for_age(_age_for(eid))

func _npc_key(role: String, eid: String) -> String:
	# V13 的父亲在渲染层复用年长男性 mate 外形。
	if role == "parent" and eid == "V13":
		return "mate"
	return role

func run() -> void:
	Data.ensure_loaded()

	# 最新角色技术：7 个阶段 + 6 个 NPC，每角色 4 帧。
	assert(PixelCast.STAGES.size() == 7, "pixel_cast should expose 7 life stages")
	assert(PixelCast.ROLES.size() == 6, "pixel_cast should expose 6 NPC roles")
	var cast_data: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/cast.json"))
	var cast: Dictionary = cast_data.get("cast", {})
	assert(cast.size() == 13, "cast.json should have 7 stages + 6 NPC")
	for id in cast:
		assert(int(cast[id].get("frames", 0)) == 4, "each cast entry should have 4 frames: " + str(id))
	for stage in PixelCast.STAGES:
		assert(PixelCast.frame(stage, false, 0) != null, "missing lead frame: " + stage)
	for role in PixelCast.ROLES:
		assert(PixelCast.frame(role, true, 0) != null, "missing npc frame: " + role)

	var cutscenes := Data.cutscene_map()
	assert(cutscenes.size() >= 3)
	var seen_actions := {}
	var seen_faces := {}
	for eid in cutscenes:
		var cut: Dictionary = cutscenes[eid]
		var bg := str(cut.get("bg", "home"))
		assert(PixelCast.room(bg) != null, "missing room atlas: " + bg)
		assert(SpriteKit.scene(bg) != null, "SpriteKit.scene should resolve latest room: " + bg)

		var cast_list: Array = cut.get("cast", [])
		var by_role := {}
		for c in cast_list:
			var role := str(c.get("role", "lead"))
			by_role[role] = c
			var key := _stage_key(str(eid)) if role == "lead" else _npc_key(role, str(eid))
			var npc := role != "lead"
			assert(PixelCast.frame(key, npc, 0) != null, "missing cast frame %s/%s" % [eid, key])
			assert(PixelCast.portrait(key, npc, false) != null, "missing portrait %s/%s" % [eid, key])
			assert(PixelCast.portrait(key, npc, true) != null, "missing speaking portrait %s/%s" % [eid, key])
			var act := str(c.get("action", "idle"))
			assert(ACTIONS.has(act), "unknown cast action: " + act)
			seen_actions[act] = true
			if c.has("from"):
				seen_actions["walk"] = true
			seen_faces[SpriteKit.norm_face(str(c.get("face", "normal")))] = true

		for b in cut.get("beats", []):
			var expr := SpriteKit.norm_face(str(b.get("expr", "normal")))
			assert(EXPRESSIONS.has(expr), "unknown expression: " + expr)
			seen_faces[expr] = true
			if b.has("action"):
				var action := str(b["action"])
				assert(ACTIONS.has(action), "unknown beat action: " + action)
				var target := str(b.get("target", b.get("face", "lead")))
				assert(by_role.has(target), "%s beat target not in cast: %s" % [eid, target])
				seen_actions[action] = true

	# 至少用了走位 + 一个手势语义，证明剧情动作确实接到最新角色帧。
	assert(seen_actions.has("walk"), "should use walk")
	assert(seen_actions.has("wave") or seen_actions.has("raise"), "should use a gesture action")
	assert(seen_faces.has("surprise"), "should use surprise expression")

	print("PASS: story cutscenes resolve against the latest pixel_cast cast/rooms")
	quit()
