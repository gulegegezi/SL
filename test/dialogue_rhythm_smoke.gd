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
	print("PASS: speaker cadence and interruption marker helpers")
	quit()
