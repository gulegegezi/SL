extends SceneTree
const Stage := preload("res://scripts/story_stage.gd")
const Director := preload("res://scripts/story_director.gd")
const State := preload("res://scripts/game_state.gd")
const Data := preload("res://scripts/data_loader.gd")
var stage
var state

func _initialize() -> void:
	call_deferred("run")

func play_event(id: String, index: int) -> void:
	var event := Data.find_event(id)
	stage.configure(state)
	stage.play(event, event.choices[index], [])
	stage._process(6.0)
	assert(not stage.playing)

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/" + name + ".png")

func run() -> void:
	Data.ensure_loaded()
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.content_scale_size = Vector2i(520, 480)
	root.size = Vector2i(780, 720)
	stage = Stage.new()
	stage.size = Vector2(520, 480)
	root.add_child(stage)
	state = State.new()
	state.age = 1
	stage.configure(state)
	play_event("C01", 0)
	assert(stage.mode == "grasp" and stage.shot.prop == "pen")
	assert(state.story_world.memories.size() == 1)
	await capture("life-town-child")
	play_event("C01", 2)
	assert(stage.mode == "grasp" and stage.shot.prop == "phone")
	assert(Director.plan(Data.find_event("N14"), Data.find_event("N14").choices[1], "walk").action == "refuse")
	state.age = 30
	state.money = 50
	play_event("N14", 0)
	assert(state.story_world.home_level == 1)
	play_event("N15", 0)
	assert(state.story_world.partner)
	play_event("N16", 0)
	assert(state.story_world.child)
	stage.play({"title": "第一次播种"}, {"label": "种菜", "result": "新叶从泥土里长了出来。"}, [])
	stage._process(6.0)
	assert(state.story_world.crops == 1)
	play_event("N09", 0)
	stage.play({"title": "老朋友"}, {"label": "与朋友交流", "result": "你们成了常来常往的朋友。"}, [])
	stage._process(6.0)
	assert(state.story_world.friends == 1)
	await capture("life-town-adult")
	var memory_count: int = state.story_world.memories.size()
	stage.queue_free()
	await process_frame
	stage = Stage.new()
	stage.size = Vector2(520, 480)
	root.add_child(stage)
	stage.configure(state)
	assert(stage.world.memories.size() == memory_count)
	assert(stage.world.crops == 1 and stage.world.partner and stage.world.child)
	assert(stage.actor == state.story_world.position)
	state.age = 68
	play_event("N43", 2)
	assert(stage.mode == "fish" and stage.shot.place == "pond")
	await capture("life-town-senior")
	var fresh := State.new()
	stage.configure(fresh)
	assert(stage.world.memories.is_empty() and not stage.world.partner)
	var count := 0
	for event in Data.events():
		for choice in event.get("choices", []) + event.get("altChoices", []):
			var shot := Director.plan(event, choice, Stage.resolve(event, choice, []))
			assert(Director.PLACES.has(shot.place))
			assert(Stage.TITLES.has(shot.action))
			count += 1
	print("PASS: %d choices routed; grasp variants, purchase/wait, marriage, child, crops, friends, reconstruction persistence, fresh life, senior fishing" % count)
	stage.queue_free()
	await process_frame
	quit()
