# Equipment bay v2 — light palette, spec v1.0.5

Recolor-only revision of the accepted v1 scale and composition. No generation, scaling, section resampling, alpha editing, geometry changes, or movement of props. New assets remain in the prescribed 26-color palette; old batches are untouched. Visual review pending; these are static composites, not Godot screenshots.

## Files

- `rhodes_walls_light_v1.png`: item4b, 256×192 atlas with exactly the same layout and alpha as Batch1 v5. Individual `*_light_v1.png` modules include straight wall60×46, rib6×46, side strip8×60, side doorway8×60, both L corners32×60, three door states45×46, separate contact shadow60×2. Every original alpha byte is preserved. Wall main face #a9b2b3 with #98a2a6 supporting faces, top cap #c3cacc; dark seams/recesses and existing status accents retained. Door clearance32×36 and3px chamfers unchanged. Do not place a rib immediately beside a door frame.
- `rhodes_floor_equipment_v1.png`: recolored120×120 accepted floor pattern, dominant #566064 with #737d82 supporting plates/highlights; brightest #98a2a6. Four edge seams pass pixel equality checks. Four `rhodes_floor_equipment_quadrant_[0-3]_v1.png`60×60 files are row-major lossless quadrants for the §4 tile grid: use together as a2×2 repeating pattern. They are not four independently seamless patterns. `floor_tiling_3x3_1x.png` and `_4x.png` show repetition of the complete120×120 tile.
- `rhodes_workbench_on_v2.png` / `_off_v2.png`:70×26, surface height remains approximately14px.
- `rhodes_weapon_cabinet_on_v2.png` / `_off_v2.png`:26×41; dark recesses remain behind stored blades.
- `rhodes_crane_hook_v2.png`:34×44, native rail anchor(17,0), atlas anchor(160,13), room sprite origin(106,3), all unchanged.
- `rhodes_robotic_arm_on_v2.png` / `_off_v2.png`:34×34.
- `rhodes_supply_crate_v2.png`:25×11, cold-grey equipment case with a thin orange lid band.
- `rhodes_supply_crates_stack_v2.png`:40×25, cold-grey boxes with orange lid-edge bands.
- `rhodes_equipment_stations_v2.png`:512×256,4×2 cells of128, original cell positions and baseline113. Row0 workbenchON/cabinetON/empty/empty; row1 correspondingOFF/empty/empty.
- `rhodes_equipment_props_v2.png`:256×192,4×3 cells of64, original positions and baseline56. Row0 case/stack/hook/armON; row1 only column3 armOFF; row2 empty. Hook baseline is packing only; place it by its ceiling anchor.

All native asset PNGs have exact nearest-neighbor8× inspection copies. Import native files with nearest filtering.

## Measured colors

Opaque pixels only. Brightness column uses display-value Rec.709 luma `Y'=(0.2126R+0.7152G+0.0722B)/255` to compare with the provided approximately0.26–0.36 old-prop measurements. This is not linear-light relative luminance; `validation.txt` reports that separately as well. Complete palette ramps count toward accents, including dark accent shades. No screen exemption is used: every final prop, ON and OFF, passes the strict combined10% / individual6% limits.

| Prop | Mean Y' | Orange | Yellow | Cyan | Red | Total accents |
|---|---:|---:|---:|---:|---:|---:|
| Workbench ON |0.576448|1.665%|0%|5.250%|0%|6.914%|
| Workbench OFF |0.570663|1.665%|0%|0%|0%|1.665%|
| Weapon cabinet ON |0.610380|1.333%|0%|0.103%|0%|1.436%|
| Weapon cabinet OFF |0.610401|1.333%|0%|0%|0%|1.333%|
| Crane hook |0.516381|1.644%|0%|0%|0%|1.644%|
| Robotic arm ON |0.577830|2.448%|0%|0.188%|0%|2.637%|
| Robotic arm OFF |0.577650|2.448%|0%|0%|0%|2.448%|
| Single case |0.636308|5.150%|0%|0%|0%|5.150%|
| Crate stack |0.590997|4.881%|0%|0%|0%|4.881%|

The most frequent color of every prop is in #98a2a6–#d4dadb;64.15–77.82% of each prop's pixels have Y'>=0.5. Workbench screen background is neutral grey, with the original wrench/highlight shapes cyan. OFF retains those shapes in neutral shades and contains zero cyan. Thin crane cables are grey metal; all cable pixels and alpha positions remain unchanged.

## Review and reproduction

- `equipment_bay_lappland_1x.png`196×169 and `_4x.png`784×676: same room composition and180×115 floor interior as v1, using the light shell and updated props. Original Lappland frame0 at1:1, colors untouched.
- `equipment_scale_review_1x.png`480×150 and `_4x.png`1920×600: per-prop comparisons beside Lappland, plus OFF variants.
- `recolor_equipment.ps1`: deterministic native pixel color remap with small-part accent masks; includes palette, alpha, door clearance, tiling, luminance, dominant-color, accent-budget and8× export assertions. No resampling of source assets occurs.
- `verify_delivery.ps1`: independently checks all11 prop/atlas alpha masks against v1, all4× previews, door chamfers, and protected source hashes. Run it after the recolor script.
- `validation.txt`: full before/after measurements and checks. `protected_inputs_sha256.json`: source hashes.

The floor and shell are room materials, not individual props; the prop0.50–0.65 mean target applies to the nine prop/state images above. Sealed-door warning tape and wall status accents retain their accepted functions. No other room has been produced in this revision.
