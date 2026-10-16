extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.gc.new_game()
	main.gc.state.age = 10
	main.render_main()
	await process_frame
	assert(main.anim_stage.size.y >= 300)
	var stage = main._story
	for mode in stage.TITLES:
		stage.play({}, {"story": mode, "result": "小人正在演绎选择后的故事。"}, [])
		await create_timer(0.12).timeout
		assert(stage.mode == mode)
	assert(stage.resolve({}, {"label": "去跑步", "result": "身体更健康"}, []) == "sport")
	assert(stage.resolve({}, {"label": "休息", "result": "停止加班"}, []) == "rest")
	assert(stage.resolve({}, {"label": "努力学习"}, []) == "study")
	var before: int = main.gc.state.money
	var choice := {"label": "去工作", "result": "你完成了工作，挣到了第一笔钱。", "effects": {"money": 5}}
	main._on_choice(choice)
	main._on_choice(choice)
	assert(main.gc.state.money == before + 5)
	assert(main._continue.disabled)
	await create_timer(main._story.duration + 0.3).timeout
	assert(not main._continue.disabled)
	assert(main.gc.state.age == 10)
	# 在真实渲染模式下保存当前 UI。
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/story-stage-preview.png")
	main._continue.pressed.emit()
	assert(main.gc.state.age > 10)
	assert(not main._choice_busy)
	print("PASS: all story modes, semantic routing, duplicate-choice guard, completion gate, next event")
	main.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	quit()
