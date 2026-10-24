extends SceneTree
const Run := preload("res://scripts/life_comic_run.gd")
const Pages := preload("res://scripts/life_comic_pages.gd")
var failures := 0
func check(value: bool, text: String) -> void:
	if not value:
		failures += 1
		push_error(text)
func _initialize() -> void:
	call_deferred("run_tests")
func run_tests() -> void:
	var a = Run.new()
	a.start(42)
	check(a.events.size() == 24,"24 authored events loaded")
	check(a.options().size() == 3,"birth has three choices")
	check(Pages.make(a).panels.size() >= 3,"separate setup, NPC dialogue and narrator invitation")
	var b = Run.new()
	check(b.restore(a.snapshot()),"restore pending choice")
	var result: Dictionary = a.choose(1).duplicate(true)
	check(result == b.choose(1),"save before choice preserves random outcome")
	var scores: Dictionary = a.s.scores.duplicate(true)
	a.choose(2)
	check(a.s.scores == scores and a.s.committed == result,"double click cannot settle twice")
	check(Pages.make(a,true).panels.size() == 3,"three authored result panels")
	check(a.save("user://life_comic_test.save"),"atomic native save")
	check(b.load_save("user://life_comic_test.save"),"native disk save loaded")
	a.finish(); b.finish()
	check(a.snapshot() == b.snapshot(),"save after choice preserves next age, NPCs, events and RNG")
	var rare = Run.new()
	rare.start(17)
	rare.s.pending = {}; rare.begin("RX01")
	check(rare.options().size() > 0,"diagnostic scene has choices")
	rare.choose(0); rare.finish()
	check(not rare.s.pending.is_empty(),"rare scene returns to pool or queues followup")
	for key in rare.arcs:
		for option in range(rare.arcs[key].options.size()):
			var scene_run = Run.new(); scene_run.start(51+option)
			scene_run.s.pending = {}; scene_run.begin(key,{"lost_role":"parent"})
			check(not Pages.make(scene_run).panels.is_empty(),"all rare scene openings render")
			scene_run.choose(option)
			check(not Pages.make(scene_run,true).panels.is_empty(),"all rare options render")
			scene_run.finish()
	var rejected = a.snapshot()
	rejected.rng.erase("mortality")
	check(not b.restore(rejected),"incomplete save rejected without changing state")
	for seed_value in range(80):
		var life = Run.new()
		life.start(seed_value)
		var steps := 0
		while life.s.terminal.is_empty() and steps < 200:
			check(not life.s.pending.is_empty(),"life never stalls without an event")
			var event: Dictionary = life.source()
			if event.has("age_range"):
				check(life.s.age >= event.age_range[0] and life.s.age <= event.age_range[1],"age window respected")
				for role in event.cast_bindings.values():
					if role != "lead": check(life.s.roles[role].alive,"dead NPC never returns on stage")
			check(not Pages.make(life).panels.is_empty(),"opening panel adapter")
			life.choose(steps%life.options().size())
			check(not Pages.make(life,true).panels.is_empty(),"result panel adapter")
			life.finish()
			steps += 1
		check(steps < 200 and not life.s.terminal.is_empty(),"life reaches a terminal without looping")
		check(life.choose(0).is_empty(),"no postmortem choices")
		check(not Pages.ending(life).panels.is_empty(),"ending renders")
	# The narrative lens cannot reroll actual life events.
	for seed_value in range(20):
		var low = Run.new(); low.start(seed_value)
		var high = Run.new(); high.restore(low.snapshot())
		low.s.scores.abstract = 0; high.s.scores.abstract = 100
		while low.s.terminal.is_empty():
			check(low.s.pending.id == high.s.pending.id and low.s.age == high.s.age,"tiers retain same event and age")
			check(low.choose(0).facts == high.choose(0).facts,"tiers retain same random facts")
			low.finish(); high.finish()
		check(low.s.terminal.cause == high.s.terminal.cause and low.s.age == high.s.age,"tiers do not change lifespan")
	print("LIFE_COMIC_SMOKE ","PASS" if failures == 0 else "FAIL", " · 80 complete lives / 20 paired lenses / native save roundtrip")
	quit(0 if failures == 0 else 1)
