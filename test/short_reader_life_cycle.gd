extends SceneTree
const Archive := preload("res://scripts/comic_archive.gd")
var main
var path := "user://short_cycle_%d.save" % Time.get_ticks_usec()
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	create_timer(35).timeout.connect(func(): push_error("short UI life timeout"); quit(1))
	preload("res://scripts/save_manager.gd").writes_enabled = false
	var results: Array = []
	for policy in [0,2]:
		main = load("res://scenes/Main.tscn").instantiate()
		root.add_child(main)
		await process_frame
		main.autosave_enabled = false
		main.archive_path = path
		main.gc.rng.seed = 910+policy
		main.gc.new_game()
		main.gc.state.age = 1
		main.gc.state.health = 14
		main.gc.state.lifespan = 92
		main.render_main()
		var choices := 0
		var guard := 0
		var previous := 0
		while not main._completed and guard < 55:
			guard += 1
			if main._after_choice:
				if choices == 5:
					var event_id: String = main.current_event.id
					var queue: Array = main.gc.state.story_queue.duplicate()
					assert(Archive.save_run(main._snapshot(),path))
					main.resume_saved()
					await process_frame
					await process_frame
					assert(main._after_choice and main.current_event.id == event_id and main.gc.state.story_queue == queue)
				main._advance_page()
			else:
				assert(not main.current_event.is_empty() and main.current_event.has("comic"))
				main._on_comic_choice(main.current_event.choices[policy])
				await create_timer(0.12).timeout
				choices += 1
			await process_frame
			assert(main._history.size() >= previous)
			previous = main._history.size()
		assert(main._completed and choices in range(14,21))
		results.append({"choices":choices,"age":main.gc.state.age,"pages":main._history.size()})
		main.queue_free()
		await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	print("PASS: two UI lives with no required interactions, mid-result resume, ending and immutable history: ",results)
	quit()
