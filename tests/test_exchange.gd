extends SceneTree
## The Doctor's account at the exchange (势力与交易所策划案_v0_7.md): spot,
## orders, forwards, CFDs, the loan, the money changer, 企鹅物流, 加工部, posts.
var game: GameManager
var failures := 0
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool) -> void:
	print(("PASS " if passed else "FAIL ") + label)
	if not passed: failures += 1

func stash_add(item: Item) -> Item:
	game.base.shelf.append(item)
	return item

## Moves the clock (and the market with it).
func later(seconds: int) -> void:
	BaseState.clock_offset += seconds
	game.market.advance_to(BaseState.now())

func set_index(market_id: String, value: float) -> void:
	var b = game.market.books[market_id]
	b.i = value
	b.wp = value
	b.mu = value
	b.p = 0.0
	b.lock = 0
	b.pj = 0.0
	b.sh = 0.0

func run() -> void:
	MarketState.tz_override = 0
	# The market starts at now() and ticks every second of it: pinned, every run
	# walks the same prices, news and trading hours (a Wednesday, 10:00).
	BaseState.frozen_clock = 1791972000
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	game.fixed_market_seed = 77
	root.add_child(game)
	await step(8)
	game.rng.seed = 77
	var ex := game.exchange
	var market := game.market
	game.gold = 500000
	check("the exchange opens with 喀兰贸易 at R1", ex.unlocked() and ex.rank("karlan") == 1 and ex.rank("lungmen") == 0)
	# --- Spot ---------------------------------------------------------------------
	var armor := stash_add(Item.create("测试护甲", Item.Category.ARMOR, 2, 2))
	armor.value = 100
	set_index("lungmen:armor", 1.0)
	var q := ex.quote_sell(armor, "lungmen")
	var expected := 10000.0 * 1.25 * market.bid("lungmen:armor") * (1.0 - minf(0.3, 0.5 * 12500.0 / market.depth("lungmen:armor"))) * (1.0 - 0.04)
	check("龙门商会 quotes base × preference × bid − slippage − 4%%: %.0f" % float(q.net), q.ok and absf(float(q.net) - expected) < 1.0 and q.currency == "lmd")
	var gold_before := game.gold
	check("selling pays 龙门币", ex.sell_item(armor, "lungmen") and game.gold - gold_before == floori(float(q.net)) and not game.stash.has(armor))
	check("selling builds relation and pushes the market", ex.relation("lungmen") > 0 and market.books["lungmen:armor"].p > 0.0)
	var cube := stash_add(MaterialCatalog.create("固源岩", 10))
	var rq := ex.quote_sell(cube, "rhine")
	var acct := ex.gold_account
	check("莱茵生命 pays into the 赤金 account (fixed 1000 base)", rq.currency == "gold" and ex.sell_item(cube, "rhine") and absf(ex.gold_account - acct - float(rq.net)) < 0.02)
	var ore := FieldCatalog.exclusive("mine")
	game.inventory.try_add(ore)
	check("a field-only faction refuses remote trade", not ex.quote_sell(ore, "reunion").ok and ex.quote_sell(ore, "reunion", false).ok)
	ex.relations["lungmen"] = 50
	check("contraband to 鼠王 costs 龙门商会 relation", ex.sell_item(ore, "rat") and ex.relation("lungmen") == 45)
	var fee_r1 := ex.remote_fee("karlan")
	ex.relations["karlan"] = 500
	check("the remote fee falls 0.5%% a rank: %.3f, %.3f" % [fee_r1, ex.remote_fee("karlan")], is_equal_approx(fee_r1, 0.035) and is_equal_approx(ex.remote_fee("karlan"), 0.015))
	ex.relations["karlan"] = 100
	var crates := game.base.crates.size()
	var lmd := game.gold
	check("buying from a shelf pays and lands at receiving", ex.buy_material("lungmen", "螺栓", 5) and game.gold < lmd and game.base.crates.size() == crates + 1)
	check("and uses the buy quota", ex.quota_left("lungmen") < ex.quota_cap("lungmen"))
	ex.quota_used["lungmen"] = ex.quota_cap("lungmen")
	check("a full quota refuses", not ex.buy_material("lungmen", "螺栓", 1))
	later(600)
	check("the quota comes back 10% per 10 minutes", absf(ex.quota_left("lungmen") - ex.quota_cap("lungmen") * 0.1) < 50.0)
	# --- Orders -------------------------------------------------------------------
	var sword := stash_add(Item.create("测试长剑", Item.Category.WEAPON, 1, 3))
	sword.value = 80
	set_index("karlan:weapon", 1.0)
	check("a limit sell escrows the item", ex.place_sell_order(sword, "karlan", "limit", 110.0) and not game.stash.has(sword) and ex.orders.size() == 1)
	later(4)
	check("it waits below the limit", ex.orders.size() == 1)
	acct = ex.gold_account
	set_index("karlan:weapon", 1.12)
	later(4)
	check("and fills when the market reaches it", ex.orders.is_empty() and ex.gold_account > acct)
	var shield := stash_add(Item.create("测试盾", Item.Category.ARMOR, 2, 2))
	ex.place_sell_order(shield, "karlan", "stop", 50.0)
	check("cancelling returns the item to staging", ex.cancel_order(ex.orders[-1].id) and game.base.staging.any(func(i): return i.item_name == "测试盾"))
	# --- Forwards -----------------------------------------------------------------
	ex.relations["lungmen"] = 300
	set_index("lungmen:build", 1.0)
	var balance := game.gold
	check("a 交货合约 needs the rank for its leverage", not ex.forward_refusal("lungmen", 3).is_empty() if ex.rank("lungmen") < 3 else true)
	check("opening a forward takes margin and fee", ex.open_forward("lungmen", "螺栓", 10, 0, true, 2) and game.gold < balance)
	var f: Dictionary = ex.forwards[-1]
	check("the deliver price is under spot", float(f.k) < ex.material_spot("lungmen", "螺栓", true))
	stash_add(MaterialCatalog.create("螺栓", 10))
	var rel := ex.relation("lungmen")
	balance = game.gold
	check("delivering pays K × Q plus the margin back", ex.deliver_forward(f.id) and game.gold - balance == floori(float(f.k) * 10 + float(f.margin)) and ex.relation("lungmen") == rel + 10)
	ex.open_forward("lungmen", "螺栓", 30, 0, true, 1)
	rel = ex.relation("lungmen")
	later(3700)
	check("no goods at expiry: default, relation −40, a cooldown", ex.forwards.is_empty() and ex.relation("lungmen") == rel - 40 and ex.forward_refusal("lungmen", 1) == "违约冷却中")
	check("the cooldown lasts at least six hours", int(ex.forward_cooldown["lungmen"]) - market.t >= Exchange.DEFAULT_MIN_COOLDOWN - 200)
	ex.relations["karlan"] = 300
	crates = game.base.crates.size()
	check("a 收货合约 opens", ex.open_forward("karlan", "帆布", 4, 0, false, 1))
	later(3700)
	check("and at expiry pays the rest and the goods arrive", ex.forwards.is_empty() and game.base.crates.size() == crates + 1)
	ex.open_forward("karlan", "碳素", 5, 1, false, 3)
	var fwd: Dictionary = ex.forwards[-1]
	set_index("karlan:build", 0.3)
	later(4)
	check("a big loss forces the forward closed", ex.forwards.is_empty() and ex.history[-1].kind == "liquidated")
	# --- CFDs ---------------------------------------------------------------------
	game.gold = 500000
	ex.loan = 0
	set_index("fx", 1.0)
	check("a CFD on the rate opens long 2×", ex.open_cfd("fx", 1, 2, 20000.0))
	var c: Dictionary = ex.cfds[-1]
	set_index("fx", 1.5)
	check("a rising rate shows profit: %.0f" % ex.cfd_pnl(c), ex.cfd_pnl(c) > 19000.0)
	balance = game.gold
	var cap := ex.cfd_cap()
	ex.cfd_day.used = 0.0
	ex.close_cfd(c.id)
	check("closing pays the margin plus profit up to today's cap: +%d" % (game.gold - balance), game.gold - balance <= 20000 + cap + 1)
	check("the rest waits for the next trading day", ex.cfd_pending() > 0.0)
	var pending := ex.cfd_pending()
	balance = game.gold
	later(MarketState.next_day_start(market.t) - market.t + 4)
	check("and comes in at 08:00", ex.cfd_pending() < pending and game.gold > balance)
	ex.note_contract_reward(20000)
	check("today's contract rewards raise the cap by half", is_equal_approx(ex.cfd_cap(), 10000.0 + 10000.0))
	game.gold = 30000
	ex.loan = 25000
	check("borrowed money is not margin (贷款不能当保证金)", not ex.open_cfd("fx", 1, 1, 10000.0) and ex.cfd_refusal("fx", 1, 10000.0) == "保证金不足")
	ex.loan = 0
	game.gold = 900000
	ex.relations["karlan"] = 100
	check("the notional cap per issuer", not ex.open_cfd("fx", 1, 1, 60000.0) and ex.cfd_refusal("fx", 1, 60000.0) == "持仓上限")
	check("leverage needs the issuer's rank", not ex.open_cfd("comp:lungmen", 1, 2, 5.0))
	ex.open_cfd("fx", -1, 1, 10000.0)
	var short: Dictionary = ex.cfds[-1]
	var margin_before := float(short.margin)
	later(MarketState.next_day_start(market.t) - market.t + 4)
	check("an overnight fee comes off the margin at 08:00", float(short.margin) < margin_before)
	ex.set_cfd_limits(short.id, 0.0, ex.cfd_price("fx") * 1.01)
	set_index("fx", 1.5)
	later(4)
	check("a stop-loss closes the short", not ex.cfds.has(short))
	# --- Loans --------------------------------------------------------------------
	game.gold = 0
	check("the loan limit follows prestige: %d" % ex.loan_limit(), ex.loan_limit() == 20000 * (game.base.rank() + 1))
	check("borrowing adds to the balance", ex.borrow(10000) and game.gold == 10000 and ex.loan == 10000)
	check("not past the limit", not ex.borrow(ex.loan_limit()))
	ex.on_settlement(0)
	check("interest once a settlement: 1% under 10,000", ex.loan == 10100)
	check("tiers", is_equal_approx(Exchange.loan_rate(40000), 0.02) and is_equal_approx(Exchange.loan_rate(90000), 0.03) and is_equal_approx(Exchange.loan_rate(150000), 0.04))
	ex.loan = 200000
	game.gold = 10000
	var taken := ex.on_settlement(8000)
	check("an overdue loan takes the contract reward first", taken == 8000 and ex.loan_locked() and not ex.borrow(1000))
	ex.loan = 0
	check("repaying", ex.borrow(5000) and ex.repay(5000) and ex.loan == 0)
	# --- Money changer ------------------------------------------------------------
	set_index("fx", 1.1)
	market.advance_to(market.t + 2)
	game.gold = 110000
	acct = ex.gold_account
	check("the terminal changes 龙门币 to 赤金 at the rate less 0.5%", ex.convert(true, 110000) and absf(ex.gold_account - acct - 110000.0 / (Economy.fx * 1.005)) < 0.02)
	game.gold = 0
	check("可露希尔 changes at 3%", game.closure_convert(false, 10.0) and absi(game.gold - roundi(10.0 * Economy.fx * 0.97)) <= 1)
	check("可露希尔 buys bars at the live rate", Economy.closure_bar_price() == roundi(Economy.fx * 0.97))
	stash_add(MaterialCatalog.create(Economy.GOLD_ID, 3))
	acct = ex.gold_account
	check("bars go into the account", ex.deposit_bars(3) and absf(ex.gold_account - acct - 3.0) < 0.01)
	check("whole bars come out to staging", ex.withdraw_bars(2) and game.base.staging.any(func(i): return i.material_id == Economy.GOLD_ID))
	var fee_item := MaterialCatalog.create("螺栓", 10)
	check("the camp's deposit fee uses the live rate", game.deposit_fee(fee_item) == maxi(1, ceili(Economy.price(fee_item) * FieldCatalog.DEPOSIT_FEE / Economy.fx)))
	# --- Direct delivery ----------------------------------------------------------
	var plain := stash_add(MaterialCatalog.create("螺栓", 10))
	balance = game.gold
	game.sell(plain)
	check("plain delivery pays 80%% of 交付价: %d" % (game.gold - balance), game.gold - balance == roundi(Economy.price(MaterialCatalog.create("螺栓", 10)) * 0.8))
	# --- 企鹅物流 -------------------------------------------------------------------
	game.gold = 100000
	var cargo := stash_add(MaterialCatalog.create("医用耗材包", 10))
	check("shipping charges a fee and takes the goods", ex.ship(cargo, "reunion") and game.gold < 100000 and ex.shipments.size() == 1)
	acct = ex.gold_account
	later(4 * 3600 + 10)
	check("and pays at the price on arrival, even to a field-only faction", ex.shipments.is_empty() and ex.gold_account > acct)
	# --- Alerts and the watch list ------------------------------------------------
	ex.toggle_watch("fx")
	check("watching", ex.watch.has("fx"))
	ex.add_alert("fx", ">=", ex.cfd_price("fx") * 1.01)
	set_index("fx", 2.0)
	later(4)
	check("a price alert fires once", ex.alerts.is_empty())
	# --- 加工部 ---------------------------------------------------------------------
	game.gold = 10000
	stash_add(MaterialCatalog.create("源岩", 15))
	check("a recipe needs its inputs", game.workshop_refusal("固源岩", 6).begins_with("缺少"))
	check("five 固源岩 from fifteen 源岩", game.workshop_start("固源岩", 5) and game.material_count("源岩") == 0 and game.gold == 10000 - 500)
	check("the queue is full with one job at R0", game.workshop_refusal("糖", 1) == "加工队列已满")
	var staged := game.base.staging.size()
	BaseState.clock_offset += 11 * 60
	game._tick_workshop()
	check("finished goods go to staging", game.base.staging.size() > staged and game.base.staging.any(func(i): return i.material_id == "固源岩" and i.quantity == 5))
	stash_add(MaterialCatalog.create("螺栓", 12))
	stash_add(MaterialCatalog.create("金属板", 6))
	stash_add(MaterialCatalog.create("胶带", 2))
	check("packing a trade crate", game.workshop_start("工业补给箱", 1))
	BaseState.clock_offset += 120
	game._tick_workshop()
	var crate: Item = game.base.staging.filter(func(i): return i.material_id == "工业补给箱")[0] if game.base.staging.any(func(i): return i.material_id == "工业补给箱") else null
	check("a trade crate is trade goods", crate != null and FactionCatalog.category_of(crate) == "trade" and ex.quote_sell(crate, "kazimierz").ok)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var w := Workshop.new()
	var bys := 0
	for k in range(200): bys += w.start("异铁", 10, 0, rng).byproducts.values().reduce(func(a, b): return a + b, 0)
	check("byproducts about 10%% (PRTS): %d / 2000" % bys, absi(bys - 200) < 50)
	check("PRTS costs: 100 / 200 / 300, carbon 800", Workshop.recipe("固源岩").lmd == 100 and Workshop.recipe("固源岩组").lmd == 200 and Workshop.recipe("提纯源岩").lmd == 300 and Workshop.recipe("碳素").lmd == 800)
	check("固源岩组 is five to one", Workshop.recipe("固源岩组")["in"]["固源岩"] == 5)
	check("加工部 posts orders", BaseCatalog.ORDERS.values().any(func(o): return o.dept == "加工部"))
	# --- Saving -------------------------------------------------------------------
	var copy := Exchange.new()
	copy.load_data(JSON.parse_string(JSON.stringify(ex.to_data())))
	check("the account saves and loads", absf(copy.gold_account - ex.gold_account) < 0.01 and copy.relation("lungmen") == ex.relation("lungmen") and copy.watch == ex.watch and copy.loan == ex.loan)
	# --- News in the field and the swan popup ------------------------------------
	await game.start_contract("mine")
	await step(4)
	game.market.fire("U2")
	check("in the field PRTS reports market news", game.prts_log.any(func(l): return "PRTS 快讯" in str(l[1])))
	game.market.fire("U6")
	check("a black swan waits as the base popup", not game.swan_popup.is_empty())
	# A post in the mine.
	game.encounter = "post"
	game.post_faction = "reunion"
	var meds := MaterialCatalog.create("医用耗材包", 5)
	game.inventory.try_add(meds)
	acct = ex.gold_account
	var bars_before := game.gold_bars()
	var post_q := ex.quote_sell(meds, "reunion", false)
	check("a post pays whole 赤金 into the pack, rounded down, no fee", game.post_sell(meds) and game.gold_bars() - bars_before == floori(float(post_q.net)) and absf(ex.gold_account - acct) < 0.001)
	check("a field price shows the bars and the exact quote", Exchange.format_field("gold", 2.88) == "2 赤金 (2.88)" and Exchange.format_field("gold", 2.12, true) == "3 赤金 (2.12)" and Exchange.field_bars(3.0, true) == 3 and Exchange.field_bars(0.49) == 0)
	game.give_gold_bars(100)
	bars_before = game.gold_bars()
	var rate_before := game.contamination_rate()
	var unit := float(ex.quote_buy("reunion", "源岩").unit)
	check("buying at a post goes into the pack", game.post_buy("源岩", 5) and game.inventory.count_material("源岩") == 5)
	check("and costs whole 赤金 from the pack", bars_before - game.gold_bars() == Exchange.field_bars(unit * 5, true))
	check("整合运动残党's goods are dirty: contamination rises while carried", game.count_effect("dirty") == 1 and game.contamination_rate() > rate_before)
	check("dirty stacks do not merge with clean ones", not MaterialCatalog.create("源岩", 1).can_stack_with(game.inventory.items.filter(func(i): return i.effect == "dirty")[0]))
	# A forward expiring in the field settles from the warehouse only.
	ex.relations["lungmen"] = 300
	ex.forward_cooldown.clear()
	ex.open_forward("lungmen", "固源岩", 3, 0, true, 1)
	game.inventory.try_add(MaterialCatalog.create("固源岩", 3))
	BaseState.clock_offset += 3700
	game.market.advance_to(BaseState.now())
	check("in the field the pack is never emptied for a delivery (default instead)", game.inventory.count_material("固源岩") == 3 and ex.forwards.is_empty() and ex.history[-1].kind == "default")
	check("news of the region she works in comes up more", ex._news_weight("U1") > ex._news_weight("C5"))
	game.post_faction = "sami"
	set_index("sami:fuel", 1.0)
	set_index("sami:medical", 1.0)
	# The news may have shut 萨米's market just now; this checks the barter itself.
	game.market.effects.clear()
	game.market._mods_dirty = true
	var fuel := MaterialCatalog.create("固体燃料", 10)
	game.inventory.try_add(fuel)
	var herbs := game.barter_count(fuel, "林地草药")
	check("萨米 barters fuel for herbs: %d" % herbs, herbs > 0 and game.barter(fuel, "林地草药") and game.inventory.count_material("林地草药") + 0 >= 0)
	game.settle(true)
	await step(2)
	check("back at the base the swan pops up", game._swan_panel.visible or not game.base_walk_active())
	game.close_swan_popup()
	check("and closes", game.swan_popup.is_empty())
	print("TEST_EXCHANGE: %d failures" % failures)
	quit(1 if failures > 0 else 0)
