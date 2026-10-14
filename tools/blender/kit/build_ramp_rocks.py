"""ramp_rock_{big,small}_{a,b} and the snowfield's ramp_snow_rock_*: the rocks that
line a ramp's sides (用户 2026-10-13: 路边石改为大块岩石和小石头交错，不要现在这种
长方体). TerraceDressing sets big boulders and clusters of small stones
alternately along both real edges of every ramp.

"big": a boulder with a smaller one leaning on it, irregular, origin at road
level; it runs ROOT below the road so where the causeway's side falls away
(TerrainSurface._causeways) the rock goes down with it instead of floating.
"small": three or four stones scattered over ~0.9 m, sunk a little.
Mine rock for the mine and the city, frozen grey-blue rock for the snowfield,
whose tops the game snows.

Through the Blender MCP add-on into new scenes of the open Blender, or:

    blender -b --factory-startup --python-exit-code 1 --python tools/blender/kit/build_ramp_rocks.py
"""
import os
import random
import sys

sys.path.append(os.path.dirname(__file__))
import bpy  # noqa: E402
import kit_common as kit  # noqa: E402
from build_mine_cliff import rock_material  # noqa: E402
from build_poi import _publish  # noqa: E402

ROOT = 1.2  # how far a big rock reaches below the road


def big(seed):
    random.seed(seed)
    r = random.uniform(0.55, 0.7)
    main = kit.rock("main", r, (0.0, 0.0, r * 0.35 - ROOT * 0.35), (random.uniform(1.1, 1.4), random.uniform(0.85, 1.05), random.uniform(1.15, 1.45)), subdivisions=3)
    kit.roughen(main, seed, strength=0.16, size=0.35, subdiv=2, crack_strength=0.06, bulge=0.12, bulge_size=0.8)
    r2 = r * random.uniform(0.45, 0.6)
    side = kit.rock("side", r2, (r * random.uniform(0.8, 1.0), random.uniform(-0.2, 0.2), r2 * 0.4 - 0.1), (1.2, 1.0, 0.9), subdivisions=2)
    kit.roughen(side, seed + 1, strength=0.08, size=0.25, subdiv=2, crack_strength=0.04)
    obj = kit.join([main, side], "rock")
    # The foot: everything below the road stretched down to ROOT.
    for v in obj.data.vertices:
        if v.co.z < 0.0: v.co.z *= ROOT / max(0.3, r * 0.9)
    obj.data.update()
    kit.decimate(obj, 1800)
    return obj


def small(seed):
    random.seed(seed)
    stones = []
    for i in range(random.randint(3, 4)):
        r = random.uniform(0.11, 0.24)
        stone = kit.rock(f"s{i}", r, (random.uniform(-0.45, 0.45), random.uniform(-0.25, 0.25), r * 0.3),
                         (random.uniform(1.0, 1.5), random.uniform(0.8, 1.1), random.uniform(0.6, 0.85)), subdivisions=2)
        kit.roughen(stone, seed + i, strength=0.04, size=0.12, subdiv=1, crack_strength=0.02)
        stones.append(stone)
    obj = kit.join(stones, "stones")
    kit.clip_below(obj, -0.05)
    kit.decimate(obj, 900)
    return obj


def build(kind, variant, seed, snow):
    name = f"ramp_{'snow_' if snow else ''}rock_{kind}_{variant}"
    obj = big(seed) if kind == "big" else small(seed)
    obj.name = name
    if snow:
        from build_snow_kit import snow_rock
        material = snow_rock(f"{name}_p", seed)
    else:
        material = rock_material(f"{name}_p", seed)
    return name, [(obj, material, "rock")]


def publish(name, parts):
    return _publish(parts, name, 2.4, 512)


PIECES = [("big", "a", 531), ("big", "b", 533), ("small", "a", 535), ("small", "b", 537)]

if __name__ == "__main__":
    for kind, variant, seed in PIECES:
        for snow in (False, True):
            kit.reset_scene()
            publish(*build(kind, variant, seed, snow))
