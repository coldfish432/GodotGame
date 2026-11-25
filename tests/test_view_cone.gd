extends SceneTree
## 视野锥与移速（用户 2026-11-24）: an enemy that sees her inside the cone ahead of
## it wakes its own guard post and every enemy near it; behind it, nothing
## wakes. Every enemy moves 1.2× what it did.
var game: GameManager
var failures := 0
func _initialize() -> void: call_deferred("run")
func step(count: int = 1) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func check(label: String, passed: bool, detail: Variant = "") -> void:
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label + ("" if str(detail).is_empty() else "  " + str(detail)))

func walkable(point: Vector3) -> Vector3:
	var result := game.world_map.nearest_walkable(point)
	result.y = 0.7
	return result

func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

## A bearing from `from` along which every point out to `reach` is walkable
## where it was aimed and in clear sight of `from`.
func open_bearing(from: Vector3, reach: float) -> Vector3:
	var best := Vector3.ZERO
	var best_miss := INF
	for i in range(48):
		var dir := Vector3(cos(TAU * i / 48.0), 0, sin(TAU * i / 48.0))
		var miss := 0.0
		for r in [6.0, 10.0, 13.0, reach]:
			var landed := walkable(from + dir * r)
			miss = maxf(miss, absf(flat(landed, from) - r))
			if not game.line_of_sight(from, landed): miss = INF
		if miss < best_miss:
			best_miss = miss
			best = dir
		if miss < 0.3: break
	return best

func spawn(at: Vector3, type: String = "") -> Enemy:
	var e := game._spawn_enemy(at, false, false, type)
	# Its all-round sense shrunk: only the cone can see her from here.
	e.perception_radius = 4.0
	return e

func run() -> void:
	Engine.time_scale = 3
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	await step(3)
	await game.start_contract("mine")
	game.player.invulnerable = true
	await step(3)
	game._clear_field()
	await step(3)

	var her := walkable(ContinuousWorldMap.ENTRY_POSITION)
	game.player.teleport(her)
	await step(2)
	her = game.player.global_position
	var dir := open_bearing(her, 18.0)
	var side := dir.cross(Vector3.UP).normalized()
	var type := EnemyAttacks.default_type(game.region_id, false, false)

	# A post 15 m out (her well outside its 7 m trigger); its watcher 13 m out.
	var post := GuardPost.new()
	post.game = game
	post.position = walkable(her + dir * 15.0)
	game.add_child(post)
	var watcher := spawn(her + dir * 13.0, type)
	post.add_guard(watcher)
	var mate := spawn(her + dir * 17.0, type)
	post.add_guard(mate)
	# Not of the post, but within 12 m of the watcher.
	var near := spawn(her + dir * 15.0 + side * 3.0, type)
	# Far from the watcher: stays as it was.
	var far := spawn(her - dir * 9.0 - side * 9.0, type)
	for e in [watcher, mate, near, far]: e._look_along(e.global_position - her)
	await step(20)
	var all := [watcher, mate, near, far]
	check("setup: watcher 13 m off, in sight, beyond its all-round sense", flat(watcher.global_position, her) > 11.0 and flat(watcher.global_position, her) < Enemy.VIEW_CONE_RANGE and game.line_of_sight(watcher.global_position, her), flat(watcher.global_position, her))
	check("setup: near one within the alert radius, far one outside it", flat(near.global_position, watcher.global_position) <= Enemy.VIEW_CONE_ALERT_RADIUS and flat(far.global_position, watcher.global_position) > Enemy.VIEW_CONE_ALERT_RADIUS)
	check("with her behind them nobody wakes", not post.active and all.all(func(e): return e.state == Enemy.State.IDLE), all.map(func(e): return e.state))
	check("behind is outside the cone", not watcher.in_view_cone(her))

	watcher._look_along(her - watcher.global_position)
	check("facing her, she is inside its cone", watcher.in_view_cone(her))
	await step(3)
	check("seen in the cone, the watcher chases", watcher.state == Enemy.State.CHASING)
	check("…and its guard post wakes, every guard with it", post.active and mate.state == Enemy.State.CHASING)
	check("…and an enemy near it takes up the chase", near.state == Enemy.State.CHASING)
	check("…but one far off stays where it was", far.state == Enemy.State.IDLE)

	# Off to the side (beyond the half-angle) it does not see her.
	game._clear_field()
	await step(3)
	var flank := spawn(her + dir * 12.0, type)
	var aside := (her - flank.global_position).normalized().rotated(Vector3.UP, deg_to_rad(Enemy.VIEW_CONE_HALF_ANGLE + 20.0))
	flank._look_along(aside)
	await step(10)
	check("she 50° off its nose is not seen", flank.state == Enemy.State.IDLE and not flank.in_view_cone(her))
	flank._look_along((her - flank.global_position).normalized().rotated(Vector3.UP, deg_to_rad(Enemy.VIEW_CONE_HALF_ANGLE - 10.0)))
	await step(3)
	check("she 20° off its nose is seen", flank.state == Enemy.State.CHASING)

	# Beyond the cone's range nothing sees her.
	game._clear_field()
	await step(3)
	var distant := spawn(her + dir * 18.0, type)
	distant._look_along(her - distant.global_position)
	await step(10)
	check("beyond %.0f m the cone does not reach" % Enemy.VIEW_CONE_RANGE, flat(distant.global_position, her) > Enemy.VIEW_CONE_RANGE and distant.state == Enemy.State.IDLE, flat(distant.global_position, her))

	# Spawned facings differ: not every enemy looks the same way.
	var yaws := {}
	for i in range(8):
		var e := spawn(her + side * float(i) * 1.5 - dir * 3.0, type)
		yaws[snappedf(atan2(e.facing_dir().x, e.facing_dir().z), 0.1)] = true
	check("spawned enemies face different ways", yaws.size() >= 4, yaws.size())

	# 移速 +20%.
	game._clear_field()
	await step(3)
	var probe := [EnemyAttacks.default_type(game.region_id, false, false), EnemyAttacks.default_type(game.region_id, false, true), EnemyAttacks.region_elite(game.region_id, game.rng_floor)]
	for t in EnemyAttacks.PROFILES.keys():
		if EnemyAttacks.PROFILES[t].get("stealth", false) or EnemyAttacks.PROFILES[t].has("slow"):
			probe.append(t)
			if probe.size() >= 6: break
	for t in probe:
		var e := game._spawn_enemy(her - dir * 4.0, false, false, t)
		var p: Dictionary = e.attack_profile
		var old := (1.2 if e.elite else (2.4 if e.keeps_distance else 2.1)) * float(p.get("slow", 1.0))
		if p.get("stealth", false): old = 2.3
		check("%s moves 1.2× (%.3f → %.3f)" % [t, old, e.move_speed], is_equal_approx(e.move_speed, old * 1.2) and is_equal_approx(e.current_speed(), e.move_speed))
		e.queue_free()
	var boss := game._spawn_boss("patriot", 1, her - dir * 6.0)
	var base_speed := float(boss.fig.get("speed", 1.2)) * (1.0 + BossCatalog.SWIFT_SPEED if boss.affixes.has("swift") else 1.0)
	check("a boss moves 1.2× too (%.3f → %.3f)" % [base_speed, boss.move_speed], is_equal_approx(boss.move_speed, base_speed * 1.2))

	print("VIEW CONE RESULT: %d failures" % failures)
	game.queue_free()
	await step(3)
	quit(1 if failures else 0)
