extends RefCounted
## Pure, deterministic action timeline. Historic panels sample a settled pose.
const DURATION := 2.4
const NAMED := ["reach","receive","offer","read","phone","sign","draw","drum","wave","walk","sit","nod","type","poweroff","put_down","eat"]

static func minimum_time(action: String) -> float:
	return {"sign":1.8,"draw":1.8,"walk":1.85,"drum":1.4,"phone":1.05,"read":1.05,"raise":0.85,"reach":0.85,"wave":0.85,"put_down":0.82,"poweroff":0.82}.get(action,0.0)

static func kind(direction: Dictionary) -> String:
	var action := str(direction.get("action","idle"))
	var prop := str(direction.get("prop",""))
	if prop == "drum" and action in ["raise","wave","reach"]: return "drum"
	if prop == "pencil" and action == "sign": return "draw"
	if prop == "meal" and action == "raise": return "eat"
	if action == "raise": return "reach"
	return action

static func interaction_kind(config: Dictionary) -> String:
	if config.has("action"): return str(config.action)
	if str(config.get("kind","")) == "drag": return "receive"
	match str(config.get("prop","")):
		"phone": return "phone"
		"drum": return "drum"
		"pencil": return "draw"
		"book": return "read"
		"clock": return "reach"
		_: return "read"

static func sample(action: String, time: float, reduced: bool = false) -> Dictionary:
	var t := DURATION if reduced else clampf(time,0,DURATION)
	var reach := smoothstep(0.22,0.82,t)
	var settle := smoothstep(1.85,DURATION,t)
	var windup := sin(clampf(t/0.28,0,1)*PI)
	var stroke := sin(clampf((t-0.8)/1.05,0,1)*PI*6)*(1-settle) if t >= 0.8 else 0.0
	var out := {"phase":"anticipation" if t < 0.22 else ("reach" if t < 0.82 else ("contact" if t < 1.85 else "settle")),
		"reach":reach,"contact":t>=0.82,"pose":smoothstep(0.24,0.65,t),"settle":settle,
		"offset":Vector2.ZERO,"angle":0.0,"hand":reach,"stroke":stroke,"camera":1.0}
	out["travel"] = smoothstep(0.22,1.85,t)
	out["work"] = smoothstep(0.82,1.85,t)
	match action:
		"reach","receive","offer":
			out.offset = Vector2(-windup*3+reach*7*(1-settle*0.4),-sin(reach*PI)*3)
			out.angle = (-windup*1.5+reach*2.5*(1-settle*0.4))*PI/180
		"phone": out.angle = -reach*2*PI/180; out.offset = Vector2(reach*3,-reach*2)
		"read": out.angle = reach*3*PI/180; out.offset = Vector2(0,reach*4)
		"sign","draw","type":
			out.angle = reach*4*PI/180
			out.offset = Vector2(stroke*0.8,reach*5)
		"drum": out.offset = Vector2(stroke*1.5,absf(stroke)*3); out.angle = stroke*0.8*PI/180
		"wave": out.hand = sin(clampf((t-0.25)/1.4,0,1)*PI*5)*(1-settle)
		"walk": out.offset = Vector2(0,sin(float(out.travel)*PI*6)*2.5*(1-settle))
		"sit": out.offset = Vector2(0,reach*18)
		"nod": out.offset = Vector2(0,sin(clampf((t-0.22)/1.2,0,1)*PI)*7)
		"put_down","poweroff": out.hand = 1-reach
		"eat": out.hand = reach; out.angle = reach*2*PI/180
	if action in ["phone","read","sign","draw","drum"]:
		out.camera = 1+sin(clampf(t/DURATION,0,1)*PI)*0.025
	return out
