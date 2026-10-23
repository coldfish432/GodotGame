extends SceneTree
## The live market (势力与交易所策划案_v0_7.md §5): never closed, real time,
## simulated on load, news and black swans (交易所事件表_v1_0.md).
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(label: String, passed: bool) -> void:
	print(("PASS " if passed else "FAIL ") + label)
	if not passed: failures += 1

const T0 := 2000000000   # 2033-05-18, a fixed start

func run() -> void:
	MarketState.tz_override = 0
	var m := MarketState.new()
	m.start(T0, 99)
	check("every faction market and the rate exist: %d" % m.books.size(), m.books.size() == FactionCatalog.markets().size() and m.books.has("fx"))
	check("two hours of history behind a fresh market", m.candles("fx", "1m", 500).size() >= 110)
	check("the made-up history makes no headlines", m.news.is_empty())
	var t := Time.get_ticks_msec()
	m.advance_to(T0 + 6 * 3600)
	var six := Time.get_ticks_msec() - t
	var lo := 9.0
	var hi := 0.0
	for b in m.books.values():
		lo = minf(lo, b.i)
		hi = maxf(hi, b.i)
	check("indices stay sane after six hours: %.2f–%.2f" % [lo, hi], lo > 0.4 and hi < 2.5)
	check("1-minute candles are capped at six hours", m.candles("fx", "1m", 10000).size() <= MarketState.KEEP_M1 * 2)
	for p in ["1m", "5m", "15m", "1h", "4h", "1d", "1w"]:
		check("candles at %s" % p, not m.candles("lungmen:armor", p, 50).is_empty())
	var candle: Array = m.candles("lungmen:armor", "15m", 1)[0]
	check("a candle is o h l c v with h ≥ o, c ≥ l", candle.size() == 5 and candle[1] >= candle[0] and candle[1] >= candle[3] and candle[2] <= candle[0] and candle[2] <= candle[3])
	check("FX shows 龙门币 per 赤金, the rest ×100", absf(m.price("fx") - m.index("fx") * 1000) < 0.01 and absf(m.price("rhine:originium") - m.index("rhine:originium") * 100) < 0.01)
	check("Economy.fx follows the rate", absf(Economy.fx - m.fx_rate()) < 0.5)
	# Catching up a long gap fast (读档时模拟 K 线).
	t = Time.get_ticks_msec()
	m.advance_to(T0 + 6 * 3600 + 7 * 86400)
	var week := Time.get_ticks_msec() - t
	print("six hours %d ms, seven days %d ms" % [six, week])
	check("a week offline catches up in under 3 s: %d ms" % week, week < 3000)
	t = Time.get_ticks_msec()
	m.advance_to(T0 + 60 * 86400)
	check("more than seven days only simulates the last seven: %d ms" % (Time.get_ticks_msec() - t), Time.get_ticks_msec() - t < 3000 and m.t > T0 + 60 * 86400 - 3)
	# Active hours (不停市): thin books outside them, never closed.
	var day := T0 - posmod(T0, 86400)    # midnight UTC = local with tz 0
	# The made-up history may leave an all-day or spread event running; the
	# hours alone are checked here.
	m.effects.clear()
	m._mods_dirty = true
	m.t = day + 10 * 3600
	check("龙门商会 active at 10:00, not at 22:00", m.active("lungmen", 10) and not m.active("lungmen", 22))
	check("鼠王 active at 22:00, 喀兰贸易 all day", m.active("rat", 22) and not m.active("rat", 10) and m.active("karlan", 3))
	var in_hours := m.spread("lungmen:armor")
	m.t = day + 22 * 3600
	check("off hours the spread doubles", absf(m.spread("lungmen:armor") - in_hours * 2.0) < 0.0001)
	check("off hours the depth halves", absf(m.depth("lungmen:armor") * 2.0 - MarketState.DEPTH_LMD * 1.0) < 1.0)
	check("still tradeable off hours (no halt)", not m.halted("lungmen:armor"))
	check("the trading day turns at 08:00", MarketState.day_key(day + 7 * 3600) == MarketState.day_key(day + 7 * 3600 + 1) and MarketState.day_key(day + 8 * 3600) == MarketState.day_key(day + 7 * 3600) + 1)
	check("next 08:00", MarketState.next_day_start(day + 9 * 3600) == day + 86400 + 8 * 3600)
	# Rate limit (涨跌限速): a black swan moves 10% per 5 minutes at most.
	var m2 := MarketState.new()
	m2.start(T0, 5)
	var before := m2.index("fx")
	m2.fire("L9")
	var tick_start := m2.t
	m2.advance_to(m2.t + 60)
	var after_minute := m2.index("fx")
	check("the swan's jump is held to 10%% per window: %.3f → %.3f" % [before, after_minute], after_minute / before < 1.12)
	var peak := 0.0
	for k in range(40):
		m2.advance_to(tick_start + (k + 1) * 60)
		peak = maxf(peak, m2.index("fx"))
	check("and is worked off over the next windows: peak %.3f" % peak, peak / before > 1.15)
	var swan_news: Array = m2.news.filter(func(n): return n.id == "L9")
	check("a swan headline is news, kind swan, with the markets it moved and which way", not swan_news.is_empty() and swan_news[0].kind == "swan" and swan_news[0].markets.has("fx") and int(swan_news[0].moves.get("fx", 0)) == 1)
	# Rumors: a third now, then confirmed or denied.
	var m3 := MarketState.new()
	m3.start(T0, 11)
	m3.fire("C2")
	var e: Dictionary = m3.effects.filter(func(x): return x.id == "C2")[0]
	check("a rumor starts at 30%", is_equal_approx(float(e.scale), 0.3) and m3.news[-1].status == "待证实" and not str(m3.news[-1].cred).is_empty())
	check("orders are locked for three ticks after news", m3.locked("rhine:originium"))
	m3.advance_to(m3.t + 6 * 60)
	check("a rumor is verified within five minutes: %s" % m3.news.filter(func(n): return n.id == "C2")[0].status, m3.news.filter(func(n): return n.id == "C2")[0].status in ["已证实", "已辟谣"])
	# Picks fill the title.
	m3.fire("X2")
	check("天灾预警 names a region", not m3.news[-1].title.contains("%s") and m3.news[-1].title.begins_with("天灾预警："))
	m3.fire("L3")
	check("传闻：鼠王在收… names a category", not m3.news[-1].title.contains("%s"))
	# Calendar: random announcements ahead, seasonal ones on the real calendar.
	check("the calendar holds announcements ahead", m3.calendar.filter(func(c): return not c.get("seasonal", false)).size() >= MarketState.RANDOM_ANNOUNCES)
	var seasons := MarketEvents.seasonal_between(Time.get_unix_time_from_datetime_string("2026-11-25T00:00:00"), Time.get_unix_time_from_datetime_string("2026-12-03T00:00:00"))
	check("雪山大典 and the 天灾简报 fall on December 1st", seasons.any(func(s): return s[1] == "K1") and seasons.any(func(s): return s[1] == "X1"))
	var spring := MarketEvents.seasonal_between(Time.get_unix_time_from_datetime_string("2027-01-25T00:00:00"), Time.get_unix_time_from_datetime_string("2027-02-06T00:00:00"))
	check("新春备货 a week before 春节 2027", spring.any(func(s): return s[1] == "L5"))
	# Black swans: memoryless, mean three weeks, no pity (完全随机).
	var waits: Array = []
	var omens := 0
	var m4 := MarketState.new()
	m4.rng.seed = 3
	for k in range(3000):
		m4.t = 0
		m4._schedule_swan()
		waits.append(float(m4.swan.at))
		if int(m4.swan.precursor_at) != -1: omens += 1
	var mean := 0.0
	for w in waits: mean += w
	mean /= waits.size()
	var under := waits.filter(func(w): return w < MarketState.SWAN_MEAN).size() / float(waits.size())
	check("swan waits average about 21 days: %.1f" % (mean / 86400.0), absf(mean / MarketState.SWAN_MEAN - 1.0) < 0.08)
	check("and are exponential (63%% under the mean): %.2f" % under, absf(under - 0.632) < 0.04)
	check("some come within a day of each other", waits.any(func(w): return w < 86400))
	check("about half have an omen: %d / 3000" % omens, absi(omens - 1500) < 150)
	check("20 black swans, all drawable", MarketEvents.of_kind("swan").size() == 20)
	# Every event fires cleanly.
	var m5 := MarketState.new()
	m5.start(T0, 21)
	var broken: Array = []
	for id in MarketEvents.EVENTS:
		var fired := m5.fire(id)
		if fired.is_empty() or str(m5.news[-1].title).contains("%"): broken.append(id)
	check("all %d events fire with a filled title: %s" % [MarketEvents.EVENTS.size(), broken], broken.is_empty() and MarketEvents.EVENTS.size() == 200)
	var empty: Array = []
	for id in MarketEvents.EVENTS:
		for spec in MarketEvents.EVENTS[id].effects:
			var sel := str(spec.sel)
			if sel.begins_with("@") or sel.begins_with("#") or sel.contains("%s"): continue
			if m5._resolve(sel, [], "").is_empty(): empty.append("%s %s" % [id, sel])
	check("every effect reaches a real market: %s" % [empty], empty.is_empty())
	var titles := {}
	for id in MarketEvents.EVENTS: titles[MarketEvents.EVENTS[id].title] = true
	check("no two events share a title", titles.size() == MarketEvents.EVENTS.size())
	m5.advance_to(m5.t + 3600)
	check("effects change targets without breaking the books", m5.books.values().all(func(b): return b.i > 0.1 and b.i < 6.0))
	check("北原邪魔 raises snow threat", m5.threat_mult("snow") > 1.0)
	# Linked events (用户: 频率随机，事件相互关联).
	var bad_links: Array = []
	var linked := {}
	var n_links := 0
	for id in MarketLinks.LINKS:
		if not MarketEvents.EVENTS.has(id): bad_links.append(id)
		linked[id] = true
		for link in MarketLinks.LINKS[id]:
			n_links += 1
			var to := str(link.get("f", link.get("b", "")))
			if not MarketEvents.EVENTS.has(to): bad_links.append("%s→%s" % [id, to])
			linked[to] = true
			if not str(link.get("if", "")).is_empty() and MarketEvents.EVENTS[id].kind != "rumor": bad_links.append("%s if on a non-rumor" % id)
	check("every link points at a real event, conditions only on rumors: %s" % [bad_links], bad_links.is_empty())
	print("links: %d from %d events, %d of 200 events in a story line, %d arcs" % [n_links, MarketLinks.LINKS.size(), linked.size(), MarketLinks.ARCS.size()])
	check("most events belong to a story line: %d" % linked.size(), linked.size() >= 150)
	var m8 := MarketState.new()
	m8.start(T0, 31)
	m8.chain.clear()
	m8.fire("X7", {"region": "龙门"})
	var title7: String = m8.news[-1].title
	check("天灾直击 sets off follow-ups", not m8.chain.is_empty())
	var follow: Dictionary = m8.chain[0]
	m8.advance_to(int(follow.at) + 4)
	var later: Array = m8.news.filter(func(n): return n.get("cause", "") == title7)
	check("a follow-up comes later, naming its cause: %s" % (later[0].title if not later.is_empty() else "none"), not later.is_empty())
	check("and keeps the region picked: %s" % (later[0].title if not later.is_empty() else ""), later.is_empty() or not later[0].title.contains("：") or later[0].title.ends_with("龙门") or not MarketEvents.EVENTS[later[0].id].get("pick_region", false))
	m8.boosts.clear()
	m8.fire("L15")
	check("an event raises the odds of what it leads to", m8.boosts.get("L32", []).any(func(b): return float(b.x) == 2.0) and m8.boosts.get("L33", []).any(func(b): return float(b.x) == 1.5))
	m8.fire("L32")
	check("and can lower others", m8.boost_of("L2") < 1.0)
	var hits := 0
	for k in range(400):
		m8.chain.clear()
		m8._follow("C2", "传闻：莱茵生命矿石病临床试验结果", {}, "true")
		hits += m8.chain.filter(func(c): return c.id == "X14").size()
	check("a confirmed rumor leads on at its odds (40%%): %d / 400" % hits, absi(hits - 160) < 40)
	m8.chain.clear()
	for k in range(50): m8._follow("C2", "x", {}, "false")
	check("a denied one takes the other branch", m8.chain.all(func(c): return c.id == "C28") and not m8.chain.is_empty())
	m8.chain.clear()
	m8._follow("K1", "x", {}, "")
	for k in range(30): m8._follow("K1", "x", {}, "")
	check("a follow-up announcement goes on the calendar", m8.calendar.any(func(c): return c.get("linked", false) and c.id == "K19"))
	m8.fire("U7")
	var saved := m8.to_data()
	var m9 := MarketState.new()
	m9.load_data(saved)
	check("chains and odds survive a save", m9.chain.size() == m8.chain.size() and m9.boost_of("U23") == m8.boost_of("U23"))
	# The web (用户: 能织成网吗): one connected net, and the world state.
	var adj := {}
	for id in MarketEvents.EVENTS: adj[id] = {}
	for id in MarketLinks.LINKS:
		for link in MarketLinks.LINKS[id]:
			var to := str(link.get("f", link.get("b", "")))
			if to != id and adj.has(to):
				adj[id][to] = true
				adj[to][id] = true
	var reached := {"L1": true}
	var stack := ["L1"]
	while not stack.is_empty():
		var v = stack.pop_back()
		for w in adj[v]:
			if not reached.has(w):
				reached[w] = true
				stack.append(w)
	check("all 200 events hang in one web: %d" % reached.size(), reached.size() == 200)
	var leaning := MarketEvents.EVENTS.keys().filter(func(id): return not MarketLinks.affinity(id).is_empty()).size()
	check("events lean on the world state: %d / 200" % leaning, leaning >= 185)
	var w1 := MarketState.new()
	w1.start(T0, 41)
	w1.factors.clear()
	var arms_before := w1.lean("C9")
	for id in ["U2", "U3", "U13", "U19", "U14"]: w1.fire(id)
	check("Ursus unrest raises the Ursus factor: %.2f" % w1.factor("ursus"), w1.factor("ursus") > 0.5)
	check("and the odds of Columbia's arms news, far away: ×%.2f → ×%.2f" % [arms_before, w1.lean("C9")], w1.lean("C9") > arms_before * 1.04)
	var before_calm := w1.factor("ursus")
	w1.fire("U11")
	check("a calming event pulls its factor back down", w1.factor("ursus") < before_calm)
	var level := w1.factor("ursus")
	var w3 := MarketState.new()
	w3.start(T0, 43)
	w3.chain.clear()
	w3.factors["ursus"] = 2.0
	w3.advance_to(w3.t + 72 * 3600)
	# 用户: 不用过于考虑平衡 — a crisis may linger or deepen; it only stays in range.
	check("a crisis may linger, within range: %.2f" % w3.factor("ursus"), w3.factor("ursus") >= MarketLinks.FACTOR_RANGE.x and w3.factor("ursus") <= MarketLinks.FACTOR_RANGE.y)
	check("the usual flow of news is taken off (surprises only)", not MarketLinks.drift(MarketState.BREAKING_PER_DAY, MarketState.RUMOR_PER_DAY).is_empty())
	w1.boosts.clear()
	for k in range(6): w1.fire("L15")
	check("raised again, odds stack up to the cap: ×%.2f" % w1.boost_of("L32"), is_equal_approx(w1.boost_of("L32"), MarketState.BOOST_CAP))
	var w2 := MarketState.new()
	w2.load_data(w1.to_data())
	check("the world state is saved", absf(w2.factor("ursus") - w1.factor("ursus")) < 1e-6)
	# Flash offers come and go.
	var m6 := MarketState.new()
	m6.start(T0, 8)
	var seen := {"flash": 0}
	m6.on_news = func(n: Dictionary, _ev: Dictionary): if n.kind == "flash": seen.flash += 1
	m6.advance_to(T0 + 3 * 86400)
	check("flash offers appear over three days: %d" % seen.flash, seen.flash > 0)
	check("the news center keeps the last %d headlines" % MarketState.NEWS_KEEP, m6.news.size() <= MarketState.NEWS_KEEP)
	check("and none outlives two minutes", m6.flash.all(func(f): return int(f.until) - m6.t <= 120))
	# Saving.
	var path := "user://test_market.bin"
	m6.save_file(path)
	var m7 := MarketState.new()
	check("a market loads back", m7.load_file(path))
	check("with its books, news and clock", m7.t == m6.t and absf(m7.index("fx") - m6.index("fx")) < 1e-6 and m7.news.size() == m6.news.size()
		and m7.candles("fx", "15m", 20).size() == m6.candles("fx", "15m", 20).size())
	m7.advance_to(m7.t + 600)
	check("and keeps running", m7.t >= m6.t + 598)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("TEST_MARKET: %d failures" % failures)
	quit(1 if failures > 0 else 0)
