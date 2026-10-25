extends SceneTree
## 奶蛙 NPC 立绘回归：分件齐全、脸部可用、世界模式整身 fallback 可加载。
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
	assert(load("res://assets/chars/npc_naiwa_idle_0_normal.png") != null,
		"naiwa idle fallback texture must load")
	print("PASS: naiwa npc parts, face, idle fallback")
	quit()
