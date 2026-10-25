extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.content_scale_size = Vector2i(520,900)
	root.size = Vector2i(520,900)
	var lab = load("res://scenes/ActingLab.tscn").instantiate()
	root.add_child(lab)
	await process_frame
	lab.playing = false
	DirAccess.make_dir_recursive_absolute("res://docs/acting")
	for entry in [[0,0.1,"receive-before"],[0,1.3,"receive-contact"],[1,1.3,"read-contact"],[2,0.1,"phone-before"],[2,1.3,"phone-contact"],[3,1.3,"sign-contact"],[4,1.2,"drum-contact"],[5,0.7,"walk-contact"]]:
		lab.select(int(entry[0]))
		lab.sample_at(float(entry[1]))
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://docs/acting/"+str(entry[2])+".png") == OK)
	lab.queue_free()
	await process_frame
	print("PASS: eight native action previews captured")
	quit()
