# 环境与背景：HD-2D 优化记录

日期：2026-10-25。基于 `animation` 分支的 3D 像素舞台（`9c4d832`）。
参考：**风来之国**（暖灯冷影、前景遮挡）、**八方旅人**（移轴景深、聚光）、**旅行青蛙**（低对比柔光、慢速氛围）。

## 一、分镜画面怎么来的

`comic_panel.gd` 里 `presentation == "pixel3d"` 的分格会挂一个 `SubViewport`（约 250×146），
里面是 `pixel_environment_3d.gd` 建的地台、`pixel_billboard_actor.gd` 立的纸片人物，
最后经 `shaders/pixel_grade.gdshader` 做一层全屏后处理。本次只动这三处，不改人物与剧情。

## 二、后处理：`pixel_grade.gdshader`

| 效果 | 做法 | 参数 |
| --- | --- | --- |
| 倾斜移轴景深 | 以 `focus_center` 为中心画一条清晰带，偏离越远 8 点环形采样半径越大 | `dof_strength` / `focus_width` |
| 泛光 | 亮部超过阈值后单独提出来模糊一圈再叠回（暖灯的溢光） | `bloom_strength` / `bloom_threshold` |
| 冷暖分级 | 明暗做 9 级台阶；阴影推青、亮部推琥珀 | `warm_cast` |
| 暗角 | 径向压暗，给地台一个「舞台」的边界 | `vignette` |
| 底部薄雾 | 下缘按屏幕坐标混入雾色，拉开近远 | `haze` / `haze_color` |

每个场景一套参数，在 `pixel_stage_view.gd::_grade_preset()` 里：

- 家最暖（`warm_cast` 0.38）、办公室偏冷（-0.12）、医院临床白（-0.28）
- 公园景深收小（0.44）避免把人糊掉、泛光降到 0.24
- `night` 变体统一：泛光 +0.16、暖调 +0.10、暗角 +0.06、雾 +0.04

**踩过的坑**：`SCREEN_PIXEL_SIZE` 只在 `fragment()` 里可用，自定义函数里取不到，
必须当参数传进去，否则整套 shader 编译失败、画面直接不渲染。

## 三、场景：`pixel_environment_3d.gd`

### 新增的光

| 灯 | 作用 | 能量（白天/夜晚） |
| --- | --- | --- |
| `WarmRakingSun`（原有） | 主光 | 0.82 / 0.50 |
| `CoolWindowFill`（新） | 窗口方向的冷补光，压阴面但不出硬影 | 0.16 / 0.12 |
| `WarmRimLight`（新） | 从角色背后打，人物从背景里「剥」出来 | 0.20 / 0.26 |
| `WarmPracticalLight`（原有） | 灯具/路灯的实用光 | 0.55 / 1.05，范围 6.4 |

### 新增的层次

- **前景层**：贴着镜头的一层剪影。公园是近景树干 + 草丛；家是低矮叶片。
  *办公楼/教室/医院不放* —— 室内长灌木很怪；竖直布幔在这一机位会读成一根柱子。
- **地面光池**：灯下的柔光圆盘（径向渐变 + 加法混合），把光「落」在地上。
- **窗光柱**：从窗口斜射的半透明片，夜间更明显。
- **浮尘**：`CPUParticles3D`，20 来颗、7 秒生命、几乎不动的漂移。
- **渐变天空**：背景从纯色换成 `ProceduralSkyMaterial`，地台浮在一个有方向的颜色里，而不是黑底。
- **墙角压暗**：贴墙根的一条暗带，让墙和地分开。

**踩过的坑**：加法混合里 **alpha 不参与运算**。径向渐变如果做在 alpha 上，
整块 quad 会被原样加上去 —— 第一次渲染时地面出现了两块纯白方块。
渐变必须做在 RGB 上（白→黑），黑色等于不添加。

## 四、验证

```bash
godot --headless --path . --script res://test/pixel_stage_smoke.gd
godot --headless --path . --script res://test/pixel_reader_smoke.gd
godot --headless --path . --script res://test/life_comic_ui_smoke.gd
godot --headless --path . --script res://test/comic_smoke.gd
```

四个全部通过；主场景 `--quit-after 90` 零报错。
前后对照图见工作区 `库检查/环境对比.png`（同一分格、同一随机种子，左原样 / 右优化后）。

## 五、还没做的

- 人物只有有限方向的姿势图，没有八方向动画；轮廓光是靠灯而不是描边 shader。
- 景深是屏幕空间近似，没有按 3D 深度取样——所以「远处的树」和「近处的树」虚化程度一样。
- 场景仍是方块搭建（BoxMesh），没有贴图材质。要做到《风来之国》那种手绘厚度，需要给地台加 UV 贴图与法线。

---

## 六、第二轮：材质细节 / 深度雾 / 柔光着色器

### 材质
`_detail_texture()` 在运行时用 `Image.create(32,32)` 生成三种可平铺的灰度细节，最近邻采样：

| 种类 | 图案 | 用在哪 |
| --- | --- | --- |
| `floor` | 16px 砖缝 + 轻微噪点 | 地砖（MultiMesh 的 vertex color 负责染色） |
| `wall` | 竖向抹灰痕（每 8px 一道） | 背墙、侧墙 |
| `wood` | 横向木纹（每 6px）+ 偶发深色结 | 桌面 |

不引入二进制资源，随工程走；`_material()` 按 `颜色:辉光:材质` 缓存，不会重复建材质。

### 深度雾（真·距离线索）
`Environment.fog_mode = FOG_MODE_DEPTH`，室内 `density 0.10 / begin 6.0 / end 12.0`，
室外 `0.18 / 4.5 / 13.0`。

**坑**：一开始把 `end` 设成 7.2，而后墙离相机大约 8 个单位 —— 整面墙被雾洗成一片白，
看起来像窗户过曝。雾的 `end` 必须大于「最远的可见表面」，否则它会把场景吃掉。

### 柔光着色器 `shaders/soft_light.gdshader`
地面光池、窗光柱、浮尘共用一个 spatial shader：`shape=0` 用 `length(uv*2-1)` 算径向衰减，
`shape=1` 用 UV.y 算竖向衰减，`blend_add` 叠加。

**为什么换成着色器**：`GradientTexture2D` 配 `BLEND_MODE_ADD` 时，整块 quad 会被原样加上去，
地面上出现两块纯白方块；换成着色器后衰减写在 `ALBEDO` 里，黑色自然等于不添加。

### 关于「真 3D 景深」
试过在 canvas_item 后处理里取深度：`hint_depth_texture` **不支持 canvas_item shader**，
编译直接失败。而 Compatibility 渲染器没有内置 DOF。
所以景深保持**屏幕空间移轴**——这恰好也是《八方旅人》的做法（固定机位 + 竖向模糊带），
真正的距离感改由上面的深度雾补上。

### 与并行提交的去重
`699c89a`（多光源分层 + 体积光柱 + 空气粒子 + 接地影）已经提供 `pixel_fx_3d.gd`
（`dust/pollen/leaves/fireflies`、`contact_shadow`、`breathe`）。
本次删掉了自己写的浮尘，统一走 `Fx.*`；光池、材质、雾、前景、分级预设不重叠，保留。

另：`pixel_stage_smoke` 里「角色不能有 MeshInstance3D」这条断言已被接地影打破，
改成排除 `ContactShadow` 之后再判空 —— 不变量（没有体素身体）仍然成立。
