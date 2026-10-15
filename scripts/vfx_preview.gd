## VFX 预览台 — 单独调试 / 观看每个像素动画
## 用法：
##   1. 在 Godot 里打开 scenes/VFXPreview.tscn，按 F6（运行当前场景）
##   2. 或把 project.godot 的 run/main_scene 临时改成它，按 F5
## 操作：点按钮单独播放 / 「连续播放全部」自动轮播 / 空格播下一个
extends Control

const ChoiceVFX := preload("res://scripts/vfx.gd")

## 与 main.gd 一致的调色板（tag 动画需要）
const C := {
	"panel": Color(0.071, 0.086, 0.110, 1),
	"panel2": Color(0.090, 0.110, 0.141, 1),
	"line": Color(0.141, 0.173, 0.220, 1),
	"txt": Color(0.788, 0.831, 0.886, 1),
	"dim": Color(0.400, 0.451, 0.541, 1),
	"green": Color(0.224, 1.0, 0.533, 1),
	"cyan": Color(0.310, 0.890, 1.0, 1),
	"pink": Color(1.0, 0.373, 0.824, 1),
	"yellow": Color(1.0, 0.827, 0.310, 1),
	"red": Color(1.0, 0.302, 0.369, 1),
	"purple": Color(0.627, 0.420, 1.0, 1),
}

## 与 vfx.gd 的 _dispatch 分支一一对应（25 种）
const ANIMS := [
	"coin", "bill", "brain", "heart", "muscle", "decay", "clover", "psych",
	"hourglass", "confetti", "wilt", "tag",
	"firework", "jackpot", "night", "rain", "heartbreak", "exam",
	"gamble", "code", "death", "glitch", "smoke", "run", "spark",
]

const CN := {
	"coin": "金币雨", "bill": "钞票飞散", "brain": "脑电波", "heart": "爱心上升",
	"muscle": "力量脉冲", "decay": "受创抖动", "clover": "旋转星", "psych": "彩虹螺旋",
	"hourglass": "沙漏", "confetti": "五彩纸屑", "wilt": "枯萎压暗", "tag": "标签弹泡",
	"firework": "烟花", "jackpot": "金币爆发", "night": "深夜", "rain": "落雨",
	"heartbreak": "心碎", "exam": "考试", "gamble": "骰子", "code": "代码雨",
	"death": "心电图", "glitch": "故障", "smoke": "烟雾", "run": "速度线",
	"spark": "像素爆点",
}

const AUTO_GAP := 1.7

var stage: Control
var info: Label
var auto_btn: Button
var auto_on := false
var auto_idx := 0
var auto_accum := 0.0


func _ready() -> void:
	_build()
	_play_anim("coin")


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.043, 0.051, 0.063, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	var title := Label.new()
	title.text = "VFX 预览台 · 逐个播放像素动画"
	title.add_theme_color_override("font_color", C["yellow"])
	title.add_theme_font_size_override("font_size", 18)
	col.add_child(title)

	var tip := Label.new()
	tip.text = "点按钮单独播放；「连续播放全部」自动轮播 25 种；★ = 独占动画（播放时不叠加属性动画）"
	tip.add_theme_color_override("font_color", C["dim"])
	tip.add_theme_font_size_override("font_size", 12)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(tip)

	# ---- 演出区 ----
	var frame := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.067, 0.086, 1)
	sb.set_corner_radius_all(6)
	sb.border_color = C["line"]
	sb.set_border_width_all(1)
	frame.add_theme_stylebox_override("panel", sb)
	col.add_child(frame)

	stage = Control.new()
	stage.custom_minimum_size = Vector2(0, 210)
	stage.clip_contents = true
	frame.add_child(stage)

	info = Label.new()
	info.text = "—"
	info.add_theme_color_override("font_color", C["cyan"])
	info.add_theme_font_size_override("font_size", 12)
	col.add_child(info)

	# ---- 按钮区 ----
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	col.add_child(flow)

	auto_btn = Button.new()
	auto_btn.text = "▶ 连续播放全部"
	auto_btn.pressed.connect(_toggle_auto)
	flow.add_child(auto_btn)

	var clr := Button.new()
	clr.text = "清空舞台"
	clr.pressed.connect(_clear_stage)
	flow.add_child(clr)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(12, 0)
	flow.add_child(spacer)

	for a in ANIMS:
		var key: String = str(a)
		var b := Button.new()
		b.text = str(CN.get(key, key)) + (" ★" if ChoiceVFX.is_solo(key) else "")
		b.tooltip_text = key
		b.pressed.connect(_play_anim.bind(key))
		flow.add_child(b)


func _play_anim(a: String) -> void:
	_clear_stage()
	var suffix := "　★ 独占：不再叠加属性动画" if ChoiceVFX.is_solo(a) else ""
	info.text = "正在播放：%s　[%s]%s" % [str(CN.get(a, a)), a, suffix]
	ChoiceVFX.play(stage, [a], ["示例标签"], C)


func _clear_stage() -> void:
	if stage == null or not is_instance_valid(stage):
		return
	for ch in stage.get_children():
		ch.queue_free()


func _toggle_auto() -> void:
	auto_on = not auto_on
	auto_btn.text = "⏸ 暂停轮播" if auto_on else "▶ 连续播放全部"
	if auto_on:
		auto_idx = 0
		auto_accum = AUTO_GAP


func _process(delta: float) -> void:
	if not auto_on:
		return
	auto_accum += delta
	if auto_accum >= AUTO_GAP:
		auto_accum = 0.0
		_next_anim()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_next_anim()


func _next_anim() -> void:
	var a := str(ANIMS[auto_idx % ANIMS.size()])
	auto_idx += 1
	_play_anim(a)
