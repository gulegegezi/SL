## GameController — 核心游戏引擎
## 移植自 gamelife.html 的 newGame/pickEvent/choose/nextPhase/endGame 逻辑
extends RefCounted

const DataLoader := preload("res://scripts/data_loader.gd")
const GameState := preload("res://scripts/game_state.gd")
const SaveManager := preload("res://scripts/save_manager.gd")

signal game_started(s: GameState)
signal event_picked(s: GameState, ev: Dictionary)
signal choice_resolved(s: GameState, result_text: String)
signal phase_advanced(s: GameState)
signal game_ended(s: GameState, ending: Dictionary, info: Dictionary)

var state: GameState
var meta: Dictionary
var rng := RandomNumberGenerator.new()

func init() -> void:
	DataLoader.ensure_loaded()
	rng.randomize()
	meta = SaveManager.load_meta()

# ==========================================================
# 工具函数
# ==========================================================
func rnd(n: int) -> int:
	return rng.randi() % n

func pick(arr: Array) -> Variant:
	if arr.is_empty():
		return null
	return arr[rnd(arr.size())]

func wpick(items: Array, wf: Callable) -> Variant:
	var total := 0.0
	var weights: Array[float] = []
	for it in items:
		var w := float(wf.call(it))
		w = maxf(0.0, w)
		weights.append(w)
		total += w
	if total <= 0.0:
		return null
	var r := rng.randf() * total
	for i in range(items.size()):
		r -= weights[i]
		if r <= 0.0:
			return items[i]
	return items[items.size() - 1]

# ==========================================================
# 新游戏（掷骰出生）
# ==========================================================
func new_game() -> GameState:
	state = GameState.new()
	var rkeys := DataLoader.region_keys()
	var region_key: String = wpick(rkeys, func(k): return 4 if DataLoader.regions()[k].get("hard", false) else 10)
	var region: Dictionary = DataLoader.regions()[region_key]
	state.region = region_key

	var provinces: Array = region.get("provinces", [])
	state.province = pick(provinces)

	var g_roll := rng.randf()
	state.gender = "？" if g_roll >= 0.96 else ("男" if g_roll < 0.48 else "女")
	state.body = pick(DataLoader.body_types())
	state.health_type = pick(DataLoader.health_types())
	state.tier = wpick(DataLoader.tiers(), func(t): return t.get("weight", 10))
	state.line = "normal" if rng.randf() < float(state.tier.get("normalRate", 0.35)) else "absurd"

	state.parent_job = pick(DataLoader.parent_jobs())
	state.birth_hour = pick(DataLoader.birth_hours())
	state.birth_dream = pick(DataLoader.birth_dreams())

	# 初始属性
	var st := {
		"int": 8, "health": 8, "charm": 8, "luck": 8, "money": 10,
		"abstract": (20 + rnd(20)) if state.line == "absurd" else rnd(12)
	}
	# 地区加成
	var rb: Dictionary = region.get("bonus", {})
	for k in rb:
		st[k] = (st.get(k, 0) + rb[k])
	# 体型修正
	st["health"] += state.body.get("delta", 0)
	# 档位加成
	var tb: Dictionary = state.tier.get("bonus", {})
	for k in tb:
		st[k] = (st.get(k, 0) + tb[k])
	# 父母职业
	var pj: Dictionary = state.parent_job.get("effects", {})
	for k in pj:
		st[k] = (st.get(k, 0) + pj[k])

	st["money"] = maxi(0, st.get("money", 0) + state.tier.get("money", 0))
	st["lifespan"] = 70 + state.health_type.get("lifespan", 0) + int(maxf(0, float(st.get("health", 0))) * 1.5)

	state.intl = clampi(st.get("int", 8), 0, 20)
	state.health = clampi(st.get("health", 8), 0, 20)
	state.charm = clampi(st.get("charm", 8), 0, 20)
	state.luck = clampi(st.get("luck", 8), 0, 20)
	state.money = maxi(0, st.get("money", 10))
	state.abstract_val = clampi(st.get("abstract", 0), 0, 100)
	state.lifespan = maxi(15, st.get("lifespan", 70))
	state.abstract_peaked = state.abstract_val
	state.abstract_dropped = state.abstract_val
	state.lives = state.tier.get("lives", 0)

	# 成就检查
	var xhsd := DataLoader.xhsd_provinces()
	if xhsd.has(state.province):
		state.achieved["山河大学"] = true
		meta["provincesBorn"][state.province] = true
		_unlock_achievement("山河大学")
		var all_xhsd := true
		for p in xhsd:
			if not meta["provincesBorn"].has(p):
				all_xhsd = false
				break
		if all_xhsd:
			_unlock_achievement("山河四省满贯")

	if state.tier.get("key") == "hang":
		_unlock_achievement("天命之子")
	if state.tier.get("key") == "lawanle" and state.line == "normal":
		_unlock_achievement("天崩开局")

	meta["plays"] = meta.get("plays", 0) + 1
	SaveManager.save_meta(meta)

	game_started.emit(state)
	return state

## 开局剧情入口：普通线 / 抽象线各自从 story_opening.json 的 start 节点开始。
## 序章节点通过 choice.next / event.next 串成分支树，播放期间不推进年龄。
func begin_opening() -> bool:
	if state == null or state.opening_done or not state.story_queue.is_empty():
		return false
	var start := DataLoader.opening_start(state.line)
	if start.is_empty():
		return false
	state.story_queue = [start]
	return true

# ==========================================================
# 事件抽取
# ==========================================================
func pick_event() -> Dictionary:
	var s := state

	# 分支剧情优先：上一选项 next 指定的节点不参与随机池，也不会被 recent 过滤。
	while not s.story_queue.is_empty():
		var nid: String = str(s.story_queue.pop_front())
		var branch := DataLoader.find_story_node(nid)
		if not branch.is_empty():
			var node: Dictionary = _fill_node(branch)
			event_picked.emit(state, node)
			return node

	# 特殊事件优先
	var xhsd := DataLoader.xhsd_provinces()
	if s.age <= 12 and s.province != "" and xhsd.has(s.province) and not s.achieved.has("_xhsd"):
		s.achieved["_xhsd"] = true
		var ev := DataLoader.find_event("S_XHSD")
		if not ev.is_empty():
			return ev

	if s.age >= 20 and rng.randf() < 0.012:
		var ev := DataLoader.find_event("S_HOT")
		if not ev.is_empty() and not s.recent.has("S_HOT"):
			return ev
	if s.age >= 20 and s.health <= 6 and rng.randf() < 0.30:
		var ev := DataLoader.find_event("S_NEAR")
		if not ev.is_empty():
			return ev
	if s.age >= 25 and s.health <= 4 and rng.randf() < 0.40:
		var ev := DataLoader.find_event("S_ICU")
		if not ev.is_empty() and not s.recent.has("S_ICU"):
			return ev
	if s.line == "absurd" and s.age >= 25 and s.abstract_val >= 50 and not s.has_tag("退役") and rng.randf() < 0.05:
		var ev := DataLoader.find_event("S_RETIRE")
		if not ev.is_empty() and not s.recent.has("S_RETIRE"):
			return ev
	if s.age >= 20 and rng.randf() < 0.006:
		var ev := DataLoader.find_event("S_LOTTERY")
		if not ev.is_empty():
			return ev

	# 主候选池筛选
	var cands: Array = []
	for e in DataLoader.events():
		if s.recent.has(e.get("id", "")):
			continue
		var eline: String = e.get("line", "common")
		if eline != "common" and eline != s.line and eline != "lucky":
			continue
		if e.get("id") == "A015" and s.has_tag("退休"):
			continue
		# 标签 / 关系 / 选择记忆 / 年龄 / 属性条件统一走 _cond_matches。
		var c: Dictionary = e.get("cond", {})
		if not _cond_matches(c):
			continue
		# once：长线剧情一局只出现一次。
		if e.get("once", false) and s.used_ids.has(e.get("id", "")):
			continue
		if e.get("id") == "S_LOTTERY" and rng.randf() > 0.5:
			continue
		cands.append(e)

	# 加权抽取
	var ev = wpick(cands, func(e):
		var w := float(e.get("weight", 10))
		if e.get("line") == "lucky":
			w = minf(w, 4.0)
		var stage: String = e.get("stage", "")
		var eid: String = e.get("id", "")
		if stage == "physio":
			var matched := false
			if s.age <= 12 and (eid == "P01" or eid == "P05"):
				matched = true
			elif s.age >= 11 and s.age <= 16 and (eid == "P02" or eid == "P03" or eid == "P04" or eid == "P05"):
				matched = true
			elif s.age >= 17 and s.age <= 30 and (eid == "P06" or eid == "P07"):
				matched = true
			elif s.age >= 26 and s.age <= 45 and (eid == "P08" or eid == "P09"):
				matched = true
			elif s.age >= 45 and (eid.begins_with("P1") or eid.begins_with("P2")):
				matched = true
			else:
				matched = false
			w *= 3.0 if matched else 0.6
		if s.age <= 12 and stage == "child":
			w *= 2.6
		if s.age > 13 and s.age < 30 and stage == "adult":
			w *= 1.5
		if s.age >= 55 and (eid.begins_with("N3") or eid.begins_with("N4")):
			w *= 1.8
		if s.abstract_val >= 70 and e.get("line") == "absurd":
			w *= 1.4
		if s.abstract_val < 20 and e.get("line") == "normal":
			w *= 1.4
		return w
	)

	if ev == null:
		# 兜底：取任意不在 recent 中的事件；已抓过周就不再把 C01 兜回来。
		for e in DataLoader.events():
			if s.recent.has(e.get("id", "")):
				continue
			if e.get("id") == "C01" and s.has_tag("_已抓周"):
				continue
			ev = e
			break

	if ev == null:
		return {}

	var eDict: Dictionary = _fill_node(ev)
	event_picked.emit(state, eDict)
	return eDict

# ==========================================================
# 选择处理
# ==========================================================
func apply_effects(eff: Dictionary) -> void:
	for k in eff:
		var v: int = eff[k]
		if v == 0:
			continue
		if k == "lifespan":
			state.lifespan = maxi(10, state.lifespan + v)
			continue
		var current := state.get_attr(k)
		state.set_attr(k, current + v)
	state.clamp_all()

func choose(c: Dictionary, ev: Dictionary) -> void:
	var s := state
	var eff: Dictionary = c.get("effects", {})
	# 标签
	if c.has("tags"):
		for t in c["tags"]:
			s.tags[t] = true
			_unlock_game_achievement(t)
	if ev.has("tags"):
		for t in ev["tags"]:
			s.tags[t] = true
			_unlock_game_achievement(t)
	if c.get("nearDeath", false):
		s.near_death += 1

	apply_effects(eff)
	if c.has("relations"):
		for who in c["relations"]:
			s.add_relation(str(who), int(c["relations"][who]))
	# 记住这次选择，后续事件文本可用 {choice:事件ID} 回忆它。
	var eid := str(ev.get("id", ""))
	if not eid.is_empty():
		s.choice_log[eid] = str(c.get("memory", c.get("label", "")))
	_queue_story_next(c, ev)

	var result_text: String = _fill_text(str(c.get("result", "")))
	choice_resolved.emit(s, result_text)

	# 延迟推进（UI 动画时间由调用方处理）
func advance_after_choice(ev: Dictionary) -> void:
	var s := state
	s.step += 1
	s.recent.append(ev.get("id", ""))
	if s.recent.size() > 8:
		s.recent.pop_front()
	var eid: String = ev.get("id", "")
	if not s.used_ids.has(eid):
		s.used_ids.append(eid)
	# 分支树里还有下一幕：不涨年龄，先把这段剧情播完。
	if not s.story_queue.is_empty():
		phase_advanced.emit(s)
		return
	_next_phase(int(ev.get("ageGain", -1)))

# ==========================================================
# 分支剧情：next 解析 / 选项显隐 / 条件判断
# ==========================================================
## choice.next 优先，其次 event.next。支持字符串或
## {"default": "OP14", "when": [{"tags": ["社牛"], "next": "OP13A"}]}。
func _resolve_next(spec: Variant) -> String:
	if spec == null:
		return ""
	if typeof(spec) == TYPE_STRING or typeof(spec) == TYPE_STRING_NAME:
		return str(spec)
	if typeof(spec) != TYPE_DICTIONARY:
		return ""
	var d: Dictionary = spec
	for rule in d.get("when", []):
		if typeof(rule) == TYPE_DICTIONARY and _cond_matches(rule):
			return str(rule.get("next", ""))
	return str(d.get("default", ""))

func _queue_story_next(c: Dictionary, ev: Dictionary) -> void:
	var nxt := _resolve_next(c.get("next", null))
	if nxt.is_empty():
		nxt = _resolve_next(ev.get("next", null))
	if nxt.is_empty():
		if bool(ev.get("endOpening", false)):
			state.opening_done = true
		return
	if DataLoader.find_story_node(nxt).is_empty():
		push_warning("story next target missing: " + nxt)
		return
	state.story_queue.push_back(nxt)

## 把 {choice:事件ID} 换成当时的 memory；没记录就退成“那一次”。
func _fill_text(text: String) -> String:
	if text.is_empty() or not text.contains("{choice:"):
		return text
	var out := text
	for eid in state.choice_log:
		out = out.replace("{choice:%s}" % str(eid), str(state.choice_log[eid]))
	var re := RegEx.new()
	re.compile("\\{choice:[^}]+\\}")
	for m in re.search_all(out):
		out = out.replace(m.get_string(0), "那一次")
	return out

## 返回填好回忆文本的副本，避免污染 DataLoader 里的原始 JSON。
func _fill_node(node: Dictionary) -> Dictionary:
	var out: Dictionary = node.duplicate(true)
	out["title"] = _fill_text(str(out.get("title", "")))
	out["text"] = _fill_text(str(out.get("text", "")))
	if out.has("altTitle"):
		out["altTitle"] = _fill_text(str(out["altTitle"]))
	if out.has("altText"):
		out["altText"] = _fill_text(str(out["altText"]))
	for key in ["choices", "altChoices"]:
		if not out.has(key):
			continue
		var arr: Array = out[key]
		for c in arr:
			if typeof(c) != TYPE_DICTIONARY:
				continue
			c["label"] = _fill_text(str(c.get("label", "")))
			c["result"] = _fill_text(str(c.get("result", "")))
	return out

## 条件：tags / notTags / anyTags / line / min* / max* / relations /
## maxRelations / chose / onlyProvince。所有列出的条件需同时满足。
func _cond_matches(cond: Dictionary) -> bool:
	var s := state
	if cond.has("tags"):
		for t in cond["tags"]:
			if not s.has_tag(str(t)):
				return false
	if cond.has("notTags"):
		for t in cond["notTags"]:
			if s.has_tag(str(t)):
				return false
	if cond.has("anyTags"):
		var hit := false
		for t in cond["anyTags"]:
			if s.has_tag(str(t)):
				hit = true
				break
		if not hit:
			return false
	if cond.has("line") and s.line != str(cond["line"]):
		return false
	if cond.has("minInt") and s.intl < int(cond["minInt"]): return false
	if cond.has("maxInt") and s.intl > int(cond["maxInt"]): return false
	if cond.has("minCharm") and s.charm < int(cond["minCharm"]): return false
	if cond.has("maxCharm") and s.charm > int(cond["maxCharm"]): return false
	if cond.has("minLuck") and s.luck < int(cond["minLuck"]): return false
	if cond.has("maxLuck") and s.luck > int(cond["maxLuck"]): return false
	if cond.has("minMoney") and s.money < int(cond["minMoney"]): return false
	if cond.has("maxMoney") and s.money > int(cond["maxMoney"]): return false
	if cond.has("minHealth") and s.health < int(cond["minHealth"]): return false
	if cond.has("maxHealth") and s.health > int(cond["maxHealth"]): return false
	if cond.has("minAge") and s.age < int(cond["minAge"]): return false
	if cond.has("maxAge") and s.age > int(cond["maxAge"]): return false
	if cond.has("relations"):
		for who in cond["relations"]:
			if s.get_relation(str(who)) < int(cond["relations"][who]):
				return false
	if cond.has("maxRelations"):
		for who in cond["maxRelations"]:
			if s.get_relation(str(who)) > int(cond["maxRelations"][who]):
				return false
	if cond.has("chose"):
		for eid in cond["chose"]:
			if s.choice_memory(str(eid)) != str(cond["chose"][eid]):
				return false
	if cond.has("onlyProvince"):
		var op: Array = cond["onlyProvince"]
		if not op.has(s.province):
			return false
	return true

## UI 用：showIf / hideIf 控制选项是否出现。全部隐藏时主界面会退回原选项列表。
func choice_available(c: Dictionary) -> bool:
	if c.has("showIf"):
		var show: Variant = c["showIf"]
		if typeof(show) == TYPE_DICTIONARY and not _cond_matches(show):
			return false
	if c.has("hideIf"):
		var hide: Variant = c["hideIf"]
		if typeof(hide) == TYPE_DICTIONARY and _cond_matches(hide):
			return false
	return true

# ==========================================================
# 阶段推进
# ==========================================================
## age_gain >= 0 时使用事件指定的年数（序章 OP14 用它把 0 岁推到 1 岁）；
## -1 表示沿用原来的 2~4 年节奏。
func _next_phase(age_gain: int = -1) -> void:
	var s := state
	var years := age_gain
	if years < 0:
		years = 3 if s.abstract_val >= 86 else 2
		if float(s.step) > float(s.max_step) * 0.66:
			years += 1
	s.age += years

	# 抽象度回归
	const BASELINE := 10
	if s.abstract_val > BASELINE:
		s.abstract_val -= (3 if s.abstract_val >= 60 else 1)
	elif s.abstract_val < BASELINE:
		s.abstract_val += 1
	s.abstract_val = clampi(s.abstract_val, 0, 100)
	s.abstract_peaked = maxi(s.abstract_peaked, s.abstract_val)
	s.abstract_dropped = mini(s.abstract_dropped, s.abstract_val)

	# 标签持续效果
	if s.has_tag("网瘾") and not s.has_tag("退役"):
		s.abstract_val = clampi(s.abstract_val + 5, 0, 100)
		s.health -= 1
	if s.has_tag("负债") and s.money < 0:
		s.money -= 3
		s.charm -= 1
	if s.has_tag("卷王"):
		s.intl += 1
		s.health -= 1
	if s.money < 0:
		s.money = 0
		s.tags["债台高筑"] = true

	# 自然衰退
	if s.age > 30 and s.age % 5 == 0:
		s.health -= 1
	if s.age > 60 and s.age % 3 == 0:
		s.health -= 1
		s.charm -= 1

	s.clamp_all()

	if s.money == 0:
		s.money_zero_count += 1
	if s.health <= 0 and s.lives > 0:
		s.lives -= 1
		s.health = 8
		s.near_death += 1

	_check_achievements()
	phase_advanced.emit(s)

# ==========================================================
# 成就
# ==========================================================
func _unlock_achievement(name: String) -> bool:
	if meta["achievements"].has(name):
		return false
	meta["achievements"][name] = Time.get_unix_time_from_system()
	SaveManager.save_meta(meta)
	return true

func _unlock_game_achievement(id: String) -> void:
	match id:
		"契约": _unlock_achievement("契约成立")
		"宗师": _unlock_achievement("峡谷传说")
		"圣衣": _unlock_achievement("燃烧吧小宇宙")

func _check_achievements() -> void:
	var s := state
	if s.age > 0 and s.age <= 10:
		_unlock_achievement("第一天就死了")
	if s.age >= 100:
		_unlock_achievement("老不死")
	if s.money_zero_count >= 5:
		_unlock_achievement("穷得叮当响")
	if s.money >= 500:
		_unlock_achievement("富可敌国")
	if s.tier.get("key") == "lawanle" and s.line == "absurd" and s.abstract_val >= 90:
		_unlock_achievement("抽象逆袭")
	if meta["endings"].size() >= DataLoader.endings().size():
		_unlock_achievement("全图鉴")

# ==========================================================
# 结局判定
# ==========================================================
func end_game() -> Dictionary:
	var s := state
	if s.death_reason.is_empty():
		s.death_reason = "身体撑不住了" if s.health <= 0 else "寿终正寝"

	var score := s.intl * 3 + s.health * 3 + s.charm * 2 + s.luck + int(s.money / 10.0) + int(float(s.abstract_val) * 0.4)
	var rating: String
	if s.age < 15:
		rating = "lawanle"
	elif score >= 110:
		rating = "hang"
	elif score >= 80:
		rating = "renshangren"
	elif score >= 50:
		rating = "npc"
	else:
		rating = "lawanle"
	s.rating = rating

	# 隐藏结局优先
	var ending := _match_ending(s, rating)
	if ending.is_empty():
		ending = _fallback_ending(rating)
	if ending.is_empty():
		ending = DataLoader.endings()[0]

	# 记录
	var first_time: bool = not (meta["endings"] as Dictionary).has(ending.get("id", ""))
	meta["endings"][ending.get("id", "")] = {
		"n": ending.get("name", ""),
		"t": Time.get_unix_time_from_system()
	}

	var best_rank := _rank_val(meta.get("best", null))
	var current_rank := _rank_val(rating)
	if meta.get("best") == null or current_rank > best_rank:
		meta["best"] = rating

	_check_achievements()
	SaveManager.save_meta(meta)

	var info := {
		"score": score,
		"rating": rating,
		"first_time": first_time
	}
	game_ended.emit(s, ending, info)
	return ending

func _rank_val(r: Variant) -> int:
	match r:
		"lawanle": return 0
		"npc": return 1
		"renshangren": return 2
		"hang": return 3
		_: return -1

## 隐藏结局匹配（cond 评估）
func _match_ending(s: GameState, rating: String) -> Dictionary:
	for e in DataLoader.endings():
		if not e.get("hidden", false):
			continue
		if _eval_ending_cond(e, s):
			return e
	return {}

func _fallback_ending(rating: String) -> Dictionary:
	# 同线同评级 → 同评级兜底
	var s := state
	var pool: Array = []
	for e in DataLoader.endings():
		if e.get("hidden", false):
			continue
		var eline: String = e.get("line", "normal")
		if eline != s.line and eline != "any":
			continue
		if e.get("tier") != rating:
			continue
		# 评估 cond
		if _eval_ending_cond(e, s):
			pool.append(e)
	if not pool.is_empty():
		return pick(pool)
	# 同评级兜底
	var tier_pool: Array = []
	for e in DataLoader.endings():
		if e.get("hidden", false):
			continue
		if e.get("tier") == rating:
			tier_pool.append(e)
	if not tier_pool.is_empty():
		return pick(tier_pool)
	return {}

## 评估结局条件（转换自 JS cond 函数）
func _eval_ending_cond(ending: Dictionary, s: GameState) -> bool:
	var cond_str: String = ending.get("condStr", "")
	if cond_str.is_empty():
		return false
	var eid: String = ending.get("id", "")
	match eid:
		"E_N01": return s.has_tag("编制") and s.money >= 50 and s.is_debt_free()
		"E_N02": return s.has_tag("有房") and s.intl >= 16
		"E_N03": return s.money >= 300
		"E_N04": return s.intl >= 14 and not s.has_tag("创业")
		"E_N05": return s.money < 5 and not s.has_tag("编制")
		"E_N06": return s.intl >= 8 and s.intl <= 12 and s.health >= 8 and s.health <= 12
		"E_N07": return s.has_tag("晚育")
		"E_N08": return s.health <= 0 and s.has_tag("work")
		"E_N09": return not s.has_tag("编制") and s.money >= 30 and s.is_debt_free()
		"E_N10": return s.money >= 100 and s.health >= 15
		"E_N11": return s.age >= 80 and s.health >= 8
		"E_N12": return s.age >= 70 and s.charm <= 4
		"E_A01": return s.abstract_val >= 70 and s.age >= 60
		"E_A02": return s.abstract_val >= 90 and s.age >= 40
		"E_A03": return s.abstract_val >= 100
		"E_A04": return s.has_tag("退役") and s.abstract_val >= 40
		"E_A05": return s.has_tag("上热搜")
		"E_A06": return s.has_tag("表情包")
		"E_A07": return s.money < 10 and s.abstract_val >= 50 and s.has_tag("网瘾") and s.has_tag("退役")
		"E_A08": return s.abstract_val >= 80 and s.health <= 5
		"E_A09": return s.intl <= 12 and s.has_tag("遇到AI")
		"E_A10": return s.abstract_val >= 100 and s.charm >= 15
		"E_A11":
			var xy: Variant = s.tag_value("谐音")
			return typeof(xy) == TYPE_INT and xy >= 5
		"E_A12": return s.line == "absurd" and s.abstract_val <= 20
		"E_G01": return s.has_tag("契约") and s.has_tag("退役") and s.age >= 40
		"E_G02": return s.has_tag("宗师")
		"E_G03": return s.has_tag("圣衣")
		"E_G04": return s.has_tag("峡谷") and not s.has_tag("宗师") and s.age >= 30
		"E_X01": return s.achieved.has("山河大学") and s.intl >= 16 and s.age >= 20
		"E_X02": return s.abstract_peaked >= 80 and s.abstract_dropped <= 15
		"E_X03": return s.get_tier_key() == "lawanle" and s.rating == "hang"
		"E_X04": return s.near_death >= 3
		_: return false
