extends SceneTree
const Motion := preload("res://scripts/comic_motion.gd")
const Art := preload("res://scripts/comic_art.gd")
const View := preload("res://scripts/comic_panel.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	create_timer(15).timeout.connect(func(): push_error("motion test timeout"); quit(1))
	var count := 0
	for key in ["infant_infant","lead_child","lead_teen","lead_youth","lead_adult","lead_middle","lead_elder","npc_parent","npc_friend","npc_teacher","npc_boss","npc_partner","npc_mate"]:
		var seen: Array = []
		for action in ["reach","read","phone","sign"]:
			var texture := Art.action_pose(key,action) as AtlasTexture
			assert(texture != null and Rect2(Vector2.ZERO,texture.atlas.get_size()).encloses(texture.region))
			assert(not seen.has(texture.region),"body actions must have different actual source regions")
			seen.append(texture.region)
			count += 1
	for action in Motion.NAMED:
		assert(Motion.sample(action,0.1).phase == "anticipation")
		assert(Motion.sample(action,0.5).phase == "reach")
		assert(Motion.sample(action,1.2).phase == "contact")
		assert(Motion.sample(action,2.4).phase == "settle")
		assert(Motion.sample(action,0.1,true) == Motion.sample(action,2.4,true))
	var walk_count := 0
	for key in ["lead_child","lead_teen","lead_youth","lead_adult","lead_middle","lead_elder"]:
		for index in range(4):
			var texture := Art.walk_frame(key,index) as AtlasTexture
			assert(texture != null and Rect2(Vector2.ZERO,texture.atlas.get_size()).encloses(texture.region))
			assert(texture.region.size.y > texture.region.size.x,"walking assets must show a full body")
			walk_count += 1
	assert(Motion.sample("phone",0.1).pose == 0 and Motion.sample("phone",1).pose == 1)
	assert(Motion.sample("sign",1.1).stroke != Motion.sample("sign",1.3).stroke)
	assert(Motion.sample("sign",1.0).work < Motion.sample("sign",1.6).work)
	var view := View.new()
	root.add_child(view)
	view.size = Vector2(490,380)
	view.setup({"caption":"你拿起手机，举到耳边。","ink":"lead_adult","action":"phone","prop":"phone","shot":"medium","shot_locked":true},null)
	view.set_revealed(false)
	view.set_revealed(true)
	for i in range(400): view._process(0.025)
	assert(view.visible_characters == view._full_text.length() and not view.is_processing())
	view.setup({"caption":"你拿起手机，窗外下雨了。","ink":"lead_adult","shot":"medium","shot_locked":true},null)
	view.set_revealed(false)
	view.set_revealed(true)
	var previous_time := 0.0
	for i in range(200):
		view._process(0.025)
		assert(view._moment_age >= previous_time,"same held action must not restart at a weather clause")
		previous_time = view._moment_age
	view.setup({"caption":"你签字，然后走出房间。","ink":"lead_adult","shot":"medium","shot_locked":true},null)
	view.set_revealed(false)
	view.set_revealed(true)
	var sign_duration := 0.0
	for i in range(250):
		if str(view.current_direction.get("action","")) == "sign": sign_duration = view._moment_age
		view._process(0.025)
	assert(sign_duration >= 1.7,"writing should reach paper contact before moving to departure")
	view.setup({"caption":"你伸手接过玩具。","ink":"lead_child","interaction":{"kind":"drag","prop":"toy"},"interaction_progress":{"completed":true}},null)
	assert(view._interaction_clock == Motion.DURATION,"saved interactions must load at settled action, not restart")
	view.set_revealed(false)
	view.set_revealed(true)
	assert(view._interaction_clock == Motion.DURATION)
	view.queue_free()
	await process_frame
	var lab = load("res://scenes/ActingLab.tscn").instantiate()
	root.add_child(lab)
	await process_frame
	lab.sample_at(Motion.DURATION+0.6)
	lab._process(0.2)
	assert(lab.clock < 0.1,"preview loop must pass the settled hold and restart")
	lab.queue_free()
	await process_frame
	print("PASS: ",count," distinct body poses + ",walk_count," full-body walking frames; anticipation/contact/settle, progressive strokes, settled saves, reduced motion and preview loop")
	quit()
