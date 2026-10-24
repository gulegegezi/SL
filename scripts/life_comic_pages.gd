extends RefCounted
## Adapter: authored camera/action vocabulary -> existing comic renderer.
const Director := preload("res://scripts/comic_director.gd")
const ROLE_ART := {"clinician":"mate","hobby_admin":"teacher","community_teacher":"teacher","neighbor":"friend"}
const PROPS := {"blanket":"blanket","photo":"photo","flashlight":"flashlight","biscuit":"biscuit","tooth":"tooth","eraser":"eraser","ledger":"book","exam":"contract","notebook":"book","eggs":"eggs","plant":"plant","fridge":"fridge","phone":"phone","bill":"contract","noodles":"meal","report":"contract","key":"key","badge":"badge","bench":""}
const ROLE_NAMES := {"parent":"妈妈","mate":"爸爸","friend":"老同学","teacher":"老师","boss":"同事","partner":"伴侣","neighbor":"邻居","clinician":"医生","hobby_admin":"排练室管理员","community_teacher":"培训班老师"}
static var dialogue_book: Dictionary = {}

static func book() -> Dictionary:
	if dialogue_book.is_empty(): dialogue_book = JSON.parse_string(FileAccess.get_file_as_string("res://data/story_life_dialogue.json"))
	return dialogue_book.events

static func speak(run, e: Dictionary, original: Dictionary, text: String, name: String = "旁白", role: String = "lead") -> Dictionary:
	var is_narrator := name == "旁白"
	var out := panel(run,e,original,"旁白："+text if is_narrator else "", "" if is_narrator else name+"："+text,role)
	out["text_channel"] = "narration" if is_narrator else "dialogue"
	out["speaker_label"] = name
	out["dialogue_version"] = 2
	return out

static func npc_lines(run, e: Dictionary, text: String) -> Array:
	var output: Array = []
	# One label per actual speaker, including the two parents on the departure page.
	var remaining := text
	for marker in ["妈妈：","爸爸："]: remaining = remaining.replace(" "+marker,"\n"+marker)
	for line in remaining.split("\n",false):
		var at: int = line.find("：")
		var name: String = line.left(at) if at >= 0 else "对方"
		var words: String = line.substr(at+1) if at >= 0 else line
		var role := "friend"
		for slot in e.get("actors",[]):
			if slot != "lead":
				role = e.get("cast_bindings",{}).get(slot,slot)
				break
		# Literal character labels take precedence over the order of art slots.
		if name == "爸爸": role = "mate"
		elif name == "妈妈": role = "parent"
		elif name == "医生": role = "clinician"
		if not run.s.roles.get(role,{}).get("alive",false): role = "clinician"
		var art_role: String = ROLE_ART.get(role,role)
		var p := speak(run,e,{"shot":"medium","actors":["lead",role],"action":"talk"},words,name,art_role)
		p["support"] = "npc_"+art_role
		p["world_solo"] = false
		output.append(p)
	return output

static func action_for(value: String) -> String:
	# Related directions share an existing whole-body gesture, not a false bespoke clip.
	for row in [["walk",["walk","depart","leave","step_back"]],["phone",["call","phone","message","contact"]],["draw",["draw","write","note","annotate","label","plan","schedule","list"]],["read",["read","review","search","find","question","report"]],["offer",["offer","share","pass","lend","exchange","feed"]],["receive",["receive","grip","hold"]],["wave",["wave"]],["sit",["sit","rest","bench"]],["drum",["drum","practice"]],["raise",["raise","show","photo","point"]]]:
		for fragment in row[1]:
			if value.contains(fragment): return row[0]
	return "idle"

static func panel(run, e: Dictionary, original: Dictionary, caption: String, bubble: String = "", speaker: String = "lead") -> Dictionary:
	var actors: Array = original.get("actors",e.get("actors",["lead"]))
	var bindings: Dictionary = e.get("cast_bindings",{})
	var support := "none"
	for slot in actors:
		var role: String = bindings.get(slot,slot)
		if role != "lead" and run.s.roles.get(role,{}).get("alive",false):
			support = "npc_"+str(ROLE_ART.get(role,role))
			break
	var prop: String = PROPS.get(original.get("prop",e.get("prop","")),"")
	var out := {"shot":original.get("shot","wide"),"shot_locked":true,"scene":e.get("scene","home"),
		"ink":Director.ink_key(run.s.age),"age":run.s.age,"caption":caption,"bubble":bubble,
		"support":support,"tone":"paper","prop":prop,"frame":0,
		"action":action_for(original.get("action","")),"actor":speaker,"source_action":original.get("action","")}
	if support == "none": out["world_solo"] = true
	return out

static func make(run, result: bool = false) -> Dictionary:
	var e: Dictionary = run.source()
	var t: int = run.s.committed.tier if result else run.s.pending.tier
	var panels: Array = []
	if e.has("choices"):
		var writing: Dictionary = book()[e.id]
		if not result:
			panels.append(speak(run,e,e.panels[0],"【%s】\n%s" % [e.title,e.facts]))
			panels.append_array(npc_lines(run,e,e.npc_dialogue))
			var guide := speak(run,e,{"shot":"wide","action":"choice_pause"},writing.guide[t])
			guide["expr"] = "normal"
			panels.append(guide)
		else:
			var c: Dictionary = e.choices[run.s.committed.choice]
			var spoken: String = c.lines[t]
			if run.s.age < 3: spoken = "呜。" if run.s.committed.choice != 2 else "哇——"
			panels.append(speak(run,e,run.s.committed.panels[0],spoken,"你"))
			# Actual consequences occur exactly once, before the narrator's reaction.
			panels.append(speak(run,e,run.s.committed.panels[1],str(run.s.committed.facts)))
			var response: String = writing.responses[run.s.committed.choice]
			if t == 1: response = "好，"+response
			elif t == 2: response = "这场戏按你的办法往下走。"+response
			elif t == 3: response = "我改一下旁白。"+response
			var reaction := speak(run,e,{"shot":"wide","action":"settle"},response)
			reaction["expr"] = "normal"
			panels.append(reaction)
	else:
		var lens: Array = e.lenses[t]
		var context: Dictionary = run.s.pending.get("context",{})
		var facts: String = {"RX05":"恢复以后，原来的生活方式需要调整。你仍然有想做的事，也有权决定需要什么帮助。"}.get(e.id,e.facts)
		if e.id == "RX06":
			facts = "你得知%s离世了。" % ROLE_NAMES.get(context.get("lost_role",""),"一位熟悉的人")
		var location := "hospital" if e.id in ["RX01","RX02","RX03","RX04"] else "home"
		var rare_event := {"scene":location,"actors":["lead"],"prop":"report" if location == "hospital" else "photo"}
		if result:
			if run.s.age >= 3: panels.append(speak(run,rare_event,{"shot":"medium"},str(run.s.committed.label),"你"))
			panels.append(speak(run,rare_event,{"shot":"wide"},str(run.s.committed.facts)))
			panels.append(speak(run,rare_event,{"shot":"medium"},str(lens[0])))
		else:
			panels.append(speak(run,rare_event,{"shot":"wide"},"【%s】\n%s" % [e.title,facts]))
			if e.has("npc"): panels.append_array(npc_lines(run,rare_event,str(e.npc)))
			panels.append(speak(run,rare_event,{"shot":"medium"},str(lens[0])))
		if run.s.age < 16: panels.append(speak(run,rare_event,{"shot":"detail"},"照护者会帮忙安排。你只需先表达自己的需要。"))
	return {"no":run.s.pages.size()+1,"age":run.s.age,"stage":run.pack.rules.tiers[t].name,"title":e.title,
		"event_id":e.id,"result":result,"panels":panels,"series":0,"slots":[],"dialogue_version":2}

static func upgrade_legacy(spec: Dictionary) -> Dictionary:
	if int(spec.get("dialogue_version",0)) >= 2: return spec
	var out := spec.duplicate(true)
	var rebuilt: Array = []
	var previous := ""
	for original in spec.get("panels",[]):
		var cap: String = original.get("caption","")
		for marker in ["【心里】","【心里的字幕】"]:
			if cap.contains(marker): cap = cap.left(cap.find(marker)).strip_edges()
		if not previous.is_empty() and cap.begins_with(previous): cap = cap.trim_prefix(previous).strip_edges()
		var p: Dictionary = original.duplicate(true)
		var bub: String = p.get("bubble","")
		p.caption = cap
		p.bubble = ""
		if not cap.is_empty():
			p.caption = cap if cap.begins_with("旁白：") else "旁白："+cap
			p.bubble = ""
			p["text_channel"] = "narration"
			rebuilt.append(p)
			previous = cap
		if not bub.is_empty():
			var spoken: Dictionary = original.duplicate(true)
			spoken.caption = ""
			spoken.bubble = bub if bub.contains("：") else "你："+bub
			spoken["text_channel"] = "dialogue"
			rebuilt.append(spoken)
		if cap.is_empty() and bub.is_empty(): rebuilt.append(p)
	out.panels = rebuilt
	out["dialogue_version"] = 2
	return out

static func ending(run) -> Dictionary:
	var terminal: Dictionary = run.s.terminal
	var text := ""
	for e in run.pack.endings:
		if e.id == terminal.id or (terminal.early and e.id == "END_EARLY"):
			text += str(e.voices[terminal.tier])+"\n"
	return {"no":run.s.pages.size()+1,"age":terminal.age,"stage":"未完" if terminal.id == "END_OPEN" else "这一生的尾声","slots":[],
		"panels":[{"ink":"","tone":"black","shot":"wide","caption":"旁白："+text,"shot_locked":true}]}
