# Batch 1 v4 — spec v1.0.2

Floor v2 remains accepted and unchanged. This folder contains replacements for walls/doors and the console only.

## Method

Walls, doors, side strips and corners are drawn directly on the native pixel grid, as explicitly approved in this chat after the image model failed the geometric requirements. `build_native.ps1` is the reproducible native drawing source. No wall section or door component is stretched or resampled.

The console was redrawn using built-in image_gen, then the WHOLE sprite was reduced uniformly by an integer factor of 16 on both axes. There is no section resampling or aspect-ratio correction. Its native canvas is 95×43; visible bounds are 94×43, close to the requested approximate 90×50 and below the 50-px height limit. The top/front boundary was redrawn by image_gen before reduction, not moved by image processing. Approximate visible desk surface is 4px and front fascia 10px; desk top is about 15px above the ground. Three v2 pictograms remain readable. OFF uses identical geometry and removes cyan palette colors plus cyan-tinted source glow highlights.

## Deliverables

- `rhodes_walls_doors_v4.png`: native 256×192 atlas; matching `_8x.png` is 2048×1536.
- `rhodes_console_v4.png`: native 256×128 atlas; matching `_8x.png` is 2048×1024.
- Individual modules also supplied in native size and exact 8× review size.
- `corner_join_review_v4.png`: orthographic corner connection sample, not an engine screenshot.
- `validation.txt`: checked geometry, transparency, palette, ON/OFF silhouette and uniform output blocks.
- `console_sampling.txt`: source bounding box and uniform integer sampling details.
- `sources/`: all generated attempts, including rejected drafts. Do not use these directly as the final sprites.
- `prompts.md`: actual image-generation prompts and reference paths.

## Geometry

|Module|Native size / constraint|
|---|---|
|Straight wall|60×46; cap4 + face40 + baseboard2; matching repeat edges, no end pillars|
|Separate rib|6×46|
|Front door states|45×46; open state has a fully transparent32×36 rectangle at local x6–37,y9–44|
|Side wall|8×60 total: highlight1 + cap4 + dark edge1 + contact shadow2|
|Side door|8×60; gap38 at y11–48, posts6×6 at y5–10 and49–54, threshold1px|
|L corners|32×60; cap bends90degrees into side strip; E-W face ends at the junction|
|Console|95×43 canvas /94×43 visible; one uniform16× reduction; OFF zero cyan|

## Atlas placement (x,y)

Walls atlas uses64×64 cells. Straight wall(2,10), rib(93,10), right L(144,2), left L(208,2); open(9,74), closed(73,74), sealed(137,74); side strip(28,130), side door(92,130). Console128×128 cells: ON(16,70), OFF(144,70), baseline113.

No engine integration or engine validation performed. Pixel and geometry checks pass; visual acceptance remains for this review.

