# Batch H5 — Rhodes Island base: warehouse and medical gameplay parts

Hi Sol. This batch covers the art the base's new gameplay still lacks. Everything else these systems need already exists and has been accepted (yellow interaction marker, pharmacy shelf and flask states, scan-gate lamps, crates, zone frames, cargo drone). Please do not redraw those.

## Delivery

- Folder: `art/rhodes/batch_H5_v1/`
- `manifest.json` in the same format as `batch_H4_warehouse_v2/manifest.json`: one entry per asset with `id`, `file`, `size`, `anchor_px`.
- A `validation.txt` with your own checks. We re-verify everything independently.

## Rules (same as every batch)

1. **Locked palette only.** Use exactly the colours in `art/rhodes/pixel_kit.py` (`COLORS`). No new colours, no anti-aliasing, no gradients.
2. **Binary alpha.** Every pixel is either fully opaque or fully transparent.
3. **Native pixel size.** Draw at the exact sizes below. No upscaling and downscaling, no soft resampling.
4. **Same camera as all accepted art.** Orthographic 3/4 top-down view, looking straight ahead. Nothing rotated or skewed.
5. **Match the accepted style.** Look at the H2/H4 warehouse parts and the H3/H4 medical parts: dark steel, 1 px dark outlines, yellow-black hazard trim, small cyan and amber accents.
6. **Do not modify any accepted file.**

## Reference images (attached)

- `evidence/rhodes-engine/b2-receiving.png`, `b2-carrying.png`: the warehouse floor in-engine, showing scale, the floor grid and the existing zone frames.
- `evidence/rhodes-engine/b5-new-racks.png`: racks standing in the engine.
- `evidence/rhodes-assembly/shelf_hatch_frames_8x.png`: **my placeholder hatch**, shown 8× (closed → open). Replace it; match its layout rules below.
- The accepted racks: `batch_H2_warehouse_v2/warehouse_rack_{weapons,armor,materials}_80x64.png` and `batch_H4_warehouse_v2/warehouse_rack_trinket_80x64.png`.

---

## 1. Shelf floor hatch — highest priority

When Lappland enters the warehouse, the lights come on bank by bank and a hatch in the floor under each personal-storage rack slides open. The rack then rises slowly out of the slot. The engine runs this today with a placeholder; this is the real art.

| id | size | anchor_px |
|---|---|---|
| `warehouse_shelf_hatch_closed_84x18` | 84×18 | [42, 17] |
| `warehouse_shelf_hatch_open_84x18` | 84×18 | [42, 17] |

- **Closed:** a flush steel floor plate, slightly darker than the warehouse floor, with two small recessed lift points. It must read as part of the floor, not as an object lying on it.
- **Open:** the same footprint with the cover gone. The inside is a near-black slot. One row of warm amber light (`O2`, with `O0` above it) runs along the **front lip**, and guide rails show at both ends.
- **Layout rules.** The engine slides the cover open itself in 6 frames, so these must hold exactly:
  - **Rows 0–1 and 16–17** are a yellow-black hazard edge (`Y2`/`K`), **identical in both states**.
  - **Columns 0–3 and 80–83** are the end frame (1 px outline + 3 px rail), **identical in both states**. The cover halves slide under these.
  - The cover splits on a vertical seam **at x = 42**. Draw the closed cover so the left half (x 4–41) and right half (x 42–79) each look complete on their own.
  - In the open state, put the amber lip on **row 15** (directly above the bottom hazard edge). The rack's bottom edge rises from that line.
- The rack is 80 px wide, so the hatch shows 2 px of frame on each side of it.

## 2. Rack fill states — 4 categories × 2 new states

Only the front row of racks shows individual cells. The middle and back rows are hidden behind it, so each rack shows how full it is through its own picture. The accepted racks already look full, so they are the **full** state. Please draw **empty** and **half**.

| id | size | anchor_px | based on |
|---|---|---|---|
| `warehouse_rack_weapons_empty_80x64` | 80×64 | [40, 63] | `warehouse_rack_weapons_80x64` |
| `warehouse_rack_weapons_half_80x64` | 80×64 | [40, 63] | 〃 |
| `warehouse_rack_armor_empty_80x64` | 80×64 | [40, 63] | `warehouse_rack_armor_80x64` |
| `warehouse_rack_armor_half_80x64` | 80×64 | [40, 63] | 〃 |
| `warehouse_rack_trinket_empty_80x64` | 80×64 | [40, 63] | `warehouse_rack_trinket_80x64` |
| `warehouse_rack_trinket_half_80x64` | 80×64 | [40, 63] | 〃 |
| `warehouse_rack_materials_empty_80x64` | 80×64 | [40, 63] | `warehouse_rack_materials_80x64` |
| `warehouse_rack_materials_half_80x64` | 80×64 | [40, 63] | 〃 |

- **The frame must be pixel-identical to the accepted rack:** posts, shelves, feet, and the top plate with its letter (`B1-03-A` to `D`). Only the stored goods change. We will diff the frame pixels.
- **Empty:** bare shelves. You may add one or two small details so it doesn't look broken, such as a price tag or a strap on a shelf, but no goods.
- **Half:** about half the goods of the full state, spread across both shelves rather than packed on one side.

## 3. Two blank plates

The numbers are printed on them by the engine using the existing 5×7 glyphs, so leave the text field empty.

| id | size | anchor_px | purpose |
|---|---|---|---|
| `warehouse_zone_counter_plate_36x12` | 36×12 | [18, 11] | beside each zone's rack head plate, shows `14/36` |
| `warehouse_overflow_plate_24x12` | 24×12 | [12, 11] | beside the overflow crates at receiving, shows `+N` |

- Same style as `small_number_plate_B1_03` (dark plate, light outline, yellow top strip).
- Leave a clear field inside: **30×7 px** for the counter plate and **18×7 px** for the overflow plate, vertically centred, plain plate colour.

## 4. Staging area floor frame

Staging is an unsorted holding area next to receiving, holding roughly three full hauls. Its floor currently uses my palette-dash placeholder (visible in `b2-staging.png`).

| id | size | anchor_px |
|---|---|---|
| `warehouse_zone_staging_90x44` | 90×44 | [45, 43] |

- Same construction as `warehouse_zone_weapon_normal_90x44` (dashed frame on the floor), so tiles can sit side by side to make a larger area.
- Colour: **neutral light grey or white dashes** (`G2` / `W1`), clearly different from the four category colours.
- Label `STAGING` in the frame's bottom-left corner. Leave the top half empty: pallets with crates stand there and would cover it.
- No category icon.

## 5. Recovery bed, occupied

After a death, Lappland wakes on the central recovery bed. For about a second the bed shows someone lying in it, then she is standing beside it.

| id | size | anchor_px | based on |
|---|---|---|---|
| `medical_recovery_bed_occupied` | 62×32 | same as `medical_recovery_bed` | `batch_H3_medical_v4/medical_recovery_bed.png` |

- The bed frame, monitor and wheels must be **pixel-identical** to the accepted bed. Only the mattress area changes.
- Show the blanket raised over a body, with a little silver-white hair on the pillow (Lappland's hair colour, `W1`/`W2`). Keep the face unreadable at this size: no eyes, no features.

---

## Acceptance checklist (we check each item)

- [ ] All 14 files present, sizes and anchors exactly as listed, `manifest.json` matches.
- [ ] Palette: every opaque pixel is a `pixel_kit.COLORS` colour.
- [ ] Alpha: binary.
- [ ] Hatch: rows 0–1 and 16–17 plus columns 0–3 and 80–83 identical between closed and open; seam at x = 42; amber lip on row 15.
- [ ] Rack states and bed: frame pixels identical to the accepted originals.
- [ ] Plates: text fields left blank at the stated size.
- [ ] Staging frame: tiles cleanly side by side; label in the bottom-left only.
- [ ] Nothing accepted was modified.
