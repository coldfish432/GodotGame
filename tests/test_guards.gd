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
func clear() -> void:
	game._clear_field()
	await step(3)
## A direction in which `anchor + dir * range` survives the walkable snap at
## close to the range asked for, so "outside the trigger radius" really is.
func _open_bearing(anchor: Vector3, want: float) -> Vector3:
	var best := Vector3(0, 0, 1)
	var best_gap := -1.0
	for i in range(24):
		var dir := Vector3(cos(TAU * float(i) / 24.0), 0, sin(TAU * float(i) / 24.0))
		var landed := walkable(anchor + dir * want)
		var gap := Vector2(landed.x - anchor.x, landed.z - anchor.z).length()
		if gap > best_gap:
			best_gap = gap
			best = dir
		if gap >= want - 0.5: break
	return best

func walkable(point: Vector3) -> Vector3:
	var result := game.world_map.nearest_walkable(point)
	result.y = 0.7
	return result
func run() -> void:
	Engine.time_scale = 3
	Engine.physics_ticks_per_second = 180
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	await step(3)
	for region in ["mine", "city", "snow"]:
		await game.start_contract(region)
		game.player.invulnerable = true
		await step(3)
		var posts := get_nodes_in_group("guard_posts")
		# One device post now: gilding (and its guards) is gone (保全系统修订案); squads and 坎诺特 are unguarded.
		check(region + " all search points and devices have a guard squad", posts.size() == game.world_map.cache_positions.size() + 1 and posts.all(func(p): return p.guards.size() == 2))
		var reachable := true
		for post in posts:
			for guard in post.guards:
				var path := NavigationServer3D.map_get_path(game.world_map.navigation_map_rid(), ContinuousWorldMap.ENTRY_POSITION, guard.home_position, true)
				if path.size() < 2 or path[-1].distance_to(guard.home_position) > 1: reachable = false
		check(region + " guard stations are reachable and separated", reachable and posts.all(func(p): return p.guards.size() == 2 and p.guards[0].home_position.distance_to(p.guards[1].home_position) >= 2))
		await exercise_guards(region)
		game.settle(true)
		await step(3)
	await game.start_contract("mine")
	game.player.invulnerable = true
	await exercise_normal()
	await clear()
	check("field cleanup removes every guard post and enemy", get_nodes_in_group("guard_posts").is_empty() and get_nodes_in_group("enemies").is_empty())
	var file := FileAccess.open("res://../evidence/downfall-guard-tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures}, "  "))
	print("GUARD RESULT: %d checks, %d failures" % [checks.size(), failures])
	game.queue_free()
	await step(3)
	quit(1 if failures else 0)

func exercise_guards(region: String) -> void:
	var anchor: Vector3 = game.world_map.buff_position
	anchor.y = 0
	await clear()
	var post := game._spawn_guard_post(anchor, "测试搜索点")
	if post.guards.size() != 2: return
	# Probed rather than assumed. This used to aim at main_path[2] and trust
	# that the ground that way was open; with layouts generated per seed it
	# often is not, and nearest_walkable then snaps the "outside the trigger"
	# spot to somewhere inside it, so the test failed on the fixture rather
	# than on the behaviour.
	var approach := _open_bearing(anchor, 9.0)
	game.player.teleport(walkable(anchor + approach * 9))
	await step(15)
	check(region + " guards stay at stations outside search-point trigger", not post.active and post.guards.all(func(e): return e.state == Enemy.State.IDLE and e.position.distance_to(e.home_position) < 0.1))
	game.player.teleport(walkable(anchor + approach * 6))
	await step(3)
	check(region + " entering the point radius alerts the whole squad", post.active and post.guards.all(func(e): return e.state == Enemy.State.CHASING))
	game.player.teleport(walkable(anchor + approach * 9))
	await step(80)
	check(region + " active squad follows into hysteresis band", post.active and post.guards.all(func(e): return e.state == Enemy.State.CHASING))
	game.player.teleport(walkable(anchor + approach * 16))
	await step(1)
	check(region + " leaving the search point sends squad home", not post.active and post.guards.all(func(e): return not e.preparing_attack and (e.state == Enemy.State.RETURNING or (e.state == Enemy.State.IDLE and e.position.distance_to(e.home_position) < 0.31))))
	# Run right back through the trigger during the return: no boundary jitter.
	game.player.teleport(walkable(anchor + approach * 6))
	await step(2)
	check(region + " return cannot be interrupted by re-entering the trigger", not post.active and post.guards.all(func(e): return e.state != Enemy.State.CHASING))
	game.player.teleport(ContinuousWorldMap.ENTRY_POSITION)
	var outside := 0
	for tick in range(500):
		await step()
		for guard in post.guards:
			if not game.world_map._is_open(guard.position.x, guard.position.z, 0.1): outside += 1
		if post.guards.all(func(e): return e.state == Enemy.State.IDLE): break
	check(region + " guards navigate to their separate original stations", outside == 0 and post.guards.all(func(e): return e.state == Enemy.State.IDLE and e.position.distance_to(e.home_position) < 0.31))
	await step(50)
	game.player.teleport(walkable(anchor + approach * 5))
	await step(3)
	check(region + " a returned squad can trigger again", post.active and post.guards.all(func(e): return e.state == Enemy.State.CHASING))
	# Death and collection cannot invalidate the fixed home anchor.
	for guard in post.guards.duplicate(): guard.take_hit(10000)
	game.player.teleport(walkable(anchor + approach * 16))
	await step(3)
	game.player.teleport(walkable(anchor + approach * 6))
	await step(3)
	check(region + " dead guards never respawn on zone re-entry", post.guards.is_empty() and not post.active)

func exercise_normal() -> void:
	await clear()
	var home := ContinuousWorldMap.ENTRY_POSITION
	var enemy := game._spawn_enemy(home, false, false)
	enemy.perception_radius = 4
	game.player.teleport(home + Vector3(6, 0, 0))
	await step(20)
	check("normal enemy ignores a player outside perception", enemy.state == Enemy.State.IDLE and enemy.position.distance_to(enemy.home_position) < 0.01)
	game.player.teleport(home + Vector3(3.5, 0, 0))
	await step(2)
	check("normal enemy acquires a visible nearby player", enemy.state == Enemy.State.CHASING)
	var paused_at := enemy.position
	game.open_modal("inventory")
	await step(30)
	check("modal pause freezes pursuit and perception timers", enemy.position.is_equal_approx(paused_at))
	game.close_modal()
	await step(90)
	game.player.teleport(walkable(Vector3(game.world_map.main_path[2].x, 0.7, game.world_map.main_path[2].y)))
	await step(1)
	check("normal enemy leashes against its original spawn", enemy.state == Enemy.State.RETURNING and not enemy.preparing_attack)
	enemy.take_hit(0.1)
	check("being hit does not interrupt the trip home", enemy.state == Enemy.State.RETURNING)
	var damaged_health := enemy.health
	for tick in range(400):
		await step()
		if enemy.state == Enemy.State.IDLE: break
	check("normal return reaches home and preserves remaining health", enemy.state == Enemy.State.IDLE and enemy.position.distance_to(enemy.home_position) < 0.31 and is_equal_approx(enemy.health, damaged_health))
	await step(50)
	game.player.teleport(home + Vector3(6, 0, 0))
	enemy.take_hit(0.1)
	check("being hit is perception inside the home leash", enemy.state == Enemy.State.CHASING)
	enemy.perception_radius = 0.1
	enemy.sight_memory = 0.15
	await step(45)
	check("lost contact expires instead of tracking forever", enemy.state != Enemy.State.CHASING)
	await clear()
	var pillar: Vector3 = game.world_map._closed_circles[0]
	game.player.teleport(Vector3(pillar.x - 4, 0.7, pillar.y))
	enemy = game._spawn_enemy(Vector3(pillar.x + 4, 0.65, pillar.y), false, false)
	await step(30)
	check("normal perception cannot see through terrain", not game.line_of_sight(game.player.position, enemy.position) and enemy.state == Enemy.State.IDLE)
	await clear()
	game.player.teleport(home)
	enemy = game._spawn_enemy(home + Vector3(6, 0, 0), false, true)
	await step(2)
	check("perceived ordinary ranged target winds up without warnings", enemy.preparing_attack and enemy._warning_markers.is_empty())
	var warnings := enemy._warning_markers.duplicate()
	game.player.teleport(walkable(Vector3(game.world_map.main_path[2].x, 0.7, game.world_map.main_path[2].y)))
	await step(3)
	check("leashing cancels windup and removes its warnings", not enemy.preparing_attack and warnings.all(func(w): return not is_instance_valid(w)))
	await step(75)
	check("cancelled ranged attack never emits a projectile", game.get_children().filter(func(n): return n is EnemyProjectile).is_empty())
