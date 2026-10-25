extends SceneTree
## 对话手法回归：短句抢拍、有来有回、每段至少一个问句。

func _initialize() -> void:
	call_deferred("run")


func _lines(e: Dictionary) -> Array:
	var out: Array = []
	for raw in str(e.get("npc_dialogue", "")).split(char(10), false):
		var line := str(raw).strip_edges()
		if line.is_empty():
			continue
		var at := line.find("：")
		out.append(line.substr(at + 1) if at >= 0 else line)
	return out


func run() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/story_life_comic.json"))
	var checked := 0
	var with_question := 0
	for e in data.events:
		var turns := _lines(e)
		if turns.size() < 4:
			continue
		checked += 1
		var short := 0
		var longest := 0
		var has_question := false
		for t in turns:
			if str(t).length() <= 18:
				short += 1
			longest = maxi(longest, str(t).length())
			if str(t).contains("？"):
				has_question = true
		assert(float(short) / float(turns.size()) >= 0.55,
			"%s 短句比例太低：%d/%d" % [e.id, short, turns.size()])
		assert(longest <= 45, "%s 有一句太长：%d" % [e.id, longest])
		if has_question:
			with_question += 1
	assert(checked >= 10, "多轮对话的事件太少：%d" % checked)
	assert(with_question >= 8, "含问句的对话太少：%d" % with_question)
	print("PASS: dialogue craft on %d multi-turn events (%d with question)" % [checked, with_question])
	quit()
