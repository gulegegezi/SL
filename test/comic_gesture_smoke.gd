extends SceneTree
const Gesture := preload("res://scripts/comic_gesture.gd")
const Art := preload("res://scripts/comic_art.gd")
const World := preload("res://scripts/comic_world.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var identities := ["lead_child","lead_teen","lead_youth","lead_adult","lead_middle","lead_elder","npc_parent","npc_friend","npc_teacher","npc_boss","npc_partner","npc_mate"]
	for key in identities:
		var distinct := {}
		for i in range(4):
			var frame := Art.ensemble_frame(key,i)
			assert(frame != null,"all twelve identities require matching whole-body poses")
			assert(frame.region.size.y>frame.region.size.x,"must include complete body rather than a bust")
			assert(Rect2(Vector2.ZERO,frame.atlas.get_size()).encloses(frame.region))
			assert(not distinct.has(frame.region))
			distinct[frame.region] = true
			var sampled := World.pixel_texture(frame,64)
			assert(sampled.get_height()==64,"all actors must use the same source pixel density")
	assert(Gesture.sample("receive",0.1).frame==0)
	assert(Gesture.sample("receive",0.35).frame==1)
	assert(Gesture.sample("receive",1.0).frame==2)
	assert(Gesture.sample("wave",1.0).frame==3)
	assert(Gesture.sample("idle",2.4).frame==0,"idle must never use a walking stride")
	assert(not Gesture.sample("receive",0.35).contact and Gesture.sample("receive",0.8).contact)
	for action in Gesture.ACTIVE:
		var settled := Gesture.sample(action,0,true)
		assert(settled == Gesture.sample(action,2.4,true))
		assert(settled.angle==0 and settled.offset==Vector2.ZERO,"reduced motion and archive must be still")
	assert(Gesture.response("performance","drum",0.3).time == 0)
	assert(Gesture.response("performance","drum",1.3).time > 0.6,"audience responds after the action")
	assert(Gesture.response("gift","receive",0.3).time > 0.3,"giver anticipates receiver")
	print("PASS: 48 matching full-body poses, uniform pixel density, distinct anticipation/contact/reaction, stationary idle and deterministic archive")
	quit()
