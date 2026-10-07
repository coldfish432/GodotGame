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

## Pack contents counted by units, so a drop that merges into a stack counts.
func inventory_units() -> int:
	var total := 0
	for item in game.inventory.items: total += item.quantity
	return total

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
		var units_before_kill: int = inventory_units()
		while is_instance_valid(target) and swings < 10:
			await step(45)  # clear the blade cooldown (0.7s) between swings
			if is_instance_valid(target):
				game.player.attack(target)
			swings += 1
		# Drops follow 掉落物策划案 §3.1: a kill can drop nothing (12%), gold
		# (8–14) or items, scattered in a ring around the body. Walk over every
		# drop, then check each was collected and something was gained unless
		# the roll was "nothing".
		var drops := get_nodes_in_group("loot").filter(func(n): return is_instance_valid(n) and not n.is_queued_for_deletion())
		var dropped := drops.size()
		for loot in drops:
			if is_instance_valid(loot):
				game.player.teleport(loot.global_position)
				await step(3)
		await step(2)
		var left := get_nodes_in_group("loot").filter(func(n): return is_instance_valid(n) and not n.is_queued_for_deletion()).size()
		var gained: bool = game.run_gold > gold_before_kill or inventory_units() > units_before_kill
		check("melee-kills-enemy-and-loot-is-auto-collected", not is_instance_valid(target) and left == 0 and (gained or dropped == 0),
			{"dropped": dropped, "left": left, "gold_before": gold_before_kill, "gold_after": game.run_gold, "inventory_before": inventory_count_before_kill, "inventory_after": game.inventory.items.size()})

	# --- Air swings (用户 2026-10-07): a ground click still lands on an enemy in
	# reach in front of her; one behind her, or out of reach, is untouched.
	game.player.teleport(arena_anchor)
	await clear_all_enemies()
	var front: Enemy = game._spawn_enemy(arena_anchor + Vector3(2.0, 0.0, 0.0), false, false)
	var behind: Enemy = game._spawn_enemy(arena_anchor + Vector3(-2.0, 0.0, 0.0), false, false)
	var far: Enemy = game._spawn_enemy(arena_anchor + Vector3(8.0, 0.0, 0.5), false, false)
	await step(2)
	var front_hp: float = front.health
	var behind_hp: float = behind.health
	var far_hp: float = far.health
	game.player._attack_cooldown = 0
	game.player.attack_direction(Vector3.RIGHT)
	check("air-swing-hits-enemy-in-reach-in-front", front.health < front_hp and is_equal_approx(behind.health, behind_hp) and is_equal_approx(far.health, far_hp),
		{"front": [front_hp, front.health], "behind": [behind_hp, behind.health], "far": [far_hp, far.health]})
	await step(45)
	var charge_before: int = game.player.sword_charge
	game.player.attack_direction(Vector3.FORWARD)
	check("air-swing-at-nobody-is-a-whiff", game.player.sword_charge == charge_before and is_equal_approx(behind.health, behind_hp),
		{"charge": [charge_before, game.player.sword_charge]})
	# A ranged weapon cannot swing at the air.
	await step(45)
	var bow := Item.create("测试弩", Item.Category.WEAPON, 1, 3)
	bow.base_id = "_test_crossbow"
	GearCatalog.extra_bases["_test_crossbow"] = {"form": "crossbow"}
	game.player.equipped[Item.Category.WEAPON] = bow
	var front_before_bow: float = front.health
	game.player._attack_cooldown = 0
	game.player.attack_direction(Vector3.RIGHT)
	check("ranged-weapon-cannot-air-attack", game.player.is_ranged_weapon() and is_equal_approx(front.health, front_before_bow) and game.player._attack_cooldown <= 0,
		{"front": [front_before_bow, front.health]})
	game.player.equipped.erase(Item.Category.WEAPON)
	GearCatalog.extra_bases.erase("_test_crossbow")
	await clear_all_enemies()

	# --- Target lock (用户 2026-10-07): one click locks an enemy; she closes to
	# her weapon's reach, stops there and attacks only it.
	game.player.teleport(arena_anchor)
	await clear_all_enemies()
	var mark: Enemy = game._spawn_enemy(arena_anchor + Vector3(8.0, 0.0, 0.0), false, false)
	mark.set_physics_process(false)
	var bystander: Enemy = game._spawn_enemy(arena_anchor + Vector3(0.0, 0.0, 2.5), false, false)
	bystander.set_physics_process(false)
	for e in [mark, bystander]:
		e.max_health = 100000.0
		e.health = 100000.0
	await step(2)
	var mark_hp: float = mark.health
	var bystander_hp: float = bystander.health
	game.player._attack_cooldown = 0
	game.player.lock_target(mark)
	await step(120)
	var gap: float = Vector2(mark.global_position.x - game.player.global_position.x, mark.global_position.z - game.player.global_position.z).length()
	check("melee-lock-closes-in-and-attacks-only-the-target", mark.health < mark_hp and is_equal_approx(bystander.health, bystander_hp) and gap <= Player.BLADE_RANGE + 0.05,
		{"gap": gap, "mark": [mark_hp, mark.health], "bystander": [bystander_hp, bystander.health]})
	# Ranged: stops at its own range instead of walking into melee.
	GearCatalog.extra_bases["_test_crossbow"] = {"form": "crossbow", "range": 7.0}
	var crossbow := Item.create("测试弩", Item.Category.WEAPON, 1, 3)
	crossbow.base_id = "_test_crossbow"
	game.player.equipped[Item.Category.WEAPON] = crossbow
	game.player.teleport(arena_anchor)
	# A spot 12 away with a clear line from her (the field has pillars).
	var spot := arena_anchor + Vector3(12.0, 0.0, 0.0)
	for angle in range(0, 360, 15):
		var candidate := arena_anchor + Vector3(12.0, 0.0, 0.0).rotated(Vector3.UP, deg_to_rad(angle))
		if game.line_of_sight(arena_anchor, candidate) and game.world_map.try_sample_navigation_position(candidate, 0.5).distance_to(candidate) < 0.6:
			spot = candidate
			break
	mark.global_position = spot
	await step(2)
	mark_hp = mark.health
	game.player.lock_target(mark)
	await step(150)
	gap = Vector2(mark.global_position.x - game.player.global_position.x, mark.global_position.z - game.player.global_position.z).length()
	check("ranged-lock-stops-at-max-range-and-attacks", mark.health < mark_hp and gap > 6.0 and gap <= 7.05, {"gap": gap, "mark": [mark_hp, mark.health]})
	# Keys cancel the lock; a dead target releases it.
	Input.action_press("move_left")
	await step(3)
	Input.action_release("move_left")
	check("keys-cancel-the-lock", not game.player.has_target(), {})
	game.player.lock_target(mark)
	mark.take_hit(mark.health + 1.0, "true")
	await step(3)
	check("a-dead-target-releases-the-lock", game.player.attack_target == null, {})
	game.player.equipped.erase(Item.Category.WEAPON)
	GearCatalog.extra_bases.erase("_test_crossbow")
	await clear_all_enemies()

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
