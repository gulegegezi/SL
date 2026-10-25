extends SceneTree
## 对话框回归：LC29/30 保持分格 + 对话框，文本量足够大。

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
	for eid in ["LC29", "LC30"]:
		var run = _new_run(eid)
		var page: Dictionary = Pages.make(run)
		assert(bool(page.get("text_only", false)), eid + " 应是长文本页")
		var chars := 0
		for p in page.panels:
			assert(str(p.get("box", "")) == "dialogue", eid + " 每一格都应是对话框")
			assert(str(p.get("presentation", "")) != "text", eid + " 不应切成纯文本页")
			chars += str(p.get("caption", "")).length()
		assert(chars >= 120, eid + " 文本量太少：%d 字" % chars)

	# 非文本事件不能被误标
	var other = _new_run("LC01")
	assert(str(Pages.make(other).panels[0].get("presentation", "")) != "text", "普通页不应变成文本页")

	print("PASS: LC29/LC30 keep dialogue boxes and carry enough text")
	quit()
