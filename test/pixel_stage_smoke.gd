extends SceneTree
const Run := preload("res://scripts/life_comic_run.gd")
const Pages := preload("res://scripts/life_comic_pages.gd")
const PixelPanel := preload("res://scripts/comic_panel.gd")
const Stage := preload("res://scripts/pixel_stage_view.gd")
var errors := 0
func verify(value: bool, message: String) -> void:
	if not value: errors += 1; push_error(message)
func _initialize() -> void:
	call_deferred("run_test")
func run_test() -> void:
	var palette: Dictionary = preload("res://scripts/pixel_environment_3d.gd").palette()
	for kind in ["book","contract","photo","flashlight","biscuit","tooth","eraser","eggs","plant","fridge","phone","meal","drum","key","badge","bench","blanket"]:
		var prop := preload("res://scripts/pixel_prop_3d.gd").build(kind,palette)
		verify(prop.get_child_count() > 0,"story prop geometry: "+kind)
		prop.free()
	root.size = Vector2i(900,700)
	root.content_scale_size = Vector2i(900,700)
	var life = Run.new(); life.start(39)
	life.s.pending = {}; life.s.age = 18; life.begin("LC11")
	var spec: Dictionary = Pages.make(life).panels[-1].duplicate(true)
	var p := PixelPanel.new()
	p.size = Vector2(880,670)
	p.position = Vector2(10,10)
	p.setup(spec,null)
	root.add_child(p)
	await process_frame
	await process_frame
	await process_frame
	verify(p.pixel_stage != null and is_instance_valid(p.pixel_stage.viewport),"visible panel owns real 3D viewport")
	verify(p.pixel_stage.lead is Node3D and p.pixel_stage.camera is Camera3D,"actor staged in real 3D world")
	verify(p.pixel_stage.lead.sprite is Sprite3D and p.pixel_stage.npc.sprite is Sprite3D,"lead and NPC use flat 2D artwork")
	verify(p.pixel_stage.lead.find_children("*","MeshInstance3D",true,false).is_empty(),"no voxel body geometry in character")
	verify(p.pixel_stage.lead.sprite.global_basis.z.dot(p.pixel_stage.camera.global_basis.z) > 0.999,"sprite faces the cinematic camera")
	verify(p.pixel_stage.viewport.size.x <= 320,"bounded pixel resolution")
	var ratio: Vector2 = p.pixel_stage._screen_rect.size/Vector2(p.pixel_stage.viewport.size)
	verify(is_equal_approx(ratio.x,roundf(ratio.x)) and is_equal_approx(ratio.x,ratio.y),"uniform integer pixel scaling")
	var before: Dictionary = life.snapshot()
	verify(p.pixel_stage.perform_interaction(),"story exploration starts")
	p.pixel_stage._process(3.7)
	verify(p.interaction_done,"exploration completes")
	verify(p.pixel_stage.object.global_position.distance_to(p.pixel_stage.lead.hand_anchor.global_position) < 0.01,"received object reaches current-frame receiver grip")
	verify(before == life.snapshot(),"exploration does not change fate or consume choice")
	verify(not p.pixel_stage.perform_interaction(),"completed discovery cannot settle twice")
	if "--capture" in OS.get_cmdline_user_args():
		await create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("D:/gamelife/pixel-stage-preview.png")
	p.hide()
	p.pixel_stage._process(0.5)
	await process_frame
	verify(not is_instance_valid(p.pixel_stage.viewport) and Stage.live_viewports == 0,"offscreen worlds release GPU resources")
	p.show()
	await process_frame
	await process_frame
	verify(p.pixel_stage.interacted,"restored stage retains interaction completion")
	p.queue_free()
	await process_frame
	verify(Stage.live_viewports == 0,"viewport counter cleaned on page destruction")
	print("PIXEL_STAGE_SMOKE ","PASS" if errors == 0 else "FAIL")
	quit(0 if errors == 0 else 1)
