extends SceneTree
## 过场 CG 多轮对话：统一模板、说话人口型、交替推进与选择回归。
const CutsceneStage := preload("res://scripts/cutscene_stage.gd")
const State := preload("res://scripts/game_state.gd")
const SpriteKit := preload("res://scripts/sprite_kit.gd")

var errors := 0

func verify(value: bool, message: String) -> void:
	if not value:
		errors += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	root.size = Vector2i(900,700)
	root.content_scale_size = Vector2i(900,700)
	DirAccess.make_dir_recursive_absolute("D:/gamelife/_render_cmp")
	var stage := CutsceneStage.new()
	stage.size = Vector2(880,680)
	stage.position = Vector2(10,10)
	root.add_child(stage)
	await process_frame
	var state := State.new()
	state.age = 30
	var cut := {
		"bg":"home",
		"cast":[{"role":"lead","x":55,"y":64},{"role":"parent","x":108,"y":64}],
		"beats":[
			{"speaker":"旁白","face":"lead","expr":"neutral","text":"夜里的客厅很安静。"},
			{"speaker":"妈妈","face":"parent","expr":"neutral","text":"别怕，我在。"},
			{"speaker":"你","face":"lead","expr":"neutral","text":"我记得。"},
			{"speaker":"妈妈","face":"parent","expr":"neutral","text":"我们慢慢来。"},
		],
	}
	var choice := {"label":"继续","result":"","effects":{}}
	stage.configure({"id":"DIALOGUE_TEST"},cut,state,[choice])
	var selected: Array = []
	stage.finished.connect(func(value): selected.append(value))
	stage.play()
	stage.set_process(false)
	stage.advance()
	stage.advance()
	verify(stage.beat_index == 1,"second beat is active")
	verify(stage.is_talking("parent") and not stage.is_talking("lead"),"only the current speaker talks")
	verify(int(SpriteKit.action_info("npc_parent","idle").get("n",1)) >= 2,"NPC fixture has two mouth frames")
	stage.clock = 0.0
	var closed := stage.cast_frame_index("parent","parent",stage.actors.parent)
	stage.clock = 0.25
	var open := stage.cast_frame_index("parent","parent",stage.actors.parent)
	verify(closed != open,"neutral NPC alternates mouth frames while typing")
	stage.reduced_motion = true
	verify(stage.cast_frame_index("parent","parent",stage.actors.parent) == 0,"reduced motion disables mouth flapping")
	stage.reduced_motion = false
	stage.visible_chars = 4
	if "--capture" in OS.get_cmdline_user_args():
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("D:/gamelife/_render_cmp/cutscene_dialogue_parent.png")
	stage.advance()
	verify(not stage.is_talking("parent"),"mouth stops when the line is complete")
	stage.advance()
	verify(stage.beat_index == 2 and stage.is_talking("lead"),"advancing switches the mouth to the protagonist")
	verify(not stage.is_talking("parent"),"previous speaker stops on the next beat")
	stage.advance()
	if "--capture" in OS.get_cmdline_user_args():
		stage.clock = 0.25
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("D:/gamelife/_render_cmp/cutscene_dialogue_lead.png")
	stage.advance()
	verify(stage.beat_index == 3 and stage.is_talking("parent"),"dialogue returns to the NPC on a later beat")
	stage.advance()
	stage.advance()
	verify(stage.in_choices and not stage.is_talking("parent"),"choices suspend dialogue mouth animation")
	stage.confirm()
	verify(selected.size() == 1 and selected[0] == choice,"multi-turn dialogue still confirms the original choice")
	stage.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("CUTSCENE_DIALOGUE_SMOKE ","PASS" if errors == 0 else "FAIL")
	quit(0 if errors == 0 else 1)
