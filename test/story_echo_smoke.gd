extends SceneTree
## 剧情回响（串）回归：echo 必须指向更早的事件，motif 必须引用存在的条目。

func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var raw := FileAccess.get_file_as_string("res://data/story_life_comic.json")
	var data = JSON.parse_string(raw)
	assert(data != null, "story_life_comic.json 解析失败")
	var ids := {}
	for e in data.get("events", []):
		assert(not ids.has(e.id), "事件 id 重复: " + str(e.id))
		ids[e.id] = e

	var echoes := 0
	for e in data.get("events", []):
		if not e.has("echo"):
			continue
		echoes += 1
		var src := str(e["echo"].get("from", ""))
		assert(ids.has(src), "%s: echo.from 不存在 %s" % [e.id, src])
		assert(int(ids[src].age_range[0]) < int(e.age_range[0]),
			"%s: echo 来源 %s 不比它更早" % [e.id, src])
		assert(not str(e["echo"].get("line", "")).is_empty(), "%s: echo 缺 line" % e.id)
	assert(echoes >= 5, "前半生至少要有 5 处回响，实际 %d" % echoes)

	var motifs: Dictionary = data.get("motifs", {})
	assert(motifs.size() >= 5, "motif 至少 5 个")
	for name in motifs:
		var entries: Array = motifs[name].get("events", [])
		assert(entries.size() >= 2, "motif %s 至少要串两处" % name)
		for eid in entries:
			assert(ids.has(eid), "motif %s 引用了不存在的事件 %s" % [name, eid])

	print("PASS: %d echoes, %d motifs" % [echoes, motifs.size()])
	quit()
