extends Control
const Run := preload("res://scripts/life_comic_run.gd")
const Pages := preload("res://scripts/life_comic_pages.gd")
const PixelPanel := preload("res://scripts/comic_panel.gd")
const Direction := preload("res://scripts/pixel_story_direction.gd")
var index := 0
var panel: Control
var heading: Label
var area: Control
var events := ["LC01","LC03","LC06","LC09","LC11","LC12","LC18","LC23","LC24"]

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("14252c")
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	column.offset_left = 16; column.offset_right = -16; column.offset_top = 16; column.offset_bottom = -16
	add_child(column)
	heading = Label.new()
	heading.add_theme_font_override("font",preload("res://scripts/comic_theme.gd").font_body())
	column.add_child(heading)
	area = Control.new()
	area.size_flags_vertical = SIZE_EXPAND_FILL
	column.add_child(area)
	var row := HBoxContainer.new()
	column.add_child(row)
	for item in [["上一场",func(): index = posmod(index-1,events.size()); show_event()], ["下一场",func(): index = posmod(index+1,events.size()); show_event()], ["场景互动",func(): if panel.pixel_stage != null: panel.pixel_stage.perform_interaction()], ["重播CG",func(): if panel.pixel_stage != null: panel.pixel_stage.replay_cg()], ["跳过CG",func(): if panel.pixel_stage != null: panel.pixel_stage.skip_cg()]]:
		var b := Button.new()
		b.text = item[0]; b.size_flags_horizontal = SIZE_EXPAND_FILL; b.custom_minimum_size.y = 42
		b.pressed.connect(item[1]); row.add_child(b)
	show_event()

func show_event() -> void:
	if is_instance_valid(panel): area.remove_child(panel); panel.queue_free()
	var run = Run.new()
	run.start(42)
	run.s.pending = {}; run.s.committed = {}
	var event: Dictionary = run.events[events[index]]
	run.s.age = int(event.age_range[0])
	run.begin(event.id)
	var spec: Dictionary = Pages.make(run).panels[-1].duplicate(true)
	spec["caption"] = "旁白："+str(event.facts)
	spec["pixel_cg"] = Direction.cg(event.id)
	panel = PixelPanel.new()
	panel.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	panel.setup(spec,null)
	area.add_child(panel)
	heading.text = "像素人生 · 3D 演出预览 / "+event.title
