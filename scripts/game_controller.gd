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

# ==========================================================
# 事件抽取
# ==========================================================
func pick_event() -> Dictionary:
	var s := state

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
		var c: Dictionary = e.get("cond", {})
		if c.has("minAge") and s.age < int(c["minAge"]):
			continue
		if c.has("maxAge") and s.age > int(c["maxAge"]):
			continue
		if c.has("minMoney") and s.money < int(c["minMoney"]):
			continue
		if c.has("maxHealth") and s.health > int(c["maxHealth"]):
			continue
		if c.has("minInt") and s.intl < int(c["minInt"]):
			continue
		if c.has("minCharm") and s.charm < int(c["minCharm"]):
			continue
		if c.has("onlyProvince"):
			var op: Array = c["onlyProvince"]
			if not op.has(s.province):
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
		# 兜底：取任意不在 recent 中的事件
		for e in DataLoader.events():
			if not s.recent.has(e.get("id", "")):
				ev = e
				break

	if ev == null:
		return {}

	var eDict: Dictionary = ev
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

	var result_text: String = c.get("result", "")
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
	_next_phase()

# ==========================================================
# 阶段推进
# ==========================================================
func _next_phase() -> void:
	var s := state
	var years := 3 if s.abstract_val >= 86 else 2
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
