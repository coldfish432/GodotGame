"""Snowfield (萨米·冻土林线) kit: art/kit/snow_*.glb and poi_camp.glb.

雪原地图调研与方案_v1.md §2. The same roles as the mine's pieces, in Sami's
materials: a charcoal brazier lights the rooms (the mine's lamp post), a trail
post with a lantern marks the corridors (the mine's timber frames), a snow
priest's totem stands over the way down (the mine's headframe), and drifts,
fallen logs and icicles dress the cliffs. Snow on the tops is not baked here:
the game's shaders lay it on every upward face in this region (field_snow),
so models and terrain carry the same snow.

Origin at the bottom centre unless noted, Blender Z up, metres.

Run: blender -b --factory-startup --python-exit-code 1 --python tools/blender/kit/build_snow_kit.py
"""
import math
import os
import random
import sys

sys.path.append(os.path.dirname(__file__))
import bpy  # noqa: E402
import kit_common as kit  # noqa: E402
from build_mine_accents import rust_material, wood_material, _lantern_parts  # noqa: E402
from build_mine_cliff import rock_material  # noqa: E402
import poi_detail as d  # noqa: E402
from build_poi import cloth, _settled_publish  # noqa: E402


def snow_rock(name, seed):
    """Grey-blue frozen rock (the mine's rock material in a cold palette)."""
    mat = rock_material(name, seed)
    ramp = [n for n in mat.node_tree.nodes if n.bl_idname == "ShaderNodeValToRGB"][0]
    stops = ramp.color_ramp.elements
    colours = ["2c3238", "5a6670", "8a96a0"]
    for i, element in enumerate(stops):
        element.color = kit.srgb(colours[min(i, 2)])
    return mat


def birch_wood(name, seed):
    """Weathered pale wood: Sami build in birch and pine."""
    return d.worn(wood_material(name, seed), edge="d8d0c0", edge_strength=0.4, grime="1a1610", grime_strength=0.35)


def brazier(seed):
    """snow_brazier: a Sami charcoal fire in an iron bowl on three legs, ringed
    with stones, a few split logs stacked beside it; the coals glow."""
    kit.reset_scene()
    random.seed(seed)
    stones = []
    for i in range(9):
        a = i * math.tau / 9
        stone = kit.rock(f"ring{i}", random.uniform(0.12, 0.17), (math.cos(a) * 0.62, math.sin(a) * 0.62, 0.06), (1.3, 1.0, 0.7), subdivisions=1)
        kit.roughen(stone, seed + i, strength=0.03, size=0.1, subdiv=1)
        stones.append(stone)
    stone_obj = kit.join(stones, "stones")
    kit.clip_below(stone_obj, 0.0)
    bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=0.42, depth=0.22, location=(0, 0, 0.62))
    bowl = bpy.context.object
    for v in bowl.data.vertices:
        if v.co.z < 0: v.co.x *= 0.6; v.co.y *= 0.6
    legs = [d.bbox(f"leg{i}", (0.04, 0.04, 0.6), (math.cos(i * 2.1) * 0.28, math.sin(i * 2.1) * 0.28, 0.3), (math.sin(i * 2.1) * 0.25, -math.cos(i * 2.1) * 0.25, 0), width=0.008) for i in range(3)]
    iron = kit.join([bowl] + legs, "iron")
    coals = [kit.rock(f"coal{i}", random.uniform(0.06, 0.1), (random.uniform(-0.25, 0.25), random.uniform(-0.25, 0.25), 0.74), (1.2, 1.0, 0.7), subdivisions=1) for i in range(10)]
    glow = kit.join(coals, "coals")
    logs = [d.cyl(f"log{i}", 0.07, 0.7, (0.95, -0.15 + i * 0.15, 0.08 + (0.12 if i == 1 else 0)), (0, math.pi / 2, random.uniform(-0.2, 0.2)), 8) for i in range(3)]
    wood = kit.join(logs, "logs")
    _settled_publish([(stone_obj, snow_rock("snow_brazier_stone_p", seed), "stone"),
                      (iron, rust_material("snow_brazier_iron_p", seed), "iron"),
                      (wood, birch_wood("snow_brazier_wood_p", seed), "wood"),
                      (glow, kit.flat_material("snow_brazier_glow_p", "ffb040", 8.0, "e05010"), "glow")], "snow_brazier", 2.4, 512)


def trail_post(seed):
    """snow_trail_post: a carved Sami waymark. A post with a crossbar, antlers
    on top, cloth strips and a bone charm hanging, a lantern on an arm."""
    kit.reset_scene()
    random.seed(seed)
    wood = [d.bbox("post", (0.16, 0.16, 2.6), (0, 0, 1.3), width=0.02),
            d.bbox("cross", (0.7, 0.08, 0.08), (0, 0, 2.2), width=0.012),
            d.bbox("arm", (0.6, 0.07, 0.07), (0.32, 0, 1.75), width=0.01)]
    for i in range(4):  # carved rings
        wood.append(d.bbox(f"ring{i}", (0.19, 0.19, 0.04), (0, 0, 0.5 + i * 0.4), width=0.008))
    for i in range(3):
        stone = kit.rock(f"foot{i}", 0.15, (math.cos(i * 2.1) * 0.18, math.sin(i * 2.1) * 0.18, 0.05), (1.2, 1.0, 0.6), subdivisions=1)
        kit.roughen(stone, seed + i, strength=0.03, size=0.1, subdiv=1)
        wood.append(stone)
    wood_obj = kit.join(wood, "wood")
    kit.clip_below(wood_obj, 0.0)
    antlers = []
    for s in (-1, 1):
        antlers.append(d.bbox(f"beam{s}", (0.04, 0.04, 0.5), (s * 0.12, 0, 2.78), (0, s * 0.5, 0), width=0.01))
        for t in range(3):
            antlers.append(d.bbox(f"tine{s}{t}", (0.03, 0.03, 0.2), (s * (0.14 + t * 0.06), 0, 2.72 + t * 0.12), (0, s * 1.1, 0), width=0.008))
    bone = kit.join(antlers, "bone")
    strips = [kit.box(f"strip{i}", (0.06, 0.01, 0.45), (-0.25 + i * 0.12, 0, 1.95), (0, random.uniform(-0.15, 0.15), 0)) for i in range(4)]
    cloth_obj = kit.join(strips, "cloth")
    iron, glass = _lantern_parts(seed, (0.58, 0.0, 1.72))
    iron_obj = kit.join(iron, "iron")
    _settled_publish([(wood_obj, birch_wood("snow_trail_post_wood_p", seed), "wood"),
                      (bone, kit.flat_material("snow_trail_post_bone_p", "e8e0cc", 20.0, "b0a890"), "bone"),
                      (cloth_obj, cloth("snow_trail_post_cloth_p", seed, "8a2a24"), "cloth"),
                      (iron_obj, rust_material("snow_trail_post_iron_p", seed), "iron"),
                      (glass, kit.flat_material("snow_trail_post_glow_p", "ffc870", 6.0, "e88a2a"), "glow")], "snow_trail_post", 3.4, 512)


def totem(seed):
    """snow_totem: a snow priest's totem over the way down. A tall carved pole
    on a cairn, stacked faces, a crown of antlers, long cloth streamers and
    two cold lamps; the landmark that reads from across the room."""
    kit.reset_scene()
    random.seed(seed)
    cairn = []
    for i in range(12):
        a = i * 0.9
        r = random.uniform(0.2, 0.35)
        stone = kit.rock(f"cairn{i}", r, (math.cos(a) * 0.55, math.sin(a) * 0.55, r * 0.5 + (0.25 if i % 3 == 0 else 0)), (1.2, 1.0, 0.8))
        kit.roughen(stone, seed + i, strength=0.04, size=0.15, subdiv=1)
        cairn.append(stone)
    stone_obj = kit.join(cairn, "stones")
    kit.clip_below(stone_obj, 0.0)
    kit.decimate(stone_obj, 2000)
    wood = [d.bbox("pole", (0.36, 0.36, 5.2), (0, 0, 2.6), width=0.05)]
    for i, z in enumerate((1.4, 2.4, 3.4)):
        wood.append(d.bbox(f"face{i}", (0.46, 0.46, 0.5), (0, 0, z), width=0.06))
        wood.append(d.bbox(f"brow{i}", (0.5, 0.12, 0.08), (0, -0.25, z + 0.12), width=0.02))
        wood.append(d.bbox(f"nose{i}", (0.08, 0.1, 0.18), (0, -0.27, z - 0.02), width=0.015))
    wood.append(d.bbox("yoke", (1.6, 0.14, 0.14), (0, 0, 4.4), width=0.02))
    wood_obj = kit.join(wood, "wood")
    antlers = []
    for s in (-1, 1):
        antlers.append(d.bbox(f"beam{s}", (0.07, 0.07, 1.1), (s * 0.3, 0, 5.6), (0, s * 0.55, 0), width=0.015))
        for t in range(4):
            antlers.append(d.bbox(f"tine{s}{t}", (0.05, 0.05, 0.4), (s * (0.3 + t * 0.13), 0, 5.4 + t * 0.2), (0, s * 1.15, 0), width=0.012))
    bone = kit.join(antlers, "bone")
    streamers = [kit.box(f"str{s}{i}", (0.1, 0.01, 1.4), (s * (0.55 + i * 0.18), 0, 3.6), (0, random.uniform(-0.1, 0.1), 0)) for s in (-1, 1) for i in range(2)]
    cloth_obj = kit.join(streamers, "cloth")
    iron = []
    glass = []
    for s in (-1, 1):
        parts, g = _lantern_parts(seed, (s * 0.75, 0.0, 4.35))
        iron += parts
        glass.append(g)
    iron_obj = kit.join(iron, "iron")
    glass_obj = kit.join(glass, "glass")
    _settled_publish([(stone_obj, snow_rock("snow_totem_stone_p", seed), "stone"),
                      (wood_obj, birch_wood("snow_totem_wood_p", seed), "wood"),
                      (bone, kit.flat_material("snow_totem_bone_p", "ece4d0", 20.0, "b4ac94"), "bone"),
                      (cloth_obj, cloth("snow_totem_cloth_p", seed, "2a4a8a"), "cloth"),
                      (iron_obj, rust_material("snow_totem_iron_p", seed), "iron"),
                      (glass_obj, kit.flat_material("snow_totem_glow_p", "dff4ff", 6.0, "8fc8ff"), "glow")], "snow_totem", 7.0, 512)


def drift(variant, seed):
    """snow_drift_{a,b}: snow banked against a cliff foot, a rock or two showing."""
    kit.reset_scene()
    random.seed(seed)
    mound = kit.rock("mound", 0.9, (0, 0, 0), (1.6, 1.0, 0.45), subdivisions=3)
    kit.roughen(mound, seed, strength=0.08, size=0.5, subdiv=1)
    kit.clip_below(mound, 0.0)
    kit.decimate(mound, 1500)
    rocks = [kit.rock(f"r{i}", random.uniform(0.15, 0.25), (random.uniform(-0.8, 0.8), random.uniform(-0.3, 0.3), 0.15), (1.2, 1.0, 0.8), subdivisions=1) for i in range(2)]
    for i, r in enumerate(rocks): kit.roughen(r, seed + i, strength=0.03, size=0.1, subdiv=1)
    rock_obj = kit.join(rocks, "rocks")
    _settled_publish([(mound, kit.flat_material("snow_drift_snow_p", "e8eef4", 12.0, "b8c8d8"), "snow"),
                      (rock_obj, snow_rock("snow_drift_rock_p", seed), "rock")], f"snow_drift_{variant}", 3.2, 512)


def fallen_log(seed):
    """snow_log: a fallen pine with its broken stumps of branches and root plate."""
    kit.reset_scene()
    random.seed(seed)
    trunk = d.cyl("trunk", 0.22, 3.2, (0, 0, 0.2), (0, math.pi / 2, random.uniform(-0.1, 0.1)), 12)
    branches = [d.cyl(f"br{i}", 0.05, 0.5, (random.uniform(-1.3, 1.3), random.uniform(-0.1, 0.1), 0.35), (random.uniform(-0.8, 0.8), random.uniform(-0.6, 0.6), 0), 6) for i in range(5)]
    root = kit.rock("root", 0.45, (1.65, 0, 0.35), (0.35, 1.0, 1.0), subdivisions=2)
    kit.roughen(root, seed, strength=0.05, size=0.15, subdiv=1)
    wood = kit.join([trunk] + branches + [root], "wood")
    kit.clip_below(wood, 0.0)
    _settled_publish([(wood, d.worn(wood_material("snow_log_wood_p", seed), edge="8a7a62", edge_strength=0.3), "wood")], "snow_log", 3.8, 512)


def icicles(seed):
    """snow_icicles: a fringe of icicles hanging under a cliff lip. Origin at
    the top centre (it hangs DOWN from z = 0); about 2 m of lip."""
    kit.reset_scene()
    random.seed(seed)
    cones = []
    for i in range(14):
        length = random.uniform(0.15, 0.6)
        bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=random.uniform(0.03, 0.06), radius2=0.0, depth=length,
                                        location=(-1.0 + i * 0.15 + random.uniform(-0.04, 0.04), random.uniform(-0.05, 0.05), -length / 2), rotation=(math.pi, 0, 0))
        cones.append(bpy.context.object)
    lip = kit.box("lip", (2.1, 0.18, 0.08), (0, 0, 0.0))
    kit.roughen(lip, seed, strength=0.02, size=0.08, subdiv=1)
    ice = kit.join(cones + [lip], "ice")
    # Hangs from z = 0: _settled_publish lifts the lowest point to 0, so it
    # is moved back down after export by the placement (TerraceDressing).
    _settled_publish([(ice, kit.flat_material("snow_icicles_ice_p", "c8e4f0", 10.0, "8ab8d0"), "ice")], "snow_icicles", 2.6, 256)


def camp(seed):
    """poi_camp (冰原营地): a hunters' camp. An A-frame canvas tent, a bedroll,
    a supply crate, a cold fire ring with a pot on a tripod."""
    kit.reset_scene()
    random.seed(seed)
    poles = [d.bbox(f"pole{x}{s}", (0.05, 0.05, 1.5), (x, s * 0.45, 0.65), (s * 0.6, 0, 0), width=0.008) for x in (-0.8, 0.8) for s in (-1, 1)]
    ridge = d.bbox("ridge", (1.8, 0.05, 0.05), (0, 0, 1.25), width=0.008)
    tripod = [d.bbox(f"tri{i}", (0.03, 0.03, 0.9), (0.9 + math.cos(i * 2.1) * 0.15, -1.1 + math.sin(i * 2.1) * 0.15, 0.4), (math.sin(i * 2.1) * 0.35, -math.cos(i * 2.1) * 0.35, 0), width=0.005) for i in range(3)]
    sticks = [d.cyl(f"stick{i}", 0.035, 0.45, (0.9 + random.uniform(-0.1, 0.1), -1.1 + random.uniform(-0.1, 0.1), 0.05), (0, math.pi / 2, i * 1.0), 6) for i in range(4)]
    wood = kit.join(poles + [ridge] + tripod + sticks + d.plank_box("crate", (0.6, 0.45, 0.4), (-1.3, -0.6, 0.2), plank=0.1, battens=False), "wood")
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.6))
    tent = bpy.context.object
    tent.scale = (1.7, 1.3, 1.2)
    bpy.ops.object.transform_apply(scale=True)
    for v in tent.data.vertices:
        if v.co.z > 0: v.co.y = 0.0  # pull the top edge together: an A-frame
    tent.location = (0, 0, 0.6)
    bpy.ops.object.transform_apply(location=True)
    roll = d.cyl("roll", 0.13, 0.7, (-0.2, -0.95, 0.13), (0, math.pi / 2, 0.2), 14)
    canvas = kit.join([tent, roll], "canvas")
    stones = []
    for i in range(8):
        a = i * math.tau / 8
        s = kit.rock(f"fire{i}", 0.09, (0.9 + math.cos(a) * 0.32, -1.1 + math.sin(a) * 0.32, 0.04), (1.2, 1.0, 0.6), subdivisions=1)
        kit.roughen(s, seed + i, strength=0.02, size=0.08, subdiv=1)
        stones.append(s)
    stone_obj = kit.join(stones, "stones")
    kit.clip_below(stone_obj, 0.0)
    pot = d.cyl("pot", 0.13, 0.16, (0.9, -1.1, 0.45), vertices=14)
    iron = kit.join([pot], "pot")
    _settled_publish([(wood, birch_wood("poi_camp_wood_p", seed), "wood"),
                      (canvas, cloth("poi_camp_canvas_p", seed, "7a7056"), "canvas"),
                      (stone_obj, snow_rock("poi_camp_stone_p", seed), "stone"),
                      (iron, rust_material("poi_camp_pot_p", seed), "pot")], "poi_camp", 3.2, 1024)


if __name__ == "__main__":
    brazier(401)
    trail_post(403)
    totem(405)
    drift("a", 407)
    drift("b", 409)
    fallen_log(411)
    icicles(413)
    camp(415)


def crag(variant, seed, kind):
    """snow_crag_{a,b,c}: rock breaking out of the snow mountains (用户 2026-10-12:
    随机生成类似悬崖的岩壁突起). "spire": a leaning tower of split slabs;
    "wall": a short cliff face, stepped; "tor": a heap of big blocks. Grey-blue
    frozen rock; the game snows its tops. Origin at the bottom centre, built
    to sink ~0.5 into the slope it stands on."""
    kit.reset_scene()
    random.seed(seed)
    parts = []
    if kind == "spire":
        z = 0.0
        for i in range(4):
            h = random.uniform(1.0, 1.6)
            w = 1.6 - i * 0.28
            slab = kit.box(f"s{i}", (w * random.uniform(0.9, 1.2), w * random.uniform(0.7, 1.0), h),
                           (random.uniform(-0.15, 0.15), random.uniform(-0.15, 0.15), z + h / 2),
                           (random.uniform(-0.12, 0.12), random.uniform(-0.12, 0.12), random.uniform(0, math.pi)))
            kit.roughen(slab, seed + i, strength=0.14, size=0.4, bevel=0.06, subdiv=2, crack_strength=0.06, bulge=0.2, bulge_size=0.9)
            parts.append(slab)
            z += h * 0.9
    elif kind == "wall":
        for i in range(3):
            h = random.uniform(2.2, 3.6) - i * 0.5
            slab = kit.box(f"w{i}", (random.uniform(1.6, 2.4), 1.1, h), (-1.6 + i * 1.6, i * 0.35, h / 2),
                           (random.uniform(-0.08, 0.08), random.uniform(-0.08, 0.08), random.uniform(-0.15, 0.15)))
            kit.roughen(slab, seed + i, strength=0.16, size=0.45, bevel=0.07, subdiv=2, crack_strength=0.07, bulge=0.25, bulge_size=1.0)
            parts.append(slab)
    else:
        for i in range(5):
            r = random.uniform(0.6, 1.1)
            block = kit.rock(f"t{i}", r, (random.uniform(-1.2, 1.2), random.uniform(-0.9, 0.9), r * 0.6 + (0.8 if i == 4 else 0)),
                             (random.uniform(1.0, 1.4), random.uniform(0.9, 1.2), random.uniform(0.7, 1.0)))
            kit.roughen(block, seed + i, strength=0.12, size=0.35, subdiv=2, crack_strength=0.05)
            parts.append(block)
    obj = kit.join(parts, f"snow_crag_{variant}")
    kit.clip_below(obj, 0.0)
    kit.decimate(obj, 1600)
    _settled_publish([(obj, snow_rock(f"snow_crag_{variant}_rock_p", seed), "rock")], f"snow_crag_{variant}", 5.0, 512)


if __name__ == "__main__" and "--crags" in sys.argv:
    crag("a", 421, "spire")
    crag("b", 423, "wall")
    crag("c", 425, "tor")
