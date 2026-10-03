extends SceneTree

## Combat: melee damage/kill/auto-loot, the physical-attack windup window
## (both outcomes — leaving vs. staying in the locked sector), and the
## ranged suppressor's projectile. See entities/enemy.gd for the windup
## state machine these checks are exercising.

const Game = preload("res://game/game_manager.gd")

var game: Node3D
var results: Array[Dictionary] = []
var failures: int = 0
var arena_anchor: Vector3

func _initialize() -> void:
	call_deferred("run")

func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame

func check(id: String, passed: bool, observation: Dictionary) -> void:
	results.append({"id": id, "status": "PASS" if passed else "FAIL", "observed": observation})
	if not passed:
		failures += 1
	print(JSON.stringify(results.back()))

func enemy_count() -> int:
	return get_nodes_in_group("enemies").size()

func first_enemy() -> Node:
	var enemies := get_nodes_in_group("enemies")
	return enemies[0] if not enemies.is_empty() else null

func clear_all_enemies() -> void:
	for node in get_nodes_in_group("enemies"):
		node.queue_free()
	await step(2)

func run() -> void:
	game = Game.new()
	game.start_at_base = false
	game.save_enabled = false
	root.add_child(game)
	await step(6)
	arena_anchor = ContinuousWorldMap.ENTRY_POSITION

	# --- Melee attack: walk to a real spawned enemy and hit it for real damage.
	var target := first_enemy()
	check("wave-spawned", target != null, {"enemy_count": enemy_count()})
	if target != null:
		game.player.teleport(target.global_position + Vector3(1.0, 0.0, 0.0))
		await step(2)
		var hp_before: float = target.health
		game.player.attack(target)
		check("melee-attack-deals-ATK-minus-DEF", is_equal_approx(target.health, hp_before - CombatStats.physical(600.0, target.defense)),
			{"before": hp_before, "after": target.health})

		var swings := 0
		var gold_before_kill: int = game.run_gold
		var inventory_count_before_kill: int = game.inventory.items.size()
		while is_instance_valid(target) and swings < 10:
			await step(30)  # clear the blade cooldown (0.42s) between swings
			if is_instance_valid(target):
				game.player.attack(target)
			swings += 1
		# The player stands 1 unit from the kill, well inside Loot's 1.25
		# pickup radius, so the drop is auto-collected before a lingering
		# "loot" group node could ever be observed. spawn_loot() rolls either
		# gold or an Item (45% chance, since the M2 economy pass), so check
		# for either outcome rather than assuming gold specifically.
		var got_gold: bool = game.run_gold == gold_before_kill + 10
		var got_item: bool = game.inventory.items.size() == inventory_count_before_kill + 1
		check("melee-kills-enemy-and-loot-is-auto-collected", not is_instance_valid(target) and (got_gold or got_item),
			{"gold_before": gold_before_kill, "gold_after": game.run_gold, "inventory_before": inventory_count_before_kill, "inventory_after": game.inventory.items.size()})

	# Isolate enemy damage from the new carried-ore pollution mechanic.
	game.inventory.items.clear()
	game.safe_bag.items.clear()
	for loot in get_nodes_in_group("loot"): loot.queue_free()
	# --- Physical attack: leaving the locked sector prevents damage.
	# Pin the player to a fixed anchor first: teleport() also clears any
	# leftover move target so a manual position edit isn't fought the moment
	# the next physics frame ticks.
	game.player.teleport(arena_anchor)
	game.player.regen_timer = Player.HP_REGEN_INTERVAL  # keep passive regen out of this window
	await clear_all_enemies()
	game._spawn_enemy(arena_anchor + Vector3(2.0, 0.0, 0.0), false, false)
	await step(1)
	var hp_before_dodge: float = game.player.hp
	await step(20)  # let the telegraph begin (attack_timer starts at 0)
	game.player.teleport(arena_anchor + Vector3(10.0, 0.0, 0.0))  # leave the locked 2.4-radius sector
	await step(60)  # windup (0.55s) plus margin
	check("dodge-out-of-telegraph-avoids-damage", is_equal_approx(game.player.hp, hp_before_dodge),
		{"hp_before": hp_before_dodge, "hp_after": game.player.hp})

	game.player.teleport(arena_anchor)
	game.player.regen_timer = Player.HP_REGEN_INTERVAL
	await clear_all_enemies()
	game._spawn_enemy(arena_anchor + Vector3(2.0, 0.0, 0.0), false, false)
	await step(1)
	var hp_before_stand: float = game.player.hp
	await step(60)  # stay put through the full windup this time
	check("standing-in-telegraph-takes-damage", game.player.hp < hp_before_stand,
		{"hp_before": hp_before_stand, "hp_after": game.player.hp})

	# --- Ranged suppressor: telegraphs, fires a projectile, and it actually
	# hits a stationary player in its path.
	game.player.teleport(arena_anchor)
	game.player.regen_timer = Player.HP_REGEN_INTERVAL
	await clear_all_enemies()
	game._spawn_enemy(arena_anchor + Vector3(6.0, 0.0, 0.0), false, true)
	await step(1)
	var hp_before_ranged: float = game.player.hp
	await step(67)  # 1.0s windup (the windup is the warning now); arrow still in flight
	var projectile_seen := false
	for node in game.get_children():
		if node is EnemyProjectile:
			projectile_seen = true
	check("ranged-enemy-launches-projectile", projectile_seen, {"projectile_seen": projectile_seen})

	await step(70)  # 6 units at speed 9 (~0.67s) plus margin, comfortably inside the 5s regen window
	check("ranged-projectile-damages-stationary-player", game.player.hp < hp_before_ranged,
		{"hp_before": hp_before_ranged, "hp_after": game.player.hp})

	var report := {
		"scope": "downfall-godot combat tests (melee damage/kill/loot, telegraph dodge both ways, ranged suppressor)",
		"engine": Engine.get_version_info().string,
		"created_at": Time.get_datetime_string_from_system(true),
		"results": results,
		"failures": failures,
	}
	var evidence_dir := ProjectSettings.globalize_path("res://../evidence")
	DirAccess.make_dir_recursive_absolute(evidence_dir)
	var file := FileAccess.open(evidence_dir + "/downfall-test-combat-" + str(Time.get_unix_time_from_system()) + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("DOWNFALL TEST_COMBAT: %d checks / %d failures" % [results.size(), failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
