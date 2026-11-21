"""mine_trestle: the mine's overpass (立交桥修订案 v0.1 §3, 用户 2026-11-21:
矿洞和叙拉古也要): a steel trestle carrying a rail track over the drift below.

The same frame as snow_bridge and city_overpass, which ContinuousWorldMap
stands between two stubs dug at the deck's level: Blender X along the span,
Y across, Z up; the origin is the middle of the deck's top (flat, z = 0); the
cliff lines it springs from at x = +-SPAN / 2, DROP below; the game scales X
to the span and walls the deck at +-2.45 itself. Nothing stands under the
middle: the drift below is walked.

What makes it the mine's (地区靠风格区分): timber sleepers on two riveted
steel stringers, a narrow-gauge track down the middle, trestle bents of
braced steel at both cliff lines, a hand rail over a toe board in hazard
stripes, and pit lamps hung from the rail posts.

Through the Blender MCP add-on (a new scene in the open Blender):

    import build_mine_trestle as m; m.build()
"""
import math
import os
import random
import sys

sys.path.append(os.path.dirname(__file__))
import bpy  # noqa: E402
import kit_common as kit  # noqa: E402
import poi_detail as d  # noqa: E402
from build_mine_accents import rust_material, wood_material, _lantern_parts  # noqa: E402
from build_poi import painted  # noqa: E402
import build_city_kit as city  # noqa: E402

SPAN = 10.0
LENGTH = 12.8
HALF_WIDTH = 2.5
DROP = 4.4


def mine_trestle(seed=1101):
    random.seed(seed)
    steel, timber, stripes_y, stripes_k, glow = [], [], [], [], []
    # Deck: sleepers across, their tops the walking surface, on two stringers.
    x = -LENGTH * 0.5 + 0.2
    k = 0
    while x < LENGTH * 0.5 - 0.1:
        timber.append(d.bbox(f"sleeper{k}", (0.32, HALF_WIDTH * 2 + 0.2, 0.18), (x, 0, -0.09 - random.uniform(0.0, 0.015)), width=0.02))
        x += 0.46
        k += 1
    for s in (-1, 1):
        steel.append(d.bbox(f"stringer{s}", (LENGTH, 0.22, 0.55), (0, s * 1.55, -0.46), width=0.02))
        steel.append(kit.box(f"flange{s}", (LENGTH, 0.42, 0.06), (0, s * 1.55, -0.72)))
        # Rails of the narrow-gauge track.
        steel.append(kit.box(f"rail{s}", (LENGTH, 0.07, 0.11), (0, s * 0.6, 0.055)))
    # Bents at the cliff lines: two legs, cross bracing, a cap beam.
    for side in (-1, 1):
        bx = side * SPAN * 0.5
        steel.append(d.bbox(f"cap{side}", (0.5, HALF_WIDTH * 2 + 0.6, 0.35), (bx, 0, -0.9), width=0.02))
        for s in (-1, 1):
            steel.append(d.bbox(f"leg{side}{s}", (0.32, 0.32, DROP + 0.8), (bx, s * 2.1, -(DROP + 0.8) * 0.5 - 0.5), width=0.02))
        length = math.hypot(4.2, DROP - 1.0)
        tilt = math.atan2(DROP - 1.0, 4.2)
        for s in (-1, 1):
            steel.append(kit.box(f"brace{side}{s}", (0.12, length, 0.12), (bx, 0, -(DROP + 1.0) * 0.5 - 0.3), (s * tilt, 0, 0)))
        steel.append(kit.box(f"tie{side}", (0.14, 4.2, 0.14), (bx, 0, -DROP + 0.3)))
    # Rail posts and hand rail; the toe board between them in hazard stripes.
    for s in (-1, 1):
        y = s * (HALF_WIDTH + 0.05)
        px = -LENGTH * 0.5 + 0.4
        while px <= LENGTH * 0.5 - 0.3:
            steel.append(kit.box(f"post{s}_{px:.1f}", (0.09, 0.09, 1.1), (px, y, 0.55)))
            px += 1.5
        steel.append(kit.box(f"handrail{s}", (LENGTH - 0.6, 0.08, 0.08), (0, y, 1.1)))
        steel.append(kit.box(f"midrail{s}", (LENGTH - 0.6, 0.05, 0.05), (0, y, 0.6)))
        sx = -LENGTH * 0.5 + 0.4
        n = 0
        while sx < LENGTH * 0.5 - 0.4:
            (stripes_y if n % 2 == 0 else stripes_k).append(kit.box(f"toe{s}_{n}", (0.4, 0.04, 0.22), (sx + 0.2, y, 0.11)))
            sx += 0.4
            n += 1
        # Pit lamps hung off two posts each side.
        for lx in (-2.5, 2.5):
            arm = kit.box(f"arm{s}{lx}", (0.05, 0.4, 0.05), (lx, y - s * 0.2, 1.05))
            steel.append(arm)
            cage, glass = _lantern_parts(seed, at=(lx, y - s * 0.38, 1.02))
            steel += cage
            glow.append(glass)
    return [(kit.join(steel, "steel"), rust_material("mine_trestle_steel_p", seed), "steel"),
            (kit.join(timber, "timber"), wood_material("mine_trestle_timber_p", seed), "timber"),
            (kit.join(stripes_y, "stripe"), painted("mine_trestle_stripe_p", "d8a820", seed), "stripe"),
            (kit.join(stripes_k, "dark"), painted("mine_trestle_dark_p", "26282a", seed), "dark"),
            (kit.join(glow, "glow"), kit.flat_material("mine_trestle_glow_p", "ffc04a", 6.0, "e8801e"), "glow")]


def new_scene(name):
    scene = bpy.data.scenes.new(name)
    bpy.context.window.scene = scene
    scene.unit_settings.system = "METRIC"
    try:
        scene.render.engine = "CYCLES"
    except TypeError:
        pass
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    return scene


def build(export=True):
    new_scene("mine_trestle")
    parts = mine_trestle()
    if not export:
        return parts
    city.BAKE_SIZE.update({"steel": 1024, "timber": 512, "stripe": 128, "dark": 128, "glow": 128})
    city.PREVIEW["mine_trestle"] = 15.0
    return city.publish("mine_trestle", parts)


if __name__ == "__main__":
    kit.reset_scene()
    build()
