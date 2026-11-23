class_name MarketInfluence
extends RefCounted

## 交易所统一行情修订案 v0.2 §3 / v0.3 §2 (用户 2026-11-22: 影响不显示，是隐藏
## 参数): how much each faction and firm weighs on a pack's line. The base is
## its size there (making + use + stock / 7, MarketLedgers); the factor floats
## ±10% with time (a slow walk), state (its cash or its firm's health, daily)
## and events naming it. Its share of a pack = its factor over everyone's.
## Never shown anywhere.

const TERM := 0.04
const RANGE := 0.10
const TIME_HALF := 3.0 * 86400.0
const TIME_SPREAD := 0.02
const EVENT_HALF := 86400.0
const EVENT_STEP := 0.02
const ROUND := 900
## A faction also weighs by the market it keeps: this share of its book's
## depth counts as size (its venue, where everyone else trades the pack).
const VENUE := 0.25

var time := {}      # pid -> {cat: x}
var state := {}     # pid -> x
var event := {}     # pid -> {cat: x}
var shares := {}    # cat -> {pid: share}
var _round := -1
var _day := -1

func empty() -> bool:
	return shares.is_empty()

func start(m: MarketState) -> void:
	time.clear()
	state.clear()
	event.clear()
	for pid in MarketLedgers.participants(m):
		var t := {}
		for cat in MarketLedgers.cats(m, pid): t[cat] = clampf(m.rng.randfn(0.0, TIME_SPREAD), -TERM, TERM)
		time[pid] = t
	_round = int(m.t / ROUND)
	_day = MarketState.day_key(m.t)
	recompute(m)

func base(m: MarketState, pid: String, cat: String) -> float:
	var b := MarketLedgers.prod_day(m, pid, cat) + MarketLedgers.use_day(m, pid, cat) + MarketLedgers.inv(m, pid, cat) / 7.0
	if not MarketLedgers.is_firm(pid):
		var q := "%s:%s" % [MarketLedgers.id_of(pid), cat]
		if m.books.has(q): b += MarketState.DEPTH_LMD * float(FactionCatalog.info(MarketLedgers.id_of(pid)).get("depth", 1.0)) * VENUE
		elif b <= 0.0 and FactionCatalog.preference(MarketLedgers.id_of(pid), cat) > 0.0: b = MarketLedgers.TRADE_ONLY
	return b

func drift(pid: String, cat: String) -> float:
	return clampf(float((time.get(pid, {}) as Dictionary).get(cat, 0.0)) + float(state.get(pid, 0.0)) + float((event.get(pid, {}) as Dictionary).get(cat, 0.0)), -RANGE, RANGE)

func factor(m: MarketState, pid: String, cat: String) -> float:
	return base(m, pid, cat) * (1.0 + drift(pid, cat))

func recompute(m: MarketState) -> void:
	shares.clear()
	var pids := MarketLedgers.participants(m)
	for cat in FactionCatalog.line_ids():
		var row := {}
		var total := 0.0
		for pid in pids:
			if not MarketLedgers.cats(m, pid).has(cat): continue
			var f := factor(m, pid, cat)
			if f <= 0.0: continue
			row[pid] = f
			total += f
		if total <= 0.0: continue
		for pid in row: row[pid] = float(row[pid]) / total
		shares[cat] = row
	m._mods_dirty = true

func share(pid: String, cat: String) -> float:
	return float((shares.get(cat, {}) as Dictionary).get(pid, 0.0))

## A faction book's share of its line; before any shares, an even split.
func quote_share(m: MarketState, quote: String) -> float:
	var parts := FactionCatalog.split(quote)
	var cat := str(parts[1])
	if shares.has(cat): return share("f:" + str(parts[0]), cat)
	var n := m.quotes_of(cat).size()
	return 1.0 / n if n > 0 else 1.0

func step(m: MarketState, _dt: int) -> void:
	var r := int(m.t / ROUND)
	if r == _round: return
	var rounds := clampi(r - _round, 1, 96) if _round >= 0 else 1
	_round = r
	var keep_t := pow(0.5, rounds * ROUND / TIME_HALF)
	var keep_e := pow(0.5, rounds * ROUND / EVENT_HALF)
	var sigma := TIME_SPREAD * sqrt(maxf(0.0, 1.0 - keep_t * keep_t))
	for pid in time:
		var row: Dictionary = time[pid]
		for cat in row: row[cat] = clampf(float(row[cat]) * keep_t + m.rng.randfn(0.0, sigma), -TERM, TERM)
	for pid in event:
		var row: Dictionary = event[pid]
		for cat in row.keys():
			row[cat] = float(row[cat]) * keep_e
			if absf(float(row[cat])) < 0.001: row.erase(cat)
	var day := MarketState.day_key(m.t)
	if day != _day:
		_day = day
		_daily(m)
	recompute(m)

## The state term: a faction's cash against its start, a firm's use and value.
func _daily(m: MarketState) -> void:
	for pid in MarketLedgers.participants(m):
		var s := MarketLedgers.store(m, pid)
		var x := 0.0
		if MarketLedgers.is_firm(pid):
			x = (float(s.get("util", 0.8)) - 0.8) * 0.2 + (m.firms.fair_index(MarketLedgers.id_of(pid)) - 1.0) * 0.1
		else:
			var start := float(FactionAICatalog.info(MarketLedgers.id_of(pid)).get("cash", 1.0))
			x = (float(s.get("cash", start)) / maxf(start, 1.0) - 1.0) * 0.04
		state[pid] = clampf(x, -TERM, TERM)
		if not time.has(pid): time[pid] = {}

## The event term: news naming a faction (its books) or a firm moves it.
func on_event(m: MarketState, items: Array, picks: Dictionary, id: String = "") -> void:
	for item in items:
		if item.get("global", false): continue
		var sign := 0.0
		if item.has("jump"): sign = signf(float(item.jump))
		elif item.has("mult"): sign = signf(float(item.mult) - 1.0)
		if sign == 0.0: continue
		for q in item.markets:
			if Currencies.is_fx(str(q)): continue
			var parts := FactionCatalog.split(str(q))
			_nudge("f:" + str(parts[0]), str(parts[1]), sign)
	if picks.has("firm") and id.begins_with("FE"):
		var firm := str(picks.firm)
		var sign := -1.0 if id in ["FE2", "FE4"] else 1.0
		for cat in MarketLedgers.cats(m, "c:" + firm): _nudge("c:" + firm, str(cat), sign)

func _nudge(pid: String, cat: String, sign: float) -> void:
	if not event.has(pid): event[pid] = {}
	event[pid][cat] = clampf(float(event[pid].get(cat, 0.0)) + EVENT_STEP * sign, -TERM, TERM)

func to_data() -> Dictionary:
	return {"time": time.duplicate(true), "state": state.duplicate(), "event": event.duplicate(true), "shares": shares.duplicate(true), "round": _round, "day": _day}

func load_data(d: Dictionary) -> void:
	time = (d.get("time", {}) as Dictionary).duplicate(true)
	state = (d.get("state", {}) as Dictionary).duplicate()
	event = (d.get("event", {}) as Dictionary).duplicate(true)
	_round = int(d.get("round", -1))
	_day = int(d.get("day", -1))
	shares = (d.get("shares", {}) as Dictionary).duplicate(true)
