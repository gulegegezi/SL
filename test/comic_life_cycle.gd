extends SceneTree
const State := preload("res://scripts/game_state.gd")
const Director := preload("res://scripts/comic_director.gd")
const Saves := preload("res://scripts/save_manager.gd")
const Data := preload("res://scripts/data_loader.gd")
var main

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(45).timeout.connect(func(): push_error("life cycle timeout"); quit(1))
	Saves.writes_enabled = false
	var results: Array = []
	for seed_value in [101,202]:
		main = load("res://scenes/Main.tscn").instantiate()
		root.add_child(main)
		await process_frame
		main.autosave_enabled = false
		main.gc.state = State.new()
		main.gc.state.age = 1
		main.gc.state.health = 18
		main.gc.state.lifespan = 44
		main.gc.state.money = 30
		main.gc.state.line = "normal"
		main.gc.state.region = Data.region_keys()[0]
		main.gc.rng.seed = seed_value
		main._comic = Director.new_run(main.gc.rng)
		main.render_main()
		var previous_count := 0
		var guard := 0
		while not main._completed and guard < 100:
			guard += 1
			if main._after_choice:
				main._advance_page()
			else:
				var available: Array = main._action_box.find_children("*", "Button", true, false).filter(func(button): return not button.disabled and not button.is_queued_for_deletion())
				assert(not available.is_empty(), "player must have a choice or continuation")
				available[0].pressed.emit()
				await create_timer(0.12).timeout
			await process_frame
			assert(main._history.size() >= previous_count, "completed pages must never disappear")
			previous_count = main._history.size()
		assert(main._completed and guard < 100, "life must reach an ending")
		var frames := 0
		var montages := 0
		for entry in main._history:
			frames += entry.spec.panels.size()
			if bool(entry.spec.get("montage", false)): montages += 1
		results.append({"seed": seed_value, "age": main.gc.state.age, "pages": main._history.size(), "panels": frames, "quiet_intervals": montages})
		main._on_game_started(main.gc.state)
		assert(main._history.is_empty() and main._page_no == 0 and not main._completed, "another life resets the old strip")
		main.queue_free()
		await process_frame
	print("PASS two complete seeded lives; cumulative panels, ending and restart: ", results)
	quit()
