# Godot 导入与二维人物／立体场景技术接入

验证日期：2026-10-25。当前开发分支：`animation`。本次使用 Godot 4.7.2、Compatibility 渲染器完成导入。

## 导入正确的项目

本机最新动画项目是 `D:/gamelife/gamelife-anim/project.godot`。`D:/gamelife/godot_project` 是另一个目录，打开它不会自动加载动画分支的修改。

1. 在 Godot 项目管理器选择「导入」，选中动画分支根目录的 `project.godot`，等待资源扫描结束。
2. 打开 `scenes/PixelStageLab.tscn`，按 F6。通过「上一场／下一场」切换事件，测试场景互动及 CG 镜头。预览台不写正式存档。
3. 按 F5 运行完整项目，从首页进入「折痕与歪楼 · 新剧情漫画人生」。向下阅读，在当前事件选择观察或正式剧情选项。
4. 从 GitHub 获取时选择 `animation` 分支，保持整个项目目录结构。仅复制某一个场景文件会缺少脚本、字体与角色图集。

## 运行链路

`Main.tscn → LifeComic.tscn → life_comic_reader.gd → life_comic_pages.gd → comic_page.gd → comic_panel.gd → pixel_stage_view.gd`

每个可见分镜持有独立的 `SubViewport` 与 3D 世界。环境由 `pixel_environment_3d.gd` 创建，二维人物由 `pixel_billboard_actor.gd` 创建，物品由 `pixel_prop_3d.gd` 创建。特殊镜头读取 `data/pixel_cg.json`，可选观察读取 `pixel_story_direction.gd`。

### 人物与背景如何融合

- 人物使用 `Sprite3D`，加载现有透明全身图集；主舞台不加载体素人物身体。
- 图像平面随相机朝向更新，脚底仍固定在 3D 世界中的站位。角色走位和相机移动可以独立进行。
- 开启受光、透明裁切、深度测试与投影，最近邻采样保持像素边缘。前景物件可遮挡人物，人物也会受场景灯光影响。
- 每次姿态更新后，重新计算手部位置，再更新手持物品，避免道具落后一帧或接物方向反转。
- `pixel_grade.gdshader` 只处理场景画面，加入轻度明暗分级、冷暖倾向、颜色边缘强化与局部高光扩散；文字和按钮保持清晰。
- 相机像素网格对齐配合显示位移补偿，改善平移中的像素游动。旋转和缩放仍会重新投影，不保证所有镜头完全没有像素闪动。

### 阅读、互动与资源生命周期

最多同时保留 4 个可见分镜视口；离屏约 0.35 秒后释放，再次进入可见区域时重建。观察与 CG 完成标记写入分镜存档，不重新抽取随机结果。窗口改变尺寸会重建分镜，因此重播／跳过按钮点击时重新查找当前实例。

技术边界和美术状态见 [二维人物接入说明](hd2d-characters.md)，场景、色板和镜头数据见 [舞台说明](pixel-stage-3d.md)。现有人物仍使用有限方向的姿势图，不是完整八方向动画库。

## 验证命令

在动画分支项目根目录运行，下列 `godot` 指本机 Godot 可执行文件：

```text
godot --headless --editor --path . --import
godot --headless --path . --script res://test/pixel_stage_smoke.gd
godot --headless --path . --script res://test/pixel_reader_smoke.gd
godot --headless --path . --script res://test/life_comic_ui_smoke.gd
```

导入会生成本地 `.godot` 缓存，无需上传；脚本和着色器的 `.uid` 标识随代码提交。导入日志中关于 `res://godot_demo` 内另有 `project.godot` 的提示表示该嵌套项目被跳过，不影响当前项目运行。无图形检查不能替代实际光照和遮挡预览。
