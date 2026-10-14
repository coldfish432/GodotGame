"""Detail helpers for the search-point models (build_poi.py, v2 2026-10-12:
the user asked for finer models).

- Bevelled boxes everywhere, so every edge catches the light.
- Crates built plank by plank with gaps and battens, not as one block.
- Rivets, hinges, handles, latches as their own small parts.
- Materials get edge wear (Cycles pointiness: convex edges lighten, the paint
  rubbed through) and grime in the hollows, baked with the AO.
"""
import math

import bpy
import kit_common as kit


def bevel(obj, width=0.012, segments=2):
    mod = obj.modifiers.new("bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def bbox(name, size, location, rotation=(0, 0, 0), width=0.012):
    """A bevelled box."""
    return bevel(kit.box(name, size, location, rotation), min(width, min(size) * 0.3))


def cyl(name, radius, depth, location, rotation=(0, 0, 0), vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    return obj


def rivets(prefix, points, radius=0.012, axis="y", sign=-1.0):
    """Little domed heads standing out of a face (the face normal along `axis`)."""
    out = []
    rot = {"x": (0, math.pi / 2, 0), "y": (math.pi / 2, 0, 0), "z": (0, 0, 0)}[axis]
    for i, p in enumerate(points):
        out.append(cyl(f"{prefix}{i}", radius, 0.008, p, rot, 8))
    return out


def plank_box(prefix, size, location, plank=0.14, gap=0.012, battens=True, along="x"):
    """A crate made of planks: each face is a row of boards with small gaps,
    corner posts, and (optionally) battens across the long faces."""
    sx, sy, sz = size
    cx, cy, cz = location
    t = 0.022
    parts = []
    # Long faces (front/back, normal along y): boards run along x.
    rows = max(2, round(sz / plank))
    h = (sz - gap * (rows - 1)) / rows
    for face in (-1, 1):
        for r in range(rows):
            z = cz - sz / 2 + h / 2 + r * (h + gap)
            parts.append(bbox(f"{prefix}fb{face}{r}", (sx - 2 * t, t, h), (cx, cy + face * (sy / 2 - t / 2), z), width=0.006))
    # End faces (normal along x).
    for face in (-1, 1):
        for r in range(rows):
            z = cz - sz / 2 + h / 2 + r * (h + gap)
            parts.append(bbox(f"{prefix}fe{face}{r}", (t, sy - 2 * t, h), (cx + face * (sx / 2 - t / 2), cy, z), width=0.006))
    # Top boards (run along x).
    cols = max(2, round(sy / plank))
    w = (sy - gap * (cols - 1)) / cols
    for c in range(cols):
        y = cy - sy / 2 + w / 2 + c * (w + gap)
        parts.append(bbox(f"{prefix}top{c}", (sx, w, t), (cx, y, cz + sz / 2 - t / 2), width=0.006))
    # Corner posts.
    for ex in (-1, 1):
        for ey in (-1, 1):
            parts.append(bbox(f"{prefix}post{ex}{ey}", (0.045, 0.045, sz), (cx + ex * (sx / 2 - 0.0225), cy + ey * (sy / 2 - 0.0225), cz), width=0.008))
    if battens:
        for face in (-1, 1):
            for bx in (-sx * 0.3, sx * 0.3):
                parts.append(bbox(f"{prefix}bat{face}{bx}", (0.07, 0.02, sz * 0.92), (cx + bx, cy + face * (sy / 2 + 0.006), cz), width=0.006))
    return parts


def hinge(prefix, location, length=0.12, axis="x"):
    rot = (0, math.pi / 2, 0) if axis == "x" else (0, 0, 0)
    knuckle = cyl(f"{prefix}k", 0.014, length, location, rot, 10)
    leaf = bbox(f"{prefix}l", (length if axis == "x" else 0.05, 0.006, 0.05 if axis == "x" else length), (location[0], location[1] - 0.008, location[2] - 0.03), width=0.002)
    return [knuckle, leaf]


def latch(prefix, location):
    """A toggle latch: base plate, hasp and staple."""
    x, y, z = location
    return [bbox(f"{prefix}plate", (0.07, 0.012, 0.05), (x, y, z - 0.02), width=0.003),
            bbox(f"{prefix}hasp", (0.03, 0.016, 0.07), (x, y - 0.006, z + 0.015), width=0.003),
            bbox(f"{prefix}staple", (0.05, 0.012, 0.02), (x, y, z + 0.06), width=0.003)]


def handle(prefix, location, width=0.18, axis="x", face_sign=-1.0, face_axis="y"):
    """A bent bar handle standing off a face."""
    x, y, z = location
    off = 0.035 * face_sign
    if face_axis == "y":
        return [bbox(f"{prefix}bar", (width, 0.02, 0.02), (x, y + off, z), width=0.006),
                bbox(f"{prefix}l", (0.02, 0.035, 0.02), (x - width / 2, y + off / 2, z), width=0.004),
                bbox(f"{prefix}r", (0.02, 0.035, 0.02), (x + width / 2, y + off / 2, z), width=0.004)]
    return [bbox(f"{prefix}bar", (0.02, width, 0.02), (x + off, y, z), width=0.006),
            bbox(f"{prefix}l", (0.035, 0.02, 0.02), (x + off / 2, y - width / 2, z), width=0.004),
            bbox(f"{prefix}r", (0.035, 0.02, 0.02), (x + off / 2, y + width / 2, z), width=0.004)]


def stripes(prefix, size, location, count=5, axis="x"):
    """Hazard stripes as alternate slanted bars (paint them yellow/black as two parts)."""
    sx, sy, sz = size
    x, y, z = location
    out = []
    step = sx / count
    for i in range(count):
        out.append(kit.box(f"{prefix}{i}", (step * 0.5, sy, sz * 1.2), (x - sx / 2 + step * (i + 0.5), y, z), (0, 0.6, 0)))
    return out


def worn(mat, edge="ffffff", edge_strength=0.45, grime="1a1612", grime_strength=0.35):
    """Edge wear and grime on a procedural material, through its Base Color:
    convex edges (pointiness) lift towards `edge`, hollows sink towards `grime`."""
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = kit.principled(nodes)
    src = bsdf.inputs["Base Color"].links[0].from_socket if bsdf.inputs["Base Color"].links else None
    geo = nodes.new("ShaderNodeNewGeometry")
    edges = nodes.new("ShaderNodeMapRange")
    edges.inputs["From Min"].default_value = 0.52
    edges.inputs["From Max"].default_value = 0.62
    links.new(geo.outputs["Pointiness"], edges.inputs["Value"])
    hollow = nodes.new("ShaderNodeMapRange")
    hollow.inputs["From Min"].default_value = 0.48
    hollow.inputs["From Max"].default_value = 0.4
    links.new(geo.outputs["Pointiness"], hollow.inputs["Value"])
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 30.0
    chip = nodes.new("ShaderNodeMath")
    chip.operation = "MULTIPLY"
    links.new(edges.outputs["Result"], chip.inputs[0])
    links.new(noise.outputs["Fac"], chip.inputs[1])
    edge_amt = nodes.new("ShaderNodeMath")
    edge_amt.operation = "MULTIPLY"
    edge_amt.inputs[1].default_value = edge_strength * 1.8
    links.new(chip.outputs["Value"], edge_amt.inputs[0])
    lifted = nodes.new("ShaderNodeMix")
    lifted.data_type = "RGBA"
    links.new(edge_amt.outputs["Value"], lifted.inputs["Factor"])
    if src is not None: links.new(src, lifted.inputs["A"])
    else: lifted.inputs["A"].default_value = bsdf.inputs["Base Color"].default_value
    lifted.inputs["B"].default_value = kit.srgb(edge)
    grime_amt = nodes.new("ShaderNodeMath")
    grime_amt.operation = "MULTIPLY"
    grime_amt.inputs[1].default_value = grime_strength
    links.new(hollow.outputs["Result"], grime_amt.inputs[0])
    dirty = nodes.new("ShaderNodeMix")
    dirty.data_type = "RGBA"
    links.new(grime_amt.outputs["Value"], dirty.inputs["Factor"])
    links.new(lifted.outputs["Result"], dirty.inputs["A"])
    dirty.inputs["B"].default_value = kit.srgb(grime)
    links.new(dirty.outputs["Result"], bsdf.inputs["Base Color"])
    return mat
