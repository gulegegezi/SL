# 对话框（Undertale 式）

`scripts/dialogue_box.gd`：分幕对话（`scene_conversation.gd`）里承载台词的对话框。
只做「长什么样」，逐字进度由单格传入 —— 这样不会和已有的打字机各跑一套计时。

## 从《传说之下》借来的五条约定

调研来源：Undertale 对话框的公开拆解资料（文本框尺寸、边框像素、行数上限、星号前缀规则）。

| 约定 | 本项目的落地 |
| --- | --- |
| 纯黑底 + **直角**白框，无圆角无阴影 | `draw_rect` 实心黑 + 3px 白描边 |
| 旁白与台词以 `* ` 起行 | 首行 `* `，换行后的行用两个空格对齐，不重复星号 |
| 一页最多 **3 行**，超了分页 | `LINES_PER_PAGE = 3`，`page_count()` 可查 |
| 逐字显示，每字一声 blip | 复用字音库；进度来自 `panel.visible_characters` |
| 打完一页右下角闪 `▼` | `is_line_done()` 为真时按 1.1s 周期闪 |
| 说话人在框左上沿的名牌 | `speaker` 非空时画一个小牌，旁白不显示 |

**没有照搬的**：字体（原作是 8bitoperator JVE，中文没法用，改用系统黑体）、
立绘位置（我们的角色是全身纸片人，塞进方框反而看不清，先留空接口）。

## 接口

```gdscript
var box := DialogueBox.new()
box.show_line("你回来了。饭在锅里。", "母亲")   # 第二参数留空 = 旁白
box.set_progress(panel.visible_characters)      # 每帧喂进度
box.is_line_done()                              # 整句读完
box._lines / page_count() / page_index()        # 排版结果，便于测试
```

## 接了哪些地方

`scene_conversation.gd`：

- 建框：`stage_area` 底部，高度 156px，`PRESET_BOTTOM_WIDE`
- 单格设 `hide_text = true`，画面只剩场景与人物，文字全交给框
- 每帧 `box.set_progress(panel.visible_characters)`
- 单格后添加会盖住框，所以在 `show_line()` 里 `box.move_to_front()`
- 点击画面 / 空格仍然走原来的 `advance()`，翻页与「显示整句」语义不变

## 两个坑

1. **`show_line()` 时控件宽度还是 0**：如果这时排版，每两个字就会被断成一行。
   现在 `_draw()` 里检测宽度变化后重排一次。
2. **`* ` 是两个装饰字符，不计入原文进度**：直接按 `visible_characters` 截断会少显示两个字。
   取字符数时要先减掉行首缩进，再 +2 补回来。

## 验证

```bash
godot --headless --path . --script res://test/dialogue_box_smoke.gd
```

16 条断言：星号前缀、自动换行、三行一页、翻页映射、读完判定、空文本与旁白不显示名牌。
