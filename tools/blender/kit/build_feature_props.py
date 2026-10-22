"""地图特色 props (地图特色策划案_v1_0.md §10): art/kit/snow_fire_pit.glb and
art/kit/mine_decon_shower.glb.

- 萨米火堆: a ring of frost-grey stones round charred birch, a birch stick with a
  bone charm beside it. About 1.3 m across, low; the flames are Godot's.
- 矿区净化喷淋点: a steel frame over a grated plate, a shower head, a water
  tank with yellow-black hazard bands, a cyan lamp ("glow") on the frame.

Blender Z up, metres; origin at the bottom centre. Through the MCP add-on:

    import build_feature_props as k; k.build("snow_fire_pit")
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


def snow_fire_pit(seed=1901):
    """萨米火堆: stones, charred birch laid as a cone, a bone charm on a stick."""
    random.seed(seed)
    rocks = []
    for k in range(10):
        a = k / 10 * math.tau + random.uniform(-0.12, 0.12)
        r = random.uniform(0.52, 0.6)
        rocks.append(rough_rock(f"r{k}", random.uniform(0.11, 0.16), (math.cos(a) * r, math.sin(a) * r, 0.07), seed + k))
    logs, bark = [], []
    for k in range(5):
        a = k / 5 * math.tau + random.uniform(-0.2, 0.2)
        # Leaning in to a cone: the foot out on the ash, the top over the middle.
        foot = Vector((math.cos(a) * 0.4, math.sin(a) * 0.4, 0.04))
        top = Vector((math.cos(a) * 0.03, math.sin(a) * 0.03, 0.5))
        axis = top - foot
        rot = axis.to_track_quat("Z", "Y").to_euler()
        logs.append(d.cyl(f"l{k}", 0.05, axis.length, (foot + top) / 2, rotation=rot, vertices=8))
        # Pale birch bark still on the unburnt foot.
        bark.append(d.cyl(f"b{k}", 0.054, 0.16, foot + axis.normalized() * 0.08, rotation=rot, vertices=8))
    ash = [d.cyl("ash", 0.42, 0.03, (0, 0, 0.015), vertices=16)]
    stick = [d.cyl("stick", 0.025, 1.1, (0.78, 0.25, 0.55), vertices=6)]
    bone = [d.cyl("bone", 0.03, 0.22, (0.78, 0.25, 0.95), vertices=6), kit.box("bonex", (0.16, 0.03, 0.03), (0.78, 0.25, 1.0))]
    return [(kit.join(rocks, "rock"), stone("snow_fire_pit_rock_p", seed, "8a9096"), "rock"),
            (kit.join(logs + stick, "char"), flat("snow_fire_pit_char_p", "2a2420", "120e0c"), "char"),
            (kit.join(bark, "bark"), flat("snow_fire_pit_bark_p", "d8d4c8", "3a3632", 14.0), "bark"),
            (kit.join(ash, "ash"), flat("snow_fire_pit_ash_p", "4a4644", "26221f"), "ash"),
            (kit.join(bone, "bone"), flat("snow_fire_pit_bone_p", "e6dcc4"), "bone")]


def mine_decon_shower(seed=1903):
    """矿区净化喷淋点: steel frame, grated plate, shower head, hazard tank, cyan lamp."""
    plate = [d.bbox("plate", (1.3, 1.3, 0.08), (0, 0, 0.04), width=0.01)]
    grate = [kit.box(f"g{k}", (1.2, 0.03, 0.02), (0, -0.55 + k * 0.1, 0.09)) for k in range(12)]
    frame = [d.bbox(f"p{x}", (0.1, 0.1, 2.4), (x * 0.6, 0, 1.28), width=0.01) for x in (-1, 1)]
    frame.append(d.bbox("top", (1.3, 0.1, 0.1), (0, 0, 2.48), width=0.01))
    frame.append(d.bbox("pipe", (0.06, 0.5, 0.06), (0, -0.25, 2.48), width=0.005))
    head = [d.cyl("head", 0.16, 0.06, (0, -0.5, 2.4), vertices=14)]
    tank = [d.cyl("tank", 0.32, 0.95, (1.05, 0.1, 0.5), vertices=16)]
    # Hazard bands round the tank, and its valve, in black.
    bands = [d.cyl(f"band{k}", 0.335, 0.1, (1.05, 0.1, z), vertices=16) for k, z in enumerate((0.2, 0.5, 0.8))]
    bands.append(d.cyl("valve", 0.06, 0.1, (1.05, 0.1, 1.02), vertices=8))
    lamp = [d.cyl("lamp", 0.07, 0.12, (-0.6, 0, 2.6), vertices=10)]
    return [(kit.join(plate + grate, "plate"), steel("mine_decon_shower_plate_p", seed, "3e4246"), "plate"),
            (kit.join(frame + head, "steel"), steel("mine_decon_shower_steel_p", seed, "6a7076"), "steel"),
            (kit.join(tank, "tank"), flat("mine_decon_shower_tank_p", "e0b020", "a07a10", 8.0), "tank"),
            (kit.join(bands, "band"), flat("mine_decon_shower_band_p", "161616"), "band"),
            (kit.join(lamp, "glow"), flat("mine_decon_shower_glow_p", "5ae6ff"), "glow")]


BUILDERS = [snow_fire_pit, mine_decon_shower]
PREVIEW = {"snow_fire_pit": 2.4, "mine_decon_shower": 3.6}
BAKE_SIZE = {"rock": 512, "char": 256, "bark": 256, "ash": 256, "bone": 128, "plate": 256, "steel": 256, "tank": 256, "band": 64, "glow": 64}


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
