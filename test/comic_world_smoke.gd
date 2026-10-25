extends SceneTree
const World := preload("res://scripts/comic_world.gd")
const Art := preload("res://scripts/comic_art.gd")
const PanelView := preload("res://scripts/comic_panel.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	create_timer(30).timeout.connect(func(): push_error("world scene timeout"); quit(1))
	# Atlas regions share the source GPU texture: their rendered identities must remain separate.
	var parent := World.pixel_texture(Art.portrait("npc_parent",0),28)
	var boss := World.pixel_texture(Art.portrait("npc_boss",0),28)
	assert(parent != boss and parent.get_image().get_data() != boss.get_image().get_data(),"NPC atlas regions must not alias")
	var child := World.pixel_texture(Art.walk_frame("lead_child",0),64)
	var adult := World.pixel_texture(Art.walk_frame("lead_adult",0),64)
	assert(child != adult and child.get_image().get_data() != adult.get_image().get_data(),"life stages must remain visually distinct")
	var next_frame := World.pixel_texture(Art.walk_frame("lead_adult",1),64)
	assert(next_frame.get_image().get_data() != adult.get_image().get_data(),"walking must retain actual source frame differences")
	assert(not World.enabled({"ink":""}),"empty future panels must stay empty")
	var lab = load("res://scenes/WorldLab.tscn").instantiate()
	root.add_child(lab)
	await process_frame
	lab.playing = false
	for i in range(6):
		lab.select(i)
		for time in [0.0,0.65,1.25,2.4]:
			lab.sample_at(time)
			await process_frame
			for panel in lab.panels:
				panel.queue_redraw()
				assert(World.enabled(panel.spec))
				assert(not World.plan(panel.spec).support.is_empty())
	# Loading a historical panel must show the settled scene, never start an entrance again.
	var view := PanelView.new()
	view.size = Vector2(340,280)
	view.setup({"ink":"lead_adult","caption":"你离开公园，朋友站在原地。","scene":"park","action":"walk"},null)
	root.add_child(view)
	assert(is_equal_approx(view._moment_age,2.4) and not view.is_processing())
	view.reduced_motion = true
	assert(World.pose("walk",0,true).progress == 1.0)
	view.queue_free()
	lab.queue_free()
	await process_frame
	print("PASS: atlas identity, age/frame distinction, six ensemble storyboards, settled archive and reduced motion")
	quit()
