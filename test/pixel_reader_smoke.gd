extends SceneTree
## Integration regression: use real reader controls and a dedicated test bookmark.
const Reader := preload("res://scripts/life_comic_reader.gd")
const Run := preload("res://scripts/life_comic_run.gd")
const Pages := preload("res://scripts/life_comic_pages.gd")
const TEST_SAVE := "user://pixel_reader_smoke.save"
var failures := 0
var assertions := 0

func check(condition: bool, description: String) -> bool:
	assertions += 1
	if not condition:
		failures += 1
		push_error(description)
	return condition

func _initialize() -> void:
	call_deferred("run_tests")

func frames(count: int = 12) -> void:
	for _i in range(count): await process_frame

func save_panel(bookmark: Dictionary, key: String) -> Dictionary:
	for page in bookmark.get("pages", []):
		for item in page.get("panels", []):
			if item.has(key): return item
	return {}

func disk_snapshot() -> Dictionary:
	var stored = Run.new()
	if not check(stored.load_save(TEST_SAVE), "Dedicated reader bookmark loads from disk"):
		return {}
	return stored.s

func test_legacy_upgrade(source: Dictionary) -> void:
	var legacy := source.duplicate(true)
	for p in legacy.panels:
		for key in ["presentation", "pixel_variant", "pixel_cg", "cg_progress", "pixel_interaction", "interaction_progress"]:
			p.erase(key)
	var original := legacy.duplicate(true)
	var once := Pages.upgrade_legacy(legacy)
	var twice := Pages.upgrade_legacy(once)
	check(legacy == original, "Upgrading dialogue2 does not mutate the original bookmark")
	check(once == twice, "Upgrading the same dialogue2 page twice is idempotent")
	check(once.panels.size() == original.panels.size(), "Legacy migration retains panel count")
	check(once.panels[0].get("cg_progress", {}).get("completed", false), "Legacy special shot is marked seen instead of replaying automatically")
	check(once.panels[-1].has("pixel_interaction"), "Legacy pending event receives the optional observation")
	for i in range(original.panels.size()):
		check(once.panels[i].caption == original.panels[i].caption and once.panels[i].bubble == original.panels[i].bubble, "Legacy text remains unchanged")
		check(once.panels[i].action == original.panels[i].action, "Legacy choice direction remains unchanged")

func run_tests() -> void:
	root.size = Vector2i(820, 1100)
	root.content_scale_size = Vector2i(820, 1100)
	var fixture = Run.new()
	fixture.start(9347)
	var opening := Pages.make(fixture)
	test_legacy_upgrade(opening)
	fixture.s.pages.append(opening)
	if not check(fixture.save(TEST_SAVE), "Create isolated reader test bookmark"):
		finish()
		return
	var reader = Reader.new()
	reader.save_path = TEST_SAVE
	reader.resume_on_open = true
	root.add_child(reader)
	await frames(20)
	var before: Dictionary = reader.run.snapshot()
	var cinema: Control = reader._find_stage_panel("pixel_cg")
	var observation: Control = reader._find_stage_panel("pixel_interaction")
	if not check(is_instance_valid(cinema) and is_instance_valid(observation), "Real Reader exposes CG and observation panels"):
		reader.queue_free()
		await frames()
		finish()
		return
	var controls: Node = reader.actions.get_node_or_null("CinemaTools")
	if not check(controls != null and controls.get_child_count() == 2, "Real Reader renders replay and skip controls"):
		reader.queue_free()
		await frames()
		finish()
		return
	var replay_button: Button = controls.get_child(0)
	var skip_button: Button = controls.get_child(1)
	skip_button.pressed.emit()
	await frames(4)
	check(cinema.pixel_stage.cg_finished and cinema.pixel_stage.cg_time < 0, "Skip button ends the current cinematic")
	check(save_panel(disk_snapshot(), "pixel_cg").get("cg_progress", {}).get("completed", false), "CG skip completion reaches the disk bookmark")
	var explore_button: Button = reader.actions.get_node_or_null("ExploreScene")
	if check(explore_button != null, "Real Reader has an exploration button"):
		explore_button.pressed.emit()
		await frames(12)
		observation = reader._find_stage_panel("pixel_interaction")
		check(observation.pixel_stage.interaction_time >= 0, "Explore button starts the scene action")
		# Advance the actual controller deterministically instead of sleeping 3.6 seconds.
		for _i in range(12):
			if not observation.pixel_stage.interacted: observation.pixel_stage._process(0.4)
			await process_frame
		check(observation.pixel_stage.interacted and observation.interaction_done, "Observation action reaches its completed state")
		check(explore_button.disabled, "Completed observation disables its action button")
		check(save_panel(disk_snapshot(), "pixel_interaction").get("interaction_progress", {}).get("completed", false), "Observation completion reaches the disk bookmark")
	# Keep the original buttons: their callbacks must resolve the rebuilt panel at click time.
	var previous_cinema_id := cinema.get_instance_id()
	root.size = Vector2i(440, 920)
	root.content_scale_size = Vector2i(440, 920)
	await frames(20)
	var resized_cinema: Control = reader._find_stage_panel("pixel_cg")
	check(resized_cinema.get_instance_id() != previous_cinema_id, "Narrow resize actually rebuilt the panels")
	check(not is_instance_valid(cinema), "Old cinematic panel was released after resize")
	check(is_instance_valid(replay_button) and is_instance_valid(skip_button), "Existing controls remain after panel rebuild")
	replay_button.pressed.emit()
	await frames(8)
	resized_cinema = reader._find_stage_panel("pixel_cg")
	check(resized_cinema.pixel_stage.cg_time >= 0 and not resized_cinema.pixel_stage.cg_finished, "Replay button starts the new panel after resize")
	skip_button.pressed.emit()
	await frames(4)
	check(resized_cinema.pixel_stage.cg_time < 0 and resized_cinema.pixel_stage.cg_finished, "Skip button stops the new panel after resize")
	check(reader.run.s.pending == before.pending and reader.run.s.committed.is_empty(), "Exploration, replay and skip never commit a story choice")
	check(reader.run.s.scores == before.scores and reader.run.snapshot().rng == before.rng, "Presentation controls preserve scores and all fate RNG streams")
	reader.autosave()
	reader.queue_free()
	await frames(12)
	var resumed = Reader.new()
	resumed.save_path = TEST_SAVE
	resumed.resume_on_open = true
	root.add_child(resumed)
	await frames(20)
	var restored_observation: Control = resumed._find_stage_panel("pixel_interaction")
	var restored_cinema: Control = resumed._find_stage_panel("pixel_cg")
	check(is_instance_valid(restored_observation) and is_instance_valid(restored_cinema), "Fresh Reader restores both presentation panels")
	check(restored_observation.interaction_done and restored_observation.pixel_stage.interacted, "Fresh Reader restores observation discovery")
	check(restored_cinema.pixel_stage.cg_finished and restored_cinema.pixel_stage.cg_time < 0, "Fresh Reader retains skipped CG instead of automatically replaying it")
	check(resumed.actions.get_node("ExploreScene").disabled, "Fresh Reader does not offer an already completed exploration")
	check(resumed.run.s.pending == before.pending and resumed.run.s.committed.is_empty(), "Fresh Reader still awaits the original formal choice")
	resumed.queue_free()
	await frames(12)
	finish()

func finish() -> void:
	print("PIXEL_READER_SMOKE ", "PASS" if failures == 0 else "FAIL", " · ", assertions, " checks · real reader buttons / bookmark restore / resize replay / dialogue2 upgrade")
	quit(0 if failures == 0 else 1)
