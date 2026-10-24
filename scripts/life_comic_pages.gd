extends RefCounted
## Adapter: authored camera/action vocabulary -> existing comic renderer.
const Director := preload("res://scripts/comic_director.gd")
const ROLE_ART := {"clinician":"mate","hobby_admin":"teacher","community_teacher":"teacher","neighbor":"friend"}
const PROPS := {"blanket":"blanket","photo":"photo","flashlight":"flashlight","biscuit":"biscuit","tooth":"tooth","eraser":"eraser","ledger":"book","exam":"contract","notebook":"book","eggs":"eggs","plant":"plant","fridge":"fridge","phone":"phone","bill":"contract","noodles":"meal","report":"contract","key":"key","badge":"badge","bench":""}
const ROLE_NAMES := {"parent":"妈妈","mate":"爸爸","friend":"老同学","teacher":"老师","boss":"同事","partner":"伴侣","neighbor":"邻居","clinician":"医生","hobby_admin":"排练室管理员","community_teacher":"培训班老师"}

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
		var lens: Dictionary = run.s.committed.voice if result else e.lenses[t]
		var originals: Array = run.s.committed.panels if result else e.panels
		for i in range(originals.size()):
			var p: Dictionary = originals[i]
			var caption := str(p.get("caption",""))
			var bubble := ""
			if p.has("voice_ref"):
				caption = str(lens.narrator)+"\n【心里】"+str(lens.inner)
				bubble = str(lens.dialogue)
			if not result and i == 0: caption = "【%s】\n%s" % [e.title,caption]
			if not result and i == originals.size()-1: caption = "接下来，你会怎么做？"
			# Literal NPC speech stays identical in all four narrative lenses.
			if not result and i == 1: caption = str(e.npc_dialogue)
			if run.s.age < 3 and not bubble.is_empty():
				caption += "\n【心里的字幕】"+bubble
				bubble = ""
			var rendered := panel(run,e,p,caption,bubble)
			if not result and i == 1:
				for slot in e.actors:
					var role: String = e.cast_bindings.get(slot,slot)
					if role != "lead":
						rendered.actor = str(ROLE_ART.get(role,role))
						rendered.bubble = caption
						rendered.caption = ""
						break
			panels.append(rendered)
	else:
		var lens: Array = e.lenses[t]
		var context: Dictionary = run.s.pending.get("context",{})
		var facts: String = {"RX05":"恢复以后，原来的生活方式需要调整。你仍然有想做的事，也有权决定需要什么帮助。"}.get(e.id,e.facts)
		if e.id == "RX06":
			facts = "%s离世了。以后的现场不会再出现这个人。" % ROLE_NAMES.get(context.get("lost_role",""),"一位熟悉的人")
		var location := "hospital" if e.id in ["RX01","RX02","RX03","RX04"] else "home"
		var rare_event := {"scene":location,"actors":["lead"],"prop":"report" if location == "hospital" else "photo"}
		if result:
			panels.append(panel(run,rare_event,{"shot":"medium"},"你的选择："+str(run.s.committed.label)))
			panels.append(panel(run,rare_event,{"shot":"wide"},str(run.s.committed.facts)))
			panels.append(panel(run,rare_event,{"shot":"medium"},str(lens[0])+"\n【心里】"+str(lens[1])))
		else:
			panels.append(panel(run,rare_event,{"shot":"wide"},"【%s】\n%s" % [e.title,facts]))
			panels.append(panel(run,rare_event,{"shot":"medium"},str(lens[0])+"\n【心里】"+str(lens[1]),str(lens[2]) if run.s.age >= 3 else ""))
			if e.has("npc"): panels.append(panel(run,rare_event,{"shot":"detail"},str(e.npc)))
		if run.s.age < 16: panels.append(panel(run,rare_event,{"shot":"detail"},"照护者协助安排；你可以用自己的方式表达需要。"))
	return {"no":run.s.pages.size()+1,"age":run.s.age,"stage":run.pack.rules.tiers[t].name,"title":e.title,
		"event_id":e.id,"result":result,"panels":panels,"series":0,"slots":[]}

static func ending(run) -> Dictionary:
	var terminal: Dictionary = run.s.terminal
	var text := ""
	for e in run.pack.endings:
		if e.id == terminal.id or (terminal.early and e.id == "END_EARLY"):
			text += str(e.voices[terminal.tier])+"\n"
	return {"no":run.s.pages.size()+1,"age":terminal.age,"stage":"未完" if terminal.id == "END_OPEN" else "这一生的尾声","slots":[],
		"panels":[{"ink":"","tone":"black","shot":"wide","caption":text,"shot_locked":true}]}
