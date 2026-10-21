extends SceneTree
## 文本 → 演出 回归：说什么就演什么，动作先起手再开字，镜头跟着说话人。

const BeatDirector := preload("res://scripts/beat_director.gd")
const CutsceneStage := preload("res://scripts/cutscene_stage.gd")
const SpriteKit := preload("res://scripts/sprite_kit.gd")
const State := preload("res://scripts/game_state.gd")


func _initialize() -> void:
	call_deferred("run")


func _state() -> State:
	var s := State.new()
	s.age = 20
	return s


func run() -> void:
	# 1) 文本推断
	assert(BeatDirector.expression_for("她笑了起来") == "happy")
	assert(BeatDirector.expression_for("他疼得直皱眉") == "hurt")
	assert(BeatDirector.expression_for("她怕得发抖") == "scared")
	assert(BeatDirector.action_for("他转身走了出去") == "walk")
	assert(BeatDirector.action_for("她挥了挥手") == "wave")
	assert(BeatDirector.action_for("走廊里很安静") == "idle", "「走廊」不该触发 walk")

	# 2) 显式字段优先
	var d := BeatDirector.direction({"text": "她笑了", "expr": "sad", "action": "sit"})
	assert(str(d["expr"]) == "sad" and str(d["action"]) == "sit")

	# 3) 镜头：情绪句推近，旁白拉远
	var shot := BeatDirector.shot_for({"speaker": "妈妈", "text": "她笑了"}, 118.0, 1.0)
	assert(float(shot["zoom"]) > 1.0, "情绪句应该推近")
	var narr := BeatDirector.shot_for({"speaker": "旁白", "text": "雨停了。"}, 80.0, 1.0)
	assert(float(narr["zoom"]) < 1.0, "旁白应该拉远")

	# 4) 帧资源
	assert(SpriteKit.frame("lead_adult", "idle", 0, "happy") != null, "idle happy 帧缺失")
	assert(SpriteKit.frame("lead_adult", "walk", 2) != null, "walk 帧缺失")
	assert(SpriteKit.frame("parent", "idle", 0, "normal", true) != null, "npc idle 帧缺失")

	# 5) 舞台：一句「跑了出去」应切到 walk，并先起手再开字
	var stage = CutsceneStage.new()
	stage.size = Vector2(480, 420)
	root.add_child(stage)
	var cut := {
		"bg": "park",
		"cast": [{"role": "lead", "x": 60, "y": 64}],
		"beats": [
			{"speaker": "旁白", "face": "lead", "expr": "neutral", "text": "风停了。"},
			{"speaker": "你", "face": "lead", "expr": "happy", "text": "他跑了出去。"},
		],
	}
	stage.configure({"id": "T1"}, cut, _state())
	stage.play()
	assert(str(stage.actors["lead"]["action"]) == "idle")
	stage.advance()
	stage.advance()
	await process_frame
	assert(str(stage.actors["lead"]["action"]) == "walk", "文本说跑，动作就要走")
	assert(str(stage.actors["lead"]["expr"]) == "happy", "显式表情优先")
	assert(stage.hold_timer > 0.0, "动作要先起手，再开字")

	print("PASS: text-driven beats (action/expr/camera/hold)")
	quit()
