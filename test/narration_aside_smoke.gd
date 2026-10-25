extends SceneTree
## 旁白插拍回归：按事件类型决定插 0/1/2 次，位置在对白之间。

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


func _aside_hits(page: Dictionary, ev: Dictionary) -> int:
	var hits := 0
	for p in page.panels:
		if str(p.get("text_channel", "")) != "narration":
			continue
		var cap := str(p.get("caption", ""))
		for a in ev.get("narrator_asides", []):
			if not str(a).is_empty() and cap.find(str(a)) >= 0:
				hits += 1
				break
	return hits


func run() -> void:
	# 规则：text_only 0 / misread 2 / echo 1 / 对白≥6 句 2 / 普通 1 / 显式覆盖
	assert(Pages.aside_count_for({"text_only": true}) == 0)
	assert(Pages.aside_count_for({"misread": "x"}) == 2)
	assert(Pages.aside_count_for({"echo": {"from": "LC01"}}) == 1)
	assert(Pages.aside_count_for({"npc_dialogue": "你：一\n你：二\n你：三\n你：四\n你：五\n你：六"}) == 2)
	assert(Pages.aside_count_for({"npc_dialogue": "你：一\n你：二"}) == 1)
	assert(Pages.aside_count_for({"aside_count": 0, "misread": "x"}) == 0)
	assert(Pages.aside_count_for({"aside_plan": {"count": 3}}) == 3, "aside_plan 应覆盖类型规则")

	# 位置：数据指定优先；否则挑以 ！/？ 结尾的对白
	var panels := [
		{"text_channel": "dialogue", "bubble": "你：来了。"},
		{"text_channel": "dialogue", "bubble": "他：你终于来了？"},
		{"text_channel": "dialogue", "bubble": "你：走吧。"},
		{"text_channel": "dialogue", "bubble": "他：就现在！"},
	]
	assert(Pages.aside_positions(panels, 2, [1]) == [1], "after 应被尊重")
	assert(Pages.aside_positions(panels, 2) == [2, 4], "应挑问句/叹句所在的对白序号")
	assert(Pages.aside_positions(panels, 2, []) == [2, 4])

	var cases := {"LC34": 2, "LC29": 0, "LC03": 1}
	for eid in cases:
		var run = _new_run(eid)
		var ev: Dictionary = run.events[eid]
		var page: Dictionary = Pages.make(run)
		var hits := _aside_hits(page, ev)
		assert(hits == int(cases[eid]), "%s 旁白插拍数应为 %d，实际 %d" % [eid, cases[eid], hits])
		var narration := 0
		for p in page.panels:
			if str(p.get("text_channel", "")) == "narration":
				narration += 1
		assert(narration >= 2, eid + " 旁白格太少：%d" % narration)
	print("PASS: aside count follows event type (%d cases)" % cases.size())
	quit()
