# 剧情路线（story）

> 分支：`story`。集成分支：`master`。动画路线：`animation`。
> 总览：[docs/two-routes.md](two-routes.md)。

## 只做这些

剧情路线负责「玩家读到什么、选什么、选了以后世界记住什么」：

| 可写 | 说明 |
| --- | --- |
| `data/game_data.json` | 随机事件、选项、结果、效果、标签、关系、记忆 |
| `data/story_opening.json` | 序章 26 个节点 + 36 个分支后续节点 |
| `data/story_arcs.json` | 同桌 / 父母 / 学业职业 / 爱好 四条联动线 |
| `data/story_cutscenes.json` | 过场的 `bg` / `cast` / `beats` 对白脚本 |
| `docs/story-*.md`、`docs/story-links.md` | 剧情说明、分支树、联动表 |
| `test/opening_smoke.gd`、`test/linkage_smoke.gd` 的数据断言 | 结构校验 |

## 不碰这些

渲染与演出属于动画路线：`scripts/cutscene_stage.gd`、`sprite_kit.gd`、`audio_fx.gd`、`story_stage.gd`、`story_room.gd`、`story_director.gd`、`ui_anim.gd`、`vfx.gd`、`assets/*`、`data/rig.json`、`data/frames.json`。

共享文件 `scripts/main.gd`、`data_loader.gd`、`game_controller.gd`、`game_state.gd`、`scenes/Main.tscn`、`project.godot` 默认只读；需要改时先在 `master` 落最小改动，再 rebase 两条路线。

## 现有剧情量

- `game_data.json`：200 个事件。
- `story_opening.json`：26 个序章节点 + 36 个分支后续节点。
- `story_arcs.json`：16 个联动事件 + 9 个后续节点，四条人生线。
- `story_cutscenes.json`：3 个过场（`OP01` 出生、`V03` 老同学来电、`V13` 病房走廊）。

## 写作约定

### 事件

```json
{
  "id": "V40",
  "title": "旧信封",
  "text": "……{choice:V01}……",
  "cond": {"minAge": 30, "maxAge": 45, "tags": ["_同桌_联系"]},
  "choices": [
    {
      "label": "拆开",
      "result": "……",
      "memory": "你拆开了那封旧信",
      "effects": {"charm": 1},
      "relations": {"同桌": 2},
      "tags": ["_同桌_旧信"],
      "next": "V40A",
      "showIf": {"relations": {"同桌": 2}},
      "requireRelations": {"同桌": 2},
      "requireHint": "需要和同桌更熟"
    }
  ],
  "weight": 26,
  "line": "common",
  "stage": "adult",
  "once": true,
  "tags": ["_同桌_旧信线"]
}
```

- `next` 串起分支；`choice.next` 优先于 `event.next`。
- `memory` 是给后续 `{choice:事件ID}` 回忆用的短句。
- `relations` 改变羁绊值（-5..10）；`requireRelations` / `requireTags` 只锁 UI，不删选项。
- `showIf` 直接隐藏选项；`once: true` 保证长线只出现一次。
- 隐藏标签统一用 `_` 开头，不会显示在顶栏。

### 过场脚本

```json
"OP05": {
  "bg": "home",
  "cast": [
    {"role": "parent", "x": 118, "y": 74},
    {"role": "lead", "x": 52, "y": 76}
  ],
  "beats": [
    {"speaker": "旁白", "face": "lead", "expr": "neutral", "text": "……"},
    {"speaker": "妈妈", "face": "parent", "expr": "neutral", "text": "……"}
  ]
}
```

只写对白与站位；`expr` 可选 `neutral / happy / sad / shock`（NPC 目前只有 base 头，写了也会退回 base）。选项仍来自事件本身，不在过场里重复。

## 接下来可以写

1. **序章过场化**：`OP02`–`OP14` 逐段配 `beats`，让出生、满月、抓周、全家福都变成对话框演出。
2. **四条联动线的过场**：`V01/V02/V04`（同桌）、`V11/V12/V14`（父母）、`V21–V24`（职业）、`V31–V34`（爱好）。
3. **中段事件扩容**：20–40 岁、40–60 岁各补 5–8 个事件，继续用 `memory` + `relations` 做跨事件回响。
4. **分支收束**：给目前单节点的分支补 1 个后续节点，让“选择 → 当天结果 → 之后”三段完整。

## 验证

```bash
godot --headless --path . --script res://test/opening_smoke.gd
godot --headless --path . --script res://test/linkage_smoke.gd
godot --headless --path . --script res://test/cutscene_smoke.gd
godot --headless --path . --script res://test/opening_ui_smoke.gd
```

数据改动至少跑前三个；改了序章/过场再接 `opening_ui_smoke`。

## 合并

- 功能分支命名：`story/<主题>`，例如 `story/prologue-cutscenes`。
- 只改本路线归属文件；共享文件改动先在 `master` 落。
- 合回 `story` 后开 PR 到 `master`，再让 `animation` rebase。
