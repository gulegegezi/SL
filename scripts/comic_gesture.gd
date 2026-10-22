extends RefCounted
## Shared whole-body keypose timing for the lead and every supporting actor.
const DURATION := 2.4
const ACTIVE := ["raise","reach","receive","offer","talk","read","phone","sign","draw","drum","type","wave","nod","sit","eat"]

static func sample(action: String, time: float, settled: bool = false) -> Dictionary:
	var t := DURATION if settled else clampf(time,0,DURATION)
	var active := action in ACTIVE
	var frame := 0
	if active:
		if t >= 0.16 and t < 0.62: frame = 1
		elif t >= 0.62: frame = 3 if action == "wave" else 2
		if action in ["nod","sit"]: frame = 0
		if action in ["phone","drum","type","sign","draw"] and t >= 0.62: frame = 1
	var envelope := sin(clampf((t-0.16)/2.24,0,1)*PI)
	var lean := 0.0
	var offset := Vector2.ZERO
	var squash := Vector2.ONE
	if not settled and t < DURATION and active:
		lean = deg_to_rad(-2.5*sin(clampf(t/0.62,0,1)*PI)) if t < 0.62 else deg_to_rad(2.0*envelope)
		offset = Vector2(-2*sin(clampf(t/0.62,0,1)*PI),0)
		squash = Vector2(1+envelope*0.015,1-envelope*0.018)
		if action == "nod": offset.y = sin(clampf(t/1.4,0,1)*PI)*2
		if action in ["drum","type","sign","draw"] and t > 0.62:
			offset.y = sin((t-0.62)*16)*envelope*1.2
		if action == "wave" and t > 0.62: lean += deg_to_rad(sin((t-0.62)*9)*1.5*envelope)
	if action == "sit": squash.y *= lerpf(1.0,0.87,smoothstep(0.16,1.4,t))
	return {"frame":frame,"angle":lean,"offset":offset,"scale":squash,
		"contact":t>=0.62,"phase":"anticipation" if t<0.62 else ("action" if t<1.85 else "settle")}

static func response(mode: String, action: String, time: float) -> Dictionary:
	var kind := "idle"
	var delay := 0.0
	match mode:
		"gift": kind = "offer"; delay = -0.22
		"care": kind = "receive"; delay = 0.22
		"performance": kind = "wave"; delay = 0.65
		"farewell": kind = "wave"; delay = 0.25
		_: kind = "nod" if action != "idle" else "idle"; delay = 0.38
	return {"action":kind,"time":maxf(0,time-delay)}
