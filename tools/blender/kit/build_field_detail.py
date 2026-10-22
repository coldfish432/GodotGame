"""Field detail kit (用户 2026-10-20: 外勤地图的表现力都不行…矿洞应该有遮挡视线的
岩壁和通天的石柱…雪原只是需要更多精细的建模).

    mine_originium_{a,b}  a cluster of Originium crystals growing out of a rock,
                          the crystals ("glow") self-lit; TerraceDressing hangs
                          an orange light on each (the cave's own lamps,
                          as 恐怖黎明's caves are lit by their crystals and fires)
    snow_boulders_{a,b}   a heap of frost-split rocks for the open floor
    snow_ruin_{a,b}       a broken run of Ursus fieldstone wall, a pier standing
    snow_ice_shards       a cluster of upthrust ice
    snow_shrub            a frozen tundra bush, bare twigs

Snow on top is laid by the game's shaders (field_snow), not baked. Origin at
the bottom centre, Blender Z up, metres. Built through the MCP add-on in the
open Blender, each piece in a new scene (kit.reset_scene would unload it).
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
from build_snow_kit import snow_rock, birch_wood  # noqa: E402
from build_poi import _settled_publish  # noqa: E402


def _prism(name, radius, length, location, tilt, sides=6):
    """A crystal: a hexagonal prism with a pointed tip, leaning by `tilt`."""
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides, radius=radius, depth=length, location=(0, 0, length / 2))
    body = bpy.context.object
    bpy.ops.mesh.primitive_cone_add(vertices=sides, radius1=radius, radius2=0.0, depth=radius * 2.2,
                                    location=(0, 0, length + radius * 1.1))
    tip = bpy.context.object
    crystal = kit.join([body, tip], name)
    crystal.rotation_euler = tilt
    crystal.location = location
    bpy.ops.object.select_all(action="DESELECT")
    crystal.select_set(True)
    bpy.context.view_layer.objects.active = crystal
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return crystal


def originium(variant, seed):
    new_scene(f"mine_originium_{variant}")
    random.seed(seed)
    base = kit.rock("base", 0.55, (0, 0, 0.1), (1.3, 1.0, 0.55), subdivisions=3)
    kit.roughen(base, seed, strength=0.08, size=0.3, subdiv=1, crack_strength=0.04)
    kit.clip_below(base, 0.0)
    crystals = []
    for i in range(random.randint(6, 9)):
        angle = random.uniform(0, math.tau)
        lean = random.uniform(0.1, 0.65)
        r = random.uniform(0.06, 0.16)
        crystals.append(_prism(f"c{i}", r, random.uniform(0.35, 1.2) * (1.2 - lean * 0.6),
                               (math.cos(angle) * random.uniform(0.0, 0.45), math.sin(angle) * random.uniform(0.0, 0.3), 0.25),
                               (math.cos(angle + math.pi / 2) * lean, math.sin(angle + math.pi / 2) * lean, random.uniform(0, math.tau))))
    glass = kit.join(crystals, "glow")
    _settled_publish([(base, rock_material(f"mine_originium_{variant}_rock_p", seed), "rock"),
                      (glass, kit.flat_material(f"mine_originium_{variant}_glow_p", "ff9a3c", 8.0, "e0561a"), "glow")],
                     f"mine_originium_{variant}", 2.0, 512)


def boulders(variant, seed):
    new_scene(f"snow_boulders_{variant}")
    random.seed(seed)
    rocks = []
    for i in range(random.randint(3, 5)):
        r = random.uniform(0.3, 0.7) if i == 0 else random.uniform(0.15, 0.4)
        angle = random.uniform(0, math.tau)
        rock = kit.rock(f"b{i}", r, (math.cos(angle) * (0 if i == 0 else random.uniform(0.5, 0.9)), math.sin(angle) * (0 if i == 0 else random.uniform(0.4, 0.7)), r * 0.45),
                        (random.uniform(1.0, 1.4), random.uniform(0.85, 1.1), random.uniform(0.6, 0.85)))
        kit.roughen(rock, seed * 10 + i, strength=0.1 * r, size=0.3, subdiv=2, crack_strength=0.05, bulge=0.3)
        rocks.append(rock)
    heap = kit.join(rocks, "rock")
    kit.clip_below(heap, 0.0)
    kit.decimate(heap, 3000)
    _settled_publish([(heap, snow_rock(f"snow_boulders_{variant}_p", seed), "rock")], f"snow_boulders_{variant}", 2.6, 512)


def ruin(variant, seed):
    """Fieldstone courses with a broken top, a squared pier at one end."""
    new_scene(f"snow_ruin_{variant}")
    random.seed(seed)
    stones = []
    length = random.uniform(3.2, 4.2)
    z = 0.0
    course = 0
    while z < 1.9:
        height = random.uniform(0.22, 0.32)
        # The broken top: courses shorten and end ragged as the wall climbs.
        top_end = length * (1.0 - course * random.uniform(0.08, 0.16))
        x = -length / 2 + random.uniform(0.0, 0.2)
        while x < -length / 2 + top_end:
            w = random.uniform(0.35, 0.7)
            s = kit.box(f"s{course}_{len(stones)}", (w * 0.96, random.uniform(0.42, 0.5), height * 0.94),
                        (x + w / 2, random.uniform(-0.03, 0.03), z + height / 2),
                        (random.uniform(-0.03, 0.03), random.uniform(-0.03, 0.03), random.uniform(-0.04, 0.04)))
            kit.roughen(s, seed * 100 + len(stones), strength=0.025, size=0.12, bevel=0.03, subdiv=1)
            stones.append(s)
            x += w
        z += height
        course += 1
    pier = kit.box("pier", (0.7, 0.7, 2.6), (-length / 2 - 0.2, 0, 1.3))
    kit.roughen(pier, seed, strength=0.04, size=0.2, bevel=0.05, subdiv=2, crack_strength=0.05)
    stones.append(pier)
    for i in range(random.randint(3, 5)):
        r = random.uniform(0.15, 0.28)
        fallen = kit.box(f"f{i}", (r * 2.2, r * 1.6, r * 1.2), (random.uniform(-length / 2, length / 2), random.uniform(0.5, 0.9) * random.choice((-1, 1)), r * 0.5),
                         (random.uniform(-0.3, 0.3), random.uniform(-0.3, 0.3), random.uniform(0, math.tau)))
        kit.roughen(fallen, seed * 100 + 70 + i, strength=0.03, size=0.1, bevel=0.03, subdiv=1)
        stones.append(fallen)
    wall = kit.join(stones, "stone")
    kit.clip_below(wall, 0.0)
    kit.decimate(wall, 5000)
    _settled_publish([(wall, snow_rock(f"snow_ruin_{variant}_p", seed + 3), "stone")], f"snow_ruin_{variant}", 4.6, 1024)


def ice_shards(seed):
    new_scene("snow_ice_shards")
    random.seed(seed)
    shards = []
    for i in range(random.randint(7, 10)):
        angle = random.uniform(0, math.tau)
        lean = random.uniform(0.05, 0.5)
        shards.append(_prism(f"i{i}", random.uniform(0.08, 0.22), random.uniform(0.4, 1.6) * (1.1 - lean),
                             (math.cos(angle) * random.uniform(0.0, 0.6), math.sin(angle) * random.uniform(0.0, 0.45), 0.0),
                             (math.cos(angle + math.pi / 2) * lean, math.sin(angle + math.pi / 2) * lean, random.uniform(0, math.tau)), sides=5))
    ice = kit.join(shards, "ice")
    kit.clip_below(ice, 0.0)
    _settled_publish([(ice, kit.flat_material("snow_ice_shards_p", "cfeaf6", 9.0, "7fb4d0"), "ice")], "snow_ice_shards", 2.4, 512)


def shrub(seed):
    new_scene("snow_shrub")
    random.seed(seed)
    twigs = []

    def grow(start, direction, length, radius, depth):
        end = (start[0] + direction[0] * length, start[1] + direction[1] * length, start[2] + direction[2] * length)
        mid = tuple((a + b) / 2 for a, b in zip(start, end))
        bpy.ops.mesh.primitive_cylinder_add(vertices=5, radius=radius, depth=length, location=mid)
        twig = bpy.context.object
        twig.rotation_euler = (0.0, math.acos(max(-1.0, min(1.0, direction[2]))), math.atan2(direction[1], direction[0]))
        twigs.append(twig)
        if depth == 0: return
        for _ in range(random.randint(2, 3)):
            a = math.atan2(direction[1], direction[0]) + random.uniform(-0.9, 0.9)
            up = max(0.2, direction[2] + random.uniform(-0.3, 0.2))
            flat = math.sqrt(max(0.0, 1.0 - up * up))
            grow(end, (math.cos(a) * flat, math.sin(a) * flat, up), length * random.uniform(0.55, 0.75), radius * 0.65, depth - 1)

    for i in range(random.randint(5, 7)):
        a = random.uniform(0, math.tau)
        up = random.uniform(0.55, 0.9)
        flat = math.sqrt(1.0 - up * up)
        grow((random.uniform(-0.1, 0.1), random.uniform(-0.1, 0.1), 0.0), (math.cos(a) * flat, math.sin(a) * flat, up), random.uniform(0.35, 0.5), 0.03, 2)
    bush = kit.join(twigs, "wood")
    kit.clip_below(bush, 0.0)
    _settled_publish([(bush, birch_wood("snow_shrub_p", seed), "wood")], "snow_shrub", 1.8, 256)


def build_all():
    originium("a", 501)
    originium("b", 503)
    boulders("a", 511)
    boulders("b", 513)
    ruin("a", 521)
    ruin("b", 523)
    ice_shards(531)
    shrub(541)
