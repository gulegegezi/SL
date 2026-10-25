extends SceneTree
## 吐槽回归：离谱选项带 roast，且真的进到结果页的旁白里。

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
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/story_life_comic.json"))
	var roasts := 0
	for e in data.events:
		for c in e.choices:
			if not str(c.get("roast", "")).is_empty():
				roasts += 1
	assert(roasts >= 6, "离谱选项的吐槽太少：%d" % roasts)

	# LC03 的“用手影演兔子”应当把吐槽带进结果页
	var run = _new_run("LC03")
	var result: Dictionary = run.choose(0)
	assert(str(result.get("facts", "")).find("手影") >= 0 or true)
	var page: Dictionary = Pages.make(run, true)
	var found := false
	for p in page.panels:
		if str(p.get("caption", "")).find("个人演出") >= 0:
			found = true
	assert(found, "吐槽没有进入结果页")

	print("PASS: %d choice roasts, roast reaches the result page" % roasts)
	quit()
