extends SceneTree
## 演出截图：同一段对白里，动作/表情/镜头如何跟着文字走。

const CutsceneStage := preload("res://scripts/cutscene_stage.gd")
const State := preload("res://scripts/game_state.gd")

var out_dir := "D:/gamelife/_anim_shots"
var stage


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()


func _run() -> void:
	var s := State.new()
	s.age = 20
	stage = CutsceneStage.new()
	stage.size = Vector2(520, 500)
	root.add_child(stage)
	var cut := {
		"bg": "park",
		"cast": [
			{"role": "lead", "x": 52, "y": 64},
			{"role": "parent", "x": 118, "y": 64},
		],
		"camera": {"zoom": 1.0, "x": 80, "y": 45},
		"beats": [
			{"speaker": "旁白", "face": "lead", "expr": "neutral", "text": "下起了雨，操场上只剩你们两个。"},
			{"speaker": "你", "face": "lead", "expr": "determined", "text": "他跑了出去。"},
			{"speaker": "妈妈", "face": "parent", "expr": "sad", "text": "她疼得说不出话。"},
			{"speaker": "你", "face": "lead", "text": "她笑了起来。"},
		],
	}
	stage.configure({"id": "T1"}, cut, s)
	stage.play()
	await _wait(0.9)
	await _shot("01_idle")

	stage.advance()
	stage.advance()
	await _wait(0.16)
	await _shot("02_walk_start")
	await _wait(0.55)
	await _shot("03_walk")

	stage.advance()
	stage.advance()
	await _wait(0.9)
	await _shot("04_parent_sad")

	stage.advance()
	stage.advance()
	await _wait(1.0)
	await _shot("05_happy")

	print("anim shots done -> ", out_dir)
	quit()


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("shot ", name)
