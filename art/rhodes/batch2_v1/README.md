# Batch 2 v1 — hall assets for review

Scope: logistics service counter, Rhodes Island L floor logo, straight and corner hazard-line decals. Batch1 v5 is closed and unchanged; door chamfers remain3px. No scripts/scenes outside this output directory are modified.

## Files

|Deliverable|Native size|Notes|
|---|---|---|
|`rhodes_logistics_on_v1.png`, `rhodes_logistics_off_v1.png`|71×40 canvas,71×39 visible|Blank yellow sign, no letters or staff; tiny cyan indicators ON, zero cyan OFF|
|`rhodes_logistics_atlas_v1.png`|256×128|Two128×128 cells, ON then OFF; sprite origins(28,74) and(156,74), feet at y112 /baseline113|
|`rhodes_logo_L_gray_v1.png`|64×64|#c3cacc symbol and #15181a internal field; transparent outside triangle|
|`rhodes_logo_L_yellow_v1.png`|64×64|#f4d73c symbol and #15181a internal field; transparent outside triangle|
|`rhodes_hazard_horizontal_v1.png`|60×6|45degree stripes,3px yellow/3px black|
|`rhodes_hazard_vertical_v1.png`|6×60|Same stripe phase|
|`rhodes_hazard_corner_NW/NE/SW/SE_v1.png`|24×24 each|6px L-shaped bands, all four corner directions|
|`rhodes_hall_decals_atlas_v1.png`|384×192|4×2 cells,96×96 each|

Every asset has an exact8× nearest-neighbor review export with `_8x` suffix. Assets have binary alpha and use only the specified26-color palette. No Chinese, English or numbers are painted on the assets.

## Production method

Counter: built-in image_gen using the character, field-prop atlas, accepted console and office2021 references. The final source was reduced uniformly by16 in BOTH axes over the entire sprite, then palette-quantized and alpha-thresholded. No section resampling. Blank sign is approximately5px high; worktop is around5px visible depth, front around8px, counter top-to-ground no more than15px. Total height39px fits the locked46px wall and30px character scale. ON/OFF share the exact silhouette. Original source and full prompt are retained.

Logo: drawn directly at native64×64 per §3.3, not scaled down from a large generated image. It has a3px triangle frame, simplified crenellated tower and narrow waist; no small lettering. Only two opaque colors per version. The outside is transparent. It is deliberately uncompressed top-down artwork; the engine should apply ground projection. L logo remains a batch2 visual-review candidate; M/S and font/sign assets are outside this batch.

Hazards: native-grid extension of the approved hazard-stripe rule. The pattern is `(x+y) mod6`, with three yellow and three near-black pixels per period. Straight lengths and corner offsets are multiples of6. Corners are floor decals with no wall face, no bevel, no extruded thickness. Use tile offsets divisible by6 to keep the stripe phase continuous; a 96×96 assembled boundary is shown in the comparison.

## Decal atlas coordinates

Cells are96×96, indexed from0. First row: gray logo, yellow logo, horizontal line, vertical line. Second row: NW, NE, SW, SE corner. Logos start at cell(16,16); horizontal line(18,45); vertical line(45,18); corner(36,36). These floor decals are centered in their cells; foot-baseline placement applies to standing props only.

## Review composite

- `batch2_review_1x.png`:480×180 native pixel scale.
- `batch2_review_4x.png`:1920×720 exact4×.

Left: ON counter against the unchanged locked wall, OFF counter below, original Lappland frame0 alongside each. Middle: both L logo colors and straight hazard segments. Right: a joined hazard boundary with Lappland for scale. Labels are on the review board only.

Counter and character visible feet share a baseline. Accepted wall geometry is used without modification. Floor preview uses the same uniform10× sampled/cropped source as batch1's comparison. It does not modify the accepted floor. The logo and ground decals are shown unprojected for pixel review; this is not an engine screenshot.

`build_batch2.ps1` reproduces finishing, native decal drawing, atlases, composite and checks. `validation.txt` records results; `batch1_lock_verification.json` confirms all files in batch1_v5 retained their original SHA-256 hashes. Engine integration/validation has not been performed.

## Exact counter prompt

References:
- `D:/CSYE 7370/downfall-godot/godot_assets/lappland_combat_64.png`
- `D:/CSYE 7370/downfall-godot/art/field/props_v1.png`
- `D:/CSYE 7370/downfall-godot/art/rhodes/batch1_v4/console_on_v4_8x.png`
- `D:/CSYE 7370/evidence/rhodes-references/furniture/office_2021.png`

```text
Use case: stylized-concept. One isolated logistics service-window COUNTER sprite for Rhodes Island landship hall, batch2 of a pixel-art topdown3/4 orthographic game. Reference1: actual30px tall player scale only, never draw the character. Reference2 pixel prop style. Reference3 accepted console style and scale. Reference4 office furniture design/yellow signage inspiration ONLY, no realistic rendering. NEW subject: compact straight service hatch with dark-steel frame, overhead BLANK YELLOW SIGN PANEL, open empty service aperture, low waist-height countertop at bottom, enclosed vented front panel below it. NO STAFF OR PEOPLE. No text, letters, logos or numbers. Yellow signage must be blank. Front-facing orthographic, only shallow top surfaces visible, no yaw or isometric diamond. Target native overall72px wide x40px tall, lower counter desk surface at14px above floor: visible4px top slab and10px front face; above is a tall OPEN SERVICE WINDOW with slim sideposts and a small6px-high header containing the blank yellow panel. Whole height40px fits locked46px walls. Sideposts are part of the furniture, not new walls. Simple tiny cyan status indicator on counter edge, no large monitor; perhaps small inset card reader within counter, no added clutter. Dark gunmetal #2c3236/#3d4448, nearblack outlines, cool gray edge highlights, safety yellow sign #f4d73c/#b89a2a, restrained orange latch. Worktop brighter than body but white-haired character should remain salient. Pixel style is deliberately low resolution with1 logical pixel outlines and2-4px clusters, no fine detail, no gradient, no bloom or antialiasing, no cast floor shadow or floor patch, genuine transparent background. Native128x128 cell, furniture72x40 within it, feet at cell y112, generous transparent margin; output exactly8x enlarged by nearest-neighbor if possible. The whole sprite may be uniformly integer downsampled, never stretched in parts. The counter must be low: lower14px of40px tall total, not an oversized cabinet. Palette only #0b0c0d #15181a #1f2427 #2c3236 #3d4448 #566064 #737d82 #98a2a6 #c3cacc #a9b2b3 #d4dadb #eef2f2 #6b5a1e #b89a2a #f4d73c #6e2f14 #b8531f #e0782a #0f3a40 #2a8a92 #5fd0d8 #b8f4f6 #5a4428 #c89a5a #f1d9a6 #8a1f1f.
```

