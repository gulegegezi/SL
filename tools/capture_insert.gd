extends SceneTree
## 直接搭「漫画插页」面板截图：前半生、action=idle 的叙述页。

const Run := preload("res://scripts/life_comic_run.gd")
const Pages := preload("res://scripts/life_comic_pages.gd")
const ComicPanel := preload("res://scripts/comic_panel.gd")

var out_dir := "D:/gamelife/_insert_shots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()


func _run() -> void:
	root.size = Vector2i(520, 900)
	root.content_scale_size = Vector2i(520, 900)
	var bg := Control.new()
	bg.size = Vector2(520, 900)
	root.add_child(bg)
	var found := 0
	for id in ["LC01", "LC03", "LC06", "LC09", "LC11", "LC12", "LC18"]:
		var run = Run.new()
		run.start(42)
		run.s.pending = {}
		run.s.committed = {}
		var ev: Dictionary = run.events[id]
		run.s.age = int(ev.age_range[0])
		run.begin(id)
		var page: Dictionary = Pages.make(run)
		var insert_spec: Dictionary = {}
		for p in page.panels:
			if p.has("comic_insert"):
				insert_spec = p
				break
		if insert_spec.is_empty():
			continue
		var panel = ComicPanel.new()
		panel.size = Vector2(500, 400)
		panel.position = Vector2(10, 30 + found * 430)
		bg.add_child(panel)
		panel.setup(insert_spec, null)
		panel.set_revealed(true)
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/insert_%d.png" % [out_dir, found])
		print("insert: ", id, " age=", run.s.age, " title=", ev.title)
		found += 1
		if found >= 3:
			break
	print("insert shots: ", found)
	quit()
