extends SceneTree
## 序章与主界面的接线回归：开始人生后先播 OP01，选项进入 OP02，且序章内年龄不变。
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.gc.new_game()
	main.gc.state.line = "normal"
	main.gc.state.age = 0
	main.gc.state.step = 0
	assert(main.gc.begin_opening(), "begin_opening should queue OP01")
	main.render_main()
	await process_frame

	assert(str(main.current_event.get("id", "")) == "OP01", "first screen must be the prologue")
	assert(str(main.current_event.get("title", "")) == "第一声")
	assert(main.current_event.get("choices", []).size() >= 3)
	assert(str(main.current_event.get("stage", "")) == "prologue")

	var picked: Dictionary = main.current_event["choices"][0]
	main._on_choice(picked)
	assert(main._choice_busy)
	assert(main._continue.disabled)
	await create_timer(main._story.duration + 0.4).timeout
	assert(not main._continue.disabled, "story must finish before continue")

	var step_before: int = main.gc.state.step
	main._continue.pressed.emit()
	await process_frame
	assert(str(main.current_event.get("id", "")) == "OP02", "first choice should lead to OP02")
	assert(main.gc.state.step == step_before + 1)
	assert(main.gc.state.age == 0, "prologue must not advance age")
	assert(not main._choice_busy)

	print("PASS: opening UI wiring, choice -> OP02, age held during prologue")
	main.queue_free()
	await process_frame
	quit()
