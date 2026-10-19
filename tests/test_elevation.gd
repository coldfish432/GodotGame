extends SceneTree

## Terraces and route markers (地图场景改造 2026-10-12, 参考《恐怖黎明》).
##
## The layout sweep runs the map generator alone over many seeds and checks
## what the change promised: floors come in more than one tier, the route
## markers are not pinned to the trunk's end, ramps stay walkable slopes, and
## everything the player has to stand at is on level ground. The body checks
## then put a real CharacterBody3D at a cliff, from above and from below:
## walking off a terrace edge must not drop it, walking at the face must not
## climb it, and a ray across the cliff must be blocked.

## Daily runs sweep fewer floors; DOWNFALL_FULL=1 (run_all.ps1 -Full) the lot.
var SEEDS := 30 if OS.get_environment("DOWNFALL_FULL") == "1" else 15

var failures := 0
var checks: Array[Dictionary] = []

func _initialize() -> void: call_deferred("run")

func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame

func check(label: String, passed: bool) -> void:
	checks.append({"check": label, "passed": passed})
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label)

func run() -> void:
	var map := ContinuousWorldMap.new()
	root.add_child(map)
	var tiered := 0
	var trunk_exits := 0
	var fallbacks := 0
	var ramps := 0
	var steepest := 0.0
	var unlevel := 0
	var cliffs := 0
	var worst_ramp := ""
	var total_cut := 0.0
	var total_face := 0.0
	var accents := {}
	var lamp_total := 0
	var headframes := 0
	var darkest := INF
	var dressed_ramps := 0
	var dressed_rubble := 0
	var misplaced := 0
	var dressing_bodies := 0
	for i in range(SEEDS):
		map.region_id = ["mine", "city", "snow"][i % 3]
		map.generate((i + 1) * 4421, 1)
		var tiers := {}
		for level in map.levels: tiers[level] = true
		if tiers.size() > 1: tiered += 1
		if map.exit_chamber == map.main_path.size() - 1: trunk_exits += 1
		if map.level_attempts >= 3: fallbacks += 1
		cliffs += map._surface.cliff_count
		for ramp in map.ramp_midpoints():
			ramps += 1
			# Gradient along the ramp's own centre line, metre by metre.
			var piece: PackedVector2Array = ramp.piece
			var length := 0.0
			for k in range(piece.size() - 1): length += piece[k].distance_to(piece[k + 1])
			var previous := INF
			for t in range(int(length) + 1):
				var along := ContinuousWorldMap._polyline_range(piece, 0.0, maxf(float(t), 0.06))
				var p: Vector2 = along[-1] if along.size() > 0 else piece[0]
				var here := map.ground_height(p)
				if previous < INF:
					if absf(here - previous) > steepest: worst_ramp = "%s seed %d link %d at %s" % [map.region_id, (i + 1) * 4421, ramp.link, p]
					steepest = maxf(steepest, absf(here - previous))
				previous = here
		var dressing: TerraceDressing = map.terrace_dressing
		dressed_ramps += dressing.ramp_count
		dressed_rubble += dressing.rubble_count
		for node in map._generated_root.find_children("*", "CollisionObject3D", true, false):
			if node.get_parent() != null and node.get_parent().name.begins_with("Terrace"): dressing_bodies += 1
		# The swept faces cover the cliff lines, and every face column turns
		# towards the low floor.
		var cut_length := 0.0
		for cut in map._surface.cliff_cuts: cut_length += Vector2(cut[0], cut[1]).distance_to(Vector2(cut[2], cut[3]))
		total_cut += cut_length
		total_face += dressing.cliff_face.face_length
		for path in dressing.accent_transforms: accents[String(path).get_file().get_basename()] = int(accents.get(String(path).get_file().get_basename(), 0)) + (dressing.accent_transforms[path] as Array).size()
		for chain in dressing.cliff_face.chains:
			if chain.bank: continue  # bank faces front open ground, not a lower floor
			for k in range(chain.points.size()):
				var at: Vector2 = chain.points[k]
				var front: Vector2 = chain.front[k]
				if chain.high[k] - chain.low[k] > 1.5 and map.ground_height(at + front * 1.2) > map.ground_height(at - front * 1.2) - 0.5: misplaced += 1
		if map.region_id == "mine":
			lamp_total += dressing.lamps.size()
			headframes += dressing.headframe_points.size()
			# Readability (恐怖黎明 was faulted for unplayably dark areas): the trunk
			# floor must never fall below a floor of light.
			for k in range(map.main_path.size()):
				var light := dressing.field_light.light_at(map.main_path[k])
				darkest = minf(darkest, (light.r + light.g + light.b) / 3.0)
		var spots: Array[Vector3] = [map.buff_position, map.encounter_position, map.exit_node.position, map.route_guard_position]
		if map.has_vault: spots.append(map.vault_position)
		for node in map.route_nodes: spots.append(node.position)
		for spot in spots:
			if not map._surface.is_level(Vector2(spot.x, spot.z)) or absf(spot.y - map.ground_height(Vector2(spot.x, spot.z))) > 0.7: unlevel += 1
	check("most floors have more than one tier (%d of %d)" % [tiered, SEEDS], tiered >= SEEDS * 0.6)
	check("route markers are mostly away from the trunk's end (%d of %d at the end)" % [trunk_exits, SEEDS], trunk_exits <= SEEDS * 0.45 and trunk_exits >= 1)
	check("tier rolls rarely fall back to a flat floor (%d of %d)" % [fallbacks, SEEDS], fallbacks <= SEEDS * 0.15)
	check("ramps are dug (%d over %d floors) and stay walkable (steepest %.2f per metre)" % [ramps, SEEDS, steepest], ramps >= SEEDS and steepest < 0.45)
	if steepest >= 0.45: print("  steepest ramp: ", worst_ramp)
	check("cliffs are walled (%d wall pieces)" % cliffs, cliffs > 0)
	check("the terraces are dressed (%d ramp kerbs, %d rubble piles)" % [dressed_ramps, dressed_rubble], dressed_ramps >= ramps and dressed_rubble > 0)
	check("continuous cliff faces cover the cliff lines (%.0f m of face over %.0f m of wall)" % [total_face, total_cut], total_face >= total_cut * 0.8)
	check("the mine sets its Blender accents along the faces (%s)" % [accents], accents.size() >= 4)
	check("mine floors are lit by lamps and the way down has its headframe (%d lamps, %d headframes over %d mine floors)" % [lamp_total, headframes, SEEDS / 3], lamp_total >= SEEDS / 3 * 8 and headframes >= SEEDS / 3 * 0.7)
	check("the trunk is never too dark to read (darkest %.2f)" % darkest, darkest >= 0.7)
	check("every cliff face column fronts the low floor (%d off)" % misplaced, misplaced <= 3)
	check("the dressing adds no collision (%d bodies)" % dressing_bodies, dressing_bodies == 0)
	check("devices, markers and the outpost stand on level ground at ground height (%d off)" % unlevel, unlevel == 0)

	# A real body at a real cliff.
	var game := GameManager.new()
	game.start_at_base = false
	game.save_enabled = false
	root.add_child(game)
	await step(10)
	var found := false
	for attempt in range(12):
		game.fixed_map_seed = 1000 + attempt * 37
		await game.start_contract(["mine", "city", "snow"][attempt % 3])
		game._clear_field()
		await step(4)
		var pair := _cliff_pair(game.world_map)
		if pair.is_empty():
			game.settle(true)
			await step(2)
			continue
		found = true
		var high: Vector2 = pair[0]
		var low: Vector2 = pair[1]
		var high_ground := game.world_map.ground_height(high)
		var low_ground := game.world_map.ground_height(low)
		var player := game.player
		player.invulnerable = true
		check("a ray across the cliff is blocked (%.1f above %.1f)" % [high_ground, low_ground],
			not game.line_of_sight(Vector3(high.x, high_ground + 0.7, high.y), Vector3(low.x, low_ground + 0.7, low.y)))
		player.set_physics_process(false)
		player.teleport(Vector3(high.x, high_ground + 0.7, high.y))
		var lowest := await _walk(player, low - high, 120)
		check("walking off the terrace edge does not drop the body (lowest %.2f, terrace %.2f)" % [lowest.x, high_ground], lowest.x > high_ground - 0.5)
		player.teleport(Vector3(low.x, low_ground + 0.7, low.y))
		var climbed := await _walk(player, high - low, 120)
		check("walking at the cliff face does not climb it (highest %.2f, floor %.2f)" % [climbed.y, low_ground], climbed.y < low_ground + 1.4)
		player.set_physics_process(true)
		break
	check("a seed with a cliff to test was found", found)
	var file := FileAccess.open("res://../evidence/downfall-elevation-tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "engine": Engine.get_version_info().string}, "  "))
	print("ELEVATION RESULT: %d checks, %d failures" % [checks.size(), failures])
	game.queue_free()
	map.queue_free()
	await step(3)
	quit(1 if failures else 0)

## Drives the body straight along `direction` at walking speed with gravity,
## returning (lowest feet-height seen, highest).
func _walk(player: Player, direction: Vector2, ticks: int) -> Vector2:
	var heading := Vector3(direction.x, 0, direction.y).normalized()
	var lowest := INF
	var highest := -INF
	for tick in range(ticks):
		var vy := player.velocity.y
		player.velocity = heading * 5.0
		player.velocity.y = -2.0 if player.is_on_floor() else vy + Player.GRAVITY / 60.0
		player.move_and_slide()
		await physics_frame
		lowest = minf(lowest, player.global_position.y - 0.7)
		highest = maxf(highest, player.global_position.y - 0.7)
	return Vector2(lowest, highest)

## Two level spots a few metres apart across a cliff: one on a terrace, one
## below it, with no ramp between them in a straight line.
func _cliff_pair(map: ContinuousWorldMap) -> Array:
	for z in range(int(map.SPINE_MIN.y), int(map.SPINE_MAX.y), 2):
		for x in range(int(map.SPINE_MIN.x), int(map.SPINE_MAX.x), 2):
			var high := Vector2(x, z)
			if not map._has_clearance(high): continue
			var h := map.ground_height(high)
			if h < map.TIER - 0.1: continue
			for k in range(8):
				var direction := Vector2.from_angle(TAU * k / 8.0)
				var low := high + direction * 5.0
				if not map._has_clearance(low) or map.ground_height(low) > h - map.TIER + 0.1: continue
				# Every step of the straight line is open ground: a cliff, not rock.
				var open := true
				for t in range(1, 10):
					if not map._is_open(high.x + direction.x * t * 0.5, high.y + direction.y * t * 0.5, 0.0): open = false
				if open: return [high, low]
	return []
