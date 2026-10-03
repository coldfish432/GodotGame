# Set-piece A — Repair Station calibration

Generated as one connected work area using the new Rhodes Island illustration target in spec v1.0.7: reference roles were `elite_2019` for the workshop, `office_2021` for the yellow/blue graphic language, `icu_2021` for clean banded light, and Lappland frame0 for scale. The attached field `scene_groups_v2` reference was not used.

`rhodes_repair_station_A_v1.png` is a native128×80 transparent sprite; opaque artwork is centered at124×57, with its feet baseline at70. The whole generated alpha-bounds image was reduced uniformly by integer12 and quantized to the specified29-color palette. No parts were separately resized. Binary alpha is used. The native sprite also has an exact8× inspection copy.

The group combines a low workbench, monitor and wrench pictogram, clamped sword, articulated arm reaching toward the blade, two stools, connected blue toolboard, stickers, yellow/blue wall band, yellow floor work-zone frame, and striped safety pedestal. Yellow and blue graphics and functional hazard markings account for the largest accent shares; the outline remains selective.

The room preview places this group against the accepted light wall/floor shell with Lappland frame0 at1:1 in the open foreground aisle: [native composite](equipment_bay_A_lappland_1x.png) · [4× composite](equipment_bay_A_lappland_4x.png).

The full group measurements in `validation.txt` include the graphic band, screen, hazard pedestal, and floor frame: mean display luma Y′=0.5098; near-black #0b0c0d=0.887%; orange0.120%; yellow8.153%; cyan2.350%; red0%; Rhodes blue11.799%; all accent ramps together22.422%. The total is reported without subtracting the graphic/signage/hazard exceptions in §3.1.1. No isolated equipment body is recolored or measured separately in this grouped illustration.

`prompt.txt` and the untouched imagegen source are included. `build_setpiece.ps1` records the generation-size reduction, palette mapping and composite layout. The output is a static art preview, not a Godot screenshot; set-pieces B and C have not been started.
