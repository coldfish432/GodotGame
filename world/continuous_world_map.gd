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
var _main_segments: Array[PackedFloat32Array] = []
var _surface: TerrainSurface

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
	vault_node = null
	_plan_terrain()
	_surface = TerrainSurface.new()
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
## The only other guarantees are the ones downstream code depends on: a
## minimum node count, and at least one spur in each third of the route so the
## early-build / mid-gilding / late-extraction ordering survives every seed.
## Everything else — extent, node count, chamber sizes, turn pattern, how many
## spurs and niches and loops and skips there are and where — comes from seed.
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
	for i in range(node_count):
		if i > 0:
			# basicTurningChance plus increasingTurningChance per straight run:
			# the longer a passage has gone without bending, the likelier the
			# next dig turns. Straight corridors stay possible, just not for long.
			if _rng.randf() < TURN_BASIC + TURN_INCREASING * float(straight):
				var swing := _rng.randf_range(0.35, 0.95) * (1.0 if _rng.randf() < 0.5 else -1.0)
				heading = clampf(heading + swing, PI * 0.5 - TURN_CONE, PI * 0.5 + TURN_CONE)
				straight = 0
			else:
				straight += 1
			point += Vector2(cos(heading), sin(heading)) * step
			point.x = clampf(point.x, -half_x, half_x)
			point.y = clampf(point.y, SPINE_MIN.y + 10.0, deepest)
		main_path.append(point)

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
		previous_wide = wide
		_open_circles.append(Vector3(point.x, point.y, radius))
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
		if i > 0:
			var base := 5.0 if region_id == "mine" else (5.6 if region_id == "city" else 6.2)
			_connect(main_path[i - 1], point, base + _rng.randf_range(-0.5, 0.9), true)

	_dig_spurs(node_count)
	_dig_extras(node_count)

## Spurs are dug off random trunk nodes, with one forced into each third of the
## route: the device ordering downstream reads the shallowest, median and
## deepest spur, and a seed that happened to put every spur at one end would
## otherwise hand extraction to the front of the map.
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
		var direction := Vector2(-forward.y, forward.x) * side
		var reach := _rng.randf_range(24.0, 40.0)
		var end := base + direction * reach
		end.x = clampf(end.x, SPINE_MIN.x + 9.0, SPINE_MAX.x - 9.0)
		end.y = clampf(end.y, SPINE_MIN.y + 9.0, SPINE_MAX.y - 9.0)
		if end.distance_to(base) < 14.0: continue
		var chamber := Vector3(end.x, end.y, _rng.randf_range(6.0, 8.5))
		_open_circles.append(chamber)
		branch_centres.append(chamber)
		_spur_anchors.append(Vector2(float(index), side))
		_spur_points.append(end)
		_connect(base, end, _rng.randf_range(3.2, 4.2), false)
	# Devices are assigned by depth order, so that list is sorted — but the dig
	# order is what _spur_anchors and _spur_points are indexed by, so those two
	# are left alone and kept parallel to each other, not to branch_centres.
	branch_centres.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y < b.y)

## Flank roads, second-order niches, skip routes, oxbow loops and the vault.
## Every one of these is a count rolled from its {min,max} budget rather than a
## fixed feature of the layout.
func _dig_extras(node_count: int) -> void:
	for i in range(_spur_anchors.size()):
		for j in range(i + 1, _spur_anchors.size()):
			if _spur_anchors[i].y != _spur_anchors[j].y: continue
			var gap: float = absf(_spur_anchors[j].x - _spur_anchors[i].x)
			if gap < 1.0 or gap > 3.0 or _rng.randf() > 0.55: continue
			_connect(_spur_point(i), _spur_point(j), _rng.randf_range(3.0, 3.8), false)

	for i in range(_rng.randi_range(ELEMENT_NICHES.x, ELEMENT_NICHES.y)):
		if _spur_anchors.is_empty(): break
		var pick := _rng.randi_range(0, _spur_anchors.size() - 1)
		var spur := _spur_point(pick)
		var outward: float = _spur_anchors[pick].y
		var niche := Vector2(
			clampf(spur.x + outward * _rng.randf_range(11.0, 17.0), SPINE_MIN.x + 8.0, SPINE_MAX.x - 8.0),
			clampf(spur.y + _rng.randf_range(-13.0, 13.0), SPINE_MIN.y + 8.0, SPINE_MAX.y - 8.0))
		if niche.distance_to(spur) < 9.0 or _too_near(niche, niche_centres, 12.0): continue
		_open_circles.append(Vector3(niche.x, niche.y, _rng.randf_range(4.5, 6.0)))
		_connect(spur, niche, _rng.randf_range(2.8, 3.4), false)
		niche_centres.append(niche)

	for i in range(_rng.randi_range(ELEMENT_SKIPS.x, ELEMENT_SKIPS.y)):
		if _spur_anchors.is_empty(): break
		var pick := _rng.randi_range(0, _spur_anchors.size() - 1)
		var rejoin := int(_spur_anchors[pick].x) + _rng.randi_range(3, 4)
		if rejoin >= main_path.size(): continue
		_connect(_spur_point(pick), main_path[rejoin], _rng.randf_range(2.8, 3.3), false)

	for i in range(_rng.randi_range(ELEMENT_LOOPS.x, ELEMENT_LOOPS.y)):
		var anchor := _rng.randi_range(1, maxi(1, node_count - 4))
		if anchor + 2 >= main_path.size(): continue
		var base: Vector2 = main_path[anchor]
		var side := 1.0 if _rng.randf() < 0.5 else -1.0
		var reach := _rng.randf_range(26.0, 44.0)
		var near := Vector2(clampf(base.x + side * reach, SPINE_MIN.x + 10.0, SPINE_MAX.x - 10.0), base.y + _rng.randf_range(-4.0, 6.0))
		var far := Vector2(clampf(near.x + side * _rng.randf_range(-6.0, 10.0), SPINE_MIN.x + 10.0, SPINE_MAX.x - 10.0), near.y + _rng.randf_range(16.0, 30.0))
		if _too_near(near, loop_centres, 16.0): continue
		_open_circles.append(Vector3(near.x, near.y, _rng.randf_range(6.0, 7.5)))
		_open_circles.append(Vector3(far.x, far.y, _rng.randf_range(5.5, 7.0)))
		loop_centres.append(near)
		loop_centres.append(far)
		_connect(base, near, _rng.randf_range(3.2, 3.8), false)
		_connect(near, far, _rng.randf_range(3.2, 3.8), false)
		_connect(far, main_path[anchor + 2], _rng.randf_range(3.2, 3.8), false)

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
	_open_circles.append(Vector3(vault.x, vault.y, _rng.randf_range(7.5, 9.0)))
	_connect(vault_base, vault, _rng.randf_range(3.2, 3.8), false)
	vault_centre = vault

func _spur_point(index: int) -> Vector2:
	return _spur_points[index]

func _too_near(candidate: Vector2, others: Array[Vector2], limit: float) -> bool:
	for other in others:
		if other.distance_to(candidate) < limit: return true
	return false

func _connect(a: Vector2, b: Vector2, width: float, main: bool) -> void:
	var middle := (a + b) * 0.5
	if region_id == "city":
		middle = Vector2(a.x, b.y) if absf(b.x - a.x) > 8 else middle
	else:
		var direction := (b - a).normalized()
		middle += Vector2(-direction.y, direction.x) * _rng.randf_range(-2, 2)
	for pair in [[a, middle], [middle, b]]:
		var start: Vector2 = pair[0]
		var end: Vector2 = pair[1]
		if start.distance_to(end) < 0.1: continue
		var segment := PackedFloat32Array([start.x, start.y, end.x, end.y, width])
		_open_segments.append(segment)
		if main: _main_segments.append(segment)

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
	for circle in _open_circles:
		var offset := point - Vector2(circle.x, circle.y)
		var chamber_distance := circle.z - offset.length()
		if region_id == "city":
			var q := offset.abs() - Vector2(circle.z * 0.85, circle.z * 0.7)
			chamber_distance = -(q.max(Vector2.ZERO).length() + minf(maxf(q.x, q.y), 0.0)) + 1.0
		if chamber_distance > best:
			second = best
			best = chamber_distance
		elif chamber_distance > second:
			second = chamber_distance
	for segment in _open_segments:
		var corridor_distance: float = segment[4] - _segment_distance(point, segment)
		if corridor_distance > best:
			second = best
			best = corridor_distance
		elif corridor_distance > second:
			second = corridor_distance
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

func _has_clearance(point: Vector2) -> bool:
	return _is_open(point.x, point.y, -1.5)

func _safe_spot(preferred: Vector2, centre: Vector2, radius: float) -> Vector2:
	if _has_clearance(preferred): return preferred
	for ring in [0.3, 0.5, 0.7]:
		for i in range(16):
			var probe: Vector2 = centre + Vector2.from_angle(TAU * float(i) / 16.0) * radius * ring
			if _has_clearance(probe): return probe
	return centre

func _place_content() -> void:
	# Early build, middle gilding, late extraction. Each is explored via a spur,
	# leaving enough main-path encounters to use an acquired build immediately.
	# Picked by position along the route rather than by fixed index, so adding
	# or removing detours cannot silently move extraction to the front.
	# Every marker is settled onto ground the terrain actually left open. The
	# chamber centre was a safe enough guess while spurs were a fixed size at
	# fixed anchors; with both seeded, a chamber can be clipped by the bounds
	# or crowded by a neighbour, and a marker sitting a metre inside rock is
	# not a crash — it is a device or an extraction point that cannot be
	# reached, which only a seed sweep would ever catch.
	var buff := branch_centres[0]
	var gild := branch_centres[branch_centres.size() / 2]
	var exit_spot := branch_centres[branch_centres.size() - 1]
	var buff_at := _safe_spot(Vector2(buff.x, buff.y), Vector2(buff.x, buff.y), buff.z)
	var gild_at := _safe_spot(Vector2(gild.x, gild.y), Vector2(gild.x, gild.y), gild.z)
	var exit_at := _safe_spot(Vector2(exit_spot.x, exit_spot.y), Vector2(exit_spot.x, exit_spot.y), exit_spot.z)
	buff_position = Vector3(buff_at.x, 0.65, buff_at.y)
	encounter_position = Vector3(gild_at.x, 0.65, gild_at.y)
	buff_device_node = _marker("强化 · E", buff_position, Color("ef9b42"))
	encounter_node = _marker("坎诺特 · E" if encounter_kind == "trader" else "罗德岛小队 · E", encounter_position, Color("e6c25a") if encounter_kind == "trader" else Color("5fd0d8"))
	encounter_node.visible = not encounter_kind.is_empty()
	exit_node = _marker("撤离 · E", Vector3(exit_at.x, 0.15, exit_at.y), Color("63eca7"))
	exit_node.visible = extraction_available
	route_nodes.clear()
	var final_chamber: Vector3 = _open_circles[main_path.size() - 1]
	for i in range(3):
		var wanted: Vector2 = main_path[-1] + Vector2((i - 1) * 5.5, 2.5)
		var spot := _safe_spot(wanted, main_path[-1], final_chamber.z)
		route_nodes.append(_marker(FieldCatalog.ROUTES[i].name + " · E", Vector3(spot.x, 0.15, spot.y), Color("69b7ea")))
	enemy_spawn_points.clear()
	# Spread existing regional enemy budgets across the whole route first.
	for i in range(2, main_path.size(), 2):
		var point := main_path[i]
		enemy_spawn_points.append(Vector3(point.x, 0, point.y))
	for branch in branch_centres:
		enemy_spawn_points.append(Vector3(branch.x, 0, branch.y + 2))
	cache_positions.clear()
	# Every detour that is not carrying a device carries supplies instead — a
	# longer route must not mean a higher share of empty dead ends.
	for i in range(branch_centres.size()):
		if i == 0 or i == branch_centres.size() / 2 or i == branch_centres.size() - 1: continue
		var spur := branch_centres[i]
		cache_positions.append(Vector3(spur.x, 0.5, spur.y))
	# An absent extraction must not turn its branch into an empty dead end.
	cache_positions.append(Vector3(exit_spot.x + 2.0, 0.5, exit_spot.y))
	for i in range(2, main_path.size() - 1, 4):
		var point := _safe_spot(main_path[i] + Vector2(-3, 2), main_path[i], 10)
		cache_positions.append(Vector3(point.x, 0.5, point.y))
	for loop in loop_centres:
		cache_positions.append(Vector3(loop.x, 0.5, loop.y))
	# A second-order niche is the longest walk on the map for its size, so it
	# always pays; an empty one would just teach the player to ignore forks.
	for niche in niche_centres:
		cache_positions.append(Vector3(niche.x, 0.5, niche.y))

	# Mechanisms sit on the detours that carry no device, so clearing them all
	# means having actually walked the spurs rather than pressing north. Spurs
	# first because their anchors are spread along the whole route; niches and
	# loop rooms only top up when a seed produced few spare spurs.
	mechanism_positions.clear()
	var candidates: Array[Vector2] = []
	for i in range(branch_centres.size()):
		if i == 0 or i == branch_centres.size() / 2 or i == branch_centres.size() - 1: continue
		candidates.append(Vector2(branch_centres[i].x, branch_centres[i].y))
	candidates.append_array(niche_centres)
	candidates.append_array(loop_centres)
	for i in range(mini(4, candidates.size())):
		var spot := _safe_spot(candidates[i] + Vector2(2.0, -2.0), candidates[i], 5.0)
		mechanism_positions.append(Vector3(spot.x, 0.5, spot.y))
		mechanism_nodes.append(_marker("机关 · E", Vector3(spot.x, 0.35, spot.y), Color("b47ae0")))

	var vault_spot := _safe_spot(vault_centre, vault_centre, 8.0)
	vault_position = Vector3(vault_spot.x, 0.5, vault_spot.y)
	vault_node = _marker("密室", Vector3(vault_spot.x, 0.2, vault_spot.y), Color("d8b24a"))

func _dress_landmarks() -> void:
	# Compose grounded groups independently of progression RNG and collision.
	SceneDressing.new().build(self)
	# Linear remnants follow the route itself: curved mine rails / broken road
	# markings. They carry no collision and cannot determine walkable topology.
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

func _strip(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	var middle := (a + b) * 0.5
	var mesh := _make_box("RouteTrace", Vector3(middle.x, 0.022, middle.y), Vector3(width, 0.025, a.distance_to(b)), color, false)
	mesh.rotation.y = atan2(b.x - a.x, b.y - a.y)

func _marker(title: String, pos: Vector3, color: Color) -> Node3D:
	var node := _make_cylinder(title, pos, 1.6, 0.25, color, false)
	var label := Label3D.new()
	label.text = title
	label.font_size = 36
	label.pixel_size = 0.009
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 1.3
	label.modulate = color
	node.add_child(label)
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
	if _has_clearance(flat):
		return point
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
	return Vector3(best.x, point.y, best.y)

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
	if is_instance_valid(_generated_root):
		remove_child(_generated_root)
		_generated_root.queue_free()
	_generated_root = null
