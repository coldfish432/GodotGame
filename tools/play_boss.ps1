# Hands-on boss bench (用户 2026-11-05): straight onto a boss or warden floor,
# the operator levelled and dressed for that depth. Nothing is saved.
#   .\tools\play_boss.ps1                         # 矿区 floor 20, 阿米娅
#   .\tools\play_boss.ps1 -Region city -Floor 40
#   .\tools\play_boss.ps1 -Region snow -Floor 30 -Operator hellagur
# Regions: mine, city, snow, siracusa. Floors: 10, 20, 30 … (20, 40 … are
# region bosses; 10, 30 … wardens). Keys in game: see tests/play_boss.gd.
param([string]$Region = "mine", [int]$Floor = 20, [string]$Operator = "")

$projectPath = Split-Path -Parent $PSScriptRoot
$enginePath = Join-Path (Split-Path -Parent $projectPath) 'Godot_v4.7.2-stable_win64.exe'
if (-not (Test-Path -LiteralPath $enginePath)) { throw "Godot executable not found: $enginePath" }
if ($Floor % 10 -ne 0 -or $Floor -le 0) { throw "Floor must be 10, 20, 30 ..." }

$env:DOWNFALL_PLAY_BOSS = "${Region}:${Floor}:${Operator}"
& $enginePath --path $projectPath --script res://tests/play_boss.gd
