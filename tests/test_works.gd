extends SceneTree

## 基建设施修订案_v1_1.md (用户 2026-10-22): the 基建总控台 is built first;
## each facility is upgraded at its own site until it is connected, then from
## the hub too; the exchange's building waits for 喀兰贸易 R2; the 基建 quick
## button appears once the hub stands; each part shows as a construction site
## until it is built.

var failures := 0
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool, detail: Variant = null) -> void:
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label + ("" if detail == null else "  " + str(detail)))

func give(game: GameManager, cost: Dictionary) -> void:
	for id in cost:
		var left := int(cost[id])
		while left > 0:
			var m := MaterialCatalog.create(id, left)
			game.base.shelf.append(m)
			left -= m.quantity

func find_meta(node: Node, key: String, value: Variant) -> Button:
	for child in node.get_children():
		if child is Button and child.has_meta(key) and child.get_meta(key) == value: return child
		var found := find_meta(child, key, value)
		if found != null: return found
	return null

func run() -> void:
	var game := GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	await step(8)
	var base := game.base
	game.gold = 1000000
	var works := game.works

	# A new base: nothing connected, the hub, the lab and the exchange unbuilt.
	check("a new base: hub, lab and exchange at Lv0, nothing connected", base.facility_level("hub") == 0 and base.facility_level("lab") == 0
		and base.facility_level("exchange") == 0 and base.connected.is_empty())
	check("every facility has its site terminal", BaseCatalog.FACILITY_ORDER.all(func(id): return not game.base_map.station("site_" + id).is_empty()))
	var hub_part := 0
	check("the hub's console stands behind a construction site", not works.built(hub_part) and (works._drawn[hub_part].pieces as Array).size() > 4
		and (works._drawn[hub_part].pieces as Array).any(func(p): return p.get_meta("model") == "build_barrier"))
	check("the 基建 quick button is hidden before the hub", not _quick_button(game).visible)
	check("the exchange is closed", not game.exchange.unlocked())

	# On site before the hub: a facility's upgrade, but no link yet.
	check("a link needs the hub first", game.connect_refusal("warehouse") == "需要基建总控台")
	check("from the hub an unconnected facility refuses", game.facility_refusal("warehouse", true) == "未接入")
	give(game, BaseCatalog.facility_step("warehouse", 2).materials)
	game.open_build_site("warehouse")
	var up := find_meta(game.menu, "facility", "warehouse")
	check("the warehouse's site offers its upgrade", up != null and not up.disabled)
	if up: up.pressed.emit()
	check("upgraded on site", base.facility_level("warehouse") == 2)
	game.close_modal()

	# The hub.
	give(game, BaseCatalog.facility_step("hub", 1).materials)
	game.player.teleport(game.base_map.station("site_hub").position)
	await step(2)
	game._base_interact()
	check("E at the hub's site opens its build page", game.modal == "station" and game.menu._station == "build_site")
	up = find_meta(game.menu, "facility", "hub")
	if up: up.pressed.emit()
	game.close_modal()
	await step(2)
	check("the hub is built", base.hub_built())
	check("its console replaces the site", works.built(hub_part) and (works._drawn[hub_part].pieces as Array).size() == 1)
	check("the quick button appears", _quick_button(game).visible)
	game._base_interact()
	check("E at the hub now opens the console", game.modal == "station" and game.menu._station == "construction")
	game.close_modal()

	# Linking, then remote upgrades.
	check("now a link can be bought", game.connect_refusal("outfit").begins_with("缺少"))
	give(game, BaseCatalog.connect_materials("outfit"))
	var gold := game.gold
	check("linking costs %s and its materials" % int(BaseCatalog.CONNECT_COST.price), game.connect_facility("outfit") and gold - game.gold == int(BaseCatalog.CONNECT_COST.price) and base.is_connected_to_hub("outfit"))
	await step(2)
	var trunk: int = range(BaseWorks.PARTS.size()).filter(func(i): return BaseWorks.PARTS[i][1] == "cable_trunk" and BaseWorks.PARTS[i][5] == "link:outfit")[0]
	check("its trunk to the hub lights up", works.built(trunk) and (works._drawn[trunk].pieces as Array).size() == 1)
	give(game, BaseCatalog.facility_step("outfit", 2).materials)
	check("a connected facility upgrades from the hub", game.facility_refusal("outfit", true).is_empty() and game.upgrade_facility("outfit", true))
	check("an unconnected one still refuses there", not game.upgrade_facility("store", true))
	game.menu.build_pick = "outfit"
	game.open_station("construction")
	check("the console lists every facility", BaseCatalog.FACILITY_ORDER.all(func(id): return find_meta(game.menu, "facility_row", id) != null))
	game.close_modal()

	# The exchange waits for 喀兰贸易 R2.
	game.exchange.relations["karlan"] = 499
	check("below 喀兰贸易 R2 the exchange cannot be built or linked", game.facility_refusal("exchange") == "需要喀兰贸易关系 R2"
		and game.connect_refusal("exchange") == "需要喀兰贸易关系 R2")
	game.open_build_site("exchange")
	check("its page shows the relation only", find_meta(game.menu, "facility", "exchange") == null)
	game.close_modal()
	game.exchange.relations["karlan"] = 500
	give(game, BaseCatalog.facility_step("exchange", 1).materials)
	check("at R2 it is built on site", game.facility_refusal("exchange").is_empty() and game.upgrade_facility("exchange"))
	check("and opens for trading", game.exchange.unlocked())
	check("its loan limit is %d at Lv1" % Exchange.LOAN_STEP, game.exchange.loan_limit() == Exchange.LOAN_STEP or base.researched("loan_terms"))

	# Saves.
	var copy := BaseState.new()
	copy.load_data(JSON.parse_string(JSON.stringify(base.to_data())), {})
	check("a save keeps the hub, the links and the levels", copy.hub_built() and copy.is_connected_to_hub("outfit") and not copy.is_connected_to_hub("store")
		and copy.facility_level("exchange") == 1)
	var old := base.to_data()
	var levels: Dictionary = old.facilities
	levels.erase("hub")
	old.erase("connected")
	copy.load_data(JSON.parse_string(JSON.stringify(old)), {})
	check("a v1.0 save: hub built, all connected, exchange open", copy.hub_built() and BaseCatalog.connectable().all(func(id): return copy.is_connected_to_hub(id))
		and copy.facility_level("exchange") >= 1)

	game.queue_free()
	await step(2)
	print("WORKS FAILURES: %d" % failures)
	quit(1 if failures else 0)

func _quick_button(game: GameManager) -> Button:
	for hud in game.find_children("*", "BaseHud", true, false):
		for b in (hud as BaseHud)._buttons.get_children():
			if b.get_meta("kind", "") == "construction": return b
	return Button.new()
