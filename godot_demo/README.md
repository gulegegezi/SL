# gamelife demo · Godot 项目

这是从 SL 仓库生成的一个**独立 Godot 项目**，只包含「经典 Demo：序章 + 人生池」需要的场景、脚本、数据和素材。

## 运行

1. 用 Godot 4.3+ 打开本目录的 `project.godot`。
2. 按 **F5**（或右上角运行）启动，主场景是 `scenes/DemoTrial.tscn`。
3. 也可以直接打开 `scenes/DemoTrial.tscn` 按 **F6**。

## 操作

- 点击对话框 / 空格 / 回车：推进对话、补全文字
- 出现选项时：上下方向键移动红心，回车确认；也可直接点击选项
- 左上角 **重开**：重新播一遍

## 内容

- 序章：出生 → 满月 → 第一个词 → 第一步 → 抓周，按选项分支
- 人生池：序章后随机抽事件，年龄 +1～2 岁，最多 34 幕
- 结算：综合分 + 评级 + 「再玩一次」
- 表现：Undertale / Deltarune 式旁白（`*` 开头、无名字）、逐字打字、红心选择、camera 推近、letterbox、闪白/闪黑、选择后的角色反应

## 数据

- `data/story_opening.json`：序章分支
- `data/game_data.json`：人生池事件
- `data/story_cutscenes.json`：过场对白、镜头与选择反应
- `data/story_arcs.json`：联动剧本（随 DataLoader 一起加载）

## 验证

```bash
godot --headless --path . --script res://test/demo_trial_smoke.gd
```

该测试会从 `OP01` 开始，走完序章与人生池，直到结算。

截图（会打开窗口跑一遍，产物写到传入的目录）：

```bash
godot --path . --script res://tools/capture_demo.gd -- <输出目录>
```

它会依次截下：开场对白、选项、选择结果、人生池、结果页、结算页。

## 说明

这是生成时的快照，不是主仓库的替代。要修改剧情/动画，仍建议在 SL 主仓库里改，然后重新生成本目录。
