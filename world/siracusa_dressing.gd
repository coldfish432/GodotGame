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
## 改造案 v1.1 §2: nearer neutral, so the faded roofs stay faded and the
## sandstone stays sand.
const FAMILY_TINTS := {
	"saluzzo": [Color(1.14, 1.02, 0.92), Color(1.1, 0.98, 0.9), Color(1.16, 1.08, 0.98)],
	"rossetti": [Color(1.12, 1.06, 0.92), Color(1.08, 1.02, 0.9), Color(1.16, 1.1, 1.0)],
	"bellone": [Color(1.0, 0.96, 0.9), Color(0.94, 0.92, 0.88), Color(1.04, 0.98, 0.9)],
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
	look_rng.seed = map.seed_value ^ 0x10e7
	root = Node3D.new()
	root.name = "SiracusaDressing"
	parent.add_child(root)
	_place_landmark_fronts()
	_place_mansion_gates()
	_place_bell_tower()
	map.mark("  siracusa: landmarks + mansions + bell tower")
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
	_place_arch_houses()
	_place_lines()
	map.mark("  siracusa: arches, string lights, laundry")
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

func _add(name: String, placed: Transform3D, _barricade := false) -> void:
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

# --- Dusk dressing (龙门城区与叙拉古地图改造案 v1.1 §2) ----------------------------
# The plan stays as it was: the bell tower and the arched houses take slots the
# landmarks, gateways and houses already use, and everything here draws on
# look_rng, so what collides is placed as before.

## 钟楼: one a floor, a square tower with an arched belfry, the tallest piece
## on the floor (art/kit/siracusa_bell_tower.glb), on the rock behind a
## piazza's north edge, facing the camera across it. Placed before the house
## fronts, which keep off it; well away from the way down so it does not point
## there. Where the camera's sight over it cannot be had it is still placed,
## at the spot that hides least: a landmark may hide her (改造案 §3).
const BELL_TOWER := "siracusa_bell_tower"
const BELL_TOWER_CLEAR := 35.0
const BELL_LIGHT := Color(1.0, 0.78, 0.5) * 0.8
var bell_tower_count := 0
var bell_tower_point := Vector2.INF

func _place_bell_tower() -> void:
	var exit := Vector2.INF
	if is_instance_valid(map.exit_node): exit = Vector2(map.exit_node.position.x, map.exit_node.position.z)
	var rooms: Array[int] = []
	for i in range(1, map._open_circles.size()):
		var room: Vector3 = map._open_circles[i]
		if room.z < 6.0 or map.is_mansion(i) or not map.landmark_of(i).is_empty(): continue
		if exit != Vector2.INF and Vector2(room.x, room.y).distance_to(exit) < BELL_TOWER_CLEAR: continue
		rooms.append(i)
	for i in range(rooms.size() - 1, 0, -1):
		var j := look_rng.randi_range(0, i)
		var swap := rooms[i]
		rooms[i] = rooms[j]
		rooms[j] = swap
	var box := _bounds_of(BELL_TOWER)
	var half := box.size.x * 0.5
	var best := {}
	for room_index in rooms:
		var room: Vector3 = map._open_circles[room_index]
		var centre := Vector2(room.x, room.y)
		for fx in [-0.55, 0.55, -0.25, 0.25]:
			# North from the piazza to its edge, then the tower behind it.
			var p := centre + Vector2(room.z * fx, 0.0)
			var t := 0.0
			while t < room.z * 1.6 and map._surface.distance_near(p + Vector2(0, t)) >= -0.3: t += 0.25
			if t >= room.z * 1.6: continue
			var rect := Rect2(Vector2(p.x - half, p.y + t + 0.3), Vector2(half * 2.0, box.size.z))
			if _taken(rect.grow(0.4)) or _marker_in(rect.grow(1.0)): continue
			var on_rock := true
			for c in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y), rect.get_center()]:
				if map._surface.distance_near(c) > -0.2: on_rock = false
			if not on_rock: continue
			var north := 99.0
			for f in [0.1, 0.5, 0.9]:
				north = minf(north, _open_north(Vector2(lerpf(rect.position.x, rect.end.x, f), rect.end.y + 0.05), 30.0))
			var hidden := box.size.y * SIGHT - north
			if best.is_empty() or hidden < float(best.hidden): best = {"rect": rect, "hidden": hidden}
			if hidden <= 0.0: break
		if not best.is_empty() and float(best.hidden) <= 0.0: break
	if best.is_empty(): return
	var rect: Rect2 = best.rect
	_occupy(rect)
	var at := rect.get_center()
	var base: float = map._surface.top_at(at) - 0.25
	for c in [rect.position, rect.end]: base = minf(base, map._surface.top_at(c) - 0.25)
	# The model's footprint centred on `at`, its front (+Z) turned south.
	var yaw := Basis(Vector3.UP, PI)
	var centre: Vector3 = yaw * Vector3(box.position.x + box.size.x * 0.5, 0.0, box.position.z + box.size.z * 0.5)
	_add(BELL_TOWER, Transform3D(yaw, Vector3(at.x - centre.x, base, at.y - centre.z)))
	# Its belfry lit, and a lantern at its door.
	lamps.append({"at": Vector3(at.x, base + box.size.y * 0.78, rect.position.y - 0.6), "color": BELL_LIGHT, "radius": 7.0})
	lamps.append({"at": Vector3(at.x, map.ground_height(Vector2(at.x, rect.position.y - 1.0)) + 2.6, rect.position.y - 1.2), "color": LANTERN_LIGHT, "radius": 5.0})
	bell_tower_point = at
	bell_tower_count += 1
	landmark_count += 1
	landmark_points.append(at)

## 拱门过街楼: a house built over her lane, the lane through a stone arch under
## it with a wall lamp inside (art/kit/siracusa_arch_house.glb, its arch
## ARCH_OPENING wide along x, stretched to the lane). 1–2 a floor, where the
## lane runs between houses on both sides; not by a gateway, a marker or the
## way down. The arch is no longer than the houses beside it.
const ARCH_HOUSE := "siracusa_arch_house"
const ARCH_OPENING := 6.0
const ARCH_COUNT := Vector2i(1, 2)
const ARCH_REACH := 5.0
var arch_count := 0
var arch_points: Array[Vector2] = []

func _place_arch_houses() -> void:
	var exit := Vector2.INF
	if is_instance_valid(map.exit_node): exit = Vector2(map.exit_node.position.x, map.exit_node.position.z)
	var found: Array[Dictionary] = []
	var loose: Array[Dictionary] = []
	for index in range(map._links.size()):
		var link: Dictionary = map._links[index]
		if not link.alive: continue
		var line: PackedVector2Array = map._link_points(index)
		for k in range(line.size() - 1):
			var a := line[k]
			var b := line[k + 1]
			var length := a.distance_to(b)
			if length < 6.0: continue
			var heading := (b - a) / length
			var across := heading.orthogonal()
			for f in [0.25, 0.4, 0.55, 0.7]:
				var mid := a.lerp(b, f)
				if map._surface.distance_near(mid) < 1.0: continue
				if _near_marker(mid, 7.0) or _near_any(gate_points, mid, 10.0) or _near_any(landmark_points, mid, 12.0): continue
				if exit != Vector2.INF and mid.distance_to(exit) < 25.0: continue
				if mid.distance_to(Vector2(ContinuousWorldMap.ENTRY_POSITION.x, ContinuousWorldMap.ENTRY_POSITION.z)) < 20.0: continue
				# Houses either side of it first; failing those, any walls.
				var walls := _walls_across(mid, across, ARCH_REACH, heading, 0.8)
				var into := found
				if walls.is_empty():
					walls = _walls_across(mid, across, ARCH_REACH, heading, 0.0, false)
					into = loose
				if walls.is_empty(): continue
				into.append({"at": mid + across * (walls[1] - walls[0]) * 0.5, "across": across, "heading": heading, "span": walls[0] + walls[1]})
	_shuffle_with(found, look_rng)
	_shuffle_with(loose, look_rng)
	found.append_array(loose)
	var want := look_rng.randi_range(ARCH_COUNT.x, ARCH_COUNT.y)
	for spot in found:
		if arch_count >= want: break
		var at: Vector2 = spot.at
		if _near_any(arch_points, at, 30.0): continue
		var across: Vector2 = spot.across
		var ground: float = map.ground_height(at)
		var turn := Basis(Vector3.UP, atan2(-across.y, across.x)) * Basis.from_scale(Vector3(float(spot.span) / ARCH_OPENING, 1.0, 1.0))
		_add(ARCH_HOUSE, Transform3D(turn, Vector3(at.x, ground - 0.02, at.y)))
		lamps.append({"at": Vector3(at.x, ground + 3.0, at.y), "color": LANTERN_LIGHT, "radius": 4.5})
		arch_points.append(at)
		arch_count += 1

## How far from `at` the lane's walls are either way along `across` (each
## within `reach`), with a house behind each (unless not `housed`), `depth`
## along `heading` either side of the line; empty when not.
func _walls_across(at: Vector2, across: Vector2, reach_limit: float, heading: Vector2, depth: float, housed := true) -> Array[float]:
	var walls: Array[float] = []
	for side in [-1.0, 1.0]:
		var reach := 0.0
		while reach < reach_limit and map._surface.distance_near(at + across * side * reach) >= 0.0: reach += 0.25
		var wall: Vector2 = at + across * side * (reach + 0.8)
		if reach >= reach_limit: return [] as Array[float]
		if housed and (not _covered(wall + heading * depth) or not _covered(wall - heading * depth)): return [] as Array[float]
		walls.append(reach)
	return walls

## Over her lanes, between the houses either side (改造案 §2): strings of warm
## bulbs (every other bulb a small light) and laundry lines.
const STRING_GAP := Vector2(9.0, 13.0)
const STRING_SHARE := 0.6
const LAUNDRY_LINE_SHARE := 0.45
const BULB_LIGHT := Color(1.0, 0.76, 0.42) * 0.5
const BULB_COLOUR := Color(1.0, 0.8, 0.5)
var string_count := 0
var bulb_count := 0
var line_count := 0

func _place_lines() -> void:
	var wire := SurfaceTool.new()
	wire.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bulbs := SurfaceTool.new()
	bulbs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var laundry := SurfaceTool.new()
	laundry.begin(Mesh.PRIMITIVE_TRIANGLES)
	var taken: Array[Vector2] = []
	for index in range(map._links.size()):
		var link: Dictionary = map._links[index]
		if not link.alive: continue
		var line: PackedVector2Array = map._link_points(index)
		for k in range(line.size() - 1):
			var a := line[k]
			var b := line[k + 1]
			var length := a.distance_to(b)
			if length < 4.0: continue
			var heading := (b - a) / length
			var across := heading.orthogonal()
			var t := look_rng.randf_range(2.0, 6.0)
			while t < length - 1.5:
				var centre := a + heading * t
				t += look_rng.randf_range(STRING_GAP.x, STRING_GAP.y)
				if _near_any(taken, centre, 6.0) or _near_any(arch_points, centre, 6.0) or _near_any(gate_points, centre, 4.0): continue
				var walls := _walls_across(centre, across, 8.0, heading, 0.0, false)
				if walls.is_empty(): continue
				var from := centre - across * (walls[0] + 0.3)
				var to := centre + across * (walls[1] + 0.3)
				var ground: float = map.ground_height(centre)
				var roll := look_rng.randf()
				if roll < STRING_SHARE:
					var h := ground + look_rng.randf_range(4.8, 5.6)
					var sag := look_rng.randf_range(0.4, 0.7)
					_cable(wire, from, h, to, h, sag)
					var count := look_rng.randi_range(5, 8)
					for n in range(count):
						var f := (n + 0.5) / count
						var p := from.lerp(to, f)
						var y := h - sag * 4.0 * f * (1.0 - f) - 0.12
						_bulb(bulbs, Vector3(p.x, y, p.y), 0.09)
						if n % 2 == 1: lamps.append({"at": Vector3(p.x, y - 0.2, p.y), "color": BULB_LIGHT, "radius": 3.0})
						bulb_count += 1
					string_count += 1
				elif roll < STRING_SHARE + (1.0 - STRING_SHARE) * LAUNDRY_LINE_SHARE:
					var h := ground + look_rng.randf_range(4.2, 5.0)
					_cable(wire, from, h, to, h, 0.3)
					_laundry(laundry, from, to, h, 0.3)
					line_count += 1
				else: continue
				taken.append(centre)
	if line_count > 0: _add_laundry_mesh(laundry, "Laundry")
	var mesh := wire.commit()
	if mesh != null and mesh.get_surface_count() > 0:
		var instance := MeshInstance3D.new()
		instance.name = "Lines"
		instance.mesh = mesh
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = CABLE_COLOUR
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		instance.material_override = material
		root.add_child(instance)
	bulbs.generate_normals()
	var lit := bulbs.commit()
	if lit != null and lit.get_surface_count() > 0:
		var instance := MeshInstance3D.new()
		instance.name = "StringLights"
		instance.mesh = lit
		var material := StandardMaterial3D.new()
		material.albedo_color = BULB_COLOUR
		material.emission_enabled = true
		material.emission = BULB_COLOUR
		material.emission_energy_multiplier = 3.0
		instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(instance)

## A small bulb: a diamond of eight faces round `p`.
func _bulb(tool: SurfaceTool, p: Vector3, r: float) -> void:
	var tips := [Vector3(r, 0, 0), Vector3(0, 0, r), Vector3(-r, 0, 0), Vector3(0, 0, -r)]
	for i in range(4):
		var a: Vector3 = p + tips[i]
		var b: Vector3 = p + tips[(i + 1) % 4]
		for v in [p + Vector3(0, r * 1.3, 0), b, a, p - Vector3(0, r * 1.3, 0), a, b]:
			tool.add_vertex(v)
