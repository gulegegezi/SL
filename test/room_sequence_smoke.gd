extends SceneTree
const Stage := preload("res://scripts/story_stage.gd")
const Director := preload("res://scripts/story_director.gd")
const Data := preload("res://scripts/data_loader.gd")
const State := preload("res://scripts/game_state.gd")
var stage
var completions := 0

func _initialize() -> void:
	call_deferred("run")

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
	var state := State.new()
	state.age = 1
	stage.configure(state)
	stage.finished.connect(func(): completions += 1)
	var event := Data.find_event("C01")
	stage.play(event, event.choices[0], [])
	assert(stage.shot.room == "nursery" and stage.shot.prop == "pen")
	assert(stage.beat_index == 0)
	assert(stage.world.memories.is_empty())
	stage.advance_dialogue() # 先补全文字
	assert(stage.beat_index == 0)
	stage.advance_dialogue() # 再前进到伸手拿取
	assert(stage.beat_index == 1)
	assert(stage.world.memories.is_empty())
	stage._process(stage.beat_durations[1] * 0.6)
	await capture("story-room-grasp")
	stage._process(stage.duration)
	assert(stage.world.memories.size() == 1 and completions == 1)
	stage.advance_dialogue()
	assert(completions == 1)
	state.age = 30
	stage.configure(state)
	event = Data.find_event("N14")
	stage.play(event, event.choices[0], [])
	stage._process(stage.beat_durations[0] + stage.beat_durations[1] + 0.5)
	assert(stage.shot.room == "agency" and stage.mode == "move")
	stage.advance_dialogue()
	await capture("story-room-purchase")
	stage._process(stage.duration)
	var owned: int = stage.world.home_level
	stage.play(event, event.choices[1], [])
	assert(stage.shot.room == "agency" and stage.mode == "refuse")
	stage._process(stage.duration)
	assert(stage.world.home_level == owned)
	event = Data.find_event("N15")
	stage.play(event, event.choices[0], [])
	stage._process(stage.duration)
	assert(stage.shot.room == "chapel" and stage.world.partner)
	await capture("story-room-wedding")
	var count := 0
	var rooms := {}
	for ev in Data.events():
		for choice in ev.get("choices", []) + ev.get("altChoices", []):
			stage.play(ev, choice, [])
			assert(stage.shot.beats.size() == 3)
			assert(stage.shot.beats[2].text == choice.result)
			assert(stage.duration >= 5.4)
			assert(Stage.Room.NAMES.has(stage.shot.room))
			rooms[stage.shot.room] = true
			# 每个选项均走完分镜、绘制和完成信号，确认只记一次经历。
			var before: int = stage.world.memories.size()
			stage._process(stage.duration)
			await process_frame
			assert(stage.world.memories.size() == before + 1)
			count += 1
	print("PASS: %d choice sequences, %d rooms, continuous beats, two-step dialogue, unique outcome, exactly-once completion" % [count, rooms.size()])
	stage.queue_free()
	await process_frame
	quit()
