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

## 自解压单文件（只发一个 exe）

7-Zip 已安装到 `C:\Program Files-Zip`。做法：

```powershell
cd D:\gamelifeuild
& "C:\Program Files-Zipz.exe" a -t7z -mx=7 -mmt=on payload.7z windows/CreasesAndTangents.exe windows/CreasesAndTangents.pck windows/README.txt

# config.txt（UTF-8，无 BOM）
# ;!@Install@!UTF-8!
# Title="折痕与歪楼 / LIFE IN PANELS"
# RunProgram="CreasesAndTangents.exe"
# GUIMode="2"
# ;!@InstallEnd@!

cmd /c copy /b "C:\Program Files-Zipz.sfx" + sfx_config.txt + payload.7z CreasesAndTangents-Setup.exe
```

产物：`build/CreasesAndTangents-Setup.exe`（108 MB）。
双击后它会解压到 `%TEMP%`（约 217 MB）并启动游戏，首次启动慢 5–10 秒；
关闭游戏后临时文件由系统清理。

**注意**：自解压包比 zip 更容易被杀毒软件误报；对方若被拦，
右键「属性 → 解除锁定」或改用 zip。

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
