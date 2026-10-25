## comic_director.gd — 漫画分镜导演
## 决定：这一岁画几格、怎么切版、每格什么镜别、哪些年直接「提笔带过」。
## 全部是纯逻辑（不碰节点），所以可以用 test/comic_smoke.gd 无头跑。
extends RefCounted
const SemanticPlan := preload("res://scripts/comic_performance.gd")

# ---- 版式：归一化坐标（0..1），分格越多个数越多，但始终有一格是「大格」 ----
const LAYOUTS := {
	1: [
		[Rect2(0, 0, 1, 1)],
	],
	2: [
		[Rect2(0, 0, 1, 0.54), Rect2(0, 0.54, 1, 0.46)],
		[Rect2(0, 0, 0.64, 1), Rect2(0.64, 0, 0.36, 1)],
	],
	3: [
		[Rect2(0, 0, 1, 0.46), Rect2(0, 0.46, 0.5, 0.54), Rect2(0.5, 0.46, 0.5, 0.54)],
		[Rect2(0, 0, 0.56, 0.5), Rect2(0.56, 0, 0.44, 0.5), Rect2(0, 0.5, 1, 0.5)],
		[Rect2(0, 0, 0.44, 1), Rect2(0.44, 0, 0.56, 0.52), Rect2(0.44, 0.52, 0.56, 0.48)],
	],
	4: [
		[Rect2(0, 0, 1, 0.34), Rect2(0, 0.34, 0.5, 0.33), Rect2(0.5, 0.34, 0.5, 0.33), Rect2(0, 0.67, 1, 0.33)],
		[Rect2(0, 0, 0.52, 0.42), Rect2(0.52, 0, 0.48, 0.42), Rect2(0, 0.42, 0.34, 0.58), Rect2(0.34, 0.42, 0.66, 0.58)],
	],
	5: [
		[Rect2(0, 0, 1, 0.30), Rect2(0, 0.30, 0.5, 0.35), Rect2(0.5, 0.30, 0.5, 0.35),
		 Rect2(0, 0.65, 0.5, 0.35), Rect2(0.5, 0.65, 0.5, 0.35)],
		[Rect2(0, 0, 0.62, 0.44), Rect2(0.62, 0, 0.38, 0.44), Rect2(0, 0.44, 0.38, 0.27),
		 Rect2(0.38, 0.44, 0.62, 0.27), Rect2(0, 0.71, 1, 0.29)],
	],
	6: [
		[Rect2(0, 0, 1, 0.28), Rect2(0, 0.28, 0.5, 0.26), Rect2(0.5, 0.28, 0.5, 0.26),
		 Rect2(0, 0.54, 0.34, 0.46), Rect2(0.34, 0.54, 0.33, 0.46), Rect2(0.67, 0.54, 0.33, 0.46)],
	],
}

# ---- 性格标签 → 分镜密度（用户要的「随选项改变的性格分镜」）----
const EXTRO := ["会分享", "粘人", "社牛", "仗义", "共情", "勇敢", "要强", "上热搜", "报喜不报忧"]
const INTRO := ["守口如瓶", "观察者", "社恐", "内向", "孤僻", "沉默", "网瘾"]

const SFX_CALM := ["……", "沙沙", "簌", "呼——"]
const SFX_HIT := ["！？", "咚", "啪", "咯噔"]
const SFX_UP := ["叮", "啪！", "哗——"]
const SFX_ABSURD := ["？", "嗡——", "啪嗒"]


# ==========================================================
# 一局的分镜参数（每局随机，所以每次存档的漫画长度不同）
# ==========================================================
static func new_run(rng: RandomNumberGenerator) -> Dictionary:
	return {
		"seed": rng.randi(),
		"density_off": rng.randi_range(-1, 1),      # 每局随机 ±1 格的偏移（不用倍率，倍率会把年龄曲线压平）
		"skip_rate": rng.randf_range(0.08, 0.20),    # 提笔带过的概率
		"skip_bias": rng.randi_range(4, 7),          # 每隔几步更容易带过
	}


## 年龄增加基础篇幅；健康和选择形成的性格再影响密度。
static func stage_base(age: int) -> int:
	if age <= 6: return 2
	if age <= 12: return 2
	if age <= 18: return 3
	if age <= 30: return 4
	if age <= 60: return 5
	return 5


## 性格倾向：外向的人一页能塞更多「事件」，内向的人更多独白格
static func persona_bias(s) -> int:
	var up := 0
	var down := 0
	for t in EXTRO:
		if s.has_tag(t): up += 1
	for t in INTRO:
		if s.has_tag(t): down += 1
	return mini(2, up) - mini(2, down)


## 健康直接压缩分镜数：身体不行，人生就没有那么多镜头
static func health_bias(s) -> int:
	var h: int = s.health
	if h <= 3: return -2
	if h <= 6: return -1
	if h >= 16: return 1
	return 0


static func panels_for(s, run: Dictionary, rng: RandomNumberGenerator) -> int:
	var base := stage_base(int(s.age))
	var abs_bonus := 1 if int(s.abstract_val) >= 61 else 0
	var n: int = base + health_bias(s) + persona_bias(s) + abs_bonus \
		+ int(run.get("density_off", 0)) + rng.randi_range(0, 1)
	return clampi(n, 2, 6)


## 全话数 = 还能活的年数（寿命被选择改变，人生长度就变）
static func series_len(s) -> int:
	return maxi(int(s.age), int(s.lifespan))


static func layout_for(n: int, rng: RandomNumberGenerator) -> Array:
	var pool: Array = LAYOUTS.get(clampi(n, 1, 6), LAYOUTS[1])
	return pool[rng.randi_range(0, pool.size() - 1)]


## 是否把这一岁「提笔带过」
static func should_montage(s, run: Dictionary, rng: RandomNumberGenerator) -> bool:
	var age := int(s.age)
	# 童年跳得快，晚年也跳，中年是重头戏
	var mul := 1.0
	if age <= 5: mul = 1.15
	elif age <= 17: mul = 0.95
	elif age <= 45: mul = 0.5
	else: mul = 1.0
	# 健康差 → 更容易一笔带过（没精力过）
	if int(s.health) <= 5: mul *= 1.4
	var p: float = float(run.get("skip_rate", 0.25)) * mul
	return rng.randf() < clampf(p, 0.0, 0.32)

## Only ordinary low-impact events may be summarized. Never silently choose a branch,
## personality, romance, death/lifespan or relationship decision for the player.
static func can_montage(ev: Dictionary, s) -> bool:
	if int(s.health) <= 6: return false
	if not s.story_queue.is_empty(): return false
	if str(ev.get("id", "")).begins_with("OP") or str(ev.get("id", "")).begins_with("V"): return false
	if ev.has("next") or ev.has("tags") or bool(ev.get("important", false)): return false
	var context := str(ev.get("title", "")) + str(ev.get("text", ""))
	for word in ["结婚", "婚礼", "生子", "生娃", "去世", "死亡", "买房", "高考", "辞职"]:
		if context.contains(word): return false
	for choice in ev.get("choices", []):
		for protected in ["next", "tags", "relations", "nearDeath", "require", "requireTags", "requireRelations", "showIf", "hideIf"]:
			if choice.has(protected): return false
		for attr in choice.get("effects", {}):
			if str(attr) == "lifespan" or absi(int(choice.effects[attr])) > 2: return false
	return not ev.get("choices", []).is_empty()

static func scene_for(text: String, age: int) -> String:
	for pair in [["hospital", ["医院", "病", "治疗", "医生"]], ["classroom", ["学校", "老师", "考试", "作业"]], ["office", ["工作", "公司", "加班", "同事"]], ["bedroom", ["睡", "宿舍", "休息", "房间"]]]:
		for word in pair[1]:
			if text.contains(word): return pair[0]
	return "home" if age < 14 else "office"

static func supporting_role(text: String, age: int) -> String:
	for pair in [["teacher", ["老师", "上课", "学校"]], ["boss", ["上司", "老板", "公司"]], ["partner", ["爱人", "恋爱", "伴侣", "结婚"]], ["parent", ["妈妈", "爸爸", "家人", "父母"]]]:
		for word in pair[1]:
			if text.contains(word): return "npc_" + str(pair[0])
	return "npc_parent" if age < 14 else "npc_friend"


# ==========================================================
# 生成一页
# ==========================================================
static func ink_key(age: int) -> String:
	if age <= 2: return "infant_infant"
	if age <= 6: return "lead_child"
	if age <= 12: return "lead_teen"
	if age <= 18: return "lead_youth"
	if age <= 40: return "lead_adult"
	if age <= 60: return "lead_middle"
	return "lead_elder"


static func split_sentences(text: String) -> Array:
	var out: Array = []
	var cur := ""
	for i in range(text.length()):
		var ch := text.substr(i, 1)
		cur += ch
		if "。！？…；\n".find(ch) >= 0:
			var t := cur.strip_edges()
			if t.length() > 0:
				out.append(t)
			cur = ""
	var tail := cur.strip_edges()
	if tail.length() > 0:
		out.append(tail)
	return out


static func _is_quote(t: String) -> bool:
	return t.begins_with("「") or t.begins_with("“")


## 一页 = 一岁 = 一个事件
static func build(s, ev: Dictionary, run: Dictionary, rng: RandomNumberGenerator, no: int) -> Dictionary:
	if ev.has("comic"):
		return preload("res://scripts/short_storyboard.gd").page(s, ev, ink_key(int(s.age)), no)
	var n := panels_for(s, run, rng)
	var slots := layout_for(n, rng)
	var ink := ink_key(int(s.age))
	var sentences := split_sentences(str(ev.get("text", "")))
	var title := str(ev.get("title", ""))
	var is_abs := int(s.abstract_val) >= 61
	var context := title + str(ev.get("text", ""))

	var panels: Array = []
	for i in range(n):
		panels.append({
			"scene": scene_for(context, int(s.age)),
			"support": supporting_role(context, int(s.age)) if i == 0 else "",
			"shot": _shot(i, n, rng),
			"tone": _tone(i, n),
			"ink": ink,
			# 同一个人的 4 张线稿轮着用：一格一个姿势，别整页复制粘贴
			"frame": (no + i * 3) % 4,
			"caption": "",
			"bubble": "",
			"sfx": "",
			"vertical": false,
			"dx": rng.randf_range(-0.18, 0.18),
		})

	# 文字分配：第一格放标题 + 第一句，其余格按句分配，末格留白做「抉择特写」
	var idx := 0
	var rest: Array = sentences
	if rest.size() > 0:
		var first: String = str(rest[0])
		if _is_quote(first):
			panels[0]["bubble"] = first.trim_prefix("「").trim_suffix("」")
			panels[0]["caption"] = "【%s】" % title
		else:
			panels[0]["caption"] = "【%s】\n%s" % [title, first]
		idx = 1
	for i in range(1, n - 1):
		if idx >= rest.size():
			break
		var t := str(rest[idx])
		idx += 1
		if _is_quote(t):
			panels[i]["bubble"] = t.trim_prefix("「").trim_suffix("」")
		else:
			panels[i]["caption"] = t
	# 没分到的句子塞进倒数第二格（避免丢内容）
	if idx < rest.size() and n >= 2:
		var extra := ""
		while idx < rest.size():
			extra += str(rest[idx])
			idx += 1
		var j: int = maxi(1, n - 2)
		panels[j]["caption"] = (str(panels[j]["caption"]) + "\n" + extra).strip_edges()

	# 空白的格给拟声词（纯视觉节拍）
	for i in range(n):
		if str(panels[i]["caption"]).is_empty() and str(panels[i]["bubble"]).is_empty():
			panels[i]["sfx"] = _sfx(i, is_abs, rng)
			panels[i]["vertical"] = i == n - 1

	return SemanticPlan.annotate({
		"no": no,
		"age": int(s.age),
		"stage": _stage(int(s.age)),
		"title": title,
		"montage": false,
		"panels": panels,
		"slots": slots,
		"series": series_len(s),
	})


static func _shot(i: int, n: int, rng: RandomNumberGenerator) -> String:
	if n == 1:
		return "wide"
	if i == 0:
		return "wide" if rng.randf() < 0.65 else "medium"
	if i == n - 1:
		return "extreme" if n >= 4 else "close"
	var pool := ["medium", "close", "detail", "medium"]
	return pool[rng.randi_range(0, pool.size() - 1)]


static func _tone(i: int, n: int) -> String:
	# 全页只允许一格纯黑（高光时刻），否则整页压得喘不过气
	if n <= 1:
		return "paper"
	if n == 2:
		return "tone" if i == 1 else "paper"
	if n == 3:
		if i == 2:
			return "black"
		return "tone" if i == 1 else "paper"
	if i == n - 2:
		return "black"
	if i == 1:
		return "tone"
	return "paper"


static func _sfx(i: int, absurd: bool, rng: RandomNumberGenerator) -> String:
	if absurd:
		return SFX_ABSURD[rng.randi_range(0, SFX_ABSURD.size() - 1)]
	var pool := SFX_CALM
	if i == 0:
		pool = SFX_CALM
	elif i % 2 == 0:
		pool = SFX_HIT
	else:
		pool = SFX_UP
	return pool[rng.randi_range(0, pool.size() - 1)]


static func _stage(age: int) -> String:
	if age <= 6: return "童年"
	if age <= 12: return "小学"
	if age <= 18: return "少年"
	if age <= 25: return "青年"
	if age <= 40: return "成年"
	if age <= 60: return "中年"
	return "晚年"


# ==========================================================
# 「提笔带过」页
# ==========================================================
static func build_montage(s, items: Array, rng: RandomNumberGenerator, no: int) -> Dictionary:
	var lines: Array = []
	for it in items:
		lines.append("· %d 岁　%s" % [int(it.get("age", 0)), str(it.get("title", ""))])
	var body := "这些年没发生什么值得画的事：\n" + "\n".join(lines)
	var result := ""
	for it in items:
		if not str(it.get("result", "")).is_empty():
			result = str(it.get("result", ""))
	var panels := [
		{"shot": "wide", "tone": "black", "ink": "", "caption": body, "bubble": "", "sfx": "提笔带过", "vertical": false},
		{"shot": "detail", "tone": "tone", "ink": "", "caption": result, "bubble": "", "sfx": "", "vertical": false},
	]
	return {
		"no": no,
		"age": int(s.age),
		"stage": _stage(int(s.age)),
		"title": "提笔带过",
		"montage": true,
		"panels": panels,
		"slots": [Rect2(0, 0, 1, 0.56), Rect2(0, 0.56, 1, 0.44)],
		"series": series_len(s),
	}


## 选择结果格：单独一张「反应镜」
static func reaction_panel(text: String, delta: int) -> Dictionary:
	var tone := "paper"
	var sfx := "……"
	if delta >= 6:
		tone = "tone"
		sfx = "叮"
	elif delta <= -6:
		tone = "black"
		sfx = "！？"
	elif delta < 0:
		sfx = "咯噔"
	return {"shot": "close", "tone": tone, "ink": "", "caption": text, "bubble": "", "sfx": sfx, "vertical": false}


## 选择后的「结果页」：这一页专门画「你刚才做了什么」
static func build_result(s, c: Dictionary, result_text: String, rng: RandomNumberGenerator, no: int) -> Dictionary:
	if c.has("comic"):
		var directed := c.duplicate(true)
		directed["title"] = "▶ " + str(c.get("label", ""))
		return preload("res://scripts/short_storyboard.gd").page(s, directed, ink_key(int(s.age)), no, true)
	var eff: Dictionary = c.get("effects", {})
	var delta := 0
	for k in eff:
		if k == "abstract":
			continue
		delta += int(eff[k])
	var ink := ink_key(int(s.age))
	var label := str(c.get("label", ""))
	var tone2 := "tone" if delta > 0 else ("black" if delta < 0 else "paper")
	var sfx_text := "叮" if delta >= 6 else ("啪" if delta > 0 else ("！？" if delta <= -6 else "咯噔"))
	if delta == 0:
		sfx_text = "……"
	var panels := [
		{"shot": "medium", "tone": "paper", "ink": ink, "caption": "▶ " + label,
		 "bubble": "", "sfx": "", "vertical": false, "scene": scene_for(label + result_text, int(s.age)), "frame": 1},
		{"shot": "close", "tone": tone2, "ink": ink, "caption": result_text,
		 "bubble": "", "sfx": "", "vertical": false},
		{"shot": "detail", "tone": "black" if delta < 0 else "paper", "ink": "",
		 "caption": effect_summary(c), "bubble": "",
		 "sfx": sfx_text, "vertical": true},
	]
	return SemanticPlan.annotate({
		"no": no,
		"age": int(s.age),
		"stage": _stage(int(s.age)),
		"title": "结果",
		"montage": false,
		"result": true,
		"panels": panels,
		"slots": [Rect2(0, 0, 1, 0.42), Rect2(0, 0.42, 0.62, 0.58), Rect2(0.62, 0.42, 0.38, 0.58)],
		"series": series_len(s),
	})

static func effect_summary(choice: Dictionary) -> String:
	var labels := {"health": "体质", "int": "心智", "charm": "魅力", "luck": "运气", "money": "金钱", "lifespan": "寿命", "abstract": "抽象度"}
	var lines: PackedStringArray = []
	for key in choice.get("effects", {}):
		lines.append("%s %+d" % [labels.get(key, key), int(choice.effects[key])])
	for tag in choice.get("tags", []): lines.append("留下性格：" + str(tag))
	return " · ".join(lines) if not lines.is_empty() else "这一刻，留在了记忆里。"
