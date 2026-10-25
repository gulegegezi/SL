extends SceneTree
const World := preload("res://scripts/comic_world.gd")
const PanelView := preload("res://scripts/comic_panel.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	create_timer(20).timeout.connect(func(): push_error("layout timeout"); quit(1))
	var spec := {"ink":"lead_adult","scene":"home","caption":"你拿起手机，听完朋友说的话。窗外下雨了。你决定把今天的烦恼留在今天。","bubble":"明天一起去吃饭吧。","interaction":{"kind":"tap","prop":"phone","reveal":"对方笑了：下次见。"}}
	var previous_height := 0.0
	for width in [320,360,479,480,520]:
		var panel := PanelView.new()
		panel.size = Vector2(width,380)
		root.add_child(panel)
		panel.setup(spec,null)
		for completed in [false,true]:
			panel.interaction_done = completed
			var layout := World.composition(panel.spec,panel.size,completed)
			assert(layout.area.position.y > 42,"dialogue/hint need reserved space")
			assert(layout.foot_y < panel.size.y-World.caption_height(panel.spec,panel.size,completed),"feet must stay above the entire caption including discoveries")
			for target in [false,true]:
				assert(layout.area.encloses(World.interaction_rect(panel,target)),"visible prop and drop target must remain within the unobscured stage")
			var body := Rect2(layout.lead-Vector2(float(layout.height)*0.25,float(layout.height)),Vector2(float(layout.height)*0.50,float(layout.height)))
			for prop in ["phone","drum","letter"]:
				assert(layout.area.encloses(World.settled_object_rect(panel,body,prop)),"completed props must not overlap the caption")
			if not completed and previous_height > 0:
				assert(absf(float(layout.height)-previous_height)<42,"479 to 480px must not change pixel scale or jump character size")
			if not completed: previous_height = layout.height
		panel.queue_free()
	# Explicit casting must survive incidental mentions of other people.
	assert(World.plan({"caption":"朋友把老师的书递给你。","support":"npc_teacher"}).support == "npc_teacher")
	var lab = load("res://scenes/WorldLab.tscn").instantiate()
	root.add_child(lab)
	await process_frame
	lab.playing = false
	lab.sample_at(1.25)
	assert(is_equal_approx(lab.timeline.value,1.25),"scrubber must follow actual playback")
	lab.size = Vector2(360,900)
	lab._layout()
	for panel in lab.panels: assert(panel.position.x+panel.size.x <= 360,"preview must fit narrow windows")
	lab.sample_at(3.2)
	for panel in lab.panels: assert(panel._moment_age == 2.4,"preview and archived settle must use identical times")
	lab.queue_free()
	await process_frame
	print("PASS: five widths, caption/bubble/discovery safe areas, aligned prop/drop targets, continuous scale, explicit casting and preview scrubber")
	quit()
