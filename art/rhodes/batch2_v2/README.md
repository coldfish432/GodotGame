# Batch 2 v2 — corrected L logo and floor intake

## Corrected L logo (§3.3 v1.0.4)

- `rhodes_logo_L_gray_v2.png`:64×64 native; light #c3cacc triangle with #15181a tower and base bar.
- `rhodes_logo_L_yellow_v2.png`:64×64 native; light #f4d73c triangle with #15181a tower and base bar.
- Exactly two opaque colors per image; outside triangle fully transparent. No antialiasing or fractional alpha.
- Drawn directly at native64×64 using `redraw_logo_finish_floor.ps1`; no bitmap reduction or image-model tracing. Reference: `evidence/rhodes-references/base/logo_rhodes.png`.
- Three crenellations form a broad head at y24–32. A short neck at y33–34 leads immediately into a body that widens downward from10px to22px over y35–47. Four mound steps end at y52. The separate50×2 dark base bar at y56–57 occupies the original text-band position; no letters.
- Triangle fill is continuous light color. The tower and bar remain inset from the outer triangular silhouette; there is no dark internal triangle field.

Review: `logo_review_1x.png` and exact4× `logo_review_4x.png`; separate `_8x.png` assets also supplied. Gray and yellow logos sit on the finished floor at native proportions.

`rhodes_hall_decals_atlas_v2.png` updates only the first two96×96 cells of the v1 atlas. All accepted hazard pixels are checked identical. The counter is unchanged in `../batch2_v1/`.

## Floor intake

Canonical intake file: `../rhodes_floor_v1.png` (120×120 opaque RGBA PNG). An identical copy is provided in this folder.

Source: accepted `../source_batch1_v2/rhodes_floor_source_v2.png`,1254×1254. The full source is downscaled uniformly to120×120 using nearest-neighbor samples at pixel centers, then quantized to the specified26-color palette. **The uniform divisor is10.45 on both axes**, because the generated source is1254px; this is not falsely described as an integer reduction. No cropping, aspect-ratio change, section scaling or gradients are applied. The original remains unchanged.

The final image uses10 of the allowed26 colors and is opaque throughout. Palette quantization alone left94 of120 left/right edge pairs and71 of120 top/bottom pairs unequal. The outermost row/column pairs were reconciled using a palette-quantized average. This changed165 of14400 pixels (1.15%); all interior pixels are identical to the initial uniform-downscaled/quantized result.

Checks and visual review:

- Left/right edge mismatches:0.
- Top/bottom edge mismatches:0; all four corners agree.
- 3×3 tile grid inspected: no discontinuity at repeat boundaries.
- 60px wrap-offset preview inspected: the original tile boundaries run through the center without a visible break.
- The repeating plate and hatch pattern remains intentional; seamless does not imply non-repeating artwork.

Proof files: `floor_tiling_3x3_1x.png`, `floor_tiling_3x3_4x.png`, `floor_wrap_offset_60px.png`, `floor_wrap_offset_60px_4x.png`. Diagnostics preserve the pre-repair quantized floor and a boundary-edit mask.

## Preservation and validation

`validation.txt` records dimensions, palette, cone direction, base bar, alpha and edge checks. `accepted_inputs_verified.json` confirms the accepted batch2_v1 files and original floor source retain their SHA-256 hashes. `intake_manifest.json` records the canonical floor hash and verifies it matches the review copy.

Batch1 remains closed. Counter and hazard decals are not redrawn. This is asset preparation and static tiling verification; no engine integration or runtime validation is claimed.

