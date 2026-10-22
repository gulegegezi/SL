extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(520,900)
	root.content_scale_size = Vector2i(520,900)
	var lab = load("res://scenes/WorldLab.tscn").instantiate()
	root.add_child(lab)
	await process_frame
	lab.playing = false
	DirAccess.make_dir_recursive_absolute("res://docs/world-scenes")
	for i in range(6):
		lab.select(i)
		lab.sample_at(1.25)
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://docs/world-scenes/scene-%d.png" % i) == OK)
	lab.select(5)
	lab.sample_at(2.4)
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://docs/world-scenes/farewell-after.png") == OK)
	print("PASS: six ensemble storyboards and settled farewell captured")
	quit()
