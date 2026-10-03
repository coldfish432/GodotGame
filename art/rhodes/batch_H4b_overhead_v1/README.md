# H4b overhead asset kit v1

Build with `python build_overhead.py`. Generated high-resolution originals and prompts are under `sources/`. The build uniformly reduces by integer factors, quantizes to the Rhodes 31-color palette, then repairs repeatable seams on the native grid. Exports are native PNGs and exact 8× review copies.

The 60×14 E–W I-beam tiles horizontally; the 14×60 N–S version is its exact native rotation. Use the 36×36 junction at a crossing and a separate 28×28 left/right wall bracket at each wall. Place the 6×14 yellow-black marker only on exposed ends, never between tiled straight sections. The orange-cable tray and medical curtain track are 60-px seam-matched segments.

The hoist trolley and hook are **two separate sprites**. `manifest.json` gives each `cable_socket_px`; draw a 1–2-px steel cable between those sockets at runtime and change its length as the hook moves. The composite shows one example cable, but no cable sprite is baked into either asset.

Render these sprites above objects and characters, with no collision. Suggested ceiling height offset is 40–60 px above the floor beneath a beam. When a character passes underneath, the engine may fade the ceiling layer to about 40% alpha. Route beams and trays above clear aisle bands so they do not cover main furniture or interaction markers. `H4b_overhead_lappland_1x.png` is a scale preview, not a room layout.
