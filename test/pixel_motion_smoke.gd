extends SceneTree
## 动作模组与平滑走位回归：采样、过渡、速度上限、步态相位。

const ActionModule := preload("res://scripts/pixel_action_module.gd")
const ActorRig := preload("res://scripts/pixel_billboard_actor.gd")
const Stage := preload("res://scripts/pixel_stage_view.gd")
const CutIn := preload("res://scripts/pixel_cutin.gd")


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	# 1) 动作模组：走路是「向下踩」的起伏，坐着有下沉，站起没有
	var walk := ActionModule.sample("walk", 0.5, 1.0)
	assert(float(walk["bob"]) <= 0.001, "走路的起伏应当是负向（踩地）")
	assert(float(walk["bob"]) >= -0.06, "起伏别夸张到飘起来")
	assert(float(ActionModule.sample("walk", 0.5, 1.4)["bob"]) <= float(ActionModule.sample("walk", 0.5, 0.6)["bob"]), "越快幅度越大")
	assert(float(ActionModule.sample("sit", 0.0)["drop"]) > 0.1, "坐下要有下沉")
	assert(float(ActionModule.sample("stand", 0.0)["drop"]) == 0.0, "站起不下沉")
	var blended := ActionModule.blend({"bob": 0.0, "lean": 0.0, "drop": 0.0}, {"bob": 0.2, "lean": 4.0, "drop": 0.0}, 0.5)
	assert(is_equal_approx(float(blended["bob"]), 0.1), "过渡要取中间值")

	# 2) 平滑走位：速度有上限、不会瞬移
	var stage = Stage.new()
	root.add_child(stage)
	var node := Node3D.new()
	root.add_child(node)
	node.position = Vector3.ZERO
	var target := Vector3(3.0, 0.0, 0.0)
	var last := node.position
	var first_step := 0.0
	var max_step := 0.0
	for i in range(120):
		var moved: float = stage._arrive(node, target, "lead", 1.0 / 60.0)
		var step := node.position.distance_to(last)
		max_step = maxf(max_step, step)
		if i == 0:
			first_step = step
		last = node.position
	assert(first_step < 0.02, "起步第一帧不能瞬移")
	assert(max_step < 0.06, "每帧位移要被速度上限压住")
	assert(node.position.distance_to(target) < 0.01, "最终要落到目标点")
	assert(float(stage._phase["lead"]) == 0.0, "没走就不该有步态相位")

	# 3) 演员：走路的起伏/前倾/坐下的下沉确实被用上
	var actor = ActorRig.new()
	root.add_child(actor)
	actor.setup("lead_adult", 30, {})
	actor.pose("walk", 1.0, false, false, 1.2)
	assert(actor._bob < 0.0, "走路要有踩地起伏")
	assert(absf(actor._lean) > 0.01, "走路要有一点前倾")
	actor.pose("sit", 0.5, false, false, 1.0)
	assert(actor._drop > 0.1, "坐下要下沉")

	# 4) 漫画弹窗：时间轴与拟声词
	assert(CutIn.active(0.0) and CutIn.active(1.0))
	assert(not CutIn.active(CutIn.DURATION + 0.01), "弹窗要自己收走")
	assert(CutIn.sfx_for("drum") == "咚")
	assert(CutIn.sfx_for("phone") == "嗡")
	assert(not CutIn.sfx_for("unknown").is_empty(), "未知动作也要有兜底拟声词")

	print("PASS: action module, smooth locomotion, actor pose, cut-in timeline")
	quit()
