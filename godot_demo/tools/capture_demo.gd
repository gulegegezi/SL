extends SceneTree
## 开发用截图工具：把 DemoTrial 跑到关键节拍并保存 PNG。
## 用法：godot --path godot_demo --script res://tools/capture_demo.gd -- <输出目录>

var out_dir := "res://docs/_shots"
var demo
var stage


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()


func _run() -> void:
	demo = (load("res://scenes/DemoTrial.tscn") as PackedScene).instantiate()
	root.add_child(demo)
	await _wait(0.25)

	await _reveal_all()
	await _shot("01_open")

	# 推到第一个选项
	await _advance_until_choices(24)
	await _shot("02_choice")

	# 选第一个选项 → 结果镜头（letterbox + flash + 反应对白）
	stage.confirm()
	await _wait(0.55)
	await _reveal_all()
	await _shot("03_result")

	# 走完序章，进入人生池
	var guard := 0
	while demo.phase != "life" and guard < 40:
		guard += 1
		if stage.in_choices:
			stage.confirm()
			await _wait(0.45)
		await _reveal_all()
		await _advance_until_choices(12)
		if demo.phase == "life":
			break

	await _reveal_all()
	await _shot("04_life")

	# 再推进几幕，截一张中段
	for _i in range(3):
		if stage.in_choices:
			stage.confirm()
			await _wait(0.45)
		await _reveal_all()
		await _advance_until_choices(12)
	await _reveal_all()
	await _shot("05_life_mid")

	# 直接结算，验证结算页排版
	demo._end_demo()
	await _wait(0.4)
	await _shot("06_end")

	print("capture done -> ", out_dir)
	quit()


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _reveal_all() -> void:
	## 把当前节拍的逐字补完，再等一帧让 _draw 跟上。
	if stage == null:
		stage = demo.stage
	for _i in range(12):
		if stage.in_choices or stage.beat_index < 0:
			break
		var total: int = stage._display_text().length()
		if stage.visible_chars >= total:
			break
		stage.advance()
		await process_frame
	await process_frame


func _advance_until_choices(max_steps: int) -> void:
	for _i in range(max_steps):
		if stage.in_choices:
			return
		stage.advance()
		await process_frame
		await _reveal_all()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, name]
	var err := img.save_png(path)
	if err != OK:
		push_error("save_png failed: %s (%d)" % [path, err])
	else:
		print("shot: ", path)
