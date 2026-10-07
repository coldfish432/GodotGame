param([switch]$Visual)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
$enginePath = Join-Path (Split-Path -Parent $projectPath) 'Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $enginePath)) { throw "Godot executable not found: $enginePath" }
foreach ($suite in @('test_v1', 'test_base_state', 'test_warehouse', 'test_orders', 'test_medical', 'test_progression', 'test_base_scene', 'test_layout', 'test_terrain', 'test_scene_dressing', 'test_guards', 'test_movement', 'test_combat', 'test_enemy_attacks', 'test_lappland', 'test_relics', 'test_builds', 'test_inventory', 'test_loot', 'test_item_icons', 'test_relic_icons', 'test_gear', 'test_ai_driver', 'test_revisions', 'test_audio')) {
    $output = & $enginePath --headless --path $projectPath --script "res://tests/$suite.gd" 2>&1
    $exitCode = $LASTEXITCODE
    $output | Write-Output
    if ($exitCode -ne 0 -or ($output -match 'SCRIPT ERROR:|ERROR:|FAIL ')) { throw "Failed: $suite" }
}
if ($Visual) {
    foreach ($suite in @('test_audio', 'test_ui_v1', 'test_lappland_input', 'capture_enemy_attacks', 'capture_lappland', 'capture_v1', 'capture_terrain', 'capture_guards')) {
        $output = & $enginePath --path $projectPath --script "res://tests/$suite.gd" --rendering-method gl_compatibility --audio-driver Dummy --resolution 1280x720 2>&1
        $exitCode = $LASTEXITCODE
        $output | Write-Output
        if ($exitCode -ne 0 -or ($output -match 'SCRIPT ERROR:|ERROR:|FAIL ')) { throw "Failed: $suite" }
    }
}
