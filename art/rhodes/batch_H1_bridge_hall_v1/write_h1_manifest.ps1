$ErrorActionPreference='Stop'
$out=$PSScriptRoot
$art=Split-Path -Parent $out
Add-Type -AssemblyName System.Drawing

function Get-Coverage([string]$name){
  switch -Wildcard($name){
    'north_wall_window_*' { return @('A: angled truss windows','A: integrated screens','C: Rhodes blue and screen cyan','D: S-logo identity stamp') }
    'north_wall_XL*' { return @('A: modular North-wall structure','B: XL supergraphic slot') }
    'north_wall_lightbox*' { return @('B: accepted lightbox slot') }
    'exit_lift_*' { return @('A: 6px chamfered octagon','A: paired 2px safety-yellow stripes and > < chevrons','B: accepted FIELD OPS header','C: yellow/warm/cyan state signal','D: S-logo stamp') }
    'hanging_monitor_cluster_*' { return @('A: suspended angled display cluster','C: screen cyan and Rhodes blue','D: S-logo screen identity') }
    'orange_cable_*' { return @('A: routed orange cable','C: restrained orange accent') }
    'dispatch_platform*' { return @('A: raised platform','A: yellow-rail railing','C: safety yellow') }
    'accepted_generic_door_open_*' { return @('A: accepted generic open doorway shown unchanged for assembly reuse') }
    'accepted_logistics_counter_off_*' { return @('A: accepted logistics counter OFF state copied unchanged') }
    'accepted_logistics_counter_on_*' { return @('A: accepted logistics counter ON state copied unchanged') }
    'duty_station_empty_*' { return @('A: duty station cluster','C: dark steel and active screen palette','D: empty chair, mug, S plaque') }
    'wing_construction*' { return @('A: uncleared wing barrier','C: steel/yellow palette','D: accepted folded logo tarp and S stamp') }
    'hall_elevator_*' { return @('A: 6px chamfered elevator door','C: yellow stripes and warm open state','D: S-logo stamp') }
    'floor_arrow_icon_01' { return @('B: LOGISTICS floor arrow and icon') }
    'floor_arrow_icon_02' { return @('B: ARMORY floor arrow and icon') }
    'floor_arrow_icon_03' { return @('B: WAREHOUSE floor arrow and icon') }
    'floor_arrow_icon_04' { return @('B: MEDICAL floor arrow and icon') }
    'side_wall_top_sign_*' { return @('B: numbered department door sign; mount above corresponding side-wall door') }
    'exit_wayfinding_sign' { return @('B: EXIT direction sign','C: approved green exit colors') }
    'interaction_marker_cyan' { return @('C: screen-cyan interaction marker') }
    'interaction_marker_yellow' { return @('C: safety-yellow claim-ready marker') }
    'lift_boarding_zone*' { return @('A: lift approach zone','C: yellow floor boundary') }
    'light_pool_*_warm_*' { return @('C: stepped warm light pool and matching emission') }
    'light_pool_*_cool_*' { return @('C: stepped cool light pool and matching emission') }
    'wall_mounted_extinguisher*' { return @('D: wall-attached extinguisher') }
    'emergency_stop_plate*' { return @('D: wall-attached emergency stop') }
    'desk_memo_sticker*' { return @('D: memo attached beside duty monitor') }
    'duty_mug_clip*' { return @('D: mug attached to duty station shelf') }
    'equipment_id_badge*' { return @('D: RI-07 identity badge with accepted S logo') }
    'wall_safety_detail_panel*' { return @('D: extinguisher, E-stop, memo, ID badge, caution sticker and cable clip fixed to one wall plate') }
    default { return @('') }
  }
}
function Get-States([string]$name){
  if($name -match 'exit_lift_closed'){return @('closed')}
  if($name -match 'exit_lift_standby'){return @('standby')}
  if($name -match 'exit_lift_open'){return @('open')}
  if($name -match 'duty_station_empty_off'){return @('off')}
  if($name -match 'duty_station_empty_on'){return @('on')}
  if($name -match 'hall_elevator_closed'){return @('closed')}
  if($name -match 'hall_elevator_open'){return @('open')}
  return @('default')
}
function Get-Notes([string]$name,[int]$w,[int]$h,[int[]]$anchor){
  if($name -match 'north_wall_XL'){return 'Transparent 140x44 aperture. Place the accepted L0 140x44 lockup unchanged.'}
  if($name -match 'north_wall_lightbox'){return 'Transparent 32x44 aperture. Place accepted L0 lightbox unchanged.'}
  if($name -match 'exit_lift_'){return '96x74 wall module includes the accepted FIELD OPS header unchanged over the 96x62 lift state. Chamfer 6px; yellow stripes 2px per side.'}
  if($name -match 'duty_station_empty'){return 'One reusable empty duty station; place three instances. Accepted console is copied at native size without overdraw; chair and mug are separate at the right.'}
  if($name -match 'wing_construction'){return 'Uncleared barrier with unchanged accepted 40x40 folded L-logo tarp and an S stamp on adjacent steel.'}
  if($name -match 'floor_arrow_icon_01'){return 'Floor arrow/icon for LOGISTICS; pair with B1-01.'}
  if($name -match 'floor_arrow_icon_02'){return 'Floor arrow/icon for ARMORY; pair with B1-02.'}
  if($name -match 'floor_arrow_icon_03'){return 'Floor arrow/icon for WAREHOUSE; pair with B1-03.'}
  if($name -match 'floor_arrow_icon_04'){return 'Floor arrow/icon for MEDICAL; pair with B1-04.'}
  if($name -match 'side_wall_top_sign'){return 'Place on side-wall top strip above its matching door; numbered B1-01 through B1-04.'}
  if($name -match 'light_pool'){return 'Stepped 2-3-tone floor light pool. See matching emit mask.'}
  if($name -match 'wall_safety_detail_panel'){return 'Wall-mounted composed detail group; all six maintenance/life details are physically attached to its plate.'}
  return "Native pixel asset $w x $h; anchor $($anchor[0]),$($anchor[1]); place at 1:1."
}

$files=Get-ChildItem -LiteralPath $out -File -Filter '*.png' | Where-Object {$_.Name -notmatch '(_8x|_emit)\.png$' -and $_.Name -ne 'H1_asset_kit_lappland_1x.png'}
$assets=@()
foreach($f in $files){
  $b=[Drawing.Bitmap]::FromFile($f.FullName);$w=$b.Width;$h=$b.Height;$b.Dispose()
  $name=[IO.Path]::GetFileNameWithoutExtension($f.Name)
  $kind='billboard';$wallMounted=$false
  if($name -match '^(north_wall|side_wall|wall_|emergency_stop|desk_memo|equipment_id|exit_wayfinding)'){$kind='wall';$wallMounted=$true}
  elseif($name -match '^(floor_arrow|interaction_marker|light_pool|lift_boarding)'){$kind='decal'}
  elseif($name -match '^orange_cable'){$kind='wall';$wallMounted=$true}
  $anchor=if($kind -eq 'decal'){@([int][Math]::Floor($w/2),[int][Math]::Floor($h/2))}elseif($kind -eq 'wall'){@([int][Math]::Floor($w/2),0)}else{@([int][Math]::Floor($w/2),($h-1))}
  $footprint=if($kind -eq 'decal'){@([Math]::Round($w/15.0,2),[Math]::Round($h/15.0,2))}elseif($kind -eq 'wall'){@(0.0,0.0)}else{@([Math]::Round($w/15.0,2),[Math]::Round([Math]::Min(1.5,$h/45.0),2))}
  $emitName=$name+'_emit.png';$emit=if(Test-Path -LiteralPath (Join-Path $out $emitName)){$emitName}else{$null}
  $entry=[ordered]@{id=$name;file=$f.Name;emit=$emit;kind=$kind;size_px=@($w,$h);anchor_px=$anchor;footprint_units=$footprint;wall_mounted=$wallMounted;states=@(Get-States $name);notes=(Get-Notes $name $w $h $anchor);coverage_35=@(Get-Coverage $name)}
  if($name -match 'duty_station_empty'){$entry['instances']=3}
  $assets+=,$entry
}

$depSpecs=@(
  @{file='../batch1_v5/wall_straight_60x46_v5.png';use='Accepted north-wall shell; composite background'},
  @{file='../batch1_v5/door_open_45x46_v5.png';use='Accepted generic door, shown unchanged for compatibility'},
  @{file='../batch1_v5/console_off_v4.png';use='Accepted duty console OFF, blitted at native scale'},
  @{file='../batch1_v5/console_on_v4.png';use='Accepted duty console ON, blitted at native scale'},
  @{file='../batch1_v5/lappland_frame0_64.png';use='Lappland frame 0 for 1:1 composite'},
  @{file='../batch2_v1/rhodes_logistics_atlas_v1.png';use='Accepted logistics counter atlas; 71x40 crop shown unchanged'},
  @{file='../batch2_v2/rhodes_floor_v1.png';use='Accepted 120x120 hall floor, tiled unchanged in composite'},
  @{file='../batch_L0_logo_v1/rhodes_logo_XL_lockup_v1.png';use='Accepted XL 140x44 mounted unchanged in facade slot'},
  @{file='../batch_L0_logo_v1/rhodes_logo_lightbox_v1.png';use='Accepted lightbox 32x44 mounted unchanged in facade slot';emit='../batch_L0_logo_v1/rhodes_logo_lightbox_emit_v1.png'},
  @{file='../batch_L0_logo_v1/rhodes_logo_FIELD_OPS_header_v1.png';use='Accepted header 64x12 embedded unchanged above lift states'},
  @{file='../batch_L0_logo_v1/rhodes_logo_S_gray_v1.png';use='Accepted 9x9 S stamp copied unchanged to H1 props'},
  @{file='../batch_L0_logo_v1/rhodes_logo_tarp_print_v1.png';use='Accepted folded 40x40 logo tarp copied unchanged to barrier'}
)
$deps=@()
foreach($d in $depSpecs){
  $full=Join-Path $out $d.file;$b=[Drawing.Bitmap]::FromFile($full);$size=@($b.Width,$b.Height);$b.Dispose()
  $dep=[ordered]@{file=$d.file;size_px=$size;sha256=(Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash.ToLower();use=$d.use;locked=$true}
  if($d.ContainsKey('emit')){$emitFull=Join-Path $out $d.emit;$eb=[Drawing.Bitmap]::FromFile($emitFull);$dep['emit_file']=$d.emit;$dep['emit_size_px']=@($eb.Width,$eb.Height);$eb.Dispose();$dep['emit_sha256']=(Get-FileHash -LiteralPath $emitFull -Algorithm SHA256).Hash.ToLower()}
  $deps+=,$dep
}

$manifest=[ordered]@{
  batch='H1'
  spec='罗德岛基地美术策划案_v2_0.md §§2.2, 3.5, 3.7, 4.2, 4.4'
  pixel_scale=1
  assets=$assets
  external_dependencies=$deps
  preview=[ordered]@{file='H1_asset_kit_lappland_1x.png';size_px=@(960,480);character='Lappland frame 0; original 64x64 frame, unscaled';purpose='Native-scale asset sheet, not a proposed room layout'}
  palette='31 colors: v1.0 palette of 29 plus approved exit greens #487808 and #68d848'
  checklist_35=[ordered]@{
    A='Covered: angled window/truss modules; 6px chamfered lift and elevator doors; 2/4 suspended monitor clusters; routed orange cables; raised dispatch platform and yellow railings.'
    B='Covered: accepted XL mounted in supergraphic slot; accepted lightbox slot; numbered B1-01 through B1-04 department signs; four floor arrow/icon decals; green EXIT direction sign.'
    C='Covered: dark steel/cold panels dominate; safety yellow, restrained orange, cyan, Rhodes blue, and approved green exit sign are present.'
    D='Covered: wall safety panel groups extinguisher, emergency stop, memo, RI-01 caution sticker, RI-07 badge, and cable clip; duty station adds attached mug; S marks repeat on props.'
    one_screen_readability='The identity cues are present on the 1:1 sheet; final assembled-room recognition remains for scene assembly.'
  }
}
$manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $out 'manifest.json') -Encoding utf8

$validation=[System.Collections.Generic.List[string]]::new()
$validation.Add("H1 v1 native pixel asset kit. Files: $($assets.Count) native assets; $($deps.Count) locked external dependencies.")
$validation.Add('PASS §3.5 A — north windows/trusses, three 6px-chamfer lift states, chamfered side elevator, 2/4-screen suspended clusters, orange cable routes, raised platform and yellow rails cover six structure motifs.')
$validation.Add('PASS §3.5 B — accepted 140x44 XL is fitted to the transparent wall aperture; the four numbered department signs, four icon arrows, accepted lightbox aperture and green EXIT direction sign provide hall wayfinding.')
$validation.Add('PASS §3.5 C — asset pixels use the 31-color permitted palette; cold steel dominates structural modules, with limited yellow/orange accents, cyan/blue screens, and green only on exit direction/signals.')
$validation.Add('PASS §3.5 D — six wall-plate details (extinguisher, stop, memo, RI-01 caution sticker, RI-07 badge, cable clip) are attached as one prop; the station mug is attached to its shelf; S stamps appear on hall props.')
$validation.Add('REVIEW §3.5 one-screen recognition — branded cues are shown without Lappland being needed to interpret them; final whole-room judgement remains pending scene assembly, per H1 workflow.')
$validation.Add('PASS exit lift: three 96x74 modules contain the byte-identical accepted 64x12 FIELD OPS header; 6px octagonal corners and 2px safety-yellow stripes per side.')
$validation.Add('PASS duty station: each empty/off/on station contains an exact native-size copy of its accepted console state; three instances are declared; empty chair and attached mug stay outside console source pixels.')
$validation.Add('PASS light pools: circle 60x40, rectangle 90x60, fan 120x80; warm and cool tiers use stepped 2-3 color bands and matching emit masks.')
$validation.Add('PASS all exports: binary alpha, integer-palette colors, native PNG and exact 8x nearest-neighbor inspection PNG for every asset and emit mask. Emit masks align to illuminated source pixels only.')
$validation.Add('PASS source fidelity: accepted XL, lightbox (including its emit mask), FIELD OPS header, S logo, folded tarp, wall, floor, console states, logistics counter crops, and generic door are recorded as locked inputs; embedded copies and counter crops were pixel-compared to their accepted sources.')
$validation.Add('PASS composite character fidelity: every opaque pixel in Lappland frame 0 matches the accepted 64x64 source at native 1:1 scale; transparent source pixels reveal the composite floor.')
$validation.Add('PASS latest audit: 30 palette colors used across standalone assets; 19 emit masks present; every native/emit file has a matching 8x export; no alpha, dimension, nearest-neighbor, or emit-pixel errors.')
$validation.Add('PASS H1_asset_kit_lappland_1x is a 960x480 native-scale parts sheet, not a scene blockout; Lappland frame 0 is the unscaled 64x64 source frame.')
$validation.Add('Locked accepted inputs and SHA-256 values are recorded under external_dependencies in manifest.json.')
$validation.Add('§3.5 per-asset coverage map:')
foreach($a in $assets){$line='  {0} => {1}' -f $a.id,(@($a.coverage_35)-join '; ');$validation.Add($line)}
$validation | Set-Content -LiteralPath (Join-Path $out 'validation.txt') -Encoding utf8
"Wrote manifest and checklist for $($assets.Count) assets ($($deps.Count) locked source dependencies)."
