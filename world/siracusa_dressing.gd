class_name SiracusaDressing
extends CityDressing

## 叙拉古 · 沃尔西尼旧城区 (叙拉古地图调研与方案_v1.md §2.1, §3). The houses are
## the Blender kit's (S3, art/kit/siracusa_*.glb: terracotta roofs, lime
## render, shutters), and so are the theatre and court fronts, fountains,
## wall lanterns, family banners, wine barrels and the
## mansion gateways.
##
## Besides its houses it differs from Lungmen in how it is put together (用户
## 2026-10-16: 风格不同，一眼就能看出): fronts follow the crooked lanes at any
## angle, shoulder to shoulder; two to four storeys and no towers; wall
## lanterns rather than lamp posts; a fountain in each piazza; the families'
## banners where their turfs meet; a theatre and a court facing the camera
## across their squares; the mansions walled round their courts. Lungmen's
## street furniture (crossings, traffic lights, cables, cranes, roof huts,
## side streets) is not laid here.

## The families' houses (tools/blender/kit/build_siracusa_kit.py, S3): lime
## render, terracotta roofs, shutters; the Bellone, whose house fell
## (泰拉大典:叙拉古: 在争夺沃尔西尼时覆灭), keep the ruins. Fronts: the run's
## pieces in turn, tallest first; the one-storey house where the camera's
## sight allows nothing taller (the south side of a lane).
const FAMILY_FRONTAGE := {
	"saluzzo": ["siracusa_house_d", "siracusa_house_a", "siracusa_house_c", "siracusa_house_b", "siracusa_house_low"],
	"rossetti": ["siracusa_house_c", "siracusa_house_b", "siracusa_house_a", "siracusa_house_d", "siracusa_house_low"],
	"bellone": ["siracusa_ruin", "siracusa_house_a", "siracusa_house_b", "siracusa_ruin", "siracusa_house_low"],
}
const FAMILY_FILL := {
	"saluzzo": ["siracusa_house_d", "siracusa_house_c", "siracusa_house_a", "siracusa_house_b", "siracusa_house_low"],
	"rossetti": ["siracusa_house_c", "siracusa_house_a", "siracusa_house_d", "siracusa_house_b", "siracusa_house_low"],
	"bellone": ["siracusa_ruin", "siracusa_house_a", "siracusa_house_low", "siracusa_house_b"],
}
## The fill tries each piece at these sizes: the blocks between crooked lanes
## are odd shapes, and an old town's houses come small.
const FILL_SCALES := [1.0, 0.8, 0.62]
## Where each house hides the ground behind it: its eaves and the lower part
## of its roof (the ridge is narrow).
const HOUSE_SIGHT := {
	"siracusa_house_a": 7.6, "siracusa_house_b": 10.6, "siracusa_house_c": 7.9, "siracusa_house_d": 10.6,
	"siracusa_house_low": 4.2, "siracusa_ruin": 7.6,
}
## Warm plaster under the night (§2.1.4: 暖为主): cream and terracotta for
## the Saluzzo, sand and ochre for the Rossetti, the Bellone's faded grey.
const FAMILY_TINTS := {
	"saluzzo": [Color(1.3, 1.02, 0.82), Color(1.24, 0.92, 0.76), Color(1.34, 1.14, 0.92)],
	"rossetti": [Color(1.28, 1.14, 0.84), Color(1.2, 1.06, 0.8), Color(1.34, 1.22, 0.96)],
	"bellone": [Color(1.02, 0.96, 0.86), Color(0.94, 0.9, 0.84), Color(1.08, 0.98, 0.86)],
}
## The paving per turf (TerrainSurface reads it; FieldArt divides by 0.3):
## a tint over the paving texture (0.3 is neutral), a little warmer or
## colder by family.
const STONE_TINTS := {
	"saluzzo": Color(0.31, 0.3, 0.29), "rossetti": Color(0.32, 0.31, 0.29), "bellone": Color(0.28, 0.28, 0.28),
}
## Each family's banner colour: Saluzzo wine, Rossetti deep blue, the
## Bellone's faded ochre.
const BANNER_COLOURS := {
	"saluzzo": Color(0.46, 0.1, 0.14), "rossetti": Color(0.12, 0.2, 0.4), "bellone": Color(0.52, 0.42, 0.2),
}
## A front run follows a kerb at any angle, in steps of this.
const FRONT_STEP := deg_to_rad(6.0)
## Wall lanterns (§2.1.2: 铸铁灯柱、墙上挂的壁灯): warm white-gold, small pools.
const LANTERN := "res://art/kit/siracusa_lantern.glb"
const LANTERN_GAP := 9.0
const LANTERN_HEIGHT := 3.2
const LANTERN_LIGHT := Color(1.0, 0.84, 0.58) * 0.85

var banner_count := 0
var fountain_count := 0
var lantern_count := 0
var landmark_kinds: Array[String] = []
var mansion_gates := 0
## Where each gateway stands (the captures).
var gate_points: Array[Vector2] = []

func build(world: Node3D, parent: Node3D) -> void:
	map = world
	rng.seed = map.seed_value ^ 0x51ac
	root = Node3D.new()
	root.name = "SiracusaDressing"
	parent.add_child(root)
	_place_landmark_fronts()
	_place_mansion_gates()
	map.mark("  siracusa: landmarks + mansions")
	_place_frontage()
	map.mark("  siracusa: lane fronts")
	_place_buildings()
	map.mark("  siracusa: block fill")
	_place_barricades()
	_place_roadblock()
	_place_fountains()
	_place_banners()
	_place_lanterns()
	map.mark("  siracusa: barricades, fountains, banners, lanterns")
	for path in transforms:
		_add_set(String(path).get_file().get_basename(), TerraceDressing.kit_mesh(load(path)), transforms[path])
	map.mark("  siracusa: multimeshes")

# --- Hooks into CityDressing --------------------------------------------------------

func _palette(kind: String) -> Array:
	return FAMILY_TINTS.get(kind, FAMILY_TINTS.saluzzo)

func _sight_height(name: String, box: AABB) -> float:
	return float(HOUSE_SIGHT.get(name, box.size.y))

func _frontage_pieces(kind: String) -> Array:
	return FAMILY_FRONTAGE.get(kind, FAMILY_FRONTAGE.saluzzo)

## Any direction: the lanes are not square to anything.
func _front_axis(normal: Vector2) -> Vector2:
	var axis := Vector2.from_angle(snappedf(normal.angle(), FRONT_STEP))
	return axis if normal.dot(axis) > 0.97 else Vector2.ZERO

func _axis_key(axis: Vector2) -> Vector2:
	return Vector2(roundf(axis.angle() / FRONT_STEP), 0.0)

func _axis_of_key(key: Vector2) -> Vector2:
	return Vector2.from_angle(key.x * FRONT_STEP)

## Fronts laid along a lane that is not square to the axes (the tests read it).
var angled_fronts := 0

func _front_piece(name: String, base: Vector2, along: Vector2, axis: Vector2, u: float, end: float) -> float:
	var width := super._front_piece(name, base, along, axis, u, end)
	if width > 0.0 and absf(axis.x) < 0.98 and absf(axis.y) < 0.98: angled_fronts += 1
	return width

## Barricades are the families' own: wine barrels stacked across the lane
## (萨卢佐葡萄酒) — drawn as built shapes, the collider is CityDressing's.
func _barricade_piece(_piece: int) -> String:
	return ""

func _add(name: String, placed: Transform3D) -> void:
	if name.is_empty():
		_barrels(Vector2(placed.origin.x, placed.origin.z), placed.origin.y)
		return
	super._add(name, placed)

func _place_buildings() -> void:
	var lo: Vector2 = map.SPINE_MIN - Vector2(24, 24)
	var hi: Vector2 = map.SPINE_MAX + Vector2(24, 24)
	var step := 5.0
	var z := lo.y
	while z < hi.y:
		var x := lo.x
		while x < hi.x:
			var p := Vector2(x + rng.randf_range(-0.6, 0.6), z + rng.randf_range(-0.6, 0.6))
			x += step
			if -map._surface.distance_near(p) < 1.5: continue
			if _taken(Rect2(p - Vector2(1.0, 1.0), Vector2(2.0, 2.0))): continue
			_try_fill(p, FAMILY_FILL.get(map.district_at(p), FAMILY_FILL.saluzzo))
		z += step

## One house of the fill at `p`, the first piece and size that fits, its front
## to the nearest lane and low enough for the camera to see the lane behind.
func _try_fill(p: Vector2, pieces: Array) -> void:
	var facing := _facing(p)
	var north := _open_north(p, 20.0)
	var yaw := Basis(Vector3.UP, atan2(facing.x, facing.y))
	for scale in FILL_SCALES:
		for name in pieces:
			var box := _bounds_of(name)
			var half := Vector2(box.size.x, box.size.z) * 0.5 * float(scale)
			if absf(facing.x) > 0.5: half = Vector2(half.y, half.x)
			var rect := Rect2(p - half, half * 2.0)
			if not _clear(rect): continue
			var height: float = float(HOUSE_SIGHT.get(name, box.size.y)) * float(scale)
			if height * SIGHT > north - half.y: continue
			_occupy(rect.grow(0.3))
			# The model's footprint centred on `p`, whatever its own origin.
			var centre: Vector3 = yaw * (Vector3(box.position.x + box.size.x * 0.5, 0.0, box.position.z + box.size.z * 0.5) * float(scale))
			var base: float = map._surface.top_at(p) - 0.25
			_add(name, Transform3D(yaw.scaled(Vector3.ONE * float(scale)), Vector3(p.x - centre.x, base, p.y - centre.z)))
			building_count += 1
			return

# --- Landmarks and mansions ---------------------------------------------------------

## The theatre (米兰剧场) and the court (沃尔西尼法庭) stand on the north side
## of their squares, facing the camera across them (§3.2): the Blender fronts
## (art/kit/siracusa_theatre/court.glb), scaled to the square, their body on
## the rock behind the square's north wall and their portico and steps out
## into the square, low enough that the camera still sees the road behind.
## Built before the fronts, which keep off them.
const LANDMARK_MODELS := {"theatre": "siracusa_theatre", "court": "siracusa_court"}
## The model's front face lies this far in front of its origin (Blender −Y).
const LANDMARK_FACE := 3.5

func _place_landmark_fronts() -> void:
	for l in map.landmarks:
		var room: int = int(l.room)
		var circle: Vector3 = map._open_circles[room]
		var centre := Vector2(circle.x, circle.y)
		# The square's north wall (ContinuousWorldMap._square_distance: open to
		# 0.75 r + 1 from the centre).
		var edge := centre.y + circle.z * 0.75 + 0.9
		var name: String = LANDMARK_MODELS[str(l.kind)]
		var box := _bounds_of(name)
		var behind := LANDMARK_FACE - box.position.z
		var ahead := box.end.z - LANDMARK_FACE
		var scale := clampf(circle.z * 1.6 / box.size.x, 0.7, 1.25)
		# Lower it until the camera sees over it to the road behind.
		var placed := false
		while scale >= 0.6:
			var half := box.size.x * 0.5 * scale
			var rect := Rect2(Vector2(centre.x - half, edge + 0.3), Vector2(half * 2.0, behind * scale))
			var north := 99.0
			for f in [0.1, 0.5, 0.9]:
				north = minf(north, _open_north(Vector2(lerpf(rect.position.x, rect.end.x, f), rect.end.y + 0.05), 24.0))
			if box.size.y * scale * SIGHT > north + behind * scale:
				scale -= 0.1
				continue
			# The body stands on rock only; its steps on nothing she must reach.
			var on_rock := true
			for fx in [0.05, 0.5, 0.95]:
				for fz in [0.35, 0.95]:
					if map._surface.distance_near(rect.position + rect.size * Vector2(fx, fz)) > -0.2: on_rock = false
			var steps := Rect2(Vector2(centre.x - half, edge + 0.3 - ahead * scale), Vector2(half * 2.0, ahead * scale))
			if not on_rock or _marker_in(steps.grow(1.5)): break
			_occupy(rect)
			var base: float = map.ground_height(Vector2(centre.x, edge - 1.0))
			var origin := Vector3(centre.x, base - 0.02, edge + 0.3 + LANDMARK_FACE * scale)
			_add(name, Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * scale), origin))
			_collider(steps.get_center(), Vector2.RIGHT, Vector3(steps.size.x, 1.2, steps.size.y))
			# The lamps before its doors; the theatre's the brightest on the floor.
			var glow := 1.0 if l.kind == "theatre" else 0.75
			for side in [-1.0, 1.0]:
				lamps.append({"at": Vector3(centre.x + side * half * 0.35, base + 2.6, edge + 0.3 - 1.0 * scale), "color": LANTERN_LIGHT * glow, "radius": 6.0})
			placed = true
			break
		if not placed: continue
		landmark_kinds.append(str(l.kind))
		landmark_count += 1
		landmark_points.append(centre)

## A mansion's court is walled round by its houses (the fronts do that); its
## one way in gets the family's gateway: stone piers, a crested lintel over
## the lane, the iron gate swung open into the court.
const GATE_PIER := 3.5
func _place_mansion_gates() -> void:
	for room in map.mansion_rooms:
		for index in range(map._links.size()):
			var link: Dictionary = map._links[index]
			if not link.alive or (int(link.a) != room and int(link.b) != room): continue
			var line: PackedVector2Array = map._link_points(index)
			var centre: Vector2 = map._centre(room)
			# The point where the lane meets the court's wall, coming in.
			var from: Vector2 = line[1] if line[1].distance_to(centre) > 2.0 else line[0 if int(link.b) == room else 2]
			var heading := (centre - from).normalized()
			var half: float = float(link.width) + 0.5
			# Out from the court along the lane, the first place with wall on
			# both sides of the way (a lane that opens straight off a square
			# has none, and gets no gateway).
			var across := heading.orthogonal()
			var at: Vector2 = centre - heading * float(map._open_circles[room].z) * 0.7
			var found := false
			for t in range(40):
				if map._surface.distance_near(at) > 1.0 and map._surface.distance_near(at + across * (half + 0.7)) < -0.1 and map._surface.distance_near(at - across * (half + 0.7)) < -0.1:
					found = true
					break
				at -= heading * 0.4
			if not found: break
			var ground: float = map.ground_height(at)
			# art/kit/siracusa_mansion_gate.glb: its piers 3.5 m either side of
			# its middle, stretched to the lane; the lane side (+Z) outwards.
			var turn := Basis(Vector3.UP, atan2(-heading.x, -heading.y)) * Basis.from_scale(Vector3(half / GATE_PIER, 1.0, 1.0))
			_add("siracusa_mansion_gate", Transform3D(turn, Vector3(at.x, ground - 0.02, at.y)))
			gate_points.append(at)
			lamps.append({"at": Vector3(at.x, ground + 3.0, at.y) + Vector3(heading.x, 0, heading.y) * -0.8, "color": LANTERN_LIGHT, "radius": 5.0})
			mansion_gates += 1
			break

## Whether a device, a destination or a point of interest lies within `reach`
## of `p` (placed before the dressing; nothing that collides may cover one).
func _near_marker(p: Vector2, reach: float) -> bool:
	var points: Array = [map.buff_position, map.encounter_position, map.route_guard_position, map.vault_position]
	if is_instance_valid(map.exit_node): points.append(map.exit_node.position)
	for node in map.route_nodes: points.append(node.position)
	points.append_array(map.cache_positions)
	for at in points:
		if Vector2((at as Vector3).x, (at as Vector3).z).distance_to(p) < reach: return true
	return false

func _marker_in(rect: Rect2) -> bool:
	var points: Array = [map.buff_position, map.encounter_position, map.route_guard_position, map.vault_position]
	if is_instance_valid(map.exit_node): points.append(map.exit_node.position)
	for node in map.route_nodes: points.append(node.position)
	points.append_array(map.cache_positions)
	for at in points:
		if rect.has_point(Vector2((at as Vector3).x, (at as Vector3).z)): return true
	return false

# --- Piazzas, banners, barrels ------------------------------------------------------

## A fountain at the heart of each piazza big enough to walk round it (§3.2):
## art/kit/siracusa_fountain.glb. It stops her and her shots.
func _place_fountains() -> void:
	for i in range(map._open_circles.size()):
		var room: Vector3 = map._open_circles[i]
		if room.z < 7.0 or map.is_mansion(i) or not map.landmark_of(i).is_empty() or i == 0: continue
		var centre := Vector2(room.x, room.y)
		if not map._has_clearance(centre) or not map._has_clearance(centre + Vector2(2.2, 0)) or not map._has_clearance(centre - Vector2(2.2, 0)): continue
		if _near_marker(centre, 4.0): continue
		var ground: float = map.ground_height(centre)
		_add("siracusa_fountain", Transform3D(Basis(Vector3.UP, rng.randi_range(0, 7) * PI * 0.25), Vector3(centre.x, ground - 0.02, centre.y)))
		_collider(centre, Vector2.RIGHT, Vector3(3.2, 0.9, 3.2))
		fountain_count += 1

## Where one family's turf meets another's on her lane, a banner of each on
## either wall (§3.1: 家族旗帜): a pole out of the wall, its cloth hanging.
func _place_banners() -> void:
	if map.districts.size() < 2: return
	var placed: Array[Vector2] = []
	for index in range(map._links.size()):
		var link: Dictionary = map._links[index]
		if not link.alive: continue
		var line: PackedVector2Array = map._link_points(index)
		for k in range(line.size() - 1):
			var a := line[k]
			var b := line[k + 1]
			var length := a.distance_to(b)
			var t := 0.0
			var before: String = map.district_at(a)
			while t < length:
				t += 1.5
				var p := a.lerp(b, minf(t, length) / length)
				var here: String = map.district_at(p)
				if here == before: continue
				if not _near_any(placed, p, 10.0):
					placed.append(p)
					var across := (b - a).normalized().orthogonal()
					_banner(p, across, before, -1.0)
					_banner(p, across, here, 1.0)
				before = here

func _banner(p: Vector2, across: Vector2, family: String, side: float) -> void:
	var step := 0.0
	while step < 7.0 and map._surface.distance_near(p + across * side * step) > 0.0: step += 0.25
	if step >= 7.0: return
	var wall := p + across * side * (step - 0.1)
	var ground: float = map.ground_height(wall - across * side * 0.5)
	var out := -across * side
	# art/kit/siracusa_banner_<family>.glb: its pole out of the wall (+Z).
	var family_name: String = family if BANNER_COLOURS.has(family) else "saluzzo"
	_add("siracusa_banner_" + family_name, Transform3D(Basis(Vector3.UP, atan2(out.x, out.y)), Vector3(wall.x, ground, wall.y)))
	banner_count += 1

## The car's lane mouth (叙拉古敌人设计案 §三第 7.1 节, constraint 4): barrels
## across the lane from the car's flanks to the walls, colliding; the car
## itself (GameManager._spawn_car) fills the gap between them.
const ROADBLOCK_GAP := 1.1
var roadblock_barrels := 0

func _place_roadblock() -> void:
	if map.roadblock.is_empty(): return
	var at: Vector2 = map.roadblock.at
	var across: Vector2 = (map.roadblock.along as Vector2).orthogonal()
	for side in [-1.0, 1.0]:
		var s := ROADBLOCK_GAP + 0.5
		while s < float(map.roadblock.half) + 1.5:
			var p: Vector2 = at + across * side * s
			if map._surface.distance_near(p) > -0.3:
				super._add("siracusa_barrels", Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)), Vector3(p.x, map.ground_height(p), p.y)))
				_collider(p, across, Vector3(1.0, 1.2, 1.0))
				roadblock_barrels += 1
			s += 0.9

## A stack of wine barrels (art/kit/siracusa_barrels.glb) where a
## barricade piece would go.
func _barrels(p: Vector2, ground: float) -> void:
	super._add("siracusa_barrels", Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)), Vector3(p.x, ground, p.y)))

## Lanterns on the house fronts along her lanes, every LANTERN_GAP or so, each
## with a small warm pool (§2.1.2). Only on a wall that has a house to it.
func _place_lanterns() -> void:
	var placed: Array[Vector2] = []
	var mesh_points: Array[Transform3D] = []
	for edge in map._surface.contour_edges:
		var a := Vector2(edge[0], edge[1])
		var b := Vector2(edge[2], edge[3])
		var m := (a + b) * 0.5
		var tangent := b - a
		if tangent.length() < 0.05: continue
		var normal := Vector2(-tangent.y, tangent.x).normalized()
		if map._surface.distance_near(m + normal * 0.8) < map._surface.distance_near(m - normal * 0.8): normal = -normal
		if not _covered(m - normal * 1.2) or _near_any(placed, m, LANTERN_GAP): continue
		placed.append(m)
		var at := m - normal * 0.15
		var ground: float = map.ground_height(m + normal * 0.6)
		mesh_points.append(Transform3D(Basis(Vector3.UP, atan2(normal.x, normal.y)), Vector3(at.x, ground + LANTERN_HEIGHT, at.y)))
		var pool := m + normal * 1.0
		lamps.append({"at": Vector3(pool.x, ground + 2.2, pool.y), "color": LANTERN_LIGHT, "radius": 5.5})
		lantern_count += 1
	if not mesh_points.is_empty():
		var path := LANTERN
		if not transforms.has(path): transforms[path] = [] as Array[Transform3D]
		(transforms[path] as Array[Transform3D]).append_array(mesh_points)
