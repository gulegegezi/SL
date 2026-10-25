extends SceneTree
## 电波系误会：LC34 的误会说明必须进入页面，且三个选项可结算。

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
	var run = _new_run("LC34")
	var ev: Dictionary = run.events["LC34"]
	assert(ev.choices.size() == 3, "LC34 要有三个选项")
	assert(not str(ev.get("misread", "")).is_empty(), "LC34 要有误会说明")
	var page: Dictionary = Pages.make(run)
	var found := false
	for p in page.panels:
		if str(p.get("caption", "")).find("误会：") >= 0:
			found = true
	assert(found, "误会说明没有进入页面")
	for i in range(3):
		var r = _new_run("LC34")
		var result: Dictionary = r.choose(i)
		assert(not str(result.get("facts", "")).is_empty(), "LC34 选项 %d 无结果" % i)
	print("PASS: denpa misread panel and three outcomes")
	quit()
