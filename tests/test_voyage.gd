extends SceneTree
## Rhodes Island on the sand table (沙盘航行策划案_v1_0.md): the relation
## ladder, voyages, medical stays, bulk orders and the delivery contract.
var game: GameManager
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool, detail: Variant = "") -> void:
	checks += 1
	print(("PASS " if passed else "FAIL ") + label + ("" if passed or str(detail).is_empty() else "  [%s]" % str(detail)))
	if not passed: failures += 1

## Moves the wall clock and settles the voyage up to it.
func later(seconds: int) -> void:
	BaseState.clock_offset += seconds
	game.market.advance_to(BaseState.now())
	game.voyage.tick(BaseState.now())

func now() -> int:
	return BaseState.now()

func run() -> void:
	MarketState.tz_override = 0
	BaseState.frozen_clock = 1791972000
	_ladder()
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	game.fixed_market_seed = 77
	root.add_child(game)
	await step(8)
	game.rng.seed = 91
	_daily_correction()
	_voyages()
	_stays()
	_conflicts()
	_orders()
	await _delivery()
	await _station()
	_save()
	print("VOYAGE RESULT: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await step(2)
	quit(1 if failures else 0)

# --- §1 -------------------------------------------------------------------------------------

func _ladder() -> void:
	check("ranks climb like Grim Dawn: 150 / 500 / 1000 / 2500 / 5000",
		Exchange.rank_of(149) == 0 and Exchange.rank_of(150) == 1 and Exchange.rank_of(499) == 1 and Exchange.rank_of(500) == 2
		and Exchange.rank_of(1000) == 3 and Exchange.rank_of(2500) == 4 and Exchange.rank_of(5000) == 5)
	check("the next rank's mark", Exchange.next_rank_at(342) == 500 and Exchange.next_rank_at(5000) == 5000)
	check("old saves keep their rank and progress: 250 → 750, 100 → 150, 500 → 5000",
		Exchange.migrate_relation(250) == 750 and Exchange.migrate_relation(100) == 150 and Exchange.migrate_relation(500) == 5000 and Exchange.migrate_relation(0) == 0)
	check("no correction at or below the expected value", Exchange.drift(1000, 1000) == 0 and Exchange.drift(800, 1000) == 0)
	check("the correction grows with the excess: 1500 over → −38, 4000 over → −200", Exchange.drift(2500, 1000) == 38 and Exchange.drift(5000, 1000) == 200, [Exchange.drift(2500, 1000), Exchange.drift(5000, 1000)])
	check("expected values follow each place's attitude", FactionCatalog.RELATION_EXPECTED.karlan > FactionCatalog.RELATION_EXPECTED.lungmen
		and FactionCatalog.RELATION_EXPECTED.lungmen > FactionCatalog.RELATION_EXPECTED.ursus and FactionCatalog.trading().all(func(f): return FactionCatalog.RELATION_EXPECTED.has(f)))
	var ex := Exchange.new()
	ex.load_data({"relations": {"karlan": 100, "lungmen": 350}})
	check("an old account is migrated on load", ex.relation("karlan") == 150 and ex.relation("lungmen") == 1750, ex.relations)
	var fresh := Exchange.new()
	fresh.load_data(fresh.to_data())
	check("a new account starts 喀兰贸易 at 150 and is not migrated again", Exchange.START_RELATIONS.karlan == 150 and fresh.relations.get("karlan", 150) == 150)

func _daily_correction() -> void:
	var ex := game.exchange
	ex.relations["lungmen"] = 2500
	ex.relations["ursus"] = 400
	var day := MarketState.day_key(game.market.t)
	while MarketState.day_key(game.market.t) == day: later(3600)
	check("a new trading day corrects a relation above its expected value", ex.relation("lungmen") == 2500 - 38 and ex.relation("ursus") == 400, ex.relations)
	later(86400 * 30)
	check("thirty days later it has come down towards 1000 (about 1770)", ex.relation("lungmen") > 1700 and ex.relation("lungmen") < 1850, ex.relation("lungmen"))
	ex.relations["lungmen"] = 0
	ex.relations["ursus"] = 0

# --- §3 -------------------------------------------------------------------------------------

func _voyages() -> void:
	var v := game.voyage
	game.base.ship_at = "龙门"
	check("a new save lies at 龙门", v.docked_at() == "龙门" and not v.is_sailing())
	var d := VoyageCatalog.distance("龙门", "切尔诺伯格")
	check("龙门 to 切尔诺伯格 is about 0.24 on the table", absf(d - 0.237) < 0.01, d)
	var supplies := VoyageCatalog.voyage_supplies(d)
	var expected := 0.0
	for id in supplies: expected += v.supply_price(id) * int(supplies[id])
	var standard := v.voyage_cost("切尔诺伯格", "standard")
	check("the cost is the supplies at the live price: %d" % standard, absi(standard - roundi(expected)) <= 100 and standard > 100000 and standard < 400000)
	check("全速 costs ×1.25, 边走边补 ×0.75",
		absi(v.voyage_cost("切尔诺伯格", "fast") - roundi(expected * 1.25)) <= 100 and absi(v.voyage_cost("切尔诺伯格", "resupply") - roundi(expected * 0.75)) <= 100)
	var hours := VoyageCatalog.HOURS_BASE + VoyageCatalog.HOURS_PER_DISTANCE * d
	check("and takes 1 + 6d hours, −30% / +30%",
		absi(v.voyage_seconds("切尔诺伯格", "standard") - roundi(hours * 3600)) <= 1 and absi(v.voyage_seconds("切尔诺伯格", "fast") - roundi(hours * 0.7 * 3600)) <= 1
		and absi(v.voyage_seconds("切尔诺伯格", "resupply") - roundi(hours * 1.3 * 3600)) <= 1)
	# Dearer fuel at the anchor makes the voyage dearer.
	var book: String = "lungmen:fuel"
	var before_i: float = game.market.books[book].i
	game.market.books[book].i = before_i * 2.0
	check("dearer fuel, dearer voyage", v.voyage_cost("切尔诺伯格", "standard") > standard)
	game.market.books[book].i = before_i
	check("the farthest leg is dearer than the nearest", v.voyage_cost("哥伦比亚", "standard") > v.voyage_cost("切尔诺伯格", "standard"))
	game.gold = 1000
	check("too poor to sail early on", v.voyage_refusal("切尔诺伯格", "standard") == "龙门币不足" and not game.sail("切尔诺伯格", "standard"))
	game.gold = 2000000
	v.set_stay("injured", true, now())
	var cost := v.voyage_cost("切尔诺伯格", "fast")
	check("sailing pays up front", game.sail("切尔诺伯格", "fast") and game.gold == 2000000 - cost)
	check("under way: not at any anchor, the stay is off", v.is_sailing() and v.docked_at().is_empty() and not v.stay_on() and not v.set_stay("injured", true, now()))
	check("a second voyage waits for the first", v.voyage_refusal("萨米", "standard") == "航行中")
	var span := int(v.sailing.due) - int(v.sailing.start)
	later(span / 2)
	check("halfway along the leg", absf(v.progress(now()) - 0.5) < 0.01 and v.is_sailing())
	game.show_ship()
	check("the table's ship moves along the leg", game.base_map.ship_place == "切尔诺伯格")
	later(span)
	check("arrived at 切尔诺伯格", not v.is_sailing() and game.base.ship_at == "切尔诺伯格")
	game.base.ship_at = "龙门"

# --- §4 -------------------------------------------------------------------------------------

func _shelf(id: String, count: int) -> Item:
	var item := MaterialCatalog.create(id, count)
	game.base.shelf.append(item)
	return item

func _stays() -> void:
	var v := game.voyage
	var ex := game.exchange
	ex.relations["lungmen"] = 0
	ex.relations["rat"] = 0
	game.gold = 1000000
	v.relation_frac.clear()
	check("care costs 3000 / 6000 an hour", VoyageCatalog.STAY_COST.injured == 3000 and VoyageCatalog.STAY_COST.infected == 6000)
	v.set_stay("injured", true, now())
	later(3600)
	check("an hour of injured care: −3000, 龙门商会 +1, 鼠王 half a point", game.gold == 1000000 - 3000 and ex.relation("lungmen") == 1 and ex.relation("rat") == 0, [game.gold, ex.relations])
	later(3600)
	check("鼠王's halves make a point", ex.relation("rat") == 1 and ex.relation("lungmen") == 2)
	later(1800)
	check("half an hour settles nothing", ex.relation("lungmen") == 2)
	# Medical supplies pay at most half an hour's cost, whole units, cheapest first.
	var sugar := _shelf("代糖", 10)
	v.set_supplies(true)
	var gold := game.gold
	later(1800)
	var unit := Economy.lmd(sugar.unit_value)
	var used := mini(10, floori(1500.0 / unit))
	check("supplies pay up to half: %d 代糖 used" % (10 - sugar.quantity), sugar.quantity == 10 - used and gold - game.gold == 3000 - used * unit, [gold - game.gold, sugar.quantity])
	v.set_supplies(false)
	game.base.take_from_shelf(sugar)
	# A budget stops the stay.
	v.set_stay("injured", false, now())
	v.set_budget(5000)
	v.set_stay("injured", true, now())
	later(3600 * 3)
	check("a 5000 budget allows one hour, then stops", not v.stay_on() and int(v.stay.spent) == 3000)
	v.set_budget(0)
	# A target stops it.
	v.set_target("lungmen", ex.relation("lungmen") + 2)
	v.set_stay("injured", true, now())
	later(3600 * 5)
	check("the target relation stops it", not v.stay_on() and ex.relation("lungmen") == int(v.stay.target), [ex.relation("lungmen"), v.stay.target])
	v.set_target("", 0)
	# The cap: R3.
	ex.relations["lungmen"] = VoyageState.cap() - 1
	ex.relations["rat"] = VoyageState.cap()
	v.set_stay("injured", true, now())
	later(3600 * 3)
	check("a stay lifts nobody past R3, and stops when all are there", ex.relation("lungmen") == VoyageState.cap() and ex.relation("rat") == VoyageState.cap() and not v.stay_on())
	ex.relations["lungmen"] = 0
	ex.relations["rat"] = 0
	# No money, no care.
	game.gold = 2000
	v.set_stay("injured", true, now())
	later(3600)
	check("short of money the stay stops without debt", not v.stay_on() and game.gold == 2000)
	game.gold = 1000000
	# Offline: hours settle on catch-up.
	v.set_stay("infected", true, now())
	gold = game.gold
	later(3600 * 10)
	check("ten hours away settle ten hours", gold - game.gold == 60000 and ex.relation("rat") == 30 and ex.relation("lungmen") == 10, [gold - game.gold, ex.relations])
	v.set_stay("infected", false, now())

func _conflicts() -> void:
	var v := game.voyage
	var ex := game.exchange
	game.gold = 10000000
	game.base.ship_at = "切尔诺伯格"
	ex.relations["ursus"] = 100
	ex.relations["reunion"] = 0
	v.set_stay("infected", true, now())
	later(3600 * 6)
	check("切尔诺伯格: the mines lose, the remnants gain", ex.relation("ursus") == 94 and ex.relation("reunion") == 18, ex.relations)
	check("six infected hours: the next mine contract starts at +10% threat", is_equal_approx(v.threat_start("mine"), 0.1) and v.threat_start("city") == 0.0)
	later(3600 * 60)
	check("capped at +40%", is_equal_approx(v.mine_threat, VoyageCatalog.MINE_THREAT_CAP))
	v.contract_done("mine")
	check("a mine contract spends it", v.threat_start("mine") == 0.0)
	v.set_stay("infected", false, now())
	# 卡西米尔: 无胄盟 strike now and then.
	game.base.ship_at = "卡西米尔"
	ex.relations["kazimierz"] = 0
	v.relation_frac.clear()
	v.set_stay("infected", true, now())
	later(3600 * 200)
	var rel := ex.relation("kazimierz")
	check("卡西米尔: strikes cost relation (%d < 300)" % rel, rel < 300 and rel > 150)
	v.set_stay("infected", false, now())
	# 叙拉古: insurance and 血债.
	game.base.ship_at = "叙拉古"
	v.set_stay("injured", true, now())
	v.set_stay("infected", true, now())
	check("叙拉古: infected care pays the families' insurance", v.hour_cost() == 3000 + 6000 + 2000)
	var gold := game.gold
	later(3600 * 6)
	check("six hours: 11000 an hour, 血债 ×0.9", gold - game.gold == 66000 and is_equal_approx(v.debt_mult("siracusa"), 0.9), [gold - game.gold, v.siracusa_debt])
	v.set_stay("injured", false, now())
	v.set_stay("infected", false, now())
	v.contract_done("siracusa")
	check("a Siracusa contract spends the 血债 rate", v.debt_mult("siracusa") == 1.0)
	game.base.ship_at = "龙门"

# --- §5 -------------------------------------------------------------------------------------

func _order_for(faction: String, lines: Dictionary) -> Dictionary:
	var v := game.voyage
	v.orders.clear()
	var o := v._new_order(now())
	o.faction = faction
	o.lines = lines
	o.currency = FactionCatalog.currency(faction)
	o.pay = 12.5 if o.currency == "gold" else 25000.0
	o.relation = 15
	v.orders.append(o)
	v.last_refill = now()
	return o

func _orders() -> void:
	var v := game.voyage
	var ex := game.exchange
	v.orders.clear()
	v.last_refill = 0
	v.tick(now())
	check("four orders on the board", v.orders.size() == VoyageCatalog.ORDER_SLOTS)
	var term := now() + VoyageCatalog.ORDER_TERM
	var sane := v.orders.all(func(o): return (o.lines as Dictionary).size() >= 1 and int(o.relation) >= 10 and int(o.relation) <= 20 and int(o.expires) == term and str(o.faction) != "penguin" and float(o.pay) > 0.0)
	check("each asks 1–2 goods, pays, relation +10–20, three days", sane, v.orders)
	var counts := true
	for k in range(200):
		var o := v._new_order(now())
		var total := 0
		for m in o.lines:
			if int(o.lines[m]) < 30 or int(o.lines[m]) > 100: counts = false
			total += int(o.lines[m])
		if total > 150: counts = false
	check("each line asks 30–100, an order at most 150 in all", counts)
	v.orders.pop_back()
	later(VoyageCatalog.ORDER_REFILL - 60)
	check("an empty slot waits six hours", v.orders.size() == VoyageCatalog.ORDER_SLOTS - 1)
	later(120)
	check("then fills", v.orders.size() == VoyageCatalog.ORDER_SLOTS)
	# In the faction's waters: submit and wait an hour.
	var o := _order_for("lungmen", {"螺栓": 20})
	check("short of goods it will not take it", v.submit_refusal(int(o.id)).begins_with("缺少"))
	_shelf("螺栓", 25)
	var gold := game.gold
	var rel := ex.relation("lungmen")
	check("in 龙门's waters it is submitted", game.submit_bulk(int(o.id)) and game.material_count("螺栓") == 5 and str(o.state) == "handover")
	check("and cannot be packed", v.pack_refusal(int(o.id)) != "")
	later(1800)
	check("not paid before the hour", game.gold == gold)
	later(1900)
	check("after an hour: paid and relation +15", game.gold == gold + 25000 and ex.relation("lungmen") == rel + 15 and v.order(int(o.id)).is_empty())
	# Out of waters: pack a crate.
	o = _order_for("rhine", {"螺栓": 10})
	check("莱茵生命 is not in 龙门's waters", v.submit_refusal(int(o.id)) == "不在境内")
	_shelf("螺栓", 10)
	game.base.camps["snow"] = 30
	check("packing takes the goods", game.pack_bulk(int(o.id)) and game.material_count("螺栓") == 5 and str(o.state) == "packed")
	var crate := v.cargo_item(o)
	check("the crate is at staging, 4×3, worth nothing to sell", crate != null and game.base.location_of(crate) == "staging" and crate.width == 4 and crate.height == 3
		and game.trader_offer(crate) == 0 and Economy.price(crate) == 0 and not game.sell(crate))
	check("too big for any safe bag", BaseCatalog.SAFE_SIZES.all(func(s): return s.x < crate.width or s.y < crate.height))
	var floors: Dictionary = o.floors
	check("it goes to 萨米 or 叙拉古: floors within reach", floors.has("snow") and floors.has("siracusa") and int(floors.snow) <= 39 and int(floors.siracusa) <= 9
		and int(floors.snow) % 10 != 0, floors)
	check("a delivery card at 萨米's desk, none at 龙门's", game.contract_offers("snow").any(func(c): return c.type == "deliver" and int(c.order) == int(o.id))
		and not game.contract_offers("city").any(func(c): return c.type == "deliver"))
	var reach := true
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in range(400):
		var f := VoyageState.delivery_floor(30, rng)
		if f < 1 or f > 39 or f % 10 == 0: reach = false
		if VoyageState.delivery_floor(0, rng) > 9: reach = false
	check("past 30 floors: anywhere 1–39 but a camp; no camp: 1–9", reach)
	# Sailing into its waters, the crate is handed in at the terminal.
	game.base.ship_at = "哥伦比亚"
	check("in 莱茵生命's waters the packed crate can be submitted", v.submit_refusal(int(o.id)).is_empty() and game.submit_bulk(int(o.id)) and game.base.location_of(crate).is_empty())
	game.base.ship_at = "龙门"
	# A crate lost reopens the order.
	o = _order_for("rhine", {"螺栓": 5})
	game.pack_bulk(int(o.id))
	game.base.remove_item(v.cargo_item(o))
	v.on_settle()
	check("a crate lost with the pack: the order is open again", str(o.state) == "open" and str(o.cargo).is_empty())
	# Expiry returns a packed crate's goods.
	_shelf("螺栓", 5)
	game.pack_bulk(int(o.id))
	var bolts := game.material_count("螺栓")
	var crates := game.base.all_items().filter(func(i): return i.effect == VoyageCatalog.CARGO_EFFECT).size()
	later(VoyageCatalog.ORDER_TERM + 60)
	var staged: int = game.base.all_items().filter(func(i): return i.material_id == "螺栓").reduce(func(a, i): return a + i.quantity, 0)
	check("expired: the crate is unpacked, the goods come back", v.order(int(o.id)).is_empty() and crates == 1
		and game.base.all_items().filter(func(i): return i.effect == VoyageCatalog.CARGO_EFFECT).is_empty() and staged >= 5, [bolts, staged])

# --- §5.3 in the field ------------------------------------------------------------------------

func _delivery() -> void:
	var v := game.voyage
	var ex := game.exchange
	var o := _order_for("karlan", {"螺栓": 5})
	_shelf("螺栓", 5)
	game.pack_bulk(int(o.id))
	var crate := v.cargo_item(o)
	game.base.remove_item(crate)
	check("the crate goes into the pack", game.inventory.try_add(crate))
	crate.carried_in = true
	o.floors = {"snow": 3, "siracusa": 3}
	var card: Dictionary = game.contract_offers("snow").filter(func(c): return c.type == "deliver")[0]
	check("the card reads 运送 and its pay", FieldCatalog.contract_goal(card, "snow", 1).begins_with("运送") and FieldCatalog.contract_bonus_text(card).contains("关系 +15"))
	var ship := game.base.ship_at
	game._pending_contract = card
	await game.start_contract("snow")
	await step(2)
	check("a contract no longer moves the ship", game.base.ship_at == ship)
	check("no handover point before its floor", not is_instance_valid(game.handover_node))
	game.floor_number = 2
	await game.advance(0)
	await step(4)
	check("on floor 3 the handover point stands", game.floor_number == 3 and is_instance_valid(game.handover_node), game.floor_number)
	for enemy in game.floor_enemies(): enemy.take_hit(99999999.0, "true")
	for trap in game.traps: trap.spent = true
	await step(3)
	game.player.teleport(game.handover_node.global_position + Vector3(0.6, 0, 0))
	await step(2)
	check("the prompt names the buyer", game.interaction_prompt() == FactionCatalog.name_of("karlan"), game.interaction_prompt())
	game._interact()
	check("handed over: the crate leaves the pack, the objective is done", game.cargo_delivered and not game.inventory.items.has(crate) and game.contract_progress().done)
	var gold_account := ex.gold_account
	var rel := ex.relation("karlan")
	game.settle(false)
	await step(2)
	check("paid at settlement even after a fall", is_equal_approx(ex.gold_account, gold_account + 12.5) and ex.relation("karlan") == rel + 15 and v.order(int(o.id)).is_empty())

# --- The station ----------------------------------------------------------------------------

func _station() -> void:
	await step(4)
	check("the hall has a sand table station", not game.base_map.station("sand_table").is_empty())
	game.open_station("sand_table")
	await step(2)
	check("it opens the sand table", game.modal == "station")
	game.close_modal()

func _save() -> void:
	var v := game.voyage
	game.gold = 5000000
	v.set_stay("injured", true, now())
	game.sail("萨米", "resupply")
	_order_for("sami", {"螺栓": 3})
	var copy := VoyageState.new()
	copy.load_data(JSON.parse_string(JSON.stringify(v.to_data())))
	check("the voyage survives a save", copy.sailing.to == "萨米" and copy.orders.size() == 1 and int(copy.orders[0].lines["螺栓"]) == 3 and int(copy.orders[0].id) == int(v.orders[0].id))
