extends RefCounted
## Bring the older event library into the native comic run, without a second RNG/life engine.
const Loader := preload("res://scripts/data_loader.gd")
const PREFIX := "EX:"
const ATTRS := {"health":"physical", "int":"intelligence", "charm":"charm", "luck":"luck", "mental":"mental", "money":"money", "abstract":"abstract"}
static var _catalog: Dictionary = {}

static func catalog() -> Dictionary:
	if not _catalog.is_empty(): return _catalog
	Loader.ensure_loaded()
	var out := {}
	for raw in Loader.data.EVENTS + Loader.arcs.get("events", []):
		out[PREFIX + str(raw.id)] = adapt(raw, false)
	for book in [Loader.opening.get("nodes", {}), Loader.arcs.get("nodes", {})]:
		for id in book:
			out[PREFIX + str(id)] = adapt(book[id], true)
	_catalog = out
	return _catalog

static func adapt(raw: Dictionary, branch: bool) -> Dictionary:
	var e := raw.duplicate(true)
	e["legacy"] = true
	e["original_id"] = str(raw.id)
	e["id"] = PREFIX + str(raw.id)
	e["branch_only"] = branch
	e["age_range"] = [raw.get("cond", {}).get("minAge", 0), raw.get("cond", {}).get("maxAge", 140)]
	var words := str(raw.get("title", "")) + str(raw.get("text", ""))
	var place := "home"
	var role := "friend"
	for row in [["hospital", "clinician", ["医院", "医生", "病房", "体检", "产房"]], ["classroom", "teacher", ["老师", "考试", "学校", "同桌", "幼儿园"]], ["office", "boss", ["公司", "老板", "面试", "同事", "工作"]], ["park", "friend", ["公园", "长椅", "散步", "旅行"]]]:
		if row[2].any(func(w): return words.contains(w)):
			place = row[0]; role = row[1]; break
	if place == "home":
		if words.contains("妈") or words.contains("父母"): role = "parent"
		elif words.contains("爸"): role = "mate"
		elif words.contains("伴侣") or words.contains("结婚"): role = "partner"
	e["scene"] = place
	e["cast_bindings"] = {role:role}
	e["actors"] = ["lead", role]
	e["prop"] = "book" if place == "classroom" else ("phone" if place == "office" else "photo")
	return e

static func initialize(run) -> void:
	Loader.ensure_loaded()
	var rng: RandomNumberGenerator = run.streams.npc
	var region: String = Loader.data.REGIONS.keys()[rng.randi_range(0, Loader.data.REGIONS.size()-1)]
	var provinces: Array = Loader.data.REGIONS[region].provinces
	var family: Dictionary = Loader.data.FAMILIES[rng.randi_range(0, Loader.data.FAMILIES.size()-1)]
	var talent: Dictionary = Loader.data.TALENTS[rng.randi_range(0, Loader.data.TALENTS.size()-1)]
	run.s["legacy"] = {"region":region, "province":provinces[rng.randi_range(0, provinces.size()-1)], "family":family.name,
		"talent":talent.name, "line":["normal", "normal", "absurd", "lucky"][rng.randi_range(0,3)], "relations":{}, "memories":{}, "near_death":0}
	for key in ["intelligence", "charm", "luck"]: run.s.scores[key] = rng.randi_range(4, 10)
	apply_effects(run, Loader.data.REGIONS[region].get("bonus", {}))
	apply_effects(run, family.effects)
	apply_effects(run, talent.effects)

static func matches(run, cond: Dictionary) -> bool:
	for tag in cond.get("tags", []):
		if tag not in run.s.flags: return false
	for tag in cond.get("notTags", []):
		if tag in run.s.flags: return false
	if cond.has("anyTags") and not cond.anyTags.any(func(tag): return tag in run.s.flags): return false
	if cond.has("line") and cond.line != run.s.get("legacy", {}).get("line", "normal"): return false
	if cond.has("onlyProvince") and run.s.get("legacy", {}).get("province", "") not in cond.onlyProvince: return false
	for pair in [["Age", "age"], ["Health", "physical"], ["Int", "intelligence"], ["Charm", "charm"], ["Luck", "luck"], ["Money", "money"], ["Abstract", "abstract"]]:
		var value: float = run.s.age if pair[1] == "age" else float(run.s.scores.get(pair[1], 5))
		if cond.has("min"+pair[0]) and value < float(cond["min"+pair[0]]): return false
		if cond.has("max"+pair[0]) and value > float(cond["max"+pair[0]]): return false
	for who in cond.get("relations", {}):
		if int(run.s.get("legacy", {}).get("relations", {}).get(who, 0)) < int(cond.relations[who]): return false
	for who in cond.get("maxRelations", {}):
		if int(run.s.get("legacy", {}).get("relations", {}).get(who, 0)) > int(cond.maxRelations[who]): return false
	for id in cond.get("chose", {}):
		if run.s.get("legacy", {}).get("memories", {}).get(id, "") != cond.chose[id]: return false
	return true

static func eligible(run, e: Dictionary) -> bool:
	if e.branch_only or run.s.seen.has(e.id) or not matches(run, e.get("cond", {})): return false
	if e.get("line", "common") not in ["common", run.s.get("legacy", {}).get("line", "normal")]: return false
	for role in e.cast_bindings:
		if not run.s.roles.get(role, {}).get("alive", false): return false
		if role == "partner" and (run.s.partner_age < 0 or run.s.age < run.s.partner_age): return false
	return not prepare(run, e).choices.is_empty()

static func fill(run, text: String) -> String:
	var re := RegEx.new()
	re.compile("\\{choice:([^}]+)\\}")
	for m in re.search_all(text):
		text = text.replace(m.get_string(), str(run.s.get("legacy", {}).get("memories", {}).get(m.get_string(1), "那一次")))
	return text

static func prepare(run, original: Dictionary) -> Dictionary:
	var e := original.duplicate(true)
	e.text = fill(run, str(e.get("text", "")))
	e.choices = e.choices.filter(func(c): return matches(run, c.get("showIf", {})) and (not c.has("hideIf") or not matches(run, c.hideIf)) and matches(run, {"tags":c.get("requireTags", []), "relations":c.get("requireRelations", {})}))
	for c in e.choices:
		c.label = fill(run, str(c.label)); c.result = fill(run, str(c.get("result", "")))
	return e

static func apply_effects(run, effects: Dictionary) -> void:
	var translated := {}
	for key in effects:
		if key == "lifespan":
			# This mode uses annual hazard, not a predetermined death date.
			translated["physical"] = float(effects[key]) * .5
		elif ATTRS.has(key): translated[ATTRS[key]] = effects[key]
	run.effects(translated)

static func next_id(run, spec: Variant) -> String:
	if spec is String: return PREFIX + spec if not spec.is_empty() else ""
	if spec is Dictionary:
		for rule in spec.get("when", []):
			if matches(run, rule): return PREFIX + str(rule.get("next", ""))
		return PREFIX + str(spec.default) if not str(spec.get("default", "")).is_empty() else ""
	return ""

static func choose(run, e: Dictionary, index: int) -> Dictionary:
	if not run.s.has("legacy"): run.s["legacy"] = {"relations":{}, "memories":{}, "near_death":0}
	var c: Dictionary = e.choices[index]
	apply_effects(run, c.get("effects", {}))
	for tag in e.get("tags", []) + c.get("tags", []):
		if tag not in run.s.flags: run.s.flags.append(tag)
	for who in c.get("relations", {}):
		run.s.legacy.relations[who] = int(run.s.legacy.relations.get(who, 0)) + int(c.relations[who])
	run.s.legacy.memories[e.original_id] = str(c.get("memory", c.label))
	if c.get("nearDeath", false): run.s.legacy.near_death += 1
	run.s.seen[e.id] = run.s.age
	if not e.branch_only: run.s.decisions += 1
	var next := next_id(run, c.get("next", e.get("next", "")))
	if e.get("endOpening", false):
		run.s.age = maxi(run.s.age, 1)
		next = "LC02"
	return {"choice":index, "label":c.label, "tier":run.tier(), "facts":fill(run, str(c.get("result", ""))), "next":next, "outcome_id":e.id+":"+str(index)}

static func opening_id(run) -> String:
	return PREFIX + str(Loader.opening.start.get(run.s.get("legacy", {}).get("line", "normal"), "OP01"))
