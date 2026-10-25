# 构建 Windows 可玩包（运行器 + pck）
# 用法：powershell -File tools/build_windows.ps1 [-Godot <exe>] [-Out <dir>]
param(
    [string]$Godot = "D:\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe",
    [string]$Runner = "D:\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe",
    [string]$Out = "D:\gamelife\build"
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$win = Join-Path $Out "windows"
New-Item -ItemType Directory -Force -Path $win | Out-Null

Write-Host "1/4 导出 pck ..."
$pck = Join-Path $Out "gamelife.pck"
& $Godot --headless --path $root --export-pack "Windows Desktop" $pck
if (-not (Test-Path $pck)) { throw "pck 导出失败" }

Write-Host "2/4 复制运行器 ..."
Copy-Item $Runner (Join-Path $win "CreasesAndTangents.exe") -Force
Copy-Item $pck (Join-Path $win "CreasesAndTangents.pck") -Force

Write-Host "3/4 写 README ..."
$readme = @"
折痕与歪楼 / LIFE IN PANELS

双击 CreasesAndTangents.exe 开始。
滚轮/拖动向下阅读，点击选项做选择，书签自动保存。
存档：%APPDATA%\Godot\app_userdata\Creases and Tangents\

两个文件必须同目录、同名：CreasesAndTangents.exe + CreasesAndTangents.pck
"@
Set-Content -Path (Join-Path $win "README.txt") -Value $readme -Encoding UTF8

Write-Host "4/4 打包 zip ..."
$zip = Join-Path $Out "CreasesAndTangents-win64.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $win "*") -DestinationPath $zip -CompressionLevel Optimal
Write-Host "完成：$zip"
