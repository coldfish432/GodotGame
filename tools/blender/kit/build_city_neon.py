"""Lungmen's neon: art/kit/city_neon_*.glb (用户 2026-10-16: 龙门还可以优化，
比如城区加霓虹灯).

The lower city at night is lit by its signs as much as by its street lamps:
vertical blade signs hung out over the street, boards over the shopfronts,
big frames on the roofs. Each piece is a dark steel frame and backing with
neon tubes on it, the tubes drawn white (part "glow", self-lit in the game);
CityDressing tints each placed sign its own colour (pink, cyan, red, green,
amber, violet) and lays a pool of that colour on the street below.

The tubes trace made-up characters, not real ones: strokes on a 3 x 3 grid,
read at game zoom as lettering.

Blender Z up, metres; a sign's origin is where it meets the wall (blade,
board) or the roof (roof frame), its face towards Blender -Y (Godot +Z,
the street).

    import build_city_neon as n; n.build("city_neon_blade_a")
"""
import math
import os
import random
import sys

sys.path.append(os.path.dirname(__file__))
import bpy  # noqa: E402
import kit_common as kit  # noqa: E402
import build_city_kit as city  # noqa: E402
import build_siracusa_kit as sr  # noqa: E402

TUBE = 0.09


def frame_steel(name, seed):
    return city._ramp_material(name, [(0.3, "141518"), (0.6, "22252a"), (0.95, "34383e")], 8.0, seed, 3.0)


def tube_white(name):
    return kit.flat_material(name, "fff6ee", 0.0)


def _glyph(prefix, centre, size, plane, seed, out=0.0):
    """A made-up character: 3-5 strokes along the lines of a 3 x 3 grid.
    `plane` maps (u, v) in the glyph to a world point (and its tube box)."""
    random.seed(seed)
    strokes = []
    lines = [("h", 0), ("h", 1), ("h", 2), ("v", 0), ("v", 1), ("v", 2)]
    picks = random.sample(lines, random.randint(3, 5))
    for k, (kind, i) in enumerate(picks):
        a, b = sorted(random.sample([0, 1, 2], 2))
        if kind == "h":
            u0, u1, v0, v1 = a, b, i, i
        else:
            u0, u1, v0, v1 = i, i, a, b
        if u0 == u1 and v0 == v1:
            continue
        strokes.append(plane(f"{prefix}s{k}", centre, size, (u0, v0), (u1, v1), out))
    return strokes


def _yz_plane(name, centre, size, p0, p1, out):
    """Strokes on a blade's face (the YZ plane), at x = centre.x + out."""
    cell = size / 2.0
    y0, z0 = centre[1] + (p0[0] - 1) * cell, centre[2] - (p0[1] - 1) * cell
    y1, z1 = centre[1] + (p1[0] - 1) * cell, centre[2] - (p1[1] - 1) * cell
    ly, lz = abs(y1 - y0) + TUBE, abs(z1 - z0) + TUBE
    return kit.box(name, (TUBE, ly, lz), (centre[0] + out, (y0 + y1) * 0.5, (z0 + z1) * 0.5))


def _xz_plane(name, centre, size, p0, p1, out):
    """Strokes on a board's face (the XZ plane), at y = centre.y - out."""
    cell = size / 2.0
    x0, z0 = centre[0] + (p0[0] - 1) * cell, centre[2] - (p0[1] - 1) * cell
    x1, z1 = centre[0] + (p1[0] - 1) * cell, centre[2] - (p1[1] - 1) * cell
    return kit.box(name, (abs(x1 - x0) + TUBE, TUBE, abs(z1 - z0) + TUBE), ((x0 + x1) * 0.5, centre[1] - out, (z0 + z1) * 0.5))


def _border_yz(prefix, x, y0, y1, z0, z1):
    return [kit.box(f"{prefix}t", (TUBE, y1 - y0, TUBE), (x, (y0 + y1) * 0.5, z1)),
            kit.box(f"{prefix}b", (TUBE, y1 - y0, TUBE), (x, (y0 + y1) * 0.5, z0)),
            kit.box(f"{prefix}f", (TUBE, TUBE, z1 - z0), (x, y0, (z0 + z1) * 0.5)),
            kit.box(f"{prefix}k", (TUBE, TUBE, z1 - z0), (x, y1, (z0 + z1) * 0.5))]


def _border_xz(prefix, y, x0, x1, z0, z1):
    return [kit.box(f"{prefix}t", (x1 - x0, TUBE, TUBE), ((x0 + x1) * 0.5, y, z1)),
            kit.box(f"{prefix}b", (x1 - x0, TUBE, TUBE), ((x0 + x1) * 0.5, y, z0)),
            kit.box(f"{prefix}l", (TUBE, TUBE, z1 - z0), (x0, y, (z0 + z1) * 0.5)),
            kit.box(f"{prefix}r", (TUBE, TUBE, z1 - z0), (x1, y, (z0 + z1) * 0.5))]


def _blade(name, depth, height, glyphs, seed):
    """A vertical blade sign out from the wall (-Y), its lowest edge at z = 0:
    a dark panel lettered in neon on both faces and along its top, on two
    brackets."""
    panel_t = 0.16
    y0, y1 = -0.35 - depth, -0.35
    frame = [kit.box("panel", (panel_t, depth, height), (0, (y0 + y1) * 0.5, height * 0.5)),
             kit.box("arm_top", (0.08, 0.4, 0.08), (0, -0.2, height - 0.2)),
             kit.box("arm_low", (0.08, 0.4, 0.08), (0, -0.2, 0.2)),
             kit.box("cap", (panel_t + 0.06, depth + 0.06, 0.08), (0, (y0 + y1) * 0.5, height + 0.04))]
    tubes = []
    size = min(depth * 0.62, height / glyphs * 0.62)
    for side in (-1, 1):
        x = side * (panel_t * 0.5 + TUBE * 0.5)
        tubes += _border_yz(f"bd{side}", x, y0 + 0.06, y1 - 0.06, 0.06, height - 0.06)
        for g in range(glyphs):
            zc = height - (g + 0.5) * height / glyphs
            tubes += _glyph(f"g{side}_{g}", (0.0, (y0 + y1) * 0.5, zc), size, _yz_plane, seed + g, out=x)
    # Along the top edge: what the camera sees most of from above.
    tubes.append(kit.box("toptube", (TUBE, depth - 0.1, TUBE), (0, (y0 + y1) * 0.5, height + 0.1)))
    return [(kit.join(frame, "frame"), frame_steel(f"{name}_frame_p", seed), "frame"),
            (kit.join(tubes, "glow"), tube_white(f"{name}_glow_p"), "glow")]


def city_neon_blade_a(seed=961):
    """竖招霓虹: 1.1 m out, 2.8 m tall, three characters."""
    return _blade("city_neon_blade_a", 1.1, 2.8, 3, seed)


def city_neon_blade_b(seed=963):
    """竖招霓虹（短）: 1.4 m out, 1.9 m tall, two characters."""
    return _blade("city_neon_blade_b", 1.4, 1.9, 2, seed)


def city_neon_board(seed=965):
    """店招霓虹: a 3.4 m board flat on the facade over the shopfront, tipped
    forward 15° so the camera reads it; four characters in a frame."""
    width, height = 3.4, 1.0
    tilt = math.radians(15)
    frame = [kit.box("panel", (width, 0.14, height), (0, -0.2, height * 0.5)),
             kit.box("arm_l", (0.08, 0.3, 0.08), (-width * 0.4, -0.1, height * 0.8)),
             kit.box("arm_r", (0.08, 0.3, 0.08), (width * 0.4, -0.1, height * 0.8))]
    y = -0.2 - 0.07 - TUBE * 0.5
    tubes = _border_xz("bd", y, -width * 0.5 + 0.06, width * 0.5 - 0.06, 0.06, height - 0.06)
    for g in range(4):
        xc = -width * 0.5 + (g + 0.5) * width / 4
        tubes += _glyph(f"g{g}", (xc, -0.2, height * 0.5), 0.58, _xz_plane, seed + g, out=0.07 + TUBE * 0.5)
    tubes.append(kit.box("toptube", (width - 0.1, TUBE, TUBE), (0, -0.2, height + 0.06)))
    for obj in frame + tubes:
        obj.rotation_euler = (-tilt, 0, 0)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
    for obj in frame + tubes:
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    return [(kit.join(frame, "frame"), frame_steel("city_neon_board_frame_p", seed), "frame"),
            (kit.join(tubes, "glow"), tube_white("city_neon_board_glow_p"), "glow")]


def city_neon_roof(seed=967):
    """天台霓虹: a 4.6 m lattice frame standing on the roof, set back a
    little and leaning back 20°, its characters facing the street; the
    biggest sign on the block, seen from across the floor."""
    width, height, lift = 4.6, 1.8, 0.6
    lean = math.radians(20)
    frame, tubes = [], []
    for s in (-1, 1):
        frame.append(kit.box(f"leg{s}", (0.1, 0.1, lift + 0.4), (s * (width * 0.45), 0.3, (lift + 0.4) * 0.5)))
        frame.append(kit.box(f"strut{s}", (0.08, 0.08, 1.6), (s * (width * 0.45), 0.9, 0.8), (math.radians(-35), 0, 0)))
    face = [kit.box("rail_t", (width, 0.08, 0.08), (0, 0, lift + height)),
            kit.box("rail_b", (width, 0.08, 0.08), (0, 0, lift)),
            kit.box("back", (width - 0.2, 0.05, height - 0.1), (0, 0.06, lift + height * 0.5))]
    for k in range(6):
        x = -width * 0.5 + 0.1 + k * (width - 0.2) / 5
        face.append(kit.box(f"post{k}", (0.06, 0.06, height), (x, 0, lift + height * 0.5)))
    y = -0.06
    face_tubes = _border_xz("bd", y, -width * 0.5 + 0.08, width * 0.5 - 0.08, lift + 0.08, lift + height - 0.08)
    for g in range(4):
        xc = -width * 0.5 + (g + 0.5) * width / 4
        face_tubes += _glyph(f"g{g}", (xc, 0.0, lift + height * 0.5), 0.95, _xz_plane, seed + g, out=0.06)
    # Lean the face back about its foot.
    for obj in face + face_tubes:
        obj.location.z -= lift
    for obj in face + face_tubes:
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
        obj.rotation_euler = (lean, 0, 0)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
        obj.location.z += lift
        bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    frame += face
    tubes += face_tubes
    return [(kit.join(frame, "frame"), frame_steel("city_neon_roof_frame_p", seed), "frame"),
            (kit.join(tubes, "glow"), tube_white("city_neon_roof_glow_p"), "glow")]


BUILDERS = [city_neon_blade_a, city_neon_blade_b, city_neon_board, city_neon_roof]
PREVIEW = {"city_neon_blade_a": 4.0, "city_neon_blade_b": 4.0, "city_neon_board": 4.0, "city_neon_roof": 6.0}


def publish(name, parts):
    city.BAKE_SIZE.update({"frame": 256, "glow": 64})
    city.PREVIEW.update(PREVIEW)
    return city.publish(name, parts)


def build(name, export=True):
    builder = next(b for b in BUILDERS if b.__name__ == name)
    sr.new_scene(name)
    parts = builder()
    if not export:
        return parts
    return publish(name, parts)


if __name__ == "__main__":
    for builder in BUILDERS:
        kit.reset_scene()
        publish(builder.__name__, builder())
