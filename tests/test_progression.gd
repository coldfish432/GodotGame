extends SceneTree

## B5 of 基地玩法策划案_v1_0.md: what facility levels open (仓库修订 2026-10-23:
## warehouse cells and stack size only), the order reroll, station markers, the
## base's top bar and the departure card (§2.2, §3.5, §3.6, §5).

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

## The first button under `node` whose meta `key` is `value`.
func _find_meta(node: Node, key: String, value: Variant) -> Button:
	for child in node.get_children():
		if child is Button and child.has_meta(key) and child.get_meta(key) == value: return child
		var found := _find_meta(child, key, value)
		if found != null: return found
	return null

func run() -> void:
	rules()
	await through_game()
	print("PROGRESSION FAILURES: %d" % failures)
	quit(1 if failures else 0)

func rules() -> void:
	var base := BaseState.new()
	# 仓库修订 (用户 2026-10-23): the warehouse is one count of cells for every
	# kind of item, raised with 仓储部 alone; no racks to build.
	check("Lv1: 60 cells, whatever the kind", base.capacity() == 60 and base.capacity(Item.Category.WEAPON) == 60 and base.capacity(Item.Category.MATERIAL) == 60 and base.stack_mult() == 1)
	var wh_price := int(BaseCatalog.facility_step("warehouse", 2).price)
	check("upgrading 仓储部 is refused without the gold", base.facility_refusal("warehouse", wh_price - 1) == "龙门币不足" and base.facility_refusal("warehouse", wh_price).is_empty())
	check("raising it opens the next level", base.raise_facility("warehouse") == 2 and base.facility_level("warehouse") == 2)
	check("Lv2: 120 cells, stacks ×2", base.capacity() == 120 and base.stack_mult() == 2)
	base.set_facility("warehouse", 3)
	check("Lv3: 220 cells, stacks ×3", base.capacity() == 220 and base.stack_mult() == 3)
	base.set_facility("warehouse", 4)
	check("Lv4: 360 cells, stacks ×5", base.capacity() == 360 and base.stack_mult() == 5)

	# One item or one stack a cell; stacks merge up to max_stack × stack_mult().
	var s := BaseState.new()
	s.set_facility("warehouse", 2)
	var bolts := MaterialCatalog.create("螺栓", 1)
	var limit := bolts.max_stack
	bolts.set_quantity(limit)
	check("a stack takes one cell", s.store(bolts) == "shelf" and s.shelf_count() == 1)
	var more := MaterialCatalog.create("螺栓", limit)
	check("a second stack merges into the cell up to twice the bag limit", s.store(more) == "shelf" and s.shelf_count() == 1 and bolts.quantity == limit * 2)
	var piece := s.bag_piece(bolts)
	check("bringing it to the pack splits off one bag-sized stack", piece != bolts and piece.quantity == limit and bolts.quantity == limit and s.shelf_count() == 1)
	# The piece went to the pack, so the cell has room for one bag stack again.
	for i in range(s.capacity() - s.shelf_count()): s.shelf.append(item("库存%d" % i, Item.Category.WEAPON))
	var blade := item("新刀", Item.Category.WEAPON)
	check("a full warehouse refuses what she stores", s.store_target(blade) == "" and s.store(blade) == "" and s.location_of(blade) == "")
	var fits := MaterialCatalog.create("螺栓", 1)
	check("…unless a stack still takes it", s.store(fits) == "shelf" and s.shelf_count() == s.capacity())
	var arrival := item("送回的甲", Item.Category.ARMOR)
	check("what the base brings home goes in over capacity, never lost", s.receive(arrival) and s.location_of(arrival) == "shelf" and s.shelf_count() == s.capacity() + 1)
	check("no crates and no staging any more", not "crates" in s and not "staging" in s and s.sealed_count() == 0)

	# Saves from before: crates and staging fold into the warehouse.
	var old := BaseState.new()
	var data := old.to_data()
	data["crates"] = [{"item": item("旧箱货", Item.Category.WEAPON).to_data(), "sealed": true}]
	data["staging"] = [item("旧暂存", Item.Category.TRINKET).to_data()]
	old.load_data(data, {})
	check("an old save's crates and staging land in the warehouse", old.shelf.size() == 2 and old.shelf.any(func(x): return x.item_name == "旧箱货") and old.shelf.any(func(x): return x.item_name == "旧暂存"))

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
	var hidden := unbuilt.all(func(s): return not s.hatch_mesh.visible and not s.node.visible and s.rack.leaves.all(func(x): return not x.visible))
	check("unbuilt racks are hidden with their hatches", unbuilt.size() == 32 and hidden)

	# Markers.
	check("every station has a marker", game.base_map.interactables.all(func(st): return game.markers.marker(st.id) != null))
	var arrived := item("新货", Item.Category.MATERIAL)
	game.base.receive(arrived)
	await step(2)
	# 仓库修订: arrivals go straight into the warehouse, so receiving never calls.
	check("arrivals go straight into the warehouse; the receiving marker stays hidden", game.base.location_of(arrived) == "shelf"
		and not game.station_needs_attention("receiving_bays") and (game.markers.marker("receiving_bays") == null or not game.markers.marker("receiving_bays").visible))
	check("a quiet station stays cyan", game.markers.marker("dispatch").texture == game.markers.cyan)
	game.base.report_unread = true
	await step(2)
	check("an unread report turns the desk yellow; the scan gate has no marker (污染不带出局外)",
		game.markers.marker("reception").texture == game.markers.yellow and game.markers.marker("decon") == null)

	# Top bar.
	game.base.injured = true
	await step(2)
	check("the base top bar shows gold and injury, never contamination or prestige: " + game._status_bar.text,
		game._status_bar.visible and "龙门币" in game._status_bar.text and not "声望" in game._status_bar.text and not "污染" in game._status_bar.text and "重伤" in game._status_bar.text)

	# Departure card only when there is something to look at (no crates to warn of now).
	game.request_contract("mine")
	check("with warnings, contracts show the departure card first", game.in_base and game.modal == "station" and game.menu.visible
		and game.departure_warnings().size() == 1)
	game.close_modal()
	game.base.injured = false
	check("without warnings there is none", game.departure_warnings().is_empty())
	await game.start_contract("mine")
	game.settle(true)
	await step(2)

	# 仓储部 to Lv2 on the 基建 page: more cells, bigger stacks, more racks drawn.
	var wh_price := int(BaseCatalog.facility_step("warehouse", 2).price)
	var start_gold := wh_price + 10000
	game.gold = start_gold
	check("the upgrade needs its materials", not game.upgrade_facility("warehouse") and "缺少" in game.facility_refusal("warehouse"))
	give(game, BaseCatalog.facility_step("warehouse", 2).materials)
	game.open_build_site("warehouse")
	var up: Button = _find_meta(game.menu, "facility", "warehouse")
	check("the warehouse's construction site offers the upgrade", up != null and not up.disabled)
	if up != null: up.pressed.emit()
	check("upgrading names what it opens: " + game.message, game.base.facility_level("warehouse") == 2 and "120 格" in game.message and game.gold == 10000)
	check("Lv2: 120 cells, stacks ×2", game.base.capacity() == 120 and game.base.stack_mult() == 2)
	game.close_modal()
	await step(3)
	check("the level's racks join the reveal", reveal.built_shelves().size() == 16)
	var a: Array = view.anchors.zones.weapon
	game.player.teleport(game.base_map.to_world((a[0] + a[2]) * 0.5, a[3] + 3.0, BaseMap.PLAYER_Y))
	var frames := 0
	while frames < 900 and not reveal.settled():
		await process_frame
		frames += 1
	var second: Dictionary = reveal._shelves.filter(func(s): return s.category == "weapon" and s.slot == 1)[0]
	check("and rises with the others", reveal.settled() and second.node.visible and is_zero_approx(second.node.position.y))
	var space := game.get_world_3d().direct_space_state
	var query := PhysicsPointQueryParameters3D.new()
	query.position = Vector3(second.node.position.x, 1.0, second.node.position.z) + BaseMap.ORIGIN
	check("and stands in the way like the first", not space.intersect_point(query).is_empty())
	check("nothing to buy for the warehouse: no drone, no console", not game.has_method("buy_drone") and not game.has_method("buy_console") and not game.has_method("build_rack") and game.base.console)

	# 仓储部 Lv4 no longer gives a free order reroll (仓库修订); the board has 3 + 1 slots.
	game.base.set_facility("warehouse", 4)
	await game.start_contract("city")
	game.settle(true)
	check("the board has ORDER_SLOTS + 1 slots", game.base.order_slot_count() == BaseCatalog.ORDER_SLOTS + 1)
	game.base.orders.slots = [{"id": "eng_materials", "state": "open", "delivered": []}, {"id": "log_trinkets", "state": "open", "delivered": []}, null]
	check("Lv4: no free reroll after a settlement", not game.base.reroll_available and not game.reroll_order(0))

	# Saves keep all of it.
	game.save_path = "user://progression_TEST_ONLY.json"
	game.save_enabled = true
	game.save_base()
	var racks: Dictionary = game.base.racks.duplicate()
	game.base = BaseState.new()
	game.load_base()
	await step(3)
	check("save keeps facility levels and the racks they draw", game.base.racks == racks and game.base.facility_level("warehouse") == 4 and game.base.capacity() == 360)
	check("racks from a save are shown", reveal.built_shelves().size() == 36)
	game.save_enabled = false
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(game.save_path + suffix): DirAccess.remove_absolute(game.save_path + suffix)
	game.queue_free()
	await step(2)
