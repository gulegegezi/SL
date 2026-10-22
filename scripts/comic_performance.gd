extends RefCounted
## Rule-based semantic direction shared by the comic reader and legacy cutscenes.
## Explicit instructions win; negative, hypothetical and cancelled verbs do not act.
const EMOTIONS := [
	["dead", ["失神", "麻木", "生无可恋", "无语", "一片空白"]],
	["cry", ["爆哭", "大哭", "泣不成声", "眼泪止不住", "哭得", "嚎啕"]],
	["rage", ["暴怒", "怒吼", "火冒三丈", "掀桌", "怒不可遏"]],
	["shock", ["震惊", "吃惊", "吓了一跳", "目瞪口呆", "惊呆", "瞪大", "呆住"]],
	["panic", ["慌", "糟了", "怎么办", "手足无措", "冷汗"]],
	["sleep", ["睡着", "睡了", "闭上眼", "入睡", "打盹"]],
	["love", ["心动", "怦然", "脸红心跳"]],
	["smug", ["得意", "挑眉", "坏笑", "嚣张"]],
	["hurt", ["疼", "痛", "累", "受伤", "喘", "咬牙"]],
	["scared", ["害怕", "怕", "恐惧", "发抖"]],
	["angry", ["生气", "愤怒", "骂", "吼"]],
	["sad", ["哭", "难过", "伤心", "眼泪", "失落", "舍不得"]],
	["shy", ["害羞", "不好意思", "脸红", "低下头"]],
	["determined", ["决定", "发誓", "坚持", "握紧"]],
	["happy", ["笑", "开心", "高兴", "暖", "喜悦"]],
]
const ACTIONS := [
	["idle", ["停下", "站住", "停住", "停止走", "不动了"]],
	["put_down", ["放下", "收起", "挂断"]],
	["sleep", ["睡着", "睡了", "躺下", "入睡", "打盹"]],
	["sign", ["签下", "签字", "签了", "签名"]],
	["phone", ["拿起手机", "接起电话", "拨通", "打电话"]],
	["read", ["翻开书", "读书", "看书", "翻书"]],
	["poweroff", ["关掉电脑", "关闭电脑", "合上电脑"]],
	["type", ["敲键盘", "打字", "打开电脑", "加班"]],
	["nod", ["点头", "点了点头"]],
	["wave", ["挥手", "招手", "挥了挥", "告别"]],
	["sit", ["坐下", "坐着", "蹲下", "趴在"]],
	["raise", ["举起", "伸手", "抬起", "接过", "递给", "抓住"]],
	["walk", ["走进", "走出", "走了", "离开", "跑", "奔", "冲向", "逃"]],
]
const ACTORS := [["parent", ["妈妈", "母亲", "奶奶", "外婆"]], ["boss", ["老板", "上司"]], ["teacher", ["老师", "教师"]], ["partner", ["伴侣", "爱人", "妻子", "丈夫"]], ["friend", ["朋友", "同学", "同事"]], ["mate", ["爸爸", "父亲", "邻居", "爷爷", "外公"]], ["lead", ["你", "我"]]]
const NEGATIVES := ["没有", "并不", "并未", "不再", "不曾", "从没", "未曾", "不要", "别", "没", "不"]
const STRONG := ["爆哭", "大哭", "暴怒", "震惊", "惊呆", "吓了一跳", "怒吼", "目瞪口呆", "掀桌", "手足无措", "泣不成声"]

static func positive_at(text: String, word: String, at: int) -> bool:
	var prefix := text.substr(maxi(0, at - 6), mini(at, 6))
	var suffix := text.substr(at + word.length(), 4)
	if prefix.ends_with("忍不住") or prefix.ends_with("情不自禁"): return true
	if suffix.begins_with("不出来") or suffix.begins_with("不了"): return false
	for neg in NEGATIVES:
		var index := prefix.rfind(neg)
		if index >= 0 and prefix.length() - index - neg.length() <= 3: return false
	return true

static func _match(text: String, rules: Array, fallback: String) -> Dictionary:
	var mentioned := false
	for rule in rules:
		for word in rule[1]:
			var at := text.find(word)
			while at >= 0:
				mentioned = true
				if positive_at(text, word, at): return {"value": rule[0], "at": at, "mentioned": true}
				at = text.find(word, at + str(word).length())
	return {"value": fallback, "at": 0, "mentioned": mentioned}

static func _subject(text: String, before: int, fallback: String) -> String:
	var best := -1
	var actor := fallback
	var prefix := text.substr(0, before + 1)
	for row in ACTORS:
		for name in row[1]:
			var at := prefix.rfind(name)
			if at > 0 and prefix.substr(at - 1, 1) in ["对", "向", "给"]: continue
			if at > best: best = at; actor = row[0]
	return actor

static func analyse(text: String, fallback_actor: String = "lead") -> Dictionary:
	var emotion := _match(text, EMOTIONS, "normal")
	var action := _match(text, ACTIONS, "idle")
	var hypothetical := text.begins_with("如果") or text.begins_with("要是") or text.begins_with("假如")
	if hypothetical: emotion.value = "normal"; action.value = "idle"
	var cue := mini(int(emotion.at) if emotion.mentioned else text.length(), int(action.at) if action.mentioned else text.length())
	if cue >= text.length(): cue = 0
	var subject_at := cue if emotion.mentioned or action.mentioned else mini(text.length(),3)
	var actor := _subject(text, subject_at, fallback_actor)
	var intensity := 0 if str(emotion.value) == "normal" else 1
	for word in STRONG:
		var at := text.find(word)
		if at >= 0 and not hypothetical and positive_at(text, word, at): intensity = 3
	var prop: String = {"sign": "contract", "phone": "phone", "read": "book", "type": "computer", "poweroff": "computer", "sleep": "bed"}.get(action.value, "")
	return {"text": text, "expr": emotion.value, "action": action.value, "actor": actor, "prop": prop,
		"emotion_mentioned": emotion.mentioned, "action_mentioned": action.mentioned,
		"cancel_action": bool(action.mentioned) and str(action.value) == "idle",
		"intensity": intensity, "cue": cue, "mentioned": emotion.mentioned or action.mentioned,
		"sfx": {"rage": "轰", "shock": "？！", "cry": "呜哇", "panic": "咯噔", "dead": "……"}.get(emotion.value, "") if intensity >= 3 or str(emotion.value) == "dead" else "",
		"weather": weather_for(text)}

static func clauses(text: String, fallback_actor: String = "lead") -> Array:
	var out: Array = []
	var regex := RegEx.new()
	regex.compile("[^，。！？；\\n]+[，。！？；\\n]*")
	var previous_actor := fallback_actor
	for found in regex.search_all(text):
		var fragment := found.get_string()
		if fragment.begins_with("【") and fragment.strip_edges().ends_with("】"): continue
		var direction := analyse(fragment.strip_edges(), previous_actor)
		previous_actor = direction.actor
		direction["start"] = found.get_start()
		direction["trigger"] = found.get_start() + int(direction.cue)
		out.append(direction)
	if out.is_empty():
		var direction := analyse(text)
		direction["start"] = 0
		direction["trigger"] = 0
		out.append(direction)
	return out

static func direction(text: String) -> Dictionary:
	var beats := clauses(text)
	var result: Dictionary = beats[0]
	for beat in beats:
		if bool(beat.mentioned): result = beat
	return result.duplicate(true)

static func panel(spec: Dictionary) -> Dictionary:
	var out := spec.duplicate(true)
	var text := str(spec.get("caption", "")) + ("\n" + str(spec.bubble) if not str(spec.get("bubble", "")).is_empty() else "")
	var beats := clauses(text)
	var actors := {}
	for beat in beats:
		var actor := str(spec.get("actor", beat.actor))
		var previous: Dictionary = actors.get(actor, {"expr": "normal", "action": "idle", "prop": ""})
		if not bool(beat.emotion_mentioned) and not spec.has("expr"): beat.expr = previous.expr
		if not bool(beat.action_mentioned) and not spec.has("action"): beat.action = previous.action
		if str(beat.prop).is_empty(): beat.prop = previous.prop
		if bool(beat.cancel_action) or str(beat.action) == "put_down": beat.prop = ""
		for field in ["expr", "action", "actor", "prop", "intensity", "weather"]:
			if spec.has(field): beat[field] = spec[field]
		if str(beat.action) == "sleep" and not spec.has("expr"): beat.expr = "sleep"
		actors[actor] = {"expr": beat.expr, "action": beat.action, "prop": beat.prop}
		beat["sfx"] = {"rage": "轰", "shock": "？！", "cry": "呜哇", "panic": "咯噔", "dead": "……"}.get(beat.expr, "") if int(beat.intensity) >= 3 or str(beat.expr) == "dead" else ""
		beat["exit"] = false
		for leave in ["走出", "走了出去", "跑出", "跑了出去", "离开", "逃"]:
			if str(beat.action) == "walk" and str(beat.text).contains(leave): beat["exit"] = true
	out["performance"] = beats
	if not bool(spec.get("shot_locked", false)):
		var strongest := 0
		var focus_action := "idle"
		var focus_prop := ""
		var emotion := "normal"
		for beat in beats:
			strongest = maxi(strongest, int(beat.intensity))
			if str(beat.action) != "idle": focus_action = beat.action
			if not str(beat.prop).is_empty(): focus_prop = beat.prop
			if str(beat.expr) != "normal": emotion = beat.expr
		if strongest >= 3: out["shot"] = "extreme"
		elif not focus_prop.is_empty() and focus_action != "sleep": out["shot"] = "detail"
		elif focus_action == "walk": out["shot"] = "wide"
		elif emotion != "normal" and str(out.get("shot", "")) == "detail": out["shot"] = "close"
	# Random decorative sound effects must not imply an unrelated action.
	if not text.strip_edges().is_empty(): out["sfx"] = ""
	return out

static func annotate(page: Dictionary) -> Dictionary:
	var out := page.duplicate(true)
	var panels: Array = []
	for spec in page.get("panels", []): panels.append(panel(spec))
	out["panels"] = panels
	return out

static func weather_for(text: String) -> String:
	for stop in ["雨停", "雪停", "风停", "放晴", "不再下雨"]:
		if text.contains(stop): return "clear"
	for entry in [["rain", "下雨"], ["rain", "雨落"], ["rain", "雨声"], ["rain", "雨点"], ["rain", "暴雨"], ["rain", "大雨"], ["snow", "下雪"], ["snow", "雪花"], ["wind", "风吹"], ["wind", "起风"], ["night", "夜"]]:
		var at := text.find(entry[1])
		if at >= 0 and positive_at(text, entry[1], at) and not text.begins_with("如果"): return entry[0]
	return ""
