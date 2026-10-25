extends SceneTree
## 核心引擎边界回归：事件通知、成就条件、缓存查找与空权重。

const Controller := preload("res://scripts/game_controller.gd")
const Data := preload("res://scripts/data_loader.gd")
const Run := preload("res://scripts/life_comic_run.gd")
const Saves := preload("res://scripts/save_manager.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	Saves.writes_enabled = false
	Data.ensure_loaded()
	check(not Data.events().is_empty(), "event cache is populated")
	for event in Data.events():
		check(Data.find_event(str(event.id)) == event, "indexed lookup returns authored event: " + str(event.id))
	check(Data.find_event("__missing__").is_empty(), "missing event lookup is safe")

	var gc := Controller.new()
	gc.init()
	gc.new_game(false)
	gc.state.province = ""
	gc.state.age = 20
	gc.state.health = 20
	gc.state.line = "normal"
	var emitted: Array = []
	gc.event_picked.connect(func(_state, event): emitted.append(event))
	var special: Dictionary = {}
	for seed_value in range(1000):
		gc.rng.seed = seed_value
		special = gc.pick_event()
		if str(special.get("id", "")) == "S_HOT": break
	check(str(special.get("id", "")) == "S_HOT", "deterministic special event fixture found")
	check(not emitted.is_empty() and emitted.back() == special, "special event uses the common event_picked path")

	gc.state.choice_log["TEST"] = "保留下来的选择"
	var memory_event := Data.find_event("S_HOT").duplicate(true)
	memory_event.text = "后来你仍会想起{choice:TEST}。"
	var filled: Dictionary = gc._fill_and_emit(memory_event)
	check(filled.text == "后来你仍会想起保留下来的选择。", "special events resolve choice memories")
	check(str(Data.find_event("S_HOT").text).find("保留下来的选择") == -1, "text filling never mutates source data")

	gc.meta.achievements.erase("第一天就死了")
	gc.state.age = 5
	gc.state.health = 10
	gc._check_achievements()
	check(not gc.meta.achievements.has("第一天就死了"), "living child does not unlock early-death achievement")
	gc.state.health = 0
	gc._check_achievements()
	check(gc.meta.achievements.has("第一天就死了"), "early death still unlocks its achievement")

	var life := Run.new()
	life.start(42)
	var before := life.snapshot()
	check(life.weighted([], "event").is_empty(), "empty weighted list returns an empty result")
	check(life.snapshot() == before, "empty weighted list does not advance RNG")
	check(life.weighted([{"id": "disabled", "weight": 0}], "event").is_empty(), "zero-total weights cannot select an outcome")
	check(life.snapshot() == before, "invalid weights do not advance RNG")

	print("ENGINE_REGRESSION ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
