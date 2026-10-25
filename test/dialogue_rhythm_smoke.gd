extends SceneTree
## 对话节奏回归：角色语速表 + 被打断的句尾标记。

const ComicPanel := preload("res://scripts/comic_panel.gd")


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	assert(ComicPanel.cadence_for("爸爸") > ComicPanel.cadence_for("你"), "爸爸应比主角慢")
	assert(ComicPanel.cadence_for("班长") > ComicPanel.cadence_for("同桌"), "班长应比同桌慢")
	assert(is_equal_approx(ComicPanel.cadence_for("路人甲"), 1.0), "未知角色用 1.0")
	assert(ComicPanel.interrupted("她可能以为……"), "省略号应判为被打断")
	assert(ComicPanel.interrupted("等等——"), "破折号应判为被打断")
	assert(not ComicPanel.interrupted("好，听他的。"), "完整句不应判为被打断")
	# 情绪叠加：生气更快，哭更慢
	assert(ComicPanel.cadence_for("爸爸", "angry") < ComicPanel.cadence_for("爸爸"), "生气应更快")
	assert(ComicPanel.cadence_for("爸爸", "cry") > ComicPanel.cadence_for("爸爸"), "哭应更慢")
	# 切角：4 点 → 5 点，且右下角被切掉
	var rect := Rect2(0, 0, 100, 40)
	assert(ComicPanel.box_polygon(rect, 0.0).size() == 4, "完整框应是四角")
	var cut := ComicPanel.box_polygon(rect, 16.0)
	assert(cut.size() == 5, "切角框应是五角")
	assert(cut[2].y < rect.end.y and cut[3].x < rect.end.x, "切角位置不对")
	# 标点停顿：破折号 > 省略号 > 逗号 > 普通字
	assert(ComicPanel.char_delay("—") > ComicPanel.char_delay("…"), "破折号停顿应最长")
	assert(ComicPanel.char_delay("…") > ComicPanel.char_delay("，"), "省略号应长于逗号")
	assert(ComicPanel.char_delay("，") > ComicPanel.char_delay("字"), "逗号应长于普通字")
	# 句内加速：ramp 越小越快
	assert(ComicPanel.char_delay("字", 0.8) < ComicPanel.char_delay("字", 1.0), "加速后单字延迟应更短")
	print("PASS: speaker cadence and interruption marker helpers")
	quit()
