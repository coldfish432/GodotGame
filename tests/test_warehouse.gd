extends SceneTree

## B2 of 基地玩法策划案_v1_0.md as changed by 仓库修订 (用户 2026-10-23): the
## warehouse room is for show (rack faces, the order board), nothing in it takes
## the E key; the warehouse is one count of cells set by 仓储部's level, with a
## per-cell stack multiplier; the 仓管台 and settlement's 仓库 page put things away.
## Uses the real base map.

var game: GameManager
var view: WarehouseView
var failures := 0
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool) -> void:
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label)
func item(name: String, category: Item.Category, w: int = 1, h: int = 1) -> Item:
	return Item.create(name, category, w, h, 1.0)
func stand(p: Array) -> void:
	game.player.teleport(game.base_map.to_world(p[0], p[1], BaseMap.PLAYER_Y))
	await step(2)
## A button whose meta "label" (AK buttons) is `label`, anywhere under `node`.
func find_label(node: Node, label: String) -> Button:
	if node is Button and str(node.get_meta("label", node.text)) == label: return node
	for child in node.get_children():
		var found := find_label(child, label)
		if found: return found
	return null
## Whether some visible label or button under `node` contains `needle`.
func find_text(node: Node, needle: String) -> bool:
	if (node is Label or node is Button) and needle in str(node.text) and (node as CanvasItem).is_visible_in_tree(): return true
	for child in node.get_children():
		if find_text(child, needle): return true
	return false
func centre(rect: Array) -> Array: return [(rect[0] + rect[2]) * 0.5, (rect[1] + rect[3]) * 0.5]

func run() -> void:
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	await step(8)
	view = game.warehouse_view
	var a: Dictionary = view.anchors
	check("warehouse view has its anchors and the board", view.ready() and a.bays.size() == 6 and view._board != null)
	check("no crates are drawn on an empty base", view._crates.is_empty())

	# Arrivals go straight into the warehouse (仓库修订: no crates, no staging).
	var sword := item("长剑", Item.Category.WEAPON, 2, 1)
	var plate := item("重甲", Item.Category.ARMOR, 2, 2)
	var ring := item("指环", Item.Category.TRINKET)
	var finds: Array[Item] = [sword, plate, ring]
	for i in range(5): finds.append(item("矿料%d" % i, Item.Category.MATERIAL))
	for x in finds: game.base.receive(x)
	await step(2)
	check("eight arrivals: all in the warehouse, no crate drawn", finds.all(func(x): return game.base.location_of(x) == "shelf")
		and game.stash.size() == 8 and game.base.shelf_count() == 8 and view._crates.is_empty())
	check("the weapon rack face shows one filled cell", view._cell_layers[0][0].filter(func(c): return c.visible).size() == 1 and view._cell_layers[0][0][0].visible)
	check("the material rack face shows five", view._cell_layers[Item.Category.MATERIAL][0].filter(func(c): return c.visible).size() == 5)
	check("zone frames stay hidden", view._zone_lights[0].all(func(d): return not d.visible) and view._zone_frames[0].all(func(d): return not d.visible))

	# Nothing in the room answers E: not the bays, the zones or staging.
	for spot_at in [[a.bays[0][0], a.bays[0][1] + 1.0], centre(view.zone_rect(0)), centre(a.staging)]:
		await stand(spot_at)
		var spot := game.nearby_station()
		check("nothing to do at %s: %s" % [str(spot_at), str(spot.get("kind", ""))],
			view.target_at(game.player.global_position).is_empty() and not str(spot.get("kind", "")) in ["crate", "zone", "shelf_zone", "staging", "putback"])

	# Capacity: one count for every kind, set by 仓储部; the stack multiplier too.
	var expect := {1: [60, 1], 2: [120, 2], 3: [220, 3], 4: [360, 5]}
	for level in expect:
		game.base.set_facility("warehouse", level)
		check("仓储部 Lv%d: %d cells, stacks ×%d" % [level, expect[level][0], expect[level][1]],
			game.base.capacity() == expect[level][0] and game.base.stack_mult() == expect[level][1]
			and range(4).all(func(c): return game.base.capacity(c) == expect[level][0]))
		await step(1)
		check("仓储部 Lv%d draws its racks" % level, int(game.base.racks[0]) == clampi(level * 3 - 2, BaseCatalog.STARTING_RACKS, BaseCatalog.RACK_SLOTS))
	game.base.research.done.append(ResearchCatalog.id_of_key("rack_cells"))
	check("立体货架 adds 20%", game.base.capacity() == 432)
	game.base.research.done.erase(ResearchCatalog.id_of_key("rack_cells"))

	# A warehouse stack holds a bag stack × stack_mult(); bringing one out takes a bag-sized piece.
	game.base.set_facility("warehouse", 2)
	var bolts := MaterialCatalog.create("螺栓", 1)
	var per_bag := bolts.max_stack
	bolts.set_quantity(per_bag)
	var more := MaterialCatalog.create("螺栓", per_bag)
	game.inventory.try_add(bolts)
	game.inventory.try_add(more)
	check("storing two bag stacks of one material fills one cell at ×2", game.store_item(bolts) and game.store_item(more)
		and game.stash.filter(func(x): return x.material_id == "螺栓").size() == 1 and game.base.location_of(bolts) == "shelf" and bolts.quantity == per_bag * 2)
	check("bringing it takes one bag stack, the rest stays", game.bring_item(bolts) and bolts.quantity == per_bag and game.base.location_of(bolts) == "shelf"
		and game.inventory.items.any(func(x): return x.material_id == "螺栓" and x.quantity == per_bag))

	# Full warehouse: storing from the loadout refuses, base arrivals still come in.
	game.base.set_facility("warehouse", 1)
	while game.base.shelf_count() < game.base.capacity(): game.base.shelf.append(item("库存%d" % game.base.shelf_count(), Item.Category.TRINKET))
	var spare := item("第61件", Item.Category.WEAPON)
	game.inventory.try_add(spare)
	check("a full warehouse refuses to store and says how full", not game.store_item(spare) and "60/60" in game.message and game.inventory.items.has(spare))
	var parcel := item("送回的装备", Item.Category.ARMOR)
	check("arrivals still come in over the count", game.base.receive(parcel) and game.base.location_of(parcel) == "shelf" and game.base.shelf_count() == 61)

	# The 仓管台: the whole warehouse with one load bar; no console to buy.
	game.open_station("stash")
	await step(1)
	check("the 仓管台 shows the load and stack size", find_text(game.menu, "%d/%d  ·  ×%d" % [game.base.shelf_count(), game.base.capacity(), game.base.stack_mult()]))
	check("and the carry-in row", find_text(game.menu, "将带入"))
	game.close_modal()
	check("a new base has its console from the start", BaseState.new().console)
	var old := game.base.to_data()
	old.erase("console")
	var reloaded := BaseState.new()
	reloaded.load_data(old, {})
	check("a save from before keeps the 仓管台 working", reloaded.console)

	# A save from before 仓库修订: its crates and staging fold into the warehouse.
	var legacy := BaseState.new().to_data()
	var in_crate := item("箱中物", Item.Category.WEAPON)
	var staged := item("暂存物", Item.Category.ARMOR)
	var shelved := item("架上物", Item.Category.TRINKET)
	legacy.shelf = [shelved.to_data()]
	legacy.crates = [{"item": in_crate.to_data(), "opened": false}]
	legacy.staging = [staged.to_data()]
	var folded := BaseState.new()
	folded.load_data(JSON.parse_string(JSON.stringify(legacy)), {})
	var uids := folded.shelf.map(func(x): return x.uid)
	check("old crates and staging load into the warehouse", folded.shelf.size() == 3 and uids.has(in_crate.uid) and uids.has(staged.uid) and uids.has(shelved.uid))

	# Settlement's 仓库 page: what came home stays in the bags until put away.
	game.base.shelf.clear()
	for x in game.inventory.items.duplicate(): game.inventory.remove(x)
	await game.start_contract("mine")
	var found := item("带回的饰品", Item.Category.TRINKET)
	var found_safe := item("袋中材料", Item.Category.MATERIAL)
	var worn := item("现场换上的甲", Item.Category.ARMOR, 2, 2)
	game.inventory.try_add(found)
	game.safe_bag.try_add(found_safe)
	game.player.equip(worn)
	game.settle(true)
	await step(2)
	check("extracted finds stay in her bags, worn stays worn", game.inventory.items.has(found) and game.safe_bag.items.has(found_safe)
		and game.player.equipped.get(Item.Category.ARMOR) == worn and game.base.location_of(found) == "")
	check("the settlement screen is open on its first tab", game.modal == "settlement" and game.menu.settle_tab == 0)
	game.menu.settle_tab = 1
	game.menu.show_settlement()
	await step(1)
	var all := find_label(game.menu, "一键入库")
	check("the 仓库 tab offers 一键入库", all != null and not all.disabled)
	if all: all.pressed.emit()
	await step(1)
	check("一键入库 puts the pack and the safe bag away, worn stays on", game.base.location_of(found) == "shelf" and game.base.location_of(found_safe) == "shelf"
		and not game.carried_items().has(found) and game.player.equipped.get(Item.Category.ARMOR) == worn and game.base.location_of(worn) == "")
	game.close_modal()

	print("WAREHOUSE FAILURES: %d" % failures)
	quit(1 if failures else 0)
