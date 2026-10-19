class_name RailNetwork
extends RefCounted

## The mine's track as one network with curves and junctions (用户 2026-10-12:
## 铁轨添加弯道和岔路), instead of straight 1.5 m pieces end to end.
##
## The worn corridors (the map's trail links) are joined room by room: at each
## room the two corridors that face each other best run straight through as
## one line, and every other corridor leaves that line as a branch, on an
## S-curve that starts tangent to it — a set of points, with a switch stand
## beside it. Each line is smoothed (Chaikin) so bends become curves, then the
## two rails are swept along it and sleepers are laid every SLEEPER_STEP,
## everything on the ground and tilted to it.
##
## The track is dressing, not a road (用户 2026-10-12: 随机刷小段，不大段铺开):
## of the full network only short random stretches are laid, FRAGMENT long
## with GAP between them, so the mine shows bits of old track here and there.
const SLEEPER := preload("res://art/kit/mine_sleeper.glb")
const SWITCH := preload("res://art/kit/mine_rail_switch.glb")
const STEEL := preload("res://art/kit/textures/mine_rail_steel.png")
const HALF_GAUGE := 0.85
const RAIL_WIDTH := 0.07
const RAIL_HEIGHT := 0.1
const SLEEPER_STEP := 0.75
const SAMPLE := 0.5
## Two corridors run through a room as one line when they turn by at most
## this much (the dot of their outgoing directions is below it).
const THROUGH_DOT := 0.3
## A branch leaves its host line this far from the room's centre and joins
## its own corridor this far out.
const BRANCH_START := 1.2
const BRANCH_JOIN := 5.5
## Length of each laid stretch, and of the bare ground between stretches.
const FRAGMENT := Vector2(8.0, 20.0)
const GAP := Vector2(12.0, 28.0)
const MIN_FRAGMENT := 5.0

var map: Node3D
## Smoothed centre lines, in x/z.
var lines: Array[PackedVector2Array] = []
var sleepers: Array[Transform3D] = []
var switches: Array[Transform3D] = []
var _sleeper_lift := 0.0

## Each trail link's ends: {room, dir (pointing out of the room), mode
## ("through" | "branch" | "end"), partner [link, end] for through, host dir
## for branch}.
var _ends := {}
var _points := {}

func build(world: Node3D) -> MeshInstance3D:
	map = world
	_sleeper_lift = -TerraceDressing.kit_mesh(SLEEPER).get_aabb().position.y
	var links: Array[int] = []
	for index in range(map._links.size()):
		var link: Dictionary = map._links[index]
		# A sealed vault's lane is not dug: no track runs into the rock.
		if link.alive and link.trail and not (map.vault_excluded and index == map._vault_link): links.append(index)
	if links.is_empty(): return null
	for index in links:
		var line := _resample(map._link_points(index), SAMPLE)
		_points[index] = line
		_ends[Vector2i(index, 0)] = {"room": int(map._links[index].a), "dir": (line[mini(4, line.size() - 1)] - line[0]).normalized(), "mode": "end"}
		_ends[Vector2i(index, 1)] = {"room": int(map._links[index].b), "dir": (line[maxi(0, line.size() - 5)] - line[-1]).normalized(), "mode": "end"}
	_pair_rooms()
	_walk_chains(links)
	_keep_fragments()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for line in lines:
		_sweep_rails(tool, line)
		_lay_sleepers(line)
	tool.generate_normals()
	var rails := MeshInstance3D.new()
	rails.name = "RailLines"
	rails.mesh = tool.commit()
	var material := ShaderMaterial.new()
	material.shader = TerraceDressing.KIT_SHADER
	material.set_shader_parameter("albedo_tex", STEEL)
	material.set_shader_parameter("gain", 1.35)
	rails.material_override = material
	return rails

## Cut every line down to short random stretches; a switch stand stays only
## where a kept stretch passes its points.
func _keep_fragments() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = map.seed_value ^ 0x7a11
	var kept: Array[PackedVector2Array] = []
	for line in lines:
		var along := rng.randf_range(0.0, GAP.y)
		var next_start := along
		var piece := PackedVector2Array()
		var piece_end := 0.0
		var run := 0.0
		for i in range(line.size()):
			if i > 0: run += line[i - 1].distance_to(line[i])
			if piece.is_empty():
				if run >= next_start:
					piece.append(line[i])
					piece_end = run + rng.randf_range(FRAGMENT.x, FRAGMENT.y)
				continue
			piece.append(line[i])
			if run >= piece_end or i == line.size() - 1:
				# A stretch cut short by the line's end is dropped, not left as a stub.
				if piece.size() >= 3 and (piece.size() - 1) * SAMPLE >= MIN_FRAGMENT: kept.append(piece)
				piece = PackedVector2Array()
				next_start = run + rng.randf_range(GAP.x, GAP.y)
	lines = kept
	var stands: Array[Transform3D] = []
	for stand in switches:
		var at := Vector2(stand.origin.x, stand.origin.z)
		for line in lines:
			var near := false
			for p in line:
				if p.distance_to(at) < 2.5:
					near = true
					break
			if near:
				stands.append(stand)
				break
	switches = stands

## At each room: the best-facing pair of corridor ends runs through; every
## other end branches off the through line (or, with no through line, ends).
func _pair_rooms() -> void:
	var by_room := {}
	for key in _ends:
		var room: int = _ends[key].room
		if not by_room.has(room): by_room[room] = []
		by_room[room].append(key)
	for room in by_room:
		var keys: Array = by_room[room]
		var best := []
		var best_dot := THROUGH_DOT
		for i in range(keys.size()):
			for j in range(i + 1, keys.size()):
				var dot: float = (_ends[keys[i]].dir as Vector2).dot(_ends[keys[j]].dir)
				if dot < best_dot:
					best_dot = dot
					best = [keys[i], keys[j]]
		if best.is_empty(): continue
		_ends[best[0]].mode = "through"
		_ends[best[0]].partner = best[1]
		_ends[best[1]].mode = "through"
		_ends[best[1]].partner = best[0]
		for key in keys:
			if key in best: continue
			var out: Vector2 = _ends[key].dir
			# The host direction: the through end leaving towards the branch's side.
			var host: Vector2 = _ends[best[0]].dir if (_ends[best[0]].dir as Vector2).dot(out) > (_ends[best[1]].dir as Vector2).dot(out) else _ends[best[1]].dir
			_ends[key].mode = "branch"
			_ends[key].host = host

## Chains of links joined through rooms, with branch curves at branch ends.
func _walk_chains(links: Array[int]) -> void:
	var done := {}
	for start in links:
		if done.has(start): continue
		# Walk back to an end that is not "through", so the chain starts there.
		var link := start
		var end := 0
		var guard := 0
		while _ends[Vector2i(link, end)].mode == "through" and guard < 64:
			var partner: Vector2i = _ends[Vector2i(link, end)].partner
			if done.has(partner.x) or partner.x == start and guard > 0: break
			link = partner.x
			end = 1 - partner.y
			guard += 1
		var chain := PackedVector2Array()
		var head := Vector2i(link, end)
		if _ends[head].mode == "branch": chain.append_array(_branch_curve(head, true))
		guard = 0
		while guard < 64:
			guard += 1
			done[link] = true
			var line: PackedVector2Array = _points[link]
			if end == 1: line = _reversed(line)
			var exit := Vector2i(link, 1 - end)
			line = _trim(line, Vector2i(link, end), false)
			line = _trim(line, exit, true)
			chain.append_array(line)
			var info: Dictionary = _ends[exit]
			if info.mode == "branch":
				chain.append_array(_branch_curve(exit, false))
				break
			if info.mode != "through": break
			var partner: Vector2i = info.partner
			if done.has(partner.x): break
			link = partner.x
			end = partner.y
		if chain.size() >= 2: lines.append(_resample(_smooth(chain), SAMPLE))

## A branch end's points near the room are replaced by its curve.
func _trim(line: PackedVector2Array, key: Vector2i, at_end: bool) -> PackedVector2Array:
	if _ends[key].mode != "branch": return line
	var centre := _room_centre(_ends[key].room)
	var out := PackedVector2Array()
	for p in line:
		if p.distance_to(centre) >= BRANCH_JOIN: out.append(p)
	return out

## The S-curve from the host line (BRANCH_START out of the room, tangent to
## it) to the branch's own corridor (BRANCH_JOIN out). `leading` = the chain
## starts here, so the curve runs host → branch; otherwise branch → host.
func _branch_curve(key: Vector2i, leading: bool) -> PackedVector2Array:
	var info: Dictionary = _ends[key]
	var centre := _room_centre(info.room)
	var host: Vector2 = info.host
	var out: Vector2 = info.dir
	var start := centre + host * BRANCH_START
	var join := centre + out * BRANCH_JOIN
	var p1 := start + host * 2.0
	var p2 := join - out * 2.0
	var curve := PackedVector2Array()
	for i in range(13):
		var t := float(i) / 12.0
		var u := 1.0 - t
		curve.append(start * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + join * t * t * t)
	# The switch stand beside the points, on the side away from the branch.
	var across := host.orthogonal()
	if across.dot(out) > 0.0: across = -across
	var stand := start + across * 1.55
	if map._is_open(stand.x, stand.y, -0.6):
		switches.append(Transform3D(Basis.looking_at(Vector3(host.x, 0, host.y)), Vector3(stand.x, map.ground_height(stand), stand.y)))
	return curve if leading else _reversed(curve)

func _room_centre(room: int) -> Vector2:
	var circle: Vector3 = map._open_circles[room]
	return Vector2(circle.x, circle.y)

static func _reversed(line: PackedVector2Array) -> PackedVector2Array:
	var out := line.duplicate()
	out.reverse()
	return out

static func _smooth(line: PackedVector2Array) -> PackedVector2Array:
	var points := line
	for pass_index in range(3):
		if points.size() < 3: break
		var next := PackedVector2Array([points[0]])
		for i in range(points.size() - 1):
			next.append(points[i].lerp(points[i + 1], 0.25))
			next.append(points[i].lerp(points[i + 1], 0.75))
		next.append(points[-1])
		points = next
	return points

static func _resample(line: PackedVector2Array, step: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if line.size() < 2: return line
	out.append(line[0])
	var carry := 0.0
	for i in range(line.size() - 1):
		var a := line[i]
		var b := line[i + 1]
		var length := a.distance_to(b)
		var d := step - carry
		while d <= length:
			out.append(a.lerp(b, d / length))
			d += step
		carry = length - (d - step)
	if out[-1].distance_to(line[-1]) > step * 0.3: out.append(line[-1])
	return out

func _ground(p: Vector2) -> float:
	return map.ground_height(p)

func _lay_sleepers(line: PackedVector2Array) -> void:
	var along := 0.0
	var next := 0.2
	for i in range(1, line.size()):
		along += line[i - 1].distance_to(line[i])
		if along < next: continue
		next += SLEEPER_STEP
		var a := Vector3(line[i - 1].x, _ground(line[i - 1]), line[i - 1].y)
		var b := Vector3(line[i].x, _ground(line[i]), line[i].y)
		var mid := (a + b) * 0.5
		sleepers.append(Transform3D(Basis.looking_at((b - a).normalized()), mid + Vector3.UP * (_sleeper_lift + 0.005)))

## Two rails as boxed strips along the line, sitting on the sleepers.
func _sweep_rails(tool: SurfaceTool, line: PackedVector2Array) -> void:
	for side: float in [-1.0, 1.0]:
		var left := PackedVector3Array()
		var right := PackedVector3Array()
		var along := PackedFloat32Array()
		var run := 0.0
		for i in range(line.size()):
			var prev := line[maxi(i - 1, 0)]
			var next := line[mini(i + 1, line.size() - 1)]
			var across := (next - prev).normalized().orthogonal()
			var centre := line[i] + across * HALF_GAUGE * side
			var base := _ground(line[i]) + 0.1
			left.append(Vector3(centre.x - across.x * RAIL_WIDTH * 0.5, base, centre.y - across.y * RAIL_WIDTH * 0.5))
			right.append(Vector3(centre.x + across.x * RAIL_WIDTH * 0.5, base, centre.y + across.y * RAIL_WIDTH * 0.5))
			if i > 0: run += line[i - 1].distance_to(line[i])
			along.append(run)
		for i in range(line.size() - 1):
			var up := Vector3.UP * RAIL_HEIGHT
			var u0 := along[i] * 0.5
			var u1 := along[i + 1] * 0.5
			# Top, then the two sides.
			_quad(tool, left[i] + up, right[i] + up, right[i + 1] + up, left[i + 1] + up, u0, u1, 0.4, 0.6)
			_quad(tool, left[i], left[i] + up, left[i + 1] + up, left[i + 1], u0, u1, 0.2, 0.4)
			_quad(tool, right[i] + up, right[i], right[i + 1], right[i + 1] + up, u0, u1, 0.6, 0.8)

static func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, u0: float, u1: float, v0: float, v1: float) -> void:
	var uvs := [Vector2(u0, v0), Vector2(u0, v1), Vector2(u1, v1), Vector2(u1, v0)]
	var corners := [a, b, c, d]
	for k in [0, 1, 2, 0, 2, 3]:
		tool.set_uv(uvs[k])
		tool.add_vertex(corners[k])
