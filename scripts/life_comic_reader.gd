extends Control
## Independent native reader, using the existing animated pixel comic panels.
const Run := preload("res://scripts/life_comic_run.gd")
const Pages := preload("res://scripts/life_comic_pages.gd")
const Page := preload("res://scripts/comic_page.gd")
const ThemeKit := preload("res://scripts/comic_theme.gd")
var run = Run.new()
var scroll: ScrollContainer
var strip: VBoxContainer
var actions: VBoxContainer
var status: Label
var notice: Label
var blank: Control
var locked := false
var save_enabled := true
var save_path := Run.SAVE_PATH
var resume_on_open := false

func _ready() -> void:
	resume_on_open = resume_on_open or bool(get_tree().get_meta("life_comic_resume",false))
	get_tree().remove_meta("life_comic_resume")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = ThemeKit.WALL
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margins.add_theme_constant_override("margin_"+side,12)
	add_child(margins)
	var column := VBoxContainer.new()
	margins.add_child(column)
	var tools := HBoxContainer.new()
	column.add_child(tools)
	button(tools,"返回首页",leave)
	var save_button := button(tools,"保存书签",func():
		run.s["scroll"] = scroll.scroll_vertical
		notice.text = "书签已保存" if run.save(save_path) else "保存失败，请检查磁盘空间")
	status = label("")
	column.add_child(status)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	strip = VBoxContainer.new()
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.add_theme_constant_override("separation",28)
	scroll.add_child(strip)
	var action_scroll := ScrollContainer.new()
	action_scroll.custom_minimum_size.y = 175
	action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(action_scroll)
	actions = VBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_scroll.add_child(actions)
	notice = label("向下阅读，未画的分镜会随着人生填充。")
	column.add_child(notice)
	if resume_on_open:
		if not run.load_save(save_path):
			save_enabled = false
			save_button.disabled = true
			status.text = "暂时无法读取这份书签"
			notice.text = "原存档已保留。返回首页后可重新开始一生。"
			button(actions,"返回首页",leave)
			return
		for i in range(run.s.pages.size()):
			run.s.pages[i] = Pages.upgrade_legacy(run.s.pages[i])
			append_page(run.s.pages[i],false)
	else:
		run.start(int(Time.get_unix_time_from_system()) ^ Time.get_ticks_usec())
		add_current()
	add_blank()
	refresh()
	if resume_on_open: call_deferred("restore_scroll")

func label(text: String) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_override("font",ThemeKit.font_body())
	node.add_theme_font_size_override("font_size",14)
	node.add_theme_color_override("font_color",ThemeKit.CREAM)
	return node

func button(parent: Node, text: String, callback: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 42
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_override("font",ThemeKit.font_body())
	node.add_theme_font_size_override("font_size",14)
	node.pressed.connect(callback)
	parent.add_child(node)
	return node

func add_blank() -> void:
	if is_instance_valid(blank):
		strip.remove_child(blank)
		blank.queue_free()
	blank = Page.new()
	blank.build({"blank":true,"panels":[{}],"slots":[Rect2(0,0,1,1)]},250)
	strip.add_child(blank)

func append_page(spec: Dictionary, animate: bool = true) -> void:
	var page := Page.new()
	page.build(spec,800)
	page.interactions_enabled = run.s.committed.is_empty() and run.s.terminal.is_empty() and spec.get("event_id","") == run.s.pending.get("id","") and int(spec.get("age",-1)) == run.s.age
	page.interaction_changed.connect(func(_index, _progress): autosave(); refresh_exploration())
	page.cinematic_changed.connect(func(_index): autosave())
	strip.add_child(page)
	if is_instance_valid(blank): strip.move_child(page,blank.get_index())
	if animate:
		page.reveal_panels()
		call_deferred("scroll_to_page",page)

func add_current() -> void:
	var spec := Pages.ending(run) if not run.s.terminal.is_empty() else Pages.make(run)
	run.s.pages.append(spec)
	append_page(spec)

func refresh() -> void:
	for child in actions.get_children():
		actions.remove_child(child)
		child.queue_free()
	status.text = "%d 岁 · 身体 %d · 心理 %d · 抽象 %d（%s）" % [run.s.age,run.s.scores.physical,run.s.scores.mental,run.s.scores.abstract,run.pack.rules.tiers[run.tier()].name]
	locked = false
	if not run.s.terminal.is_empty():
		button(actions,"这一卷读完了 · 返回首页",leave)
	elif not run.s.committed.is_empty():
		button(actions,"继续往下读",advance)
	else:
		var options: Array = run.options()
		for i in range(options.size()):
			var choice_button := button(actions,str(options[i]),select.bind(i))
			choice_button.name = "Choice_"+str(i)
	var exploring := _find_stage_panel("pixel_interaction")
	if exploring != null and run.s.committed.is_empty() and run.s.terminal.is_empty():
		var explore_button := button(actions,"◇ "+str(exploring.spec.pixel_interaction.get("label","观察现场")),explore_scene)
		explore_button.name = "ExploreScene"
		explore_button.disabled = bool(exploring.spec.get("interaction_progress",{}).get("completed",false))
	var cinema := _find_stage_panel("pixel_cg")
	if cinema != null:
		var row := HBoxContainer.new()
		row.name = "CinemaTools"
		actions.add_child(row)
		button(row,"重播特别镜头",func():
			var current := _find_stage_panel("pixel_cg")
			if not is_instance_valid(current): return
			scroll_to_page(current.get_parent())
			if is_instance_valid(current.pixel_stage): current.pixel_stage.replay_cg())
		button(row,"跳过镜头",func():
			var current := _find_stage_panel("pixel_cg")
			if is_instance_valid(current) and is_instance_valid(current.pixel_stage): current.pixel_stage.skip_cg())
	for page in strip.get_children():
		if page == blank: continue
		page.interactions_enabled = run.s.committed.is_empty() and run.s.terminal.is_empty() and page.spec.get("event_id","") == run.s.pending.get("id","") and int(page.spec.get("age",-1)) == run.s.age
	autosave()

func _find_stage_panel(key: String) -> Control:
	var children := strip.get_children()
	children.reverse()
	for page in children:
		if page == blank or not page.get("spec") is Dictionary: continue
		if str(page.spec.get("event_id","")) != str(run.s.pending.get("id","")) or int(page.spec.get("age",-1)) != run.s.age: continue
		for p in page.panels:
			if p.spec.has(key): return p
	return null

func explore_scene() -> void:
	var p := _find_stage_panel("pixel_interaction")
	if p == null: return
	scroll_to_page(p.get_parent())
	# Put the interaction panel itself on screen, not only the chapter header.
	await get_tree().process_frame
	await get_tree().process_frame
	p = _find_stage_panel("pixel_interaction")
	if not is_instance_valid(p): return
	scroll.scroll_vertical = int(p.get_parent().position.y+p.position.y)-8
	if is_instance_valid(p.pixel_stage): p.pixel_stage.perform_interaction()

func refresh_exploration() -> void:
	var explore := actions.get_node_or_null("ExploreScene")
	if explore != null: explore.disabled = true; explore.text = "✓ 已观察，可继续作出选择"

func select(index: int) -> void:
	if locked or not run.s.committed.is_empty(): return
	locked = true
	if run.choose(index).is_empty():
		locked = false
		return
	var spec := Pages.make(run,true)
	run.s.pages.append(spec)
	append_page(spec)
	refresh()

func advance() -> void:
	if locked or run.s.committed.is_empty(): return
	locked = true
	var age: int = run.s.age
	if not run.finish():
		locked = false
		return
	if run.s.age-age > 1:
		var gap := {"no":run.s.pages.size()+1,"age":run.s.age,"stage":"提笔带过","slots":[],"panels":[{"ink":"","shot":"detail","tone":"black","caption":"旁白：%d—%d 岁，日常在画外继续。下一格，留给值得停下来的事。" % [age,run.s.age],"shot_locked":true}]}
		run.s.pages.append(gap)
		append_page(gap,false)
	add_current()
	add_blank()
	refresh()

func autosave() -> void:
	if save_enabled: run.save(save_path)

func restore_scroll() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	scroll.scroll_vertical = int(run.s.get("scroll",0))

func scroll_to_page(page: Control) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(page): scroll.scroll_vertical = maxi(0,int(page.position.y))

func leave() -> void:
	run.s["scroll"] = scroll.scroll_vertical
	autosave()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not run.s.is_empty():
		run.s["scroll"] = scroll.scroll_vertical
		autosave()
