extends SceneTree
## 对话框回归：星号前缀、自动换行、三行一页、进度映射、▼ 出现条件。
## 运行：godot --headless --path . --script res://test/dialogue_box_smoke.gd

const Box := preload("res://scripts/dialogue_box.gd")

var fails: Array = []


func _initialize() -> void:
	call_deferred("run")


func ok(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		print("  FAIL ", msg)
		fails.append(msg)


func run() -> void:
	print("== 1. 星号前缀 ==")
	var box = Box.new()
	box.size = Vector2(484, 150)
	root.add_child(box)
	await process_frame
	box.show_line("你回来了。饭在锅里。", "母亲")
	ok(box._lines.size() == 1, "短句一行放得下")
	ok(str(box._lines[0]).begins_with("* "), "首行以「* 」开头")
	ok(box.speaker == "母亲", "说话人写入")

	print("== 2. 进度与 ▼ ==")
	box.set_progress(0)
	ok(not box.is_line_done(), "刚开头不算读完")
	box.set_progress(box.text.length())
	ok(box.is_line_done(), "满进度算读完")
	ok(box.page_count() == 1, "短句只有一页")

	print("== 3. 自动换行与分页 ==")
	var long_text := ""
	for i in range(6):
		long_text += "这是一句用来测试自动换行与分页的长台词，需要超过三行。"
	var big = Box.new()
	big.size = Vector2(484, 150)
	root.add_child(big)
	await process_frame
	big.show_line(long_text, "")
	ok(big._lines.size() > 3, "长句换行后超过三行（%d 行）" % big._lines.size())
	ok(big.page_count() >= 2, "因此拆成多页（%d 页）" % big.page_count())
	ok(str(big._lines[0]).begins_with("* "), "首行有星号")
	ok(str(big._lines[1]).begins_with("  "), "后续行用两个空格对齐，不重复星号")

	print("== 4. 翻页映射 ==")
	var second_page_start: int = int(big._line_starts[3])
	big.set_progress(second_page_start - 1)
	ok(big.page_index() == 0, "第三行还在第一页")
	big.set_progress(second_page_start + 2)
	ok(big.page_index() == 1, "越过第三行进入第二页")
	big.set_progress(long_text.length())
	ok(big.is_line_done() and big.page_index() == big.page_count() - 1, "读完停在最后一页")

	print("== 5. 空文本与无说话人 ==")
	var empty = Box.new()
	empty.size = Vector2(484, 150)
	root.add_child(empty)
	await process_frame
	empty.show_line("", "")
	ok(empty.page_count() == 1, "空文本也有一页，不会崩")
	ok(empty.speaker == "", "旁白不带名牌")

	box.queue_free()
	big.queue_free()
	empty.queue_free()
	print("")
	print("全部通过" if fails.is_empty() else "失败 %d 项：%s" % [fails.size(), str(fails)])
	quit(0 if fails.is_empty() else 1)
