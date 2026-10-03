# Batch 1 v3 — reviewed dimensions

Generated using built-in image_gen, then finished to the exact logical grids using `finish_assets.ps1` in accordance with the spec's pixel-finishing workflow. Generated source images are retained in `sources/`. The accepted floor v2 was not modified.

## Review outputs

- `rhodes_walls_doors_v3.png`: native 256×192 atlas; `_8x.png`: exact 2048×1536.
- `rhodes_console_v3.png`: native 256×128 atlas; `_8x.png`: exact 2048×1024.
- Individual modules are also delivered as native and 8× PNG pairs.
- Pixels use the specified 26-color palette and binary transparency. Every output block is exactly 8×8 uniform pixels.

## Atlas coordinates (logical pixels, zero-based)

|Module|x,y|size|
|---|---|---|
|Straight wall|2,20|60×36: cap 4, face 30, baseboard 2|
|Separate rib|93,20|6×36|
|Inner corner|147,20|26×36|
|Outer corner|211,20|26×36|
|Front open / closed / sealed door|9 / 73 / 137,84|45×36 each|
|End cap|220,84|8×36|
|Top-down wall strip|30,130|4×60, dark edge included in width|
|Top-down door strip|93,130|6×60 overall; 4-px wall strip, 38-px gap, 6×6 posts|
|Console ON / OFF|19 / 147,63|90×50 each; lower desk section 15 px|

Top-down door local coordinates: posts x0–5, y5–10 and49–54; clear wall break y11–48 is38px, with one-pixel threshold at x3. Row3 contains only top-down geometry. No perspective side door remains.

The console keeps the three v2 pictograms (crystal, city, conifers), dark curved worktop, orange supports and three separate monitors. Pixel finishing resamples the screen section to35px and desk section to15px; OFF excludes all four cyan palette colors. Native files are deliberately small; use 8× files for review.

Validation results are in `validation.txt`; measured nontransparent bounding boxes are in `measured_bounds.json`. In-engine validation has not been performed. Sources are illustrative generation outputs; use the finished root-level PNGs for this review.

## Exact image-generation prompts

### walls_doors

- `D:/CSYE 7370/downfall-godot/art/rhodes/source_batch1_v2/rhodes_walls_doors_source_v2.png`
- `D:/CSYE 7370/downfall-godot/godot_assets/lappland_combat_64.png`
- `D:/CSYE 7370/downfall-godot/art/field/props_v1.png`

```text
Use case: precise-object-edit. Revise the attached game asset according to exact pixel-art production measurements. True transparent background. Flat limited-palette chunky pixel art, black 1-logical-pixel outlines, top-left light, no smooth gradients, no bloom, no text or labels or measurement annotations. Palette #0b0c0d #15181a #1f2427 #2c3236 #3d4448 #566064 #737d82 #98a2a6 #c3cacc #a9b2b3 #d4dadb #eef2f2 #6b5a1e #b89a2a #f4d73c #6e2f14 #b8531f #e0782a #0f3a40 #2a8a92 #5fd0d8 #b8f4f6 #5a4428 #c89a5a #f1d9a6 #8a1f1f. Image1 edit target, images2/3 style/scale references. Redraw as EXACT2048x1536 image representing256x192 logical pixels at8x nearest-neighbor. Invisible regular4column3row grid of64x64 logical cells. Fit every asset within its assigned cell and leave transparent margins; do not enlarge to fill sheet. Row1 col1: plain rectangular horizontal repeatable wall strip60px wide x36px tall total: top cap4px, front face30px, baseboard2px. Perfectly horizontal straight rectangular cap and base, absolutely NO end pillars, no end caps, no side face, no raised end blocks, no orange or yellow stripe, no cyan trim. Left and right ends match for tiling. Row1 col2: ONE freestanding narrow rib/pillar module6px wide x36px high, separate from wall; row1 col3 inner corner, col4 outer corner. Row2 col1,col2,col3: identical45px-wide outer octagonal door frame, frontal no yaw, open/closed/sealed states respectively. Open center genuinely transparent no hallway painting. Closed gray steel double panels. Sealed hazard barrier and single red lamp. Blank name plaque. Row2 col4: narrow endcap. Door frame total height36px. Row3 completely REMOVE ALL PERSPECTIVE SIDE DOORS. Row3col1: ONLY an orthographic overhead vertical wall-top strip4px wide x60px long, one dark edge pixel, no front face, no side face. Row3col2: same4px strip with38px vertical gap in center,6x6 square post tops at ends of gap and fine threshold line joining them. Both are flat floor-plan sprites, strictly topdown, no diagonal/isometric/perspective polygons. Row3col3/4 empty transparent. Preserve industrial dark steel wear of input1 but simplify to true low resolution clusters. All logical pixels must be uniform8x8 output blocks. Wall body30px equals reference character body height.
```

### console

- `D:/CSYE 7370/downfall-godot/art/rhodes/source_batch1_v2/rhodes_console_source_v2.png`
- `D:/CSYE 7370/downfall-godot/godot_assets/lappland_combat_64.png`
- `D:/CSYE 7370/downfall-godot/art/field/props_v1.png`

```text
Use case: precise-object-edit. Revise the attached game asset according to exact pixel-art production measurements. True transparent background. Flat limited-palette chunky pixel art, black 1-logical-pixel outlines, top-left light, no smooth gradients, no bloom, no text or labels or measurement annotations. Palette #0b0c0d #15181a #1f2427 #2c3236 #3d4448 #566064 #737d82 #98a2a6 #c3cacc #a9b2b3 #d4dadb #eef2f2 #6b5a1e #b89a2a #f4d73c #6e2f14 #b8531f #e0782a #0f3a40 #2a8a92 #5fd0d8 #b8f4f6 #5a4428 #c89a5a #f1d9a6 #8a1f1f. Image1 is EDIT TARGET, images2/3 scale/style references only. Preserve v2 console design exactly: three separate screens, left mineral crystal pictogram, middle ruined-city silhouette, right twin pine tree pictogram, curved metal desk, orange panels, two supports. Correct physical size. EXACT2048x1024 output canvas, representing256x128 logical pixels at8x nearest-neighbor, two128x128 cells. Each console only90px wide x50px high total INCLUDING screens: occupies x19..108,y63..112 within its own cell, so large transparent margins above and around. Desk surface no more than15px above foot baseline, lower desk body therefore only15px tall; screens and mounts occupy remaining35px. Make short low waist-high desk, NOT previous tall cabinets. Left ON, right OFF, EXACT same geometry and pixel silhouette. ON screens keep the three specified pictograms. Right OFF: absolutely ZERO CYAN ANYWHERE: change ALL cyan pixels including side monitor lamps, bezels, tiny indicator lights, keyboard buttons, small desk screen, reflection accents to neutral dark gray. OFF may ONLY use gunmetal, neutral gray and orange; never teal, blue, cyan, or green. Same camera and design as target. No extra props or text. Raster at stated logical scale, upscale exactly8x with uniform hard square pixels.
```

