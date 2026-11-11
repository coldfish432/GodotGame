"""Shapes for the snowfield's props, rebuilt 2026-11-11 (用户: 倒伏的树现在像倒的电线杆子，
石头太圆润了).

    tube()          a tapered tube along a polyline: irregular section, bark
                    furrows, a pointed or splintered end (trunks, branches, roots)
    fallen_pine()   a fallen pine: tapered, bent trunk with a root flare, the
                    torn-up root plate standing on end with its roots, whorls of
                    branches (the ones under it snapped short), twigs and
                    sprays of needles; parts "bark", "soil", "needles"
    shard()         an angular rock: the convex hull of points pushed towards a
                    block, sliced flat by a few fracture planes
    split_block()   a shard split in two by one plane, the halves pulled apart
                    (frost-split)
    bark_material() pine bark: long plates between dark furrows

Everything is built where it stands (world = object coordinates), Blender Z up,
metres; the trunk lies along +X from its root at x = 0.
"""
import math
import random

import bmesh
import bpy
from mathutils import Matrix, Vector

import kit_common as kit

TAU = math.tau


def _object(name, bm):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def tube(name, points, radii, sides=10, seed=0, wobble=0.05, furrows=0, furrow_depth=0.0,
         start="cap", end="point", splinter=0.0):
    """start/end: "cap" (flat), "point" (closes to a tip), "splinter" (a broken
    end: the rim torn into spikes `splinter` long), "open"."""
    rnd = random.Random(seed)
    pts = [Vector(p) for p in points]
    n = len(pts)
    tangents = []
    for i in range(n):
        a, b = pts[max(0, i - 1)], pts[min(n - 1, i + 1)]
        tangents.append((b - a).normalized())
    up = Vector((0, 0, 1)) if abs(tangents[0].z) < 0.9 else Vector((1, 0, 0))
    normal = (up - tangents[0] * up.dot(tangents[0])).normalized()
    phase = [rnd.uniform(0, TAU) for _ in range(4)]
    bm = bmesh.new()
    rings = []
    for i in range(n):
        t = tangents[i]
        normal = (normal - t * normal.dot(t)).normalized()
        binormal = t.cross(normal)
        ring = []
        for k in range(sides):
            a = TAU * k / sides
            r = radii[i] * (1.0 + wobble * (0.6 * math.sin(2 * a + phase[0] + i * 0.31) + 0.4 * math.sin(3 * a + phase[1] - i * 0.17)))
            if furrows:
                ridge = max(0.0, math.sin(furrows * a + phase[2] + 0.4 * math.sin(i * 0.5 + phase[3])))
                r *= 1.0 - furrow_depth * ridge ** 3
            ring.append(bm.verts.new(pts[i] + normal * math.cos(a) * r + binormal * math.sin(a) * r))
        rings.append(ring)
    for i in range(n - 1):
        for k in range(sides):
            bm.faces.new((rings[i][k], rings[i][(k + 1) % sides], rings[i + 1][(k + 1) % sides], rings[i + 1][k]))

    def close(ring, centre, outward, kind):
        if kind == "open": return
        if kind == "splinter":
            # Spikes of torn wood round the rim, the middle sunk a little.
            for k, v in enumerate(ring):
                v.co += outward * splinter * (rnd.uniform(0.2, 1.0) if k % 2 == 0 else rnd.uniform(0.0, 0.3))
            tip = bm.verts.new(centre + outward * splinter * 0.15)
        elif kind == "point":
            tip = bm.verts.new(centre + outward * radii[-1 if outward.dot(tangents[-1]) > 0 else 0] * 2.5)
        else:
            tip = bm.verts.new(centre)
        for k in range(sides):
            bm.faces.new((ring[k], ring[(k + 1) % sides], tip))

    close(rings[0], pts[0], -tangents[0], start)
    close(rings[-1], pts[-1], tangents[-1], end)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _object(name, bm)


def seal(obj):
    """Closes the holes a clip_below (or an open tube end) leaves, so each
    piece is closed again: kit.finish_mesh's normals_make_consistent turns
    open tubes inside out (2026-11-11: four stump roots baked black)."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary], sides=0)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    return obj


def _polyline(start, direction, length, segments, droop=0.0, curl=None, rnd=None):
    """Points from `start` along `direction`, bending down by `droop` (metres at
    the far end) and randomly by `curl`."""
    rnd = rnd or random
    d = Vector(direction).normalized()
    pts = [Vector(start)]
    step = length / segments
    for s in range(segments):
        jitter = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))) * (curl or 0.0)
        d = (d + jitter + Vector((0, 0, -droop / max(length, 0.01)))).normalized()
        pts.append(pts[-1] + d * step)
    return pts


def _taper(r0, r1, count, power=1.0):
    return [r1 + (r0 - r1) * (1.0 - i / (count - 1)) ** power for i in range(count)]


def fallen_pine(seed, length=4.0, radius=0.24, crown=True):
    """Returns (bark, soil, needles) objects."""
    rnd = random.Random(seed)
    random.seed(seed)
    rings = 22
    bend = rnd.uniform(-0.18, 0.18)
    # Lying on its branches, so a little above the ground in the middle.
    def centre(t):
        r = radius_at(t)
        return Vector((t * length, bend * math.sin(math.pi * t * 0.9), r * 0.92 + 0.05 * math.sin(math.pi * t)))

    def radius_at(t):
        tip = 0.03 if crown else radius * 0.45
        r = tip + (radius - tip) * (1.0 - t) ** 1.25
        return r * (1.0 + 0.4 * math.exp(-t * 9.0))   # the root flare

    reach = 1.0 if crown else rnd.uniform(0.62, 0.72)
    ts = [reach * i / (rings - 1) for i in range(rings)]
    bark = [tube("trunk", [centre(t) for t in ts], [radius_at(t) for t in ts], sides=16, seed=seed,
                 wobble=0.05, furrows=7, furrow_depth=0.12, start="cap",
                 end="point" if crown else "splinter", splinter=0.35)]

    # Branches in whorls up the crown; the lower trunk has only snapped stubs.
    needles = []
    t = 0.12
    w = 0
    while t < reach - 0.03:
        whorl = rnd.randint(3, 5) if t > 0.38 else rnd.randint(1, 2)
        spin = rnd.uniform(0, TAU)
        for b in range(whorl):
            a = spin + TAU * b / whorl + rnd.uniform(-0.3, 0.3)
            out = Vector((0.0, math.cos(a), math.sin(a)))
            base = centre(t) + out * radius_at(t) * 0.8
            # Grew up and out from the trunk: out, and forward towards the tip.
            direction = (out + Vector((0.75, 0, 0))).normalized()
            into_ground = out.z < -0.35
            if t < 0.38 or into_ground:
                # Snapped short: a stub with a torn end.
                l = rnd.uniform(0.08, 0.2) if not into_ground else rnd.uniform(0.04, 0.12)
                pts = _polyline(base, direction, l, 2, rnd=rnd)
                bark.append(tube(f"stub{w}_{b}", pts, _taper(rnd.uniform(0.025, 0.045), 0.02, 3), sides=6,
                                 seed=seed + w * 10 + b, wobble=0.1, start="open", end="splinter", splinter=0.05))
                continue
            span = (t - 0.38) / max(0.01, reach - 0.38)
            l = (0.45 + 1.25 * (1.0 - span) ** 0.8) * rnd.uniform(0.8, 1.15) * (length / 4.0)
            pts = _polyline(base, direction, l, 4, droop=l * 0.25 * max(0.0, out.z), curl=0.12, rnd=rnd)
            r0 = (0.028 + 0.022 * (1.0 - span)) * (radius / 0.24)
            bark.append(tube(f"br{w}_{b}", pts, _taper(r0, 0.006, len(pts), 0.8), sides=6, seed=seed + w * 10 + b,
                             wobble=0.08, start="open", end="point"))
            # Two or three twigs off it, and needles on the live ends.
            for k in range(rnd.randint(2, 3)):
                at = pts[rnd.randint(2, len(pts) - 2)]
                side = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.3, 1))).normalized()
                twig = _polyline(at, (direction + side * 0.9).normalized(), l * rnd.uniform(0.25, 0.4), 2, curl=0.15, rnd=rnd)
                bark.append(tube(f"tw{w}_{b}_{k}", twig, _taper(0.012, 0.004, len(twig)), sides=4, seed=seed + k,
                                 wobble=0.0, start="open", end="point"))
            # A spray of needles along the outer part of most branches.
            if rnd.random() < 0.8: needles.append(_frond(f"n{w}_{b}", pts[1:], 0.12 + 0.09 * (1 - span), rnd))
        w += 1
        t += rnd.uniform(0.055, 0.08)
    if crown: needles.append(_frond("leader", [centre(reach - 0.08 + 0.02 * i) for i in range(5)] + [centre(reach) + Vector((0.25, 0, 0))], 0.1, rnd))

    soil, roots = _root_plate(seed, radius, rnd)
    bark += roots
    return kit.join(bark, "bark"), soil, kit.join(needles, "needles") if needles else None


def _frond(name, pts, width, rnd):
    """A spray of needles along a branch: a flat strip with a sawtooth edge,
    widest a third of the way out, closing to the branch's tip; a little
    thickness so it shows from both sides."""
    bm = bmesh.new()
    count = len(pts)
    top, bottom = [], []
    up = Vector((0, 0, 1))
    steps = (count - 1) * 3
    for i in range(steps + 1):
        u = i / steps
        f = u * (count - 1)
        k = min(int(f), count - 2)
        p = pts[k].lerp(pts[k + 1], f - k)
        t = (pts[k + 1] - pts[k]).normalized()
        side = t.cross(up)
        if side.length < 0.1: side = t.cross(Vector((1, 0, 0)))
        side.normalize()
        flat = side.cross(t).normalized()
        if flat.z < 0: flat = -flat
        w = width * math.sin(math.pi * min(1.0, u * 1.4 + 0.08)) * (1.25 if i % 2 else 0.8) * rnd.uniform(0.85, 1.1)
        for sign in (1, -1):
            edge = p + side * w * sign - flat * w * 0.25
            top.append(bm.verts.new(edge + flat * 0.012))
            bottom.append(bm.verts.new(edge - flat * 0.012))
    # Rows of two: [left, right] per step.
    for i in range(steps):
        a, b, c, d = i * 2, i * 2 + 1, i * 2 + 3, i * 2 + 2
        bm.faces.new((top[a], top[b], top[c], top[d]))
        bm.faces.new((bottom[d], bottom[c], bottom[b], bottom[a]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _object(name, bm)


def _root_plate(seed, radius, rnd):
    """The torn-up root plate standing on end at the trunk's foot (normal along
    -X), soil and stones caught in it, roots fraying out of its rim and back."""
    # 2026-11-11 after the first look in game: smaller, thinner and ragged,
    # or from above its snowed rim reads as a mushroom cap.
    plate_r = radius * rnd.uniform(2.7, 3.1)
    c = Vector((-0.06, 0.0, plate_r * 0.55))
    bm = bmesh.new()
    count = 22
    front, back = [], []
    for k in range(count):
        a = TAU * k / count
        r = plate_r * (0.72 + 0.12 * math.sin(3 * a + seed) + rnd.uniform(0.0, 0.32) * (1.0 if k % 3 else 0.55))
        y, z = math.cos(a) * r, math.sin(a) * r * 0.9
        front.append(bm.verts.new(c + Vector((0.05 + rnd.uniform(-0.03, 0.03), y, z))))
        back.append(bm.verts.new(c + Vector((-0.1 + rnd.uniform(-0.05, 0.04), y * 0.9, z * 0.9))))
    fc = bm.verts.new(c + Vector((0.1, 0, 0)))
    bc = bm.verts.new(c + Vector((-0.3, 0, 0)))
    for k in range(count):
        j = (k + 1) % count
        bm.faces.new((front[k], front[j], fc))
        bm.faces.new((back[j], back[k], bc))
        bm.faces.new((front[j], front[k], back[k], back[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    soil = _object("soil", bm)
    kit.roughen(soil, seed + 7, strength=0.1, size=0.16, subdiv=2, crack_strength=0.05, bulge=0.08, bulge_size=0.5)
    stones = [shard(f"st{k}", (rnd.uniform(0.07, 0.13),) * 3, seed + 40 + k,
                    c + Vector((-0.3, math.cos(a) * plate_r * 0.5, math.sin(a) * plate_r * 0.45)))
              for k, a in enumerate([rnd.uniform(0, TAU) for _ in range(7)])]
    soil = kit.join([soil] + stones, "soil")
    roots = []
    for k in range(16):
        a = TAU * k / 16 + rnd.uniform(-0.2, 0.2)
        rim = c + Vector((-0.05, math.cos(a) * plate_r * 0.85, math.sin(a) * plate_r * 0.75))
        outward = Vector((rnd.uniform(-0.9, -0.2), math.cos(a), math.sin(a) * 0.8)).normalized()
        l = rnd.uniform(0.35, 0.8) * plate_r
        pts = _polyline(rim, outward, l, 4, droop=l * 0.4, curl=0.18, rnd=rnd)
        roots.append(tube(f"root{k}", pts, _taper(rnd.uniform(0.03, 0.055), 0.006, len(pts)), sides=6,
                          seed=seed + 60 + k, wobble=0.12, start="open", end="point"))
    # Root tails hanging from the back of the plate down to the ground.
    for k in range(7):
        y = rnd.uniform(-0.7, 0.7) * plate_r
        z = c.z + rnd.uniform(-0.3, 0.5) * plate_r
        pts = _polyline(Vector((-0.12, y, z)), (rnd.uniform(-0.6, -0.2), rnd.uniform(-0.3, 0.3), -1.0), z + 0.1, 4, curl=0.2, rnd=rnd)
        roots.append(tube(f"tail{k}", pts, _taper(rnd.uniform(0.02, 0.035), 0.006, len(pts)), sides=5,
                          seed=seed + 120 + k, wobble=0.1, start="open", end="point"))
    # The plate leans back off the trunk (its top away from it), so from the
    # follow camera the soil face and its roots show, not just the snowed rim.
    lean = Matrix.Translation((0.0, 0.0, 0.0)) @ Matrix.Rotation(math.radians(-rnd.uniform(16, 24)), 4, "Y")
    for obj in [soil] + roots:
        obj.data.transform(lean)
        obj.data.update()
    # The big roots where trunk meets plate, flaring out.
    for k in range(5):
        a = TAU * k / 5 + rnd.uniform(-0.3, 0.3)
        out = Vector((0.0, math.cos(a), math.sin(a)))
        base = Vector((0.25, 0, radius)) + out * radius * 0.6
        pts = [base, base + Vector((-0.2, 0, 0)) + out * radius * 0.9, base + Vector((-0.32, 0, 0)) + out * plate_r * 0.55]
        roots.append(tube(f"flare{k}", pts, [radius * 0.45, radius * 0.3, radius * 0.12], sides=8,
                          seed=seed + 80 + k, wobble=0.1, start="open", end="point"))
    return soil, roots


def bark_material(name, seed, axis="X"):
    """Pine bark: grey-brown plates, long along the trunk (`axis`: X lying,
    Z standing), dark furrows."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    coord = nodes.new("ShaderNodeTexCoord")
    mapping = nodes.new("ShaderNodeMapping")
    mapping.inputs["Location"].default_value = (seed * 1.3, seed * 0.7, seed * 0.4)
    mapping.inputs["Scale"].default_value = (2.2, 7.0, 7.0) if axis == "X" else (3.5, 3.5, 1.2)
    links.new(coord.outputs["Object"], mapping.inputs["Vector"])
    cells = nodes.new("ShaderNodeTexVoronoi")
    cells.feature = "DISTANCE_TO_EDGE"
    cells.inputs["Scale"].default_value = 3.0
    links.new(mapping.outputs["Vector"], cells.inputs["Vector"])
    crack = nodes.new("ShaderNodeValToRGB")
    crack.color_ramp.elements[0].position = 0.0
    crack.color_ramp.elements[0].color = kit.srgb("17120e")
    crack.color_ramp.elements[1].position = 0.12
    crack.color_ramp.elements[1].color = kit.srgb("ffffff")
    links.new(cells.outputs["Distance"], crack.inputs["Fac"])
    tone = nodes.new("ShaderNodeTexNoise")
    tone.inputs["Scale"].default_value = 4.0
    tone.inputs["Detail"].default_value = 6.0
    links.new(mapping.outputs["Vector"], tone.inputs["Vector"])
    plates = nodes.new("ShaderNodeValToRGB")
    plates.color_ramp.elements[0].position = 0.35
    plates.color_ramp.elements[0].color = kit.srgb("3e3128")
    plates.color_ramp.elements[1].position = 0.7
    plates.color_ramp.elements[1].color = kit.srgb("74604c")
    links.new(tone.outputs["Fac"], plates.inputs["Fac"])
    mix = nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    links.new(plates.outputs["Color"], mix.inputs["A"])
    links.new(crack.outputs["Color"], mix.inputs["B"])
    links.new(mix.outputs["Result"], kit.principled(nodes).inputs["Base Color"])
    return mat


def _block_points(size, seed, count=30):
    """Points pushed towards a box (blocky, not round), jittered in size."""
    rnd = random.Random(seed)
    pts = []
    for _ in range(count):
        v = Vector((rnd.gauss(0, 1), rnd.gauss(0, 1), rnd.gauss(0, 1))).normalized()
        v = Vector([math.copysign(abs(c) ** 0.45, c) for c in v])
        pts.append(Vector((v.x * size[0], v.y * size[1], v.z * size[2])) * rnd.uniform(0.82, 1.0))
    # Fracture planes: everything past a plane is pressed onto it, so the hull
    # gets big flat faces with hard edges.
    for _ in range(rnd.randint(3, 5)):
        n = Vector((rnd.gauss(0, 1), rnd.gauss(0, 1), rnd.gauss(0, 1) * 0.7)).normalized()
        reach = max(abs(n.x) * size[0], abs(n.y) * size[1], abs(n.z) * size[2])
        d = reach * rnd.uniform(0.55, 0.8)
        for p in pts:
            over = p.dot(n) - d
            if over > 0: p -= n * over
    return pts


def _hull(name, pts, location, rotation):
    bm = bmesh.new()
    for p in pts: bm.verts.new(p)
    bmesh.ops.convex_hull(bm, input=bm.verts)
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(2), verts=bm.verts, edges=bm.edges)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bmesh.ops.transform(bm, matrix=Matrix.Translation(location) @ _euler(rotation), verts=bm.verts)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _object(name, bm)


def _euler(rotation):
    from mathutils import Euler
    return Euler(rotation).to_matrix().to_4x4()


def _chip(obj, seed, r):
    """Fine relief that keeps the flat faces: a little lump and crack."""
    kit.roughen(obj, seed, strength=0.035 * r, size=max(0.08, r * 0.5), subdiv=2, crack_strength=0.03 * r)


def shard(name, size, seed, location=(0, 0, 0), rotation=(0, 0, 0), relief=True):
    obj = _hull(name, _block_points(size, seed), Vector(location), rotation)
    if relief: _chip(obj, seed, max(size))
    return obj


def split_block(name, size, seed, location=(0, 0, 0), rotation=(0, 0, 0), gap=0.08):
    """A block split by one steep plane, the halves pulled `gap` apart and one
    tipped a little: the frost crack through a boulder."""
    rnd = random.Random(seed + 1)
    pts = _block_points(size, seed, 40)
    n = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.25, 0.25))).normalized()
    off = rnd.uniform(-0.15, 0.15) * max(size)
    halves = []
    for sign in (1, -1):
        side = [p.copy() for p in pts if (p.dot(n) - off) * sign >= 0]
        side += [p - n * (p.dot(n) - off) for p in pts if (p.dot(n) - off) * sign < 0]
        tip = _euler((rnd.uniform(-0.08, 0.08), rnd.uniform(-0.08, 0.08), rnd.uniform(-0.05, 0.05))) if sign < 0 else Matrix.Identity(4)
        side = [(tip @ p.to_4d()).to_3d() + n * gap * 0.5 * sign for p in side]
        h = _hull(f"{name}_{'ab'[sign < 0]}", side, Vector(location), rotation)
        _chip(h, seed + (sign < 0), max(size))
        halves.append(h)
    return halves
