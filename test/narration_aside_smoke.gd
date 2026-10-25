extends SceneTree
## 旁白回归：对白之间要插入 tier 对应的旁白，整页不能只剩对话。

const Run := preload("res://scripts/life_comic_run.gd")
const Pages := preload("res://scripts/life_comic_pages.gd")


func _initialize() -> void:
	call_deferred("run")


func _new_run(eid: String):
	var run = Run.new()
	run.start(42)
	run.s.pending = {}
	run.s.committed = {}
	var ev: Dictionary = run.events[eid]
	run.s.age = int(ev.age_range[0])
	run.begin(eid)
	return run


func run() -> void:
	for eid in ["LC01", "LC31", "LC29", "LC34"]:
		var run = _new_run(eid)
		var ev: Dictionary = run.events[eid]
		var tier := int(run.tier())
		var expected := str(ev.narrator_asides[tier]).strip_edges()
		var page: Dictionary = Pages.make(run)
		var narration := 0
		var has_aside := false
		for p in page.panels:
			if str(p.get("text_channel", "")) == "narration":
				narration += 1
				if str(p.get("caption", "")).find(expected) >= 0:
					has_aside = true
		assert(has_aside, eid + " 缺少 tier 旁白插入")
		assert(narration >= 3, eid + " 旁白太少：%d" % narration)
	print("PASS: narration asides between dialogue turns")
	quit()
