extends SceneTree

## Terrain regression: 20 seeds for EACH region, including every enemy spawn.
## The rest of the suite pins fixed_map_seed, so it only ever exercises one
## mine layout. The mine is procedurally carved, and its failure mode is a
## reward that a particular seed strands behind rock — invisible to a single
## seed, and not a crash when it happens, just an unwinnable segment. So this
## sweeps seeds and asserts the one invariant the layout has to hold: every
## device, destination and cache the player can see is walkable to from the
## entry.

const SEEDS := 60
## Small allowance for linear contour interpolation on the 1.5-unit mesh.
const SPINE_INFLATE := 0.15

var game: GameManager
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
	game = GameManager.new()
	game.start_at_base = false
	game.save_enabled = false
	root.add_child(game)
	await step(30)

	var unreachable := 0
	var worst_seed := 0
	var pillars := 0
	var caches := 0
	var chambers := 0
	var loops := 0
	var niches := 0
	var fewest_chambers := 9999
	var most_chambers := 0
	var missing_guards := 0
	for i in range(SEEDS):
		var map_seed := (i + 1) * 7717
		game.fixed_map_seed = map_seed
		await game.start_contract(["mine", "city", "snow"][i % 3])
		await step(4)
		var map_rid: RID = game.world_map._generated_root.get_navigation_map()
		var targets: Array = [
			game.world_map.buff_position,
			game.world_map.gilding_position,
			game.world_map.exit_node.position,
		]
		for node in game.world_map.route_nodes:
			targets.append(node.position)
		for target in game.world_map.cache_positions:
			targets.append(target)
		# The vault and every mechanism too: a seed that walls off one mechanism
		# makes the vault permanently unopenable, and one that walls off the
		# vault wastes the whole errand. Neither crashes, so only this catches it.
		targets.append(game.world_map.vault_position)
		for target in game.world_map.mechanism_positions:
			targets.append(target)
		for target in game.world_map.enemy_spawn_points:
			targets.append(target)
		for enemy in get_nodes_in_group("enemies"):
			targets.append(enemy.home_position)
		for post in get_nodes_in_group("guard_posts"):
			if post.guards.size() != 2: missing_guards += 1
		for target in targets:
			var path := NavigationServer3D.map_get_path(map_rid, ContinuousWorldMap.ENTRY_POSITION, target, true)
			if path.size() <= 1 or path[path.size() - 1].distance_to(target) >= 2.0:
				unreachable += 1
				worst_seed = map_seed
				print("  seed %d stranded %s" % [map_seed, target])
		pillars += game.world_map._closed_circles.size()
		caches += game.world_map.cache_positions.size()
		chambers += game.world_map._open_circles.size()
		loops += game.world_map.loop_centres.size()
		niches += game.world_map.niche_centres.size()
		fewest_chambers = mini(fewest_chambers, game.world_map._open_circles.size())
		most_chambers = maxi(most_chambers, game.world_map._open_circles.size())
		game.settle(true)
		await step(3)

	check("devices, destinations, caches and enemies reachable across %d layouts / 3 regions" % SEEDS, unreachable == 0)
	check("every search point has two guards across all layouts", missing_guards == 0)

	# Enemies have no collider, so the only thing keeping them out of the rock
	# is the navmesh clamp in Enemy._step_toward. Drive a real chase and watch
	# how far off the walkable surface they get.
	game.fixed_map_seed = 1729
	await game.start_contract("mine")
	await step(4)
	var arena: Vector2 = game.world_map.main_path[2]
	game.player.teleport(Vector3(arena.x - 3, 0.7, arena.y))
	game.player.invulnerable = true
	# Independently inspect the terrain contour, rather than comparing the
	# same navigation projection used by the enemy implementation to itself.
	var spawned_in_rock := 0
	for node in game.get_tree().get_nodes_in_group("enemies"):
		var pos: Vector3 = node.global_position
		if not game.world_map._is_open(pos.x, pos.z, SPINE_INFLATE):
			spawned_in_rock += 1
	check("no enemy spawns inside rock", spawned_in_rock == 0)

	var wandered := 0
	for tick in range(300):
		await step(1)
		for node in game.get_tree().get_nodes_in_group("enemies"):
			var pos: Vector3 = node.global_position
			if not game.world_map._is_open(pos.x, pos.z, SPINE_INFLATE):
				wandered += 1
	check("enemies stay on carved ground while chasing (%d off-path samples)" % wandered, wandered == 0)
	game.settle(true)
	await step(3)
	if unreachable > 0:
		print("  first offending seed: %d" % worst_seed)
	# Guards against the layout silently degenerating into the old open box:
	# no side branches means no detours, and no pillars means no cover.
	check("layouts keep producing side branches", float(caches) / float(SEEDS) >= 2.0)
	check("fight arenas keep producing cover pillars", float(pillars) / float(SEEDS) >= 1.0)
	check("chambers per layout stay in a sane range", float(chambers) / float(SEEDS) >= 11.0)
	# The optional topology is all seed-gated. If a gate inverted or a list
	# stopped being filled, every other check here would still pass and the
	# layouts would quietly collapse back to plain out-and-back spurs.
	check("alternate loop roads appear (%.1f chambers per layout)" % (float(loops) / float(SEEDS)), loops > 0)
	check("second-order niches appear (%.1f per layout)" % (float(niches) / float(SEEDS)), niches > 0)
	check("topology varies by seed (chambers %d..%d)" % [fewest_chambers, most_chambers], most_chambers > fewest_chambers)

	var report := {
		"checks": checks,
		"failures": failures,
		"layouts": SEEDS,
		"seeds_per_region": SEEDS / 3,
		"regions": ["mine", "city", "snow"],
		"unreachable_targets": unreachable,
		"avg_chambers": float(chambers) / float(SEEDS),
		"avg_pillars": float(pillars) / float(SEEDS),
		"avg_caches": float(caches) / float(SEEDS),
		"engine": Engine.get_version_info().string,
	}
	var file := FileAccess.open("res://../evidence/downfall-layout-tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print("LAYOUT RESULT: %d checks, %d failures (%d seeds, %.1f chambers / %.1f pillars / %.1f caches per layout)" % [
		checks.size(), failures, SEEDS,
		float(chambers) / float(SEEDS), float(pillars) / float(SEEDS), float(caches) / float(SEEDS)])
	game.queue_free()
	await step(2)
	quit(1 if failures else 0)
