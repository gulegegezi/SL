extends SceneTree
const Run := preload("res://scripts/life_comic_run.gd")
const Pages := preload("res://scripts/life_comic_pages.gd")
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func text_of(spec: Dictionary) -> String:
	var output := ""
	for p in spec.panels:
		check(str(p.get("caption","")).is_empty() or str(p.get("bubble","")).is_empty(),"one speaking channel per panel")
		output += str(p.get("caption",""))+str(p.get("bubble",""))+"\n"
	check(not output.contains("【心里】") and not output.contains("【心里的字幕】"),"no mixed inner-monologue block")
	return output
func _initialize() -> void:
	var run = Run.new()
	check(Pages.book().size() == run.events.size(),"all events have original narrator scripts")
	for e in run.events.values():
		for t in range(4):
			for choice_index in range(3):
				var life = Run.new(); life.start(83)
				life.s.pending = {}; life.s.age = int(e.age_range[0]); life.s.scores.abstract = t*25
				life.begin(e.id)
				var opening: String = text_of(Pages.make(life))
				check(opening.contains(e.facts),"setup facts preserved")
				for literal in e.npc_dialogue.replace("妈妈：","\n妈妈：").replace("爸爸：","\n爸爸：").split("\n",false):
					check(opening.contains(literal),"literal NPC words preserved in each lens")
				life.choose(choice_index)
				var result_text: String = text_of(Pages.make(life,true))
				check(result_text.count(life.s.committed.facts) == 1,"actual consequence stated exactly once")
				if life.s.age < 3: check(not result_text.contains("【心"),"infant has sounds, no adult subtitles")
	var legacy := {"panels":[{"caption":"同一件事。","bubble":""},{"caption":"同一件事。 后续。\n【心里】旧心声","bubble":"我说的话"}]}
	var converted: Dictionary = Pages.upgrade_legacy(legacy)
	var restored: String = text_of(converted)
	check(restored.count("同一件事。") == 1 and restored.contains("后续。") and restored.contains("你：我说的话"),"old pages migrate without duplicate facts or lost dialogue")
	check(legacy.panels[1].caption.contains("旧心声"),"migration does not mutate its input")
	check(Pages.upgrade_legacy(converted) == converted,"migration is idempotent")
	print("LIFE_DIALOGUE_SMOKE ","PASS" if failures == 0 else "FAIL"," · ",run.events.size()," events x 4 tiers x 3 choices / legacy presentation")
	quit(0 if failures == 0 else 1)
