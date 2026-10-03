class_name SceneDressing
extends RefCounted

## Biome compositions share the terrain's material, palette and ground height.
## All geometry is visual only and batched; gameplay uses the original contour.
var map: Node3D
var root: Node3D
var rng := RandomNumberGenerator.new()
var solids := SurfaceTool.new()
var stains := SurfaceTool.new()
var occupied: Array[Vector3] = []
var triangle_count := 0
var stain_count := 0

func build(world: Node3D) -> void:
	map = world
	rng.seed = map.seed_value ^ 935713
	root = Node3D.new()
	root.name = "SceneDressing"
	root.add_to_group("field_props")
	map._generated_root.add_child(root)
	solids.begin(Mesh.PRIMITIVE_TRIANGLES)
	stains.begin(Mesh.PRIMITIVE_TRIANGLES)
	_dress_corridors()
	_dress_edges()
	# Jittered cells place complete groups, with a surface clearance budget.
	# No dependency on triangle order, unlike decorating every Nth edge.
	var spacing := 15.0 if map.region_id == "snow" else 18.0
	for z in range(int(map.SPINE_MIN.y), int(map.SPINE_MAX.y), int(spacing)):
		for x in range(int(map.SPINE_MIN.x), int(map.SPINE_MAX.x), int(spacing)):
			var p := Vector2(x, z) + Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 4))
			var depth: float = -map._surface.distance_at(p)
			if depth < 12.0 or depth > 26.0 or rng.randf() < 0.12: continue
			if not _reserve(p, 4.0): continue
			match map.region_id:
				"mine": _mine_group(p)
				"city": _city_group(p)
				"snow": _snow_group(p)
	# Put a recognizable work/rest site beyond each reward pocket, with space
	# reserved around the device, cache and guard stations inside the pocket.
	for chamber in map.branch_centres:
		var center := Vector2(chamber.x, chamber.y)
		for attempt in range(12):
			var p: Vector2 = center + Vector2.from_angle(TAU * attempt / 12.0) * (chamber.z + 4.8)
			if not _reserve(p, 3.0): continue
			_patch(p, Vector2(3.4, 2.5), _stain_color())
			match map.region_id:
				"mine":
					_prop(p, 2, 3.8, true)
				"city":
					_prop(p, 2, 4.0, true)
				"snow":
					_prop(p, 2, 4.5, true)
					_prop(p + Vector2(2.8, 0.7), 1, 3.3)
			break
	# Existing collision pillars become rock/concrete cover, not empty circles.
	for pillar in map._closed_circles:
		var p := Vector2(pillar.x, pillar.y)
		_rock(p, Vector3(2.7, 1.5, 2.6), Color("8d969f") if map.region_id == "city" else Color("8e887d"))
	_finish_meshes()
	root.set_meta("composition_count", occupied.size())

func _dress_corridors() -> void:
	# Compose the camera-facing road edges first. A world-space grid alone
	# leaves long stretches of playable camera empty even with many props.
	for segment in map._main_segments:
		var a := Vector2(segment[0], segment[1])
		var b := Vector2(segment[2], segment[3])
		var across := (b - a).normalized().orthogonal()
		var samples := maxi(1, ceili(a.distance_to(b) / 14.0))
		for i in range(samples):
			var along := a.lerp(b, (float(i) + 0.5) / samples)
			for side in [-1.0, 1.0]:
				if rng.randf() < 0.12: continue
				for extra in [4.5, 6.0, 8.0, 10.0, 12.0]:
					var p: Vector2 = along + across * side * (segment[4] + extra)
					if not _reserve(p, 4.0): continue
					match map.region_id:
						"mine": _mine_group(p)
						"city": _city_group(p)
						"snow": _snow_group(p)
					break

func _reserve(p: Vector2, radius: float) -> bool:
	if map._surface.distance_at(p) > -(radius + 0.8): return false
	for place in occupied:
		if p.distance_to(Vector2(place.x, place.y)) < radius + place.z + 1.0: return false
	occupied.append(Vector3(p.x, p.y, radius))
	return true

func _dress_edges() -> void:
	# Small embedded forms bridge the gap between the bare curb and the larger
	# scene groups; sizes and orientations follow local terrain, not tile rows.
	for z in range(int(map.SPINE_MIN.y), int(map.SPINE_MAX.y), 5):
		for x in range(int(map.SPINE_MIN.x), int(map.SPINE_MAX.x), 5):
			var p := Vector2(x, z) + Vector2(rng.randf_range(-1.7, 1.7), rng.randf_range(-1.7, 1.7))
			var depth: float = -map._surface.distance_at(p)
			if depth < 1.9 or depth > 3.6 or rng.randf() < 0.22: continue
			if not _reserve(p, 0.8): continue
			_patch(p, Vector2(1.6, 1.2), _stain_color())
			match map.region_id:
				"mine": _rock(p, Vector3(2.5, rng.randf_range(0.8, 1.6), 2.1), Color("a39d94"))
				"city":
					_prop(p, 0, 2.6, true)
				"snow": _prop(p, 2, rng.randf_range(1.4, 2.3))

func _height(p: Vector2) -> float:
	return map._surface.height_at(p)

func _prop(p: Vector2, kind: int, height: float, composition: bool = false) -> void:
	var depth: float = -map._surface.distance_at(p)
	if depth < 1.7: return
	# On the near bank, tall sprites project over the road. Shorten those
	# silhouettes, and keep the full-sized trees/buildings on the far bank.
	var toward_road := Vector2(map._surface.distance_at(p + Vector2(0.3, 0)) - map._surface.distance_at(p - Vector2(0.3, 0)), map._surface.distance_at(p + Vector2(0, 0.3)) - map._surface.distance_at(p - Vector2(0, 0.3))).normalized()
	if toward_road.y > 0.25:
		var limit := maxf(1.4, (depth - 1.0) * 1.05)
		if height > limit and map.region_id == "city" and kind == (1 if composition else 0):
			if not composition: return
			kind = 0
			height = minf(limit, 3.6)
		if height > limit and map.region_id == "mine" and kind == 1:
			if not composition: return
			kind = 0
		if height > limit and map.region_id == "snow" and ((composition and kind == 0) or (not composition and kind in [0, 1])):
			kind = 1 if composition else 2
			height = minf(limit, 2.0)
		else: height = minf(height, limit)
	var anchor := Vector3(p.x, _height(p) + 0.035, p.y)
	var sprite := FieldArt.scene_prop(root, map.region_id, kind, anchor, height, rng.randf() < 0.5) if composition else FieldArt.prop(root, map.region_id, kind, anchor, height, rng.randf() < 0.5)
	sprite.modulate = Color("bdc3ce") if map.region_id == "snow" else Color("b6b8bb")
	sprite.set_meta("ground_anchor", anchor)
	sprite.set_meta("scene_role", kind + (10 if composition else 0))
	_patch(p, Vector2(height * 0.34, height * 0.19), Color(0.06, 0.075, 0.085, 0.33))

func _mine_group(p: Vector2) -> void:
	_patch(p, Vector2(4.5, 3.6), _stain_color())
	_prop(p, 0 if rng.randf() < 0.6 else 1, rng.randf_range(5.0, 6.8), true)
	_rock(p + Vector2(-2.2, -0.9), Vector3(1.2, 0.5, 1.0), Color("a09582"))
	_scatter(p, false)

func _city_group(p: Vector2) -> void:
	_patch(p, Vector2(5.2, 4.0), _stain_color())
	# The facade, exposed walls and foundation are one authored composition.
	_prop(p, 1 if rng.randf() < 0.7 else 0, rng.randf_range(5.4, 7.4), true)
	_prop(p + Vector2(2.4, -1.1), 3, 1.3)
	_scatter(p, true)

func _snow_group(p: Vector2) -> void:
	_patch(p, Vector2(4.3, 3.3), _stain_color())
	_prop(p, 0, rng.randf_range(5.5, 7.4), true)
	_prop(p + Vector2(2.0, 1.5), 0, rng.randf_range(3.8, 5.0))
	_prop(p + Vector2(-2.1, -1.8), 1, rng.randf_range(1.8, 2.8), true)
	if rng.randf() < 0.4: _rock(p + Vector2(2.7, -0.3), Vector3(1.8, 0.65, 1.7), Color("b7c8da"))

func _scatter(p: Vector2, concrete: bool) -> void:
	for i in range(7):
		var q := p + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(2.0, 4.6)
		if map._surface.distance_at(q) > -0.8: continue
		var size := rng.randf_range(0.25, 0.75)
		if concrete: _block(q, Vector3(size * 1.4, size * 0.45, size), Color("91939a"))
		else: _rock(q, Vector3(size, size * 0.6, size * 0.8), Color("969087"))

func _stain_color() -> Color:
	match map.region_id:
		"city": return Color(0.12, 0.15, 0.18, 0.40)
		"snow": return Color(0.13, 0.19, 0.21, 0.27)
		_: return Color(0.12, 0.095, 0.065, 0.38)

func _patch(p: Vector2, radius: Vector2, color: Color) -> void:
	for i in range(12):
		var a := p + Vector2.from_angle(TAU * i / 12.0) * radius
		var b := p + Vector2.from_angle(TAU * (i + 1) / 12.0) * radius
		for item in [[p, color], [a, Color(color, 0.0)], [b, Color(color, 0.0)]]:
			var q: Vector2 = item[0]
			stains.set_color(item[1])
			stains.set_normal(Vector3.UP)
			stains.add_vertex(Vector3(q.x, _height(q) + 0.045, q.y))
		stain_count += 1

func _rock(p: Vector2, size: Vector3, color: Color) -> void:
	var center := Vector3(p.x, _height(p) - 0.12, p.y)
	var lower: Array[Vector3] = []
	var upper: Array[Vector3] = []
	for i in range(7):
		var dir := Vector2.from_angle(TAU * i / 7.0) * rng.randf_range(0.80, 1.12)
		var foot := center + Vector3(dir.x * size.x * 0.5, 0, dir.y * size.z * 0.5)
		foot.y = _height(Vector2(foot.x, foot.z)) - 0.15
		lower.append(foot)
		upper.append(center + Vector3(dir.x * size.x * 0.32, size.y * rng.randf_range(0.65, 0.95), dir.y * size.z * 0.32))
	var peak := center + Vector3(size.x * 0.06, size.y, -size.z * 0.08)
	for i in range(7):
		var j := (i + 1) % 7
		_triangle(lower[i], lower[j], upper[j], color * 0.85)
		_triangle(lower[i], upper[j], upper[i], color)
		_triangle(upper[i], upper[j], peak, color * 1.08)

func _block(p: Vector2, size: Vector3, color: Color, angle: float = 0.0) -> void:
	var base := _height(p) - 0.1
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		base = minf(base, _height(p + (corner * Vector2(size.x, size.z) * 0.5).rotated(angle)) - 0.1)
	var points: Array[Vector3] = []
	for y in [0.0, size.y]:
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var q: Vector2 = p + (corner * Vector2(size.x, size.z) * 0.5).rotated(angle)
			points.append(Vector3(q.x, base + y, q.y))
	for quad in [[4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]:
		_triangle(points[quad[0]], points[quad[1]], points[quad[2]], color)
		_triangle(points[quad[0]], points[quad[2]], points[quad[3]], color)

func _triangle(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var normal := (c - a).cross(b - a).normalized()
	var lighting := 0.60 + absf(normal.dot(Vector3(-0.35, 0.85, -0.4).normalized())) * 0.40
	for vertex in [a, b, c]:
		solids.set_normal(normal)
		solids.set_color(Color(color.r * lighting, color.g * lighting, color.b * lighting))
		solids.add_vertex(vertex)
	triangle_count += 1

func _finish_meshes() -> void:
	if triangle_count > 0:
		var mesh := MeshInstance3D.new()
		mesh.name = "RegionalStructures"
		mesh.mesh = solids.commit()
		var material := FieldArt.background_material(map.region_id)
		material.set_shader_parameter("brightness", 1.5 if map.region_id != "snow" else 1.0)
		material.set_shader_parameter("world_scale", 7.0)
		mesh.material_override = material
		root.add_child(mesh)
	if stain_count > 0:
		var mesh := MeshInstance3D.new()
		mesh.name = "GroundContact"
		mesh.mesh = stains.commit()
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo = true
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.material_override = material
		root.add_child(mesh)
