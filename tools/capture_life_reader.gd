extends SceneTree
const State := preload("res://scripts/game_state.gd")
const Director := preload("res://scripts/comic_director.gd")
var main
var out := "res://docs/life-reader"

func _initialize() -> void:
	call_deferred("run")

func shot(name: String) -> void:
	await create_timer(0.65).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")

func run() -> void:
	preload("res://scripts/save_manager.gd").writes_enabled = false
	DirAccess.make_dir_recursive_absolute(out)
	root.content_scale_size = Vector2i(520,900)
	root.size = Vector2i(520,900)
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.autosave_enabled = false
	main.gc.state = State.new()
	main.gc.state.age = 28
	main.gc.state.health = 13
	main.gc.state.money = 32
	main.gc.state.tags = {"观察者": true}
	main.gc.rng.seed = 61021
	main._comic = Director.new_run(main.gc.rng)
	main._page_no = 7
	var event := {"id": "READER_CAPTURE", "title": "凌晨一点的办公室", "text": "窗外最后一班地铁驶过。你合上电脑，同事却把一份新的工作放在桌上。今晚，你想为自己留下一点时间。", "choices": [
		{"label": "关掉电脑，回家休息", "effects": {"health": 2}, "tags": ["观察者"], "result": "你第一次准时离开。城市的灯在窗外退去，你终于睡了一个完整的觉。"},
		{"label": "留下来，把这件事做完", "effects": {"health": -2, "money": 3}, "tags": ["要强"], "result": "办公室的灯亮到天明。你得到了一笔奖金，也把疲惫留进下一页。"}]}
	main.current_event = event
	main._render_page(event)
	await shot("01-current")
	if main._scroll_tween != null: main._scroll_tween.kill()
	main._scroll.scroll_vertical = 300
	await shot("02-scroll")
	main._on_comic_choice(event.choices[0])
	await create_timer(0.15).timeout
	await shot("03-result")
	if main._scroll_tween != null: main._scroll_tween.kill()
	main._scroll.scroll_vertical = int(main._strip_pages.size.y)
	await shot("04-unwritten")
	root.content_scale_size = Vector2i(360,640)
	root.size = Vector2i(360,640)
	main.size = Vector2(360,640)
	await process_frame
	main._scroll.scroll_vertical = 0
	await shot("05-mobile")
	main.queue_free()
	await process_frame
	print("Saved five real Godot reader screenshots")
	quit()
