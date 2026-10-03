extends SceneTree

## B2 of 基地玩法策划案_v1_0.md: receiving crates in the warehouse, opening
## them, carrying an item to its zone, staging, and what she is standing at
## (§3.3–3.6). Uses the real base map and walks with real navigation.

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
func centre(rect: Array) -> Array: return [(rect[0] + rect[2]) * 0.5, (rect[1] + rect[3]) * 0.5]
func walk_to(p: Array) -> bool:
	var goal := game.base_map.to_world(p[0], p[1], BaseMap.PLAYER_Y)
	game.player.set_move_target(goal)
	var frames := 0
	while frames < 1800 and Vector2(game.player.global_position.x - goal.x, game.player.global_position.z - goal.z).length() > 0.6:
		await physics_frame
		frames += 1
	game.player.clear_move_target()
	return frames < 1800

func run() -> void:
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	await step(8)
	view = game.warehouse_view
	var a: Dictionary = view.anchors
	check("warehouse view has its anchors and textures", view.ready() and a.bays.size() == 6 and a.overflow.size() == 6 and view.tex.size() == 22 and view.tex.has("cargo_drone")
		and ["board_empty", "board_open", "board_completed"].all(func(k): return view.tex.has(k)))
	check("no demo crates are drawn on an empty base", view._crates.is_empty())

	# Crates appear on the bays, then along the wall, sized by the item.
	var sword := item("长剑", Item.Category.WEAPON, 2, 1)
	var plate := item("重甲", Item.Category.ARMOR, 2, 2)
	var ring := item("指环", Item.Category.TRINKET)
	var finds: Array[Item] = [sword, plate, ring]
	for i in range(5): finds.append(item("矿料%d" % i, Item.Category.MATERIAL))
	for x in finds: game.base.receive(x)
	await step(2)
	check("eight crates: six on the bays, two along the wall", view._crates.size() == 8
		and is_equal_approx(view._crates[0].position.z, a.bays[0][1]) and is_equal_approx(view._crates[6].position.z, a.overflow[0][1]))
	check("crate look follows size and state", view._crates[0].texture == view.tex.crate_medium_sealed
		and view._crates[1].texture == view.tex.crate_large_sealed and view._crates[2].texture == view.tex.crate_small_sealed)

	# Open a crate where it stands.
	await stand([a.bays[0][0], a.bays[0][1] + 1.0])
	var spot := game.nearby_station()
	check("standing at a crate offers to open it: " + str(spot.get("label", "")), spot.get("kind", "") == "crate" and spot.item == sword and "中箱" in spot.label)
	game._base_interact()
	await step(1)
	check("E opens it and shows the item card", game.base.location_of(sword) == "crate_open" and game.modal == "station" and game.menu.visible)
	await step(1)
	check("the open crate is drawn open", view._crates[0].texture == view.tex.crate_medium_open)
	game.close_modal()
	check("the opened crate now offers to look again", game.nearby_station().get("label", "").begins_with("查看"))

	# Carry it: icon over her head, its zone lights up, the others do not.
	check("pick up", game.pick_up_item(sword) and game.base.hand == sword and game.base.location_of(sword) == "hand")
	await step(2)
	check("a crate disappears once its item is out", view._crates.size() == 7)
	check("the carried icon shows over her", view._hand_icon.visible and view._hand_icon.texture != null)
	check("only the weapon zone is highlighted", view._zone_lights[0].all(func(d): return d.visible)
		and [1, 2, 3].all(func(c): return view._zone_lights[c].all(func(d): return not d.visible)))
	check("one thing at a time", not game.pick_up_item(game.base.crates[0].item) or game.base.hand == sword)

	# The wrong zone refuses and keeps it in her hands; the right one shelves it.
	await stand(centre(a.zones.armor))
	spot = game.nearby_station()
	check("in the armor zone with a sword: " + str(spot.get("label", "")), spot.get("kind", "") == "zone" and spot.category == Item.Category.ARMOR and "类别不对" in spot.label)
	game._base_interact()
	check("wrong zone refuses, says where it goes, keeps it in hand", game.base.hand == sword and "武器区" in game.message)
	check("the walk to the weapon zone works with real navigation", await walk_to(centre(a.zones.weapon)))
	spot = game.nearby_station()
	check("in the weapon zone: " + str(spot.get("label", "")), spot.get("kind", "") == "zone" and "上架到武器区（0/12）" == spot.label)
	game._base_interact()
	await step(2)
	check("shelved: off her hands, on the shelf", game.base.hand == null and game.base.location_of(sword) == "shelf" and game.stash.has(sword))
	check("the rack face shows one filled cell", view._cell_layers[0][0].texture == view._cell_textures[1])
	check("icon and highlight are gone", not view._hand_icon.visible and view._zone_lights[0].all(func(d): return not d.visible))

	# Full zone: refused with the count, item stays in hand.
	for i in range(11): game.base.shelf.append(item("库存武器%d" % i, Item.Category.WEAPON))
	var spare := item("第13把", Item.Category.WEAPON)
	game.base.receive(spare)
	game.base.open_crate(spare)
	game.pick_up_item(spare)
	await step(2)
	check("a full rack shows all twelve cells", view._cell_layers[0][0].texture == view._cell_textures[12])
	check("a full zone refuses with its count", not game.shelve_carried(Item.Category.WEAPON) and "12/12" in game.message and game.base.hand == spare)

	# Staging: drop it there, pallets load up, take it back out.
	await stand(centre(a.staging))
	spot = game.nearby_station()
	check("carrying into staging offers to put it down: " + str(spot.get("label", "")), spot.get("kind", "") == "staging" and "放进暂存区" in spot.label)
	game._base_interact()
	await step(2)
	check("staged", game.base.location_of(spare) == "staging" and game.base.hand == null)
	check("one pallet loaded for one item", view._pallet_loads.filter(func(s): return s.visible).size() == 1)
	for i in range(40): game.base.staging.append(item("堆%d" % i, Item.Category.MATERIAL))
	await step(2)
	check("pallets load in four steps (41 items -> 3)", view._pallet_loads.filter(func(s): return s.visible).size() == 3)
	for i in range(40): game.base.staging.pop_back()
	game._base_interact()
	check("E at staging with empty hands lists it", game.modal == "station" and game.menu.visible)
	game.close_modal()
	check("taking it out at staging", game.pick_up_item(spare) and game.base.hand_from == "staging")
	await stand([a.bays[1][0], a.bays[1][1] + 1.0])
	spot = game.nearby_station()
	check("at receiving while carrying offers to put it back", spot.get("kind", "") == "putback")
	game._base_interact()
	check("putting it back returns it to staging, where it came from", game.base.location_of(spare) == "staging")

	# Leaving or saving never takes the carried item away.
	game.pick_up_item(spare)
	game.save_path = "user://warehouse_TEST_ONLY.json"
	game.save_enabled = true
	game.save_base()
	var everyone := game.base.all_items().size()
	game.base = BaseState.new()
	game.load_base()
	check("a save made while carrying keeps it, back where it came from", game.base.hand == null and game.base.location_of(game.base.staging.back()) == "staging"
		and game.base.all_items().size() == everyone and game.base.staging.any(func(x): return x.uid == spare.uid))
	game.save_enabled = false
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(game.save_path + suffix): DirAccess.remove_absolute(game.save_path + suffix)
	var held: Item = game.base.crates[0].item
	game.base.open_crate(held)
	game.pick_up_item(held)
	await game.start_contract("mine")
	check("leaving with something in hand puts it back in a crate", game.base.hand == null and game.base.location_of(held) == "crate_open"
		and not game.carried_items().has(held))
	game.settle(true)
	await step(2)
	check("back at base the crates are drawn again", view._crates.size() == mini(game.base.crates.size(), 12))

	print("WAREHOUSE FAILURES: %d" % failures)
	quit(1 if failures else 0)
