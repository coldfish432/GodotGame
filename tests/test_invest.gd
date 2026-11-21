extends SceneTree
## 罗德岛运营与资产管理策划案 v0.12 P3–P5: shares, bonds, funds and 赤金存单
## (§3.1, §3.3), the indicators and the ten strategy templates with their
## slots, stops and backtests (§4), and the terminal's new pages build (§6).
var game: GameManager
var failures := 0
const T0 := 1791972000
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool, detail: Variant = null) -> void:
	print(("PASS " if passed else "FAIL ") + label + ("" if passed or detail == null else "  " + str(detail)))
	if not passed: failures += 1

func later(seconds: int) -> void:
	BaseState.clock_offset += seconds
	game.market.advance_to(BaseState.now())

func run() -> void:
	# These checks are of the one-to-one clock (时间缩放策划案 v0.2: test_time_scale has the scaled one).
	BaseState.time_scale = 1
	MarketState.tz_override = 0
	_indicators()
	BaseState.frozen_clock = T0
	BaseState.stall = 0
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	game.fixed_market_seed = 33
	root.add_child(game)
	await step(8)
	game.seed_rng(33)
	for f in FactionCatalog.ORDER: game.exchange.rank_gifts[f] = FactionRewards.GIFT_RANKS.duplicate()
	game.base.set_facility("exchange", 1)
	game.gold = 10000000
	# Some history for the indicators and the backtest.
	for i in range(30): later(3 * 3600)
	_securities()
	_strategies()
	await _screens()
	print("INVEST FAILURES: %d" % failures)
	BaseState.frozen_clock = 0
	BaseState.clock_offset = 0
	quit(1 if failures > 0 else 0)

func _indicators() -> void:
	var x := PackedFloat64Array([44.34, 44.09, 44.15, 43.61, 44.33, 44.83, 45.10, 45.42, 45.84, 46.08, 45.89, 46.03, 45.61, 46.28, 46.28, 46.00, 46.03, 46.41, 46.22, 45.64])
	var rsi := Indicators.rsi(x, 14)
	check("RSI with Wilder's smoothing: %.2f" % rsi, rsi > 50.0 and rsi < 70.0)
	check("SMA", is_equal_approx(Indicators.sma(PackedFloat64Array([1, 2, 3, 4]), 2), 3.5))
	check("EMA seeds with the first value", is_equal_approx(Indicators.ema(PackedFloat64Array([2.0]), 10), 2.0))
	var long := PackedFloat64Array()
	for i in range(60): long.append(100.0 + i)
	var mac := Indicators.macd(long)
	check("MACD on a steady rise is positive", float(mac[0]) > 0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var b := PackedFloat64Array()
	var a := PackedFloat64Array()
	var w := PackedFloat64Array()
	var v := 100.0
	var u := 100.0
	for i in range(200):
		v *= exp(rng.randfn(0.0, 0.01))
		u *= exp(rng.randfn(0.0, 0.01))
		b.append(v)
		a.append(pow(v, 2.0) * 0.01 * exp(rng.randfn(0.0, 0.002)))
		w.append(u)
	var co := Indicators.cointegration(a, b)
	check("Engle–Granger finds a pair: β %.2f, t %.1f" % [float(co[1]), float(co[2])], bool(co[0]) and absf(float(co[1]) - 2.0) < 0.1)
	check("…and not two independent walks: t %.1f" % float(Indicators.cointegration(w, b)[2]), not bool(Indicators.cointegration(w, b)[0]))
	var labels := Indicators.kmeans([[0, 0], [0.1, 0], [0, 0.1], [5, 5], [5.1, 5], [5, 5.2]], 2)
	check("K-means keeps the two groups apart", labels[0] == labels[1] and labels[1] == labels[2] and labels[3] == labels[4] and labels[0] != labels[3])

func _securities() -> void:
	var ex := game.exchange
	var sec := ex.securities
	var m := game.market
	var g := game.gold
	check("buy shares of 黑钢国际 (金券, a change spread)", sec.buy_stock("blacksteel", 100000.0) and g - game.gold == ceili(100000.0 * 1.005))
	var n := sec.held("blacksteel")
	check("the shares at today's price: %.1f" % n, absf(n - 100000.0 / m.firms.share_price_lmd("blacksteel", m)) < 0.01 and absf(m.firms.holding("blacksteel", "rhodes") - n) < 1e-6)
	var lmd_before := game.gold
	sec.on_dividend("blacksteel", 2.0)
	check("a 金券 cash dividend lands as whole 龙门币 at the live rate", game.gold - lmd_before == roundi(Exchange.live_lmd("col", Exchange.from_lmd("col", n * 2.0))))
	check("its order is on the share book", m.actors.pending.has("s|blacksteel"))
	sec.buy_stock("sunvalley", 200000.0)
	var bars := game.material_count(Economy.GOLD_ID)
	sec.on_dividend("sunvalley", 2.0 * Economy.GOLD_BAR_LMD / maxf(sec.held("sunvalley"), 1.0) * sec.held("sunvalley") / sec.held("sunvalley") * 10.0)
	check("太阳谷工业 pays 实物赤金", game.material_count(Economy.GOLD_ID) > bars)
	sec.buy_stock("volvotech", 200000.0)
	var dev := game.material_count("装置")
	sec.on_dividend("volvotech", RhodesFinance.unit_lmd("装置") * 3.0 / maxf(sec.held("volvotech"), 1.0) * 5.0)
	check("沃尔沃特科钦斯基 pays in 装置", game.material_count("装置") > dev)
	g = game.gold
	check("sell them back", sec.sell_stock("blacksteel", n) and game.gold > g and sec.held("blacksteel") == 0.0)
	# Bonds.
	check("a 3-day 龙门币 bond", sec.buy_bond("lmd", 50000.0, 3))
	var bond: Dictionary = sec.bonds[-1]
	var p0 := sec.bond_price(bond)
	m.policy["lmd"] = float(m.policy.get("lmd", 0.02)) + 0.02
	check("its price falls as the rate rises: %.3f → %.3f" % [p0, sec.bond_price(bond)], sec.bond_price(bond) < p0)
	m.policy["lmd"] = float(m.policy["lmd"]) - 0.02
	g = game.gold
	sec.new_day()
	check("a day's coupon", game.gold > g)
	check("a 雷神工业 bond pays a spread over the rate", sec.bond_coupon("firm:raythean") > m.policy_rate("col") + 0.019)
	sec.buy_bond("firm:venezia", 50000.0, 7)
	var f: Dictionary = m.firms.firms.venezia
	var cash := float(f.cash)
	f.cash = -float(f.capital) * 5.0
	var count := sec.bonds.size()
	sec.new_day()
	check("its issuer under water: the bond defaults at 60%%", sec.bonds.size() == count - 1)
	f.cash = cash
	bond.due = ex.fin.today()
	sec.new_day()
	check("matured: the face back", not sec.bonds.has(bond))
	# Funds (货币精简与取整修订案 v1.0: bought with whole bars, paid out in 龙门币; no 赤金存单).
	game.base.receive(MaterialCatalog.create(Economy.GOLD_ID, 100))
	bars = ex.home_bars()
	check("a fund bought with whole bars from the warehouse", sec.buy_fund("karlan_fund", 20.4) and ex.home_bars() == bars - 20)
	var lmd_day := game.gold
	sec.new_day()
	check("it pays out in whole 龙门币 every day", game.gold > lmd_day)
	check("no 赤金存单 any more", not sec.has_method("buy_cert") and not sec.has_method("redeem_cert"))
	check("the holdings count toward net worth", sec.value_lmd() > 0.0 and ex.fin.holdings_lmd() >= sec.value_lmd() - 1.0)
	# Share CFDs.
	check("shares have CFDs too: 卡西米尔 firms by its union", ex.cfd_underlyings().has("stock:mieszko") and Exchange.cfd_issuer("stock:mieszko") == "kazimierz" and Exchange.cfd_issuer("stock:swire") == "karlan")
	check("priced in the firm's currency", absf(ex.cfd_price("stock:swire") - m.stock_price("swire")) < 1e-6 and Exchange.cfd_currency("stock:swire") == "lmd")
	var saved := Securities.new(ex)
	saved.load_data(sec.to_data())
	check("securities save and load", saved.to_data().hash() == sec.to_data().hash())

func _strategies() -> void:
	var ex := game.exchange
	var sts := ex.strategies
	check("no slots before 交易所 Lv3", sts.slots() == 0)
	game.base.set_facility("exchange", 3)
	check("Lv3: one slot", sts.slots() == 1)
	game.base.set_facility("exchange", 4)
	check("Lv4: two", sts.slots() == 2)
	game.base.research.done.append("commerce_q")
	check("量化交易: three at most", sts.slots() == 3)
	check("定投 and 套息 from the start, 成长估值 at Lv3, 配对 at Lv4", sts.unlocked("S8") and sts.unlocked("S10") and sts.unlocked("S1") and sts.unlocked("S4"))
	# Every template decides on its default pool without trouble.
	var ok := true
	for tpl in StrategyCatalog.ORDER:
		var st := {"id": 0, "tpl": tpl, "capital": 100000.0, "cash": 100000.0, "pos": {}, "params": StrategyCatalog.defaults(tpl), "pool": sts.default_pool(tpl), "state": {}, "trades": 0, "wins": 0, "marks": []}
		var w: Variant = sts.decide(st, sts.live_ctx())
		if w != null and not w is Dictionary: ok = false
	check("all ten templates decide", ok)
	var g := game.gold
	check("a strategy takes its capital", sts.create("S8", 100000.0, [], {"hours": 1, "amount": 20000}) and g - game.gold == 100000)
	sts.create("S10", 100000.0)
	sts.create("S1", 100000.0)
	check("the slots fill", sts.create_refusal("S3", 100000.0) == "槽位已满")
	var dca: Dictionary = sts.list[0]
	sts._round = -1
	sts.step()
	check("定投 buys on its first round", not dca.pos.is_empty())
	var carry: Dictionary = sts.list[1]
	var best := ""
	var r := -INF
	for c in Currencies.foreign():
		if game.market.policy_rate(c) > r:
			r = game.market.policy_rate(c)
			best = Currencies.book(c)
	check("套息 holds the highest-yield currency (short its book): %s" % best, carry.pos.has(best) and float(carry.pos[best].qty) < 0.0)
	var pos := ex.rhodes_positions()
	check("its positions are Rhodes' positions to the AI", pos.has(best))
	var eq := sts.equity(dca)
	dca.cash = float(dca.cash)
	sts.new_day()
	check("custody 0.05%% a day", sts.equity(dca) < eq)
	# Stop-loss: the curve falls past its line.
	dca.peak = sts.equity(dca) * 2.0
	g = game.gold
	sts._round = -1
	sts.step()
	check("past its drawdown it stops and pays back", not sts.list.has(dca) and game.gold > g)
	# Unpaid bills pause the strategies.
	ex.fin.arrears = 1000.0
	ex.fin._update_stops()
	check("unpaid bills pause them", ex.fin.facility_stopped("strategies") and sts.create_refusal("S8", 50000.0) == "欠费暂停")
	ex.fin.arrears = 0.0
	ex.fin._update_stops()
	# Backtests move nothing and are counted.
	var before := game.market.index("lungmen:armor")
	var pending := game.market.actors.pending.duplicate(true)
	var bt := sts.backtest("S5", 100000.0, ["lungmen:armor", "ursus:build"])
	check("a backtest replays the candles: %d points, %+.1f%%" % [(bt.get("equity", []) as Array).size(), float(bt.get("ret", 0.0)) * 100.0], (bt.get("equity", []) as Array).size() > 10 and (bt.bench as Array).size() == (bt.equity as Array).size())
	check("…and moves no book", game.market.index("lungmen:armor") == before and game.market.actors.pending.hash() == pending.hash())
	for i in range(StrategyCatalog.BACKTESTS_A_DAY): sts.backtest("S8", 50000.0)
	check("10 a day", not sts.backtest_refusal().is_empty())
	sts.liquidate_all("测试")
	check("liquidated, nothing left running", sts.list.is_empty())
	var copy := Strategies.new(ex)
	copy.load_data(sts.to_data())
	check("strategies save and load", copy.to_data().hash() == sts.to_data().hash())

func _screens() -> void:
	var menu := game.menu
	game.close_modal()
	game.open_modal("station")
	for t in [5, 6, 7]:
		ExchangeScreen.tab = t
		ExchangeScreen.build(menu)
		await step(2)
	check("资产 / 企业 / 策略 build", is_instance_valid(menu))
	menu.stash_tab = BaseScreens.RHODES_TAB
	BaseScreens.stash(menu)
	await step(2)
	ProvisionScreens.canteen_tab = 1
	ProvisionScreens.canteen(menu)
	await step(2)
	check("the 罗德岛库存 tab and the canteen's rations build", true)
	game.close_modal()
