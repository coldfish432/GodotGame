class_name ContinuousWorldMap
extends Node3D

const ENTRY_POSITION := Vector3(0, 0.7, -22)
## The floor's bounds at map_scale 1. Each floor rolls its own size (用户
## 2026-10-13: 地图画大一点，大图小图也随机): the bounds and every distance the
## layout digs over (trunk steps, branch and loop reach, the vault) are scaled
## by map_scale, room sizes are not — a big floor is the same rooms spread
## further apart, with longer corridors and more rock between them, which is
## also what gives a bridge room to cross. The entry stays where it is.
const BASE_MIN := Vector2(-96, -36)
const BASE_MAX := Vector2(96, 190)
const MAP_SCALE := Vector2(1.0, 1.5)
var map_scale := 1.0
var SPINE_MIN := BASE_MIN
var SPINE_MAX := BASE_MAX
var region_id := "mine"
## Laid out as a town (FieldCatalog.URBAN): Lungmen and Siracusa.
var urban := false
## Siracusa's floor weather (叙拉古方案 §3.4, 用户 2026-10-16: 随机): "rain" or
## "overcast"; "" elsewhere.
var weather := ""
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
## Footprints of the props that collide (CityDressing._collider): [centre, unit
## x axis, half size] on the ground plane. The contour does not know them, so
## standing room is checked against them too: an enemy placed inside one is
## hidden from every shot (line_of_sight hits the box) and cannot be killed.
var prop_blockers: Array = []
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
## Where the vault shows on the minimap once it is open (hidden until then).
var vault_node: Node3D
## 密室 (密室与陷阱修订案_v1 §2.1, 用户 2026-10-17): on VAULT_CHANCE of the
## floors a dead end off the back half, sealed by a 暗墙 at its mouth and
## covered over (VaultSeal) until the wall is broken. `force_vault` 1 / 0
## overrides the roll (tests and captures).
## Rolled on 28% of floors; about seven in ten find rock enough for the room
## (_vault_clear), so about one floor in five has one (用户: 20%).
const VAULT_CHANCE := 0.28
## Half its size each way, the same on every floor (用户 2026-10-17: 固定大小，
## 每张地图的密室样子一致).
const VAULT_ROOM := Vector2(6.0, 4.5)
## The edge's own roughness, kept off the vault room's straight walls.
func edge_noise(point: Vector2, raw: float) -> float:
	if _vault_room >= 0 and _last_owner == _vault_room: return raw * 0.1
	return raw * (0.1 if urban else 0.85)
var has_vault := false
var force_vault := -1
var _vault_room := -1
var _vault_link := -1
## The 暗墙: its centre, the way into the vault across it, and its half length.
var vault_mouth := Vector2.ZERO
var vault_inward := Vector2.ZERO
var vault_half_width := 0.0
var vault_seal: VaultSeal
## While true the vault's room and lane are left out of the carve: the floor is
## generated, meshed and dressed as if there were no vault (用户 2026-10-17:
## 整体是一体的，但是能看出来). VaultSeal builds the dug version of that patch
## aside and swaps it in when the wall breaks.
var vault_excluded := false
var _generated_root: NavigationRegion3D
var _rng := RandomNumberGenerator.new()
var _shape_rng := RandomNumberGenerator.new()
var _open_circles: Array[Vector3] = []
var _closed_circles: Array[Vector3] = []
## Per pillar, its irregular outline (用户 2026-10-12: the round pillars become
## irregular rocks of random size): stretch along its own axis, the axis
## angle, and two lobes (amplitude, phase) for frequencies 2 and 3.
var _pillar_shapes: Array[PackedFloat32Array] = []
const PILLAR_RADIUS := Vector2(2.0, 3.6)
const PILLAR_MAX_REACH := 4.4
var _open_segments: Array[PackedFloat32Array] = []
## Corridors that carry a worn trail (rails, road paint, packed snow). Rolled
## per link for trunk and branches alike, so the trail is not a guide to the
## trunk. The name predates that.
var _main_segments: Array[PackedFloat32Array] = []
var _surface: TerrainSurface
## The Blender cliff / ramp / rubble pieces laid on this floor (counts for tests).
var terrace_dressing: TerraceDressing

## Elevation (参考《恐怖黎明》: the walkable ground sits on terraces joined by
## ramps and stairs, and where two terraces meet without one there is a cliff).
## Every room is flat at a whole tier; a corridor between rooms of different
## tiers is a ramp, flat for RAMP_APRON beyond each room's rim so a junction
## never starts on a slope. Rooms of different tiers that happen to touch with
## no corridor between them meet at a cliff, which TerrainSurface walls off.
## The floor stays one sheet over x/z, so fog, the minimap and every
## walkability test stay two-dimensional; the one exception is a rock bridge
## (see BRIDGE_REGIONS), whose deck is a separate body over the sheet.
const TIER := 2.2
const MAX_TIER := 2
## Horizontal run one tier of ramp needs: 2.2 over 10 is ~12°. It was 6.5
## (~19°), but a short ramp between rooms did not read as a climb at all (用户
## 2026-10-13: 如果是坡道就长到能看出来): long enough that its middle stands
## clear of the rooms at either end, where the causeway's falling sides show.
const RAMP_RUN := 10.0
## A bridge's stubs climb two tiers each and lead straight to the deck, which
## shows the height on its own; they keep a steeper run so bridges still fit.
const BRIDGE_RAMP_RUN := 7.5
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

## Overpasses (用户 2026-10-13: 下面的路从上面的路下面穿过，形成有高度差的不连在
## 一起的回路 — the lower road passes under the upper one, so loops cross at two
## heights without joining). Two rooms with a bottom-tier corridor running
## between them are joined by a straight road that climbs from each to a deck
## two tiers over that corridor. The sheet cannot hold two floors at one x/z,
## so that road is dug as two ramped stubs that stop at the lower corridor's
## cliffs, and a rock arch (art/kit/snow_bridge.glb) carries it over the gap:
## a deck body with walls along both sides, so it cannot be walked off. Off
## the deck everything stays two-dimensional; over it, ground_height takes
## the walker's height to tell the deck from the road below.
const BRIDGE_REGIONS := ["snow", "city"]
## The span model per region; the city's is a concrete overpass (城市地图调研与方案_v1.md).
const BRIDGE_MODELS := {"snow": "res://art/kit/snow_bridge.glb", "city": "res://art/kit/city_overpass.glb"}
const BRIDGE_MAX := 2
## Tiers between the deck and the road under it.
const BRIDGE_RISE := 2
## Half-width of the stubs, like every corridor's.
const BRIDGE_HALF_WIDTH := 3.2
## Half-width of the walkable deck between its walls.
const DECK_HALF_WIDTH := 2.45
## How far the deck runs onto each stub past the cliff line.
const DECK_OVERLAP := 1.4
## Level run at the deck's height at the inner end of each stub, so the deck
## lands on flat road however the cliff it springs from runs.
const BRIDGE_FLAT := 3.5
## The stubs stop this far outside the lower corridor's edge.
const BRIDGE_STUB_GAP := 1.2
const BRIDGE_ROOM_GAP := Vector2(20.0, 52.0)
## Rock the stubs keep between themselves and every other shape.
const BRIDGE_CLEAR := 1.0
## A walker within this of a deck's top, over it, stands on it.
const BRIDGE_REACH := 2.0
## {link, lower, a, b, cross, dir, cut, along, top}, and once settled on the
## sampled terrain: centre, axis (world x/z), span between the cliff lines,
## base (the road below).
var bridges: Array[Dictionary] = []
var _base_links := 0
## {p, q, lower, heading, back_p, back_q}: room pairs dug across a branch
## corridor for a bridge, and the rooms they are tied back to.
var _crossings: Array[Dictionary] = []

## Load timing (DOWNFALL_PROFILE=1): each stage of generate() prints how long
## it took since the last mark.
var _profile := OS.get_environment("DOWNFALL_PROFILE") == "1"
var _profile_at := 0

func mark(stage: String) -> void:
	if not _profile: return
	var now := Time.get_ticks_usec()
	if not stage.is_empty(): print("  [map %s] %-22s %7.1f ms" % [region_id, stage, (now - _profile_at) / 1000.0])
	_profile_at = now

func generate(p_seed: int, _depth: int) -> void:
	mark("")
	_clear_generated_map()
	seed_value = p_seed
	_rng.seed = p_seed
	urban = FieldCatalog.urban(region_id)
	var sky := RandomNumberGenerator.new()
	sky.seed = p_seed ^ 0x5a1e
	weather = ("rain" if sky.randf() < RAIN_SHARE else "overcast") if region_id == "siracusa" else ""
	var size_rng := RandomNumberGenerator.new()
	size_rng.seed = p_seed ^ 0x5ca1e
	map_scale = size_rng.randf_range(MAP_SCALE.x, MAP_SCALE.y)
	SPINE_MIN = Vector2(BASE_MIN.x * map_scale, BASE_MIN.y)
	SPINE_MAX = Vector2(BASE_MAX.x * map_scale, BASE_MIN.y + (BASE_MAX.y - BASE_MIN.y) * map_scale)
	map_center = Vector3((SPINE_MIN.x + SPINE_MAX.x) * 0.5, 0.0, (SPINE_MIN.y + SPINE_MAX.y) * 0.5)
	map_extent = maxf(SPINE_MAX.x - SPINE_MIN.x, SPINE_MAX.y - SPINE_MIN.y) * 0.5
	_shape_rng.seed = p_seed ^ 0x9111a7
	_warp.seed = p_seed ^ 0xca7e
	_warp.frequency = CAVE_WARP_FREQUENCY
	_warp.fractal_octaves = 2
	_generated_root = NavigationRegion3D.new()
	add_child(_generated_root)
	_open_circles.clear()
	_closed_circles.clear()
	prop_blockers.clear()
	_pillar_shapes.clear()
	_room_shapes.clear()
	_swell.seed = p_seed ^ 0x5e11
	_swell.frequency = 0.07
	_swell.fractal_octaves = 1
	_open_segments.clear()
	_main_segments.clear()
	_cell_rooms.clear()
	_cell_segments.clear()
	_cell_pillars.clear()
	main_path.clear()
	branch_centres.clear()
	loop_centres.clear()
	niche_centres.clear()
	_spur_anchors.clear()
	_spur_points.clear()
	levels.clear()
	circle_kinds.clear()
	_trunk_levels.clear()
	_links.clear()
	_overlap.clear()
	_crossings.clear()
	vault_node = null
	if vault_seal != null: vault_seal.release()
	vault_seal = null
	vault_excluded = false
	_vault_room = -1
	_vault_link = -1
	var lot := RandomNumberGenerator.new()
	lot.seed = p_seed ^ 0x7a0175
	has_vault = lot.randf() < VAULT_CHANCE if force_vault < 0 else force_vault == 1
	_plan_terrain()
	_plan_old_town()
	_roll_districts()
	mark("layout")
	_base_links = _links.size()
	bridges.clear()
	_surface = TerrainSurface.new()
	# Tiers are rolled, then checked on the sampled terrain: a ramp that runs
	# past a room of another tier can meet it at a cliff and cut the way on.
	# A failed roll is re-rolled once, then the floor goes flat, so every
	# seed ends with a floor that connects.
	var dug := ""
	for attempt in range(3):
		# Bridges are planned on the tiers this attempt settled, so the ones
		# from the last attempt go before the tiers are rolled again.
		_links.resize(_base_links)
		bridges.clear()
		_assign_levels(attempt)
		_plan_bridges()
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
	mark("tiers + sampling x%d" % level_attempts)
	# The flat fallback is not checked, but its bridges' stubs stand two tiers
	# up and could still cut a way: if the floor does not connect with them,
	# it goes without.
	if level_attempts == 3 and not bridges.is_empty() and not _surface.connects(_reach_targets()):
		for bridge in bridges: _links[bridge.link].alive = false
		bridges.clear()
		_build_segments()
		_surface.sample(self)
	_settle_bridges()
	_surface.build(self)
	mark("terrain mesh")
	_build_bridges()
	_place_content()
	_plan_roadblock()
	mark("bridges + content")
	_dress_landmarks()
	if vault_seal != null:
		var roots: Array[Node] = []
		for name in ["SceneDressing", "TerraceDressing"]:
			var root := _generated_root.get_node_or_null(name)
			if root != null: roots.append(root)
		vault_seal.prepare_dressing(roots)
		mark("vault patch")
	_build_navigation_mesh()
	mark("navmesh")

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
## Cave-like layouts (用户 2026-10-12: 尝试做立体随机地图，类似这种 — a cave map
## of blobby rooms, loops and rock islands): in these regions every outline is
## domain-warped (CAVE_WARP metres of low-frequency noise shifts where the
## field is read, so walls wander without narrowing), arenas get more rock
## islands and the layout more loops. Tried in the snowfield first.
const CAVE_REGIONS := ["snow"]
## The warp squeezes where it changes fastest (by about amplitude x
## frequency x 3): kept near 20%, and cave corridors widened to make up for it.
const CAVE_WARP := 1.8
const CAVE_WARP_FREQUENCY := 0.035
const CAVE_WIDEN := 0.6
const ELEMENT_PILLARS_CAVE := Vector2i(2, 4)
const ELEMENT_LOOPS_CAVE := Vector2i(2, 4)
var _warp := FastNoiseLite.new()
## Chance a branch digs a second room past its first.
const SPUR_CHAIN_CHANCE := 0.4

func _corridor_width() -> float:
	# Siracusa's lanes: 5.2–6.6 m wall to wall (叙拉古方案 §3.2 asked for 3–4.5;
	# a lane at a slant that narrow leaves no standing ground on the terrain's
	# 1.5 m sampling grid, and the floor fails its connection check).
	if region_id == "siracusa": return _rng.randf_range(LANE_WIDTH.x, LANE_WIDTH.x + 0.7)
	return _rng.randf_range(3.4, 5.6) + (0.5 if region_id == "snow" else (0.3 if region_id == "city" else 0.0)) + (CAVE_WIDEN if region_id in CAVE_REGIONS else 0.0)

## Roads and rooms run into each other (用户 2026-10-13: 模糊道路和房间之间的区
## 别，像恐怖黎明那样, for every region). A room is no longer a circle: its rim
## swells and pulls in with two lobes (amplitude in ROOM_LOBES, from the shape
## RNG so the layout does not move). A corridor is no longer a tube: it widens
## along its run by up to CORRIDOR_SWELL of its width, in slow swells, and it
## flares into each room it joins by up to CORRIDOR_FLARE of that room's
## radius, so the road opens into the room instead of meeting a rim. Widths
## only ever grow from the planned ones, so every clearance the layout was
## checked against still holds. The city keeps its squared blocks.
const ROOM_LOBES := Vector2(0.05, 0.14)
const CORRIDOR_SWELL := 0.55
const CORRIDOR_FLARE := 0.45
## Per room: amplitude and phase of the 2- and 3-lobe terms.
var _room_shapes: Array[PackedFloat32Array] = []
var _swell := FastNoiseLite.new()

func _add_circle(point: Vector2, radius: float, kind: String, trunk_level: int) -> int:
	# Siracusa's squares are small piazzas (叙拉古方案 §3.2): the arenas shrink,
	# the small rooms stay as they are.
	if region_id == "siracusa" and radius > PIAZZA_FROM: radius = PIAZZA_FROM + (radius - PIAZZA_FROM) * PIAZZA_SHRINK
	_room_shapes.append(PackedFloat32Array([_shape_rng.randf_range(ROOM_LOBES.x, ROOM_LOBES.y), _shape_rng.randf_range(0.0, TAU),
		_shape_rng.randf_range(ROOM_LOBES.x, ROOM_LOBES.y) * 0.7, _shape_rng.randf_range(0.0, TAU)]))
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
	var step := clampf((target_z - entry.y) / (float(node_count) * 0.82), 9.5 * map_scale, 18.0 * map_scale)

	var heading := PI * 0.5
	var straight := 0
	var point := entry
	var previous_wide := true  # the entry adit counts as wide, so node 1 necks
	var level := 0
	for i in range(node_count):
		# A trunk that has reached the far edge stops there: further digs would
		# be clamped onto the same line and pile rooms into each other.
		if i > 0 and main_path[-1].y >= deepest - 0.5: break
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
			var pillars := ELEMENT_PILLARS_CAVE if region_id in CAVE_REGIONS else (Vector2i.ZERO if region_id == "siracusa" else ELEMENT_PILLARS)
			for p in range(_rng.randi_range(pillars.x, pillars.y)):
				var angle := _rng.randf_range(0.0, TAU)
				var offset := Vector2(cos(angle), sin(angle)) * _rng.randf_range(3.5, radius - 6.0)
				if offset.length() < 2.0: continue
				# Floor on the radius, not just a pleasing range: the terrain
				# contour is sampled on a 1.5 grid, and a pillar much narrower
				# than a couple of cells does not reliably close into wall
				# geometry — it stops blocking line of sight, which quietly
				# takes away the cover a fight in that arena depends on.
				# The narrowest point of the outline still stays above 1.7.
				# Size from the layout's RNG (one draw, as before); the outline from
				# its own, so reshaping pillars never reshuffles the rest of a map.
				var pillar_r := _rng.randf_range(PILLAR_RADIUS.x, PILLAR_RADIUS.y)
				var shape := PackedFloat32Array([_shape_rng.randf_range(1.0, 1.4), _shape_rng.randf_range(0.0, PI),
					_shape_rng.randf_range(0.04, 0.12), _shape_rng.randf_range(0.0, TAU), _shape_rng.randf_range(0.03, 0.09), _shape_rng.randf_range(0.0, TAU)])
				# The whole outline stays inside the arena with a walkable ring
				# around it, and never reaches past PILLAR_MAX_REACH: a long
				# rock must not wall off a cache or a corridor mouth.
				var reach := pillar_r * shape[0] * (1.0 + shape[2] + shape[4])
				var room := maxf(PILLAR_RADIUS.x, minf(PILLAR_MAX_REACH, radius - offset.length() - 3.5))
				if reach > room:
					pillar_r *= room / reach
					if pillar_r < 1.9: shape[0] = 1.0
				_closed_circles.append(Vector3(point.x + offset.x, point.y + offset.y, pillar_r))
				_pillar_shapes.append(shape)

	_dig_spurs(main_path.size())
	_dig_crossings()
	_dig_extras(main_path.size())

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
		var reach := _rng.randf_range(24.0, 42.0) * map_scale
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
		var further := end + onward * (radius + _rng.randf_range(14.0, 26.0) * map_scale)
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
			if not _clear_of_crossings([_spur_point(i), _spur_point(j)], 6.0): continue
			_link(_circle_at(_spur_point(i)), _circle_at(_spur_point(j)), _corridor_width() * 0.85, TRAIL_BRANCH)

	for i in range(_rng.randi_range(ELEMENT_NICHES.x, ELEMENT_NICHES.y)):
		if _spur_anchors.is_empty(): break
		var pick := _rng.randi_range(0, _spur_anchors.size() - 1)
		var spur := _spur_point(pick)
		var outward: float = _spur_anchors[pick].y
		var niche := Vector2(
			clampf(spur.x + outward * _rng.randf_range(11.0, 17.0) * map_scale, SPINE_MIN.x + 8.0, SPINE_MAX.x - 8.0),
			clampf(spur.y + _rng.randf_range(-13.0, 13.0), SPINE_MIN.y + 8.0, SPINE_MAX.y - 8.0))
		if niche.distance_to(spur) < 9.0 or _too_near(niche, niche_centres, 12.0): continue
		if not _clear_of_crossings([spur, niche], 6.0) or not _clear_of_crossings([niche], 6.0 + 4.0): continue
		var spur_room := _circle_at(spur)
		var room := _add_circle(niche, _rng.randf_range(4.5, 6.0), "niche", _trunk_levels[spur_room])
		_link(spur_room, room, _rng.randf_range(2.8, 3.6) + (CAVE_WIDEN if region_id in CAVE_REGIONS else 0.0), TRAIL_BRANCH)
		niche_centres.append(niche)

	for i in range(_rng.randi_range(ELEMENT_SKIPS.x, ELEMENT_SKIPS.y)):
		if _spur_anchors.is_empty(): break
		var pick := _rng.randi_range(0, _spur_anchors.size() - 1)
		var rejoin := int(_spur_anchors[pick].x) + _rng.randi_range(3, 4)
		if rejoin >= main_path.size(): continue
		if not _clear_of_crossings([_spur_point(pick), main_path[rejoin]], 6.0): continue
		_link(_circle_at(_spur_point(pick)), rejoin, _corridor_width() * 0.8, TRAIL_BRANCH)

	var loops := ELEMENT_LOOPS_CAVE if region_id in CAVE_REGIONS else ELEMENT_LOOPS
	for i in range(_rng.randi_range(loops.x, loops.y)):
		var anchor := _rng.randi_range(1, maxi(1, node_count - 4))
		if anchor + 2 >= main_path.size(): continue
		var base: Vector2 = main_path[anchor]
		var side := 1.0 if _rng.randf() < 0.5 else -1.0
		var reach := _rng.randf_range(26.0, 44.0) * map_scale
		var near := Vector2(clampf(base.x + side * reach, SPINE_MIN.x + 10.0, SPINE_MAX.x - 10.0), base.y + _rng.randf_range(-4.0, 6.0))
		var far := Vector2(clampf(near.x + side * _rng.randf_range(-6.0, 10.0), SPINE_MIN.x + 10.0, SPINE_MAX.x - 10.0), near.y + _rng.randf_range(16.0, 30.0) * map_scale)
		if _too_near(near, loop_centres, 16.0): continue
		if not _clear_of_crossings([base, near, far, main_path[anchor + 2]], 6.0) or not _clear_of_crossings([near], 7.5 + 4.0) or not _clear_of_crossings([far], 7.0 + 4.0): continue
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
		clampf(vault_base.x + vault_side * _rng.randf_range(26.0, 36.0) * map_scale, SPINE_MIN.x + 11.0, SPINE_MAX.x - 11.0),
		clampf(vault_base.y + _rng.randf_range(4.0, 14.0), SPINE_MIN.y + 11.0, SPINE_MAX.y - 11.0))
	# The vault always gets dug; it only keeps off a bridge's road if the
	# other flank has room.
	if not _clear_of_crossings([vault_base, vault], 6.0) or not _clear_of_crossings([vault], 9.0 + 4.0):
		var mirrored := Vector2(clampf(2.0 * vault_base.x - vault.x, SPINE_MIN.x + 11.0, SPINE_MAX.x - 11.0), vault.y)
		if _clear_of_crossings([vault_base, mirrored], 6.0) and _clear_of_crossings([mirrored], 9.0 + 4.0): vault = mirrored
	var vault_radius := _rng.randf_range(7.5, 9.0)
	var vault_width := _rng.randf_range(3.2, 3.8)
	# The room needs rock all round it: tried where it was rolled, then on the
	# other flank and further out; with nowhere clear, no vault this floor.
	if has_vault:
		var tries: Array[Vector2] = [vault, Vector2(2.0 * vault_base.x - vault.x, vault.y)]
		for push in [1.3, 1.6]:
			for flank in [1.0, -1.0]:
				tries.append(Vector2(vault_base.x + (vault.x - vault_base.x) * push * flank, vault.y))
		var clear := false
		for spot in tries:
			spot = Vector2(clampf(spot.x, SPINE_MIN.x + 11.0, SPINE_MAX.x - 11.0), spot.y)
			if _vault_clear(spot, vault_base):
				vault = spot
				clear = true
				break
		has_vault = clear
	vault_centre = vault
	if has_vault:
		_vault_room = _add_circle(vault, vault_radius, "vault", _trunk_levels[vault_index])
		_vault_link = _links.size()
		_link(vault_index, _vault_room, vault_width, TRAIL_BRANCH)
		vault_excluded = true
	else:
		# The same draws a dug vault takes, so the rest of the floor is the
		# same floor either way.
		for i in range(4): _shape_rng.randf()
		if region_id != "city": _rng.randf()
		_rng.randf()

## Whether a corridor through `points` (or, for one point, a room there) keeps
## `margin` past the stubs' width off every bridge road planned so far.
func _clear_of_crossings(points: Array, margin: float) -> bool:
	for crossing in _crossings:
		var road := PackedVector2Array([_centre(crossing.p), _centre(crossing.q)])
		if points.size() == 1:
			if _line_gap(PackedVector2Array([points[0]]), road) < margin + BRIDGE_HALF_WIDTH: return false
			continue
		for k in range(points.size() - 1):
			if _line_gap(PackedVector2Array([points[k], points[k + 1]]), road) < margin + BRIDGE_HALF_WIDTH + 2.0: return false
	return true

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
	# Every Siracusa lane, the scaled and fixed ones too, stays in LANE_WIDTH:
	# narrower ones leave no standing ground on the sampling grid once they kink.
	if region_id == "siracusa": width = clampf(width, LANE_WIDTH.x, LANE_WIDTH.y)
	var start := Vector2(_open_circles[a].x, _open_circles[a].y)
	var end := Vector2(_open_circles[b].x, _open_circles[b].y)
	var middle := (start + end) * 0.5
	if region_id == "city":
		middle = Vector2(start.x, end.y) if absf(end.x - start.x) > 8 else middle
	elif region_id == "siracusa":
		# A lane kinks once, well off the straight line, at no particular angle.
		var direction := (end - start).normalized()
		var bend := _rng.randf_range(-1.0, 1.0)
		var length := start.distance_to(end)
		middle += Vector2(-direction.y, direction.x) * signf(bend) * lerpf(LANE_KINK.x, LANE_KINK.y, absf(bend)) * length
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
	# A crossing's corridor runs level under its deck, and its two rooms and
	# the rooms they are tied back to stand at that corridor's tier, so each
	# ramp up to the deck has the rise it was dug for: BRIDGE_RISE.
	for crossing in _crossings:
		var under: Dictionary = _links[crossing.lower]
		_tie(group, [int(under.a), int(under.b), int(crossing.p), int(crossing.back_p), int(crossing.q), int(crossing.back_q)])
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
	return r * 1.1 + 1.0 if urban else r

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
		var pairs := [[a, middle], [middle, b]]
		# A bridge's road is two stubs; the gap between them is the deck's.
		if link.has("bridge"):
			var bridge: Dictionary = bridges[link.bridge]
			var direction: Vector2 = bridge.dir
			pairs = [[a, a + direction * (float(bridge.along) - float(bridge.cut))], [a + direction * (float(bridge.along) + float(bridge.cut)), b]]
		for pair in pairs:
			var start: Vector2 = pair[0]
			var end: Vector2 = pair[1]
			var length := start.distance_to(end)
			if length < 0.1: continue
			along = Vector2(_open_circles[link.a].x, _open_circles[link.a].y).distance_to(start) if link.has("bridge") else along
			# x, z, x, z, half-width, link, arc length at start, at end.
			var segment := PackedFloat32Array([start.x, start.y, end.x, end.y, link.width, index, along, along + length])
			along += length
			_open_segments.append(segment)
			if link.trail: _main_segments.append(segment)
	_build_shape_grid()

## Crossings: dug right after the branches, while the rock between them is
## still whole. Across the middle of a branch corridor (the longest straight
## runs on the floor) a room is dug well out to either side, and each is tied
## back to its nearest room on its own side. When the tiers allow
## (_crossing_option) the two are joined by a road over that corridor: up a
## ramp from one, over a bridge two tiers above it, down to the other — so the
## loop through them passes over the branch without meeting it. From their own
## RNG, so nothing dug before them moves.
func _dig_crossings() -> void:
	if not region_id in BRIDGE_REGIONS: return
	var dig := RandomNumberGenerator.new()
	dig.seed = seed_value ^ 0x0ee7a5
	# Branch corridors first (shuffled), then the trunk's.
	var order: Array[int] = []
	var trunk: Array[int] = []
	for index in range(_links.size()):
		if circle_kinds[_links[index].b] == "spur": order.append(index)
		elif circle_kinds[_links[index].a] == "trunk" and circle_kinds[_links[index].b] == "trunk": trunk.append(index)
	for list in [order, trunk]:
		for i in range(list.size() - 1, 0, -1):
			var j := dig.randi_range(0, i)
			var swap: int = list[i]
			list[i] = list[j]
			list[j] = swap
	order.append_array(trunk)
	for index in order:
		if _crossings.size() >= BRIDGE_MAX: break
		_try_crossing(index, dig)

func _try_crossing(lower: int, dig: RandomNumberGenerator) -> void:
	var link: Dictionary = _links[lower]
	for other in _crossings:
		var taken := [int(_links[other.lower].a), int(_links[other.lower].b)]
		if taken.has(int(link.a)) or taken.has(int(link.b)): return
	var line := _link_points(lower)
	var total: float = link.length
	var lo: float = _open_circles[link.a].z + 2.0
	var hi: float = total - _open_circles[link.b].z - 2.0
	if hi < lo: return
	var at := lerpf(lo, hi, dig.randf_range(0.35, 0.65))
	var cross := line[0]
	var heading := Vector2.RIGHT
	var walked := 0.0
	for k in range(line.size() - 1):
		var piece := line[k].distance_to(line[k + 1])
		if walked + piece >= at or k == line.size() - 2:
			heading = (line[k + 1] - line[k]).normalized()
			cross = line[k].lerp(line[k + 1], clampf((at - walked) / maxf(piece, 0.001), 0.0, 1.0))
			break
		walked += piece
	var radius := dig.randf_range(5.0, 6.5)
	for turn in [0.0, 0.2, -0.2]:
		var normal := heading.orthogonal().rotated(turn)
		var sine := absf(normal.cross(heading))
		# The corridor as dug there, swollen or flared, not as planned.
		var cut := _link_half_width(lower, at) / sine + BRIDGE_STUB_GAP
		# Room for each stub to ramp the whole rise from its room to the deck.
		var reach := cut + RAMP_APRON + BRIDGE_FLAT + BRIDGE_RAMP_RUN * BRIDGE_RISE + radius + 1.0
		# Each side on its own: the nearest of a few distances out where the
		# room fits and the stub back to the corridor runs through rock.
		var p := _crossing_spot(cross, -normal, cut, reach, radius, lower)
		var q := _crossing_spot(cross, normal, cut, reach, radius, lower)
		if p == Vector2.INF or q == Vector2.INF: continue
		var back_p := _crossing_anchor(p, radius, -normal, cross, lower)
		var back_q := _crossing_anchor(q, radius, normal, cross, lower)
		if back_p < 0 or back_q < 0: continue
		# Nor across a bridge road already planned.
		if not _clear_of_crossings([p], radius + 2.0) or not _clear_of_crossings([q], radius + 2.0): continue
		if not _clear_of_crossings([p, q], 2.0) or not _clear_of_crossings([p, _centre(back_p)], 6.0) or not _clear_of_crossings([q, _centre(back_q)], 6.0): continue
		var room_p := _add_circle(p, radius, "crossing", _trunk_levels[back_p])
		var room_q := _add_circle(q, radius, "crossing", _trunk_levels[back_q])
		_link(back_p, room_p, _corridor_width(), TRAIL_BRANCH)
		_link(back_q, room_q, _corridor_width(), TRAIL_BRANCH)
		_crossings.append({"p": room_p, "q": room_q, "lower": lower, "heading": heading, "back_p": back_p, "back_q": back_q})
		return

func _crossing_spot(cross: Vector2, outward: Vector2, cut: float, reach: float, radius: float, lower: int) -> Vector2:
	for extra in [0.0, 3.0, 6.0, 9.0]:
		var room: Vector2 = cross + outward * (reach + extra)
		if not _crossing_room_ok(room, radius, lower): continue
		var s := cut
		while s < reach + extra - radius:
			if not _bridge_clear(cross + outward * s, -1, -1, -1, lower): return Vector2.INF
			s += 1.5
		return room
	return Vector2.INF

func _crossing_room_ok(point: Vector2, radius: float, lower: int) -> bool:
	if point.x < SPINE_MIN.x + radius + 4.0 or point.x > SPINE_MAX.x - radius - 4.0: return false
	if point.y < SPINE_MIN.y + radius + 4.0 or point.y > SPINE_MAX.y - radius - 4.0: return false
	return _bridge_clear(point, -1, -1, -1, lower, radius + 1.0)

## The nearest room on the crossing room's own side of the corridor below
## that a straight corridor from `point` reaches through rock without
## crossing anything; -1 if none.
func _crossing_anchor(point: Vector2, radius: float, outward: Vector2, cross: Vector2, lower: int) -> int:
	var best := -1
	var best_distance := INF
	for i in range(_open_circles.size()):
		var centre := _centre(i)
		# Well on this side: a corridor back to the crossed corridor's own
		# rooms would run along beside the stub.
		if (centre - cross).dot(outward) < _open_circles[i].z + radius: continue
		var distance := point.distance_to(centre)
		if distance >= best_distance or distance > 55.0: continue
		var crossed := false
		for index in range(_links.size()):
			if [int(_links[index].a), int(_links[index].b)].has(i): continue
			var line := _link_points(index)
			for k in range(line.size() - 1):
				if Geometry2D.segment_intersects_segment(point, centre, line[k], line[k + 1]) != null: crossed = true
		if crossed: continue
		var direction := (centre - point) / distance
		var clear := true
		var s := radius + 1.5
		while s < distance - _open_circles[i].z - 1.0 and clear:
			clear = _bridge_clear(point + direction * s, i, -1, -1, lower, 5.6 + CAVE_WIDEN)
			s += 1.5
		if not clear: continue
		best = i
		best_distance = distance
	return best

## The road over a crossing's corridor, on the tiers this attempt settled:
## the corridor level, two tiers under the deck, and the run for each side's
## ramp; {} if not (the two rooms then stay as two dead ends).
func _crossing_option(crossing: Dictionary) -> Dictionary:
	var a: int = crossing.p
	var b: int = crossing.q
	var lower: int = crossing.lower
	var under: Dictionary = _links[lower]
	if not under.alive or levels[under.a] != levels[under.b]: return {}
	var deck_tier: int = levels[under.a] + BRIDGE_RISE
	if deck_tier > MAX_TIER + 2: return {}
	var from := _centre(a)
	var to := _centre(b)
	var gap := from.distance_to(to)
	var direction := (to - from) / gap
	var line := _link_points(lower)
	var cross := from.lerp(to, 0.5)
	var heading: Vector2 = crossing.heading
	for k in range(line.size() - 1):
		var hit: Variant = Geometry2D.segment_intersects_segment(from, to, line[k], line[k + 1])
		if hit != null:
			cross = hit
			heading = (line[k + 1] - line[k]).normalized()
	var along := from.distance_to(cross)
	var sine := absf(direction.cross(heading))
	var cut := _link_half_width(lower, _arc_on_link(lower, cross)) / sine + BRIDGE_STUB_GAP
	if along - cut - _open_circles[a].z - RAMP_APRON - BRIDGE_FLAT < BRIDGE_RAMP_RUN * (deck_tier - levels[a]): return {}
	if gap - along - cut - _open_circles[b].z - RAMP_APRON - BRIDGE_FLAT < BRIDGE_RAMP_RUN * (deck_tier - levels[b]): return {}
	# What was dug after the crossing may have come too close.
	var s: float = _open_circles[a].z
	while s <= gap - _open_circles[b].z:
		if absf(s - along) >= cut and not _bridge_clear(from + direction * s, a, b, -1, lower): return {}
		s += 1.5
	return {"a": a, "b": b, "lower": lower, "cross": cross, "dir": direction, "cut": cut, "along": along,
		"top": float(deck_tier) * TIER, "under": heading}

## City districts (用户 2026-10-14: 随机结构；真实高度，区分不同区域的城景;
## 城市地图调研与方案_v1.md): one to four district seeds over the floor, each
## of a kind, a point belonging to its nearest seed. A floor can be one
## district throughout (all slums, all streets) or a mix; where the slums meet
## another district a quarantine wall stands (CityDressing).
const DISTRICT_KINDS := ["street", "slum", "yard", "site"]
var districts: Array[Dictionary] = []

## Siracusa's districts are the families' turfs (叙拉古方案 §3.1, 用户 2026-10-16:
## 血债不分开 — so only the look follows them): two or three per floor.
const FAMILIES := ["saluzzo", "rossetti", "bellone"]

func _roll_districts() -> void:
	districts.clear()
	if region_id == "siracusa":
		var turf := RandomNumberGenerator.new()
		turf.seed = seed_value ^ 0xfa111
		var families: Array = FAMILIES.duplicate()
		for i in range(families.size() - 1, 0, -1):
			var j := turf.randi_range(0, i)
			var swap = families[i]
			families[i] = families[j]
			families[j] = swap
		var count := turf.randi_range(2, 3)
		# Spread along the trunk: the entry's family, then deeper ones.
		for k in range(count):
			var at := main_path[clampi(int(float(main_path.size() - 1) * float(k) / float(maxi(1, count - 1))), 0, main_path.size() - 1)]
			districts.append({"point": at + Vector2(turf.randf_range(-12.0, 12.0), 0.0), "kind": families[k]})
		return
	if region_id != "city": return
	var roll := RandomNumberGenerator.new()
	roll.seed = seed_value ^ 0xd157
	var count := roll.randi_range(1, 4)
	for i in range(count):
		var room := roll.randi_range(0, _open_circles.size() - 1)
		districts.append({"point": _centre(room), "kind": DISTRICT_KINDS[roll.randi_range(0, DISTRICT_KINDS.size() - 1)]})
	# The entry is always a street: the floor starts at a checkpoint.
	districts[0].point = _centre(0)
	districts[0].kind = "street"

## The district kind at x/z ("" outside the city).
func district_at(point: Vector2) -> String:
	if districts.is_empty(): return ""
	var best := 0
	for i in range(1, districts.size()):
		if point.distance_squared_to(districts[i].point) < point.distance_squared_to(districts[best].point): best = i
	return districts[best].kind

func _centre(i: int) -> Vector2:
	return Vector2(_open_circles[i].x, _open_circles[i].y)

## Picks up to BRIDGE_MAX overpasses on the tiers just assigned, from every
## pair of rooms that could carry one, with its own RNG so the layout does not
## move. Each becomes a link (so walk distances, the exit choice and the
## guards see the way over) whose two stubs _build_segments digs.
func _plan_bridges() -> void:
	if not region_id in BRIDGE_REGIONS: return
	# The crossings dug for bridges first, then any other pair that happens to
	# have a corridor between them.
	var planned: Array[Dictionary] = []
	for crossing in _crossings:
		var option := _crossing_option(crossing)
		if not option.is_empty(): planned.append(option)
	var options: Array[Dictionary] = []
	for a in range(_open_circles.size()):
		for b in range(a + 1, _open_circles.size()):
			# No bridge to or over the vault: it is not there until it opens.
			if a == _vault_room or b == _vault_room: continue
			var option := _bridge_option(a, b)
			if not option.is_empty() and (_vault_link < 0 or int(option.get("lower", -1)) != _vault_link): options.append(option)
	var pick_rng := RandomNumberGenerator.new()
	pick_rng.seed = seed_value ^ 0xb81d6e
	while bridges.size() < BRIDGE_MAX and not (planned.is_empty() and options.is_empty()):
		var option: Dictionary = planned.pop_front() if not planned.is_empty() else options.pop_at(pick_rng.randi_range(0, options.size() - 1))
		var apart := true
		for other in bridges:
			# Two bridges share no room, no lower corridor and no stretch of rock.
			var rooms := [int(other.a), int(other.b)]
			if rooms.has(int(option.a)) or rooms.has(int(option.b)) or (int(other.lower) >= 0 and int(other.lower) == int(option.lower)): apart = false
			elif _segments_gap(other, option) < BRIDGE_HALF_WIDTH * 2.0 + BRIDGE_CLEAR: apart = false
		if not apart: continue
		option.link = _links.size()
		_links.append({"a": option.a, "b": option.b, "middle": option.cross, "width": BRIDGE_HALF_WIDTH,
			"trail": false, "length": _centre(option.a).distance_to(_centre(option.b)), "alive": true, "bridge": bridges.size()})
		bridges.append(option)

func _segments_gap(one: Dictionary, other: Dictionary) -> float:
	return _line_gap(PackedVector2Array([_centre(one.a), _centre(one.b)]), PackedVector2Array([_centre(other.a), _centre(other.b)]))

## A straight road from room a to room b that crosses exactly one corridor,
## steeply enough to read as passing over it, and otherwise runs through solid
## rock. It climbs from each room to a deck two tiers over that corridor and
## needs the run for those ramps either side; {} when the pair cannot carry one.
func _bridge_option(a: int, b: int) -> Dictionary:
	var from := _centre(a)
	var to := _centre(b)
	var gap := from.distance_to(to)
	if gap < BRIDGE_ROOM_GAP.x or gap > BRIDGE_ROOM_GAP.y: return {}
	var direction := (to - from) / gap
	var lower := -1
	var cross := Vector2.ZERO
	var sine := 0.0
	for index in range(_links.size()):
		var link: Dictionary = _links[index]
		if not link.alive: continue
		var ends := [int(link.a), int(link.b)]
		if ends.has(a) and ends.has(b): return {}
		# Its own rooms' corridors meet the road in those rooms, not across it.
		if ends.has(a) or ends.has(b): continue
		var line := _link_points(index)
		for k in range(line.size() - 1):
			var hit: Variant = Geometry2D.segment_intersects_segment(from, to, line[k], line[k + 1])
			if hit == null: continue
			if lower >= 0 and lower != index: return {}
			lower = index
			cross = hit
			sine = absf(direction.cross((line[k + 1] - line[k]).normalized()))
	if lower < 0 or sine < 0.55: return {}
	var under: Dictionary = _links[lower]
	var under_ends := [int(under.a), int(under.b)]
	if under_ends.has(a) or under_ends.has(b): return {}
	var deck_tier: int = levels[under.a] + BRIDGE_RISE
	if levels[under.b] != levels[under.a] or deck_tier > MAX_TIER + 1: return {}
	for end in under_ends:
		if cross.distance_to(_centre(end)) < _open_circles[end].z + BRIDGE_HALF_WIDTH + 2.5: return {}
	var along := from.distance_to(cross)
	var cut := _link_half_width(lower, _arc_on_link(lower, cross)) / sine + BRIDGE_STUB_GAP
	if along - cut < _open_circles[a].z + 5.0 or gap - along - cut < _open_circles[b].z + 5.0: return {}
	# Each side climbs from its room's tier to the deck's over its own stub.
	if along - cut - _open_circles[a].z - RAMP_APRON - BRIDGE_FLAT < BRIDGE_RAMP_RUN * (deck_tier - levels[a]): return {}
	if gap - along - cut - _open_circles[b].z - RAMP_APRON - BRIDGE_FLAT < BRIDGE_RAMP_RUN * (deck_tier - levels[b]): return {}
	var s: float = _open_circles[a].z
	while s <= gap - _open_circles[b].z:
		if absf(s - along) >= cut and not _bridge_clear(from + direction * s, a, b, lower): return {}
		s += 1.5
	var under_line := _link_points(lower)
	return {"a": a, "b": b, "lower": lower, "cross": cross, "dir": direction, "cut": cut, "along": along, "top": float(deck_tier) * TIER,
		"under": (under_line[2] - under_line[0]).normalized()}

## Rock enough round `point` of a stub: no room, corridor or pillar near it
## but the bridge's own. Under a crossing, the corridor it passes over (`soft`)
## and that corridor's two rooms may come closer: the stub stands two tiers
## over them, so they need only stay off its centre line.
func _bridge_clear(point: Vector2, a: int, b: int, lower: int, soft: int = -1, own_reach: float = -1.0) -> bool:
	var reach := (own_reach if own_reach > 0.0 else BRIDGE_HALF_WIDTH) + BRIDGE_CLEAR + (CAVE_WARP if region_id in CAVE_REGIONS else 0.0)
	var below := own_reach + 1.0 if own_reach > 0.0 else 1.0
	var soft_rooms := [int(_links[soft].a), int(_links[soft].b)] if soft >= 0 else []
	for i in range(_open_circles.size()):
		if i == a or i == b: continue
		if point.distance_to(_centre(i)) - _room_reach(i) < (below if soft_rooms.has(i) else reach): return false
	for index in range(_links.size()):
		var link: Dictionary = _links[index]
		if not link.alive or index == lower: continue
		if index == soft:
			if _point_line_gap(point, _link_points(index)) - float(link.width) < below: return false
			continue
		# Corridors out of the bridge's own rooms meet it inside those rooms.
		var own := -1
		if [int(link.a), int(link.b)].has(a): own = a
		elif [int(link.a), int(link.b)].has(b): own = b
		if own >= 0 and point.distance_to(_centre(own)) < _open_circles[own].z + reach + 2.0: continue
		if _point_line_gap(point, _link_points(index)) - float(link.width) < reach: return false
	for i in range(_closed_circles.size()):
		if point.distance_to(Vector2(_closed_circles[i].x, _closed_circles[i].y)) - pillar_reach(i) < BRIDGE_HALF_WIDTH + 1.0: return false
	return true

## Where `planned` lands in the world: the inverse of the cave warp.
func _unwarp(planned: Vector2) -> Vector2:
	var point := planned
	for i in range(8): point = planned - (warped(point) - point)
	return point

## Each bridge measured on the sampled terrain: the cliff lines the deck spans
## between, and checks that the road below lies the full rise under it and
## the stubs' floor meets it at each end. A bridge that fails is not built:
## its stubs are filled in again and the terrain sampled once more.
func _settle_bridges() -> void:
	if bridges.is_empty(): return
	var failed := false
	for bridge in bridges:
		if _settle_bridge(bridge): continue
		failed = true
		_links[bridge.link].alive = false
	if not failed: return
	_build_segments()
	_surface.sample(self)
	var kept: Array[Dictionary] = []
	for bridge in bridges:
		if not _links[bridge.link].alive: continue
		_links[bridge.link].bridge = kept.size()
		kept.append(bridge)
	bridges = kept

func _settle_bridge(bridge: Dictionary) -> bool:
	var top: float = bridge.top
	var cross := _unwarp(bridge.cross)
	var axis := (_unwarp(bridge.cross + bridge.dir * 6.0) - _unwarp(bridge.cross - bridge.dir * 6.0)).normalized()
	if _surface.ground_at(cross) > top - TIER * BRIDGE_RISE + 0.4: return false
	var across := axis.orthogonal()
	# The cliff lines across the deck's whole width: the far edge of each,
	# where the crossing is oblique.
	var near := -1.0
	var far := -1.0
	for side in [-1.0, 0.0, 1.0]:
		var line: Vector2 = cross + across * side * DECK_HALF_WIDTH
		var to_near := _cliff_along(line, -axis, top)
		var to_far := _cliff_along(line, axis, top)
		if to_near < 0.0 or to_far < 0.0: return false
		near = maxf(near, to_near)
		far = maxf(far, to_far)
	var start := cross - axis * near
	var end := cross + axis * far
	var span := near + far
	if span < 3.0 or span > 18.0: return false
	for under in [cross, start.lerp(end, 0.3), start.lerp(end, 0.7), cross + across * (DECK_HALF_WIDTH - 0.8), cross - across * (DECK_HALF_WIDTH - 0.8)]:
		if _surface.ground_at(under) > top - TIER * BRIDGE_RISE + 0.4: return false
	for foot in [start - axis * (DECK_OVERLAP - 0.3), end + axis * (DECK_OVERLAP - 0.3)]:
		for side in [-1.0, 0.0, 1.0]:
			var on: Vector2 = foot + across * side * (DECK_HALF_WIDTH - 0.9)
			if _surface.distance_at(on) < 0.1 or absf(_surface.ground_at(on) - top) > 0.15: return false
	bridge.centre = (start + end) * 0.5
	bridge.axis = axis
	bridge.span = span
	bridge.base = _surface.ground_at(cross)
	return true

## Distance from `origin` along `direction` to where the ground climbs to `top`.
func _cliff_along(origin: Vector2, direction: Vector2, top: float) -> float:
	var t := 0.0
	while t < 14.0:
		if _surface.ground_at(origin + direction * t) >= top - 0.3: return maxf(0.0, t - 0.125)
		t += 0.25
	return -1.0

## The arch's cliff lines stand this far apart in the model (build_snow_bridge.py SPAN).
const BRIDGE_MODEL_SPAN := 10.0

## The arch and its deck: the Blender piece stretched to the span, a slab
## flush with the stubs' floor to walk on, and walls along both sides.
func _build_bridges() -> void:
	var scene := load(BRIDGE_MODELS.get(region_id, BRIDGE_MODELS.snow)) as PackedScene
	for i in range(bridges.size()):
		var bridge: Dictionary = bridges[i]
		var axis: Vector2 = bridge.axis
		var x := Vector3(axis.x, 0.0, axis.y)
		var root := Node3D.new()
		root.name = "Bridge%d" % i
		_generated_root.add_child(root)
		root.transform = Transform3D(Basis(x, Vector3.UP, x.cross(Vector3.UP)), Vector3(bridge.centre.x, bridge.top, bridge.centre.y))
		if scene != null:
			var arch := MeshInstance3D.new()
			arch.name = "Arch"
			arch.mesh = TerraceDressing.kit_mesh(scene)
			arch.scale = Vector3(float(bridge.span) / BRIDGE_MODEL_SPAN, 1.0, 1.0)
			root.add_child(arch)
		var length := float(bridge.span) + 2.0 * DECK_OVERLAP
		var deck := StaticBody3D.new()
		deck.name = "Deck"
		root.add_child(deck)
		_box_shape(deck, Vector3(length, 0.6, DECK_HALF_WIDTH * 2.0 + 0.4), Vector3(0, -0.3, 0))
		var walls := StaticBody3D.new()
		walls.name = "DeckWalls"
		walls.add_to_group("world_obstacle")
		root.add_child(walls)
		for side in [-1.0, 1.0]:
			_box_shape(walls, Vector3(length, 3.4, 0.2), Vector3(0, 1.4, side * (DECK_HALF_WIDTH + 0.1)))

func _box_shape(body: StaticBody3D, size: Vector3, at: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	body.add_child(shape)

## Rooms the floor has to connect: all of them, from the entry.
func _reach_targets() -> Array[Vector2]:
	var targets: Array[Vector2] = []
	for i in range(_open_circles.size()):
		if vault_excluded and i == _vault_room: continue
		targets.append(Vector2(_open_circles[i].x, _open_circles[i].y))
	return targets

func _link_height(link: Dictionary, s: float) -> float:
	# A bridge's road: up from room a to the deck, level over it, down to b.
	if link.has("bridge"):
		var bridge: Dictionary = bridges[link.bridge]
		var top: float = bridge.top
		var lo: float = float(bridge.along) - float(bridge.cut) - BRIDGE_FLAT
		var hi: float = float(bridge.along) + float(bridge.cut) + BRIDGE_FLAT
		if s <= lo:
			var start: float = _open_circles[link.a].z + RAMP_APRON
			return lerpf(float(levels[link.a]) * TIER, top, clampf((s - start) / maxf(lo - start, 0.001), 0.0, 1.0))
		if s >= hi:
			var end: float = float(link.length) - _open_circles[link.b].z - RAMP_APRON
			return lerpf(top, float(levels[link.b]) * TIER, clampf((s - hi) / maxf(end - hi, 0.001), 0.0, 1.0))
		return top
	var ha := float(levels[link.a]) * TIER
	var hb := float(levels[link.b]) * TIER
	if ha == hb: return ha
	var start: float = _open_circles[link.a].z + RAMP_APRON
	var end: float = float(link.length) - _open_circles[link.b].z - RAMP_APRON
	if end <= start: return ha if s < float(link.length) * 0.5 else hb
	# The climb takes its RAMP_RUN per tier in the middle of the free run and no
	# more: spread over a long corridor it would be too gentle to read (and
	# to dress), so the rest of the corridor stays level.
	var run := minf(end - start, RAMP_RUN * absf(hb - ha) / TIER)
	var middle := (start + end) * 0.5
	return lerpf(ha, hb, clampf((s - (middle - run * 0.5)) / maxf(run, 0.001), 0.0, 1.0))

## Ground level the shape `owner` (from carved_distance) sets at `point`.
## Where the layout's shapes are read for `point`: itself, or in a cave
## region shifted by the warp (both components from one noise, offset).
func warped(point: Vector2) -> Vector2:
	if not region_id in CAVE_REGIONS: return point
	return point + Vector2(_warp.get_noise_2dv(point), _warp.get_noise_2dv(point + Vector2(431.0, -217.0))) * CAVE_WARP

func owner_height(owner: int, point: Vector2) -> float:
	point = warped(point)
	if owner >= 0: return float(levels[owner]) * TIER
	var segment: PackedFloat32Array = _open_segments[-owner - 1]
	var a := Vector2(segment[0], segment[1])
	var delta := Vector2(segment[2], segment[3]) - a
	var t := clampf((point - a).dot(delta) / maxf(delta.length_squared(), 0.001), 0, 1)
	return _link_height(_links[int(segment[5])], lerpf(segment[6], segment[7], t))

## Height of the walkable ground (or the rock's foot) at x/z, matching the mesh.
## `from_y` is the height of whoever asks: over a bridge, a walker up at its
## deck stands on the deck, anyone lower on the road beneath.
func ground_height(point: Vector2, from_y: float = -INF) -> float:
	var ground := _surface.ground_at(point) if _surface != null else 0.0
	if from_y > -INF:
		for bridge in bridges:
			if from_y >= float(bridge.top) - BRIDGE_REACH and ground < float(bridge.top) - 0.5 and on_deck(bridge, point): return float(bridge.top)
	return ground

## Whether x/z lies on `bridge`'s deck (`margin` wider either side).
func on_deck(bridge: Dictionary, point: Vector2, margin: float = 0.0) -> bool:
	if not bridge.has("centre"): return false
	var local: Vector2 = point - bridge.centre
	var axis: Vector2 = bridge.axis
	return absf(local.dot(axis)) <= float(bridge.span) * 0.5 + DECK_OVERLAP + margin and absf(local.dot(axis.orthogonal())) <= DECK_HALF_WIDTH + margin

## The bridge whose deck, or `margin` round it, covers x/z; {} if none.
func bridge_at(point: Vector2, margin: float = 0.0) -> Dictionary:
	for bridge in bridges:
		if on_deck(bridge, point, margin): return bridge
	return {}

## Where a ray from the camera meets a deck's top, if it meets one before
## the ground: Vector3.INF when none does.
func deck_hit(from: Vector3, direction: Vector3) -> Vector3:
	if absf(direction.y) < 0.0001: return Vector3.INF
	for bridge in bridges:
		var t := (float(bridge.top) - from.y) / direction.y
		if t < 0.0: continue
		var hit := from + direction * t
		if on_deck(bridge, Vector2(hit.x, hit.z)): return hit
	return Vector3.INF

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
		if not link.alive or levels[link.a] == levels[link.b] or link.has("bridge"): continue
		var piece: PackedVector2Array = _pieces[index * 3 + 1]
		if piece.size() < 2: continue
		var up := (piece[-1] - piece[0]).normalized() * (1.0 if levels[link.b] > levels[link.a] else -1.0)
		found.append({"point": piece[0].lerp(piece[-1], 0.5), "up": up, "link": index, "piece": piece})
	return found

func _segment_distance(point: Vector2, segment: PackedFloat32Array) -> float:
	var a := Vector2(segment[0], segment[1])
	var delta := Vector2(segment[2], segment[3]) - a
	# A city street runs along an axis and is measured square to it (the
	# chessboard distance): its end is a square cap, and where two shapes of
	# different tiers meet, the line between them is straight, not the curve
	# two round fields would draw.
	if region_id == "city" and (absf(delta.x) < 0.01 or absf(delta.y) < 0.01):
		var low := a.min(a + delta)
		var high := a.max(a + delta)
		var outside := Vector2(maxf(maxf(low.x - point.x, point.x - high.x), 0.0), maxf(maxf(low.y - point.y, point.y - high.y), 0.0))
		return maxf(outside.x, outside.y)
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
const BLEND := 4.5
## Street corners in the city stay sharp, just not knife-edged.
const CITY_BLEND := 1.2
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
	point = warped(point)
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
	# Only the shapes that can reach this part of the map (see _build_shape_grid).
	var cell := _shape_cell(point)
	var rooms: PackedInt32Array = _cell_rooms[cell] if cell >= 0 else _all_rooms
	var segments: PackedInt32Array = _cell_segments[cell] if cell >= 0 else _all_segments
	var pillars: PackedInt32Array = _cell_pillars[cell] if cell >= 0 else _all_pillars
	for i in rooms:
		if vault_excluded and i == _vault_room: continue
		var circle := _open_circles[i]
		var offset := point - Vector2(circle.x, circle.y)
		var reach := offset.length()
		# Its widest lobe bounds it, as for the corridors below.
		if not urban and circle.z * (1.0 + ROOM_LOBES.y * 1.7) - reach <= second: continue
		var chamber_distance := circle.z * _lobed(i, offset) - reach
		# The vault is a room (用户 2026-10-17: 密室做成房间的样子): square-walled,
		# VAULT_ROOM of its radius each way.
		if i == _vault_room:
			var q := offset.abs() - VAULT_ROOM
			chamber_distance = -maxf(q.x, q.y)
			if chamber_distance > best:
				second = best
				best = chamber_distance
				owner = i
			elif chamber_distance > second:
				second = chamber_distance
			continue
		if region_id == "city":
			var q := offset.abs() - Vector2(circle.z * 0.85, circle.z * 0.7)
			chamber_distance = -maxf(q.x, q.y) + 1.0
		elif region_id == "siracusa":
			chamber_distance = _square_distance(i, offset)
		if chamber_distance > best:
			second = best
			best = chamber_distance
			owner = i
		elif chamber_distance > second:
			second = chamber_distance
	for j in segments:
		var segment := _open_segments[j]
		if vault_excluded and int(segment[5]) == _vault_link: continue
		var away := _segment_distance(point, segment)
		# The widest this corridor gets anywhere bounds it: past that it cannot
		# be either of the two nearest shapes, and the swell is not worth reading.
		var link: Dictionary = _links[int(segment[5])]
		var widest: float = segment[4] if urban else maxf(segment[4] * (1.0 + CORRIDOR_SWELL), maxf(_open_circles[link.a].z, _open_circles[link.b].z) * CORRIDOR_FLARE + segment[4] * 0.5)
		if widest - away <= second: continue
		var corridor_distance: float = _corridor_half_width(segment, point) - away
		if corridor_distance > best:
			second = best
			best = corridor_distance
			owner = -(j + 1)
		elif corridor_distance > second:
			second = corridor_distance
	_last_owner = owner
	var distance := best if second <= -1e8 else _smooth_max(best, second, CITY_BLEND if urban else BLEND)
	# The vault room keeps its straight walls: no fillet swells it past them.
	if owner == _vault_room and _vault_room >= 0: distance = best
	for i in pillars:
		distance = _smooth_min(distance, _pillar_distance(i, point), PILLAR_BLEND)
	return distance

## Load time (用户 2026-10-13: 优化地图加载): carved_distance is read at every
## terrain sample and again while the mesh is built, and looping over every
## room, corridor and pillar each time was most of a floor's load. The map is
## cut into SHAPE_CELL squares, each listing the shapes whose field can reach
## above -SHAPE_REACH anywhere in it; nothing further off can be one of the two
## nearest there, and rock that deep reads the same however deep it is (the
## deepest anything looks is the snow mountains' rise, 18 m in). A square no
## shape reaches keeps its nearest room, so the rock there still takes a tier.
const SHAPE_CELL := 16.0
const SHAPE_REACH := 26.0
var _shape_origin := Vector2.ZERO
var _shape_columns := 0
var _shape_rows := 0
var _cell_rooms: Array[PackedInt32Array] = []
var _cell_segments: Array[PackedInt32Array] = []
var _cell_pillars: Array[PackedInt32Array] = []
var _all_rooms := PackedInt32Array()
var _all_segments := PackedInt32Array()
var _all_pillars := PackedInt32Array()

func _shape_cell(point: Vector2) -> int:
	if _cell_rooms.is_empty(): return -1
	var x := int(floor((point.x - _shape_origin.x) / SHAPE_CELL))
	var z := int(floor((point.y - _shape_origin.y) / SHAPE_CELL))
	if x < 0 or z < 0 or x >= _shape_columns or z >= _shape_rows: return -1
	return z * _shape_columns + x

func _build_shape_grid() -> void:
	_all_rooms = PackedInt32Array(range(_open_circles.size()))
	_all_segments = PackedInt32Array(range(_open_segments.size()))
	_all_pillars = PackedInt32Array(range(_closed_circles.size()))
	# The terrain samples the bounds and a 36 m apron, the warp shifts by up
	# to CAVE_WARP; one cell more each side covers both.
	_shape_origin = SPINE_MIN - Vector2(36.0 + SHAPE_CELL, 36.0 + SHAPE_CELL)
	var far := SPINE_MAX + Vector2(36.0 + SHAPE_CELL, 36.0 + SHAPE_CELL)
	_shape_columns = ceili((far.x - _shape_origin.x) / SHAPE_CELL)
	_shape_rows = ceili((far.y - _shape_origin.y) / SHAPE_CELL)
	_cell_rooms.clear()
	_cell_segments.clear()
	_cell_pillars.clear()
	var half := SHAPE_CELL * 0.5 * sqrt(2.0)
	for z in range(_shape_rows):
		for x in range(_shape_columns):
			var centre := _shape_origin + Vector2(x + 0.5, z + 0.5) * SHAPE_CELL
			var rooms := PackedInt32Array()
			var nearest := 0
			var nearest_gap := INF
			for i in range(_open_circles.size()):
				var circle := _open_circles[i]
				var gap := centre.distance_to(Vector2(circle.x, circle.y)) - _room_reach(i) * (1.0 + ROOM_LOBES.y * 1.7) - half
				if gap <= SHAPE_REACH: rooms.append(i)
				if gap < nearest_gap:
					nearest_gap = gap
					nearest = i
			var segments := PackedInt32Array()
			for j in range(_open_segments.size()):
				var segment := _open_segments[j]
				var link: Dictionary = _links[int(segment[5])]
				var widest := maxf(segment[4] * (1.0 + CORRIDOR_SWELL), maxf(_open_circles[link.a].z, _open_circles[link.b].z) * CORRIDOR_FLARE + segment[4] * 0.5)
				if _segment_distance(centre, segment) - widest - half <= SHAPE_REACH: segments.append(j)
			if rooms.is_empty() and segments.is_empty(): rooms.append(nearest)
			var pillars := PackedInt32Array()
			for i in range(_closed_circles.size()):
				var pillar := _closed_circles[i]
				if centre.distance_to(Vector2(pillar.x, pillar.y)) - pillar_reach(i) - half <= SHAPE_REACH: pillars.append(i)
			_cell_rooms.append(rooms)
			_cell_segments.append(segments)
			_cell_pillars.append(pillars)

## Room i's rim at `offset` from its centre, as a share of its radius.
func _lobed(i: int, offset: Vector2) -> float:
	if urban or i >= _room_shapes.size(): return 1.0
	var shape := _room_shapes[i]
	var angle := offset.angle()
	return 1.0 + shape[0] * sin(2.0 * angle + shape[1]) + shape[2] * sin(3.0 * angle + shape[3])

## A corridor's half-width where `point` projects onto it: the planned width,
## swollen along the run, flared into the rooms at its ends.
func _corridor_half_width(segment: PackedFloat32Array, point: Vector2) -> float:
	var base: float = segment[4]
	var a := Vector2(segment[0], segment[1])
	var delta := Vector2(segment[2], segment[3]) - a
	var t := clampf((point - a).dot(delta) / maxf(delta.length_squared(), 0.001), 0.0, 1.0)
	return _link_half_width(int(segment[5]), lerpf(segment[6], segment[7], t))

## Link `index`'s half-width `s` metres along it (see _corridor_half_width).
func _link_half_width(index: int, s: float) -> float:
	var link: Dictionary = _links[index]
	var base: float = link.width
	# Lungmen's streets keep their width, kerb to kerb: the city is right-angled
	# (城市地图调研与方案_v1.md §1); its rooms blur into the roads by size instead.
	if urban: return base
	# The vault's passage keeps its width, door to door: no flare swells the room.
	if index == _vault_link: return base
	var swell := clampf(_swell.get_noise_2d(s, float(index) * 37.0) * 0.5 + 0.5, 0.0, 1.0)
	var width := base * (1.0 + CORRIDOR_SWELL * swell * swell)
	# A bridge's stubs keep their width: the deck is sized to them.
	if link.has("bridge"): return base
	var length: float = link.length
	for end in [[int(link.a), s], [int(link.b), length - s]]:
		var room: float = _open_circles[end[0]].z
		var near: float = end[1]
		width = maxf(width, lerpf(base, maxf(base, room * CORRIDOR_FLARE + base * 0.5), 1.0 - smoothstep(room * 0.7, room + 7.0, near)))
	return width

## How far along link `index` the point nearest `point` lies.
func _arc_on_link(index: int, point: Vector2) -> float:
	var line := _link_points(index)
	var best := INF
	var arc := 0.0
	var along := 0.0
	for k in range(line.size() - 1):
		var closest := Geometry2D.get_closest_point_to_segment(point, line[k], line[k + 1])
		if closest.distance_to(point) < best:
			best = closest.distance_to(point)
			arc = along + line[k].distance_to(closest)
		along += line[k].distance_to(line[k + 1])
	return arc

## Signed distance to pillar i's irregular outline (an approximation: exact
## along the rim, which is all the contour and the clearance tests need).
func _pillar_distance(i: int, point: Vector2) -> float:
	var pillar := _closed_circles[i]
	var offset := point - Vector2(pillar.x, pillar.y)
	if i >= _pillar_shapes.size(): return offset.length() - pillar.z
	var shape := _pillar_shapes[i]
	# In the city a pillar is a block (a lone building, a heap of rubble),
	# square to the streets.
	if region_id == "city":
		var square := offset.rotated(-snappedf(shape[1], PI * 0.5))
		var q := square.abs() - Vector2(pillar.z * shape[0], pillar.z) * 0.85
		return q.max(Vector2.ZERO).length() + minf(maxf(q.x, q.y), 0.0)
	var local := offset.rotated(-shape[1])
	local.x /= shape[0]
	var angle := local.angle()
	var rim := pillar.z * (1.0 + shape[2] * sin(2.0 * angle + shape[3]) + shape[4] * sin(3.0 * angle + shape[5]))
	return (local.length() - rim) * minf(1.0, shape[0])

## Furthest the pillar's outline reaches from its centre.
func pillar_reach(i: int) -> float:
	var r: float = _closed_circles[i].z
	if i >= _pillar_shapes.size(): return r
	var shape := _pillar_shapes[i]
	return r * shape[0] * (1.0 + shape[2] + shape[4])

func road_distance(point: Vector2) -> float:
	var distance := INF
	for segment in _main_segments: distance = minf(distance, _segment_distance(point, segment))
	return distance

func _is_open(x: float, z: float, inflate: float = 0.0) -> bool:
	var point := Vector2(x, z)
	return (_surface.distance_at(point) if _surface != null else carved_distance(point)) >= -inflate

## Room to stand: well inside the contour and not on a cliff's face.
func _has_clearance(point: Vector2) -> bool:
	return _is_open(point.x, point.y, -1.5) and (_surface == null or _surface.is_level(point)) and not in_prop(point, PROP_MARGIN)

## Room kept round a colliding prop: an actor's body, so a shot at its middle
## does not clip the box's corner.
const PROP_MARGIN := 0.6

func in_prop(point: Vector2, margin: float = 0.0) -> bool:
	for blocker in prop_blockers:
		var offset: Vector2 = point - (blocker[0] as Vector2)
		var half: Vector2 = blocker[2]
		if offset.length_squared() > (half.length() + margin) * (half.length() + margin): continue
		var x_axis: Vector2 = blocker[1]
		if absf(offset.dot(x_axis)) < half.x + margin and absf(offset.dot(x_axis.orthogonal())) < half.y + margin: return true
	return false

## 用户 2026-10-14: 兴趣点不都刷在道路、房间中央. A point of interest in the room
## round `centre`: a quarter at the middle, the rest set back against its wall
## or in a corner (open ground 1–3 m from the edge, room to stand round it).
## From the layout's own RNG, so the floor stays the seed's.
func _poi_spot(centre: Vector2, radius: float) -> Vector2:
	if _rng.randf() < 0.25: return _safe_spot(centre, centre, radius)
	for attempt in range(24):
		var probe := centre + Vector2.from_angle(_rng.randf_range(0.0, TAU)) * radius * _rng.randf_range(0.45, 1.0)
		var open := _surface.distance_near(probe) if _surface != null else carved_distance(probe)
		if open < 1.6 or open > 3.2 or not _has_clearance(probe): continue
		return probe
	return _safe_spot(centre, centre, radius)

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

# --- Siracusa: the old town (叙拉古地图调研与方案_v1.md §3) ------------------------

const RAIN_SHARE := 0.5
## Lane half-widths: 5.2–6.6 m wall to wall (narrower leaves no standing
## ground on the 1.5 m sampling grid where a lane runs at a slant).
const LANE_WIDTH := Vector2(2.6, 3.3)
## Lanes kink off the straight line by this share of their length.
const LANE_KINK := Vector2(0.14, 0.28)
## Rooms over PIAZZA_FROM keep only PIAZZA_SHRINK of the excess.
const PIAZZA_FROM := 6.5
const PIAZZA_SHRINK := 0.55
## Family mansions (§3.2): dead-end rooms walled round, one gate.
const MANSIONS := Vector2i(1, 2)
const MANSION_RADIUS := Vector2(5.5, 11.0)
## Landmark rooms: the theatre and the court, one each at most.
const LANDMARK_KINDS := ["theatre", "court"]
const LANDMARK_RADIUS := 7.5
## Rooms laid out as mansions, and {"room", "kind"} landmarks.
var mansion_rooms: Array[int] = []
var landmarks: Array[Dictionary] = []

## Picks the mansions and the landmark rooms from the layout just dug, with
## its own RNG so nothing else moves. A mansion is a dead end (a branch room
## with one way in); a landmark is a bigger room that is not a mansion, the
## entry or the trunk's end.
func _plan_old_town() -> void:
	mansion_rooms.clear()
	landmarks.clear()
	if region_id != "siracusa": return
	var roll := RandomNumberGenerator.new()
	roll.seed = seed_value ^ 0x5112a
	var dead_ends: Array[int] = []
	for i in range(_open_circles.size()):
		if circle_kinds[i] != "spur" or _degree(i) != 1: continue
		var r: float = _open_circles[i].z
		if r >= MANSION_RADIUS.x and r <= MANSION_RADIUS.y: dead_ends.append(i)
	_shuffle_ints(dead_ends, roll)
	# Spurs enough stay open for the early build, the encounter and the exits.
	var spur_count := circle_kinds.count("spur")
	var count := mini(roll.randi_range(MANSIONS.x, MANSIONS.y), maxi(0, spur_count - 4))
	for k in range(mini(count, dead_ends.size())): mansion_rooms.append(dead_ends[k])
	var big: Array[int] = []
	for i in range(1, _open_circles.size()):
		if i == main_path.size() - 1 or mansion_rooms.has(i) or circle_kinds[i] in ["vault", "niche"]: continue
		if _open_circles[i].z >= LANDMARK_RADIUS and not _entered_from_north(i): big.append(i)
	_shuffle_ints(big, roll)
	for kind in LANDMARK_KINDS:
		if big.is_empty() or roll.randf() < 0.25: continue
		landmarks.append({"room": big.pop_back(), "kind": kind})

## Whether a lane leaves room i through its north wall, where a landmark's
## front would stand across it.
func _entered_from_north(i: int) -> bool:
	var centre := _centre(i)
	for index in range(_links.size()):
		var link: Dictionary = _links[index]
		if int(link.a) != i and int(link.b) != i: continue
		var line := _link_points(index)
		var toward: Vector2 = line[1] if line[1].distance_to(centre) > 1.0 else (line[2] if int(link.a) == i else line[0])
		var d := toward - centre
		if d.y > 0.0 and absf(d.x) < d.y * (0.85 / 0.75) + 6.0: return true
	return false

static func _shuffle_ints(list: Array[int], roll: RandomNumberGenerator) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := roll.randi_range(0, i)
		var swap := list[i]
		list[i] = list[j]
		list[j] = swap

## 家族专用轿车's roadblock (叙拉古敌人设计案 §三第 7.1 节): on half the floors, a
## trunk lane leaving a piazza deeper in, which is a cut edge (no loop round
## it), neither the first nor the last of the trunk, clear of every marker.
## {"at": the car's spot, "along": the lane's way deeper, "half": its half-width}.
var roadblock := {}
const ROADBLOCK_SHARE := 0.5

func _plan_roadblock() -> void:
	roadblock = {}
	if region_id != "siracusa": return
	var roll := RandomNumberGenerator.new()
	roll.seed = seed_value ^ 0xca5
	if roll.randf() >= ROADBLOCK_SHARE: return
	var markers: Array = [buff_position, encounter_position, route_guard_position, vault_position]
	markers.append_array(cache_positions)
	if is_instance_valid(exit_node): markers.append(exit_node.position)
	for node in route_nodes: markers.append(node.position)
	var options: Array[int] = []
	for index in range(_links.size()):
		var link: Dictionary = _links[index]
		var a := int(link.a)
		var b := int(link.b)
		if not link.alive or link.has("bridge") or circle_kinds[a] != "trunk" or circle_kinds[b] != "trunk": continue
		if a == 0 or b != a + 1 or b >= main_path.size() - 1: continue
		if _open_circles[a].z < PIAZZA_FROM or mansion_rooms.has(a) or not landmark_of(a).is_empty(): continue
		if not _cut_edge(index): continue
		options.append(index)
	_shuffle_ints(options, roll)
	for index in options:
		var link: Dictionary = _links[index]
		var line := _link_points(index)
		var start: Vector2 = line[0]
		var travel := float(_open_circles[int(link.a)].z) * 0.9 + 3.5
		var at := start
		var along := Vector2.ZERO
		for k in range(line.size() - 1):
			var leg: float = line[k].distance_to(line[k + 1])
			if travel <= leg:
				along = (line[k + 1] - line[k]).normalized()
				at = line[k] + along * travel
				break
			travel -= leg
		if along == Vector2.ZERO or not _has_clearance(at): continue
		var clear := true
		for m in markers:
			if Vector2((m as Vector3).x, (m as Vector3).z).distance_to(at) < 6.0: clear = false
		if not clear: continue
		roadblock = {"at": at, "along": along, "half": float(link.width) + 0.5, "link": index}
		return

## Whether removing link `index` cuts the floor in two (no loop round it).
func _cut_edge(index: int) -> bool:
	var seen := {0: true}
	var queue: Array[int] = [0]
	while not queue.is_empty():
		var room: int = queue.pop_back()
		for k in range(_links.size()):
			var link: Dictionary = _links[k]
			if k == index or not link.alive: continue
			var other := -1
			if int(link.a) == room: other = int(link.b)
			elif int(link.b) == room: other = int(link.a)
			if other >= 0 and not seen.has(other):
				seen[other] = true
				queue.append(other)
	return not seen.has(int(_links[index].b))

func is_mansion(room: int) -> bool:
	return mansion_rooms.has(room)

func landmark_of(room: int) -> String:
	for l in landmarks:
		if int(l.room) == room: return str(l.kind)
	return ""

## The room whose floor holds `point` (within its radius of its centre), or -1.
func room_at(point: Vector2) -> int:
	for i in range(_open_circles.size()):
		if point.distance_to(_centre(i)) <= _open_circles[i].z: return i
	return -1

## Room i's walls in Siracusa: a piazza is an oblong at its own angle; a
## mansion's court and a landmark's square sit square to the axes (a façade
## faces the camera across it; a court is walled round).
func _square_distance(i: int, offset: Vector2) -> float:
	var r: float = _open_circles[i].z
	if mansion_rooms.has(i) or not landmark_of(i).is_empty():
		var q := offset.abs() - Vector2(r * 0.85, r * 0.75)
		return -maxf(q.x, q.y) + 1.0
	var shape := _room_shapes[i] if i < _room_shapes.size() else PackedFloat32Array([0.1, 0.0, 0.0, 0.0])
	var local := offset.rotated(-shape[1])
	var q := local.abs() - Vector2(r * 0.88, r * (0.62 + shape[0] * 1.6))
	return -maxf(q.x, q.y) + 1.0

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
		if circle_kinds[i] == "spur" and circle_distance[i] < INF and not mansion_rooms.has(i): spurs.append(i)
	# By the walk from the entry, not by depth: with loops a shallow room can be
	# a long way round, and the early build has to be early on foot.
	spurs.sort_custom(func(a: int, b: int) -> bool: return circle_distance[a] < circle_distance[b])
	var buff_room: int = spurs[0]
	var encounter_room: int = spurs[spurs.size() / 2]
	var farthest := 0.0
	for d in circle_distance:
		if d < INF: farthest = maxf(farthest, d)
	var trunk_end := main_path.size() - 1

	# Route markers: any dead-end room big enough for three markers, in the far
	# part of the walk. The trunk's end is one candidate among several.
	var candidates: Array[int] = []
	# The last pass drops the "past the early build" rule rather than leave
	# no candidate at all (the trunk's end always qualifies then).
	for share in [0.5, 0.35, 0.0, -1.0]:
		for i in range(_open_circles.size()):
			if i == buff_room or i == encounter_room or circle_kinds[i] in ["vault", "niche"] or mansion_rooms.has(i): continue
			# Well past the early build along the walk (loops can make a shallow
			# room a long way round).
			if share >= 0.0 and circle_distance[i] < circle_distance[buff_room] * 1.6: continue
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
		if i == exit_chamber or i == buff_room or i == encounter_room or i == 0 or circle_kinds[i] in ["vault", "niche"] or mansion_rooms.has(i): continue
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
	_modelled(buff_device_node, "res://art/kit/buff_device.glb")
	if encounter_kind == "post":
		# A faction's post (势力与交易所策划案 §12): the stall without 坎诺特, until its NPC art.
		encounter_node = _set_piece("据点 · E", encounter_position, Color("c48cff"), ENCOUNTER_MODELS.trader)
	else:
		encounter_node = _set_piece("坎诺特 · E" if encounter_kind == "trader" else "罗德岛小队 · E", encounter_position, Color("e6c25a") if encounter_kind == "trader" else Color("5fd0d8"), ENCOUNTER_MODELS["trader" if encounter_kind == "trader" else "squad"], "trader" if encounter_kind == "trader" else "squad")
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
		route_nodes.append(_modelled(_marker(FieldCatalog.ROUTES[i].name + " · E", _grounded(spot, 0.15), Color("69b7ea")), "res://art/kit/route_marker.glb", arrival))
	var hold := _open_circles[maxi(0, parent[exit_chamber])]
	var hold_at := Vector2(hold.x, hold.y).lerp(route_centre, 0.35) if parent[exit_chamber] > 0 else route_centre - arrival * 8.0
	route_guard_position = _grounded(_safe_spot(hold_at, Vector2(hold.x, hold.y), hold.z), 0.0)

	enemy_spawn_points.clear()
	# Spread existing regional enemy budgets across the whole route first.
	# Settled like every marker: a pillar can stand over a small room's centre.
	for i in range(2, main_path.size(), 2):
		var spawn := _safe_spot(main_path[i], main_path[i], _open_circles[i].z)
		# A neck room wholly taken by a neighbouring pillar has no spot: skip it.
		if _has_clearance(spawn): enemy_spawn_points.append(_grounded(spawn, 0.0))
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
	# Each mansion's court keeps the family's safe (game_manager: mansion_point).
	for i in mansion_rooms:
		if circle_distance[i] < INF: spare.append(i)
	for i in spare:
		var centre := Vector2(_open_circles[i].x, _open_circles[i].y)
		# Settled like every marker: a warped outline may not cover the centre.
		cache_positions.append(_grounded(_poi_spot(centre, _open_circles[i].z), 0.5))
	# An absent extraction must not turn its room into an empty dead end.
	var exit_centre := Vector2(exit_spot.x, exit_spot.y)
	cache_positions.append(_grounded(_safe_spot(exit_centre + Vector2(2.0, 0.0), exit_centre, exit_spot.z), 0.5))
	# Nor the trunk's end, when the markers went elsewhere.
	if exit_chamber != trunk_end and extraction_chamber != trunk_end:
		cache_positions.append(_grounded(_safe_spot(main_path[trunk_end], main_path[trunk_end], 8.0), 0.5))
	for i in range(2, main_path.size() - 1, 4):
		cache_positions.append(_grounded(_poi_spot(main_path[i], minf(_open_circles[i].z, 10.0)), 0.5))
	for loop in loop_centres:
		if _circle_at(loop) != exit_chamber: cache_positions.append(_grounded(_poi_spot(loop, 6.0), 0.5))
	# A second-order niche is the longest walk on the map for its size, so it
	# always pays; an empty one would just teach the player to ignore forks.
	for niche in niche_centres:
		cache_positions.append(_grounded(_safe_spot(niche, niche, 4.5), 0.5))

	vault_position = Vector3(1.0e6, 0.0, 1.0e6)
	if has_vault:
		var vault_spot := _safe_spot(vault_centre, vault_centre, 8.0)
		vault_position = _grounded(vault_spot, 0.5)
		vault_node = Node3D.new()
		vault_node.name = "VaultMark"
		vault_node.visible = false
		_generated_root.add_child(vault_node)
		vault_node.position = vault_position
		_find_vault_mouth()
		vault_seal = VaultSeal.new()
		vault_seal.prepare(self)

## The 暗墙 is the stretch of the room's edge where the vault's lane would
## leave it: walking the lane out from the trunk, the first point where the
## floor, carved with the vault, would run on into what is rock without it.
func _find_vault_mouth() -> void:
	var link: Dictionary = _links[_vault_link]
	var points := [Vector2(_open_circles[link.a].x, _open_circles[link.a].y), link.middle as Vector2, Vector2(_open_circles[link.b].x, _open_circles[link.b].y)]
	vault_half_width = float(link.width) + 0.8
	for leg in range(2):
		var from: Vector2 = points[leg]
		var to: Vector2 = points[leg + 1]
		var length := from.distance_to(to)
		var t := 0.0
		while t < length:
			var p := from.lerp(to, t / length)
			if _surface.distance_near(p) < 0.0:
				vault_inward = (to - from).normalized()
				vault_mouth = p
				return
			t += 0.25
	vault_mouth = points[1]
	vault_inward = (points[2] - points[1]).normalized()

## Whether a vault room at `spot`, its lane to `base`, would stand in rock
## (VAULT_CLEAR all round) clear of every room and corridor planned so far.
const VAULT_CLEAR := 4.0
func _vault_clear(spot: Vector2, base: Vector2) -> bool:
	var rect := Rect2(spot - VAULT_ROOM, VAULT_ROOM * 2.0).grow(VAULT_CLEAR)
	for i in range(_open_circles.size()):
		var c := _open_circles[i]
		var centre := Vector2(c.x, c.y)
		var nearest := centre.clamp(rect.position, rect.end)
		if nearest.distance_to(centre) < c.z * 1.3: return false
	for link in _links:
		if not link.alive: continue
		var line := PackedVector2Array([_centre(int(link.a)), link.middle as Vector2, _centre(int(link.b))])
		for k in range(2):
			var leg := PackedVector2Array([line[k], line[k + 1]])
			# Corridors the lane leaves from may meet it at the trunk; the room may meet none.
			var corners := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y), rect.position])
			for e in range(4):
				if _line_gap(PackedVector2Array([corners[e], corners[e + 1]]), leg) < float(link.width): return false
			if rect.has_point(line[k]): return false
	return true

## The vault's room and lane, with room round them.
func vault_bounds() -> Rect2:
	var circle := _open_circles[_vault_room]
	var rect := Rect2(Vector2(circle.x, circle.y), Vector2.ZERO).grow(circle.z * 1.8)
	var link: Dictionary = _links[_vault_link]
	for p in [Vector2(_open_circles[link.a].x, _open_circles[link.a].y), link.middle as Vector2]:
		rect = rect.expand(p)
	return rect.grow(float(link.width) * 2.0)

## Never hidden any more: a sealed vault is plain rock (kept for the trap and
## fog callers; true only over the vault's own dug ground while sealed).
func vault_hidden(point: Vector2) -> bool:
	if vault_seal == null or vault_seal.opened: return false
	return vault_seal.in_patch(point) and (point - vault_mouth).dot(vault_inward) > 0.0

func _dress_landmarks() -> void:
	# Compose grounded groups independently of progression RNG and collision.
	SceneDressing.new().build(self)
	# The mine's track is a Blender model (TerraceDressing.RAILS); the city's
	# road markings are CityDressing's (standard roads only).
	# Cliffs, ramps and cliff-foot rubble from the Blender kit (a3/CHANGE-BRIEF.md).
	terrace_dressing = TerraceDressing.new()
	terrace_dressing.build(self)

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

## Set pieces from tools/blender/kit/build_encounter.py (NPC_brief_v3.md Part C).
const ENCOUNTER_MODELS := {"squad": "res://art/kit/enc_squad_post.glb", "trader": "res://art/kit/enc_trader_stall.glb"}
## Larger than life, as the search points are (LootContainer.MODEL_SCALE), so they read from the camera.
const ENCOUNTER_SCALE := 1.5
## Where the NPC stands, from the set piece's centre: in front of it, towards the camera (-Z).
const ENCOUNTER_STAND := {"squad": Vector3.ZERO, "trader": Vector3(0.3, 0.0, -1.65)}
## Half the squad post's footprint (x, z) before ENCOUNTER_SCALE (art/kit/enc_squad_post.glb).
const SQUAD_POST_HALF := Vector2(1.12, 0.68)

## An encounter's set piece standing on the ground at `pos`, front to the
## camera. Walk-through, like the search points.
func _set_piece(title: String, pos: Vector3, color: Color, model: String, npc: String = "") -> Node3D:
	var node := Node3D.new()
	node.name = title
	node.set_meta("art_kind", title)
	_generated_root.add_child(node)
	node.position = on_ground(pos)
	var mesh := MeshInstance3D.new()
	mesh.name = "Model"
	mesh.mesh = TerraceDressing.kit_mesh(load(model))
	node.add_child(mesh)
	# The node floats where the HUD and the E range read it; the model stands on the ground.
	mesh.position.y = ground_height(Vector2(pos.x, pos.z)) - node.position.y
	# Built front to Blender -Y (Godot +Z); the follow camera sits at -Z.
	mesh.rotation.y = PI
	mesh.scale = Vector3.ONE * ENCOUNTER_SCALE
	if not npc.is_empty():
		var stand: Vector3 = ENCOUNTER_STAND[npc]
		# Its own generator, seeded by the spot: drawing from _rng here would
		# move everything placed after it on a seeded map.
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(Vector2i(roundi(pos.x * 100.0), roundi(pos.z * 100.0)))
		var spots: Array[Vector3] = [stand]
		var who: Array = [npc]
		if npc == "squad":
			spots = _squad_spots(pos, rng)
			who = ["melee", "sniper", "logistics"]
			for i in range(who.size() - 1, 0, -1):
				var j := rng.randi_range(0, i)
				var swap = who[i]
				who[i] = who[j]
				who[j] = swap
		for i in range(spots.size()):
			var figure := FieldArt.npc_idle(who[i])
			figure.position = spots[i] + Vector3(0, ground_height(Vector2(pos.x + spots[i].x, pos.z + spots[i].z)) - node.position.y, 0)
			# Each on its own frame, so they do not breathe in step.
			figure.frame = rng.randi_range(0, FieldArt.NPC_FRAMES - 1)
			# Standing upright, stretched by the camera's tilt so it draws the
			# same pixels: a camera-facing billboard leans back into the set piece
			# behind it and loses its head there.
			figure.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			figure.scale.y = GameManager.CAMERA_OFFSET.length() / absf(GameManager.CAMERA_OFFSET.z)
			node.add_child(figure)
	# No Label3D over it: the world renders at 640×360, where 3D text breaks
	# into noise; the HUD's E prompt names it when the player is near.
	return node

## The squad's three spots around its post (用户 2026-10-13: 随机三角站位,
## 围绕在箱子周边、分散随机): on a ring just outside the post's footprint,
## at random angles at least 70° apart, each at its own distance; a spot off
## the walkable floor is drawn again. `pos` is the post's centre in the world.
## Sorted back to front.
func _squad_spots(pos: Vector3, rng: RandomNumberGenerator) -> Array[Vector3]:
	var half := SQUAD_POST_HALF * ENCOUNTER_SCALE
	var angles: Array[float] = []
	var spots: Array[Vector3] = []
	for tries in range(60):
		if spots.size() == 3: break
		var a := rng.randf_range(-PI, PI)
		var apart := true
		for b in angles:
			if absf(wrapf(a - b, -PI, PI)) < deg_to_rad(70.0): apart = false
		if not apart: continue
		var reach := rng.randf_range(1.0, 1.45)
		var spot := Vector3(cos(a) * (half.x + 0.45) * reach, 0, sin(a) * (half.y + 0.4) * reach)
		if tries < 50 and not _has_clearance(Vector2(pos.x + spot.x, pos.z + spot.z)): continue
		angles.append(a)
		spots.append(spot)
	spots.sort_custom(func(p: Vector3, q: Vector3): return p.z > q.z)
	return spots

## A marker's placeholder disc swapped for its model (tools/blender/kit/
## build_trap_kit.py PROPS, 用户 2026-10-17: 几何体代替的都换成建模), standing on
## the ground, facing `facing` (its front, Godot +Z) when given.
func _modelled(node: Node3D, path: String, facing := Vector2.ZERO) -> Node3D:
	var marker := node as MeshInstance3D
	marker.mesh = TerraceDressing.kit_mesh(load(path))
	marker.material_override = null
	marker.position.y = ground_height(Vector2(marker.position.x, marker.position.z))
	if facing != Vector2.ZERO: marker.rotation.y = atan2(-facing.x, -facing.y)
	return marker

func _marker(title: String, pos: Vector3, color: Color) -> Node3D:
	# No Label3D: 3D text is noise at the world's 640×360, and the HUD shows
	# only the E key when near (用户 2026-10-13: 不要中文label了).
	return _make_cylinder(title, on_ground(pos), 1.6, 0.25, color, false)

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
	FieldLight.clear()
	if is_instance_valid(_generated_root):
		remove_child(_generated_root)
		_generated_root.queue_free()
	_generated_root = null
