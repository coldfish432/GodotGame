# H4 warehouse asset kit v2

Build with `python build_warehouse.py` from any working directory. Generated high-resolution originals and their prompts are in `sources/`; `h4_kit.py` and `h3_source_pipeline.py` provide uniform integer nearest-neighbor reduction, 31-color CIELAB quantization, exact 8× exports, and validation. Furniture and equipment are image-generated. Slot overlays, category icons, rack IDs, order-card state details, and floor markings are native-grid graphics.

Use the accepted H2 wall, floor, weapon/armor/material racks, terminal, forklift, and counter directly. Retire the H2 **consumables** rack and zone, and use the new **TRINKET** rack and zone. The small items have no S logo. `warehouse_shelf_slot_empty_12x12.png` and `warehouse_shelf_slot_filled_12x12.png` have the same bounds; place them at top-left positions `(12,10) (27,10) (42,10) (57,10)`, repeat at y=27 and y=44 in an 80×64 rack. Each can be switched independently. Rack head plates `A1`–`D2` identify the four categories and two rows.

The trinket rack header now reads **B1-03-C** in the accepted 5×7 font. Open-crate source art has been redrawn with a raised lid and a broad dark cavity; the first H4 originals remain in `sources/previous_v1/`. Sealed/open pairs still share their bottom-center state box.

Crates have small/medium/large sizes and sealed/open states, bottom-center aligned per size. The open state shows an empty cavity; gameplay supplies revealed item art separately. Numbered receiving-bay decals `R01`–`R06` are examples; the final slot count is gameplay data. Carry frame is 22×22 above the character; the matching 14×14 category icon goes at offset `(4,4)`. The category zone frame switches from normal to highlight for the carried class. The order board switches among open, completed, and empty states; the trolley has accepted empty and matching 42×34 loaded states.

`manifest.json` lists native sizes, anchors, state groups, emits, source hashes, and accepted dependencies. `H4_warehouse_lappland_1x.png` is a scale/composition review, not a room layout. Its `_4x` copy is nearest-neighbor only. Final scene assembly remains with the user.
