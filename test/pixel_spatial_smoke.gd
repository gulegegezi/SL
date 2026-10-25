extends SceneTree
## 大型家具与婴儿摇篮的实际舞台、互动落点和画面边界回归。

const Run := preload("res://scripts/life_comic_run.gd")
const Pages := preload("res://scripts/life_comic_pages.gd")
const PixelPanel := preload("res://scripts/comic_panel.gd")
const Stage := preload("res://scripts/pixel_stage_view.gd")

var errors := 0

func verify(value: bool, message: String) -> void:
	if not value:
		errors += 1
		push_error(message)

func ground_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x,a.z).distance_to(Vector2(b.x,b.z))

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	root.size = Vector2i(900,700)
	root.content_scale_size = Vector2i(900,700)
	DirAccess.make_dir_recursive_absolute("D:/gamelife/_render_cmp")
	for fixture in [
		{"name":"fridge","kind":"fridge","age":30,"action":"reach","clearance":1.0,"reach":1.35},
		{"name":"bench","kind":"bench","age":30,"action":"sit","clearance":1.20,"reach":1.50},
		{"name":"newborn","kind":"blanket","age":0,"action":"receive","clearance":0.0,"reach":0.0},
	]:
		var life := Run.new()
		life.start(39)
		life.s.pending = {}
		life.s.age = fixture.age
		life.begin("LC11")
		var spec: Dictionary = Pages.make(life).panels[-1].duplicate(true)
		spec["age"] = fixture.age
		spec["ink"] = "infant_infant" if fixture.name == "newborn" else "lead_adult"
		spec["support"] = "npc_parent"
		spec["scene"] = "home"
		spec["world_solo"] = false
		spec["pixel_interaction"] = {"prop":fixture.kind,"target":"prop","action":fixture.action,"label":"检查","reveal":"检查完成"}
		var panel := PixelPanel.new()
		panel.size = Vector2(880,670)
		panel.position = Vector2(10,10)
		panel.setup(spec,null)
		root.add_child(panel)
		await process_frame
		await process_frame
		await process_frame
		var stage = panel.pixel_stage
		verify(stage != null and is_instance_valid(stage.viewport),fixture.name+": viewport created")
		if stage == null or not is_instance_valid(stage.viewport):
			panel.queue_free()
			continue
		verify(stage.perform_interaction(),fixture.name+": interaction starts")
		stage._process(3.7)
		verify(stage.interacted,fixture.name+": interaction completes")
		verify(ground_distance(stage.lead.position,stage.npc.position) >= Stage.ACTOR_CLEARANCE-0.0001,fixture.name+": actors do not overlap")
		var projected: Vector2 = stage.camera.unproject_position(stage.lead.global_position+Vector3(0,stage.lead.height*0.5,0))
		verify(Rect2(Vector2.ZERO,Vector2(stage.viewport.size)).has_point(projected),fixture.name+": actor remains inside the rendered frame")
		var projected_npc: Vector2 = stage.camera.unproject_position(stage.npc.global_position+Vector3(0,stage.npc.height*0.5,0))
		verify(projected.distance_to(projected_npc) >= stage.viewport.size.x*0.05,fixture.name+": actors stay visually separated in the camera projection")
		if fixture.name == "fridge":
			verify(stage.prop_rest == Stage.FRIDGE_POS,"fridge uses its dedicated furniture bay")
			verify(ground_distance(stage.lead.position,Stage.FRIDGE_POS) >= fixture.clearance-0.0001,"fridge body does not intersect the lead")
			verify(ground_distance(stage.lead.position,Stage.FRIDGE_POS) <= fixture.reach,"lead walks to the fridge instead of interacting from across the room")
			var fridge_footprint := Rect2(Vector2(Stage.FRIDGE_POS.x-0.425,Stage.FRIDGE_POS.z-0.325),Vector2(0.85,0.65))
			for furniture_name in ["SofaBase","SofaBack","TableTop","BookcaseBack"]:
				var furniture := stage.world.get_node(furniture_name) as MeshInstance3D
				var dimensions := (furniture.mesh as BoxMesh).size
				var footprint := Rect2(Vector2(furniture.position.x-dimensions.x*0.5,furniture.position.z-dimensions.z*0.5),Vector2(dimensions.x,dimensions.z))
				verify(not fridge_footprint.intersects(footprint),"fridge footprint does not overlap "+furniture_name)
		elif fixture.name == "bench":
			verify(stage.prop_rest == Stage.BENCH_POS,"bench uses its dedicated furniture bay")
			verify(ground_distance(stage.lead.position,Stage.BENCH_POS) >= fixture.clearance-0.0001,"bench body does not intersect the lead")
			verify(ground_distance(stage.lead.position,Stage.BENCH_POS) <= fixture.reach,"lead walks to the bench instead of interacting from across the room")
		else:
			verify(is_equal_approx(stage.lead.position.y,Stage.LEAD_POS.y+0.65),"newborn stays on the cradle mattress")
			verify(stage.lead.is_newborn,"newborn keeps the lying-down artwork")
		if "--capture" in OS.get_cmdline_user_args():
			await create_timer(0.2).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("D:/gamelife/_render_cmp/spatial_"+fixture.name+".png")
		panel.queue_free()
		await process_frame
		await process_frame
	print("PIXEL_SPATIAL_SMOKE ","PASS" if errors == 0 else "FAIL")
	quit(0 if errors == 0 else 1)
