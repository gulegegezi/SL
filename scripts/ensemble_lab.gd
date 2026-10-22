extends Control
const World := preload("res://scripts/comic_world.gd")
const Ink := preload("res://scripts/comic_theme.gd")
var clock := 0.0
var playing := true
var reduced := false
var action := "receive"
var scrubber: HSlider
var keys := ["lead_child","lead_teen","lead_youth","lead_adult","lead_middle","lead_elder","npc_parent","npc_friend","npc_teacher","npc_boss","npc_partner","npc_mate"]
var names := ["童年","少年","青年","成年","中年","老年","妈妈","朋友","老师","老板","伴侣","邻居"]
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var list := OptionButton.new()
	list.position = Vector2(14,12)
	var values := ["idle","receive","wave","phone","drum","nod","sit","talk"]
	for text in ["站立","递接","挥手","电话","节拍","点头","坐下","交谈"]: list.add_item(text)
	list.select(1)
	list.item_selected.connect(func(index): action=values[index];clock=0;queue_redraw())
	add_child(list)
	var pause := Button.new()
	pause.text = "播放 / 暂停"
	pause.position = Vector2(126,12)
	pause.pressed.connect(func(): playing=not playing)
	add_child(pause)
	var low := CheckButton.new()
	low.text = "减少动态"
	low.position = Vector2(270,12)
	low.toggled.connect(func(value): reduced=value;queue_redraw())
	add_child(low)
	scrubber = HSlider.new()
	scrubber.position = Vector2(14,58)
	scrubber.size = Vector2(492,24)
	scrubber.max_value=2.4
	scrubber.step=0.05
	scrubber.value_changed.connect(func(value): playing=false;clock=value;queue_redraw())
	add_child(scrubber)
func _process(delta: float) -> void:
	if playing: clock=fmod(clock+delta,3.2)
	scrubber.set_value_no_signal(minf(clock,2.4))
	queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("102330"))
	for i in range(keys.size()):
		var cell := Rect2(10+(i%3)*(size.x-20)/3,104+floori(i/3.0)*190,(size.x-20)/3-5,182)
		draw_rect(cell,Color("193846"))
		draw_line(cell.position+Vector2(8,145),cell.position+Vector2(cell.size.x-8,145),Color("4b747b"),1)
		World.actor(self,keys[i],cell.position+Vector2(cell.size.x*0.5,145),action,minf(clock,2.4),"normal",i>=6,reduced or clock>=2.4,3.8)
		draw_string(Ink.font_body(),cell.position+Vector2(8,169),names[i],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Ink.CREAM)
