extends SceneTree
## 多轮对话回归：一行一个「名字：台词」，解析成多格对白，说话人顺序正确。

const Run := preload("res://scripts/life_comic_run.gd")
const Pages := preload("res://scripts/life_comic_pages.gd")

const CASES := {
	"LC01": ["妈妈", "爸爸", "妈妈", "爸爸", "你"],
	"LC03": ["爸爸", "妈妈", "爸爸", "你", "妈妈"],
	"LC31": ["班长", "你", "班长", "你", "班长"],
	"LC02": ["妈妈", "你", "爸爸", "妈妈", "你"],
	"LC23": ["身边的人", "你", "身边的人", "你", "身边的人", "你"],
}


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
	for eid in CASES.keys():
		var run = _new_run(eid)
		var page: Dictionary = Pages.make(run)
		var speakers: Array = []
		for p in page.panels:
			if str(p.get("text_channel", "")) == "dialogue":
				var label := str(p.get("speaker_label", ""))
				speakers.append(label)
				assert(not str(p.get("bubble", "")).is_empty(), eid + " 对白格不能空")
		assert(speakers == CASES[eid],
			"%s 说话人顺序不对：%s" % [eid, str(speakers)])
		# 主角那一格不挂 NPC 立绘
		for p in page.panels:
			if str(p.get("speaker_label", "")) == "你":
				assert(str(p.get("support", "")) == "", eid + " 主角格不该有 NPC 立绘")
				assert(bool(p.get("world_solo", false)), eid + " 主角格应是单人舞台")
	print("PASS: multi-turn dialogues parse in order (%d cases)" % CASES.size())
	quit()
