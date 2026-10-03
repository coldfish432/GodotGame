class_name TerrainSurface
extends RefCounted

## A single signed contour drives ground, banks, collision and the local map.
## Triangles are clipped at the contour, avoiding grid-shaped stair-step walls.
const CELL := 1.5
var field: Node3D
var noise := FastNoiseLite.new()
var floor_tool := SurfaceTool.new()
var mass_tool := SurfaceTool.new()
var wall_tool := SurfaceTool.new()
var collision_walls := PackedVector3Array()
var minimap_faces: Array[PackedVector2Array] = []
var boundaries: Array[PackedVector2Array] = []
var _vertex_cache := {}

func build(map: Node3D) -> void:
	field = map
	noise.seed = map.seed_value
	noise.frequency = 0.15
	noise.fractal_octaves = 2
	for tool in [floor_tool, mass_tool, wall_tool]: tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Visual apron stays beyond the follow camera at the outermost reward spur.
	var visual_min: Vector2 = map.SPINE_MIN - Vector2(36, 36)
	var visual_max: Vector2 = map.SPINE_MAX + Vector2(36, 36)
	var columns := ceili((visual_max.x - visual_min.x) / CELL)
	var rows := ceili((visual_max.y - visual_min.y) / CELL)
	var samples: Array[PackedFloat32Array] = []
	for z in range(rows + 1):
		var row := PackedFloat32Array()
		for x in range(columns + 1):
			row.append(distance_at(visual_min + Vector2(x, z) * CELL))
		samples.append(row)
	for z in range(rows):
		for x in range(columns):
			var a := visual_min + Vector2(x, z) * CELL
			var b := a + Vector2(CELL, 0)
			var c := a + Vector2(CELL, CELL)
			var d := a + Vector2(0, CELL)
			_cut_triangle([a, b, c], [samples[z][x], samples[z][x + 1], samples[z + 1][x + 1]])
			_cut_triangle([a, c, d], [samples[z][x], samples[z + 1][x + 1], samples[z + 1][x]])
	var ground := _finish(floor_tool, "WalkableTerrain")
	ground.create_trimesh_collision()
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

func _cut_triangle(points: Array, values: Array) -> void:
	var inside := _clip(points, values, true)
	var outside := _clip(points, values, false)
	if inside.size() >= 3:
		minimap_faces.append(inside)
		_polygon(floor_tool, inside, false)
	if outside.size() >= 3: _polygon(mass_tool, outside, true)
	var edge := PackedVector2Array()
	for i in range(3):
		var j := (i + 1) % 3
		if (values[i] >= 0) != (values[j] >= 0):
			edge.append(points[i].lerp(points[j], values[i] / (values[i] - values[j])))
	if edge.size() != 2 or edge[0].distance_squared_to(edge[1]) < 0.00001: return
	boundaries.append(edge)
	var a := Vector3(edge[0].x, 0, edge[0].y)
	var b := Vector3(edge[1].x, 0, edge[1].y)
	var up_a := a + Vector3.UP * _height(edge[0], true)
	var up_b := b + Vector3.UP * _height(edge[1], true)
	var color := Color(0.88, 0.88, 0.88)
	_triangle(wall_tool, a, b, up_b, color * 0.62, color * 0.62, color)
	_triangle(wall_tool, a, up_b, up_a, color * 0.62, color, color)
	# Full collision height blocks dashes and projectiles; the visible bank is
	# low near the road, preserving the top-down view of the character.
	for vertex in [a, b, b + Vector3.UP * 4, a, b + Vector3.UP * 4, a + Vector3.UP * 4]:
		collision_walls.append(vertex)

func _height(point: Vector2, mass: bool) -> float:
	if not mass: return 0.0
	var depth := maxf(0, -distance_at(point))
	# These are ground formations, not identical tall plateaus in every biome.
	# The collision contour stays unchanged; dressing supplies rocks, walls
	# and trees on top of the regional ground profile.
	match field.region_id:
		"city": return 0.60 + minf(depth * 0.045, 0.55) + noise.get_noise_2dv(point * 0.45) * minf(depth, 0.4)
		"snow": return 0.45 + minf(depth * 0.09, 1.5) + noise.get_noise_2dv(point * 0.45) * minf(depth, 0.8)
		_: return 0.75 + minf(depth * 0.22, 3.0) + noise.get_noise_2dv(point * 0.65) * minf(depth, 0.8)

func height_at(point: Vector2) -> float:
	if distance_at(point) >= 0: return 0.0
	# Interpolate the same grid triangles used for the visible mass, so props
	# follow its actual mesh instead of hovering over an analytic approximation.
	var origin: Vector2 = field.SPINE_MIN - Vector2(36, 36)
	var cell := (point - origin) / CELL
	var fraction := cell - cell.floor()
	var a := origin + cell.floor() * CELL
	var ha := _height(a, true)
	var hc := _height(a + Vector2(CELL, CELL), true)
	if fraction.x >= fraction.y:
		return ha * (1.0 - fraction.x) + _height(a + Vector2(CELL, 0), true) * (fraction.x - fraction.y) + hc * fraction.y
	return ha * (1.0 - fraction.y) + hc * fraction.x + _height(a + Vector2(0, CELL), true) * (fraction.y - fraction.x)

func _color(point: Vector2, mass: bool) -> Color:
	if mass:
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

func _polygon(tool: SurfaceTool, polygon: PackedVector2Array, mass: bool) -> void:
	for i in range(1, polygon.size() - 1):
		var points := [polygon[0], polygon[i], polygon[i + 1]]
		var vertices: Array[Vector3] = []
		var colors: Array[Color] = []
		for p: Vector2 in points:
			var key := Vector3(p.x, 1.0 if mass else 0.0, p.y)
			if not _vertex_cache.has(key):
				_vertex_cache[key] = [Vector3(p.x, _height(p, mass), p.y), _color(p, mass)]
			vertices.append(_vertex_cache[key][0])
			colors.append(_vertex_cache[key][1])
		_triangle(tool, vertices[0], vertices[1], vertices[2], colors[0], colors[1], colors[2])

func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
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
