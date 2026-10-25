extends SceneTree
## Undertale 式过场回归：数据完整、SpriteKit 映射、逐字推进到心形光标、锁定项跳过。
const Data := preload("res://scripts/data_loader.gd")
const CutsceneStage := preload("res://scripts/cutscene_stage.gd")
const SpriteKit := preload("res://scripts/sprite_kit.gd")
const State := preload("res://scripts/game_state.gd")

func _initialize() -> void:
	call_deferred("run")

func _state(age: int) -> State:
	var s := State.new()
	s.age = age
	return s

func run() -> void:
	Data.ensure_loaded()
	var map := Data.cutscene_map()
	assert(map.size() >= 3, "should have OP01/V03/V13 cutscenes")
	for eid in ["OP01", "V03", "V13"]:
		var cut := Data.cutscene_for(eid)
		assert(not cut.is_empty(), "missing cutscene " + eid)
		assert(cut.has("bg") and cut.has("beats"))
		assert(cut["beats"].size() >= 2)
		for b in cut["beats"]:
			assert(b.has("speaker") and b.has("text"))
		for c in cut.get("cast", []):
			assert(c.has("role"))

	# SpriteKit：年龄映射与分件组装。
	assert(SpriteKit.stage_for_age(5) == "child")
	assert(SpriteKit.stage_for_age(16) == "youth")
	assert(SpriteKit.stage_for_age(20) == "adult")
	assert(SpriteKit.stage_for_age(70) == "elder")
	var parts := SpriteKit.compose("adult", false, "happy")
	assert(parts.size() == 6, "lead = legs/torso/arms/head")
	for t in parts:
		assert(t != null, "lead parts must load")
	assert(SpriteKit.face("parent", "happy", true) != null, "npc face must load")

	# 直接播放 OP01 过场，走到选项并确认第一项。
	var ev := {
		"id": "OP01",
		"choices": [
			{"label": "放声大哭", "result": "…", "effects": {"health": 1}},
			{"label": "安静地睁眼", "result": "…", "effects": {"int": 1}},
			{"label": "一把抓住护士的手指", "result": "…", "effects": {"luck": 1}},
		],
	}
	var stage := CutsceneStage.new()
	stage.size = Vector2(520, 480)
	root.add_child(stage)
	await process_frame
	stage.configure(ev, Data.cutscene_for("OP01"), _state(1), ev["choices"])
	var got := []
	stage.finished.connect(func(c): got.append(c))
	stage.play()
	assert(stage.beat_index == 0)
	var guard := 0
	while not stage.in_choices and guard < 20:
		stage.advance()
		guard += 1
	assert(stage.in_choices, "must reach choices after beats")
	assert(guard < 20)
	stage.confirm()
	assert(got.size() == 1 and str(got[0]["label"]) == "放声大哭")
	stage.queue_free()
	await process_frame

	# 锁定项：V13 的陪床需要关系，菜单应从第一个可选项开始，并跳过锁定项。
	var ev2 := {
		"id": "V13",
		"choices": [
			{"label": "留下来陪床", "result": ""},
			{"label": "去缴费", "result": ""},
			{"label": "先回去", "result": ""},
		],
	}
	var rich := [
		{"choice": ev2["choices"][0], "locked": true, "hint": "需要和妈妈更亲近"},
		{"choice": ev2["choices"][1], "locked": false, "hint": ""},
		{"choice": ev2["choices"][2], "locked": false, "hint": ""},
	]
	var locked := CutsceneStage.new()
	locked.size = Vector2(520, 480)
	root.add_child(locked)
	await process_frame
	locked.configure(ev2, Data.cutscene_for("V13"), _state(40), rich)
	var res := []
	locked.finished.connect(func(c): res.append(c))
	locked.play()
	var g := 0
	while not locked.in_choices and g < 20:
		locked.advance()
		g += 1
	assert(locked.in_choices)
	assert(locked.choice_index == 1, "first unlocked option should be selected")
	locked.move_choice(-1)
	assert(locked.choice_index == 2, "wrapping must skip the locked first option")
	locked.choice_index = 0
	locked.confirm()
	assert(res.is_empty(), "confirming a locked option must do nothing")
	locked.choice_index = 2
	locked.confirm()
	assert(res.size() == 1 and str(res[0]["label"]) == "先回去")
	locked.queue_free()
	await process_frame

	# 剧情 beat 直接驱动逐帧动作：V03 老同学挥手，下一拍收回。
	var v03_ev := {
		"id": "V03",
		"choices": [
			{"label": "去见他", "result": ""},
			{"label": "说最近很忙，改天", "result": ""},
			{"label": "问他：你当年为什么走", "result": ""},
		],
	}
	var wave := CutsceneStage.new()
	wave.size = Vector2(520, 480)
	root.add_child(wave)
	await process_frame
	wave.configure(v03_ev, Data.cutscene_for("V03"), _state(30), v03_ev["choices"])
	wave.play()
	for _i in range(4):
		wave.advance()
	assert(wave.beat_index == 2, "should reach the friend's line")
	assert(str(wave.cast[1].get("action", "")) == "wave", "friend should wave on the line")
	for _i in range(2):
		wave.advance()
	assert(wave.beat_index == 3)
	assert(str(wave.cast[1].get("action", "")) == "idle", "friend should stop waving")
	assert(wave.lead_expr == "happy", "lead expression should switch to happy")
	wave.queue_free()
	await process_frame
	# 等音频服务器释放最后一次确认音的播放句柄。
	await create_timer(0.15).timeout

	print("PASS: cutscene data, sprite kit, beats -> heart choices, locked skip, beat-driven actions")
	quit()
