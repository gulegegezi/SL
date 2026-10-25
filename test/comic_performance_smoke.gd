extends SceneTree
const Plan := preload("res://scripts/comic_performance.gd")
const Art := preload("res://scripts/comic_art.gd")
const ComicPanelClass := preload("res://scripts/comic_panel.gd")
const Beat := preload("res://scripts/beat_director.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(20).timeout.connect(func(): push_error("performance test timeout"); quit(1))
	for text in ["你没有哭。", "他并不害怕。", "她不再难过。", "你笑不出来。", "你没有震惊。"]:
		assert(Plan.direction(text).expr == "normal", "negative emotion: " + text)
	assert(Plan.direction("她忍不住笑了。").expr == "happy")
	assert(Plan.direction("你笑着，心里却很难过。").expr == "sad")
	assert(Plan.direction("如果你哭了呢？").expr == "normal")
	assert(Plan.direction("你没有走出房间。").action == "idle")
	assert(Beat.action_for("你跑了出去，然后停下了。") == "idle")
	assert(Plan.direction("妈妈对你挥手。").actor == "parent")
	assert(Plan.direction("妈妈走进房间，笑了。").actor == "parent")
	assert(Plan.direction("爸爸突然大哭。").actor == "mate", "father uses the existing older male rather than the mother")
	assert(Plan.direction("老板点头，说下周来试试。").actor == "boss")
	assert(Plan.direction("妈妈把水杯放到桌上。").actor == "parent")
	assert(Plan.direction("你给妈妈打电话。").actor == "lead")
	assert(Plan.direction("你走回家，放慢了脚步。").action == "walk")
	assert(Plan.weather_for("你的雨衣挂在走廊。") == "")
	assert(Plan.weather_for("车停了。") == "")
	assert(Plan.weather_for("雨停了。") == "clear")
	assert(Plan.weather_for("雨点落在窗上。") == "rain")
	assert(Plan.direction("你签下合同。").prop == "contract")
	assert(Plan.direction("你合上电脑。").action == "poweroff")
	var asleep := Plan.panel({"caption":"你睡着了，窗外传来雨声。"})
	assert(asleep.performance[-1].expr == "sleep", "unrelated narration must not reopen sleeping eyes")
	var phone := Plan.panel({"caption":"你拿起手机，微笑着。"})
	assert(phone.performance[-1].prop == "phone", "a held prop should not vanish in the next clause")
	var put_down := Plan.panel({"caption":"你拿起手机，又放下了。"})
	assert(put_down.performance[-1].prop == "", "putting down a prop must clear it")
	var overridden := Plan.panel({"caption": "你暴怒地吼叫。", "expr": "happy", "actor": "teacher", "intensity": 0})
	assert(overridden.performance[0].expr == "happy" and overridden.performance[0].actor == "teacher" and overridden.performance[0].sfx == "")
	var scene := Plan.panel({"caption": "你震惊得呆住了。", "ink": "lead_adult", "shot": "detail"})
	assert(scene.shot == "extreme")
	var leave := Plan.panel({"caption": "你跑了出去。"})
	assert(leave.performance[0].exit)
	var count := 0
	for key in ["infant_infant","lead_child","lead_teen","lead_youth","lead_adult","lead_middle","lead_elder","npc_parent","npc_friend","npc_teacher","npc_boss","npc_partner","npc_mate"]:
		var regions: Array = []
		for expression in ["happy","cry","angry","shock","panic","sleep"]:
			var texture := Art.portrait(key,0,expression) as AtlasTexture
			assert(texture != null and Rect2(Vector2.ZERO,texture.atlas.get_size()).encloses(texture.region))
			assert(not regions.has(texture.region), "expressions need different source regions")
			regions.append(texture.region)
			count += 1
	var panel := ComicPanelClass.new()
	panel.size = Vector2(480,300)
	root.add_child(panel)
	var text := "你微笑着，妈妈突然大哭起来。"
	panel.setup({"caption": text,"ink":"lead_adult","shot":"medium"},Art.portrait("lead_adult",0))
	panel.set_revealed(false)
	panel.set_revealed(true)
	var saw_happy := false
	var saw_parent_cry := false
	for i in range(300):
		panel._process(0.025)
		if str(panel.current_direction.get("expr","")) == "happy": saw_happy = true
		if str(panel.current_direction.get("expr","")) == "cry":
			assert(panel.visible_characters >= text.find("大哭"), "face must not anticipate a future clause")
			assert(panel.current_direction.actor == "parent", "mother must react, not the protagonist")
			saw_parent_cry = true
	assert(saw_happy and saw_parent_cry and panel.impact_count == 1, str([saw_happy,saw_parent_cry,panel.impact_count,panel.visible_characters,panel.moments]))
	assert(panel.visible_characters == text.length())
	panel.finish_reveal()
	assert(panel.visible_characters == text.length() and panel._impact_left == 0)
	panel.setup({"caption":"你睡着了。","ink":"lead_adult"},Art.portrait("lead_adult",0))
	assert(panel.current_direction.expr == "sleep" and panel.current_direction.prop == "bed")
	panel.queue_free()
	await process_frame
	print("PASS: ", count, " real expression regions, negation/contrast/subjects/props, timed reactions, exactly one impact")
	quit()
