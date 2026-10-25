extends SceneTree
## 漫画插页回归：只在前半生（≤30 岁）替换叙述页，且必须带旁白与气泡。

const Run := preload("res://scripts/life_comic_run.gd")
const Pages := preload("res://scripts/life_comic_pages.gd")


func _initialize() -> void:
	call_deferred("run")


func _page_for(id: String) -> Dictionary:
	var run = Run.new()
	run.start(42)
	run.s.pending = {}
	run.s.committed = {}
	var ev: Dictionary = run.events[id]
	run.s.age = int(ev.age_range[0])
	run.begin(id)
	var page: Dictionary = Pages.make(run)
	page["_age"] = run.s.age
	return page


func run() -> void:
	var first_half := ["LC01", "LC03", "LC06", "LC09", "LC11", "LC12", "LC18"]
	for id in first_half:
		var page := _page_for(id)
		var insert: Dictionary = {}
		for p in page.panels:
			if p.has("comic_insert"):
				insert = p
				break
		assert(not insert.is_empty(), id + " 前半生应该有漫画插页")
		assert(insert.get("presentation", "") == "comic_insert")
		var panels: Array = insert.comic_insert.panels
		assert(panels.size() == 2, "插页固定两格")
		assert(not str(panels[0].get("caption", "")).is_empty(), "第一格要有旁白")
		assert(not str(panels[1].get("bubble", "")).is_empty(), "第二格要有对话气泡")

	# 后半生不做插页
	for id in ["LC23", "LC24"]:
		var page := _page_for(id)
		for p in page.panels:
			assert(not p.has("comic_insert"), id + " 属于后半生，不应改成插页")

	print("PASS: comic insert only in first half, with narration and bubble")
	quit()
