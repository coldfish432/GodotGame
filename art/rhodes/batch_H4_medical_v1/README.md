# H4 medical asset kit v1

Build with `python build_medical.py` from any working directory. Generated high-resolution originals and their prompts are in `sources/`; `h4_kit.py` and `h3_source_pipeline.py` perform uniform integer nearest-neighbor reduction, 31-color CIELAB quantization, exact 8× exports, and validation. Native-grid work is confined to state lights, bottle draining, signs, the glass strip, and alignment to accepted H3 bed geometry.

The reception desk swaps idle/alert at the same anchor. The pharmacy shelf has three separately switchable bottle types A/B/C, each full/empty; these letters identify art variants only and do not prescribe potion mechanics. The shelf also includes all-full/all-empty convenience composites. `CONTAMINATION` and `WARD` signs use the accepted 5×7 glyphs. The contamination door lamp is green/red; the scanner and exam bed belong inside a separate room. The north–south glass partition has a 6-px cap plus 2-px contact shadow and a 38-px door-gap variant.

The ward bed preserves the accepted H3 53×34 shell in empty/occupied states. The occupied patient is anonymous and is not a new Lappland death pose. The accepted recovery bed remains the wake-up point. The two staff stand spots are left empty for later recruitment content. Use the H3 medical white wall and floor and its approved life details as the room shell.

`manifest.json` lists sizes, anchors, state groups, emits, source hashes, and accepted dependencies. `H4_medical_lappland_1x.png` is a scale/composition review, not a room layout. Its `_4x` copy is nearest-neighbor only. Final scene assembly remains with the user.
