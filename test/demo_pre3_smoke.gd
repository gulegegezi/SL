extends SceneTree
## 三岁前试玩回归：7 幕顺序、每幕过场/选项存在、可从头玩到结尾并生成总结。
const Data := preload("res://scripts/data_loader.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	Data.ensure_loaded()
	var demo_data: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/story_demo_pre3.json"))
	var scenes: Array = demo_data.get("scenes", [])
	assert(scenes.size() == 7, "three-years demo should have 7 scenes")
	for entry in scenes:
		var ev := Data.find_story_node(str(entry.get("event", "")))
		assert(not ev.is_empty(), "missing event " + str(entry.get("event", "")))
		assert(ev.get("choices", []).size() >= 1)
		var cut := Data.cutscene_for(str(entry.get("cutscene", "")))
		assert(not cut.is_empty(), "missing cutscene " + str(entry.get("cutscene", "")))
		assert(cut.get("beats", []).size() >= 1)

	var demo = load("res://scenes/StoryDemo.tscn").instantiate()
	root.add_child(demo)
	await process_frame
	assert(demo.scenes.size() == 7)
	assert(demo.index == 0)
	assert(demo.phase == "scene")
	assert(demo.stage != null)

	var guard := 0
	while demo.phase != "end" and guard < 200:
		var stage = demo.stage
		var steps := 0
		while not stage.in_choices and steps < 30:
			stage.advance()
			steps += 1
		assert(stage.in_choices, "scene/result should reach choices")
		stage.confirm()
		await process_frame
		guard += 1

	assert(demo.phase == "end", "demo should reach the ending")
	assert(guard < 200)
	assert(demo.memories.size() == 7, "each scene should record one memory")
	assert(demo.summary.visible, "ending summary should be visible")
	assert(demo.summary.text.contains("年龄：3 岁"), "summary should show age 3")
	assert(demo.stage.visible == false)

	print("PASS: pre-3 demo runs 7 scenes with cutscenes, choices and an age-3 summary")
	demo.queue_free()
	await process_frame
	quit()
