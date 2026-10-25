extends Light3D
## 灯光呼吸：能量在小范围内缓慢起伏，像灯泡/屏幕/火光，而不是死亮。
## 由 pixel_fx_3d.breathe() 挂上来，参数从节点 meta 读。

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	var base := float(get_meta("base_energy", light_energy))
	var depth := float(get_meta("breath_depth", 0.06))
	var speed := float(get_meta("breath_speed", 2.6))
	var wave := sin(_t * speed) * sin(_t * speed * 0.37 + 1.3)
	light_energy = base * (1.0 - depth * 0.5 + depth * 0.5 * wave)
