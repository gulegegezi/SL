extends SceneTree
## 续写事件回归：LC26/27/28 的结构、选项、结果页都能跑。

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
	for eid in ["LC26", "LC27", "LC28", "LC31", "LC32", "LC33"]:
		var run = _new_run(eid)
		var page: Dictionary = Pages.make(run)
		assert(page.panels.size() >= 3, eid + " 页面至少三格")
		var ev: Dictionary = run.events[eid]
		assert(ev.choices.size() == 3, eid + " 要有三个选项")
		for c in ev.choices:
			assert(c.has("lines") and c.lines.size() == 4, eid + " 选项台词要有四档")
			assert(c.has("outcomes") and not c.outcomes.is_empty(), eid + " 选项要有结果")
			var o: Dictionary = c.outcomes[0]
			assert(o.voices.size() == 4, eid + " 结果要四档旁白")
			assert(o.panels.size() == 3, eid + " 结果页三格")
		# 三个选项都实际结算一次
		for i in range(3):
			var r = _new_run(eid)
			var result: Dictionary = r.choose(i)
			assert(not result.is_empty(), "%s 选项 %d 结算失败" % [eid, i])
			assert(not str(result.get("facts", "")).is_empty(), "%s 选项 %d 缺结果文案" % [eid, i])
			var result_page: Dictionary = Pages.make(r, true)
			assert(result_page.panels.size() >= 2, "%s 结果页组装失败" % eid)

	print("PASS: LC26-28/31-33 build pages, 3 choices each, outcomes resolve")
	quit()
