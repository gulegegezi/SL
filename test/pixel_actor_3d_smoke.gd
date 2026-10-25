extends SceneTree
const Actor = preload("res://scripts/pixel_actor_3d.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var keys := ["infant_infant", "lead_child", "lead_teen", "lead_youth", "lead_adult", "lead_middle", "lead_elder", "npc_parent", "npc_mate", "npc_friend", "npc_teacher", "npc_boss", "npc_partner"]
	var ages := [1, 5, 10, 16, 28, 52, 75, 38, 44, 29, 40, 50, 30]
	var actions := ["idle", "walk", "run", "give", "offer", "receive", "read", "phone", "wave", "celebrate", "drum", "type", "sign", "sit", "sleep", "nod", "put_down", "eat", "talk", "sad", "shock"]
	for i in range(keys.size()):
		var actor = Actor.new()
		root.add_child(actor)
		actor.setup(keys[i], ages[i], {"ink":"#233a42", "amber":Color("d4a35f")})
		actor.position = Vector3(3, 0, -2)
		actor.rotation.y = 0.7
		var original: Vector3 = actor.position
		assert(actor.hand_anchor != null)
		for action in actions:
			for time in [0.0, 0.18, 0.7, 1.5, 4.0]:
				actor.pose(action, time, true, false)
				assert(actor.position == original, "Animation must not change staging position")
				assert(is_equal_approx(actor.rotation.y, 0.7), "Animation must preserve staging facing")
				assert(actor.hand_anchor.global_position.is_finite())
				actor.pose(action, time, true, true)
		actor.pose("offer", 1.0)
		var offer_hand: Vector3 = actor.hand_anchor.position
		assert(offer_hand.is_finite())
		assert(actor._arms[1].rotation.x < -0.5, "Offer needs a real articulated reach")
		actor.pose("read", 1.0)
		if not actor.is_newborn:
			assert(actor._elbows[0].rotation.x < -0.9, "Book pose folds both elbows")
		for sample in range(20):
			actor.pose("walk", float(sample) * 0.11)
			if actor.is_newborn:
				assert(absf(actor._head.rotation.x + PI * 0.5) < 0.02, "Newborn stays lying even for walk cues")
				assert(actor.height < 0.4, "Newborn height describes mattress contact")
				continue
			var sole_y: float = INF
			for leg_index in range(2):
				for toe in [-0.1125, 0.2225]:
					var foot: Vector3 = actor._legs[leg_index].transform * (actor._knees[leg_index].transform * Vector3(0, -0.43, toe))
					sole_y = minf(sole_y, actor._hips.position.y + foot.y)
			assert(absf(sole_y) < 0.0001, "One support foot must stay planted")
		actor.setup(keys[i], ages[i])
		assert(actor.get_child_count() == 1, "Setup must not duplicate the skeleton")
		actor.free()
	print("PASS pixel_actor_3d: 13 identities; 21 articulated actions; reduced motion; stable floor origin; reusable setup")
	quit()
