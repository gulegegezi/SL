## beat_director.gd — 把一句台词读成「怎么演」。
##
## 动画路线只允许给 beats 追加可选字段；这里做的是**反向**：
## 不要求剧情数据补字段，先从文本里读动作、表情、镜头，
## 让旧的 story_cutscenes.json 也能「说到哪，演到哪」。
##
## 优先级：beat 里显式写的 expr / action / camera > 文本推断 > 默认值。
extends RefCounted

## 数据里出现过 shock 这类旧别名，统一收到 10 表情里
const EXPR_ALIAS := {
	"shock": "surprise",
	"neutral": "normal",
	"normal": "normal",
	"surprise": "surprise",
	"scared": "scared",
	"determined": "determined",
}

## 表情按「越具体越优先」排队：疼/怕 比 笑 更能说明这一刻
const EXPR_RULES := [
	["hurt", ["疼", "痛", "伤", "病", "血", "累", "喘", "咬牙"]],
	["scared", ["怕", "恐", "颤", "抖", "危险", "黑暗", "不敢"]],
	["angry", ["怒", "骂", "吼", "吵", "气死", "恨", "滚"]],
	["surprise", ["惊", "吓", "突然", "愣", "呆", "竟然", "猛地"]],
	["sad", ["哭", "难过", "伤心", "眼泪", "舍不得", "失落", "沉默"]],
	["shy", ["害羞", "脸红", "不好意思", "低头"]],
	["determined", ["一定", "决定", "发誓", "坚持", "咬", "握紧"]],
	["happy", ["笑", "开心", "高兴", "喜欢", "暖", "甜", "乐"]],
]

## 动作优先长词，避免「走廊」被当成「走」
const ACTION_RULES := [
	["sit", ["坐下", "坐着", "躺下", "躺在", "蹲下", "趴在", "瘫"]],
	["wave", ["挥手", "招手", "摆了摆手", "挥了挥", "告别"]],
	["raise", ["举起", "抬起", "伸手", "够到", "接过", "递给", "抓住"]],
	["walk", ["走了", "走进", "走出", "跑", "奔", "追上", "逃", "冲向"]],
]

const PUNCT_LONG := ["。", "！", "？", "…"]
const PUNCT_SHORT := ["，", "、", "：", "；"]


static func expression_for(text: String) -> String:
	for rule in EXPR_RULES:
		for w in rule[1]:
			if text.find(w) >= 0:
				return str(rule[0])
	return "normal"


static func action_for(text: String) -> String:
	for rule in ACTION_RULES:
		for w in rule[1]:
			if text.find(w) >= 0:
				return str(rule[0])
	return "idle"


## 一句台词 → 这一拍怎么动
## actor: "lead" 或 NPC 角色名（来自 beat.face）
## 返回 {expr, action, hold, emotion, focus}
static func direction(beat: Dictionary, actor: String = "lead") -> Dictionary:
	var text := str(beat.get("text", ""))
	var expr := str(beat.get("expr", "")).strip_edges()
	if expr.is_empty():
		expr = expression_for(text)
	expr = str(EXPR_ALIAS.get(expr, expr))
	var action := str(beat.get("action", "")).strip_edges()
	if action.is_empty():
		action = action_for(text)
	# 动作需要一个起手时间：先动起来，再开口
	var hold := 0.0 if action == "idle" else 0.22
	return {
		"expr": expr,
		"action": action,
		"hold": hold,
		"emotion": expr != "normal",
		"actor": actor,
	}


## 镜头：说话的人在哪，镜头就往哪压一点；旁白/情绪弱的句子拉远
static func shot_for(beat: Dictionary, actor_x: float, base_zoom: float) -> Dictionary:
	var text := str(beat.get("text", ""))
	var speaker := str(beat.get("speaker", ""))
	var d := direction(beat)
	var zoom := base_zoom
	if speaker == "旁白":
		zoom = base_zoom - 0.06
	elif bool(d["emotion"]):
		zoom = base_zoom + 0.12
	return {
		"zoom": clampf(zoom, 0.85, 1.6),
		"x": clampf(actor_x, 24.0, 136.0),
		"y": 46.0,
	}


## 逐字节拍：标点留气口，和画面上的停顿对齐
static func char_delay(ch: String) -> float:
	if ch in PUNCT_LONG:
		return 0.22
	if ch in PUNCT_SHORT:
		return 0.10
	if ch == "\n":
		return 0.16
	return 0.042


static func is_pause(ch: String) -> bool:
	return ch in PUNCT_LONG or ch in PUNCT_SHORT or ch == "\n"


## 天气：文字里说了雨/雪/风/夜，画面就跟着下
static func weather_for(text: String) -> String:
	if text.find("雨停") >= 0 or text.find("放晴") >= 0 or text.find("停了") >= 0:
		return "clear"
	if text.find("雨") >= 0:
		return "rain"
	if text.find("雪") >= 0:
		return "snow"
	if text.find("风") >= 0:
		return "wind"
	if text.find("夜") >= 0 or text.find("天黑") >= 0:
		return "night"
	return ""
