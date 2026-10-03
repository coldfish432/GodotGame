# Batch 3 — equipment bay calibration v1

Review candidate, 2026-09-30. Scope: §2.3 equipment bay and §4 items 6–7 only. Batch 1 v5 and Batch 2 accepted files remain unchanged. Gray logo L remains the default floor decal; this small equipment-room composition does not add a logo.

## Deliverables

| Individual native PNG stem | Canvas | Visible bounds | Whole-source reduction |
|---|---:|---:|---:|
| `rhodes_workbench_on_v1`, `_off_v1` | 70×26 | 70×25 | ÷24 |
| `rhodes_weapon_cabinet_on_v1`, `_off_v1` | 26×41 | 26×41 | ÷28 |
| `rhodes_crane_hook_v1` | 34×44 | 34×43 | ÷30 |
| `rhodes_robotic_arm_on_v1`, `_off_v1` | 34×34 | 34×33 | ÷26 |
| `rhodes_supply_crate_v1` | 25×11 | 24×10 | ÷48 |
| `rhodes_supply_crates_stack_v1` | 40×25 | 40×24 | ÷30 |

All have exact nearest-neighbor `_8x.png` inspection copies. Native files are the import assets. The single crate is a shallow equipment case; the stack comprises three taller supply boxes.

`rhodes_equipment_stations_v1.png`: 512×256, 4×2 cells of128×128. Zero-based row0: workbench ON, cabinet ON, empty, empty. Row1: workbench OFF, cabinet OFF, empty, empty. Feet baseline113 within each cell, last opaque row112.

`rhodes_equipment_props_v1.png`: 256×192, 4×3 cells of64×64. Row0: single case, stacked crates, crane hook, arm ON. Row1: empty, empty, empty, arm OFF. Row2 empty. Feet baseline56, last opaque row55. Empty cells intentionally reserve the remaining room batches; this is not the final combined all-rooms atlas.

## Scale and layout

- Locked wall height46 (4cap+40face+2baseboard); corners and side strips copied from accepted Batch1 v5 without changes. Do not place a rib directly beside a door frame.
- Workbench surface-to-ground is approximately14px; the shallow tabletop, short supports, and monitor/lamp are one uniformly reduced image. No section compression. Cabinet is upright blade storage, not a waist-height work surface.
- Crane is ceiling mounted. Its atlas bottom baseline is a packing convention, **not a ground-contact pivot**. Native anchor is `(17,0)` at rail top midpoint; atlas anchor `(160,13)`. In the room review it is placed at `(106,3)`, so its last visible hook pixel is at y45 and room floor begins at y46. Do not place the hook tip on the floor.
- No baked floor shadows. Equipment lighting is cool top-left; orange covers/tools and gray steel, no decorative hazard stripes. Red is excluded from equipment quantization because the spec reserves it for sealed-door lamps/fire equipment.

## Review images

- `equipment_bay_lappland_1x.png`196×169 and `_4x.png`784×676: assembled room, 180×115 floor interior, all six props, accepted walls/corners/floor, Lappland frame0 unchanged at1:1.
- `equipment_scale_review_1x.png`480×150 and `_4x.png`1920×600: top row workbench, cabinet, overhead hook, robotic arm beside native Lappland; bottom row crate variants and OFF fixtures.
- These are static pixel composites, not Godot screenshots. Engine integration and user visual acceptance are pending.

## Reproducibility and validation

Generated with the built-in imagegen tool. Exact six prompts in `prompts.json`; untouched generated originals in `sources/`. Reference roles: accepted Batch1 scale composite for style/scale, elite desk and weapon cabinet for furniture design; original equipment-room references inspected during preparation.

Run `powershell -NoProfile -ExecutionPolicy Bypass -File build_equipment.ps1` to reproduce outputs. Each source alpha>=128 bounding box is padded to a multiple of its integer divisor; a single nearest sample is used per k×k block across the whole sprite. Sample offset is `(k/2,k/2)`, except crane `(8,15)` to improve thin-cable sampling. The same divisor is applied on both axes, with no section resampling or aspect changes. Source generator resolutions were not exact requested logical upscales; final native assets and8× copies are the validated deliverables.

All new asset opaque pixels belong to the specified26-color palette; transparency is binary. Each asset uses a subset, not all26 colors. Workbench, cabinet and arm OFF variants have identical alpha and zero cyan; screen/lamp emission removed. Composite colors additionally include original character pixels, intentionally unquantized.

`validation.txt` records actual dimensions, atlas origins, palette counts, ON/OFF checks and exact8× pixel checks. `locked_inputs_sha256.json` records all accepted Batch1 PNG hashes. Accepted floor SHA256: `433DDED8F5A617327257266CCC33A5F01CED342413079BF54E84D41810798130`.
