extends SceneTree
## 纯文本叙事回归：LC29/30 必须是文本页，且文本量足够大。

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
		assert(bool(page.get("text_only", false)), eid + " 应是纯文本页")
		assert(str(page.panels[0].get("presentation", "")) == "text", eid + " 首页应是 text")
		assert(not str(page.panels[0].get("heading", "")).is_empty(), eid + " 文本页要有标题")
		var chars := 0
		for p in page.panels:
			assert(str(p.get("presentation", "")) == "text", eid + " 每一格都应是文本")
			chars += str(p.get("caption", "")).length()
		assert(chars >= 120, eid + " 文本量太少：%d 字" % chars)

	# 非文本事件不能被误标
	var other = _new_run("LC01")
	assert(str(Pages.make(other).panels[0].get("presentation", "")) != "text", "普通页不应变成文本页")

	print("PASS: text-only pages LC29/LC30 carry enough text")
	quit()
