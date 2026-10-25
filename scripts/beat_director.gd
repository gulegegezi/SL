## beat_director.gd — 把一句台词读成「怎么演」。
##
## 动画路线只允许给 beats 追加可选字段；这里做的是**反向**：
## 不要求剧情数据补字段，先从文本里读动作、表情、镜头，
## 让旧的 story_cutscenes.json 也能「说到哪，演到哪」。
##
## 优先级：beat 里显式写的 expr / action / camera > 文本推断 > 默认值。
extends RefCounted
const Semantic := preload("res://scripts/comic_performance.gd")

## 数据里出现过 shock 这类旧别名，统一收到 10 表情里
const EXPR_ALIAS := {
	"neutral": "normal",
	"normal": "normal",
	"surprise": "surprise",
	"scared": "scared",
	"determined": "determined",
}

## 表情按「越具体越优先」排队：疼/怕 比 笑 更能说明这一刻
const EXPR_RULES := [
	# 越夸张的越先判：一句里同时有「哭」和「笑」时，先演更用力的那个
	["dead", ["失神", "空白", "麻木", "没有反应", "眼神空", "生无可恋"]],
	["cry", ["大哭", "爆哭", "嚎", "哭得", "眼泪止不住", "泣不成声"]],
	["rage", ["暴怒", "炸了", "怒吼", "怒不可遏", "掀桌", "火冒三丈"]],
	["hurt", ["疼", "痛", "伤", "病", "血", "累", "喘", "咬牙"]],
	["panic", ["慌", "急", "乱", "糟了", "怎么办", "手足无措"]],
	["scared", ["怕", "恐", "颤", "抖", "危险", "黑暗", "不敢"]],
	["shock", ["惊", "吓", "震", "呆住", "瞪大", "目瞪口呆", "震惊"]],
	["smug", ["得意", "嚣张", "坏笑", "挑眉", "哼", "小看我"]],
	["love", ["心动", "喜欢", "脸红心跳", "看呆", "砰砰"]],
	["angry", ["怒", "骂", "吼", "吵", "气死", "恨", "滚"]],
	["surprise", ["突然", "愣", "竟然", "猛地", "没想到"]],
	["sad", ["哭", "难过", "伤心", "眼泪", "舍不得", "失落", "沉默"]],
	["shy", ["害羞", "脸红", "不好意思", "低头"]],
	["determined", ["一定", "决定", "发誓", "坚持", "咬", "握紧"]],
	["happy", ["笑", "开心", "高兴", "暖", "甜", "乐"]],
]

## 夸张演出：哪些表情要配「冲击帧」——白闪 / 集中线 / 抖屏 / 拟声词
const IMPACT := {
	"rage": {"sfx": "轰", "shake": 9.0, "flash": 0.55, "punch": 0.30},
	"shock": {"sfx": "！！", "shake": 8.0, "flash": 0.60, "punch": 0.28},
	"cry": {"sfx": "呜哇", "shake": 4.0, "flash": 0.0, "punch": 0.16},
	"panic": {"sfx": "哗", "shake": 6.0, "flash": 0.0, "punch": 0.14},
	"dead": {"sfx": "……", "shake": 0.0, "flash": 0.0, "punch": -0.10},
	"love": {"sfx": "咚", "shake": 0.0, "flash": 0.35, "punch": 0.18},
	"angry": {"sfx": "哼", "shake": 4.0, "flash": 0.0, "punch": 0.12},
	"hurt": {"sfx": "！", "shake": 5.0, "flash": 0.20, "punch": 0.14},
}


static func impact_for(expr: String) -> Dictionary:
	return IMPACT.get(expr, {})

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
	var expr := str(Semantic.direction(text).expr)
	return "blink" if expr == "sleep" else expr


static func action_for(text: String) -> String:
	var action := str(Semantic.direction(text).action)
	if action == "sleep": return "sit"
	if action == "nod": return "idle"
	if action == "put_down": return "idle"
	if action in ["sign", "phone", "read", "type", "poweroff"]: return "raise"
	return action


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
		"stop": bool(Semantic.direction(text).get("cancel_action", false)),
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
	return Semantic.weather_for(text)
