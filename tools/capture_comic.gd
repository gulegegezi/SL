extends SceneTree
## 开发用：进游戏 → 掷骰 → 开始这一生 → 截漫画页 → 选一个 → 截结果页。

var out_dir := "D:/gamelife/_shots_comic"
var main: Control


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()


func _run() -> void:
	main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _wait(0.4)
	await _shot("01_title")

	_press("开始人生")
	await _wait(1.2)
	await _shot("02_roll")

	# 等掷骰动画结束，出现「开始这一生」
	for _i in range(120):
		if _find_button("开始这一生") != null:
			break
		await _wait(0.2)
	await _shot("03_birth")

	_press("开始这一生")
	await _wait(1.2)
	await _shot("04_page")

	# 点第一个正常选项
	var choice := _first_choice_button()
	if choice != null:
		choice.emit_signal("pressed")
		# 新一页刚放上去：分格还空着，正在被一格一格填
		await _wait(0.18)
		await _shot("05_filling")
		await _wait(1.0)
		await _shot("05_result")

	# 再往后翻两页，看看不同版式
	_press("继续")
	await _wait(1.6)
	await _shot("06_next")
	_press("继续")
	await _wait(1.6)
	await _shot("07_next2")

	print("capture done -> ", out_dir)
	quit()


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var err := img.save_png("%s/%s.png" % [out_dir, name])
	print("shot ", name, " err=", err)


func _walk(n: Node, out: Array) -> void:
	if n is Button:
		out.append(n)
	for c in n.get_children():
		_walk(c, out)


func _buttons() -> Array:
	var out: Array = []
	_walk(main, out)
	return out


func _find_button(want: String) -> Button:
	for b in _buttons():
		var t := str(b.text).replace(" ", "")
		if t.contains(want.replace(" ", "")):
			return b
	return null


func _first_choice_button() -> Button:
	for b in _buttons():
		var t := str(b.text).replace(" ", "")
		if t.is_empty() or t.contains("继续") or t.contains("重开"):
			continue
		if t.contains("结局图鉴") or t.contains("成就") or t.contains("开始"):
			continue
		return b
	return null


func _press(want: String) -> bool:
	var b := _find_button(want)
	if b == null:
		print("button not found: ", want)
		return false
	b.emit_signal("pressed")
	return true
