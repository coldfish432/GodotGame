extends SceneTree
var game: GameManager
var failures := 0
var checks: Array[Dictionary] = []
func _initialize() -> void: call_deferred("run")
func step(count: int = 1) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func check(label: String, passed: bool) -> void:
	checks.append({"check": label, "passed": passed})
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label)
func run() -> void:
	# Same 1/60 simulated physics step, accelerated wall-clock execution.
	Engine.time_scale = 3.0
	Engine.physics_ticks_per_second = 180
	game = GameManager.new()
	game.save_enabled = false
	root.add_child(game)
	await step(5)
	for region in ["mine", "city", "snow"]:
		game.fixed_map_seed = 1729
		await game.start_contract(region)
		game._clear_field()
		game.player.invulnerable = true
		await step(4)
		var map := game.world_map
		var end: Vector3 = map.route_nodes[1].position
		var rid := map.navigation_map_rid()
		var path := NavigationServer3D.map_get_path(rid, ContinuousWorldMap.ENTRY_POSITION, end, true)
		var length := 0.0
		var worst := 0.0
		for i in range(1, path.size()):
			length += path[i - 1].distance_to(path[i])
			for sample in range(11):
				var p := path[i - 1].lerp(path[i], sample / 10.0)
				worst = maxf(worst, -map._surface.distance_at(Vector2(p.x, p.z)))
		# Tolerance is half the terrain field's sampling cell, because that is
		# the accuracy the field has: at a sharp corner the interpolated
		# distance is off by a fraction of a cell, so a tighter bound than this
		# measures the sampling grid rather than the geometry. A genuine hole in
		# the route is orders of magnitude larger and still fails here.
		var tolerance := TerrainSurface.CELL * 0.5
		check(region + " path follows continuous terrain and reaches final arena (points %d, length %.0f, worst %.2f of %.2f)" % [path.size(), length, worst, tolerance],
			path.size() > 4 and worst < tolerance and length > 120)
		check(region + " early build leaves later encounters", map.buff_position.z < map.main_path[4].y and map.encounter_position.z < end.z - 25)
		var area := 0.0
		for face in map.minimap_faces:
			for i in range(1, face.size() - 1): area += absf((face[i] - face[0]).cross(face[i + 1] - face[0])) * 0.5
		# Expressed as a share of the bounding rectangle rather than as an
		# absolute area: the claim being made is "most of the box is solid",
		# which must keep holding whatever size the segment is scaled to.
		var bounds: Vector2 = ContinuousWorldMap.SPINE_MAX - ContinuousWorldMap.SPINE_MIN
		var share := area / (bounds.x * bounds.y)
		check(region + " terrain constrains space instead of an open rectangle (walkable %.0f of %.0f, %.0f%%)" % [area, bounds.x * bounds.y, share * 100.0],
			share > 0.10 and share < 0.40)
		# Real CharacterBody3D follows the entire route, with no intermediate
		# teleports. This catches collision snags a navmesh-only test cannot.
		game.player.set_move_target(end)
		var left_ground := 0
		var arrived := false
		var walk_worst := 0.0
		var used := 0
		# Budget derived from the route the player actually has to walk rather
		# than a fixed count, so rescaling the segment does not turn "arrived"
		# into a stopwatch failure. 1.8x covers detours around cover.
		var budget := int(length / maxf(game.player.move_speed, 0.1) * 60.0 * 1.8)
		for tick in range(budget):
			await step()
			var p := game.player.global_position
			used = tick
			walk_worst = maxf(walk_worst, -map._surface.distance_at(Vector2(p.x, p.z)))
			# Same sampling-cell tolerance as the path check above. The height
			# test stays exact: falling through the floor is a real failure and
			# has nothing to do with how finely the distance field is sampled.
			if not map._is_open(p.x, p.z, tolerance) or p.y < 0.4: left_ground += 1
			if Vector2(p.x - end.x, p.z - end.z).length() < 0.6:
				arrived = true
				break
		check(region + " player walks entry to destination without snagging or leaving terrain (arrived %s, %d/%d ticks, off-ground %d, worst %.2f)" % [arrived, used, budget, left_ground, walk_worst],
			arrived and left_ground == 0)
		# Opposite sides of a real cover pillar: no teleported intermediate
		# waypoints, and the initial direct ray must be blocked.
		var pillar: Vector3 = map._closed_circles[0]
		var left := Vector3(pillar.x - 4, 0.7, pillar.y)
		var right := Vector3(pillar.x + 4, 0.65, pillar.y)
		game.player.teleport(left)
		var pursuer := game._spawn_enemy(right, false, false)
		# A guard zone supplies the alert while the pillar hides the player.
		# Ordinary enemies now correctly remain idle without perception.
		var post := GuardPost.new()
		post.game = game
		post.position = Vector3(pillar.x, 0, pillar.y - 3.5)
		game.add_child(post)
		post.add_guard(pursuer)
		await step(3)
		var enemy: Enemy = get_nodes_in_group("enemies")[0]
		check(region + " bank collision blocks direct fire through cover", not game.line_of_sight(left, right))
		var crossed := 0
		var attacked := false
		for tick in range(650):
			await step()
			if not map._is_open(enemy.position.x, enemy.position.z, 0.0): crossed += 1
			if enemy.attack_phase != "idle" and game.line_of_sight(enemy.position, game.player.position): attacked = true
		# Regional melee attacks now have distinct reaches. Require a real
		# attack after circling cover, not the former universal 2.8 distance.
		var reach: float = {"mine": 2.4, "city": 3.2, "snow": 3.0}[region]
		check(region + " enemy goes around cover and attacks (distance %.2f, off-ground %d)" % [enemy.position.distance_to(game.player.position), crossed], crossed == 0 and attacked and enemy.position.distance_to(game.player.position) <= reach + 0.1)
		# Removing all decorative sprites cannot open a shortcut or remove a wall.
		for prop in get_nodes_in_group("field_props"): prop.hide()
		check(region + " terrain remains functional without decorative props", not game.line_of_sight(left, right) and NavigationServer3D.map_get_path(rid, ContinuousWorldMap.ENTRY_POSITION, end, true).size() == path.size())
		game.settle(true)
		await step(3)
	var file := FileAccess.open("res://../evidence/downfall-terrain-tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "engine": Engine.get_version_info().string}, "  "))
	print("TERRAIN RESULT: %d checks, %d failures" % [checks.size(), failures])
	game.queue_free()
	await step(3)
	quit(1 if failures else 0)
