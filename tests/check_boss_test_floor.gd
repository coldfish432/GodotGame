extends SceneTree

## DOWNFALL_BOSS_FLOOR (tools/boss_test.ps1): the contract opens on that floor,
## the player a short walk from its boss or warden, and free to move.

var failures := 0
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool, detail: Variant = null) -> void:
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label + ("" if detail == null or passed else "  %s" % str(detail)))

func run() -> void:
	var want := GameManager.boss_test_floor()
	print("floor env: ", want)
	for region in ["mine", "city", "snow", "siracusa"]:
		var game := GameManager.new()
		game.save_enabled = false
		game.fixed_map_seed = 4242
		root.add_child(game)
		await step(8)
		await game.start_contract(region)
		await step(4)
		if want > 0: check("%s on floor %d" % [region, want], game.floor_number == want, game.floor_number)
		var boss = game.outpost_boss
		if want > 0 and is_instance_valid(boss):
			var d: float = game.player.global_position.distance_to(boss.global_position)
			check("%s boss %.0f m away" % [region, d], d < 45.0, d)
		check("%s simulation active" % region, game.simulation_active(), "modal=%s transitioning=%s looting=%s" % [game.modal, game.transitioning, game.looting])
		var from: Vector3 = game.player.global_position
		game.player.set_move_target(from + Vector3(0, 0, -8))
		await step(40)
		var moved := from.distance_to(game.player.global_position)
		check("%s walks to a click (%.2f m)" % [region, moved], moved > 1.0, "on_floor=%s pos=%s" % [game.player.is_on_floor(), game.player.global_position])
		var keys_from: Vector3 = game.player.global_position
		game.player.set_move_target(keys_from + Vector3(-8, 0, 0))
		await step(40)
		check("%s walks to a second click" % region, keys_from.distance_to(game.player.global_position) > 1.0)
		game.queue_free()
		await step(2)
	print("BOSS TEST FLOOR RESULT: %d failures" % failures)
	quit(1 if failures else 0)
