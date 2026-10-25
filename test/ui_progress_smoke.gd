extends SceneTree
## 使用真实鼠标事件回归，而非直接调用按钮回调。
var main

func _initialize() -> void:
	call_deferred("run")

func click(button: Button) -> void:
	var pos := button.get_global_rect().get_center()
	assert(root.get_visible_rect().has_point(pos), "button is outside viewport")
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	root.push_input(motion, true)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = pos
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func run() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	# 独立运行态，避免测试修改玩家的局数或结局存档。
	main.gc.state = main.GameState.new()
	# 4 岁：避开带过场的前三岁事件（C33/C34），本测试只验证按钮布局与继续按钮。
	main.gc.state.age = 4
	main.gc.state.health = 20
	main.gc.state.line = "normal"
	main.gc.state.family = {"name": "长文本回归", "desc": "这是一段用于测试滚动布局的童年故事。".repeat(12)}
	var scroll: ScrollContainer = main.get_node("MarginContainer/ScrollContainer")
	for dims in [Vector2i(520, 900), Vector2i(520, 640), Vector2i(360, 640)]:
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
		root.content_scale_size = dims
		root.size = dims
		main.render_main()
		await create_timer(0.8).timeout
		var chosen: Button
		for node in main.screen.get_children():
			if node is VBoxContainer:
				for child in node.get_children():
					if child is Button and not child.disabled:
						chosen = child
						break
		assert(chosen != null)
		scroll.ensure_control_visible(chosen)
		await process_frame
		await click(chosen)
		assert(main._choice_busy and main._story.playing)
		assert(main._continue.disabled)
		# 第一轮实际等待完整播放，之后覆盖小窗口下完成信号和点击。
		if dims.y == 900:
			await create_timer(main._story.duration + 0.3).timeout
		else:
			assert(root.get_visible_rect().encloses(main._next_dialogue.get_global_rect()))
			for i in range(8):
				if not main._story.playing: break
				await click(main._next_dialogue)
			assert(not main._story.playing)
		await process_frame
		assert(not main._continue.disabled)
		var rect: Rect2 = main._continue.get_global_rect()
		assert(root.get_visible_rect().encloses(rect), "continue must be completely visible")
		var age_before: int = main.gc.state.age
		var step_before: int = main.gc.state.step
		# 本次选项是否把剧情接到下一幕；接的话年龄先不涨，等后续节点播完再涨。
		var chained := false
		if main.current_choice.has("next"):
			chained = not main.gc._resolve_next(main.current_choice["next"]).is_empty()
		if not chained and main.current_event.has("next"):
			chained = not main.gc._resolve_next(main.current_event["next"]).is_empty()
		await click(main._continue)
		if chained:
			assert(main.gc.state.age == age_before, "chained story should keep age")
		else:
			assert(main.gc.state.age > age_before)
		assert(main.gc.state.step == step_before + 1)
		assert(not main._choice_busy)
		assert(not main._action_bar.visible)
		assert(scroll.scroll_vertical == 0)
		print("PASS actual mouse choice -> story -> visible continue -> next event: ", dims)
	main.queue_free()
	await process_frame
	quit()
