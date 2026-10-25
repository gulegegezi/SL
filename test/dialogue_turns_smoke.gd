extends SceneTree
## 多轮对话回归：对白按数据里的「名字：台词」顺序成格，中间可插旁白。

const Run := preload("res://scripts/life_comic_run.gd")
const Pages := preload("res://scripts/life_comic_pages.gd")

const CASES := ["LC01", "LC02", "LC03", "LC23", "LC31", "LC34"]


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


func _expected(ev: Dictionary) -> Array:
	var out: Array = []
	for raw in str(ev.get("npc_dialogue", "")).split(char(10), false):
		var line := str(raw).strip_edges()
		if line.is_empty():
			continue
		var at := line.find("：")
		out.append(line.left(at) if at > 0 else "")
	return out


func run() -> void:
	for eid in CASES:
		var run = _new_run(eid)
		var ev: Dictionary = run.events[eid]
		var expected := _expected(ev)
		assert(expected.size() >= 4, eid + " 对话轮次太少")
		var page: Dictionary = Pages.make(run)
		var speakers: Array = []
		for p in page.panels:
			if str(p.get("text_channel", "")) == "dialogue":
				speakers.append(str(p.get("speaker_label", "")))
				assert(not str(p.get("bubble", "")).is_empty(), eid + " 对白格不能空")
		assert(speakers == expected, "%s 说话人顺序不对：%s" % [eid, str(speakers)])
		# 主角那一格不挂 NPC 立绘
		for p in page.panels:
			if str(p.get("speaker_label", "")) == "你":
				assert(str(p.get("support", "")) == "", eid + " 主角格不该有 NPC 立绘")
				assert(bool(p.get("world_solo", false)), eid + " 主角格应是单人舞台")
	print("PASS: dialogue turns match authored order (%d cases)" % CASES.size())
	quit()
