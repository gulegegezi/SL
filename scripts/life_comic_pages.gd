extends RefCounted
## Adapter: authored camera/action vocabulary -> existing comic renderer.
const Director := preload("res://scripts/comic_director.gd")
const PixelDirection := preload("res://scripts/pixel_story_direction.gd")
const ROLE_ART := {"clinician":"mate","hobby_admin":"teacher","community_teacher":"teacher","neighbor":"friend"}
const PROPS := {"blanket":"blanket","photo":"photo","flashlight":"flashlight","biscuit":"biscuit","tooth":"tooth","eraser":"eraser","ledger":"book","exam":"contract","notebook":"book","eggs":"eggs","plant":"plant","fridge":"fridge","phone":"phone","bill":"contract","noodles":"meal","report":"contract","key":"key","badge":"badge","bench":"bench","drum":"drum"}
## 漫画插页只应用到前半生（0–30 岁）
const FIRST_HALF_AGE := 30
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
	# 支持「角色之间的多轮对话」：每行一个「名字：台词」，
	# 没有名字的行接到上一句；「你」走主角立绘，其他名字映射到 NPC 立绘。
	var output: Array = []
	var default_role := "friend"
	for slot in e.get("actors", []):
		if slot != "lead":
			default_role = e.get("cast_bindings", {}).get(slot, slot)
			break
	var name_to_role := {
		"妈妈": "parent", "母亲": "parent",
		"爸爸": "mate", "父亲": "mate",
		"老师": "teacher", "班主任": "teacher", "医生": "clinician",
		"同桌": "friend", "同学": "friend", "朋友": "friend", "老同学": "friend",
		"室友": "friend", "熟人": "friend", "邻居": "neighbor",
		"管理员": "hobby_admin", "同事": "boss", "老板": "boss",
		"伴侣": "partner", "对方": "partner", "班长": "friend", "销售": "boss",
	}
	var turns: Array = []
	var remaining := text
	for marker in ["妈妈：", "爸爸："]: remaining = remaining.replace(marker, "\n" + marker)
	for raw in remaining.split(char(10), false):
		var line := str(raw).strip_edges()
		if line.is_empty():
			continue
		var at: int = line.find("：")
		var name := ""
		var words := line
		if at > 0 and at <= 6:
			name = line.left(at)
			words = line.substr(at + 1).strip_edges()
		if name.is_empty() and not turns.is_empty():
			turns[turns.size() - 1][1] = str(turns[turns.size() - 1][1]) + " " + words
		else:
			turns.append([name, words])
	for turn in turns:
		var name := str(turn[0])
		var words := str(turn[1])
		if names_are_lead(name):
			var me := speak(run, e, {"shot": "medium", "actors": ["lead"], "action": "talk"}, words, "你", "lead")
			me["support"] = ""
			me["world_solo"] = true
			output.append(me)
			continue
		var role: String = name_to_role.get(name, default_role)
		if not run.s.roles.get(role, {}).get("alive", false):
			role = "clinician"
		var art_role: String = ROLE_ART.get(role, role)
		var p := speak(run, e, {"shot": "medium", "actors": ["lead", role], "action": "talk"}, words, name, art_role)
		p["support"] = "npc_" + art_role
		p["world_solo"] = false
		output.append(p)
	return output


static func names_are_lead(name: String) -> bool:
	return name in ["你", "我", "自己"]


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
		"action":action_for(original.get("action","")),"actor":speaker,"source_action":original.get("action",""),"presentation":"pixel3d"}
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
			# 过于离谱的选择：在结果旁白后面追加一句吐槽（数据里可选）
			var roast := str(c.get("roast", "")).strip_edges()
			if not roast.is_empty():
				response += "\n" + roast
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
	var special: Dictionary = PixelDirection.cg(e.id,result)
	for p in panels: p["pixel_variant"] = special.get("variant","quiet" if str(e.id).begins_with("RX") else "day")
	if not special.is_empty(): panels[0]["pixel_cg"] = special
	# 剧情统一用对话框讲：画面只当背景，不再要求每句话都配一个镜头
	for i in range(panels.size()):
		panels[i]["box"] = "dialogue"
	if bool(e.get("text_only", false)):
		for i in range(panels.size()):
			panels[i].erase("pixel_cg")
			panels[i].erase("pixel_interaction")
	if not result:
		_apply_insert(run, panels, e)
	# 旁白插拍：次数按事件类型，位置可数据指定，否则挑情绪峰值
	if not result and e.has("narrator_asides"):
		var asides: Array = e.get("narrator_asides", [])
		var want := aside_count_for(e)
		var plan: Dictionary = e.get("aside_plan", {})
		if want > 0 and not asides.is_empty():
			var after: Array = plan.get("after", [])
			var ordinals := aside_positions(panels, want, after)
			var spots: Array = []
			var seen := 0
			for i in range(panels.size()):
				if str(panels[i].get("text_channel", "")) == "dialogue":
					seen += 1
					if seen in ordinals:
						spots.append(i + 1)
			var tiers: Array = plan.get("tiers", [])
			for k in range(spots.size() - 1, -1, -1):
				var pick := int(tiers[k]) if k < tiers.size() else (t + k * 2) % asides.size()
				var aside := str(asides[posmod(pick, asides.size())]).strip_edges()
				if aside.is_empty():
					continue
				var note := speak(run, e, {"shot": "detail", "action": "settle"}, aside)
				note["expr"] = "normal"
				panels.insert(int(spots[k]), note)
	# 电波系：把「此刻的误会」明摆出来（参考 GAMERS 的误会网）
	var misread := str(e.get("misread", "")).strip_edges()
	if not result and not misread.is_empty():
		var note := speak(run, e, {"shot": "wide", "action": "settle"}, "误会：" + misread)
		note["expr"] = "normal"
		panels.append(note)
	if not result:
		var action: Dictionary = PixelDirection.interaction(e.id)
		if not action.is_empty():
			panels[-1]["pixel_interaction"] = action
			panels[-1]["interaction_progress"] = {"completed":false}
			if action.get("target","") == "npc" and panels[-1].get("world_solo",false):
				panels[-1]["support"] = "npc_mate"
				for earlier in panels:
					if earlier.get("support","none") != "none": panels[-1]["support"] = earlier.support; break
				panels[-1]["world_solo"] = false
	return {"no":run.s.pages.size()+1,"age":run.s.age,"stage":run.pack.rules.tiers[t].name,"title":e.title,
		"event_id":e.id,"result":result,"panels":panels,"series":0,"slots":[],"dialogue_version":2,
		"text_only":bool(e.get("text_only", false))}

## 旁白插哪：数据指定 after，否则挑「情绪峰值」（以 ！/？ 结尾的对白）
static func aside_positions(panels: Array, want: int, after: Array = []) -> Array:
	if want <= 0:
		return []
	if not after.is_empty():
		var fixed: Array = []
		for v in after:
			fixed.append(int(v))
			if fixed.size() >= want:
				break
		return fixed
	var peaks: Array = []
	var ordinal := 0
	for p in panels:
		if str(p.get("text_channel", "")) != "dialogue":
			continue
		ordinal += 1
		var line := str(p.get("bubble", "")).strip_edges()
		if line.ends_with("！") or line.ends_with("？"):
			peaks.append(ordinal)
	var out: Array = []
	for v in peaks:
		if out.size() >= want:
			break
		out.append(v)
	for fallback in [2, 5, 3, 4]:
		if out.size() >= want:
			break
		if not out.has(fallback):
			out.append(fallback)
	out.sort()
	return out


## 旁白插几次：按事件类型决定，可用 aside_count 覆盖
static func aside_count_for(e: Dictionary) -> int:
	if e.has("aside_plan"):
		return clampi(int(e.aside_plan.get("count", 1)), 0, 3)
	if e.has("aside_count"):
		return clampi(int(e.aside_count), 0, 3)
	if bool(e.get("text_only", false)):
		return 0          # 长文本页本身旁白已经很多
	if e.has("misread"):
		return 2          # 误会喜剧：旁白多嘴两次
	if e.has("echo"):
		return 1          # 回响页：一次就够
	var turns := str(e.get("npc_dialogue", "")).count("：")
	if turns >= 6:
		return 2          # 对白密集：插两次
	return 1


## 前半生里「动作演不出来」的页：改成双格漫画（旁白框 + 气泡 + 立绘）
static func _apply_insert(run, panels: Array, e: Dictionary) -> void:
	if bool(e.get("text_only", false)):
		return
	if int(run.s.age) > FIRST_HALF_AGE:
		return
	var has_dialogue := false
	for probe in panels:
		if str(probe.get("text_channel", "")) == "dialogue":
			has_dialogue = true
			break
	for p in panels:
		if str(p.get("action", "idle")) != "idle":
			continue
		if p.has("pixel_interaction") or p.has("pixel_cg"):
			continue
		var caption := str(p.get("caption", ""))
		if caption.is_empty() and str(p.get("bubble", "")).is_empty():
			continue
		var narrator := caption.trim_prefix("旁白：")
		if narrator.is_empty():
			var first_bits := str(e.get("facts", "")).split("。", false)
			narrator = str(first_bits[0]) + "。" if first_bits.size() > 0 else str(e.get("title", ""))
		var speech := str(p.get("bubble", ""))
		var colon := speech.find("：")
		if colon >= 0:
			speech = speech.substr(colon + 1)
		if speech.is_empty() and not has_dialogue:
			speech = str(e.get("npc_dialogue", ""))
			var c2 := speech.find("：")
			if c2 >= 0:
				speech = speech.substr(c2 + 1)
		# 有的页里对话已经单独成格，has_dialogue 为真，但被选中的这一格本身没有台词，
		# 于是插页第二格会没有气泡。退一步：优先用 npc_dialogue，再用本档位的台词。
		if speech.strip_edges().is_empty():
			var fallback := str(e.get("npc_dialogue", ""))
			var c3 := fallback.find("：")
			if c3 >= 0:
				fallback = fallback.substr(c3 + 1)
			if fallback.strip_edges().is_empty():
				var tier: int = int(run.s.pending.get("tier", 0))
				var lenses: Array = e.get("lenses", [])
				if tier < lenses.size():
					fallback = str(lenses[tier].get("dialogue", ""))
			speech = fallback
		var second := ""
		var bits := str(e.get("facts", "")).split("。", false)
		if bits.size() > 1:
			second = str(bits[1]) + "。"
		var lead_key := str(p.get("ink", "lead_adult"))
		var support := str(p.get("support", ""))
		p["presentation"] = "comic_insert"
		p["comic_insert"] = {"panels": [
			{"caption": narrator, "key": lead_key, "bg": "paper", "bg_art": "scene",
				"scene": str(e.get("scene", "home"))},
			{"caption": second, "bubble": speech,
				"key": support if not support.is_empty() and support != "none" else lead_key, "bg": "ink"},
		]}
		return


static func upgrade_legacy(spec: Dictionary) -> Dictionary:
	if int(spec.get("dialogue_version",0)) >= 2:
		var staged := spec.duplicate(true)
		for p in staged.get("panels",[]):
			if not str(p.get("ink","")).is_empty(): p["presentation"] = "pixel3d"
		if not staged.get("panels",[]).is_empty():
			var id: String = staged.get("event_id","")
			var special: Dictionary = PixelDirection.cg(id,bool(staged.get("result",false)))
			if not special.is_empty() and not staged.panels[0].has("pixel_cg"):
				staged.panels[0]["pixel_cg"] = special
				staged.panels[0]["cg_progress"] = {"completed":true}
			for p in staged.panels:
				if not p.has("pixel_variant"): p["pixel_variant"] = special.get("variant","day")
			var action: Dictionary = PixelDirection.interaction(id)
			if not action.is_empty() and not bool(staged.get("result",false)) and not staged.panels[-1].has("pixel_interaction"):
				staged.panels[-1]["pixel_interaction"] = action
		return staged
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
	return upgrade_legacy(out)

static func ending(run) -> Dictionary:
	var terminal: Dictionary = run.s.terminal
	var text := ""
	for e in run.pack.endings:
		if e.id == terminal.id or (terminal.early and e.id == "END_EARLY"):
			text += str(e.voices[terminal.tier])+"\n"
	return {"no":run.s.pages.size()+1,"age":terminal.age,"stage":"未完" if terminal.id == "END_OPEN" else "这一生的尾声","slots":[],
		"panels":[{"ink":"","tone":"black","shot":"wide","caption":"旁白："+text,"shot_locked":true}]}
