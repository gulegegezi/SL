extends SceneTree
const Archive := preload("res://scripts/comic_archive.gd")
const Director := preload("res://scripts/comic_director.gd")
const Art := preload("res://scripts/comic_art.gd")
const State := preload("res://scripts/game_state.gd")
const Saves := preload("res://scripts/save_manager.gd")
var main
var path := "user://comic_reader_test_%d.save" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("run")

func click(button: Button) -> void:
	assert(root.get_visible_rect().encloses(button.get_global_rect()), "choice must be visible")
	var position := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion, true)
	await process_frame
	for pressed in [true, false]:
		var mouse := InputEventMouseButton.new()
		mouse.position = position
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = pressed
		root.push_input(mouse, true)
		await process_frame

func run() -> void:
	create_timer(25).timeout.connect(func(): push_error("comic reader test timeout"); quit(1))
	Saves.writes_enabled = false
	for key in ["infant_infant", "lead_child", "lead_teen", "lead_youth", "lead_adult", "lead_middle", "lead_elder", "npc_parent", "npc_friend", "npc_teacher", "npc_boss", "npc_partner", "npc_mate"]:
		for pose in range(2):
			var portrait := Art.portrait(key, pose) as AtlasTexture
			assert(portrait != null and Rect2(Vector2.ZERO, portrait.atlas.get_size()).encloses(portrait.region))
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.autosave_enabled = false
	main.archive_path = path
	main.gc.state = State.new()
	main.gc.state.age = 26
	main.gc.state.health = 10
	main.gc.rng.seed = 404
	main._comic = Director.new_run(main.gc.rng)
	var event := {"id": "READER_TEST", "title": "办公室的夜晚", "text": "你关掉工作电脑，窗外的城市还没有睡去。你决定如何度过今晚？", "choices": [
		{"label": "关机，回家休息", "effects": {"health": 2}, "result": "你回到房间睡了一觉，身体缓过来一些。"},
		{"label": "继续加班", "effects": {"health": -2}, "result": "灯一直亮到天明，你的肩膀变得沉重。"}]}
	assert(Director.can_montage(event, main.gc.state))
	assert(not Director.can_montage({"id": "WEDDING", "title": "结婚", "choices": event.choices}, main.gc.state))
	assert(not Director.can_montage({"id": "BRANCH", "next": "V03", "choices": event.choices}, main.gc.state))
	assert(not Director.can_montage({"id": "TAG", "choices": [{"tags": ["勇敢"]}]}, main.gc.state))
	assert(not main.gc.choice_lock_hint({"requireRelations": {"parent": 3}}).is_empty())
	assert(not main.gc.choice_visible({"showIf": {"tags": ["不存在的前置"]}}))
	main.current_event = event
	main._render_page(event)
	await process_frame
	await process_frame
	assert(main._history.size() == 1 and main._blanks.size() == 2)
	var original_history: Array = main._history.duplicate(true)
	var original_rng: int = main.gc.rng.state
	main.save_current()
	var stored := Archive.load_run(path)
	assert(stored.state.age == 26 and stored.history[0].spec.slots[0] is Rect2)
	await main.resume_saved()
	assert(main._history == original_history and main.gc.rng.state == original_rng, "resume must not reroll pages or RNG")
	assert(not main._after_choice)
	# A scroll-finished autosave may arrive between effects and their result page.
	main._busy = true
	main.gc.state.health = 12
	main.autosave_enabled = true
	main._autosave()
	assert(Archive.load_run(path).state.health == 10, "never save effects with an unresolved choice")
	main.gc.state.health = 10
	main._busy = false
	main.autosave_enabled = false
	await create_timer(0.8).timeout
	var button: Button = main._action_box.find_children("*", "Button", true, false)[0]
	await click(button)
	await create_timer(0.18).timeout
	assert(main.gc.state.health == 12 and main._history.size() == 2 and main._after_choice)
	main._on_comic_choice(event.choices[0])
	assert(main.gc.state.health == 12, "duplicate choice must not apply effects again")
	main.save_current()
	main.gc.state.health = 1
	await main.resume_saved()
	assert(main.gc.state.health == 12 and main._history.size() == 2 and main._after_choice)
	var before: Dictionary = main._comic.duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	assert(Director.new_run(rng).seed != before.seed, "another life receives another seed")
	for viewport_size in [Vector2i(520,900), Vector2i(360,640)]:
		root.content_scale_size = viewport_size
		root.size = viewport_size
		main.size = viewport_size
		await process_frame
		await process_frame
		main._layout_reader()
		await process_frame
		assert(main._strip_pages.size.x <= viewport_size.x, "comic must fit narrow viewport")
		assert(root.get_visible_rect().encloses(main._action_layer.get_global_rect()), "fixed action must fit viewport")
	# A second atomic save must replace the first and retain a readable backup.
	assert(Archive.save_run(main._snapshot(), path))
	assert(not Archive.load_run(path + ".bak").is_empty())
	main._completed = true
	assert(Archive.save_run(main._snapshot(), path))
	await main.resume_saved()
	assert(main._completed, "completed books must not resume as an unfinished life")
	main.save_current()
	assert(Archive.load_run(path).completed, "saving a finished book must preserve its ending")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	main.queue_free()
	await process_frame
	print("PASS: 26 mature portraits, safe montage, mouse choice, exact-once results, durable RNG/layout resume, 360px reader")
	quit()
