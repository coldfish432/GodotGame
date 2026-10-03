# H3b expansion v1

Asset kit for v2.0 section 2.4. No gameplay scene or blockout is included.
The 1x gallery is for scale and state review; the 4x gallery is exact pixel replication.

- `manifest.json`: every native asset, anchor, footprint, state assembly and emit mask.
- `H3b_expansion_lappland_1x.png`: native gallery with unchanged Lappland frame 0.
- `H3b_expansion_lappland_4x.png`: enlarged review.
- `validation.txt`: independent export, geometry and provenance checks.
- `sources/`: three generated originals and the exact built-in image-generation prompt set.

## Corridor dimensions and assembly

The principal straight module follows the east-west wings: 6 units long and
4 units deep. At 15 px/unit and 0.85 ground-Y scale, its floor is 90x51 px.
The north wall is 46 px (40 face + 4 cap + 2 baseboard); the optional south
top-cap occupies a further 6 px outside the clear floor. Thus the convenience
state images are 90x103. Repeat at X offsets of 90 px, not 103 px.

Layered floor, north wall, door socket and south cap are also included. Ground
pixels come from the accepted dark-steel floor with no resampling; the exported
90px repeat has matching end columns. The two states have identical dimensions.
The uncleared state is dimmed by palette steps and contains debris plus a warning.
The clearing overlay shares its origin; it adds two drones and a work lamp without
changing the corridor's traversal state. Collision/unlocking belongs to assembly.

The dead-end fence is a front-facing, 4-unit billboard. Its fence body is 60x46;
the optional UNCLEARED sign above it adds 12px. At an east-west world endpoint,
keep the sprite facing the camera and put the blocking collider across the actual
4-unit corridor. Do not rotate its art into an isometric side view.

## Locked room-slot doors

All three door images are byte-identical to batch 1 v5: 45x46, with the accepted
3px corner chamfers. Sealed already contains hazard tape and a red lamp. Built
uses the accepted normal door with a separately attached B1-05 number plate.

For empty slots, place `room_slot_empty_backing_32x36` at door-local [6,9],
then the transparent open door above it. The backing shows only the visible bare
floor and compact pending-build frame. It is decoration, not collision or an
alteration of the locked 32x36 opening. State assembly offsets are in the manifest.
Use `corridor_door_socket_90x46` and insert any door at [22,0]. Do not place a rib
directly next to the frame: the frame already serves as its own pillar.

The full pending-build decal is 90x51 with accepted 5x7 text. The compact 28x18
decal has a build-cross pictogram and no tiny generated lettering. All emit masks
align with their diffuse images. The optional work-light pool is the accepted H1
additive texture on opaque black, referenced by hash in the manifest.

## Sources and rebuild

Drone, work lamp and debris were generated individually with the built-in image
tool, then reduced uniformly by integer factors and quantized. Fence, warning,
floor frames and labels are native geometric modules. The accepted 40x40 tarp
print is pasted without scaling. There is one logo on each dead-end cap; keep the
whole assembled screen within the six-logo cap.

Run `python build_h3b.py`, then `python validate_h3b.py` from this folder.
The shared `../pixel_kit.py` and `../h3_source_pipeline.py` supply the accepted
palette, glyphs and uniform source-reduction helpers. Every asset has a native PNG
and exact 8x review export. Accepted H3 v4 assets are untouched.
