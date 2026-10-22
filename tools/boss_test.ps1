# Starts the game with every contract beginning on a boss or warden floor:
#   .\tools\boss_test.ps1 20    # region boss, tier 1 (40 = tier 2 …)
#   .\tools\boss_test.ps1 10    # warden, tier 1 (30 = tier 2 …)
# Pick the region with the contract at the sand table. Debug runs only.
param([int]$Floor = 20)

$projectPath = Split-Path -Parent $PSScriptRoot
$enginePath = Join-Path (Split-Path -Parent $projectPath) 'Godot_v4.7.2-stable_win64.exe'
if (-not (Test-Path -LiteralPath $enginePath)) { throw "Godot executable not found: $enginePath" }
if ($Floor % 10 -ne 0 -or $Floor -le 0) { throw "Floor must be 10, 20, 30 ..." }

$env:DOWNFALL_BOSS_FLOOR = "$Floor"
& $enginePath --path $projectPath
