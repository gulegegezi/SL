extends SceneTree
const State := preload("res://scripts/game_state.gd")
const Pace := preload("res://scripts/short_life.gd")
var main
func _initialize() -> void:
	call_deferred("run")
func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://docs/short-life/"+name+".png") == OK)
func run() -> void:
	preload("res://scripts/save_manager.gd").writes_enabled = false
	DirAccess.make_dir_recursive_absolute("res://docs/short-life")
	root.content_scale_size = Vector2i(520,900)
	root.size = Vector2i(520,900)
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.autosave_enabled = false
	for id in ["SL01","SL07","SL22","SL40"]:
		main.gc.new_game()
		main.gc.state.short_mode = true
		main.gc.state.health = 12
		main.gc.state.lifespan = 90
		var event: Dictionary = {}
		for candidate in Pace.data().events:
			if str(candidate.id) == id: event = candidate.duplicate(true); break
		main.gc.state.age = int(event.age)
		main.current_event = event
		main._render_page(event)
		await process_frame
		await process_frame
		await create_timer(0.7).timeout
		var page = main._strip_pages.get_child(0).get_child(0)
		for panel in page.panels: panel.set_revealed(true); panel.finish_reveal()
		var focus = page.panels[1]
		main._scroll.scroll_vertical = int(focus.position.y - 12)
		await process_frame
		await shot(id+"-before")
		focus.complete_interaction()
		await create_timer(0.95).timeout
		await shot(id+"-after")
		if id == "SL22":
			main._on_comic_choice(event.choices[0])
			await create_timer(0.13).timeout
			await process_frame
			await create_timer(0.7).timeout
			var result_page = main._strip_pages.get_child(1).get_child(0)
			for panel in result_page.panels: panel.set_revealed(true); panel.finish_reveal()
			await shot("SL22-result")
	root.content_scale_size = Vector2i(360,900)
	root.size = Vector2i(360,900)
	await process_frame
	await process_frame
	var mobile_page = main._strip_pages.get_child(0).get_child(0)
	for panel in mobile_page.panels: panel.set_revealed(true); panel.finish_reveal()
	mobile_page.panels[1].complete_interaction()
	main._scroll.scroll_vertical = int(mobile_page.panels[1].position.y - 12)
	await shot("mobile-360")
	root.content_scale_size = Vector2i(520,900)
	root.size = Vector2i(520,900)
	main.gc.new_game()
	main.gc.state.age = 27
	main.gc.state.short_previous_age = 18
	main.gc.state.tags["手艺人"] = true
	main.render_main()
	await create_timer(0.8).timeout
	var jump_page = main._strip_pages.get_child(0).get_child(0)
	for panel in jump_page.panels: panel.set_revealed(true); panel.finish_reveal()
	await shot("jump-18-to-27")
	main.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("PASS: native short-life reader screenshots captured")
	quit()
