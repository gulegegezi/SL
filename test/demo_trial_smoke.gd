extends SceneTree
## 经典 Demo 移植回归：序章分支 → 人生池 → 结算，整条链路可从头玩到尾。
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var demo = load("res://scenes/DemoTrial.tscn").instantiate()
	root.add_child(demo)
	await process_frame
	assert(demo.phase == "prologue", "demo should start in the prologue")
	assert(str(demo.current_event.get("id", "")) == "OP01", "prologue should start at OP01")
	assert(demo.stage != null)

	var guard := 0
	while not demo.ended and guard < 1200:
		var stage = demo.stage
		var steps := 0
		while not stage.in_choices and steps < 40:
			stage.advance()
			steps += 1
		assert(stage.in_choices, "every scene should reach choices")
		stage.confirm()
		await process_frame
		guard += 1

	assert(demo.ended, "demo should reach the ending")
	assert(guard < 1200)
	assert(demo.summary.visible, "ending summary should be visible")
	assert(demo.summary.text.contains("综合分"), "summary should show a score")
	assert(demo.turn <= 34, "life pool should cap at 34 turns")

	print("PASS: classic demo prologue -> life pool -> ending, %d choices" % guard)
	demo.queue_free()
	await process_frame
	quit()
