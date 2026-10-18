# Undertale 式剧情过场时间轴

> 数据文件：[`data/story_cutscenes.json`](../data/story_cutscenes.json)。
> 渲染：[`scripts/cutscene_stage.gd`](../scripts/cutscene_stage.gd) + [`scripts/pixel_cast.gd`](../scripts/pixel_cast.gd) + [`scripts/sprite_kit.gd`](../scripts/sprite_kit.gd) + [`scripts/audio_fx.gd`](../scripts/audio_fx.gd)。
> 素材：[`assets/portraits_v2`](../assets/portraits_v2)、[`data/cast.json`](../data/cast.json)、[`assets/rooms`](../assets/rooms)。
> 剧情数据仍在 GitHub 仓库 **SL**（`gulegegezi/SL`）。
> 叙事总纲与人物小传见 [story-bible.md](story-bible.md)；三岁前试玩见 [story-demo-pre3.md](story-demo-pre3.md)；经典 Demo 的 Godot 移植见 [demo-trial-godot.md](demo-trial-godot.md)。

![过场首屏：序章·出生](story-cutscene-preview.png)

![过场动画：V03 老同学走进公园并挥手](story-animation-preview.png)

## 这是什么

给事件加一层 **Undertale 式过场**：不再是「文字卡 + 按钮 + 三镜头小剧场」，而是

- 房间图集背景（`PixelCast.room`，160×120 逻辑画布）；
- **SL 库最新 `pixel_cast` 角色图集**：7 个阶段（婴儿/幼年/学龄/少年/成年/中年/老年）+ 6 个 NPC，每个角色 4 帧（静止 / 两帧走 / 说话抬手）；
- 角色可以按 `from` / `walk_time` 从场外走进来，走到 `x/y` 后自动切回 `idle`；
- `action` 语义映射到最新 4 帧素材：`walk` → 走路循环，`wave` / `raise` → 说话抬手帧，`idle` / `sit` → 静止；
- 底部黑框对话框：说话人名字、立绘槽、逐字打字 + 合成「滴滴」音；
- 对白结束后的**对话框内选项**，红色心形光标上下移动、回车/点击确认；
- 关系不够的选项会灰色显示并带「需要和…更亲近」提示，无法选中。

> 角色已从旧的 `assets/chars` 分件/逐帧路径切到 GitHub 最新提交的 `pixel_cast` 图集（`assets/portraits_v2` + `data/cast.json`）。旧 `frames.json` 的 10 表情帧保留在仓库里作为素材储备，但当前过场不再使用。

## 剧情 × 动画：beat 里的动作字段

`data/story_cutscenes.json` 的对白是剧情，`scripts/pixel_cast.gd` 的 4 帧角色图集是动画。两者通过 beat 字段接起来：

| 字段 | 写在哪 | 作用 |
| --- | --- | --- |
| `action` | `beat` 或 `cast[]` | `idle / walk / wave / raise / sit`；写给 `target` 角色，保持到下一次显式切换 |
| `target` | `beat` | 执行动作的角色，默认等于 `face` |
| `face` | `beat` | 对话框立绘是谁（`lead` 或 NPC 角色） |
| `expr` | `beat` | 语义提示（normal / happy / sad / angry / surprise / scared / determined / shy / hurt / blink）；最新素材只有静止/抬手两种立绘，非 normal 会优先用抬手帧 |
| `from` | `cast[]` | 入场起点 `[x, y]`；有此字段时角色边走边播走路帧 |
| `walk_time` | `cast[]` | 入场时长，默认 1.0 秒 |
| `cast[].action` / `cast[].face` | `cast[]` | 该角色的默认动作与表情 |

渲染时由 `PixelCast.frame_index()` 在 4 帧里换帧：走路 `0→1→0→2`，说话抬手第 3 帧，静止第 0 帧。最新素材没有 `wave`/`raise`/`sit` 专用帧，所以 `wave`/`raise` 复用抬手帧，`sit` 退回静止；这些字段保留语义，等后续补专用素材时不需要改剧情。

例子：V03 里老同学从画面右侧走进来，说完“是我。……我回来了”时挥手（抬手帧），下一句再收回 idle。

```json
{"role": "friend", "x": 118, "y": 62, "from": [152, 62], "walk_time": 1.1, "action": "idle"}
{"speaker": "老同学", "face": "friend", "action": "wave", "target": "friend", "text": "是我。……我回来了，想见一面。"}
{"speaker": "你", "face": "lead", "expr": "happy", "action": "idle", "target": "friend", "text": "你这些年，到底去哪儿了？"}
```

## 场景缩放与镜头

过场现在把**背景和人物放进同一个 camera 变换**，只缩放一次，所以人物不会和背景各缩各的：

- 逻辑场景是 `160×90`，房间图集从 `512×512` 裁成 `512×288` 的 16:9 视野，再整体缩放到窗口。
- 人物脚底默认落在 `y = 62`（`data/rig.json` 的 `floor_y`），`PixelCast.draw_actor` 以脚底为锚点，人物高度 `36`（婴儿 `24`）与场景同倍缩放。
- 每个过场可选 `camera`：`{"zoom": 1.06, "x": 80, "y": 44}`。`zoom` 是镜头推拉，`x/y` 是镜头聚焦的场景坐标；默认 `zoom=1.0`、聚焦画面中心。
- 人物脚下有一层 3 行渐隐软阴影，随 camera 一起缩放，用来把角色「按」在地面上。
- 如果换了一张房间图，只需要根据图的墙脚线调 `camera.y` / 人物 `y`，或调 `zoom` 取景；不用改代码。

## 现在接入了哪些过场

| 事件 | 场景 | 出场 |
| --- | --- | --- |
| `OP01` 序章·出生 | `hospital` | 主角（婴儿）+ 妈妈 |
| `OP05` 满月酒 | `home` | 主角（婴儿）+ 妈妈 |
| `OP09` 第一个词 | `home` | 主角 + 妈妈 / 爸爸 |
| `OP10` 第一步 | `home` | 主角 + 妈妈 / 爸爸 |
| `OP11` 抓周 | `home` | 主角 + 妈妈 |
| `C33` 一岁半的午后 | `home` | 主角（婴儿） |
| `C34` 两岁的雨 | `home` | 主角（婴儿） |
| `V03` 老同学来电 | `park` | 主角 + 老同学 |
| `V13` 病房走廊 | `hospital` | 主角 + 爸爸 |

前三岁相关的 7 个过场已经串成可玩试玩：[story-demo-pre3.md](story-demo-pre3.md)。

## 剧本全文

### OP01 · 出生

**场景**：医院，凌晨四点，雨刚停。灯管嗡嗡响。
**出场**：主角（婴儿，`lead_child`）在左，妈妈（`npc_parent`）在右。
**背景**：`hospital`。

> **旁白**（主角 neutral）：凌晨四点，雨刚停。产房的灯管嗡嗡响，你被一双戴橡胶手套的手倒提着，拍了两下脚心。
>
> **你**（shock）：……
>
> **妈妈**：看，是个健康的宝宝。

**选择**：

1. 放声大哭，把屋顶掀了
2. 安静地睁眼，先观察一下
3. 一把抓住护士的手指

**演出提示**：旁白时主角是 `normal`；切到「你」时换 `surprise`；妈妈说话时立绘切到 NPC 妈妈，并在最后一句做 `wave`。三个选择分别走向 `OP02` / `OP03` / `OP04`，序章内年龄不增长。

---

### V03 · 老同学来电

**场景**：公园，傍晚。手机响了三次。
**出场**：主角（成年，`lead_adult`）在左；老同学（`npc_friend`）从右侧 `from [152, 74]` 走进来，`walk_time 1.1`，停在 `118, 74`。
**背景**：`park`。

> **旁白**（主角 `normal`）：手机响了三次，一个陌生号码。
>
> **你**（`surprise`）：喂？
>
> **老同学**（`action: wave`）：是我。……我回来了，想见一面。
>
> **你**（`happy`，`action: idle`，`target: friend`）：你这些年，到底去哪儿了？

**选择**：

1. 去见他
2. 说最近很忙，改天
3. 问他：你当年为什么走（需要和同桌更熟）

**演出提示**：选项 3 是锁定项，关系不足时灰显「需要和同桌更熟」。选择后分别进入 `V03A` / `V03B` / `V03C`，再由它们汇入 `V04`。这条过场是同桌线的情绪转折点：前三句是试探，最后一句才露出真正的在意。

---

### V13 · 病房走廊

**场景**：医院，凌晨两点。走廊很亮。
**出场**：主角（成年，`lead_adult`）在左，爸爸（`npc_parent`）在右。
**背景**：`hospital`。

> **旁白**（主角 `blink`）：凌晨两点，医院的走廊很亮，亮得人睡不着。
>
> **爸爸**（`action: raise`）：没事，你回去睡吧。
>
> **你**（`sad`，`action: idle`，`target: parent`）：爸，你先回去吧，今晚我守着。

**选择**：

1. 留下来陪床（需要和妈妈更亲近）
2. 去缴费，把手续办完
3. 说：我明天还要上班

**演出提示**：爸爸的台词越轻，越要留停顿；他抬手（`raise`）之后，下一句再收回 `idle`。主角的第一句用 `blink`（走廊太亮），最后一句换 `sad`。选项 1 是锁定项；关系不足时玩家会看到「需要和妈妈更亲近」，这本身就是这场戏的一部分。

## 接下来可以写的过场

- `OP05` 满月酒：一桌亲戚、红包、筷子；适合让 NPC 妈妈/二姨轮流出画。
- `OP11` 抓周：六样东西摆在桌上，适合做「主角走向桌子」的走位。
- `V11` 家长会之后：妈妈拿着成绩单，一路沉默；适合用路灯/楼道灯做镜头。
- `V21` 分科表：笔尖悬在文理两栏之间；适合给一个很长的停顿。
- `V31` 排练室：推开门，看见落灰的钢琴；适合先给空镜，再让主角入画。

## 数据格式

```json
{
  "version": 2,
  "cutscenes": {
    "OP01": {
      "bg": "hospital",
      "cast": [
        {"role": "parent", "x": 118, "y": 74, "action": "idle", "face": "normal"},
        {"role": "lead", "x": 52, "y": 76, "action": "idle", "face": "normal"}
      ],
      "beats": [
        {"speaker": "旁白", "face": "lead", "expr": "normal", "text": "……"},
        {"speaker": "你", "face": "lead", "expr": "surprise", "text": "……"},
        {"speaker": "妈妈", "face": "parent", "expr": "normal", "action": "wave", "target": "parent", "text": "……"}
      ]
    }
  }
}
```

- `bg`：`home / classroom / hospital / office / park / grave / bedroom`。
- `cast[].role`：`lead` 或 `boss / friend / mate / parent / partner / teacher`；`x/y` 是 160×120 逻辑坐标里的脚底位置。
- `cast[]` 可选 `from: [x, y]` 与 `walk_time`，角色会从场外走进 `x/y`；可选默认 `action` / `face`。
- `beats[].face`：对话框立绘是谁；`lead` 按年龄取阶段，`expr` 是语义提示（最新素材只有静止/抬手两种立绘）。
- `beats[].action` + `target`：让某个角色做 `idle / walk / wave / raise / sit`，动作保持到下一次显式切换；具体映射见上表。
- **选项不写在这里**：选项沿用事件自己的 `choices`，`main.gd` 会按 `showIf` 过滤、按 `requireRelations/requireTags` 标灰锁定，选择后仍走 `gc.choose` 结算。

## 素材与角色拼装

- 角色使用 GitHub 最新提交的 [`pixel_cast.gd`](../scripts/pixel_cast.gd) + [`assets/portraits_v2`](../assets/portraits_v2) 图集；`data/cast.json` 记录 7 个阶段 + 6 个 NPC，每人 4 帧。
- `assets/cast/*.png` 是同一批帧的独立导出，方便直接查看；`regions.json` 记录每帧在 atlas 里的区域。
- 姿态只有 4 帧：静止、两种迈步、说话抬手。`pixel_cast.gd` 用 `0→1→0→2` 播走路、`0↔3` 播说话；没有 `wave/raise/sit` 专用帧。
- 对话框立绘直接裁角色帧上半部约 46%，与场上角色同一套图，不会出现两套画风。
- 旧的 [`data/frames.json`](../data/frames.json) + `assets/chars` 10 表情素材保留在仓库里，作为后续补表情/专用动作的储备；当前过场不走这条路径。
- 旧的 `SpriteKit.compose()` 分件合成继续作为兜底保留。
- 音频是运行时合成的方波/正弦短音（`audio_fx.gd`），无外部音频文件依赖。

## 怎么新增一个过场

1. 在 `data/story_cutscenes.json` 的 `cutscenes` 下加一个以事件 id 为键的条目。
2. 事件在随机池/序章/联动里正常触发；`render_main()` 发现 `cutscene_for(id)` 非空就切到过场。
3. 没写过场的事件继续走原来的「文字卡 + 三镜头小剧场」，互不影响。

## 验证

```bash
godot --headless --path . --script res://test/animation_link_smoke.gd
godot --headless --path . --script res://test/cutscene_smoke.gd
godot --headless --path . --script res://test/opening_ui_smoke.gd
godot --headless --path . --script res://test/linkage_smoke.gd
godot --headless --path . --script res://test/opening_smoke.gd
godot --headless --path . --script res://test/story_smoke.gd
godot --headless --path . --script res://test/room_sequence_smoke.gd
godot --headless --path . --script res://test/ui_progress_smoke.gd
godot --headless --path . --script res://test/world_smoke.gd
```
