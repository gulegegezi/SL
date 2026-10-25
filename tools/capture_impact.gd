extends SceneTree
## 夸张漫画面相截图：暴怒 / 爆哭 / 失神，各截「冲击那一瞬」和「落定后」。

const CutsceneStage := preload("res://scripts/cutscene_stage.gd")
const State := preload("res://scripts/game_state.gd")

var out_dir := "D:/gamelife/_impact_shots"
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
		"bg": "home",
		"cast": [{"role": "lead", "x": 62, "y": 64}],
		"beats": [
			{"speaker": "你", "face": "lead", "text": "他暴怒地吼了出来。"},
			{"speaker": "你", "face": "lead", "text": "她爆哭起来。"},
			{"speaker": "你", "face": "lead", "text": "他愣住了，失神地看着地面。"},
		],
	}
	stage.configure({"id": "I1"}, cut, s)
	stage.play()

	await _wait(0.30)
	await _shot("01_rage_impact")
	await _wait(0.9)
	await _shot("02_rage_settle")

	stage.advance()
	stage.advance()
	await _wait(0.30)
	await _shot("03_cry_impact")
	await _wait(0.9)
	await _shot("04_cry_settle")

	stage.advance()
	stage.advance()
	await _wait(0.30)
	await _shot("05_dead_impact")
	await _wait(0.9)
	await _shot("06_dead_settle")

	print("impact shots done -> ", out_dir)
	quit()


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("shot ", name)
