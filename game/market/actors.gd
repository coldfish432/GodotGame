class_name MarketActors
extends RefCounted

## §3.8: who trades and how they decide. Nine factions with books of their own
## (cash, stock by category, debt, character), the four crowds (value, trend,
## maker, noise) and the central banks (MarketState's pegs and policy rates).
## Every 15 minutes of the Rhodes clock each actor looks, scores what it needs,
## picks the best one or two actions and turns them into orders, spread over
## the next round as flow on the books (MarketState.add_flow). A utility AI:
## no trees, no search. §3.8.8: factions see Rhodes only through the layers
## of information it leaves (their own venue, what is public, what they infer).

const ROUND := 900
const DAY := 86400
## §3.8.2: an actor moves at most this share of a book's depth a round.
const IMPACT_CAP := 0.05
const THRESHOLD := 0.15
const INERTIA := 0.1
## §3.8.5 the crowds' money (龙门币), split between them by recent results.
const CROWD_CASH := 30000000.0
const GROUPS := ["value", "trend", "maker", "noise"]
const START_SHARE := {"value": 0.35, "trend": 0.3, "maker": 0.2, "noise": 0.15}
const CROWD_POSITION := 0.5
## §3.8.7 drift.
const DRIFT_STEP := 0.02
const DRIFT_RANGE := 0.3
const DRIFT_BACK := 0.05
## §3.8.8 the layers: days of the upkeep's buying before it is learned / forgotten.
const LEARN_DAYS := 3
const LEARN_DAYS_RAT := 2
const FORGET_DAYS := 3
const FOOTPRINT := 0.1
const ESTIMATE_RANGE := Vector2(0.5, 1.5)
const ESTIMATE_RANGE_RAT := Vector2(0.8, 1.2)
const ESTIMATE_DECAY := 0.6
## Daily budget for hostile trades, by rank (冷漠 3%, 中立 1%, v0.8 默认).
const HOSTILE_BUDGET := [0.03, 0.01, 0.0, 0.0, 0.0, 0.0]
const HOSTILE_TENDENCY := [1.0, 0.3, 0.0, 0.0, 0.0, 0.0]
const FRIEND_TENDENCY := [0.0, 0.0, 0.3, 0.6, 1.0, 1.0]
const LOSS_CAP := 0.1
const GRUDGE_DECAY := 0.8
## Faction to faction (§3.9.4): conflict per 龙门币 harassed, its daily fade.
const CONFLICT_PER_LMD := 1.0 / 400.0
const CONFLICT_FADE := 0.95
## Event chains (§3.4): a cooldown per event and per faction.
const EVENT_COOLDOWN := 12 * 3600
const SELL_STREAK_EVENT := 3
## A faction's own income a day, as a share of what it uses (§3.8.9 势力不会破产).
const INCOME_SHARE := 1.1
## A faction stops borrowing once it owes this many days of what it uses.
const DEBT_DAYS := 30.0
## §3.8.9: below 5% of what it started with, its home sends 2% of that a day.
## A faction selling goods it did not make gets this share of the price.
const RESALE := 0.6
## Cash over this × the start is spent at home, HOME_SPEND a day (2026-11-14).
const HOME_SPEND_ABOVE := 2.0
const HOME_SPEND := 0.03
const HOME_HELP_BELOW := 0.05
const HOME_HELP := 0.02

var factions := {}     # id -> ledger
var groups := {}       # id -> {cash, pos: {book: notional}, worth: [..7]}
var pending := {}        # "b|market" / "s|firm" -> {left, rate}: what is still to trade this round
var reactions: Array = [] # {at, faction, market, amount, news_t, who}
var cooldowns := {}    # event id / faction -> until
var upkeep_today := {} # market -> true (seen at today's open)
var maker_share := 0.2
var _round := -1
var _day := -1

func start(m: MarketState) -> void:
	factions.clear()
	groups.clear()
	pending.clear()
	for f in FactionAICatalog.FACTIONS:
		var info := FactionAICatalog.info(f)
		var traits: Dictionary = (info.traits as Dictionary).duplicate()
		var inv := {}
		for cat in info.use: inv[cat] = float(info.use[cat]) * _target_days(traits)
		factions[f] = {"cash": float(info.cash), "debt": 0.0, "inv": inv, "traits": traits.duplicate(), "base": traits,
			"start": float(info.cash), "worth": [], "last": "", "rel": {}, "seen": {}, "miss": {}, "learned": {}, "est": {},
			"grudge": 0.0, "rhodes": [], "spent": 0.0, "sold": {}, "sells": {}, "shares": {}}
	for g in GROUPS: groups[g] = {"cash": CROWD_CASH * float(START_SHARE[g]), "pos": {}, "worth": []}
	_round = int(m.t / ROUND)
	_day = MarketState.day_key(m.t)

static func _target_days(traits: Dictionary) -> float:
	return 2.0 + 8.0 * float(traits.get("patience", 0.5))

# --- Relations between factions (§3.9.4) --------------------------------------------------

func relation(a: String, b: String) -> float:
	var r: Dictionary = (factions.get(a, {}) as Dictionary).get("rel", {})
	var e: Dictionary = r.get(b, {})
	return clampf(FactionAICatalog.base_relation(a, b) + float(e.get("conflict", 0.0)) + float(e.get("event", 0.0)), -1000.0, 1000.0)

func tier(a: String, b: String) -> String: return FactionAICatalog.tier_name(relation(a, b))

func _shift(a: String, b: String, key: String, amount: float) -> void:
	if not factions.has(a) or a == b or a == "penguin" or b == "penguin": return
	var r: Dictionary = factions[a].rel
	if not r.has(b): r[b] = {"conflict": 0.0, "event": 0.0}
	r[b][key] = clampf(float(r[b][key]) + amount, -1000.0, 1000.0)

## An event's attitude change between two factions (§3.9.4).
func event_shift(a: String, b: String, amount: float) -> void:
	_shift(a, b, "event", amount)

func enemies_of(a: String) -> Array:
	var out: Array = []
	for b in factions:
		if b != a and FactionAICatalog.tension(relation(a, str(b))) > 0.0: out.append(str(b))
	return out

# --- The step ------------------------------------------------------------------------------

## Called after every market step: the round's orders come in as flow; a new
## round decides; a new day settles.
func step(m: MarketState, dt: int) -> void:
	if factions.is_empty(): start(m)
	_execute(m, dt)
	var day := MarketState.day_key(m.t)
	if day != _day:
		_day_close(m, day)
		_day = day
	var r := int(m.t / ROUND)
	if r != _round:
		_round = r
		_decide_all(m)

func _execute(m: MarketState, dt: int) -> void:
	if pending.is_empty(): return
	var done: Array = []
	for key in pending:
		var o: Dictionary = pending[key]
		var left := float(o.left)
		var amt := minf(absf(left), float(o.rate) * dt)
		var signed := amt * signf(left)
		o.left = left - signed
		var k := str(key)
		if k.begins_with("s|"): m.add_stock_flow(k.substr(2), signed)
		else: m.add_flow(k.substr(2), signed)
		if absf(float(o.left)) <= 1.0: done.append(key)
	for key in done: pending.erase(key)

## An order of `lmd` (signed, base price) spread over the next round.
func place(m: MarketState, market: String, lmd: float, who: String, stock := false) -> float:
	var depth := m.stock_depth(market) if stock else m.depth(market)
	var cap := depth * IMPACT_CAP
	var amount := clampf(lmd, -cap, cap)
	if absf(amount) < 1.0: return 0.0
	var key := ("s|" if stock else "b|") + market
	var o: Dictionary = pending.get(key, {"left": 0.0, "rate": 0.0})
	o.left = float(o.left) + amount
	o.rate = maxf(float(o.rate), absf(float(o.left)) / ROUND)
	pending[key] = o
	if who == "rhodes_upkeep" and not stock: m.actors.saw_upkeep(market)
	return amount

# --- Deciding -------------------------------------------------------------------------------

func _decide_all(m: MarketState) -> void:
	for f in factions: _decide_faction(m, str(f))
	_decide_groups(m)
	_reactions_due(m)
	if m.rhodes != null and m.t % 3600 < ROUND: _rhodes_round(m)

## The book of `faction` for `category` ("" when it has none).
static func book_of(m: MarketState, faction: String, category: String) -> String:
	var id := "%s:%s" % [faction, category]
	return id if m.books.has(id) else ""

## Where a faction sells `category`: the book that pays best among the others.
static func best_buyer(m: MarketState, seller: String, category: String) -> String:
	var best := ""
	var bid := -1.0
	for b: MarketState.Book in m.books.values():
		if b.fx or b.category != category or b.faction == seller: continue
		if b.i > bid:
			bid = b.i
			best = b.id
	return best

## The mean index of the books trading `category`.
static func cat_price(m: MarketState, category: String) -> float:
	var t := 0.0
	var n := 0
	for b: MarketState.Book in m.books.values():
		if b.category == category and not b.fx:
			t += b.i
			n += 1
	return t / n if n > 0 else 1.0

## Where a faction buys `category`: its own book, else the cheapest that trades it.
static func best_seller(m: MarketState, buyer: String, category: String) -> String:
	var own := book_of(m, buyer, category)
	if not own.is_empty(): return own
	var best := ""
	var ask := INF
	for b: MarketState.Book in m.books.values():
		if b.fx or b.category != category: continue
		if b.i < ask:
			ask = b.i
			best = b.id
	return best

func fair(m: MarketState, market: String) -> float:
	var b: MarketState.Book = m.books.get(market)
	if b == null: return 1.0
	return b.mu * b.lt * float(m.mods(market).get("mult", 1.0)) * exp(b.sh)

## §3.8.6 the price an actor expects: fair value and the trend, by its tilt.
func expected(m: MarketState, market: String, value_tilt: float) -> float:
	var b: MarketState.Book = m.books.get(market)
	if b == null: return 1.0
	var trend := b.i * (1.0 + clampf(b.mo * 3600.0, -0.2, 0.2))
	return fair(m, market) * value_tilt + trend * (1.0 - value_tilt)

func _decide_faction(m: MarketState, f: String) -> void:
	var a: Dictionary = factions[f]
	var info := FactionAICatalog.info(f)
	var tr: Dictionary = a.traits
	var days := float(ROUND) / DAY
	var dm := m.econ.demand_mult() if m.econ != null else 1.0
	# The round's use and making.
	for cat in info.use: a.inv[cat] = maxf(0.0, float(a.inv.get(cat, 0.0)) - float(info.use[cat]) * days * dm)
	# Makers make more when it pays (elastic supply).
	for cat in info.make: a.inv[cat] = float(a.inv.get(cat, 0.0)) + float(info.make[cat]) * days * (2.0 - dm if bool(info.get("volatile", false)) else 1.0) * clampf(cat_price(m, str(cat)), 0.6, 1.6)
	if bool(info.get("carrier", false)): return
	var target_days := _target_days(tr)
	var use_day := 0.0
	for cat in info.use: use_day += float(info.use[cat])
	var cands: Array = []
	for cat in info.use:
		var target := float(info.use[cat]) * target_days
		var have := float(a.inv.get(cat, 0.0))
		var market := best_seller(m, f, str(cat))
		if market.is_empty(): continue
		var need := clampf((target - have) / maxf(target, 1.0), 0.0, 1.0)
		# Dear goods are bought less and later (elastic demand).
		var px := m.index(market)
		need *= clampf(1.6 - 0.6 * px, 0.15, 1.2)
		if need > 0.0: cands.append({"kind": "buy", "m": market, "cat": cat, "amt": minf(target - have, float(info.use[cat])) * clampf(1.0 / (px * px), 0.25, 2.0), "score": need})
		# Hoarding: it expects higher prices.
		var lift := expected(m, market, float(tr.value)) / maxf(m.index(market), 0.05) - 1.0
		# Hoarding has a ceiling: a stock of twice the target at most, and not on credit.
		var room := target * 2.0 - have
		if lift > 0.02 and room > 0.0 and float(a.cash) > use_day * 5.0:
			cands.append({"kind": "hoard", "m": market, "cat": cat, "amt": minf(room, float(info.use[cat]) * 0.5), "score": clampf(lift * 10.0, 0.0, 1.0) * (1.0 - float(tr.risk) * 0.5)})
	for cat in a.inv:
		var target := float(info.use.get(cat, 0.0)) * target_days + float(info.make.get(cat, 0.0))
		# What it uses is kept up to the hoarding ceiling (twice the target): selling
		# from the target up made it buy at home and dump abroad round after round
		# (萨米 lost its cash that way, 2026-11-14). Short of cash, down to the target.
		if info.use.has(cat) and float(a.cash) >= use_day * 2.0:
			target += float(info.use[cat]) * target_days
		var extra := float(a.inv[cat]) - target
		if extra <= 0.0: continue
		var market := best_buyer(m, f, str(cat))
		if market.is_empty(): continue
		var need := clampf(extra / maxf(target, float(info.make.get(cat, 1000.0))), 0.0, 1.0)
		if float(a.cash) < use_day * 2.0: need = minf(1.0, need + 0.4)
		cands.append({"kind": "sell", "m": market, "cat": cat, "amt": -extra, "score": need})
	# Harassing the factions it is hostile to (§3.8.3 打压对手), with money to spare.
	for b in (enemies_of(f) if float(a.cash) > use_day * 10.0 else []):
		var tension := FactionAICatalog.tension(relation(f, b))
		var binfo := FactionAICatalog.info(b)
		for cat in binfo.get("use", {}):
			var market := book_of(m, b, str(cat))
			if market.is_empty(): continue
			cands.append({"kind": "harass", "m": market, "cat": cat, "target": b, "amt": float(a.cash) * 0.004, "score": tension * float(tr.revenge) * 0.5})
			break
	# Money: short, it sells shares first, then borrows; flush, it repays or invests (once a day).
	var held_firm := ""
	for firm in a.shares:
		if float(a.shares[firm]) > 0.0:
			held_firm = str(firm)
			break
	if float(a.cash) < use_day * 3.0 and not held_firm.is_empty():
		cands.append({"kind": "divest", "firm": held_firm, "amt": use_day * 5.0, "score": 0.7})
	elif float(a.cash) < use_day * 2.0 and not bool(info.get("no_credit", false)) and int(a.get("borrowed_day", -1)) != _day and float(a.debt) < use_day * DEBT_DAYS:
		cands.append({"kind": "borrow", "amt": use_day * 5.0, "score": 0.6})
	if float(a.debt) > 0.0 and float(a.cash) > use_day * 10.0:
		cands.append({"kind": "repay", "amt": minf(float(a.debt), float(a.cash) - use_day * 10.0), "score": 0.3 + (m.credit.base_rate(m) * 200.0 if m.credit != null else 0.2)})
	if m.firms != null and float(a.cash) > use_day * 30.0 * (1.0 + float(tr.cash)) and int(a.get("invested_day", -1)) != _day:
		var pick := m.firms.pick_for(f, m)
		if not pick.is_empty(): cands.append({"kind": "invest", "firm": pick, "amt": float(a.cash) * 0.05, "score": 0.35 * (1.0 - float(tr.cash))})
	for c in cands:
		var afford := 1.0
		if str(c.kind) in ["buy", "hoard", "harass"]: afford = clampf(float(a.cash) / maxf(absf(float(c.amt)) * m.index(str(c.m)), 1.0), 0.0, 1.0)
		c.score = float(c.score) * afford * (1.0 - float(tr.risk) * 0.2 * m.books.get(str(c.get("m", "")), MarketState.Book.new()).ew * 100.0)
		if str(c.kind) == str(a.last): c.score = float(c.score) + INERTIA
	cands.sort_custom(func(x, y): return float(x.score) > float(y.score))
	var done := 0
	for c in cands:
		if done >= 2 or float(c.score) < THRESHOLD: break
		if _act(m, f, c): done += 1
	a.last = str(cands[0].kind) if not cands.is_empty() and float(cands[0].score) >= THRESHOLD else ""

## §3.8.10: a running 7-day net by category (the 势力页 column).
func _note_net(a: Dictionary, category: String, lmd: float) -> void:
	if not a.has("net7"): a["net7"] = {}
	a.net7[category] = float(a.net7.get(category, 0.0)) + lmd

func _act(m: MarketState, f: String, c: Dictionary) -> bool:
	var a: Dictionary = factions[f]
	if c.has("cat") and str(c.kind) in ["buy", "hoard", "harass", "sell"]: _note_net(a, str(c.cat), float(c.amt))
	match str(c.kind):
		"buy", "hoard", "harass":
			var price := m.index(str(c.m))
			var amt := minf(float(c.amt), float(a.cash) / maxf(price, 0.05))
			var done := place(m, str(c.m), amt, "faction:" + f)
			if done <= 0.0: return false
			a.cash = float(a.cash) - done * price
			a.inv[c.cat] = float(a.inv.get(c.cat, 0.0)) + done
			if m.econ != null: m.econ.faction_net += done
			# 动作即事件: a big purchase is announced (§3.4).
			if str(c.kind) == "buy" and done >= m.depth(str(c.m)) * IMPACT_CAP * 0.9 and _cool(m, "AE2:" + f): m.fire("AE2", {"faction": f})
			if str(c.kind) == "harass":
				_shift(str(c.target), f, "conflict", -done * CONFLICT_PER_LMD)
			return true
		"sell":
			var have := float(a.inv.get(c.cat, 0.0))
			var done := place(m, str(c.m), maxf(float(c.amt), -have), "faction:" + f)
			if done >= 0.0: return false
			a.inv[c.cat] = have + done
			a.cash = float(a.cash) - done * m.index(str(c.m)) * resale(f, str(c.cat))
			if m.econ != null: m.econ.faction_net += done
			a.sold[c.cat] = float(a.sold.get(c.cat, 0.0)) - done
			_friends_take(m, f, str(c.cat), -done)
			return true
		"borrow":
			if m.credit != null and not m.credit.can_lend(float(c.amt)): return false
			a.borrowed_day = _day
			a.cash = float(a.cash) + float(c.amt)
			a.debt = float(a.debt) + float(c.amt)
			if m.credit != null: m.credit.demand += float(c.amt)
			return true
		"repay":
			var amt := minf(float(c.amt), float(a.debt))
			a.cash = float(a.cash) - amt
			a.debt = float(a.debt) - amt
			if m.credit != null: m.credit.demand = maxf(0.0, m.credit.demand - amt)
			return amt > 0.0
		"divest":
			var firm := str(c.firm)
			var price := m.firms.share_price_lmd(firm, m)
			var n := minf(float(a.shares[firm]), float(c.amt) / maxf(price, 0.01))
			var got := m.firms.sell_shares(m, firm, n, "faction:" + f)
			if got <= 0.0:
				a.shares.erase(firm)
				return false
			a.shares[firm] = float(a.shares[firm]) - n
			if float(a.shares[firm]) <= 0.0001: a.shares.erase(firm)
			a.cash = float(a.cash) + got
			return true
		"invest":
			a.invested_day = _day
			var spend := float(c.amt)
			var got := m.firms.buy_shares(m, str(c.firm), spend, "faction:" + f)
			if got <= 0.0: return false
			a.cash = float(a.cash) - spend
			a.shares[c.firm] = float(a.shares.get(c.firm, 0.0)) + got
			return true
	return false

## §3.8.3 合作: a friendly faction that uses the category takes part of what is sold.
func _friends_take(m: MarketState, seller: String, category: String, amount: float) -> void:
	for b in factions:
		if b == seller or tier(str(b), seller) != "友好": continue
		var use: Dictionary = FactionAICatalog.info(str(b)).get("use", {})
		if not use.has(category): continue
		var market := best_seller(m, str(b), category)
		if market.is_empty(): continue
		var take := amount * 0.3
		var a: Dictionary = factions[b]
		if float(a.cash) < take * m.index(market): continue
		var done := place(m, market, take, "faction:" + str(b))
		a.cash = float(a.cash) - done * m.index(market)
		a.inv[category] = float(a.inv.get(category, 0.0)) + done
		_shift(seller, str(b), "conflict", done * CONFLICT_PER_LMD * 0.5)

# --- The crowds (§3.8.5) ---------------------------------------------------------------------

func _decide_groups(m: MarketState) -> void:
	var e := m.econ.e if m.econ != null else 0.0
	maker_share = clampf(float(groups.maker.cash) / maxf(1.0, _crowd_total()), 0.0, 0.6)
	m._depth_slot = -1
	for b: MarketState.Book in m.books.values():
		_crowd_book(m, b.id, false, e)
	if m.firms != null:
		for id in m.stocks: _crowd_book(m, str(id), true, e)

func _crowd_total() -> float:
	var t := 0.0
	for g in groups: t += float(groups[g].cash)
	return t

func _crowd_book(m: MarketState, market: String, stock: bool, e: float) -> void:
	var b: MarketState.Book = m.stocks.get(market) if stock else m.books.get(market)
	if b == null: return
	var depth := m.stock_depth(market) if stock else m.depth(market)
	var price := b.i
	var fair_v := m.firms.fair_index(market) if stock else fair(m, market)
	# Value: back toward fair value, harder the further it strays (3× fair: all in, §3.8.9).
	var dev := log(maxf(price, 0.01) / maxf(fair_v, 0.01))
	var vshare := float(groups.value.cash) / CROWD_CASH * (1.0 - 0.3 * e)
	if absf(dev) > 0.03:
		var boost := 4.0 if absf(dev) > log(3.0) else 1.0
		_crowd_order(m, "value", market, -signf(dev) * minf(absf(dev) * 10.0, 1.0) * depth * 0.02 * vshare * boost, stock, price)
	# Trend: a 20-candle breakout above the 50 average buys, a breakdown sells, otherwise it takes profit.
	var c := b.c15
	var n := c.size() / MarketState.FIELDS
	if n > 52:
		var hi := -INF
		var lo := INF
		for k in range(n - 21, n - 1):
			hi = maxf(hi, c[k * MarketState.FIELDS + 1])
			lo = minf(lo, c[k * MarketState.FIELDS + 2])
		var ma := 0.0
		for k in range(n - 50, n): ma += c[k * MarketState.FIELDS + 3]
		ma /= 50.0
		var tshare := float(groups.trend.cash) / CROWD_CASH * (1.0 + 0.3 * e)
		var pos := float(groups.trend.pos.get(market, 0.0))
		if price > hi and price > ma: _crowd_order(m, "trend", market, depth * 0.015 * tshare, stock, price)
		elif price < lo and price < ma: _crowd_order(m, "trend", market, -depth * 0.015 * tshare, stock, price)
		elif absf(pos) > 1.0: _crowd_order(m, "trend", market, -pos * 0.2, stock, price)
	# Noise.
	var nshare := float(groups.noise.cash) / CROWD_CASH
	_crowd_order(m, "noise", market, m.rng.randfn(0.0, depth * 0.003) * nshare * 4.0, stock, price)

## A crowd's position on one book stays within half the book's depth (base
## price): it cannot snowball on its own size.
func _crowd_order(m: MarketState, g: String, market: String, lmd: float, stock: bool, price: float) -> void:
	var grp: Dictionary = groups[g]
	var pos := float(grp.pos.get(market, 0.0))
	var limit := (m.stock_depth(market) if stock else m.depth(market)) * CROWD_POSITION
	lmd = clampf(pos + lmd, -limit, limit) - pos
	var done := place(m, market, lmd, "crowd:" + g, stock)
	if absf(done) < 1.0: return
	grp.pos[market] = pos + done
	grp.cash = float(grp.cash) - done * price

func crowd_worth(m: MarketState, g: String) -> float:
	var grp: Dictionary = groups[g]
	var v := float(grp.cash)
	for market in grp.pos:
		var b: MarketState.Book = m.stocks.get(market) if m.stocks.has(market) else m.books.get(market)
		if b != null: v += float(grp.pos[market]) * b.i
	return v

# --- Reactions to news (§3.4 先事件，后动作) ---------------------------------------------------

## A headline changes what the factions that use those goods expect: they act
## within hours, as far as they believe it.
func on_news(m: MarketState, headline: Dictionary, ev: Dictionary) -> void:
	if factions.is_empty() or ev.is_empty(): return
	for market in headline.get("markets", []):
		var sign := int((headline.get("moves", {}) as Dictionary).get(market, 0))
		# Only the ones who use the goods react, and only to dearer news: they buy
		# ahead. On cheaper news a user waits rather than dumping what it needs
		# (dumping at the resale cut and buying back made 萨米 poor, 2026-11-14).
		if sign <= 0: continue
		var b: MarketState.Book = m.books.get(market)
		if b == null or b.fx: continue
		for f in factions:
			var info := FactionAICatalog.info(str(f))
			if not (info.get("use", {}) as Dictionary).has(b.category): continue
			# Not past its hoarding ceiling (twice its target stock).
			if sign > 0 and float(factions[f].inv.get(b.category, 0.0)) > float(info.use[b.category]) * _target_days(factions[f].traits) * 2.0: continue
			var belief := 1.0
			if str(headline.get("kind", "")) == "rumor":
				belief = float(MarketState.CREDIBILITY.get(str(headline.get("cred", "中")), 0.5)) * float(factions[f].traits.credulity) * 2.0
			var amount := float(info.use[b.category]) * 0.5 * sign * belief
			if absf(amount) < 10.0: continue
			reactions.append({"at": m.t + m.rng.randi_range(1800, 3 * 3600), "faction": str(f), "market": best_seller(m, str(f), b.category), "amount": amount, "news_t": int(headline.t), "id": str(headline.id), "rumor": str(headline.kind) == "rumor"})

func _reactions_due(m: MarketState) -> void:
	if reactions.is_empty(): return
	for r in reactions.duplicate():
		# A rumor proven false: the ones who acted on it unwind (§3.4).
		if bool(r.get("rumor", false)) and _rumor_false(m, int(r.news_t), str(r.id)):
			reactions.erase(r)
			if bool(r.get("done", false)): _react_fill(m, r, -float(r.amount))
			continue
		if bool(r.get("done", false)):
			if m.t - int(r.at) > DAY: reactions.erase(r)
			continue
		if int(r.at) > m.t or str(r.market).is_empty(): continue
		var a: Dictionary = factions[r.faction]
		var use_day := 0.0
		for cat in FactionAICatalog.info(str(r.faction)).get("use", {}): use_day += float(FactionAICatalog.info(str(r.faction)).use[cat])
		if float(r.amount) > 0.0 and float(a.cash) < use_day * 5.0:
			reactions.erase(r)
			continue
		var done := _react_fill(m, r, float(r.amount))
		r.amount = done
		r.done = true
		if not bool(r.get("rumor", false)): reactions.erase(r)

## What a sale pays of the book's price: goods it makes, all; goods it bought
## and sells on, RESALE (freight, the reseller's cut). Without it, buying on a
## cheap book and selling on the dearest made every faction rich (2026-11-14).
static func resale(f: String, category: String) -> float:
	return 1.0 if (FactionAICatalog.info(f).get("make", {}) as Dictionary).has(category) else RESALE

## A news trade: the goods go into (or come out of) its stock and the cash moves
## with them. Before 2026-11-14 only the cash moved, so every news buy burned
## money (龙门 lost 3.3M in ten days that way) and every news sale made it.
func _react_fill(m: MarketState, r: Dictionary, amount: float) -> float:
	var a: Dictionary = factions[r.faction]
	var b: MarketState.Book = m.books.get(str(r.market))
	if b == null: return 0.0
	var price := m.index(str(r.market))
	var have := float(a.inv.get(b.category, 0.0))
	if amount > 0.0: amount = minf(amount, maxf(float(a.cash), 0.0) / maxf(price, 0.05))
	else: amount = maxf(amount, -have)
	if absf(amount) < 1e-6: return 0.0
	var done := place(m, str(r.market), amount, "faction:" + str(r.faction))
	a.cash = float(a.cash) - done * price * (resale(str(r.faction), b.category) if done < 0.0 else 1.0)
	a.inv[b.category] = maxf(0.0, have + done)
	return done

static func _rumor_false(m: MarketState, at: int, id: String) -> bool:
	for n in m.news:
		if int(n.t) == at and str(n.id) == id: return str(n.get("status", "")) == "已辟谣"
	return false

# --- Rhodes (§3.8.8, information layers) -------------------------------------------------

## Layer 1: a trade Rhodes made at `faction`'s own venue (signed: + Rhodes bought).
func rhodes_trade(m: MarketState, faction: String, market: String, lmd: float) -> void:
	if not factions.has(faction): return
	var a: Dictionary = factions[faction]
	a.rhodes.append([m.t, market, lmd])
	a.rhodes = a.rhodes.filter(func(x): return int(x[0]) > m.t - 7 * DAY)
	if lmd >= 0.0 or m.rhodes == null: return
	var r := int(m.rhodes.rank(faction))
	# 拒绝接盘 when hostile; buying back when friendly.
	var hostile := float(HOSTILE_TENDENCY[r]) * float(a.traits.revenge)
	var friendly := float(FRIEND_TENDENCY[r])
	if hostile > 0.0 and not market.is_empty(): m.add_pressure(market, -lmd * hostile * 0.5, "faction:" + faction)
	if friendly > 0.0 and not market.is_empty(): place(m, market, -lmd * friendly * 0.5, "faction:" + faction)
	# Selling into its venue lowers what its stock is worth: that is held against Rhodes.
	var b: MarketState.Book = m.books.get(market)
	if b != null and float(a.inv.get(b.category, 0.0)) > 0.0: a.grudge = float(a.grudge) + (-lmd) * 0.1

## The 7 days' net of Rhodes at this faction's venue (势力页 "对罗德岛").
func rhodes_net(faction: String) -> float:
	var v := 0.0
	for x in (factions.get(faction, {}) as Dictionary).get("rhodes", []): v += float(x[2])
	return v

## Layer 3: the upkeep's buying at the day's open, seen in the books' flow.
func saw_upkeep(market: String) -> void:
	upkeep_today[market] = true

func learned(faction: String, market: String) -> bool:
	return bool((factions.get(faction, {}) as Dictionary).get("learned", {}).get(market, false))

func estimate(faction: String, market: String) -> float:
	return float((factions.get(faction, {}) as Dictionary).get("est", {}).get(market, 0.0))

func _learn_upkeep() -> void:
	for f in factions:
		var a: Dictionary = factions[f]
		var need := LEARN_DAYS_RAT if f == "rat" else LEARN_DAYS
		for market in upkeep_today:
			a.seen[market] = int(a.seen.get(market, 0)) + 1
			a.miss[market] = 0
			if int(a.seen[market]) >= need: a.learned[market] = true
		for market in a.seen.keys():
			if upkeep_today.has(market): continue
			a.miss[market] = int(a.miss.get(market, 0)) + 1
			a.seen[market] = 0
			if int(a.miss[market]) >= FORGET_DAYS: a.learned.erase(market)
	upkeep_today.clear()

## Layer 2 and 4, once a day: public holdings exactly; other positions only
## from a footprint, off by a factor; estimates fade once the footprint goes.
func _infer_positions(m: MarketState) -> void:
	if m.rhodes == null: return
	var pos: Dictionary = m.rhodes.rhodes_positions()
	var public: Dictionary = m.firms.public_holders() if m.firms != null else {}
	for f in factions:
		var a: Dictionary = factions[f]
		var rng_range := ESTIMATE_RANGE_RAT if f == "rat" else ESTIMATE_RANGE
		for market in a.est.keys(): a.est[market] = float(a.est[market]) * ESTIMATE_DECAY
		for market in pos:
			var size := float(pos[market])
			var depth := m.stock_depth(market) if m.stocks.has(market) else m.depth(market)
			if public.has(market):
				a.est[market] = size
			elif absf(size) >= depth * FOOTPRINT:
				var seed_rng := RandomNumberGenerator.new()
				seed_rng.seed = hash("%s|%s|%d" % [f, market, _day])
				a.est[market] = size * seed_rng.randf_range(rng_range.x, rng_range.y)
		for market in a.est.keys():
			if absf(float(a.est[market])) < 100.0: a.est.erase(market)

## Hourly: what hostile factions do to what they can see of Rhodes, and the
## friendly ones' help (§3.8.8). Budget a day: 3% of cash at 冷漠, 1% at 中立.
func _rhodes_round(m: MarketState) -> void:
	var hour := MarketState.hour_at(m.t)
	for f in factions:
		if f == "penguin": continue
		var a: Dictionary = factions[f]
		var r := int(m.rhodes.rank(str(f)))
		var hostile := float(HOSTILE_TENDENCY[r]) * float(a.traits.revenge)
		var friendly := float(FRIEND_TENDENCY[r])
		var budget := float(a.cash) * float(HOSTILE_BUDGET[r]) - float(a.spent)
		if hostile > 0.0 and budget > 0.0:
			var per := minf(budget, float(a.cash) * LOSS_CAP) * hostile
			# 抬价囤货: before the 08:00 bill, on the books it has learned.
			if hour == 7:
				for market in a.learned:
					if per <= 1.0: break
					var price := m.index(str(market))
					var done := place(m, str(market), per / maxf(price, 0.05), "hostile:" + str(f))
					a.cash = float(a.cash) - done * price
					a.spent = float(a.spent) + done * price
					per -= done * price
			# 反向砸盘: against what it believes Rhodes holds.
			for market in a.est:
				if per <= 1.0: break
				var est := float(a.est[market])
				var stock := m.stocks.has(market)
				var price := (m.stocks[market] as MarketState.Book).i if stock else m.index(str(market))
				var lmd := -signf(est) * minf(absf(est) * 0.2, per) / maxf(price, 0.05)
				var done := place(m, str(market), lmd, "hostile:" + str(f), stock)
				a.spent = float(a.spent) + absf(done) * price
				a.cash = float(a.cash) - done * price
				per -= absf(done) * price
			# 抢跑挂单: Rhodes' big orders at its venue.
			for o in m.rhodes.orders_at(str(f)):
				if per <= 1.0: break
				var lmd := signf(float(o.size)) * minf(absf(float(o.size)), per)
				var done := place(m, str(o.market), lmd, "hostile:" + str(f))
				a.spent = float(a.spent) + absf(done)
				per -= absf(done)
		if friendly > 0.0 and hour == 7:
			# Friendly: a little more on offer where the bill buys.
			for market in a.learned:
				var info := FactionAICatalog.info(str(f))
				var b: MarketState.Book = m.books.get(market)
				if b == null: continue
				if not (info.get("make", {}) as Dictionary).has(b.category): continue
				place(m, str(market), -float(info.make[b.category]) * 0.1 * friendly, "friend:" + str(f))
	# Many hostile trades make news (动作即事件).
	for f in factions:
		if float(factions[f].spent) > float(factions[f].cash) * 0.02 and _cool(m, "AE6:" + str(f)):
			m.fire("AE6", {"faction": str(f)})

func _cool(m: MarketState, key: String) -> bool:
	if int(cooldowns.get(key, 0)) > m.t: return false
	cooldowns[key] = m.t + EVENT_COOLDOWN
	return true

# --- The day ---------------------------------------------------------------------------------

func _day_close(m: MarketState, day: int) -> void:
	_learn_upkeep()
	_infer_positions(m)
	for f in factions:
		var a: Dictionary = factions[f]
		a.spent = 0.0
		a.grudge = float(a.grudge) * GRUDGE_DECAY
		var net7: Dictionary = a.get("net7", {})
		for cat in net7.keys(): net7[cat] = float(net7[cat]) * (6.0 / 7.0)
		var w := worth(m, str(f))
		a.worth.append(w)
		if a.worth.size() > 31: a.worth = a.worth.slice(a.worth.size() - 31)
		_drift(str(f), w)
		for b in a.rel: a.rel[b].conflict = float(a.rel[b].conflict) * CONFLICT_FADE
		# 先动作，后事件: three days of selling one category makes news.
		for cat in a.sold:
			a.sells[cat] = int(a.sells.get(cat, 0)) + 1 if float(a.sold[cat]) > float(FactionAICatalog.info(str(f)).get("make", {}).get(cat, 0.0)) * 1.5 else 0
			if int(a.sells[cat]) >= SELL_STREAK_EVENT and _cool(m, "AE1:" + str(f)):
				a.sells[cat] = 0
				m.fire("AE1", {"faction": str(f)})
		a.sold = {}
		# Its home economy pays for what it uses (taxes, trade we do not model), at
		# the price it pays: the book it buys from, not the mean of all books (萨米
		# pays its thin home books, often three times the mean; 2026-11-14).
		var use_total := 0.0
		for cat in FactionAICatalog.info(str(f)).get("use", {}):
			var seller := best_seller(m, str(f), str(cat))
			use_total += float(FactionAICatalog.info(str(f)).use[cat]) * (m.index(seller) if not seller.is_empty() else cat_price(m, str(cat)))
		a.cash = float(a.cash) + use_total * float(FactionAICatalog.info(str(f)).get("income", INCOME_SHARE))
		# Its home spends what piles up (§3.8.9 防止失控): cash over HOME_SPEND_ABOVE ×
		# its start drains HOME_SPEND a day, so worth settles instead of compounding.
		var over := float(a.cash) - float(FactionAICatalog.info(str(f)).cash) * HOME_SPEND_ABOVE
		if over > 0.0: a.cash = float(a.cash) - over * HOME_SPEND
		# Interest on what it owes.
		if float(a.debt) > 0.0 and m.credit != null: a.debt = float(a.debt) * (1.0 + m.credit.base_rate(m))
		# 势力不会破产 (§3.8.9): a little help from home when the cash runs out.
		var start := float(FactionAICatalog.info(str(f)).cash)
		var liquid := float(a.cash) - float(a.debt)
		if m.firms != null:
			for firm in a.shares: liquid += float(a.shares[firm]) * m.firms.share_price_lmd(str(firm), m)
		if float(a.cash) < 0.0 or liquid < start * HOME_HELP_BELOW:
			a.cash = maxf(float(a.cash), 0.0) + start * HOME_HELP
	_crowd_day(m)

func worth(m: MarketState, f: String) -> float:
	var a: Dictionary = factions[f]
	var v := float(a.cash) - float(a.debt)
	for cat in a.inv:
		var market := best_seller(m, f, str(cat))
		v += float(a.inv[cat]) * (m.index(market) if not market.is_empty() else 1.0)
	if m.firms != null:
		for firm in a.shares: v += float(a.shares[firm]) * m.firms.share_price_lmd(str(firm))
	return v

## §3.8.7: results move the character, at most 2% a day, ±30% of the base,
## and 5% back toward it every day. Deterministic.
func _drift(f: String, w: float) -> void:
	var a: Dictionary = factions[f]
	var hist: Array = a.worth
	var ret := 0.0
	if hist.size() >= 2: ret = w / maxf(float(hist[0]), 1.0) - 1.0
	var capital := w / maxf(float(a.start), 1.0)
	var tr: Dictionary = a.traits
	var base: Dictionary = a.base
	var push := {}
	if ret > 0.0:
		push.risk = -1.0
		push.value = -1.0
	elif ret < 0.0:
		push.risk = 1.0
		push.value = 1.0
		push.cash = 1.0
	if capital > 1.0:
		push.patience = 1.0
		push.cash = float(push.get("cash", 0.0)) - 1.0
	elif capital < 1.0:
		push.patience = -1.0
		push.credulity = 1.0
		push.revenge = 1.0
	for k in FactionAICatalog.TRAITS:
		var v := float(tr[k])
		var b := float(base[k])
		var strength := clampf(absf(ret) * 10.0 if k in ["risk", "value"] else absf(capital - 1.0) * 5.0, 0.0, 1.0)
		v += float(push.get(k, 0.0)) * DRIFT_STEP * strength * b
		v += (b - v) * DRIFT_BACK
		tr[k] = clampf(v, b * (1.0 - DRIFT_RANGE), minf(1.0, b * (1.0 + DRIFT_RANGE)))

## §3.8.5: money follows the crowds that made money over 7 days; the total stays.
func _crowd_day(m: MarketState) -> void:
	var rets := {}
	var total := 0.0
	for g in groups:
		var grp: Dictionary = groups[g]
		var w := crowd_worth(m, g)
		grp.worth.append(w)
		if grp.worth.size() > 8: grp.worth = grp.worth.slice(grp.worth.size() - 8)
		rets[g] = w / maxf(float(grp.worth[0]), 1.0) - 1.0
		total += w
	# The crowds as a whole lost everything: new money comes in at the start's size.
	if total < CROWD_CASH * 0.2:
		for g in groups:
			groups[g].pos = {}
			groups[g].cash = CROWD_CASH * float(START_SHARE[g])
			groups[g].worth = []
		return
	var weights := {}
	var wsum := 0.0
	for g in groups:
		weights[g] = exp(clampf(float(rets[g]) * 20.0, -3.0, 3.0)) * float(START_SHARE[g])
		wsum += float(weights[g])
	for g in groups:
		var want := total * float(weights[g]) / wsum
		var have := crowd_worth(m, g)
		groups[g].cash = maxf(0.0, float(groups[g].cash) + (want - have) * 0.1)

# --- Saving ----------------------------------------------------------------------------------

func to_data() -> Dictionary:
	return {"factions": factions.duplicate(true), "groups": groups.duplicate(true), "pending": pending.duplicate(true), "reactions": reactions.duplicate(true),
		"cooldowns": cooldowns.duplicate(), "upkeep_today": upkeep_today.duplicate(), "round": _round, "day": _day, "maker_share": maker_share}

func load_data(d: Dictionary) -> void:
	factions = (d.get("factions", {}) as Dictionary).duplicate(true) if d.get("factions") is Dictionary else {}
	groups = (d.get("groups", {}) as Dictionary).duplicate(true) if d.get("groups") is Dictionary else {}
	pending = (d.get("pending", {}) as Dictionary).duplicate(true) if d.get("pending") is Dictionary else {}
	reactions = (d.get("reactions", []) as Array).duplicate(true) if d.get("reactions") is Array else []
	cooldowns = (d.get("cooldowns", {}) as Dictionary).duplicate() if d.get("cooldowns") is Dictionary else {}
	upkeep_today = (d.get("upkeep_today", {}) as Dictionary).duplicate() if d.get("upkeep_today") is Dictionary else {}
	_round = int(d.get("round", -1))
	_day = int(d.get("day", -1))
	maker_share = float(d.get("maker_share", 0.2))
	# A faction added since the save starts fresh.
	for f in FactionAICatalog.FACTIONS:
		if not factions.has(f): factions.clear()
