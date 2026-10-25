# gamelife · 人生漫画

一个把「一局人生」画成**竖向漫画流**的 Godot 4.7 项目：
每一格是一个独立的 3D 像素小舞台，舞台里站着二维纸片人，镜头与光照按 HD-2D 的思路处理。

- **技术总览（先读这个）** → [docs/animation-overview.md](docs/animation-overview.md)
- 运行形态：标题 → 掷骰决定出身 → 竖向漫画流（未活到的年份是空白分镜）→ 结局 / 图鉴 / 成就
- 视觉参考：风来之国（暖灯冷影、前景遮挡）、八方旅人（移轴景深、聚光）、旅行青蛙（低对比柔光）

## 跑起来

```bash
godot --headless --editor --path . --import   # 首次或换机，先导入资源
godot --path .                                # F5
```

单格调试（不写存档）：

```bash
godot --path . scenes/PixelStageLab.tscn
```

## 回归

```bash
godot --headless --path . --script res://test/comic_smoke.gd        # 分镜逻辑
godot --headless --path . --script res://test/pixel_stage_smoke.gd  # 3D 舞台
godot --headless --path . --script res://tools/smoke_strip.gd       # 一路点到结局
```

## 分支

| 分支 | 用途 |
| --- | --- |
| `master` | 主分支，与 `animation` 保持同步 |
| `animation` | 动画/渲染相关开发，HD-2D 舞台与演出系统 |
| `story` | 剧情数据与文本 |
| `feat/life-comic-reader` | 竖向漫画阅读器 |

## 目录

```
scenes/    Main / LifeComic / 各调试台
scripts/   main、comic_*（分镜）、life_comic_*（剧情运行时）、pixel_*（3D 舞台）
shaders/   pixel_grade（后处理）、soft_light（光池）
data/      story_life_comic（剧情主包）、game_data（数值）、pixel_cg（镜头）
assets/    comic_city / ink_umdc / portraits_v2 / chars / rooms / props
test/      33 个冒烟测试
tools/     图集索引、导出、截图、端到端冒烟
docs/      设计与复盘文档（索引见技术总览末尾）
```
