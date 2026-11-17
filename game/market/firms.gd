class_name Firms
extends RefCounted

## §3.2 / §3.8.4: the listed firms as actors. Each produces (capacity × use,
## use drifting toward demand), buys its inputs and sells its output as flow
## on the factions' books, books the result every day, closes a quarter
## every 7 days (8 kept), pays dividends, buys back or issues, expands or
## shrinks, and is restructured (never delisted) when its equity goes below 0.
## Money inside is 龙门币 at the fixed base rate; screens show the firm's own
## currency. Share prices live on MarketState.stocks.

const ROUND := 900
const DAY := 86400
const QUARTER_DAYS := 7
const KEEP_QUARTERS := 8
const KEEP_DAYS := 14
const UTIL_STEP := 0.1
const EXPAND_UTIL := 0.85
const SHRINK_UTIL := 0.5
const STREAK := 5
const FAIR_PE := {"cycle": 8.0, "slow": 11.0, "stable": 15.0, "fast": 22.0}
const TONE_GROWTH := {"cycle": -0.02, "slow": 0.05, "stable": 0.12, "fast": 0.3}
const PUBLIC_SHARE := 0.05

var firms := {}
var news_day := 0     # headlines in the last day (玫瑰报业)
var freight := 0.0    # 企鹅物流's carried fees since the last round
var volume := 0.0     # the market's traded value since the last round
var _round := -1
var _day := -1

func start(m: MarketState) -> void:
	firms.clear()
	m.stocks.clear()
	for id in FirmCatalog.ORDER:
		var info := FirmCatalog.info(id)
		var ni_day := _start_ni_day(info)
		var shares := float(info.shares)
		var eps_year := maxf(ni_day, float(info.revenue) * 0.02) * FirmCatalog.YEAR_DAYS / shares
		var f := {"cash": float(info.revenue) * 30.0, "debt": float(info.capital) * 0.2, "capital": float(info.capital), "cap": float(info.revenue),
			"util": 0.8, "shares": shares, "base": eps_year * FirmCatalog.START_PE, "holders": {}, "today": _blank(), "days": [], "quarters": [],
			"retained": 0.0, "payout": float(info.payout), "hi": 0, "lo": 0, "boost": 1.0, "boost_until": 0, "up_q": 0, "cur": str(info.cur), "restructured": 0}
		firms[id] = f
		var b := MarketState.Book.new()
		b.setup_stock(id)
		b.i = 1.0
		b.mu = 1.0
		b.wp = 1.0
		b.w0 = m.t
		m.stocks[id] = b
	_round = int(m.t / ROUND)
	_day = MarketState.day_key(m.t)

static func _start_ni_day(info: Dictionary) -> float:
	var rev := float(info.revenue) * 0.8
	return rev * (1.0 - float(info.input) - float(info.sga) - float(info.rd)) - float(info.capital) * float(info.get("depreciation", FirmCatalog.DEPRECIATION))

static func _blank() -> Dictionary:
	return {"rev": 0.0, "cogs": 0.0, "sga": 0.0, "rd": 0.0, "dep": 0.0, "interest": 0.0, "ni": 0.0, "capex": 0.0, "div": 0.0, "buyback": 0.0, "issued": 0.0}

# --- Prices ---------------------------------------------------------------------------------

func f_of(id: String) -> Dictionary: return firms.get(id, {})

## 龙门币 a share at the index's base.
func base_lmd(id: String) -> float: return float(f_of(id).get("base", 1.0))

func share_price_lmd(id: String, m: MarketState = null) -> float:
	var b: MarketState.Book = (m.stocks.get(id) if m != null else null)
	return base_lmd(id) * (b.i if b != null else _index_cache.get(id, 1.0))

var _index_cache := {}

func price_from_index(id: String, i: float) -> float:
	_index_cache[id] = i
	return base_lmd(id) * i / Currencies.lmd_per_unit(FirmCatalog.currency(id))

func market_cap_lmd(id: String) -> float:
	var f := f_of(id)
	return base_lmd(id) * float(_index_cache.get(id, 1.0)) * float(f.get("shares", 1.0))

## Where its price is pulled: earnings at the class's fair multiple, never
## under half its book value a share (§3.2, the crowd's value side reads it too).
func fair_index(id: String) -> float:
	var f := f_of(id)
	if f.is_empty(): return 1.0
	# Worked out once at each round's start and kept with the firm (a save
	# loaded mid-round goes on with the same number).
	if int(f.get("fair_round", -1)) == _round: return float(f.fair_i)
	var r := cached_ratios(id)
	var e := _e
	var pe := float(FAIR_PE.get(str(r.class_id), 15.0)) * (1.0 + 0.2 * e)
	var fair := maxf(float(r.eps_year) * pe, 0.5 * float(r.book_ps))
	if (f.quarters as Array).size() < 2: fair = lerpf(base_lmd(id), fair, 0.3)
	var v := clampf(fair / maxf(base_lmd(id), 0.01), 0.05, 20.0)
	f["fair_round"] = _round
	f["fair_i"] = v
	return v

var _e := 0.0
var _fair_cache := {}
var _ratio_cache := {}

## ratios() at the round's price, worked out once a round (the AI reads it often).
func cached_ratios(id: String) -> Dictionary:
	var c: Array = _ratio_cache.get(id, [])
	if not c.is_empty() and int(c[0]) == _round: return c[1]
	var r := ratios(id, base_lmd(id) * float(_index_cache.get(id, 1.0)))
	_ratio_cache[id] = [_round, r]
	return r

# --- The round -------------------------------------------------------------------------------

func step(m: MarketState, dt: int) -> void:
	if firms.is_empty(): start(m)
	_e = m.econ.e if m.econ != null else 0.0
	for id in firms: _index_cache[id] = (m.stocks[id] as MarketState.Book).i if m.stocks.has(id) else 1.0
	_ratio_cache.clear()
	var day := MarketState.day_key(m.t)
	if day != _day:
		_day = day
		_day_close(m)
	var r := int(m.t / ROUND)
	if r == _round: return
	_round = r
	news_day = 0
	for n in m.news:
		if int(n.t) > m.t - DAY: news_day += 1
	for id in firms:
		firms[id]["fair_round"] = -1
		fair_index(str(id))
	for id in firms: _produce(m, str(id))
	freight = 0.0
	volume = 0.0

## Demand a day (龙门币 of revenue) now (§3.8.4).
func demand(m: MarketState, id: String) -> float:
	var info := FirmCatalog.info(id)
	var f := f_of(id)
	var base := float(info.revenue) * (m.econ.demand_mult() if m.econ != null else 1.0)
	if int(f.boost_until) > m.t: base *= float(f.boost)
	match str(info.get("service", "")):
		"defense": base *= 1.0 + 0.3 * maxf(0.0, m.factor("war") if m.factors.has("war") else 0.0)
		"news": base *= 0.6 + 0.4 * clampf(news_day / 40.0, 0.0, 2.0)
		"rent": base *= _composite(m, "lungmen") * (1.0 - clampf((m.policy_rate("lmd") - 0.02) * 5.0, -0.3, 0.3))
		"freight_penguin": base *= 0.7 + clampf(volume / 2000000.0, 0.0, 0.6) + clampf(freight / 20000.0, 0.0, 0.5)
		"freight": base *= 0.7 + clampf(volume / 2000000.0, 0.0, 0.6)
		"vehicles": base *= m.econ.demand_mult() if m.econ != null else 1.0
		"telecom", "liquor": pass
	return base

static func _composite(m: MarketState, faction: String) -> float:
	var t := 0.0
	var n := 0
	for b: MarketState.Book in m.books.values():
		if b.faction == faction:
			t += b.i
			n += 1
	return t / maxf(1.0, n) if n > 0 else 1.0

## The mean index of the books trading these categories.
static func _cat_index(m: MarketState, cats: Dictionary) -> float:
	if cats.is_empty(): return 1.0
	var total := 0.0
	var w := 0.0
	for cat in cats:
		var sum := 0.0
		var n := 0
		for b: MarketState.Book in m.books.values():
			if b.category == cat:
				sum += b.i
				n += 1
		if n == 0: continue
		total += float(cats[cat]) * sum / n
		w += float(cats[cat])
	return total / w if w > 0.0 else 1.0

func _produce(m: MarketState, id: String) -> void:
	var info := FirmCatalog.info(id)
	var f := f_of(id)
	var frac := float(ROUND) / DAY
	var units := float(f.cap) * float(f.util) * frac
	var out_cats: Dictionary = info.out
	var in_cats: Dictionary = info.get("in", {})
	var rev := units * _cat_index(m, out_cats)
	var cogs := units * float(info.input) * _cat_index(m, in_cats)
	# Inputs bought and output sold as flow on the books.
	for cat in in_cats:
		var market := MarketActors.best_seller(m, "", str(cat))
		if not market.is_empty(): m.actors.place(m, market, units * float(info.input) * float(in_cats[cat]), "firm:" + id)
	for cat in out_cats:
		var market := MarketActors.best_buyer(m, "", str(cat))
		if not market.is_empty(): m.actors.place(m, market, -units * float(out_cats[cat]), "firm:" + id)
	var sga := rev * float(info.sga)
	var rd := rev * float(info.rd)
	var dep := float(f.capital) * float(info.get("depreciation", FirmCatalog.DEPRECIATION)) * frac
	var rate := m.credit.base_rate(m) if m.credit != null else 0.001
	var interest := float(f.debt) * rate * frac
	var ni := rev - cogs - sga - rd - dep - interest
	var t: Dictionary = f.today
	t.rev = float(t.rev) + rev
	t.cogs = float(t.cogs) + cogs
	t.sga = float(t.sga) + sga
	t.rd = float(t.rd) + rd
	t.dep = float(t.dep) + dep
	t.interest = float(t.interest) + interest
	t.ni = float(t.ni) + ni
	f.cash = float(f.cash) + rev - cogs - sga - rd - interest

# --- The day and the quarter -----------------------------------------------------------------

func _day_close(m: MarketState) -> void:
	for id in firms:
		var f: Dictionary = firms[id]
		var info := FirmCatalog.info(id)
		# Use toward demand, at most 10% a day.
		var want := clampf(demand(m, str(id)) / maxf(float(f.cap), 1.0), 0.0, 1.0)
		f.util = clampf(float(f.util) + clampf(want - float(f.util), -UTIL_STEP, UTIL_STEP), 0.05, 1.0)
		f.hi = int(f.hi) + 1 if float(f.util) > EXPAND_UTIL else 0
		f.lo = int(f.lo) + 1 if float(f.util) < SHRINK_UTIL else 0
		var rate := m.credit.base_rate(m) * FirmCatalog.YEAR_DAYS if m.credit != null else 0.056
		var roi := _roi(str(id))
		if int(f.hi) >= STREAK and roi > rate:
			# Expanding: cash first, then the pool, then new shares (credit tight).
			var cost := float(f.capital) * 0.1
			if float(f.cash) >= cost: f.cash = float(f.cash) - cost
			elif m.credit != null and m.credit.can_lend(cost) and m.credit.tightness() < 1.0:
				f.debt = float(f.debt) + cost
				m.credit.demand += cost
			else: _issue(m, str(id), cost)
			f.capital = float(f.capital) + cost
			f.cap = float(f.cap) * 1.1
			f.today.capex = float(f.today.capex) + cost
			f.hi = 0
		elif int(f.lo) >= STREAK:
			f.cap = float(f.cap) * 0.92
			f.capital = float(f.capital) * 0.95
			f.lo = 0
		# Buy back when flush and cheap; issue when short of cash.
		var price := share_price_lmd(str(id), m)
		var costs_day := float(info.revenue) * (float(info.input) + float(info.sga) + float(info.rd))
		if float(f.cash) > costs_day * 60.0 and price < base_lmd(str(id)) * fair_index(str(id)) * 0.9:
			var spend := float(f.cash) * 0.02
			var n := spend / maxf(price, 0.01)
			f.cash = float(f.cash) - spend
			f.shares = maxf(float(f.shares) * 0.5, float(f.shares) - n)
			f.today.buyback = float(f.today.buyback) + spend
			m.actors.place(m, str(id), n * base_lmd(str(id)), "firm:" + str(id), true)
			if m.rng.randf() < 0.3: m.fire("AE3", {"firm": str(id)})
		elif float(f.cash) < 0.0:
			_issue(m, str(id), -float(f.cash) + costs_day * 10.0)
		f.retained = float(f.retained) + float(f.today.ni)
		f.days.append(f.today)
		if f.days.size() > KEEP_DAYS: f.days = f.days.slice(f.days.size() - KEEP_DAYS)
		f.today = _blank()
		if _day % QUARTER_DAYS == 0: _close_quarter(m, str(id))
		# §3.8.4 困境: equity below zero, restructured and still listed.
		if equity(str(id)) < 0.0: _restructure(m, str(id))
	_research_note(m)

## §3.2 PRTS 研报: one line a trading day, from the numbers, no opinion.
func _research_note(m: MarketState) -> void:
	var with_q: Array = firms.keys().filter(func(id): return (firms[id].quarters as Array).size() >= 2)
	if with_q.is_empty(): return
	var id := str(with_q[_day % with_q.size()])
	var q: Array = firms[id].quarters
	var a := float(q[-2].eps)
	var b := float(q[-1].eps)
	var r := cached_ratios(id)
	var title := "%s 季报 EPS 环比 %+.0f%%，增长调整市盈率 %s" % [FirmCatalog.name_of(id), (b - a) / maxf(absf(a), 1e-6) * 100.0, ("%.1f" % float(r.peg)) if float(r.peg) < 99.0 else "—"]
	m.news.append({"t": m.t, "id": "PRTS研报", "kind": "announce", "title": title, "region": str(FirmCatalog.info(id).region), "cred": "", "status": "", "unread": true, "markets": [], "moves": {}, "picks": {"firm": id}})  # i18n: skip
	if m.news.size() > MarketState.NEWS_KEEP: m.news = m.news.slice(m.news.size() - MarketState.NEWS_KEEP)

func _issue(m: MarketState, id: String, amount: float) -> void:
	var f := f_of(id)
	var price := maxf(share_price_lmd(id, m), 0.01)
	var n := amount / price
	f.shares = float(f.shares) + n
	f.cash = float(f.cash) + amount
	f.today.issued = float(f.today.issued) + amount
	m.actors.place(m, id, -n * base_lmd(id), "firm:" + id, true)
	m.fire("AE4", {"firm": id})

func equity(id: String) -> float:
	var f := f_of(id)
	return float(f.capital) + float(f.cash) - float(f.debt)

func _roi(id: String) -> float:
	var q: Array = f_of(id).quarters
	if q.is_empty(): return 0.1
	var ni := float(q[-1].ni) * FirmCatalog.YEAR_DAYS / QUARTER_DAYS
	return ni / maxf(float(f_of(id).capital), 1.0)

func _close_quarter(m: MarketState, id: String) -> void:
	var f := f_of(id)
	var days: Array = f.days
	if days.is_empty(): return
	var take := days.slice(maxi(0, days.size() - QUARTER_DAYS))
	var q := _blank()
	for d in take:
		for k in q: q[k] = float(q[k]) + float(d.get(k, 0.0))
	var info := FirmCatalog.info(id)
	# Dividends (§3.3) and the payout's moves (动作即事件).
	var prev: Array = f.quarters
	if float(q.ni) > 0.0 and float(f.payout) > 0.0:
		var total := float(q.ni) * float(f.payout)
		q.div = total
		f.cash = float(f.cash) - total
		f.retained = float(f.retained) - total
		var per := total / maxf(float(f.shares), 1.0)
		_pay_holders(m, id, per)
	if not prev.is_empty():
		if float(q.ni) > float(prev[-1].ni) and float(prev[-1].ni) > 0.0: f.up_q = int(f.up_q) + 1
		else: f.up_q = 0
		if int(f.up_q) >= 3 and str(info.dividend) != "none":
			f.payout = minf(0.8, float(f.payout) + 0.05)
			f.up_q = 0
			m.fire("AE5", {"firm": id})
		elif float(q.ni) < 0.0 and float(f.payout) > 0.05:
			f.payout = float(f.payout) * 0.5
			m.fire("AE7", {"firm": id})
	q["shares"] = float(f.shares)
	q["eps"] = float(q.ni) / maxf(float(f.shares), 1.0)
	q["cash"] = float(f.cash)
	q["debt"] = float(f.debt)
	q["capital"] = float(f.capital)
	q["equity"] = equity(id)
	q["retained"] = float(f.retained)
	q["cfo"] = float(q.ni) + float(q.dep)
	q["current_liab"] = float(f.debt) * 0.3 + (float(q.cogs) + float(q.sga)) / QUARTER_DAYS * 30.0
	q["day"] = _day
	prev.append(q)
	if prev.size() > KEEP_QUARTERS: f.quarters = prev.slice(prev.size() - KEEP_QUARTERS)
	if float(q.rev) > 0.0 and m.rng.randf() < 0.25: m.fire("AE9", {"firm": id})

## Holders get their share: factions in cash, Rhodes through its account (§3.3).
func _pay_holders(m: MarketState, id: String, per_share: float) -> void:
	var f := f_of(id)
	for who in f.holders:
		var n := float(f.holders[who])
		if n <= 0.0: continue
		var w := str(who)
		if w.begins_with("faction:"):
			var a: Dictionary = m.actors.factions.get(w.substr(8), {})
			if not a.is_empty(): a.cash = float(a.cash) + n * per_share
	if m.rhodes != null and m.rhodes.securities != null: m.rhodes.securities.on_dividend(id, per_share)

func _restructure(m: MarketState, id: String) -> void:
	var f := f_of(id)
	if m.t - int(f.restructured) < 7 * DAY: return
	f.restructured = m.t
	f.shares = float(f.shares) * 1.5
	f.debt = float(f.debt) * 0.6
	f.cash = maxf(float(f.cash), 0.0) + float(f.capital) * 0.05
	var b: MarketState.Book = m.stocks.get(id)
	if b != null: b.sh -= 0.35
	m.fire("AE8", {"firm": id})

# --- Ratios (§3.2) ---------------------------------------------------------------------------

## Everything the share page and the strategies read, from the last quarters.
## Prices in 龙门币 a share.
func ratios(id: String, price_lmd: float) -> Dictionary:
	var f := f_of(id)
	var info := FirmCatalog.info(id)
	var q: Array = f.get("quarters", [])
	var shares := maxf(float(f.get("shares", 1.0)), 1.0)
	var out := {"pe": INF, "peg": INF, "dpeg": INF, "fcf_yield": 0.0, "net_cash": float(f.get("cash", 0.0)) - float(f.get("debt", 0.0)),
		"growth": float(TONE_GROWTH.get(str(info.get("tone", "stable")), 0.1)), "class_id": str(info.get("tone", "stable")), "eps_year": 0.0,
		"book_ps": equity(id) / shares, "yield": 0.0, "moat": [], "moat_count": 0}
	if q.is_empty():
		var ni_day := _start_ni_day(info)
		out.eps_year = ni_day * FirmCatalog.YEAR_DAYS / shares
	else:
		var eps_sum := 0.0
		var take := q.slice(maxi(0, q.size() - 4))
		for x in take: eps_sum += float(x.eps)
		out.eps_year = eps_sum / take.size() * FirmCatalog.YEAR_DAYS / QUARTER_DAYS
		if q.size() >= 2:
			var first := float(q[maxi(0, q.size() - 5)].eps)
			var last := float(q[-1].eps)
			var n := mini(q.size() - 1, 4)
			if first > 0.0 and last > 0.0: out.growth = pow(last / first, 3.0 / n) - 1.0
			elif last < first: out.growth = -0.1
		var div_year := 0.0
		var cfo := 0.0
		var capex := 0.0
		for x in take:
			div_year += float(x.div)
			cfo += float(x.cfo)
			capex += float(x.capex)
		var scale := FirmCatalog.YEAR_DAYS / (QUARTER_DAYS * take.size())
		out.yield = div_year * scale / shares / maxf(price_lmd, 0.01)
		out.fcf_yield = (cfo - capex) * scale / maxf(price_lmd * shares, 1.0)
	var g := float(out.growth)
	out.class_id = "cycle" if g < 0.0 else ("slow" if g < 0.08 else ("stable" if g <= 0.2 else "fast"))
	if float(out.eps_year) > 0.0:
		out.pe = price_lmd / float(out.eps_year)
		if g > 0.0: out.peg = float(out.pe) / (g * 100.0)
		if g + float(out.yield) > 0.0: out.dpeg = float(out.pe) / ((g + float(out.yield)) * 100.0)
	out.moat = moat(id)
	out.moat_count = (out.moat as Array).filter(func(x): return bool(x[1])).size()
	return out

## §3.2 护城河 12 条: [name, passed, value] over the kept quarters.
func moat(id: String) -> Array:
	var f := f_of(id)
	var q: Array = f.get("quarters", [])
	var sum := _blank()
	for x in q:
		for k in sum: sum[k] = float(sum[k]) + float(x.get(k, 0.0))
	var rev := maxf(float(sum.rev), 1.0)
	var gross := float(sum.rev) - float(sum.cogs)
	var op := gross - float(sum.sga) - float(sum.rd) - float(sum.dep)
	var eps_up := q.size() >= 2
	var ret_up := q.size() >= 2
	for k in range(1, q.size()):
		if float(q[k].eps) < float(q[k - 1].eps): eps_up = false
		if float(q[k].retained) < float(q[k - 1].retained): ret_up = false
	var last: Dictionary = q[-1] if not q.is_empty() else {"cash": f.get("cash", 0.0), "current_liab": 1.0, "debt": f.get("debt", 0.0), "equity": equity(id)}
	var eq := maxf(float(last.get("equity", 1.0)), 1.0)
	var cfo := float(sum.ni) + float(sum.dep)
	return [
		["毛利率 ≥40%", gross / rev >= 0.4, gross / rev],
		["销售管理费率 ≤30%", float(sum.sga) / maxf(gross, 1.0) <= 0.3, float(sum.sga) / maxf(gross, 1.0)],
		["研发费率 ≤30%", float(sum.rd) / maxf(gross, 1.0) <= 0.3, float(sum.rd) / maxf(gross, 1.0)],
		["折旧率 ≤10%", float(sum.dep) / maxf(gross, 1.0) <= 0.1, float(sum.dep) / maxf(gross, 1.0)],
		["利息负担 ≤15%", float(sum.interest) / maxf(op, 1.0) <= 0.15 and op > 0.0, float(sum.interest) / maxf(op, 1.0)],
		["净利率 ≥20%", float(sum.ni) / rev >= 0.2, float(sum.ni) / rev],
		["EPS 连续增长", eps_up, 1.0 if eps_up else 0.0],
		["现金 > 短期负债", float(last.get("cash", 0.0)) > float(last.get("current_liab", 0.0)), float(last.get("cash", 0.0)) / maxf(float(last.get("current_liab", 1.0)), 1.0)],
		["调整后负债权益比 <0.8", float(last.get("debt", 0.0)) / eq < 0.8, float(last.get("debt", 0.0)) / eq],
		["无优先股", true, 0.0],
		["留存收益持续增长", ret_up, 1.0 if ret_up else 0.0],
		["资本开支率 <25%", float(sum.capex) / maxf(cfo, 1.0) < 0.25, float(sum.capex) / maxf(cfo, 1.0)],
	]

## Mean earnings growth across the firms (the cycle's firm part, §3.6).
func profit_growth() -> float:
	if firms.is_empty(): return 0.0
	var t := 0.0
	for id in firms:
		var q: Array = firms[id].quarters
		if q.size() < 2: continue
		var a := float(q[-2].ni)
		var b := float(q[-1].ni)
		t += clampf((b - a) / maxf(absf(a), 1.0), -1.0, 1.0)
	return t / firms.size()

# --- Shares -----------------------------------------------------------------------------------

## A faction picks what to buy: 卡西米尔's own firms first, else the strongest moat for the price.
func pick_for(faction: String, m: MarketState) -> String:
	var best := ""
	var score := -INF
	var home := str(FactionAICatalog.info(faction).get("investor", ""))
	for id in firms:
		var r := cached_ratios(str(id))
		var s := float(r.moat_count) - minf(float(r.pe), 60.0) / 20.0
		if not home.is_empty() and FirmCatalog.currency(str(id)) == home: s += 4.0
		if s > score:
			score = s
			best = str(id)
	return best

## Buys `spend_lmd` of `id` for `who`; returns the shares (orders move the book over the round).
func buy_shares(m: MarketState, id: String, spend_lmd: float, who: String) -> float:
	var f := f_of(id)
	if f.is_empty() or spend_lmd <= 0.0: return 0.0
	var n := spend_lmd / maxf(share_price_lmd(id, m), 0.01)
	f.holders[who] = float(f.holders.get(who, 0.0)) + n
	m.actors.place(m, id, n * base_lmd(id), who, true)
	return n

## Sells `n` shares for `who`; returns the 龙门币 at today's price.
func sell_shares(m: MarketState, id: String, n: float, who: String) -> float:
	var f := f_of(id)
	if f.is_empty() or n <= 0.0: return 0.0
	n = minf(n, float(f.holders.get(who, 0.0)))
	if n <= 0.0: return 0.0
	f.holders[who] = float(f.holders[who]) - n
	if float(f.holders[who]) <= 0.0001: f.holders.erase(who)
	m.actors.place(m, id, -n * base_lmd(id), who, true)
	return n * share_price_lmd(id, m)

func holding(id: String, who: String) -> float:
	return float(f_of(id).get("holders", {}).get(who, 0.0))

## §3.8.10 主要持有人: who holds what share, the crowds' positions included.
func holders(m: MarketState, id: String) -> Array:
	var f := f_of(id)
	var total := maxf(float(f.get("shares", 1.0)), 1.0)
	var out: Array = []
	for who in f.get("holders", {}):
		var n := float(f.holders[who])
		var w := str(who)
		var name := w
		if w.begins_with("faction:"): name = FactionCatalog.name_of(w.substr(8))
		elif w == "rhodes": name = "罗德岛"
		out.append([name, n / total])
	for g in m.actors.groups:
		var pos := float((m.actors.groups[g].pos as Dictionary).get(id, 0.0))
		if pos > 0.0: out.append([str({"value": "价值型", "trend": "趋势型", "maker": "做市型", "noise": "噪声型"}[g]), pos / maxf(base_lmd(id), 0.01) / total])
	out.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
	return out

## §3.8.8 layer 2: Rhodes' holdings past 5%, in 龙门币 (public).
func public_holders() -> Dictionary:
	var out := {}
	for id in firms:
		var n := holding(str(id), "rhodes")
		if n / maxf(float(firms[id].shares), 1.0) >= PUBLIC_SHARE: out[id] = n * share_price_lmd(str(id))
	return out

# --- News ------------------------------------------------------------------------------------

## The firm events (运营策划案 §3.4): orders lift demand for a while; bad news cuts the price.
func on_event(m: MarketState, id: String, picks: Dictionary) -> void:
	var firm := str(picks.get("firm", ""))
	var f := f_of(firm)
	if f.is_empty(): return
	var b: MarketState.Book = m.stocks.get(firm)
	match id:
		"FE1", "FE3":
			f.boost = 1.5
			f.boost_until = m.t + 5 * DAY
			if b != null: b.sh += 0.08
		"FE2":
			f.boost = 0.7
			f.boost_until = m.t + 3 * DAY
			if b != null: b.sh -= 0.1
		"FE4":
			f.boost = 0.6
			f.boost_until = m.t + 4 * DAY
			if b != null: b.sh -= 0.15
		"FE5", "FE6":
			f.cap = float(f.cap) * 1.08
			if b != null: b.sh += 0.12

func to_data() -> Dictionary:
	return {"firms": firms.duplicate(true), "round": _round, "day": _day, "news_day": news_day, "freight": freight, "volume": volume}

func load_data(d: Dictionary) -> void:
	firms = (d.get("firms", {}) as Dictionary).duplicate(true) if d.get("firms") is Dictionary else {}
	_round = int(d.get("round", -1))
	_day = int(d.get("day", -1))
	news_day = int(d.get("news_day", 0))
	freight = float(d.get("freight", 0.0))
	volume = float(d.get("volume", 0.0))
	for id in FirmCatalog.ORDER:
		if not firms.has(id): firms.clear()
