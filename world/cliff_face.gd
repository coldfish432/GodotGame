class_name CliffFace
extends RefCounted

## One continuous rock face along every cliff line, instead of a row of
## segments: the user asked for the joins to vanish so a cliff reads as one
## piece (2026-10-12).
##
## The terrain's cliff pieces (TerrainSurface.cliff_cuts) are short and come in
## no order, but neighbouring pieces share their end points exactly, so they
## are chained into polylines, smoothed (Chaikin) to take out the grid's
## zigzag, and resampled. A profile is swept along each chain: the foot buried
## in the low floor, stacked strata that each stand a little further back and
## leave a ledge, and a lip that folds back under the upper floor. Every
## deformation is world-space noise and every boundary wobbles continuously
## along the chain, so nothing repeats and there is no seam anywhere. The
## texture is a Blender-baked rock swatch sampled triplanar in world space
## (cliff_face.gdshader), and vertex colours carry the occlusion.
##
## Visual only: the collision wall on the face line stays as it is.
const SHADER := preload("res://world/cliff_face.gdshader")
const CAVE_SHADER := preload("res://world/cliff_face_cave.gdshader")
## Baked in Blender by tools/blender/kit/build_rock_swatch.py. A region
## without its own swatch uses its terrain background, tinted.
const SWATCHES := {"mine": "res://art/kit/textures/mine_rock_swatch.png"}
const TINTS := {"mine": Color(1.25, 1.2, 1.15), "city": Color(0.95, 0.97, 1.0), "snow": Color(0.78, 0.84, 0.9)}
const SPACING := 0.5
## Furthest the rock stands in front of the face line, where the collision
## wall is: past this a player standing at the wall would be inside the rock.
const MAX_FRONT := 0.45
## A chain shorter than this is a stub where a ramp meets a cliff; skipped.
const SMOOTH_PASSES := 8
const DRIFT := 0.6
const MIN_CHAIN := 1.2

var map: Node3D
var noise := FastNoiseLite.new()
var detail := FastNoiseLite.new()
## Each chain: {"points": PackedVector2Array, "low": PackedFloat32Array,
## "high": PackedFloat32Array, "front": PackedVector2Array}.
var chains: Array[Dictionary] = []
var face_length := 0.0
## chains[bank_start:] are rock-bank faces along the contour, not cliffs.
var bank_start := 0
var _banking := false
## A bank face stands closer in: the corridor is narrower than a terrace.
const BANK_FRONT := 0.25
const BANK_DEPTH := 0.6

func build(world: Node3D) -> MeshInstance3D:
	map = world
	noise.seed = map.seed_value ^ 0x51c1ff
	noise.frequency = 0.35
	noise.fractal_octaves = 3
	detail.seed = map.seed_value ^ 0x2a7e
	detail.frequency = 1.6
	detail.fractal_octaves = 2
	_chain(map._surface.cliff_cuts)
	# The off-road rock banks get the same swept face, lower, along the
	# walkable contour: the user found the raised rock did not read as raised.
	var banks: Array[PackedFloat32Array] = []
	# Not in the city (用户 2026-10-14: 这个台子不能删掉吗): the ground between
	# its buildings lies flush with the road; the buildings are the edge.
	for edge in (map._surface.contour_edges if not map.urban else []):
		var a := Vector2(edge[0], edge[1])
		var b := Vector2(edge[2], edge[3])
		var low_a: float = map.ground_height(a)
		var low_b: float = map.ground_height(b)
		# The face tops out where the rock mass does, so the two meet flush.
		banks.append(PackedFloat32Array([a.x, a.y, b.x, b.y, 0.0, 0.0, low_a, map._surface.rock_top_at(a), low_b, map._surface.rock_top_at(b)]))
	bank_start = chains.size()
	_banking = true
	_chain(banks)
	_banking = false
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for chain in chains: _sweep(tool, chain)
	if face_length <= 0.0: return null
	tool.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = "CliffFaces"
	instance.mesh = tool.commit()
	instance.material_override = _material()
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance

func _material() -> ShaderMaterial:
	return rock_material(map.region_id)

## The rock look shared by the swept faces and the terrain's rock mass.
## A region without art of its own (FieldCatalog.art_region) takes its stand-in's
## for anything it has not got.
static func rock_material(region: String) -> ShaderMaterial:
	var own := region
	region = FieldCatalog.art_region(region)
	var material := ShaderMaterial.new()
	material.shader = CAVE_SHADER if own == "mine" else SHADER
	var texture: Texture2D = load(SWATCHES[region]) if SWATCHES.has(region) else FieldArt.BACKGROUNDS[region]
	# Sol's painted face (the city's kerbs and retaining walls, C3) once delivered.
	var face := FieldArt.painted(own + "_wall")
	if face == null: face = FieldArt.painted(region + "_wall")
	material.set_shader_parameter("background_tex", face if face != null else texture)
	material.set_shader_parameter("world_scale", 6.0 if face != null else (4.0 if SWATCHES.has(region) else 12.0))
	var tint: Color = TINTS.get(region, Color.WHITE)
	material.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	# The ground between the buildings (C4), painted, once delivered.
	var top := FieldArt.painted(own + "_block_ground")
	if top == null: top = FieldArt.painted(region + "_block_ground")
	material.set_shader_parameter("top_tex", top if top != null else FieldArt.BACKGROUNDS[region])
	material.set_shader_parameter("top_scale", 6.0 if top != null else 12.0)
	var pave := FieldArt.painted(region + "_pavement")
	if own == "city" and pave != null:
		material.set_shader_parameter("city_pave", true)
		material.set_shader_parameter("pave_tex", pave)
	# 叙拉古: the road's own paving runs on to the houses' feet (用户 2026-10-20:
	# 道路边缘有奇怪的黑色阴影), at the road's gain.
	var stone := FieldArt.painted("siracusa_road") if own == "siracusa" else null
	if stone != null:
		material.set_shader_parameter("city_pave", true)
		material.set_shader_parameter("pave_tex", stone)
		material.set_shader_parameter("pave_scale", 6.0)
		material.set_shader_parameter("pave_gain", 1.6)
	material.set_shader_parameter("top_tint", Vector3.ONE * (0.85 if region == "mine" else 0.95))
	# The mine's cave walls and pillars (TerrainSurface CAVE_WALL).
	if own == "mine":
		material.set_shader_parameter("void_from", 3.0)
		material.set_shader_parameter("void_span", 13.0)
	return material

static func _key(point: Vector2) -> Vector2i:
	return Vector2i(roundi(point.x * 200.0), roundi(point.y * 200.0))

## Pieces into polylines, following shared end points.
func _chain(cuts: Array[PackedFloat32Array]) -> void:
	var ends := {}
	for i in range(cuts.size()):
		for side in range(2):
			var key := _key(Vector2(cuts[i][side * 2], cuts[i][side * 2 + 1]))
			if not ends.has(key): ends[key] = []
			ends[key].append(Vector2i(i, side))
	var used := PackedByteArray()
	used.resize(cuts.size())
	for start in range(cuts.size()):
		if used[start] != 0: continue
		used[start] = 1
		# Grow both ways from this piece.
		var forward := _walk(cuts, ends, used, start, 1)
		var backward := _walk(cuts, ends, used, start, 0)
		backward.reverse()
		var points := PackedVector2Array()
		var low := PackedFloat32Array()
		var high := PackedFloat32Array()
		# Assemble: backward ends ... start piece ... forward ends.
		var sequence: Array = []
		for item in backward: sequence.append(item)
		sequence.append([cuts[start][0], cuts[start][1], cuts[start][6], cuts[start][7]])
		sequence.append([cuts[start][2], cuts[start][3], cuts[start][8], cuts[start][9]])
		for item in forward: sequence.append(item)
		for item in sequence:
			points.append(Vector2(item[0], item[1]))
			low.append(item[2])
			high.append(item[3])
		_add_chain(points, low, high)

## End points reached by walking from piece `start` out of its end `side`.
func _walk(cuts: Array[PackedFloat32Array], ends: Dictionary, used: PackedByteArray, start: int, side: int) -> Array:
	var out: Array = []
	var current := start
	var exit := side
	while true:
		var at := Vector2(cuts[current][exit * 2], cuts[current][exit * 2 + 1])
		var next := -1
		var next_side := 0
		for candidate in ends.get(_key(at), []):
			if used[candidate.x] == 0:
				next = candidate.x
				next_side = candidate.y
				break
		if next < 0: break
		used[next] = 1
		var far := 1 - next_side
		out.append([cuts[next][far * 2], cuts[next][far * 2 + 1], cuts[next][6 + far * 2], cuts[next][7 + far * 2]])
		current = next
		exit = far
	return out

func _add_chain(points: PackedVector2Array, low: PackedFloat32Array, high: PackedFloat32Array) -> void:
	var banking := _banking
	var length := 0.0
	for i in range(1, points.size()): length += points[i - 1].distance_to(points[i])
	if length < MIN_CHAIN: return
	# Chaikin twice: the cut line steps along the 1.5 m grid's diagonals.
	for pass_index in range(2):
		var smooth_points := PackedVector2Array([points[0]])
		var smooth_low := PackedFloat32Array([low[0]])
		var smooth_high := PackedFloat32Array([high[0]])
		for i in range(points.size() - 1):
			for t in [0.25, 0.75]:
				smooth_points.append(points[i].lerp(points[i + 1], t))
				smooth_low.append(lerpf(low[i], low[i + 1], t))
				smooth_high.append(lerpf(high[i], high[i + 1], t))
		smooth_points.append(points[-1])
		smooth_low.append(low[-1])
		smooth_high.append(high[-1])
		points = smooth_points
		low = smooth_low
		high = smooth_high
	# Resample evenly.
	var even := PackedVector2Array()
	var even_low := PackedFloat32Array()
	var even_high := PackedFloat32Array()
	var along := 0.0
	var next_mark := 0.0
	for i in range(points.size() - 1):
		var piece := points[i].distance_to(points[i + 1])
		while next_mark <= along + piece and piece > 0.0:
			var t := (next_mark - along) / piece
			even.append(points[i].lerp(points[i + 1], t))
			even_low.append(lerpf(low[i], low[i + 1], t))
			even_high.append(lerpf(high[i], high[i + 1], t))
			next_mark += SPACING
		along += piece
	even.append(points[-1])
	even_low.append(low[-1])
	even_high.append(high[-1])
	# Chaikin rounds the corners but keeps the grid's staircase; averaging
	# with neighbours, a few times over, straightens it into the line the
	# terraces actually make. Held to DRIFT of the wall, which stays where it is.
	var anchor := even.duplicate()
	# The city's kerbs keep their corners: fewer passes there.
	for pass_index in range(2 if map.urban else SMOOTH_PASSES):
		var relaxed := even.duplicate()
		for i in range(1, even.size() - 1):
			var target := (even[i - 1] + even[i] * 2.0 + even[i + 1]) * 0.25
			relaxed[i] = anchor[i] + (target - anchor[i]).limit_length(DRIFT)
		even = relaxed
	# Front: towards the low floor, read from the ground on either side.
	var front := PackedVector2Array()
	for i in range(even.size()):
		var tangent := (even[mini(i + 1, even.size() - 1)] - even[maxi(i - 1, 0)]).normalized()
		var normal := tangent.orthogonal()
		if banking:
			if map._surface.distance_at(even[i] + normal * 0.9) < map._surface.distance_at(even[i] - normal * 0.9): normal = -normal
		elif map.ground_height(even[i] + normal * 0.9) > map.ground_height(even[i] - normal * 0.9): normal = -normal
		front.append(normal)
	# Smooth the fronts so a single misread sample cannot twist the face.
	var steady := PackedVector2Array()
	for i in range(front.size()):
		var sum := Vector2.ZERO
		for k in range(maxi(0, i - 2), mini(front.size(), i + 3)): sum += front[k]
		steady.append(sum.normalized() if sum.length() > 0.01 else front[i])
	# Where smoothing drew the line back behind the wall, push the face out by
	# that much: the terrain's own flat cliff face stands on the wall and would
	# show through in front of the rock.
	var lag := PackedFloat32Array()
	for i in range(even.size()):
		lag.append(maxf(0.0, -(even[i] - anchor[i]).dot(steady[i])))
	if not banking: face_length += along
	chains.append({"points": even, "low": even_low, "high": even_high, "front": steady, "lag": lag, "length": along, "bank": banking})

## Profile rows at one column: [height, offset in front of the face line, shade].
func _profile(point: Vector2, s: float, low: float, high: float, layers: int, bank: bool = false) -> Array:
	if map.region_id == "snow": return _drift_profile(point, low, high, bank)
	var rise := maxf(high - low, 0.0)
	var rows: Array = []
	rows.append([low - 0.3, 0.42, 0.55])  # buried foot
	var boundaries: Array[float] = []
	for j in range(layers + 1):
		var t := float(j) / layers
		var wobble := 0.0 if j == 0 or j == layers else noise.get_noise_2d(s * 0.4, j * 17.0) * 0.45 * rise / layers
		boundaries.append(low + rise * t + wobble)
	for j in range(layers):
		var bottom: float = boundaries[j]
		var top: float = boundaries[j + 1]
		var tier := float(j) / maxf(layers, 1)
		# Lower strata stand out further; each one leans back towards its top
		# and the next starts behind it, which leaves a ledge.
		var out := 0.36 - 0.3 * tier + noise.get_noise_2d(s * 0.7, j * 31.0 + 5.0) * 0.08
		rows.append([bottom + 0.02, out, 0.8 if j > 0 else 0.68])
		rows.append([lerpf(bottom, top, 0.45), out - 0.03, 0.95])
		rows.append([top - 0.06, out - 0.1, 0.88])
		rows.append([top - 0.01, out - 0.16, 0.72])  # under the next ledge
	rows.append([high + 0.04, -0.02, 0.98])  # lip
	rows.append([high + 0.1, -0.3, 1.0])
	rows.append([high + 0.05, -0.75, 1.0])
	rows.append([high - 0.2, -1.25, 0.9])  # tucked under the upper floor
	for row in rows:
		var world := Vector3(point.x, row[0], point.y)
		var bump := noise.get_noise_3dv(world) * 0.09 + detail.get_noise_3dv(world) * 0.035
		if bank: row[1] = minf((row[1] + bump) * BANK_DEPTH, BANK_FRONT)
		else: row[1] = minf(row[1] + bump, MAX_FRONT)
	return rows

## The snowfield's edge (用户 2026-10-12: 边缘应该缓一点，不应该像矿洞一样):
## no strata, one smooth convex drift from a foot just out on the floor up to
## the top DRIFT_RUN behind the line, the way snow banks against a slope.
const DRIFT_RUN := {"bank": 2.4, "cliff": 1.8}
const DRIFT_ROWS := 8

func _drift_profile(point: Vector2, low: float, high: float, bank: bool) -> Array:
	var rise := maxf(high - low, 0.0)
	var run: float = DRIFT_RUN.bank if bank else DRIFT_RUN.cliff
	var front := minf(BANK_FRONT if bank else MAX_FRONT, 0.35)
	var rows: Array = [[low - 0.25, front + 0.1, 0.8]]
	for k in range(DRIFT_ROWS + 1):
		var t := float(k) / DRIFT_ROWS
		# Convex: steepest at the foot, rounding over into the top.
		var h := low + rise * (1.0 - pow(1.0 - t, 2.2))
		var offset := lerpf(front, -run, t)
		var world := Vector3(point.x, h, point.y)
		offset += noise.get_noise_3dv(world) * 0.12 * (1.0 - t)
		rows.append([h, minf(offset, front + 0.05), lerpf(0.86, 1.02, t)])
	rows.append([high - 0.3, -run - 0.6, 1.0])  # tucked under the top
	return rows

func _sweep(tool: SurfaceTool, chain: Dictionary) -> void:
	var points: PackedVector2Array = chain.points
	var columns: Array = []
	# One strata count per chain, from its tallest point, so every column has
	# the same rows and the sweep stitches without gaps.
	var tallest := 0.0
	for i in range(points.size()): tallest = maxf(tallest, chain.high[i] - chain.low[i])
	var layers := clampi(roundi(tallest / 0.7), 1, 7)
	var along := 0.0
	for i in range(points.size()):
		if i > 0: along += points[i - 1].distance_to(points[i])
		var rows := _profile(points[i], along + points[0].x * 0.37, chain.low[i], chain.high[i], layers, chain.bank)
		# Ends taper into the rock instead of stopping as a cut-off slab.
		var end := minf(along, float(chain.length) - along)
		var fade := smoothstep(0.0, 1.2, end)
		var column := []
		for row in rows:
			var offset: float = lerpf(-0.35, row[1] + chain.lag[i], fade)
			var front: Vector2 = chain.front[i]
			var p: Vector2 = points[i] + front * offset
			column.append([Vector3(p.x, row[0], p.y), row[2]])
		columns.append(column)
	for i in range(columns.size() - 1):
		var a: Array = columns[i]
		var b: Array = columns[i + 1]
		for r in range(mini(a.size(), b.size()) - 1):
			_quad(tool, a[r], b[r], b[r + 1], a[r + 1])

func _quad(tool: SurfaceTool, a: Array, b: Array, c: Array, d: Array) -> void:
	for vertex in [a, b, c, a, c, d]:
		var shade: float = vertex[1]
		tool.set_color(Color(shade, shade, shade))
		tool.add_vertex(vertex[0])
