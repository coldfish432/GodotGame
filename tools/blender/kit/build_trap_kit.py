"""Traps, vault walls and operator traces: art/kit/trap_<region>_<kind>.glb,
vault_wall_<region>.glb, trace_<operator>.glb (密室与陷阱修订案_v1 §2, 干员寻访
策划案 §13; 用户 2026-10-17).

- Traps are small and low, to be seen only if looked for (看得见但不显眼): each
  region's own kind, heavy (a blow from above or below) and light.
- A vault wall is a 2 m length, along x, centred, its lane side facing -Y
  (Godot +Z); VaultSeal lays as many as the mouth needs. Each carries the one
  tell, a crack down its face.
- A trace is one operator's own small thing at a dead end, about a metre.

Blender Z up, metres; origin at the bottom centre. Through the MCP add-on:

    import build_trap_kit as k; k.build("trap_mine_heavy")
"""
import math
import os
import random
import sys

sys.path.append(os.path.dirname(__file__))
import bpy  # noqa: E402
import kit_common as kit  # noqa: E402
import poi_detail as d  # noqa: E402
import build_city_kit as city  # noqa: E402
from build_city_kit import lit, steel  # noqa: E402
from build_siracusa_kit import iron, new_scene, render, stone, tiles, wood  # noqa: E402


def flat(name, hex_rgb, darker=None, scale=6.0):
    return kit.flat_material(name, hex_rgb, scale if darker else 0.0, darker)


def rough_rock(name, radius, location, seed, squash=(1.0, 1.0, 0.7)):
    obj = kit.rock(name, radius, location, squash, subdivisions=2)
    kit.roughen(obj, seed, radius * 0.25, radius * 0.8, subdiv=1)
    return obj


def crack(prefix, x, y, z0, z1, wiggle=0.12):
    """A zigzag crack down a face at y, as thin dark slivers."""
    out = []
    steps = 6
    px, pz = x, z1
    random.seed(hash(prefix) & 0xffff)
    for k in range(steps):
        nz = z1 - (z1 - z0) * (k + 1) / steps
        nx = x + random.uniform(-wiggle, wiggle)
        length = math.hypot(nx - px, nz - pz)
        angle = math.atan2(nx - px, nz - pz)
        out.append(kit.box(f"{prefix}{k}", (0.035, 0.03, length + 0.02), ((px + nx) / 2, y, (pz + nz) / 2), (0, angle, 0)))
        px, pz = nx, nz
    return out


# --- Traps ----------------------------------------------------------------------

def trap_mine_heavy(seed=1201):
    """落石: fresh rockfall on the floor, a ring of loose stones round a
    cracked patch, the warning that more is coming down."""
    random.seed(seed)
    rocks = []
    for k in range(9):
        a = k / 9 * math.tau + random.uniform(-0.2, 0.2)
        r = random.uniform(0.7, 1.15)
        rocks.append(rough_rock(f"r{k}", random.uniform(0.12, 0.24), (math.cos(a) * r, math.sin(a) * r, 0.06), seed + k))
    rocks.append(rough_rock("big", 0.3, (0.2, -0.1, 0.1), seed + 20, (1.2, 1.0, 0.6)))
    cracks = []
    for k in range(5):
        a = k / 5 * math.tau
        cracks.append(kit.box(f"c{k}", (0.9, 0.05, 0.02), (math.cos(a) * 0.45, math.sin(a) * 0.45, 0.005), (0, 0, a)))
    return [(kit.join(rocks, "rock"), stone("trap_mine_heavy_rock_p", seed, "6e6252"), "rock"),
            (kit.join(cracks, "crack"), flat("trap_mine_heavy_crack_p", "151210"), "crack")]


def trap_mine_light(seed=1203):
    """捕兽夹: an iron jaw trap, open, on its chain."""
    jaws, chain = [], []
    for s in (-1, 1):
        for k in range(7):
            x = -0.3 + k * 0.1
            jaws.append(kit.box(f"t{s}{k}", (0.03, 0.05, 0.07), (x, s * 0.2, 0.06), (s * 0.4, 0, 0)))
        jaws.append(kit.box(f"bar{s}", (0.66, 0.04, 0.03), (0, s * 0.18, 0.025)))
    jaws.append(d.cyl("plate", 0.1, 0.02, (0, 0, 0.02), vertices=12))
    jaws.append(kit.box("spring", (0.9, 0.06, 0.03), (0, 0, 0.02)))
    for k in range(5):
        chain.append(d.cyl(f"l{k}", 0.03, 0.015, (0.5 + k * 0.07, 0.05 * (k % 2), 0.01), vertices=8))
    return [(kit.join(jaws, "iron"), steel("trap_mine_light_iron_p", seed, "4a4640"), "iron"),
            (kit.join(chain, "chain"), iron("trap_mine_light_chain_p", seed), "chain")]


def trap_city_heavy(seed=1205):
    """松动的井盖: a manhole cover tipped in its frame over the drop, its rim
    broken, a dark gap showing."""
    frame = [kit.box("fx0", (0.12, 1.1, 0.06), (0.5, 0, 0.03)), kit.box("fx1", (0.12, 1.1, 0.06), (-0.5, 0, 0.03)),
              kit.box("fy0", (1.1, 0.12, 0.06), (0, 0.5, 0.03)), kit.box("fy1", (1.1, 0.12, 0.06), (0, -0.5, 0.03))]
    lid = [d.cyl("lid", 0.42, 0.05, (0.06, 0.04, 0.05), (0.12, 0.05, 0), vertices=20)]
    for k in range(4):
        lid.append(kit.box(f"g{k}", (0.6, 0.03, 0.012), (0.06, -0.18 + k * 0.12, 0.085), (0.12, 0.05, 0)))
    hole = [kit.box("hole", (0.9, 0.9, 0.01), (0, 0, 0.01))]
    return [(kit.join(frame, "frame"), steel("trap_city_heavy_frame_p", seed, "50504c"), "frame"),
            (kit.join(lid, "lid"), steel("trap_city_heavy_lid_p", seed + 1, "3e3e3a"), "lid"),
            (kit.join(hole, "hole"), flat("trap_city_heavy_hole_p", "080808"), "hole")]


def trap_city_light(seed=1207):
    """漏电的电缆: a cut cable lying across the ground, its frayed end
    sparking (the spark is lit)."""
    cable = []
    for k in range(8):
        cable.append(d.cyl(f"c{k}", 0.035, 0.22, (-0.8 + k * 0.2, 0.06 * math.sin(k), 0.035), (0, math.pi / 2, 0.15 * math.cos(k)), vertices=8))
    copper = [kit.box(f"w{k}", (0.12, 0.01, 0.01), (0.82 + 0.05 * k, 0.03 * (k - 1), 0.04), (0, 0, 0.5 * (k - 1))) for k in range(3)]
    spark = [kit.rock("spark", 0.06, (0.95, 0.0, 0.06), subdivisions=1)]
    return [(kit.join(cable, "cable"), flat("trap_city_light_cable_p", "1a1a1a", "0e0e0e"), "cable"),
            (kit.join(copper, "copper"), flat("trap_city_light_copper_p", "b06a30"), "copper"),
            (kit.join(spark, "glow"), lit("trap_city_light_glow_p"), "glow")]


def trap_snow_heavy(seed=1209):
    """薄冰: a patch of thin grey-blue ice over water, cracked from its middle."""
    ice = [d.cyl("ice", 1.1, 0.02, (0, 0, 0.01), vertices=18)]
    cracks = []
    for k in range(7):
        a = k / 7 * math.tau + 0.3
        cracks.append(kit.box(f"c{k}", (1.0, 0.025, 0.012), (math.cos(a) * 0.5, math.sin(a) * 0.5, 0.025), (0, 0, a)))
    return [(kit.join(ice, "ice"), flat("trap_snow_heavy_ice_p", "7f97a6", "5f7786", 3.0), "ice"),
            (kit.join(cracks, "crack"), flat("trap_snow_heavy_crack_p", "d8e6ee"), "crack")]


def trap_snow_light(seed=1211):
    """冰刺: a few short ice spikes through the snow."""
    random.seed(seed)
    spikes = []
    for k in range(6):
        a = k / 6 * math.tau + random.uniform(-0.3, 0.3)
        r = random.uniform(0.1, 0.45)
        bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.08, radius2=0.0, depth=random.uniform(0.18, 0.32),
                                        location=(math.cos(a) * r, math.sin(a) * r, 0.1), rotation=(random.uniform(-0.25, 0.25), random.uniform(-0.25, 0.25), 0))
        spikes.append(bpy.context.object)
    return [(kit.join(spikes, "ice"), flat("trap_snow_light_ice_p", "c4dce8", "8fb0c2", 4.0), "ice")]


def trap_siracusa_heavy(seed=1213):
    """松动的石板: one paving slab sunk at a tilt over a dark gap (a pit)."""
    slab = [d.bbox("slab", (1.0, 0.7, 0.08), (0.04, 0.02, 0.0), (0.06, -0.05, 0.1), width=0.02)]
    gap = [kit.box("gap", (1.12, 0.82, 0.01), (0, 0, 0.004))]
    return [(kit.join(slab, "stone"), stone("trap_siracusa_heavy_stone_p", seed, "a69a82"), "stone"),
            (kit.join(gap, "hole"), flat("trap_siracusa_heavy_hole_p", "0a0908"), "hole")]


def trap_siracusa_light(seed=1215):
    """绊线: a wire at ankle height between two iron pegs."""
    pegs = [d.cyl(f"p{s}", 0.025, 0.24, (s * 0.7, 0, 0.12), vertices=8) for s in (-1, 1)]
    wire = [d.cyl("wire", 0.006, 1.4, (0, 0, 0.16), (0, math.pi / 2, 0), vertices=6)]
    return [(kit.join(pegs, "iron"), iron("trap_siracusa_light_iron_p", seed), "iron"),
            (kit.join(wire, "wire"), flat("trap_siracusa_light_wire_p", "8a8a86"), "wire")]


# --- Vault walls ------------------------------------------------------------------

def vault_wall_mine(seed=1221):
    """塌方: a 2 m length of fallen rock heaped to 1.8 m across the lane, a
    timber prop crushed in it; the crack is a split down the big face."""
    random.seed(seed)
    rocks = [rough_rock("core", 1.0, (0, 0, 0.6), seed, (1.05, 0.75, 0.95))]
    for k in range(7):
        rocks.append(rough_rock(f"r{k}", random.uniform(0.25, 0.45), (random.uniform(-0.9, 0.9), random.uniform(-0.7, -0.4), random.uniform(0.15, 0.9)), seed + k))
    beam = [d.bbox("beam", (0.16, 0.16, 1.9), (0.5, -0.55, 0.7), (0.0, 0.9, 0.2), width=0.015)]
    gap = crack("crack", -0.2, -0.82, 0.2, 1.5)
    return [(kit.join(rocks, "rock"), stone("vault_wall_mine_rock_p", seed, "5e5446"), "rock"),
            (kit.join(beam, "wood"), wood("vault_wall_mine_wood_p", seed), "wood"),
            (kit.join(gap, "crack"), flat("vault_wall_mine_crack_p", "0c0a08"), "crack")]


def vault_wall_snow(seed=1223):
    """冰封: fallen rock under packed snow and ice across the lane, 1.6 m."""
    random.seed(seed)
    rocks = [rough_rock("core", 1.0, (0, 0, 0.5), seed, (1.05, 0.75, 0.85))]
    for k in range(5):
        rocks.append(rough_rock(f"r{k}", random.uniform(0.25, 0.4), (random.uniform(-0.9, 0.9), random.uniform(-0.7, -0.4), random.uniform(0.15, 0.6)), seed + k))
    snow = [rough_rock("cap", 0.95, (0, 0.05, 1.05), seed + 30, (1.1, 0.8, 0.35))]
    gap = crack("crack", 0.25, -0.8, 0.2, 1.3)
    return [(kit.join(rocks, "rock"), stone("vault_wall_snow_rock_p", seed, "5d6670"), "rock"),
            (kit.join(snow, "snow"), flat("vault_wall_snow_snow_p", "dfe8ee", "b9c8d2", 4.0), "snow"),
            (kit.join(gap, "crack"), flat("vault_wall_snow_crack_p", "0c0e10"), "crack")]


def vault_wall_siracusa(seed=1225):
    """封死的门洞: a 2 m length of rendered wall, 2.6 m high, terracotta-capped,
    with an old arched doorway bricked up in it (the tell: the bricks show
    through the render, and a crack runs down the infill)."""
    body = [d.bbox("wall", (2.0, 0.45, 2.5), (0, 0, 1.25), width=0.02)]
    arch = [kit.box("infill", (1.1, 0.06, 1.7), (0, -0.25, 0.85))]
    arch.append(d.cyl("head", 0.55, 0.06, (0, -0.25, 1.7), (math.pi / 2, 0, 0), vertices=16))
    trim = [kit.box(f"jamb{s}", (0.12, 0.08, 1.75), (s * 0.6, -0.26, 0.875)) for s in (-1, 1)]
    cap = [kit.box("cap", (2.02, 0.58, 0.1), (0, 0, 2.55)), d.cyl("ridge", 0.1, 2.02, (0, 0, 2.62), (0, math.pi / 2, 0), vertices=8)]
    gap = crack("crack", 0.15, -0.29, 0.3, 1.9, 0.08)
    return [(kit.join(body, "wall"), render("vault_wall_siracusa_wall_p", "cbb48e", seed, brick_share=0.05), "wall"),
            (kit.join(arch, "brick"), city._ramp_material("vault_wall_siracusa_brick_p", [(0.3, "6e3a28"), (0.6, "8a4a32"), (0.95, "a0603e")], 14.0, seed, 3.0), "brick"),
            (kit.join(trim, "trim"), stone("vault_wall_siracusa_trim_p", seed, "b8ab8e"), "trim"),
            (kit.join(cap, "roof"), tiles("vault_wall_siracusa_roof_p", seed), "roof"),
            (kit.join(gap, "crack"), flat("vault_wall_siracusa_crack_p", "100c0a"), "crack")]


def _shard(name, radius, location, seed):
    """A broken stone: angular and flat, not a pebble."""
    random.seed(seed)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=radius, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = (random.uniform(0.9, 1.4), random.uniform(0.7, 1.1), random.uniform(0.35, 0.55))
    obj.rotation_euler = (random.uniform(-0.3, 0.3), random.uniform(-0.3, 0.3), random.uniform(0, math.tau))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    for v in obj.data.vertices:
        v.co *= random.uniform(0.8, 1.15)
    return obj


def vault_tell_mine(seed=1231):
    """The mine's tell at a sealed vault (用户: 整体是一体的，但是能看出来): a
    spill of fresh fall at the foot of the face, paler than the old rubble
    round it (broken this year, not grimed), with a split prop timber in it.
    About 2 m along x, spilling towards -Y (the room); origin at the face's foot."""
    random.seed(seed)
    stones = []
    for k in range(16):
        x = random.uniform(-1.0, 1.0)
        y = -random.uniform(0.0, 0.9) * (1.0 - abs(x) * 0.4)
        r = random.uniform(0.07, 0.2) * (1.0 - abs(y) * 0.5)
        stones.append(_shard(f"s{k}", r, (x, y, r * 0.35), seed + k))
    for k in range(3):
        stones.append(_shard(f"b{k}", random.uniform(0.22, 0.3), (-0.6 + k * 0.6, 0.05, 0.12), seed + 40 + k))
    timber = [d.bbox("t0", (0.12, 0.12, 0.9), (0.35, -0.35, 0.1), (math.radians(80), 0, 0.5), width=0.012),
              d.bbox("t1", (0.1, 0.1, 0.5), (0.7, -0.1, 0.1), (math.radians(84), 0, -0.4), width=0.012)]
    return [(kit.join(stones, "rock"), stone("vault_tell_mine_rock_p", seed, "746a58"), "rock"),
            (kit.join(timber, "wood"), city._ramp_material("vault_tell_mine_wood_p", [(0.3, "6a5038"), (0.6, "8e6e4a"), (0.95, "b0905e")], 12.0, seed, 3.0), "wood")]


def _spill(prefix, seed, count, size, depth=0.9):
    """Shards spilled from the foot of an edge towards -Y (the room)."""
    random.seed(seed)
    out = []
    for k in range(count):
        x = random.uniform(-1.0, 1.0)
        y = -random.uniform(0.0, depth) * (1.0 - abs(x) * 0.4)
        r = random.uniform(size[0], size[1]) * (1.0 - abs(y) * 0.5)
        out.append(_shard(f"{prefix}{k}", r, (x, y, r * 0.35), seed + k))
    return out


def vault_tell_snow(seed=1233):
    """萨米: fresh fall at the foot of the bank, its broken faces still dark
    against the drift (snow has not settled on it yet), a skin of loose snow
    knocked down with it."""
    stones = _spill("s", seed, 14, (0.07, 0.2))
    for k in range(3):
        stones.append(_shard(f"b{k}", random.uniform(0.22, 0.3), (-0.6 + k * 0.6, 0.05, 0.12), seed + 40 + k))
    powder = []
    for k in range(4):
        powder.append(kit.rock(f"p{k}", random.uniform(0.18, 0.3), (random.uniform(-0.9, 0.9), random.uniform(-0.5, 0.0), 0.0), (1.4, 1.0, 0.25), subdivisions=2))
    return [(kit.join(stones, "rock"), stone("vault_tell_snow_rock_p", seed, "5a6068"), "rock"),
            (kit.join(powder, "snow"), flat("vault_tell_snow_snow_p", "d6e2ea", "b8c8d4", 4.0), "snow")]


def vault_tell_city(seed=1235):
    """龙门: broken brick and a cracked kerb slab at the foot of a wall that
    was bricked up in a hurry (fresh brick, not the street's grime)."""
    random.seed(seed)
    bricks = []
    for k in range(14):
        x = random.uniform(-1.0, 1.0)
        y = -random.uniform(0.0, 0.8)
        bricks.append(kit.box(f"b{k}", (random.uniform(0.12, 0.22), 0.1, 0.06), (x, y, 0.03 + random.uniform(0.0, 0.05)), (random.uniform(-0.3, 0.3), random.uniform(-0.3, 0.3), random.uniform(0, math.tau))))
    slab = [d.bbox("slab", (0.6, 0.4, 0.06), (0.3, -0.35, 0.03), (0.08, -0.05, 0.3), width=0.01)]
    return [(kit.join(bricks, "brick"), city._ramp_material("vault_tell_city_brick_p", [(0.3, "6a3a2a"), (0.6, "8a4c36"), (0.95, "a26248")], 14.0, seed, 3.0), "brick"),
            (kit.join(slab, "stone"), stone("vault_tell_city_stone_p", seed, "8a8a86"), "stone")]


def vault_tell_siracusa(seed=1237):
    """叙拉古: broken terracotta tile and lumps of fallen lime render at the
    foot of a wall, as where an old doorway was bricked in."""
    random.seed(seed)
    tiles_ = []
    for k in range(10):
        x = random.uniform(-1.0, 1.0)
        y = -random.uniform(0.0, 0.8)
        tiles_.append(kit.box(f"t{k}", (random.uniform(0.12, 0.2), random.uniform(0.08, 0.14), 0.02), (x, y, 0.02), (random.uniform(-0.3, 0.3), random.uniform(-0.3, 0.3), random.uniform(0, math.tau))))
    plaster = _spill("p", seed + 7, 9, (0.05, 0.12), 0.6)
    return [(kit.join(tiles_, "roof"), tiles("vault_tell_siracusa_roof_p", seed), "roof"),
            (kit.join(plaster, "wall"), flat("vault_tell_siracusa_wall_p", "cbb48e", "a8946e", 6.0), "wall")]


# --- Traces ---------------------------------------------------------------------
# 用户 2026-10-17 (太丑、太扎眼; 整体是一体的，但是能看出来): marks on the
# ground in the ground's own dark tones, low and small, each an operator's own
# (TracePoint adds the faint motes that show it from close by).

def _gash(prefix, length, width, location, angle, seed=0, pieces=((0.0, 0.36), (0.43, 0.8), (0.86, 1.0))):
    """A cut in the ground, flat: a sliver that tapers to nothing at both
    ends, ragged along its edges, broken where the blade skipped, with a few
    chips flung off it (用户 2026-10-17: 像一根棍子 — not a bar)."""
    from build_siracusa_kit import _mesh
    random.seed(seed + hash(prefix) % 997)
    x0, y0, z = location
    ca, sa = math.cos(angle), math.sin(angle)
    def at(u, v):
        return (x0 + ca * u - sa * v, y0 + sa * u + ca * v, z + 0.003)
    verts, faces = [], []
    steps = 14
    for start, end in pieces:
        base = len(verts)
        for k in range(steps + 1):
            t = start + (end - start) * k / steps
            # Widest a third of the way in, nothing at the cut's two ends.
            body = math.sin(math.pi * t) ** 0.7 * (1.0 - 0.35 * t)
            local = 1.0 - abs(2.0 * k / steps - 1.0) ** 3
            half = width * 0.5 * body * local * random.uniform(0.6, 1.25)
            u = (t - 0.5) * length
            wob = random.uniform(-0.25, 0.25) * width
            verts.append(at(u, wob + half))
            verts.append(at(u, wob - half))
        for k in range(steps):
            a = base + k * 2
            faces.append((a, a + 2, a + 3, a + 1))
    groove = [_mesh(f"{prefix}g", verts, faces)]
    chips = []
    for k in range(5):
        t = random.uniform(0.1, 0.9)
        u = (t - 0.5) * length
        v = random.choice((-1, 1)) * random.uniform(width * 0.8, width * 2.2)
        r = random.uniform(0.012, 0.03)
        c = at(u, v)
        chips.append(_mesh(f"{prefix}c{k}", [(c[0] + r, c[1], c[2]), (c[0] - r * 0.6, c[1] + r, c[2]), (c[0] - r * 0.4, c[1] - r * 0.9, c[2])], [(0, 1, 2)]))
    return groove, chips


def trace_hellagur(seed=1241):
    """赫拉格: one long sabre cut across the ground, clean and straight."""
    groove, chips = _gash("cut", 1.3, 0.07, (0, 0, 0), 0.35, seed)
    return [(kit.join(groove + chips, "cut"), flat("trace_hellagur_cut_p", "3e3328"), "cut")]


def trace_rosa(seed=1243):
    """早露: a crossbow bolt driven into the ground at a slant, half its shaft out."""
    bolt = [d.cyl("shaft", 0.012, 0.32, (0, 0, 0.09), (0.9, 0, 0.4), vertices=6)]
    vanes = [kit.box(f"v{k}", (0.004, 0.05, 0.04), (0.06 * math.sin(0.4), -0.12, 0.2), (0.9, 0, 0.4 + k * math.pi / 2)) for k in range(2)]
    return [(kit.join(bolt, "shaft"), flat("trace_rosa_shaft_p", "3a342c"), "shaft"),
            (kit.join(vanes, "vane"), flat("trace_rosa_vane_p", "6a6258"), "vane")]


def trace_hoshiguma(seed=1245):
    """星熊: a shield's scrape — a band of parallel scratches where something
    broad was dragged and braced."""
    scratches = []
    for k in range(6):
        scratches.append(kit.box(f"s{k}", (0.9 - abs(k - 2.5) * 0.08, 0.014, 0.005), (0.0, -0.15 + k * 0.06, 0.003), (0, 0, 0.12)))
    return [(kit.join(scratches, "scratch"), flat("trace_hoshiguma_scratch_p", "3a332c"), "scratch")]


def trace_lin(seed=1247):
    """林: the shards of a small teacup, a dark tea stain under them."""
    random.seed(seed)
    stain = [d.cyl("stain", 0.28, 0.004, (0, 0, 0.002), vertices=14)]
    shards = []
    for k in range(5):
        shards.append(kit.box(f"p{k}", (random.uniform(0.04, 0.08), random.uniform(0.03, 0.05), 0.01), (random.uniform(-0.18, 0.18), random.uniform(-0.15, 0.15), 0.008), (0.2, 0.1, random.uniform(0, math.tau))))
    return [(kit.join(stain, "stain"), flat("trace_lin_stain_p", "201a12"), "stain"),
            (kit.join(shards, "china"), flat("trace_lin_china_p", "8a857a"), "china")]


def trace_typhon(seed=1249):
    """提丰: the broken-off end of a hunting arrow in the ground, fletching up."""
    shaft = [d.cyl("shaft", 0.014, 0.22, (0, 0, 0.08), (0.35, 0.2, 0), vertices=6)]
    vanes = [kit.box(f"v{k}", (0.004, 0.06, 0.07), (0.02, -0.03, 0.17), (0.35, 0.2, k * math.pi / 2)) for k in range(2)]
    return [(kit.join(shaft, "shaft"), flat("trace_typhon_shaft_p", "4a3e30"), "shaft"),
            (kit.join(vanes, "vane"), flat("trace_typhon_vane_p", "6e665c"), "vane")]


def trace_santalla(seed=1251):
    """寒檀: a frost bloom on the ground, a six-armed star of rime."""
    arms = []
    for k in range(6):
        a = k / 6 * math.tau
        arms.append(kit.box(f"a{k}", (0.42, 0.03, 0.006), (math.cos(a) * 0.21, math.sin(a) * 0.21, 0.003), (0, 0, a)))
        for side in (-1, 1):
            b = a + side * 0.6
            arms.append(kit.box(f"t{k}{side}", (0.12, 0.02, 0.006), (math.cos(a) * 0.3 + math.cos(b) * 0.05, math.sin(a) * 0.3 + math.sin(b) * 0.05, 0.003), (0, 0, b)))
    return [(kit.join(arms, "rime"), flat("trace_santalla_rime_p", "8a9ca6"), "rime")]


def trace_texas(seed=1253):
    """德克萨斯: a crumpled snack wrapper, its red faded with dirt."""
    random.seed(seed)
    paper = []
    for k in range(4):
        paper.append(kit.box(f"w{k}", (0.16, 0.1, 0.015), (random.uniform(-0.06, 0.06), random.uniform(-0.06, 0.06), 0.012 + k * 0.008), (random.uniform(-0.5, 0.5), random.uniform(-0.5, 0.5), random.uniform(0, math.tau))))
    return [(kit.join(paper, "paper"), flat("trace_texas_paper_p", "6e2620", "4a1a16", 12.0), "paper")]


def trace_lappland(seed=1255):
    """拉普兰德: two cuts crossed on the ground, an X struck in passing."""
    g0, c0 = _gash("a", 0.9, 0.06, (0, 0, 0), 0.6, seed, ((0.0, 0.55), (0.62, 1.0)))
    g1, c1 = _gash("b", 0.9, 0.06, (0, 0, 0.001), -0.6, seed + 1, ((0.0, 0.4), (0.47, 1.0)))
    return [(kit.join(g0 + g1 + c0 + c1, "cut"), flat("trace_lappland_cut_p", "3a3632"), "cut")]


# --- Vault rooms (用户 2026-10-17: 密室做成房间的样子) ------------------------------
# Floor tiles 2 x 2 m (origin at the middle, top at z 0.03); wall panels 2 m
# along x, 2.4 m high, their room side facing -Y (Godot +Z), origin at the
# bottom of the room face's middle; furniture centred, its back to +Y.

def room_floor_mine(seed=1261):
    """坑道储藏间: worn floorboards over the rock."""
    boards = [d.bbox(f"b{k}", (2.0, 0.24, 0.03), (0, -0.88 + k * 0.25, 0.015), width=0.006) for k in range(8)]
    return [(kit.join(boards, "wood"), wood("room_floor_mine_wood_p", seed), "wood")]


def room_wall_mine(seed=1263):
    """Boarded rock: horizontal planks between squared posts, a cap beam."""
    planks = [d.bbox(f"p{k}", (1.84, 0.06, 0.28), (0, 0.03, 0.16 + k * 0.3), width=0.008) for k in range(7)]
    posts = [d.bbox(f"post{s}", (0.18, 0.2, 2.4), (s * 0.92, 0.0, 1.2), width=0.015) for s in (-1, 1)]
    posts.append(d.bbox("cap", (2.0, 0.22, 0.18), (0, 0.0, 2.3), width=0.015))
    return [(kit.join(planks, "wood"), wood("room_wall_mine_wood_p", seed), "wood"),
            (kit.join(posts, "beam"), city._ramp_material("room_wall_mine_beam_p", [(0.3, "3a2616"), (0.6, "5a3c22"), (0.95, "7a5432")], 12.0, seed, 3.0), "beam")]


def room_floor_snow(seed=1265):
    """猎人藏身处: split-log floor, the round side down."""
    random.seed(seed)
    logs = [d.bbox(f"l{k}", (2.0, 0.23, 0.03), (0, -0.88 + k * 0.25, 0.015), width=0.012) for k in range(8)]
    for k in range(8):
        logs.append(kit.box(f"seam{k}", (2.0, 0.02, 0.031), (0, -0.88 + k * 0.25 + 0.115, 0.0155)))
    return [(kit.join(logs, "wood"), wood("room_floor_snow_wood_p", seed), "wood")]


def room_wall_snow(seed=1267):
    """A wall of stacked logs, notched at the ends, frost on the top log."""
    logs = [d.cyl(f"l{k}", 0.15, 2.1, (0, 0.0, 0.15 + k * 0.29), (0, math.pi / 2, 0), vertices=10) for k in range(8)]
    frost = [kit.box("frost", (2.1, 0.32, 0.05), (0, 0.0, 2.32))]
    return [(kit.join(logs, "wood"), city._ramp_material("room_wall_snow_wood_p", [(0.3, "3e3226"), (0.6, "5e4c38"), (0.95, "7e6a50")], 10.0, seed, 3.0), "wood"),
            (kit.join(frost, "snow"), flat("room_wall_snow_snow_p", "d6e2ea"), "snow")]


def room_floor_city(seed=1269):
    """龙门的暗间: worn grey floor tiles, 0.5 m."""
    tiles_ = [d.bbox(f"t{x}{y}", (0.48, 0.48, 0.03), (-0.75 + x * 0.5, -0.75 + y * 0.5, 0.015), width=0.006) for x in range(4) for y in range(4)]
    return [(kit.join(tiles_, "tile"), stone("room_floor_city_tile_p", seed, "7c7e7a"), "tile")]


def room_wall_city(seed=1271):
    """Painted plaster over a dark tiled dado, a pipe along the top."""
    upper = [d.bbox("upper", (2.0, 0.2, 1.5), (0, 0.0, 1.65), width=0.01)]
    dado = [d.bbox("dado", (2.0, 0.22, 0.9), (0, -0.01, 0.45), width=0.01)]
    pipe = [d.cyl("pipe", 0.05, 2.0, (0, -0.16, 2.25), (0, math.pi / 2, 0), vertices=8)]
    return [(kit.join(upper, "wall"), flat("room_wall_city_wall_p", "8a9088", "6e746c", 3.0), "wall"),
            (kit.join(dado, "dado"), stone("room_wall_city_dado_p", seed, "3e4a48"), "dado"),
            (kit.join(pipe, "iron"), steel("room_wall_city_iron_p", seed, "4a4a46"), "iron")]


def room_floor_siracusa(seed=1273):
    """家族的地窖: terracotta floor tiles, 0.4 m, in a herringbone of rows."""
    tiles_ = []
    for x in range(5):
        for y in range(5):
            tiles_.append(d.bbox(f"t{x}{y}", (0.38, 0.38, 0.03), (-0.8 + x * 0.4, -0.8 + y * 0.4, 0.015), width=0.006))
    return [(kit.join(tiles_, "tile"), city._ramp_material("room_floor_siracusa_tile_p", [(0.3, "7a3a24"), (0.6, "9a5232"), (0.95, "b26a44")], 8.0, seed, 3.0), "tile")]


def room_wall_siracusa(seed=1275):
    """Lime render over a stone base, the render worn to brick in places."""
    upper = [d.bbox("upper", (2.0, 0.24, 1.8), (0, 0.0, 1.5), width=0.01)]
    base = [d.bbox("base", (2.0, 0.28, 0.6), (0, -0.02, 0.3), width=0.012)]
    return [(kit.join(upper, "wall"), render("room_wall_siracusa_wall_p", "cbb48e", seed, brick_share=0.12), "wall"),
            (kit.join(base, "stone"), stone("room_wall_siracusa_stone_p", seed, "9a8e76"), "stone")]


def room_shelf(seed=1277):
    """A tall shelf of planks on iron uprights, a few boxes and jars on it."""
    random.seed(seed)
    wood_ = [d.bbox(f"s{k}", (1.5, 0.42, 0.04), (0, 0, 0.2 + k * 0.55), width=0.006) for k in range(4)]
    irons = [d.bbox(f"u{x}{y}", (0.04, 0.04, 1.9), (x * 0.72, y * 0.18, 0.95), width=0.004) for x in (-1, 1) for y in (-1, 1)]
    goods = []
    for k in range(3):
        for j in range(random.randint(1, 3)):
            goods.append(d.bbox(f"g{k}{j}", (random.uniform(0.2, 0.32), 0.3, random.uniform(0.15, 0.32)), (-0.5 + j * 0.42 + random.uniform(-0.05, 0.05), 0, 0.22 + k * 0.55 + 0.12), width=0.01))
    return [(kit.join(wood_, "wood"), wood("room_shelf_wood_p", seed), "wood"),
            (kit.join(irons, "iron"), iron("room_shelf_iron_p", seed), "iron"),
            (kit.join(goods, "box"), city._ramp_material("room_shelf_box_p", [(0.3, "5a4a36"), (0.6, "7a6646"), (0.95, "9a845c")], 10.0, seed, 3.0), "box")]


def room_crates(seed=1279):
    """Three crates stacked, the top one turned."""
    crates = d.plank_box("a", (0.8, 0.7, 0.6), (-0.3, 0, 0.3)) + d.plank_box("b", (0.7, 0.6, 0.55), (0.45, 0.05, 0.275)) + d.plank_box("c", (0.6, 0.55, 0.5), (0.0, 0.0, 0.85))
    return [(kit.join(crates, "wood"), wood("room_crates_wood_p", seed), "wood")]


def room_table(seed=1281):
    """A heavy table, a ledger and a strongbox on it."""
    table = [d.bbox("top", (1.4, 0.8, 0.07), (0, 0, 0.78), width=0.01)] + [d.bbox(f"l{x}{y}", (0.08, 0.08, 0.76), (x * 0.62, y * 0.32, 0.38), width=0.006) for x in (-1, 1) for y in (-1, 1)]
    things = [d.bbox("box", (0.4, 0.3, 0.25), (0.3, 0.05, 0.94), width=0.01), d.bbox("book", (0.3, 0.22, 0.05), (-0.3, -0.05, 0.84), (0, 0, 0.3), width=0.005)]
    return [(kit.join(table, "wood"), wood("room_table_wood_p", seed), "wood"),
            (kit.join(things, "iron"), steel("room_table_iron_p", seed, "4e4a44"), "iron")]


def room_lantern(seed=1283):
    """A standing lantern, its flame lit."""
    stand = [d.cyl("pole", 0.025, 1.5, (0, 0, 0.75), vertices=8), d.cyl("foot", 0.18, 0.04, (0, 0, 0.02), vertices=12),
             d.bbox("cage", (0.22, 0.22, 0.3), (0, 0, 1.6), width=0.01)]
    flame = [kit.rock("flame", 0.07, (0, 0, 1.6), (1.0, 1.0, 1.4), subdivisions=1)]
    return [(kit.join(stand, "iron"), iron("room_lantern_iron_p", seed), "iron"),
            (kit.join(flame, "glow"), lit("room_lantern_glow_p"), "glow")]


ROOMS = [room_floor_mine, room_wall_mine, room_floor_snow, room_wall_snow, room_floor_city, room_wall_city,
         room_floor_siracusa, room_wall_siracusa, room_shelf, room_crates, room_table, room_lantern]

# --- Field props that were code shapes (用户 2026-10-17: 掉落的藏品从几何体换成
# 建模，其他几何体代替的都换成建模) ---------------------------------------------

def _relic(prefix, seed, trim_hex, glow_hex, trim_mat):
    """A reliquary on the ground: a hexagonal plinth, a glass case and a
    crystal glowing inside it, a ring of trim at its waist. About 0.9 m."""
    plinth = [d.cyl("base", 0.34, 0.12, (0, 0, 0.06), vertices=6), d.cyl("step", 0.27, 0.08, (0, 0, 0.16), vertices=6)]
    trims = [d.cyl("ring", 0.24, 0.04, (0, 0, 0.42), vertices=6), d.cyl("cap", 0.22, 0.06, (0, 0, 0.72), vertices=6)]
    for k in range(6):
        a = k / 6 * math.tau
        trims.append(kit.box(f"rib{k}", (0.03, 0.03, 0.52), (math.cos(a) * 0.205, math.sin(a) * 0.205, 0.46)))
    glass = [d.cyl("glass", 0.2, 0.5, (0, 0, 0.45), vertices=6)]
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.08, radius2=0.0, depth=0.22, location=(0, 0, 0.55))
    top = bpy.context.object
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.08, radius2=0.0, depth=0.16, location=(0, 0, 0.36), rotation=(math.pi, 0, 0))
    bottom = bpy.context.object
    return [(kit.join(plinth, "stone"), stone(f"{prefix}_stone_p", seed, "4a4844"), "stone"),
            (kit.join(trims, "trim"), trim_mat, "trim"),
            (kit.join(glass, "glass"), flat(f"{prefix}_glass_p", "2a3440"), "glass"),
            (kit.join([top, bottom], "glow"), flat(f"{prefix}_glow_p", glow_hex), "glow")]


def relic_cache_vault(seed=1301):
    """密室藏品: gold-trimmed, an amber crystal."""
    return _relic("relic_cache_vault", seed, "c8a050", "ffc060", city._ramp_material("relic_cache_vault_trim_p", [(0.3, "7a5a20"), (0.6, "c09040"), (0.95, "e8c070")], 8.0, seed, 3.0))


def relic_cache_field(seed=1303):
    """战斗缴获: steel-trimmed, a blue crystal."""
    return _relic("relic_cache_field", seed, "8a9098", "7ab8ff", steel("relic_cache_field_trim_p", seed, "6a7078"))


def buff_device(seed=1305):
    """强化装置: a Rhodes field unit — a squared white casing on a dark base,
    a sloped panel, an orange core glowing in a slot down its face."""
    base = [d.bbox("base", (1.0, 0.8, 0.18), (0, 0, 0.09), width=0.02)]
    casing = [d.bbox("body", (0.7, 0.55, 1.05), (0, 0.05, 0.7), width=0.03),
              d.bbox("panel", (0.6, 0.3, 0.06), (0, -0.28, 0.95), (math.radians(-35), 0, 0), width=0.01)]
    stripe = [kit.box("stripe", (0.72, 0.57, 0.06), (0, 0.05, 1.12))]
    core = [kit.box("core", (0.14, 0.06, 0.62), (0, -0.23, 0.62))]
    return [(kit.join(base, "base"), steel("buff_device_base_p", seed, "3a3c3e"), "base"),
            (kit.join(casing, "body"), flat("buff_device_body_p", "d8dcdc", "b8bcbc", 4.0), "body"),
            (kit.join(stripe, "stripe"), flat("buff_device_stripe_p", "e07a20"), "stripe"),
            (kit.join(core, "glow"), flat("buff_device_glow_p", "ffa040"), "glow")]


def route_marker(seed=1307):
    """深入入口: a steel waypoint post on a footing, a sign-arm pointing on and a
    blue lamp on top."""
    footing = [d.bbox("foot", (0.6, 0.6, 0.2), (0, 0, 0.1), width=0.02)]
    post = [d.bbox("post", (0.14, 0.14, 2.0), (0, 0, 1.1), width=0.01), d.bbox("arm", (0.8, 0.06, 0.24), (0.38, 0, 1.75), width=0.01)]
    tip = [kit.box("tip", (0.17, 0.062, 0.17), (0.82, 0, 1.75), (0, math.radians(45), 0))]
    lamp = [d.cyl("lamp", 0.08, 0.14, (0, 0, 2.2), vertices=10)]
    return [(kit.join(footing, "stone"), stone("route_marker_stone_p", seed, "6a6a66"), "stone"),
            (kit.join(post + tip, "steel"), steel("route_marker_steel_p", seed, "4a5a6a"), "steel"),
            (kit.join(lamp, "glow"), flat("route_marker_glow_p", "70b8ff"), "glow")]


def poi_depot(seed=1309):
    """物资仓 (龙门): a wire-mesh cage on a pallet, cartons inside, hazard
    striping on its corner posts."""
    random.seed(seed)
    pallet = [d.bbox(f"pl{k}", (1.3, 0.16, 0.06), (0, -0.5 + k * 0.25, 0.12), width=0.005) for k in range(5)] + [d.bbox(f"r{k}", (0.1, 1.3, 0.1), (-0.55 + k * 0.55, 0, 0.05), width=0.005) for k in range(3)]
    posts = [d.bbox(f"p{x}{y}", (0.06, 0.06, 1.0), (x * 0.62, y * 0.62, 0.65), width=0.005) for x in (-1, 1) for y in (-1, 1)]
    mesh = []
    for side in range(4):
        for k in range(6):
            t = -0.6 + k * 0.24
            if side < 2: mesh.append(kit.box(f"m{side}{k}", (0.015, 0.015, 0.96), (t, (side * 2 - 1) * 0.62, 0.65)))
            else: mesh.append(kit.box(f"m{side}{k}", (0.015, 0.015, 0.96), (((side - 2) * 2 - 1) * 0.62, t, 0.65)))
    cartons = [d.bbox(f"c{k}", (random.uniform(0.35, 0.5), random.uniform(0.35, 0.5), random.uniform(0.25, 0.4)), (random.uniform(-0.3, 0.3), random.uniform(-0.3, 0.3), 0.3 + k * 0.3), (0, 0, random.uniform(-0.3, 0.3)), width=0.01) for k in range(3)]
    return [(kit.join(pallet, "wood"), wood("poi_depot_wood_p", seed), "wood"),
            (kit.join(posts, "stripe"), city._ramp_material("poi_depot_stripe_p", [(0.45, "141414"), (0.55, "e0b020")], 18.0, seed, 1.0), "stripe"),
            (kit.join(mesh, "steel"), steel("poi_depot_steel_p", seed, "6a6e70"), "steel"),
            (kit.join(cartons, "box"), city._ramp_material("poi_depot_box_p", [(0.3, "7a6446"), (0.6, "9a7e58"), (0.95, "b89a6e")], 10.0, seed, 3.0), "box")]


def heal_orb(seed=1311):
    """回血球: a small medical ampoule, its green fill glowing, steel caps."""
    caps = [d.cyl("c0", 0.055, 0.05, (0, 0, 0.025), vertices=10), d.cyl("c1", 0.055, 0.05, (0, 0, 0.255), vertices=10)]
    fill = [d.cyl("fill", 0.045, 0.18, (0, 0, 0.14), vertices=10)]
    return [(kit.join(caps, "steel"), steel("heal_orb_steel_p", seed, "9aa0a4"), "steel"),
            (kit.join(fill, "glow"), flat("heal_orb_glow_p", "7ae8a0"), "glow")]


PROPS = [relic_cache_vault, relic_cache_field, buff_device, route_marker, poi_depot, heal_orb]

TRAPS = [trap_mine_heavy, trap_mine_light, trap_city_heavy, trap_city_light, trap_snow_heavy, trap_snow_light,
         trap_siracusa_heavy, trap_siracusa_light]
WALLS = [vault_wall_mine, vault_wall_snow, vault_wall_siracusa]
TELLS = [vault_tell_mine, vault_tell_snow, vault_tell_city, vault_tell_siracusa]
TRACES = [trace_hellagur, trace_rosa, trace_hoshiguma, trace_lin, trace_typhon, trace_santalla, trace_texas, trace_lappland]
BUILDERS = TRAPS + WALLS + TELLS + TRACES + ROOMS + PROPS
PREVIEW = {b.__name__: 2.6 for b in TRAPS + TRACES}
PREVIEW.update({b.__name__: 3.4 for b in WALLS + TELLS + ROOMS + PROPS})
BAKE_SIZE = {"rock": 512, "wall": 512, "brick": 256, "trim": 256, "roof": 256, "snow": 256}


def publish(name, parts):
    city.BAKE_SIZE.update(BAKE_SIZE)
    city.PREVIEW.update(PREVIEW)
    return city.publish(name, parts)


def build(name):
    builder = next(b for b in BUILDERS if b.__name__ == name)
    new_scene(name)
    return publish(name, builder())


def build_all():
    for builder in BUILDERS:
        build(builder.__name__)
