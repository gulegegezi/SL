extends SceneTree
const Pace := preload("res://scripts/short_life.gd")
const Interaction := preload("res://scripts/comic_interaction.gd")
var main
var capture_directory := "res://docs/world-scenes/" if "--world" in OS.get_cmdline_user_args() else "res://docs/acting/"
func _initialize() -> void:
	call_deferred("run")
func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(capture_directory+name+".png") == OK)
func run() -> void:
	preload("res://scripts/save_manager.gd").writes_enabled = false
	root.content_scale_size = Vector2i(520,900)
	root.size = Vector2i(520,900)
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.autosave_enabled = false
	for id in ["SL27","SL16"]:
		main.gc.new_game()
		var event: Dictionary = {}
		for candidate in Pace.data().events:
			if str(candidate.id) == id: event = candidate.duplicate(true); break
		main.gc.state.age = int(event.age)
		main.current_event = event
		main._render_page(event)
		await create_timer(0.75).timeout
		var page = main._strip_pages.get_child(0).get_child(0)
		for panel in page.panels: panel.set_revealed(true); panel.finish_reveal()
		var panel = page.panels[1]
		main._scroll.scroll_vertical = int(panel.position.y-12)
		await process_frame
		var at: Vector2 = panel.global_position+Interaction.object_rect(panel.size,str(panel.spec.interaction.prop)).get_center()
		for pressed in [true,false]:
			var mouse := InputEventMouseButton.new()
			mouse.position = at
			mouse.button_index = MOUSE_BUTTON_LEFT
			mouse.pressed = pressed
			root.push_input(mouse,true)
			await process_frame
		assert(panel.interaction_done,"native game click must start the actor action")
		await create_timer(1.1).timeout
		main._scroll.scroll_vertical = int(panel.position.y-12)
		await shot("game-"+id)
		if id == "SL27":
			root.content_scale_size = Vector2i(360,900)
			root.size = Vector2i(360,900)
			await process_frame
			await process_frame
			page = main._strip_pages.get_child(0).get_child(0)
			for narrow_panel in page.panels: narrow_panel.set_revealed(true); narrow_panel.finish_reveal()
			main._scroll.scroll_vertical = int(page.panels[1].position.y-12)
			await shot("game-mobile-phone")
			root.content_scale_size = Vector2i(520,900)
			root.size = Vector2i(520,900)
			await process_frame
	main.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("PASS: native game phone/drum clicks, contact poses and mobile capture")
	quit()
