"""snow_bridge: a natural rock arch carrying one road over another (用户 2026-10-13:
下面的路从上面的路下面穿过，形成有高度差的不连在一起的回路).

The game (ContinuousWorldMap bridges) digs the upper road as two stubs at the
deck's level that stop at the lower road's cliffs, and stands this piece
between them. Blender X runs along the span, Y across it, Z up; the origin is
the middle of the deck's top, which is flat at z = 0 so the road walks onto it
flush. The cliff lines it springs from sit at x = +-SPAN / 2, 4.4 below the
deck (two terrace tiers); past them the body is buried under the stubs'
floor. The game scales X to the span it needs. Snow on the deck is the
shader's (field_snow), as on every other piece.

Built through the Blender MCP add-on into the open Blender (a new scene), or
headless:

    blender -b --factory-startup --python-exit-code 1 --python tools/blender/kit/build_snow_bridge.py
"""
import math
import os
import random
import sys

sys.path.append(os.path.dirname(__file__))
import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector, noise  # noqa: E402
import kit_common as kit  # noqa: E402
from build_snow_kit import snow_rock  # noqa: E402
from build_poi import _publish  # noqa: E402

SPAN = 10.0          # between the two cliff lines
LENGTH = 12.8        # with the ends buried under the stubs
HALF_WIDTH = 2.5     # flat deck either side of the centre line
DROP = 4.4           # deck to the road below
CROWN = 1.3          # deck thickness at mid-span
STEPS = 64
RING_TOP = 8
RING_SIDE = 7
RING_UNDER = 8


def underside(x):
    """Arch soffit: thin at the crown, springing from the lower road at the
    cliff lines, solid below the stubs past them."""
    f = min(abs(x) / (SPAN * 0.5), 1.0)
    return -(CROWN + (DROP + 0.5 - CROWN) * f ** 3)


def _ring(x):
    """Cross-section (y, z, displace weight) at x, round from the deck's
    left edge across the top, down the right side, back under, up the left."""
    soffit = underside(x)
    pts = []
    for i in range(RING_TOP):
        pts.append((-HALF_WIDTH + 2 * HALF_WIDTH * i / RING_TOP, 0.0, 0.0))
    for i in range(RING_SIDE):
        f = i / RING_SIDE
        pts.append((HALF_WIDTH + 0.12 + 0.35 * math.sin(math.pi * f), soffit * f, 1.0))
    for i in range(RING_UNDER):
        y = HALF_WIDTH + 0.1 - (2 * HALF_WIDTH + 0.2) * i / RING_UNDER
        pts.append((y, soffit - 0.15 * math.sin(math.pi * i / RING_UNDER), 1.0))
    for i in range(RING_SIDE):
        f = 1.0 - i / RING_SIDE
        pts.append((-HALF_WIDTH - 0.12 - 0.35 * math.sin(math.pi * f), soffit * f, 1.0))
    return pts


def body(seed):
    """The arch: the cross-section swept along X, then pushed in and out by
    world-space noise along each vertex's outward direction. The deck's top
    is left flat."""
    random.seed(seed)
    offset = Vector((random.uniform(-90, 90), random.uniform(-90, 90), random.uniform(-90, 90)))
    mesh = bpy.data.meshes.new("snow_bridge_body")
    bm = bmesh.new()
    rings = []
    for s in range(STEPS + 1):
        x = -LENGTH * 0.5 + LENGTH * s / STEPS
        ring = []
        pts = _ring(x)
        for k, (y, z, weight) in enumerate(pts):
            p = Vector((x, y, z))
            if weight > 0.0:
                centre = Vector((x, 0.0, underside(x) * 0.5))
                out = (p - centre)
                out.x = 0.0
                out.normalize()
                n = noise.fractal(p * 0.45 + offset, 0.6, 2.2, 4) * 0.42 + noise.noise(p * 1.6 + offset) * 0.1
                p += out * n * weight
            ring.append(bm.verts.new(p))
        rings.append(ring)
    count = len(rings[0])
    for s in range(STEPS):
        a, b = rings[s], rings[s + 1]
        for k in range(count):
            j = (k + 1) % count
            bm.faces.new((a[k], a[j], b[j], b[k]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("snow_bridge_body", mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def lips(seed):
    """Broken rock along both edges of the deck: it reads as a ridge of rock,
    not a slab, and frames the walkable top (the game walls it at +-2.45)."""
    random.seed(seed)
    stones = []
    for side in (-1.0, 1.0):
        x = -LENGTH * 0.5 + 1.0
        while x < LENGTH * 0.5 - 1.0:
            r = random.uniform(0.22, 0.42)
            stone = kit.rock(f"lip{len(stones)}", r, (x, side * (HALF_WIDTH + 0.1 + random.uniform(-0.05, 0.12)), r * 0.25),
                             (random.uniform(1.2, 1.8), random.uniform(0.8, 1.1), random.uniform(0.6, 0.9)), subdivisions=2)
            kit.roughen(stone, seed + len(stones), strength=0.06, size=0.18, subdiv=1)
            stones.append(stone)
            x += random.uniform(0.6, 1.1)
    obj = kit.join(stones, "snow_bridge_lips")
    kit.clip_below(obj, -0.3)
    kit.decimate(obj, 3000)
    return obj


def icicles(seed):
    """Ice hanging from the soffit under the crown, thickest along both edges
    where meltwater runs off the deck."""
    random.seed(seed)
    spikes = []
    x = -SPAN * 0.3
    while x < SPAN * 0.3:
        for side in (-1.0, 1.0):
            if random.random() < 0.35: continue
            length = random.uniform(0.2, 0.7) * (1.0 - abs(x) / SPAN)
            y = side * random.uniform(1.4, HALF_WIDTH)
            top = underside(x) - 0.15 * math.sin(math.pi * (HALF_WIDTH + 0.1 - y) / (2 * HALF_WIDTH + 0.2)) + 0.12
            bpy.ops.mesh.primitive_cone_add(vertices=5, radius1=random.uniform(0.05, 0.1), radius2=0.0, depth=length,
                                            location=(x, y, top - length * 0.5), rotation=(math.pi, 0, 0))
            spikes.append(bpy.context.object)
        x += random.uniform(0.2, 0.45)
    return kit.join(spikes, "snow_bridge_ice")


def build(seed=431):
    deck = body(seed)
    kit.decimate(deck, 7000)
    rim = lips(seed + 1)
    ice = icicles(seed + 2)
    return [(deck, snow_rock("snow_bridge_rock_p", seed), "rock"),
            (rim, snow_rock("snow_bridge_lip_p", seed + 1), "lip"),
            (ice, kit.flat_material("snow_bridge_ice_p", "c8dde8", 9.0, "8fb0c2"), "ice")]


def publish(parts):
    return _publish(parts, "snow_bridge", 14.0, 1024)


if __name__ == "__main__":
    kit.reset_scene()
    publish(build())
