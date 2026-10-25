extends SceneTree
## 前 30 岁的语气回归：抽象/元叙述的标记必须还在。
## 防止以后有人把旁白改回四平八稳的说明文。

const META := ["系统提示", "旁白", "本场", "本作", "命运", "项目", "流程", "剧本"]


func _initialize() -> void:
	call_deferred("run")


func _hits(text: String) -> bool:
	for marker in META:
		if text.find(marker) >= 0:
			return true
	return false


func run() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/story_life_comic.json"))
	var dialogue = JSON.parse_string(FileAccess.get_file_as_string("res://data/story_life_dialogue.json"))
	assert(data != null and dialogue != null)

	var facts_hits := 0
	var guide_hits := 0
	var response_hits := 0
	for e in data.events:
		if int(e.age_range[0]) > 30:
			continue
		if _hits(str(e.get("facts", ""))):
			facts_hits += 1
		for line in dialogue.events.get(e.id, {}).get("guide", []):
			if _hits(str(line)):
				guide_hits += 1
		for line in dialogue.events.get(e.id, {}).get("responses", []):
			if _hits(str(line)):
				response_hits += 1

	assert(facts_hits >= 8, "前 30 岁的开场旁白里，抽象/元叙述标记太少：%d" % facts_hits)
	assert(guide_hits >= 6, "选项前的旁白不够「自我意识」：%d" % guide_hits)
	assert(response_hits >= 10, "选择后的旁白吐槽太少：%d" % response_hits)

	# 不能因为玩梗把事实撑爆（面板换行有限）
	for e in data.events:
		var text := str(e.get("facts", ""))
		assert(text.length() <= 120, "%s 的 facts 过长：%d" % [e.id, text.length()])

	print("PASS: abstract/meta tone in first 30 years (facts %d, guide %d, responses %d)" % [facts_hits, guide_hits, response_hits])
	quit()
