"""Mine cave pillars, three variants: art/kit/mine_pillar_{a,b,c}.glb.

用户 2026-10-20: 矿洞应该有遮挡视线的岩壁和通天的石柱. One stands on each rock
island in a mine room (TerrainSurface._raise_pillars keeps the island low;
TerraceDressing places the column on it, scaled to the island's radius).

Footprint radius 1.0 at the foot, 24 tall: from the camera it runs off the
top of the screen into the dark. Built as a stack of mis-set, lumpy rock drums
that narrow to a waist and flare again at the head (a stalagmite grown into a
stalactite), with a skirt of fallen boulders round the foot. Same rock
material as the mine cliffs, so the column and the walls are one stone.
"""
import math
import os
import random
import sys

sys.path.append(os.path.dirname(__file__))
import bpy  # noqa: E402
import kit_common as kit  # noqa: E402
from build_mine_cliff import rock_material  # noqa: E402
from build_siracusa_kit import new_scene  # noqa: E402

HEIGHT = 24.0


def profile(t):
    """Radius at height fraction t: a broad flared foot, a waist at ~0.5, and a
    head that spreads again into the roof."""
    foot = 0.74 + 0.26 * (1.0 - min(t / 0.5, 1.0)) ** 2
    head = 0.55 * max(0.0, (t - 0.5) / 0.5) ** 1.5
    return foot + head


def build(variant, seed):
    # A new scene in the open Blender: kit.reset_scene's factory reset would
    # unload the MCP add-on.
    new_scene(f"mine_pillar_{variant}")
    random.seed(seed)
    parts = []
    z = 0.0
    lean = (random.uniform(-0.25, 0.25), random.uniform(-0.25, 0.25))
    while z < HEIGHT:
        t = z / HEIGHT
        height = random.uniform(1.6, 2.8) * (1.0 + t * 0.5)
        radius = profile(t) * random.uniform(0.9, 1.08)
        # The column wanders a little off plumb, more towards its waist.
        sway = math.sin(t * math.pi)
        centre = (lean[0] * sway + random.uniform(-0.1, 0.1), lean[1] * sway + random.uniform(-0.1, 0.1))
        drum = kit.rock(f"drum{len(parts)}", radius, (centre[0], centre[1], z + height * 0.5),
                        (random.uniform(0.9, 1.15), random.uniform(0.9, 1.15), height / (2 * radius) * 1.4))
        kit.roughen(drum, seed * 100 + len(parts), strength=0.16 * radius, size=0.5, subdiv=2,
                    crack_strength=0.07, bulge=0.4, bulge_size=1.0)
        parts.append(drum)
        # Lumps of stone bulging from its flank: no two heights alike.
        for k in range(random.randint(1, 2)):
            a = random.uniform(0, math.tau)
            r = radius * random.uniform(0.3, 0.45)
            lump = kit.rock(f"lump{len(parts)}", r, (centre[0] + math.cos(a) * radius * 0.6, centre[1] + math.sin(a) * radius * 0.6, z + height * random.uniform(0.2, 0.8)),
                            (random.uniform(0.8, 1.1), random.uniform(0.8, 1.1), random.uniform(1.2, 2.0)))
            kit.roughen(lump, seed * 100 + 500 + len(parts), strength=0.12 * r, size=0.35, subdiv=1, crack_strength=0.05)
            parts.append(lump)
        z += height * 0.62
    for i in range(random.randint(4, 6)):
        angle = random.uniform(0, math.tau)
        r = random.uniform(0.18, 0.34)
        boulder = kit.rock(f"foot{i}", r, (math.cos(angle) * 0.95, math.sin(angle) * 0.95, r * 0.4),
                           (random.uniform(1.0, 1.4), random.uniform(0.8, 1.1), random.uniform(0.55, 0.8)))
        kit.roughen(boulder, seed * 100 + 60 + i, strength=0.1, size=0.25, subdiv=1)
        parts.append(boulder)
    obj = kit.join(parts, f"mine_pillar_{variant}")
    kit.clip_below(obj, 0.0)
    kit.decimate(obj, 14000)
    kit.finish_mesh(obj)
    procedural = rock_material(f"mine_pillar_{variant}_procedural", seed)
    obj.data.materials.clear()
    obj.data.materials.append(procedural)
    image = kit.bake_texture(obj, procedural, f"mine_pillar_{variant}")
    obj.data.materials.clear()
    obj.data.materials.append(kit.baked_material(f"mine_pillar_{variant}", image))
    kit.report(obj, f"mine_pillar_{variant}")
    path = kit.export(obj, f"mine_pillar_{variant}")
    print("EXPORTED", path)


if __name__ == "__main__":
    for variant, seed in (("a", 41), ("b", 53), ("c", 67)):
        build(variant, seed)
