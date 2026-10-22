class_name TerraceDressing
extends RefCounted

## Lays the Assignment 3 Blender assets (art/models/*.glb, a3/CHANGE-BRIEF.md)
## onto the terraces the generator made, the way 《恐怖黎明》 dresses its
## heightmap: the terrain keeps the shape and the collision, and rock and road
## pieces are placed on top of it.
##
## - Cliffs are one continuous swept face per cliff line (CliffFace), not a
##   row of cliff_wall_segment copies: joined segments showed their seams.
## - Big rocks and clusters of small stones in turn (art/kit/ramp_*rock_*.glb)
##   along both real edges of every sloped stretch of floor. The Assignment 3 arched_ramp_segment used to be
##   stretched over each ramp instead, but its kerbs stood at the planned
##   width, not on the warped cave walls, and showed as a long bright line in
##   the road (用户 2026-10-13: 用了坡道的地方根本看不出来抬高了，角线也没藏好).
## - cliff_rubble_pile every few metres along the foot of each face.
##
## Visual only: no collider, so navigation and every walkability test are
## unchanged, and the pieces are in "field_props" like the other dressing.
## The rocks lining a ramp's sides, per region (用户 2026-10-13: 路边石改为大块
## 岩石和小石头交错，不要现在这种长方体): big boulders, rooted down into the
## causeway's falling side, in turn with clusters of small stones.
const KERBS := {
	"mine": {"big": ["res://art/kit/ramp_rock_big_a.glb", "res://art/kit/ramp_rock_big_b.glb"], "small": ["res://art/kit/ramp_rock_small_a.glb", "res://art/kit/ramp_rock_small_b.glb"]},
	"city": {"big": ["res://art/kit/ramp_rock_big_a.glb", "res://art/kit/ramp_rock_big_b.glb"], "small": ["res://art/kit/ramp_rock_small_a.glb", "res://art/kit/ramp_rock_small_b.glb"]},
	"snow": {"big": ["res://art/kit/ramp_snow_rock_big_a.glb", "res://art/kit/ramp_snow_rock_big_b.glb"], "small": ["res://art/kit/ramp_snow_rock_small_a.glb", "res://art/kit/ramp_snow_rock_small_b.glb"]},
}
## Metres along the edge each kind takes before the next (rolled in the range).
const KERB_STEP := {"big": Vector2(1.6, 2.2), "small": Vector2(0.8, 1.2)}
const KERB_SNOW_BIAS := -0.3
## The boulders and ruined wall: stone, a cap of snow at most.
const STONE_SNOW_BIAS := -0.4
## Floor slope (rise per metre) that counts as ramp: a 2.2 tier over 6.5 is
## 0.34; level floor is 0, and a cliff's samples jump far past the top end.
const KERB_SLOPE := Vector2(0.12, 0.7)
const RUBBLE := preload("res://art/models/cliff_rubble_pile.glb")
const SHADER := preload("res://world/terrace_dressing.gdshader")
const KIT_SHADER := preload("res://world/kit_piece.gdshader")
const KIT_CAVE_SHADER := preload("res://world/kit_piece_cave.gdshader")
const GLOW_SHADER := preload("res://world/kit_glow.gdshader")
## The region whose kit a floor borrows (FieldCatalog.art_region: 叙拉古 uses
## Lungmen's until its own is modelled).
func _look() -> String:
	return FieldCatalog.art_region(map.region_id)

## Light sources and the landmark over the way down, per region (FieldLight).
const LIGHTING := {
	"mine": {"lantern": "res://art/kit/mine_lantern.glb", "post": "res://art/kit/mine_lamp_post.glb", "headframe": "res://art/kit/mine_headframe.glb",
		"warm": Color(1.25, 0.86, 0.4), "goal": Color(0.9, 1.45, 2.3), "extract": Color(0.35, 1.0, 0.55)},
	# Charcoal braziers in the rooms (fire low to the ground), the snow priest's
	# totem over the way down.
	"snow": {"lantern": "res://art/kit/mine_lantern.glb", "post": "res://art/kit/snow_brazier.glb", "headframe": "res://art/kit/snow_totem.glb",
		"warm": Color(1.4, 0.72, 0.3), "goal": Color(0.9, 1.45, 2.3), "extract": Color(0.35, 1.0, 0.55), "post_light": 0.9, "headframe_scale": 1.0},
}
## Waymarks along the corridors, one wall at a time, each with a lantern
## (the snowfield's answer to the mine's timber frames).
const MARKERS := {
	"snow": {"post": "res://art/kit/snow_trail_post.glb", "gap": Vector2(15.0, 26.0), "light": Color(1.1, 0.68, 0.32)},
}
## The forest on the rock off the road (用户 2026-10-12: 要做): conifers on a
## jittered grid, weighted by kind, never on walkable ground. "depth" is how
## far into the rock a tree may stand (metres past the contour).
const FORESTS := {
	# "clump": noise frequency of the stands and clearings (用户 2026-10-12:
	# 有的地方成片，有的地方留出空地); "chance" is a stand's own density.
	"snow": {"step": 3.0, "chance": 0.92, "clump": 0.045, "open": 0.05, "depth": Vector2(2.2, 26.0), "kinds": [
		{"path": "res://art/kit/snow_pine_a.glb", "weight": 3.0, "scale": Vector2(0.8, 1.25)},
		{"path": "res://art/kit/snow_pine_b.glb", "weight": 3.0, "scale": Vector2(0.8, 1.2)},
		{"path": "res://art/kit/snow_pine_c.glb", "weight": 2.0, "scale": Vector2(0.8, 1.3)},
		{"path": "res://art/kit/snow_snag.glb", "weight": 0.6, "scale": Vector2(0.8, 1.1)},
	]},
}
## Rock breaking out of the snow mountains (用户 2026-10-12: 随机生成类似悬崖的
## 岩壁突起): on a jittered grid over deep rock, where a noise ridge says so,
## never taller than the mountain may stand there (TerrainSurface caps it so
## nothing hides a road from the camera).
const CRAGS := {
	"snow": {"step": 7.0, "depth": Vector2(4.0, 30.0), "paths": ["res://art/kit/snow_crag_a.glb", "res://art/kit/snow_crag_b.glb", "res://art/kit/snow_crag_c.glb"], "scale": Vector2(0.8, 1.5)},
	# The mine's rock crowded with stalagmites from the wall's foot up its
	# slope (参考《恐怖黎明》's caves, 用户 2026-10-20).
	"mine": {"step": 3.5, "depth": Vector2(0.6, 9.0), "paths": ["res://art/kit/mine_stalagmites_a.glb", "res://art/kit/mine_stalagmites_b.glb", "res://art/kit/mine_stalagmites_c.glb"], "scale": Vector2(0.8, 1.7)},
}
var crag_transforms := {}
var crag_count := 0
var _crag_spots: Array[Vector3] = []
## Snow lies on a conifer's sloping tiers, not only on flat tops.
const TREE_SNOW_BIAS := 0.12
## Light snowfall following the camera (never a blizzard: the fight must read).
const SNOWFALL := {"snow": true}
## Modelled track laid along each worn corridor, per region: 1.5 m pieces end
## to end, each tilted to the ground under it.
const RAILS := {"mine": "res://art/kit/mine_rail.glb"}
const RAIL_PIECE := 1.5
## Timber support frames spanning the corridors, per region: two posts at the
## walls and a crossbeam overhead. Drawn as plain solid models: the user asked
## for no see-through while she passes under (2026-10-12).
## They replace the mine-entrance sprite the scene dressing used to place.
const FRAMES := {
	"mine": {"post": "res://art/kit/mine_timber_post.glb", "cap": "res://art/kit/mine_timber_cap.glb", "gap": Vector2(14.0, 22.0), "height": 3.0},
}
## Fixed Blender pieces set into and along the swept faces, per region
## (tools/blender/kit). "at": foot = half-sunk in the face at the low floor,
## brace = stood against the face and stretched to the drop, lip = on the rim
## jutting out over the face, floor = on the low floor in front of the face.
## A region listed here uses its own floor pieces instead of cliff_rubble_pile.
const ACCENTS := {
	"mine": [
		{"at": "foot", "paths": ["res://art/kit/mine_cliff_a.glb", "res://art/kit/mine_cliff_b.glb", "res://art/kit/mine_cliff_c.glb"], "gap": Vector2(4.0, 7.0), "scale": Vector2(0.6, 0.8), "min_rise": 1.5},
		{"at": "lip", "paths": ["res://art/kit/mine_ledge_a.glb", "res://art/kit/mine_ledge_b.glb"], "gap": Vector2(5.0, 9.0), "scale": Vector2(1.0, 1.3), "min_rise": 1.5},
		{"at": "brace", "paths": ["res://art/kit/mine_brace.glb"], "gap": Vector2(10.0, 16.0), "scale": Vector2(0.9, 1.05), "min_rise": 1.8},
		{"at": "floor", "paths": ["res://art/kit/mine_rocks_a.glb", "res://art/kit/mine_rocks_b.glb"], "gap": Vector2(4.0, 7.0), "scale": Vector2(0.8, 1.2), "min_rise": 1.0},
		{"at": "floor", "paths": ["res://art/kit/mine_cart.glb"], "gap": Vector2(18.0, 40.0), "scale": Vector2(0.95, 1.05), "min_rise": 1.0},
		# Originium breaking out at the walls' foot, each one a lamp
		# (ORIGINIUM_LIGHT): the cave lit by its own crystals.
		{"at": "foot", "paths": ["res://art/kit/mine_originium_a.glb", "res://art/kit/mine_originium_b.glb"], "gap": Vector2(14.0, 28.0), "scale": Vector2(0.9, 1.4), "min_rise": 1.0},
	],
	# 萨米·冻土林线 (雪原地图调研与方案_v1.md): drifts banked at the cliff foot,
	# icicles under the lip, fallen pines on the floor.
	"snow": [
		{"at": "foot", "paths": ["res://art/kit/snow_drift_a.glb", "res://art/kit/snow_drift_b.glb"], "gap": Vector2(10.0, 18.0), "scale": Vector2(0.55, 0.85), "min_rise": 1.5},
		{"at": "hang", "paths": ["res://art/kit/snow_icicles.glb"], "gap": Vector2(4.0, 9.0), "scale": Vector2(0.9, 1.2), "min_rise": 1.5},
		{"at": "floor", "paths": ["res://art/kit/snow_log.glb"], "gap": Vector2(35.0, 70.0), "scale": Vector2(0.85, 1.1), "min_rise": 1.0},
		# 用户 2026-10-20: 雪原只是需要更多精细的建模. Frost-split boulders and
		# the odd run of Ursus wall along the cliff foot, ice thrust up against it.
		{"at": "floor", "paths": ["res://art/kit/snow_boulders_a.glb", "res://art/kit/snow_boulders_b.glb"], "gap": Vector2(8.0, 16.0), "scale": Vector2(1.2, 2.0), "min_rise": 1.0},
		{"at": "floor", "paths": ["res://art/kit/snow_ruin_a.glb", "res://art/kit/snow_ruin_b.glb"], "gap": Vector2(45.0, 90.0), "scale": Vector2(0.9, 1.1), "min_rise": 1.0},
		{"at": "foot", "paths": ["res://art/kit/snow_ice_shards.glb"], "gap": Vector2(16.0, 30.0), "scale": Vector2(0.9, 1.5), "min_rise": 1.0},
	],
}
## Baked kit colours against the swept face's tinted swatch (CliffFace.TINTS).
const KIT_GAIN := {"mine": 1.25}
## Pieces along one face keep at least this far apart (metres along the line).
const ACCENT_SPACING := 1.8
## Blender colours are dark flat values; over each region's rock grain they
## need lifting by a different amount to land near the terrain's brightness.
const TINT_GAIN := {"mine": 2.2, "city": 1.7, "snow": 1.05}
## The ramp's road surface (Blender #988164) is not drawn: no material can
## match the floor's own shader, and the 0.1 crown does not read from the
## follow camera. The terrain's ramp is the road; the kerbstones line it.
const HIDDEN_SURFACES := ["988164"]

## Metres between rubble piles along a cliff foot (rolled per gap).
const RUBBLE_GAP := Vector2(4.5, 8.0)

## Mine colours are the assets' own; the other regions swap them.
const PALETTES := {
	"city": {"443c31": "4f5459", "5a4f40": "6a6e70", "988164": "786f5a", "6e6a60": "8d8a80", "6b5e4c": "6d7073", "4f463a": "50565b"},
	"snow": {"443c31": "5d6b74", "5a4f40": "8a979e", "988164": "b6c1b5", "6e6a60": "9aa7ad", "6b5e4c": "7f8c93", "4f463a": "5c6870"},
}

var map: Node3D
var rng := RandomNumberGenerator.new()
## The city's buildings, walls and street furniture (city floors only).
var city: CityDressing
## The continuous rock faces swept along the cliff lines.
var cliff_face: CliffFace
var ramp_count := 0
var rubble_count := 0
## Kept here as well as in the MultiMeshes: a headless renderer does not hand
## instance transforms back, and the tests read them.
var ramp_transforms: Array[Transform3D] = []
## The kerb pieces by glb path (ramp_transforms holds all of them).
var kerb_transforms := {}
var rubble_transforms: Array[Transform3D] = []
## Accent transforms by glb path, for the MultiMeshes and the tests.
var accent_transforms := {}
var frame_posts: Array[Transform3D] = []
var frame_caps: Array[Transform3D] = []
var rail_pieces: Array[Transform3D] = []
var rail_network: RailNetwork
var lantern_points: Array[Transform3D] = []
var marker_points: Array[Transform3D] = []
## Trees by glb path.
var tree_transforms := {}
var tree_count := 0
## The snowfall over the camera, moved there by GameManager every frame.
var weather: CPUParticles3D
var post_points: Array[Transform3D] = []
var headframe_points: Array[Transform3D] = []
## Every lamp baked into the light map: {"at", "color", "radius"}.
var lamps: Array[Dictionary] = []
var field_light: FieldLight
## Built again over a vault's dug patch (VaultSeal): the floor-wide pieces
## that are not dressing (the weather, the extraction, the light map) are left
## to the first build.
var patch_only := false

func build(world: Node3D) -> void:
	map = world
	rng.seed = map.seed_value ^ 0x7e11ace
	var root := Node3D.new()
	root.name = "TerraceDressing"
	root.add_to_group("field_props")
	map._generated_root.add_child(root)
	map.mark("scene dressing")
	cliff_face = CliffFace.new()
	var faces := cliff_face.build(map)
	if faces != null: root.add_child(faces)
	map.mark("cliff faces")
	# Lungmen: the blocks off the road are built up (CityDressing); Siracusa's
	# old town the same way, in its own style (SiracusaDressing).
	if map.urban:
		city = SiracusaDressing.new() if map.region_id == "siracusa" else CityDressing.new()
		city.build(map, root)
		lamps.append_array(city.lamps)
		map.mark("city blocks")
	if ACCENTS.has(map.region_id):
		_place_accents(ACCENTS[map.region_id])
		_light_originium()
	else: _place_rubble(rubble_transforms)
	if SCATTER.has(map.region_id): _scatter(SCATTER[map.region_id])
	_place_ramps(ramp_transforms)
	if FRAMES.has(map.region_id): _place_frames(FRAMES[map.region_id])
	if MARKERS.has(map.region_id): _place_markers(MARKERS[map.region_id])
	if RAILS.has(map.region_id): _place_rails(root)
	ramp_count = ramp_transforms.size()
	rubble_count = rubble_transforms.size()
	root.set_meta("cliff_face_length", cliff_face.face_length)
	root.set_meta("ramp_segments", ramp_count)
	root.set_meta("rubble_piles", rubble_count)
	if KERBS.has(_look()):
		for path in KERBS[_look()].big + KERBS[_look()].small:
			# Less snow than other pieces: dark rock against the white is what
			# shows the ramp's edge.
			_add_set(root, "RampKerbs_" + String(path).get_file().get_basename(), kit_mesh(load(path), float(KIT_GAIN.get(map.region_id, 1.0)), KERB_SNOW_BIAS), kerb_transforms.get(path, [] as Array[Transform3D]))
	_add_set(root, "RubblePiles", _regional_mesh(RUBBLE), rubble_transforms)
	if FRAMES.has(map.region_id):
		var frame: Dictionary = FRAMES[map.region_id]
		_add_set(root, "FramePosts", _kit_mesh(load(frame.post)), frame_posts)
		_add_set(root, "FrameCaps", _kit_mesh(load(frame.cap)), frame_caps)
	if rail_network != null:
		_add_set(root, "Sleepers", _kit_mesh(RailNetwork.SLEEPER), rail_network.sleepers)
		_add_set(root, "RailSwitches", _kit_mesh(RailNetwork.SWITCH), rail_network.switches)
	if LIGHTING.has(map.region_id):
		var lit: Dictionary = LIGHTING[map.region_id]
		_place_lights(lit)
		_add_set(root, "Lanterns", _kit_mesh(load(lit.lantern)), lantern_points)
		_add_set(root, "LampPosts", _kit_mesh(load(lit.post)), _enlarged(post_points, PROP_SCALE))
		_add_set(root, "Headframe", _kit_mesh(load(lit.headframe)), headframe_points)
	if MARKERS.has(map.region_id): _add_set(root, "Waymarks", _kit_mesh(load(MARKERS[map.region_id].post)), _enlarged(marker_points, PROP_SCALE))
	map.mark("accents ramps frames lights")
	if CRAGS.has(map.region_id):
		_place_crags(CRAGS[map.region_id])
		for path in crag_transforms:
			_add_set(root, "Crags_" + String(path).get_file().get_basename(), _kit_mesh(load(path)), crag_transforms[path])
	if map.region_id == "mine":
		_place_cave_pillars(root)
		_place_light_shafts(root)
	map.mark("crags")
	if FORESTS.has(map.region_id):
		_place_trees(FORESTS[map.region_id])
		for path in tree_transforms:
			_add_set(root, "Trees_" + String(path).get_file().get_basename(), kit_mesh(load(path), 1.0, TREE_SNOW_BIAS), tree_transforms[path])
	if patch_only: pass
	elif SNOWFALL.has(map.region_id):
		weather = _snowfall()
		root.add_child(weather)
	elif map.weather == "rain":
		weather = _rainfall()
		root.add_child(weather)
	map.mark("trees + snowfall")
	if not patch_only:
		_place_extraction(root)
		field_light = FieldLight.new()
		field_light.build(map, lamps)
	map.mark("extraction + light map")
	for path in accent_transforms:
		# The boulders and the ruined wall keep their stone showing: under the
		# full snow they read as snowballs.
		var bias := STONE_SNOW_BIAS if String(path).contains("snow_boulders") or String(path).contains("snow_ruin") else 0.0
		var label := String(path).get_file().get_basename()
		var placed: Array[Transform3D] = accent_transforms[path]
		if label in PROP_ACCENTS: placed = _enlarged(placed, PROP_SCALE)
		_add_set(root, "Accent_" + label, kit_mesh(load(path), float(KIT_GAIN.get(map.region_id, 1.0)), bias), placed)

## Steps along every face chain for each accent kind, with its own random gap,
## and keeps pieces on one chain apart.
func _place_accents(kinds: Array) -> void:
	for chain in cliff_face.chains:
		var points: PackedVector2Array = chain.points
		var taken: Array[float] = []
		for kind in kinds:
			var gap: Vector2 = kind.gap
			# The first comes early: most chains are shorter than a full gap.
			var next := rng.randf_range(1.0, gap.x)
			var along := 0.0
			for i in range(1, points.size() - 1):
				along += points[i - 1].distance_to(points[i])
				if along < next: continue
				var rise: float = chain.high[i] - chain.low[i]
				if rise < float(kind.min_rise) or _near(taken, along): continue
				var placed: Variant = _accent(kind, chain, i, rise)
				if placed == null: continue
				next = along + rng.randf_range(gap.x, gap.y)
				taken.append(along)
				var paths: Array = kind.paths
				var path: String = paths[rng.randi_range(0, paths.size() - 1)]
				if not accent_transforms.has(path): accent_transforms[path] = [] as Array[Transform3D]
				(accent_transforms[path] as Array[Transform3D]).append(placed)

static func _near(taken: Array[float], along: float) -> bool:
	for other in taken:
		if absf(other - along) < ACCENT_SPACING: return true
	return false

## One accent's transform at column i of a chain, or null where it cannot go.
func _accent(kind: Dictionary, chain: Dictionary, i: int, rise: float) -> Variant:
	var point: Vector2 = chain.points[i]
	var front: Vector2 = chain.front[i]
	var lag: float = chain.lag[i]
	var size: float = rng.randf_range(kind.scale.x, kind.scale.y)
	var facing := Basis.looking_at(Vector3(-front.x, 0, -front.y)) * Basis(Vector3.UP, rng.randf_range(-0.12, 0.12))
	match String(kind.at):
		"foot":
			# Pushed out past the strata so the piece stands proud of the face.
			var at := point + front * (0.45 + lag)
			return Transform3D(facing * Basis.from_scale(Vector3.ONE * size), Vector3(at.x, chain.low[i] - 0.1, at.y))
		"brace":
			var at := point + front * (0.38 + lag)
			return Transform3D(facing * Basis.from_scale(Vector3(size, size, size) * Vector3(1, rise / 2.2, 1)), Vector3(at.x, chain.low[i], at.y))
		"hang":
			# Hangs from the lip, just in front of the face's top.
			var at := point + front * (lag + 0.08)
			var hang := Transform3D(facing * Basis.from_scale(Vector3.ONE * size), Vector3.ZERO)
			return Transform3D(hang.basis, Vector3(at.x, chain.high[i] + 0.05 - 0.58 * size, at.y))
		"lip":
			var at := point + front * lag
			return Transform3D(facing * Basis.from_scale(Vector3.ONE * size), Vector3(at.x, chain.high[i] - 0.05, at.y))
		"floor":
			# Clear of the cliff's foot, where the ground is not level enough to stand on.
			var at := point + front * rng.randf_range(1.6, 2.4) + front.orthogonal() * rng.randf_range(-0.6, 0.6)
			if not map._has_clearance(at): return null
			var turn := Basis(Vector3.UP, rng.randf_range(0.0, TAU))
			return Transform3D(turn * Basis.from_scale(Vector3.ONE * size), Vector3(at.x, map.ground_height(at), at.y))
	return null

## Free-standing pieces against the figures (CityDressing.PROP_SCALE says why):
## drawn this much larger all round. Pieces fitted to a cliff (its foot, lip,
## braces, icicles) and the ramps keep the size the terrain gives them.
const PROP_SCALE := 1.6
const TREE_SCALE := 1.4
const PROP_ACCENTS := ["mine_rocks_a", "mine_rocks_b", "mine_cart", "mine_originium_a", "mine_originium_b", "snow_log", "snow_boulders_a",
	"snow_boulders_b", "snow_ruin_a", "snow_ruin_b", "snow_ice_shards", "snow_shrub"]

static func _enlarged(list: Array[Transform3D], factor: float) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for t in list: out.append(Transform3D(t.basis * Basis.from_scale(Vector3.ONE * factor), t.origin))
	return out

## Each Originium cluster's glow on the rock round it.
const ORIGINIUM_LIGHT := Color(1.0, 0.45, 0.12) * 0.75
func _light_originium() -> void:
	for path in accent_transforms:
		if not String(path).contains("mine_originium"): continue
		for placed: Transform3D in accent_transforms[path]:
			lamps.append({"at": placed.origin + Vector3.UP * 0.9 * PROP_SCALE, "color": ORIGINIUM_LIGHT, "radius": 6.5 * 1.3})

## Small things over the rooms' open floor (stones in the mine, frozen shrubs
## on the tundra), on
## their own generator so nothing else on the floor moves. No collision: they
## are knee high and stand clear of the corridors' middle.
const SCATTER := {
	"mine": {"density": 0.01, "paths": ["res://art/kit/mine_rocks_a.glb", "res://art/kit/mine_rocks_b.glb"], "scale": Vector2(0.35, 0.6)},
	"snow": {"density": 0.012, "paths": ["res://art/kit/snow_shrub.glb", "res://art/kit/snow_shrub.glb", "res://art/kit/snow_ice_shards.glb"], "scale": Vector2(0.7, 1.3)},
}
var scatter_count := 0
func _scatter(scatter: Dictionary) -> void:
	var pick := RandomNumberGenerator.new()
	pick.seed = map.seed_value ^ 0x5ca77e
	var paths: Array = scatter.paths
	for i in range(map._open_circles.size()):
		var room: Vector3 = map._open_circles[i]
		for k in range(roundi(room.z * room.z * PI * float(scatter.density))):
			var at := Vector2(room.x, room.y) + Vector2.from_angle(pick.randf_range(0.0, TAU)) * room.z * sqrt(pick.randf()) * 1.1
			var path: String = paths[pick.randi_range(0, paths.size() - 1)]
			var size := pick.randf_range(scatter.scale.x, scatter.scale.y)
			if map._surface.distance_at(at) < 0.8 or not map._has_clearance(at): continue
			if not accent_transforms.has(path): accent_transforms[path] = [] as Array[Transform3D]
			(accent_transforms[path] as Array[Transform3D]).append(Transform3D(Basis(Vector3.UP, pick.randf_range(0.0, TAU)) * Basis.from_scale(Vector3.ONE * size), Vector3(at.x, map.ground_height(at), at.y)))
			scatter_count += 1

## Support frames along every corridor, away from the rooms: at each spot the
## walls either side are found by walking out to the contour, a post stands
## just inside each wall, and the crossbeam is stretched to meet them.
func _place_frames(frame: Dictionary) -> void:
	var gap: Vector2 = frame.gap
	for segment in map._open_segments:
		var a := Vector2(segment[0], segment[1])
		var b := Vector2(segment[2], segment[3])
		var length := a.distance_to(b)
		if length < 4.0: continue
		var along := (b - a) / length
		var across := along.orthogonal()
		var t := rng.randf_range(2.0, gap.x * 0.6)
		while t < length - 2.0:
			var centre := a + along * t
			t += rng.randf_range(gap.x, gap.y)
			if _in_room(centre) or not map._is_open(centre.x, centre.y, -1.0): continue
			# Not where corridors meet: the walls there do not face each other.
			if _near_other_corridor(centre, segment): continue
			var left := _wall(centre, across)
			var right := _wall(centre, -across)
			if left < 0.0 or right < 0.0: continue
			var span := left + right
			if span < 3.0 or span > 12.0: continue
			var post_l := centre + across * (left - 0.35)
			var post_r := centre - across * (right - 0.35)
			var ground_l: float = map.ground_height(post_l)
			var ground_r: float = map.ground_height(post_r)
			if absf(ground_l - ground_r) > 0.6: continue
			var facing := Basis.looking_at(Vector3(along.x, 0, along.y))
			frame_posts.append(Transform3D(facing, Vector3(post_l.x, ground_l, post_l.y)))
			frame_posts.append(Transform3D(facing, Vector3(post_r.x, ground_r, post_r.y)))
			var middle := (post_l + post_r) * 0.5
			# The asset's 1 m beam runs along its X; X here is `across`.
			var beam := Basis(Vector3(across.x, 0, across.y) * (span - 0.3), Vector3.UP, Vector3(-across.y, 0, across.x))
			frame_caps.append(Transform3D(beam, Vector3(middle.x, maxf(ground_l, ground_r) + float(frame.height), middle.y)))

## Track along every worn corridor segment (the map's trail segments), piece
## after piece, each pointed from its start to its end on the ground so it
## climbs ramps with them.
## The track network: curved lines with branches off them (RailNetwork). The
## sleepers double as rail_pieces, which the search points read to tell
## whether they stand by the track.
func _place_rails(root: Node3D) -> void:
	rail_network = RailNetwork.new()
	var rails := rail_network.build(map)
	if rails != null: root.add_child(rails)
	rail_pieces = rail_network.sleepers

## Lamps by rule (地图表现调研 §2 构图): rooms on the way are lit by a post or
## two, dead ends are left dark, every frame in a corridor carries a lamp, the
## route markers stand under the headframe in a strong cold light, and
## extraction has its own green one. All of it baked into FieldLight.
func _place_lights(lit: Dictionary) -> void:
	var warm: Color = lit.warm
	for cap in frame_caps:
		var hook := cap.origin
		lantern_points.append(Transform3D(Basis.IDENTITY, hook))
		lamps.append({"at": hook + Vector3.DOWN * 0.3, "color": warm * 0.9, "radius": 8.5})
	for i in range(map._open_circles.size()):
		var circle: Vector3 = map._open_circles[i]
		if i == map.exit_chamber or i == map.extraction_chamber: continue
		var kind: String = map.circle_kinds[i]
		if kind == "vault" or kind == "niche": continue
		# A dead end off the way stays dark; the trunk is always lit.
		if kind != "trunk" and map._degree(i) <= 1: continue
		if circle.z < 6.0 or circle_distance_ok(i) == false: continue
		var count := 2 if circle.z >= 12.0 else 1
		for k in range(count):
			var angle := rng.randf_range(0.0, TAU)
			var spot := Vector2(circle.x, circle.y) + Vector2.from_angle(angle) * circle.z * rng.randf_range(0.45, 0.7)
			if not map._has_clearance(spot): continue
			var ground: float = map.ground_height(spot)
			var turn := Basis(Vector3.UP, rng.randf_range(0.0, TAU))
			post_points.append(Transform3D(turn, Vector3(spot.x, ground, spot.y)))
			lamps.append({"at": Vector3(spot.x, ground + float(lit.get("post_light", 2.2)) * PROP_SCALE, spot.y), "color": warm, "radius": 11.0})
	# The way down: headframe behind the three markers, cold and strong.
	if map.exit_chamber >= 0 and map.route_nodes.size() == 3:
		var middle: Vector3 = map.route_nodes[1].position
		var side: Vector3 = map.route_nodes[2].position - map.route_nodes[0].position
		var arrival := Vector2(-side.z, side.x).normalized()
		var centre := Vector2(map._open_circles[map.exit_chamber].x, map._open_circles[map.exit_chamber].y)
		# A cramped room can settle the outer markers on one spot.
		if arrival.is_zero_approx(): arrival = Vector2.UP
		if arrival.dot(Vector2(middle.x, middle.z) - centre) < 0.0: arrival = -arrival
		# Behind the markers if there is room, else beside them, nearer or
		# further: a room's rim is irregular now, so the spot right behind the
		# markers is often rock.
		var offsets: Array[Vector2] = []
		for turn in [0.0, 0.6, -0.6, 1.2, -1.2, 1.8, -1.8]:
			for reach in [5.0, 4.0, 6.0, 3.0]: offsets.append(arrival.rotated(turn) * reach)
		for offset in offsets:
			var spot: Vector2 = Vector2(middle.x, middle.z) + offset
			if not map._is_open(spot.x, spot.y, -2.0): continue
			var ground: float = map.ground_height(spot)
			var facing := Basis.looking_at(Vector3(-arrival.x, 0, -arrival.y)) * Basis.from_scale(Vector3.ONE * float(lit.get("headframe_scale", 1.3)))
			headframe_points.append(Transform3D(facing, Vector3(spot.x, ground, spot.y)))
			lamps.append({"at": Vector3(spot.x, ground + 6.0, spot.y), "color": lit.goal * 0.6, "radius": 10.0})
			break
		lamps.append({"at": middle + Vector3.UP * 2.0, "color": lit.goal, "radius": 13.0})
	if is_instance_valid(map.buff_device_node):
		lamps.append({"at": map.buff_position + Vector3.UP * 1.5, "color": lit.warm * 0.7, "radius": 7.0})

## Extraction is marked by a signal flare (user, 2026-10-12): a burning stick
## in a cairn, green smoke rising from it and a green pool of light, in every
## region. The marker node keeps its label and its place for interaction; its
## placeholder disc is dropped.
const FLARE := preload("res://art/kit/signal_flare.glb")
const FLARE_SCALE := 1.8
const FLARE_LIGHT := Color(0.35, 1.25, 0.5)

func _place_extraction(root: Node3D) -> void:
	var marker := map.exit_node as MeshInstance3D
	if not is_instance_valid(marker) or not marker.visible: return
	marker.mesh = null
	var at := Vector3(marker.position.x, map.ground_height(Vector2(marker.position.x, marker.position.z)), marker.position.z)
	var flare := MeshInstance3D.new()
	flare.name = "SignalFlare"
	flare.mesh = kit_mesh(FLARE)
	root.add_child(flare)
	flare.position = at
	flare.scale = Vector3.ONE * FLARE_SCALE
	flare.rotation.y = rng.randf_range(0.0, TAU)
	var tip := flare.transform * _highest_vertex(flare.mesh)
	root.add_child(_flare_smoke(tip))
	lamps.append({"at": at + Vector3.UP * 1.0, "color": FLARE_LIGHT, "radius": 9.5})
	flare_position = at
	# In Lungmen the flare burns on a helipad (城市地图调研与方案_v1.md ⑪),
	# sunk until only its marked top shows, so nothing steps up onto it.
	if map.region_id == "city":
		var pad := MeshInstance3D.new()
		pad.name = "Helipad"
		pad.mesh = kit_mesh(load("res://art/kit/city_helipad.glb"))
		root.add_child(pad)
		pad.position = at + Vector3.DOWN * 0.27
		pad.rotation.y = flare.rotation.y

var flare_position := Vector3.INF

## The mesh's highest point (the flare's burning tip).
static func _highest_vertex(mesh: Mesh) -> Vector3:
	var best := Vector3(0, -INF, 0)
	for surface in range(mesh.get_surface_count()):
		for v in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			if v.y > best.y: best = v
	return best

## Green smoke rising and spreading from the flare tip, fading out as it goes.
static func _flare_smoke(at: Vector3) -> CPUParticles3D:
	var smoke := CPUParticles3D.new()
	smoke.name = "FlareSmoke"
	smoke.position = at
	smoke.amount = 70
	smoke.lifetime = 6.0
	smoke.preprocess = 6.0
	smoke.direction = Vector3.UP
	smoke.spread = 22.0
	smoke.initial_velocity_min = 0.55
	smoke.initial_velocity_max = 1.0
	smoke.gravity = Vector3(0.22, 0.2, 0.1)  # rises, and drifts off with the air
	smoke.angle_min = 0.0
	smoke.angle_max = 360.0
	smoke.damping_min = 0.15
	smoke.damping_max = 0.3
	smoke.scale_amount_min = 0.55
	smoke.scale_amount_max = 0.85
	var growth := Curve.new()
	growth.add_point(Vector2(0.0, 0.3))
	growth.add_point(Vector2(1.0, 2.8))
	smoke.scale_amount_curve = growth
	var fade := Gradient.new()
	fade.set_color(0, Color(0.7, 1.0, 0.65, 0.7))
	fade.set_color(1, Color(0.3, 0.5, 0.32, 0.0))
	fade.add_point(0.2, Color(0.45, 0.95, 0.5, 0.42))
	fade.add_point(0.6, Color(0.38, 0.7, 0.42, 0.18))
	smoke.color_ramp = fade
	var puff := QuadMesh.new()
	puff.size = Vector2(0.9, 0.9)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var round := GradientTexture2D.new()
	round.fill = GradientTexture2D.FILL_RADIAL
	round.fill_from = Vector2(0.5, 0.5)
	round.fill_to = Vector2(0.5, 0.0)
	round.width = 32
	round.height = 32
	var soft := Gradient.new()
	soft.set_color(0, Color(1, 1, 1, 0.9))
	soft.set_color(1, Color(1, 1, 1, 0))
	soft.add_point(0.55, Color(1, 1, 1, 0.45))
	round.gradient = soft
	material.albedo_texture = round
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	puff.material = material
	smoke.mesh = puff
	return smoke

## Lamps added after the map was dressed (the search points' work lights,
## placed by GameManager once it has spawned them): baked into the light map.
func add_lamps(extra: Array[Dictionary]) -> void:
	lamps.append_array(extra)
	field_light.build(map, lamps)

func circle_distance_ok(i: int) -> bool:
	return i < map.circle_distance.size() and map.circle_distance[i] < INF

func _near_other_corridor(point: Vector2, own: PackedFloat32Array) -> bool:
	for segment in map._open_segments:
		if int(segment[5]) == int(own[5]): continue
		var a := Vector2(segment[0], segment[1])
		var b := Vector2(segment[2], segment[3])
		if Geometry2D.get_closest_point_to_segment(point, a, b).distance_to(point) < float(segment[4]) + 4.0: return true
	return false

## Waymarks: along every corridor, away from rooms and junctions, a post just
## inside one wall (the side alternates at random), with its lantern's light.
func _place_markers(marker: Dictionary) -> void:
	var gap: Vector2 = marker.gap
	for segment in map._open_segments:
		var a := Vector2(segment[0], segment[1])
		var b := Vector2(segment[2], segment[3])
		var length := a.distance_to(b)
		if length < 4.0: continue
		var along := (b - a) / length
		var t := rng.randf_range(2.0, gap.x * 0.6)
		while t < length - 2.0:
			var centre := a + along * t
			t += rng.randf_range(gap.x, gap.y)
			if _in_room(centre) or _near_other_corridor(centre, segment): continue
			var side := along.orthogonal() * (1.0 if rng.randf() < 0.5 else -1.0)
			var wall := _wall(centre, side)
			if wall < 0.0: continue
			var spot := centre + side * (wall - 0.45)
			if not map._has_clearance(spot) and not map._is_open(spot.x, spot.y, -0.4): continue
			var ground: float = map.ground_height(spot)
			# The lantern arm reaches into the corridor.
			var facing := Basis.looking_at(Vector3(side.x, 0, side.y)) * Basis(Vector3.UP, PI / 2)
			marker_points.append(Transform3D(facing, Vector3(spot.x, ground, spot.y)))
			lamps.append({"at": Vector3(spot.x - side.x * 0.6 * PROP_SCALE, ground + 1.6 * PROP_SCALE, spot.y - side.y * 0.6 * PROP_SCALE), "color": marker.light, "radius": 7.5})

## Trees on the rock: a jittered grid inside the map, each spot kept only
## where it is far enough into the rock that the crown stays off the road.
## A tree on the near (camera) side of a road would hide it, so there the
## tallest kinds are dropped and the rest held to the depth they stand at
## (the rule the old sprite props used, SceneDressing._prop).
func _place_trees(forest: Dictionary) -> void:
	var kinds: Array = forest.kinds
	var weights: Array = kinds.map(func(k): return float(k.weight))
	var total := 0.0
	for w in weights: total += w
	var step: float = forest.step
	var depth_range: Vector2 = forest.depth
	var lo: Vector2 = map.SPINE_MIN - Vector2(20, 20)
	var hi: Vector2 = map.SPINE_MAX + Vector2(20, 20)
	# Each kind's height, read once rather than per tree.
	var heights: Array[float] = []
	for kind in kinds: heights.append(TerraceDressing.kit_mesh(load(kind.path)).get_aabb().size.y)
	var clumps := FastNoiseLite.new()
	clumps.seed = map.seed_value ^ 0x7ee5
	clumps.frequency = float(forest.get("clump", 0.05))
	clumps.fractal_octaves = 2
	var z := lo.y
	while z < hi.y:
		var x := lo.x
		while x < hi.x:
			var p := Vector2(x + rng.randf_range(-step * 0.45, step * 0.45), z + rng.randf_range(-step * 0.45, step * 0.45))
			x += step
			# Dense in a stand, nearly empty in a clearing, a soft edge between.
			var stand := smoothstep(-0.15, 0.3, clumps.get_noise_2dv(p))
			var density := lerpf(float(forest.get("open", 0.05)), 1.0, stand) * float(forest.chance)
			if rng.randf() > density: continue
			var depth: float = -map._surface.distance_near(p)
			if depth < depth_range.x or depth > depth_range.y: continue
			if _on_pillar(p) or _on_crag(p): continue
			var pick := rng.randf() * total
			var picked := kinds.size() - 1
			for k in range(kinds.size()):
				pick -= float(weights[k])
				if pick <= 0.0:
					picked = k
					break
			var kind: Dictionary = kinds[picked]
			var scale := rng.randf_range(kind.scale.x, kind.scale.y) * TREE_SCALE
			var height: float = heights[picked] * scale
			# Road to the north of this spot (+z, away from the camera): near bank.
			var toward := Vector2(map._surface.distance_near(p + Vector2(0.8, 0)) - map._surface.distance_near(p - Vector2(0.8, 0)),
				map._surface.distance_near(p + Vector2(0, 0.8)) - map._surface.distance_near(p - Vector2(0, 0.8))).normalized()
			if toward.y > 0.3:
				var limit := (depth - 1.0) * 0.9
				if limit < 2.0: continue
				if height > limit: scale *= limit / height
			var at := Vector3(p.x, map._surface.top_at(p) - 0.15, p.y)
			var turn := Basis(Vector3.UP, rng.randf_range(0.0, TAU))
			if not tree_transforms.has(kind.path): tree_transforms[kind.path] = [] as Array[Transform3D]
			(tree_transforms[kind.path] as Array[Transform3D]).append(Transform3D(turn * Basis.from_scale(Vector3.ONE * scale), at))
			tree_count += 1
		z += step

func _place_crags(crags: Dictionary) -> void:
	var ridges := FastNoiseLite.new()
	ridges.seed = map.seed_value ^ 0xc4a6
	ridges.frequency = 0.05
	var step: float = crags.step
	var span: Vector2 = crags.depth
	var paths: Array = crags.paths
	var sizes := {}
	for path in paths: sizes[path] = TerraceDressing.kit_mesh(load(path)).get_aabb().size
	var lo: Vector2 = map.SPINE_MIN - Vector2(20, 20)
	var hi: Vector2 = map.SPINE_MAX + Vector2(20, 20)
	var z := lo.y
	while z < hi.y:
		var x := lo.x
		while x < hi.x:
			var p := Vector2(x + rng.randf_range(-step * 0.4, step * 0.4), z + rng.randf_range(-step * 0.4, step * 0.4))
			x += step
			if ridges.get_noise_2dv(p) < 0.15: continue
			var depth: float = -map._surface.distance_near(p)
			if depth < span.x or depth > span.y: continue
			var path: String = paths[rng.randi_range(0, paths.size() - 1)]
			var size: Vector3 = sizes[path]
			var scale := rng.randf_range(crags.scale.x, crags.scale.y)
			# No taller than the mountain may stand here (the sight cap).
			var room: float = map._surface.mountain_at(p) + 1.5
			var tall: float = size.y * scale
			if tall > room:
				scale *= room / tall
				if scale < 0.5: continue
			var at := Vector3(p.x, map._surface.top_at(p) - 0.5 * scale, p.y)
			var turn := Basis(Vector3.UP, rng.randf_range(0.0, TAU)) * Basis(Vector3.RIGHT, rng.randf_range(-0.1, 0.1))
			if not crag_transforms.has(path): crag_transforms[path] = [] as Array[Transform3D]
			(crag_transforms[path] as Array[Transform3D]).append(Transform3D(turn * Basis.from_scale(Vector3.ONE * scale), at))
			_crag_spots.append(Vector3(p.x, p.y, size.x * scale * 0.55 + 0.8))
			crag_count += 1
		z += step

## The mine's cave pillars (用户 2026-10-20: 通天的石柱): a column on every rock
## island, scaled to it, rising off the top of the screen into the dark. Its
## own generator, so the rest of the floor's dressing is not reshuffled.
const CAVE_PILLARS := ["res://art/kit/mine_pillar_a.glb", "res://art/kit/mine_pillar_b.glb", "res://art/kit/mine_pillar_c.glb"]
var cave_pillar_count := 0

## Each column: x, z and the radius it covers on screen.
var cave_pillar_spots: Array[Vector3] = []
const CAVE_PILLAR_HEIGHT := 24.0

## Whether rock stands between the camera and her at `at` (GameManager eases
## the cut-away open while it does): a column nearer the camera across her
## line of sight, or the cave wall rising before her. `toward_camera` is the
## camera's way along the ground; at `pitch` a point s metres nearer the camera
## covers her middle once it stands 0.9 + s·tan(pitch) high.
func rock_before(at: Vector3, toward_camera: Vector2, pitch: float) -> bool:
	if map.region_id != "mine" or map._surface == null: return false
	var feet := Vector2(at.x, at.z)
	var slope := tan(pitch)
	for spot in cave_pillar_spots:
		var offset := Vector2(spot.x, spot.y) - feet
		var s := offset.dot(toward_camera)
		if s <= 0.0 or absf(offset.cross(toward_camera)) > spot.z + 1.2: continue
		if CAVE_PILLAR_HEIGHT >= 0.9 + s * slope: return true
	var ground: float = map._surface.ground_at(feet)
	for k in range(1, 16):
		var s := k * 0.7
		for side: float in [-0.9, 0.0, 0.9]:
			var p := feet + toward_camera * s + toward_camera.orthogonal() * side
			if map._surface.top_at(p) - ground >= 0.9 + s * slope: return true
	return false

static func cave_pillars_ready() -> bool:
	return ResourceLoader.exists(CAVE_PILLARS[0])

func _place_cave_pillars(root: Node3D) -> void:
	var paths := CAVE_PILLARS.filter(func(path: String) -> bool: return ResourceLoader.exists(path))
	if paths.is_empty(): return
	var pick := RandomNumberGenerator.new()
	pick.seed = map.seed_value ^ 0x9111a5
	var placed := {}
	for i in range(map._closed_circles.size()):
		var circle: Vector3 = map._closed_circles[i]
		var at := Vector2(circle.x, circle.y)
		var path: String = paths[pick.randi_range(0, paths.size() - 1)]
		var size := circle.z * 0.75
		var basis := Basis(Vector3.UP, pick.randf_range(0.0, TAU)) * Basis.from_scale(Vector3(size, pick.randf_range(0.95, 1.1), size))
		if not placed.has(path): placed[path] = [] as Array[Transform3D]
		(placed[path] as Array[Transform3D]).append(Transform3D(basis, Vector3(at.x, map._surface.ground_at(at) - 0.2, at.y)))
		cave_pillar_spots.append(Vector3(at.x, at.y, size * 1.3))
		cave_pillar_count += 1
	for path in placed:
		var mesh := (_kit_mesh(load(path)) as Mesh).duplicate()
		for surface in range(mesh.get_surface_count()):
			var source := mesh.surface_get_material(surface) as ShaderMaterial
			var material := ShaderMaterial.new()
			material.shader = KIT_CAVE_SHADER
			for parameter in ["albedo_tex", "normal_tex", "gain"]:
				material.set_shader_parameter(parameter, source.get_shader_parameter(parameter))
			material.set_shader_parameter("void_from", 6.0)
			material.set_shader_parameter("void_span", 12.0)
			mesh.surface_set_material(surface, material)
		_add_set(root, "CavePillars_" + String(path).get_file().get_basename(), mesh, placed[path])

## Daylight through cracks in the mine's roof: in some of the bigger rooms, a
## pale shaft from out of sight above, its pool on the floor a spot light's.
const SHAFT_SHADER := preload("res://world/light_shaft.gdshader")
# Rare and faint (用户 2026-10-21: 顶光还是太奇怪了，有点突兀，更柔和并不常见).
const SHAFT_CHANCE := 0.15
const SHAFT_HEIGHT := 22.0
var light_shaft_count := 0

func _place_light_shafts(root: Node3D) -> void:
	var pick := RandomNumberGenerator.new()
	pick.seed = map.seed_value ^ 0x5aaf7
	var material := ShaderMaterial.new()
	material.shader = SHAFT_SHADER
	for i in range(map._open_circles.size()):
		var room: Vector3 = map._open_circles[i]
		if room.z < 7.0 or pick.randf() > SHAFT_CHANCE: continue
		var at := Vector2(room.x, room.y) + Vector2.from_angle(pick.randf_range(0.0, TAU)) * room.z * pick.randf_range(0.0, 0.4)
		if map._surface.distance_at(at) < 2.0: continue
		var ground: float = map._surface.ground_at(at)
		var radius := pick.randf_range(1.6, 2.6)
		var cone := CylinderMesh.new()
		cone.top_radius = radius * 0.55
		cone.bottom_radius = radius
		cone.height = SHAFT_HEIGHT
		cone.cap_top = false
		cone.cap_bottom = false
		cone.radial_segments = 20
		var shaft := MeshInstance3D.new()
		shaft.name = "LightShaft"
		shaft.mesh = cone
		shaft.material_override = material
		shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shaft.position = Vector3(at.x, ground + SHAFT_HEIGHT * 0.5, at.y)
		root.add_child(shaft)
		var sun := SpotLight3D.new()
		sun.name = "ShaftLight"
		sun.light_color = Color(0.78, 0.86, 1.0)
		sun.light_energy = 3.0
		sun.spot_range = SHAFT_HEIGHT + 4.0
		# Wide and fading from the middle out: a soft glow, no edged pool.
		sun.spot_angle = rad_to_deg(atan(radius * 2.4 / SHAFT_HEIGHT))
		sun.spot_angle_attenuation = 3.0
		sun.spot_attenuation = 0.4
		sun.light_specular = 0.2
		sun.position = Vector3(at.x, ground + SHAFT_HEIGHT, at.y)
		sun.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
		root.add_child(sun)
		light_shaft_count += 1

func _on_crag(p: Vector2) -> bool:
	for spot in _crag_spots:
		if Vector2(spot.x, spot.y).distance_to(p) < spot.z: return true
	return false

## Inside (or hard against) a cover pillar: no tree stands on those.
func _on_pillar(p: Vector2) -> bool:
	for i in range(map._closed_circles.size()):
		var pillar: Vector3 = map._closed_circles[i]
		if Vector2(pillar.x, pillar.y).distance_to(p) < map.pillar_reach(i) + 1.0: return true
	return false

## Snow falling over the camera's view: small, sparse flakes drifting with the
## wind, in world space so they do not slide when she runs.
static func _snowfall() -> CPUParticles3D:
	var snow := CPUParticles3D.new()
	snow.name = "Snowfall"
	snow.amount = 420
	snow.lifetime = 6.0
	snow.preprocess = 6.0
	snow.local_coords = false
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(22.0, 0.5, 18.0)
	snow.direction = Vector3.DOWN
	snow.spread = 12.0
	snow.initial_velocity_min = 0.6
	snow.initial_velocity_max = 1.2
	snow.gravity = Vector3(0.5, -1.4, 0.2)
	snow.scale_amount_min = 0.6
	snow.scale_amount_max = 1.2
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.0))
	fade.add_point(0.15, Color(0.95, 0.97, 1.0, 0.85))
	fade.set_color(fade.get_point_count() - 1, Color(0.95, 0.97, 1.0, 0.0))
	snow.color_ramp = fade
	var flake := QuadMesh.new()
	flake.size = Vector2(0.16, 0.16)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	flake.material = material
	snow.mesh = flake
	return snow

## 叙拉古's rain (叙拉古方案 §3.4: 东部湿润，雨季较长): thin streaks falling
## fast and a little slanted, light enough not to hide the street.
static func _rainfall() -> CPUParticles3D:
	var rain := CPUParticles3D.new()
	rain.name = "Rainfall"
	rain.amount = 520
	rain.lifetime = 1.1
	rain.preprocess = 1.1
	rain.local_coords = false
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(22.0, 0.5, 18.0)
	rain.direction = Vector3(0.12, -1.0, 0.05)
	rain.spread = 2.0
	rain.initial_velocity_min = 11.0
	rain.initial_velocity_max = 13.0
	rain.gravity = Vector3(0, -2.0, 0)
	var fade := Gradient.new()
	fade.set_color(0, Color(0.8, 0.86, 0.95, 0.0))
	fade.add_point(0.2, Color(0.8, 0.86, 0.95, 0.45))
	fade.set_color(fade.get_point_count() - 1, Color(0.8, 0.86, 0.95, 0.0))
	rain.color_ramp = fade
	var streak := QuadMesh.new()
	streak.size = Vector2(0.03, 0.7)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	material.billboard_keep_scale = true
	streak.material = material
	rain.mesh = streak
	return rain

## Distance from `point` along `direction` to the wall (the contour), or -1.
func _wall(point: Vector2, direction: Vector2) -> float:
	var d := 0.0
	while d < 7.0:
		d += 0.25
		if map._surface.distance_at(point + direction * d) < 0.15: return d
	return -1.0

func _in_room(point: Vector2) -> bool:
	for circle in map._open_circles:
		if point.distance_to(Vector2(circle.x, circle.y)) < circle.z + 1.5: return true
	return false

## A kit piece's mesh with its baked texture drawn through kit_piece.gdshader.
func _kit_mesh(scene: PackedScene) -> Mesh:
	return kit_mesh(scene, float(KIT_GAIN.get(map.region_id, 1.0)))

## Shared with SceneDressing: a kit glb's mesh, every baked texture drawn
## through kit_piece.gdshader. Cached per path and gain.
static var _kit_cache := {}
static func kit_mesh(scene: PackedScene, gain: float = 1.0, snow_bias: float = 0.0) -> Mesh:
	var key := "%s@%.2f@%.2f" % [scene.resource_path, gain, snow_bias]
	if _kit_cache.has(key): return _kit_cache[key]
	var mesh := _first_mesh(scene.instantiate())
	if mesh == null: return mesh
	mesh = mesh.duplicate()
	for surface in range(mesh.get_surface_count()):
		var source := mesh.surface_get_material(surface) as BaseMaterial3D
		var material := ShaderMaterial.new()
		material.shader = KIT_SHADER
		# A part baked as "<piece>_glow" is a lamp's glass: drawn self-lit (a
		# rebuilt piece exports it as "<piece>_glow.001": the suffix is dropped).
		if source != null and source.resource_name.get_slice(".", 0).ends_with("_glow"):
			material.shader = GLOW_SHADER
		if source != null: material.set_shader_parameter("albedo_tex", source.albedo_texture)
		# The relief baked with the colour (场景渲染统一改造案_v1 S2); the lit base shader reads it.
		if source != null and source.normal_enabled and source.normal_texture != null: material.set_shader_parameter("normal_tex", source.normal_texture)
		if material.shader == KIT_SHADER:
			material.set_shader_parameter("gain", gain)
			material.set_shader_parameter("snow_bias", snow_bias)
		mesh.surface_set_material(surface, material)
	_kit_cache[key] = mesh
	return mesh

func _add_set(root: Node3D, label: String, mesh: Mesh, transforms: Array[Transform3D]) -> void:
	# Nothing stands in a bridge's way: cliff accents, crags and trees by its
	# deck would poke through it. Ramps and the rubble at a cliff's foot stay.
	if not label.begins_with("RampKerbs") and label != "RubblePiles" and not map.bridges.is_empty():
		var clear: Array[Transform3D] = []
		for t in transforms:
			if map.bridge_at(Vector2(t.origin.x, t.origin.z), 2.0).is_empty(): clear.append(t)
		transforms = clear
	if transforms.is_empty() or mesh == null: return
	var instance := MultiMeshInstance3D.new()
	instance.name = label
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in range(transforms.size()): multimesh.set_instance_transform(i, transforms[i])
	instance.multimesh = multimesh
	root.add_child(instance)

## Rubble at the foot of the swept faces, every few metres along each chain,
## where the drop is a real one.
func _place_rubble(rubble: Array[Transform3D]) -> void:
	for chain in cliff_face.chains:
		var points: PackedVector2Array = chain.points
		var next := rng.randf_range(2.0, 4.0)
		var along := 0.0
		for i in range(1, points.size()):
			along += points[i - 1].distance_to(points[i])
			if along < next: continue
			next = along + rng.randf_range(RUBBLE_GAP.x, RUBBLE_GAP.y)
			if chain.high[i] - chain.low[i] < 1.2: continue
			var front: Vector2 = chain.front[i]
			var spot := points[i] + front * rng.randf_range(0.7, 1.1) + front.orthogonal() * rng.randf_range(-0.6, 0.6)
			var scale := rng.randf_range(0.75, 1.15)
			var turn := Basis(Vector3.UP, rng.randf_range(0.0, TAU))
			rubble.append(Transform3D(turn * Basis.from_scale(Vector3.ONE * scale), Vector3(spot.x, map.ground_height(spot), spot.y)))

## Rocks along each bank wherever the floor beside it is a ramp's slope, big
## and small in turn, over the seam between floor and bank. A big one is
## rooted at road level and reaches down the causeway's falling side
## (TerrainSurface._causeways); small stones sit on the road's edge.
func _place_ramps(ramps: Array[Transform3D]) -> void:
	if not KERBS.has(_look()): return
	var kit: Dictionary = KERBS[_look()]
	var laid := 0
	for chain in cliff_face.chains:
		if not chain.bank: continue
		var points: PackedVector2Array = chain.points
		var next := 0.0
		var along := 0.0
		var big := rng.randf() < 0.5
		for i in range(1, points.size()):
			along += points[i - 1].distance_to(points[i])
			if along < next: continue
			var front: Vector2 = chain.front[i]
			# Slope of the floor a step in from the edge.
			var floor_point := points[i] + front * 1.2
			var gx: float = (map.ground_height(floor_point + Vector2(0.75, 0)) - map.ground_height(floor_point - Vector2(0.75, 0))) / 1.5
			var gz: float = (map.ground_height(floor_point + Vector2(0, 0.75)) - map.ground_height(floor_point - Vector2(0, 0.75))) / 1.5
			var slope := Vector2(gx, gz).length()
			if slope < KERB_SLOPE.x or slope > KERB_SLOPE.y:
				next = along + 0.5
				continue
			var kind := "big" if big else "small"
			var step: Vector2 = KERB_STEP[kind]
			next = along + rng.randf_range(step.x, step.y)
			big = not big
			var at := points[i] + front * (0.0 if kind == "big" else 0.35) + Vector2(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.12, 0.12))
			var road: float = map.ground_height(at + front * 0.4)
			var size := rng.randf_range(0.85, 1.15) if kind == "big" else rng.randf_range(0.9, 1.3)
			var turn := Basis(Vector3.UP, rng.randf_range(0.0, TAU)) * Basis.from_scale(Vector3(size, size * rng.randf_range(0.9, 1.15), size))
			var placed := Transform3D(turn, Vector3(at.x, road - (0.15 if kind == "big" else 0.02), at.y))
			var paths: Array = kit[kind]
			var path: String = paths[rng.randi_range(0, paths.size() - 1)]
			if not kerb_transforms.has(path): kerb_transforms[path] = [] as Array[Transform3D]
			(kerb_transforms[path] as Array[Transform3D]).append(placed)
			ramps.append(placed)
			laid += 1

## The asset's mesh drawn with the terrain's look (terrace_dressing.gdshader):
## each surface keeps its Blender colour as a tint over the region's rock
## grain, with the mine colours swapped for the region's own.
func _regional_mesh(scene: PackedScene) -> Mesh:
	var mesh := _first_mesh(scene.instantiate())
	if mesh == null: return mesh
	var palette: Dictionary = PALETTES.get(_look(), {})
	var kept := ArrayMesh.new()
	for surface in range(mesh.get_surface_count()):
		var source := mesh.surface_get_material(surface) as BaseMaterial3D
		var colour := source.albedo_color if source != null else Color.WHITE
		var hex := colour.to_html(false).to_lower()
		if HIDDEN_SURFACES.has(hex): continue
		if palette.has(hex): colour = Color(palette[hex])
		var material := ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter("background_tex", FieldArt.BACKGROUNDS[FieldCatalog.art_region(map.region_id)])
		material.set_shader_parameter("world_scale", 12.0)
		material.set_shader_parameter("tint", Vector3(colour.r, colour.g, colour.b) * float(TINT_GAIN.get(_look(), 2.0)))
		kept.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(surface))
		kept.surface_set_material(kept.get_surface_count() - 1, material)
	return kept

## The glb's single mesh (each asset is one joined object), freeing the scene.
static func _first_mesh(node: Node) -> Mesh:
	var found: Mesh = null
	var stack: Array[Node] = [node]
	while not stack.is_empty() and found == null:
		var current: Node = stack.pop_back()
		if current is MeshInstance3D: found = (current as MeshInstance3D).mesh
		stack.append_array(current.get_children())
	node.free()
	return found
