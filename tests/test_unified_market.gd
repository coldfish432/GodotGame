extends SceneTree
## 交易所统一行情修订案 v0.3: one line a pack, faction books at the line ×
## (1 + basis), hidden shares, news split by share, the ledgers, the drives and
## the plans (B3–B16), saving and the move from an old save.
const T0 := 1791972000
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(label: String, passed: bool, detail: Variant = null) -> void:
	print(("PASS " if passed else "FAIL ") + label + ("" if passed or detail == null else "  " + str(detail)))
	if not passed: failures += 1

func fresh(seed_value: int = 11) -> MarketState:
	var m := MarketState.new()
	m.start(T0, seed_value)
	return m

func run() -> void:
	BaseState.time_scale = 1
	MarketState.tz_override = 0
	_lines()
	_shares()
	_news_split()
	_flows()
	_plans()
	_news_plans()
	_saving()
	_three_days()
	print("UNIFIED MARKET FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)

func _lines() -> void:
	var m := fresh()
	check("one line a pack: %d" % m.lines.size(), m.lines.size() == FactionCatalog.line_ids().size() and m.lines.size() == 12)
	var ok := true
	var within := true
	for id in m.books:
		var b: MarketState.Book = m.books[id]
		if b.fx: continue
		var line: MarketState.Book = m.lines[b.category]
		ok = ok and absf(b.i - line.i * (1.0 + m.basis(str(id)))) < 1e-6
		within = within and absf(m.basis(str(id))) <= MarketState.BASIS_CAP + 1e-9
	check("a faction book is its line × (1 + basis)", ok)
	check("every basis within ±8%", within)
	var q1 := "lungmen:build"
	var q2 := "kazimierz:build"
	check("two books of a pack differ only by their bases", absf(m.index(q1) / m.index(q2) - (1.0 + m.basis(q1)) / (1.0 + m.basis(q2))) < 1e-6)
	check("a book shows its pack's candles", m.candles(q1, "1m", 30) == m.candles("build", "1m", 30) and not m.candles("build", "1m", 30).is_empty())
	check("a line is as deep as its books together", absf(m.depth("build") - m.quotes_of("build").reduce(func(a, q): return a + m.depth(str(q)), 0.0)) < 1.0)
	check("the line's name is its pack", FactionCatalog.market_name("fuel") == "燃料桶" and FactionCatalog.market_name("build") == "建材包")

func _shares() -> void:
	var m := fresh()
	var sums := true
	for cat in m.influence.shares:
		var s := 0.0
		for pid in m.influence.shares[cat]: s += float(m.influence.shares[cat][pid])
		sums = sums and absf(s - 1.0) < 1e-6
	check("each pack's shares add up to 1", sums and m.influence.shares.size() == 12)
	m.advance_to(T0 + 3 * 86400)
	var inside := true
	for pid in MarketLedgers.participants(m):
		for cat in MarketLedgers.cats(m, pid):
			inside = inside and absf(m.influence.drift(pid, str(cat))) <= MarketInfluence.RANGE + 1e-9
	check("every factor floats within ±10%", inside)
	check("firms weigh in too", m.influence.share("c:mieszko", "build") > 0.0 and m.influence.share("f:lungmen", "build") > 0.0)
	var before := m.influence.drift("f:lungmen", "build")
	m.influence.on_event(m, [{"markets": ["lungmen:build"], "mult": 1.3}], {})
	check("news naming it moves its factor", m.influence.drift("f:lungmen", "build") > before, [before, m.influence.drift("f:lungmen", "build")])

func _news_split() -> void:
	var m := fresh()
	var s := m.influence.quote_share(m, "lungmen:build")
	var base_mult := float(m.mods("build").get("mult", 1.0))
	var base_basis := float(m._basis_mods.get("lungmen:build", 0.0))
	var other_basis := float(m._basis_mods.get("kazimierz:build", 0.0))
	m.effects.append({"id": "T", "title": "", "kind": "breaking", "until": m.t + 3600, "scale": 1.0, "items": [{"markets": ["lungmen:build"], "factions": ["lungmen"], "mult": 1.3}], "picks": {}})
	m._mods_dirty = true
	var line_mult := float(m.mods("build").get("mult", 1.0))
	check("a faction's news reaches the line by its share: ×%.3f (share %.2f)" % [line_mult, s], absf(line_mult - clampf(base_mult + 0.3 * s, 0.2, 5.0)) < 1e-6)
	check("the rest is its basis, at most 8%", absf(float(m._basis_mods.get("lungmen:build", 0.0)) - clampf(base_basis + 0.3 * (1.0 - s), -0.08, 0.08)) < 1e-6)
	check("other books get no basis from it", absf(float(m._basis_mods.get("kazimierz:build", 0.0)) - other_basis) < 1e-9)
	var g := fresh()
	var cold0 := float(g.mods("cold").get("mult", 1.0))
	var cold_basis := g._basis_mods.duplicate()
	g.effects.append({"id": "T", "title": "", "kind": "breaking", "until": g.t + 3600, "scale": 1.0, "items": [{"markets": g.quotes_of("cold"), "factions": [], "mult": 1.2, "global": true, "cats": ["cold"]}], "picks": {}})
	g._mods_dirty = true
	check("a \"*:category\" one moves the line whole", absf(float(g.mods("cold").get("mult", 1.0)) - (cold0 + 0.2)) < 1e-6 and g._basis_mods == cold_basis)
	var j := fresh()
	var line: MarketState.Book = j.lines["build"]
	var pj := line.pj
	var bs := (j.books["lungmen:build"] as MarketState.Book).bs
	var share := j.influence.quote_share(j, "lungmen:build")
	j._jump("lungmen:build", 0.05)
	check("a jump: the line by the share, the rest the basis", absf(line.pj - pj - log(1.0 + 0.05 * share)) < 1e-6 and absf((j.books["lungmen:build"] as MarketState.Book).bs - clampf(bs + 0.05 * (1.0 - share), -0.08, 0.08)) < 1e-6)
	# A real event from the table, end to end.
	var e := fresh()
	var entry := e.fire("L3", {"category": "medical"})
	check("an event names its books and the line moves by share", not entry.is_empty() and float(e.mods("medical").get("mult", 1.0)) > 1.0 and e.basis("rat:medical") > (e.books["rat:medical"] as MarketState.Book).bs)

func _flows() -> void:
	var m := fresh()
	var q := "ursus:fuel"
	var b: MarketState.Book = m.books[q]
	var line: MarketState.Book = m.lines["fuel"]
	b.bs = 0.0
	var fl := line.fl
	m.add_pressure(q, 40000.0, "rhodes")
	check("Rhodes' sale: half on the line", absf(line.fl - (fl - 20000.0)) < 1e-6)
	check("and half on that venue's basis", b.bs < 0.0, b.bs)
	var fl2 := line.fl
	m.add_flow(q, 10000.0, "faction:ursus")
	check("a faction's order is all on the line", absf(line.fl - fl2 - 10000.0) < 1e-6)
	var bs := b.bs
	m.add_flow(q, 10000.0, "arb:test")
	check("an arbitrage only on the basis", absf(line.fl - fl2 - 10000.0) < 1e-6 and b.bs > bs)
	m.pin("karlan:cold", 1.5)
	check("pin puts a book at a price through its line", absf(m.index("karlan:cold") - 1.5) < 1e-6)

func _plans() -> void:
	var m := fresh(21)
	m.plans.enabled = false
	var p := m.plans
	# B3: the rat pumps what its enemy 龙门 buys.
	var d := MarketDrives.of(m, "f:rat", "medical")
	check("D3: 鼠王 is driven to hurt 龙门 on what 龙门 buys (%.2f)" % float(d.D3u), float(d.D3u) > 0.1 and str(d.rival) == "f:lungmen")
	check("B3 scores past the threshold on it", p._score("B3", d) >= MarketPlans.THRESHOLD)
	var plan := p.begin(m, "f:rat", "B3", "medical", d)
	var inv0 := MarketLedgers.inv(m, "f:rat", "medical")
	for k in range(4): p._advance(m, plan)
	check("扫货拉抬 buys", MarketLedgers.inv(m, "f:rat", "medical") > inv0 and float(plan.spent) > 0.0)
	# B4 → B5: hoard, then dump.
	var h := p.begin(m, "f:ursus", "B4", "originium")
	check("囤货惜售 holds it back", MarketLedgers.held(m, "f:ursus", "originium"))
	var room := MarketLedgers.capacity(m, "f:ursus", "originium")
	MarketLedgers.store(m, "f:ursus").inv["originium"] = room
	p._advance(m, h)
	check("full: it waits", str(h.phase) == "wait")
	h.ref = 0.01
	p._advance(m, h)
	check("worth it: it turns to dumping and lets go", str(h.phase) == "dump" and not MarketLedgers.held(m, "f:ursus", "originium"))
	var before := MarketLedgers.inv(m, "f:ursus", "originium")
	p._advance(m, h)
	check("集中抛售 sells", MarketLedgers.inv(m, "f:ursus", "originium") < before)
	# B5 standalone.
	MarketLedgers.store(m, "f:karlan").inv["cold"] = MarketLedgers.target(m, "f:karlan", "cold") * 3.0
	var dump := p.begin(m, "f:karlan", "B5", "cold")
	var c0 := MarketLedgers.inv(m, "f:karlan", "cold")
	p._advance(m, dump)
	check("B5 sells down toward its target", MarketLedgers.inv(m, "f:karlan", "cold") < c0)
	# B6: off the mean, 龙门 leans against it.
	var line: MarketState.Book = m.lines["armor"]
	line.i = MarketDrives.mean7(line) * 0.8
	var d6 := MarketDrives.of(m, "f:lungmen", "armor")
	check("D4: 龙门商会 wants it steady (%.2f)" % float(d6.D4), float(d6.D4) > 0.3)
	var steady := p.begin(m, "f:lungmen", "B6", "armor", d6)
	var a0 := MarketLedgers.inv(m, "f:lungmen", "armor")
	p._advance(m, steady)
	check("维稳托市 buys when it is low", MarketLedgers.inv(m, "f:lungmen", "armor") > a0 and float(steady.goal) > 0.0)
	# B7.
	var under := p.begin(m, "c:mieszko", "B7", "build")
	var cash0 := MarketLedgers.cash(m, "c:mieszko")
	MarketLedgers.store(m, "c:mieszko").inv["build"] = MarketLedgers.target(m, "c:mieszko", "build")
	p._advance(m, under)
	check("倾销 holds back the ordinary selling and sells itself", MarketLedgers.held(m, "c:mieszko", "build") and MarketLedgers.cash(m, "c:mieszko") > cash0)
	# B8 and its stop.
	var corner := p.begin(m, "f:kazimierz", "B8", "trinket")
	p._advance(m, corner)
	check("逼空 collects and holds", float(corner.bought) > 0.0 and MarketLedgers.held(m, "f:kazimierz", "trinket"))
	corner.paid = float(corner.budget) * 10.0
	p._advance(m, corner)
	check("a loss past 30% of the budget: it gets out", str(corner.phase) == "out" and not MarketLedgers.held(m, "f:kazimierz", "trinket"))
	# B9.
	var lo := "lungmen:fuel"
	var hi := "karlan:fuel"
	(m.books[lo] as MarketState.Book).bs = -0.04
	(m.books[hi] as MarketState.Book).bs = 0.04
	var gap0 := m.basis(hi) - m.basis(lo)
	var kc := MarketLedgers.cash(m, "f:karlan")
	p._arbitrage(m)
	check("套利 narrows the gap and keeps a little", m.basis(hi) - m.basis(lo) < gap0 and MarketLedgers.cash(m, "f:karlan") > kc)
	# B10 / B11.
	var cut := p.begin(m, "f:ursus", "B10", "build")
	check("减产: the making drops for days, and it is news", MarketLedgers.pm(m, "f:ursus", "build") == MarketPlans.CUT and str(m.news[-1].title).contains("减产") and cut.kind == "B10")
	p.begin(m, "f:rhine", "B11", "medical")
	check("增产", MarketLedgers.pm(m, "f:rhine", "medical") == MarketPlans.RAISE and str(m.news[-1].title).contains("增产"))
	# B12.
	var any := false
	for cat in m.lines:
		if not p.rumors_for(str(cat), 1).is_empty() or not p.rumors_for(str(cat), -1).is_empty(): any = true
	check("the table has rumors to put about", any)
	var fired := false
	for k in range(200):
		var n := m.news.size()
		p._maybe_rumor(m, "f:rat", "contraband", 1)
		p._maybe_rumor(m, "f:rhine", "originium", 1)
		if m.news.size() > n:
			fired = str(m.news[-1].cred) == "低"
			break
	check("放风造势: a real rumor at 低", fired)
	# B16.
	MarketLedgers.store(m, "f:sami").inv["fuel"] = 0.0
	MarketLedgers.store(m, "f:karlan").inv["fuel"] = MarketLedgers.target(m, "f:karlan", "fuel") * 3.0
	var sn := MarketLedgers.inv(m, "f:sami", "fuel")
	p._aid(m)
	check("援助盟友: 喀兰 sends 萨米 fuel, not through the market", MarketLedgers.inv(m, "f:sami", "fuel") > sn and str(m.news[-1].title).contains("调拨"))

func _news_plans() -> void:
	var m := fresh(31)
	var p := m.plans
	# B14: bad news on what a careful holder has too much of (no plans already in hand).
	p.active = p.active.filter(func(x): return not str(x.pid) in ["f:reunion", "f:lungmen"])
	p.cool.clear()
	MarketLedgers.store(m, "f:reunion").inv["medical"] = MarketLedgers.target(m, "f:reunion", "medical") * 3.0
	var headline := {"t": m.t, "id": "X", "kind": "breaking", "title": "", "region": "", "cred": "", "moves": {"reunion:medical": -1}, "markets": ["reunion:medical"]}
	m.news.append(headline)
	p.on_news(m, headline, {"hours": 4})
	check("恐慌出逃 after bad news", not p.on_cat("f:reunion", "medical").is_empty() and str(p.on_cat("f:reunion", "medical").kind) == "B14")
	# B15: news at home lifting what it uses.
	var up := {"t": m.t, "id": "Y", "kind": "breaking", "title": "", "region": "龙门", "cred": "", "moves": {"lungmen:medical": 1}, "markets": ["lungmen:medical"]}
	p.on_news(m, up, {"hours": 6})
	check("战略储备 when home calls for it", p.policy_on(m, "f:lungmen", "medical") and str(p.on_cat("f:lungmen", "medical").get("kind", "")) == "B15")
	check("D9 is on while the call lasts", float(MarketDrives.of(m, "f:lungmen", "medical").D9) == 1.0)
	# Exposure comes later.
	var plan := p.begin(m, "f:rat", "B3", "medical")
	plan.vol = m.depth("medical")
	var queued := m.pending_news.size()
	for k in range(20):
		plan.exposed = false
		p._expose(m, plan, 1.0)
	check("a big plan can make the news 1–6 hours later", m.pending_news.size() > queued and m.pending_news.slice(queued).all(func(n): return int(n.at) >= m.t + 3600 and int(n.at) <= m.t + 6 * 3600))

func _saving() -> void:
	var m := fresh(41)
	m.advance_to(T0 + 86400)
	var data := m.to_data()
	var c := MarketState.new()
	c.load_data(data)
	check("saved and loaded: the lines", absf(c.index("build") - m.index("build")) < 1e-9 and c.candles("build", "15m", 50).size() == m.candles("build", "15m", 50).size())
	check("the bases", absf(c.basis("lungmen:build") - m.basis("lungmen:build")) < 1e-9)
	check("the plans and the hidden factors", c.plans.active.size() == m.plans.active.size() and absf(c.influence.share("f:lungmen", "build") - m.influence.share("f:lungmen", "build")) < 1e-9)
	# An old save: no lines; each line at its books' weighted mean, no history.
	var old: Dictionary = data.duplicate(true)
	old.erase("unified")
	old.erase("lines")
	old.erase("influence")
	old.erase("plans")
	var idx := {}
	for q in m.quotes_of("weapon"): idx[q] = (old.books[q] as Dictionary).i
	var o := MarketState.new()
	o.load_data(old)
	var lo := INF
	var hi := -INF
	for q in idx:
		lo = minf(lo, float(idx[q]))
		hi = maxf(hi, float(idx[q]))
	check("an old save: each line within its books' range", o.index("weapon") >= lo - 1e-6 and o.index("weapon") <= hi + 1e-6, [lo, o.index("weapon"), hi])
	check("its K lines start empty (用户: 清空)", o.candles("weapon", "1m", 10).is_empty() and o.candles("lungmen:weapon", "1d", 10).is_empty())
	check("the faction books are still there (orders and contracts on them hold)", o.books.has("lungmen:weapon") and o.books.has("rat:contraband"))
	o.advance_to(o.t + 3600)
	check("and it goes on", not o.candles("weapon", "1m", 10).is_empty())

func _three_days() -> void:
	var m := fresh(7)
	m.advance_to(T0 + 3 * 86400)
	var worst := 0.0
	for cat in m.lines:
		var lo := INF
		var hi := -INF
		for q in m.quotes_of(str(cat)):
			lo = minf(lo, m.index(str(q)))
			hi = maxf(hi, m.index(str(q)))
		worst = maxf(worst, hi / lo - 1.0)
	check("three days on, a pack's books differ only by their bases: at most %.1f%%" % (worst * 100.0), worst <= 1.08 / 0.92 - 1.0 + 1e-6)
	var started := 0
	for k in m.plans.stats: started += int(m.plans.stats[k])
	check("plans run on their own: %s" % str(m.plans.stats), started > 0)
	var sane := true
	for cat in m.lines: sane = sane and m.index(str(cat)) > 0.3 and m.index(str(cat)) < 3.0
	check("the lines stay sane", sane)
