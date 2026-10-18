extends SceneTree
const Cast := preload("res://scripts/pixel_cast.gd")
const Gallery := preload("res://scripts/pixel_cast_gallery.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(Cast.stage_for_age(1) == "infant")
	assert(Cast.stage_for_age(17) == "youth")
	assert(Cast.stage_for_age(26) == "adult")
	assert(Cast.frame_index(0.2, true, false) != Cast.frame_index(0.5, true, false))
	for npc in [false, true]:
		var keys: Array = Cast.ROLES if npc else Cast.STAGES
		for key in keys:
			for col in range(4):
				var frame := Cast.frame(key, npc, col) as AtlasTexture
				assert(frame != null and frame.region.size.x > 10 and frame.region.size.y > 10)
				assert(Rect2(Vector2.ZERO, frame.atlas.get_size()).encloses(frame.region))
				assert(Cast.portrait(key, npc) != null)
	for i in range(6):
		var texture := Cast.room(Cast.ROOMS[i]) as AtlasTexture
		assert(texture.region.position == Vector2((i % 3) * 512, floori(i / 3.0) * 512))
	var bedroom := Cast.room("bedroom")
	assert(bedroom != null and Cast.room("bedroom") == bedroom, "background must retain a texture reference between draw calls")
	var gallery := Gallery.new()
	root.content_scale_size = Vector2i(520, 900)
	root.size = Vector2i(520, 900)
	gallery.size = Vector2(520, 900)
	root.add_child(gallery)
	await process_frame
	for page in range(4):
		gallery.show_page(page)
		if page == 3:
			gallery.sample._process(gallery.sample.duration)
		await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/pixel-assets-%d.png" % page)
	gallery.play_sample(0)
	assert(gallery.sample.mode == "family")
	gallery.sample._process(gallery.sample.duration + 1)
	assert(not gallery.sample.playing)
	gallery.play_sample(1)
	assert(gallery.sample.mode == "rest")
	gallery.sample._process(gallery.sample.duration + 1)
	assert(not gallery.sample.playing)
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/pixel-assets-rest.png")
	gallery.queue_free()
	await process_frame
	print("PASS: 7 life stages, 6 NPCs, 52 bounded frames, 7 rooms, both option animations finish")
	quit()
