extends SceneTree

## The equipment and inventory improvements of 装备与背包界面调研.md §5:
## comparison and 战力, rarity colours and badges, drag/drop and quick moves,
## sorting, affix tiers, value preview, pickup filter, expansions and the
## warehouse search / store-all. Drag and drop is driven through the same
## _can_drop_data / _drop_data calls Godot's GUI makes.

var game: GameManager
var failures := 0
var checks := 0

func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool, seen: Variant = null) -> void:
	checks += 1
	if not passed:
		failures += 1
		if seen != null: print("   seen: ", seen)
	print(("PASS " if passed else "FAIL ") + label)

func find_node(node: Node, script_class: String, predicate: Callable) -> Node:
	if node.get_class() != "" and node.get_script() != null and str(node.get_script().get_global_name()) == script_class and predicate.call(node): return node
	for child in node.get_children():
		var found := find_node(child, script_class, predicate)
		if found != null: return found
	return null

func panel() -> InventoryPanel:
	return game._inventory_panel

func grid_for(container: ItemContainer) -> Control:
	return _find(panel(), func(n): return n.has_method("_drop_data") and "container" in n and n.container == container)

func slot_for(category: int) -> Control:
	return _find(panel(), func(n): return n.has_method("_drop_data") and "category" in n and n.category == category)

func _find(node: Node, predicate: Callable) -> Node:
	if predicate.call(node): return node
	for child in node.get_children():
		var found := _find(child, predicate)
		if found != null: return found
	return null

func weapon(power: float, rarity: int = 1) -> Item:
	var item := Item.create("测试战刃", Item.Category.WEAPON, 2, 1, power)
	item.rarity = rarity
	return item

func run() -> void:
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	await step(4)
	await game.start_contract("city")
	game._clear_field()
	await step(2)

	# --- Affix tiers and saves.
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var tiers := {0: 0, 1: 0, 2: 0}
	var in_range := true
	for i in range(400):
		var item := FieldCatalog.roll_item("snow", 3, rng, 1.0)
		for mod in item.modifiers:
			if not mod.is_random_affix(): continue
			tiers[mod.tier] += 1
			in_range = in_range and is_equal_approx(mod.amount, float(FieldCatalog.AFFIX_AMOUNTS[mod.stat]) * ItemModifier.TIER_SCALES[mod.tier])
	check("affixes roll all three tiers at 70/100/130% of base", tiers[0] > 0 and tiers[1] > 0 and tiers[2] > 0 and in_range, tiers)
	var tiered := weapon(2.0)
	var atk := ItemModifier.stat_mod(ItemModifier.Stat.ATK_PCT, 0.104)
	atk.tier = 2
	tiered.modifiers = [atk]
	check("tier survives a save round trip", Item.from_data(tiered.to_data()).modifiers[0].tier == 2)
	var old := tiered.to_data()
	old.mods = [{"stat": ItemModifier.Stat.ATK_PCT, "amount": 0.056, "trigger": 0}]
	check("old saves infer the tier from the amount", Item.from_data(old).modifiers[0].tier == 0)
	check("Alt shows the tier and the range", "Ⅲ" in atk.describe_detailed(false) and "范围" in atk.describe_detailed(true) and not "范围" in atk.describe_detailed(false))

	# --- Rarity colours are one palette.
	check("rarity colours match the relic palette", Item.RARITY_COLORS[1] != Item.RARITY_COLORS[0] and Item.RARITY_COLORS[2] == RelicCatalog.RARITY_COLORS[2])

	# --- Side-effect-free preview (no 战力: 用户 2026-10-06).
	var p := game.player
	p.sword_charge = 2
	p.hp = 1000
	var atk_now := p.attack_power()
	var blade := weapon(3.0)
	blade.modifiers = [ItemModifier.trigger_mod(ItemModifier.Trigger.SWORD_WAVE)]
	var preview := p.preview_equip(blade)
	check("preview reports higher ATK for a better weapon, and no 战力", preview.after.atk > preview.before.atk and not preview.after.has("rating") and not p.has_method("power_rating"))
	check("preview leaves life, charge and the slot untouched", p.hp == 1000 and p.sword_charge == 2 and p.equipped.get(Item.Category.WEAPON) == null and is_equal_approx(p.attack_power(), atk_now))
	var tip := ItemTooltip.text(game, blade, false, false)
	check("tooltip shows per-stat differences and no 战力", not "战力" in tip and "▲" in tip and "攻击力" in tip and "触发" in tip)
	check("tooltip has no death forecast or key hints, and gives the 交付价 in 龙门币", not "死亡时" in tip and not "按住" in tip and "龙门币" in tip)
	check("stat panel previews the change in brackets", "(+" in ItemTooltip.stats_text(game, blade))

	# --- Death outcomes and the value preview.
	var covered := weapon(1.0)   # an insured find
	covered.insured = true
	covered.value = 100
	var insured := weapon(1.0)
	insured.insured = true
	insured.carried_in = true
	insured.value = 50
	var safe := Item.create("测试材料", Item.Category.MATERIAL, 1, 1)
	safe.value = 30
	var loose := weapon(1.0)
	loose.value = 20
	game.inventory.try_add(covered)
	game.inventory.try_add(insured)
	game.safe_bag.try_add(safe)
	game.inventory.try_add(loose)
	check("death outcome per protection", game.death_outcome(covered) == "送回（投保）" and game.death_outcome(safe) == "保留（安全袋）"
		and game.death_outcome(insured) == "送回（投保）" and game.death_outcome(loose) == "丢失")
	var value := game.value_summary()
	var flasks: int = game.carried_potions().reduce(func(n, x): return n + x.value, 0)
	check("value preview adds up what is kept, insured and lost", value.kept == 30 and value.insured == 150 and value.lost == 20 + flasks and value.carried == 200 + flasks, value)

	# --- The panel: badges, drag and drop, quick moves.
	game.open_modal("inventory")
	panel().open()
	await step(2)
	# The value-at-stake line was explanatory content the user ruled out (2026-10-05).
	# Explanatory content and key hints were ruled out (用户 2026-10-05/06).
	check("panel has no value-at-stake or shortcut line", _find(panel(), func(n): return n is Label and ("若此刻阵亡" in n.text or "Ctrl+左键" in n.text)) == null)
	var pack_grid := grid_for(game.inventory)
	var safe_grid := grid_for(game.safe_bag)
	check("pack and safe bag grids accept drops", pack_grid != null and safe_grid != null)
	var free := Vector2i(-1, -1)
	for y in range(game.inventory.height):
		for x in range(game.inventory.width):
			if free.x < 0 and game.inventory.can_place(loose, x, y) and (x != loose.grid_x or y != loose.grid_y): free = Vector2i(x, y)
	var data := {"item": loose, "from": game.inventory, "grab": Vector2.ZERO}
	var at := Vector2(free.x * InventoryPanel.CELL + 4, free.y * InventoryPanel.CELL + 4)
	check("an empty spot previews green", pack_grid._can_drop_data(at, data))
	pack_grid._drop_data(at, data)
	await step()
	check("dropping moves the item to that cell", loose.grid_x == free.x and loose.grid_y == free.y and game.inventory.items.has(loose))
	pack_grid = grid_for(game.inventory)
	var onto := Vector2(covered.grid_x * InventoryPanel.CELL + 4, covered.grid_y * InventoryPanel.CELL + 4)
	check("an occupied spot previews red and refuses", not pack_grid._can_drop_data(onto, data))
	safe_grid = grid_for(game.safe_bag)
	var small := Item.create("小饰品", Item.Category.TRINKET, 1, 1, 1.0)
	game.inventory.try_add(small)
	panel()._rebuild()
	await step()
	safe_grid = grid_for(game.safe_bag)
	var safe_data := {"item": small, "from": game.inventory, "grab": Vector2.ZERO}
	var safe_cell := Vector2(1 * InventoryPanel.CELL + 4, 0 * InventoryPanel.CELL + 4)
	check("pack → safe bag by drag", safe_grid._can_drop_data(safe_cell, safe_data))
	safe_grid._drop_data(safe_cell, safe_data)
	await step()
	check("the item now sits in the safe bag", game.safe_bag.items.has(small) and not game.inventory.items.has(small))
	panel().ctrl_click(small, game.safe_bag)
	await step()
	check("Ctrl+click moves it back to the pack", game.inventory.items.has(small) and not game.safe_bag.items.has(small))
	var slot := slot_for(Item.Category.WEAPON)
	var to_slot := {"item": blade, "from": game.inventory, "grab": Vector2.ZERO}
	game.inventory.try_add(blade)
	check("a weapon slot accepts a weapon, not a trinket", slot._can_drop_data(Vector2.ZERO, to_slot) and not slot._can_drop_data(Vector2.ZERO, {"item": small, "from": game.inventory}))
	slot._drop_data(Vector2.ZERO, to_slot)
	await step()
	check("dropping on the slot equips it", p.equipped.get(Item.Category.WEAPON) == blade and not game.inventory.items.has(blade))
	pack_grid = grid_for(game.inventory)
	var spot := Vector2i(-1, -1)
	for y in range(game.inventory.height):
		for x in range(game.inventory.width):
			if spot.x < 0 and game.inventory.can_place(blade, x, y): spot = Vector2i(x, y)
	pack_grid._drop_data(Vector2(spot.x * InventoryPanel.CELL + 4, spot.y * InventoryPanel.CELL + 4), {"item": blade, "from": null, "grab": Vector2.ZERO})
	await step()
	check("dragging the worn item to the pack unequips it there", p.equipped.get(Item.Category.WEAPON) == null and blade.grid_x == spot.x and blade.grid_y == spot.y)
	panel().right_click(blade, game.inventory)
	await step()
	check("right click equips", p.equipped.get(Item.Category.WEAPON) == blade)
	panel().right_click(blade, null)
	await step()
	check("right click on the worn item unequips", p.equipped.get(Item.Category.WEAPON) == null and game.inventory.items.has(blade))
	panel().ask_drop(loose, game.inventory)
	check("dropping asks first", panel()._confirm.visible and game.inventory.items.has(loose))
	panel()._confirm.confirmed.emit()
	panel()._confirm.hide()
	await step()
	check("confirming drops it on the ground", not game.inventory.items.has(loose) and get_nodes_in_group("loot").any(func(n): return n.item == loose))
	panel()._drag_item = small
	panel()._drag_from = game.inventory
	panel()._last_pointer = panel().panel.get_global_rect().get_center()
	panel()._notification(Control.NOTIFICATION_DRAG_END)
	check("a refused drop inside the panel is just cancelled", not panel()._confirm.visible and game.inventory.items.has(small))
	panel()._drag_item = small
	panel()._drag_from = game.inventory
	panel()._last_pointer = Vector2(-50, -50)
	panel()._notification(Control.NOTIFICATION_DRAG_END)
	check("a drag released outside the panel asks to drop", panel()._confirm.visible)
	panel().hide()
	await step()
	check("closing the inventory closes the drop dialog", not panel()._confirm.visible)
	panel().show()
	panel()._rebuild()
	await step()
	var tile := _find(panel(), func(n): return "item" in n and "container" in n and n.get("item") == insured and n is Button)
	check("an insured tile has the teal insurance border", tile != null and (tile.get_theme_stylebox("normal") as StyleBoxFlat).border_color == InventoryPanel.INSURED)

	# --- Sorting.
	game.inventory.items.clear()
	var pieces: Array[Item] = [Item.create("材料甲", Item.Category.MATERIAL, 1, 1), weapon(1.0, 0), weapon(1.0, 2), Item.create("甲胄", Item.Category.ARMOR, 2, 2, 1.0)]
	for i in range(pieces.size()):
		game.inventory.place(pieces[i], 9 - i * 2 if i < 3 else 0, 5 if i < 3 else 0)
	check("sort repacks by category then rarity", game.sort_pack() and pieces[2].grid_x == 0 and pieces[2].grid_y == 0 and game.inventory.items.size() == 4)
	var weapon_rank := [pieces[2], pieces[1]]
	check("the rare weapon comes before the common one", weapon_rank[0].grid_y < weapon_rank[1].grid_y or (weapon_rank[0].grid_y == weapon_rank[1].grid_y and weapon_rank[0].grid_x < weapon_rank[1].grid_x))
	game.safe_bag.items.clear()
	game.close_modal()

	# --- Pickup filter.
	for node in get_nodes_in_group("loot"): node.queue_free()
	await step()
	game.pickup_filter = 1
	var common := weapon(1.0, 0)
	var rare := weapon(1.0, 2)
	var ore := FieldCatalog.exclusive("mine")
	check("filter 精良以上 skips common gear but keeps rare gear and exclusives", not game.passes_pickup_filter(common) and game.passes_pickup_filter(rare) and game.passes_pickup_filter(ore))
	var drop := Loot.new()
	drop.game = game
	drop.item = common
	game.add_child(drop)
	drop.global_position = p.global_position
	await step(3)
	check("a filtered drop is not auto-picked", is_instance_valid(drop) and not game.inventory.items.has(common))
	game._interact()
	await step()
	check("E picks up a filtered drop", game.inventory.items.has(common))
	game.cycle_pickup_filter()
	game.cycle_pickup_filter()
	check("the filter cycles back to 全部", game.pickup_filter == 0)

	# --- Expansions and the warehouse.
	game.settle(true)
	await step(2)
	check("starts at 10×6 and 2×2", game.inventory.width == 10 and game.inventory.height == 6 and game.safe_bag.width == 2 and game.safe_bag.height == 2)
	game.gold = 100000
	check("pack expansion needs R1", not game.buy_pack_upgrade())
	game.base.prestige = 60
	check("expansions also need base materials", not game.buy_pack_upgrade() and "缺少" in game.upgrade_refusal("pack"))
	var needed := {}
	for cost in [BaseCatalog.PACK_MATERIALS[1], BaseCatalog.PACK_MATERIALS[2], BaseCatalog.SAFE_MATERIALS[1]]:
		for id in cost: needed[id] = int(needed.get(id, 0)) + int(cost[id])
	for id in needed:
		var left := int(needed[id])
		while left > 0:
			var m := MaterialCatalog.create(id, left)
			game.base.shelf.append(m)
			left -= m.quantity
	check("at R2 the pack grows to 10×8 then 12×8", game.buy_pack_upgrade() and game.inventory.height == 8 and game.buy_pack_upgrade() and game.inventory.width == 12)
	check("then it is fully expanded", not game.buy_pack_upgrade() and game.gold == 100000 - 12000 - 26000)
	check("safe bag grows to 3×2 at R2, 3×3 needs R3", game.buy_safe_upgrade() and game.safe_bag.width == 3 and not game.buy_safe_upgrade())
	check("and every material was used", needed.keys().all(func(id): return game.material_count(id) == 0))
	var data_out := game.base.to_data()
	var reloaded := BaseState.new()
	reloaded.load_data(data_out, {})
	check("expansion levels are saved", reloaded.pack_level == 2 and reloaded.safe_level == 1)
	var mats: Array[Item] = []
	for i in range(3):
		mats.append(Item.create("封装矿料", Item.Category.MATERIAL, 1, 1))
		game.inventory.try_add(mats[-1])
	check("store-all sends every carried material to the warehouse", game.store_all_materials() == 3 and mats.all(func(x): return game.stash.has(x) or game.base.staging.has(x)))
	game.open_station("stash")
	await step()
	game.menu.stash_query = "不存在的名字"
	game.menu._refresh()
	await step()
	check("a search with no match hides the stash rows", not _find(game.menu, func(n): return n is Button and n.has_meta("item") and game.stash.has(n.get_meta("item"))))
	game.menu.stash_query = "封装"
	game.menu._refresh()
	await step()
	check("a matching search shows them", _find(game.menu, func(n): return n is Button and n.has_meta("item") and game.stash.has(n.get_meta("item"))) != null)
	game.menu.stash_query = ""
	game.close_modal()
	print("INVENTORY RESULT: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
