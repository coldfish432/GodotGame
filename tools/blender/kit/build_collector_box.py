"""收藏品箱 models (整理箱与收藏品策划案 v0.2 §3): art/kit/poi_collector_<region>.glb.

One per region, each the kind of box its people would keep their small
valuables in, so it reads as "someone's treasures" from the follow camera and
apart from the safe (iron, square, on feet) and the weapon box (long, olive):

- mine: an Ursus tin trunk, red paint over rust, iron bands and corner caps,
  a padlock on the hasp.
- city: a Yan red-lacquer chest on short legs, brass corners, a round lock
  plate and gold edging.
- snow: a low Sami wooden chest with a hide thrown over it, tied with cord,
  an antler for a handle.
- siracusa: two leather suitcases stacked a little askew, straps and brass
  clasps, the family's travelling cases.

Same conventions as build_poi.py: origin at the bottom centre, Z up, metres,
front towards Blender -Y (Godot +Z); textures baked from procedural materials.

Built through the Blender MCP add-on into the open Blender (a new scene per
model), or headless:

    blender -b --factory-startup --python-exit-code 1 --python tools/blender/kit/build_collector_box.py
"""
import math
import os
import sys

sys.path.append(os.path.dirname(__file__))
import bpy  # noqa: E402
import kit_common as kit  # noqa: E402
import build_poi as poi  # noqa: E402
import poi_detail as d  # noqa: E402


def _scene(name):
    """Headless: a factory scene. In the open Blender: a fresh scene of its own
    (a factory reset would unload the MCP add-on)."""
    if bpy.app.background:
        kit.reset_scene()
        return
    scene = bpy.data.scenes.new(name)
    bpy.context.window.scene = scene
    scene.unit_settings.system = "METRIC"
    try:
        scene.render.engine = "CYCLES"
    except TypeError:
        pass
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24


def _brass(name):
    return d.worn(kit.flat_material(name, "c8a24a", 9.0, "7a5f22"), edge="f0d890", edge_strength=0.5)


def _leather(name, seed, base):
    return d.worn(poi.cloth(name, seed, base), edge="b08a5a", edge_strength=0.35, grime="140c08", grime_strength=0.4)


def mine(seed):
    """乌萨斯铁皮箱: a tin trunk with a low domed lid, iron bands round it,
    corner caps, two side handles and a padlock on the hasp."""
    _scene("poi_collector_mine")
    body = d.bbox("body", (0.9, 0.52, 0.42), (0, 0, 0.21), width=0.02)
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.3, depth=0.9, location=(0, 0, 0.42), rotation=(0, math.pi / 2, 0))
    lid = bpy.context.object
    # Local z is the cylinder's length (world x); local x is world z.
    lid.scale = (0.42, 0.87, 1.0)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    kit.clip_below(lid, 0.42)
    lid.name = "lid"
    shell = kit.join([body, lid], "shell")
    bands = []
    for x in (-0.3, 0.0, 0.3):
        bands.append(d.bbox(f"band{x}", (0.05, 0.54, 0.43), (x, 0, 0.215), width=0.006))
        bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.312, depth=0.05, location=(x, 0, 0.42), rotation=(0, math.pi / 2, 0))
        arch = bpy.context.object
        arch.scale = (0.42, 0.87, 1.0)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        kit.clip_below(arch, 0.42)
        bands.append(arch)
    caps = [d.bbox(f"cap{x}{y}", (0.08, 0.08, 0.1), (x * 0.43, y * 0.24, 0.05), width=0.008) for x in (-1, 1) for y in (-1, 1)]
    grips = []
    for s in (-1, 1):
        grips += d.handle(f"grip{s}", (s * 0.45, 0, 0.3), 0.16, face_sign=s, face_axis="x")
    iron = kit.join(bands + caps + grips + d.rivets("rv", [(x, -0.272, z) for x in (-0.3, 0.0, 0.3) for z in (0.06, 0.36)], 0.011), "iron")
    hasp = d.latch("hasp", (0.15, -0.265, 0.4))
    lock = kit.join(hasp + [d.bbox("lock", (0.08, 0.04, 0.09), (0.15, -0.3, 0.3), width=0.01),
                            d.cyl("shackle", 0.028, 0.018, (0.15, -0.3, 0.37), (math.pi / 2, 0, 0), 12)], "lock")
    stencil = kit.join([d.bbox("stencil", (0.22, 0.006, 0.07), (-0.15, -0.262, 0.22), width=0.002)], "stencil")
    kit.publish_parts([(shell, poi._wear_paint("poi_collector_mine_shell_p", "7a2a22", seed, "9a6a5a"), "shell"),
                       (iron, poi._wear_rust("poi_collector_mine_iron_p", seed), "iron"),
                       (lock, _brass("poi_collector_mine_lock_p"), "lock"),
                       (stencil, kit.flat_material("poi_collector_mine_stencil_p", "d8c89a"), "stencil")], "poi_collector_mine", 1.6, 1024)


def city(seed):
    """炎国漆箱: a red-lacquer chest on four short legs with a slightly
    overhanging lid, brass corner plates, a round lock plate and gold edging."""
    _scene("poi_collector_city")
    body = d.bbox("body", (0.78, 0.48, 0.42), (0, 0, 0.31), width=0.015)
    lid = d.bbox("lid", (0.84, 0.54, 0.1), (0, 0, 0.57), width=0.02)
    top = d.bbox("top", (0.72, 0.42, 0.04), (0, 0, 0.64), width=0.012)
    lacquer = kit.join([body, lid, top], "lacquer")
    legs = [d.bbox(f"leg{x}{y}", (0.07, 0.07, 0.1), (x * 0.33, y * 0.19, 0.05), width=0.01) for x in (-1, 1) for y in (-1, 1)]
    apron = d.bbox("apron", (0.74, 0.44, 0.03), (0, 0, 0.115), width=0.006)
    wood = kit.join(legs + [apron], "wood")
    corners = [d.bbox(f"corner{x}{z}", (0.1, 0.5, 0.1), (x * 0.35, 0, z), width=0.004) for x in (-1, 1) for z in (0.15, 0.47)]
    plate = d.cyl("plate", 0.075, 0.012, (0, -0.246, 0.46), (math.pi / 2, 0, 0), 24)
    pin = d.bbox("pin", (0.03, 0.03, 0.09), (0, -0.258, 0.47), width=0.004)
    pulls = []
    for s in (-1, 1):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.05, minor_radius=0.008, major_segments=16, minor_segments=6, location=(s * 0.4, 0, 0.36), rotation=(0, math.pi / 2, 0))
        pulls.append(bpy.context.object)
    edging = [d.bbox(f"edge{y}", (0.84, 0.012, 0.012), (0, y * 0.27, 0.52), width=0.003) for y in (-1, 1)]
    brass = kit.join(corners + [plate, pin] + pulls + edging, "brass")
    kit.publish_parts([(lacquer, d.worn(kit.flat_material("poi_collector_city_lacquer_p", "9e1f1a", 14.0, "6a1210"), edge="d8584a", edge_strength=0.3), "lacquer"),
                       (wood, poi._wear_wood("poi_collector_city_wood_p", seed), "wood"),
                       (brass, _brass("poi_collector_city_brass_p"), "brass")], "poi_collector_city", 1.6, 1024)


def snow(seed):
    """萨米箱: a low planked chest with a hide thrown over the lid and down the
    sides, two cords round it, and an antler lashed on as the handle."""
    _scene("poi_collector_snow")
    planks = d.plank_box("chest", (0.82, 0.5, 0.4), (0, 0, 0.2), plank=0.12, battens=False)
    poi._wood(planks, seed)
    wood = kit.join(planks, "wood")
    hide = kit.box("hide", (0.7, 0.62, 0.05), (0.04, 0, 0.43))
    kit.roughen(hide, seed + 5, strength=0.02, size=0.12, bevel=0.03, subdiv=3)
    drape = [kit.box(f"drape{s}", (0.6, 0.04, 0.22), (0.04, s * 0.29, 0.33), (s * 0.15, 0, 0)) for s in (-1, 1)]
    for i, part in enumerate(drape): kit.roughen(part, seed + 6 + i, strength=0.015, size=0.1, bevel=0.02, subdiv=2)
    fur = kit.join([hide] + drape, "fur")
    kit.decimate(fur, 3000)
    cords = kit.join([d.bbox(f"cord{x}", (0.025, 0.66, 0.48), (x, 0, 0.24), width=0.008) for x in (-0.22, 0.26)], "cord")
    bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.022, radius2=0.012, depth=0.5, location=(0.02, -0.12, 0.49), rotation=(0, math.pi / 2, 0.15))
    beam = bpy.context.object
    tines = []
    for k, (x, ang) in enumerate([(-0.12, 0.6), (0.05, 0.75), (0.18, 0.55)]):
        bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.013, radius2=0.004, depth=0.14, location=(x, -0.16, 0.54), rotation=(ang, 0, 0))
        tines.append(bpy.context.object)
    antler = kit.join([beam] + tines, "antler")
    kit.publish_parts([(wood, poi._wear_wood("poi_collector_snow_wood_p", seed), "wood"),
                       (fur, poi.cloth("poi_collector_snow_fur_p", seed, "8a7356"), "fur"),
                       (cords, kit.flat_material("poi_collector_snow_cord_p", "3a2a1c"), "cord"),
                       (antler, kit.flat_material("poi_collector_snow_antler_p", "d8ccb0", 12.0, "a89a7c"), "antler")], "poi_collector_snow", 1.6, 1024)


def siracusa(seed):
    """叙拉古皮箱: a big leather suitcase lying flat and a smaller one on top,
    turned a little; straps, brass clasps and corner guards, a handle each."""
    _scene("poi_collector_siracusa")
    big = d.bbox("big", (0.82, 0.5, 0.26), (0, 0, 0.13), width=0.04)
    small = d.bbox("small", (0.6, 0.38, 0.2), (0.03, 0.02, 0.36), (0, 0, math.radians(-9)), width=0.035)
    leather = kit.join([big, small], "leather")
    straps = [d.bbox(f"strap{x}", (0.05, 0.52, 0.27), (x, 0, 0.13), width=0.006) for x in (-0.22, 0.22)]
    straps += [d.bbox(f"sstrap{x}", (0.045, 0.4, 0.21), (0.03 + x * math.cos(math.radians(-9)), 0.02 + x * math.sin(math.radians(-9)), 0.36), (0, 0, math.radians(-9)), width=0.006) for x in (-0.16, 0.16)]
    handles = [d.bbox("bhandle", (0.16, 0.035, 0.035), (0, -0.27, 0.2), width=0.012),
               d.bbox("shandle", (0.13, 0.03, 0.03), (0.0, -0.17, 0.45), (0, 0, math.radians(-9)), width=0.01)]
    dark = kit.join(straps + handles, "dark")
    clasps = []
    for x in (-0.22, 0.22):
        clasps += d.latch(f"bc{x}", (x, -0.262, 0.2))
    guards = [d.bbox(f"guard{x}{y}", (0.06, 0.06, 0.27), (x * 0.39, y * 0.23, 0.135), width=0.006) for x in (-1, 1) for y in (-1, 1)]
    brass = kit.join(clasps + guards, "brass")
    kit.publish_parts([(leather, _leather("poi_collector_siracusa_leather_p", seed, "6a3a20"), "leather"),
                       (dark, _leather("poi_collector_siracusa_strap_p", seed + 1, "2e1c12"), "strap"),
                       (brass, _brass("poi_collector_siracusa_brass_p"), "brass")], "poi_collector_siracusa", 1.6, 1024)


BUILDERS = [mine, city, snow, siracusa]

if __name__ == "__main__":
    mine(401)
    city(403)
    snow(405)
    siracusa(407)
