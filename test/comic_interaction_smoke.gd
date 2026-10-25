extends SceneTree
const PanelView := preload("res://scripts/comic_panel.gd")
const Interaction := preload("res://scripts/comic_interaction.gd")
const Pace := preload("res://scripts/short_life.gd")
const Director := preload("res://scripts/comic_director.gd")
const Archive := preload("res://scripts/comic_archive.gd")
const State := preload("res://scripts/game_state.gd")
var panel
var emissions := 0

func _initialize() -> void:
	call_deferred("run")

func pointer(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event,true)
	await process_frame

func run() -> void:
	create_timer(20).timeout.connect(func(): push_error("interaction timeout"); quit(1))
	root.size = Vector2i(520,900)
	panel = PanelView.new()
	panel.position = Vector2(12,80)
	panel.size = Vector2(490,380)
	root.add_child(panel)
	panel.interacted.connect(func(_progress): emissions += 1)
	for kind in ["tap","reveal","drag","hold"]:
		panel.setup({"caption":"你伸手看看桌上的东西。","ink":"lead_adult","stage_action":true,"interaction":{"kind":kind,"prop":"toy","hint":"试试","reveal":"看到了藏着的小纸条。"}},null)
		panel.finish_reveal()
		var object_at: Vector2 = panel.position + panel.interaction_object_rect().get_center()
		await pointer(object_at,true)
		if kind == "drag":
			await pointer(object_at,false)
			assert(not panel.interaction_done,"a cancelled drag must remain retryable")
			await pointer(object_at,true)
			var motion := InputEventMouseMotion.new()
			motion.position = panel.position+panel.interaction_target_rect().get_center()
			root.push_input(motion,true)
			await process_frame
			await pointer(motion.position,false)
		elif kind == "hold":
			await create_timer(0.25).timeout
			await pointer(object_at,false)
			assert(not panel.interaction_done,"short press must not satisfy hold")
			await pointer(object_at,true)
			await create_timer(0.9).timeout
			await pointer(object_at,false)
		else: await pointer(object_at,false)
		assert(panel.interaction_done,"actual pointer did not complete " + kind)
		var count := emissions
		panel.complete_interaction()
		assert(emissions == count,"one completion per panel")
		panel.setup(panel.spec,null)
		assert(panel.interaction_done,"completed discovery must survive reflow/resume")
	assert(emissions == 4)
	panel.setup({"caption":"你举起鼓槌。","ink":"lead_adult","stage_action":true,"interaction":{"kind":"tap","prop":"drum","hint":"敲鼓","reveal":"第一拍响了。"}},null)
	panel.finish_reveal()
	var drum_at: Vector2 = panel.position+panel.interaction_object_rect().get_center()
	await pointer(drum_at,true)
	await pointer(drum_at,false)
	assert(panel.interaction_done,"the visible drum must be the actual clickable area")
	panel.queue_free()
	await process_frame
	preload("res://scripts/save_manager.gd").writes_enabled = false
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.autosave_enabled = false
	main.archive_path = "user://short_interaction_test.save"
	main.gc.state = State.new()
	main.gc.state.short_mode = true
	main.gc.state.age = 1
	var event: Dictionary = Pace.data().events[0].duplicate(true)
	main.current_event = event
	main._render_page(event)
	await process_frame
	await process_frame
	var page = main._strip_pages.get_child(0).get_child(0)
	page.panels[1].complete_interaction()
	assert(main._history[0].spec.panels[1].interaction_progress.completed)
	assert(Archive.save_run(main._snapshot(),main.archive_path))
	main.resume_saved()
	await process_frame
	await process_frame
	assert(main._history[0].spec.panels[1].interaction_progress.completed)
	page = main._strip_pages.get_child(0).get_child(0)
	assert(page.interactions_enabled and page.panels[1].interaction_done)
	# Disregarding all interactions must still allow a choice and its continuation.
	main._on_comic_choice(main.current_event.choices[0])
	await create_timer(0.13).timeout
	assert(main._after_choice and main.gc.state.choice_log.has("SL01"))
	assert(not page.interactions_enabled,"past panels must be frozen after choosing")
	main._advance_page()
	assert(main.gc.state.age == 4 and main.current_event.id == "SL04")
	main.queue_free()
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists("user://short_interaction_test.save"+suffix): DirAccess.remove_absolute("user://short_interaction_test.save"+suffix)
	print("PASS: actual mouse tap/flip/drag/hold, cancel and retry, exact-once, history/save/reflow, optional choices, age skip")
	quit()
