# 导出 Windows 可玩包

本机没有导出模板（`export_templates/4.7.2.stable.mono` 为空），所以用
「Godot 运行器 + .pck」的方式打包，效果与导出单文件一致，双击即玩。

## 一键

```powershell
powershell -File tools/build_windows.ps1
```

脚本做的事：

1. `--headless --export-pack "Windows Desktop" build/gamelife.pck`
2. 把 Godot 运行器复制成 `build/windows/CreasesAndTangents.exe`
3. 把 `gamelife.pck` 复制成同名的 `CreasesAndTangents.pck`
4. 写 `README.txt`
5. 打 zip：`build/CreasesAndTangents-win64.zip`

## 手动

```powershell
$godot = "D:\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe"
& $godot --headless --path . --export-pack "Windows Desktop" "D:/gamelife/build/gamelife.pck"
Copy-Item "D:\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe" "D:/gamelife/build/windows/CreasesAndTangents.exe"
Copy-Item "D:/gamelife/build/gamelife.pck" "D:/gamelife/build/windows/CreasesAndTangents.pck"
```

运行：双击 `build/windows/CreasesAndTangents.exe`。

## 想要单文件 exe

装一次导出模板即可（约 1 GB，本机网络太慢没下）：

```powershell
# 在 Godot 编辑器里：编辑器 → 管理导出模板 → 下载并安装
# 然后：
& $godot --headless --path . --export-release "Windows Desktop" "D:/gamelife/build/CreasesAndTangents.exe"
```

`export_presets.cfg` 已经写好（预设名 `Windows Desktop`，embed_pck 打开），装好模板后一条命令即可。

## 注意

- 用 mono 版运行器也能跑 GDScript 项目；启动日志里的
  `.NET: Failed to load project assembly` 是正常现象，不影响游戏。
- 两个文件必须同目录且同名（`X.exe` + `X.pck`）。
