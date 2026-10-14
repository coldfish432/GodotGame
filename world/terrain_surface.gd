class_name TerrainSurface
extends RefCounted

## A single signed contour drives ground, banks, collision and the local map.
## Triangles are clipped at the contour, avoiding grid-shaped stair-step walls.
##
## The ground is no longer flat: every grid sample carries the height the
## nearest shape gives it (ContinuousWorldMap.owner_height), and the floor is
## the piecewise-linear sheet through those samples. Ramps come out as gentle
## triangles; where two tiers meet without a ramp, the triangle between them
## would be steep — that one is split instead into level floor either side of
## a vertical rock face with a wall on it (_cliff_split), so the high side
## cannot be walked off and the low side cannot be climbed.
const CELL := 1.5
## Clearance a sample needs to count as standing room in the connectivity check.
const STAND := 0.8
var field: Node3D
var noise := FastNoiseLite.new()
## Vertex arrays for one mesh, filled directly and committed in one go: a
## floor runs to a couple of hundred thousand vertices, and SurfaceTool's five
## calls per vertex were most of the terrain's build time.
class MeshArrays:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()

	func commit() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_TEX_UV2] = uv2s
		var mesh := ArrayMesh.new()
		if not vertices.is_empty(): mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh

var floor_tool := MeshArrays.new()
var mass_tool := MeshArrays.new()
var wall_tool := MeshArrays.new()
var collision_walls := PackedVector3Array()
var ground_faces := PackedVector3Array()
var minimap_faces: Array[PackedVector2Array] = []
var boundaries: Array[PackedVector2Array] = []
var cliff_count := 0
## Every walled cliff piece: x, z, x, z of its face line, low floor, high floor,
## then low and high floor at each end (the face tapers where a ramp meets it).
## TerraceDressing stands the Blender cliff segments on these.
var cliff_cuts: Array[PackedFloat32Array] = []
## Every piece of the walkable contour (x, z, x, z); CliffFace sweeps the
## rock banks' faces along these.
var contour_edges: Array[PackedFloat32Array] = []
## Indices of the targets the last connects() found cut off.
var stranded: Array[int] = []
var _vertex_cache := {}
var origin := Vector2.ZERO
var columns := 0
var rows := 0
var _distance := PackedFloat32Array()
var _height_grid := PackedFloat32Array()
var _owner := PackedInt32Array()
## The grid holds this map's distances (distance_at reads them back).
var _sampled := false

## Samples the contour and the ground height on the grid. Cheap enough to
## repeat when the map re-rolls its tiers.
func sample(map: Node3D) -> void:
	field = map
	noise.seed = map.seed_value
	noise.frequency = 0.15
	noise.fractal_octaves = 2
	# Visual apron stays beyond the follow camera at the outermost reward spur.
	origin = map.SPINE_MIN - Vector2(36, 36)
	var visual_max: Vector2 = map.SPINE_MAX + Vector2(36, 36)
	columns = ceili((visual_max.x - origin.x) / CELL)
	rows = ceili((visual_max.y - origin.y) / CELL)
	_distance.resize((rows + 1) * (columns + 1))
	_owner.resize(_distance.size())
	_sampled = false
	for z in range(rows + 1):
		for x in range(columns + 1):
			var p := origin + Vector2(x, z) * CELL
			var index := z * (columns + 1) + x
			_distance[index] = distance_at(p)
			_owner[index] = map._last_owner
	_sampled = true
	relevel()

## Heights again from the owners already sampled, after the tiers changed.
func relevel() -> void:
	_height_grid.resize(_distance.size())
	for z in range(rows + 1):
		for x in range(columns + 1):
			var index := z * (columns + 1) + x
			_height_grid[index] = field.owner_height(_owner[index], origin + Vector2(x, z) * CELL)

## Whether walkable ground joins the first target to every other one, going
## only across triangles that are slope rather than cliff.
func connects(targets: Array[Vector2]) -> bool:
	var parent := PackedInt32Array()
	parent.resize(_distance.size())
	for i in range(parent.size()): parent[i] = i
	for z in range(rows):
		for x in range(columns):
			var a := z * (columns + 1) + x
			var b := a + 1
			var c := a + columns + 2
			var d := a + columns + 1
			for tri in [[a, b, c], [a, c, d]]:
				if not _standing(tri): continue
				_union(parent, tri[0], tri[1])
				_union(parent, tri[0], tri[2])
	var roots := []
	stranded.clear()
	for i in range(targets.size()):
		var vertex := _open_vertex_near(targets[i])
		if vertex < 0: continue
		var root := _find(parent, vertex)
		if roots.is_empty(): roots.append(root)
		elif root != roots[0]: stranded.append(i)
	return stranded.is_empty()

func _standing(tri: Array) -> bool:
	var low := INF
	var high := -INF
	for v in tri:
		if _distance[v] < STAND: return false
		low = minf(low, _height_grid[v])
		high = maxf(high, _height_grid[v])
	return high - low <= field.CLIFF_STEP

func _find(parent: PackedInt32Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i

func _union(parent: PackedInt32Array, a: int, b: int) -> void:
	var ra := _find(parent, a)
	var rb := _find(parent, b)
	if ra != rb: parent[ra] = rb

func _open_vertex_near(point: Vector2) -> int:
	var cell := ((point - origin) / CELL).round()
	for ring in range(3):
		for dz in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				var x := int(cell.x) + dx
				var z := int(cell.y) + dz
				if x < 0 or z < 0 or x > columns or z > rows: continue
				var index := z * (columns + 1) + x
				if _distance[index] >= STAND: return index
	return -1

func build(map: Node3D) -> void:
	field = map
	_build_top_grid()
	map.mark("rock + mountain grids")
	for tool in [floor_tool, mass_tool, wall_tool]:
		tool.vertices.clear(); tool.normals.clear(); tool.colors.clear(); tool.uvs.clear(); tool.uv2s.clear()
	for z in range(rows):
		for x in range(columns):
			var a := origin + Vector2(x, z) * CELL
			var b := a + Vector2(CELL, 0)
			var c := a + Vector2(CELL, CELL)
			var d := a + Vector2(0, CELL)
			var ia := z * (columns + 1) + x
			var ib := ia + 1
			var ic := ia + columns + 2
			var id := ia + columns + 1
			_cut_triangle([a, b, c], [_distance[ia], _distance[ib], _distance[ic]], [_height_grid[ia], _height_grid[ib], _height_grid[ic]])
			_cut_triangle([a, c, d], [_distance[ia], _distance[ic], _distance[id]], [_height_grid[ia], _height_grid[ic], _height_grid[id]])
	map.mark("terrain triangles")
	var ground := _finish(floor_tool, "WalkableTerrain")
	# Floor and cliff faces collide as one sheet: a cliff face is too steep to
	# stand on, but there has to be something under the strip between the
	# floor and the cliff wall or a body there would drop through the map.
	var ground_body := StaticBody3D.new()
	ground_body.name = "WalkableTerrainCollision"
	var ground_shape := ConcavePolygonShape3D.new()
	ground_shape.set_faces(ground_faces)
	var ground_collision := CollisionShape3D.new()
	ground_collision.shape = ground_shape
	ground_body.add_child(ground_collision)
	ground.add_child(ground_body)
	_finish(mass_tool, "RaisedTerrain")
	_finish(wall_tool, "ContourBanks")
	_build_backdrop()
	var body := StaticBody3D.new()
	body.name = "TerrainBoundaryCollision"
	body.add_to_group("world_obstacle")
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(collision_walls)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	map._generated_root.add_child(body)
	map.minimap_faces = minimap_faces
	map.terrain_edges = boundaries

func distance_at(point: Vector2) -> float:
	# A grid vertex was sampled already (build asks for most of them several
	# times over: heights, colours, light); only points between them are new.
	if not _distance.is_empty() and _sampled:
		var cell := (point - origin) / CELL
		var nearest := cell.round()
		if cell.distance_squared_to(nearest) < 0.000001 and nearest.x >= 0 and nearest.y >= 0 and nearest.x <= columns and nearest.y <= rows:
			return _distance[int(nearest.y) * (columns + 1) + int(nearest.x)]
	# Small edge erosion only. Centre lines retain their guaranteed width.
	return field.carved_distance(point) + noise.get_noise_2dv(point) * (0.35 if field.region_id == "city" else 0.85)

## The contour distance at x/z read off the sampled grid (its triangles, as
## ground_at): close to distance_at and nearly free, for placing dressing,
## where a few centimetres do not matter and a full distance field read per
## candidate spot was a good share of the load.
func distance_near(point: Vector2) -> float:
	if _distance.is_empty() or not _sampled: return distance_at(point)
	var cell := (point - origin) / CELL
	var x := clampi(int(floor(cell.x)), 0, columns - 1)
	var z := clampi(int(floor(cell.y)), 0, rows - 1)
	var fraction := (cell - Vector2(x, z)).clamp(Vector2.ZERO, Vector2.ONE)
	var ia := z * (columns + 1) + x
	var da := _distance[ia]
	var dc := _distance[ia + columns + 2]
	if fraction.x >= fraction.y:
		return da * (1.0 - fraction.x) + _distance[ia + 1] * (fraction.x - fraction.y) + dc * fraction.y
	return da * (1.0 - fraction.y) + dc * fraction.x + _distance[ia + columns + 1] * (fraction.y - fraction.x)

## Ground height at x/z on the same triangles the floor mesh uses, so whatever
## stands on this stands on the visible ground.
func ground_at(point: Vector2) -> float:
	if _height_grid.is_empty(): return 0.0
	var cell := (point - origin) / CELL
	var x := clampi(int(floor(cell.x)), 0, columns - 1)
	var z := clampi(int(floor(cell.y)), 0, rows - 1)
	var fraction := (cell - Vector2(x, z)).clamp(Vector2.ZERO, Vector2.ONE)
	var ia := z * (columns + 1) + x
	var ha := _height_grid[ia]
	var hc := _height_grid[ia + columns + 2]
	if fraction.x >= fraction.y:
		return ha * (1.0 - fraction.x) + _height_grid[ia + 1] * (fraction.x - fraction.y) + hc * fraction.y
	return ha * (1.0 - fraction.y) + hc * fraction.x + _height_grid[ia + columns + 1] * (fraction.y - fraction.x)

## No cliff within a step of `point`: the ground around it rises no faster
## than a ramp does.
func is_level(point: Vector2) -> bool:
	var here := ground_at(point)
	for offset in [Vector2(1.5, 0), Vector2(-1.5, 0), Vector2(0, 1.5), Vector2(0, -1.5)]:
		if absf(ground_at(point + offset) - here) > field.CLIFF_STEP * 0.6: return false
	return true

func _clip(points: Array, values: Array, inside: bool) -> PackedVector2Array:
	var output := PackedVector2Array()
	for i in range(3):
		var j := (i + 1) % 3
		var keep_a: bool = values[i] >= 0 if inside else values[i] < 0
		var keep_b: bool = values[j] >= 0 if inside else values[j] < 0
		if keep_a: output.append(points[i])
		if keep_a != keep_b:
			output.append(points[i].lerp(points[j], values[i] / (values[i] - values[j])))
	return output

func _cut_triangle(points: Array, values: Array, heights: Array) -> void:
	var inside := _clip(points, values, true)
	var outside := _clip(points, values, false)
	var low: float = heights.min()
	var high: float = heights.max()
	var cliff: bool = high - low > field.CLIFF_STEP
	if inside.size() >= 3:
		minimap_faces.append(inside)
		if cliff: _cliff_split(inside, low, high)
		else:
			_polygon(floor_tool, inside, 0)
			_collide(inside)
	if outside.size() >= 3: _polygon(mass_tool, outside, 1)
	var edge := PackedVector2Array()
	for i in range(3):
		var j := (i + 1) % 3
		if (values[i] >= 0) != (values[j] >= 0):
			edge.append(points[i].lerp(points[j], values[i] / (values[i] - values[j])))
	if edge.size() != 2 or edge[0].distance_squared_to(edge[1]) < 0.00001: return
	boundaries.append(edge)
	contour_edges.append(PackedFloat32Array([edge[0].x, edge[0].y, edge[1].x, edge[1].y]))
	var a := Vector3(edge[0].x, ground_at(edge[0]), edge[0].y)
	var b := Vector3(edge[1].x, ground_at(edge[1]), edge[1].y)
	var up_a := Vector3(a.x, _height(edge[0], true), a.z)
	var up_b := Vector3(b.x, _height(edge[1], true), b.z)
	var color := Color(0.88, 0.88, 0.88)
	_triangle(wall_tool, a, b, up_b, color * 0.62, color * 0.62, color)
	_triangle(wall_tool, a, up_b, up_a, color * 0.62, color, color)
	# Full collision height blocks dashes and projectiles; the visible bank is
	# low near the road, preserving the top-down view of the character.
	for vertex in [a, b, b + Vector3.UP * 4, a, b + Vector3.UP * 4, a + Vector3.UP * 4]:
		collision_walls.append(vertex)

## A cliff triangle split along a fixed mid-tier height: the floor on each side
## stays level right up to the line, and a vertical rock face stands on it.
## The line comes from the same linear field on every triangle, so where
## neighbouring cliff triangles share an edge they cut it at the same point
## and the face has no gaps. Along an edge whose ends are close in height (a
## ramp meeting the cliff's end) the cut point takes the field's own height on
## both sides, so the face tapers out instead of leaving a crack.
func _cliff_split(polygon: PackedVector2Array, low: float, high: float) -> void:
	var iso: float = (floorf((low + high) * 0.5 / field.TIER) + 0.5) * field.TIER
	if iso <= low or iso >= high: iso = (low + high) * 0.5
	var heights := PackedFloat32Array()
	for p in polygon: heights.append(ground_at(p))
	var upper := PackedVector2Array()
	var upper_h := PackedFloat32Array()
	var lower := PackedVector2Array()
	var lower_h := PackedFloat32Array()
	var cut := PackedVector2Array()
	var cut_top := PackedFloat32Array()
	var cut_bottom := PackedFloat32Array()
	for i in range(polygon.size()):
		var j := (i + 1) % polygon.size()
		var hi := heights[i]
		var hj := heights[j]
		if hi >= iso:
			upper.append(polygon[i])
			upper_h.append(hi)
		else:
			lower.append(polygon[i])
			lower_h.append(hi)
		if (hi >= iso) == (hj >= iso): continue
		var point := polygon[i].lerp(polygon[j], (iso - hi) / (hj - hi))
		var step: bool = absf(hj - hi) > field.CLIFF_STEP
		var top: float = maxf(hi, hj) if step else iso
		var bottom: float = minf(hi, hj) if step else iso
		upper.append(point)
		upper_h.append(top)
		lower.append(point)
		lower_h.append(bottom)
		cut.append(point)
		cut_top.append(top)
		cut_bottom.append(bottom)
	for part in [[upper, upper_h], [lower, lower_h]]:
		if (part[0] as PackedVector2Array).size() < 3: continue
		_polygon_at(floor_tool, part[0], part[1])
		_collide_at(part[0], part[1])
	if cut.size() != 2 or cut[0].distance_squared_to(cut[1]) < 0.00001: return
	var a0 := Vector3(cut[0].x, cut_bottom[0], cut[0].y)
	var b0 := Vector3(cut[1].x, cut_bottom[1], cut[1].y)
	var a1 := Vector3(cut[0].x, cut_top[0], cut[0].y)
	var b1 := Vector3(cut[1].x, cut_top[1], cut[1].y)
	var rock := _color(cut[0], 2)
	_triangle(mass_tool, a0, b0, b1, rock * 0.8, rock * 0.8, rock)
	_triangle(mass_tool, a0, b1, a1, rock * 0.8, rock, rock)
	if maxf(cut_top[0] - cut_bottom[0], cut_top[1] - cut_bottom[1]) <= field.CLIFF_STEP: return
	# Collision along the face, from under the low floor to well over the high
	# one: the high side cannot be walked off, the low side not climbed, and a
	# shot across is stopped like at any other bank.
	cliff_count += 1
	cliff_cuts.append(PackedFloat32Array([cut[0].x, cut[0].y, cut[1].x, cut[1].y, minf(cut_bottom[0], cut_bottom[1]), maxf(cut_top[0], cut_top[1]), cut_bottom[0], cut_top[0], cut_bottom[1], cut_top[1]]))
	boundaries.append(cut)
	_cliff_wall(cut[0], cut[1], minf(cut_bottom[0], cut_bottom[1]) - 0.4, maxf(cut_top[0], cut_top[1]) + 4.0)

## A cliff's collision wall. Where a bridge's deck runs over the cliff it
## stops just under the deck: the road beneath is still walled, and the deck
## carries on over the cliff's top from the stub.
func _cliff_wall(a: Vector2, b: Vector2, bottom: float, top: float) -> void:
	var pieces := [Vector3(0.0, 1.0, top)]
	for bridge in field.bridges:
		if not bridge.has("centre"): continue
		var centre: Vector2 = bridge.centre
		var axis: Vector2 = bridge.axis
		var along := _band((a - centre).dot(axis), (b - centre).dot(axis), float(bridge.span) * 0.5 + field.DECK_OVERLAP + 0.3)
		var across := _band((a - centre).dot(axis.orthogonal()), (b - centre).dot(axis.orthogonal()), field.DECK_HALF_WIDTH + 0.15)
		var lo := maxf(along.x, across.x)
		var hi := minf(along.y, across.y)
		if lo >= hi: continue
		var next := []
		for piece: Vector3 in pieces:
			var from := maxf(piece.x, lo)
			var to := minf(piece.y, hi)
			if from >= to:
				next.append(piece)
				continue
			if from > piece.x: next.append(Vector3(piece.x, from, piece.z))
			next.append(Vector3(from, to, minf(piece.z, float(bridge.top) - 0.25)))
			if to < piece.y: next.append(Vector3(to, piece.y, piece.z))
		pieces = next
	for piece: Vector3 in pieces:
		var pa := a.lerp(b, piece.x)
		var pb := a.lerp(b, piece.y)
		var wa := Vector3(pa.x, bottom, pa.y)
		var wb := Vector3(pb.x, bottom, pb.y)
		for vertex in [wa, wb, Vector3(wb.x, piece.z, wb.z), wa, Vector3(wb.x, piece.z, wb.z), Vector3(wa.x, piece.z, wa.z)]:
			collision_walls.append(vertex)

## The part of [0, 1] where a value running linearly from f0 to f1 stays
## within +-limit (empty: x >= y).
static func _band(f0: float, f1: float, limit: float) -> Vector2:
	if absf(f1 - f0) < 0.000001: return Vector2(0.0, 1.0) if absf(f0) <= limit else Vector2(1.0, 0.0)
	var t0 := (-limit - f0) / (f1 - f0)
	var t1 := (limit - f0) / (f1 - f0)
	return Vector2(clampf(minf(t0, t1), 0.0, 1.0), clampf(maxf(t0, t1), 0.0, 1.0))

## A floor polygon at given heights (colour and light still from the cache).
func _polygon_at(tool: MeshArrays, polygon: PackedVector2Array, heights: PackedFloat32Array) -> void:
	for i in range(1, polygon.size() - 1):
		var vertices: Array[Vector3] = []
		var colors: Array[Color] = []
		var lights: Array[float] = []
		for k in [0, i, i + 1]:
			var p: Vector2 = polygon[k]
			var key := Vector3(p.x, 0.0, p.y)
			if not _vertex_cache.has(key):
				_vertex_cache[key] = [Vector3(p.x, _height(p, false), p.y), _color(p, 0), _terrace_light(p)]
			vertices.append(Vector3(p.x, heights[k], p.y))
			colors.append(_vertex_cache[key][1])
			lights.append(_vertex_cache[key][2])
		_triangle(tool, vertices[0], vertices[1], vertices[2], colors[0], colors[1], colors[2], lights)

func _collide_at(polygon: PackedVector2Array, heights: PackedFloat32Array) -> void:
	for i in range(1, polygon.size() - 1):
		for k in [0, i, i + 1]:
			ground_faces.append(Vector3(polygon[k].x, heights[k], polygon[k].y))

func _collide(polygon: PackedVector2Array) -> void:
	for i in range(1, polygon.size() - 1):
		# Same winding as the floor mesh: navigation baking reads it as up-facing.
		for p in [polygon[0], polygon[i], polygon[i + 1]]:
			ground_faces.append(Vector3(p.x, ground_at(p), p.y))

## Rock height: the ground's own level there plus the regional bank profile.
func _height(point: Vector2, mass: bool) -> float:
	var ground := ground_at(point)
	if not mass: return ground
	var depth := maxf(0, -distance_at(point))
	if field.region_id == "snow":
		# Under the snow drift (CliffFace._drift_profile) the rock eases up
		# from the rim instead of standing as a wall.
		var top := rock_top_at(point)
		# Beside a causeway the drift falls away at once, behind its wall.
		var rise := smoothstep(0.0, 0.7 if top < ground - 0.3 else 2.6, depth)
		return lerpf(ground, top, rise) + mountain_at(point) + noise.get_noise_2dv(point * 0.65) * minf(depth * 0.1, 0.25)
	# A flat-topped bank (rock_top_at), just roughened: a little noise that
	# fades in from the rim, so the top meets the swept face's lip flush.
	return rock_top_at(point) + noise.get_noise_2dv(point * 0.65) * minf(depth * 0.1, 0.18)

## Surface height at x/z: the floor where open, the rock mass where not.
func height_at(point: Vector2) -> float:
	if distance_at(point) >= 0: return ground_at(point)
	# Interpolate the same grid triangles used for the visible mass, so props
	# follow its actual mesh instead of hovering over an analytic approximation.
	var cell := (point - origin) / CELL
	var fraction := cell - cell.floor()
	var a := origin + cell.floor() * CELL
	var ha := _height(a, true)
	var hc := _height(a + Vector2(CELL, CELL), true)
	if fraction.x >= fraction.y:
		return ha * (1.0 - fraction.x) + _height(a + Vector2(CELL, 0), true) * (fraction.x - fraction.y) + hc * fraction.y
	return ha * (1.0 - fraction.y) + hc * fraction.x + _height(a + Vector2(0, CELL), true) * (fraction.y - fraction.x)

## `height`: the vertex's own height when the caller has it (mass vertices).
func _color(point: Vector2, kind: int, height: float = NAN) -> Color:
	if kind == 2:
		# Cliff face: the darker rock of a bank's foot.
		return Color(0.7, 0.7, 0.7)
	if kind == 1:
		var depth := maxf(0, -distance_at(point))
		var contact := lerpf(0.78, 1.0, smoothstep(0.0, 3.0, depth))
		# Alpha: shade laid over the snow too (cliff_face.gdshader), deeper the
		# further the rock lies below the floor beside it — a causeway's
		# fallen-away side.
		var drop := ground_at(point) - (height if not is_nan(height) else _height(point, true))
		return Color(contact, contact, contact, lerpf(1.0, 0.4, smoothstep(0.15, 1.8, drop)))
	var road := 1.0 - smoothstep(1.3, 3.6, field.road_distance(point))
	var open := maxf(0, distance_at(point))
	var edge := smoothstep(0.0, 2.5, open)
	var color: Color
	match field.region_id:
		"city": color = Color("454e54").lerp(Color("786f5a"), road * 0.42)
		"snow": color = Color("76919c").lerp(Color("b6c1b5"), road * 0.65)
		_: color = Color("615646").lerp(Color("988164"), road * 0.65)
	var mottling := 0.94 + noise.get_noise_2dv(point * 2.3) * 0.14
	color *= mottling * lerpf(0.57, 1.0, edge)
	color.a = smoothstep(0.0, 1.4, open)
	return color

## How a terrace reads from the follow camera, which sees no slope: the
## higher the tier the lighter its floor, ground at the foot of a cliff lies in
## its shadow, and the cliff's top edge catches the light.
## Cast shadow (参考《恐怖黎明》's low sun): the camera sees almost no slope,
## so a terrace reads by the shadow it throws on the ground below it. The sun
## stands toward world +X / +Z, so shadows fall to the bottom right of the
## screen (screen right is world -X). Marched over the top-surface grid, which
## includes the rock banks, once per vertex at build time.
const SUN_XZ := Vector2(0.6, 0.8)
const SUN_SLOPE := 0.6  # tan of the sun's elevation, ~31 degrees: a tier throws ~3.7 m
const SHADOW_REACH := 8.0
var _top_grid := PackedFloat32Array()

## The rock mass's top, one smooth sheet (user, 2026-10-12: the rock read as a
## sunken bowl behind its rim, and boxes stood inside it). Its base is the
## highest walkable floor within ROCK_REACH — so rock between two terraces
## stands at least level with the upper one — blurred until no step is left,
## then one fixed bank height on top: flush with the bank face's rim.
const ROCK_REACH := 3
const ROCK_BLUR := 6

func _build_top_grid() -> void:
	var size := _height_grid.size()
	var base := PackedFloat32Array()
	base.resize(size)
	var width := columns + 1
	for z in range(rows + 1):
		for x in range(width):
			var i := z * width + x
			if _distance[i] >= 0.0:
				base[i] = _height_grid[i]
				continue
			var best := -INF
			for dz in range(-ROCK_REACH, ROCK_REACH + 1):
				var zz := z + dz
				if zz < 0 or zz > rows: continue
				for dx in range(-ROCK_REACH, ROCK_REACH + 1):
					var xx := x + dx
					if xx < 0 or xx >= width: continue
					var k := zz * width + xx
					if _distance[k] >= 0.0: best = maxf(best, _height_grid[k])
			base[i] = best if best > -INF else _height_grid[i]
	# Deep rock with no floor in reach takes its neighbours' level as the
	# blur spreads; rock vertices only, so the floor is never lifted.
	for pass_index in range(ROCK_BLUR):
		var next := base.duplicate()
		for z in range(1, rows):
			for x in range(1, width - 1):
				var i := z * width + x
				if _distance[i] >= 0.0: continue
				next[i] = (base[i] * 4.0 + base[i - 1] + base[i + 1] + base[i - width] + base[i + width]) / 8.0
		base = next
	base = _causeways(base)
	_rock_grid.resize(size)
	_top_grid.resize(size)
	for i in range(size):
		_rock_grid[i] = base[i] + _bank()
	_build_mountains()
	for i in range(size):
		_top_grid[i] = _rock_grid[i] + _mountain_grid[i] if _distance[i] < 0.0 else _height_grid[i]

var _rock_grid := PackedFloat32Array()

## Ramps as causeways (用户 2026-10-13: 用了坡道的地方根本看不出来抬高了): the
## rock beside a ramp no longer climbs with it. Within CAUSEWAY_REACH cells of
## sloped floor it is held to the tier below that floor, so the further up the
## ramp the more it stands out of the ground either side, and the rise shows
## as the bank falling away from the kerbs, with its shadow. A couple of blur
## passes ease the held band back into the rock round it.
const CAUSEWAY_REACH := 4
const CAUSEWAY_SLOPE := Vector2(0.12, 0.7)

func _causeways(base: PackedFloat32Array) -> PackedFloat32Array:
	var width := columns + 1
	var cap := PackedFloat32Array()
	cap.resize(base.size())
	cap.fill(INF)
	var any := false
	for z in range(1, rows):
		for x in range(1, width - 1):
			var k := z * width + x
			if _distance[k] < 0.0: continue
			var gx := (_height_grid[k + 1] - _height_grid[k - 1]) / (2.0 * CELL)
			var gz := (_height_grid[k + width] - _height_grid[k - width]) / (2.0 * CELL)
			var slope := Vector2(gx, gz).length()
			if slope < CAUSEWAY_SLOPE.x or slope > CAUSEWAY_SLOPE.y: continue
			# The tier this stretch of ramp climbs from; the rock beside it
			# tops out at that floor, bank and all taken off.
			var below: float = floorf((_height_grid[k] - 0.01) / field.TIER) * field.TIER - _bank()
			for dz in range(-CAUSEWAY_REACH, CAUSEWAY_REACH + 1):
				for dx in range(-CAUSEWAY_REACH, CAUSEWAY_REACH + 1):
					var zz := z + dz
					var xx := x + dx
					if zz < 0 or zz > rows or xx < 0 or xx >= width: continue
					var i := zz * width + xx
					if _distance[i] >= 0.0: continue
					cap[i] = minf(cap[i], below)
					any = true
	if not any: return base
	for i in range(base.size()): base[i] = minf(base[i], cap[i])
	for pass_index in range(2):
		var next := base.duplicate()
		for z in range(1, rows):
			for x in range(1, width - 1):
				var i := z * width + x
				if _distance[i] >= 0.0: continue
				next[i] = (base[i] * 4.0 + base[i - 1] + base[i + 1] + base[i - width] + base[i + width]) / 8.0
		base = next
	return base

## Snow mountains on the rock off the road (用户 2026-10-12: 组成边界的区块做成
## 雪山的样式，不规律的向上倾斜，随机生成等高线后平滑处理). In the snowfield
## the rock is not a flat bank but rises away from the road: a noise height
## cut into contour steps (MOUNTAIN_STEP) and blurred, so the slopes come out
## as soft irregular terraces; the rise starts behind the drift at the rim.
## Rock that stands between the camera and a road is held down, by how far
## the road lies to the north of it (the camera looks north, down 58°).
## Zero everywhere else.
const MOUNTAIN_HEIGHT := 14.0
const MOUNTAIN_STEP := 1.6
const MOUNTAIN_BLUR := 2
## Height the rock may stand per metre of rock to the north of it before a road.
const MOUNTAIN_SIGHT := 1.4
var _mountain_grid := PackedFloat32Array()

func _build_mountains() -> void:
	var size := _height_grid.size()
	_mountain_grid.resize(size)
	_mountain_grid.fill(0.0)
	if field.region_id != "snow": return
	var shape := FastNoiseLite.new()
	shape.seed = field.seed_value ^ 0x5a0c
	shape.frequency = 0.028
	shape.fractal_octaves = 4
	var width := columns + 1
	var raw := PackedFloat32Array()
	raw.resize(size)
	# Rock samples in a row from each one northwards, counted once per column
	# (a run that reaches the map's edge counts as unbounded).
	var run := PackedInt32Array()
	run.resize(size + width)
	for x in range(width): run[(rows + 1) * width + x] = 100000
	for z in range(rows, -1, -1):
		for x in range(width):
			var i := z * width + x
			run[i] = run[i + width] + 1 if _distance[i] < 0.0 else 0
	# The shape noise rolls over ~36 m: read on every other sample, blended
	# between (four octaves per sample was most of this pass).
	var coarse_width := width / 2 + 2
	var coarse := PackedFloat32Array()
	coarse.resize(coarse_width * (rows / 2 + 2))
	for cz in range(rows / 2 + 2):
		for cx in range(coarse_width):
			coarse[cz * coarse_width + cx] = clampf(shape.get_noise_2dv(origin + Vector2(cx * 2, cz * 2) * CELL) * 0.5 + 0.5, 0.0, 1.0)
	for z in range(rows + 1):
		for x in range(width):
			var i := z * width + x
			if _distance[i] >= 0.0: continue
			var depth := -_distance[i]
			# The rise starts 2.4 in: nearer the rim there is no mountain to read.
			if depth <= 2.4: continue
			var c := (z / 2) * coarse_width + x / 2
			var fx := float(x % 2) * 0.5
			var fz := float(z % 2) * 0.5
			var n := lerpf(lerpf(coarse[c], coarse[c + 1], fx), lerpf(coarse[c + coarse_width], coarse[c + coarse_width + 1], fx), fz)
			var h := smoothstep(2.4, 18.0, depth) * (0.25 + 0.75 * n) * MOUNTAIN_HEIGHT
			# Contour steps, then smoothed below.
			h = floorf(h / MOUNTAIN_STEP) * MOUNTAIN_STEP
			# Held down where a road lies to the north (towards +z) within sight.
			var north := run[i + width] if z < rows else 100000
			if north < 24: h = minf(h, float(north) * CELL * MOUNTAIN_SIGHT)
			raw[i] = h
	for pass_index in range(MOUNTAIN_BLUR):
		var next := raw.duplicate()
		for z in range(1, rows):
			for x in range(1, width - 1):
				var i := z * width + x
				if _distance[i] >= 0.0: continue
				next[i] = (raw[i] * 4.0 + raw[i - 1] + raw[i + 1] + raw[i - width] + raw[i + width]) / 8.0
		raw = next
	_mountain_grid = raw

## Mountain height above the bank at x/z (grid triangles, as the mesh).
func mountain_at(point: Vector2) -> float:
	if _mountain_grid.is_empty(): return 0.0
	var cell := (point - origin) / CELL
	var x := clampi(int(floor(cell.x)), 0, columns - 1)
	var z := clampi(int(floor(cell.y)), 0, rows - 1)
	var fraction := (cell - Vector2(x, z)).clamp(Vector2.ZERO, Vector2.ONE)
	var ia := z * (columns + 1) + x
	var ha := _mountain_grid[ia]
	var hc := _mountain_grid[ia + columns + 2]
	if fraction.x >= fraction.y:
		return ha * (1.0 - fraction.x) + _mountain_grid[ia + 1] * (fraction.x - fraction.y) + hc * fraction.y
	return ha * (1.0 - fraction.y) + hc * fraction.x + _mountain_grid[ia + columns + 1] * (fraction.y - fraction.x)

## The rock bank's height above its base, flat (_height adds only a little noise).
func _bank(_depth: float = 0.0) -> float:
	match field.region_id:
		"city": return 1.1
		"snow": return 1.1
		_: return 1.6

## Rock top at x/z, on the same grid triangles as the mesh, without noise.
func rock_top_at(point: Vector2) -> float:
	if _rock_grid.is_empty(): return ground_at(point) + _bank()
	var cell := (point - origin) / CELL
	var x := clampi(int(floor(cell.x)), 0, columns - 1)
	var z := clampi(int(floor(cell.y)), 0, rows - 1)
	var fraction := (cell - Vector2(x, z)).clamp(Vector2.ZERO, Vector2.ONE)
	var ia := z * (columns + 1) + x
	var ha := _rock_grid[ia]
	var hc := _rock_grid[ia + columns + 2]
	if fraction.x >= fraction.y:
		return ha * (1.0 - fraction.x) + _rock_grid[ia + 1] * (fraction.x - fraction.y) + hc * fraction.y
	return ha * (1.0 - fraction.y) + hc * fraction.x + _rock_grid[ia + columns + 1] * (fraction.y - fraction.x)

## Height of the visible top at x/z: the floor, or the rock mass's top.
func top_at(point: Vector2) -> float:
	return _top_at(point) if not _top_grid.is_empty() else ground_at(point)

func _top_at(point: Vector2) -> float:
	var cell := (point - origin) / CELL
	var x := clampi(int(floor(cell.x)), 0, columns - 1)
	var z := clampi(int(floor(cell.y)), 0, rows - 1)
	var fraction := (cell - Vector2(x, z)).clamp(Vector2.ZERO, Vector2.ONE)
	var ia := z * (columns + 1) + x
	var ha := _top_grid[ia]
	var hc := _top_grid[ia + columns + 2]
	if fraction.x >= fraction.y:
		return ha * (1.0 - fraction.x) + _top_grid[ia + 1] * (fraction.x - fraction.y) + hc * fraction.y
	return ha * (1.0 - fraction.y) + hc * fraction.x + _top_grid[ia + columns + 1] * (fraction.y - fraction.x)

## 0 in full sun, 1 in full shadow (soft over 0.6 of clearance).
func _shadow(point: Vector2, ground: float) -> float:
	var shade := 0.0
	var t := 0.6
	while t <= SHADOW_REACH:
		var blocker := _top_at(point + SUN_XZ * t) - (ground + t * SUN_SLOPE)
		if blocker > 0.0: shade = maxf(shade, clampf(blocker / 0.6, 0.0, 1.0))
		if shade >= 1.0: break
		t += 0.5
	return shade

## A ramp reads by its light as well (用户 2026-10-13: 坡道看不出抬高): the
## follow camera sees no slope, so floor tilted towards the low sun is lit
## up and floor tilted away from it darkened, by the ratio of their sun-facing,
## softened by this power. Cliffs (whose samples jump) are left to the faces.
const SLOPE_LIGHT := 0.7

func _terrace_light(point: Vector2) -> float:
	var ground := ground_at(point)
	var light := lerpf(0.76, 1.2, clampf(ground / (field.TIER * field.MAX_TIER), 0.0, 1.0))
	var gx := (ground_at(point + Vector2(0.75, 0.0)) - ground_at(point - Vector2(0.75, 0.0))) / 1.5
	var gz := (ground_at(point + Vector2(0.0, 0.75)) - ground_at(point - Vector2(0.0, 0.75))) / 1.5
	if Vector2(gx, gz).length() < 0.7:
		var sun := Vector3(SUN_XZ.x, SUN_SLOPE, SUN_XZ.y).normalized()
		var facing := Vector3(-gx, 1.0, -gz).normalized().dot(sun) / sun.y
		light *= pow(clampf(facing, 0.3, 2.0), SLOPE_LIGHT)
	if not _top_grid.is_empty(): light *= lerpf(1.0, 0.5, _shadow(point, ground))
	var below := 0.0
	var above := 0.0
	for k in range(8):
		var probe := point + Vector2.from_angle(TAU * k / 8.0) * 2.0
		var rise := ground_at(probe) - ground
		above = maxf(above, rise)
		below = maxf(below, -rise)
	if above > field.CLIFF_STEP: light *= lerpf(0.78, 0.6, clampf((above - field.CLIFF_STEP) / field.TIER, 0.0, 1.0))
	elif below > field.CLIFF_STEP: light *= 1.16
	return light

## kind 0 floor, 1 rock mass, 2 cliff face.
func _polygon(tool: MeshArrays, polygon: PackedVector2Array, kind: int) -> void:
	for i in range(1, polygon.size() - 1):
		var points := [polygon[0], polygon[i], polygon[i + 1]]
		var vertices: Array[Vector3] = []
		var colors: Array[Color] = []
		var lights: Array[float] = []
		for p: Vector2 in points:
			var key := Vector3(p.x, float(kind), p.y)
			if not _vertex_cache.has(key):
				var height := _height(p, kind == 1)
				_vertex_cache[key] = [Vector3(p.x, height, p.y), _color(p, kind, height if kind == 1 else NAN), _terrace_light(p) if kind == 0 else 1.0]
			vertices.append(_vertex_cache[key][0])
			colors.append(_vertex_cache[key][1])
			lights.append(_vertex_cache[key][2])
		_triangle(tool, vertices[0], vertices[1], vertices[2], colors[0], colors[1], colors[2], lights)

## `lights` reaches the floor shader as UV2.x (see FieldArt.terrain_material).
func _triangle(tool: MeshArrays, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color, lights: Array[float] = [1.0, 1.0, 1.0]) -> void:
	var normal := (c - a).cross(b - a).normalized()
	var shade := 0.74 + absf(normal.dot(Vector3(-0.4, 0.8, -0.4).normalized())) * 0.26
	var vertices := [a, b, c]
	var colors := [ca, cb, cc]
	for i in range(3):
		tool.normals.append(normal)
		var shaded: Color = colors[i] * shade
		shaded.a = colors[i].a
		tool.colors.append(shaded)
		tool.uvs.append(Vector2(vertices[i].x, vertices[i].z) / 5.0)
		tool.uv2s.append(Vector2(lights[i], 0.0))
		tool.vertices.append(vertices[i])

func _finish(tool: MeshArrays, label: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = tool.commit()
	# Rock mass and banks take the swept faces' rock (CliffFace.rock_material),
	# so the raised ground off the road reads as rock, not as painted floor.
	node.material_override = FieldArt.terrain_material(field.region_id) if label == "WalkableTerrain" else CliffFace.rock_material(field.region_id)
	field._generated_root.add_child(node)
	return node

func _build_backdrop() -> void:
	# A visual-only continuation also fills wide overview cameras beyond the
	# detailed terrain apron. It has no collider and is excluded from baking.
	var backdrop := MeshInstance3D.new()
	backdrop.name = "RegionalBackdrop"
	var plane := PlaneMesh.new()
	plane.size = field.SPINE_MAX - field.SPINE_MIN + Vector2(512, 512)
	backdrop.mesh = plane
	backdrop.position = Vector3(field.map_center.x, -0.12, field.map_center.z)
	backdrop.material_override = FieldArt.background_material(field.region_id)
	field._generated_root.add_child(backdrop)
