# 主角与 NPC 的统一画风和全身演出

2026-10-22，`animation` 分支。F5 主游戏默认采用本次演出。

## 画风

将六位 NPC 的旧 24×36 大头角色替换为与主角相近的动漫全身人物：相近头身比、深青线条、服装阴影和相同的 64 像素采样高度。主角也新增真正站立的姿势，不再用走路帧作定格。童年、少年会按年龄缩小身体，NPC 维持成人比例。

六个人生年龄段与六位 NPC 共 **48 个全身关键姿势**：站立、蓄力、前伸、挥手。角色和手脚均为完整图片；没有重新拼接矩形身体或附加多余手臂。主角走动继续使用已有 24 帧全身步行动画。

## 动作

`scripts/comic_gesture.gd` 提供双方共用的 2.4 秒动作时间线：先蓄力，再切到身体动作，最后收势；用轻微前后倾、压缩与重心变化衔接关键帧。点头只轻微起伏，敲鼓/打字保持收肘姿势，电话保持持机姿势，负面情绪避免使用笑着挥手的身体帧。

NPC 的动作与主角错开：递物的一方先伸手，接物随后；观众在节拍之后回应；告别稍后挥手。清除了配角无理由滑动靠近的位移。场景分类优先保留首个明确动作，避免“鼓/读书社”一句被后面的“书”错误归为学习。

动作关键接触加短促动作线，物件从原点击区域移动到接物/持机位置。仍保留上一版布局安全区、同一套点击/绘制区域、减少动态与存档收势状态。

这是完整身体关键帧配合代码缓动的像素演出，尚未给每个事件、每位 NPC 制作独有的逐帧长动画。

## 预览

- `scenes/EnsembleLab.tscn`，F6：同时对比六年龄主角与六位 NPC；八类动作、暂停、时间滑杆、减少动态。
- `scenes/WorldLab.tscn`，F6：六组连续事件分镜。
- `docs/world-scenes/ensemble.png`：统一画风对照。
- `docs/world-scenes/ensemble-motion.gif`：Godot 原生渲染的动作演示。
- `tools/capture_ensemble.gd` 将 25 个原生帧写入 `.godot/ensemble-frames`；随后运行 `tools/export_ensemble.py` 导出 GIF，需要 Pillow。

## 素材与生成提示词

本次使用 **内置 image_gen**，未使用 CLI/API 备用模式。原始生成结果完整复制入项目，索引脚本只读取透明边界，不修改 PNG。

- `assets/comic_ensemble/npc-v1.png`：六位 NPC 的四个全身姿势。
- `assets/comic_ensemble/lead-v1.png`：六年龄主角的四个全身姿势。
- `assets/comic_ensemble/middle-v1.png`：中年主角的独立四姿势，修正原图挥手时外套错误变成棕色的问题。
- `assets/comic_ensemble/prompts.json`：NPC 与主角完整生成提示词、参考来源和模式。
- `assets/comic_ensemble/middle-prompt.json`：中年修正的完整提示词。一次局部改色请求连接失败，最终用内置工具另行生成这一行，未切换到 CLI。
- `assets/comic_ensemble/regions.json`：实际使用 48 个矩形区域，中年一行以独立图覆盖。
- `tools/index_comic_ensemble.py`：索引器，需要 Pillow；源图的未选中区域保留在原始文件，不进入渲染。

在本机的保存目录为 `D:/gamelife/gamelife-anim/assets/comic_ensemble/`。

## 验证

新增 `test/comic_gesture_smoke.gd` 验证 12 个身份、48 个真实全身区域、统一采样密度、起手/接触/回应、站立与读档/减少动态定格。连同布局、真实鼠标互动、短篇与旧长线整局、存档恢复等共 16 组回归检查通过；原生手机/敲鼓互动及窄屏截图另行检查。
