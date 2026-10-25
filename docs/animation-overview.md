# 人生漫画 · 开发逻辑与技术应用总览

> 面向：接手这个仓库的人、要改动画/场景/剧情的人、以及想复用这套做法的人。
> 记录时点：2026-10-25，`animation` 分支。规模：53 个 GDScript、约 1.2 万行、11 个场景、33 个冒烟测试。
> 细节文档见文末「文档地图」，本文只讲**为什么这么搭**和**每一层在做什么**。

---

## 1. 一句话架构

**一局人生 = 一条竖向漫画流；每一格是一个独立的 3D 小舞台；舞台里站着二维纸片人。**

数据从一份可编辑的剧情包出发，经过「语义导演」翻译成镜头与动作，再由「分镜导演」切成版式，
最后由分格自己开一个 `SubViewport` 渲染 3D 场景、把人物贴上去、加一层 HD-2D 后处理。

```
玩家选择
  → game_controller 结算数值（只结算一次）
  → life_comic_run      推进这一页的状态与随机数
  → life_comic_pages    把「作者写的镜头/动作词汇」翻译成渲染器认识的 panel spec
  → comic_director      决定这一页几格、怎么切、每格什么镜别
  → comic_page / comic_panel   版式与单格绘制
  → pixel_stage_view    每格一个 SubViewport + 正交相机 + 3D 世界
       ├ pixel_environment_3d   地台、墙、家具、灯光、雾、材质、前景
       ├ pixel_billboard_actor  二维纸片人（Sprite3D，永远朝向相机）
       ├ pixel_prop_3d          可交互道具
       └ pixel_fx_3d            浮尘/花粉/落叶/萤火、接地影、灯光呼吸
  → shaders/pixel_grade   移轴景深 + 泛光 + 冷暖分级 + 暗角 + 薄雾
```

---

## 2. 分层职责

| 层 | 模块 | 只干这件事 |
| --- | --- | --- |
| 数值 | `game_controller.gd`(717) | 属性、标签、关系、结局判定。**一次选择只结算一次** |
| 状态 | `game_state.gd` | 一局的可序列化状态（属性/标签/关系/待播队列） |
| 剧情 | `life_comic_run.gd`(232) | 读 `story_life_comic.json`，维护「已翻页 / 待选择」两份快照 |
| 翻译 | `life_comic_pages.gd`(184) | 作者的 `shot/action/prop/scene` → 渲染器的 `panel spec` |
| 语义 | `comic_performance.gd`(172) | 规则化导演：文本里的「抓住/转身/拒绝」→ 动作与表情；**显式指令优先，否定/假设/取消不动** |
| 世界 | `comic_world.gd`(317) | 地点、群像、这一格留下的物理后果（哪怕没有旁白） |
| 分镜 | `comic_director.gd`(400) | 格数、版式、镜别、提笔带过。**纯函数，不碰节点** |
| 绘制 | `comic_page.gd` / `comic_panel.gd`(217/567) | 页眉、分格、网点、旁白框、气泡、拟声词、逐格显影 |
| 舞台 | `pixel_stage_view.gd`(480) | 视口生命周期、相机、纸片人站位、道具交互、后处理接入 |
| 布景 | `pixel_environment_3d.gd`(611) | 用方块搭场景 + 灯光 + 雾 + 材质 + 前景层 |
| 存档 | `comic_archive.gd` | 二进制 Variant 落盘（含 RNG 与分格 Rect2），原子写 + `.bak` |
| 入口 | `main.gd`(1077) | 标题 / 掷骰 / 竖向漫画流 / 结局 / 图鉴 / 成就 / 书签 |

**关键分界**：`comic_director` 与 `comic_performance` 是纯逻辑（`RefCounted`，不 new 任何节点），
所以能在 `--headless` 下直接断言；一旦发现某个决定只能靠「看画面」验证，说明它不该放在这一层。

---

## 3. 数据层：剧情是怎么变成画面的

### 3.1 三份数据，各管一段

| 文件 | 大小 | 管什么 | 谁在读 |
| --- | --- | --- | --- |
| `data/story_life_comic.json` | 608 KB | 人生漫画主包：节点、选项、镜头、动作、场景、道具 | `life_comic_run` |
| `data/story_life_dialogue.json` | 31 KB | 对白/旁白的分离数据（谁在说、说什么） | `life_comic_pages` |
| `data/pixel_cg.json` | 22 KB | 特殊镜头语言（推镜、定格、远景） | `pixel_story_direction` |
| `data/game_data.json` | 205 KB | 数值侧：事件池、结局、成就、阶层、天赋 | `data_loader` |

### 3.2 一份 panel spec 长什么样

渲染器只认这个字典，作者写的东西必须先翻译成它：

```gdscript
{
  "shot": "wide|medium|close|extreme|detail",   # 镜别
  "scene": "home|office|classroom|hospital|park",
  "pixel_variant": "day|night|quiet|stage",      # 同一场景的四种调色
  "ink": "lead_adult",                           # 人物（按年龄取图集行）
  "support": "npc_friend",                       # 在场 NPC，可为 none
  "prop": "phone",                               # 可交互道具
  "presentation": "pixel3d",                     # 只有这个值才开 3D 舞台
  "action": "grab", "actor": "lead",             # 动作与执行者
  "caption": "...", "bubble": "...",             # 旁白 / 气泡
  "pixel_interaction": {...}, "pixel_cg": {...}, # 观察玩法 / 特殊镜头
}
```

**约定**：`presentation == "pixel3d"` 且 `ink` 非空 → 开 3D 舞台；否则退回 2D 房间背景。
这条判断在 `comic_panel._uses_pixel()` 里，是 2D/3D 的唯一开关。

---

## 4. 演出层：选择要「看得见」

一个选项固定分三段，缺一段就会显得选择没有后果：

| 段 | 内容 | 数据来源 |
| --- | --- | --- |
| 入场 | 角色走到目标位，说明当前事件 | `scene` + 走位 |
| 行动 | 执行选项对应的动作（抓/递/转身/拒绝） | `action` + `comic_performance` |
| 结果 | 该选项**自己的**结果文字 + 世界变化 | `result` + `comic_world` |

`comic_performance` 的规则优先级是刻意设计的：

1. 显式指令（作者写的 `action`）最高
2. 否则按动词/情绪词典推断
3. **否定句、假设句、被取消的动词不触发动作**（否则「我没有抓住」会让角色真的去抓）

同名事件的不同选项必须给出不同动作——「接受」和「拒绝」不能播同一个动作，
这是这套演出系统最容易退化的地方。

---

## 5. 渲染层：HD-2D 是怎么拼出来的

### 5.1 空间

- 每格一个 `SubViewport`，**分辨率 ≤320px 宽**（≈250×146），最近邻放大
- 正交相机（`size = 5.7`），固定机位，所以「屏幕空间移轴」就是正确的景深做法
- **最多同时 4 个活跃视口**；离屏约 0.35 秒释放，回到可见区重建
- 角色站位固定在 `(-1.1, 0, 0.8)` 与 `(1.15, 0, 0)`，布景不得遮挡这两条通道

### 5.2 人物：为什么是纸片

人物用 `Sprite3D` 加载透明全身图集，`shaded = true` 参与光照、投射阴影、最近邻采样。

选择纸片而不是体素的理由：
- 现有图集是手绘/生成的分件立绘，体素化会丢掉表情与服装细节
- 纸片可以直接被前景物件遮挡，读起来仍是「人在景里」
- 成本低：换装/换表情只是换 UV 或换图

代价是**只有有限方向的姿势**，不是八方向动画库；转身靠 `rotation.y` 的平滑插值，
所以大角度转身时会「纸片转过去」的感觉，这是当前的美术边界。

### 5.3 布景：方块 + 三种材质 + 六盏灯

场景全部是 `BoxMesh` 搭的浅地台（约 9×3.2×7），没有贴图模型。让它不显得像塑料玩具靠四件事：

1. **程序化材质**：运行时生成 32×32 可平铺细节（地砖缝 / 墙面抹灰 / 木纹），最近邻平铺
2. **分层灯光**：主光（暖，带阴影）+ 冷侧补光 + 轮廓光 + 实用光 + 副灯 + 反弹光
3. **光池**：`shaders/soft_light.gdshader` 在灯下地面叠一圈径向衰减的加法光
4. **深度雾**：`FOG_MODE_DEPTH`，室内 `0.10 / 6.0 / 12.0`、室外 `0.18 / 4.5 / 13.0`

### 5.4 后处理：`pixel_grade.gdshader`

| 效果 | 参数 | 意图 |
| --- | --- | --- |
| 倾斜移轴景深 | `dof_strength / focus_center / focus_width` | 上下虚、中间实，地台感（八方旅人） |
| 泛光 | `bloom_strength / bloom_threshold` | 只让灯具与窗户溢光，纸面不发光 |
| 冷暖分级 | `warm_cast` | 阴影推青、亮部推琥珀（风来之国） |
| 暗角 + 薄雾 | `vignette / haze` | 低对比柔光，收住画面边缘（旅行青蛙） |

每个场景一套参数，集中在 `pixel_stage_view._grade_preset()`：
家 0.38 暖 / 办公室 -0.12 冷 / 医院 -0.28 临床白 / 公园景深 0.44、泛光 0.24。

---

## 6. 存档：为什么不用 JSON

`comic_archive.gd` 用二进制 Variant 存，理由只有一条：**要原样保留类型**。

- 分格位置是 `Rect2`，随机数是 `RandomNumberGenerator.state`（64 位）
- 转 JSON 会把 `Rect2` 变成字典、把 64 位整数变成浮点，读回来这一局的「随机序列」就变了
- 写入用 `.tmp` → rename，并保留 `.bak`；版本号写在信封里

一局存的是：`state`（属性/标签/关系/待播队列）+ `comic`（本局分镜参数）+ `pages`（已翻页的 spec）。

---

## 7. 测试：33 个冒烟，分四层

| 层 | 代表 | 断言什么 |
| --- | --- | --- |
| 纯逻辑 | `comic_smoke` / `comic_performance_smoke` | 分镜数量曲线、版式槽位、语义规则 |
| 阅读器 | `life_comic_smoke` / `life_comic_ui_smoke` / `comic_reader_smoke` | 翻页、选项、结果、存档往返 |
| 渲染 | `pixel_stage_smoke` / `pixel_reader_smoke` / `pixel_motion_smoke` | 视口生命周期、人物朝向相机、像素整数缩放、离屏释放 |
| 世界/数据 | `comic_world_smoke` / `text_sync_smoke` / `engine_regression` | 布景合法性、文本同步、旧数据回归 |

```bash
godot --headless --path . --script res://test/comic_smoke.gd
godot --headless --path . --script res://test/pixel_stage_smoke.gd
```

`tools/smoke_strip.gd` 是端到端那条：从标题一路点到结局，验证「已画的页永不消失」。

---

## 8. 工具链

| 工具 | 干什么 |
| --- | --- |
| `tools/index_*.py` | 扫描图集 alpha 边界，生成 `regions.json`。**只索引，不改图** |
| `tools/extract_data.py` | 从早期 HTML 版抽数据成 JSON |
| `tools/export_ensemble.py` | 把 Godot 渲染帧编码成 GIF 预览 |
| `tools/capture_*.gd` | 各自留一张「当前长什么样」的截图，用于前后对比 |
| `tools/smoke_strip.gd` | 全流程冒烟 |

**做法上的约定**：任何美术改动都要留一张改动前后的对照图。
调参靠肉眼很容易越调越暗/越亮，`git stash` 回退三个文件再渲染一遍，才有可信的基线。

---

## 9. 关键决策记录

| 决策 | 选择 | 理由 / 代价 |
| --- | --- | --- |
| 人物形态 | 2D 纸片 + 3D 场景 | 保住立绘细节与表情；代价是转身角度受限 |
| 分镜逻辑 | 纯函数（`comic_director`） | 可无头测试；代价是不能在逻辑层直接操作节点 |
| 景深 | 屏幕空间移轴 | `hint_depth_texture` 不支持 canvas_item，Compatibility 也无 DOF；固定机位下这本来就是正确解 |
| 每格独立视口 | 是，最多 4 个 | 隔离干净、单格可独立释放；代价是每格一份光照与雾 |
| 滚动形态 | 竖向累积，不翻页替换 | 手机阅读习惯；「未活到的年份」用空白分镜占位 |
| 存档格式 | 二进制 Variant | 类型无损（`Rect2` / RNG state）；代价是不可读、不能手改 |

---

## 10. 踩坑清单（跨轮次沉淀）

1. **`SCREEN_PIXEL_SIZE` 只在 `fragment()` 里可见**。写进自定义函数会让整套 shader 编译失败，
   表现是画面完全空白，而不是报错到眼前。
2. **加法混合里 alpha 不参与运算**。径向渐变做在 alpha 上 → 整块 quad 被原样加上去，
   地面出现纯白方块。衰减必须写在 `ALBEDO`（白→黑），或在 shader 里算。
3. **雾的 `end` 必须大于最远可见面**。设 7.2 而后墙在 8 单位处，整面墙会被雾洗白。
4. **特写不能按「脚贴底」定位**。一放大头就被推出画格上方，只剩一片头发；特写要「头顶贴格顶」。
5. **本局随机不能用「格数倍率」**。0.8~1.3 的倍率会把年龄曲线压平（童年和少年都落到 2 格），
   要用 ±1 格偏移。
6. **全黑格里画角色会糊成一团墨点**。黑格只放速度线与白字。
7. **Godot 的布局溢出只有真跑才看得见**。`--quit-after 60` 无错误 ≠ 界面正常；
   长文本 Label 不开 `autowrap` 时最小宽度等于整段文字宽度，会把整页撑出视口。
8. **同一工作树多人并行时，改前先 `git log -1` / `git status`**。撞过两次：
   一次把对方的接入整段回退掉，一次重复实现了对方刚提交的粒子系统。

---

## 11. 目录导航

```
scenes/         Main(标题/掷骰/流/结局)  LifeComic(阅读器)  PixelStageLab(单格调试)
                WorldLab / EnsembleLab / PerformanceLab / ActingLab(演出调试台)
scripts/        见第 2 节分层表；以 main / comic_* / life_comic_* / pixel_* 四组命名
shaders/        pixel_grade(后处理)  soft_light(光池)  其余为 2D 特效
data/           story_life_comic(主包) story_life_dialogue(对白) pixel_cg(镜头)
                game_data(数值) + 各类索引 json
assets/         comic_city(成人像图集) ink_umdc / ink(线稿后备) portraits_v2(原始图集)
                chars(分件)  rooms(房间)  props(道具)  vfx
test/           33 个冒烟，见第 7 节
tools/          索引 / 导出 / 截图 / 端到端冒烟，见第 8 节
docs/           各类设计与复盘，见下方文档地图
```

---

## 12. 文档地图

**总览与规范**
[本文](animation-overview.md) · [动画制作指南](animation-production-guide.md) · [进度报告](progress-report.md)

**运行时与阅读器**
[人生漫画阅读器](life-comic-reader.md) · [竖向漫画流](life-strip.md) · [分镜系统](comic-panels.md) ·
[演出规则](comic-performance.md) · [世界与场景](comic-world-scenes.md) · [动作模组](motion-module.md) ·
[漫画弹窗/切镜](comic-cutin.md)

**渲染与美术**
[HD2D 导入与渲染](godot-hd2d-import.md) · [二维人物接入](hd2d-characters.md) · [像素舞台](pixel-stage-3d.md) ·
[光照与氛围](hd2d-lighting.md) · [环境优化记录](environment-hd2d.md) · [像素美术 v2](pixel-cast-v2.md) ·
[UMDC 画风](umdc-style.md) · [表情与文本同步](animation-expressions.md) · [文本同步](animation-text-sync.md)

**剧情与内容**
[故事圣经](story-bible.md) · [人生事件](story-life-events.md) · [人生漫画 Godot 化](story-life-godot.md) ·
[序章](story-opening.md) · [过场](story-cutscenes.md) · [双路线](two-routes.md) · [剧情文本全量](剧情文本-全量.md)

**场景与演示台**
[独立场景](independent-scenes.md) · [Demo Trial](demo-trial-godot.md) · [世界/群像/演出台](comic-ensemble.md) ·
[短篇人生](short-life.md) · [像素小镇](life-town.md) · [舞台](story-stage.md)

---

## 13. 复现

```bash
# 1. 导入（首次或换机）
godot --headless --editor --path . --import

# 2. 跑起来
godot --path .                      # F5：标题 → 掷骰 → 竖向漫画流

# 3. 单格调试（不写存档）
godot --path . scenes/PixelStageLab.tscn

# 4. 回归
godot --headless --path . --script res://test/comic_smoke.gd
godot --headless --path . --script res://test/pixel_stage_smoke.gd
godot --headless --path . --script res://tools/smoke_strip.gd
```

> 注意：`D:/gamelife` 下有多个工作目录，**按 F5 前确认打开的是哪一个**。
> `gamelife-anim` 是动画分支的本地工作副本；`gamelife-1.2` 是主工作区。
