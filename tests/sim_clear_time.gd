extends SceneTree

## How long a full clear of one floor takes (用户 2026-10-14): the AiDriver kills
## every enemy, then walks to every search point and searches it to the end.
## Game seconds, threat meter held at zero so no patrols interfere. Not a
## pass/fail suite; run by hand.

const CAP := 900.0
const SEEDS := [4242, 1729, 9001]
const FLOORS := [1, 5]

func _initialize() -> void: call_deferred("run")

func run() -> void:
	Engine.time_scale = 4.0
	# DOWNFALL_SIM=mine:5 (or mine:5:4242) runs one region and floor (and seed) only (one process each keeps a crash local).
	var only := OS.get_environment("DOWNFALL_SIM").split(":")
	for region in ["mine", "city", "snow"]:
		for depth in FLOORS:
			if only.size() >= 2 and (only[0] != region or int(only[1]) != depth): continue
			for map_seed in SEEDS:
				if only.size() == 3 and int(only[2]) != map_seed: continue
				await _one(region, depth, map_seed)
	quit(0)

func _one(region: String, depth: int, map_seed: int) -> void:
	var game := GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = map_seed
	root.add_child(game)
	for i in range(4): await process_frame
	await game.start_contract(region)
	if depth > 1:
		game.floor_number = depth - 1
		await game.advance(0)
	game.player.invulnerable = true
	var driver := AiDriver.new()
	var t := 0.0
	var fight_done := -1.0
	var walked := 0.0
	var last := game.player.global_position
	var enemies_at_start := _enemies(game).size()
	var fill: float = game.threat.fill_seconds
	var boxes: Array = game.get_tree().get_nodes_in_group("loot_containers").filter(func(b): return b.game == game and not b.sealed)
	var searched := 0
	var stuck := 0
	var left := 9999
	var since := 0.0
	var box_time := 0.0
	var search_time := 0.0
	while t < CAP:
		await physics_frame
		# Each physics tick covers time_scale ticks of game time.
		var dt := Engine.time_scale / Engine.physics_ticks_per_second
		t += dt
		game.threat.value = 0.0
		if game.in_base: break
		walked += Vector2(game.player.global_position.x - last.x, game.player.global_position.z - last.z).length()
		last = game.player.global_position
		var alive := _enemies(game)
		if not alive.is_empty():
			if game.hands_busy(): game.close_modal()
			# No kill in 40 s: the bot cannot reach the nearest one; take it off the count.
			since += dt
			if alive.size() < left:
				left = alive.size()
				since = 0.0
			elif since > 40.0:
				alive.sort_custom(func(a, b): return a.global_position.distance_to(game.player.global_position) < b.global_position.distance_to(game.player.global_position))
				alive[0].take_hit(99999999.0, "true")
				stuck += 1
				since = 0.0
			driver.decide(game)
			continue
		if fight_done < 0.0: fight_done = t
		# Searching: stand at the box until every item is found, then move on.
		if game.hands_busy():
			search_time += dt
			if game.looting.fully_searched():
				game.looting.storage.items.clear()
				game.close_modal()
				searched += 1
			continue
		var open: Array = boxes.filter(func(b): return is_instance_valid(b) and not b.fully_searched())
		if open.is_empty(): break
		open.sort_custom(func(a, b): return a.global_position.distance_to(game.player.global_position) < b.global_position.distance_to(game.player.global_position))
		var box: LootContainer = open[0]
		if box_time > 40.0:
			box.set("opened", true)
			box.set("_pending", [])
			stuck += 1
			box_time = 0.0
			continue
		box_time += dt
		if game.player.global_position.distance_to(box.global_position) < 2.0:
			box_time = 0.0
			game.player.clear_move_target()
			game._interact()
			if not game.hands_busy():
				# A box that would not open (a mimic woke): count it, the fight goes on.
				box.set("opened", true)
				box.set("_pending", [])
		else:
			driver._move_toward(game, game.player, box.global_position)
	print("CLEAR %s F%d seed %d: total %.0fs  fight %.0fs  search %.0fs (%d boxes)  walk %.0fm  enemies %d  unreachable %d  fill %.0fs → %.1f waves%s" % [region, depth, map_seed, t,
		fight_done if fight_done >= 0.0 else t, search_time, searched, walked, enemies_at_start, stuck, fill, t / fill, "  CAPPED" if t >= CAP else ""])
	game.queue_free()
	await process_frame

func _enemies(game: GameManager) -> Array:
	return game.get_tree().get_nodes_in_group("enemies").filter(func(e): return e.game == game and not e._dead and not e.attack_profile.get("neutral", false))
