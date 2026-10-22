class_name CityDressing
extends RefCounted

## Lungmen's lower city (城市地图调研与方案_v1.md; 用户 2026-10-14: 随机结构；真实
## 高度，区分不同区域的城景；都建). The rock off the road becomes the city:
## buildings at real height on every block, chosen by the district the block
## lies in (ContinuousWorldMap.district_at) —
##   street: shop houses, towers, tea houses over the outer city's streets;
##   slum:   corrugated shacks packed close, one and two storeys;
##   yard:   container stacks and a gantry crane over the warehouse yards;
##   site:   collapsed blocks and stacked building stock round the sites,
##           scaffolding up the banks (_place_banks).
## Each faces the road nearest it. A building south of a road stands no taller
## than lets the follow camera see the road behind it (the camera looks north
## down 58°, so a building of height h hides 0.62 h behind it).
## Then the city under siege: barricades across the trunk with one narrow gap,
## a quarantine wall where the slums meet another district with a gate on each
## road through it, kiosks and sandbags for cover in the big rooms, a helipad
## under the extraction. Buildings, walls and furniture in the rock are visual
## only (the rock already stops her); barricades and cover on the road collide.

const KIT := "res://art/kit/"
## Footprint (x, z) and height of each building, measured from the models.
const BUILDINGS := {
	"city_tower": Vector3(11.2, 17.7, 12.0), "city_shop_house": Vector3(9.2, 11.5, 10.0),
	"city_tea_house": Vector3(9.1, 8.6, 8.0), "city_ruin": Vector3(9.8, 9.2, 11.8),
	"city_shack_a": Vector3(4.2, 3.0, 3.5), "city_shack_b": Vector3(5.2, 3.4, 3.9), "city_shack_c": Vector3(5.0, 5.4, 4.1),
	"city_container": Vector3(6.2, 2.6, 2.5), "city_scaffold": Vector3(4.2, 6.2, 1.3),
}
## Per district: the buildings it builds, tallest first, and the block step.
const DISTRICT_BUILDINGS := {
	"street": {"pieces": ["city_tower", "city_shop_house", "city_tea_house"], "step": 6.0},
	"slum": {"pieces": ["city_shack_c", "city_shack_b", "city_shack_a"], "step": 3.5},
	"yard": {"pieces": ["city_container"], "step": 3.5},
	"site": {"pieces": ["city_ruin", "city_shop_house", "city_tea_house", "city_container"], "step": 5.0},
}
## Street fronts (用户 2026-10-14: 房子构成道路的形状，像真实街道那样): per district,
## the pieces that line its roads, front to the kerb. Tall ones only where the
## camera still sees over them (the north side of a road, and its east and
## west sides); the south side takes the one-storey rows, whose roof is all
## the camera sees of them.
const FRONTAGE := {
	"street": ["city_tower", "city_shop_house", "city_row_mid", "city_tea_house", "city_row_low_b", "city_row_low_a"],
	"site": ["city_ruin", "city_shop_house", "city_row_low_b", "city_container", "city_row_low_a"],
	# The slums keep the weathered rows (用户 2026-10-16: 城区里的房子不应该是斑驳
	# 的，贫民窟应该是); the outer city's buildings are clean.
	"slum": ["city_shack_c", "city_shack_b", "city_shack_a", "city_row_low_a_worn", "city_row_low_b_worn"],
	"yard": ["city_container", "city_row_low_b", "city_container", "city_row_low_a"],
}
## How tall each piece stands where it hides the ground behind it (its walls
## and parapet; an aerial or a tank on top does not count).
const SIGHT_HEIGHT := {
	"city_tower": 16.2, "city_shop_house": 10.0, "city_row_mid": 9.7, "city_tea_house": 7.1, "city_ruin": 9.0,
	"city_row_low_a": 4.3, "city_row_low_b": 4.6, "city_row_low_a_worn": 4.3, "city_row_low_b_worn": 4.6, "city_shack_a": 3.0, "city_shack_b": 3.2, "city_shack_c": 5.4,
	"city_container": 2.6,
}
## Road edge a one-storey row on the south side may hide: the pavement strip.
const KERB_HIDE := 2.7
## The buildings tinted one by one (kit_piece.gdshader use_tint), and the
## tints: pale concrete, sun-bleached, tar, terracotta, mossed, blue-grey.
const TINTED := ["city_tower", "city_shop_house", "city_row_mid", "city_tea_house", "city_ruin", "city_row_low_a", "city_row_low_b", "city_row_low_a_worn", "city_row_low_b_worn", "city_shack_a", "city_shack_b", "city_shack_c",
	"city_tower_lower", "city_shop_house_lower", "city_row_mid_lower", "city_tea_house_lower", "city_row_low_a_lower", "city_row_low_b_lower"]
const ROOF_TINTS := [Color(1.22, 1.18, 1.1), Color(1.12, 1.04, 0.92), Color(0.78, 0.78, 0.82), Color(1.18, 0.9, 0.78), Color(0.92, 1.04, 0.9), Color(0.9, 0.98, 1.12), Color(1.0, 1.0, 1.0)]

## Per district: the street's pale concrete and terracotta, the yards' blue-
## greys, the sites' dust, the slums' rust and tar.
const DISTRICT_TINTS := {
	"street": [Color(1.22, 1.18, 1.1), Color(1.12, 1.04, 0.92), Color(1.18, 0.9, 0.78), Color(1.0, 1.0, 1.0)],
	"yard": [Color(0.86, 0.96, 1.14), Color(0.92, 0.98, 1.08), Color(0.8, 0.86, 0.96)],
	"site": [Color(1.16, 1.04, 0.84), Color(1.1, 0.98, 0.82), Color(1.0, 0.94, 0.84)],
	"slum": [Color(1.06, 0.82, 0.68), Color(0.78, 0.76, 0.74), Color(0.92, 0.98, 0.84), Color(1.0, 0.88, 0.76)],
}

## 龙门城区 · 下城 (龙门城区与叙拉古地图改造案 v1.1 §1.3, 用户 2026-10-21: 换地图内
## 大小组件和光影、滤镜、材质): the same streets and the same plan, laid with
## the outer city's buildings rebuilt for the lower city (build_city_kit.py
## LOWER: old concrete and tile streaked with damp, rows of windows a third
## lit, more air conditioners and laundry poles), darker colder tints, a third
## of the street lamps, neon that lights only its sign, warm window and red
## lantern light at the doors, laundry under the cables, and 1–2 牌楼连廊
## across her trunk road. Everything the lower city adds draws on look_rng,
## so the plan (and all that collides) is the upper city's to the metre.
var lower := false
var look_rng := RandomNumberGenerator.new()
const LOWER_PIECES := {"city_tower": "city_tower_lower", "city_shop_house": "city_shop_house_lower", "city_row_mid": "city_row_mid_lower",
	"city_tea_house": "city_tea_house_lower", "city_row_low_a": "city_row_low_a_lower", "city_row_low_b": "city_row_low_b_lower"}
## Damp concrete and old tile, colder than the upper city's.
const LOWER_TINTS := {
	"street": [Color(0.82, 0.86, 0.94), Color(0.9, 0.88, 0.86), Color(0.74, 0.78, 0.86), Color(0.86, 0.8, 0.76)],
	"yard": [Color(0.74, 0.82, 0.94), Color(0.8, 0.84, 0.92), Color(0.7, 0.74, 0.84)],
	"site": [Color(0.9, 0.84, 0.74), Color(0.84, 0.8, 0.74), Color(0.8, 0.78, 0.74)],
	"slum": [Color(0.88, 0.72, 0.62), Color(0.68, 0.68, 0.7), Color(0.76, 0.82, 0.74), Color(0.84, 0.76, 0.68)],
}
## Street lamps kept: one in this many.
const LOWER_LAMP_EVERY := 3

## Stacks of containers: up to this many high.
const STACK := 3
## Ground hidden behind a building per metre of its height (camera 58° down).
const SIGHT := 0.62

var map: Node3D
var root: Node3D
var rng := RandomNumberGenerator.new()
var transforms := {}
var building_count := 0
var barricade_count := 0
var gate_count := 0
var culvert_count := 0
var scaffold_count := 0
## Where each sewer mouth and scaffold went, for the captures.
var bank_points: Array[Vector2] = []
var _occupied: Array[Rect2] = []
## _occupied by OCCUPIED_CELL squares, so a test reads only what is near
## (load time: a floor places a few thousand pieces).
const OCCUPIED_CELL := 12.0
var _occupied_grid := {}

func _occupy(rect: Rect2) -> void:
	_occupied.append(rect)
	var index := _occupied.size() - 1
	for cell in _cells_of(rect):
		var list: PackedInt32Array = _occupied_grid.get(cell, PackedInt32Array())
		list.append(index)
		_occupied_grid[cell] = list

func _cells_of(rect: Rect2) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var lo := Vector2i(floori(rect.position.x / OCCUPIED_CELL), floori(rect.position.y / OCCUPIED_CELL))
	var hi := Vector2i(floori(rect.end.x / OCCUPIED_CELL), floori(rect.end.y / OCCUPIED_CELL))
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1): cells.append(Vector2i(x, y))
	return cells

## Whether `rect` meets anything placed.
func _taken(rect: Rect2) -> bool:
	for cell in _cells_of(rect):
		for index in _occupied_grid.get(cell, PackedInt32Array()):
			if _occupied[index].intersects(rect): return true
	return false
var _bounds := {}
var frontage_count := 0
## The streets she cannot walk: {"rect", "axis" (along it), "mouths" (ends
## that open on her road, each barricaded)}.
var side_streets: Array[Dictionary] = []

func build(world: Node3D, parent: Node3D) -> void:
	map = world
	rng.seed = map.seed_value ^ 0xc17e
	lower = map.city_variant == "lower"
	look_rng.seed = map.seed_value ^ 0x10e7
	root = Node3D.new()
	root.name = "CityDressing"
	parent.add_child(root)
	_place_banks()
	_plan_side_streets()
	_place_walls()
	_place_landmarks()
	map.mark("  city: banks + side streets + borders")
	_place_frontage()
	map.mark("  city: street fronts")
	_place_buildings()
	map.mark("  city: block fill")
	_place_barricades()
	_place_cover()
	_place_gantries()
	_build_side_streets()
	map.mark("  city: walls, cover, side street mesh")
	_place_fences()
	_place_lamps()
	map.mark("  city: railings + lamps")
	_place_furniture()
	_place_cables()
	_place_neon()
	map.mark("  city: street furniture + cables")
	if lower:
		_place_front_lights()
		_place_skybridges()
		_place_front_laundry()
		map.mark("  city: lower city lights + skybridges")
	for path in transforms:
		_add_set(String(path).get_file().get_basename(), TerraceDressing.kit_mesh(load(path)), transforms[path])
	map.mark("  city: multimeshes")

## The tints a district's buildings draw from (SiracusaDressing has its own).
func _palette(kind: String) -> Array:
	if lower: return LOWER_TINTS.get(kind, LOWER_TINTS.street)
	return DISTRICT_TINTS.get(kind, ROOF_TINTS)

## How tall a piece stands where it hides the ground behind it.
func _sight_height(name: String, box: AABB) -> float:
	return float(SIGHT_HEIGHT.get(name, box.size.y)) * rise_of(name)

## The pieces that line a district's roads, tallest first.
func _frontage_pieces(kind: String) -> Array:
	return FRONTAGE.get(kind, FRONTAGE.street)

## The direction (towards the road) a run of street front is laid along, for
## a kerb edge whose normal is `normal`; ZERO when no run follows it. Lungmen
## is right-angled: only kerbs square to an axis are built along.
func _front_axis(normal: Vector2) -> Vector2:
	var axis := Vector2(roundf(normal.x), roundf(normal.y))
	if axis.length() != 1.0 or normal.dot(axis) < 0.95: return Vector2.ZERO
	return axis

## A key that tells runs along the same direction apart.
func _axis_key(axis: Vector2) -> Vector2:
	return axis

## Pieces against the figures (用户 2026-10-20: 地图里的场景物件都调大，和人物的
## 相对比例要对). A figure is a camera-facing billboard, its full height on
## screen; a model shows cos(58°) = 0.53 of its height, so a 1.7 m prop read
## half her size. Street furniture is drawn PROP_SCALE larger all round
## (its collider too); fences and walls only taller (they run along a line);
## buildings BUILDING_RISE taller, their footprint kept to the street plan.
## Across a barricade a piece keeps its length so the gap stays one person wide.
const PROP_SCALE := 1.6
const PROP_PIECES := ["city_bin", "city_bollards", "city_bus_stop", "city_car_wreck", "city_cones", "city_hydrant", "city_kiosk",
	"city_phone_booth", "city_postbox", "city_street_lamp", "city_traffic_light", "city_vending", "city_sandbags", "city_water_barrier", "city_hedgehog"]
const RISE_PIECES := ["city_fence", "city_hoarding", "city_yard_fence", "city_gate", "city_site_gate", "city_yard_gate", "city_wall"]
const LINE_RISE := 1.4
const BUILDING_RISE := 1.45
const RISEN_BUILDINGS := ["city_tower", "city_shop_house", "city_row_mid", "city_tea_house", "city_row_low_a", "city_row_low_b", "city_row_low_a_worn", "city_row_low_b_worn",
	"city_shack_a", "city_shack_b", "city_shack_c", "siracusa_house_a", "siracusa_house_b", "siracusa_house_c", "siracusa_house_d", "siracusa_house_low"]

## How much taller than modelled a piece is drawn.
static func rise_of(name: String) -> float:
	if name in RISEN_BUILDINGS: return BUILDING_RISE
	if name in RISE_PIECES: return LINE_RISE
	if name in PROP_PIECES: return PROP_SCALE
	return 1.0

## A block building's size (BUILDINGS) as drawn, BUILDING_RISE and all.
func _size_of(name: String) -> Vector3:
	var size: Vector3 = BUILDINGS[name]
	return Vector3(size.x, size.y * rise_of(name), size.z)

func _add(name: String, placed: Transform3D, barricade := false) -> void:
	if name in PROP_PIECES: placed.basis = placed.basis * Basis.from_scale(Vector3(1.0 if barricade else PROP_SCALE, PROP_SCALE, PROP_SCALE))
	elif name in RISE_PIECES or name in RISEN_BUILDINGS: placed.basis = placed.basis * Basis.from_scale(Vector3(1.0, rise_of(name), 1.0))
	# 下城: the same footprint, its lower-city model.
	if lower and LOWER_PIECES.has(name): name = LOWER_PIECES[name]
	var path := KIT + name + ".glb"
	if not transforms.has(path): transforms[path] = [] as Array[Transform3D]
	(transforms[path] as Array[Transform3D]).append(placed)

func _add_set(label: String, mesh: Mesh, list: Array[Transform3D]) -> void:
	if list.is_empty() or mesh == null: return
	var instance := MultiMeshInstance3D.new()
	instance.name = label
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var tinted := label in TINTED
	var neon: Array = _neon_colours.get(KIT + label + ".glb", [])
	multimesh.use_colors = tinted or not neon.is_empty()
	multimesh.mesh = mesh
	multimesh.instance_count = list.size()
	for i in range(list.size()):
		multimesh.set_instance_transform(i, list[i])
		if tinted:
			var palette: Array = _palette(map.district_at(Vector2(list[i].origin.x, list[i].origin.z)))
			multimesh.set_instance_color(i, palette[rng.randi_range(0, palette.size() - 1)])
		elif not neon.is_empty():
			multimesh.set_instance_color(i, neon[i])
	if tinted:
		for surface in range(mesh.get_surface_count()):
			var material := mesh.surface_get_material(surface) as ShaderMaterial
			if material != null: material.set_shader_parameter("use_tint", true)
	if not neon.is_empty():
		# Only the tubes take the colour; the frames stay dark steel.
		for surface in range(mesh.get_surface_count()):
			var material := mesh.surface_get_material(surface) as ShaderMaterial
			if material != null and material.shader == TerraceDressing.GLOW_SHADER: material.set_shader_parameter("use_tint", true)
	instance.multimesh = multimesh
	root.add_child(instance)

# --- 下城: door lights and 牌楼连廊 ----------------------------------------------------

## The lower city's light (改造案 §1.3: 以窗光和红灯笼为主): at some building
## fronts a small warm pool from the lit windows and doorway; at some shops a
## pair of red lanterns (art/kit/city_lc_lantern.glb) either side of the door,
## each with its small red-warm pool.
const WINDOW_LIGHT := Color(1.0, 0.7, 0.38) * 0.7
const WINDOW_SHARE := 0.45
const LANTERN_LIGHT_RED := Color(1.0, 0.34, 0.2) * 0.85
const LANTERN_SHARE := 0.35
const LANTERN_FRONTS := ["city_tower", "city_shop_house", "city_row_mid", "city_tea_house", "city_row_low_a", "city_row_low_b"]
var red_lantern_count := 0
var window_light_count := 0

func _place_front_lights() -> void:
	for f in fronts:
		var kerb: Vector2 = f.kerb
		var axis: Vector2 = f.axis
		var along: Vector2 = f.along
		var floor_y: float = f.floor
		var ground: float = map.ground_height(kerb + axis * 1.0)
		if look_rng.randf() < WINDOW_SHARE:
			var at := kerb + along * look_rng.randf_range(-f.width * 0.3, f.width * 0.3) + axis * 1.2
			lamps.append({"at": Vector3(at.x, ground + 2.6, at.y), "color": WINDOW_LIGHT, "radius": 4.5})
			window_light_count += 1
		if f.name in LANTERN_FRONTS and look_rng.randf() < LANTERN_SHARE:
			var yaw := Basis(Vector3.UP, atan2(axis.x, axis.y))
			var door := kerb + along * look_rng.randf_range(-f.width * 0.2, f.width * 0.2)
			for side in [-1.0, 1.0]:
				var at: Vector2 = door + along * side * 0.9 - axis * 0.05
				_add("city_lc_lantern", Transform3D(yaw, Vector3(at.x, floor_y + 3.4, at.y)))
				red_lantern_count += 1
			var pool := door + axis * 0.9
			lamps.append({"at": Vector3(pool.x, ground + 2.2, pool.y), "color": LANTERN_LIGHT_RED, "radius": 4.0})

## 牌楼连廊 (改造案 §1.3, §3): a covered bridge with a 歇山 roof between the
## buildings either side of her trunk road, high over her head, two red
## lanterns under it; 1–2 a floor, on a straight stretch of the trunk with
## buildings on both kerbs, well clear of the way down. It stops nothing:
## the road under it is walkable, and she is hidden while she is under it.
## The model (art/kit/city_lc_skybridge.glb) spans SKYBRIDGE_SPAN kerb to
## kerb along its x and is stretched to the street.
const SKYBRIDGE_SPAN := 10.0
const SKYBRIDGE_COUNT := Vector2i(1, 2)
const SKYBRIDGE_WIDTH := Vector2(6.0, 16.0)
const SKYBRIDGE_CLEAR := 36.0
## How near her trunk it must be.
const SKYBRIDGE_TRUNK := 10.0
var skybridge_count := 0
var skybridge_points: Array[Vector2] = []

## Places across the streets she walks with a building behind both kerbs:
## sampled every `step` along each corridor, the kerbs `span` apart (at most
## `max_span`) along `across`, `at` the street's middle, `along` its run.
func _street_spans(step: float, max_span: float) -> Array[Dictionary]:
	var spans: Array[Dictionary] = []
	for segment in map._open_segments:
		var a := Vector2(segment[0], segment[1])
		var b := Vector2(segment[2], segment[3])
		var length := a.distance_to(b)
		if length < 6.0: continue
		var along := (b - a) / length
		var across := along.orthogonal()
		var t := step * 0.5
		while t < length - 2.0:
			var centre := a + along * t
			t += step
			var walls: Array[float] = []
			for side in [-1.0, 1.0]:
				var reach := 0.0
				while reach < max_span and map._surface.distance_near(centre + across * side * reach) >= 0.0: reach += 0.25
				var wall: Vector2 = centre + across * side * (reach + 1.5)
				if reach >= max_span or not _taken(Rect2(wall - Vector2(0.4, 0.4), Vector2(0.8, 0.8))): break
				walls.append(reach)
			if walls.size() < 2 or walls[0] + walls[1] > max_span: continue
			spans.append({"at": centre + across * (walls[1] - walls[0]) * 0.5, "across": across, "along": along, "span": walls[0] + walls[1]})
	return spans

## How far `p` is from her trunk (the main path's rooms and the roads between).
func _trunk_distance(p: Vector2) -> float:
	var best := INF
	for i in range(map.main_path.size() - 1):
		var a: Vector2 = map.main_path[i]
		var b: Vector2 = map.main_path[i + 1]
		var t := clampf((p - a).dot(b - a) / maxf((b - a).length_squared(), 0.01), 0.0, 1.0)
		best = minf(best, p.distance_to(a.lerp(b, t)))
	return best

func _place_skybridges() -> void:
	var exit := Vector2.INF
	if is_instance_valid(map.exit_node): exit = Vector2(map.exit_node.position.x, map.exit_node.position.z)
	var entry := Vector2(ContinuousWorldMap.ENTRY_POSITION.x, ContinuousWorldMap.ENTRY_POSITION.z)
	var found: Array[Dictionary] = []
	var off_trunk: Array[Dictionary] = []
	for spot in _street_spans(2.0, SKYBRIDGE_WIDTH.y):
		var centre: Vector2 = spot.at
		if float(spot.span) < SKYBRIDGE_WIDTH.x: continue
		if exit != Vector2.INF and centre.distance_to(exit) < SKYBRIDGE_CLEAR: continue
		if centre.distance_to(entry) < 20.0 or not map.bridge_at(centre, 6.0).is_empty(): continue
		if _near_any(zebra_points, centre, 9.0): continue
		(found if _trunk_distance(centre) <= SKYBRIDGE_TRUNK else off_trunk).append(spot)
	# On her trunk first, then by any other road she walks.
	_shuffle_with(found, look_rng)
	_shuffle_with(off_trunk, look_rng)
	found.append_array(off_trunk)
	var want := look_rng.randi_range(SKYBRIDGE_COUNT.x, SKYBRIDGE_COUNT.y)
	for spot in found:
		if skybridge_count >= want: break
		var at: Vector2 = spot.at
		if _near_any(skybridge_points, at, 30.0): continue
		var across: Vector2 = spot.across
		var along: Vector2 = spot.along
		var ground: float = map.ground_height(at)
		# Model x along `across`, stretched so its ends go 0.6 m into the walls.
		var turn := Basis(Vector3.UP, atan2(-across.y, across.x)) * Basis.from_scale(Vector3((float(spot.span) + 1.2) / SKYBRIDGE_SPAN, 1.0, 1.0))
		_add("city_lc_skybridge", Transform3D(turn, Vector3(at.x, ground - 0.02, at.y)))
		for side in [-1.0, 1.0]:
			var pool: Vector2 = at + along * side * 1.9
			lamps.append({"at": Vector3(pool.x, ground + 3.6, pool.y), "color": LANTERN_LIGHT_RED * 1.1, "radius": 5.5})
		skybridge_points.append(at)
		skybridge_count += 1

# --- Side streets ----------------------------------------------------------------------

## 用户 2026-10-14: 避免这种无路的楼，不想让玩家进入的地方画出来但用障碍物拦住.
## The rock between her roads is cut into blocks by a grid of streets she
## cannot walk: drawn at the rock's top, lined with buildings like her own,
## and barricaded where they open on her road (where the bank's wall already
## stops her: the barricade is what she sees stop her). No building stands
## without a street in front of it.
const SIDE_STREET_GAP := Vector2(24.0, 36.0)
## The road's colour per district (FieldArt.terrain_material divides by 0.3).
const ROAD_TINTS := {
	"street": Color(0.3, 0.3, 0.3), "yard": Color(0.37, 0.37, 0.36),
	"site": Color(0.37, 0.31, 0.23), "slum": Color(0.25, 0.24, 0.21),
}
const SIDE_STREET_WIDTH := Vector2(5.5, 7.5)

func _plan_side_streets() -> void:
	var surface = map._surface
	var lo: Vector2 = surface.origin + Vector2(2, 2)
	var hi: Vector2 = surface.origin + Vector2(surface.columns, surface.rows) * surface.CELL - Vector2(2, 2)
	for vertical in [true, false]:
		var across: float = (lo.x if vertical else lo.y) + rng.randf_range(6.0, 18.0)
		var limit: float = hi.x if vertical else hi.y
		while across < limit:
			var width := rng.randf_range(SIDE_STREET_WIDTH.x, SIDE_STREET_WIDTH.y)
			_side_street_line(vertical, across, width, lo, hi)
			across += rng.randf_range(SIDE_STREET_GAP.x, SIDE_STREET_GAP.y)

## One grid line: every stretch of it that lies in the rock, kerb to kerb.
func _side_street_line(vertical: bool, across: float, width: float, lo: Vector2, hi: Vector2) -> void:
	var along := Vector2(0, 1) if vertical else Vector2(1, 0)
	var side := Vector2(1, 0) if vertical else Vector2(0, 1)
	var start: float = lo.y if vertical else lo.x
	var stop: float = hi.y if vertical else hi.x
	var run_from := NAN
	var t := start
	while t <= stop + 1.0:
		var centre := side * across + along * t
		var inside := t <= stop
		if inside:
			for f in [-0.5, 0.0, 0.5]:
				if map._surface.distance_near(centre + side * width * f) > -0.4:
					inside = false
					break
		if inside and is_nan(run_from): run_from = t
		elif not inside and not is_nan(run_from):
			_add_side_street(along, side, across, width, run_from, t - 1.0, start, stop)
			run_from = NAN
		t += 1.0

func _add_side_street(along: Vector2, side: Vector2, across: float, width: float, from: float, to: float, start: float, stop: float) -> void:
	if to - from < 8.0: return
	# An end that stops at her road is a mouth; one that stops anywhere else
	# (the floor's edge, a cliff, a building already there) is a dead end.
	var mouths: Array[Dictionary] = []
	for end in [[from, -1.0], [to, 1.0]]:
		var outward: Vector2 = along * float(end[1])
		var tip: Vector2 = side * across + along * float(end[0])
		if map._surface.distance_near(tip + outward * 1.6) < 0.0: continue
		# Carried on to the kerb, so the street meets her road.
		var reach := 0.0
		while reach < 2.0 and map._surface.distance_near(tip + outward * (reach + 0.5)) < -0.15: reach += 0.5
		if end[1] < 0.0: from -= reach
		else: to += reach
		mouths.append({"tip": tip + outward * reach, "in": -outward})
	var low := side * (across - width * 0.5) + along * from
	var high := side * (across + width * 0.5) + along * to
	var rect := Rect2(low.min(high), (high - low).abs())
	if _taken(rect): return
	if not map.bridge_at(rect.get_center(), maxf(rect.size.x, rect.size.y) * 0.5).is_empty(): return
	_occupy(rect)
	side_streets.append({"rect": rect, "along": along, "side": side, "across": across, "width": width, "from": from, "to": to, "mouths": mouths})

## The side streets' frontages, in the same form as the contour's runs: each
## kerb, its road towards the street's middle.
func _side_street_runs() -> Array[Dictionary]:
	var runs: Array[Dictionary] = []
	for street in side_streets:
		var side: Vector2 = street.side
		for sign in [-1.0, 1.0]:
			# `axis` points from the buildings to the street.
			var axis: Vector2 = side * -sign
			var edge: float = float(street.across) + sign * float(street.width) * 0.5
			var along: Vector2 = axis.orthogonal()
			var a: float = (street.along as Vector2 * float(street.from)).dot(along)
			var b: float = (street.along as Vector2 * float(street.to)).dot(along)
			runs.append({"axis": axis, "across": (side * edge).dot(axis), "from": minf(a, b), "to": maxf(a, b)})
	return runs

## The streets drawn (the floor's own road material, at the rock's top) and
## their mouths barricaded.
func _build_side_streets() -> void:
	if side_streets.is_empty(): return
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for street in side_streets:
		var along: Vector2 = street.along
		var side: Vector2 = street.side
		var width: float = street.width
		# Across: kerb, pavement edge, road, pavement edge, kerb (COLOR.a, as
		# the floor carries it: 0 at the kerb, 1 into the road).
		var cuts := [-0.5, -0.5 + 1.4 / width, 0.5 - 1.4 / width, 0.5]
		var shades := [0.0, 1.0, 1.0, 0.0]
		var t: float = street.from
		while t < float(street.to) - 0.01:
			var next := minf(t + 1.5, float(street.to))
			for k in range(cuts.size() - 1):
				var quad := []
				for corner in [[t, k], [next, k], [next, k + 1], [t, k + 1]]:
					var p: Vector2 = side * (float(street.across) + width * float(cuts[corner[1]])) + along * float(corner[0])
					quad.append([Vector3(p.x, map._surface.top_at(p) + 0.04, p.y), float(shades[corner[1]])])
				for index in [0, 1, 2, 0, 2, 3]:
					var vertex: Array = quad[index]
					var shade: float = vertex[1]
					var tint: Color = ROAD_TINTS.get(map.district_at(side * float(street.across) + along * t), ROAD_TINTS.street)
					tool.set_color(Color(tint, shade))
					tool.set_uv2(Vector2(0.92, 0.0))
					tool.set_normal(Vector3.UP)
					tool.add_vertex(vertex[0])
			t = next
		# The centre line, dashed like her own roads'.
		var dash: float = float(street.from) + 1.0
		while dash + 1.6 < float(street.to):
			var quad: Array[Vector3] = []
			for corner in [[dash, -0.08], [dash + 1.6, -0.08], [dash + 1.6, 0.08], [dash, 0.08]]:
				var p: Vector2 = side * (float(street.across) + float(corner[1])) + along * float(corner[0])
				quad.append(Vector3(p.x, map._surface.top_at(p) + 0.06, p.y))
			for index in [0, 1, 2, 0, 2, 3]:
				tool.set_color(Color(0.78, 0.72, 0.52, 1.0))
				tool.set_uv2(Vector2(0.92, 0.0))
				tool.set_normal(Vector3.UP)
				tool.add_vertex(quad[index])
			dash += 4.0
		_barricade_mouths(street)
	var instance := MeshInstance3D.new()
	instance.name = "SideStreets"
	instance.mesh = tool.commit()
	instance.material_override = FieldArt.terrain_material("city", FieldLight.key(map))
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(instance)

## Across each mouth, a metre in: water barriers, hedgehogs and sandbags shoulder
## to shoulder, no gap.
func _barricade_mouths(street: Dictionary) -> void:
	var side: Vector2 = street.side
	for mouth in street.mouths:
		var at: Vector2 = mouth.tip + (mouth["in"] as Vector2) * 1.0
		var yaw := Basis(Vector3.UP, -side.angle())
		var s := -float(street.width) * 0.5 + 1.0
		var piece := rng.randi_range(0, 2)
		while s <= float(street.width) * 0.5 - 0.8:
			var p: Vector2 = at + side * s
			var name: String = ["city_water_barrier", "city_hedgehog", "city_sandbags"][piece % 3]
			_add(name, Transform3D(yaw * Basis(Vector3.UP, rng.randf_range(-0.12, 0.12)), Vector3(p.x, map._surface.top_at(p) - 0.02, p.y)), true)
			s += 2.0
			piece += 1

# --- Railings --------------------------------------------------------------------------

## Wherever her road's edge has no building front, street barricade or other
## piece behind it, an iron railing along the kerb: with the bank gone the
## edge would otherwise be an unseen wall (用户 2026-10-14: 不想让玩家进入的地方
## 画出来但用障碍物拦住).
var fence_count := 0

func _place_fences() -> void:
	var placed := {}
	for edge in map._surface.contour_edges:
		var a := Vector2(edge[0], edge[1])
		var b := Vector2(edge[2], edge[3])
		var m := (a + b) * 0.5
		var tangent := b - a
		if tangent.length() < 0.05: continue
		var normal := Vector2(-tangent.y, tangent.x).normalized()
		if map._surface.distance_near(m + normal * 0.8) < map._surface.distance_near(m - normal * 0.8): normal = -normal
		if _covered(m - normal * 0.9) or not map.bridge_at(m, 3.0).is_empty(): continue
		var cell := Vector2i(floori(m.x / 2.0), floori(m.y / 2.0))
		var near := false
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				for other in placed.get(cell + Vector2i(dx, dz), []):
					if (other as Vector2).distance_to(m) < 1.95: near = true
		if near: continue
		if not placed.has(cell): placed[cell] = []
		(placed[cell] as Array).append(m)
		var at := m - normal * 0.15
		_add("city_fence", Transform3D(Basis(Vector3.UP, atan2(normal.x, normal.y)), Vector3(at.x, map.ground_height(at) - 0.02, at.y)))
		fence_count += 1

## Street lamps along her roads, at the back of the pavement with their arms
## out over the asphalt, each with its pool of sodium light (TerraceDressing
## bakes `lamps` into the floor's light with its own).
const LAMP_GAP := 14.0
const LAMP_LIGHT := Color(1.0, 0.7, 0.38) * 0.95
## Each district lit its own way: sodium streets, the yards' cold floodlit
## white, the sites' amber work lamps, the slums' weak green-white tubes.
const DISTRICT_LIGHT := {
	"street": Color(1.0, 0.7, 0.38) * 0.95, "yard": Color(0.78, 0.86, 1.0) * 0.95,
	"site": Color(1.0, 0.58, 0.2) * 0.9, "slum": Color(0.62, 0.85, 0.7) * 0.6,
}
var lamps: Array[Dictionary] = []
var street_lamp_count := 0

func _place_lamps() -> void:
	var placed := {}
	var seen := 0
	for edge in map._surface.contour_edges:
		var a := Vector2(edge[0], edge[1])
		var b := Vector2(edge[2], edge[3])
		var m := (a + b) * 0.5
		var tangent := b - a
		if tangent.length() < 0.05: continue
		var normal := Vector2(-tangent.y, tangent.x).normalized()
		if map._surface.distance_near(m + normal * 0.8) < map._surface.distance_near(m - normal * 0.8): normal = -normal
		# Straight kerbs only, with road enough in front for the arm.
		if absf(normal.x) < 0.98 and absf(normal.y) < 0.98: continue
		if map._surface.distance_near(m + normal * 3.0) < 2.0 or not map.bridge_at(m, 4.0).is_empty(): continue
		var key := Vector3i(floori(m.x / LAMP_GAP), floori(m.y / LAMP_GAP), roundi(normal.angle() * 2.0 / PI))
		if placed.has(key): continue
		var near := false
		for other in placed.values():
			if (other as Vector2).distance_to(m) < LAMP_GAP * 0.7: near = true
		if near: continue
		placed[key] = m
		_kerb_points.append(m)
		seen += 1
		if lower and seen % LOWER_LAMP_EVERY != 1: continue
		var foot := m - normal * 0.35
		var ground: float = map.ground_height(m + normal * 1.0)
		_add("city_street_lamp", Transform3D(Basis(Vector3.UP, atan2(normal.x, normal.y)), Vector3(foot.x, ground - 0.02, foot.y)))
		var pool := m + normal * 1.3
		var district: String = map.district_at(m)
		lamps.append({"at": Vector3(pool.x, ground + 1.5, pool.y), "color": DISTRICT_LIGHT.get(district, LAMP_LIGHT), "radius": 7.5})
		street_lamp_count += 1

# --- Neon ------------------------------------------------------------------------------

## 用户 2026-10-16: 龙门还可以优化，比如城区加霓虹灯. The lower city lit by its
## signs (tools/blender/kit/build_city_neon.py): blade signs hung out over the
## street, boards on the facades, frames on the roofs, each its own colour,
## each laying a pool of that colour on the street. Thickest in the outer
## city's streets, a few at the building sites; none in the slums (用户
## 2026-10-16: 贫民窟不做霓虹), a few in the yards.
const NEON_COLOURS := [Color(1.0, 0.3, 0.68), Color(0.25, 0.9, 1.0), Color(1.0, 0.2, 0.24), Color(0.3, 1.0, 0.55),
	Color(1.0, 0.74, 0.22), Color(0.7, 0.38, 1.0)]
## Per district: the chance a building front gets a blade, a board, a roof frame.
const NEON_SHARE := {
	"street": {"blade": 1.0, "board": 0.7, "roof": 0.6},
	"yard": {"blade": 0.35, "board": 0.2, "roof": 0.1},
	"site": {"blade": 0.15, "board": 0.05, "roof": 0.0},
}
## Building fronts that carry signs (not containers, ruins or scaffolds).
const NEON_FRONTS := ["city_tower", "city_shop_house", "city_row_mid", "city_tea_house", "city_row_low_a", "city_row_low_b", "city_row_low_a_worn", "city_row_low_b_worn",
	"city_shack_a", "city_shack_b", "city_shack_c"]
## How strongly a sign lights the street, and how far (用户 2026-10-20:
## 龙门需要更大范围的霓虹).
const NEON_LIGHT := 1.5
const NEON_RADIUS := 11.0
## 下城's signs: pink and violet turned red and amber, and a pool no wider
## than the pavement under them.
const LOWER_NEON := {Color(1.0, 0.3, 0.68): Color(1.0, 0.2, 0.24), Color(0.7, 0.38, 1.0): Color(1.0, 0.74, 0.22)}
const LOWER_NEON_LIGHT := 0.55
const LOWER_NEON_RADIUS := 3.2
## The street fronts placed (_front_piece): where signs can go.
var fronts: Array[Dictionary] = []
var neon_count := 0
var neon_points: Array[Vector2] = []
## The district of the building each sign hangs on.
var neon_districts: Array[String] = []
## Per model path, each placed sign's colour, in the order of `transforms`.
var _neon_colours := {}
var _neon_district := ""

func _place_neon() -> void:
	for f in fronts:
		if not f.name in NEON_FRONTS: continue
		_neon_district = str(f.district)
		var share: Dictionary = NEON_SHARE.get(f.district, {})
		if share.is_empty(): continue
		var kerb: Vector2 = f.kerb
		var axis: Vector2 = f.axis
		var along: Vector2 = f.along
		var floor_y: float = f.floor
		var height: float = f.height
		var yaw := Basis(Vector3.UP, atan2(axis.x, axis.y))
		var ground: float = map.ground_height(kerb + axis * 1.0)
		if rng.randf() < float(share.get("blade", 0.0)) and height >= 4.0:
			var at := kerb + along * rng.randf_range(-f.width * 0.35, f.width * 0.35) - axis * 0.05
			# A one-storey row hangs the short blade at its eaves.
			var model := "city_neon_blade_a" if height >= 6.0 and rng.randf() < 0.6 else "city_neon_blade_b"
			var z := clampf(rng.randf_range(3.8, 6.0), 2.6, maxf(2.6, height - (3.0 if model == "city_neon_blade_a" else 2.1)))
			_add_neon(model, Transform3D(yaw, Vector3(at.x, floor_y + z, at.y)), at + axis * 1.6, ground)
		if rng.randf() < float(share.get("board", 0.0)) and height >= 7.0:
			var at := kerb + along * rng.randf_range(-f.width * 0.2, f.width * 0.2) - axis * 0.02
			_add_neon("city_neon_board", Transform3D(yaw, Vector3(at.x, floor_y + minf(height - 1.4, 6.4), at.y)), at + axis * 1.4, ground)
		if rng.randf() < float(share.get("roof", 0.0)) and f.width >= 6.0 and float(f.spare) > 2.6 * SIGHT:
			var at := kerb - axis * 1.8
			_add_neon("city_neon_roof", Transform3D(yaw, Vector3(at.x, floor_y + height - 0.6, at.y)), kerb + axis * 2.5, ground, 1.4)

## One sign: its model, a colour, and the pool of that colour on the street.
func _add_neon(name: String, placed: Transform3D, pool: Vector2, ground: float, strength: float = 1.0) -> void:
	var colour: Color = NEON_COLOURS[rng.randi_range(0, NEON_COLOURS.size() - 1)]
	# 下城: no pink or violet; the sign lights itself and the kerb under it.
	if lower: colour = LOWER_NEON.get(colour, colour)
	_add(name, placed)
	var path := KIT + name + ".glb"
	if not _neon_colours.has(path): _neon_colours[path] = []
	(_neon_colours[path] as Array).append(colour)
	if lower: lamps.append({"at": Vector3(pool.x, ground + 2.4, pool.y), "color": colour * LOWER_NEON_LIGHT, "radius": LOWER_NEON_RADIUS})
	else: lamps.append({"at": Vector3(pool.x, ground + 2.4, pool.y), "color": colour * NEON_LIGHT * strength, "radius": NEON_RADIUS * strength})
	neon_count += 1
	neon_points.append(pool)
	neon_districts.append(_neon_district)

# --- Street furniture -----------------------------------------------------------------

## 用户 2026-10-14: 加城市中常见摆件，红绿灯什么的. At every street's mouth on a
## junction a traffic light on the right-hand kerb and a zebra crossing; along
## the pavements the district's furniture; burnt-out cars by the kerb of the
## wide roads and in the barricaded streets; manholes down the middle.
## Anything big enough to stand in her way collides.
const KERB_FURNITURE := {
	"street": ["city_hydrant", "city_postbox", "city_bin", "city_phone_booth", "city_vending", "city_bus_stop", "city_bollards"],
	"site": ["city_cones", "city_bin", "city_bollards", "city_hydrant"],
	"yard": ["city_bollards", "city_cones", "city_bin"],
	"slum": ["city_bin", "city_bin", "city_cones"],
}
## Collision box (along the kerb, height, across) of the pieces that block.
const FURNITURE_BOXES := {
	"city_bin": Vector3(1.6, 1.3, 1.0), "city_phone_booth": Vector3(1.05, 2.4, 1.05), "city_vending": Vector3(0.95, 1.9, 0.8),
	"city_bus_stop": Vector3(3.8, 2.6, 1.2), "city_car_wreck": Vector3(4.4, 1.5, 1.8),
}
const FURNITURE_GAP := 8.0
const WRECK_SHARE := 0.12
var _kerb_points: Array[Vector2] = []
var _furniture_points: Array[Vector2] = []
var traffic_light_count := 0
var furniture_count := 0
var wreck_count := 0

func _place_furniture() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_place_junctions(tool)
	_draw_border_lines(tool)
	_place_kerbside()
	_place_side_street_wrecks()
	_place_manholes()
	var instance := MeshInstance3D.new()
	instance.name = "RoadMarkings"
	instance.mesh = tool.commit()
	if instance.mesh != null:
		instance.material_override = FieldArt.terrain_material("city", FieldLight.key(map))
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(instance)

## Cables strung across her streets between the buildings either side, two or
## three together and sagging, at 5–7.5 m: the lower city's overhead tangle.
## Only where both kerbs are built (a cable from nothing reads as a glitch).
const CABLE_COLOUR := Color(0.07, 0.07, 0.08)
var cable_count := 0

func _place_cables() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var laundry := SurfaceTool.new()
	laundry.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in map._open_segments:
		var a := Vector2(segment[0], segment[1])
		var b := Vector2(segment[2], segment[3])
		var length := a.distance_to(b)
		if length < 6.0: continue
		var along := (b - a) / length
		var across := along.orthogonal()
		var t := rng.randf_range(2.0, 8.0)
		while t < length - 2.0:
			var centre := a + along * t
			t += rng.randf_range(9.0, 14.0)
			# Out to each kerb, then a little into the buildings.
			var ends: Array[Vector2] = []
			for side in [-1.0, 1.0]:
				var reach := 0.0
				while reach < 14.0 and map._surface.distance_near(centre + across * side * reach) >= 0.0: reach += 0.5
				var wall: Vector2 = centre + across * side * (reach + 0.6)
				if reach >= 14.0 or not _taken(Rect2(wall - Vector2(0.4, 0.4), Vector2(0.8, 0.8))): break
				ends.append(wall)
			if ends.size() < 2 or not map.bridge_at(centre, 3.0).is_empty(): continue
			var ground: float = map.ground_height(centre)
			for k in range(rng.randi_range(2, 3)):
				var shift := along * rng.randf_range(-0.6, 0.6)
				var h0 := ground + rng.randf_range(5.0, 7.5)
				var h1 := h0 + rng.randf_range(-0.6, 0.6)
				_cable(tool, ends[0] + shift, h0, ends[1] + shift + along * rng.randf_range(-0.8, 0.8), h1, rng.randf_range(0.4, 0.9))
			cable_count += 1
			# 下城: a laundry line strung alongside every other bundle.
			if lower and look_rng.randf() < LOWER_LAUNDRY_SHARE:
				var shift := along * look_rng.randf_range(1.0, 1.6) * (1.0 if look_rng.randf() < 0.5 else -1.0)
				var h := ground + look_rng.randf_range(4.6, 5.6)
				_cable(tool, ends[0] + shift, h, ends[1] + shift, h, 0.35)
				_laundry(laundry, ends[0] + shift, ends[1] + shift, h, 0.35)
				laundry_count += 1
	if laundry_count > 0: _add_laundry_mesh(laundry, "Laundry")
	var mesh := tool.commit()
	if mesh == null: return
	var instance := MeshInstance3D.new()
	instance.name = "Cables"
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = CABLE_COLOUR
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	instance.material_override = material
	# Overhead, so in the lower city they cast their shadows (改造案 §1.3:
	# 只投阴影，不挡角色).
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if lower else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(instance)

## Laundry pegged along a line from `from` to `to` at height `h`: cloths of
## faded colours hanging straight down, a gap now and then.
const LOWER_LAUNDRY_SHARE := 0.5
const LAUNDRY_COLOURS := [Color(0.62, 0.16, 0.13), Color(0.16, 0.32, 0.52), Color(0.7, 0.56, 0.2), Color(0.72, 0.7, 0.66), Color(0.2, 0.42, 0.3), Color(0.52, 0.22, 0.4), Color(0.4, 0.32, 0.24)]
var laundry_count := 0

func _laundry(tool: SurfaceTool, from: Vector2, to: Vector2, h: float, sag: float) -> void:
	var length := from.distance_to(to)
	var along := (to - from) / maxf(length, 0.01)
	var u := look_rng.randf_range(0.6, 1.2)
	while u < length - 0.6:
		var w := look_rng.randf_range(0.35, 0.7)
		var drop := look_rng.randf_range(0.45, 0.85)
		var f := (u + w * 0.5) / length
		var top := h - sag * 4.0 * f * (1.0 - f) - 0.03
		var colour: Color = LAUNDRY_COLOURS[look_rng.randi_range(0, LAUNDRY_COLOURS.size() - 1)]
		var a := from + along * u
		var b := from + along * (u + w)
		tool.set_color(colour)
		for v in [Vector3(a.x, top, a.y), Vector3(b.x, top, b.y), Vector3(b.x, top - drop, b.y), Vector3(a.x, top, a.y), Vector3(b.x, top - drop, b.y), Vector3(a.x, top - drop, a.y)]:
			tool.add_vertex(v)
		u += w + (look_rng.randf_range(0.6, 1.6) if look_rng.randf() < 0.3 else look_rng.randf_range(0.05, 0.2))

## 下城: laundry lines from window to window across her streets, where
## there are buildings on both kerbs, every few metres; clear of the 连廊.
const FRONT_LAUNDRY_SHARE := 0.5

func _place_front_laundry() -> void:
	var line := SurfaceTool.new()
	line.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cloth := SurfaceTool.new()
	cloth.begin(Mesh.PRIMITIVE_TRIANGLES)
	var placed: Array[Vector2] = []
	var before := laundry_count
	for spot in _street_spans(3.0, 12.0):
		var at: Vector2 = spot.at
		if look_rng.randf() > FRONT_LAUNDRY_SHARE or _near_any(placed, at, 7.0) or _near_any(skybridge_points, at, 6.0): continue
		var across: Vector2 = spot.across
		var half: float = float(spot.span) * 0.5 + 0.3
		var h: float = map.ground_height(at) + look_rng.randf_range(4.6, 6.0)
		var from := at - across * half
		var to := at + across * half
		_cable(line, from, h, to, h, 0.3)
		_laundry(cloth, from, to, h, 0.3)
		placed.append(at)
		laundry_count += 1
	if laundry_count == before: return
	_add_laundry_mesh(cloth, "FrontLaundry")
	var instance := MeshInstance3D.new()
	instance.name = "LaundryLines"
	instance.mesh = line.commit()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = CABLE_COLOUR
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	instance.material_override = material
	root.add_child(instance)

## The cloths as one lit, two-sided mesh that casts its shadow.
func _add_laundry_mesh(tool: SurfaceTool, label: String) -> void:
	tool.generate_normals()
	var mesh := tool.commit()
	if mesh == null or mesh.get_surface_count() == 0: return
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	instance.material_override = material
	root.add_child(instance)

## A sagging cable as a flat ribbon facing up (the camera looks down on it).
func _cable(tool: SurfaceTool, from: Vector2, from_h: float, to: Vector2, to_h: float, sag: float) -> void:
	const STEPS := 8
	const HALF := 0.035
	var side := (to - from).normalized().orthogonal() * HALF
	var points: Array[Vector3] = []
	for i in range(STEPS + 1):
		var f := float(i) / STEPS
		var p := from.lerp(to, f)
		points.append(Vector3(p.x, lerpf(from_h, to_h, f) - sag * 4.0 * f * (1.0 - f), p.y))
	for i in range(STEPS):
		var p0 := points[i]
		var p1 := points[i + 1]
		var s3 := Vector3(side.x, 0, side.y)
		for v in [p0 - s3, p1 - s3, p1 + s3, p0 - s3, p1 + s3, p0 + s3]:
			tool.add_vertex(v)

## Each corridor's mouth on a room: the corridor runs square out of the room
## (CityDressing works on the city's square layout), so the mouth is the
## room's box edge along that axis.
## 用户 2026-10-14: 只有标准的道路才加中虚线，标准路口画斑马线，虚线在斑马线前停止并
## 画止车线. A standard road is a straight leg of corridor between two rooms,
## 6–13 m kerb to kerb, outside the slums; its dashes run only where it is
## a road (not through a square, not round its bend). A standard junction is a
## room where three or more such roads meet and that is no square (STANDARD_JUNCTION):
## at each road's mouth on it a zebra crossing, before that the stop line over
## the inbound half (traffic keeps right), the light on that kerb, and the
## dashes stop short of the stop line.
const ROAD_WIDTH := Vector2(6.0, 13.0)
const STANDARD_JUNCTION := 11.0
const DASH := Vector2(1.6, 2.4)
const MARK_WHITE := Color(0.78, 0.77, 0.72)
const MARK_YELLOW := Color(0.66, 0.6, 0.4)

func _place_junctions(tool: SurfaceTool) -> void:
	var standard := {}
	for i in range(map._open_circles.size()):
		var room: Vector3 = map._open_circles[i]
		var centre := Vector2(room.x, room.y)
		if room.z <= STANDARD_JUNCTION and map._degree(i) >= 3 and map.district_at(centre) != "slum" and map.bridge_at(centre, 8.0).is_empty():
			standard[i] = true
	for index in range(map._links.size()):
		var link: Dictionary = map._links[index]
		if not link.alive or link.has("bridge"): continue
		var line: PackedVector2Array = map._link_points(index)
		var legs: Array = []
		for k in range(line.size() - 1):
			if line[k].distance_to(line[k + 1]) > 0.5: legs.append([line[k], line[k + 1], k == 0, k == line.size() - 2])
		for leg in legs:
			var p0: Vector2 = leg[0]
			var p1: Vector2 = leg[1]
			var length := p0.distance_to(p1)
			var axis := (p1 - p0) / length
			var square := Vector2(roundf(axis.x), roundf(axis.y))
			if square.length() != 1.0 or axis.dot(square) < 0.99: continue
			axis = square
			var side := Vector2(-axis.y, axis.x)
			# From each end: a room's edge, or the bend's far kerb.
			var from := _leg_end(int(link.a), axis, leg[2], legs.size() > 1)
			var to := length - _leg_end(int(link.b), -axis, leg[3], legs.size() > 1)
			for end in [[leg[2], int(link.a), p0, axis, 1.0], [leg[3], int(link.b), p1, -axis, -1.0]]:
				if not end[0] or not standard.has(end[1]): continue
				var cut := _mouth(tool, end[1], end[2], end[3], index)
				if cut <= 0.0: continue
				if end[4] > 0.0: from = maxf(from, cut)
				else: to = minf(to, length - cut)
			_dashes(tool, p0, axis, side, from, to)

## Distance in from a leg's end where its own road starts: the room's box edge
## at a room, half a road past the corner at a bend.
func _leg_end(room: int, out: Vector2, at_room: bool, bent: bool) -> float:
	if not at_room: return 7.0 if bent else 0.0
	var r: float = map._open_circles[room].z
	return r * (0.85 if absf(out.x) > 0.5 else 0.7) + 1.5

## The crossing, stop line and light at one road's mouth on a standard
## junction; how far in from the room's centre the dashes may start (0: not
## a standard road here).
func _mouth(tool: SurfaceTool, room: int, centre: Vector2, out: Vector2, index: int) -> float:
	var r: float = map._open_circles[room].z
	var mouth := centre + out * (r * (0.85 if absf(out.x) > 0.5 else 0.7) + 1.0)
	if map.district_at(mouth) == "slum" or not map.bridge_at(mouth, 6.0).is_empty(): return 0.0
	var side := Vector2(-out.y, out.x)
	var zebra := mouth + out * 1.9
	var kerbs := _kerbs(zebra, side)
	if kerbs.x + kerbs.y < ROAD_WIDTH.x or kerbs.x + kerbs.y > ROAD_WIDTH.y: return 0.0
	_zebra_span(tool, zebra, out, side, -kerbs.y + 0.5, kerbs.x - 0.5)
	# Inbound traffic (towards the junction, -out) keeps right: the -side half.
	var stop := mouth + out * 4.1
	_quad(tool, stop, out, side, Vector2(-0.22, 0.22), Vector2(-kerbs.y + 0.4, 0.0), MARK_WHITE)
	var pole := stop - side * (kerbs.y + 0.35) + out * 0.3
	if map._surface.distance_near(pole) < 0.0 and map._surface.distance_near(pole) > -2.5:
		_add("city_traffic_light", Transform3D(Basis(Vector3.UP, atan2(side.x, side.y)), Vector3(pole.x, map.ground_height(pole + side * 0.8) - 0.02, pole.y)))
		_kerb_points.append(pole)
		lamps.append({"at": Vector3(stop.x - side.x * 0.5, map.ground_height(stop) + 1.2, stop.y - side.y * 0.5), "color": Color(0.9, 0.18, 0.12) * 0.55, "radius": 4.0})
		traffic_light_count += 1
	zebra_count += 1
	zebra_points.append(zebra)
	return (mouth - centre).length() + 4.8

## Kerb distances either side of `at` (x along +side, y along -side).
func _kerbs(at: Vector2, side: Vector2) -> Vector2:
	var reach := Vector2.ZERO
	while reach.x < 9.0 and map._surface.distance_near(at + side * (reach.x + 0.25)) >= 0.0: reach.x += 0.25
	while reach.y < 9.0 and map._surface.distance_near(at - side * (reach.y + 0.25)) >= 0.0: reach.y += 0.25
	return reach

## The centre line's dashes between `from` and `to` along the leg, where the
## road there is a standard one.
func _dashes(tool: SurfaceTool, p0: Vector2, axis: Vector2, side: Vector2, from: float, to: float) -> void:
	var t := from
	while t + DASH.x <= to:
		var at := p0 + axis * (t + DASH.x * 0.5)
		var kerbs := _kerbs(at, side)
		var width := kerbs.x + kerbs.y
		if width >= ROAD_WIDTH.x and width <= ROAD_WIDTH.y and absf(kerbs.x - kerbs.y) < 2.5 and map.district_at(at) != "slum":
			_quad(tool, at, axis, side, Vector2(-DASH.x * 0.5, DASH.x * 0.5), Vector2(-0.08, 0.08), MARK_YELLOW)
		t += DASH.x + DASH.y
	dash_count += 1

## A flat painted rectangle: `along` range on `axis`, `across` range on `side`.
func _quad(tool: SurfaceTool, at: Vector2, axis: Vector2, side: Vector2, along: Vector2, across: Vector2, colour: Color) -> void:
	var quad: Array[Vector3] = []
	for corner in [[along.x, across.x], [along.y, across.x], [along.y, across.y], [along.x, across.y]]:
		var q: Vector2 = at + axis * float(corner[0]) + side * float(corner[1])
		quad.append(Vector3(q.x, map.ground_height(q) + 0.032, q.y))
	for k in [0, 1, 2, 0, 2, 3]:
		tool.set_color(Color(colour, 1.0))
		tool.set_uv2(Vector2(1.0, 0.0))
		tool.set_normal(Vector3.UP)
		tool.add_vertex(quad[k])

var zebra_count := 0
var zebra_points: Array[Vector2] = []
var dash_count := 0

## Zebra bars from `low` to `high` across the road, 0.5 m on and off, 3 m long.
func _zebra_span(tool: SurfaceTool, at: Vector2, along: Vector2, side: Vector2, low: float, high: float) -> void:
	var s := low
	while s + 0.5 <= high:
		_quad(tool, at, along, side, Vector2(-1.5, 1.5), Vector2(s, s + 0.5), MARK_WHITE)
		s += 1.0

## White bars across the street, 0.5 m on, 0.5 m off, 3 m long.
func _zebra(tool: SurfaceTool, at: Vector2, along: Vector2, side: Vector2, half: float) -> void:
	var s := -half
	while s + 0.5 <= half:
		var quad: Array[Vector3] = []
		for corner in [[s, -1.5], [s + 0.5, -1.5], [s + 0.5, 1.5], [s, 1.5]]:
			var p: Vector2 = at + side * float(corner[0]) + along * float(corner[1])
			quad.append(Vector3(p.x, map.ground_height(p) + 0.03, p.y))
		for k in [0, 1, 2, 0, 2, 3]:
			tool.set_color(Color(0.78, 0.77, 0.72, 1.0))
			tool.set_uv2(Vector2(1.0, 0.0))
			tool.set_normal(Vector3.UP)
			tool.add_vertex(quad[k])
		s += 1.0

## On the walkable pavement strip, every FURNITURE_GAP or so, off the lamps
## and lights: the district's furniture, its front to the road; now and then
## a wreck parked at the kerb of a wide road.
func _place_kerbside() -> void:
	for edge in map._surface.contour_edges:
		var a := Vector2(edge[0], edge[1])
		var b := Vector2(edge[2], edge[3])
		var m := (a + b) * 0.5
		var tangent := b - a
		if tangent.length() < 0.05: continue
		tangent = tangent.normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		if map._surface.distance_near(m + normal * 0.8) < map._surface.distance_near(m - normal * 0.8): normal = -normal
		if absf(normal.x) < 0.98 and absf(normal.y) < 0.98: continue
		if _near_any(_furniture_points, m, FURNITURE_GAP) or _near_any(_kerb_points, m, 2.5) or not map.bridge_at(m, 4.0).is_empty(): continue
		if rng.randf() < 0.3:
			_furniture_points.append(m)
			continue
		var kind: String = map.district_at(m)
		var yaw := Basis(Vector3.UP, atan2(normal.x, normal.y))
		# A wreck by the kerb where the road is wide enough to drive past it.
		# Sized for the wreck as drawn (PROP_SCALE): the road past it stays open.
		if rng.randf() < WRECK_SHARE and map._surface.distance_near(m + normal * 7.0 * PROP_SCALE) > 2.5 and map._has_clearance(m + normal * 1.6 * PROP_SCALE + normal * 3.0):
			var at := m + normal * 1.6 * PROP_SCALE
			var heading := Basis(Vector3.UP, atan2(tangent.x, tangent.y) + rng.randf_range(-0.25, 0.25))
			_add("city_car_wreck", Transform3D(heading * Basis(Vector3.UP, -PI * 0.5), Vector3(at.x, map.ground_height(at) - 0.03, at.y)))
			_collider(at, tangent, FURNITURE_BOXES.city_car_wreck * PROP_SCALE)
			_furniture_points.append(m)
			wreck_count += 1
			continue
		var choices: Array = KERB_FURNITURE.get(kind, KERB_FURNITURE.street)
		var name: String = choices[rng.randi_range(0, choices.size() - 1)]
		var at := m + normal * 0.7
		if FURNITURE_BOXES.has(name):
			# The road beside it stays wide enough to pass.
			if map._surface.distance_near(m + normal * 5.0) < 2.0: continue
			var box: Vector3 = FURNITURE_BOXES[name] * PROP_SCALE
			at = m + normal * (box.z * 0.5 + 0.1)
			_collider(at, tangent, box)
		_add(name, Transform3D(yaw * Basis(Vector3.UP, rng.randf_range(-0.08, 0.08)), Vector3(at.x, map.ground_height(at) - 0.02, at.y)))
		_furniture_points.append(m)
		furniture_count += 1

## The barricaded streets: cars left where they stopped and bins, nothing
## she can reach.
func _place_side_street_wrecks() -> void:
	for street in side_streets:
		var along: Vector2 = street.along
		var side: Vector2 = street.side
		var length: float = float(street.to) - float(street.from)
		for k in range(rng.randi_range(0, mini(3, int(length / 12.0)))):
			var t := rng.randf_range(float(street.from) + 4.0, float(street.to) - 4.0)
			var offset := rng.randf_range(-0.25, 0.25) * float(street.width)
			var at: Vector2 = side * (float(street.across) + offset) + along * t
			var name := "city_car_wreck" if rng.randf() < 0.6 else "city_bin"
			var heading := Basis(Vector3.UP, atan2(along.x, along.y) + (rng.randf_range(-0.5, 0.5) if name == "city_car_wreck" else rng.randf_range(0, TAU)))
			_add(name, Transform3D(heading * Basis(Vector3.UP, -PI * 0.5), Vector3(at.x, map._surface.top_at(at) + 0.01, at.y)))

## Manholes down her streets, a little off the centre line.
func _place_manholes() -> void:
	for segment in map._open_segments:
		var a := Vector2(segment[0], segment[1])
		var b := Vector2(segment[2], segment[3])
		var length := a.distance_to(b)
		if length < 10.0: continue
		var across := (b - a).normalized().orthogonal()
		var t := rng.randf_range(4.0, 12.0)
		while t < length - 4.0:
			var p := a.lerp(b, t / length) + across * rng.randf_range(-1.8, 1.8)
			if map._surface.distance_near(p) > 1.5 and map.bridge_at(p, 2.0).is_empty():
				_add("city_manhole", Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)), Vector3(p.x, map.ground_height(p) + 0.005, p.y)))
			t += rng.randf_range(14.0, 26.0)

func _covered(p: Vector2) -> bool:
	return _taken(Rect2(p - Vector2(0.3, 0.3), Vector2(0.6, 0.6)))

# --- Street fronts ---------------------------------------------------------------------

## The model's bounds, Godot axes, front towards +Z.
func _bounds_of(name: String) -> AABB:
	if not _bounds.has(name):
		var mesh := TerraceDressing.kit_mesh(load(KIT + name + ".glb"))
		_bounds[name] = mesh.get_aabb() if mesh != null else AABB(Vector3(-2, 0, -2), Vector3(4, 3, 4))
	return _bounds[name]

## Each straight run of road edge, lined with buildings end to end, fronts to
## the kerb. The runs come from the contour (the city's edges are square: see
## ContinuousWorldMap._segment_distance): every edge piece whose road lies
## square to one side, grouped by that side and the line it is on.
func _place_frontage() -> void:
	var lines := {}
	for edge in map._surface.contour_edges:
		var a := Vector2(edge[0], edge[1])
		var b := Vector2(edge[2], edge[3])
		var m := (a + b) * 0.5
		var tangent := b - a
		if tangent.length() < 0.05: continue
		var normal := Vector2(-tangent.y, tangent.x).normalized()
		# Towards the road.
		if map._surface.distance_near(m + normal * 0.8) < map._surface.distance_near(m - normal * 0.8): normal = -normal
		var axis := _front_axis(normal)
		if axis == Vector2.ZERO: continue
		var axis_key := _axis_key(axis)
		var key := Vector3(axis_key.x, axis_key.y, roundf(m.dot(axis) * 2.0) * 0.5)
		if not lines.has(key): lines[key] = []
		(lines[key] as Array).append(m.dot(axis.orthogonal()))
	var runs: Array[Dictionary] = []
	for key in lines:
		var ts: Array = lines[key]
		ts.sort()
		var start: float = ts[0]
		var last: float = ts[0]
		for t in ts.slice(1) + [INF]:
			if float(t) - last > 2.0:
				if last - start >= 3.0: runs.append({"axis": _axis_of_key(Vector2(key.x, key.y)), "across": key.z, "from": start - 0.75, "to": last + 0.75})
				start = t
			last = t
	runs.append_array(_side_street_runs())
	runs.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x.to) - float(x.from) > float(y.to) - float(y.from))
	for run in runs: _line_run(run)

func _axis_of_key(key: Vector2) -> Vector2:
	return key

func _line_run(run: Dictionary) -> void:
	var axis: Vector2 = run.axis
	var along := axis.orthogonal()
	var base: Vector2 = axis * float(run.across)
	var u: float = run.from
	var end: float = run.to
	while u < end - 2.5:
		var at := base + along * u
		# Already built (a side street, a corner house from the other run):
		# no piece would fit, and trying each costs a load-time share.
		var behind := at + along * 0.8 - axis * 1.2
		if _taken(Rect2(behind - Vector2(0.5, 0.5), Vector2(1.0, 1.0))):
			u += 1.5
			continue
		var kind: String = map.district_at(at - axis * 3.0)
		var pieces: Array = _frontage_pieces(kind).duplicate()
		var placed := 0.0
		# The district's own order (tall first) now and then shuffled, so a
		# street is not one row of towers; then any piece that fits.
		if rng.randf() < 0.45: _shuffle(pieces)
		for name in pieces:
			placed = _front_piece(name, base, along, axis, u, end)
			if placed > 0.0: break
		if placed > 0.0:
			# Shoulder to shoulder, with an alley now and then.
			u += placed + (rng.randf_range(1.4, 2.4) if rng.randf() < 0.15 else rng.randf_range(0.0, 0.35))
		else: u += 1.5

func _shuffle_with(list: Array, roll: RandomNumberGenerator) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := roll.randi_range(0, i)
		var swap = list[i]
		list[i] = list[j]
		list[j] = swap

func _shuffle(list: Array) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = list[i]
		list[i] = list[j]
		list[j] = swap

## The lower city builds on its roofs (香港城寨): corrugated rooms knocked up
## on a flat roof, one or two, wherever the camera's sight over the building
## still allows the extra height (`spare`: metres of sight left behind it).
const ROOF_HUT_SHARE := 0.55

func _roof_huts(name: String, rect: Rect2, roof: float, spare: float) -> void:
	if map.region_id != "city" or not name in ["city_tower", "city_shop_house", "city_row_mid", "city_tea_house", "city_row_low_a", "city_row_low_b", "city_row_low_a_worn", "city_row_low_b_worn"]: return
	if rng.randf() > ROOF_HUT_SHARE: return
	var hut: Vector3 = _size_of("city_shack_a")
	for k in range(rng.randi_range(1, 2)):
		var scale := rng.randf_range(0.7, 1.0)
		if hut.y * scale * SIGHT > spare: return
		var inner := rect.grow(-2.2)
		if inner.size.x <= 0.0 or inner.size.y <= 0.0: return
		var at := inner.position + Vector2(rng.randf(), rng.randf()) * inner.size
		var turn := Basis(Vector3.UP, rng.randi_range(0, 3) * PI * 0.5 + rng.randf_range(-0.1, 0.1))
		_add(["city_shack_a", "city_shack_b"][k % 2], Transform3D(turn.scaled(Vector3(scale, scale, scale)), Vector3(at.x, roof, at.y)))

## One piece fronting the run at `u` along it; its width when it fits, else 0.
func _front_piece(name: String, base: Vector2, along: Vector2, axis: Vector2, u: float, end: float) -> float:
	var box := _bounds_of(name)
	var width := box.size.x
	if u + width > end + 0.6: return 0.0
	# Model +Z (its front) turns to face the road along `axis`.
	var yaw := Basis(Vector3.UP, atan2(axis.x, axis.y))
	var side := yaw * Vector3(1, 0, 0)
	# Its near end along the run sits at `u`; its front (model +Z, all signs
	# and air conditioners included) at the kerb.
	var lead := -box.position.x if Vector2(side.x, side.z).dot(along) > 0.0 else box.end.x
	var origin := base + along * (u + lead) - axis * (box.end.z + 0.05)
	var corners: Array[Vector2] = []
	for cx in [box.position.x, box.end.x]:
		for cz in [box.position.z, box.end.z]:
			var local: Vector3 = yaw * Vector3(cx, 0, cz)
			corners.append(origin + Vector2(local.x, local.z))
	var low := corners[0]
	var high := corners[0]
	for c in corners:
		low = low.min(c)
		high = high.max(c)
	var rect := Rect2(low, high - low)
	if _taken(rect.grow(-0.05)): return 0.0
	# In the rock all round, bar the overhang of its signs at the front: its
	# own corners, drawn in 0.6 (a run that is not square to an axis turns
	# the footprint, and its bounding box would reach into the road).
	var middle := rect.get_center()
	var grown := rect.grow(-0.6)
	var inner: Array = [grown.position, Vector2(grown.end.x, grown.position.y), grown.end, Vector2(grown.position.x, grown.end.y), middle]
	if map.region_id != "city":
		inner = corners.map(func(c: Vector2) -> Vector2: return c + (middle - c).normalized() * 0.85)
		inner.append(middle)
	for c in inner:
		if map._surface.distance_near(c) > -0.2: return 0.0
	if not map.bridge_at(rect.get_center(), maxf(rect.size.x, rect.size.y) * 0.5 + 2.0).is_empty(): return 0.0
	# The camera's sight over it: the road north of it stays in view.
	var height := _sight_height(name, box)
	var stack := rng.randi_range(1, 2) if name == "city_container" else 1
	var north := 99.0
	for f in [0.1, 0.5, 0.9]:
		north = minf(north, _open_north(Vector2(lerpf(rect.position.x, rect.end.x, f), rect.end.y + 0.05), height * SIGHT + 4.0))
	var allowance := KERB_HIDE if height <= 5.0 else 0.0
	if height * stack * SIGHT > north + allowance: stack = 1
	if height * stack * SIGHT > north + allowance: return 0.0
	_occupy(rect)
	var floor_y: float = map._surface.top_at(origin) - 0.25
	for c in corners: floor_y = minf(floor_y, map._surface.top_at(c) - 0.25)
	for level in range(stack):
		_add(name, Transform3D(yaw * Basis(Vector3.UP, PI if level == 1 else 0.0), Vector3(origin.x, floor_y + level * box.size.y * rise_of(name), origin.y)))
	_roof_huts(name, rect, floor_y + height - 0.7, north - height * SIGHT)
	fronts.append({"name": name, "kerb": base + along * (u + width * 0.5), "along": along, "axis": axis, "width": width,
		"height": height, "floor": floor_y, "spare": north - height * SIGHT, "district": map.district_at(base + along * (u + width * 0.5) - axis * 3.0)})
	frontage_count += 1
	building_count += 1
	return width

# --- Buildings ------------------------------------------------------------------------

func _place_buildings() -> void:
	var lo: Vector2 = map.SPINE_MIN - Vector2(24, 24)
	var hi: Vector2 = map.SPINE_MAX + Vector2(24, 24)
	# The coarsest grid first (streets' big blocks), then the finer ones fill in.
	for kind in ["street", "site", "yard", "slum"]:
		var plan: Dictionary = DISTRICT_BUILDINGS[kind]
		var step: float = plan.step
		var z := lo.y
		while z < hi.y:
			var x := lo.x
			while x < hi.x:
				var p := Vector2(x + rng.randf_range(-0.6, 0.6), z + rng.randf_range(-0.6, 0.6))
				x += step
				if map.district_at(p) != kind: continue
				if -map._surface.distance_near(p) < 1.5: continue
				if _taken(Rect2(p - Vector2(1.0, 1.0), Vector2(2.0, 2.0))): continue
				_try_building(p, plan.pieces)
			z += step

func _try_building(p: Vector2, pieces: Array) -> void:
	var facing := _facing(p)
	var north := _open_north(p, 20.0)
	# The slums are built by hand, not planned: any shack, in any order.
	var slum: bool = pieces.has("city_shack_a")
	if slum:
		pieces = pieces.duplicate()
		for i in range(pieces.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var swap = pieces[i]
			pieces[i] = pieces[j]
			pieces[j] = swap
	for name in pieces:
		var size: Vector3 = _size_of(name)
		var half := Vector2(size.x, size.z) * 0.5
		if absf(facing.x) > 0.5: half = Vector2(half.y, half.x)
		var rect := Rect2(p - half, half * 2.0)
		if not _clear(rect): continue
		# The camera's sight over it to the road north of it.
		var stack := 1
		var height := size.y
		if name == "city_container": stack = rng.randi_range(1, STACK)
		if (height * stack) * SIGHT > north - half.y:
			if name != "city_container": continue
			stack = maxi(1, floori((north - half.y) / SIGHT / height))
			if height * SIGHT > north - half.y: continue
		_occupy(rect.grow(0.4))
		var yaw := Basis(Vector3.UP, atan2(facing.x, facing.y))
		var base: float = map._surface.top_at(p) - 0.25
		if slum:
			_add_shack(name, p, yaw, base, size, north - half.y)
			building_count += 1
			return
		for level in range(stack):
			var turn := yaw * Basis(Vector3.UP, PI if level % 2 == 1 and name == "city_container" else 0.0)
			_add(name, Transform3D(turn, Vector3(p.x, base + level * height, p.y)))
		building_count += 1
		return

## A shack, a little askew and of its own height, sometimes sunk a step or
## with a lean-to room built on its roof: from the camera the slum is a heap
## of roofs at many levels, not a tiled floor of one.
func _add_shack(name: String, p: Vector2, yaw: Basis, base: float, size: Vector3, sight: float) -> void:
	var turn := yaw * Basis(Vector3.UP, rng.randf_range(-0.16, 0.16))
	var tall := rng.randf_range(0.8, 1.2)
	var sunk := rng.randf_range(-0.7, 0.1)
	_add(name, Transform3D(turn.scaled(Vector3(1.0, tall, 1.0)), Vector3(p.x, base + sunk, p.y)))
	var top := size.y * tall + sunk
	if name == "city_shack_c" or rng.randf() > 0.4: return
	var upper: Vector3 = _size_of("city_shack_a")
	if (top + upper.y * 0.75) * SIGHT > sight: return
	var shift := Vector2(rng.randf_range(-0.2, 0.2) * size.x, rng.randf_range(-0.2, 0.2) * size.z)
	var room := turn * Basis(Vector3.UP, PI * 0.5 * rng.randi_range(0, 3) + rng.randf_range(-0.2, 0.2))
	_add("city_shack_a", Transform3D(room.scaled(Vector3(0.7, 0.75, 0.7)), Vector3(p.x + shift.x, base + top - 0.35, p.y + shift.y)))

## Inside the rock all round, and on no building already placed.
func _clear(rect: Rect2) -> bool:
	for corner in [rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y), rect.get_center()]:
		if map._surface.distance_near(corner) > -0.4: return false
	return not _taken(rect)

## The axis towards the nearest road: a building turns its front (the
## model's +Z, Blender's -Y) that way.
func _facing(p: Vector2) -> Vector2:
	var best := Vector2(0, -1)
	var nearest := INF
	for dir in [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]:
		var t := 1.0
		while t < 30.0 and map._surface.distance_near(p + dir * t) < 0.0: t += 1.0
		if t < nearest:
			nearest = t
			best = dir
	return best

## Metres of rock from `p` northwards (+z, away from the camera) to the first
## open ground; 99 when there is none within reach.
## Searched only as far as `limit`: beyond it, nothing the caller places can
## hide that road anyway.
func _open_north(p: Vector2, limit: float = 40.0) -> float:
	# Two-metre strides, then the metre back: the same answer at half the reads.
	var t := 0.0
	while t < limit:
		if map._surface.distance_near(p + Vector2(0, t)) >= 0.0:
			return t - 1.0 if t >= 1.0 and map._surface.distance_near(p + Vector2(0, t - 1.0)) >= 0.0 else t
		t += 2.0
	return 99.0

# --- On the banks ---------------------------------------------------------------------

## Set into the road's north banks, where the camera sees their fronts: the
## sewer mouths (下水道, the slums' way under the wall) in the slums, and
## scaffolding up the faces of the building sites. Before the buildings, which
## keep off them. Visual only, like the buildings: the bank already stops her.
func _place_banks() -> void:
	var edges: Array = map._surface.contour_edges.duplicate()
	for i in range(edges.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = edges[i]
		edges[i] = edges[j]
		edges[j] = swap
	var slums := 0
	for d in map.districts:
		if d.kind == "slum": slums += 1
	var culverts := mini(slums, 3) if slums > 0 else (1 if rng.randf() < 0.5 else 0)
	var sites := 0
	for d in map.districts:
		if d.kind == "site": sites += 1
	var scaffolds := sites * rng.randi_range(3, 6)
	var placed: Array[Vector2] = []
	for edge in edges:
		if culvert_count >= culverts and scaffold_count >= scaffolds: break
		var m := Vector2((edge[0] + edge[2]) * 0.5, (edge[1] + edge[3]) * 0.5)
		var kind: String = map.district_at(m)
		var name := ""
		if culvert_count < culverts and (kind == "slum" or slums == 0): name = "city_culvert"
		elif scaffold_count < scaffolds and kind == "site": name = "city_scaffold"
		else: continue
		if not _north_bank(m, 3.0) or _near_any(placed, m, 10.0 if name == "city_scaffold" else 16.0) or not map.bridge_at(m, 5.0).is_empty(): continue
		placed.append(m)
		bank_points.append(m)
		var front := Vector2(0, -1)
		var yaw := Basis(Vector3.UP, atan2(front.x, front.y))
		var foot: float = map.ground_height(m + front * 1.2)
		if name == "city_culvert":
			_add(name, Transform3D(yaw, Vector3(m.x, foot - 0.02, m.y + 0.1)))
			_occupy(Rect2(m + Vector2(-3.0, 0.0), Vector2(6.0, 1.6)))
			culvert_count += 1
		else:
			_add(name, Transform3D(yaw, Vector3(m.x, foot - 0.05, m.y + 0.75)))
			_occupy(Rect2(m + Vector2(-2.4, 0.0), Vector2(4.8, 1.8)))
			scaffold_count += 1

## A straight stretch of bank, `half` either side of `m`, with rock behind it
## to the north and level open road in front of it to the south.
func _north_bank(m: Vector2, half: float) -> bool:
	for t in [-half, 0.0, half]:
		var p: Vector2 = m + Vector2(t, 0)
		if absf(map._surface.distance_near(p)) > 0.6: return false
		if map._surface.distance_near(p + Vector2(0, 1.6)) > -0.8: return false
		if map._surface.distance_near(p + Vector2(0, -2.0)) < 0.8: return false
	return map._surface.is_level(m + Vector2(0, -1.5))

# --- The quarantine wall --------------------------------------------------------------

## Along the edge between the slums and any other district: wall panels in the
## rock, a gate where a road crosses the edge.
## 用户 2026-10-14: 地区随机但是需要能分辨出具体区域，区域间用标志性的东西分隔.
## Every edge between two districts is marked by the one with the stronger
## look (BORDER_ORDER): its own wall between the buildings, and its own gate
## where a road crosses — the slums' quarantine wall and checkpoint, the
## warehouse yard's chain-link and guarded gate, the site's blue hoarding and
## its gate. The walls go down before the buildings, which keep off them.
const BORDER_ORDER := ["slum", "yard", "site"]
const BORDERS := {
	"slum": {"wall": "city_wall", "gate": "city_gate", "post": "city_water_barrier", "paint": Color(0.62, 0.16, 0.12)},
	"yard": {"wall": "city_yard_fence", "gate": "city_yard_gate", "light": Color(0.85, 0.92, 1.05), "radius": 13.0, "post": "city_bollards", "paint": Color(0.7, 0.56, 0.12)},
	"site": {"wall": "city_hoarding", "gate": "city_site_gate", "light": Color(1.0, 0.62, 0.22), "radius": 7.0, "post": "city_cones", "paint": Color(0.16, 0.3, 0.56)},
}
const BORDER_STEP := 6.0
## Widest a gate is stretched (its posts on the two kerbs) where the border
## crosses a square instead of a street.
const GATE_STRETCH := 2.4
var border_counts := {}

static func border_kind(a: String, b: String) -> String:
	if a == b: return ""
	for kind in BORDER_ORDER:
		if a == kind or b == kind: return kind
	return ""

func _place_walls() -> void:
	if map.districts.size() < 2: return
	_place_gates()
	var lo: Vector2 = map.SPINE_MIN - Vector2(12, 12)
	var hi: Vector2 = map.SPINE_MAX + Vector2(12, 12)
	var z := lo.y
	while z < hi.y:
		var x := lo.x
		while x < hi.x:
			var p := Vector2(x, z)
			x += BORDER_STEP
			for dir in [Vector2(BORDER_STEP, 0), Vector2(0, BORDER_STEP)]:
				var q: Vector2 = p + dir
				var kind := border_kind(map.district_at(p), map.district_at(q))
				if kind.is_empty(): continue
				var mid: Vector2 = (p + q) * 0.5
				# The panel runs across the step between the two samples.
				var along := Vector2(-dir.y, dir.x).normalized()
				var ends_clear := true
				for f in [-0.45, 0.0, 0.45]:
					if map._surface.distance_near(mid + along * BORDER_STEP * f) > -0.6: ends_clear = false
				if not ends_clear or _near_any(_gate_points, mid, 7.0): continue
				var yaw := Basis(Vector3.UP, -along.angle())
				_add(BORDERS[kind].wall, Transform3D(yaw, Vector3(mid.x, map._surface.top_at(mid) - 0.05, mid.y)))
				var half := Vector2(absf(along.x), absf(along.y)) * BORDER_STEP * 0.5 + Vector2(0.6, 0.6)
				_occupy(Rect2(mid - half, half * 2.0))
				border_counts[kind] = int(border_counts.get(kind, 0)) + 1
		z += BORDER_STEP

var _gate_points: Array[Vector2] = []

## Where a border crosses her road (sampled along the border, as the walls
## are): the border's gate across the road, its posts on the two kerbs — the
## shorter way across, a square's gate stretched to it.
func _place_gates() -> void:
	var lo: Vector2 = map.SPINE_MIN - Vector2(12, 12)
	var hi: Vector2 = map.SPINE_MAX + Vector2(12, 12)
	var step := 2.0
	var z := lo.y
	while z < hi.y:
		var x := lo.x
		while x < hi.x:
			var p := Vector2(x, z)
			x += step
			for dir in [Vector2(step, 0), Vector2(0, step)]:
				var kind := border_kind(map.district_at(p), map.district_at(p + dir))
				if kind.is_empty(): continue
				var mid: Vector2 = p + dir * 0.5
				if map._surface.distance_near(mid) < 1.0 or _near_any(_gate_points, mid, 16.0) or not map.bridge_at(mid, 6.0).is_empty(): continue
				_try_gate(kind, mid)
		z += step
	_place_border_lines()

## Where the border runs over open ground no gate spans (a square, a wide
## junction): a line of the district's paint across the ground and, every
## BORDER_POST_GAP, its posts — the slums' water barriers, the yards'
## bollards, the sites' cones — with room to walk between.
const BORDER_POST_GAP := 6.0
var _border_lines: Array[Dictionary] = []

func _place_border_lines() -> void:
	var lo: Vector2 = map.SPINE_MIN - Vector2(12, 12)
	var hi: Vector2 = map.SPINE_MAX + Vector2(12, 12)
	var step := 2.0
	var posts: Array[Vector2] = []
	var z := lo.y
	while z < hi.y:
		var x := lo.x
		while x < hi.x:
			var p := Vector2(x, z)
			x += step
			for dir in [Vector2(step, 0), Vector2(0, step)]:
				var kind := border_kind(map.district_at(p), map.district_at(p + dir))
				if kind.is_empty(): continue
				var mid: Vector2 = p + dir * 0.5
				if map._surface.distance_near(mid) < 0.4 or _near_any(_gate_points, mid, 8.0) or not map.bridge_at(mid, 4.0).is_empty(): continue
				var along := Vector2(-dir.y, dir.x).normalized()
				_border_lines.append({"at": mid, "along": along, "colour": BORDERS[kind].paint})
				if _near_any(posts, mid, BORDER_POST_GAP) or map._surface.distance_near(mid) < 1.2: continue
				posts.append(mid)
				var name: String = BORDERS[kind].post
				_add(name, Transform3D(Basis(Vector3.UP, -along.angle()), Vector3(mid.x, map.ground_height(mid) - 0.02, mid.y)))
				if name != "city_cones": _collider(mid, along, Vector3(2.1, 0.9, 0.5) * PROP_SCALE)
		z += step

func _draw_border_lines(tool: SurfaceTool) -> void:
	for line in _border_lines:
		var at: Vector2 = line.at
		var along: Vector2 = line.along
		var across := along.orthogonal()
		var quad: Array[Vector3] = []
		for corner in [[-1.05, -0.18], [1.05, -0.18], [1.05, 0.18], [-1.05, 0.18]]:
			var q: Vector2 = at + along * float(corner[0]) + across * float(corner[1])
			quad.append(Vector3(q.x, map.ground_height(q) + 0.035, q.y))
		for k in [0, 1, 2, 0, 2, 3]:
			tool.set_color(Color(line.colour, 1.0))
			tool.set_uv2(Vector2(1.0, 0.0))
			tool.set_normal(Vector3.UP)
			tool.add_vertex(quad[k])

func _try_gate(kind: String, mid: Vector2) -> void:
	var best_axis := Vector2.ZERO
	var best_span := INF
	var best_centre := mid
	for axis in [Vector2(1, 0), Vector2(0, 1)]:
		var reach := [0.0, 0.0]
		for k in range(2):
			var dir: Vector2 = axis * (1.0 if k == 0 else -1.0)
			while reach[k] < 16.0 and map._surface.distance_near(mid + dir * (reach[k] + 0.5)) >= 0.0: reach[k] += 0.5
		if reach[0] >= 16.0 or reach[1] >= 16.0: continue
		var span: float = float(reach[0]) + float(reach[1])
		if span < best_span:
			best_span = span
			best_axis = axis
			best_centre = mid + axis * (float(reach[0]) - float(reach[1])) * 0.5
	if best_axis == Vector2.ZERO: return
	var stretch := maxf(1.0, (best_span + 0.6) / 10.4)
	if stretch > GATE_STRETCH: return
	_gate_points.append(best_centre)
	var yaw := Basis(Vector3.UP, -best_axis.angle())
	_add(BORDERS[kind].gate, Transform3D(yaw * Basis.from_scale(Vector3(stretch, 1.0, 1.0)), Vector3(best_centre.x, map.ground_height(best_centre), best_centre.y)))
	if BORDERS[kind].has("light"):
		lamps.append({"at": Vector3(best_centre.x, map.ground_height(best_centre) + 2.0, best_centre.y), "color": BORDERS[kind].light, "radius": BORDERS[kind].radius})
	gate_count += 1

## A landmark at the heart of a district seen from across the floor: a tower
## crane over each building site, in the rock nearest its centre.
var landmark_count := 0
var landmark_points: Array[Vector2] = []

func _place_landmarks() -> void:
	for d in map.districts:
		if d.kind != "site": continue
		var centre: Vector2 = d.point
		for ring in range(0, 40, 2):
			var done := false
			for k in range(12):
				var p: Vector2 = centre + Vector2.from_angle(TAU * k / 12.0) * ring
				if map.district_at(p) != "site": continue
				var rect := Rect2(p - Vector2(1.8, 1.8), Vector2(3.6, 3.6))
				if _taken(rect) or not _clear(rect): continue
				_occupy(rect)
				var yaw := Basis(Vector3.UP, rng.randf_range(0, TAU))
				_add("city_tower_crane", Transform3D(yaw, Vector3(p.x, map._surface.top_at(p) - 0.1, p.y)))
				var tip := yaw * Vector3(16.0, 0, 0)
				lamps.append({"at": Vector3(p.x + tip.x, map._surface.top_at(p) + 6.0, p.y + tip.z), "color": Color(1.0, 0.25, 0.15) * 0.4, "radius": 4.0})
				landmark_count += 1
				landmark_points.append(p)
				done = true
				break
			if done: break

static func _near_any(points: Array[Vector2], p: Vector2, limit: float) -> bool:
	for other in points:
		if other.distance_to(p) < limit: return true
	return false

# --- Barricades and cover -------------------------------------------------------------

## The pieces of a barricade across her road, in turn.
func _barricade_piece(piece: int) -> String:
	return ["city_water_barrier", "city_sandbags", "city_hedgehog"][piece % 3]

## One or two trunk corridors barricaded across, leaving a gap one person wide.
const BARRICADE_GAP := 2.6
func _place_barricades() -> void:
	var corridors: Array[int] = []
	for index in range(map.main_path.size() - 1):
		if map._links[index].alive and not map._links[index].has("bridge"): corridors.append(index)
	var count := mini(rng.randi_range(1, 2), corridors.size())
	for k in range(count):
		var index: int = corridors.pop_at(rng.randi_range(0, corridors.size() - 1))
		var link: Dictionary = map._links[index]
		var line: PackedVector2Array = map._link_points(index)
		var at: Vector2 = line[0].lerp(line[1], 0.5) if line[0].distance_to(line[1]) > line[1].distance_to(line[2]) else line[1].lerp(line[2], 0.5)
		var heading: Vector2 = (line[1] - line[0]).normalized() if line[0].distance_to(line[1]) > line[1].distance_to(line[2]) else (line[2] - line[1]).normalized()
		var across := heading.orthogonal()
		var half: float = map._link_half_width(index, map._arc_on_link(index, at)) + 1.0
		var gap := rng.randf_range(-half * 0.4, half * 0.4)
		# Laid outwards from the gap, so it is GAP wide whatever the road's width:
		# one person, and the navigation mesh's agent, through.
		var piece := 0
		for side in [-1.0, 1.0]:
			var s: float = gap + side * (BARRICADE_GAP * 0.5 + 1.0)
			while absf(s) < half:
				var p := at + across * s
				if map._surface.distance_near(p) > 0.2:
					var name := _barricade_piece(piece)
					var yaw := Basis(Vector3.UP, -across.angle())
					_add(name, Transform3D(yaw, Vector3(p.x, map.ground_height(p), p.y)), true)
					_collider(p, across, Vector3(2.0, PROP_SCALE, 0.6 * PROP_SCALE))
				s += side * 2.0
				piece += 1
		barricade_count += 1

## Kiosks and sandbag walls in the big rooms, kept off the middle and the rim.
func _place_cover() -> void:
	for i in range(map._open_circles.size()):
		var room: Vector3 = map._open_circles[i]
		if room.z < 10.0: continue
		var centre := Vector2(room.x, room.y)
		for k in range(rng.randi_range(2, 4)):
			var p := centre + Vector2.from_angle(rng.randf_range(0, TAU)) * room.z * rng.randf_range(0.35, 0.6)
			if not map._has_clearance(p): continue
			var name := "city_kiosk" if k == 0 and map.district_at(p) == "street" else "city_sandbags"
			var yaw := Basis(Vector3.UP, rng.randi_range(0, 3) * PI * 0.5)
			# Room to walk round it at both ends and both sides, now it is
			# drawn PROP_SCALE large: a wall against a kerb or another piece
			# shut a pocket of the room off.
			var run := Vector2.RIGHT.rotated(-yaw.get_euler().y)
			var reach := (2.2 if name == "city_kiosk" else 2.4) * PROP_SCALE * 0.5 + 1.4
			var walled := false
			for probe in [p + run * reach, p - run * reach, p + run.orthogonal() * 2.2, p - run.orthogonal() * 2.2]:
				if not map._has_clearance(probe): walled = true
			if walled: continue
			_add(name, Transform3D(yaw, Vector3(p.x, map.ground_height(p), p.y)))
			_collider(p, Vector2.RIGHT.rotated(-yaw.get_euler().y), (Vector3(2.2, 1.0, 1.6) if name == "city_kiosk" else Vector3(2.4, 0.9, 0.5)) * PROP_SCALE)

## A gantry crane over each big warehouse-yard room, legs at its sides.
func _place_gantries() -> void:
	for i in range(map._open_circles.size()):
		var room: Vector3 = map._open_circles[i]
		var centre := Vector2(room.x, room.y)
		if room.z < 9.0 or map.district_at(centre) != "yard": continue
		_add("city_gantry", Transform3D(Basis(Vector3.UP, rng.randi_range(0, 1) * PI * 0.5), Vector3(centre.x, map.ground_height(centre), centre.y)))

## A box that stops her and her shots, standing on the road.
func _collider(p: Vector2, across: Vector2, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.add_to_group("world_obstacle")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	map._generated_root.add_child(body)
	var x := Vector3(across.x, 0, across.y).normalized()
	map.prop_blockers.append([p, Vector2(x.x, x.z), Vector2(size.x, size.z) * 0.5])
	body.transform = Transform3D(Basis(x, Vector3.UP, x.cross(Vector3.UP)), Vector3(p.x, map.ground_height(p) + size.y * 0.5, p.y))
