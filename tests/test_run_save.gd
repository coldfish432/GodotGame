extends SceneTree
## 局内存档 (用户 2026-10-24: 局内保存并退出，读档仍在局内，本层原地继续):
## in every region, on the first floor and one further down, a run saved in
## the field loads back in the field — the same floor, her where she stood,
## the dead still dead, the boxes as searched, the ground loot where it lay,
## the fog, the relics and the meters; and a save picked up once is used up.
var failures := 0
## One file per process: two runs at once (another session's run_all) shared
## one path and deleted or overwrote each other's saves mid-test.
var PATH := "user://run_save_TEST_ONLY_%d.json" % OS.get_process_id()
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool, detail: Variant = null) -> void:
	print(("PASS " if passed else "FAIL ") + label + ("" if detail == null or passed else "  " + str(detail)))
	if not passed: failures += 1

func clean() -> void:
	for suffix in ["", ".bak", ".tmp", ".lock", ".market", ".release"]:
		if FileAccess.file_exists(PATH + suffix): DirAccess.remove_absolute(PATH + suffix)

func boot() -> GameManager:
	var game := GameManager.new()
	game.save_path = PATH
	root.add_child(game)
	while game.booting: await step(1)
	await step(2)
	return game

func alive(game: GameManager) -> Array:
	return RunSave.floor_pieces(game).filter(func(n): return n is Enemy and not n._dead and n.get_meta("floor_id", -1) >= 0).map(func(n): return int(n.get_meta("floor_id")))

func boxes(game: GameManager) -> Array:
	var out := []
	for n in RunSave.floor_pieces(game):
		if n is LootContainer: out.append([int(n.get_meta("floor_id", -1)), n.opened, n._pending.size(), n.storage.items.size()])
	out.sort()
	return out

func ground(game: GameManager) -> Array:
	var out := []
	for n in game.get_children():
		if n is Loot and not n.is_queued_for_deletion(): out.append(n.item.uid)
	out.sort()
	return out

func state(game: GameManager) -> Dictionary:
	return {"floor": game.floor_number, "region": game.region_id, "alive": alive(game), "boxes": boxes(game), "ground": ground(game),
		"builds": game.builds.duplicate(), "threat": snappedf(game.threat.value, 0.01), "fog": game.fog.revealed_cells(),
		"pack": game.inventory.items.map(func(i): return i.uid), "hp": roundi(game.player.hp),
		"at": Vector2(snappedf(game.player.global_position.x, 0.1), snappedf(game.player.global_position.z, 0.1)),
		"made": game._floor_made.size(), "vault": game.vault_opened, "spent": game.traps.filter(func(t): return t.spent).size()}

func play_a_little(game: GameManager) -> void:
	# Kill three, search a box to the end and one half way, drop an item,
	# spring a trap, take a relic, walk off a way, take a hit.
	var enemies: Array = RunSave.floor_pieces(game).filter(func(n): return n is Enemy and not n is Boss and not n._dead)
	for i in range(mini(3, enemies.size())): enemies[i].take_hit(1.0e9, "true")
	var found: Array = RunSave.floor_pieces(game).filter(func(n): return n is LootContainer and not n.mimic)
	if found.size() >= 1: found[0].open_now()
	if found.size() >= 2:
		found[1].begin_open()
		game.looting = found[1]
		for k in range(240):
			if found[1]._pending.size() <= 1: break
			await step(1)
		game._stop_looting()
	if not game.inventory.items.is_empty(): game.drop_item(game.inventory.items[0], game.inventory)
	if not game.traps.is_empty(): game.traps[0].mark_spent()
	var relic := RelicCatalog.roll_offers(game.region_id, game.builds, "device", game.rng, 1)
	if not relic.is_empty(): game.builds.append(str(relic[0].id))
	game.player._recompute_stats()
	# Somewhere along the route, off every trap: loaded, she is not invulnerable.
	var walk: PackedVector2Array = game.world_map.main_path
	for k in range(4, walk.size()):
		var spot := game.world_map.nearest_walkable(Vector3(walk[k].x, 0, walk[k].y))
		if game.traps.all(func(t): return Vector2(t.global_position.x - spot.x, t.global_position.z - spot.z).length() > 6.0):
			game.player.teleport(spot)
			break
	game.fog.reveal(game.player.global_position)
	game.player.invulnerable = true
	game.player.hp = game.player.max_hp * 0.6
	game.threat.value = 37.5
	await step(20)

func round_trip(region: String, deeper: bool) -> void:
	clean()
	SystemScreens.settings["auto_potion"] = ""
	var game := await boot()
	game.fixed_map_seed = 3100 + region.length()
	# A floor to save: no map-less 不期而遇 on the way (肉鸽路线图).
	game.route_plain = true
	await game.start_contract(region)
	if deeper:
		await game.advance(0)
		await step(4)
	var where := "%s floor %d" % [region, game.floor_number]
	await play_a_little(game)
	var before := state(game)
	check(where + ": saving in the field works", game.can_save_run() and game.save_run())
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	check(where + ": the save holds the run and the contract stays open", saved.has("run") and bool(saved.active_contract))
	game.queue_free()
	await step(3)

	var back := await boot()
	var after := state(back)
	check(where + ": loads in the field, not the base", not back.in_base and not back.in_camp and back._resume.is_empty())
	check(where + ": the floor is rebuilt as it was built", after.made == before.made and not back.last_notice.contains("未能按存档复原"), [before.made, after.made, back.last_notice])
	# The meter goes on filling while the floor loads.
	check(where + ": threat as saved", absf(float(after.threat) - float(before.threat)) < 0.5, [before.threat, after.threat])
	for key in ["floor", "region", "alive", "boxes", "ground", "builds", "fog", "pack", "vault", "spent"]:
		check(where + ": " + key + " as saved", after[key] == before[key], [before[key], after[key]])
	check(where + ": her life as saved", absi(int(after.hp) - int(before.hp)) <= 1, [before.hp, after.hp])
	check(where + ": she stands where she was", (after.at as Vector2).distance_to(before.at) < 0.6, [before.at, after.at])
	var used: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	check(where + ": picked up, the save is used up (a crash now settles as before)", not used.has("run") and bool(used.active_contract))
	# Saved again and loaded again: still the same.
	back.save_run()
	back.queue_free()
	await step(3)
	var again := await boot()
	check(where + ": a second round trip keeps it", state(again).alive == before.alive and state(again).ground == before.ground)
	again.queue_free()
	await step(3)

## A map-less 不期而遇 (肉鸽路线图): saved on its card, loaded back on it.
func event_trip() -> void:
	clean()
	var game := await boot()
	game.fixed_map_seed = 78
	await game.start_contract("mine", 0)
	await step(4)
	game._ensure_route()
	for node in game.route_map.cols[1]:
		node.kind = "event"
		node.event = "gambler"
		node.exit = false
	await game.advance(0)
	await step(2)
	check("event: saving on a map-less card works", game.in_event and game.save_run())
	game.queue_free()
	await step(3)
	var back := await boot()
	check("event: loads back on its card", back.in_event and back.modal == "event" and back.floor_number == 2 and back.event_id() == "gambler")
	back.queue_free()
	await step(3)

func camp_trip() -> void:
	clean()
	var game := await boot()
	game.fixed_map_seed = 77
	await game.start_contract("mine", 0)
	await step(4)
	game.floor_number = 10
	await game._enter_camp()
	var map: Dictionary = game.route_map.duplicate(true)
	await step(2)
	check("camp: saving in a camp works", game.in_camp and game.save_run())
	game.queue_free()
	await step(3)
	var back := await boot()
	check("camp: loads back in the camp", back.in_camp and not back.in_base and back.modal.is_empty() and back.encounter == "closure" and back.floor_number == 10 and back.route_node == Vector2i(-1, 0) and back.route_map == map)
	back.queue_free()
	await step(3)

## Every stream's dice are kept; a save from before the streams (one state
## each) still loads in the field.
func old_save_trip() -> void:
	clean()
	SystemScreens.settings["auto_potion"] = ""
	var game := await boot()
	game.fixed_map_seed = 3107
	game.route_plain = true
	await game.start_contract("mine")
	await step(4)
	game.save_run()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	var run_rng: Variant = saved.run.get("rng")
	var entry: Dictionary = saved.run.get("entry", {})
	check("streams: the run, the floor and the wave keep every stream", run_rng is Dictionary and entry.get("rng") is Dictionary and entry.get("wave") is Dictionary
		and GameManager.RNG_STREAMS.all(func(k): return run_rng.has(k) and entry.rng.has(k) and entry.wave.has(k)) and saved.get("rng_streams") is Dictionary)
	saved.run.rng = str(run_rng.rng)
	entry.rng = str(entry.rng.rng)
	entry.wave = str(entry.wave.rng)
	saved.erase("rng_streams")
	game.queue_free()
	await step(3)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(saved))
	file.close()
	var back := await boot()
	check("streams: an older save with one state loads in the field", not back.in_base and not back.in_camp and back._resume.is_empty() and back.floor_number == 1)
	back.queue_free()
	await step(3)

func no_save_in_base() -> void:
	clean()
	var game := await boot()
	check("at the base there is no field save", game.in_base and not game.can_save_run())
	game.queue_free()
	await step(3)

func run() -> void:
	# The set pieces (BossShow) have their own suite; these check the fight itself.
	BossShow.enabled = false
	await no_save_in_base()
	for region in ["mine", "snow", "city", "siracusa"]:
		await round_trip(region, false)
	await round_trip("snow", true)
	await round_trip("siracusa", true)
	await camp_trip()
	await old_save_trip()
	await event_trip()
	clean()
	print("RUN SAVE FAILURES %d" % failures)
	quit(1 if failures else 0)
