# Batch 1 v5 — native-grid style pass

This is a style-only update using v2 as the visual target. All nine existing modules retain v4 dimensions and the exact v4 alpha masks. The accepted console is copied byte-for-byte; floor v2 is unchanged.

## Review files

- `rhodes_walls_doors_v5.png` — 256×192 native atlas.
- `rhodes_walls_doors_v5_8x.png` — exact 2048×1536 review export.
- `lappland_scale_composite_1x.png` — 540×120 comparison at native scale.
- `lappland_scale_composite_4x.png` — exact nearest-neighbor 2160×480 comparison.
- `comparison_doorway_*`, `comparison_side_wall_*`, `comparison_console_*` — individual 180×120 /720×480 panels.
- `lappland_frame0_64.png` — unchanged top-left64×64 frame extracted from `godot_assets/lappland_combat_64.png`.
- `style_pass.ps1` — reproducible native edits, compositing and checks.
- `validation.txt` — verification results.

## Style changes

Door outer chamfers follow the existing45-degree3-px stepped silhouette at all four corners; bevel highlights now make them visible. The header has an orange accent and a cyan status lamp for open/closed, red for sealed. The45×46 outer size and32×36 clear opening are unchanged.

The floor preview's dominant palette tone is #2c3236. Wall faces use #3d4448 as the dominant tone, with darker panel seams and restrained highlights. A horizontal steel conduit sits8px below the4px cap (local y12), with small clamps. A one-pixel muted safety-yellow band sits at baseboard y44.

The2-px contact shadow is supplied separately as `wall_floor_contact_shadow_60x2_v5.png`, drawn in #15181a. Place it on the floor immediately below the wall at local y46. It is a ground overlay, not an expansion of the locked60×46 wall sprite or collision shape. For corner face spans, use the corresponding24-px portion of this overlay; do not add it on top of the side strip's existing shadow.

Corners retain their exact L geometry, top-cap pixels and side-strip pixels; only the E-W face receives the matching wall colors/conduit/baseboard stripe. Side-wall and side-door modules remain entirely pixel-identical to v4.

## Layout rule — ribs and door frames

**Do not place a rib directly next to a door frame. The door frame already serves as its own pillar.** Straight wall strips join the frame directly. Use standalone ribs on uninterrupted wall runs (nominal60px spacing); omit any rib that would abut a frame, and resume the rhythm beyond the doorway. The doorway composite contains no adjacent rib.

## Composite interpretation

Panels are, left to right: Lappland frame0 in the open doorway, beside the side wall, and beside the accepted console. Every character/environment sprite is placed at native1:1 scale; the4× file only repeats pixels. The character frame has a38×29 alpha>=128 bounding box including weapons. Its body/head fits vertically inside the36px opening; weapon tips can extend across the jambs because the character is composited in front of the door. This is an art-scale composite, not an engine screenshot or collision test.

The accepted high-resolution floor source is sampled only for the comparison background: centered1200×1200 crop, uniform integer reduction by10, palette quantization for consistent comparison. Its original file is not modified. No character or console resampling is performed.

## Checks

- All nine module sizes and alpha masks match v4.
- Open doorway retains its fully transparent32×36 rectangle.
- All four3px outer chamfers remain unchanged.
- Side-strip and side-door pixels match v4; corner cap/side pixels match v4.
- Wall repeat ends match; native assets stay within the26-color palette and binary alpha.
- Module8× and composite4× exports are exact pixel replication.
- Accepted console copies are verified by SHA-256 in `accepted_console_hashes.json`.

In-engine validation has not been performed in this art-only pass.

