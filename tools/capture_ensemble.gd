extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(520,900)
	root.content_scale_size = Vector2i(520,900)
	var lab = load("res://scenes/EnsembleLab.tscn").instantiate()
	root.add_child(lab)
	await process_frame
	lab.playing=false
	DirAccess.make_dir_recursive_absolute("res://.godot/ensemble-frames")
	for i in range(25):
		lab.clock=i/10.0
		lab.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://.godot/ensemble-frames/%02d.png" % i)==OK)
		if i==10: assert(root.get_texture().get_image().save_png("res://docs/world-scenes/ensemble.png")==OK)
	print("PASS: 25 ensemble animation frames captured in native Godot")
	quit()
