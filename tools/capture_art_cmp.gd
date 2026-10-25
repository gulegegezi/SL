extends SceneTree
## 美术/渲染对比截图：同一 3D 像素舞台，按 tag 输出三场。

var OUT := "D:/gamelife/_render_cmp"

var lab


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var tag := args[0] if args.size() > 0 else "run"
	if args.size() > 1:
		OUT = args[1]
	DirAccess.make_dir_recursive_absolute(OUT)
	_run(tag)


func _run(tag: String) -> void:
	root.size = Vector2i(520, 900)
	root.content_scale_size = Vector2i(520, 900)
	lab = (load("res://scenes/PixelStageLab.tscn") as PackedScene).instantiate()
	root.add_child(lab)
	await create_timer(1.4).timeout
	await _shot(tag + "_01_lc01")

	lab.index = 8
	lab.show_event()
	await create_timer(1.6).timeout
	await _shot(tag + "_02_lc24")

	lab.index = 5
	lab.show_event()
	await create_timer(1.6).timeout
	await _shot(tag + "_03_indoor")

	print("capture done: ", tag)
	quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [OUT, name])
	print("shot ", name)
