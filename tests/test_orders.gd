extends SceneTree

## B3 of 基地玩法策划案_v1_0.md: delivery orders, plain delivery and prestige
## (§2, §3.8). Board rules on their own, then delivery through the game.

var failures := 0
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool) -> void:
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label)
func item(name: String, category: Item.Category, value: int = 10, region: String = "", rarity: int = 0) -> Item:
	var x := Item.create(name, category, 1, 1, 1.0)
	x.value = value
	x.origin_region = region
	x.rarity = rarity
	return x
## A material stack: `units` units worth `unit_value` each (orders count units).
func stack(units: int, unit_value: int, region: String = "") -> Item:
	var x := MaterialCatalog.create("源岩", units, region)
	x.unit_value = unit_value
	x.set_quantity(units)
	return x
func board_with(ids: Array) -> OrderBoard:
	var board := OrderBoard.new()
	board.slots = ids.map(func(id): return null if id == null else {"id": id, "state": "open", "delivered": []})
	return board

func run() -> void:
	rules()
	await through_game()
	print("ORDERS FAILURES: %d" % failures)
	quit(1 if failures else 0)

func rules() -> void:
	var fresh := OrderBoard.new()
	fresh.start_fresh()
	check("a new game posts the starter order with the second slot empty", fresh.slots.size() == 2 and fresh.slots[0].id == "starter" and fresh.slots[1] == null)
	check("order text names department, item and count: " + BaseCatalog.order_text("eng_mine_materials"),
		BaseCatalog.order_text("eng_mine_materials") == "工程部：材料 ×8（产地：切尔诺伯格）")

	# Matching: category, rarity, origin, exclusives.
	var b := board_with(["eng_mine_materials", "log_fine_weapon", "eng_raw_ore"])
	check("material from the mine fits, from elsewhere does not", b.matches(0, item("矿料", Item.Category.MATERIAL, 10, "mine")) and not b.matches(0, item("雪料", Item.Category.MATERIAL, 10, "snow")))
	check("old items without an origin do not fit a regional order", not b.matches(0, item("旧料", Item.Category.MATERIAL)))
	check("fine weapon order refuses a common weapon", not b.matches(1, item("普通刀", Item.Category.WEAPON)) and b.matches(1, item("精良刀", Item.Category.WEAPON, 10, "", 1)))
	check("exclusive orders want that exact exclusive", b.matches(2, FieldCatalog.exclusive("mine")) and not b.matches(2, FieldCatalog.exclusive("city")))

	# Partial delivery, then payout on completion.
	var first := b.deliver(0, stack(3, 10, "mine"))
	check("first 3 of 8 units: progress, no pay yet", not first.done and first.gold == 0 and b.remaining(0) == 5)
	var big := stack(9, 8, "mine")
	var second := b.deliver(0, big)
	check("a 9-stack gives only the 5 still asked for", int(second.used) == 5)
	check("completes: (30 + 5×8) ×100 x 1.4 = 9800 龙门币, 6 prestige", second.done and second.gold == 9800 and second.prestige == 6 and b.slots[0].state == "done")
	check("a done order takes nothing more", b.deliver(0, stack(2, 10, "mine")).is_empty())
	var ore := b.deliver(2, FieldCatalog.exclusive("mine"))
	check("exclusive orders pay their fixed sum", ore.done and ore.gold == 16000 and ore.prestige == 12)
	check("abandoning empties an open slot only", b.abandon(1) and b.slots[1] == null and not b.abandon(0))

	# Refill rules, over many seeds and last regions.
	var rng := RandomNumberGenerator.new()
	var one_exclusive := true
	var points_away := true
	var no_repeats := true
	var keeps_open := true
	for seed in range(300):
		rng.seed = seed
		var region: String = ["mine", "city", "snow"][seed % 3]
		var board := board_with(["eng_raw_ore", null, null] if seed % 2 == 0 else ["med_city_armor", null, null])
		board.slots[1] = {"id": "log_trinkets", "state": "done", "delivered": []}
		var kept: String = board.slots[0].id
		board.refill(rng, region)
		var ids: Array = board.slots.filter(func(o): return o != null).map(func(o): return o.id)
		one_exclusive = one_exclusive and ids.filter(func(id): return BaseCatalog.is_exclusive_order(id)).size() <= 1
		points_away = points_away and ids.any(func(id): return not str(BaseCatalog.ORDERS[id].get("region", "")).is_empty() and BaseCatalog.ORDERS[id].region != region)
		var unique := {}
		for id in ids: unique[id] = true
		no_repeats = no_repeats and unique.size() == ids.size()
		keeps_open = keeps_open and board.slots[0].id == kept and ids.size() == 3
	check("refills: at most one exclusive order on the board (300 seeds)", one_exclusive)
	check("refills: something always points away from the last region", points_away)
	check("refills: no template twice", no_repeats)
	check("refills: open orders stay, done and empty slots are filled", keeps_open)
	var saved := board_with(["med_frozen_relic", null])
	saved.deliver(0, FieldCatalog.exclusive("snow"))
	var copy := OrderBoard.new()
	copy.load_data(JSON.parse_string(JSON.stringify(saved.to_data())))
	check("board save round trip keeps slots, state and deliveries", copy.slots[0].state == "done" and copy.slots[0].delivered.size() == 1 and copy.slots[1] == null)

	check("prestige ranks: 0 R0, 20 R1, 60 R2, 200 R4", BaseCatalog.rank_of(0) == 0 and BaseCatalog.rank_of(20) == 1 and BaseCatalog.rank_of(60) == 2 and BaseCatalog.rank_of(250) == 4)

func through_game() -> void:
	var game := GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	await step(8)
	check("the outbound station is exported", not game.base_map.station("outbound").is_empty())
	game.base.orders = board_with(["starter", "log_fine_weapon"])
	var shelf_mat := stack(2, 10)
	var pack_mat := stack(2, 15)
	var staged_mat := item("暂存材料", Item.Category.MATERIAL, 50)
	var crate_mat := item("箱中材料", Item.Category.MATERIAL, 50)
	var worn := item("装备着的精良刀", Item.Category.WEAPON, 40, "", 1)
	game.base.shelf.append(shelf_mat)
	game.inventory.try_add(pack_mat)
	game.base.staging.append(staged_mat)
	game.base.receive(crate_mat)
	game.base.open_crate(crate_mat)
	game.player.equip(worn)
	var deliverable := game.deliverable_items()
	check("deliverable: shelf and pack, not staging, crates or equipped", deliverable.has(shelf_mat) and deliverable.has(pack_mat)
		and not deliverable.has(staged_mat) and not deliverable.has(crate_mat) and not deliverable.has(worn))
	check("staged, crated and equipped items are refused by orders and plain delivery",
		not game.deliver_to_order(0, staged_mat) and not game.deliver_to_order(0, crate_mat) and not game.deliver_to_order(1, worn)
		and not game.sell(staged_mat) and not game.sell(worn))
	game.base.pick_up(crate_mat)
	check("an item in her hands cannot be delivered", not game.deliver_to_order(0, crate_mat) and not game.sell(crate_mat))
	game.base.return_hand()
	await step(2)
	check("board shows an order she can fill", game.warehouse_view.board_state() == "open" and game.warehouse_view._board.texture == game.warehouse_view.tex.board_open)
	var gold := game.gold
	check("deliver from the shelf", game.deliver_to_order(0, shelf_mat) and game.base.location_of(shelf_mat) == "" and game.gold == gold)
	check("deliver from the pack completes: (20 + 30) ×100 x 1.3 = 6500 龙门币, 5 prestige",
		game.deliver_to_order(0, pack_mat) and not game.inventory.items.has(pack_mat) and game.gold == gold + 6500 and game.base.prestige == 5)
	await step(2)
	check("with nothing fillable left, a done order shows the completed board", game.warehouse_view.board_state() == "completed")
	var sold := item("卖掉的饰品", Item.Category.TRINKET, 25)
	game.inventory.try_add(sold)
	gold = game.gold
	check("plain delivery from the pack pays its value", game.sell(sold) and game.gold == gold + 2500 and not game.inventory.items.has(sold))

	# Settlement: extraction prestige and refills.
	game.player.unequip(Item.Category.WEAPON)
	await game.start_contract("mine")
	game.settle(true)
	await step(2)
	check("extraction adds prestige", game.base.prestige == 5 + BaseCatalog.PRESTIGE_EXTRACTION)
	check("settlement refills the completed slot, the open one stays", game.base.orders.slots[0] != null and game.base.orders.slots[0].state == "open"
		and game.base.orders.slots[0].id != "starter" and game.base.orders.slots[1].id == "log_fine_weapon")
	game.base.add_prestige(60)
	check("reaching R2 opens a third order slot", game.base.rank() == 2 and game.base.orders.slots.size() == 3)
	game.base.orders = board_with(["eng_raw_ore", "med_city_armor", null])
	game.base.orders.resize(3)
	check("contract cards count the orders pointing at each region",
		game.base.orders.pointing_at("mine") == 1 and game.base.orders.pointing_at("city") == 1 and game.base.orders.pointing_at("snow") == 0)
	game.open_station("contracts")
	check("the mine contract card says an order points there", _has_text(game.menu, "订单 1"))
	game.close_modal()
	game.open_station("outbound")
	check("the outbound menu lists the orders and plain delivery", _contains_text(game.menu, "直接交付") and _contains_text(game.menu, "未封装源石原矿"))
	game.close_modal()
	game.base.orders = board_with([null, null])
	await step(2)
	check("an empty board shows the empty state", game.warehouse_view.board_state() == "empty")

	# Saves keep prestige and orders; saves from before orders start fresh.
	game.base.orders = board_with(["log_trinkets", null])
	game.save_path = "user://orders_TEST_ONLY.json"
	game.save_enabled = true
	game.save_base()
	var prestige := game.base.prestige
	game.base = BaseState.new()
	game.load_base()
	check("save keeps prestige and the board", game.base.prestige == prestige and game.base.orders.slots[0].id == "log_trinkets" and game.base.orders.slots.size() == 3)
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.save_path))
	parsed.base.erase("orders")
	parsed.base.erase("prestige")
	var file := FileAccess.open(game.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(parsed))
	file.close()
	game.load_base()
	check("a save from before orders starts with the starter order", game.base.prestige == 0 and game.base.orders.slots[0].id == "starter")
	game.save_enabled = false
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(game.save_path + suffix): DirAccess.remove_absolute(game.save_path + suffix)

func _has_text(node: Node, text: String) -> bool:
	if node is Label and node.text == text: return true
	for child in node.get_children():
		if _has_text(child, text): return true
	return false

func _contains_text(node: Node, text: String) -> bool:
	if (node is Label or node is Button) and text in node.text: return true
	for child in node.get_children():
		if _contains_text(child, text): return true
	return false
