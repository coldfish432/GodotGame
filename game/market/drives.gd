class_name MarketDrives
extends RefCounted

## 交易所统一行情修订案 v0.3 §3: why a faction or a firm would act on a pack.
## Each drive is a strength 0–1 worked out from its book, its character and
## the market; MarketPlans weighs them into its behaviours. Never shown.
##   D1 profit (D1u: expects a rise, D1d: a fall, D1s: worth selling now)
##   D2 supply (short of its target stock)
##   D3 hurt a rival (D3u: the rival buys this pack, D3d: the rival makes it)
##   D4 order (the line strays from its 7-day mean)
##   D5 market share (a maker that wants the market to itself)
##   D6 cash (short of money, in debt)
##   D7 help an ally (D7u: the ally makes it, D7aid: the ally is short of it)
##   D8 fear (bad news on what it holds)
##   D9 orders from home (a strategic reserve called)

static func of(m: MarketState, pid: String, cat: String) -> Dictionary:
	var tr := MarketLedgers.traits(m, pid)
	var line: MarketState.Book = m.lines.get(cat)
	var out := {"D1u": 0.0, "D1d": 0.0, "D1s": 0.0, "D2": 0.0, "D3u": 0.0, "D3d": 0.0, "rival": "", "D4": 0.0, "dev": 0.0,
		"D5": 0.0, "D6": 0.0, "D7u": 0.0, "D7aid": 0.0, "ally": "", "D8": 0.0, "D9": 0.0}
	if line == null: return out
	var inv := MarketLedgers.inv(m, pid, cat)
	var target := MarketLedgers.target(m, pid, cat)
	var cash := MarketLedgers.cash(m, pid)
	var price := line.i
	# D1: the price it expects against now; and what its stock cost.
	var lift := m.actors.expected(m, cat, float(tr.get("value", 0.5))) / maxf(price, 0.05) - 1.0
	var temper := (1.0 - float(tr.get("cash", 0.5))) * (0.5 + 0.5 * float(tr.get("risk", 0.5)))
	out.D1u = clampf(lift * 10.0, 0.0, 1.0) * temper
	out.D1d = clampf(-lift * 10.0, 0.0, 1.0) * temper
	if inv > target:
		var gain := price / maxf(MarketLedgers.cost(m, pid, cat), 0.05) - 1.0
		out.D1s = maxf(float(out.D1d), clampf(gain / 0.3, 0.0, 1.0) * (1.0 - 0.5 * float(tr.get("patience", 0.5))))
	# D2.
	if MarketLedgers.use_day(m, pid, cat) > 0.0:
		out.D2 = clampf((target - inv) / target, 0.0, 1.0) * (0.5 + 0.5 * float(tr.get("patience", 0.5)))
	# D3: the rival that weighs most here, as a buyer and as a maker.
	var totals := MarketLedgers.totals(m, cat)
	for r in rivals(m, pid):
		var tension := float(r[1]) * float(tr.get("revenge", 0.3))
		var rpid := str(r[0])
		var buy_w := MarketLedgers.use_day(m, rpid, cat) / maxf(float(totals.use), 1.0)
		var make_w := MarketLedgers.prod_day(m, rpid, cat) / maxf(float(totals.prod), 1.0)
		var up := clampf(tension * buy_w * 3.0, 0.0, 1.0)
		var down := clampf(tension * make_w * 3.0, 0.0, 1.0)
		if maxf(up, down) > maxf(float(out.D3u), float(out.D3d)): out.rival = rpid
		out.D3u = maxf(float(out.D3u), up)
		out.D3d = maxf(float(out.D3d), down)
	# D4: off its 7-day mean, as far as this pack matters to it.
	var dev := price / maxf(mean7(line), 0.05) - 1.0
	out.dev = dev
	var local := clampf(m.influence.share(pid, cat) * 4.0, 0.3, 1.0)
	out.D4 = clampf((absf(dev) - 0.05) / 0.12, 0.0, 1.0) * float(tr.get("order", 0.5)) * local
	# D5: a maker's share and everyone else's.
	var made := MarketLedgers.prod_day(m, pid, cat)
	if made > 0.0:
		var ps := made / maxf(float(totals.prod), 1.0)
		out.D5 = float(tr.get("ambition", 0.5)) * clampf(ps * (1.0 - ps) * 4.0, 0.0, 1.0)
	# D6.
	var use_total := maxf(MarketLedgers.use_total(m, pid), 1000.0)
	var debt := float(MarketLedgers.store(m, pid).get("debt", 0.0))
	out.D6 = clampf((use_total * 3.0 - cash) / (use_total * 3.0), 0.0, 1.0) + 0.5 * clampf(debt / (use_total * 30.0), 0.0, 1.0)
	out.D6 = minf(float(out.D6), 1.0)
	# D7: friends.
	if not MarketLedgers.is_firm(pid):
		var f := MarketLedgers.id_of(pid)
		for b in m.actors.factions:
			if str(b) == f or m.actors.tier(f, str(b)) != "友好": continue
			var apid := "f:" + str(b)
			var make_share := MarketLedgers.prod_day(m, apid, cat) / maxf(float(totals.prod), 1.0)
			out.D7u = maxf(float(out.D7u), clampf(make_share * 2.0, 0.0, 1.0))
			if MarketLedgers.use_day(m, apid, cat) > 0.0:
				var short := 1.0 - MarketLedgers.inv(m, apid, cat) / maxf(MarketLedgers.target(m, apid, cat) * 0.5, 1.0)
				if short > float(out.D7aid):
					out.D7aid = clampf(short, 0.0, 1.0)
					out.ally = apid
	# D8: bad news on this pack in the last 6 hours, as far as it believes it.
	var worth := inv * price
	var frac := worth / maxf(worth + maxf(cash, 0.0), 1.0)
	for k in range(m.news.size() - 1, maxi(-1, m.news.size() - 30), -1):
		var n: Dictionary = m.news[k]
		if int(n.t) < m.t - 6 * 3600: break
		var moves: Dictionary = n.get("moves", {})
		for q in moves:
			if int(moves[q]) >= 0 or FactionCatalog.split(str(q))[1] != cat: continue
			var cred := float(MarketState.CREDIBILITY.get(str(n.get("cred", "")), 0.8))
			out.D8 = maxf(float(out.D8), cred * float(tr.get("credulity", 0.5)) * 2.0 * frac)
	out.D8 = minf(float(out.D8), 1.0)
	# D9.
	if m.plans != null and m.plans.policy_on(m, pid, cat): out.D9 = 1.0
	return out

## [rival pid, tension]: a faction's enemies; a firm's peers making the same.
static func rivals(m: MarketState, pid: String) -> Array:
	var out: Array = []
	if MarketLedgers.is_firm(pid):
		var mine: Dictionary = FirmCatalog.info(MarketLedgers.id_of(pid)).get("out", {})
		for id in FirmCatalog.ORDER:
			if id == MarketLedgers.id_of(pid): continue
			var theirs: Dictionary = FirmCatalog.info(id).get("out", {})
			for c in mine:
				if theirs.has(c):
					out.append(["c:" + id, 0.3])
					break
		return out
	var f := MarketLedgers.id_of(pid)
	for b in m.actors.enemies_of(f):
		out.append(["f:" + str(b), FactionAICatalog.tension(m.actors.relation(f, str(b)))])
	return out

## The line's mean over its last 7 daily closes (fewer when it is younger).
static func mean7(line: MarketState.Book) -> float:
	var n := line.cd.size() / MarketState.FIELDS
	if n <= 1:
		var n15 := line.c15.size() / MarketState.FIELDS
		if n15 < 8: return line.mu * line.lt
		var s := 0.0
		var k0 := maxi(0, n15 - 96)
		for k in range(k0, n15): s += line.c15[k * MarketState.FIELDS + 3]
		return s / (n15 - k0)
	var sum := 0.0
	var k1 := maxi(0, n - 7)
	for k in range(k1, n): sum += line.cd[k * MarketState.FIELDS + 3]
	return sum / (n - k1)
