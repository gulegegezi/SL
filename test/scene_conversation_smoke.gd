extends SceneTree
const Reader := preload("res://scripts/life_comic_reader.gd")
var failures := 0
func check(value: bool, message: String) -> void:
	if not value: failures += 1; push_error(message)
func _initialize() -> void:
	call_deferred("run_test")
func frames(count: int = 6) -> void:
	for i in range(count): await process_frame
func run_test() -> void:
	root.size = Vector2i(520,900)
	root.content_scale_size = Vector2i(520,900)
	var reader = Reader.new()
	reader.save_enabled = false
	reader.save_path = "user://scene_conversation_smoke.save"
	root.add_child(reader)
	await frames()
	reader.run.s.pending = {}
	reader.run.s.age = 18
	reader.run.begin("LC11")
	reader.add_current(); reader.refresh()
	await frames()
	var before: Dictionary = reader.run.snapshot()
	reader.actions.get_node("SceneConversation").pressed.emit()
	await frames()
	var talk = reader.conversation
	check(is_instance_valid(talk) and not reader.strip.visible,"conversation overlays comic and suspends background worlds")
	talk.panel.visible_characters = 0
	talk.advance()
	check(talk.index == 0 and talk.panel.visible_characters == talk.panel._full_text.length(),"first click completes current line only")
	talk.advance()
	await frames()
	check(talk.index == 1 and talk.panel.spec.text_channel == "dialogue","second click advances to NPC speech")
	talk.panel.visible_characters = 3
	talk.panel.set_process(false)
	check(not talk.history_text().contains(str(talk.lines[-1].get("caption",""))),"history excludes unread future lines")
	if "--capture" in OS.get_cmdline_user_args():
		talk.panel.reveal_all_text()
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("D:/gamelife/scene-conversation-preview.png")
	talk.panel.visible_characters = 3
	talk.close()
	await frames()
	check(reader.strip.visible,"closing restores scrollable comic")
	check(reader.run.s.pages[-1].conversation_progress.line == 1,"presentation cursor persisted on page")
	check(reader.run.save(reader.save_path),"conversation bookmark saves")
	reader.open_conversation()
	await frames(1)
	talk = reader.conversation
	check(talk.index == 1 and talk.panel.visible_characters >= 3,"reopening resumes the same utterance")
	talk.show_history()
	check(talk.history.visible and not talk.panel.is_processing(),"history pauses typewriter")
	talk.history.hide()
	await frames()
	check(talk.panel.is_processing(),"closing history resumes typewriter")
	root.size = Vector2i(360,800)
	root.content_scale_size = Vector2i(360,800)
	await frames()
	check(talk.size.x <= 360,"conversation fits narrow screen")
	while is_instance_valid(talk) and not talk._closing:
		talk.advance()
	await frames()
	check(reader.run.s.pages[-1].conversation_progress.completed,"final line returns to comic with completion flag")
	check(reader.run.s.pending == before.pending and reader.run.s.committed == before.committed,"dialogue never commits a player choice")
	check(reader.run.snapshot().rng == before.rng and reader.run.s.scores == before.scores,"dialogue never consumes fate or changes scores")
	reader.select(0)
	reader.open_conversation()
	await frames()
	talk = reader.conversation
	var speakers: Array = []
	for line in talk.lines:
		if line.get("text_channel","") == "dialogue": speakers.append(line.get("actor","lead"))
	check(speakers.has("lead") and speakers.size() >= 2,"resolved choice replays NPC setup and actual protagonist reply together")
	talk.close()
	await frames()
	reader.queue_free()
	await frames()
	var restored = Reader.new()
	restored.save_enabled = false; restored.save_path = "user://scene_conversation_smoke.save"; restored.resume_on_open = true
	root.add_child(restored)
	await frames()
	restored.open_conversation()
	await frames()
	check(restored.conversation.index == 1,"fresh reader resumes disk conversation cursor")
	restored.conversation.close()
	await frames()
	restored.queue_free()
	await frames()
	await create_timer(0.2).timeout
	print("SCENE_CONVERSATION_SMOKE ","PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
