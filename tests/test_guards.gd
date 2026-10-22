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
## A bearing along which every step the test takes (6, 9 and `want` out)
## lands where it was aimed: a spot in rock or across a cliff snaps to the
## nearest walkable ground, which can be back inside the point. Else the
## bearing whose worst step lands closest to its aim.
func _open_bearing(anchor: Vector3, want: float) -> Vector3:
	var best := Vector3(0, 0, 1)
	var best_miss := INF
	for i in range(24):
		var dir := Vector3(cos(TAU * float(i) / 24.0), 0, sin(TAU * float(i) / 24.0))
		var miss := 0.0
		for reach in [6.0, 9.0, want]:
			var landed := walkable(anchor + dir * reach)
			miss = maxf(miss, absf(Vector2(landed.x - anchor.x, landed.z - anchor.z).length() - reach))
		if miss < best_miss:
			best_miss = miss
			best = dir
		if miss < 0.5: break
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
		# 用户 2026-10-14: 兴趣点旁边随机刷新守卫 — 0–3 a point; every post gets the guards it was given.
		check(region + " guarded points and the device get their whole squad", posts.size() >= 1 and posts.size() <= game.world_map.cache_positions.size() + 1 and posts.all(func(p): return p.guards.size() == p.planned and p.planned >= 1))
		var wanderers := get_nodes_in_group("wanderers").filter(func(e): return e.game == game)
		check(region + " wanderers walk the floor from the start", wanderers.size() >= 2)
		var starts: Array = wanderers.map(func(e): return e.global_position)
		# Wherever she is, they keep their distance from her and walk on.
		for f in range(240): await physics_frame
		var walked := 0
		for k in range(wanderers.size()):
			if is_instance_valid(wanderers[k]) and wanderers[k].global_position.distance_to(starts[k]) > 1.5: walked += 1
		check(region + " wanderers move on their own", walked >= 1)
		# Points of interest set back from the middle of their rooms, most of them.
		var off := 0
		for at in game.world_map.cache_positions:
			var room: int = -1
			var best := INF
			for i in range(game.world_map._open_circles.size()):
				var c: Vector3 = game.world_map._open_circles[i]
				var d := Vector2(c.x, c.y).distance_to(Vector2(at.x, at.z))
				if d < best:
					best = d
					room = i
			if best > 2.5: off += 1
		check(region + " most points of interest stand off the middle of their room", off * 2 > game.world_map.cache_positions.size())
		var reachable := true
		for post in posts:
			for guard in post.guards:
				var path := NavigationServer3D.map_get_path(game.world_map.navigation_map_rid(), ContinuousWorldMap.ENTRY_POSITION, guard.home_position, true)
				if path.size() < 2 or path[-1].distance_to(guard.home_position) > 1: reachable = false
		check(region + " guard stations are reachable and separated", reachable and posts.all(func(p): return p.guards.size() < 2 or p.guards[0].home_position.distance_to(p.guards[1].home_position) >= 2))
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
	# Picked for the far step (16, past the release radius): a bearing that is
	# open at 9 can still be walled at 16, and the walkable snap would then
	# land her back inside the point.
	var approach := _open_bearing(anchor, 16.0)
	game.player.teleport(walkable(anchor + approach * 9))
	await step(15)
	var settled: bool = not post.active and post.guards.all(func(e): return e.state == Enemy.State.IDLE and e.position.distance_to(e.home_position) < 0.1)
	if not settled:
		var at: Vector3 = game.player.global_position
		print("  %s: player %.1f m from the point (radius %.1f), active %s, guards %s" % [region, Vector2(at.x - anchor.x, at.z - anchor.z).length(), post.trigger_radius, post.active,
			post.guards.map(func(e): return "%s %.2f m from home, %.1f m from player" % [e.state, e.position.distance_to(e.home_position), Vector2(e.position.x - at.x, e.position.z - at.z).length()])])
	check(region + " guards stay at stations outside search-point trigger", settled)
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
	# 用户 2026-10-18: one guard up wakes them all.
	game.player.teleport(walkable(anchor + approach * 9))
	await step(2)
	post.guards[0].begin_chase()
	await step(2)
	check(region + " one guard set chasing wakes the whole squad", post.active and post.guards.all(func(e): return e.state == Enemy.State.CHASING))
	game.player.teleport(walkable(anchor + approach * 16))
	for tick in range(500):
		await step()
		if post.guards.all(func(e): return e.state == Enemy.State.IDLE): break
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
	var clear: float = game.world_map.pillar_reach(0) + 1.3
	# Opposite sides of a pillar, both on open ground: pillars are irregular
	# and sit in arenas of every shape (the mine's cave walls wander), so the
	# pillar and the pair are searched, not assumed.
	var across := Vector2.RIGHT
	var found := false
	for i in range(game.world_map._closed_circles.size()):
		pillar = game.world_map._closed_circles[i]
		clear = game.world_map.pillar_reach(i) + 1.3
		for k in range(16):
			var d := Vector2.from_angle(TAU * k / 16.0)
			var c := Vector2(pillar.x, pillar.y)
			if game.world_map._has_clearance(c - d * clear) and game.world_map._has_clearance(c + d * clear):
				across = d
				found = true
				break
		if found: break
	game.player.teleport(Vector3(pillar.x - across.x * clear, 0.7, pillar.y - across.y * clear))
	enemy = game._spawn_enemy(Vector3(pillar.x + across.x * clear, 0.65, pillar.y + across.y * clear), false, false)
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
