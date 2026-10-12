class_name ContinuousWorldMap
extends Node3D

const ENTRY_POSITION := Vector3(0, 0.7, -22)
const SPINE_MIN := Vector2(-96, -36)
const SPINE_MAX := Vector2(96, 190)
var region_id := "mine"
var extraction_available := false
var buff_position := Vector3.ZERO
## The mid-route spot where a Rhodes squad or 坎诺特 can be met (保全系统修订案 §2,
## 坎诺特商店策划案 §1). It used to hold the gilding device.
var encounter_position := Vector3.ZERO
## "" (nobody this floor), "squad" or "trader"; set before generate().
var encounter_kind := ""
var exit_node: Node3D
var buff_device_node: Node3D
var encounter_node: Node3D
var route_nodes: Array[Node3D] = []
## Where the outpost squad holds: the room the way to the route markers leads
## through. The markers are no longer always at the end of the trunk.
var route_guard_position := Vector3.ZERO
var seed_value := 0
var open_pass_count := 3
var total_pass_count := 3
var enemy_spawn_points: Array[Vector3] = []
var cache_positions: Array[Vector3] = []
var map_center := Vector3(0, 0, 77)
var map_extent := 113.0  # half the larger span; depth still exceeds width
var minimap_faces: Array[PackedVector2Array] = []
var terrain_edges: Array[PackedVector2Array] = []
var main_path := PackedVector2Array()
var branch_centres: Array[Vector3] = []
var loop_centres: Array[Vector2] = []
var niche_centres: Array[Vector2] = []
var _spur_anchors: Array[Vector2] = []
var _spur_points: Array[Vector2] = []
var vault_centre := Vector2.ZERO
var vault_position := Vector3.ZERO
var vault_node: Node3D
var mechanism_positions: Array[Vector3] = []
var mechanism_nodes: Array[Node3D] = []
var _generated_root: NavigationRegion3D
var _rng := RandomNumberGenerator.new()
var _open_circles: Array[Vector3] = []
var _closed_circles: Array[Vector3] = []
var _open_segments: Array[PackedFloat32Array] = []
## Corridors that carry a worn trail (rails, road paint, packed snow). Rolled
## per link for trunk and branches alike, so the trail is not a guide to the
## trunk. The name predates that.
var _main_segments: Array[PackedFloat32Array] = []
var _surface: TerrainSurface

## Elevation (参考《恐怖黎明》: the walkable ground sits on terraces joined by
## ramps and stairs, and where two terraces meet without one there is a cliff).
## Every room is flat at a whole tier; a corridor between rooms of different
## tiers is a ramp, flat for RAMP_APRON beyond each room's rim so a junction
## never starts on a slope. Rooms of different tiers that happen to touch with
## no corridor between them meet at a cliff, which TerrainSurface walls off.
## The floor stays one sheet over x/z — no bridge passes over another route —
## so fog, the minimap and every walkability test stay two-dimensional.
const TIER := 2.2
const MAX_TIER := 2
## Horizontal run one tier of ramp needs: 2.2 over 6.5 is ~19°, well inside
## the navmesh's 35° and the character's 45°.
const RAMP_RUN := 6.5
const RAMP_APRON := 2.0
## Rise between neighbouring terrain samples (1.5 apart) above which the ground
## is cliff, not slope: 0.9 over 1.5 is ~31°.
const CLIFF_STEP := 0.9
const TRUNK_TIER_CHANCE := 0.3
const BRANCH_TIER_CHANCE := 0.45
const TRAIL_TRUNK := 0.7
const TRAIL_BRANCH := 0.45
## Share of floors whose route markers stand at the trunk's end.
const TRUNK_EXIT_SHARE := 0.25

## Per open circle: its tier, what dug it, and the trunk tier it was dug at.
var levels := PackedInt32Array()
var circle_kinds: Array[String] = []
var _trunk_levels := PackedInt32Array()
## {a, b, middle, width, trail, length, alive}; a/b index _open_circles.
var _links: Array[Dictionary] = []
## Walk distance from the entry to each circle along the links.
var circle_distance := PackedFloat32Array()
## The circle holding the route markers, and the one holding extraction.
var exit_chamber := -1
var extraction_chamber := -1
var _last_owner := 0
## How many tier rolls the last generate() needed (1 = the first held).
var level_attempts := 0

func generate(p_seed: int, _depth: int) -> void:
	_clear_generated_map()
	seed_value = p_seed
	_rng.seed = p_seed
	_generated_root = NavigationRegion3D.new()
	add_child(_generated_root)
	_open_circles.clear()
	_closed_circles.clear()
	_open_segments.clear()
	_main_segments.clear()
	main_path.clear()
	branch_centres.clear()
	loop_centres.clear()
	niche_centres.clear()
	_spur_anchors.clear()
	_spur_points.clear()
	mechanism_nodes.clear()
	mechanism_positions.clear()
	levels.clear()
	circle_kinds.clear()
	_trunk_levels.clear()
	_links.clear()
	_overlap.clear()
	vault_node = null
	_plan_terrain()
	_surface = TerrainSurface.new()
	# Tiers are rolled, then checked on the sampled terrain: a ramp that runs
	# past a room of another tier can meet it at a cliff and cut the way on.
	# A failed roll is re-rolled once, then the floor goes flat, so every
	# seed ends with a floor that connects.
	var dug := ""
	for attempt in range(3):
		_assign_levels(attempt)
		level_attempts = attempt + 1
		# The contour only changes when a different set of corridors is dug;
		# otherwise only the heights are re-read.
		var alive := ""
		for link in _links: alive += "1" if link.alive else "0"
		if alive != dug:
			_build_segments()
			_surface.sample(self)
			dug = alive
		else:
			_surface.relevel()
		if attempt == 2 or _surface.connects(_reach_targets()): break
	_surface.build(self)
	_place_content()
	_dress_landmarks()
	_build_navigation_mesh()

## Layout generation, rebuilt in the shape of 贪婪洞窟's level_N.plist rather
## than as an authored skeleton. That game configures a floor as a size range
## the seed picks within, two turn-chance factors that decide how often a dug
## passage bends, and per-element {min,max} counts — nothing about the result
## is fixed, only its budget. See 贪婪洞窟地图设计调研.md §1.1.
##
## One thing is deliberately NOT copied: that game digs in all four directions,
## while a segment here has to run entry-south to exits-north because one-way
## advance is a hard rule of the design. So the trunk's heading is bounded to
## a forward cone; the seed decides how often and how sharply it turns inside
## that cone, not whether it doubles back. Bounding the cone also means the
## trunk cannot cross itself, so connectivity holds by construction.
##
## The trunk is a construction aid, not something the player should be able to
## read off the ground: branch corridors are as wide as trunk ones, branch rooms
## can be arenas, a branch can run on past its first room, the worn trail is
## rolled per corridor, and the route markers go to a far room that need not be
## the trunk's end. See 地图场景改造.md (2026-10-12).
const MAP_NODES := Vector2i(11, 17)
const MAP_DEPTH_RANGE := Vector2(0.68, 1.0)
const MAP_WIDTH_RANGE := Vector2(0.55, 1.0)
const TURN_BASIC := 0.16
const TURN_INCREASING := 0.17
const TURN_CONE := 0.95
const ELEMENT_SPURS := Vector2i(5, 9)
const ELEMENT_NICHES := Vector2i(0, 3)
const ELEMENT_LOOPS := Vector2i(0, 2)
const ELEMENT_SKIPS := Vector2i(0, 2)
const ELEMENT_PILLARS := Vector2i(0, 2)
## Chance a branch digs a second room past its first.
const SPUR_CHAIN_CHANCE := 0.4

func _corridor_width() -> float:
	return _rng.randf_range(3.4, 5.6) + (0.5 if region_id == "snow" else (0.3 if region_id == "city" else 0.0))

func _add_circle(point: Vector2, radius: float, kind: String, trunk_level: int) -> int:
	_open_circles.append(Vector3(point.x, point.y, radius))
	circle_kinds.append(kind)
	_trunk_levels.append(trunk_level)
	levels.append(trunk_level)
	return _open_circles.size() - 1

func _plan_terrain() -> void:
	var entry := Vector2(ENTRY_POSITION.x, ENTRY_POSITION.z)
	var half_x: float = (SPINE_MAX.x - 14.0) * _rng.randf_range(MAP_WIDTH_RANGE.x, MAP_WIDTH_RANGE.y)
	var deepest: float = SPINE_MAX.y - 16.0
	var target_z: float = entry.y + (deepest - entry.y) * _rng.randf_range(MAP_DEPTH_RANGE.x, MAP_DEPTH_RANGE.y)
	var node_count := _rng.randi_range(MAP_NODES.x, MAP_NODES.y)
	# 0.82 is the average forward component of a heading wandering inside the
	# cone; the step is sized from it so the dig lands near the target depth
	# whatever turn pattern the seed produces.
	var step := clampf((target_z - entry.y) / (float(node_count) * 0.82), 9.5, 18.0)

	var heading := PI * 0.5
	var straight := 0
	var point := entry
	var previous_wide := true  # the entry adit counts as wide, so node 1 necks
	var level := 0
	for i in range(node_count):
		var radius := 0.0
		var wide := false
		if i == 0:
			radius = 10.0
			wide = true
		elif i == node_count - 1:
			radius = _rng.randf_range(14.0, 16.5)
			wide = true
		elif previous_wide or _rng.randf() > 0.7:
			radius = _rng.randf_range(4.0, 5.6)
		else:
			radius = _rng.randf_range(12.0, 16.5) + (2.0 if region_id == "snow" else 0.0)
			wide = true
		var next_level := level
		if i > 0:
			# A change of tier needs room for its ramp, so that dig runs longer.
			var this_step := step
			if _rng.randf() < TRUNK_TIER_CHANCE:
				next_level = level + (1 if _rng.randf() < 0.5 else -1)
				if next_level < 0 or next_level > MAX_TIER: next_level = level - (next_level - level)
				this_step = maxf(step, _open_circles[i - 1].z + radius + 2.0 * RAMP_APRON + RAMP_RUN + 1.5)
			# basicTurningChance plus increasingTurningChance per straight run:
			# the longer a passage has gone without bending, the likelier the
			# next dig turns. Straight corridors stay possible, just not for long.
			if _rng.randf() < TURN_BASIC + TURN_INCREASING * float(straight):
				var swing := _rng.randf_range(0.35, 0.95) * (1.0 if _rng.randf() < 0.5 else -1.0)
				heading = clampf(heading + swing, PI * 0.5 - TURN_CONE, PI * 0.5 + TURN_CONE)
				straight = 0
			else:
				straight += 1
			point += Vector2(cos(heading), sin(heading)) * this_step
			point.x = clampf(point.x, -half_x, half_x)
			point.y = clampf(point.y, SPINE_MIN.y + 10.0, deepest)
		main_path.append(point)
		previous_wide = wide
		_add_circle(point, radius, "trunk", next_level)
		if i > 0:
			_link(i - 1, i, _corridor_width(), TRAIL_TRUNK)
			# The bounds clamp can shorten a dig below what its ramp needed.
			if _free_run(_links[-1]) < RAMP_RUN * absf(next_level - level): next_level = level
			_trunk_levels[i] = next_level
			levels[i] = next_level
		level = next_level
		if wide and i > 0:
			for p in range(_rng.randi_range(ELEMENT_PILLARS.x, ELEMENT_PILLARS.y)):
				var angle := _rng.randf_range(0.0, TAU)
				var offset := Vector2(cos(angle), sin(angle)) * _rng.randf_range(3.5, radius - 6.0)
				if offset.length() < 2.0: continue
				# Floor on the radius, not just a pleasing range: the terrain
				# contour is sampled on a 1.5 grid, and a pillar much narrower
				# than a couple of cells does not reliably close into wall
				# geometry — it stops blocking line of sight, which quietly
				# takes away the cover a fight in that arena depends on.
				_closed_circles.append(Vector3(point.x + offset.x, point.y + offset.y, _rng.randf_range(2.4, 3.2)))

	_dig_spurs(node_count)
	_dig_extras(node_count)

## Spurs are dug off random trunk nodes, with one forced into each third of the
## route: the device ordering downstream reads the shallowest and median spur,
## and a seed that happened to put every spur at one end would otherwise hand
## the early build to the back of the map.
func _dig_spurs(node_count: int) -> void:
	var count := _rng.randi_range(ELEMENT_SPURS.x, ELEMENT_SPURS.y)
	var usable := node_count - 2
	var anchors: Array[int] = []
	for band in [Vector2i(1, maxi(1, usable / 3)), Vector2i(usable / 3, 2 * usable / 3), Vector2i(2 * usable / 3, usable)]:
		anchors.append(_rng.randi_range(maxi(1, band.x), maxi(1, band.y)))
	while anchors.size() < count:
		var pick := _rng.randi_range(1, usable)
		if anchors.count(pick) < 2: anchors.append(pick)
	anchors.sort()

	_spur_anchors.clear()
	_spur_points.clear()
	for anchor in anchors:
		var index: int = mini(anchor, main_path.size() - 2)
		var base: Vector2 = main_path[index]
		var forward: Vector2 = (main_path[index + 1] - base).normalized()
		var side := 1.0 if _rng.randf() < 0.5 else -1.0
		# A fork, not a right-angle tee: anywhere from leaning forward to
		# square off the trunk, so the trunk is not the one straight line.
		var direction := forward.rotated(side * _rng.randf_range(0.75, 1.75))
		var reach := _rng.randf_range(24.0, 42.0)
		var end := base + direction * reach
		end.x = clampf(end.x, SPINE_MIN.x + 9.0, SPINE_MAX.x - 9.0)
		end.y = clampf(end.y, SPINE_MIN.y + 9.0, SPINE_MAX.y - 9.0)
		if end.distance_to(base) < 14.0: continue
		# Branch rooms come in the trunk's sizes, arenas included.
		var radius := _rng.randf_range(6.0, 8.5) if _rng.randf() < 0.6 else _rng.randf_range(10.0, 13.5)
		var room := _add_circle(end, radius, "spur", _trunk_levels[index])
		_spur_anchors.append(Vector2(float(index), side))
		_spur_points.append(end)
		_link(index, room, _corridor_width(), TRAIL_BRANCH)
		if _rng.randf() >= SPUR_CHAIN_CHANCE: continue
		var onward := direction.rotated(_rng.randf_range(-0.7, 0.7))
		var further := end + onward * _rng.randf_range(radius + 14.0, radius + 26.0)
		further.x = clampf(further.x, SPINE_MIN.x + 9.0, SPINE_MAX.x - 9.0)
		further.y = clampf(further.y, SPINE_MIN.y + 9.0, SPINE_MAX.y - 9.0)
		if further.distance_to(end) < radius + 10.0 or _crowded(further, 9.0, room): continue
		var next := _add_circle(further, _rng.randf_range(6.0, 11.0), "spur", _trunk_levels[index])
		_spur_anchors.append(Vector2(float(index), side))
		_spur_points.append(further)
		_link(room, next, _corridor_width(), TRAIL_BRANCH)
	# Devices are assigned by depth order, so that list is sorted — but the dig
	# order is what _spur_anchors and _spur_points are indexed by, so those two
	# are left alone and kept parallel to each other, not to branch_centres.
	branch_centres.clear()
	for i in range(_open_circles.size()):
		if circle_kinds[i] == "spur": branch_centres.append(_open_circles[i])
	branch_centres.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y < b.y)

## True when `point` would sit on top of a room other than `except`.
func _crowded(point: Vector2, margin: float, except: int) -> bool:
	for i in range(_open_circles.size()):
		if i == except: continue
		var circle := _open_circles[i]
		if point.distance_to(Vector2(circle.x, circle.y)) < circle.z + margin: return true
	return false

## Flank roads, second-order niches, skip routes, oxbow loops and the vault.
## Every one of these is a count rolled from its {min,max} budget rather than a
## fixed feature of the layout.
func _dig_extras(node_count: int) -> void:
	for i in range(_spur_anchors.size()):
		for j in range(i + 1, _spur_anchors.size()):
			if _spur_anchors[i].y != _spur_anchors[j].y: continue
			var gap: float = absf(_spur_anchors[j].x - _spur_anchors[i].x)
			if gap < 1.0 or gap > 3.0 or _rng.randf() > 0.55: continue
			_link(_circle_at(_spur_point(i)), _circle_at(_spur_point(j)), _corridor_width() * 0.85, TRAIL_BRANCH)

	for i in range(_rng.randi_range(ELEMENT_NICHES.x, ELEMENT_NICHES.y)):
		if _spur_anchors.is_empty(): break
		var pick := _rng.randi_range(0, _spur_anchors.size() - 1)
		var spur := _spur_point(pick)
		var outward: float = _spur_anchors[pick].y
		var niche := Vector2(
			clampf(spur.x + outward * _rng.randf_range(11.0, 17.0), SPINE_MIN.x + 8.0, SPINE_MAX.x - 8.0),
			clampf(spur.y + _rng.randf_range(-13.0, 13.0), SPINE_MIN.y + 8.0, SPINE_MAX.y - 8.0))
		if niche.distance_to(spur) < 9.0 or _too_near(niche, niche_centres, 12.0): continue
		var spur_room := _circle_at(spur)
		var room := _add_circle(niche, _rng.randf_range(4.5, 6.0), "niche", _trunk_levels[spur_room])
		_link(spur_room, room, _rng.randf_range(2.8, 3.6), TRAIL_BRANCH)
		niche_centres.append(niche)

	for i in range(_rng.randi_range(ELEMENT_SKIPS.x, ELEMENT_SKIPS.y)):
		if _spur_anchors.is_empty(): break
		var pick := _rng.randi_range(0, _spur_anchors.size() - 1)
		var rejoin := int(_spur_anchors[pick].x) + _rng.randi_range(3, 4)
		if rejoin >= main_path.size(): continue
		_link(_circle_at(_spur_point(pick)), rejoin, _corridor_width() * 0.8, TRAIL_BRANCH)

	for i in range(_rng.randi_range(ELEMENT_LOOPS.x, ELEMENT_LOOPS.y)):
		var anchor := _rng.randi_range(1, maxi(1, node_count - 4))
		if anchor + 2 >= main_path.size(): continue
		var base: Vector2 = main_path[anchor]
		var side := 1.0 if _rng.randf() < 0.5 else -1.0
		var reach := _rng.randf_range(26.0, 44.0)
		var near := Vector2(clampf(base.x + side * reach, SPINE_MIN.x + 10.0, SPINE_MAX.x - 10.0), base.y + _rng.randf_range(-4.0, 6.0))
		var far := Vector2(clampf(near.x + side * _rng.randf_range(-6.0, 10.0), SPINE_MIN.x + 10.0, SPINE_MAX.x - 10.0), near.y + _rng.randf_range(16.0, 30.0))
		if _too_near(near, loop_centres, 16.0): continue
		var near_room := _add_circle(near, _rng.randf_range(6.0, 7.5), "loop", _trunk_levels[anchor])
		var far_room := _add_circle(far, _rng.randf_range(5.5, 7.0), "loop", _trunk_levels[anchor])
		loop_centres.append(near)
		loop_centres.append(far)
		_link(anchor, near_room, _corridor_width(), TRAIL_BRANCH)
		_link(near_room, far_room, _corridor_width(), TRAIL_BRANCH)
		_link(far_room, anchor + 2, _corridor_width(), TRAIL_BRANCH)

	# The vault hangs off the back half on whichever flank is emptier there, so
	# it stays the one room that pressing forward never reaches.
	var vault_index := _rng.randi_range(maxi(1, node_count * 2 / 3), main_path.size() - 2)
	var vault_base: Vector2 = main_path[vault_index]
	var busy := 0.0
	for anchor in _spur_anchors:
		if absf(anchor.x - float(vault_index)) <= 2.0: busy += anchor.y
	var vault_side := -1.0 if busy > 0.0 else 1.0
	var vault := Vector2(
		clampf(vault_base.x + vault_side * _rng.randf_range(26.0, 36.0), SPINE_MIN.x + 11.0, SPINE_MAX.x - 11.0),
		clampf(vault_base.y + _rng.randf_range(4.0, 14.0), SPINE_MIN.y + 11.0, SPINE_MAX.y - 11.0))
	var vault_room := _add_circle(vault, _rng.randf_range(7.5, 9.0), "vault", _trunk_levels[vault_index])
	_link(vault_index, vault_room, _rng.randf_range(3.2, 3.8), TRAIL_BRANCH)
	vault_centre = vault

func _spur_point(index: int) -> Vector2:
	return _spur_points[index]

## The open circle centred on `point` (every link end is one).
func _circle_at(point: Vector2) -> int:
	for i in range(_open_circles.size()):
		if Vector2(_open_circles[i].x, _open_circles[i].y).distance_squared_to(point) < 0.01: return i
	return 0

func _too_near(candidate: Vector2, others: Array[Vector2], limit: float) -> bool:
	for other in others:
		if other.distance_to(candidate) < limit: return true
	return false

## A corridor between two rooms. Its bend is rolled here, with the layout, so
## that re-rolling tiers later never moves a wall.
func _link(a: int, b: int, width: float, trail_chance: float) -> void:
	var start := Vector2(_open_circles[a].x, _open_circles[a].y)
	var end := Vector2(_open_circles[b].x, _open_circles[b].y)
	var middle := (start + end) * 0.5
	if region_id == "city":
		middle = Vector2(start.x, end.y) if absf(end.x - start.x) > 8 else middle
	else:
		var direction := (end - start).normalized()
		middle += Vector2(-direction.y, direction.x) * _rng.randf_range(-2, 2)
	_links.append({
		"a": a, "b": b, "middle": middle, "width": width,
		"trail": _rng.randf() < trail_chance,
		"length": start.distance_to(middle) + middle.distance_to(end),
		"alive": true,
	})

## Run of corridor between the two rooms' flat aprons, available for a ramp.
func _free_run(link: Dictionary) -> float:
	return float(link.length) - _open_circles[link.a].z - _open_circles[link.b].z - 2.0 * RAMP_APRON

## attempt 0: as rolled; 1: re-rolled; 2: flat.
##
## Tiers are fitted to the geometry, not just rolled. Shapes that reach across
## each other's walking line (see _overlap) must stand at one tier, or the
## cliff where their fields hand over would close the way; a corridor that
## has neither the run for a ramp nor a stretch to itself ties its two rooms
## together the same way. Those ties sort the rooms into groups, and only
## between groups — always over a corridor that can carry a ramp — does the
## tier step. Where shapes only touch, the tiers meet at a cliff along the
## side, which is the overlook the layout wants. The sampled connectivity
## check in generate() stays as the backstop.
func _assign_levels(attempt: int) -> void:
	if _overlap.is_empty(): _measure_overlaps()
	for link in _links: link.alive = true
	for i in range(levels.size()): levels[i] = 0
	if attempt >= 2: return
	var tier_rng := RandomNumberGenerator.new()
	tier_rng.seed = seed_value ^ (0x5f3759df + attempt * 104729)
	var rooms := _open_circles.size()
	var group := PackedInt32Array()
	group.resize(rooms)
	for i in range(rooms): group[i] = i
	for shape in range(_overlap.size()):
		for other in _overlap[shape]:
			if other > shape: _tie(group, _shape_rooms(shape) + _shape_rooms(other))
	for index in range(_links.size()):
		if not _rampable(index): _tie(group, [int(_links[index].a), int(_links[index].b)])
	var tier_of := {}
	tier_of[_group_of(group, 0)] = 0
	var used := PackedByteArray()
	used.resize(_links.size())
	var changed := true
	while changed:
		changed = false
		for index in range(_links.size()):
			var link: Dictionary = _links[index]
			var from := _group_of(group, int(link.a))
			var to := _group_of(group, int(link.b))
			if from == to: continue
			if not tier_of.has(from) and tier_of.has(to):
				var swap := from
				from = to
				to = swap
			if not tier_of.has(from) or tier_of.has(to): continue
			var base: int = tier_of[from]
			var step := 0
			# A trunk dig that ran long for a ramp gets one.
			if index < main_path.size() - 1: step = _trunk_levels[index + 1] - _trunk_levels[index]
			elif tier_rng.randf() < BRANCH_TIER_CHANCE: step = 1 if tier_rng.randf() < 0.5 else -1
			var tier := base + step
			if tier < 0 or tier > MAX_TIER: tier = base - step
			tier_of[to] = tier
			used[index] = 1
			changed = true
	for i in range(rooms):
		levels[i] = int(tier_of.get(_group_of(group, i), 0))
	# A corridor closing a loop between groups settled apart: kept when it has
	# the run for the rise, otherwise not dug.
	for index in range(_links.size()):
		if used[index] != 0: continue
		var link: Dictionary = _links[index]
		var rise := absi(levels[link.a] - levels[link.b])
		link.alive = rise == 0 or _free_run(link) >= RAMP_RUN * rise

func _group_of(group: PackedInt32Array, i: int) -> int:
	while group[i] != i:
		group[i] = group[group[i]]
		i = group[i]
	return i

func _tie(group: PackedInt32Array, rooms: Array) -> void:
	for k in range(1, rooms.size()):
		var a := _group_of(group, int(rooms[0]))
		var b := _group_of(group, int(rooms[k]))
		if a != b: group[b] = a

## The rooms whose tier a shape stands at: a room itself, a level piece its
## link's room, a ramp stretch both of its link's rooms.
func _shape_rooms(shape: int) -> Array:
	if shape < _open_circles.size(): return [shape]
	var link: Dictionary = _links[_piece_link(shape)]
	match _piece_part(shape):
		0: return [int(link.a)]
		2: return [int(link.b)]
	return [int(link.a), int(link.b)]

## Room for a ramp, with nothing reaching across it.
func _rampable(index: int) -> bool:
	return _free_run(_links[index]) >= RAMP_RUN and _overlap[_open_circles.size() + index * 3 + 1].is_empty()

## Shapes are numbered rooms first (circle index), then three pieces per link
## (rooms + 3 * link + k): k = 0 the level run out of room a, 1 the stretch a
## ramp would take, 2 the level run into room b. _overlap[s] lists the shapes
## that would cut across s's walking line if the two stood at different tiers:
## where two shapes merely touch, the tiers meet at a cliff along the side,
## which is the look this is after; where one reaches over the other's centre
## line, that cliff runs across the way and closes it.
var _overlap: Array[PackedInt32Array] = []
var _pieces: Array[PackedVector2Array] = []
## Width of walkable strip either side of a centre line that must stay clear.
const BLOCK_CLEARANCE := 2.5

func _measure_overlaps() -> void:
	var rooms := _open_circles.size()
	_pieces.clear()
	for index in range(_links.size()):
		var link: Dictionary = _links[index]
		var line := _link_points(index)
		var start: float = _open_circles[link.a].z + RAMP_APRON
		var end: float = float(link.length) - _open_circles[link.b].z - RAMP_APRON
		if end < start: start = (start + end) * 0.5; end = start
		_pieces.append(_polyline_range(line, 0.0, start))
		_pieces.append(_polyline_range(line, start, end))
		_pieces.append(_polyline_range(line, end, float(link.length)))
	var total := rooms + _pieces.size()
	_overlap.clear()
	for a in range(total): _overlap.append(PackedInt32Array())
	for a in range(total):
		for b in range(a + 1, total):
			if _joined(a, b) or not _blocking(a, b): continue
			_overlap[a].append(b)
			_overlap[b].append(a)

static func _polyline_range(line: PackedVector2Array, from: float, to: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if to - from < 0.05: return out
	var along := 0.0
	for i in range(line.size() - 1):
		var length := line[i].distance_to(line[i + 1])
		var lo := clampf((from - along) / maxf(length, 0.001), 0.0, 1.0)
		var hi := clampf((to - along) / maxf(length, 0.001), 0.0, 1.0)
		if hi > lo:
			var a := line[i].lerp(line[i + 1], lo)
			if out.is_empty() or out[-1].distance_squared_to(a) > 0.0001: out.append(a)
			out.append(line[i].lerp(line[i + 1], hi))
		along += length
	return out

func _piece_link(shape: int) -> int:
	return (shape - _open_circles.size()) / 3

func _piece_part(shape: int) -> int:
	return (shape - _open_circles.size()) % 3

## The room a level piece stands in, or -1 for a ramp stretch.
func _piece_room(shape: int) -> int:
	var link: Dictionary = _links[_piece_link(shape)]
	match _piece_part(shape):
		0: return int(link.a)
		2: return int(link.b)
	return -1

func _joined(a: int, b: int) -> bool:
	var rooms := _open_circles.size()
	if a >= rooms and b >= rooms:
		if _piece_link(a) == _piece_link(b): return true
		# Level pieces running out of the same room stand on its tier together.
		var room := _piece_room(a)
		return room >= 0 and room == _piece_room(b)
	if a >= rooms: return _joined(b, a)
	if b < rooms: return false
	var link: Dictionary = _links[_piece_link(b)]
	return int(link.a) == a or int(link.b) == a

func _room_reach(i: int) -> float:
	var r: float = _open_circles[i].z
	return r * 1.1 + 1.0 if region_id == "city" else r

func _link_points(index: int) -> PackedVector2Array:
	var link: Dictionary = _links[index]
	return PackedVector2Array([Vector2(_open_circles[link.a].x, _open_circles[link.a].y), link.middle, Vector2(_open_circles[link.b].x, _open_circles[link.b].y)])

func _shape_line(shape: int) -> PackedVector2Array:
	if shape < _open_circles.size(): return PackedVector2Array([Vector2(_open_circles[shape].x, _open_circles[shape].y)])
	return _pieces[shape - _open_circles.size()]

func _shape_size(shape: int) -> float:
	if shape < _open_circles.size(): return _room_reach(shape)
	return float(_links[_piece_link(shape)].width)

## One shape's field takes over the other's centre line (or centre) when the
## two centre geometries are closer than the difference of their sizes; the
## clearance keeps a walkable strip either side of that line.
func _blocking(a: int, b: int) -> bool:
	var line_a := _shape_line(a)
	var line_b := _shape_line(b)
	if line_a.is_empty() or line_b.is_empty(): return false
	return _line_gap(line_a, line_b) < absf(_shape_size(a) - _shape_size(b)) + BLOCK_CLEARANCE

static func _line_gap(a: PackedVector2Array, b: PackedVector2Array) -> float:
	if a.size() == 1 and b.size() == 1: return a[0].distance_to(b[0])
	if a.size() == 1: return _point_line_gap(a[0], b)
	if b.size() == 1: return _point_line_gap(b[0], a)
	var nearest := INF
	for i in range(a.size() - 1):
		for k in range(b.size() - 1):
			if Geometry2D.segment_intersects_segment(a[i], a[i + 1], b[k], b[k + 1]) != null: return 0.0
			var pair := Geometry2D.get_closest_points_between_segments(a[i], a[i + 1], b[k], b[k + 1])
			nearest = minf(nearest, pair[0].distance_to(pair[1]))
	return nearest

static func _point_line_gap(point: Vector2, line: PackedVector2Array) -> float:
	var nearest := INF
	for k in range(line.size() - 1):
		nearest = minf(nearest, point.distance_to(Geometry2D.get_closest_point_to_segment(point, line[k], line[k + 1])))
	return nearest

func _build_segments() -> void:
	_open_segments.clear()
	_main_segments.clear()
	for index in range(_links.size()):
		var link: Dictionary = _links[index]
		if not link.alive: continue
		var a := Vector2(_open_circles[link.a].x, _open_circles[link.a].y)
		var b := Vector2(_open_circles[link.b].x, _open_circles[link.b].y)
		var middle: Vector2 = link.middle
		var along := 0.0
		for pair in [[a, middle], [middle, b]]:
			var start: Vector2 = pair[0]
			var end: Vector2 = pair[1]
			var length := start.distance_to(end)
			if length < 0.1: continue
			# x, z, x, z, half-width, link, arc length at start, at end.
			var segment := PackedFloat32Array([start.x, start.y, end.x, end.y, link.width, index, along, along + length])
			along += length
			_open_segments.append(segment)
			if link.trail: _main_segments.append(segment)

## Rooms the floor has to connect: all of them, from the entry.
func _reach_targets() -> Array[Vector2]:
	var targets: Array[Vector2] = []
	for circle in _open_circles: targets.append(Vector2(circle.x, circle.y))
	return targets

func _link_height(link: Dictionary, s: float) -> float:
	var ha := float(levels[link.a]) * TIER
	var hb := float(levels[link.b]) * TIER
	if ha == hb: return ha
	var start: float = _open_circles[link.a].z + RAMP_APRON
	var end: float = float(link.length) - _open_circles[link.b].z - RAMP_APRON
	if end <= start: return ha if s < float(link.length) * 0.5 else hb
	return lerpf(ha, hb, clampf((s - start) / (end - start), 0.0, 1.0))

## Ground level the shape `owner` (from carved_distance) sets at `point`.
func owner_height(owner: int, point: Vector2) -> float:
	if owner >= 0: return float(levels[owner]) * TIER
	var segment: PackedFloat32Array = _open_segments[-owner - 1]
	var a := Vector2(segment[0], segment[1])
	var delta := Vector2(segment[2], segment[3]) - a
	var t := clampf((point - a).dot(delta) / maxf(delta.length_squared(), 0.001), 0, 1)
	return _link_height(_links[int(segment[5])], lerpf(segment[6], segment[7], t))

## Height of the walkable ground (or the rock's foot) at x/z, matching the mesh.
func ground_height(point: Vector2) -> float:
	return _surface.ground_at(point) if _surface != null else 0.0

## `point` placed on the ground below or above it. A y under the local ground
## cannot be a real position, so it reads as a height above that ground — the
## convention every caller written for the flat floor already uses.
func on_ground(point: Vector3) -> Vector3:
	var ground := ground_height(Vector2(point.x, point.z))
	if point.y < ground - 0.01: point.y += ground
	return point

## Middle of every dug ramp's sloped stretch, with the ramp's direction
## (towards its high end) — for tests and captures.
func ramp_midpoints() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for index in range(_links.size()):
		var link: Dictionary = _links[index]
		if not link.alive or levels[link.a] == levels[link.b]: continue
		var piece: PackedVector2Array = _pieces[index * 3 + 1]
		if piece.size() < 2: continue
		var up := (piece[-1] - piece[0]).normalized() * (1.0 if levels[link.b] > levels[link.a] else -1.0)
		found.append({"point": piece[0].lerp(piece[-1], 0.5), "up": up, "link": index, "piece": piece})
	return found

func _segment_distance(point: Vector2, segment: PackedFloat32Array) -> float:
	var a := Vector2(segment[0], segment[1])
	var delta := Vector2(segment[2], segment[3]) - a
	var t := clampf((point - a).dot(delta) / maxf(delta.length_squared(), 0.001), 0, 1)
	return point.distance_to(a + delta * t)

## Junction smoothing. A plain max() union meets at a crease: a 5-wide corridor
## runs into a 14-radius arena wall at an angle and leaves a notch, and a
## dogleg leaves another on the inside of its bend. Blending the fields instead
## of taking the hard maximum fillets every junction, so a corridor flares open
## into the room it feeds and a bend rounds off, without any of it being
## authored per joint.
##
## BLEND is the fillet's reach. Too large and shapes that merely pass near each
## other fuse into one blob, which would undo the arena/corridor contrast the
## layout is built on; this is tuned well under the gap between parallel routes.
const BLEND := 3.5
## Pillars are free-standing rock and should still read as objects, so their
## subtraction is only eased enough to lose the cookie-cutter edge.
const PILLAR_BLEND := 1.2

static func _smooth_max(a: float, b: float, k: float) -> float:
	var h := clampf(0.5 + 0.5 * (a - b) / k, 0.0, 1.0)
	return lerpf(b, a, h) + k * h * (1.0 - h)

static func _smooth_min(a: float, b: float, k: float) -> float:
	var h := clampf(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
	return lerpf(b, a, h) - k * h * (1.0 - h)

## Also leaves the shape nearest the point in _last_owner: a circle's index, or
## -(segment index + 1). That shape sets the ground's height there.
func carved_distance(point: Vector2) -> float:
	# Only the two nearest shapes are blended, never the whole chain. Folding a
	# smooth max over every primitive in turn would add up to k/4 per step, and
	# the steps only stop contributing once the operands are more than k apart
	# — so anywhere a crowd of shapes sits at a similar distance the field
	# inflates by an amount that depends on how many primitives happen to be
	# nearby, which is not a property the layout should have. A fillet only
	# ever involves the two surfaces that form the joint, so best and
	# second-best give the same rounding with a bound that does not move.
	var best := -1e9
	var second := -1e9
	var owner := 0
	for i in range(_open_circles.size()):
		var circle := _open_circles[i]
		var offset := point - Vector2(circle.x, circle.y)
		var chamber_distance := circle.z - offset.length()
		if region_id == "city":
			var q := offset.abs() - Vector2(circle.z * 0.85, circle.z * 0.7)
			chamber_distance = -(q.max(Vector2.ZERO).length() + minf(maxf(q.x, q.y), 0.0)) + 1.0
		if chamber_distance > best:
			second = best
			best = chamber_distance
			owner = i
		elif chamber_distance > second:
			second = chamber_distance
	for j in range(_open_segments.size()):
		var segment := _open_segments[j]
		var corridor_distance: float = segment[4] - _segment_distance(point, segment)
		if corridor_distance > best:
			second = best
			best = corridor_distance
			owner = -(j + 1)
		elif corridor_distance > second:
			second = corridor_distance
	_last_owner = owner
	var distance := best if second <= -1e8 else _smooth_max(best, second, BLEND)
	for pillar in _closed_circles:
		distance = _smooth_min(distance, point.distance_to(Vector2(pillar.x, pillar.y)) - pillar.z, PILLAR_BLEND)
	return distance

func road_distance(point: Vector2) -> float:
	var distance := INF
	for segment in _main_segments: distance = minf(distance, _segment_distance(point, segment))
	return distance

func _is_open(x: float, z: float, inflate: float = 0.0) -> bool:
	var point := Vector2(x, z)
	return (_surface.distance_at(point) if _surface != null else carved_distance(point)) >= -inflate

## Room to stand: well inside the contour and not on a cliff's face.
func _has_clearance(point: Vector2) -> bool:
	return _is_open(point.x, point.y, -1.5) and (_surface == null or _surface.is_level(point))

func _safe_spot(preferred: Vector2, centre: Vector2, radius: float) -> Vector2:
	if _has_clearance(preferred): return preferred
	for ring in [0.3, 0.5, 0.7]:
		for i in range(16):
			var probe: Vector2 = centre + Vector2.from_angle(TAU * float(i) / 16.0) * radius * ring
			if _has_clearance(probe): return probe
	return centre

## A point on the ground at x/z, `lift` above it.
func _grounded(point: Vector2, lift: float) -> Vector3:
	return Vector3(point.x, ground_height(point) + lift, point.y)

## Walk distance from the entry to every room, over the corridors actually dug.
func _walk_distances() -> PackedInt32Array:
	circle_distance = PackedFloat32Array()
	circle_distance.resize(_open_circles.size())
	circle_distance.fill(INF)
	circle_distance[0] = 0.0
	var parent := PackedInt32Array()
	parent.resize(_open_circles.size())
	parent.fill(-1)
	var done := PackedByteArray()
	done.resize(_open_circles.size())
	for _pass in range(_open_circles.size()):
		var current := -1
		for i in range(_open_circles.size()):
			if done[i] == 0 and circle_distance[i] < INF and (current < 0 or circle_distance[i] < circle_distance[current]): current = i
		if current < 0: break
		done[current] = 1
		for link in _links:
			if not link.alive: continue
			var other := -1
			if int(link.a) == current: other = int(link.b)
			elif int(link.b) == current: other = int(link.a)
			if other < 0 or done[other] != 0: continue
			var through: float = circle_distance[current] + float(link.length)
			if through < circle_distance[other]:
				circle_distance[other] = through
				parent[other] = current
	return parent

func _degree(circle: int) -> int:
	var count := 0
	for link in _links:
		if link.alive and (int(link.a) == circle or int(link.b) == circle): count += 1
	return count

func _place_content() -> void:
	# Early build and the mid-route encounter sit on the shallowest and median
	# branch; the route markers and extraction go to far rooms picked from the
	# whole map, trunk end or not. Every marker is settled onto ground the
	# terrain actually left open: a marker a metre inside rock or on a cliff
	# face is not a crash — it is a device that cannot be reached, which only
	# a seed sweep would ever catch.
	var parent := _walk_distances()
	var spurs: Array[int] = []
	for i in range(_open_circles.size()):
		if circle_kinds[i] == "spur" and circle_distance[i] < INF: spurs.append(i)
	spurs.sort_custom(func(a: int, b: int) -> bool: return _open_circles[a].y < _open_circles[b].y)
	var buff_room: int = spurs[0]
	var encounter_room: int = spurs[spurs.size() / 2]
	var farthest := 0.0
	for d in circle_distance:
		if d < INF: farthest = maxf(farthest, d)
	var trunk_end := main_path.size() - 1

	# Route markers: any dead-end room big enough for three markers, in the far
	# part of the walk. The trunk's end is one candidate among several.
	var candidates: Array[int] = []
	for share in [0.5, 0.35, 0.0]:
		for i in range(_open_circles.size()):
			if i == buff_room or i == encounter_room or circle_kinds[i] in ["vault", "niche"]: continue
			if circle_distance[i] == INF or circle_distance[i] < farthest * share: continue
			if i == trunk_end or (_degree(i) == 1 and _open_circles[i].z >= 6.5): candidates.append(i)
		if not candidates.is_empty(): break
	# The trunk's end keeps only a minority share, or most floors would still
	# end where the widest road does.
	var elsewhere := candidates.filter(func(i: int) -> bool: return i != trunk_end)
	if candidates.has(trunk_end) and (elsewhere.is_empty() or _rng.randf() < TRUNK_EXIT_SHARE): exit_chamber = trunk_end
	else: exit_chamber = elsewhere[_rng.randi_range(0, elsewhere.size() - 1)]

	# Extraction: another far dead end, well apart from the route markers.
	var extract_options: Array[int] = []
	for i in range(_open_circles.size()):
		if i == exit_chamber or i == buff_room or i == encounter_room or i == 0 or circle_kinds[i] in ["vault", "niche"]: continue
		if circle_distance[i] == INF or circle_distance[i] < farthest * 0.45: continue
		if i != trunk_end and _degree(i) != 1: continue
		var centre := Vector2(_open_circles[i].x, _open_circles[i].y)
		if centre.distance_to(Vector2(_open_circles[exit_chamber].x, _open_circles[exit_chamber].y)) < 25.0: continue
		extract_options.append(i)
	if extract_options.is_empty():
		for i in spurs:
			if i != exit_chamber and i != buff_room and i != encounter_room: extract_options.append(i)
	if extract_options.is_empty(): extract_options.append(spurs[-1])
	extraction_chamber = extract_options[_rng.randi_range(0, extract_options.size() - 1)]

	var buff := _open_circles[buff_room]
	var gild := _open_circles[encounter_room]
	var exit_spot := _open_circles[extraction_chamber]
	var buff_at := _safe_spot(Vector2(buff.x, buff.y), Vector2(buff.x, buff.y), buff.z)
	var gild_at := _safe_spot(Vector2(gild.x, gild.y), Vector2(gild.x, gild.y), gild.z)
	var exit_at := _safe_spot(Vector2(exit_spot.x, exit_spot.y), Vector2(exit_spot.x, exit_spot.y), exit_spot.z)
	buff_position = _grounded(buff_at, 0.65)
	encounter_position = _grounded(gild_at, 0.65)
	buff_device_node = _marker("强化 · E", buff_position, Color("ef9b42"))
	encounter_node = _marker("坎诺特 · E" if encounter_kind == "trader" else "罗德岛小队 · E", encounter_position, Color("e6c25a") if encounter_kind == "trader" else Color("5fd0d8"))
	encounter_node.visible = not encounter_kind.is_empty()
	exit_node = _marker("撤离 · E", _grounded(exit_at, 0.15), Color("63eca7"))
	exit_node.visible = extraction_available
	route_nodes.clear()
	var route_room := _open_circles[exit_chamber]
	var route_centre := Vector2(route_room.x, route_room.y)
	# The three markers line up across the way in, so they face the arrival.
	var arrival := Vector2.UP
	if parent[exit_chamber] >= 0:
		var from := _open_circles[parent[exit_chamber]]
		arrival = (route_centre - Vector2(from.x, from.y)).normalized()
	var across := arrival.orthogonal()
	for i in range(3):
		var wanted: Vector2 = route_centre + across * (i - 1) * 5.5 + arrival * 2.5
		var spot := _safe_spot(wanted, route_centre, route_room.z)
		route_nodes.append(_marker(FieldCatalog.ROUTES[i].name + " · E", _grounded(spot, 0.15), Color("69b7ea")))
	var hold := _open_circles[maxi(0, parent[exit_chamber])]
	var hold_at := Vector2(hold.x, hold.y).lerp(route_centre, 0.35) if parent[exit_chamber] > 0 else route_centre - arrival * 8.0
	route_guard_position = _grounded(_safe_spot(hold_at, Vector2(hold.x, hold.y), hold.z), 0.0)

	enemy_spawn_points.clear()
	# Spread existing regional enemy budgets across the whole route first.
	# Settled like every marker: a pillar can stand over a small room's centre.
	for i in range(2, main_path.size(), 2):
		enemy_spawn_points.append(_grounded(_safe_spot(main_path[i], main_path[i], _open_circles[i].z), 0.0))
	for branch in branch_centres:
		var centre := Vector2(branch.x, branch.y)
		enemy_spawn_points.append(_grounded(_safe_spot(centre + Vector2(0, 2), centre, branch.z), 0.0))
	cache_positions.clear()
	# Every branch room not carrying a device or a destination carries supplies
	# instead — a longer route must not mean a higher share of empty dead ends.
	var used := [buff_room, encounter_room, extraction_chamber, exit_chamber]
	var spare: Array[int] = []
	for i in spurs:
		if not used.has(i): spare.append(i)
	for i in spare:
		cache_positions.append(_grounded(Vector2(_open_circles[i].x, _open_circles[i].y), 0.5))
	# An absent extraction must not turn its room into an empty dead end.
	cache_positions.append(_grounded(Vector2(exit_spot.x + 2.0, exit_spot.y), 0.5))
	# Nor the trunk's end, when the markers went elsewhere.
	if exit_chamber != trunk_end and extraction_chamber != trunk_end:
		cache_positions.append(_grounded(_safe_spot(main_path[trunk_end], main_path[trunk_end], 8.0), 0.5))
	for i in range(2, main_path.size() - 1, 4):
		var point := _safe_spot(main_path[i] + Vector2(-3, 2), main_path[i], 10)
		cache_positions.append(_grounded(point, 0.5))
	for loop in loop_centres:
		if _circle_at(loop) != exit_chamber: cache_positions.append(_grounded(loop, 0.5))
	# A second-order niche is the longest walk on the map for its size, so it
	# always pays; an empty one would just teach the player to ignore forks.
	for niche in niche_centres:
		cache_positions.append(_grounded(niche, 0.5))

	# Mechanisms sit on the detours that carry no device, so clearing them all
	# means having actually walked the branches rather than pressing on. Spurs
	# first because their anchors are spread along the whole route; niches and
	# loop rooms only top up when a seed produced few spare spurs.
	mechanism_positions.clear()
	var mechanism_spots: Array[Vector2] = []
	for i in spare: mechanism_spots.append(Vector2(_open_circles[i].x, _open_circles[i].y))
	mechanism_spots.append_array(niche_centres)
	mechanism_spots.append_array(loop_centres)
	for i in range(mini(4, mechanism_spots.size())):
		var spot := _safe_spot(mechanism_spots[i] + Vector2(2.0, -2.0), mechanism_spots[i], 5.0)
		mechanism_positions.append(_grounded(spot, 0.5))
		mechanism_nodes.append(_marker("机关 · E", _grounded(spot, 0.35), Color("b47ae0")))

	var vault_spot := _safe_spot(vault_centre, vault_centre, 8.0)
	vault_position = _grounded(vault_spot, 0.5)
	vault_node = _marker("密室", _grounded(vault_spot, 0.2), Color("d8b24a"))

func _dress_landmarks() -> void:
	# Compose grounded groups independently of progression RNG and collision.
	SceneDressing.new().build(self)
	# Linear remnants follow the worn corridors: curved mine rails / broken
	# road markings. They carry no collision and cannot determine walkable
	# topology. Laid in short pieces so they follow a ramp's slope.
	for segment in _main_segments:
		var a := Vector2(segment[0], segment[1])
		var b := Vector2(segment[2], segment[3])
		var direction := (b - a).normalized()
		var across := Vector2(-direction.y, direction.x)
		if region_id == "mine":
			for side in [-1.0, 1.0]: _strip(a + across * side * 0.85, b + across * side * 0.85, 0.08, Color("736550"))
			for i in range(int(a.distance_to(b) / 1.5)):
				var p := a + direction * (i * 1.5)
				_strip(p - across * 1.2, p + across * 1.2, 0.16, Color("494139"))
		elif region_id == "city":
			for i in range(int(a.distance_to(b) / 4)):
				var p := a + direction * (i * 4 + 0.5)
				_strip(p, p + direction * 1.6, 0.14, Color("a39769"))
	# Stairs on every ramp in the city, timber treads in the mine: the rise
	# has to read as a way up from above, not as a smudge in the floor.
	if region_id == "snow": return
	for segment in _open_segments:
		var link: Dictionary = _links[int(segment[5])]
		if levels[link.a] == levels[link.b]: continue
		var a := Vector2(segment[0], segment[1])
		var b := Vector2(segment[2], segment[3])
		var direction := (b - a).normalized()
		var across := Vector2(-direction.y, direction.x)
		var half: float = segment[4] - 0.8
		var tread := 0.7 if region_id == "city" else 1.1
		for i in range(int(a.distance_to(b) / tread)):
			var s: float = lerpf(segment[6], segment[7], (i * tread) / a.distance_to(b))
			var rise := _link_height(link, s)
			if is_equal_approx(rise, float(levels[link.a]) * TIER) or is_equal_approx(rise, float(levels[link.b]) * TIER): continue
			var p := a + direction * (i * tread)
			_strip(p - across * half, p + across * half, 0.12 if region_id == "city" else 0.22, Color("8d8a80") if region_id == "city" else Color("5b4a36"))

func _strip(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	var pieces := maxi(1, ceili(a.distance_to(b) / 2.0))
	for i in range(pieces):
		var from := a.lerp(b, float(i) / pieces)
		var to := a.lerp(b, float(i + 1) / pieces)
		var start := _grounded(from, 0.022)
		var end := _grounded(to, 0.022)
		var middle := (start + end) * 0.5
		var mesh := _make_box("RouteTrace", middle, Vector3(width, 0.025, start.distance_to(end)), color, false)
		if start.distance_to(end) > 0.01: mesh.basis = Basis.looking_at(end - start)

func _marker(title: String, pos: Vector3, color: Color) -> Node3D:
	var node := _make_cylinder(title, on_ground(pos), 1.6, 0.25, color, false)
	var label := Label3D.new()
	label.text = title
	label.font_size = 36
	label.pixel_size = 0.009
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 1.3
	label.modulate = color
	node.add_child(label)
	return node

	return node

func try_sample_navigation_position(position: Vector3, max_distance: float = 4.0) -> Vector3:
	if not is_instance_valid(_generated_root):
		return position
	var map_rid := _generated_root.get_navigation_map()
	var closest := NavigationServer3D.map_get_closest_point(map_rid, position)
	if closest.distance_to(position) <= max_distance:
		return closest
	return position

## Analytic fallback also works before the navigation server has synchronized.
## Explicit clearance keeps authored enemy offsets out of banks and pillars.
func nearest_walkable(point: Vector3) -> Vector3:
	if _open_circles.is_empty():
		return try_sample_navigation_position(point)
	var flat := Vector2(point.x, point.z)
	# Height above the ground is kept across the move; a y under the ground is
	# already one (see on_ground).
	var lift := point.y - ground_height(flat)
	if lift < -0.01: lift = point.y
	if _has_clearance(flat):
		return Vector3(point.x, ground_height(flat) + lift, point.z)
	var best := flat
	var best_distance := INF
	for circle in _open_circles:
		var centre := Vector2(circle.x, circle.y)
		var towards := centre + (flat - centre).limit_length(circle.z * 0.5)
		var candidate := _safe_spot(towards, centre, circle.z)
		var distance := candidate.distance_to(flat)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return Vector3(best.x, ground_height(best) + lift, best.y)

func navigation_map_rid() -> RID:
	if not is_instance_valid(_generated_root):
		return RID()
	return _generated_root.get_navigation_map()

func is_navigation_ready() -> bool:
	return is_instance_valid(_generated_root) and _generated_root.navigation_mesh != null

func clamp_to_world(position: Vector3) -> Vector3:
	position.x = clampf(position.x, SPINE_MIN.x + 1.2, SPINE_MAX.x - 1.2)
	position.z = clampf(position.z, SPINE_MIN.y + 1.2, SPINE_MAX.y - 1.2)
	return nearest_walkable(position)

func _build_navigation_mesh() -> void:
	var nav_mesh := NavigationMesh.new()
	nav_mesh.agent_height = 1.5
	nav_mesh.agent_radius = 0.75
	nav_mesh.agent_max_climb = 0.5
	nav_mesh.agent_max_slope = 35.0
	nav_mesh.cell_size = 0.25
	nav_mesh.cell_height = 0.25
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	_generated_root.navigation_mesh = nav_mesh
	_generated_root.bake_navigation_mesh(false)

func _make_box(box_name: String, pos: Vector3, size: Vector3, color: Color, obstacle: bool) -> Node3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = box_name
	mesh_instance.set_meta("art_kind", box_name)
	mesh_instance.set_meta("obstacle", obstacle)
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_instance.material_override = mat
	_generated_root.add_child(mesh_instance)
	mesh_instance.position = pos

	if not obstacle and box_name != "Ground":
		return mesh_instance
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	mesh_instance.add_child(body)
	if obstacle:
		body.add_to_group("world_obstacle")
	return mesh_instance

func _make_cylinder(cyl_name: String, pos: Vector3, diameter: float, height: float, color: Color, obstacle: bool) -> Node3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = cyl_name
	mesh_instance.set_meta("art_kind", cyl_name)
	mesh_instance.set_meta("obstacle", obstacle)
	var cyl := CylinderMesh.new()
	cyl.top_radius = diameter / 2.0
	cyl.bottom_radius = diameter / 2.0
	cyl.height = height
	mesh_instance.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_instance.material_override = mat
	_generated_root.add_child(mesh_instance)
	mesh_instance.position = pos

	if obstacle:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.add_to_group("world_obstacle")
		var shape := CollisionShape3D.new()
		var cyl_shape := CylinderShape3D.new()
		cyl_shape.radius = diameter / 2.0
		cyl_shape.height = height
		shape.shape = cyl_shape
		body.add_child(shape)
		mesh_instance.add_child(body)
	return mesh_instance

func _clear_generated_map() -> void:
	exit_node = null
	buff_device_node = null
	encounter_node = null
	enemy_spawn_points.clear()
	_surface = null
	if is_instance_valid(_generated_root):
		remove_child(_generated_root)
		_generated_root.queue_free()
	_generated_root = null
