extends SceneTree
## 选项联动回归：关系值、选择记忆、条件解锁、四段式长线、UI 灰色锁定项。
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

func run() -> void:
	Data.ensure_loaded()
	var arcs := Data.arcs_data()
	assert(arcs.has("events") and arcs.has("nodes"))
	var events: Array = Data.arc_events()
	var nodes: Dictionary = Data.arc_nodes()
	assert(events.size() >= 16, "five arcs x four beats")
	assert(nodes.size() >= 9, "branch nodes for the linked arcs")

	# 结构：每个选项都有 memory，所有 next 都能解析。
	for e in events:
		assert(str(e.get("id", "")).begins_with("V"))
		assert(bool(e.get("once", false)), "arc events should be once-only: " + str(e.get("id", "")))
		var choices: Array = e.get("choices", [])
		assert(choices.size() >= 3)
		for c in choices:
			assert(str(c.get("memory", "")) != "", "missing memory: " + str(e.get("id", "")))
			for t in targets(c.get("next", null)):
				assert(not Data.find_story_node(t).is_empty(),
					"%s -> missing next %s" % [e.get("id", ""), t])
	for id in nodes:
		var n: Dictionary = nodes[id]
		assert(str(n.get("id", "")) == str(id))
		assert(str(n.get("stage", "")) == "branch")
		for c in n.get("choices", []):
			assert(str(c.get("memory", "")) != "", "missing branch memory: " + str(id))

	# 四段式链条的条件确实接得上。
	var v01 := Data.find_event("V01")
	var v02 := Data.find_event("V02")
	var v03 := Data.find_event("V03")
	var v04 := Data.find_event("V04")
	assert(v01.has("tags") and v01["tags"].has("_同桌_初识"))
	assert(v02["cond"]["tags"].has("_同桌_初识"))
	assert(v02.has("tags") and v02["tags"].has("_同桌_转学"))
	assert(v03["cond"]["tags"].has("_同桌_转学"))
	assert(v04["cond"]["tags"].has("_同桌_联系"))

	# 关系值 + 记忆 + 条件判断。
	var gc := Controller.new()
	gc.init()
	gc.state = State.new()
	gc.state.line = "normal"
	gc.state.age = 10

	gc.choose(v01["choices"][0], v01)
	assert(gc.state.get_relation("同桌") == 2)
	assert(gc.state.has_tag("_同桌_初识"))
	assert(gc.state.choice_memory("V01") == "你和同桌分了同一块橡皮")
	assert(gc._fill_text("他记得，{choice:V01}。") == "他记得，你和同桌分了同一块橡皮。")
	assert(gc._cond_matches({"chose": {"V01": "你和同桌分了同一块橡皮"}}))
	assert(not gc._cond_matches({"chose": {"V01": "另一句话"}}))
	assert(gc._cond_matches({"relations": {"同桌": 2}}))
	assert(not gc._cond_matches({"relations": {"同桌": 3}}))

	# V02 -> V03 -> V03A -> V04，年龄只在我们手动改，剧情链本身不跳段。
	gc.state.age = 13
	assert(gc._cond_matches(v02["cond"]), "V01 should unlock V02 at the right age")
	gc.choose(v02["choices"][0], v02)
	assert(gc.state.has_tag("_同桌_转学"))
	assert(gc.state.get_relation("同桌") == 4)

	gc.state.age = 30
	assert(gc._cond_matches(v03["cond"]), "V02 should unlock V03")
	gc.choose(v03["choices"][0], v03)
	assert(gc.state.has_tag("_同桌_联系"))
	assert(gc.state.story_queue.size() == 1 and gc.state.story_queue[0] == "V03A")
	var branch: Dictionary = gc.pick_event()
	assert(str(branch.get("id", "")) == "V03A")
	gc.choose(branch["choices"][0], branch)
	assert(gc.state.get_relation("同桌") == 8)

	gc.state.age = 50
	gc.choose(v04["choices"][0], v04)
	assert(gc.state.get_relation("同桌") == 10, "relations clamp at 10")

	# _fill_node 不能改到 DataLoader 的源数据。
	var raw_v03 := str(v03.get("text", ""))
	var filled := gc._fill_node(v03)
	assert(str(v03.get("text", "")) == raw_v03, "source node must not be mutated")
	assert(str(filled.get("text", "")).contains("你和同桌分了同一块橡皮"))

	# 关系值边界。
	var fresh := State.new()
	fresh.add_relation("同桌", 99)
	assert(fresh.get_relation("同桌") == 10)
	fresh.add_relation("同桌", -99)
	assert(fresh.get_relation("同桌") == -5)

	# UI：不满足 requireRelations 时灰掉并显示 requireHint；羁绊条能显示正负值。
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var ui_state := State.new()
	ui_state.relations = {"同桌": 0, "妈妈": 3}
	var locked: Button = main._choice_btn({
		"label": "问他：你当年为什么走",
		"requireRelations": {"同桌": 2},
		"requireHint": "需要和同桌更熟",
	}, ui_state)
	assert(locked.disabled, "locked choice should be disabled")
	assert(locked.text.contains("需要和同桌更熟"))
	var bar: HBoxContainer = main._render_relations(ui_state)
	assert(bar.get_child_count() >= 2, "relations bar should show mom + label")
	main.queue_free()
	await process_frame

	print("PASS: linked arcs, relations, choice memory, conditional unlock, locked UI choice")
	quit()
