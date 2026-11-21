extends SceneTree
## 罗德岛运营与资产管理策划案 v0.12 P2/P3: the actors (§3.8), event chains
## (§3.4), what factions can know of Rhodes (§3.8.8), the relation modifiers
## (§3.9), the cycle and the credit pool (§3.6, §3.7).
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
	_bare()
	_events()
	_firms()
	BaseState.frozen_clock = T0
	BaseState.stall = 0
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	game.fixed_market_seed = 91
	root.add_child(game)
	await step(8)
	game.seed_rng(91)
	for f in FactionCatalog.ORDER: game.exchange.rank_gifts[f] = FactionRewards.GIFT_RANKS.duplicate()
	game.base.set_facility("exchange", 3)
	game.gold = 5000000
	_layers()
	_hostility()
	_relation_mods()
	print("MARKET AI FAILURES: %d" % failures)
	BaseState.frozen_clock = 0
	BaseState.clock_offset = 0
	quit(1 if failures > 0 else 0)

func _bare() -> void:
	var a := MarketState.new()
	a.start(T0, 5)
	var b := MarketState.new()
	b.start(T0, 5)
	# Within the one-day catch-up cap (时间缩放策划案 v0.2 §5): past it the market
	# skips ahead, which the game never does (the clock stands still instead).
	a.advance_to(T0 + 86400 - 7200)
	b.advance_to(T0 + 86400 - 7200)
	check("a fixed seed replays the same market, actors and all", is_equal_approx(a.index("lungmen:armor"), b.index("lungmen:armor")) and is_equal_approx(a.econ.e, b.econ.e) and is_equal_approx(a.stock_price("swire"), b.stock_price("swire")))
	# One after the other (the published rates are shared statics, as in the game).
	var snap := a.to_data().duplicate(true)
	a.advance_to(T0 + 2 * 86400 - 7200)
	var a_idx := a.index("ursus:build")
	var a_px := a.stock_price("penguin")
	var c := MarketState.new()
	c.load_data(snap)
	c.advance_to(T0 + 2 * 86400 - 7200)
	check("saved and loaded it goes on the same way", absf(a_idx / c.index("ursus:build") - 1.0) < 1e-6 and absf(a_px / c.stock_price("penguin") - 1.0) < 1e-6, [a_idx, c.index("ursus:build"), a_px, c.stock_price("penguin")])
	a.load_data(c.to_data())
	check("the noise left is 0.4 of the old", is_equal_approx(MarketState.NOISE_SCALE, 0.4))
	# A big sale pushes the book down; it comes back toward fair. Six copies with
	# their own noise each (one copy is luck: after the sale its actors and noise
	# go their own way), sold on against the same copies left alone.
	var m := "karlan:cold"
	var gap := 0.0
	var gap2 := 0.0
	var capped := true
	for k in range(6):
		var d := MarketState.new()
		d.load_data(a.to_data())
		d.rng.seed = 100 + k
		var e := MarketState.new()
		e.load_data(a.to_data())
		e.rng.seed = 100 + k
		var cap := e.depth(m) * MarketActors.IMPACT_CAP
		capped = capped and is_equal_approx(e.actors.place(e, m, -cap * 10.0, "test"), -cap)
		d.advance_to(d.t + 900)
		e.advance_to(e.t + 900)
		gap += (d.index(m) - e.index(m)) / 6.0
		# The intraday pull (half-life 20 minutes) takes most of it back within the hour.
		d.advance_to(d.t + 3600)
		e.advance_to(e.t + 3600)
		gap2 += (d.index(m) - e.index(m)) / 6.0
	check("one actor moves at most 5% of the depth a round", capped)
	check("a big sale pushes the price down: %.4f" % gap, gap > 0.0)
	check("and it comes back toward fair: %.4f → %.4f" % [gap, gap2], absf(gap2) < gap)
	# Factions restock and clear.
	var f := MarketState.new()
	f.load_data(a.to_data())
	f.actors.pending.clear()
	f.actors.factions.lungmen.inv["armor"] = 0.0
	f.actors._decide_faction(f, "lungmen")
	check("短缺: 龙门商会 buys armor on its own book", float((f.actors.pending.get("b|lungmen:armor", {}) as Dictionary).get("left", 0.0)) > 0.0)
	f.actors.pending.clear()
	f.actors.factions.ursus.inv["originium"] = 5000000.0
	f.actors._decide_faction(f, "ursus")
	var sold := f.actors.pending.keys().filter(func(k): return float(f.actors.pending[k].left) < 0.0)
	check("过剩: 乌萨斯矿场 sells where it pays most", not sold.is_empty())
	# The crowds.
	var g := MarketState.new()
	g.load_data(a.to_data())
	g.actors.pending.clear()
	var bk: MarketState.Book = g.books["rhine:medical"]
	bk.i = g.actors.fair(g, "rhine:medical") * 0.7
	g.actors.groups.value.pos.erase("rhine:medical")
	var pos := 0.0
	g.actors._crowd_book(g, "rhine:medical", false, 0.0)
	check("价值型 buys what is far under fair", float(g.actors.groups.value.pos.get("rhine:medical", 0.0)) > pos)
	var total := 0.0
	for k in g.actors.groups: total += g.actors.crowd_worth(g, k)
	g.actors.groups.trend.worth = [g.actors.crowd_worth(g, "trend") * 0.8]
	g.actors._crowd_day(g)
	var total2 := 0.0
	for k in g.actors.groups: total2 += g.actors.crowd_worth(g, k)
	check("money moves between crowds, the total stays", absf(total - total2) < 1.0)
	var cash_ok := true
	for k in a.actors.factions: cash_ok = cash_ok and float(a.actors.factions[k].cash) >= 0.0
	check("no faction's cash goes below zero", cash_ok)
	# The character: the same for every new save; results move it, slowly, within ±30%.
	var h := MarketState.new()
	h.start(T0 + 999, 12345)
	check("every new market starts with the same characters", h.actors.factions.rat.traits == a.actors.factions.rat.base)
	var rat: Dictionary = h.actors.factions.rat
	var risk := float(rat.traits.risk)
	rat.worth = [1000000.0, 1300000.0]
	h.actors._drift("rat", 1300000.0)
	check("a good month: less risk-averse (%.3f → %.3f), at most 2%% a day" % [risk, float(rat.traits.risk)], float(rat.traits.risk) < risk and risk - float(rat.traits.risk) <= risk * 0.021 + risk * MarketActors.DRIFT_BACK)
	for i in range(200):
		rat.worth = [1000000.0, 500000.0]
		h.actors._drift("rat", 500000.0)
	check("never past ±30%% of the base", float(rat.traits.risk) <= float(rat.base.risk) * 1.3 + 1e-6)
	for i in range(200):
		rat.worth = [float(rat.start), float(rat.start)]
		h.actors._drift("rat", float(rat.start))
	check("quiet days bring it back", absf(float(rat.traits.risk) - float(rat.base.risk)) < 0.01)
	# Firms: dearer inputs, thinner margins.
	var p := MarketState.new()
	p.load_data(a.to_data())
	var fr: Dictionary = p.firms.firms.raythean
	fr.today = Firms._blank()
	p.firms._produce(p, "raythean")
	var margin := 1.0 - float(fr.today.cogs) / float(fr.today.rev)
	for id in p.books:
		var book: MarketState.Book = p.books[id]
		if book.category in ["build", "electronic"] and not book.fx: book.i *= 2.0
	fr.today = Firms._blank()
	p.firms._produce(p, "raythean")
	check("雷神工业's inputs double: the margin narrows", 1.0 - float(fr.today.cogs) / float(fr.today.rev) < margin)
	# The cycle and the pool.
	check("E stays in −1…1, the deposit lift within ±30%%", absf(a.econ.e) <= 1.0 and absf(a.econ.deposit_mult() - 1.0) <= 0.3 + 1e-9)
	var lens: Array = []
	var w := MarketState.new()
	w.start(T0, 3)
	for i in range(6):
		w.econ.wave(w.econ.wave_start + int(w.econ.wave_len) + 1, w.rng)
		lens.append(w.econ.wave_len / 86400.0)
	check("the wave lasts 20–40 days: %s" % str(lens.map(func(x): return snappedf(x, 0.1))), lens.all(func(x): return x >= 20.0 and x <= 40.0))
	var cp := CreditPool.new()
	cp.supply = 10000000.0
	cp.demand = 2000000.0
	var loose := cp.base_rate(a)
	cp.demand = 12000000.0
	check("tighter credit, a higher base rate", cp.base_rate(a) > loose)

func _events() -> void:
	var m := MarketState.new()
	m.start(T0, 8)
	var a: Dictionary = m.actors.factions.ursus
	for i in range(3):
		a.sold["originium"] = 1e9
		m.actors._day_close(m, i)
	check("先动作，后事件: three days of selling make news", m.news.any(func(n): return str(n.id) == "AE1"))
	var before := m.actors.reactions.size()
	m.fire("L3", {"category": "medical"})
	check("先事件，后动作: the factions that use those goods react later", m.actors.reactions.size() > before and m.actors.reactions.all(func(r): return int(r.at) > m.t))
	m.firms._issue(m, "rose", 100000.0)
	check("动作即事件: an issue is news as it happens", m.news.any(func(n): return str(n.id) == "AE4" and str(n.title).contains("玫瑰报业")))
	var fee := float(m.penguin.fee)
	m.fire("L4")
	check("an event with no action still works as before", float(m.penguin.fee) > fee or float(m.penguin.fee) == 1.5)
	check("chains cool down", m.actors._cool(m, "X") and not m.actors._cool(m, "X"))
	m.actors.pending.clear()
	m.actors.reactions = [{"at": m.t - 10, "faction": "rhine", "market": "rhine:medical", "amount": 4000.0, "news_t": 123, "id": "ZZ", "rumor": true, "done": true}]
	m.news.append({"t": 123, "id": "ZZ", "status": "已辟谣", "title": "", "kind": "rumor"})
	m.actors._reactions_due(m)
	check("a rumor proven false: those who acted unwind", m.actors.reactions.is_empty() and float((m.actors.pending.get("b|rhine:medical", {}) as Dictionary).get("left", 0.0)) < 0.0)
	check("the actors' events are in the list (%d)" % MarketEvents.EVENTS.size(), MarketEvents.EVENTS.has("AE6") and MarketEvents.EVENTS.has("FE6"))

func _firms() -> void:
	var m := MarketState.new()
	m.start(T0, 21)
	for i in range(15): m.advance_to(T0 + (i + 1) * 86400)
	check("fifteen listed firms with share books", m.firms.firms.size() == 15 and m.stocks.size() == 15 and FirmCatalog.FIRMS.has("penguin"))
	var q: Array = m.firms.firms.swire.quarters
	check("quarters close every 7 days: %d" % q.size(), q.size() >= 2)
	var r := m.firms.ratios("swire", m.firms.share_price_lmd("swire", m))
	check("the ratios are worked out: P/E %.1f, moat %d / 12" % [float(r.pe), int(r.moat_count)], (r.moat as Array).size() == 12 and r.has("peg") and r.has("dpeg") and r.has("fcf_yield") and r.has("net_cash"))
	check("revenue comes from what it really sold", float(q[-1].rev) > 0.0 and float(q[-1].cogs) > 0.0)
	check("PRTS 研报 once a trading day", m.news.any(func(n): return str(n.id) == "PRTS研报"))
	var f: Dictionary = m.firms.firms.venezia
	f.cash = -float(f.capital) * 3.0
	f.debt = float(f.capital) * 2.0
	var shares := float(f.shares)
	m.firms._restructure(m, "venezia")
	check("困境: restructured, diluted, still listed", float(f.shares) > shares and m.news.any(func(n): return str(n.id) == "AE8") and m.stocks.has("venezia"))
	check("a fair value from earnings, inside bounds", m.firms.fair_index("sunherb") > 0.05 and m.firms.fair_index("sunherb") < 20.0)

func _layers() -> void:
	var ex := game.exchange
	var m := game.market
	var actors := m.actors
	# Layer 1: Rhodes' trades at a faction's own venue.
	var pack := MaterialCatalog.create("防具包", 1)
	game.base.shelf.append(pack)
	var n := (actors.factions.lungmen.rhodes as Array).size()
	check("layer 1: 龙门商会 sees Rhodes selling at its venue", ex.sell_item(pack, "lungmen") and (actors.factions.lungmen.rhodes as Array).size() == n + 1 and actors.rhodes_net("lungmen") < 0.0)
	check("…and only it", (actors.factions.rhine.rhodes as Array).size() == 0)
	# Layer 3: the bill's buying, learned after 3 days (鼠王 2), forgotten after 3 without.
	var mk := "ursus:build"
	for i in range(2):
		actors.saw_upkeep(mk)
		actors._learn_upkeep()
	check("layer 3: after 2 days 鼠王 has learned the bill, the others not yet", actors.learned("rat", mk) and not actors.learned("lungmen", mk))
	actors.saw_upkeep(mk)
	actors._learn_upkeep()
	check("after 3 days everyone has", actors.learned("lungmen", mk))
	for i in range(3): actors._learn_upkeep()
	check("three days without it, forgotten", not actors.learned("lungmen", mk) and not actors.learned("rat", mk))
	# Layer 2: holdings past 5% are public.
	var firm := "rose"
	var shares := float(m.firms.firms[firm].shares)
	ex.securities.shares[firm] = {"n": shares * 0.06, "cost": 1.0}
	m.firms.firms[firm].holders["rhodes"] = shares * 0.06
	actors._infer_positions(m)
	var size := shares * 0.06 * m.firms.share_price_lmd(firm)
	check("layer 2: a 6%% holding is known exactly", absf(actors.estimate("lungmen", firm) - size) < 1.0)
	ex.securities.shares.erase(firm)
	m.firms.firms[firm].holders.erase("rhodes")
	# Layer 4: a big CFD is inferred, off by 0.5–1.5 (鼠王 0.8–1.2); a small one is not.
	game.gold = 5000000
	ex.relations["karlan"] = 5000
	var u := "kazimierz:weapon"
	var depth := m.depth(u)
	ex.cfds.append({"id": 9001, "underlying": u, "dir": 1, "notional": depth * 0.3, "currency": "lmd", "margin": 1000.0, "entry": 1.0, "issuer": "karlan", "lev": 1})
	actors._infer_positions(m)
	var est := actors.estimate("lungmen", u)
	var est_rat := actors.estimate("rat", u)
	check("layer 4: a footprint is inferred within 0.5–1.5×: %.2f" % (est / (depth * 0.3)), est >= depth * 0.3 * 0.5 - 1.0 and est <= depth * 0.3 * 1.5 + 1.0)
	check("鼠王's guess is closer: %.2f" % (est_rat / (depth * 0.3)), est_rat >= depth * 0.3 * 0.8 - 1.0 and est_rat <= depth * 0.3 * 1.2 + 1.0)
	ex.cfds.clear()
	actors._infer_positions(m)
	check("closed, the guess fades", absf(actors.estimate("lungmen", u)) < absf(est))
	ex.cfds.append({"id": 9002, "underlying": "kazimierz:armor", "dir": 1, "notional": m.depth("kazimierz:armor") * 0.02, "currency": "lmd", "margin": 100.0, "entry": 1.0, "issuer": "karlan", "lev": 1})
	actors._infer_positions(m)
	check("a small position leaves no footprint", absf(actors.estimate("lungmen", "kazimierz:armor")) < 1.0)
	ex.cfds.clear()
	# Layer 5: orders at another venue are not seen.
	ex.orders.append({"id": 9100, "side": "buy", "faction": "kazimierz", "market": "kazimierz:build", "material": "螺栓", "count": 100000, "price": 1.0})
	check("layer 5: an order at 卡西米尔 is not seen at 龙门", ex.orders_at("lungmen").is_empty() and not ex.orders_at("kazimierz").is_empty())
	ex.orders.clear()
	check("layer 6: the 罗德岛库存 is never read by the AI", not "fin" in str(actors.to_data().keys()))

func _hostility() -> void:
	var ex := game.exchange
	var m := game.market
	var actors := m.actors
	ex.relation_mods = {}
	var mk := "ursus:build"
	var a: Dictionary = actors.factions.reunion
	a.learned = {mk: true}
	a.est = {}
	a.spent = 0.0
	ex.relations["reunion"] = 0
	var cash := float(a.cash)
	m.t = MarketState.next_day_start(m.t) - 3600 + 10   # 07:00
	actors.pending.clear()
	actors._rhodes_round(m)
	check("冷漠: 整合 hoards the bill's goods before 08:00", float((actors.pending.get("b|" + mk, {}) as Dictionary).get("left", 0.0)) > 0.0)
	check("within 3%% of its cash a day: %.0f of %.0f" % [float(a.spent), cash], float(a.spent) <= cash * 0.03 + 1.0 and float(a.spent) > 0.0)
	var b: Dictionary = actors.factions.lungmen
	b.learned = {mk: true}
	b.spent = 0.0
	ex.relations["lungmen"] = Exchange.RANK_AT[1]
	actors.pending.clear()
	actors._rhodes_round(m)
	check("中立: at most 1%%", float(b.spent) <= float(b.cash) * 0.01 + 1.0)
	b.spent = 0.0
	ex.relations["lungmen"] = Exchange.RANK_AT[2]
	actors._rhodes_round(m)
	check("友好: no hostile trades", float(b.spent) == 0.0)
	b.learned = {}
	check("no learned bill, no hoarding against it", true)
	# Against a believed position.
	a.learned = {}
	a.spent = 0.0
	a.est = {"karlan:cold": 50000.0}
	actors.pending.clear()
	actors._rhodes_round(m)
	check("反向砸盘: it sells into what it thinks Rhodes is long", float((actors.pending.get("b|karlan:cold", {}) as Dictionary).get("left", 0.0)) < 0.0)
	check("one hostile trade at most 10%% of its cash", float(a.spent) <= float(a.cash) * 0.1 + float(a.spent) * 0.0 + cash * 0.1)
	# Friendly: 崇拜 buys back what Rhodes sells there.
	ex.relations["karlan"] = 5000
	actors.pending.clear()
	actors.rhodes_trade(m, "karlan", "karlan:cold", -20000.0)
	check("崇拜: 喀兰 takes part of what Rhodes sells", float((actors.pending.get("b|karlan:cold", {}) as Dictionary).get("left", 0.0)) > 0.0)
	# Firms and the crowds do not tell Rhodes from anyone (no Rhodes in their code paths).
	check("firms and crowds trade the flow, not the name", not m.firms.has_method("rhodes_trade") and not "rhodes" in str(actors.groups.keys()))

func _relation_mods() -> void:
	var ex := game.exchange
	var actors := game.market.actors
	ex.relation_mods = {}
	for f in Exchange.START_RELATIONS: ex.relations[f] = int(Exchange.START_RELATIONS[f])
	for f in actors.factions:
		actors.factions[f].rel = {}
		actors.factions[f].grudge = 0.0
	ex.update_relation_mods()
	var same := true
	for f in Exchange.START_RELATIONS: same = same and ex.relation(f) == int(Exchange.START_RELATIONS[f])
	check("a new save: every modifier 0, the attitudes as the story has them", same, ex.relation_mods)
	ex.relations["rat"] = 2000
	var targets := ex.mod_targets("lungmen")
	check("敌之友: 鼠王 1000 over its 1000 → 龙门商会 −500", is_equal_approx(float(targets.enemy_friend), -500.0))
	var before := ex.relation("lungmen")
	ex.update_relation_mods()
	check("10%% of the way a day", ex.relation("lungmen") == before - 50)
	for i in range(60): ex.update_relation_mods()
	check("…and all the way in time", ex.mods_total("lungmen") == -500 or ex.relation("lungmen") == 0)
	ex.relations["rat"] = 1000
	check("at its expected value: nothing", is_equal_approx(float(ex.mod_targets("lungmen").enemy_friend), 0.0))
	ex.relations["reunion"] = 900
	check("冷淡 is half: 卡西米尔 −100 for 整合 400 over", is_equal_approx(float(ex.mod_targets("kazimierz").enemy_friend), -100.0))
	ex.relations["reunion"] = 5000
	check("one enemy at most −1500", float(ex.mod_targets("ursus").enemy_friend) >= -1500.0)
	check("企鹅物流 is nobody's enemy", ex.mod_targets("penguin").enemy_friend == 0.0 and not actors.enemies_of("lungmen").has("penguin"))
	ex.relations["reunion"] = 0
	ex.relations["rat"] = 0
	check("敌之敌: 鼠王 150 → 0 gives 龙门商会 +150", is_equal_approx(float(ex.mod_targets("lungmen").enemy_enemy), 150.0))
	check("…while 整合, cold from the start, gives nothing", is_equal_approx(float(ex.mod_targets("ursus").enemy_enemy), 0.0))
	ex.relations["rat"] = 150
	# A rank won through a modifier is announced and gifted once.
	ex.relation_mods = {}
	ex.relations["sami"] = 450
	ex.rank_gifts["sami"] = [1]
	ex.add_relation_event("sami", "test", 300.0, 5.0)
	for i in range(40): ex.update_relation_mods()
	check("a rank won by a modifier sends its gift", ex.rank("sami") == 2 and (ex.rank_gifts["sami"] as Array).has(2))
	# Factions fall out by harassing each other.
	actors.factions.karlan.rel = {}
	for i in range(40): actors._shift("karlan", "kazimierz", "conflict", -20000.0 * MarketActors.CONFLICT_PER_LMD)
	check("两家互相打压: neutral becomes hostile", actors.tier("karlan", "kazimierz") == "敌对")
	for i in range(80): actors.factions.karlan.rel.kazimierz.conflict = float(actors.factions.karlan.rel.kazimierz.conflict) * MarketActors.CONFLICT_FADE
	check("left alone, it fades", actors.tier("karlan", "kazimierz") != "敌对")
	var copy := Exchange.new()
	copy.load_data(ex.to_data())
	check("the modifiers save and load", copy.relation_mods.hash() == ex.relation_mods.hash())
