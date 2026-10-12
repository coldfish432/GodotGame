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
var floor_tool := SurfaceTool.new()
var mass_tool := SurfaceTool.new()
var wall_tool := SurfaceTool.new()
var collision_walls := PackedVector3Array()
var ground_faces := PackedVector3Array()
var minimap_faces: Array[PackedVector2Array] = []
var boundaries: Array[PackedVector2Array] = []
var cliff_count := 0
## Indices of the targets the last connects() found cut off.
var stranded: Array[int] = []
var _vertex_cache := {}
var origin := Vector2.ZERO
var columns := 0
var rows := 0
var _distance := PackedFloat32Array()
var _height_grid := PackedFloat32Array()
var _owner := PackedInt32Array()

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
	for z in range(rows + 1):
		for x in range(columns + 1):
			var p := origin + Vector2(x, z) * CELL
			var index := z * (columns + 1) + x
			_distance[index] = distance_at(p)
			_owner[index] = map._last_owner
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
	for tool in [floor_tool, mass_tool, wall_tool]: tool.begin(Mesh.PRIMITIVE_TRIANGLES)
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
	# Small edge erosion only. Centre lines retain their guaranteed width.
	return field.carved_distance(point) + noise.get_noise_2dv(point) * (0.35 if field.region_id == "city" else 0.85)

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
	boundaries.append(cut)
	var bottom := minf(cut_bottom[0], cut_bottom[1]) - 0.4
	var top := maxf(cut_top[0], cut_top[1]) + 4.0
	var wa := Vector3(cut[0].x, bottom, cut[0].y)
	var wb := Vector3(cut[1].x, bottom, cut[1].y)
	for vertex in [wa, wb, Vector3(wb.x, top, wb.z), wa, Vector3(wb.x, top, wb.z), Vector3(wa.x, top, wa.z)]:
		collision_walls.append(vertex)

## A floor polygon at given heights (colour and light still from the cache).
func _polygon_at(tool: SurfaceTool, polygon: PackedVector2Array, heights: PackedFloat32Array) -> void:
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
	# These are ground formations, not identical tall plateaus in every biome.
	# The collision contour stays unchanged; dressing supplies rocks, walls
	# and trees on top of the regional ground profile.
	match field.region_id:
		"city": return ground + 0.60 + minf(depth * 0.045, 0.55) + noise.get_noise_2dv(point * 0.45) * minf(depth, 0.4)
		"snow": return ground + 0.45 + minf(depth * 0.09, 1.5) + noise.get_noise_2dv(point * 0.45) * minf(depth, 0.8)
		_: return ground + 0.75 + minf(depth * 0.22, 3.0) + noise.get_noise_2dv(point * 0.65) * minf(depth, 0.8)

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

func _color(point: Vector2, kind: int) -> Color:
	if kind == 2:
		# Cliff face: the darker rock of a bank's foot.
		return Color(0.7, 0.7, 0.7)
	if kind == 1:
		var contact := lerpf(0.78, 1.0, smoothstep(0.0, 3.0, maxf(0, -distance_at(point))))
		return Color(contact, contact, contact)
	var road := 1.0 - smoothstep(1.3, 3.6, field.road_distance(point))
	var edge := smoothstep(0.0, 2.5, maxf(0, distance_at(point)))
	var color: Color
	match field.region_id:
		"city": color = Color("454e54").lerp(Color("786f5a"), road * 0.42)
		"snow": color = Color("76919c").lerp(Color("b6c1b5"), road * 0.65)
		_: color = Color("615646").lerp(Color("988164"), road * 0.65)
	var mottling := 0.94 + noise.get_noise_2dv(point * 2.3) * 0.14
	color *= mottling * lerpf(0.57, 1.0, edge)
	color.a = smoothstep(0.0, 1.4, maxf(0, distance_at(point)))
	return color

## How a terrace reads from the follow camera, which sees no slope: the
## higher the tier the lighter its floor, ground at the foot of a cliff lies in
## its shadow, and the cliff's top edge catches the light.
func _terrace_light(point: Vector2) -> float:
	var ground := ground_at(point)
	var light := lerpf(0.86, 1.1, clampf(ground / (field.TIER * field.MAX_TIER), 0.0, 1.0))
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
func _polygon(tool: SurfaceTool, polygon: PackedVector2Array, kind: int) -> void:
	for i in range(1, polygon.size() - 1):
		var points := [polygon[0], polygon[i], polygon[i + 1]]
		var vertices: Array[Vector3] = []
		var colors: Array[Color] = []
		var lights: Array[float] = []
		for p: Vector2 in points:
			var key := Vector3(p.x, float(kind), p.y)
			if not _vertex_cache.has(key):
				_vertex_cache[key] = [Vector3(p.x, _height(p, kind == 1), p.y), _color(p, kind), _terrace_light(p) if kind == 0 else 1.0]
			vertices.append(_vertex_cache[key][0])
			colors.append(_vertex_cache[key][1])
			lights.append(_vertex_cache[key][2])
		_triangle(tool, vertices[0], vertices[1], vertices[2], colors[0], colors[1], colors[2], lights)

## `lights` reaches the floor shader as UV2.x (see FieldArt.terrain_material).
func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color, lights: Array[float] = [1.0, 1.0, 1.0]) -> void:
	var normal := (c - a).cross(b - a).normalized()
	var shade := 0.74 + absf(normal.dot(Vector3(-0.4, 0.8, -0.4).normalized())) * 0.26
	var vertices := [a, b, c]
	var colors := [ca, cb, cc]
	for i in range(3):
		tool.set_normal(normal)
		var shaded: Color = colors[i] * shade
		shaded.a = colors[i].a
		tool.set_color(shaded)
		tool.set_uv(Vector2(vertices[i].x, vertices[i].z) / 5.0)
		tool.set_uv2(Vector2(lights[i], 0.0))
		tool.add_vertex(vertices[i])

func _finish(tool: SurfaceTool, label: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = tool.commit()
	node.material_override = FieldArt.terrain_material(field.region_id) if label == "WalkableTerrain" else FieldArt.background_material(field.region_id)
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
