extends SceneTree
## 漫画分镜回归：
##   1. 分镜数随年龄增长、受健康与性格标签影响
##   2. 版式槽位数与分格数一致
##   3. 提笔带过页 / 结果页的结构
##   4. 七个年龄段的线稿资源齐全
##   5. 主界面 render_main 真的产出漫画页节点
## 运行：godot --headless --path . --script res://test/comic_smoke.gd

const CD := preload("res://scripts/comic_director.gd")
const GS := preload("res://scripts/game_state.gd")
const ComicPage := preload("res://scripts/comic_page.gd")

var fails: Array = []


func _initialize() -> void:
	call_deferred("run")


func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		print("  FAIL ", msg)
		fails.append(msg)


func _avg_panels(age: int, health: int, tags: Array) -> float:
	var s = GS.new()
	s.age = age
	s.health = health
	for t in tags:
		s.tags[t] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var run := CD.new_run(rng)
	rng.seed = 999
	var total := 0
	var n := 60
	for i in range(n):
		total += CD.panels_for(s, run, rng)
	return float(total) / float(n)


func run() -> void:
	print("== 1. 分镜数随年龄增长 ==")
	var a_child := _avg_panels(6, 12, [])
	var a_teen := _avg_panels(16, 12, [])
	var a_adult := _avg_panels(30, 12, [])
	print("  童年 %.2f 格 / 少年 %.2f 格 / 成年 %.2f 格" % [a_child, a_teen, a_adult])
	_ok(a_teen > a_child, "少年比童年分镜多")
	_ok(a_adult > a_teen, "成年比少年分镜多")

	print("== 2. 健康压缩分镜 ==")
	var h_low := _avg_panels(30, 3, [])
	var h_mid := _avg_panels(30, 10, [])
	var h_high := _avg_panels(30, 18, [])
	print("  体质3 %.2f / 体质10 %.2f / 体质18 %.2f" % [h_low, h_mid, h_high])
	_ok(h_low < h_mid, "体质差 → 分镜更少")
	_ok(h_high > h_mid, "体质好 → 分镜更多")

	print("== 3. 性格标签改变分镜 ==")
	var extro := _avg_panels(25, 12, ["会分享", "仗义", "勇敢"])
	var intro := _avg_panels(25, 12, ["守口如瓶", "观察者"])
	print("  外向 %.2f / 内向 %.2f" % [extro, intro])
	_ok(extro > intro, "外向比内向分镜多")

	print("== 4. 版式槽位与分格数一致 ==")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var layout_ok := true
	for n in range(1, 7):
		for k in range(6):
			var slots: Array = CD.layout_for(n, rng)
			if slots.size() != n:
				layout_ok = false
	_ok(layout_ok, "1~6 格的版式槽位数都等于格数")

	print("== 5. 页面生成 ==")
	var s = GS.new()
	s.age = 30
	s.health = 12
	s.lifespan = 80
	var ev := {"id": "T1", "title": "测试事件", "text": "第一句话。第二句话！「第三句是台词。」", "choices": []}
	rng.seed = 4242
	var run2 := CD.new_run(rng)
	var page: Dictionary = CD.build(s, ev, run2, rng, 3)
	_ok(page["panels"].size() == page["slots"].size(), "分格数与槽位数一致")
	_ok(int(page["no"]) == 3, "话数写入正确")
	var all_ink := true
	for p in page["panels"]:
		if str(p["ink"]).is_empty():
			all_ink = false
	_ok(all_ink, "每格都指定了线稿")
	var has_text := false
	for p in page["panels"]:
		if not str(p["caption"]).is_empty() or not str(p["bubble"]).is_empty():
			has_text = true
	_ok(has_text, "至少一格有文字")

	print("== 6. 提笔带过 / 结果页 ==")
	var mono: Dictionary = CD.build_montage(s, [{"age": 12, "title": "转学", "result": "你在新学校没人认识。"}], rng, 5)
	_ok(bool(mono["montage"]), "带过页有 montage 标记")
	_ok(mono["panels"].size() == 2, "带过页固定两格")
	var res: Dictionary = CD.build_result(s, {"label": "交公", "effects": {"charm": 2}}, "你被表扬了。", rng, 6)
	_ok(res["panels"].size() == 3, "结果页三格")

	print("== 7. 线稿资源齐全 ==")
	var missing: Array = []
	for age in [1, 6, 12, 18, 30, 50, 70]:
		var key: String = CD.ink_key(age)
		var p := "res://assets/ink/%s_0.png" % key
		if not ResourceLoader.exists(p):
			missing.append("%d→%s" % [age, key])
	_ok(missing.is_empty(), "七个年龄段线稿齐全 %s" % ("" if missing.is_empty() else str(missing)))

	print("== 8. 页面节点组装 ==")
	var pg = ComicPage.new()
	root.add_child(pg)
	pg.build(page, 520.0)
	await process_frame
	_ok(pg.panels.size() == page["panels"].size(), "ComicPage 生成了对应数量的分格节点")
	pg.queue_free()

	print("== 9. 主界面接线 ==")
	var main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.gc.new_game()
	main.gc.state.age = 1
	main.gc.state.step = 0
	main.render_main()
	await process_frame
	var found_page := false
	for c in main.screen.get_children():
		for d in c.get_children():
			if d is ComicPage:
				found_page = true
	_ok(found_page, "render_main 产出了漫画页")
	var counter := [0]
	_walk_buttons(main, func(_b): counter[0] += 1)
	_ok(counter[0] >= 2, "页面上有选项按钮（%d 个）" % counter[0])
	main.queue_free()

	print("")
	if fails.is_empty():
		print("全部通过")
	else:
		print("失败 %d 项：%s" % [fails.size(), str(fails)])
	quit(1 if not fails.is_empty() else 0)


func _walk_buttons(n: Node, cb: Callable) -> void:
	if n is Button:
		cb.call(n)
	for c in n.get_children():
		_walk_buttons(c, cb)
