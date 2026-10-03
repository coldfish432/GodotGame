# Equipment bay v3 — figure/ground and internal form

Native recolor revision of v2. Wall faces now use dominant #98a2a6; the #c3cacc cap is preserved. Workbench, cabinet, crane and robotic-arm outer housings use #c3cacc/#d4dadb. Cabinet blade slots and stored blades, robotic-arm pivot joints, workbench recesses, and hoist recesses regain #3d4448/#566064 values. Existing #0b0c0d silhouette pixels and accent pixels are retained.

Geometry, every alpha byte, atlas slots, baselines, room placement and the crane anchor are unchanged. Floor and crate pixels match v2. No resampling or generation was used. All old input files remain untouched.

## Delivery

- `equipment_bay_lappland_1x.png`196×169 and `_4x.png`784×676: updated room, original Lappland frame0 at1:1.
- `equipment_scale_review_1x.png`480×150 and `_4x.png`1920×600: individual comparisons and OFF states.
- `rhodes_walls_light_v2.png`:256×192 atlas plus individual `*_light_v2.png` modules. Wall60×46, rib6×46, side strip/door8×60, corners32×60, doors45×46 with32×36 clearance and3px chamfers. Do not place a rib beside a door frame.
- `rhodes_equipment_stations_v3.png`:512×256,4×2 cells of128; workbench/cabinet ON in row0 columns0/1, OFF in row1 columns0/1. Baseline113.
- `rhodes_equipment_props_v3.png`:256×192,4×3 cells of64; case/stack/hook/arm ON in row0, arm OFF at row1 column3. Baseline56.
- Individual `rhodes_*_v3.png` props retain the v2 canvas sizes. Exact8× inspection copies included.
- Crane native anchor(17,0), atlas anchor(160,13), room origin(106,3), unchanged. Hook baseline is only for atlas packing; its placement remains ceiling mounted.
- `rhodes_floor_equipment_v1.png`: unchanged120×120 tile, with four60×60 quadrants and3×3 tiling previews.

## Measurements

Mean values are opaque-pixel display luma Y'=(0.2126R+0.7152G+0.0722B)/255, using the same comparison metric as v2. Linear-light luminance and all individual accent percentages are also recorded in `validation.txt`.

| Prop | Mean Y' ON / OFF | Total accents ON / OFF |
|---|---:|---:|
| Workbench |0.586632 /0.580846|6.914% /1.665%|
| Weapon cabinet |0.572073 /0.572094|1.436% /1.333%|
| Crane hook |0.533891|1.644%|
| Robotic arm |0.554174 /0.553994|2.637% /2.448%|
| Single case, unchanged |0.636308|5.150%|
| Crate stack, unchanged |0.590997|4.881%|

All final prop means remain within0.50–0.65. Accent pixels are unchanged from v2: total<=10%, each complete accent ramp<=6%, without a screen exemption. OFF variants contain zero cyan. Less uniform brightness inside the cabinet and joints is intentional to restore internal form.

`restore_form.ps1` reproduces the assets; `verify_delivery.ps1` validates source hashes, native/atlas alpha masks and exact4× exports. `validation.txt` contains the results. This is a static art composite for review; Godot integration is not part of this revision.
