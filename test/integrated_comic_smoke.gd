extends SceneTree
const Run := preload("res://scripts/life_comic_run.gd")
const Pages := preload("res://scripts/life_comic_pages.gd")
var failures := 0
func check(value: bool, message: String) -> void:
	if not value: failures += 1; push_error(message)
func _initialize() -> void:
	call_deferred("run_test")
func run_test() -> void:
	var run = Run.new()
	run.start(42)
	check(run.pack.events.size() == 34, "34 authored comic events")
	check(Run.Legacy.catalog().size() >= 270, "legacy events and continuation nodes imported")
	check(run.s.legacy.has("family") and run.s.legacy.has("talent"), "birth profile initialized")
	var rendered := 0
	for id in Run.Legacy.catalog():
		var r = Run.new(); r.start(42)
		var e: Dictionary = r.events[id]
		r.s.age = maxi(18, int(e.age_range[0])); r.s.pending = {}; r.begin(id)
		for tag in e.get("cond", {}).get("tags", []): r.s.flags.append(tag)
		if r.options().is_empty(): continue
		check(not Pages.make(r).panels.is_empty(), "legacy opening: "+id)
		var saved: Dictionary = r.snapshot()
		for option in range(r.options().size()):
			var branch = Run.new(); branch.restore(saved)
			var result: Dictionary = branch.choose(option)
			check(not result.is_empty() and not Pages.make(branch, true).panels.is_empty(), "legacy result: "+id)
			var next := str(result.get("next", ""))
			check(next.is_empty() or branch.events.has(next) or branch.arcs.has(next), "continuation target exists: "+next)
		rendered += 1
	check(rendered >= 270, "full imported catalogue is renderable")
	var linked = Run.new(); linked.start(77)
	linked.s.age = 8; linked.s.pending = {}; linked.begin("EX:V01")
	linked.choose(0); linked.finish()
	check("_同桌_初识" in linked.s.flags, "cross-age story tag retained")
	check(Run.Legacy.fill(linked, "{choice:V01}").contains("橡皮"), "cross-age memory retained")
	check(not Run.Legacy.matches(linked, {"tags":["_不存在"]}), "story prerequisites enforced")
	var prologue = Run.new(); prologue.start(8); prologue.s.pending = {}; prologue.begin(Run.Legacy.opening_id(prologue))
	var opening_steps := 0
	while str(prologue.s.pending.get("id", "")).begins_with("EX:OP") and opening_steps < 30:
		check(not prologue.options().is_empty(), "prologue never loses choices")
		prologue.choose(0); prologue.finish(); opening_steps += 1
	check(opening_steps > 2 and opening_steps < 30 and prologue.s.pending.get("id") == "LC02", "birth prologue rejoins comic childhood")
	var encountered := {}
	for seed_value in range(30):
		var life = Run.new(); life.start(seed_value)
		var steps := 0
		while life.s.terminal.is_empty() and steps < 200:
			check(not life.s.pending.is_empty() and not life.options().is_empty(), "no stalled life")
			if life.options().is_empty(): break
			encountered[life.s.pending.id] = true
			var restored = Run.new(); restored.restore(life.snapshot())
			var index: int = steps % life.options().size()
			check(life.choose(index) == restored.choose(index), "save restores actual outcome")
			life.finish(); restored.finish()
			check(life.snapshot() == restored.snapshot(), "save restores subsequent fate")
			steps += 1
		check(steps < 200 and not life.s.terminal.is_empty(), "integrated life reaches ending")
	check(encountered.keys().any(func(id): return str(id).begins_with("EX:")), "interludes appear in real lives")
	print("INTEGRATED_COMIC_SMOKE ", "PASS" if failures == 0 else "FAIL", " · catalogue=", rendered, " · encountered=", encountered.size())
	quit(0 if failures == 0 else 1)
