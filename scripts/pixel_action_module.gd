extends RefCounted
## pixel_action_module.gd — 3D 舞台的动作模组
##
## 帧动画只决定「形」（哪张图），这里决定「势」：起伏、前倾、下沉、节奏。
## 每个动作是一段可采样的参数，舞台按速度把「走路的相位」推进多远，脚步就多快。
##
## 用法：
##   var mv := ActionModule.sample("walk", phase, speed_ratio)
##   actor._bob = mv.bob; actor._lean = deg_to_rad(mv.lean); actor._drop = mv.drop

## bob：上下起伏（米）；lean：前倾角度（度）；drop：整体下沉（米）
const CLIPS := {
	"idle":   {"bob": 0.006, "hz": 2.0, "lean": 0.0, "drop": 0.0},
	"walk":   {"bob": 0.030, "hz": 4.0, "lean": 3.2, "drop": 0.0},
	"run":    {"bob": 0.045, "hz": 5.0, "lean": 7.0, "drop": 0.0},
	"talk":   {"bob": 0.007, "hz": 3.0, "lean": 0.8, "drop": 0.0},
	"reach":  {"bob": 0.003, "hz": 2.0, "lean": 2.4, "drop": 0.0},
	"offer":  {"bob": 0.003, "hz": 2.0, "lean": 2.0, "drop": 0.0},
	"receive":{"bob": 0.003, "hz": 2.0, "lean": 1.6, "drop": 0.0},
	"wave":   {"bob": 0.005, "hz": 3.0, "lean": 1.2, "drop": 0.0},
	"nod":    {"bob": 0.005, "hz": 3.5, "lean": 0.6, "drop": 0.0},
	"read":   {"bob": 0.003, "hz": 1.4, "lean": 0.4, "drop": 0.0},
	"phone":  {"bob": 0.003, "hz": 1.4, "lean": 0.8, "drop": 0.0},
	"draw":   {"bob": 0.003, "hz": 2.2, "lean": 2.2, "drop": 0.0},
	"sign":   {"bob": 0.003, "hz": 2.2, "lean": 2.2, "drop": 0.0},
	"drum":   {"bob": 0.004, "hz": 6.0, "lean": 1.8, "drop": 0.0},
	"sit":    {"bob": 0.0, "hz": 0.0, "lean": 1.2, "drop": 0.22},
	"stand":  {"bob": 0.0, "hz": 0.0, "lean": -1.2, "drop": 0.0},
}

const WALK_LIKE := ["walk", "run"]


static func clip(action: String) -> Dictionary:
	return CLIPS.get(action, CLIPS["idle"])


## phase：走路用「累计相位」，其它动作用动作内时间；speed_ratio：0.4~1.6
static func sample(action: String, phase: float, speed_ratio: float = 1.0, reduced: bool = false) -> Dictionary:
	var c := clip(action)
	var bob := 0.0
	var lean := float(c.lean)
	var drop := float(c.drop)
	if reduced:
		return {"bob": 0.0, "lean": 0.0, "drop": drop * 0.6}
	if action in WALK_LIKE:
		# 两步一次起伏：相位走多少，由舞台按实际速度累加
		var amp: float = float(c.bob) * clampf(speed_ratio, 0.5, 1.6)
		bob = -absf(sin(phase * PI)) * amp
		lean = float(c.lean) * clampf(speed_ratio, 0.6, 1.5)
	else:
		var hz: float = float(c.hz)
		if hz > 0.0:
			bob = sin(phase * hz) * float(c.bob)
	return {"bob": bob, "lean": lean, "drop": drop}


## 两个动作之间过渡：k=0 取 a，k=1 取 b
static func blend(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var t := clampf(k, 0.0, 1.0)
	return {
		"bob": lerpf(float(a.get("bob", 0.0)), float(b.get("bob", 0.0)), t),
		"lean": lerpf(float(a.get("lean", 0.0)), float(b.get("lean", 0.0)), t),
		"drop": lerpf(float(a.get("drop", 0.0)), float(b.get("drop", 0.0)), t),
	}
