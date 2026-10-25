extends SceneTree
## 对话框立绘回归：说话人映射 + 对白格进入对话框。

const ComicPanel := preload("res://scripts/comic_panel.gd")
const Run := preload("res://scripts/life_comic_run.gd")
const Pages := preload("res://scripts/life_comic_pages.gd")


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	assert(ComicPanel.speaker_key("妈妈", {}) == "npc_parent")
	assert(ComicPanel.speaker_key("爸爸", {}) == "npc_mate")
	assert(ComicPanel.speaker_key("老师", {}) == "npc_teacher")
	assert(ComicPanel.speaker_key("同桌", {}) == "npc_friend")
	assert(ComicPanel.speaker_key("你", {"ink": "lead_teen"}) == "lead_teen")
	assert(ComicPanel.speaker_key("陌生人", {"support": "npc_boss"}) == "npc_boss")
	assert(ComicPanel.speaker_key("陌生人", {"ink": "lead_adult"}) == "lead_adult")

	# 有对白的一页：对白格应进入对话框
	var run = Run.new()
	run.start(42)
	run.s.pending = {}
	run.s.committed = {}
	run.s.age = 6
	run.begin("LC26")
	var page: Dictionary = Pages.make(run)
	var dialogue_panels := 0
	for p in page.panels:
		if str(p.get("text_channel", "")) == "dialogue":
			dialogue_panels += 1
	assert(dialogue_panels >= 1, "LC26 应有对白格")
	print("PASS: speaker mapping and dialogue panels present (%d)" % dialogue_panels)
	quit()
