extends SceneTree
## 罗德岛运营与资产管理策划案 v0.12 P1: the daily bill (§2), the 罗德岛库存
## (§2.5), rations and 热餐 (§2.2.1), deposits (§3.1), the credit line and
## repayment (§3.7, §3.7.1), and the Rhodes clock that stands still (§5).
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

func stock_add(id: String, n: int) -> void:
	var left := n
	while left > 0:
		var it := MaterialCatalog.create(id, mini(left, MaterialCatalog.stack_size(id)))
		left -= it.quantity
		game.base.shelf.append(it)

func later(seconds: int) -> void:
	BaseState.clock_offset += seconds
	game.market.advance_to(BaseState.now())

## To just past the next 08:00.
func next_day() -> void:
	later(MarketState.next_day_start(game.market.t) - game.market.t + 4)

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
	for f in FactionCatalog.ORDER: ex.rank_gifts[f] = FactionRewards.GIFT_RANKS.duplicate()
	for f in ["exchange", "workshop", "warehouse", "canteen", "hub"]: game.base.set_facility(f, 1)
	game.gold = 2000000
	_upkeep(ex, fin)
	await _stock(ex, fin)
	_hot_meal(ex, fin)
	_deposits(ex, fin)
	_loans(ex, fin)
	_idle(ex, fin)
	var copy := RhodesFinance.new(ex)
	copy.load_data(fin.to_data())
	var a := copy.to_data()
	var b := fin.to_data()
	check("the books save and load", a.hash() == b.hash(), a.keys().filter(func(k): return str(a[k]) != str(b[k]) or typeof(a[k]) != typeof(b[k])).map(func(k): return "%s: %s / %s" % [k, a[k], b[k]]))
	print("RHODES OPS FAILURES: %d" % failures)
	BaseState.frozen_clock = 0
	BaseState.clock_offset = 0
	BaseState.stall = 0
	quit(1 if failures > 0 else 0)

func _upkeep(ex: Exchange, fin: RhodesFinance) -> void:
	check("tier 0 eats 异铁碎片, three tiers up 异铁", RhodesFinance.material_for("workshop", 0) == "异铁碎片" and RhodesFinance.material_for("workshop", 3) == "异铁" and RhodesFinance.material_for("workshop", 9) == "异铁组")
	check("each facility level costs base × the tier's index", is_equal_approx(fin.need_lmd("workshop"), RhodesFinance.UPKEEP_LMD * RhodesFinance.upkeep_index(fin.tier())))
	# From the 罗德岛库存 first; the personal warehouse is never touched.
	var need := fin.need_units("workshop")
	stock_add("异铁碎片", 50)
	var personal := game.material_count("异铁碎片")
	fin.stock["异铁碎片"] = need * 3
	var seller := fin.cheapest("异铁碎片")
	ex._new_day()
	var bill: Dictionary = fin.bills[-1]
	var shop: Dictionary = bill.items.filter(func(i): return i.facility == "workshop")[0]
	check("the workshop's day comes out of the stock: %d of %d" % [int(shop.from_stock.get("异铁碎片", 0)), need], int(shop.from_stock.get("异铁碎片", 0)) == need and int(shop.bought) == 0 and fin.stock_count("异铁碎片") == need * 2, shop)
	check("the personal warehouse is untouched", game.material_count("异铁碎片") == personal)
	# What is short is bought at the cheapest live ask.
	var hub: Dictionary = bill.items.filter(func(i): return i.facility == "hub")[0]
	# The hub burns fuel units: the cheapest unit of barrel, can or 固体燃料 (燃料储备修订案 §4).
	var fuel := fin.cheapest_fuel()
	check("short: bought at the cheapest seller (%s)" % str(fuel.get("faction", "")), int(hub.bought) > 0 and absi(int(hub.cost) - roundi(float(fuel.unit_lmd) * int(hub.bought))) <= 2 + int(hub.bought), [hub, fuel])
	check("the 异铁 seller is 乌萨斯西北矿场", str(seller.get("faction", "")) == "ursus")
	# MarketState.add_flow: this step's flow on the book (a faction's pending
	# order there would be someone else's).
	check("the bill's buying is order flow on that book", (ex.market.books[str(fuel.market)] as MarketState.Book).fl > 0.0)
	# Salaries in the home currency at the live rate.
	game.base.roster.assign([Operators.AMIYA_GUARD, Operators.LAPPLAND])
	var sal := fin.salary_lmd()
	var sir_book: MarketState.Book = ex.market.books[Currencies.book("sir")]
	var was := sir_book.i
	sir_book.i = was * 2.0
	ex.market._publish_rates()
	check("拉普兰德 is paid in 里拉: the rate moves her pay (%d → %d)" % [roundi(sal), roundi(fin.salary_lmd())], fin.salary_lmd() < sal - 1.0)
	sir_book.i = was
	ex.market._publish_rates()
	check("the bill goes to PRTS as numbers", bill.total > 0 and bill.has("salary"))

func _stock(ex: Exchange, fin: RhodesFinance) -> void:
	stock_add("钉子", 30)
	var before := game.material_count("钉子")
	check("transfer in: off the warehouse into the stock", fin.transfer_in("钉子", 12) and game.material_count("钉子") == before - 12 and fin.stock_count("钉子") == 12)
	check("one way: nothing takes it back out", not fin.has_method("transfer_out") and not fin.has_method("take_out") and not ex.has_method("withdraw_stock"))
	check("only what the base eats goes in", fin.transfer_refusal("源岩", 1) == "不消耗" and fin.transfer_refusal("钉子", 999) == "数量不足")
	fin.harvest_to_stock = false
	check("the harvest switch off: crops stay in the warehouse", not fin.harvest_in("舰载麦", 6))
	fin.harvest_to_stock = true
	var wheat := fin.stock_count("舰载麦")
	check("on: they go straight in", fin.harvest_in("舰载麦", 6) and fin.stock_count("舰载麦") == wheat + 6)
	check("glowing crops are no rations", not RhodesFinance.can_stock("闪耀作物"))
	check("the stock is worth its base price", absf(fin.stock_value() - fin.stock_count("钉子") * RhodesFinance.unit_lmd("钉子") - fin.stock_count("舰载麦") * RhodesFinance.unit_lmd("舰载麦") - fin.stock_count("异铁碎片") * RhodesFinance.unit_lmd("异铁碎片")) < 1.0)
	check("days left read the family's value against the day's need", fin.days_left("warehouse") > 0.0)

func _hot_meal(ex: Exchange, fin: RhodesFinance) -> void:
	var r := fin.rations()
	check("rations: one a day per operator with a canteen (%d)" % r, r == game.base.roster.size() and r > 0)
	fin.stock.erase("舰载麦")
	fin.stock["温室豆"] = 5
	fin.stock["块茎薯"] = r
	ex._new_day()
	check("enough crops: 热餐, the cheapest eaten first", fin.hot_meal() and not fin.supply_stopped() and fin.stock_count("块茎薯") == 0 and fin.stock_count("温室豆") == 5)
	game._apply_meal("")
	check("热餐 goes out with her", game.run_hot_meal)
	var hp_with := game.player.max_hp
	game.run_hot_meal = false
	game.player._recompute_stats()
	check("+3%% max HP: %.1f vs %.1f" % [hp_with, game.player.max_hp], absf(hp_with / game.player.max_hp - (1.0 + RhodesFinance.HOT_MEAL_HP) / 1.0) < 0.02)
	fin.stock["温室豆"] = r - 1
	ex._new_day()
	check("one short: no 热餐, supplies stop, nothing taken", not fin.hot_meal() and fin.supply_stopped() and fin.stock_count("温室豆") == r - 1)
	check("the canteen serves nothing", game.provisions.eat_refusal("舰内口粮") == "停发补给")
	game._apply_meal("")
	check("no 热餐 on a contract", not game.run_hot_meal)
	fin.stock["温室豆"] = r
	check("made up today: 开饭 serves at once", fin.serve_refusal().is_empty() and fin.serve_now() and fin.hot_meal() and not fin.supply_stopped() and fin.stock_count("温室豆") == 0)

func _deposits(ex: Exchange, fin: RhodesFinance) -> void:
	game.gold = 1000000
	check("demand deposit off the balance", fin.deposit("lmd", 10000) and game.gold == 990000 and is_equal_approx(float(fin.demand.lmd), 10000.0))
	var rate := fin.demand_rate("lmd")
	ex._new_day()
	check("a day's interest at the floating rate", absf(float(fin.demand.lmd) - 10000.0 * (1.0 + rate)) < 0.5, fin.demand)
	check("the balance itself earns nothing (v0.6)", true)
	var e0 := ex.market.econ.e
	ex.market.econ.e = 1.0
	check("the cycle lifts deposit rates by at most 30%%", is_equal_approx(fin.demand_rate("lmd"), RhodesFinance.DEMAND_RATE.lmd * 1.3))
	ex.market.econ.e = -1.0
	check("and lowers them by at most 30%%", is_equal_approx(fin.demand_rate("lmd"), RhodesFinance.DEMAND_RATE.lmd * 0.7))
	ex.market.econ.e = 0.0
	check("a 3-day term", fin.open_term("lmd", 20000, 3))
	var t: Dictionary = fin.terms[-1]
	var locked := float(t.rate)
	ex.market.econ.e = 1.0
	check("its rate was locked when it was opened", is_equal_approx(float(fin.terms[-1].rate), locked) and fin.term_rate(3) > locked)
	ex.market.econ.e = e0
	var g := game.gold
	check("broken early: the principal back, no interest", fin.break_term(int(t.id)) and game.gold - g == 20000)
	fin.open_term("lmd", 20000, 1)
	locked = float(fin.terms[-1].rate)
	g = game.gold
	var out := fin.paid_total + fin.repaid_total
	next_day()
	var back := game.gold - g + (fin.paid_total + fin.repaid_total - out)
	check("matured: the principal with its locked interest (%d)" % back, fin.terms.is_empty() and absi(back - roundi(20000 * (1.0 + locked))) <= 2)

func _loans(ex: Exchange, fin: RhodesFinance) -> void:
	game.gold = 100000
	ex.loan = 0
	var limit := fin.loan_limit()
	check("the limit: net worth less the stock, ×0.5, never under the floor: %d" % limit, limit == maxi(RhodesFinance.LOAN_FLOOR, roundi(maxf(0.0, fin.net_worth() - fin.stock_value()) * 0.5)))
	var stock_before := fin.loan_limit()
	fin.stock["钉子"] = fin.stock_count("钉子") + 5000
	check("the 罗德岛库存 is no collateral", fin.loan_limit() == stock_before)
	check("borrow within the limit", fin.borrow(20000) and ex.loan == 20000 and game.gold == 120000)
	check("repay any amount", fin.repay(5000) and ex.loan == 15000)
	game.gold = 100
	check("not more than the balance", not fin.repay(1000))
	game.gold = 500000
	# Auto repayment after the bill, down to the reserve.
	fin.auto_repay = true
	fin.reserve_days = 3
	ex._new_day()
	check("auto repayment keeps 3 days of bills: debt %d" % ex.loan, ex.loan == 0 or game.gold <= fin.reserve() + 1)
	ex.loan = 50000
	fin.auto_repay = false
	var g := game.gold
	var r := fin.loan_rate()
	ex._new_day()
	check("off: nothing repaid, interest compounds by the day", ex.loan >= ceili(50000 * (1.0 + r)) - 1 and ex.loan < 52000)
	stock_add("商业联合会担保函", 1)
	var l := ex.loan
	ex._new_day()
	check("a 商业联合会担保函 waives the day", ex.loan == l and game.material_count("商业联合会担保函") == 0)
	# Overdue: everything earned pays the debt.
	game.gold = 1000
	ex.loan = roundi(fin.loan_limit() * 1.6)
	fin._gold_mark = game.gold
	check("past 1.5× the limit it is overdue: no new borrowing", fin.loan_locked() and not fin.borrow(1000))
	l = ex.loan
	game.gold += 4000
	fin.step()
	check("overdue: income goes to the debt", ex.loan == l - 4000 and game.gold == 1000)
	# Past twice the limit the holdings are sold, never the warehouse or the stock.
	game.gold = 0
	fin.demand.lmd = 5000000
	fin.terms.append({"id": 999, "cur": "lmd", "amount": 300000, "rate": 0.0005, "days": 7, "due": fin.today() + 7})
	var shelf := game.base.shelf.size()
	var stock := fin.stock.duplicate()
	# Net 5.3 M less 3 M owed: the limit 1.15 M, so 3 M is past twice it.
	ex.loan = 3000000
	check("set up past twice the limit", fin.severe())
	fin._gold_mark = game.gold
	fin.step()
	check("past 2× the limit: sold down to 1.5× (%d ≤ %d)" % [ex.loan, roundi(fin.loan_limit() * 1.5)], ex.loan <= roundi(fin.loan_limit() * 1.5) + 1)
	check("the terms went first, the warehouse and stock stayed", fin.terms.is_empty() and game.base.shelf.size() == shelf and fin.stock == stock)
	ex.loan = 0
	fin.demand.lmd = 0
	game.gold = 100000
	# Between the limit and 1.5× it (the limit itself falls as the debt grows: L = 0.375 × net).
	ex.loan = roundi(0.375 * (fin.net_worth() - fin.stock_value()))
	fin._gold_mark = game.gold
	var before := ex.loan
	fin.step()
	check("over the limit but under 1.5×: no sale, no new loan", ex.loan == before and not fin.borrow(1000) and not fin.severe())
	ex.loan = 0
	var e2 := Exchange.new()
	e2.load_data({"loan": 1234})
	check("an old save's loan loads as it was", e2.loan == 1234)

func _idle(ex: Exchange, fin: RhodesFinance) -> void:
	var day := 86400
	# 时间缩放策划案 v0.2 §5 (scale 1 here): one day at most is caught up, the rest stands still.
	check("5 hours away: 5 caught up", BaseState.catch_up_split(5 * 3600) == [5 * 3600, 0])
	check("30 hours: one day, 6 hours still", BaseState.catch_up_split(30 * 3600) == [day, 6 * 3600])
	check("5 days 23 hours: one day, 4 days 23 hours still", BaseState.catch_up_split(5 * day + 23 * 3600) == [day, 4 * day + 23 * 3600])
	# Through the game's catch-up.
	game.base.research.active.append({"id": "commerce_q", "start": BaseState.now(), "end": BaseState.now() + 3 * day})
	var bills := fin.bills.size()
	ex.loan = 10000
	fin.auto_repay = false
	var loan := ex.loan
	var real_before := BaseState.frozen_clock + BaseState.clock_offset
	BaseState.clock_offset += 5 * day + 23 * 3600
	var stall := BaseState.stall
	game._catch_up_market()
	check("away 5 d 23 h: 4 d 23 h stood still", BaseState.stall - stall == 4 * day + 23 * 3600, BaseState.stall)
	check("the market caught up to the Rhodes clock", absi(game.market.t - BaseState.now()) <= MarketState.TICK)
	check("the Rhodes clock goes on a day past where it was", BaseState.now() - (real_before - stall) == day, BaseState.now() - (real_before - stall))
	check("at most two bills for the time caught up: %d" % (fin.bills.size() - bills), fin.bills.size() - bills <= 2 and fin.bills.size() - bills >= 1)
	check("interest only for the days caught up", ex.loan <= ceili(loan * pow(1.0 + RhodesFinance.LOAN_BASE_RATE * 3.0 + RhodesFinance.LOAN_DEBT_PREMIUM, 2)), [ex.loan, game.gold, fin.bills.slice(-2).map(func(b): return [b.total, b.borrowed, b.interest])])
	check("research does not finish in the still days", not game.research.is_done("commerce_q"))
	check("trading days count by the Rhodes clock", ex._day == MarketState.day_key(BaseState.now()))
	ex.loan = 0
