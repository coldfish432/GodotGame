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
# 用户 2026-10-22 (优化陷阱的表现形式和效果，可以换建模): each trap is built twice,
# armed (trap_<region>_<kind>) and sprung (…_sprung), which FieldTrap swaps in
# when it goes off. Armed they stay low and in the ground's tones, but each has
# one readable shape at game zoom (a toothed ring, a manhole, a bell on a wire);
# sprung they show what happened (the jaws shut, the lid thrown off, the ice
# broken into floes, rocks heaped where she stood).

def _cone(name, radius, depth, location, rotation=(0, 0, 0), vertices=6):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius, radius2=0.0, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    return obj


def _arc_flat(prefix, radius, a0, a1, n, width, height, z=0.0, centre=(0.0, 0.0)):
    """An arc of boxes lying in the ground plane."""
    out = []
    step = (a1 - a0) / n
    seg = 2.0 * radius * math.sin(abs(step) / 2.0) + 0.01
    for k in range(n):
        a = a0 + step * (k + 0.5)
        out.append(kit.box(f"{prefix}{k}", (seg, width, height), (centre[0] + math.cos(a) * radius, centre[1] + math.sin(a) * radius, z), (0, 0, a + math.pi / 2)))
    return out


def _arc_up(prefix, radius, a0, a1, n, width, thick, y=0.0, z=0.0):
    """An arc of boxes standing in the plane y (x across, z up)."""
    out = []
    step = (a1 - a0) / n
    seg = 2.0 * radius * math.sin(abs(step) / 2.0) + 0.01
    for k in range(n):
        a = a0 + step * (k + 0.5)
        out.append(kit.box(f"{prefix}{k}", (seg, width, thick), (math.cos(a) * radius, y, z + math.sin(a) * radius), (0, -(a + math.pi / 2), 0)))
    return out


def _blob(name, radius, z, seed, n=16, jitter=0.18, centre=(0.0, 0.0), squash=(1.0, 1.0)):
    """An irregular flat patch (one face) lying at height z."""
    from build_siracusa_kit import _mesh
    random.seed(seed)
    verts = []
    for k in range(n):
        a = k / n * math.tau
        r = radius * random.uniform(1.0 - jitter, 1.0 + jitter)
        verts.append((centre[0] + math.cos(a) * r * squash[0], centre[1] + math.sin(a) * r * squash[1], z))
    return _mesh(name, verts, [tuple(range(n))])


def _slab(name, points, z, thick, tilt=(0.0, 0.0, 0.0)):
    """A flat polygon (x, y points) with thickness, tilted about its centre."""
    from build_siracusa_kit import _mesh
    n = len(points)
    cx = sum(p[0] for p in points) / n
    cy = sum(p[1] for p in points) / n
    verts = [(x, y, z) for x, y in points] + [(x, y, z - thick) for x, y in points]
    faces = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))]
    for k in range(n):
        j = (k + 1) % n
        faces.append((k, k + n, j + n, j))
    obj = _mesh(name, verts, faces)
    obj.location = (0, 0, 0)
    import mathutils
    rot = mathutils.Euler(tilt).to_matrix().to_4x4()
    pivot = mathutils.Matrix.Translation((cx, cy, z))
    obj.data.transform(pivot @ rot @ pivot.inverted())
    return obj


def _cracks(prefix, seed, count, lengths, width, start, z=0.006):
    """Ragged cracks running out from round `start` metres off the middle,
    tapering, broken, each at its own angle (not spokes)."""
    random.seed(seed + 7)
    out = []
    for k in range(count):
        a = k / count * math.tau + random.uniform(-0.4, 0.4)
        length = random.uniform(*lengths)
        r = start + length * 0.5
        groove, chips = _gash(f"{prefix}{k}", length, width, (math.cos(a) * r, math.sin(a) * r, z), a + random.uniform(-0.35, 0.35), seed + k)
        out += groove + chips
    return out


def _chain(prefix, start, end, links=6):
    out = []
    for k in range(links):
        t = (k + 0.5) / links
        x = start[0] + (end[0] - start[0]) * t
        y = start[1] + (end[1] - start[1]) * t + 0.03 * math.sin(k * 1.7)
        out.append(d.cyl(f"{prefix}{k}", 0.028, 0.014, (x, y, 0.012), ((math.pi / 2) * (k % 2), 0, math.atan2(end[1] - start[1], end[0] - start[0])), vertices=8))
    return out


def _mine_pebbles(prefix, seed, count, r0, r1, size=(0.05, 0.12)):
    random.seed(seed)
    out = []
    for k in range(count):
        a = random.uniform(0, math.tau)
        r = random.uniform(r0, r1)
        s = random.uniform(*size)
        out.append(rough_rock(f"{prefix}{k}", s, (math.cos(a) * r, math.sin(a) * r, s * 0.4), seed + k, (1.0, 0.9, 0.6)))
    return out


def trap_mine_heavy(seed=1201):
    """落石: a fan of fresh grit and a cracked, sagging patch under a split
    roof prop — the prop lies broken across it, the warning that more is
    coming down."""
    grit = _mine_pebbles("g", seed, 16, 0.25, 1.15, (0.035, 0.08))
    prop = [d.bbox("prop0", (0.95, 0.13, 0.12), (-0.35, 0.55, 0.06), (0, 0.04, 0.35)),
            d.bbox("prop1", (0.55, 0.12, 0.11), (0.62, 0.32, 0.055), (0, -0.05, -0.5))]
    random.seed(seed)
    splinters = [kit.box(f"sp{k}", (0.14, 0.025, 0.02), (0.12 + random.uniform(-0.1, 0.1), 0.45 + random.uniform(-0.08, 0.08), 0.03), (0, 0, random.uniform(0, math.pi))) for k in range(4)]
    cracks = _cracks("c", seed, 5, (0.5, 0.85), 0.05, 0.1)
    return [(kit.join(grit, "rock"), stone("trap_mine_heavy_rock_p", seed, "6e6252"), "rock"),
            (kit.join(prop + splinters, "wood"), wood("trap_mine_heavy_wood_p", seed), "wood"),
            (kit.join(cracks, "crack"), flat("trap_mine_heavy_crack_p", "100d0b"), "crack")]


def trap_mine_heavy_sprung(seed=1301):
    """落石, come down: a heap of broken rock where the patch was."""
    random.seed(seed)
    heap = []
    for k in range(7):
        a = k / 7 * math.tau + random.uniform(-0.3, 0.3)
        r = random.uniform(0.35, 0.8)
        s = random.uniform(0.16, 0.28)
        heap.append(rough_rock(f"h{k}", s, (math.cos(a) * r, math.sin(a) * r, s * 0.45), seed + k, (1.1, 1.0, 0.65)))
    heap.append(rough_rock("top", 0.34, (0.05, -0.05, 0.16), seed + 30, (1.2, 1.05, 0.62)))
    grit = _mine_pebbles("g", seed + 50, 20, 0.6, 1.45, (0.03, 0.08))
    prop = [d.bbox("prop0", (0.5, 0.13, 0.12), (-0.95, 0.75, 0.06), (0, 0.05, 0.9)),
            d.bbox("prop1", (0.4, 0.12, 0.11), (1.05, 0.55, 0.055), (0, -0.05, -0.2))]
    dust = [_blob("dust", 1.35, 0.003, seed, 20, 0.22)]
    return [(kit.join(heap + grit, "rock"), stone("trap_mine_heavy_sprung_rock_p", seed, "786a58"), "rock"),
            (kit.join(prop, "wood"), wood("trap_mine_heavy_sprung_wood_p", seed), "wood"),
            (kit.join(dust, "dust"), flat("trap_mine_heavy_sprung_dust_p", "5a5044", "463e34", 6.0), "dust")]


def trap_mine_light(seed=1203):
    """捕兽夹: a round iron jaw trap set open flat, its teeth up, a pan in the
    middle, staked down by its chain."""
    r = 0.3
    iron_parts = _arc_flat("ja", r, -math.pi / 2, math.pi / 2, 9, 0.035, 0.03, 0.02) + _arc_flat("jb", r, math.pi / 2, math.pi * 1.5, 9, 0.035, 0.03, 0.02)
    teeth = []
    for side, (a0, a1) in enumerate(((-math.pi / 2, math.pi / 2), (math.pi / 2, math.pi * 1.5))):
        for k in range(8):
            a = a0 + (a1 - a0) * (k + 0.5) / 8
            teeth.append(_cone(f"t{side}{k}", 0.022, 0.07, (math.cos(a) * (r - 0.02), math.sin(a) * (r - 0.02), 0.06), (0, 0, 0), 4))
    iron_parts += [d.cyl("pan", 0.12, 0.018, (0, 0, 0.02), vertices=16), kit.box("bar", (0.8, 0.05, 0.025), (0, 0, 0.012)),
                   d.cyl("hinge0", 0.035, 0.05, (0.0, r, 0.025), (0, math.pi / 2, 0), vertices=8),
                   d.cyl("hinge1", 0.035, 0.05, (0.0, -r, 0.025), (0, math.pi / 2, 0), vertices=8),
                   kit.box("spring0", (0.22, 0.05, 0.03), (0.48, 0, 0.018)), kit.box("spring1", (0.22, 0.05, 0.03), (-0.48, 0, 0.018))]
    chain = _chain("l", (0.58, 0.02), (0.98, 0.22), 6)
    stake = [d.cyl("stake", 0.025, 0.09, (1.02, 0.24, 0.04), vertices=8), d.cyl("stake_head", 0.04, 0.02, (1.02, 0.24, 0.085), vertices=8)]
    return [(kit.join(iron_parts + teeth, "iron"), steel("trap_mine_light_iron_p", seed, "4e4a44"), "iron"),
            (kit.join(chain + stake, "chain"), iron("trap_mine_light_chain_p", seed), "chain")]


def trap_mine_light_sprung(seed=1303):
    """捕兽夹, shut: the two jaws standing up and clamped together."""
    r = 0.3
    jaws = _arc_up("ja", r, 0.0, math.pi, 12, 0.05, 0.035, 0.012, 0.0) + _arc_up("jb", r, 0.0, math.pi, 12, 0.05, 0.035, -0.012, 0.0)
    teeth = []
    for k in range(9):
        a = 0.2 + (math.pi - 0.4) * (k + 0.5) / 9
        for s in (-1, 1):
            x, z = math.cos(a) * (r - 0.03), math.sin(a) * (r - 0.03)
            teeth.append(_cone(f"t{s}{k}", 0.018, 0.06, (x * 0.97, 0.0, z * 0.97), (0, math.pi / 2 - a + math.pi, 0), 4))
    base = [d.cyl("pan", 0.12, 0.018, (0, 0, 0.012), vertices=16), kit.box("bar", (0.8, 0.05, 0.025), (0, 0, 0.012)),
            kit.box("spring0", (0.22, 0.05, 0.05), (0.42, 0, 0.03), (0, -0.4, 0)), kit.box("spring1", (0.22, 0.05, 0.05), (-0.42, 0, 0.03), (0, 0.4, 0))]
    chain = _chain("l", (0.58, 0.02), (0.98, 0.22), 6)
    stake = [d.cyl("stake", 0.025, 0.09, (1.02, 0.24, 0.04), vertices=8), d.cyl("stake_head", 0.04, 0.02, (1.02, 0.24, 0.085), vertices=8)]
    return [(kit.join(jaws + teeth + base, "iron"), steel("trap_mine_light_sprung_iron_p", seed, "4e4a44"), "iron"),
            (kit.join(chain + stake, "chain"), iron("trap_mine_light_sprung_chain_p", seed), "chain")]


def _manhole_frame(prefix, r):
    return _arc_flat(prefix, r + 0.05, 0.0, math.tau, 24, 0.1, 0.05, 0.025)


def _manhole_lid(prefix, r, location, tilt):
    import mathutils
    parts = [d.cyl(f"{prefix}disc", r, 0.045, (0, 0, 0), vertices=28)]
    for k in range(5):
        y = -r * 0.6 + k * r * 0.3
        half = math.sqrt(max(0.0, r * r * 0.82 - y * y))
        parts.append(kit.box(f"{prefix}g{k}", (half * 2.0, 0.035, 0.014), (0, y, 0.028)))
    parts += _arc_flat(f"{prefix}rim", r * 0.86, 0.0, math.tau, 20, 0.03, 0.012, 0.026)
    lid = kit.join(parts, f"{prefix}lid")
    lid.data.transform(mathutils.Matrix.Translation(location) @ mathutils.Euler(tilt).to_matrix().to_4x4())
    return lid


def trap_city_heavy(seed=1205):
    """松动的井盖: a round manhole whose lid sits askew in its frame, a dark
    crescent of the drop showing at one side, the road cracked round it."""
    r = 0.42
    frame = _manhole_frame("f", r)
    lid = [_manhole_lid("l", r, (0.07, 0.03, 0.03), (0.07, -0.05, 0.25))]
    hole = [d.cyl("hole", r + 0.02, 0.01, (0, 0, 0.004), vertices=28)]
    cracks = _cracks("c", seed, 3, (0.35, 0.5), 0.035, r + 0.12)
    return [(kit.join(frame, "frame"), steel("trap_city_heavy_frame_p", seed, "50504c"), "frame"),
            (kit.join(lid, "lid"), steel("trap_city_heavy_lid_p", seed + 1, "45443e"), "lid"),
            (kit.join(hole + cracks, "hole"), flat("trap_city_heavy_hole_p", "070707"), "hole")]


def trap_city_heavy_sprung(seed=1305):
    """井盖, gone: the frame round an open black drop, a ladder rung inside,
    the lid thrown off to one side."""
    r = 0.42
    frame = _manhole_frame("f", r)
    lid = [_manhole_lid("l", r, (0.95, -0.45, 0.06), (0.18, 0.12, 1.1))]
    hole = [d.cyl("hole", r + 0.02, 0.01, (0, 0, 0.004), vertices=28)]
    rungs = [kit.box(f"r{k}", (0.32, 0.03, 0.02), (0, 0.2 - k * 0.12, 0.012 - k * 0.002)) for k in range(2)]
    cracks = _cracks("c", seed, 4, (0.4, 0.6), 0.04, r + 0.12)
    return [(kit.join(frame + rungs, "frame"), steel("trap_city_heavy_sprung_frame_p", seed, "50504c"), "frame"),
            (kit.join(lid, "lid"), steel("trap_city_heavy_sprung_lid_p", seed + 1, "45443e"), "lid"),
            (kit.join(hole + cracks, "hole"), flat("trap_city_heavy_sprung_hole_p", "050505"), "hole")]


def _cable(prefix, points, radius=0.035):
    out = []
    for k in range(len(points) - 1):
        (x0, y0), (x1, y1) = points[k], points[k + 1]
        length = math.hypot(x1 - x0, y1 - y0) + 0.02
        out.append(d.cyl(f"{prefix}{k}", radius, length, ((x0 + x1) / 2, (y0 + y1) / 2, radius), (0, math.pi / 2, math.atan2(y1 - y0, x1 - x0)), vertices=8))
    return out


CABLE_PATH = [(-0.85, 0.3), (-0.6, 0.18), (-0.3, 0.2), (0.0, 0.05), (0.3, 0.0), (0.55, -0.12), (0.72, -0.1)]


def trap_city_light(seed=1207):
    """漏电的电缆: a junction box knocked over, its cable run out across the
    ground, the cut end frayed in a puddle and sparking (the spark is lit)."""
    box = [d.bbox("jb", (0.34, 0.24, 0.2), (-1.0, 0.36, 0.1), (0, 0, 0.3)), kit.box("jb_lid", (0.36, 0.04, 0.22), (-0.95, 0.53, 0.08), (0.3, 0, 0.5))]
    cable = _cable("c", CABLE_PATH)
    copper = [kit.box(f"w{k}", (0.13, 0.012, 0.012), (0.8 + 0.04 * k, 0.04 * (k - 1.5) - 0.1, 0.03), (0, 0, 0.45 * (k - 1.5))) for k in range(4)]
    puddle = [_blob("puddle", 0.32, 0.003, seed, 16, 0.18, (0.78, -0.1), (1.2, 0.85))]
    spark = [kit.rock("spark", 0.05, (0.9, -0.1, 0.06), subdivisions=1)]
    return [(kit.join(box, "box"), steel("trap_city_light_box_p", seed, "6a6a50"), "box"),
            (kit.join(cable, "cable"), flat("trap_city_light_cable_p", "1a1a1a", "0e0e0e"), "cable"),
            (kit.join(copper, "copper"), flat("trap_city_light_copper_p", "b06a30"), "copper"),
            (kit.join(puddle, "water"), flat("trap_city_light_water_p", "34404a", "28323a", 4.0), "water"),
            (kit.join(spark, "glow"), lit("trap_city_light_glow_p"), "glow")]


def trap_city_light_sprung(seed=1307):
    """漏电, discharged: the puddle scorched black in a star, the cable end
    burnt back, no spark."""
    box = [d.bbox("jb", (0.34, 0.24, 0.2), (-1.0, 0.36, 0.1), (0, 0, 0.3)), kit.box("jb_lid", (0.36, 0.04, 0.22), (-0.95, 0.53, 0.08), (0.3, 0, 0.5))]
    cable = _cable("c", CABLE_PATH[:-1])
    puddle = [_blob("puddle", 0.32, 0.003, seed, 16, 0.25, (0.78, -0.1), (1.2, 0.85))]
    scorch = [_blob("scorch", 0.5, 0.0015, seed + 3, 16, 0.3, (0.72, -0.1))]
    copper = [kit.box(f"w{k}", (0.08, 0.012, 0.012), (0.6 + 0.03 * k, 0.03 * (k - 1) - 0.12, 0.03), (0, 0, 0.6 * (k - 1))) for k in range(3)]
    return [(kit.join(box, "box"), steel("trap_city_light_sprung_box_p", seed, "6a6a50"), "box"),
            (kit.join(cable + copper, "cable"), flat("trap_city_light_sprung_cable_p", "141414", "080808"), "cable"),
            (kit.join(puddle, "water"), flat("trap_city_light_sprung_water_p", "30383e"), "water"),
            (kit.join(scorch, "scorch"), flat("trap_city_light_sprung_scorch_p", "1e1a18", "2c2622", 9.0), "scorch")]


def _snow_rim(prefix, radius, seed, count=12):
    random.seed(seed)
    out = []
    for k in range(count):
        a = k / count * math.tau + random.uniform(-0.2, 0.2)
        rr = radius * random.uniform(0.98, 1.12)
        s = random.uniform(0.09, 0.16)
        out.append(kit.rock(f"{prefix}{k}", s, (math.cos(a) * rr, math.sin(a) * rr, 0.0), (1.4, 1.0, 0.35), subdivisions=2))
    return out


def trap_snow_heavy(seed=1209):
    """薄冰: a patch of thin grey-blue ice over dark water, the water showing
    through at its middle, fine cracks starred out from it, drifted snow round
    its edge."""
    ice = [_blob("ice", 1.05, 0.008, seed, 18, 0.12)]
    deep = [_blob("deep", 0.5, 0.01, seed + 1, 14, 0.2)]
    cracks = _cracks("c", seed, 7, (0.35, 0.75), 0.03, 0.35, 0.012)
    rim = _snow_rim("s", 1.05, seed)
    return [(kit.join(ice, "ice"), flat("trap_snow_heavy_ice_p", "8aa2b0", "6a8494", 3.0), "ice"),
            (kit.join(deep, "deep"), flat("trap_snow_heavy_deep_p", "3e5664", "2e4452", 4.0), "deep"),
            (kit.join(cracks, "crack"), flat("trap_snow_heavy_crack_p", "e4eef4"), "crack"),
            (kit.join(rim, "snow"), flat("trap_snow_heavy_snow_p", "e6eef2", "c8d6de", 5.0), "snow")]


def trap_snow_heavy_sprung(seed=1309):
    """薄冰, broken: an open hole of black water with the ice floes tipped
    round its edge."""
    water = [_blob("water", 0.85, 0.003, seed, 18, 0.15)]
    random.seed(seed)
    floes = []
    for k in range(8):
        a = k / 8 * math.tau + random.uniform(-0.15, 0.15)
        r = random.uniform(0.62, 0.85)
        cx, cy = math.cos(a) * r, math.sin(a) * r
        pts = []
        for j in range(5):
            b = a + j / 5 * math.tau
            s = random.uniform(0.13, 0.24)
            pts.append((cx + math.cos(b) * s, cy + math.sin(b) * s))
        floes.append(_slab(f"f{k}", pts, 0.03, 0.025, (random.uniform(-0.3, 0.3), random.uniform(-0.3, 0.3), 0)))
    rim = _snow_rim("s", 1.1, seed)
    return [(kit.join(water, "water"), flat("trap_snow_heavy_sprung_water_p", "142430", "0c1a24", 4.0), "water"),
            (kit.join(floes, "ice"), flat("trap_snow_heavy_sprung_ice_p", "a6bcc8", "7f98a8", 4.0), "ice"),
            (kit.join(rim, "snow"), flat("trap_snow_heavy_sprung_snow_p", "e6eef2", "c8d6de", 5.0), "snow")]


def trap_snow_light(seed=1211):
    """冰刺: a frosted patch, the tips of ice spikes barely through the snow."""
    rime = [_blob("rime", 0.5, 0.004, seed, 14, 0.25)]
    random.seed(seed)
    tips = []
    for k in range(7):
        a = k / 7 * math.tau + random.uniform(-0.3, 0.3)
        r = random.uniform(0.08, 0.38)
        tips.append(_cone(f"t{k}", 0.035, random.uniform(0.06, 0.1), (math.cos(a) * r, math.sin(a) * r, 0.03), (random.uniform(-0.2, 0.2), random.uniform(-0.2, 0.2), 0), 5))
    return [(kit.join(rime, "rime"), flat("trap_snow_light_rime_p", "d4e2ea", "b4c8d4", 6.0), "rime"),
            (kit.join(tips, "ice"), flat("trap_snow_light_ice_p", "c4dce8", "8fb0c2", 4.0), "ice")]


def trap_snow_light_sprung(seed=1311):
    """冰刺, risen: a cluster of ice spikes up through the snow, some snapped."""
    rime = [_blob("rime", 0.6, 0.004, seed, 14, 0.25)]
    random.seed(seed)
    spikes = []
    for k in range(9):
        a = k / 9 * math.tau + random.uniform(-0.3, 0.3)
        r = random.uniform(0.1, 0.48)
        h = random.uniform(0.25, 0.5) * (0.55 if k % 3 == 0 else 1.0)
        spikes.append(_cone(f"s{k}", random.uniform(0.06, 0.09), h, (math.cos(a) * r, math.sin(a) * r, h * 0.45), (math.cos(a) * 0.35, -math.sin(a) * 0.35 * 0.0 + random.uniform(-0.2, 0.2), 0), 5))
    shards = [kit.box(f"x{k}", (0.07, 0.04, 0.02), (random.uniform(-0.7, 0.7), random.uniform(-0.7, 0.7), 0.01), (0, 0, random.uniform(0, math.tau))) for k in range(6)]
    return [(kit.join(rime, "rime"), flat("trap_snow_light_sprung_rime_p", "d4e2ea", "b4c8d4", 6.0), "rime"),
            (kit.join(spikes + shards, "ice"), flat("trap_snow_light_sprung_ice_p", "c4dce8", "86a8bc", 4.0), "ice")]


def trap_siracusa_heavy(seed=1213):
    """松动的石板: one paving slab sunk at a tilt over a dark gap, its corner
    chipped, a hairline crack across it."""
    slab = [d.bbox("slab", (1.0, 0.7, 0.08), (0.04, 0.02, 0.0), (0.06, -0.05, 0.1), width=0.02)]
    chips = [kit.box(f"ch{k}", (0.05, 0.04, 0.03), (0.58 + 0.05 * k, -0.42 + 0.04 * k, 0.015), (0, 0, k)) for k in range(3)]
    gap = [kit.box("gap", (1.14, 0.84, 0.01), (0, 0, 0.004))]
    crack = [kit.box(f"c{k}", (0.32, 0.018, 0.01), (-0.32 + k * 0.28, 0.08 - 0.06 * (k % 2), 0.05), (0.06, -0.05, 0.15 + 0.4 * (k % 2) - 0.2)) for k in range(3)]
    return [(kit.join(slab + chips, "stone"), stone("trap_siracusa_heavy_stone_p", seed, "a69a82"), "stone"),
            (kit.join(gap + crack, "hole"), flat("trap_siracusa_heavy_hole_p", "0a0908"), "hole")]


def trap_siracusa_heavy_sprung(seed=1313):
    """石板, fallen: the pit open, the slab broken in two and tipped into it."""
    random.seed(seed)
    pit = [kit.box("pit", (1.14, 0.84, 0.01), (0, 0, 0.004))]
    walls = [kit.box("w0", (1.14, 0.04, 0.16), (0, 0.42, -0.06)), kit.box("w1", (1.14, 0.04, 0.16), (0, -0.42, -0.06)),
             kit.box("w2", (0.04, 0.84, 0.16), (0.57, 0, -0.06)), kit.box("w3", (0.04, 0.84, 0.16), (-0.57, 0, -0.06))]
    halves = [_slab("h0", [(-0.5, -0.33), (0.02, -0.36), (-0.06, 0.34), (-0.5, 0.33)], 0.02, 0.08, (0.0, 0.42, 0.04)),
              _slab("h1", [(0.08, -0.35), (0.5, -0.33), (0.5, 0.33), (0.0, 0.36)], 0.02, 0.08, (0.0, -0.5, -0.06))]
    rubble = [rough_rock(f"r{k}", 0.05, (random.uniform(-0.6, 0.6), random.choice((-0.5, 0.5)) + random.uniform(-0.05, 0.05), 0.02), seed + k) for k in range(5)]
    return [(kit.join(halves + rubble, "stone"), stone("trap_siracusa_heavy_sprung_stone_p", seed, "a69a82"), "stone"),
            (kit.join(pit + walls, "hole"), flat("trap_siracusa_heavy_sprung_hole_p", "070605"), "hole")]


def _bell(prefix, location, tilt=(0, 0, 0)):
    import mathutils
    parts = [d.cyl(f"{prefix}b", 0.045, 0.06, (0, 0, 0), vertices=12), kit.rock(f"{prefix}t", 0.03, (0, 0, 0.035), (1, 1, 0.8), 1),
             d.cyl(f"{prefix}m", 0.055, 0.012, (0, 0, -0.03), vertices=12)]
    bell = kit.join(parts, f"{prefix}bell")
    bell.data.transform(mathutils.Matrix.Translation(location) @ mathutils.Euler(tilt).to_matrix().to_4x4())
    return bell


def trap_siracusa_light(seed=1215):
    """绊线: a wire at ankle height between two iron pegs, a small brass bell
    hung on one of them."""
    pegs = [d.cyl(f"p{s}", 0.025, 0.24, (s * 0.7, 0, 0.12), vertices=8) for s in (-1, 1)]
    pegs += [d.cyl(f"h{s}", 0.04, 0.02, (s * 0.7, 0, 0.245), vertices=8) for s in (-1, 1)]
    wire = [d.cyl("wire", 0.007, 1.4, (0, 0, 0.16), (0, math.pi / 2, 0), vertices=6)]
    bell = [_bell("b", (0.7, -0.07, 0.17))]
    return [(kit.join(pegs, "iron"), iron("trap_siracusa_light_iron_p", seed), "iron"),
            (kit.join(wire, "wire"), flat("trap_siracusa_light_wire_p", "9a9a94"), "wire"),
            (kit.join(bell, "brass"), flat("trap_siracusa_light_brass_p", "a07a38", "6e5022", 8.0), "brass")]


def trap_siracusa_light_sprung(seed=1315):
    """绊线, snapped: one peg pulled over, the wire's two ends curled on the
    ground, the bell fallen."""
    pegs = [d.cyl("p0", 0.025, 0.24, (-0.7, 0, 0.12), vertices=8), d.cyl("h0", 0.04, 0.02, (-0.7, 0, 0.245), vertices=8),
            d.cyl("p1", 0.025, 0.24, (0.8, 0.05, 0.03), (0, 1.35, 0.3), vertices=8)]
    wire = []
    for s, start in ((-1, -0.7), (1, 0.75)):
        for k in range(5):
            a = k * 0.5
            wire.append(d.cyl(f"w{s}{k}", 0.007, 0.13, (start - s * (0.08 + k * 0.1), 0.06 * math.sin(a) * s, 0.01), (0, math.pi / 2, a * 0.6 * s), vertices=6))
    bell = [_bell("b", (0.55, -0.2, 0.04), (1.4, 0.0, 0.6))]
    return [(kit.join(pegs, "iron"), iron("trap_siracusa_light_sprung_iron_p", seed), "iron"),
            (kit.join(wire, "wire"), flat("trap_siracusa_light_sprung_wire_p", "9a9a94"), "wire"),
            (kit.join(bell, "brass"), flat("trap_siracusa_light_sprung_brass_p", "a07a38", "6e5022", 8.0), "brass")]


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
    """赫拉格: one long sabre cut across the ground, the snapped tip of his
    blade stuck in the earth at its end, a strip of his pale robe caught by it."""
    groove, chips = _gash("cut", 1.3, 0.07, (0, 0, 0), 0.35, seed)
    tip = [_slab("tip", [(0.0, -0.022), (0.3, -0.012), (0.36, 0.0), (0.3, 0.012), (0.0, 0.02)], 0.0, 0.012, (0.0, -1.0, 0.35))]
    for v in tip[0].data.vertices: v.co.x, v.co.y, v.co.z = v.co.x + 0.48, v.co.y + 0.22, v.co.z + 0.02
    cloth = [_slab("cloth", [(0.38, 0.32), (0.56, 0.3), (0.6, 0.38), (0.4, 0.42)], 0.006, 0.004)]
    return [(kit.join(groove + chips, "cut"), flat("trace_hellagur_cut_p", "3e3328"), "cut"),
            (kit.join(tip, "steel"), steel("trace_hellagur_steel_p", seed, "8a8c8e"), "steel"),
            (kit.join(cloth, "cloth"), flat("trace_hellagur_cloth_p", "b8ab90", "8e8270", 9.0), "cloth")]


def trace_rosa(seed=1243):
    """早露: a heavy crossbow bolt driven into the ground at a slant, its steel
    head buried, and the broken strap of a satchel beside it."""
    bolt = [d.cyl("shaft", 0.018, 0.5, (0, 0, 0.14), (0.85, 0, 0.4), vertices=8)]
    vanes = [kit.box(f"v{k}", (0.005, 0.09, 0.06), (0.09 * math.sin(0.4), -0.17, 0.3), (0.85, 0, 0.4 + k * math.pi / 2)) for k in range(2)]
    collar = [d.cyl("collar", 0.03, 0.04, (0.0, 0.08, 0.05), (0.85, 0, 0.4), vertices=8)]
    strap = [kit.box(f"s{k}", (0.16, 0.04, 0.008), (0.3 + 0.13 * k, -0.15 + 0.04 * math.sin(k * 1.3), 0.006), (0, 0, 0.4 * math.sin(k))) for k in range(4)]
    buckle = [kit.box("bk", (0.05, 0.06, 0.012), (0.27, -0.15, 0.01))]
    return [(kit.join(bolt, "shaft"), flat("trace_rosa_shaft_p", "4a3e30"), "shaft"),
            (kit.join(vanes, "vane"), flat("trace_rosa_vane_p", "c8c2b4"), "vane"),
            (kit.join(collar + buckle, "steel"), steel("trace_rosa_steel_p", seed, "6a6c6e"), "steel"),
            (kit.join(strap, "bag"), flat("trace_rosa_bag_p", "4e5a3c", "3a4430", 8.0), "bag")]


def trace_hoshiguma(seed=1245):
    """星熊: the long scrape where a great shield was braced and dragged back,
    and a chip broken off its green-lacquered rim."""
    scratches = []
    for k in range(7):
        scratches.append(kit.box(f"s{k}", (1.1 - abs(k - 3) * 0.1, 0.016, 0.005), (0.0, -0.18 + k * 0.06, 0.003), (0, 0, 0.12)))
    ridge = [kit.box("ridge", (0.16, 0.5, 0.03), (-0.62, 0.04, 0.012), (0, 0, 0.12))]
    chip = [_slab("chip", [(0.0, 0.0), (0.18, -0.02), (0.22, 0.08), (0.05, 0.12)], 0.02, 0.02, (0.15, 0.1, 0.0))]
    for v in chip[0].data.vertices: v.co.x, v.co.y = v.co.x + 0.48, v.co.y + 0.22
    return [(kit.join(scratches + ridge, "scratch"), flat("trace_hoshiguma_scratch_p", "3a332c"), "scratch"),
            (kit.join(chip, "shield"), flat("trace_hoshiguma_shield_p", "3e6a4a", "2a4a34", 7.0), "shield")]


def trace_lin(seed=1247):
    """林: a closed paper umbrella laid down, the shards of a teacup and a
    dark tea stain beside it."""
    random.seed(seed)
    stain = [_blob("stain", 0.26, 0.002, seed, 14, 0.25, (0.25, -0.1))]
    shards = []
    for k in range(6):
        shards.append(kit.box(f"p{k}", (random.uniform(0.04, 0.08), random.uniform(0.03, 0.05), 0.012), (0.25 + random.uniform(-0.2, 0.2), -0.1 + random.uniform(-0.16, 0.16), 0.008), (0.2, 0.1, random.uniform(0, math.tau))))
    canopy = [_cone("canopy", 0.06, 0.62, (-0.25, 0.18, 0.06), (0, math.pi / 2, 0.3), 8)]
    shaft = [d.cyl("shaft", 0.01, 0.82, (-0.27, 0.19, 0.06), (0, math.pi / 2, 0.3), vertices=6),
             d.cyl("handle", 0.022, 0.14, (0.17, 0.32, 0.06), (0, math.pi / 2, 0.3), vertices=8)]
    return [(kit.join(stain, "stain"), flat("trace_lin_stain_p", "201a12"), "stain"),
            (kit.join(shards, "china"), flat("trace_lin_china_p", "d8d4c8", "8a9aa8", 14.0), "china"),
            (kit.join(canopy, "paper"), flat("trace_lin_paper_p", "7a3a30", "5a2a24", 10.0), "paper"),
            (kit.join(shaft, "wood"), wood("trace_lin_wood_p", seed), "wood")]


def trace_typhon(seed=1249):
    """提丰: a great hunting arrow snapped in two, its fletched half lying, its
    head end still in the ground, a tuft of pale fur caught on it."""
    shaft = [d.cyl("shaft", 0.016, 0.34, (0, 0, 0.1), (0.5, 0.25, 0), vertices=6),
             d.cyl("rest", 0.016, 0.55, (0.38, -0.2, 0.017), (0, math.pi / 2, 0.25), vertices=6)]
    vanes = [kit.box(f"v{k}", (0.16, 0.005, 0.05), (0.6, -0.15 + 0.012 * k, 0.03 + 0.02 * k), (k * 0.9, 0, 0.25)) for k in range(3)]
    fur = [kit.rock(f"f{k}", 0.045, (-0.05 + 0.04 * k, 0.12 + 0.02 * k, 0.03), (1.4, 0.8, 0.5), 1) for k in range(3)]
    return [(kit.join(shaft, "shaft"), flat("trace_typhon_shaft_p", "4a3e30"), "shaft"),
            (kit.join(vanes, "vane"), flat("trace_typhon_vane_p", "8a3a30", "5a2620", 9.0), "vane"),
            (kit.join(fur, "fur"), flat("trace_typhon_fur_p", "c8c0b0", "a49c8c", 12.0), "fur")]


def trace_santalla(seed=1251):
    """寒檀: a frost bloom on the ground, a six-armed star of rime, a knot of
    clear ice crystals grown at its heart."""
    arms = []
    for k in range(6):
        a = k / 6 * math.tau
        arms.append(kit.box(f"a{k}", (0.5, 0.03, 0.006), (math.cos(a) * 0.25, math.sin(a) * 0.25, 0.003), (0, 0, a)))
        for side in (-1, 1):
            for j, at in enumerate((0.22, 0.36)):
                b = a + side * 0.6
                arms.append(kit.box(f"t{k}{side}{j}", (0.12 - j * 0.03, 0.02, 0.006), (math.cos(a) * at + math.cos(b) * 0.05, math.sin(a) * at + math.sin(b) * 0.05, 0.003), (0, 0, b)))
    random.seed(seed)
    ice = [_cone(f"c{k}", 0.03, random.uniform(0.1, 0.2), (math.cos(k * 2.1) * 0.05, math.sin(k * 2.1) * 0.05, 0.05), (math.cos(k * 2.1) * 0.4, math.sin(k * 2.1) * 0.4, 0), 5) for k in range(5)]
    return [(kit.join(arms, "rime"), flat("trace_santalla_rime_p", "9aaeb8"), "rime"),
            (kit.join(ice, "ice"), flat("trace_santalla_ice_p", "cfe6f0", "9cc4d6", 5.0), "ice")]


def trace_texas(seed=1253):
    """德克萨斯: an empty red snack box crushed flat, a few of its thin sticks
    spilt beside it."""
    box = [_slab("box", [(-0.12, -0.05), (0.12, -0.06), (0.13, 0.05), (-0.11, 0.06)], 0.03, 0.025, (0.05, -0.08, 0.4))]
    flap = [_slab("flap", [(0.12, -0.05), (0.2, -0.04), (0.2, 0.04), (0.13, 0.05)], 0.02, 0.006, (0.0, 0.3, 0.4))]
    random.seed(seed)
    sticks = [d.cyl(f"s{k}", 0.006, 0.14, (0.18 + random.uniform(0, 0.18), random.uniform(-0.15, 0.15), 0.008), (0, math.pi / 2, random.uniform(0, math.pi)), vertices=5) for k in range(4)]
    return [(kit.join(box + flap, "box"), flat("trace_texas_box_p", "a8302a", "7a221e", 12.0), "box"),
            (kit.join(sticks, "paper"), flat("trace_texas_paper_p", "c89a5a", "5a3420", 20.0), "paper")]


def trace_lappland(seed=1255):
    """拉普兰德: two cuts crossed on the ground, an X struck in passing, a tuft
    of grey wolf fur torn off where the blades met."""
    g0, c0 = _gash("a", 0.9, 0.06, (0, 0, 0), 0.6, seed, ((0.0, 0.55), (0.62, 1.0)))
    g1, c1 = _gash("b", 0.9, 0.06, (0, 0, 0.001), -0.6, seed + 1, ((0.0, 0.4), (0.47, 1.0)))
    fur = [kit.rock(f"f{k}", 0.04, (0.32 + 0.035 * k, 0.12 - 0.02 * k, 0.025), (1.5, 0.7, 0.45), 1) for k in range(3)]
    return [(kit.join(g0 + g1 + c0 + c1, "cut"), flat("trace_lappland_cut_p", "3a3632"), "cut"),
            (kit.join(fur, "fur"), flat("trace_lappland_fur_p", "b4b4b8", "8a8a90", 12.0), "fur")]


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
         trap_siracusa_heavy, trap_siracusa_light,
         trap_mine_heavy_sprung, trap_mine_light_sprung, trap_city_heavy_sprung, trap_city_light_sprung,
         trap_snow_heavy_sprung, trap_snow_light_sprung, trap_siracusa_heavy_sprung, trap_siracusa_light_sprung]
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
