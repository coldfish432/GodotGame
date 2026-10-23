param([switch]$Visual, [switch]$Full, [int]$Jobs = 4, [int]$Limit = 1500)
# Runs every headless suite, $Jobs at a time. Daily runs sweep fewer generated
# floors (each map suite reads DOWNFALL_FULL); -Full sweeps them all.
# A suite whose log shows a SCRIPT ERROR is stopped 15 s later 鈥?a SceneTree
# script that errors stops but never quits 鈥?and any suite after $Limit s.
# Logs go to ../evidence/_suite_<name>.log; a summary is printed at the end.
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
$enginePath = Join-Path (Split-Path -Parent $projectPath) 'Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $enginePath)) { throw "Godot executable not found: $enginePath" }
# Suites write their results to ../evidence (res://../evidence); a fresh clone has no such folder.
$evidence = Join-Path (Split-Path -Parent $projectPath) 'evidence'
New-Item -ItemType Directory -Force -Path $evidence | Out-Null
$env:DOWNFALL_FULL = if ($Full) { '1' } else { '' }

# Longest first, so the slow map sweeps start at once and the short suites fill in.
$headlessSuites = @('test_layout', 'test_siracusa', 'test_siracusa_enemies', 'test_city_variants', 'test_recruit', 'test_traps_traces', 'test_bridges', 'test_elevation', 'test_terrain', 'test_guards', 'test_scene_dressing',
    'test_v1', 'test_revisions', 'test_new_enemies', 'test_run_goals', 'test_threat', 'test_base_state', 'test_warehouse', 'test_orders',
    'test_medical', 'test_progression', 'test_works', 'test_base_scene', 'test_movement', 'test_combat', 'test_enemy_attacks',
    'test_lappland', 'test_amiya', 'test_hellagur', 'test_recruit_kits', 'test_pointer', 'test_prts', 'test_hotbar', 'test_relics', 'test_builds', 'test_inventory', 'test_loot',
    'test_item_icons', 'test_relic_icons', 'test_gear', 'test_growth', 'test_gear_expansion', 'test_ai_driver', 'test_audio', 'test_a3_assets', 'test_i18n', 'test_heal_orbs', 'test_prefixes', 'test_prefix_families', 'test_market', 'test_potion_shops', 'test_drag_transfer', 'test_number_fields', 'test_exchange', 'test_packs', 'test_voyage', 'test_research', 'test_map_features', 'test_bosses', 'test_arenas', 'test_camera', 'test_specials', 'test_tutorial', 'test_story')
$visualSuites = @('test_ui_v1', 'test_lappland_input', 'test_amiya_input', 'test_loot_input', 'test_hotbar_input',
    'test_base_crew', 'capture_enemy_attacks', 'capture_lappland', 'capture_amiya', 'capture_recruit_kits', 'capture_v1', 'capture_terrain', 'capture_guards', 'capture_bosses', 'capture_arenas')

function Invoke-Suites([string[]]$suites, [string[]]$extra, [int]$parallel) {
    $queue = [System.Collections.Queue]::new()
    foreach ($s in $suites) { $queue.Enqueue($s) }
    $running = @{}
    $results = [ordered]@{}
    while ($queue.Count -gt 0 -or $running.Count -gt 0) {
        while ($running.Count -lt $parallel -and $queue.Count -gt 0) {
            $suite = $queue.Dequeue()
            $log = Join-Path $evidence "_suite_$suite.log"
            $arguments = @('--headless', '--path', "`"$projectPath`"", '--script', "res://tests/$suite.gd") + $extra
            $process = Start-Process -FilePath $enginePath -ArgumentList $arguments -NoNewWindow -PassThru `
                -RedirectStandardOutput $log -RedirectStandardError "$log.err"
            # Windows PowerShell only keeps the exit code of a process whose handle was read.
            $null = $process.Handle
            $running[$suite] = @{ Process = $process; Log = $log; Start = Get-Date; ErrorAt = $null }
        }
        Start-Sleep -Seconds 2
        foreach ($suite in @($running.Keys)) {
            $job = $running[$suite]
            $text = (Get-Content -LiteralPath $job.Log -Raw -ErrorAction SilentlyContinue) + (Get-Content -LiteralPath "$($job.Log).err" -Raw -ErrorAction SilentlyContinue)
            $verdict = $null
            if ($job.Process.HasExited) {
                $verdict = "exit $($job.Process.ExitCode)"
            } else {
                if ($null -eq $job.ErrorAt -and $text -match 'SCRIPT ERROR:') { $job.ErrorAt = Get-Date }
                if ($null -ne $job.ErrorAt -and ((Get-Date) - $job.ErrorAt).TotalSeconds -ge 15) { $verdict = 'stopped after SCRIPT ERROR' }
                elseif (((Get-Date) - $job.Start).TotalSeconds -ge $Limit) { $verdict = "stopped after $Limit s" }
                if ($verdict) { Stop-Process -Id $job.Process.Id -Force -ErrorAction SilentlyContinue }
            }
            if (-not $verdict) { continue }
            $failed = ($verdict -ne 'exit 0') -or ($text -match 'SCRIPT ERROR:|FAIL ')
            $seconds = [int]((Get-Date) - $job.Start).TotalSeconds
            $results[$suite] = @{ Failed = $failed; Verdict = $verdict; Seconds = $seconds }
            Write-Host ("{0,-24} {1,-6} {2,5}s  {3}" -f $suite, $(if ($failed) { 'FAIL' } else { 'ok' }), $seconds, $verdict)
            if ($failed) { ($text -split "`r?`n") | Where-Object { $_ -match '^FAIL |SCRIPT ERROR:|^\s+at: ' } | Select-Object -First 8 | ForEach-Object { Write-Host "    $_" } }
            $running.Remove($suite)
        }
    }
    return $results
}

$started = Get-Date
$all = Invoke-Suites $headlessSuites @() $Jobs
if ($Visual) {
    # Rendered suites draw to a window: one at a time.
    $more = Invoke-Suites $visualSuites @('--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--resolution', '1280x720') 1
    foreach ($key in $more.Keys) { $all[$key] = $more[$key] }
}
$bad = @($all.Keys | Where-Object { $all[$_].Failed })
Write-Output ("{0} suites in {1:n0} s ({2}), {3} failed" -f $all.Count, ((Get-Date) - $started).TotalSeconds, $(if ($Full) { 'full' } else { 'daily' }), $bad.Count)
if ($bad.Count -gt 0) { throw "Failed: $($bad -join ', ')" }
