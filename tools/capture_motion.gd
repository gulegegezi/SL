extends SceneTree
## 动作模组连拍：找一个带互动的场景，点一次互动，每 0.18s 截一帧。

var out_dir := "D:/gamelife/_motion_frames"
var lab


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()


func _run() -> void:
	root.size = Vector2i(520, 900)
	root.content_scale_size = Vector2i(520, 900)
	lab = (load("res://scenes/PixelStageLab.tscn") as PackedScene).instantiate()
	root.add_child(lab)
	await create_timer(1.0).timeout

	# 找一个「成年人 + 带互动」的场景，才能看清走位
	var found := false
	for i in range(9):
		lab.index = i
		lab.show_event()
		await create_timer(0.35).timeout
		if lab.panel != null and lab.panel.spec.has("pixel_interaction") and int(lab.panel.spec.get("age", 0)) >= 12:
			found = true
			break
	if not found:
		print("no interaction event")
		quit()
		return
	print("interaction event: ", lab.panel.spec.get("pixel_interaction", {}).get("label", ""))

	lab.panel.pixel_stage.perform_interaction()
	for f in range(13):
		await create_timer(0.15).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/frame_%d.png" % [out_dir, f])
		print("frame ", f)
	quit()
