extends RefCounted
const Direction := preload("res://scripts/comic_performance.gd")
const Pacing := preload("res://scripts/short_life.gd")

static func page(s, source: Dictionary, ink: String, no: int, result: bool = false) -> Dictionary:
	var panels: Array = []
	if not result and source.has("jump_from"):
		panels.append({"caption": Pacing.jump_text(s, int(source.jump_from)), "ink":"", "shot":"detail", "tone":"black", "shot_locked":true})
	for original in source.get("comic", []):
		var panel: Dictionary = original.duplicate(true)
		panel["ink"] = ink
		panel["scene"] = str(panel.get("scene", source.get("scene", "home")))
		panel["tone"] = str(panel.get("tone", "paper"))
		panel["age"] = int(s.age)
		if panel.has("interaction"):
			panel["support"] = str(source.get("comic",[])[0].get("support","npc_friend"))
			panel["stage_action"] = true
			panel["interaction_progress"] = {"completed":false}
		panels.append(panel)
	if result:
		var summary := ""
		for attr in source.get("effects", {}):
			summary += "%s %+d  " % [{"health":"体质","money":"金钱","charm":"魅力","int":"心智","lifespan":"寿命","abstract":"抽象度"}.get(attr,attr),int(source.effects[attr])]
		for tag in source.get("tags",[]): summary += "留下：" + str(tag) + "  "
		panels.append({"caption":summary.strip_edges(),"ink":"","shot":"detail","tone":"black","shot_locked":true})
	var out := {"no":no,"age":int(s.age),"title":str(source.get("title", "选择之后")),
		"stage":"人生短篇","event_id":str(source.get("id","")),"result":result,
		"panels":panels,"slots":[],"series":16,"montage":false}
	return Direction.annotate(out)
