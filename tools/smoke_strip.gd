extends SceneTree
## 漫画流冒烟：一路点到结局，检查追加/滚动/空白位没有报错。

var main: Control
var pages := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await create_timer(0.3).timeout
	_press("开始人生")
	await create_timer(1.0).timeout
	for _i in range(80):
		if _find("开始这一生") != null:
			break
		await create_timer(0.2).timeout
	_press("开始这一生")
	await create_timer(0.8).timeout

	var guard := 0
	while guard < 120:
		guard += 1
		var btn := _find("继续")
		if btn != null:
			btn.emit_signal("pressed")
			pages += 1
			await create_timer(0.35).timeout
			continue
		var choice := _first_choice()
		if choice != null:
			choice.emit_signal("pressed")
			await create_timer(0.35).timeout
			continue
		# 可能已经到结局
		if main.get("screen") != null and main.screen.get_child_count() > 0:
			await create_timer(0.2).timeout
			continue
		break
	print("strip smoke: pages=", pages, " children=", main.screen.get_child_count())
	quit()


func _walk(n: Node, out: Array) -> void:
	if n is Button:
		out.append(n)
	for c in n.get_children():
		_walk(c, out)


func _find(want: String) -> Button:
	var out: Array = []
	_walk(main, out)
	for b in out:
		if str(b.text).replace(" ", "").contains(want) and b.visible:
			return b
	return null


func _first_choice() -> Button:
	var out: Array = []
	_walk(main, out)
	for b in out:
		var t := str(b.text).replace(" ", "")
		if not b.visible or t.is_empty() or t.contains("继续"):
			continue
		if t.begins_with("▶"):
			return b
	return null


func _press(want: String) -> bool:
	var b := _find(want)
	if b == null:
		return false
	b.emit_signal("pressed")
	return true
