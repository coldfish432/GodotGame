"""Snow-laden conifers for the snowfield's forest (用户 2026-10-12: 要做):
art/kit/snow_pine_{a,b,c}.glb and snow_snag.glb.

The forest stands off the road, on the rock (TerraceDressing._place_trees),
as the frame of every corridor — 恐怖黎明's Frostveil and 暗黑 IV's Fractured
Peaks both read as forest first. Kept light (a few hundred triangles each):
a floor plants hundreds. Snow is not baked: field_snow lays it on every
upward needle face in the game, so the canopy whitens where it faces the sky.

Origin at the foot of the trunk, Blender Z up, metres.

Run: blender -b --factory-startup --python-exit-code 1 --python tools/blender/kit/build_snow_trees.py
"""
import math
import os
import random
import sys

sys.path.append(os.path.dirname(__file__))
import bpy  # noqa: E402
import kit_common as kit  # noqa: E402
from build_mine_accents import wood_material  # noqa: E402
from build_poi import _ramp_material, _settled_publish  # noqa: E402


def needles(name, seed):
    return _ramp_material(name, [(0.3, "142a20"), (0.6, "234231"), (0.85, "35573f")], 8.0, seed, 5.0)


def bark(name, seed):
    return _ramp_material(name, [(0.3, "2a1e16"), (0.6, "4a3628"), (0.9, "6a5240")], 12.0, seed, 4.0)


def _tier(name, radius, height, z, seed, jag=0.12):
    """One skirt of branches: a low cone with a ragged rim."""
    bpy.ops.mesh.primitive_cone_add(vertices=9, radius1=radius, radius2=radius * 0.12, depth=height, location=(0, 0, z + height / 2))
    cone = bpy.context.object
    cone.name = name
    random.seed(seed)
    for v in cone.data.vertices:
        if v.co.z < 0:  # rim: push points in and out, droop some
            k = random.uniform(1.0 - jag, 1.0 + jag)
            v.co.x *= k
            v.co.y *= k
            v.co.z -= random.uniform(0.0, height * 0.18)
    cone.rotation_euler = (0, 0, random.uniform(0, math.tau))
    bpy.ops.object.transform_apply(rotation=True)
    return cone


def pine(variant, seed, height, width, tiers):
    kit.reset_scene()
    random.seed(seed)
    trunk_h = height * 0.22
    bpy.ops.mesh.primitive_cylinder_add(vertices=7, radius=width * 0.07, depth=height * 0.95, location=(0, 0, height * 0.475))
    trunk = bpy.context.object
    for v in trunk.data.vertices:
        if v.co.z > 0: v.co.x *= 0.4; v.co.y *= 0.4
    crown = []
    span = height - trunk_h
    for i in range(tiers):
        t = i / max(tiers - 1, 1)
        r = width * 0.5 * (1.0 - t * 0.78) * random.uniform(0.9, 1.08)
        h = span / tiers * 1.7
        z = trunk_h + span * t * 0.86
        crown.append(_tier(f"tier{i}", r, h, z, seed + i))
    tip = _tier("tip", width * 0.09, span * 0.18, height * 0.86, seed + 99, 0.05)
    canopy = kit.join(crown + [tip], "canopy")
    lean = random.uniform(-0.05, 0.05)
    for obj in (trunk, canopy):
        obj.rotation_euler = (lean, random.uniform(-0.04, 0.04), 0)
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.transform_apply(rotation=True)
    _settled_publish([(trunk, bark(f"snow_pine_{variant}_bark_p", seed), "bark"),
                      (canopy, needles(f"snow_pine_{variant}_needles_p", seed), "needles")], f"snow_pine_{variant}", height * 1.3, 256)


def snag(seed):
    """snow_snag: a dead pine, bark stripped grey, a few broken limbs."""
    kit.reset_scene()
    random.seed(seed)
    bpy.ops.mesh.primitive_cylinder_add(vertices=7, radius=0.22, depth=5.0, location=(0, 0, 2.5))
    trunk = bpy.context.object
    for v in trunk.data.vertices:
        if v.co.z > 0: v.co.x *= 0.35; v.co.y *= 0.35
    limbs = []
    for i in range(6):
        z = random.uniform(1.8, 4.4)
        a = random.uniform(0, math.tau)
        length = random.uniform(0.5, 1.3) * (1.2 - z / 6.0)
        bpy.ops.mesh.primitive_cylinder_add(vertices=5, radius=0.04, depth=length,
                                            location=(math.cos(a) * length * 0.45, math.sin(a) * length * 0.45, z),
                                            rotation=(math.sin(a) * 1.1, -math.cos(a) * 1.1, 0))
        limbs.append(bpy.context.object)
    wood = kit.join([trunk] + limbs, "wood")
    _settled_publish([(wood, _ramp_material("snow_snag_wood_p", [(0.3, "3a3632"), (0.6, "6a645c"), (0.9, "908a80")], 10.0, seed, 4.0), "wood")],
                     "snow_snag", 6.5, 256)


if __name__ == "__main__":
    pine("a", 501, 8.0, 3.4, 6)
    pine("b", 503, 6.0, 3.6, 5)
    pine("c", 505, 3.6, 2.0, 4)
    snag(507)
