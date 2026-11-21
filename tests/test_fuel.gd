extends SceneTree
## 燃料储备修订案 v0.6 (用户 2026-11-17): fuel as units; 燃料罐 holds 0–60 and stays
## when empty; 固体燃料 is 12 units, made at the 加工部; the 燃料储备 takes fuel in
## and never gives it back; the hub and voyages burn the reserve, then the
## warehouse's cans, then buy; the exchange trades fuel by the 480-unit barrel
## (bought into the reserve, sold out of the cans); 燃料包 is gone; a fire burns
## the units she picks, 10 s each.
var game: GameManager
var failures := 0
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool, detail: Variant = null) -> void:
	print(("PASS " if passed else "FAIL ") + label + ("" if passed or detail == null else "  " + str(detail)))
	if not passed: failures += 1

func can(units: int) -> Item:
	var t := MaterialCatalog.create(Fuel.TANK, 1)
	Fuel.set_fill(t, units)
	return t

func shelve(item: Item) -> Item:
	game.base.shelf.append(item)
	return item

func clear_fuel() -> void:
	for item in game.base.shelf.duplicate():
		if Fuel.is_fuel(item) or item.material_id == Fuel.OLD_PACK: game.base.take_from_shelf(item)
	for bag in [game.inventory, game.safe_bag]:
		for item in bag.items.duplicate():
			if Fuel.is_fuel(item): bag.remove(item)
	game.exchange.fin.stock.erase(Fuel.RESERVE)

func next_day() -> void:
	BaseState.clock_offset += MarketState.next_day_start(game.market.t) - game.market.t + 4
	game.market.advance_to(BaseState.now())

func run() -> void:
	# These checks are of the one-to-one clock (时间缩放策划案 v0.2: test_time_scale has the scaled one).
	BaseState.time_scale = 1
	MarketState.tz_override = 0
	BaseState.frozen_clock = 1791972000
	BaseState.stall = 0
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	game.fixed_market_seed = 77
	root.add_child(game)
	await step(8)
	game.seed_rng(77)
	var ex := game.exchange
	var fin := ex.fin
	for f in ["exchange", "workshop", "warehouse", "hub"]: game.base.set_facility(f, 1)
	game.gold = 5000000
	clear_fuel()

	# --- The can and the block ---
	var full := MaterialCatalog.create(Fuel.TANK, 1)
	check("a can off the shelf is full: 60/60", full.fuel == 60 and full.stack_suffix() == " 60/60")
	check("one value a unit: full can 50, empty 10, 固体燃料 8", full.value == 50 and can(0).value == 10 and MaterialCatalog.create(Fuel.SOLID, 1).value == 8)
	check("one time a unit: 固体燃料 120 s is 12 units of 10 s", is_equal_approx(FeatureCatalog.FUELS[Fuel.SOLID], Fuel.SOLID_UNITS * Fuel.SECONDS_PER_UNIT))
	var old := full.to_data()
	old.erase("fuel")
	check("a can saved before units loads full", Item.from_data(old).fuel == 60)
	check("a can keeps its fill through a save", Item.from_data(can(23).to_data()).fuel == 23 and Item.from_data(can(23).to_data()).value == Fuel.tank_value(23))

	# --- Pouring ---
	var half := can(30)
	var solid := MaterialCatalog.create(Fuel.SOLID, 5)
	check("固体燃料 goes in whole blocks: 2 of 5 into a can at 30", Fuel.pour(solid, half) == 24 and half.fuel == 54 and solid.quantity == 3)
	check("no room for a block: nothing", Fuel.pour(solid, half) == 0 and solid.quantity == 3)
	var other := can(40)
	check("can into can: what fits, the rest stays", Fuel.pour(other, half) == 6 and half.fuel == 60 and other.fuel == 34)
	game.inventory.items.clear()
	var a := can(10)
	var b := MaterialCatalog.create(Fuel.SOLID, 2)
	game.inventory.try_add(a)
	game.inventory.try_add(b)
	check("right click pours into the pack's first can; an emptied stack leaves", game.pour_into_first_tank(b, game.inventory) == 24 and a.fuel == 34 and not game.inventory.items.has(b))
	game.inventory.items.clear()

	# --- Full cans only count for costs ---
	clear_fuel()
	shelve(can(59))
	check("a can short of full is no 燃料罐 for a cost", game.material_count(Fuel.TANK) == 0 and not game.materials_refusal({Fuel.TANK: 1}).is_empty())
	var whole := shelve(can(60))
	check("a full one is", game.material_count(Fuel.TANK) == 1 and game.consume_materials({Fuel.TANK: 1}) and not game.base.shelf.has(whole) and fin.warehouse_tanks().size() == 1)

	# --- The 燃料储备 ---
	clear_fuel()
	var c := shelve(can(45))
	var s := shelve(MaterialCatalog.create(Fuel.SOLID, 3))
	check("a can pours in, and stays empty", fin.pour_in(c) == 45 and c.fuel == 0 and game.base.shelf.has(c) and fin.fuel_reserve() == 45)
	check("an empty can cannot", fin.pour_refusal(c) == "空罐")
	check("固体燃料 pours in whole and is gone", fin.pour_in(s) == 36 and not game.base.shelf.has(s) and fin.fuel_reserve() == 81)
	check("the reserve counts in the 罗德岛库存's worth", is_equal_approx(fin.stock_value(), 81 * Fuel.unit_lmd()))
	var legacy := RhodesFinance.new(ex)
	legacy.load_data({"stock": {"燃料罐": 3, "固体燃料": 2, "异铁": 4}})
	check("an old stock's cans and blocks are reserve units now", legacy.fuel_reserve() == 3 * 60 + 2 * 12 and legacy.stock_count("异铁") == 4 and legacy.stock_count(Fuel.TANK) == 0)

	# --- The hub's day ---
	clear_fuel()
	var need := fin.need_units("hub")
	check("the hub burns fuel units", need > 0 and RhodesFinance.material_for("hub", 0) == Fuel.RESERVE, need)
	fin.add_fuel(need / 2)
	var low := shelve(can(5))
	var high := shelve(can(60))
	next_day()
	var bill: Dictionary = fin.bills[-1]
	var hub: Dictionary = bill.items.filter(func(it): return it.facility == "hub")[0]
	var from: Dictionary = hub.from_stock
	var spent := int(from.get("燃料储备", 0)) + int(from.get(Fuel.TANK, 0)) + int(hub.bought)
	check("the reserve first, then the warehouse's cans, the emptiest first", int(from.get("燃料储备", 0)) == need / 2 and fin.fuel_reserve() == 0 and low.fuel == 0 and high.fuel < 60, [from, low.fuel, high.fuel])
	check("the day's units all paid for", spent == fin.need_units("hub") or spent == need, [spent, need])
	clear_fuel()
	next_day()
	var bought: Dictionary = fin.bills[-1].items.filter(func(it): return it.facility == "hub")[0]
	check("with nothing held it is bought at the market", int(bought.bought) == fin.need_units("hub") and int(bought.cost) > 0, bought)

	# --- The barrel ---
	clear_fuel()
	check("燃料包 is gone; the fuel lot is the barrel", not Packs.is_pack(Fuel.OLD_PACK) and Packs.is_barrel(Fuel.BARREL) and not Fuel.BARREL in Packs.packing_order())
	check("fuel is never packed", not Packs.packable(can(60)) and not Packs.packable(MaterialCatalog.create(Fuel.SOLID, 5)))
	var seller := ""
	for f in FactionCatalog.ORDER:
		if ex.quote_buy(str(f), Fuel.BARREL).ok:
			seller = str(f)
			break
	check("somebody sells barrels", not seller.is_empty())
	var shelf_before := game.base.shelf.size()
	var mail_before := game.base.mail_count()
	if not seller.is_empty():
		for i in range(8): shelve(MaterialCatalog.create(Economy.GOLD_ID, 10))
		var ok := ex.buy_material(seller, Fuel.BARREL, 1)
		var barrel_items := game.stash.filter(func(it): return it.material_id == Fuel.BARREL).size()
		check("a bought barrel goes into the reserve, nothing to the warehouse", ok and fin.fuel_reserve() == 480 and barrel_items == 0 and game.base.mail_count() == mail_before,
			[ok, seller, fin.fuel_reserve(), game.base.shelf.size(), shelf_before, game.base.mail_count(), mail_before, ex.quote_buy(seller, Fuel.BARREL), ex.quota_left(seller)])
	var buyer := ""
	for f in FactionCatalog.ORDER:
		if ex.quote_fuel(str(f), 1).ok:
			buyer = str(f)
			break
	check("somebody buys barrels", not buyer.is_empty())
	for i in range(8): shelve(can(60))
	var nine := shelve(can(30))
	check("barrels held come from the cans only (8.5 cans: 1 barrel)", ex.barrels_held() == 1, ex.barrels_held())
	var lmd_before := game.gold
	var reserve_before := fin.fuel_reserve()
	check("selling one takes 480 units from the cans, the fullest first", ex.sell_fuel(buyer, 1) and fin.tank_fuel() == 30 and nine.fuel == 30 and fin.fuel_reserve() == reserve_before, [fin.tank_fuel(), nine.fuel, fin.fuel_reserve()])
	check("and pays", game.gold > lmd_before or ex.balance(FactionCatalog.currency(buyer)) > 0.0)
	check("not without a barrel's worth", not ex.sell_fuel(buyer, 1))

	# --- 燃料包 from an old save ---
	clear_fuel()
	var pack := MaterialCatalog.create(Fuel.OLD_PACK, 2)
	game.base.shelf.append(pack)
	ex.fuel_version = 0
	ex.migrate_fuel()
	check("an old save's 燃料包 pour into the reserve, 150 each", fin.fuel_reserve() == 300 and not game.base.shelf.has(pack) and ex.fuel_version == 1)

	# --- 加工部: 固体燃料 ---
	clear_fuel()
	fin.add_fuel(30)
	check("the recipe: 12 units, no loss", Workshop.cost_of(Fuel.SOLID, 2) == {Fuel.RESERVE: 24})
	check("it reads the reserve and the cans", game.material_count(Fuel.RESERVE) == 30 and game.workshop_refusal(Fuel.SOLID, 3) != "" and game.workshop_refusal(Fuel.SOLID, 2) == "")
	check("starting it takes the units", game.workshop_start(Fuel.SOLID, 2) and fin.fuel_reserve() == 6)

	# --- Voyages ---
	clear_fuel()
	var v := game.voyage
	var to := ""
	for anchor in VoyageCatalog.ANCHORS:
		if anchor != v.place():
			to = str(anchor)
			break
	var units := v.voyage_fuel(to, "standard")
	var tanks_in_cost := int(VoyageCatalog.voyage_supplies(VoyageCatalog.distance(v.place(), to))[Fuel.TANK])
	check("a voyage burns its 燃料罐 × 60 units", units == ceili(tanks_in_cost * 60 * v._cost_mult("standard", false)), [units, tanks_in_cost])
	var dry := v.voyage_cost(to, "standard")
	fin.add_fuel(units)
	var wet := v.voyage_cost(to, "standard")
	check("held fuel makes it cheaper", wet < dry and v.fuel_short(to, "standard") == 0, [dry, wet])
	if v.voyage_refusal(to, "standard").is_empty():
		check("sailing burns the units", game.sail(to, "standard") and fin.fuel_reserve() == 0)

	# --- A fire ---
	clear_fuel()
	game.inventory.items.clear()
	var pit := FirePit.new()
	root.add_child(pit)
	await step(2)
	var field_can := can(20)
	game.inventory.try_add(field_can)
	check("the pack's cans count their units", game.pack_fuels().get(Fuel.TANK, 0) == 20)
	pit.burn_left = 0.0
	check("she picks the units: 6 burn 60 s, the can stays", game.burn_tank(6, pit) == 6 and is_equal_approx(pit.burn_left, 60.0) and field_can.fuel == 14 and game.inventory.items.has(field_can))
	pit.burn_left = FeatureCatalog.FIRE_MAX - 25.0
	check("no more than the fire holds", game.burn_tank(10, pit) == 2 and field_can.fuel == 12)
	Fuel.set_fill(field_can, 0)
	check("an empty can is no fuel", not game.pack_fuels().has(Fuel.TANK))
	pit.queue_free()

	# --- Found in the field ---
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var fills := {}
	for i in range(200): fills[Fuel.field_fill(rng)] = true
	check("a can found in the field holds 0–60", fills.keys().all(func(k): return int(k) >= 0 and int(k) <= 60) and fills.has(0) and fills.size() > 30)

	print("FUEL FAILURES: %d" % failures)
	BaseState.frozen_clock = 0
	BaseState.clock_offset = 0
	quit(1 if failures > 0 else 0)
