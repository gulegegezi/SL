extends SceneTree
const Controller := preload("res://scripts/game_controller.gd")
const State := preload("res://scripts/game_state.gd")
const Archive := preload("res://scripts/comic_archive.gd")
const Pace := preload("res://scripts/short_life.gd")
const Director := preload("res://scripts/comic_director.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	preload("res://scripts/save_manager.gd").writes_enabled = false
	var all: Array = Pace.data().events.duplicate()
	all.append_array(Pace.data().nodes.values())
	var choices := 0
	for event in all:
		assert(event.comic.size() == 3 and event.choices.size() == 3)
		assert(event.comic[1].interaction.kind in ["tap","drag","hold","reveal"])
		for choice in event.choices:
			choices += 1
			assert(not choice.result.is_empty() and choice.comic.size() >= 2)
			var result_lines := ""
			for panel in choice.comic: result_lines += str(panel.caption)
			assert(result_lines == str(choice.result),"result storyboard must retain every sentence")
			if choice.has("next"): assert(not Pace.node(str(choice.next)).is_empty())
	var counts: Array = []
	for policy in range(3):
		for seed_value in range(8):
			var gc := Controller.new()
			gc.init()
			gc.rng.seed = seed_value
			gc.new_game()
			assert(gc.state.short_mode and not gc.begin_opening())
			gc.state.age = 1
			gc.state.health = 14
			gc.state.lifespan = 92
			var steps := 0
			while gc.state.age < gc.state.lifespan and gc.state.health > 0 and steps < 32:
				var event := gc.pick_event()
				assert(not event.is_empty(), "no gaps in short route")
				assert(not gc.state.used_ids.has(str(event.id)), "no repeated milestone")
				var spec := Director.build(gc.state,event,{},gc.rng,steps+1)
				assert(spec.panels.size() in [3,4])
				if int(event.age) == 0: assert(not event.has("jump_from"),"same-age followup is not a new time jump")
				for panel in spec.panels: assert(not str(panel.get("caption","")).contains("{choice:"))
				var selected: Dictionary = event.choices[policy]
				gc.choose(selected,event)
				var queued := not gc.state.story_queue.is_empty()
				var age := gc.state.age
				gc.advance_after_choice(event)
				assert(gc.state.age == age if queued else gc.state.age > age)
				if str(event.id) == "SL18" and policy == 2: assert(gc.state.age == 27)
				steps += 1
			assert(steps >= 14 and steps <= 20, "short route decision budget: " + str(steps))
			counts.append(steps)
	var state := State.new()
	state.short_mode = true
	state.short_previous_age = 18
	state.short_target_age = 27
	var restored := State.new()
	Archive.restore_state(restored,Archive.state_data(state))
	assert(restored.short_mode and restored.short_target_age == 27 and restored.short_previous_age == 18)
	var legacy := State.new()
	Archive.restore_state(legacy,{"age":37})
	assert(not legacy.short_mode, "old bookmarks retain their original event line")
	print("PASS: ",all.size()," authored scenes / ",choices," choices; 24 complete short lives, decision counts: ",counts,"; same-age branches, skip-to-work, memory and save compatibility")
	quit()
