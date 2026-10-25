extends RefCounted
## 关键抉择之间跳年，不代替玩家选任何选项。
static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/short_life.json"))
	return _data

static func node(id: String) -> Dictionary:
	return data().get("nodes", {}).get(id, {})

static func pick(s, rng: RandomNumberGenerator) -> Dictionary:
	var chapter_age := 1
	for age in data().ages:
		if int(age) <= int(s.age): chapter_age = int(age)
	var ordinary: Array = []
	var personal: Array = []
	for event in data().events:
		if int(event.age) != chapter_age or s.used_ids.has(str(event.id)): continue
		if event.has("need_tags"):
			for tag in event.need_tags:
				if s.has_tag(str(tag)): personal.append(event); break
		else: ordinary.append(event)
	var pool: Array = personal if not personal.is_empty() and rng.randf() < 0.75 else ordinary
	if pool.is_empty(): pool = personal
	if pool.is_empty(): return {}
	var selected: Dictionary = pool[rng.randi_range(0, pool.size()-1)].duplicate(true)
	if s.age - s.short_previous_age > 1:
		selected["jump_from"] = s.short_previous_age
	return selected

static func next_age(s) -> int:
	var target := int(s.lifespan)
	for age in data().ages:
		if int(age) > int(s.age): target = int(age); break
	if int(s.short_target_age) > int(s.age): target = int(s.short_target_age)
	return mini(int(s.lifespan), target)

static func jump_text(s, from_age: int) -> String:
	var interval := "%d—%d 岁 · 时光掠过" % [from_age + 1, int(s.age) - 1]
	if int(s.age) - from_age == 2: interval = "%d 岁 · 时光掠过" % (from_age+1)
	var detail := "上学、通勤、洗衣和吃饭，日子在重复的小事里往前走。"
	if s.has_tag("手艺人"): detail = "你在店里练手艺、攒工资。手上的茧厚了，第一次修好的东西还记得。"
	elif s.has_tag("画画"): detail = "课本、账单和画本换了几轮。你偶尔还会给太阳多画几条腿。"
	elif s.has_tag("乐队"): detail = "练习鼓收进柜子，节拍偶尔从通勤的耳机里回来。"
	if s.health <= 4: detail += "身体有些吃力，下一个决定更需要留一点余地。"
	return interval + "\n" + detail
