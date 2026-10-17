## GameState — 单局游戏运行时状态
## 对应 HTML 版的全局变量 S
class_name GameState
extends RefCounted

# ---- 属性 ----
var story_world: Dictionary = {}  # 单局持续存在的像素小镇与人生足迹

var province: String = ""
var region: String = ""
var gender: String = ""
var body: Dictionary = {}
var health_type: Dictionary = {}
var tier: Dictionary = {}
var line: String = ""
var parent_job: Dictionary = {}
var birth_hour: Dictionary = {}
var birth_dream: String = ""

# 六维属性
var intl: int = 8       # int 是 GDScript 关键字
var health: int = 8
var charm: int = 8
var luck: int = 8
var money: int = 10
var lifespan: int = 70
var abstract_val: int = 0

# 运行时
var age: int = 0
var step: int = 0
var max_step: int = 46
var tags: Dictionary = {}
var achieved: Dictionary = {}
var family: Dictionary = {}
var talent: Dictionary = {}
var recent: Array = []
var used_ids: Array = []
# 分支剧情：choice.next / event.next 推入的待播节点，按顺序优先于随机事件池。
var story_queue: Array = []
var opening_done: bool = false
var abstract_peaked: int = 0
var abstract_dropped: int = 0
var near_death: int = 0
var money_zero_count: int = 0
var lives: int = 0
var death_reason: String = ""
var rating: String = ""

# ---- 便捷方法 ----
func get_attr(key: String) -> int:
	match key:
		"int": return intl
		"health": return health
		"charm": return charm
		"luck": return luck
		"money": return money
		"abstract": return abstract_val
		"lifespan": return lifespan
		"age": return age
		"abstractPeaked": return abstract_peaked
		"abstractDropped": return abstract_dropped
		"nearDeath": return near_death
		"moneyZeroCount": return money_zero_count
		_: return 0

func set_attr(key: String, val: int) -> void:
	match key:
		"int": intl = val
		"health": health = val
		"charm": charm = val
		"luck": luck = val
		"money": money = val
		"abstract": abstract_val = val
		"lifespan": lifespan = val

func has_tag(tag: String) -> bool:
	return tags.get(tag, false) != false

func tag_value(tag: String) -> Variant:
	return tags.get(tag, false)

func clamp_all() -> void:
	intl = clampi(intl, 0, 20)
	health = clampi(health, 0, 20)
	charm = clampi(charm, 0, 20)
	luck = clampi(luck, 0, 20)
	abstract_val = clampi(abstract_val, 0, 100)
	money = maxi(0, money)

func get_tier_key() -> String:
	return tier.get("key", "")

func is_debt_free() -> bool:
	return !(tags.get("负债", false) and money > 0)
