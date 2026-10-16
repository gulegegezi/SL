extends RefCounted
## 将选择编排成「走到目的地 → 行动 → 结果」，世界记录放在单局 GameState 中。
const PLACES := {
	"home": Vector2(61, 85), "school": Vector2(158, 76),
	"office": Vector2(260, 82), "garden": Vector2(66, 148),
	"square": Vector2(158, 125), "pond": Vector2(259, 146)
}
const NAMES := {"home": "家", "school": "学校", "office": "工作坊", "garden": "菜园", "square": "小镇广场", "pond": "河畔"}

static func contains_any(text: String, words: Array) -> bool:
	for word in words:
		if text.contains(str(word)):
			return true
	return false

static func make_world() -> Dictionary:
	return {"position": Vector2(61, 85), "visits": {}, "crops": 0, "friends": 0,
		"partner": false, "child": false, "home_level": 0, "career": 0,
		"memories": [], "last_action": "walk"}

static func plan(event: Dictionary, choice: Dictionary, fallback: String) -> Dictionary:
	var label := str(choice.get("label", choice.get("text", "")))
	var context := str(event.get("title", "")) + str(event.get("text", ""))
	var action := fallback
	var place := "square"
	# 优先解释「我选择做什么」，事件用于补全「去 / 不去」等短选项。
	if contains_any(label, ["不去", "拒绝", "不投", "不借", "算了", "什么都不", "假装", "装傻", "沉默", "躺平", "摆烂"]):
		action = "refuse"
	elif contains_any(label, ["休息", "睡", "在家", "捂住耳朵"]):
		action = "rest"
	elif contains_any(label, ["钓鱼"]):
		action = "fish"
	elif contains_any(label + context, ["种地", "种菜", "田园", "农场"]):
		action = "farm"
	elif contains_any(label, ["医院", "医生", "治疗", "养病", "体检"]):
		action = "medical"
	elif contains_any(label, ["买房", "首付", "租房", "全款", "房贷", "贷款买下", "回老家买"]):
		action = "move"
	elif contains_any(label, ["结婚", "相亲", "表白", "约会", "领证"]):
		action = "romance"
	elif contains_any(label, ["唱", "跳舞", "广场舞", "书法", "画画", "乐器", "钢琴"]):
		action = "music"
	elif contains_any(label, ["游戏", "手机", "上网", "论坛", "电竞", "短视频"]):
		action = "game"
	elif contains_any(label, ["跑", "游泳", "健身", "锻炼", "打球"]):
		action = "sport"
	elif contains_any(label, ["陪", "照顾", "哄", "劝架", "家人"]):
		action = "family"
	elif contains_any(label, ["旅行", "旅游", "出国", "散步", "看一看"]):
		action = "explore"
	elif contains_any(label, ["学习", "学", "考试", "考研", "读", "写", "补", "理科", "文科"]):
		action = "study"
	elif contains_any(label, ["工作", "打工", "摆摊", "赚钱", "加班", "创业", "上班", "职业", "投", "谈薪", "跳槽"]):
		action = "work"
	elif contains_any(label, ["朋友", "交流", "沟通", "交往", "赴约"]):
		action = "social"
	elif label.length() <= 5:
		if contains_any(context, ["生娃", "孙子出生"]): action = "family"
		elif contains_any(context, ["结婚", "相亲", "约会", "恋爱"]): action = "romance"
		elif contains_any(context, ["生病", "医院", "体检"]): action = "medical"
		elif contains_any(context, ["房", "搬家"]): action = "move"
		elif contains_any(context, ["学校", "考试", "高考", "作业", "志愿", "分科"]): action = "study"
		elif contains_any(context, ["聚会", "社区", "团建"]): action = "social"
	var prop := ""
	# 里程碑按具体选项编排，不让抓周、买房、婚礼退化成属性动画。
	if str(event.get("id", "")) == "C01":
		action = "grasp"
		prop = "phone" if label.contains("手机") else ("coin" if label.contains("钞票") else "pen")
	if str(event.get("id", "")) == "N14" and label == "再等等": action = "refuse"
	if str(event.get("id", "")) == "N15": action = "romance"
	if str(event.get("id", "")) in ["N16", "N42"]: action = "family"
	if str(event.get("id", "")) == "C03" and label == "什么都不学": action = "refuse"
	match action:
		"study": place = "school"
		"work", "medical": place = "office"
		"rest", "family", "game", "move", "refuse", "grasp": place = "home"
		"farm": place = "garden"
		"sport", "sad", "explore", "fish": place = "pond"
	return {"action": action, "place": place, "target": PLACES[place],
		"prop": prop,
		"label": label, "result": str(choice.get("result", "这个选择成为了人生的一部分。")),
		"event": str(event.get("title", "人生片段"))}

static func remember(world: Dictionary, shot: Dictionary, age: int, money: int) -> void:
	var place: String = shot.place
	world.visits[place] = int(world.visits.get(place, 0)) + 1
	world.last_action = shot.action
	world.position = shot.target
	world.home_level = maxi(int(world.home_level), 2 if money >= 100 else (1 if money >= 30 else 0))
	if shot.action == "move": world.home_level = maxi(1, int(world.home_level))
	match str(shot.action):
		"farm": world.crops = mini(int(world.crops) + 1, 4)
		"work": world.career = mini(int(world.career) + 1, 4)
		"social": world.friends = mini(int(world.friends) + 1, 4)
		"romance":
			if contains_any(shot.event + shot.result, ["结婚", "领证", "在一起", "恋爱", "牵手"]):
				world.partner = true
		"family":
			if contains_any(shot.event + shot.result, ["孩子出生", "生孩子", "宝宝", "孩子上学", "生娃", "孙子出生"]):
				world.child = true
	world.memories.append({"age": age, "event": shot.event, "choice": shot.label, "action": shot.action})
