# 两条制作路线：剧情 / 动画

从当前整合版 `master` 拉出两条长期分支，之后分别制作，再定期并回 `master`。

```text
master（整合基线，必须始终可运行）
  ├── story       剧情路线：事件、选项、分支树、对白、过场脚本
  └── animation   动画路线：立绘、分件/逐帧、镜头、对话框、音效、演出器
```

- 剧情分支：`story`（路线说明见 [`docs/route-story.md`](route-story.md)）
- 动画分支：`animation`（路线说明见 [`docs/route-animation.md`](route-animation.md)）

## 文件归属

| 范围 | 剧情路线 `story` | 动画路线 `animation` | 整合 `master` |
| --- | --- | --- | --- |
| `data/game_data.json` 事件与选项 | 主写 | 只读 | 合并 |
| `data/story_opening.json` 序章分支树 | 主写 | 只读 | 合并 |
| `data/story_arcs.json` 联动剧本 | 主写 | 只读 | 合并 |
| `data/story_cutscenes.json` 对白/beats/cast | 主写 | 读 schema、可提兼容性改动 | 合并 |
| `data/rig.json` / `data/frames.json` | 只读 | 主写 | 合并 |
| `scripts/cutscene_stage.gd` 过场渲染 | 只读 | 主写 | 合并 |
| `scripts/sprite_kit.gd` / `audio_fx.gd` | 只读 | 主写 | 合并 |
| `scripts/story_stage.gd` / `story_room.gd` / `story_director.gd` | 只读 | 主写 | 合并 |
| `scripts/ui_anim.gd` / `vfx.gd` / `vfx_preview.gd` | 只读 | 主写 | 合并 |
| `assets/chars` / `scenes` / `props` / `vfx` | 只读 | 主写 | 合并 |
| `docs/story-*.md` / `docs/story-links.md` | 主写 | 只读 | 合并 |
| `docs/*.md` 动画/演出说明 | 只读 | 主写 | 合并 |
| `scripts/main.gd` / `data_loader.gd` / `game_controller.gd` / `game_state.gd` | 协调后改 | 协调后改 | 合并 |
| `scenes/Main.tscn` / `project.godot` | 协调后改 | 协调后改 | 合并 |

**共享文件**（`main.gd` / `data_loader.gd` / `game_controller.gd` / `game_state.gd` / `Main.tscn` / `project.godot`）默认不在路线分支里直接改；需要改时先在 `master` 落一个最小改动，再 rebase 两条路线，避免长期分叉。

## 工作流

1. 从路线分支拉功能分支：
   - `story/prologue-cutscenes`、`story/arc-v15-v20` …
   - `animation/camera-timeline`、`animation/walk-frames` …
2. 功能分支只改本路线归属的文件。
3. 本地跑该路线的验证命令（见两份 route 文档）。
4. 合回路线分支，再开 PR 合回 `master`。
5. `master` 合完后，把 `story` / `animation` rebase 到最新 `master`，保持两条路线同源。

## 验证

两条路线都要能跑完整回归：

```bash
godot --headless --path . --script res://test/opening_smoke.gd
godot --headless --path . --script res://test/opening_ui_smoke.gd
godot --headless --path . --script res://test/linkage_smoke.gd
godot --headless --path . --script res://test/cutscene_smoke.gd
godot --headless --path . --script res://test/story_smoke.gd
godot --headless --path . --script res://test/room_sequence_smoke.gd
godot --headless --path . --script res://test/ui_progress_smoke.gd
godot --headless --path . --script res://test/world_smoke.gd
```

`story` 至少要过 `opening_smoke` / `linkage_smoke` / `cutscene_smoke` 的数据断言；`animation` 至少要过 `cutscene_smoke` / `room_sequence_smoke` / `story_smoke` / `ui_progress_smoke`。
