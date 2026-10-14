"""Mine accent pieces for the swept cliff faces: art/kit/mine_*.glb.

The cliff face itself is continuous (world/cliff_face.gd); these are the
fixed Blender pieces placed along it by TerraceDressing to break it up and
give the region its character, as 《恐怖黎明》 sets rock and props into its
cliffs:

- mine_ledge_{a,b}: a rock overhang on the cliff's lip. Origin on the face line
  at the upper floor; it juts up to 0.55 out over the face (Blender -Y).
- mine_brace: timber shoring stood against the face. Origin on the face line
  at the low floor; 2.2 tall (one tier), scaled to the drop in the game.
- mine_rocks_{a,b}: a heap of fallen rock for the cliff foot. Origin at the
  bottom centre.
- mine_cart: a wrecked ore cart on its side. Origin at the bottom centre.

Run: blender -b --factory-startup --python-exit-code 1 --python tools/blender/kit/build_mine_accents.py
"""
import math
import os
import random
import sys

sys.path.append(os.path.dirname(__file__))
import bpy  # noqa: E402
import kit_common as kit  # noqa: E402
from build_mine_cliff import rock_material  # noqa: E402


def _ramp(nodes, stops):
    ramp = nodes.new("ShaderNodeValToRGB")
    elements = ramp.color_ramp.elements
    elements[0].position, elements[0].color = stops[0][0], kit.srgb(stops[0][1])
    elements[1].position, elements[1].color = stops[-1][0], kit.srgb(stops[-1][1])
    for position, colour in stops[1:-1]:
        elements.new(position).color = kit.srgb(colour)
    return ramp


def wood_material(name, seed):
    """Weathered pit timber: grain along the beam, darker knots and ends."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    coord = nodes.new("ShaderNodeTexCoord")
    mapping = nodes.new("ShaderNodeMapping")
    mapping.inputs["Location"].default_value = (seed * 2.3, seed * 1.1, seed * 0.7)
    mapping.inputs["Scale"].default_value = (6.0, 6.0, 0.6)  # grain runs along Z, the beam's length
    links.new(coord.outputs["Object"], mapping.inputs["Vector"])
    grain = nodes.new("ShaderNodeTexWave")
    grain.wave_type = "RINGS"
    grain.inputs["Scale"].default_value = 1.2
    grain.inputs["Distortion"].default_value = 8.0
    grain.inputs["Detail"].default_value = 4.0
    links.new(mapping.outputs["Vector"], grain.inputs["Vector"])
    ramp = _ramp(nodes, [(0.2, "2e2117"), (0.55, "5a4128"), (0.9, "7d5f3e")])
    links.new(grain.outputs["Fac"], ramp.inputs["Fac"])
    grime = nodes.new("ShaderNodeTexNoise")
    grime.inputs["Scale"].default_value = 3.0
    grime.inputs["Detail"].default_value = 6.0
    links.new(coord.outputs["Object"], grime.inputs["Vector"])
    grime_ramp = _ramp(nodes, [(0.35, "6c6c6c"), (0.7, "ffffff")])
    links.new(grime.outputs["Fac"], grime_ramp.inputs["Fac"])
    mix = nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    links.new(ramp.outputs["Color"], mix.inputs["A"])
    links.new(grime_ramp.outputs["Color"], mix.inputs["B"])
    links.new(mix.outputs["Result"], kit.principled(nodes).inputs["Base Color"])
    return mat


def rust_material(name, seed):
    """Ore-cart iron: grey plate eaten by orange rust in blotches."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    coord = nodes.new("ShaderNodeTexCoord")
    mapping = nodes.new("ShaderNodeMapping")
    mapping.inputs["Location"].default_value = (seed * 1.7, seed * 0.9, 0.0)
    links.new(coord.outputs["Object"], mapping.inputs["Vector"])
    blotch = nodes.new("ShaderNodeTexNoise")
    blotch.inputs["Scale"].default_value = 3.5
    blotch.inputs["Detail"].default_value = 10.0
    blotch.inputs["Roughness"].default_value = 0.7
    links.new(mapping.outputs["Vector"], blotch.inputs["Vector"])
    ramp = _ramp(nodes, [(0.38, "3e3f40"), (0.5, "5a4a3c"), (0.6, "7a3e1c"), (0.78, "a45a28")])
    links.new(blotch.outputs["Fac"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], kit.principled(nodes).inputs["Base Color"])
    return mat


def ledge(variant, seed):
    kit.reset_scene()
    random.seed(seed)
    parts = []
    slab = kit.box("slab", (random.uniform(1.6, 2.0), 1.15, 0.38), (0.0, 0.0, 0.05),
                   (random.uniform(-0.06, 0.06), random.uniform(-0.05, 0.05), random.uniform(-0.1, 0.1)))
    kit.roughen(slab, seed, strength=0.1, size=0.3, bevel=0.06, subdiv=3, crack_strength=0.05, bulge=0.25, bulge_size=0.8)
    parts.append(slab)
    for i in range(2):
        chunk = kit.rock(f"chunk{i}", random.uniform(0.2, 0.3),
                         (random.uniform(-0.7, 0.7), random.uniform(-0.35, -0.1), random.uniform(-0.1, 0.05)),
                         (1.3, 1.0, 0.7))
        kit.roughen(chunk, seed + 7 + i, strength=0.08, size=0.2, subdiv=1)
        parts.append(chunk)
    obj = kit.join(parts, f"mine_ledge_{variant}")
    kit.decimate(obj, 1200)
    # Overhang: at most 0.55 out over the face, the rest back on the terrace.
    ys = [v.co.y for v in obj.data.vertices]
    shift = -0.55 - min(ys)
    for v in obj.data.vertices:
        v.co.y += shift
    obj.data.update()
    kit.publish(obj, rock_material(f"mine_ledge_{variant}_procedural", seed), f"mine_ledge_{variant}", 512, 2.6)


def brace(seed):
    kit.reset_scene()
    random.seed(seed)
    parts = []
    lean = math.radians(6)
    for side in (-0.72, 0.72):
        post = kit.box(f"post{side}", (0.17, 0.17, 2.3), (side, -0.25 + math.sin(lean) * 1.15, 1.15), (lean, 0, random.uniform(-0.03, 0.03)))
        kit.roughen(post, seed + int(side * 10), strength=0.012, size=0.1, bevel=0.02, subdiv=2)
        parts.append(post)
    cap = kit.box("cap", (1.75, 0.2, 0.18), (0.0, -0.25 + math.sin(lean) * 2.25, 2.25), (lean, 0, 0))
    kit.roughen(cap, seed + 3, strength=0.012, size=0.1, bevel=0.02, subdiv=2)
    parts.append(cap)
    # Corner to corner: 1.44 across between the posts, 2.1 up to the cap.
    strut = kit.box("strut", (0.12, 0.12, math.hypot(1.44, 2.1)), (0.0, -0.22 + math.sin(lean) * 1.1, 1.1), (lean, math.atan2(1.44, 2.1), 0))
    kit.roughen(strut, seed + 4, strength=0.01, size=0.1, bevel=0.015, subdiv=2)
    parts.append(strut)
    for side in (-0.72, 0.72):
        foot = kit.rock(f"wedge{side}", 0.14, (side, -0.3, 0.05), (1.4, 1.0, 0.6))
        kit.roughen(foot, seed + 9, strength=0.04, size=0.12, subdiv=1)
        parts.append(foot)
    obj = kit.join(parts, "mine_brace")
    kit.clip_below(obj, 0.0)
    kit.decimate(obj, 900)
    kit.publish(obj, wood_material("mine_brace_procedural", seed), "mine_brace", 512, 3.2)


def rocks(variant, seed):
    kit.reset_scene()
    random.seed(seed)
    parts = []
    for i in range(random.randint(4, 6)):
        radius = random.uniform(0.18, 0.5) if i else 0.5
        stone = kit.rock(f"stone{i}", radius,
                         (random.uniform(-0.55, 0.55), random.uniform(-0.4, 0.4), radius * 0.55),
                         (random.uniform(0.9, 1.4), random.uniform(0.8, 1.2), random.uniform(0.6, 0.85)))
        kit.roughen(stone, seed + i, strength=0.12, size=0.22, subdiv=2, crack_strength=0.03)
        parts.append(stone)
    obj = kit.join(parts, f"mine_rocks_{variant}")
    kit.clip_below(obj, 0.0)
    kit.decimate(obj, 1100)
    kit.publish(obj, rock_material(f"mine_rocks_{variant}_procedural", seed), f"mine_rocks_{variant}", 512, 2.4)


def cart(seed):
    kit.reset_scene()
    random.seed(seed)
    parts = []
    length, width, height, wall = 1.3, 0.85, 0.62, 0.06
    # Built upright, then tipped onto its side.
    parts.append(kit.box("floor", (length, width, wall), (0, 0, 0.18)))
    for sx in (-1, 1):
        parts.append(kit.box(f"end{sx}", (wall, width, height), (sx * (length - wall) / 2, 0, 0.18 + height / 2)))
    for sy in (-1, 1):
        parts.append(kit.box(f"side{sy}", (length, wall, height), (0, sy * (width - wall) / 2, 0.18 + height / 2)))
    for sx in (-0.4, 0.4):
        for sy in (-1, 1):
            if sx > 0 and sy > 0:
                continue  # one wheel gone
            bpy.ops.mesh.primitive_cylinder_add(vertices=14, radius=0.16, depth=0.07,
                                                location=(sx, sy * (width / 2 + 0.04), 0.16), rotation=(math.pi / 2, 0, 0))
            parts.append(bpy.context.object)
    for part in parts:
        kit.roughen(part, seed + len(part.name), strength=0.015, size=0.15, bevel=0.012, subdiv=1)
    obj = kit.join(parts, "mine_cart")
    obj.rotation_euler = (math.radians(74), 0, math.radians(8))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    zs = [v.co.z for v in obj.data.vertices]
    for v in obj.data.vertices:
        v.co.z -= min(zs)
    obj.data.update()
    kit.decimate(obj, 1400)
    kit.publish(obj, rust_material("mine_cart_procedural", seed), "mine_cart", 512, 2.6)


def timber_post(seed):
    """One upright of the corridor support frame: a squared pit prop with a
    cap block and a wedge at its foot. Origin at the bottom centre; 3.1 tall."""
    kit.reset_scene()
    random.seed(seed)
    parts = []
    post = kit.box("post", (0.26, 0.26, 3.0), (0, 0, 1.5), (0, 0, random.uniform(-0.02, 0.02)))
    kit.roughen(post, seed, strength=0.012, size=0.1, bevel=0.025, subdiv=2)
    parts.append(post)
    cap = kit.box("cap", (0.42, 0.34, 0.14), (0, 0, 3.02))
    kit.roughen(cap, seed + 1, strength=0.01, size=0.1, bevel=0.02, subdiv=2)
    parts.append(cap)
    wedge = kit.box("wedge", (0.4, 0.36, 0.12), (0, 0, 0.06))
    kit.roughen(wedge, seed + 2, strength=0.012, size=0.1, bevel=0.02, subdiv=2)
    parts.append(wedge)
    for side in (-1, 1):
        cleat = kit.box(f"cleat{side}", (0.06, 0.3, 0.5), (side * 0.15, 0, 2.6))
        kit.roughen(cleat, seed + 3, strength=0.008, size=0.1, bevel=0.01, subdiv=1)
        parts.append(cleat)
    obj = kit.join(parts, "mine_timber_post")
    kit.clip_below(obj, 0.0)
    kit.decimate(obj, 700)
    kit.publish(obj, wood_material("mine_timber_post_procedural", seed), "mine_timber_post", 512, 3.6)


def timber_cap(seed):
    """The frame's crossbeam with lagging boards laid over it, as if holding up
    the roof: 1 m long along X (stretched to the corridor in the game), origin
    at the centre of its underside."""
    kit.reset_scene()
    random.seed(seed)
    parts = []
    beam = kit.box("beam", (1.0, 0.3, 0.3), (0, 0, 0.15))
    kit.roughen(beam, seed, strength=0.006, size=0.08, bevel=0.02, subdiv=2)
    parts.append(beam)
    for i, x in enumerate((-0.36, -0.12, 0.12, 0.36)):
        board = kit.box(f"board{i}", (0.2, random.uniform(1.0, 1.3), 0.05), (x, random.uniform(-0.08, 0.08), 0.325),
                        (0, 0, random.uniform(-0.05, 0.05)))
        kit.roughen(board, seed + i, strength=0.006, size=0.08, bevel=0.01, subdiv=1)
        parts.append(board)
    obj = kit.join(parts, "mine_timber_cap")
    kit.decimate(obj, 600)
    kit.publish(obj, wood_material("mine_timber_cap_procedural", seed), "mine_timber_cap", 512, 2.0)


def rail_piece(seed):
    """1.5 m of mine track: two sleepers and two steel rails on the old strip
    gauge (rails at x = +-0.85). Centred on the origin lengthwise (Blender Y,
    Godot -Z), bottom at z = 0; laid end to end along a corridor."""
    kit.reset_scene()
    random.seed(seed)
    parts = []
    for i, y in enumerate((-0.375, 0.375)):
        sleeper = kit.box(f"sleeper{i}", (2.3, 0.24, 0.12), (random.uniform(-0.04, 0.04), y, 0.06),
                          (0, 0, random.uniform(-0.04, 0.04)))
        kit.roughen(sleeper, seed + i, strength=0.01, size=0.08, bevel=0.015, subdiv=2)
        parts.append(sleeper)
    rails = []
    for side in (-0.85, 0.85):
        foot = kit.box(f"foot{side}", (0.12, 1.52, 0.03), (side, 0, 0.135))
        web = kit.box(f"web{side}", (0.035, 1.52, 0.08), (side, 0, 0.19))
        head = kit.box(f"head{side}", (0.07, 1.52, 0.045), (side, 0, 0.25))
        rails += [foot, web, head]
    obj = kit.join(parts, "mine_rail_wood")
    kit.decimate(obj, 400)
    steel = kit.join(rails, "mine_rail_steel")
    # Two materials on one object: timber sleepers, rusted steel rails.
    kit.finish_mesh(obj)
    kit.finish_mesh(steel)
    wood = wood_material("mine_rail_wood_procedural", seed)
    rust = rust_material("mine_rail_steel_procedural", seed)
    obj.data.materials.append(wood)
    steel.data.materials.append(rust)
    wood_img = kit.bake_texture(obj, wood, "mine_rail_wood", 256)
    rust_img = kit.bake_texture(steel, rust, "mine_rail_steel", 256)
    obj.data.materials.clear()
    obj.data.materials.append(kit.baked_material("mine_rail_wood", wood_img))
    steel.data.materials.clear()
    steel.data.materials.append(kit.baked_material("mine_rail_steel", rust_img))
    track = kit.join([obj, steel], "mine_rail")
    kit.report(track, "mine_rail")
    kit.export(track, "mine_rail")
    kit.render_preview(track, "mine_rail", 2.8)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(kit.OUT_DIR, "blend", "mine_rail.blend"))


def _lantern_parts(seed, at=(0.0, 0.0, 0.0)):
    """A pit lamp: iron cage and cap around an amber glass. Hangs from its hook
    at `at`; the body is below it, 0.42 tall."""
    x, y, z = at
    iron = [
        kit.box("cap", (0.2, 0.2, 0.05), (x, y, z - 0.08)),
        kit.box("base", (0.18, 0.18, 0.04), (x, y, z - 0.38)),
        kit.box("hook", (0.02, 0.02, 0.08), (x, y, z - 0.03)),
    ]
    for sx in (-1, 1):
        for sy in (-1, 1):
            iron.append(kit.box(f"bar{sx}{sy}", (0.02, 0.02, 0.3), (x + sx * 0.085, y + sy * 0.085, z - 0.23)))
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.07, depth=0.24, location=(x, y, z - 0.23))
    glass = bpy.context.object
    return iron, glass


def lantern(seed):
    """mine_lantern: hangs under a frame crossbeam. Origin at the hook."""
    kit.reset_scene()
    iron, glass = _lantern_parts(seed)
    iron_obj = kit.join(iron, "iron")
    kit.publish_parts([(iron_obj, rust_material("mine_lantern_iron_proc", seed), "iron"),
                       (glass, kit.flat_material("mine_lantern_glow_proc", "ffc04a", 6.0, "e8801e"), "glow")],
                      "mine_lantern", 1.2, 256)


def lamp_post(seed):
    """mine_lamp_post: a timber pole with an arm and a hanging lamp, for rooms.
    Origin at the foot; 2.8 tall."""
    kit.reset_scene()
    random.seed(seed)
    wood = []
    pole = kit.box("pole", (0.18, 0.18, 2.8), (0, 0, 1.4))
    kit.roughen(pole, seed, strength=0.01, size=0.1, bevel=0.02, subdiv=2)
    wood.append(pole)
    arm = kit.box("arm", (0.7, 0.12, 0.12), (0.3, 0, 2.62))
    kit.roughen(arm, seed + 1, strength=0.008, size=0.1, bevel=0.015, subdiv=1)
    wood.append(arm)
    wood.append(kit.box("brace", (0.08, 0.08, 0.6), (0.18, 0, 2.38), (0, math.radians(-40), 0)))
    for i in range(3):
        stone = kit.rock(f"foot{i}", 0.16, (math.cos(i * 2.1) * 0.2, math.sin(i * 2.1) * 0.2, 0.06), (1.2, 1.0, 0.6), subdivisions=1)
        kit.roughen(stone, seed + 5 + i, strength=0.04, size=0.12, subdiv=1)
        wood.append(stone)
    wood_obj = kit.join(wood, "wood")
    kit.clip_below(wood_obj, 0.0)
    iron, glass = _lantern_parts(seed, (0.58, 0.0, 2.56))
    iron_obj = kit.join(iron, "iron")
    kit.publish_parts([(wood_obj, wood_material("mine_lamp_post_wood_proc", seed), "wood"),
                       (iron_obj, rust_material("mine_lamp_post_iron_proc", seed), "iron"),
                       (glass, kit.flat_material("mine_lamp_post_glow_proc", "ffc04a", 6.0, "e8801e"), "glow")],
                      "mine_lamp_post", 3.4, 256)


def headframe(seed):
    """mine_headframe: the landmark over the way down. A timber tower on four
    raked legs with ties, bracing, a deck, a winding wheel on top and two
    lamps. Origin at the centre of its footprint; about 3.6 wide, 7.9 tall."""
    kit.reset_scene()
    random.seed(seed)
    wood = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            leg = kit.box(f"leg{sx}{sy}", (0.26, 0.26, 6.6), (sx * 1.15, sy * 0.85, 3.2), (sy * -0.08, sx * 0.14, 0))
            kit.roughen(leg, seed + sx * 3 + sy, strength=0.012, size=0.12, bevel=0.03, subdiv=2)
            wood.append(leg)
    for i, z in enumerate((1.6, 3.6, 5.6)):
        half_x = 1.6 - z * 0.14
        half_y = 1.1 - z * 0.08
        for sy in (-1, 1):
            wood.append(kit.box(f"rung{i}{sy}", (half_x * 2, 0.16, 0.16), (0, sy * half_y, z)))
        for sx in (-1, 1):
            wood.append(kit.box(f"tie{i}{sx}", (0.16, half_y * 2, 0.16), (sx * half_x, 0, z)))
    for sy in (-1, 1):
        for d in (-1, 1):
            wood.append(kit.box(f"x{sy}{d}", (0.1, 0.1, 2.6), (0, sy * 0.95, 2.6), (0, d * math.radians(38), 0)))
    deck = kit.box("deck", (1.9, 1.5, 0.14), (0, 0, 6.4))
    kit.roughen(deck, seed + 9, strength=0.008, size=0.1, bevel=0.02, subdiv=1)
    wood.append(deck)
    for sx in (-0.5, 0.5):
        wood.append(kit.box(f"wheel_post{sx}", (0.14, 0.14, 1.0), (sx, 0, 6.95)))
    wood_obj = kit.join(wood, "wood")
    kit.clip_below(wood_obj, 0.0)
    iron = []
    bpy.ops.mesh.primitive_torus_add(major_radius=0.75, minor_radius=0.07, major_segments=24, minor_segments=6,
                                     location=(0, 0, 7.15), rotation=(0, math.pi / 2, 0))
    iron.append(bpy.context.object)
    for k in range(3):
        iron.append(kit.box(f"spoke{k}", (0.05, 0.05, 1.45), (0, 0, 7.15), (k * math.pi / 3, 0, 0)))
    iron.append(kit.box("axle", (1.1, 0.12, 0.12), (0, 0, 7.15)))
    glass_parts = []
    for sx in (-1, 1):
        parts, glass = _lantern_parts(seed, (sx * 0.85, -0.78, 6.3))
        iron += parts
        glass_parts.append(glass)
    iron_obj = kit.join(iron, "iron")
    glass_obj = kit.join(glass_parts, "glass")
    kit.publish_parts([(wood_obj, wood_material("mine_headframe_wood_proc", seed), "wood"),
                       (iron_obj, rust_material("mine_headframe_iron_proc", seed), "iron"),
                       (glass_obj, kit.flat_material("mine_headframe_glow_proc", "dff4ff", 6.0, "8fc8ff"), "glow")],
                      "mine_headframe", 9.5, 512)


def signal_flare(seed):
    """signal_flare: the extraction marker. A signal flare stick pushed into a
    small cairn, leaning, its tip burning green. Origin at the foot; about
    0.6 tall. The tip ("glow") is drawn self-lit; smoke and light are added
    in the game (TerraceDressing._place_extraction)."""
    kit.reset_scene()
    random.seed(seed)
    stones = []
    for i in range(5):
        angle = i * 1.3
        r = random.uniform(0.09, 0.14)
        stone = kit.rock(f"cairn{i}", r, (math.cos(angle) * 0.13, math.sin(angle) * 0.13, r * 0.5), (1.2, 1.0, 0.7), subdivisions=1)
        kit.roughen(stone, seed + i, strength=0.03, size=0.1, subdiv=1)
        stones.append(stone)
    stone_obj = kit.join(stones, "stones")
    kit.clip_below(stone_obj, 0.0)
    lean = (math.radians(14), math.radians(-8), 0)
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.028, depth=0.48, location=(0, 0, 0.24), rotation=lean)
    casing = bpy.context.object
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.032, depth=0.05, location=(0, 0, 0.12), rotation=lean)
    band = bpy.context.object
    casing_obj = kit.join([casing, band], "casing")
    tip_dir = (math.sin(lean[1]) * -1.0, -math.sin(lean[0]), math.cos(lean[0]))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=6, radius=0.04,
                                         location=(tip_dir[0] * 0.5, tip_dir[1] * 0.5, tip_dir[2] * 0.5))
    tip = bpy.context.object
    kit.publish_parts([(stone_obj, kit.flat_material("signal_flare_stone_proc", "6b6460", 8.0, "3e3a37"), "stone"),
                       (casing_obj, kit.flat_material("signal_flare_casing_proc", "b8322a", 10.0, "7d1f1a"), "casing"),
                       (tip, kit.flat_material("signal_flare_glow_proc", "c8ffd0", 9.0, "4dff7a"), "glow")],
                      "signal_flare", 1.2, 256)


def sleeper(seed):
    """mine_sleeper: one timber sleeper with its two tie plates and spikes, laid
    across the track (Blender X, 2.3 long). Origin at its bottom centre. The
    rails themselves are swept along curved track in the game (RailNetwork)."""
    kit.reset_scene()
    random.seed(seed)
    wood = kit.box("sleeper", (2.3, 0.24, 0.12), (0, 0, 0.06))
    kit.roughen(wood, seed, strength=0.01, size=0.08, bevel=0.015, subdiv=2)
    kit.clip_below(wood, 0.0)
    # Hundreds per floor: kept light.
    kit.decimate(wood, 220)
    plates = []
    for x in (-0.85, 0.85):
        plates.append(kit.box(f"plate{x}", (0.2, 0.18, 0.015), (x, 0, 0.128)))
        for dx in (-0.07, 0.07):
            plates.append(kit.box(f"spike{x}{dx}", (0.025, 0.025, 0.03), (x + dx, random.uniform(-0.05, 0.05), 0.145)))
    iron = kit.join(plates, "iron")
    kit.publish_parts([(wood, wood_material("mine_sleeper_wood_proc", seed), "wood"),
                       (iron, rust_material("mine_sleeper_iron_proc", seed), "iron")], "mine_sleeper", 2.8, 256)


def rail_switch(seed):
    """mine_rail_switch: the stand that throws a set of points: a timber
    block, a cast frame, a throw lever with a counterweight ball and a
    red-and-white target disc on a mast. Origin at the bottom centre."""
    kit.reset_scene()
    random.seed(seed)
    block = kit.box("block", (0.6, 0.4, 0.14), (0, 0, 0.07))
    kit.roughen(block, seed, strength=0.008, size=0.08, bevel=0.015, subdiv=2)
    kit.clip_below(block, 0.0)
    iron = [kit.box("frame", (0.36, 0.22, 0.24), (0, 0, 0.26)),
            kit.box("lever", (0.05, 0.05, 0.7), (0.12, 0, 0.6), (0, math.radians(30), 0)),
            kit.box("mast", (0.05, 0.05, 0.9), (-0.1, 0, 0.82)),
            kit.box("rod", (0.7, 0.04, 0.04), (0.45, 0, 0.18))]
    bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=6, radius=0.08, location=(0.3, 0, 0.92))
    iron.append(bpy.context.object)
    iron_obj = kit.join(iron, "iron")
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.16, depth=0.03, location=(-0.1, 0, 1.25), rotation=(math.pi / 2, 0, 0))
    disc = bpy.context.object
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.07, depth=0.035, location=(-0.1, 0, 1.25), rotation=(math.pi / 2, 0, 0))
    centre = bpy.context.object
    kit.publish_parts([(block, wood_material("mine_rail_switch_wood_proc", seed), "wood"),
                       (iron_obj, rust_material("mine_rail_switch_iron_proc", seed), "iron"),
                       (disc, kit.flat_material("mine_rail_switch_disc_proc", "c42a2a", 9.0, "8a1c1c"), "disc"),
                       (centre, kit.flat_material("mine_rail_switch_centre_proc", "e8e4d8"), "centre")], "mine_rail_switch", 1.8, 256)


if __name__ == "__main__":
    ledge("a", 41)
    ledge("b", 53)
    brace(61)
    rocks("a", 71)
    rocks("b", 83)
    cart(97)
    timber_post(101)
    timber_cap(103)
    rail_piece(107)
    lantern(109)
    lamp_post(113)
    headframe(127)
    signal_flare(131)
    sleeper(137)
    rail_switch(139)
