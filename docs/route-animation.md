# 动画路线（animation）

> 分支：`animation`。集成分支：`master`。剧情路线：`story`。
> 总览：[docs/two-routes.md](two-routes.md)。

## 只做这些

动画路线负责「玩家看到什么、怎么动、怎么被演出来」：

| 可写 | 说明 |
| --- | --- |
| `scripts/cutscene_stage.gd` | 过场渲染器：背景、角色、对话框、逐字、心形选择 |
| `scripts/sprite_kit.gd` | 分件立绘拼装、年龄阶段、表情头 |
| `scripts/audio_fx.gd` | 运行时合成 blip / confirm |
| `scripts/story_stage.gd` / `story_room.gd` / `story_director.gd` | 旧版三镜头小剧场与布景 |
| `scripts/ui_anim.gd` / `vfx.gd` / `vfx_preview.gd` | 界面动效、VFX、预览台 |
| `data/rig.json` / `data/frames.json` | 部件锚点、逐帧动作、表情表、fps |
| `assets/chars` / `scenes` / `props` / `vfx` | 立绘、场景、家具、特效 PNG |
| 动画/演出说明文档 | 本文件、镜头与动作的补充说明 |
| `test/cutscene_smoke.gd` 渲染断言、`room_sequence_smoke`、`story_smoke`、`ui_progress_smoke` | 演出回归 |

## 不碰这些

剧情内容属于剧情路线：`data/game_data.json`、`data/story_opening.json`、`data/story_arcs.json` 的事件/选项/分支，`docs/story-*.md` 与 `docs/story-links.md`。

`data/story_cutscenes.json` 是**共享契约**：对白、站位、说话人由剧情路线写；动画路线只允许**追加可选字段**（如 `move` / `emote` / `camera` / `wait`），且必须保证旧数据不写这些字段也能正常播放。

共享文件 `scripts/main.gd`、`data_loader.gd`、`game_controller.gd`、`game_state.gd`、`scenes/Main.tscn`、`project.godot` 默认只读；需要改时先在 `master` 落最小改动，再 rebase 两条路线。

## 现有能力

- 24×36 分件立绘：`legL/legR/torso/armL/armR/head`，同一画布叠加；`data/rig.json` 记录锚点。
- **17 种表情**：10 个基础 + 7 个夸张漫画面（smug / panic / cry / dead / love / rage / shock），NPC 也有全套。
- 逐帧动作：`idle`（3 帧，支持 10 表情）、`walk / wave`（4 帧）、`raise / sit`（3 帧），`data/frames.json` 记录数量与 fps。
- Godot 过场：背景贴图 + 拼装角色 + 底部对话框（名字/立绘/逐字）+ 合成 blip + 心形光标选择 + 锁定项灰显。
- **逐帧动作已接进过场**：`CutsceneStage` 按 `frames.json` 的 fps 播 `idle/walk/wave/raise/sit`，走路带真实位移。
- **文本驱动演出**：`beat_director.gd` 从句子里读动作/表情/天气，显式字段优先；详见 [animation-text-sync.md](animation-text-sync.md)。
- **夸张漫画面**：rage/shock 等表情自带冲击帧（白闪 + 集中线 + 抖屏 + 拟声词 + 反应大脸）；详见 [animation-expressions.md](animation-expressions.md)。
- **镜头**：按说话人推近/拉远，0.15s 缓动；旁白拉远、情绪句推近。
- **天气层**：台词里的雨/雪/风/夜会画在场景上，「雨停/放晴」收掉。
- `docs/demo-trial.html` 已验证镜头推拉、上下黑边、黑闪、反应前静默、结果逐字。

## 还缺什么

1. ~~逐帧动作~~ 已完成：`idle/walk/wave/raise/sit` 按 fps 播放。
2. ~~表情与眨眼~~ 已完成：17 表情 + 4.2 秒眨眼，NPC 也有表情头。
3. ~~镜头~~ 已完成推近/拉远；黑边、黑闪、静默节拍仍只在 HTML demo 里。
4. NPC 只有 base 头，没有表情变体。
5. 音频只有 blip/confirm，没有 BGM、脚步、选择音。
6. 没有场景切换（淡入淡出/iris）。

## 接下来可以做

1. **逐帧动作**：读 `data/frames.json`，在 `CutsceneStage` 里按 fps 播 `idle/walk/wave/raise/sit`；`idle` 支持 10 表情。
2. **镜头系统**：给 beat 增加可选 `camera`（push/pull/pan）、`letterbox`、`flash`、`shake`；旧数据缺省不动。
3. **表情过渡**：眨眼（`blink` 帧）、说话者表情切换、情绪变化时轻微停顿。
4. **NPC 表情**：给 6 个 NPC 生成表情头，或做调色板/五官替换。
5. **可选 beat 指令**：`move`（走到 x/y）、`emote`（换表情）、`wait`（停顿）、`sfx`；与剧情路线约定为**追加字段**。
6. **音频**：BGM 循环、脚步、选择/确认、打字音随机音高。
7. **转场**：黑场淡入淡出、iris、房间切换。

## 验证

```bash
godot --headless --path . --script res://test/cutscene_smoke.gd
godot --headless --path . --script res://test/room_sequence_smoke.gd
godot --headless --path . --script res://test/story_smoke.gd
godot --headless --path . --script res://test/ui_progress_smoke.gd
godot --headless --path . --script res://test/world_smoke.gd
```

动 `CutsceneStage` 后至少跑 `cutscene_smoke` + `ui_progress_smoke`；动旧版小剧场再跑 `room_sequence_smoke`。

## 合并

- 功能分支命名：`animation/<主题>`，例如 `animation/frame-actions`、`animation/camera-timeline`。
- 只改本路线归属文件；共享文件改动先在 `master` 落。
- 合回 `animation` 后开 PR 到 `master`，再让 `story` rebase。
- 新增 beat 字段必须向后兼容：旧 `story_cutscenes.json` 不写新字段也要能播。
