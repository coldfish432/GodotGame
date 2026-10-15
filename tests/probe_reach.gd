extends SceneTree

## Why the clear-time bot could not reach some enemies (用户 2026-10-14): for
## each floor, whether every enemy stands on navmesh joined to the entry, and
## where the bot's player got stuck while chasing. Run by hand.
##   DOWNFALL_SIM=mine:5:4242

func _initialize() -> void: call_deferred("run")

func run() -> void:
	Engine.time_scale = 4.0
	var spec := OS.get_environment("DOWNFALL_SIM").split(":")
	var game := GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = int(spec[2])
	root.add_child(game)
	for i in range(4): await process_frame
	await game.start_contract(spec[0])
	if int(spec[1]) > 1:
		game.floor_number = int(spec[1]) - 1
		await game.advance(0)
	game.player.invulnerable = true
	for i in range(10): await physics_frame
	var rid := game.world_map.navigation_map_rid()
	var entry := NavigationServer3D.map_get_closest_point(rid, game.player.global_position)
	var cut := 0
	for e in game.get_tree().get_nodes_in_group("enemies"):
		if e.game != game: continue
		var at: Vector3 = e.global_position
		var on_mesh := NavigationServer3D.map_get_closest_point(rid, at)
		var off := Vector2(on_mesh.x - at.x, on_mesh.z - at.z).length()
		var path := NavigationServer3D.map_get_path(rid, entry, on_mesh, true)
		var gap := path[-1].distance_to(on_mesh) if path.size() > 0 else INF
		var ground := game.world_map.ground_height(Vector2(at.x, at.z))
		if off > 1.0 or gap > 1.0:
			cut += 1
			print("CUT %s %s at %s  off-mesh %.1f  path-gap %.1f  ground %.2f  y %.2f  guard %s" % [e.enemy_type, "elite" if e.elite else "", at, off, gap, ground, at.y, e.behavior == Enemy.Behavior.GUARD])
	print("NAV: %d enemies cut off from the entry" % cut)
	# The bot, as in sim_clear_time: note every spell of 6 s with no headway.
	var driver := AiDriver.new()
	var t := 0.0
	var mark := game.player.global_position
	var mark_t := 0.0
	var reports := 0
	while t < 400.0 and reports < 8:
		await physics_frame
		var dt := Engine.time_scale / Engine.physics_ticks_per_second
		t += dt
		game.threat.value = 0.0
		var alive: Array = game.get_tree().get_nodes_in_group("enemies").filter(func(x): return x.game == game and not x._dead and not x.attack_profile.get("neutral", false))
		if alive.is_empty(): break
		driver.decide(game)
		if game.player.global_position.distance_to(mark) > 1.5:
			mark = game.player.global_position
			mark_t = t
		elif t - mark_t > 6.0:
			var p := game.player.global_position
			alive.sort_custom(func(a, b): return a.global_position.distance_to(p) < b.global_position.distance_to(p))
			var target: Enemy = alive[0]
			var from := NavigationServer3D.map_get_closest_point(rid, p)
			var to := NavigationServer3D.map_get_closest_point(rid, target.global_position)
			var path := NavigationServer3D.map_get_path(rid, from, to, true)
			var reach := path.size() > 0 and path[-1].distance_to(to) < 1.0
			print("STUCK t=%.0f player %s (floor %s, ground %.2f, off-mesh %.1f)  target %s %s at %s dist %.1f  state %s  nav-path %s  sight %s  move_target %s" % [t, p, game.player.is_on_floor(),
				game.world_map.ground_height(Vector2(p.x, p.z)), Vector2(from.x - p.x, from.z - p.z).length(), target.enemy_type, "guard" if target.behavior == Enemy.Behavior.GUARD else "",
				target.global_position, p.distance_to(target.global_position), target.state, reach, game.line_of_sight(p, target.global_position), game.player._move_target if game.player._has_move_target else "none"])
			var agent: NavigationAgent3D = driver._nav_agent
			var nxt := agent.get_next_path_position()
			print("   bot agent next %s  3D gap %.2f  flat gap %.2f  (path_desired_distance %.1f)" % [nxt, nxt.distance_to(p), Vector2(nxt.x - p.x, nxt.z - p.z).length(), agent.path_desired_distance])
			# What a real click on the enemy does from here: her own navigation.
			game.player.set_move_target(target.global_position)
			var start := t
			while t - start < 20.0 and game.player.global_position.distance_to(target.global_position) > 3.0:
				await physics_frame
				t += dt
			print("   a real click on it: %s after %.1fs" % ["arrived" if game.player.global_position.distance_to(target.global_position) <= 3.0 else "NOT arrived", t - start])
			reports += 1
			mark = game.player.global_position
			mark_t = t
	quit(0)
