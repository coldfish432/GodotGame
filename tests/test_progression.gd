extends SceneTree

## B5 of 基地玩法策划案_v1_0.md: what prestige ranks open, building racks, the
## sorting drone, the R3 order reroll, station markers, the base's top bar and
## the departure card (§2.2, §3.5, §3.6, §5).

var failures := 0
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool) -> void:
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label)
func item(name: String, category: Item.Category) -> Item:
	return Item.create(name, category, 1, 1, 1.0)


## Puts `cost` on the shelf (one item per unit for supplies that do not stack).
func give(game: GameManager, cost: Dictionary) -> void:
	for id in cost:
		var left := int(cost[id])
		while left > 0:
			var m := MaterialCatalog.create(id, left)
			game.base.shelf.append(m)
			left -= m.quantity

func run() -> void:
	rules()
	await through_game()
	print("PROGRESSION FAILURES: %d" % failures)
	quit(1 if failures else 0)

func rules() -> void:
	var base := BaseState.new()
	check("racks follow the build order's prices and ranks", BaseCatalog.RACK_PRICES == [0, 6000, 9000, 14000, 14000, 14000, 20000, 20000, 20000]
		and BaseCatalog.RACK_RANKS == [0, 1, 1, 2, 2, 2, 3, 3, 3])
	check("the second rack needs R1", "R1" in base.rack_refusal(Item.Category.WEAPON, 99999))
	base.add_prestige(20)
	check("a rank-up leaves something new to look at", base.unseen_unlocks and base.rank() == 1)
	check("at R1 with enough gold it can be built", base.rack_refusal(Item.Category.WEAPON, 6000).is_empty() and "龙门币不足" in base.rack_refusal(Item.Category.WEAPON, 5999))
	check("building the second rack: 24 cells", base.build_rack(Item.Category.WEAPON) == 1 and base.capacity(Item.Category.WEAPON) == 24)
	base.build_rack(Item.Category.WEAPON)
	check("the middle row needs R2", "R2" in base.rack_refusal(Item.Category.WEAPON, 999))
	for i in range(6): base.racks[Item.Category.WEAPON] = 3 + i + 1
	check("nine racks is the most: 108 cells", base.capacity(Item.Category.WEAPON) == 108 and base.next_rack_slot(Item.Category.WEAPON) == -1)

	# Sort everything: open, shelve what fits, stage the rest, never lose any.
	var s := BaseState.new()
	for i in range(11): s.shelf.append(item("库存%d" % i, Item.Category.WEAPON))
	var a := item("新刀1", Item.Category.WEAPON)
	var b := item("新刀2", Item.Category.WEAPON)
	var c := item("新甲", Item.Category.ARMOR)
	var staged := item("暂存饰品", Item.Category.TRINKET)
	for x in [a, b, c]: s.receive(x)
	s.staging.append(staged)
	var result := s.sort_all()
	check("every sealed crate is opened and shown", result.revealed.size() == 3)
	check("what fits goes on its shelf (one weapon, the armor, the staged trinket)",
		s.location_of(a) == "shelf" and s.location_of(c) == "shelf" and s.location_of(staged) == "shelf")
	check("the weapon with no room goes to staging", s.location_of(b) == "staging" and result.staged.has(b))
	check("nothing lost, nothing duplicated", s.all_items().size() == 11 + 4 and s.crates.is_empty())

	var board := OrderBoard.new()
	board.slots = [{"id": "eng_materials", "state": "open", "delivered": []}, null]
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	check("reroll swaps an open order for a different template", board.reroll(0, rng) and board.slots[0].id != "eng_materials")
	check("an empty slot cannot be rerolled", not board.reroll(1, rng))

func through_game() -> void:
	var game := GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	await step(8)
	var view := game.warehouse_view
	var reveal := game.base_map.warehouse_reveal
	check("every rack slot is in the scene, only the first per zone built",
		reveal._shelves.size() == 36 and reveal.built_shelves().size() == 4 and reveal.built_shelves().all(func(s): return s.slot == 0))
	var unbuilt := reveal._shelves.filter(func(s): return not s.built)
	var hidden := unbuilt.all(func(s): return not s.hatch_mesh.visible and s.sprites.all(func(x): return not x.visible))
	check("unbuilt racks are hidden with their hatches", unbuilt.size() == 32 and hidden)

	# Markers.
	check("every station has a marker", game.base_map.interactables.all(func(st): return game.markers.marker(st.id) != null))
	game.base.receive(item("新货", Item.Category.MATERIAL))
	await step(2)
	check("sealed crates turn the receiving marker yellow", game.markers.marker("receiving_bays").visible and game.markers.marker("receiving_bays").texture == game.markers.yellow)
	check("a quiet station stays cyan", game.markers.marker("dispatch").texture == game.markers.cyan)
	game.base.contamination = 45
	game.base.report_unread = true
	await step(2)
	check("contamination 40+ and an unread report turn the gate and desk yellow",
		game.markers.marker("decon").texture == game.markers.yellow and game.markers.marker("reception").texture == game.markers.yellow)

	# Top bar.
	game.base.injured = true
	await step(2)
	check("the base top bar shows gold, prestige, contamination and injury: " + game._status_bar.text,
		game._status_bar.visible and "龙门币" in game._status_bar.text and "声望 R0 · 0/20" in game._status_bar.text and "污染 45 轻度" in game._status_bar.text and "重伤" in game._status_bar.text)

	# Departure card only when there is something to look at.
	game.request_contract("mine")
	check("with warnings, contracts show the departure card first", game.in_base and game.modal == "station" and game.menu.visible
		and game.departure_warnings().size() == 2)
	game.close_modal()
	game.base.injured = false
	game.base.contamination = 0
	game.base.crates.clear()
	check("without warnings there is none", game.departure_warnings().is_empty())
	await game.start_contract("mine")
	game.settle(true)
	await step(2)

	# Prestige to R1: drone and front-row racks.
	game.gold = 100000
	check("the drone needs R1", not game.buy_drone())
	game._grant(0, 20)
	check("rank-up message names what it opens: " + game.message, "R1" in game.message and "无人机" in game.message)
	check("the warehouse terminal marker turns yellow until it is opened", game.station_needs_attention("stash"))
	game.open_station("stash")
	game.close_modal()
	check("opening it clears that", not game.station_needs_attention("stash"))
	check("without materials the rack is refused", not game.build_rack(Item.Category.WEAPON) and "螺栓" in game.message)
	give(game, BaseCatalog.RACK_MATERIALS[1])
	check("build the second weapon rack for 6000 + its materials", game.build_rack(Item.Category.WEAPON) and game.gold == 94000 and game.base.racks[Item.Category.WEAPON] == 2)
	await step(3)
	check("the new rack joins the reveal", reveal.built_shelves().size() == 5)
	var a: Array = view.anchors.zones.weapon
	game.player.teleport(game.base_map.to_world((a[0] + a[2]) * 0.5, a[3] + 3.0, BaseMap.PLAYER_Y))
	var frames := 0
	while frames < 900 and not reveal.settled():
		await process_frame
		frames += 1
	var second: Dictionary = reveal._shelves.filter(func(s): return s.category == "weapon" and s.slot == 1)[0]
	check("and rises with the others", reveal.settled() and second.sprites.all(func(x): return x.visible))
	var space := game.get_world_3d().direct_space_state
	var query := PhysicsPointQueryParameters3D.new()
	query.position = Vector3(second.sprites[0].position.x, 1.0, second.sprites[0].position.z) + BaseMap.ORIGIN
	check("and stands in the way like the first", not space.intersect_point(query).is_empty())
	give(game, BaseCatalog.DRONE_MATERIALS)
	check("buy the drone for 15000 + its materials", game.material_count("螺栓") == 0 and game.buy_drone() and game.gold == 79000 and not game.buy_drone())

	# Sort everything with the drone.
	var finds: Array[Item] = []
	for i in range(5): finds.append(item("矿料%d" % i, Item.Category.MATERIAL))
	for x in finds: game.base.receive(x)
	var result := game.sort_everything()
	check("sort everything opens and shelves them", result.revealed.size() == 5 and finds.all(func(x): return game.base.location_of(x) == "shelf"))
	check("and shows the reveal", game.modal == "station" and game.menu.visible)
	await step(2)
	check("the drone flies the delivery", view.drone.flying())
	game.close_modal()
	var later := item("暂存材料", Item.Category.MATERIAL)
	game.base.staging.append(later)
	await game.start_contract("city")
	game.settle(true)
	check("on every return the drone empties staging onto the shelves", game.base.location_of(later) == "shelf")

	# R3 reroll, once per settlement.
	game._grant(0, 100)
	check("not before the next settlement", not game.base.reroll_available)
	await game.start_contract("city")
	game.settle(true)
	game.base.orders.slots = [{"id": "eng_materials", "state": "open", "delivered": []}, {"id": "log_trinkets", "state": "open", "delivered": []}, null]
	check("R3: one free reroll after a settlement", game.base.rank() == 3 and game.reroll_order(0) and not game.reroll_order(1))

	# Saves keep all of it.
	game.save_path = "user://progression_TEST_ONLY.json"
	game.save_enabled = true
	game.save_base()
	var racks: Dictionary = game.base.racks.duplicate()
	game.base = BaseState.new()
	game.load_base()
	await step(3)
	check("save keeps racks, the drone and prestige", game.base.racks == racks and game.base.drone and game.base.rank() == 3)
	check("racks from a save are shown", reveal.built_shelves().size() == 5)
	game.save_enabled = false
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(game.save_path + suffix): DirAccess.remove_absolute(game.save_path + suffix)
	game.queue_free()
	await step(2)
