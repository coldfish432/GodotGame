"""Boss arena props (Boss战场地策划案_v1_0.md §7, 用户 2026-10-19): art/kit/arena_*.glb.

矿区 (7-18 核心城中央区): blast gate, 源石祭坛, 干扰地雷, fallen generator.
龙门 (CB-10 下城区夜市): roller shutter, market cart, 医疗符文.
萨米 (树痕部落祭场): the split 木裂 totem, frozen stump, two fallen trees.
叙拉古 (IS-10 雨夜广场): fountain, newsstand, stone bench.
(叙拉古's way out is the family car, already in the game.)

Blender Z up, metres; origin at the bottom centre; a gate spans X, facing -Y.
Through the MCP add-on, one piece a call:

    import build_arena_props as k; k.build("arena_mine_gate")
"""
import math
import os
import random
import sys

sys.path.append(os.path.dirname(__file__))
import bpy  # noqa: E402,F401
from mathutils import Vector  # noqa: E402
import kit_common as kit  # noqa: E402
import poi_detail as d  # noqa: E402
import build_city_kit as city  # noqa: E402
from build_city_kit import steel  # noqa: E402
from build_siracusa_kit import new_scene, stone  # noqa: E402


def flat(name, hex_rgb, darker=None, scale=6.0):
    return kit.flat_material(name, hex_rgb, scale if darker else 0.0, darker)


def rough_rock(name, radius, location, seed, squash=(1.0, 1.0, 0.7)):
    obj = kit.rock(name, radius, location, squash, subdivisions=2)
    kit.roughen(obj, seed, radius * 0.25, radius * 0.8, subdiv=1)
    return obj


def log(name, radius, length, centre, rotation, vertices=10):
    return d.cyl(name, radius, length, centre, rotation=rotation, vertices=vertices)


# --- 矿区 ----------------------------------------------------------------------------------

def arena_mine_gate(seed=2001):
    """A blast door dropped across the way out: ribbed steel, posts, hazard band, a lamp."""
    slab = [d.bbox("slab", (8.4, 0.5, 3.0), (0, 0, 1.5), width=0.03)]
    ribs = [d.bbox(f"rib{k}", (0.18, 0.12, 2.8), (-3.6 + k * 0.9, -0.3, 1.5), width=0.01) for k in range(9)]
    posts = [d.bbox(f"post{s}", (0.5, 0.8, 3.3), (s * 4.45, 0, 1.65), width=0.03) for s in (-1, 1)]
    head = [d.bbox("head", (9.4, 0.9, 0.35), (0, 0, 3.3), width=0.03)]
    band = [d.bbox(f"stripe{k}", (0.45, 0.06, 0.45), (-3.8 + k * 0.95, -0.28, 0.45), rotation=(0, math.radians(45), 0), width=0.004) for k in range(9)]
    hazard = [d.bbox("hazard", (8.4, 0.05, 0.5), (0, -0.27, 0.45), width=0.004)]
    lamp = [d.cyl("lamp", 0.16, 0.22, (0, -0.2, 3.6), vertices=12)]
    return [(kit.join(slab + ribs, "slab"), steel("arena_mine_gate_slab_p", seed, "4a4e54"), "slab"),
            (kit.join(posts + head, "frame"), steel("arena_mine_gate_frame_p", seed + 1, "32353a"), "frame"),
            (kit.join(hazard, "hazard"), flat("arena_mine_gate_hazard_p", "e0a020", "a07210", 8.0), "hazard"),
            (kit.join(band, "band"), flat("arena_mine_gate_band_p", "141414"), "band"),
            (kit.join(lamp, "glow"), flat("arena_mine_gate_glow_p", "ff7a2a"), "glow")]


def arena_mine_shrine(seed=2002):
    """源石祭坛, as 7-18 shows it (refs_B1/stage_devices/7-18_originium_shrine.jpg):
    a heavy dark-steel ring on a square floor plate, four claw arms rising from
    the ring and curving in, holding one tall faceted originium crystal that
    glows red."""
    plate = [d.bbox("plate", (1.9, 1.9, 0.12), (0, 0, 0.06), width=0.02)]
    ring = []
    for k in range(16):
        a = k / 16 * math.tau
        ring.append(d.bbox(f"ring{k}", (0.42, 0.34, 0.32), (math.cos(a) * 0.72, math.sin(a) * 0.72, 0.28), rotation=(0, 0, a), width=0.03))
    bowl = [d.cyl("bowl", 0.5, 0.2, (0, 0, 0.22), vertices=16)]
    claws = []
    for k in range(4):
        a = k / 4 * math.tau + math.pi / 4
        out, up = Vector((math.cos(a), math.sin(a), 0)), Vector((0, 0, 1))
        # Three segments from the ring's top, leaning in toward the crystal.
        points = [out * 0.72 + up * 0.42, out * 0.62 + up * 0.85, out * 0.36 + up * 1.2, out * 0.16 + up * 1.38]
        for j in range(3):
            p0, p1 = points[j], points[j + 1]
            axis = p1 - p0
            rot = axis.to_track_quat("Z", "Y").to_euler()
            claws.append(d.bbox(f"claw{k}_{j}", (0.11, 0.07, axis.length + 0.06), (p0 + p1) / 2, rotation=rot, width=0.01))
    # The crystal: an elongated octahedron with a lesser shard at its foot.
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.26, radius2=0.0, depth=0.75, location=(0, 0, 1.07))
    top = bpy.context.active_object
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.26, radius2=0.0, depth=0.45, location=(0, 0, 0.47), rotation=(math.pi, 0, 0))
    foot = bpy.context.active_object
    shard = d.bbox("shard", (0.1, 0.1, 0.36), (0.18, -0.08, 0.5), rotation=(0.3, -0.4, 0.5), width=0.004)
    return [(kit.join(plate, "plate"), steel("arena_mine_shrine_plate_p", seed, "3a3d42"), "plate"),
            (kit.join(ring + bowl + claws, "steel"), steel("arena_mine_shrine_steel_p", seed + 1, "2e3034"), "steel"),
            (kit.join([top, foot, shard], "glow"), flat("arena_mine_shrine_glow_p", "ff3a32"), "glow")]


def arena_mine_mine(seed=2003):
    """干扰地雷: a squat steel disc on three legs, a sensor dome (its lamp is the game's)."""
    disc = [d.cyl("disc", 0.34, 0.12, (0, 0, 0.1), vertices=16), d.cyl("rim", 0.37, 0.04, (0, 0, 0.05), vertices=16)]
    legs = [d.bbox(f"leg{k}", (0.05, 0.05, 0.12), (math.cos(k * math.tau / 3) * 0.3, math.sin(k * math.tau / 3) * 0.3, 0.03), width=0.004) for k in range(3)]
    dome = [d.cyl("dome", 0.12, 0.06, (0, 0, 0.19), vertices=12)]
    stripes = [d.bbox(f"st{k}", (0.08, 0.36, 0.02), (-0.15 + k * 0.15, 0, 0.165), width=0.004) for k in range(3)]
    return [(kit.join(disc + legs + dome, "steel"), steel("arena_mine_mine_steel_p", seed, "50545a"), "steel"),
            (kit.join(stripes, "hazard"), flat("arena_mine_mine_hazard_p", "e0a020"), "hazard")]


def arena_mine_generator(seed=2004):
    """A generator set knocked on its side: drum housing, cooling fins, pipes, a skid."""
    drum = [d.cyl("drum", 0.65, 2.0, (0, 0, 0.7), rotation=(0, math.radians(90), 0), vertices=16)]
    fins = [d.cyl(f"fin{k}", 0.72, 0.05, (-0.8 + k * 0.2, 0, 0.7), rotation=(0, math.radians(90), 0), vertices=16) for k in range(9)]
    skid = [d.bbox("skid", (2.3, 1.5, 0.18), (0, 0, 0.09), width=0.02)]
    box = [d.bbox("box", (0.7, 0.9, 0.9), (0.9, 0.55, 0.6), rotation=(0, 0, 0.2), width=0.02)]
    pipes = [log("pipe0", 0.08, 1.4, (-0.4, 0.75, 0.9), (math.radians(80), 0, 0.4), 8), log("pipe1", 0.06, 1.0, (0.3, -0.75, 1.1), (math.radians(70), 0, -0.5), 8)]
    return [(kit.join(drum + fins, "drum"), steel("arena_mine_generator_drum_p", seed, "5a5048"), "drum"),
            (kit.join(skid + box, "skid"), steel("arena_mine_generator_skid_p", seed + 1, "3a3d42"), "skid"),
            (kit.join(pipes, "pipe"), flat("arena_mine_generator_pipe_p", "8a5a3a", "4a2e1e", 10.0), "pipe")]


# --- 龙门 ----------------------------------------------------------------------------------

def arena_city_shutter(seed=2101):
    """A shop's roller shutter pulled down across the way out: slats, rails, the housing."""
    slats = [d.bbox(f"sl{k}", (8.4, 0.08, 0.12), (0, 0, 0.1 + k * 0.13), width=0.008) for k in range(23)]
    rails = [d.bbox(f"rail{s}", (0.3, 0.4, 3.2), (s * 4.35, 0, 1.6), width=0.02) for s in (-1, 1)]
    housing = [d.bbox("housing", (9.0, 0.6, 0.5), (0, 0, 3.3), width=0.03)]
    lock = [d.bbox("lock", (0.4, 0.1, 0.2), (0, -0.08, 0.3), width=0.01)]
    return [(kit.join(slats, "shutter"), steel("arena_city_shutter_slats_p", seed, "7a7e80"), "shutter"),
            (kit.join(rails + housing + lock, "frame"), steel("arena_city_shutter_frame_p", seed + 1, "3e4246"), "frame")]


def arena_city_cart(seed=2102):
    """A night-market cart: a tin box on two wheels, a striped awning on poles."""
    box = [d.bbox("box", (1.5, 0.9, 0.7), (0, 0, 0.55), width=0.02)]
    wheels = [d.cyl(f"w{s}", 0.25, 0.08, (s * 0.55, 0.5, 0.25), rotation=(math.radians(90), 0, 0), vertices=12) for s in (-1, 1)]
    poles = [d.bbox(f"p{k}", (0.04, 0.04, 0.85), (sx * 0.7, sy * 0.4, 1.32), width=0.004) for k, (sx, sy) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1)))]
    awning = [d.bbox(f"a{k}", (0.3, 1.0, 0.04), (-0.6 + k * 0.3, 0, 1.76), rotation=(0.12, 0, 0), width=0.004) for k in range(5)]
    return [(kit.join(box, "tin"), steel("arena_city_cart_tin_p", seed, "6a7a6a"), "tin"),
            (kit.join(wheels + poles, "frame"), steel("arena_city_cart_frame_p", seed + 1, "2a2c30"), "frame"),
            (kit.join(awning, "awning"), flat("arena_city_cart_awning_p", "c84a3a", "8a2a20", 9.0), "awning")]


def arena_city_rune(seed=2103):
    """医疗符文, as CB-10 shows it (refs_B1/stage_devices/CB-10_map.jpg and PRTS
    特殊地形_医疗符文): a dark square floor plate with a bevelled frame, four arcs
    of a ring round a big blue cross, a small hazard label in one corner."""
    plate = [d.bbox("plate", (2.6, 2.6, 0.08), (0, 0, 0.04), width=0.03)]
    frame = [d.bbox(f"f{k}", (2.6 if k < 2 else 0.1, 0.1 if k < 2 else 2.6, 0.05), ((0, 0, -1.25, 1.25)[k], (-1.25, 1.25, 0, 0)[k], 0.1), width=0.01) for k in range(4)]
    arcs = []
    for q in range(4):
        for j in range(5):
            a = q * math.pi / 2 + math.radians(12) + j * math.radians(16.5)
            arcs.append(d.bbox(f"arc{q}_{j}", (0.3, 0.09, 0.03), (math.cos(a) * 0.98, math.sin(a) * 0.98, 0.095), rotation=(0, 0, a + math.pi / 2), width=0.004))
    cross = [d.bbox("cross_a", (1.2, 0.34, 0.03), (0, 0, 0.1), width=0.004), d.bbox("cross_b", (0.34, 1.2, 0.03), (0, 0, 0.1), width=0.004)]
    stripes = [d.bbox(f"st{k}", (0.06, 0.24, 0.02), (0.72 + k * 0.1, -0.95, 0.09), width=0.004) for k in range(4)]
    label = [d.bbox("label", (0.34, 0.2, 0.02), (0.86, -0.7, 0.09), width=0.004)]
    return [(kit.join(plate + frame, "plate"), steel("arena_city_rune_plate_p", seed, "3a4048"), "plate"),
            (kit.join(arcs + label, "frame"), steel("arena_city_rune_arc_p", seed + 1, "6a7480"), "frame"),
            (kit.join(stripes, "hazard"), flat("arena_city_rune_hazard_p", "e0b020"), "hazard"),
            (kit.join(cross, "glow"), flat("arena_city_rune_glow_p", "2a9ae8"), "glow")]


# --- 萨米 ----------------------------------------------------------------------------------

def arena_snow_totem(seed=2201):
    """The 木裂 totem: a great trunk split down the middle, the halves leaning apart, carved bands."""
    halves = []
    for s in (-1, 1):
        half = log(f"h{s}", 0.42, 2.5, (s * 0.22, 0, 1.25), (0, math.radians(s * 6), 0), 10)
        halves.append(half)
    bands = [d.cyl(f"band{k}", 0.46, 0.1, (0, 0, 0.6 + k * 0.6), vertices=12) for k in range(3)]
    antler = [log(f"t{k}", 0.04, 0.6, (math.cos(k * 2.1) * 0.25, math.sin(k * 2.1) * 0.25, 2.65), (math.sin(k * 2.1) * 0.6, math.cos(k * 2.1) * 0.6, 0), 6) for k in range(3)]
    return [(kit.join(halves, "wood"), flat("arena_snow_totem_wood_p", "6a5440", "3a2c20", 12.0), "wood"),
            (kit.join(bands, "band"), flat("arena_snow_totem_band_p", "8fd8dc", "4a8890", 8.0), "band"),
            (kit.join(antler, "bone"), flat("arena_snow_totem_bone_p", "8a7a62"), "bone")]


def arena_snow_stump(seed=2202):
    """A frozen stump: a thick cut trunk under a crust of blue-white ice."""
    trunk = [log("trunk", 0.65, 1.3, (0, 0, 0.65), (0, 0, 0), 12)]
    roots = [log(f"r{k}", 0.16, 0.9, (math.cos(k * 1.6) * 0.65, math.sin(k * 1.6) * 0.65, 0.12), (math.sin(k * 1.6) * 1.2, -math.cos(k * 1.6) * 1.2, 0), 6) for k in range(4)]
    crust = [rough_rock("ice", 0.72, (0.05, 0, 1.3), seed, (1.0, 1.0, 0.35))]
    return [(kit.join(trunk + roots, "bark"), flat("arena_snow_stump_bark_p", "4a3e34", "2a221c", 12.0), "bark"),
            (kit.join(crust, "ice"), flat("arena_snow_stump_ice_p", "d8eef8", "9fc4d8", 6.0), "ice")]


def arena_snow_logs(seed=2203):
    """Two pines felled across the way out, one on the other, branch stubs and snow."""
    random.seed(seed)
    logs = [log("l0", 0.45, 9.4, (0, 0, 0.45), (0, math.radians(90), math.radians(3)), 12),
            log("l1", 0.4, 8.6, (0.3, 0.1, 1.25), (0, math.radians(90), math.radians(-4)), 12)]
    stubs = [log(f"s{k}", 0.08, 0.6, (-4.0 + k * 0.9, random.choice((-0.4, 0.4)), 0.9 + (k % 2) * 0.8), (random.uniform(-0.9, 0.9), 0, random.uniform(0, 3)), 6) for k in range(9)]
    snow = [rough_rock(f"sn{k}", random.uniform(0.35, 0.6), (-3.6 + k * 1.8, 0, 1.6), seed + k, (1.6, 0.9, 0.35)) for k in range(5)]
    return [(kit.join(logs + stubs, "bark"), flat("arena_snow_logs_bark_p", "4a3a2e", "2a201a", 10.0), "bark"),
            (kit.join(snow, "snow"), flat("arena_snow_logs_snow_p", "eef4f8", "c4d4e0", 5.0), "snow")]


# --- 叙拉古 --------------------------------------------------------------------------------

def arena_sira_fountain(seed=2301):
    """The piazza fountain: a round stone basin, a column, a bowl on top."""
    basin = [d.cyl("basin", 1.8, 0.75, (0, 0, 0.375), vertices=28)]
    lip = [d.cyl("lip", 1.9, 0.12, (0, 0, 0.78), vertices=28)]
    column = [d.cyl("col", 0.28, 1.5, (0, 0, 1.2), vertices=12), d.cyl("bowl", 0.75, 0.18, (0, 0, 1.95), vertices=16), d.cyl("top", 0.16, 0.4, (0, 0, 2.2), vertices=10)]
    water = [d.cyl("water", 1.65, 0.04, (0, 0, 0.7), vertices=28)]
    return [(kit.join(basin + lip + column, "stone"), stone("arena_sira_fountain_stone_p", seed, "b4a68a"), "stone"),
            (kit.join(water, "water"), flat("arena_sira_fountain_water_p", "4a6a7a", "2a3e4a", 8.0), "water")]


def arena_sira_kiosk(seed=2302):
    """A newsstand: a green-painted wooden box, a little roof, shutters folded open."""
    box = [d.bbox("box", (1.5, 0.95, 1.6), (0, 0, 0.8), width=0.02)]
    roof = [d.bbox("roof", (1.75, 1.2, 0.12), (0, 0, 1.68), rotation=(0.1, 0, 0), width=0.01)]
    shutters = [d.bbox(f"sh{s}", (0.7, 0.04, 0.8), (s * 0.75, -0.55, 1.05), rotation=(0, 0, s * 0.6), width=0.004) for s in (-1, 1)]
    papers = [d.bbox(f"pa{k}", (0.25, 0.02, 0.32), (-0.45 + k * 0.3, -0.49, 1.0), width=0.004) for k in range(4)]
    return [(kit.join(box + shutters, "wood"), flat("arena_sira_kiosk_wood_p", "3e5a44", "24382a", 10.0), "wood"),
            (kit.join(roof, "roof"), flat("arena_sira_kiosk_roof_p", "2a2c30"), "roof"),
            (kit.join(papers, "paper"), flat("arena_sira_kiosk_paper_p", "d8d0bc"), "paper")]


def arena_sira_bench(seed=2303):
    """A stone bench: a thick slab on two carved legs."""
    slab = [d.bbox("slab", (1.4, 0.5, 0.16), (0, 0, 0.78), width=0.03)]
    legs = [d.bbox(f"leg{s}", (0.22, 0.45, 0.7), (s * 0.5, 0, 0.35), width=0.03) for s in (-1, 1)]
    return [(kit.join(slab + legs, "stone"), stone("arena_sira_bench_stone_p", seed, "a89a80"), "stone")]


# --- Boss演出策划案_v0_2 (用户 2026-11-04): the set pieces' props ---------------------------

def arena_mine_flag(seed=2004):
    """The 游击队 flag's pole: an iron pole on a rubble foot, a crossbar and a finial (the cloth is its own piece)."""
    pole = [d.cyl("pole", 0.05, 3.4, (0, 0, 1.7), vertices=8)]
    bar = [d.cyl("bar", 0.025, 1.35, (0.68, 0, 3.3), rotation=(0, math.radians(90), 0), vertices=6)]
    tip = [d.cyl("tip", 0.07, 0.16, (0, 0, 3.45), vertices=6)]
    foot = [rough_rock(f"r{k}", 0.22 + 0.06 * k, (math.cos(k * 2.2) * 0.22, math.sin(k * 2.2) * 0.22, 0.08), seed + k, (1.0, 1.0, 0.55)) for k in range(4)]
    return [(kit.join(pole + bar + tip, "iron"), steel("arena_mine_flag_iron_p", seed, "3a342e"), "iron"),
            (kit.join(foot, "rock"), flat("arena_mine_flag_rock_p", "5a524a", "3a342e", 8.0), "rock")]


def arena_mine_flag_cloth(seed=2005):
    """The cloth: worn orange-red, torn at the fly end, hung from the crossbar (origin at the hoist top)."""
    import bmesh
    mesh = bpy.data.meshes.new("cloth")
    bm = bmesh.new()
    random.seed(seed)
    cols, rows = 8, 5
    verts = []
    for j in range(rows + 1):
        row = []
        for i in range(cols + 1):
            x = 1.3 * i / cols
            z = -0.85 * j / rows
            if i == cols and j % 2 == 1: x -= random.uniform(0.12, 0.25)   # torn fly end
            if j == rows: z += random.uniform(0.0, 0.12) * (i / cols)
            y = 0.06 * math.sin(i * 1.3) * (i / cols)
            row.append(bm.verts.new((x, y, z)))
        verts.append(row)
    for j in range(rows):
        for i in range(cols):
            if i == cols - 1 and j == 2: continue   # a hole
            bm.faces.new((verts[j][i], verts[j][i + 1], verts[j + 1][i + 1], verts[j + 1][i]))
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("cloth", mesh)
    bpy.context.collection.objects.link(obj)
    stripe = [d.bbox("x1", (0.5, 0.012, 0.07), (0.62, 0.0, -0.42), rotation=(0, math.radians(35), 0), width=0.002),
              d.bbox("x2", (0.5, 0.012, 0.07), (0.62, 0.0, -0.42), rotation=(0, math.radians(-35), 0), width=0.002)]
    return [(kit.join([obj], "cloth"), flat("arena_mine_flag_cloth_p", "b8452a", "7a2a1a", 10.0), "cloth"),
            (kit.join(stripe, "mark"), flat("arena_mine_flag_mark_p", "1a1614"), "mark")]


def arena_snow_mound(seed=2204):
    """The ice 木裂 waits in: a faceted mound of blue-white ice over a snow skirt, shards jutting out."""
    random.seed(seed)
    core = [rough_rock("core", 1.15, (0, 0, 0.55), seed, (1.0, 1.0, 0.85))]
    shards = []
    for k in range(9):
        a = k * 0.7 + random.uniform(-0.2, 0.2)
        r = random.uniform(0.6, 1.0)
        shards.append(d.cyl(f"s{k}", random.uniform(0.12, 0.22), random.uniform(0.6, 1.2), (math.cos(a) * r, math.sin(a) * r, 0.5),
                            rotation=(math.sin(a) * 0.5, -math.cos(a) * 0.5, 0), vertices=5))
    skirt = [rough_rock(f"sk{k}", random.uniform(0.45, 0.65), (math.cos(k * 1.05) * 1.15, math.sin(k * 1.05) * 1.15, 0.05), seed + 10 + k, (1.4, 1.0, 0.3)) for k in range(6)]
    return [(kit.join(core + shards, "ice"), flat("arena_snow_mound_ice_p", "bfe4f2", "7ab0cc", 6.0), "ice"),
            (kit.join(skirt, "snow"), flat("arena_snow_mound_snow_p", "eef4f8", "c4d4e0", 5.0), "snow")]


def arena_city_manhole(seed=2104):
    """A 龙门 manhole lid: a round cast-iron lid with a cross-hatched face, set in a frame."""
    lid = [d.cyl("lid", 0.42, 0.05, (0, 0, 0.025), vertices=20)]
    ribs = [d.bbox(f"rx{k}", (0.7 - abs(k) * 0.14, 0.03, 0.02), (0, k * 0.12, 0.055), width=0.003) for k in range(-2, 3)]
    ribs += [d.bbox(f"ry{k}", (0.03, 0.7 - abs(k) * 0.14, 0.02), (k * 0.12, 0, 0.055), width=0.003) for k in range(-2, 3)]
    frame = [d.cyl("frame", 0.5, 0.03, (0, 0, 0.015), vertices=20)]
    return [(kit.join(lid + ribs, "iron"), steel("arena_city_manhole_iron_p", seed, "3a3c40"), "iron"),
            (kit.join(frame, "frame"), flat("arena_city_manhole_frame_p", "26282c"), "frame")]


def arena_city_frenzy(seed=2105):
    """源石狂暴地板 (用户 2026-11-05: 是这个，面上画着滴血的刀，周围有红色向上的光影):
    明日方舟's bleeding tile, set flush in the floor (用户 2026-11-05: 嵌在地上不要凸出来;
    2 cm thick) — a flat square in a steel frame, a dark red panel the
    game paints the dripping-knife mark on, small red lamps at the corners. The
    red light rising round it is the game's (world/frenzy_light.gdshader). 2 m across."""
    side = 2.0
    rim = 0.12
    frame = []
    for sx, sy, w, h in ((0, side / 2 - rim / 2, side, rim), (0, -side / 2 + rim / 2, side, rim),
                         (side / 2 - rim / 2, 0, rim, side - 2 * rim), (-side / 2 + rim / 2, 0, rim, side - 2 * rim)):
        frame.append(d.bbox(f"rim{sx}{sy}", (w, h, 0.02), (sx, sy, 0.01), width=0.004))
    panel = [d.bbox("panel", (side - 2 * rim, side - 2 * rim, 0.012), (0, 0, 0.006), width=0.002)]
    lamps = [d.bbox(f"l{i}", (0.14, 0.14, 0.022), (cx * (side / 2 - 0.07), cy * (side / 2 - 0.07), 0.011), width=0.003)
             for i, (cx, cy) in enumerate(((1, 1), (1, -1), (-1, 1), (-1, -1)))]
    return [(kit.join(frame, "frame"), steel("arena_city_frenzy_frame_p", seed, "34363c"), "frame"),
            (kit.join(panel, "crust"), flat("arena_city_frenzy_crust_p", "3a1414", "220808", 8.0), "crust"),
            (kit.join(lamps, "glow"), flat("arena_city_frenzy_glow_p", "ff3a2a"), "glow")]


BUILDERS = [arena_mine_gate, arena_mine_shrine, arena_mine_mine, arena_mine_generator,
            arena_city_shutter, arena_city_cart, arena_city_rune,
            arena_snow_totem, arena_snow_stump, arena_snow_logs,
            arena_sira_fountain, arena_sira_kiosk, arena_sira_bench,
            arena_mine_flag, arena_mine_flag_cloth, arena_snow_mound, arena_city_manhole, arena_city_frenzy]
PREVIEW = {"arena_mine_gate": 7.0, "arena_mine_shrine": 3.0, "arena_mine_mine": 1.2, "arena_mine_generator": 3.0,
           "arena_city_shutter": 7.0, "arena_city_cart": 2.6, "arena_city_rune": 3.4,
           "arena_snow_totem": 3.4, "arena_snow_stump": 2.4, "arena_snow_logs": 7.0,
           "arena_sira_fountain": 4.2, "arena_sira_kiosk": 2.8, "arena_sira_bench": 2.0,
           "arena_mine_flag": 4.0, "arena_mine_flag_cloth": 1.8, "arena_snow_mound": 3.0, "arena_city_manhole": 1.4, "arena_city_frenzy": 2.6}
BAKE_SIZE = {"slab": 512, "frame": 256, "hazard": 128, "band": 64, "glow": 64, "plinth": 256, "rock": 256,
             "steel": 128, "drum": 256, "skid": 256, "pipe": 128, "shutter": 512, "tin": 256, "awning": 128,
             "wood": 256, "bone": 64, "bark": 256, "ice": 256, "snow": 256, "stone": 512, "water": 128,
             "roof": 64, "paper": 64, "iron": 128, "cloth": 256, "mark": 64, "crust": 256}


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
