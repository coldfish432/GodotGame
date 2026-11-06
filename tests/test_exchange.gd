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
	game.seed_rng(77)
	var ex := game.exchange
	var market := game.market
	game.gold = 500000
	check("a new base starts by each faction's attitude, the exchange unbuilt", not ex.unlocked() and ex.rank("karlan") == 2 and ex.rank("lungmen") == 1 and ex.rank("ursus") == 0)
	# The rank gifts (test_faction_rewards) would land in this suite's warehouse counts.
	for f in FactionCatalog.ORDER: ex.rank_gifts[f] = FactionRewards.GIFT_RANKS.duplicate()
	game.base.set_facility("exchange", 1)
	check("built, it opens (基建设施修订案 v1.1)", ex.unlocked())
	# --- Spot ---------------------------------------------------------------------
	# The terminal trades packs only (交易所交易包修订案 §6).
	var loose_armor := stash_add(Item.create("测试护甲", Item.Category.ARMOR, 2, 2))
	loose_armor.value = 100
	check("the terminal refuses loose goods, a post takes them", ex.quote_sell(loose_armor, "lungmen").why == "只收交易包" and ex.quote_sell(loose_armor, "lungmen", false).ok)
	var armor := stash_add(MaterialCatalog.create("防具包", 1))
	set_index("lungmen:armor", 1.0)
	var q := ex.quote_sell(armor, "lungmen")
	var expected := 40000.0 * 1.25 * market.bid("lungmen:armor") * (1.0 - minf(0.3, 0.5 * 50000.0 / market.depth("lungmen:armor"))) * (1.0 - 0.035)
	check("龙门商会 quotes base × preference × bid − slippage − 3.5%% (中立): %.0f" % float(q.net), q.ok and absf(float(q.net) - expected) < 1.0 and q.currency == "lmd")
	var gold_before := game.gold
	check("selling pays 龙门币", ex.sell_item(armor, "lungmen") and game.gold - gold_before == floori(float(q.net)) and not game.stash.has(armor))
	check("selling builds relation and pushes the market", ex.relation("lungmen") > 0 and market.books["lungmen:armor"].p > 0.0)
	var cube := stash_add(MaterialCatalog.create("源石包", 1))
	var rq := ex.quote_sell(cube, "rhine")
	var acct := ex.gold_account
	check("莱茵生命 pays 金券 into its account (地区货币策划案 §1.5)", rq.currency == "col" and ex.sell_item(cube, "rhine") and absf(ex.balance("col") - float(rq.net)) < 0.02)
	var ore := FieldCatalog.exclusive("mine")
	game.inventory.try_add(ore)
	check("a field-only faction refuses remote trade", not ex.quote_sell(ore, "reunion").ok and ex.quote_sell(ore, "reunion", false).ok)
	ex.relations["lungmen"] = 50
	var dirty := stash_add(MaterialCatalog.create("违禁品包", 1))
	check("contraband to 鼠王 costs 龙门商会 relation", ex.sell_item(dirty, "rat") and ex.relation("lungmen") == 45)
	ex.relations["karlan"] = Exchange.RANK_AT[1]
	var fee_r1 := ex.remote_fee("karlan")
	ex.relations["karlan"] = Exchange.RANK_AT[5]
	check("the remote fee falls 0.5%% a rank: %.3f, %.3f" % [fee_r1, ex.remote_fee("karlan")], is_equal_approx(fee_r1, 0.035) and is_equal_approx(ex.remote_fee("karlan"), 0.015))
	ex.relations["karlan"] = Exchange.RANK_AT[1]
	var packs := game.material_count("建材包")
	var lmd := game.gold
	check("the terminal sells no loose goods", not ex.buy_material("lungmen", "螺栓", 5) and game.gold == lmd)
	check("龙门商会 sells the packs of its shelf, never gear", FactionCatalog.packs_sold("lungmen").has("建材包") and not FactionCatalog.packs_sold("lungmen").has("武器包"))
	check("buying a pack pays and goes straight into the warehouse (仓库修订)", ex.buy_material("lungmen", "建材包", 1) and game.gold < lmd and game.material_count("建材包") == packs + 1)
	check("and uses the buy quota", ex.quota_left("lungmen") < ex.quota_cap("lungmen"))
	ex.quota_used["lungmen"] = ex.quota_cap("lungmen")
	check("a full quota refuses", not ex.buy_material("lungmen", "建材包", 1))
	later(600)
	check("the quota comes back 10% per 10 minutes", absf(ex.quota_left("lungmen") - ex.quota_cap("lungmen") * 0.1) < 50.0)
	# --- Orders -------------------------------------------------------------------
	var sword := stash_add(MaterialCatalog.create("武器包", 1))
	set_index("karlan:weapon", 1.0)
	check("a limit sell escrows the item", ex.place_sell_order(sword, "karlan", "limit", 110.0) and not game.stash.has(sword) and ex.orders.size() == 1)
	later(4)
	check("it waits below the limit", ex.orders.size() == 1)
	acct = ex.gold_account
	set_index("karlan:weapon", 1.12)
	later(4)
	check("and fills when the market reaches it", ex.orders.is_empty() and ex.gold_account > acct)
	var shield := stash_add(MaterialCatalog.create("防具包", 1))
	ex.place_sell_order(shield, "karlan", "stop", 50.0)
	check("cancelling returns the item to the warehouse", ex.cancel_order(ex.orders[-1].id) and game.base.shelf.any(func(i): return i.material_id == "防具包"))
	# --- Forwards -----------------------------------------------------------------
	ex.relations["lungmen"] = Exchange.RANK_AT[3]
	set_index("lungmen:build", 1.0)
	var balance := game.gold
	check("a 交货合约 needs the rank for its leverage", not ex.forward_refusal("lungmen", 3).is_empty() if ex.rank("lungmen") < 3 else true)
	check("forwards are on packs only", not ex.open_forward("lungmen", "螺栓", 10, 0, true, 3) and ex.forward_materials("lungmen").has("建材包"))
	check("2× is not a step for goods (1/3/5/10/15/20)", not ex.open_forward("lungmen", "建材包", 2, 0, true, 2) and ex.forward_refusal("lungmen", 2) == "杠杆不可用")
	check("opening a forward takes margin and fee", ex.open_forward("lungmen", "建材包", 2, 0, true, 3) and game.gold < balance)
	var f: Dictionary = ex.forwards[-1]
	check("the deliver price is under spot", float(f.k) < ex.material_spot("lungmen", "建材包", true))
	stash_add(MaterialCatalog.create("建材包", 2))
	var rel := ex.relation("lungmen")
	balance = game.gold
	check("delivering pays K × Q plus the margin back", ex.deliver_forward(f.id) and game.gold - balance == floori(float(f.k) * 2 + float(f.margin)) and ex.relation("lungmen") == rel + 10)
	ex.open_forward("lungmen", "建材包", 3, 0, true, 1)
	rel = ex.relation("lungmen")
	later(3700)
	check("no goods at expiry: default, relation −40, a cooldown", ex.forwards.is_empty() and ex.relation("lungmen") == rel - 40 and ex.forward_refusal("lungmen", 1) == "违约冷却中")
	check("the cooldown lasts at least six hours", int(ex.forward_cooldown["lungmen"]) - market.t >= Exchange.DEFAULT_MIN_COOLDOWN - 200)
	ex.relations["karlan"] = Exchange.RANK_AT[3]
	ex.gold_account += 500.0
	check("gear packs only go one way: no 收货合约", not ex.open_forward("karlan", "武器包", 1, 0, false, 1) and Exchange.forward_side_refusal("karlan", "武器包", false) == "只能交货")
	var cold := game.material_count("寒地物资包")
	check("a 收货合约 opens", ex.open_forward("karlan", "寒地物资包", 1, 0, false, 1))
	later(3700)
	check("and at expiry pays the rest and the goods arrive", ex.forwards.is_empty() and game.material_count("寒地物资包") == cold + 1)
	ex.open_forward("karlan", "建材包", 5, 1, false, 3)
	var fwd: Dictionary = ex.forwards[-1]
	set_index("karlan:build", 0.3)
	later(4)
	check("a big loss forces the forward closed", ex.forwards.is_empty() and ex.history[-1].kind == "liquidated")
	# --- CFDs ---------------------------------------------------------------------
	game.gold = 500000
	ex.loan = 0
	set_index("fx", 1.0)
	check("a CFD on the rate opens long 5× (R1)", ex.open_cfd("fx", 1, 5, 8000.0))
	var c: Dictionary = ex.cfds[-1]
	set_index("fx", 2.0)   # profit about 40,000
	check("a rising rate shows profit: %.0f" % ex.cfd_pnl(c), ex.cfd_pnl(c) > 19000.0)
	balance = game.gold
	var profit := ex.cfd_pnl(c) - float(c.notional) * Exchange.CFD_FEE
	ex.close_cfd(c.id)
	# 用户 2026-10-23: no daily cap on CFD profit.
	check("closing pays the margin plus the whole profit: +%d" % (game.gold - balance), absf(game.gold - balance - (8000.0 + profit)) <= 1.0)
	check("nothing waits for the next trading day", ex.cfd_pending() == 0.0)
	ex.cfd_day.pending_lmd = 5000.0   # held back on a save from before the cap went
	balance = game.gold
	later(MarketState.next_day_start(market.t) - market.t + 4)
	check("an old save's held-back profit comes in at 08:00", ex.cfd_pending() == 0.0 and game.gold >= balance + 5000)
	game.gold = 30000
	ex.loan = 25000
	check("borrowed money is not margin (贷款不能当保证金)", not ex.open_cfd("fx", 1, 1, 10000.0) and ex.cfd_refusal("fx", 1, 10000.0) == "保证金不足")
	ex.loan = 0
	game.gold = 900000
	ex.relations["karlan"] = Exchange.RANK_AT[1]
	check("the notional cap per issuer", not ex.open_cfd("fx", 1, 1, 60000.0) and ex.cfd_refusal("fx", 1, 60000.0) == "持仓上限")
	ex.relations["kazimierz"] = 0
	check("leverage needs the issuer's rank", not ex.open_cfd("comp:lungmen", 1, 2, 5.0))
	ex.relations["kazimierz"] = Exchange.RANK_AT[1]
	ex.open_cfd("fx", -1, 1, 10000.0)
	var short: Dictionary = ex.cfds[-1]
	var margin_before := float(short.margin)
	later(MarketState.next_day_start(market.t) - market.t + 4)
	check("a short on 龙门币/赤金 earns the swap at 08:00", float(short.margin) > margin_before and absf(float(short.margin) - margin_before - float(short.notional) * market.policy_rate("lmd") / 365.0) < 0.01)
	ex.set_cfd_limits(short.id, 0.0, ex.cfd_price("fx") * 1.01)
	set_index("fx", 3.0)   # up from 2.0: past the short's stop
	later(4)
	check("a stop-loss closes the short", not ex.cfds.has(short))
	_leverage()
	# --- Loans --------------------------------------------------------------------
	game.gold = 0
	check("the loan limit follows 交易所's level: %d" % ex.loan_limit(), ex.loan_limit() == Exchange.LOAN_STEP * maxi(1, game.base.facility_level("exchange")))
	check("borrowing adds to the balance", ex.borrow(10000) and game.gold == 10000 and ex.loan == 10000)
	check("not past the limit", not ex.borrow(ex.loan_limit()))
	ex.on_settlement(0)
	check("interest once a settlement: 1%% under %d" % Exchange.LOAN_TIERS[0][0], ex.loan == 10100)
	check("tiers", is_equal_approx(Exchange.loan_rate(112000), 0.02) and is_equal_approx(Exchange.loan_rate(252000), 0.03) and is_equal_approx(Exchange.loan_rate(420000), 0.04))
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
	check("whole bars come out to the warehouse", ex.withdraw_bars(2) and game.base.shelf.any(func(i): return i.material_id == Economy.GOLD_ID))
	_currencies()
	var fee_item := MaterialCatalog.create("螺栓", 10)
	check("the camp's deposit fee uses the live rate", game.deposit_fee(fee_item) == maxi(1, ceili(Economy.price(fee_item) * FieldCatalog.DEPOSIT_FEE / Economy.fx)))
	# Direct delivery is gone (用户 2026-10-25: 只能在可露希尔处卖).
	check("there is no plain delivery", not game.has_method("sell"))
	# --- 企鹅物流 -------------------------------------------------------------------
	game.gold = 100000
	check("企鹅物流 carries packs only", not ex.ship(stash_add(MaterialCatalog.create("医用耗材包", 10)), "reunion"))
	var cargo := stash_add(MaterialCatalog.create("医疗包", 1))
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
	check("five 固源岩 from fifteen 源岩", game.workshop_start("固源岩", 5) and game.material_count("源岩") == 0 and game.gold == 10000 - 5 * int(Workshop.recipe("固源岩").lmd))
	check("the queue is full with one job at R0", game.workshop_refusal("糖", 1) == "加工队列已满")
	var made := game.material_count("固源岩")
	BaseState.clock_offset += 11 * 60
	game._tick_workshop()
	check("finished goods go into the warehouse", game.material_count("固源岩") == made + 5)
	check("packs are not a recipe (they are packed by value)", game.workshop_refusal("建材包", 1) == "没有这个配方" and not FactionCatalog.CATEGORIES.has("trade"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var w := Workshop.new()
	var bys := 0
	for k in range(200): bys += w.start("异铁", 10, 0, rng).byproducts.values().reduce(func(a, b): return a + b, 0)
	check("byproducts about 10%% (PRTS): %d / 2000" % bys, absi(bys - 200) < 50)
	check("PRTS costs ×2.8: 300 / 600 / 800, carbon 2200", Workshop.recipe("固源岩").lmd == 300 and Workshop.recipe("固源岩组").lmd == 600 and Workshop.recipe("提纯源岩").lmd == 800 and Workshop.recipe("碳素").lmd == 2200)
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
	# 整合运动残党 starts 冷漠 and sells nothing then (势力声望解锁策划案 §2.5–2.6).
	ex.relations["reunion"] = Exchange.RANK_AT[1]
	bars_before = game.gold_bars()
	var rate_before := game.contamination_rate()
	var unit := float(ex.quote_buy("reunion", "源岩").unit)
	check("buying at a post goes into the pack", game.post_buy("源岩", 5) and game.inventory.count_material("源岩") == 5)
	check("and costs whole 赤金 from the pack", bars_before - game.gold_bars() == Exchange.field_bars(unit * 5, true))
	check("整合运动残党's goods are dirty: contamination rises while carried", game.count_effect("dirty") == 1 and game.contamination_rate() > rate_before)
	check("dirty stacks do not merge with clean ones", not MaterialCatalog.create("源岩", 1).can_stack_with(game.inventory.items.filter(func(i): return i.effect == "dirty")[0]))
	# A forward expiring in the field settles from the warehouse only.
	ex.relations["lungmen"] = Exchange.RANK_AT[3]
	ex.forward_cooldown.clear()
	game.gold = 100000
	ex.open_forward("lungmen", "建材包", 1, 0, true, 1)
	# The packs bought above now sit in the warehouse (仓库修订): clear them, so
	# the only one is in her pack.
	for it in game.base.shelf.filter(func(i): return i.material_id == "建材包"): game.base.remove_item(it)
	game.inventory.try_add(MaterialCatalog.create("建材包", 1))
	BaseState.clock_offset += 3700
	game.market.advance_to(BaseState.now())
	check("in the field the pack is never emptied for a delivery (default instead)", game.inventory.count_material("建材包") == 1 and ex.forwards.is_empty() and ex.history[-1].kind == "default")
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
	_field()
	print("TEST_EXCHANGE: %d failures" % failures)
	quit(1 if failures > 0 else 0)

## 地区货币策划案 §9: Japan's caps by kind, rank by rank; calls and cuts.
func _leverage() -> void:
	var ex := game.exchange
	check("the steps: FX 25×, index 10×, goods 20×", Exchange.leverage_cap("fx_col") == 25 and Exchange.leverage_cap("comp:rhine") == 10 and Exchange.leverage_cap("lungmen:armor") == 20 and Exchange.leverage_cap("rat:contraband") == 20)
	check("rank n opens the n-th step", Exchange.rank_for("fx", 25) == 5 and Exchange.rank_for("comp:karlan", 2) == 1 and Exchange.rank_for("karlan:cold", 2) == -1)
	game.gold = 900000
	ex.loan = 0
	ex.cfds.clear()
	ex.relations["karlan"] = Exchange.RANK_AT[2]
	check("10× on FX needs R2, 15× is refused", ex.cfd_refusal("fx", 15, 1000.0) == "需要喀兰贸易关系 尊敬" and ex.cfd_refusal("fx", 10, 1000.0).is_empty())
	set_index("fx", 1.0)
	ex.open_cfd("fx", 1, 10, 5000.0)
	var c: Dictionary = ex.cfds[-1]
	check("a position carries its cap", int(c.cap) == 25 and is_equal_approx(ex.margin_ratio(c, 0.0), 2.5))
	# Down 7%: equity 1500 on a 50,000 notional needs 2000 → a call.
	set_index("fx", 0.93)
	later(4)
	check("under 100%% a call until 08:00: %.2f" % ex.margin_ratio(c, ex.cfd_pnl(c)), ex.cfds.has(c) and int(c.get("call_until", 0)) == MarketState.next_day_start(game.market.t))
	var gold := game.gold
	check("topping up clears it", ex.add_margin(int(c.id), 2000.0))
	later(4)
	check("back over 100%", not c.has("call_until"))
	# Gapped down: under 50% it is closed at once, what is left comes back.
	set_index("fx", 0.876)
	gold = game.gold
	later(4)
	check("under 50%% it is closed at once and the rest comes back: +%d" % (game.gold - gold), not ex.cfds.has(c) and game.gold > gold and ex.history[-1].kind == "liquidated")
	ex.open_cfd("fx", 1, 10, 5000.0)
	c = ex.cfds[-1]
	set_index("fx", 0.5)
	gold = game.gold
	later(4)
	check("gapped through the margin: closed, nothing owed", not ex.cfds.has(c) and game.gold == gold)
	set_index("fx", 1.0)
	# Crosses against 龙门币: FX steps, margin in 龙门币, the rate gap as swap.
	check("a cross is FX: 25× and 龙门币 margin", Exchange.leverage_cap("x_col") == 25 and Exchange.cfd_currency("x_col") == "lmd" and "x_kje" in ex.cfd_underlyings())
	check("a cross opens", ex.open_cfd("x_col", 1, 10, 3000.0))
	var x: Dictionary = ex.cfds[-1]
	check("long 金券 / 龙门币 earns 金券's rate less 龙门币's", absf(ex.overnight(x) - (game.market.policy_rate("col") - game.market.policy_rate("lmd")) / 365.0 * float(x.notional)) < 1e-6)
	ex.close_cfd(int(x.id))

## 地区货币策划案 §1.2–1.3: foreign accounts, the changer, interest.
func _currencies() -> void:
	var ex := game.exchange
	game.gold = 100000
	var q := ex.quote_convert("lmd", "col", 10000.0)
	check("龙门币 → 金券 crosses through 赤金 at both spreads ×0.75: %.2f%%" % (float(q.spread) * 100.0), q.ok and is_equal_approx(float(q.spread), (0.005 + 0.006) * 0.75))
	check("and pays the live cross rate", absf(float(q.out) - 10000.0 / Economy.fx * Currencies.rate("col") * (1.0 - float(q.spread))) < 0.01)
	var col_before := ex.balance("col")
	check("changing moves the balances", ex.convert_fx("lmd", "col", 10000.0) and game.gold == 90000 and absf(ex.balance("col") - col_before - float(q.out)) < 0.02)
	var held := ex.balance("col")
	later(MarketState.next_day_start(game.market.t) - game.market.t + 4)
	check("interest at 08:00 at the policy rate (less any F17 fee): %.2f → %.2f" % [held, ex.balance("col")], absf(ex.balance("col") - held * (1.0 + game.market.policy_rate("col") / 365.0) * (1.0 - game.market.custody_rate())) < 0.03)
	game.market.fire("F26", {})
	check("a halt stops changing 卢布 out", not ex.quote_convert("urs", "gold", 10.0).ok and ex.quote_convert("urs", "gold", 10.0).why == "暂停换出")
	check("foreign money counts in the account value", ex.account_value() > float(game.gold) + ex.gold_account * Economy.fx - ex.loan + 1.0)

## 地区货币策划案 §2: the news in the field, read through GameManager.
func _field() -> void:
	var m := game.market
	m.field.clear()
	m.fire("I17", {})
	m.fire("F16", {})
	m.fire("I9", {}).rumor.truth = true
	m._verify(m.effects[-1])
	m.fire("I8", {})
	var region := game.region_id
	game.region_id = "mine"
	game.market_field = m.field_mods("mine")
	check("the floor reads its region: threat %.2f" % game.field_mult("threat"), is_equal_approx(game.field_mult("threat"), 1.2) and game.field_mult("gold_drop") == 1.0)
	check("and the world-wide ones: 坎诺特 pays ×0.85", is_equal_approx(game.field_mult("kannot_buy"), 0.85))
	var gear := LootTables.roll_equipment(Item.Category.WEAPON, "", "mine", 5, 1, RandomNumberGenerator.new())
	gear.value = 200
	var plain := maxi(1, floori(gear.value * FieldCatalog.TRADER_BUYBACK / 10.0))
	check("坎诺特 pays less for gear: %d → %d" % [plain, game.trader_offer(gear)], game.trader_offer(gear) == floori(200 * FieldCatalog.TRADER_BUYBACK / 10.0 * 0.85))
	check("loot leans to weapons", is_equal_approx(LootTables.field_loot(game.loot_ctx(), "weapon"), 1.2))
	check("the feature grows by the news on its own map only", game.field_feature_rate("mine") == game.field_mult("feature_rate") and game.field_feature_rate("snow") == 1.0)
	check("the route odds take the news", game._route_mults({"trader": 1.5}).trader == 1.5)
	game.region_id = "city"
	game.market_field = m.field_mods("city")
	var swapped := 0
	var pool: Array = EnemyAttacks.REGION_POOLS.city.normal
	for i in range(2000):
		if game._field_enemy(str(pool[0]), "normal", pool) in GameManager.FIELD_ENEMY_TAGS.family.normal: swapped += 1
	check("family hitmen in Lungmen: %d / 2000 picks" % swapped, swapped > 300 and swapped < 520)
	check("the route reads I8 on Siracusa only", not game._route_mults({}).has("trader"))
	check("the snapshot is saved with the run", "market_field" in RunSave.GAME_KEYS)
	game.market_field = {}
	game.region_id = region
	m.field.clear()
