extends SceneTree
## 截一张新事件（LC26）的漫画页，确认续写内容真的能画出来。

const Run := preload("res://scripts/life_comic_run.gd")
const Pages := preload("res://scripts/life_comic_pages.gd")
const ComicPage := preload("res://scripts/comic_page.gd")

var out_dir := "D:/gamelife/_new_event_shots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()


func _run() -> void:
	root.size = Vector2i(520, 1400)
	root.content_scale_size = Vector2i(520, 1400)
	var bg := Control.new()
	bg.size = Vector2(520, 1400)
	root.add_child(bg)
	var run = Run.new()
	run.start(42)
	run.s.pending = {}
	run.s.committed = {}
	var ev: Dictionary = run.events["LC26"]
	run.s.age = int(ev.age_range[0])
	run.begin("LC26")
	var page: Dictionary = Pages.make(run)
	var view = ComicPage.new()
	view.build(page, 1100.0)
	view.position = Vector2(14, 20)
	bg.add_child(view)
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir + "/lc26.png")
	print("saved lc26: ", ev.title)
	quit()
