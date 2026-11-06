"""The camp between blocks (用户 2026-10-31: 营地层也要有地图, 用blender建模相关模型):
art/kit/enc_closure_stall.glb, camp_tent.glb, camp_floodlight.glb.

- enc_closure_stall: 可露希尔's counter in the field. A tall Rhodes-white
  supply locker with a lit window strip (her vending fridge, carried out),
  stacked hard cases, and a folding counter with a cash terminal. A pennant
  pole at the back. Low and open at the front right, where she stands
  (ContinuousWorldMap.ENCOUNTER_STAND.closure).
- camp_tent: a Rhodes A-frame field tent, canvas over a ridge pole, the front
  flap tied open on a dark inside, pegs and guy lines at the corners.
- camp_floodlight: a work-light mast on a tripod, a lamp panel tilted down,
  and a small generator at its foot with a cable between.

Materials reuse the encounter swatches (build_encounter: rhodes_case,
rhodes_pennant, rhodes_trim_glow, the logo decal); a part named "glow" is
drawn self-lit in the game. Origin at the bottom centre, Blender Z up,
metres, front towards Blender -Y.

Built through the Blender MCP add-on into the open Blender, one new scene per
piece (build_encounter.new_scene, then build_encounter.publish), or headless:

    blender -b --factory-startup --python-exit-code 1 --python tools/blender/kit/build_camp.py
"""
import math
import os
import random
import sys

sys.path.append(os.path.dirname(__file__))
import bpy  # noqa: E402
import mathutils  # noqa: E402
import kit_common as kit  # noqa: E402
import poi_detail as d  # noqa: E402
import build_encounter as enc  # noqa: E402


def _strut(name, foot, top, radius):
    """A round bar from `foot` to `top`."""
    mid = [(foot[k] + top[k]) / 2 for k in range(3)]
    bar = d.cyl(name, radius, math.dist(foot, top), mid, vertices=8)
    bar.rotation_euler = mathutils.Vector([top[k] - foot[k] for k in range(3)]).to_track_quat("Z", "Y").to_euler()
    return enc._apply(bar)


def _prism(name, outline, y0, y1):
    """A flat shape in x/z (`outline`, counter-clockwise), from y0 to y1."""
    import bmesh
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    near = [bm.verts.new((x, y0, z)) for x, z in outline]
    far = [bm.verts.new((x, y1, z)) for x, z in outline]
    bm.faces.new(near)
    bm.faces.new(list(reversed(far)))
    for i in range(len(outline)):
        j = (i + 1) % len(outline)
        bm.faces.new((near[i], far[i], far[j], near[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def build_closure_stall(seed=421):
    """可露希尔's camp counter, about 2.6 x 1.6 m, 2.3 m to the pennant top."""
    random.seed(seed)
    # The supply locker, back left: tall, white, a lit strip down its door.
    lx, ly = -0.85, 0.35
    locker = d.bevel(kit.box("locker", (0.78, 0.62, 1.62), (lx, ly, 0.81)), 0.04, 3)
    door = d.bbox("locker_door", (0.66, 0.03, 1.42), (lx, ly - 0.32, 0.84), width=0.01)
    window = kit.box("locker_window", (0.5, 0.012, 0.7), (lx, ly - 0.34, 1.08))
    strip = kit.box("locker_strip", (0.04, 0.012, 1.3), (lx + 0.28, ly - 0.34, 0.84))
    vent = kit.box("locker_vent", (0.5, 0.012, 0.12), (lx, ly - 0.34, 0.2))
    feet = [d.cyl(f"locker_foot{i}", 0.03, 0.04, (lx + sx * 0.3, ly + sy * 0.24, 0.02), vertices=8)
            for i, (sx, sy) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1)))]
    # Hard cases stacked by the locker, the top one turned.
    low = enc._hard_case("lo", (0.86, 0.54, 0.42), (0.12, 0.42, 0.0))
    high = enc._hard_case("hi", (0.66, 0.46, 0.34), (0.1, 0.44, 0.42), yaw=-0.15)
    side = enc._hard_case("sd", (0.5, 0.36, 0.3), (-0.2, -0.32, 0.0), yaw=0.35)
    # The folding counter, right of centre: a top on two A-legs, a terminal on it.
    cx, cy = 0.78, 0.1
    top = d.bevel(kit.box("counter_top", (1.0, 0.56, 0.05), (cx, cy, 0.86)), 0.015, 2)
    lip = kit.box("counter_lip", (1.0, 0.02, 0.1), (cx, cy - 0.28, 0.82))
    legs = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            legs.append(_strut(f"cleg{sx}{sy}", (cx + sx * 0.42, cy + sy * 0.3, 0.0), (cx + sx * 0.4, cy + sy * 0.18, 0.84), 0.015))
    till = d.bbox("till", (0.34, 0.26, 0.12), (cx + 0.18, cy + 0.06, 0.95), width=0.01)
    screen_back = d.bbox("till_screen", (0.3, 0.03, 0.2), (cx + 0.18, cy + 0.16, 1.1), (math.radians(14), 0, 0), width=0.008)
    screen = kit.box("till_glass", (0.26, 0.008, 0.16), (cx + 0.18, cy + 0.143, 1.1), (math.radians(14), 0, 0))
    flask_box = d.bevel(kit.box("flasks", (0.3, 0.2, 0.08), (cx - 0.24, cy - 0.04, 0.93)), 0.01, 2)
    vials = [d.cyl(f"vial{i}", 0.025, 0.12, (cx - 0.34 + i * 0.07, cy - 0.04, 1.02), vertices=8) for i in range(4)]
    # Pennant pole, back right.
    px, py = 1.18, 0.62
    pole = d.cyl("pole", 0.022, 2.3, (px, py, 1.15), vertices=10)
    bar = d.cyl("bar", 0.014, 0.6, (px - 0.3, py, 2.22), (0, math.pi / 2, 0), 8)
    foot = d.cyl("pole_foot", 0.09, 0.05, (px, py, 0.025), vertices=12)
    flag = enc._cloth_sheet("pennant", (0.56, 0.012, 0.8), (px - 0.31, py, 1.8), seed + 5, sag=0.004)
    logo_flag = kit.box("logo_flag", (0.34, 0.004, 0.34), (px - 0.31, py - 0.012, 1.88))
    logo_locker = kit.box("logo_locker", (0.26, 0.004, 0.26), (lx, ly - 0.345, 1.56))

    cases = kit.join([locker, door, vent, low[0], high[0], side[0], top, lip, till, screen_back, flask_box], "cases")
    glow = kit.join([window, strip, screen] + low[1] + high[1] + side[1] + vials, "glow")
    iron = kit.join(feet + low[2] + high[2] + side[2] + legs + [pole, bar, foot], "iron")
    return [(cases, enc.swatch("enc_closure_stall_case_p", "rhodes_case.png", 0.9, edge="e4e8ea"), "case"),
            (glow, enc.swatch("enc_closure_stall_glow_p", "rhodes_trim_glow.png", 0.5), "glow"),
            (iron, enc._steel("enc_closure_stall_iron_p", seed), "iron"),
            (flag, enc.swatch("enc_closure_stall_cloth_p", "rhodes_pennant.png", 1.0, edge="3a4044", grime_strength=0.2), "cloth"),
            (logo_flag, enc.decal("enc_closure_stall_logo_p", "1a1d1f"), "logo"),
            (logo_locker, enc.decal("enc_closure_stall_logo2_p", "c9cfd2"), "logo2")]


def build_tent(seed=431):
    """A Rhodes A-frame tent, about 2.2 x 1.9 m on the ground, 1.45 m tall."""
    random.seed(seed)
    width, depth, height = 2.2, 1.7, 1.45
    half = width / 2
    slope = math.atan2(height, half)
    panel_len = math.hypot(half, height) + 0.06
    panels = []
    for sx in (-1, 1):
        panel = enc._cloth_sheet(f"panel{sx}", (panel_len, depth, 0.03), (sx * half / 2, 0.0, height / 2), seed + sx,
                                 sag=0.006, rotation=(0, sx * slope, 0))
        panels.append(panel)
    # The back wall: a triangle of canvas; the front: two flaps tied open.
    back = _prism("back", ((-half, 0.0), (half, 0.0), (0.0, height)), depth / 2 - 0.02, depth / 2)
    # The front flaps rolled up and tied at the two lower corners of the door.
    flaps = []
    for sx in (-1, 1):
        x0, z0 = sx * half * 0.78, height * 0.2
        x1, z1 = sx * half * 0.3, height * 0.72
        flaps.append(_strut(f"flap{sx}", (x0, -depth / 2 - 0.03, z0), (x1, -depth / 2 - 0.03, z1), 0.07))
    # The dark inside seen through the open front, and a groundsheet.
    inside = _prism("inside", ((-half * 0.86, 0.0), (half * 0.86, 0.0), (0.0, height * 0.86)), -depth / 2 + 0.2, -depth / 2 + 0.22)
    floor = enc._cloth_sheet("floor", (2.0, depth + 0.1, 0.02), (0.0, 0.0, 0.011), seed + 11)
    kit.clip_below(floor, 0.0)
    # Ridge pole, end poles, pegs.
    ridge = d.cyl("ridge", 0.025, depth + 0.24, (0.0, 0.0, height + 0.01), (math.pi / 2, 0, 0), 8)
    poles = [d.cyl(f"endpole{sy}", 0.02, height, (0.0, sy * (depth / 2 + 0.1), height / 2), vertices=8) for sy in (-1, 1)]
    pegs = [d.cyl(f"peg{sx}{sy}", 0.015, 0.14, (sx * (half + 0.12), sy * (depth / 2 + 0.05), 0.05), vertices=6)
            for sx in (-1, 1) for sy in (-1, 1)]
    ropes = [_strut(f"rope{sx}{sy}", (sx * (half + 0.12), sy * (depth / 2 + 0.05), 0.08), (sx * half * 0.55, sy * depth / 2, height * 0.45), 0.006)
             for sx in (-1, 1) for sy in (-1, 1)]

    canvas = kit.join(panels + [back] + flaps, "canvas")
    dark = kit.join([inside, floor], "dark")
    iron = kit.join([ridge] + poles + pegs + ropes, "iron")
    return [(canvas, d.worn(kit.flat_material("camp_tent_canvas_p", "cfd3d2", noise_scale=6.0, darker="9ea4a3"), edge="e8eae8", edge_strength=0.25, grime="2a2722", grime_strength=0.4), "canvas"),
            (dark, kit.flat_material("camp_tent_dark_p", "15181a", noise_scale=4.0, darker="0b0c0d"), "dark"),
            (iron, enc._steel("camp_tent_iron_p", seed), "iron")]


def build_floodlight(seed=441):
    """A work light, about 1.2 x 1.0 m on the ground, 2.5 m to the lamp top."""
    random.seed(seed)
    mx, my = 0.0, 0.1
    mast_top = 2.25
    legs = []
    for i in range(3):
        a = math.radians(90 + i * 120)
        legs.append(_strut(f"leg{i}", (mx + 0.5 * math.cos(a), my + 0.5 * math.sin(a), 0.0), (mx, my, 0.9), 0.022))
    mast = d.cyl("mast", 0.035, mast_top - 0.8, (mx, my, 0.8 + (mast_top - 0.8) / 2), vertices=10)
    collar = d.cyl("collar", 0.06, 0.1, (mx, my, 0.9), vertices=10)
    yoke = d.bbox("yoke", (0.7, 0.06, 0.06), (mx, my, mast_top), width=0.008)
    tilt = (math.radians(-35), 0, 0)
    housing = d.bbox("housing", (0.66, 0.14, 0.4), (mx, my - 0.04, mast_top + 0.16), tilt, width=0.015)
    lamps = [kit.box(f"lamp{i}{j}", (0.27, 0.01, 0.15), (mx - 0.15 + i * 0.3, my - 0.115, mast_top + 0.07 + j * 0.19), tilt)
             for i in range(2) for j in range(2)]
    # The generator at its foot, front left, with a cable to the mast.
    gx, gy = -0.62, -0.38
    gen = d.bevel(kit.box("gen", (0.56, 0.38, 0.4), (gx, gy, 0.22)), 0.03, 2)
    frame = [d.cyl(f"gframe{s}", 0.015, 0.62, (gx, gy + s * 0.21, 0.44), (0, math.pi / 2, 0), 6) for s in (-1, 1)]
    frame += [d.cyl(f"gpost{sx}{sy}", 0.015, 0.44, (gx + sx * 0.3, gy + sy * 0.21, 0.22), vertices=6) for sx in (-1, 1) for sy in (-1, 1)]
    tank = d.cyl("gtank", 0.12, 0.3, (gx, gy + 0.02, 0.48), (0, math.pi / 2, 0), 12)
    panel = kit.box("gpanel", (0.16, 0.01, 0.1), (gx + 0.12, gy - 0.195, 0.28))
    cable = _strut("cable", (gx + 0.2, gy + 0.1, 0.03), (mx, my, 0.75), 0.012)
    stripes = d.stripes("gstripe", (0.5, 0.01, 0.06), (gx, gy - 0.195, 0.1), count=5)

    steel = kit.join(legs + [mast, collar, yoke, housing] + frame + [cable], "steel")
    body = kit.join([gen, tank], "body")
    glow = kit.join(lamps + [panel], "glow")
    warn = kit.join(stripes if isinstance(stripes, list) else [stripes], "warn")
    return [(steel, enc._steel("camp_floodlight_iron_p", seed), "iron"),
            (body, enc.swatch("camp_floodlight_case_p", "rhodes_case.png", 0.9, edge="e4e8ea"), "case"),
            (glow, enc.swatch("camp_floodlight_glow_p", "trader_lantern_glow.png", 0.5), "glow"),
            (warn, kit.flat_material("camp_floodlight_warn_p", "d8a21c"), "warn")]


if __name__ == "__main__":
    kit.reset_scene()
    enc.publish(build_closure_stall(), "enc_closure_stall")
    kit.reset_scene()
    enc.publish(build_tent(), "camp_tent")
    kit.reset_scene()
    enc.publish(build_floodlight(), "camp_floodlight")
