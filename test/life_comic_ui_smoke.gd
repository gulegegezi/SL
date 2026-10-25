extends SceneTree
const Reader := preload("res://scripts/life_comic_reader.gd")
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run_test")
func run_test() -> void:
	var reader = Reader.new()
	reader.save_enabled = false
	reader.save_path = "user://life_comic_ui_test.save"
	root.add_child(reader)
	await process_frame
	await process_frame
	check(reader.actions.get_node_or_null("Choice_2") != null,"actual opening choice buttons")
	reader.actions.get_child(0).pressed.emit()
	check(not reader.run.s.committed.is_empty(),"actual choice signal resolves")
	check(reader.run.s.pages.size() == 2,"result appears once in strip")
	if "--capture" in OS.get_cmdline_user_args():
		await create_timer(2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("D:/gamelife/life-dialogue-birth-preview.png")
	reader.select(1)
	check(reader.run.s.pages.size() == 2,"double click cannot append duplicate result")
	reader.actions.get_child(0).pressed.emit()
	check(reader.run.s.committed.is_empty() and not reader.run.s.pending.is_empty(),"continue selects a new valid event")
	check(reader.actions.get_node_or_null("Choice_0") != null,"next choices replace continue")
	# Exercise adult cast and all four lenses through the actual rendering tree.
	for value in [0,25,50,75]:
		reader.run.s.pending = {}; reader.run.s.committed = {}
		reader.run.s.age = 28; reader.run.s.scores.abstract = value
		reader.run.begin("LC14")
		reader.add_current(); reader.refresh()
		reader.select(0)
		await process_frame
		await process_frame
	root.size = Vector2i(360,800)
	root.content_scale_size = Vector2i(360,800)
	await process_frame
	await process_frame
	check(reader.actions.size.x <= 360,"choice area fits narrow screen")
	reader.run.s["scroll"] = reader.scroll.scroll_vertical
	check(reader.run.save(reader.save_path),"UI state saves")
	var restored = Reader.new()
	restored.save_enabled = false; restored.resume_on_open = true; restored.save_path = reader.save_path
	reader.queue_free()
	await process_frame
	root.add_child(restored)
	await process_frame
	await process_frame
	check(not restored.run.s.committed.is_empty(),"restored result still awaiting continue")
	check(restored.actions.get_child(0).text == "继续往下读","restored result has a continue button")
	if "--capture" in OS.get_cmdline_user_args():
		await create_timer(2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("D:/gamelife/life-comic-preview.png")
	restored.queue_free()
	await process_frame
	var title = load("res://scenes/Main.tscn").instantiate()
	root.add_child(title)
	await process_frame
	var found := false
	for item in title.find_children("*","Button",true,false):
		if item.text.contains("折痕与歪楼"): found = true
	check(found,"default project title exposes the new story mode")
	title.queue_free()
	await process_frame
	preload("res://scripts/audio_fx.gd").stop_music()
	await create_timer(.15).timeout
	print("LIFE_COMIC_UI_SMOKE ","PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
