extends SceneTree

## Balance smoke for 局内构筑与数值策划案 §12: the reactive AiDriver plays each
## region for a while and reports depth reached, relics collected, kills and
## life left. Not a pass/fail suite; run by hand when tuning numbers.

const SECONDS_PER_REGION := 150.0

func _initialize() -> void: call_deferred("run")

func run() -> void:
	Engine.time_scale = 4.0
	for region in ["mine", "city", "snow"]:
		var game := GameManager.new()
		game.save_enabled = false
		game.fixed_map_seed = 4242
		root.add_child(game)
		for i in range(4): await process_frame
		await game.start_contract(region)
		var driver := AiDriver.new()
		var kills := [0]
		var low := [game.player.max_hp]
		var start := Time.get_ticks_msec()
		var died := false
		var seen := {"depth": 1, "relics": [], "alert": 0.0, "hp": 0.0, "max": 0.0}
		var elapsed := 0.0
		while elapsed < SECONDS_PER_REGION:
			await physics_frame
			elapsed += 1.0 / Engine.physics_ticks_per_second
			if game.in_base:
				died = game.base_spawn == "death"
				break
			seen = {"depth": game.floor_number, "relics": game.builds.duplicate(), "alert": game.pressure, "hp": game.player.hp, "max": game.player.max_hp}
			# Take every relic the AI walks past: device offers, caches nearby.
			if game.modal == "build" and not game.build_offers.is_empty():
				game.choose_build(game.build_offers[0].id)
			for node in game.get_tree().get_nodes_in_group("relic_caches"):
				if not node.sealed and game.near(node) and game.modal.is_empty(): game.open_relic_offer(node.source, node)
			low[0] = minf(low[0], game.player.hp)

			driver.decide(game)
		print("SIM %s: %s  depth %d  relics %d %s  hp %d/%d (lowest %d)  alert %d  real %.0fs" % [region, "DIED" if died else ("EXTRACTED" if game.in_base else "alive"),
			seen.depth, seen.relics.size(), seen.relics,
			roundi(seen.hp), roundi(seen.max), roundi(low[0]), roundi(seen.alert), (Time.get_ticks_msec() - start) / 1000.0])
		game.queue_free()
		await process_frame
	quit(0)
