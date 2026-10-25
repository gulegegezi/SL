extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var lab = load("res://scenes/PerformanceLab.tscn").instantiate()
	root.add_child(lab)
	await process_frame
	DirAccess.make_dir_recursive_absolute("res://docs/animation-performance")
	for index in range(4):
		lab.show_sample(index)
		for card in lab.cards: card.finish_reveal()
		await process_frame
		await RenderingServer.frame_post_draw
		var path := "res://docs/animation-performance/%02d.png" % index
		assert(root.get_texture().get_image().save_png(path) == OK)
	print("PASS: four native Godot performance previews captured")
	quit()
