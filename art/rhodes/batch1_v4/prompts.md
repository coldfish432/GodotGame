# Image generation prompts — v4

Native walls/doors were subsequently redrawn on the grid with user approval. These prompts document generation attempts; final geometry is defined in build_native.ps1.

## walls_doors

- `D:/CSYE 7370/downfall-godot/art/rhodes/batch1_v3/rhodes_walls_doors_v3_8x.png`
- `D:/CSYE 7370/downfall-godot/godot_assets/lappland_combat_64.png`
- `D:/CSYE 7370/downfall-godot/art/field/props_v1.png`

```text
Professional LOW RESOLUTION game pixel sprites, Rhodes Island industrial ship base, true transparent RGBA background, 1 logical px near-black outline, steel gray flat chunky clusters, upper-left light, subtle worn metal. No gradients, bloom, text, labels, dimension marks, people, background or drop shadow unless explicitly requested. DO NOT produce polished high-resolution painted concept art. Need deliberately small native-pixel artwork with hard uniform square pixels. Palette only #0b0c0d #15181a #1f2427 #2c3236 #3d4448 #566064 #737d82 #98a2a6 #c3cacc #a9b2b3 #d4dadb #eef2f2 #6b5a1e #b89a2a #f4d73c #6e2f14 #b8531f #e0782a #0f3a40 #2a8a92 #5fd0d8 #b8f4f6 #5a4428 #c89a5a #f1d9a6 #8a1f1f. REDRAW image1 to new proportions; references2/3 only pixel style and character scale. Target canvas256x192 logical, output2048x1536 at exact8x. 4 columns x3 rows, each64x64 logical cell. Do not maximize or auto-fit objects; leave transparent margins. Row1: (1) horizontal tileable straight wall60x46 logicalpx: 4px top cap,40px front vertical face,2px baseboard. Straight RECTANGULAR continuous matching left/right ends, absolutely no end pillars, neon strips or protrusions. (2) separate narrow6x46 rib. (3) inner corner, (4) outer corner: strictly AXIS ALIGNED L-SHAPED TOP-CAP TURNS. Horizontal cap turns90degrees into vertical top-down6px-wide cap. E-W40px face below horizontal cap ends bluntly at corner. NO diamond tops, diagonal V-pillars, diagonal faces, isometric blocks, yaw, or perspective sidewalls. Row2: (1-3) open/closed/sealed chamfered-octagon doors, ALL outer frame45px wide x46px tall. Door opening must be tall: minimum32px WIDTH x36px HEIGHT rectangular unobstructed clear hole, transparent inside open door, very thin6px side jambs, narrow header. This is a near-square doorway overall, not previous squat wide doorway. Closed and sealed identical outline. Sealed has yellow-black tape and one tiny red lamp. (4) end cap. Row3:(1) ONLY flat overhead vertical wall strip60px long,6px metal width consisting of1 bright-edge+4 cap+1 dark-edge, plus2px opaque dark contact shadow on RIGHT, total8px width.(2) same vertical strip with a38px gap and6x6 post tops, narrow ground threshold in gap, matching2px contact shadow on right.(3-4) empty. Row3 entirely orthographic floor plan with no upright wall faces or perspective doors. Follow every logical dimension; the 40px vertical wall face now taller than30px reference character.
```

## console

- `D:/CSYE 7370/downfall-godot/art/rhodes/source_batch1_v2/rhodes_console_source_v2.png`
- `D:/CSYE 7370/downfall-godot/godot_assets/lappland_combat_64.png`
- `D:/CSYE 7370/downfall-godot/art/field/props_v1.png`

```text
Professional LOW RESOLUTION game pixel sprites, Rhodes Island industrial ship base, true transparent RGBA background, 1 logical px near-black outline, steel gray flat chunky clusters, upper-left light, subtle worn metal. No gradients, bloom, text, labels, dimension marks, people, background or drop shadow unless explicitly requested. DO NOT produce polished high-resolution painted concept art. Need deliberately small native-pixel artwork with hard uniform square pixels. Palette only #0b0c0d #15181a #1f2427 #2c3236 #3d4448 #566064 #737d82 #98a2a6 #c3cacc #a9b2b3 #d4dadb #eef2f2 #6b5a1e #b89a2a #f4d73c #6e2f14 #b8531f #e0782a #0f3a40 #2a8a92 #5fd0d8 #b8f4f6 #5a4428 #c89a5a #f1d9a6 #8a1f1f. REDRAW the console of image1 FROM SCRATCH AT SMALL NATIVE SCALE, do not merely shrink the tall cabinets. Keep design identity and three v2 pictograms: cyan crystal cluster, ruined city skyline, two conifer trees. Only one compact ON console in this image, OFF will be paired later. One sprite approximately90px wide x50px tall total, in a128x128 logical transparent canvas, output1024x1024 at8x. Anchor feet at logical y112, console x19..108,y63..112. This means large empty transparent margins; do not enlarge to fill canvas. A normal waist-high curved DESK with three compact widescreen monitors resting DIRECTLY ON ITS TOP via VERY SHORT desk-mounted stands, each only2-3px tall. A clearly visible substantial10px-high dark steel front fascia with vent details; a4px visible top surface; desk top14-15px above feet. So bottom15px of sprite is desk, not just a crushed line. Three monitors plus short desktop stands sit ABOVE desk taking remaining35px max. Monitors are compact and fairly squat, side displays angled slightly inward like v2. No poles running from the floor, no floor-mounted stalks, no tall side cabinets, no huge monitors over a paper thin desk. Composition is wider than tall: actual opaque sprite approximately90:50 aspect. Black outline, safety-orange side accents, tiny cyan control panel and1-2 cyan indicators. Pictograms must remain individually recognizable at native resolution: distinct crystal, city, and twin pines. Camera orthographic with slight top visible. Small readable 2-4px color clusters. Draw these proportions directly, no nonuniform scaling.
```

## console_retry

- `D:/CSYE 7370/downfall-godot/art/rhodes/source_batch1_v2/rhodes_console_source_v2.png`

```text
Redraw a single Rhodes Island dispatch desk inspired by reference, TRUE COARSE PIXEL ART sprite. Critical structural change: replace tall pedestal cabinets with a SHORT low front fascia. Wide object90 logical pixels across, overall50 logical pixels high. Desk top is at only14px above feet, consists of4px visible top surface above10px opaque front fascia. Desk front is solid chunky rectangle with vents and orange corner accent, clearly visible10px high. Three monitors are ON THE DESK with short2px feet, never from ground. Main display occupies upper35px, side displays slightly smaller, retain CRYSTAL, RUINED CITY, TWO PINE silhouettes from reference, no text. Make the desk front and top together ONLY THE BOTTOM28 PERCENT OF THE OBJECT height, not half. The screen upper region is72percent, and width-to-totalheight1.8. All screens remain physically resting on desktop despite large screen area. Orthographic no perspective vanishing point. Minimum mechanical detail. Native90x50 pixel sprite then uniform integer enlarged8x, completely transparent background, broad transparent margin. HARD SQUARE PIXELS, limited flat shades, no tiny texture details, no gradients or antialiasing. Three cyan screens, gunmetal body, cold grey tabletop, orange trim, nearblack outline. Only one ON console. Need correct proportions as drawn, will not fix by stretching sections.
```

## corners_retry



```text
A PIXEL ART GAME TILESET showing exactly TWO axis-aligned L-SHAPED WALL CORNER MODULES side-by-side on true transparent background. This is NOT ISOMETRIC. Imagine overhead floor-plan geometry: horizontal strip bends a RIGHT ANGLE into vertical strip. All straight edges perfectly HORIZONTAL OR VERTICAL in the image. The L-shape has6px-wide upright leg and4px-thick horizontal top-cap arm. First corner is a squared upper-right turn shaped like ┐; second is squared upper-left turn like ┌. Under each horizontal arm is a front-facing flat rectangular wall face40px tall with2px baseboard. That front face STOPS where the horizontal arm meets the vertical strip. No face under vertical leg. The vertical leg is ONLY a6px-wide top-down strip:1 bright edge+4 grey top+1 dark edge, plus2px contact shadow beside it. Grey wall cap, dark gunmetal rectangular flat wall face. No pillar, no V shape, no diamond, no diagonals, no angled roof, no perspective, no vanishing point, no 3D rendering. Plain simple flat2D square pixel blocks and dark outlines. Do not make 3D boxes. Each corner in64x64 logical cell, two cells horizontal, output1024x512 representing128x64 at8x. No labels or text, no dimension marks. Opaque material only in the L top and one rectangular hanging wall face, rest transparent.
```

## wall_retry



```text
One pixel art rectangular modular spaceship WALL PANEL, strictly frontal no yaw. Native60 pixels wide46 high, shown at8x integer enlargement with transparent margin. Exact construction TOP TO BOTTOM: flat light-gray cap4px, dark gunmetal vertical front face40px, thin baseboard2px. The front face is almost90 percent of total height! No thick cap. Rectangular60:46 proportions, nearly square, NOT A WIDE LOW WALL. Straight left/right cut ends matching so tiles repeat horizontally, absolutely no pillars, no end borders, no buttresses, no side faces, no perspective. Sparse large flat steel plates and restrained vertical panel joints,2-4px chunky wear, no many scratches. The top edge is perfectly horizontal, bottom edge perfectly horizontal. No colored accent bands, no neon or lamps. Coarse pixel art only,1px nearblack outline top and bottom but NO vertical black terminal borders. Use #0b0c0d #15181a #1f2427 #2c3236 #3d4448 #566064 #737d82 #98a2a6 #c3cacc. No gradients, no text, no numbers, no shadow outside sprite. Intended wall40px face taller than30px player. No surround or other props.
```

## doors_retry



```text
Pixel art game asset: THREE upright chamfered spaceship doorways in a row, open / closed / sealed. Transparent background. Each outer doorway EXACT45 logical pixels WIDE46 logical pixels HIGH. Near square or slightly TALLER than wide. Narrow SIDE JAMBS only6px wide, HEADER only7px tall, no threshold obstructing clear opening. Open doorway on left has LARGE TALL RECTANGULAR clear hole at least32px wide36px tall, transparent throughout; tiny chamfers only in outermost corners, must NOT cut into32x36 inner clearance. Upper header plaque blank. Space inside is nearly entire door, not a squat window. Each doorway same silhouette. Closed steel double panels, sealed panels plus yellow black hazard barrier and tiny red lamp. Dark steel pixel art with chunky gray bevels1px outlines and limited flat tones. Draw directly at native scale then8x enlarged. No perspective no side faces no hallway inside no text no other modules. Door sprite middle is intended for30px tall character; opening36px high. Each in64x64 cell, image1536x512 representing192x64 at8x.
```

## console_final_redraw

- `D:/CSYE 7370/downfall-godot/art/rhodes/batch1_v4/sources/console_redraw.png`

```text
Edit this console artwork while preserving the 3-monitor silhouette, distinct crystal/city/twin-pines pictograms, gray and orange industrial style, transparent background and overall framing. Re-DRAW ONLY the low desk base at the same total height, without stretching: shift the top/front boundary UP so the visible top surface is only about one quarter of the desk base height, and the opaque front fascia is about three quarters. Target at native approx90px wide: TOP SURFACE4px deep, FRONT FACE10px high,15px maximum from ground to top; currently the top is too deep and the front too shallow. Keep monitors and their SHORT desktop feet sitting on that surface. Preserve overall width:height aspect and monitor positions. The front must be a legible10px-high rectangular mechanical fascia with vents and orange corners, not a thin strip. Draw flat chunky pixel art, no gradients or subpixel details, black1px outlines. No text. Pure transparent background. One ON console only. No squashing or section scaling; change geometry by redrawing the worktop/front boundary. Use dark gunmetal and cold gray, safety orange, cyan screens.
```

