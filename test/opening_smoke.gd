extends SceneTree
## 序章分支树回归：结构校验 + 普通线/抽象线实走 + 条件选项/条件 next。
const Data := preload("res://scripts/data_loader.gd")
const Controller := preload("res://scripts/game_controller.gd")
const State := preload("res://scripts/game_state.gd")

func _initialize() -> void:
	call_deferred("run")

func targets(spec: Variant) -> Array:
	if spec == null:
		return []
	if typeof(spec) == TYPE_STRING or typeof(spec) == TYPE_STRING_NAME:
		return [str(spec)]
	if typeof(spec) != TYPE_DICTIONARY:
		return []
	var out: Array = []
	var d: Dictionary = spec
	if d.has("default"):
		out.append(str(d["default"]))
	for rule in d.get("when", []):
		if typeof(rule) == TYPE_DICTIONARY and rule.has("next"):
			out.append(str(rule["next"]))
	return out

func walk(gc: Controller, first: bool) -> Array:
	var visited: Array = []
	var guard := 0
	while not gc.state.story_queue.is_empty() and guard < 40:
		var ev: Dictionary = gc.pick_event()
		assert(not ev.is_empty(), "queue node must resolve")
		visited.append(str(ev.get("id", "")))
		var choices: Array = ev.get("choices", [])
		var usable: Array = []
		for c in choices:
			if gc.choice_available(c):
				usable.append(c)
		assert(not usable.is_empty(), "node needs at least one usable choice: " + str(ev.get("id", "")))
		var picked: Dictionary = usable[0] if first else usable[usable.size() - 1]
		gc.choose(picked, ev)
		var before: int = gc.state.age
		gc.advance_after_choice(ev)
		if not gc.state.story_queue.is_empty():
			assert(gc.state.age == before, "age must not advance inside a chained story")
		guard += 1
	assert(guard < 40, "story queue must drain")
	return visited

func run() -> void:
	Data.ensure_loaded()
	var nodes: Dictionary = Data.opening_nodes()
	assert(nodes.size() >= 26, "opening should have at least 26 nodes")
	assert(Data.opening_start("normal") == "OP01")
	assert(Data.opening_start("absurd") == "OP01A")

	var ids: Dictionary = {}
	for id in nodes:
		ids[str(id)] = true
	for e in Data.events():
		ids[str(e.get("id", ""))] = true

	var prologue := 0
	for id in nodes:
		var node: Dictionary = nodes[id]
		assert(str(node.get("id", "")) == str(id), "node id mismatch: " + str(id))
		assert(str(node.get("title", "")) != "", "empty title: " + str(id))
		assert(str(node.get("text", "")).length() >= 10, "text too short: " + str(id))
		var choices: Array = node.get("choices", [])
		assert(not choices.is_empty(), "no choices: " + str(id))
		if str(node.get("stage", "")) == "prologue":
			prologue += 1
		for c in choices:
			assert(str(c.get("label", "")) != "", "empty label: " + str(id))
			assert(str(c.get("result", "")) != "", "empty result: " + str(id))
			for t in targets(c.get("next", null)):
				assert(ids.has(t), "%s -> missing next %s" % [id, t])
		for t in targets(node.get("next", null)):
			assert(ids.has(t), "%s -> missing event next %s" % [id, t])
	assert(prologue >= 20, "opening should have at least 20 prologue nodes")

	# 随机事件的 next 必须落在 story_opening.json 的分支节点里
	for e in Data.events():
		for c in e.get("choices", []):
			for t in targets(c.get("next", null)):
				assert(nodes.has(t), "%s branch target missing %s" % [e.get("id", ""), t])

	# 普通线：一路选第一个
	var gc := Controller.new()
	gc.init()
	gc.state = State.new()
	gc.state.line = "normal"
	assert(gc.begin_opening())
	var first_path := walk(gc, true)
	assert(first_path.size() >= 8, "normal first-choice path should visit >= 8 scenes")
	assert(first_path[0] == "OP01")
	assert(first_path[first_path.size() - 1] == "OP14")
	assert(gc.state.age == 1, "OP14 ageGain should move age to 1")
	assert(gc.state.opening_done)
	assert(gc.state.has_tag("_已抓周"), "prologue grasping should set the hidden tag")
	assert(not gc._cond_matches(Data.find_event("C01")["cond"]),
		"random C01 must be excluded after the prologue grasping")

	# 普通线：一路选最后一个（应走另一条支线）
	gc.state = State.new()
	gc.state.line = "normal"
	assert(gc.begin_opening())
	var last_path := walk(gc, false)
	assert(last_path.size() >= 8)
	assert(last_path[0] == "OP01")
	assert(last_path[1] == "OP04", "last birth choice should enter hand-strength branch")

	# 抽象线：独立开头 -> 抽象满月酒
	gc.state = State.new()
	gc.state.line = "absurd"
	assert(gc.begin_opening())
	var absurd_path := walk(gc, true)
	assert(absurd_path[0] == "OP01A")
	assert(absurd_path[1] == "OP02A")
	assert(absurd_path[2] == "OP05A")
	assert(gc.state.age == 1)

	# 条件选项：只有“吃货”能看到桂花糕
	gc.state = State.new()
	gc.state.line = "normal"
	var op11: Dictionary = nodes["OP11"]
	var cake: Dictionary = op11["choices"][5]
	assert(not gc.choice_available(cake), "hidden choice must be unavailable without 吃货")
	gc.state.tags["吃货"] = true
	assert(gc.choice_available(cake), "hidden choice should appear with 吃货")

	# 条件 next：社牛走热闹的全家福
	gc.state.tags["社牛"] = true
	var op13: Dictionary = nodes["OP13"]
	assert(gc._resolve_next(op13["choices"][0]["next"]) == "OP13A")
	gc.state.tags.erase("社牛")
	assert(gc._resolve_next(op13["choices"][0]["next"]) == "OP14")

	# 普通事件也能 next 到后续节点
	var c21: Dictionary = Data.find_event("C21")
	assert(str(c21.get("id", "")) == "C21")
	assert(gc._resolve_next(c21["choices"][0]["next"]) == "C21A")

	print("PASS: opening structure, 3 story paths, conditional choice, conditional next, event branch")

	gc = null
	await process_frame
	quit()
