extends RefCounted
## Native Godot runtime for the authored pack; no Python process is needed.
const PACK_PATH := "res://data/story_life_comic.json"
const SAVE_PATH := "user://life_comic_v1.save"
var pack: Dictionary = {}
var events: Dictionary = {}
var event_list: Array = []
var arcs: Dictionary = {}
var streams: Dictionary = {}
var s: Dictionary = {}

func _init() -> void:
	pack = JSON.parse_string(FileAccess.get_file_as_string(PACK_PATH))
	for event in pack.events:
		events[event.id] = event
		event_list.append(event)
	for arc in pack.rare_arcs: arcs[arc.id] = arc

func start(seed_value: int) -> void:
	for name in ["event", "outcome", "mortality", "illness", "npc", "layout"]:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(seed_value) + ":" + name)
		streams[name] = rng
	var r: RandomNumberGenerator = streams.npc
	s = {"version":1, "seed":seed_value, "age":0, "scores":{"physical":r.randi_range(45,85), "mental":r.randi_range(45,85), "abstract":r.randi_range(0,55), "money":0},
		"flags":[], "seen":{}, "pages":[], "queue":[], "pending":{}, "committed":{}, "terminal":{},
		"illness":"", "changed_life":false, "roles":{}, "budget":streams.layout.randi_range(18,24), "decisions":0,
		"study_until":[18,21,24][r.randi_range(0,2)], "work_from":r.randi_range(16,25), "retire_age":r.randi_range(55,74),
		"house_age":r.randi_range(18,28), "partner_age":[20,24,31,-1][r.randi_range(0,3)], "last_illness_year":-1}
	for role in ["parent", "mate", "friend", "teacher", "boss", "partner", "neighbor"]:
		var offset: int = {"parent":r.randi_range(22,38), "mate":r.randi_range(22,40), "teacher":25,"boss":15}.get(role,0)
		s.roles[role] = {"alive":true,"death_at":maxi(1,r.randi_range(68,108)-offset),"met":role in ["parent","mate"]}
	for role in ["clinician","hobby_admin","community_teacher","naiwa"]: s.roles[role] = {"alive":true,"death_at":999,"met":false}
	begin("LC01")

func tier() -> int:
	return clampi(int(float(s.scores.abstract)/25),0,3)

func eligible(e: Dictionary) -> bool:
	if not s.terminal.is_empty() or s.age < e.age_range[0] or s.age > e.age_range[1]: return false
	if s.seen.has(e.id) and (e.recurrence.once or s.age-int(s.seen[e.id]) < int(e.recurrence.cooldown_years)): return false
	var q: Dictionary = e.requirements
	if q.get("education",false) and not (s.age >= 4 and s.age <= s.study_until): return false
	if q.get("education_or_hobby_group",false) and not ((s.age >= 12 and s.age <= s.study_until) or "_爱好_预约" in s.flags): return false
	if q.get("employed",false) and not (s.age >= s.work_from and s.age < s.retire_age): return false
	if q.get("independent_housing",false) and s.age < s.house_age: return false
	if q.get("relationship_active",false) and (s.partner_age < 0 or s.age < s.partner_age): return false
	if q.has("memory_any") and not q.memory_any.any(func(m): return m in s.flags): return false
	if q.get("memory_none",[]).any(func(m): return m in s.flags): return false
	var roles: Array = q.get("roles_available",[]).duplicate()
	roles.append_array(e.cast_bindings.values())
	for role in roles:
		if role == "lead": continue
		if not s.roles.has(role) or not s.roles[role].alive: return false
		if role == "partner" and (s.partner_age < 0 or s.age < s.partner_age): return false
	return true

func begin(id: String, context: Dictionary = {}) -> void:
	if not s.pending.is_empty(): return
	s.pending = {"id":id,"age":s.age,"tier":tier(),"context":context.duplicate(true)}
	s.committed = {}
	if events.has(id):
		for role in events[id].cast_bindings.values():
			if s.roles.has(role): s.roles[role].met = true

func source() -> Dictionary:
	return events.get(s.pending.get("id",""),arcs.get(s.pending.get("id",""),{}))

func options() -> Array:
	var e := source()
	if e.has("choices"): return e.choices.map(func(c): return c.label)
	return e.get("options",[])

func effects(delta: Dictionary) -> void:
	for key in delta:
		s.scores[key] = float(s.scores.get(key,0)) + float(delta[key])
		if key != "money": s.scores[key] = clampf(s.scores[key],0,100)

func weighted(rows: Array, stream: String) -> Dictionary:
	if rows.is_empty(): return {}
	var total := 0.0
	for row in rows: total += float(row.get("weight",1))
	if total <= 0.0: return {}
	var value: float = streams[stream].randf()*total
	for row in rows:
		value -= float(row.get("weight",1))
		if value < 0: return row
	return rows.back()

func choose(index: int) -> Dictionary:
	if not s.committed.is_empty(): return s.committed
	if s.pending.is_empty() or not s.terminal.is_empty() or index < 0 or index >= options().size(): return {}
	var e := source()
	var result := {"choice":index,"label":options()[index],"tier":tier(),"facts":"","next":"","outcome_id":""}
	if e.has("choices"):
		var c: Dictionary = e.choices[index]
		effects(c.effects)
		var o := weighted(c.outcomes,"outcome")
		effects(o.effects)
		for flag in [c.memory,o.memory]:
			if flag not in s.flags: s.flags.append(flag)
		s.seen[e.id] = s.age
		s.decisions += 1
		result.merge({"tier":tier(),"facts":o.facts,"outcome_id":o.id,"voice":o.voices[tier()].duplicate(true),"panels":o.panels.duplicate(true)},true)
	else:
		var next: Dictionary = e.next
		var selected: Dictionary = weighted(next.weighted,"illness" if e.id != "RX04" else "mortality") if next.has("weighted") else next
		result.facts = str(selected.get("facts","你按自己的方式安排了接下来的一小步。"))
		result.next = str(selected.get("id",""))
		result.outcome_id = result.next
		if selected.has("state"):
			if e.id == "RX03": s.illness = selected.state
			if e.id == "RX04" and selected.state == "changed_life": s.changed_life = true
		if e.id == "RX02": s.illness = "stable"
		if e.id == "RX03": s.last_illness_year = s.age
		if e.id == "RX01" and result.next == "RX01_CLEAR": s.illness = ""
		result["terminal_after"] = bool(selected.get("terminal",false))
		result["voice"] = {"narrator":result.facts,"inner":e.lenses[tier()][1],"dialogue":options()[index]}
	s.committed = result
	return result

func finish() -> bool:
	if s.committed.is_empty(): return false
	var result: Dictionary = s.committed
	s.pending = {}
	s.committed = {}
	if result.get("terminal_after",false):
		end("END_ACCIDENT","accident")
		return true
	if arcs.has(result.get("next","")): s.queue.push_front({"id":result.next})
	if not s.queue.is_empty():
		var item: Dictionary = s.queue.pop_front()
		begin(item.id,item.get("context",{}))
		return true
	var previous_age: int = s.age
	# Every year is simulated, including the quiet gap after the decision budget.
	while s.age < 140 and s.terminal.is_empty():
		s.age += 1
		annual()
		if not s.terminal.is_empty(): break
		if not s.queue.is_empty():
			var item: Dictionary = s.queue.pop_front()
			begin(item.id,item.get("context",{}))
			break
		if s.decisions >= s.budget: continue
		var pool: Array = event_list.filter(eligible)
		if not pool.is_empty() and (s.age-previous_age >= 6 or s.age in [1,4,7,13,18,30,45,65] or streams.event.randf() < 0.35):
			begin(pool[streams.event.randi_range(0,pool.size()-1)].id)
			break
	if s.age >= 140 and s.terminal.is_empty() and s.pending.is_empty(): end("END_OPEN","unfinished")
	return true

func table_value(rows: Array) -> float:
	for row in rows:
		if s.age >= row[0] and s.age <= row[1]: return float(row[2])
	return 0

func annual() -> void:
	var rules: Dictionary = pack.rules.mortality
	var body := 0.65+1.10*(100-float(s.scores.physical))/100
	var mind := 0.92+0.16*(100-float(s.scores.mental))/100
	var baseline := table_value(rules.annual_age_base)*body*mind
	var disease: float = rules.active_illness_extra_hazard.get(s.illness,0)
	var roll: float = streams.mortality.randf()
	var accident: float = rules.sudden_fatal_accident_per_year
	if roll < accident:
		end("END_ACCIDENT","accident")
		return
	if roll < accident+disease:
		end("END_ILLNESS","illness")
		return
	if roll < accident+disease+baseline:
		end("END_NATURAL" if s.age >= 60 else "END_ILLNESS","age_related" if s.age >= 60 else "other_illness")
		return
	for role in s.roles:
		var npc: Dictionary = s.roles[role]
		if npc.alive and s.age >= npc.death_at:
			npc.alive = false
			if npc.met: s.queue.append({"id":"RX06","context":{"lost_role":role}})
	var onset: float = streams.illness.randf()
	if s.illness.is_empty() and onset < table_value(rules.unexpected_cancer_onset):
		s.illness = "workup"
		s.queue.append({"id":"RX01"})
	elif s.illness in ["stable","remission","progression"] and s.age-int(s.last_illness_year) >= 2:
		s.queue.append({"id":"RX03"})
	# Nonfatal accidents have their own scene; rare, independent of good choices.
	if streams.mortality.randf() < 0.001: s.queue.append({"id":"RX04"})
	s.scores.physical = maxf(0,float(s.scores.physical)-(0.6 if s.age >= 60 else (0.2 if s.age >= 40 else 0.0)))

func end(id: String, cause: String) -> void:
	s.terminal = {"id":id,"cause":cause,"age":s.age,"tier":tier(),"early":s.age < 18}
	s.queue.clear()

func snapshot() -> Dictionary:
	var out := s.duplicate(true)
	out["rng"] = {}
	for name in streams: out.rng[name] = {"seed":streams[name].seed,"state":streams[name].state}
	return out

func restore(data: Dictionary) -> bool:
	if data.get("version",0) != 1 or not data.has("rng") or not data.has("pending") or not data.has("pages"): return false
	for key in ["scores","roles","seen","committed","terminal"]:
		if not data.get(key) is Dictionary: return false
	for key in ["pages","queue","flags"]:
		if not data.get(key) is Array: return false
	for name in ["event", "outcome", "mortality", "illness", "npc", "layout"]:
		if not data.rng.get(name) is Dictionary or not data.rng[name].has("state") or not data.rng[name].has("seed"): return false
	if not data.pending.is_empty() and not events.has(data.pending.get("id","")) and not arcs.has(data.pending.get("id","")): return false
	s = data.duplicate(true)
	streams.clear()
	for name in data.rng:
		var r := RandomNumberGenerator.new()
		r.seed = int(data.rng[name].seed)
		r.state = int(data.rng[name].state)
		streams[name] = r
	return true

func save(path: String = SAVE_PATH) -> bool:
	if s.is_empty(): return false
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null: return false
	file.store_var(snapshot())
	file.flush()
	file.close()
	return DirAccess.rename_absolute(path+".tmp",path) == OK

func load_save(path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path): return false
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return false
	var data = file.get_var(false)
	return data is Dictionary and restore(data)
