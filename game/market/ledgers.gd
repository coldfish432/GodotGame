class_name MarketLedgers
extends RefCounted

## 交易所统一行情修订案 v0.3 §2: every faction and listed firm keeps a book
## for each pack it touches: what it makes and uses a day, what it holds, what
## it wants to hold, how much it can store, what its stock cost. Amounts are
## 龙门币 of base price (index 1), the unit the actors already trade in.
## Participants are "f:<faction>" (the trading factions) and "c:<firm>".
## The numbers live in the actors' and the firms' own dictionaries (saved with
## them): faction "inv" / "cost" / "pm" / "hold", firm the same keys.

## A day's storage: this share of the stock's worth comes out of the cash.
const STORAGE := 0.002
## Room: this many times the target stock.
const CAPACITY := 4.0
## What its own making cost, as a share of the line's price.
const OWN_COST := 0.6
## A maker wants this many days of its making on hand.
const PRODUCER_DAYS := 3.0
## A faction that buys a pack it neither uses nor makes (v0.2 §3.1).
const TRADE_ONLY := 3000.0

## Caches: what a participant touches never changes; the totals hold for one tick.
static var _cats := {}
static var _tot := {}
static var _tot_t := -1
static var _tot_m: Object = null

static func participants(m: MarketState) -> Array[String]:
	var out: Array[String] = []
	if m.actors != null:
		for f in FactionCatalog.trading():
			if m.actors.factions.has(f): out.append("f:" + f)
	if m.firms != null:
		for id in FirmCatalog.ORDER:
			if m.firms.firms.has(id): out.append("c:" + id)
	return out

static func is_firm(pid: String) -> bool:
	return pid.begins_with("c:")

static func id_of(pid: String) -> String:
	return pid.substr(2)

static func name_of(pid: String) -> String:
	return FirmCatalog.name_of(id_of(pid)) if is_firm(pid) else FactionCatalog.name_of(id_of(pid))

## The dictionary that holds its numbers ({} when it has none yet).
static func store(m: MarketState, pid: String) -> Dictionary:
	if is_firm(pid): return m.firms.firms.get(id_of(pid), {}) if m.firms != null else {}
	return m.actors.factions.get(id_of(pid), {}) if m.actors != null else {}

## The packs it buys, makes or uses (lines only).
static func cats(m: MarketState, pid: String) -> Array:
	if _cats.has(pid): return _cats[pid]
	var out: Array = []
	var lines := FactionCatalog.line_ids()
	var keys: Array = []
	if is_firm(pid):
		var info := FirmCatalog.info(id_of(pid))
		keys = (info.get("in", {}) as Dictionary).keys() + (info.get("out", {}) as Dictionary).keys()
	else:
		var f := id_of(pid)
		var ai := FactionAICatalog.info(f)
		keys = (FactionCatalog.info(f).get("prefs", {}) as Dictionary).keys() + (ai.get("use", {}) as Dictionary).keys() + (ai.get("make", {}) as Dictionary).keys()
	for c in keys:
		if lines.has(str(c)) and not out.has(str(c)): out.append(str(c))
	_cats[pid] = out
	return out

static func prod_day(m: MarketState, pid: String, cat: String) -> float:
	if is_firm(pid):
		var info := FirmCatalog.info(id_of(pid))
		var f := store(m, pid)
		if f.is_empty(): return 0.0
		return float(f.cap) * float(f.util) * float((info.get("out", {}) as Dictionary).get(cat, 0.0)) * pm(m, pid, cat)
	return float((FactionAICatalog.info(id_of(pid)).get("make", {}) as Dictionary).get(cat, 0.0)) * pm(m, pid, cat)

static func use_day(m: MarketState, pid: String, cat: String) -> float:
	if is_firm(pid):
		var info := FirmCatalog.info(id_of(pid))
		var f := store(m, pid)
		if f.is_empty(): return 0.0
		return float(f.cap) * float(f.util) * float(info.input) * float((info.get("in", {}) as Dictionary).get(cat, 0.0))
	return float((FactionAICatalog.info(id_of(pid)).get("use", {}) as Dictionary).get(cat, 0.0))

static func use_total(m: MarketState, pid: String) -> float:
	var t := 0.0
	for c in cats(m, pid): t += use_day(m, pid, str(c))
	return t

static func inv(m: MarketState, pid: String, cat: String) -> float:
	var s := store(m, pid)
	return float((s.get("inv", {}) as Dictionary).get(cat, 0.0))

## Adds (or takes, negative) `delta` at `price` (index): buying moves its cost.
static func add_inv(m: MarketState, pid: String, cat: String, delta: float, price: float) -> void:
	var s := store(m, pid)
	if s.is_empty(): return
	if not s.has("inv"): s["inv"] = {}
	if not s.has("cost"): s["cost"] = {}
	var have := float(s.inv.get(cat, 0.0))
	if delta > 0.0:
		var c := float(s.cost.get(cat, price))
		s.cost[cat] = (c * have + price * delta) / maxf(have + delta, 1e-6)
	s.inv[cat] = maxf(0.0, have + delta)

static func cost(m: MarketState, pid: String, cat: String) -> float:
	return float((store(m, pid).get("cost", {}) as Dictionary).get(cat, m.index(cat)))

static func target(m: MarketState, pid: String, cat: String) -> float:
	var t := 0.0
	if is_firm(pid):
		var made := prod_day(m, pid, cat)
		t = made * PRODUCER_DAYS if made > 0.0 else use_day(m, pid, cat) * 3.0
	else:
		var tr := traits(m, pid)
		t = use_day(m, pid, cat) * MarketActors._target_days(tr) + prod_day(m, pid, cat) * PRODUCER_DAYS
	return maxf(t, 1.0)

static func capacity(m: MarketState, pid: String, cat: String) -> float:
	return maxf(target(m, pid, cat) * CAPACITY, 1000.0)

static func cash(m: MarketState, pid: String) -> float:
	return float(store(m, pid).get("cash", 0.0))

static func add_cash(m: MarketState, pid: String, d: float) -> void:
	var s := store(m, pid)
	if not s.is_empty(): s.cash = float(s.cash) + d

## Its making this round, × an active cut or rise (B10 / B11).
static func pm(m: MarketState, pid: String, cat: String) -> float:
	var e: Variant = (store(m, pid).get("pm", {}) as Dictionary).get(cat)
	if e is Array and int(e[1]) > m.t: return float(e[0])
	return 1.0

static func set_pm(m: MarketState, pid: String, cat: String, mult: float, until: int) -> void:
	var s := store(m, pid)
	if s.is_empty(): return
	if not s.has("pm"): s["pm"] = {}
	s.pm[cat] = [mult, until]

## Held back from its ordinary selling (B4 hoarding, B8 cornering).
static func held(m: MarketState, pid: String, cat: String) -> bool:
	return bool((store(m, pid).get("hold", {}) as Dictionary).get(cat, false))

static func set_hold(m: MarketState, pid: String, cat: String, on: bool) -> void:
	var s := store(m, pid)
	if s.is_empty(): return
	if not s.has("hold"): s["hold"] = {}
	if on: s.hold[cat] = true
	else: s.hold.erase(cat)

## Character: the faction's six traits plus 秩序 / 野心 (§3); a firm's by its growth class.
const FIRM_TRAITS := {
	"fast": {"risk": 0.7, "patience": 0.4, "value": 0.4, "credulity": 0.4, "revenge": 0.1, "cash": 0.3, "order": 0.3, "ambition": 0.8},
	"stable": {"risk": 0.4, "patience": 0.7, "value": 0.6, "credulity": 0.3, "revenge": 0.1, "cash": 0.5, "order": 0.7, "ambition": 0.4},
	"slow": {"risk": 0.3, "patience": 0.8, "value": 0.7, "credulity": 0.3, "revenge": 0.1, "cash": 0.6, "order": 0.6, "ambition": 0.3},
	"cycle": {"risk": 0.8, "patience": 0.4, "value": 0.5, "credulity": 0.5, "revenge": 0.1, "cash": 0.4, "order": 0.4, "ambition": 0.5},
}

static func traits(m: MarketState, pid: String) -> Dictionary:
	if is_firm(pid): return FIRM_TRAITS.get(str(FirmCatalog.info(id_of(pid)).get("tone", "stable")), FIRM_TRAITS.stable)
	var s := store(m, pid)
	var out: Dictionary = (s.get("traits", FactionAICatalog.info(id_of(pid)).get("traits", {})) as Dictionary).duplicate()
	var extra: Dictionary = FactionAICatalog.DRIVE_TRAITS.get(id_of(pid), {})
	out["order"] = float(extra.get("order", 0.5))
	out["ambition"] = float(extra.get("ambition", 0.5))
	return out

## Everyone's stock of one pack, and its making and use, together.
static func totals(m: MarketState, cat: String) -> Dictionary:
	if _tot_t != m.t or _tot_m != m:
		_tot.clear()
		_tot_t = m.t
		_tot_m = m
	if _tot.has(cat): return _tot[cat]
	var out := {"inv": 0.0, "prod": 0.0, "use": 0.0}
	for pid in participants(m):
		out.inv = float(out.inv) + inv(m, pid, cat)
		out.prod = float(out.prod) + prod_day(m, pid, cat)
		out.use = float(out.use) + use_day(m, pid, cat)
	_tot[cat] = out
	return out

## The day's storage fee (§2.1), out of its cash.
static func charge_storage(m: MarketState, pid: String) -> float:
	var s := store(m, pid)
	var fee := 0.0
	for cat in (s.get("inv", {}) as Dictionary):
		fee += float(s.inv[cat]) * m.index(str(cat)) * STORAGE
	if fee > 0.0: add_cash(m, pid, -fee)
	return fee
