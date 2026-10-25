extends SceneTree
## 对话模板与真实像素舞台联动回归。
const Dialogue := preload("res://scripts/comic_dialogue.gd")
const PixelPanel := preload("res://scripts/comic_panel.gd")

var errors := 0

func verify(value: bool, message: String) -> void:
	if not value:
		errors += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var parsed := Dialogue.copy("妈妈：别怕，我在。",4)
	verify(parsed.speaker == "妈妈","speaker label comes from the original line")
	verify(parsed.full == "别怕，我在。","speaker prefix is not repeated in the body")
	verify(parsed.shown == "别","typewriter reveals only the dialogue body")
	verify(not parsed.done,"partial dialogue remains in the typing state")
	verify(Dialogue.copy("妈妈：你好",2).shown.is_empty(),"name prefix never leaks into the body while typing")
	verify(Dialogue.copy("妈妈：你好").done,"full dialogue exposes its completion state")
	verify(Dialogue.copy("你:OK",-1).full == "OK","ASCII dialogue separators are supported")
	verify(Dialogue.copy("你好",-1,"你").speaker == "你","legacy lines without a prefix retain a speaker")

	root.size = Vector2i(900,700)
	root.content_scale_size = Vector2i(900,700)
	DirAccess.make_dir_recursive_absolute("D:/gamelife/_render_cmp")
	var panel := PixelPanel.new()
	panel.size = Vector2(880,670)
	panel.position = Vector2(10,10)
	panel.setup({
		"presentation":"pixel3d","ink":"lead_adult","age":30,"scene":"home",
		"support":"npc_parent","world_solo":false,"shot":"wide","tone":"paper",
		"caption":"","bubble":"妈妈：别怕，我在。我们慢慢来。",
		"speaker_label":"妈妈","text_channel":"dialogue","actor":"parent","action":"talk",
	},null)
	root.add_child(panel)
	await process_frame
	await process_frame
	await process_frame
	verify(panel.pixel_stage != null and is_instance_valid(panel.pixel_stage.viewport),"dialogue fixture creates its real stage")
	panel.set_revealed(false)
	panel.set_revealed(true)
	for _i in range(12): panel._process(0.025)
	verify(panel.visible_characters > 0 and panel.visible_characters < panel._full_text.length(),"real panel is in the typing state")
	panel.pixel_stage.update_actors(0.25)
	verify(panel.pixel_stage.npc.action == "talk","current dialogue beat animates the speaking NPC")
	var closed_frame: int = panel.pixel_stage.npc._frame
	panel.pixel_stage.npc.pose("talk",0.25,true,false)
	var open_frame: int = panel.pixel_stage.npc._frame
	verify(closed_frame != open_frame,"speaking alternates the actor mouth frame")
	if "--capture" in OS.get_cmdline_user_args():
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("D:/gamelife/_render_cmp/dialogue_typing.png")
	panel.finish_reveal()
	panel.pixel_stage.update_actors(0.016)
	verify(panel.visible_characters == panel._full_text.length(),"finishing a line preserves all original text")
	if "--capture" in OS.get_cmdline_user_args():
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("D:/gamelife/_render_cmp/dialogue_complete.png")
	panel.queue_free()
	await process_frame
	print("DIALOGUE_TEMPLATE_SMOKE ","PASS" if errors == 0 else "FAIL")
	quit(0 if errors == 0 else 1)
