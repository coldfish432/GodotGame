extends SceneTree
var game: GameManager
var failures := 0
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool) -> void:
	print(("PASS " if passed else "FAIL ") + label)
	if not passed: failures += 1
func run() -> void:
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	await game.start_contract("mine")
	game._clear_field()
	await step(2)
	var driver := AiDriver.new()
	var origin := game.player.global_position
	game._spawn_enemy(origin + Vector3(0, 0, 8), false, true)
	var enemy: Enemy = get_nodes_in_group("enemies")[0]
	enemy.set_physics_process(false)
	var hp := enemy.health
	driver.decide(game)
	check("AI approaches distant enemies without ranged attacks", game.player._has_move_target and enemy.health == hp)
	game.player.teleport(enemy.global_position - Vector3(0, 0, 2))
	driver.decide(game)
	check("AI attacks in melee range", enemy.health < hp and not game.player._has_move_target)
	check("AI keeps melee cooldown between decisions", game.player._attack_cooldown > 0)
	enemy._begin_telegraphed_attack()
	driver.decide(game)
	check("AI still prioritizes leaving telegraphs", game.player._has_move_target)
	game.queue_free()
	await step(2)
	print("TEST_AI_DRIVER: 4 checks / %d failures" % failures)
	quit(1 if failures else 0)
