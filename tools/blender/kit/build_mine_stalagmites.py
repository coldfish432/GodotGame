"""Mine stalagmite clusters: art/kit/mine_stalagmites_{a,b,c}.glb.

参考《恐怖黎明》's caves (用户 2026-10-20 sent a video): the rock off the
path is not a flat dark top but lumpy stone crowded with spikes and fallen
blocks at the wall's foot and over the rock. A clump of 4-8 stalagmites of
mixed height on a shared lumpy base, in the mine cliffs' rock material.
About 2.4 across, up to ~2.6 tall; origin at the bottom centre.
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


def build(variant, seed):
    new_scene(f"mine_stalagmites_{variant}")
    random.seed(seed)
    parts = []
    base = kit.rock("base", 1.0, (0, 0, 0.05), (1.25, 1.0, 0.35), subdivisions=3)
    kit.roughen(base, seed, strength=0.1, size=0.35, subdiv=1, crack_strength=0.05)
    parts.append(base)
    for i in range(random.randint(6, 9)):
        angle = random.uniform(0, math.tau)
        reach = random.uniform(0.0, 0.85)
        height = random.uniform(1.0, 2.8) * (1.0 - reach * 0.4)
        radius = height * random.uniform(0.14, 0.22)
        bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=radius, radius2=radius * 0.12, depth=height,
                                        location=(math.cos(angle) * reach, math.sin(angle) * reach * 0.8, height / 2))
        spike = bpy.context.object
        spike.rotation_euler = (random.uniform(-0.12, 0.12), random.uniform(-0.12, 0.12), random.uniform(0, math.tau))
        kit.roughen(spike, seed * 10 + i, strength=radius * 0.25, size=radius * 1.5, subdiv=2, bulge=0.3, bulge_size=0.6)
        parts.append(spike)
    for i in range(random.randint(2, 4)):
        r = random.uniform(0.14, 0.28)
        a = random.uniform(0, math.tau)
        stone = kit.rock(f"s{i}", r, (math.cos(a) * 1.1, math.sin(a) * 0.9, r * 0.4), (1.3, 1.0, 0.7), subdivisions=2)
        kit.roughen(stone, seed * 10 + 50 + i, strength=0.04, size=0.15, subdiv=1)
        parts.append(stone)
    obj = kit.join(parts, f"mine_stalagmites_{variant}")
    kit.clip_below(obj, 0.0)
    kit.decimate(obj, 4000)
    kit.finish_mesh(obj)
    procedural = rock_material(f"mine_stalagmites_{variant}_procedural", seed)
    obj.data.materials.clear()
    obj.data.materials.append(procedural)
    image = kit.bake_texture(obj, procedural, f"mine_stalagmites_{variant}", 512)
    obj.data.materials.clear()
    obj.data.materials.append(kit.baked_material(f"mine_stalagmites_{variant}", image))
    kit.report(obj, f"mine_stalagmites_{variant}")
    print("EXPORTED", kit.export(obj, f"mine_stalagmites_{variant}"))


def build_all():
    for variant, seed in (("a", 601), ("b", 607), ("c", 613)):
        build(variant, seed)
