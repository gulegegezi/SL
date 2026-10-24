extends SceneTree
## 奶蛙 NPC 立绘回归：分件齐全、脸部可用（LC25 奶蛙同学的 cast 依赖）。
const SpriteKit := preload("res://scripts/sprite_kit.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(SpriteKit.NPC_ROLES.has("naiwa"), "naiwa role registered")
	var parts := SpriteKit.compose("naiwa", true, "neutral")
	assert(parts.size() == 6, "naiwa = legs/torso/arms/head")
	for t in parts:
		assert(t != null, "naiwa part must load")
	assert(SpriteKit.face("naiwa", "happy", true) != null, "naiwa face must load")
	print("PASS: naiwa npc parts, face")
	quit()
