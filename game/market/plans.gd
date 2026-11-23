class_name MarketPlans
extends RefCounted

## 交易所统一行情修订案 v0.3 §4: what factions and firms do on the pack lines
## beyond their everyday buying and selling (MarketActors: B1 restock, B2 sell,
## B13 news front-running, B17 against Rhodes, B18 money). A plan runs over
## rounds or days in phases, with a budget and ways out; each needs drives
## (MarketDrives) to start. At most two at a time each; orders stay within 5%
## of a book's depth a round (MarketActors.place), so a big move takes time.
##   B3 扫货拉抬  B4 囤货惜售  B5 集中抛售  B6 维稳托市  B7 倾销  B8 逼空
##   B9 套利  B10 减产  B11 增产  B12 放风造势  B14 恐慌出逃  B15 战略储备
##   B16 援助盟友
## Big plans may make the news 1–6 hours later (§4.3).

const ROUND := 900
const DAY := 86400
const MAX_ACTIVE := 2
const THRESHOLD := 0.15
const COOLDOWN := 48 * 3600
const IMPACT_CAP := 0.05
## §4.3 exposure.
const EXPOSE_SHARE := 0.15
const EXPOSE_ODDS := 0.5
const EXPOSE_BLACK := 0.25
const EXPOSE_DELAY := Vector2i(3600, 6 * 3600)
## B6: steps in past 12% off the 7-day mean, stops within 5%.
const STEADY_IN := 0.12
const STEADY_OUT := 0.05
## B9: a basis gap worth trading; the share of it kept.
const ARB_GAP := 0.04
const ARB_KEEP := 0.5
## B7 sells at this share of the price and pushes that much harder.
const UNDERCUT := 0.92
const UNDERCUT_PUSH := 0.5
## B10 / B11.
const CUT_BELOW := 0.85
const RAISE_ABOVE := 1.2
const CUT := 0.8
const RAISE := 1.2
## B8.
const CORNER_SHARE := 0.25
const CORNER_GOAL := 0.5
const CORNER_STOP := 0.3

## A plan's sale of goods it did not make keeps this much (its own trades
## at its own venue: less than MarketActors.RESALE's freight and cut).
const PLAN_RESALE := 0.9
## Pumping is costly: it needs this score, not just THRESHOLD.
const PUMP_MIN := 0.3
## B4 sells its hoard once the line is this much over its start.
const HOARD_GAIN := 1.08

## How much each drive counts for each behaviour (§4.1).
const WEIGHTS := {
	"B3": {"D1u": 0.6, "D3u": 0.5, "D7u": 0.3},
	"B4": {"D1u": 0.5, "D9": 0.8, "D5": 0.2, "D3d": 0.3},
	"B5": {"D1s": 0.5, "D3d": 0.7, "D6": 0.8, "D8": 0.6},
	"B6": {"D4": 1.0, "D1u": 0.15, "D1d": 0.15},
	"B7": {"D5": 0.8, "D3d": 0.6},
	"B8": {"D1u": 0.5, "D5": 0.6},
	"B10": {"D1d": 0.6, "D4": 0.5},
	"B11": {"D1u": 0.6, "D5": 0.5},
}

const TITLES := {
	"B3": "%s出现大额买盘，来源疑似%s",
	"B4": "传闻%s正在囤积%s",
	"B5": "%s遭大额抛售，来源疑似%s",
	"B6": "%s入市平抑%s价格",
	"B7": "%s低价倾销%s",
	"B8": "传闻%s大量控制%s货源",
	"B10": "%s宣布%s减产",
	"B11": "%s宣布%s增产",
	"B14": "%s恐慌抛售%s",
	"B15": "%s启动%s战略储备",
	"B16": "%s向%s紧急调拨%s",
}

var active: Array = []     # {id, pid, kind, cat, phase, start, until, budget, spent, vol, goal, ref, exposed, ...}
var cool := {}             # "pid|cat|kind" -> until
var policy := {}           # pid -> {cat: until}: a strategic reserve called (D9)
var stats := {}            # kind -> plans started (the sim and the tests read it)
var returns := {}          # kind -> [sum of returns, count]: B3 / B8 on money in, B4 on its price at the start
var by_pid := {}           # pid -> {kind: started} (the sim)
var _round := -1
var _day := -1
var _next := 1
var _rumors := {}          # "cat|sign" -> [event ids] (B12), built once
## Off: no plans start or run (a test isolating the everyday market).
var enabled := true

func clear() -> void:
	active.clear()
	cool.clear()
	policy.clear()
	stats.clear()
	_round = -1
	_day = -1

func to_data() -> Dictionary:
	return {"active": active.duplicate(true), "cool": cool.duplicate(), "policy": policy.duplicate(true), "stats": stats.duplicate(), "returns": returns.duplicate(true), "round": _round, "day": _day, "next": _next}

func load_data(d: Dictionary) -> void:
	active = (d.get("active", []) as Array).duplicate(true)
	cool = (d.get("cool", {}) as Dictionary).duplicate()
	policy = (d.get("policy", {}) as Dictionary).duplicate(true)
	stats = (d.get("stats", {}) as Dictionary).duplicate()
	returns = (d.get("returns", {}) as Dictionary).duplicate(true)
	_round = int(d.get("round", -1))
	_day = int(d.get("day", -1))
	_next = int(d.get("next", 1))

func count(pid: String) -> int:
	var n := 0
	for p in active:
		if str(p.pid) == pid: n += 1
	return n

func on_cat(pid: String, cat: String) -> Dictionary:
	for p in active:
		if str(p.pid) == pid and str(p.cat) == cat: return p
	return {}

func policy_on(m: MarketState, pid: String, cat: String) -> bool:
	return int((policy.get(pid, {}) as Dictionary).get(cat, 0)) > m.t

func _note(kind: String) -> void:
	stats[kind] = int(stats.get(kind, 0)) + 1

# --- The step ---------------------------------------------------------------------------------

func step(m: MarketState, _dt: int) -> void:
	if not enabled or m.actors == null or m.actors.factions.is_empty(): return
	var day := MarketState.day_key(m.t)
	if day != _day:
		if _day >= 0: _daily(m)
		_day = day
	var r := int(m.t / ROUND)
	if r == _round: return
	_round = r
	for p in active.duplicate():
		if not _advance(m, p):
			_finish(m, p)
			active.erase(p)
	for pid in MarketLedgers.participants(m):
		if count(pid) < MAX_ACTIVE: _consider(m, pid)
	_arbitrage(m)
	_aid(m)

func _daily(m: MarketState) -> void:
	for pid in MarketLedgers.participants(m): MarketLedgers.charge_storage(m, pid)
	for k in cool.keys():
		if int(cool[k]) <= m.t: cool.erase(k)
	for pid in policy.keys():
		var row: Dictionary = policy[pid]
		for c in row.keys():
			if int(row[c]) <= m.t: row.erase(c)
		if row.is_empty(): policy.erase(pid)

func _cooled(m: MarketState, pid: String, cat: String, kind: String) -> bool:
	return int(cool.get("%s|%s|%s" % [pid, cat, kind], 0)) <= m.t

func _cool(m: MarketState, pid: String, cat: String, kind: String, secs: int = COOLDOWN) -> void:
	cool["%s|%s|%s" % [pid, cat, kind]] = m.t + secs

# --- Trading --------------------------------------------------------------------------------

## Where it trades a pack: a faction buys at home first, sells at home first.
func venue(m: MarketState, pid: String, cat: String, buying: bool) -> String:
	if MarketLedgers.is_firm(pid):
		return MarketActors.best_seller(m, "", cat) if buying else MarketActors.best_buyer(m, "", cat)
	var f := MarketLedgers.id_of(pid)
	if buying: return MarketActors.best_seller(m, f, cat)
	var own := MarketActors.book_of(m, f, cat)
	return own if not own.is_empty() else MarketActors.best_buyer(m, f, cat)

## An order of `lmd` (signed; + buys) for `pid` on `cat`: within its cash,
## room and stock, through the actors' order book. Returns what went in.
func trade(m: MarketState, pid: String, cat: String, lmd: float, keep: float = 1.0, push: float = 0.0) -> float:
	var at := venue(m, pid, cat, lmd > 0.0)
	if at.is_empty(): return 0.0
	var price := m.index(at)
	var have := MarketLedgers.inv(m, pid, cat)
	if lmd > 0.0:
		lmd = minf(lmd, maxf(0.0, MarketLedgers.cash(m, pid)) / maxf(price, 0.05))
		lmd = minf(lmd, maxf(0.0, MarketLedgers.capacity(m, pid, cat) - have))
	else: lmd = maxf(lmd, -have)
	if absf(lmd) < 1.0: return 0.0
	var done := m.actors.place(m, at, lmd, "plan:" + pid)
	if absf(done) < 1.0: return 0.0
	if done > 0.0:
		MarketLedgers.add_cash(m, pid, -done * price)
		MarketLedgers.add_inv(m, pid, cat, done, price)
	else:
		var resale := 1.0
		if not MarketLedgers.is_firm(pid): resale = maxf(MarketActors.resale(MarketLedgers.id_of(pid), cat), PLAN_RESALE)
		var got := -done * price * resale * keep
		MarketLedgers.add_inv(m, pid, cat, done, price)
		MarketLedgers.add_cash(m, pid, got)
		if MarketLedgers.is_firm(pid): m.firms.book_sale(MarketLedgers.id_of(pid), got)
	if push != 0.0: m.add_flow(at, done * push, "plan:" + pid)
	return done

func _cap(m: MarketState, pid: String, cat: String, buying: bool) -> float:
	var at := venue(m, pid, cat, buying)
	return m.depth(at) * IMPACT_CAP if not at.is_empty() else 0.0

# --- Starting --------------------------------------------------------------------------------

func _score(kind: String, d: Dictionary) -> float:
	var s := 0.0
	var w: Dictionary = WEIGHTS[kind]
	for k in w: s += float(d.get(k, 0.0)) * float(w[k])
	return s

func _consider(m: MarketState, pid: String) -> void:
	var best := {}
	var best_score := THRESHOLD
	var firm := MarketLedgers.is_firm(pid)
	var tr := MarketLedgers.traits(m, pid)
	var cash := MarketLedgers.cash(m, pid)
	var use_total := maxf(MarketLedgers.use_total(m, pid), 1000.0)
	for cat in MarketLedgers.cats(m, pid):
		if not on_cat(pid, str(cat)).is_empty(): continue
		var line: MarketState.Book = m.lines.get(cat)
		if line == null: continue
		var d := MarketDrives.of(m, pid, str(cat))
		var inv := MarketLedgers.inv(m, pid, str(cat))
		var target := MarketLedgers.target(m, pid, str(cat))
		var cap := MarketLedgers.capacity(m, pid, str(cat))
		var made := MarketLedgers.prod_day(m, pid, str(cat))
		var totals := MarketLedgers.totals(m, str(cat))
		var cands: Array = []
		var rich := cash > (use_total * 10.0 if not firm else 50000.0)
		if rich and _cooled(m, pid, str(cat), "B3"): cands.append("B3")
		if made > 0.0 and inv < cap * 0.7 and not MarketLedgers.held(m, pid, str(cat)) and _cooled(m, pid, str(cat), "B4"): cands.append("B4")
		if inv > target * 1.5 and _cooled(m, pid, str(cat), "B5"): cands.append("B5")
		# It steadies what it has a stake in: a pack it uses or makes.
		var stake := made > 0.0 or MarketLedgers.use_day(m, pid, str(cat)) > 0.0
		if not firm and stake and float(tr.order) >= 0.5 and absf(float(d.dev)) > STEADY_IN and _cooled(m, pid, str(cat), "B6"): cands.append("B6")
		if made > 0.0 and made / maxf(float(totals.prod), 1.0) >= 0.15 and _cooled(m, pid, str(cat), "B7"): cands.append("B7")
		if not firm and float(tr.ambition) >= 0.6 and inv / maxf(float(totals.inv), 1.0) >= CORNER_SHARE and cash > float(totals.inv) * line.i * 0.5 and _cooled(m, pid, str(cat), "B8"): cands.append("B8")
		if made > 0.0 and line.i < CUT_BELOW and MarketLedgers.pm(m, pid, str(cat)) == 1.0 and _cooled(m, pid, str(cat), "B10"): cands.append("B10")
		if made > 0.0 and line.i > RAISE_ABOVE and MarketLedgers.pm(m, pid, str(cat)) == 1.0 and _cooled(m, pid, str(cat), "B11"): cands.append("B11")
		for kind in cands:
			var s := _score(str(kind), d)
			if kind in ["B10", "B11"]: s += 0.2
			if kind == "B3" and s < PUMP_MIN: continue
			if s > best_score:
				best_score = s
				best = {"kind": kind, "cat": cat, "d": d}
	if best.is_empty(): return
	begin(m, pid, str(best.kind), str(best.cat), best.d)

## Starts `kind` for `pid` on `cat` (the tests call it directly too).
func begin(m: MarketState, pid: String, kind: String, cat: String, d: Dictionary = {}) -> Dictionary:
	var line: MarketState.Book = m.lines.get(cat)
	if line == null: return {}
	if d.is_empty(): d = MarketDrives.of(m, pid, cat)
	var cash := maxf(0.0, MarketLedgers.cash(m, pid))
	var p := {"id": _next, "pid": pid, "kind": kind, "cat": cat, "phase": "", "start": m.t, "until": m.t + DAY, "budget": 0.0, "spent": 0.0,
		"vol": 0.0, "goal": 0.0, "ref": line.i, "exposed": false, "rival": str(d.get("rival", ""))}
	_next += 1
	_note(kind)
	if not by_pid.has(pid): by_pid[pid] = {}
	by_pid[pid][kind] = int(by_pid[pid].get(kind, 0)) + 1
	match kind:
		"B3":
			p.phase = "gather"
			p.budget = cash * 0.03
			p.goal = line.i * (1.0 + m.rng.randf_range(0.10, 0.25))
			p.until = m.t + 2 * DAY
		"B4":
			p.phase = "hoard"
			p.goal = m.rng.randf_range(0.7, 1.0)
			p.until = m.t + 3 * DAY
			MarketLedgers.set_hold(m, pid, cat, true)
		"B5":
			p.phase = "dump"
			_maybe_rumor(m, pid, cat, -1)
		"B6":
			p.phase = "lean"
			p.goal = -signf(float(d.get("dev", 0.0)))
			p.budget = cash * 0.05
		"B7":
			p.phase = "undercut"
			p.until = m.t + int(m.rng.randf_range(1.0, 3.0) * DAY)
			MarketLedgers.set_hold(m, pid, cat, true)
			_tell(m, p, "B7", -1)
		"B8":
			p.phase = "collect"
			p.budget = cash * 0.15
			p.until = m.t + 2 * DAY
			p["bought"] = 0.0
			p["paid"] = 0.0
			MarketLedgers.set_hold(m, pid, cat, true)
		"B10", "B11":
			var secs := int(m.rng.randf_range(2.0, 5.0) * DAY)
			MarketLedgers.set_pm(m, pid, cat, CUT if kind == "B10" else RAISE, m.t + secs)
			_cool(m, pid, cat, kind, secs)
			_tell(m, p, kind, -1 if kind == "B11" else 1, true)
			return p
		"B14":
			p.phase = "flee"
			p.until = m.t + 3 * ROUND + 1
		"B15":
			p.phase = "buy"
			p.budget = cash * 0.1
			p.until = int((policy.get(pid, {}) as Dictionary).get(cat, m.t + DAY))
			_tell(m, p, "B15", 1, true)
	if kind in ["B3", "B5", "B7", "B8"]: _cool(m, pid, cat, kind)
	else: _cool(m, pid, cat, kind, DAY)
	active.append(p)
	return p

# --- Running ---------------------------------------------------------------------------------

## One round of a plan; false when it is over.
func _advance(m: MarketState, p: Dictionary) -> bool:
	var pid := str(p.pid)
	var cat := str(p.cat)
	var line: MarketState.Book = m.lines.get(cat)
	if line == null or MarketLedgers.store(m, pid).is_empty(): return false
	var inv := MarketLedgers.inv(m, pid, cat)
	var target := MarketLedgers.target(m, pid, cat)
	var done := 0.0
	match str(p.kind):
		"B3":
			if str(p.phase) == "gather" or str(p.phase) == "push":
				var rate := 0.5 if float(p.spent) < float(p.budget) / 3.0 else 1.0
				if rate >= 1.0 and str(p.phase) == "gather":
					p.phase = "push"
					_maybe_rumor(m, pid, cat, 1)
				var amt := minf(_cap(m, pid, cat, true) * rate, (float(p.budget) - float(p.spent)) / maxf(line.i, 0.05))
				done = trade(m, pid, cat, amt)
				p.spent = float(p.spent) + maxf(done, 0.0) * line.i
				if line.i >= float(p.goal) or float(p.spent) >= float(p.budget) * 0.98 or m.t > int(p.until) or done <= 0.0:
					if MarketLedgers.inv(m, pid, cat) > target * 1.2:
						p.phase = "unload"
						p.until = m.t + 2 * DAY
					else: return false
			else:
				if inv <= target * 1.05 or m.t > int(p.until): return false
				done = trade(m, pid, cat, -minf(inv - target, _cap(m, pid, cat, false)))
		"B4":
			var room := MarketLedgers.capacity(m, pid, cat)
			match str(p.phase):
				"hoard":
					if inv >= room * float(p.goal) or m.t > int(p.until):
						p.phase = "wait"
						p.until = m.t + 3 * DAY
						_tell(m, p, "B4", 1)
				"wait":
					var d := MarketDrives.of(m, pid, cat)
					# Worth it: the line well over where it was when the hoarding began.
					if line.i >= float(p.ref) * HOARD_GAIN or float(d.D3d) > 0.5 or float(d.D6) > 0.5:
						p.phase = "dump"
						p.until = m.t + DAY
						MarketLedgers.set_hold(m, pid, cat, false)
						_note("B5")
						_maybe_rumor(m, pid, cat, -1)
					elif m.t > int(p.until):
						MarketLedgers.set_hold(m, pid, cat, false)
						return false
				"dump":
					if inv <= target or m.t > int(p.until): return false
					done = trade(m, pid, cat, -minf(inv - target, _cap(m, pid, cat, false)))
		"B5":
			if inv <= target or m.t > int(p.until): return false
			done = trade(m, pid, cat, -minf(inv - target, _cap(m, pid, cat, false)))
			if done >= 0.0: return false
		"B6":
			var dev := line.i / maxf(MarketDrives.mean7(line), 0.05) - 1.0
			if absf(dev) < STEADY_OUT or m.t > int(p.until) or signf(dev) == float(p.goal): return false
			if float(p.goal) > 0.0:
				var amt := minf(_cap(m, pid, cat, true), (float(p.budget) - float(p.spent)) / maxf(line.i, 0.05))
				done = trade(m, pid, cat, amt)
				p.spent = float(p.spent) + maxf(done, 0.0) * line.i
				if done <= 0.0: return false
			else:
				done = trade(m, pid, cat, -minf(inv, _cap(m, pid, cat, false)))
				if done >= 0.0: return false
		"B7":
			if m.t > int(p.until):
				MarketLedgers.set_hold(m, pid, cat, false)
				return false
			var made := MarketLedgers.prod_day(m, pid, cat) * float(ROUND) / DAY
			var amt := minf(made + maxf(0.0, inv - target * 0.5), _cap(m, pid, cat, false))
			done = trade(m, pid, cat, -amt, UNDERCUT, UNDERCUT_PUSH)
		"B8":
			match str(p.phase):
				"collect":
					var totals := MarketLedgers.totals(m, cat)
					var amt := minf(_cap(m, pid, cat, true), (float(p.budget) - float(p.spent)) / maxf(line.i, 0.05))
					done = trade(m, pid, cat, amt)
					if done > 0.0:
						p.spent = float(p.spent) + done * line.i
						p.bought = float(p.bought) + done
						p.paid = float(p.paid) + done * line.i
					var share := MarketLedgers.inv(m, pid, cat) / maxf(float(totals.inv), 1.0)
					if share >= CORNER_GOAL or float(p.spent) >= float(p.budget) * 0.98 or m.t > int(p.until) or done <= 0.0:
						p.phase = "hold"
						p.until = m.t + DAY
						_tell(m, p, "B8", 1)
				"hold":
					if m.t > int(p.until):
						p.phase = "out"
						p.until = m.t + 2 * DAY
						MarketLedgers.set_hold(m, pid, cat, false)
				"out":
					if inv <= target * 1.05 or m.t > int(p.until): return false
					done = trade(m, pid, cat, -minf(inv - target, _cap(m, pid, cat, false)))
			# The stop: a loss past 30% of the budget (a steadying side buying against it).
			if str(p.phase) != "out" and float(p.bought) > 0.0:
				var loss := float(p.paid) - float(p.bought) * line.i
				if loss > float(p.budget) * CORNER_STOP:
					p.phase = "out"
					p.until = m.t + 2 * DAY
					MarketLedgers.set_hold(m, pid, cat, false)
		"B14":
			if inv <= target or m.t > int(p.until): return false
			var left := maxi(1, int((int(p.until) - m.t) / ROUND))
			done = trade(m, pid, cat, -(inv - target) / float(left))
		"B15":
			match str(p.phase):
				"buy":
					var want := MarketLedgers.use_day(m, pid, cat) * 30.0
					if inv >= want or float(p.spent) >= float(p.budget) * 0.98:
						p.phase = "keep"
					else:
						var amt := minf(minf(_cap(m, pid, cat, true), want - inv), (float(p.budget) - float(p.spent)) / maxf(line.i, 0.05))
						done = trade(m, pid, cat, amt)
						p.spent = float(p.spent) + maxf(done, 0.0) * line.i
						if done <= 0.0: p.phase = "keep"
				"keep":
					if not policy_on(m, pid, cat):
						p.phase = "release"
						p.until = m.t + 3 * DAY
				"release":
					if inv <= target or m.t > int(p.until): return false
					var left := maxi(1, int((int(p.until) - m.t) / ROUND))
					done = trade(m, pid, cat, -(inv - target) / float(left))
		_:
			return false
	if absf(done) > 0.0:
		p.vol = float(p.vol) + absf(done)
		if done < 0.0:
			p["got"] = float(p.get("got", 0.0)) - done * line.i
			p["sold"] = float(p.get("sold", 0.0)) - done
		else:
			p["bq"] = float(p.get("bq", 0.0)) + done
			p["bp"] = float(p.get("bp", 0.0)) + done * line.i
		_expose(m, p, signf(done))
	return true

## What a plan made (for the sim): money out against money in, or the price
## its hoard fetched against the price when it began.
func _finish(m: MarketState, p: Dictionary) -> void:
	var kind := str(p.kind)
	var r := 0.0
	match kind:
		"B3", "B8":
			if float(p.get("bq", 0.0)) <= 0.0: return
			var buy := float(p.bp) / float(p.bq)
			var sell := float(p.got) / float(p.sold) if float(p.get("sold", 0.0)) > 0.0 else m.index(str(p.cat))
			r = sell / maxf(buy, 0.05) - 1.0
		"B4":
			# A hoard let go unsold is worth the line when it ends.
			var sell := float(p.got) / float(p.sold) if float(p.get("sold", 0.0)) > 0.0 else m.index(str(p.cat))
			r = sell / maxf(float(p.ref), 0.05) - 1.0
		_: return
	var row: Array = returns.get(kind, [0.0, 0])
	returns[kind] = [float(row[0]) + r, int(row[1]) + 1]

# --- Exposure and news (§4.3) ----------------------------------------------------------------

func _expose(m: MarketState, p: Dictionary, sign: float) -> void:
	if bool(p.exposed) or float(p.vol) < m.depth(str(p.cat)) * EXPOSE_SHARE: return
	p.exposed = true
	var kind := str(p.kind)
	if str(p.phase) == "dump": kind = "B5"
	if str(p.phase) == "unload": kind = "B5"
	if not TITLES.has(kind) or kind in ["B10", "B11", "B15", "B4", "B8", "B7"]: return
	var black := not MarketLedgers.is_firm(str(p.pid)) and bool(FactionCatalog.info(MarketLedgers.id_of(str(p.pid))).get("black", false))
	if m.rng.randf() >= (EXPOSE_BLACK if black else EXPOSE_ODDS): return
	_tell(m, p, kind, int(sign), false)

## A headline about `p`: `now` for a public act, else 1–6 hours later.
func _tell(m: MarketState, p: Dictionary, kind: String, sign: int, now: bool = false) -> void:
	var pid := str(p.pid)
	var cat := str(p.cat)
	var who := MarketLedgers.name_of(pid)
	var pack := FactionCatalog.market_name(cat)
	var title := ""
	match kind:
		"B3", "B5": title = TITLES[kind] % [pack, who]
		"B16": title = TITLES[kind] % [who, MarketLedgers.name_of(str(p.get("ally", ""))), pack]
		_: title = TITLES[kind] % [who, pack]
	var region := str(FirmCatalog.info(MarketLedgers.id_of(pid)).get("region", "")) if MarketLedgers.is_firm(pid) else str(FactionCatalog.info(MarketLedgers.id_of(pid)).get("region", ""))
	var moves := {cat: sign} if sign != 0 else {}
	if now: m.post_news(title, region, [cat], moves)
	else: m.schedule_news(m.t + m.rng.randi_range(EXPOSE_DELAY.x, EXPOSE_DELAY.y), title, region, [cat], moves)

## B12: putting a rumor about, the same way as the plan (§4, 拍板 4: a real
## rumor from the table at 低 credibility, proven or denied like any other).
func _maybe_rumor(m: MarketState, pid: String, cat: String, sign: int) -> void:
	var tr := MarketLedgers.traits(m, pid)
	var odds := 0.1 + 0.3 * float(tr.get("ambition", 0.5)) * (1.0 - float(tr.get("order", 0.5)))
	if m.rng.randf() >= odds: return
	var ids: Array = rumors_for(cat, sign)
	if ids.is_empty(): return
	var id := str(ids[m.rng.randi() % ids.size()])
	var entry := m.fire(id, {}, MarketLedgers.name_of(pid))
	if entry.is_empty() or not entry.has("rumor"): return
	entry.rumor.cred = "低"
	entry.rumor.truth = m.rng.randf() < float(MarketState.CREDIBILITY["低"])
	for k in range(m.news.size() - 1, -1, -1):
		if str(m.news[k].id) == id and int(m.news[k].t) == m.t:
			m.news[k].cred = "低"
			break
	_note("B12")

## Rumors in the table that move `cat` one way for sure.
func rumors_for(cat: String, sign: int) -> Array:
	if _rumors.is_empty():
		for id in MarketEvents.EVENTS:
			var ev: Dictionary = MarketEvents.EVENTS[id]
			if str(ev.get("kind", "")) != "rumor" or ev.has("pick") or ev.get("pick_firm", false): continue
			for spec in ev.get("effects", []):
				var sel := str(spec.get("sel", ""))
				if Currencies.is_fx(sel) or sel.begins_with("fx") or not sel.contains(":"): continue
				var c := sel.split(":")[1]
				if c == "*" or c.contains("%"): continue
				var s := 0
				if spec.has("mult"): s = 1 if float(spec.mult) > 1.0 else -1
				elif spec.has("jump"): s = 1 if float(spec.jump) > 0.0 else -1
				if s == 0: continue
				var key := "%s|%d" % [c, s]
				if not _rumors.has(key): _rumors[key] = []
				if not (_rumors[key] as Array).has(id): _rumors[key].append(id)
	return _rumors.get("%s|%d" % [cat, sign], [])

# --- News reactions: B14 panic, B15 reserves -------------------------------------------------

func on_news(m: MarketState, headline: Dictionary, ev: Dictionary) -> void:
	if not enabled or ev.is_empty() or m.actors == null or m.actors.factions.is_empty(): return
	var moves: Dictionary = headline.get("moves", {})
	var down := {}
	var up := {}
	for q in moves:
		if Currencies.is_fx(str(q)): continue
		var c := str(FactionCatalog.split(str(q))[1]) if not FactionCatalog.is_line(str(q)) else str(q)
		if int(moves[q]) < 0: down[c] = true
		elif int(moves[q]) > 0: up[c] = true
	var hours := float(ev.get("hours", 24.0))
	for pid in MarketLedgers.participants(m):
		if count(pid) >= MAX_ACTIVE: continue
		var tr := MarketLedgers.traits(m, pid)
		for c in down:
			if not on_cat(pid, str(c)).is_empty() or not _cooled(m, pid, str(c), "B14"): continue
			if MarketLedgers.inv(m, pid, str(c)) <= MarketLedgers.target(m, pid, str(c)) or float(tr.get("risk", 0.5)) >= 0.5: continue
			var d := MarketDrives.of(m, pid, str(c))
			if float(d.D8) + 0.4 * float(d.D6) >= 0.15:
				begin(m, pid, "B14", str(c), d)
				break
		if MarketLedgers.is_firm(pid) or str(headline.get("kind", "")) == "rumor": continue
		var f := MarketLedgers.id_of(pid)
		if float(tr.get("order", 0.5)) < 0.5 or str(FactionCatalog.info(f).get("region", "")) != str(headline.get("region", "")): continue
		for c in up:
			if MarketLedgers.use_day(m, pid, str(c)) <= 0.0 or not on_cat(pid, str(c)).is_empty() or not _cooled(m, pid, str(c), "B15"): continue
			if count(pid) >= MAX_ACTIVE: break
			if not policy.has(pid): policy[pid] = {}
			policy[pid][c] = m.t + int(hours * 3600.0)
			begin(m, pid, "B15", str(c))

# --- B9 arbitrage, B16 aid -------------------------------------------------------------------

## The steady houses (秩序 0.6 up) trade the gap between two books of a pack.
func _arbitrage(m: MarketState) -> void:
	for f in FactionCatalog.trading():
		var pid := "f:" + f
		if not m.actors.factions.has(f) or float(MarketLedgers.traits(m, pid).get("order", 0.0)) < 0.6: continue
		for cat in m.lines:
			var lo := ""
			var hi := ""
			for q in m.quotes_of(str(cat)):
				if lo.is_empty() or m.basis(str(q)) < m.basis(lo): lo = str(q)
				if hi.is_empty() or m.basis(str(q)) > m.basis(hi): hi = str(q)
			if lo.is_empty() or lo == hi: continue
			var gap := m.basis(hi) - m.basis(lo)
			if gap < ARB_GAP: continue
			var amt := minf(minf(m.depth(lo), m.depth(hi)) * 0.02, MarketLedgers.cash(m, pid) * 0.01 / maxf(m.index(lo), 0.05))
			if amt < 100.0: continue
			m.add_flow(lo, amt, "arb:" + pid)
			m.add_flow(hi, -amt, "arb:" + pid)
			MarketLedgers.add_cash(m, pid, amt * m.index(lo) * gap * ARB_KEEP)
			if _cooled(m, pid, str(cat), "B9"):
				_note("B9")
				_cool(m, pid, str(cat), "B9", 6 * 3600)

## A friend short of a pack it uses gets it straight from a friend that has
## plenty, under the market (拍板 5: not through the market, only the news).
func _aid(m: MarketState) -> void:
	for a in m.actors.factions:
		var apid := "f:" + str(a)
		if not FactionCatalog.trading().has(str(a)): continue
		for b in m.actors.factions:
			if str(a) == str(b) or not FactionCatalog.trading().has(str(b)) or m.actors.tier(str(a), str(b)) != "友好": continue
			var bpid := "f:" + str(b)
			for cat in MarketLedgers.cats(m, bpid):
				var need := MarketLedgers.use_day(m, bpid, str(cat))
				if need <= 0.0: continue
				var tb := MarketLedgers.target(m, bpid, str(cat))
				var have_b := MarketLedgers.inv(m, bpid, str(cat))
				var spare := MarketLedgers.inv(m, apid, str(cat)) - MarketLedgers.target(m, apid, str(cat))
				if have_b >= tb * 0.5 or spare <= 0.0 or not _cooled(m, apid, str(cat), "B16"): continue
				var qty := minf(minf(spare, tb * 0.5 - have_b), need * 0.5)
				var price := m.index(str(cat)) * 0.9
				qty = minf(qty, maxf(0.0, MarketLedgers.cash(m, bpid)) / maxf(price, 0.05))
				if qty < 100.0: continue
				MarketLedgers.add_inv(m, apid, str(cat), -qty, price)
				MarketLedgers.add_inv(m, bpid, str(cat), qty, price)
				MarketLedgers.add_cash(m, bpid, -qty * price)
				MarketLedgers.add_cash(m, apid, qty * price)
				_note("B16")
				_cool(m, apid, str(cat), "B16", DAY)
				_tell(m, {"pid": apid, "cat": str(cat), "ally": bpid}, "B16", 0, true)
