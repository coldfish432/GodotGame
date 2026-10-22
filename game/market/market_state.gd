class_name MarketState
extends RefCounted

## The live market (势力与交易所策划案_v0_7.md §5): real time, never closed,
## simulated on load for the time the game was shut (用户 2026-10-15: 不暂停，
## 读取存档时模拟 k 线). Each market is an index around 1 that drifts in three
## hidden regimes, mean-reverts in two layers (about 20 minutes to the day's
## mean, about 5 days to the long-term level), and is pushed by news
## (MarketEvents) and by the player's own selling (pressure). Big moves are
## rate-limited to 10% per 5 minutes instead of halting (§5.5, 不停市).

const TICK := 2
## Catching up after the game was shut: exact 2 s ticks for the last hour,
## 20 s steps back to six hours (1-minute candles stay fine), 5-minute steps
## back to seven days (15-minute candles), nothing older.
const EXACT_WINDOW := 3600
const MID_WINDOW := 6 * 3600
const MID_STEP := 20
const COARSE := 300
const MAX_SIM := 7 * 86400
const DAY := 86400
const DAY_START := 8 * 3600
const KEEP_M1 := 360
const KEEP_M15 := 672
const KEEP_D1 := 400
const FIELDS := 5   # o h l c v
## Reversion speeds per second: the day's mean pulls the index back with a
## half-life of 20 minutes, the mean goes back to 1 over about 5 days.
const K_INTRADAY := 0.693 / 1200.0
const K_MEAN := 0.693 / (5.0 * 86400.0)
const MEAN_NOISE := 0.03 / 208.0      # per sqrt(tick): about 3% a day
## Regimes: per-tick noise, trend (per tick), duration range (seconds), odds.
const REGIMES := [
	{"name": "calm", "noise": 0.0009, "trend": 0.0, "secs": [180, 600], "odds": 0.55},
	{"name": "trend", "noise": 0.0012, "trend": 0.00004, "secs": [180, 480], "odds": 0.30},
	{"name": "wild", "noise": 0.0040, "trend": 0.0, "secs": [60, 180], "odds": 0.15},
]
const FX_NOISE := 0.6
const OFF_HOURS := {"spread": 2.0, "depth": 0.5, "vol": 0.7}
const SWITCH_VOL := 1.3
## Rate limit (§5.5): a market moves at most this much per window.
const LIMIT := 0.10
const LIMIT_WINDOW := 300
## Base depth (龙门币 of base price) against which selling pushes the index.
const DEPTH_LMD := 200000.0
const PRESSURE_HALF := 300.0
## A news jump fades back over this half-life (seconds).
const SHOCK_HALF := 7200.0
const PRESSURE_CAP := 0.5
## News per real day; flash offers per day; black swans: one every ~3 weeks
## on average, memoryless (用户: 完全随机).
## Tuned with tests/sim_exchange.gd (§15). 用户 2026-10-16: 增加事件数量 —
## 102 kinds of event and about two headlines an hour.
const BREAKING_PER_DAY := 36.0
const RUMOR_PER_DAY := 18.0
const FLASH_PER_DAY := 2.5
const SWAN_MEAN := 21.0 * 86400.0
const RANDOM_ANNOUNCES := 2
const NEWS_KEEP := 120
const LOCK_TICKS := 3
const CREDIBILITY := {"低": 0.3, "中": 0.55, "高": 0.8}
const RUMOR_FIRST := 0.3

## Local time offset in seconds; -1 = the system's.
static var tz_override := -1

## One market's book.
class Book:
	var id := ""
	var faction := ""
	var category := ""
	var i := 1.0       # the index
	var mu := 1.0      # the day's mean
	var lt := 1.0      # long-term level (black swans move it)
	var rg := 0
	var rl := 0.0      # seconds left in the regime
	var tr := 0.0      # trend per tick
	var p := 0.0       # selling pressure
	var pj := 0.0      # pending jump (log), released under the rate limit
	var sh := 0.0      # shock (log): a news jump the index is pulled toward, fading over hours
	var ew := 0.0      # recent size of moves per tick (vol clustering)
	var mo := 0.0      # recent drift per second (herding: moves feed the next ones)
	var w0 := 0        # rate-limit window start
	var wp := 1.0      # index at the window start
	var lock := 0      # orders do not fill before this time
	var c1 := PackedFloat32Array()
	var c15 := PackedFloat32Array()
	var cd := PackedFloat32Array()
	var b1 := -1
	var b15 := -1
	var bd := -1
	# Cached from the faction table.
	var noise := 1.0
	var fx := false
	var switches: Array = []
	var active_kind := "all"

	func setup(market: String) -> void:
		id = market
		var parts := FactionCatalog.split(market)
		faction = parts[0]
		category = parts[1]
		fx = market == FactionCatalog.FX
		var info := FactionCatalog.info(faction)
		noise = float(info.get("noise", 1.0))
		active_kind = str(info.get("active", "all"))
		switches = FactionCatalog.switch_hours(faction)

	## Candles are updated in place (member arrays do not copy).
	func candle(local_t: int, open_price: float, volume: float) -> void:
		var k1 := floori(local_t / 60.0) * 60
		var k15 := floori(local_t / 900.0) * 900
		var kd := floori((local_t - DAY_START) / float(DAY))
		if k1 != b1:
			b1 = k1
			c1.append_array(PackedFloat32Array([open_price, maxf(open_price, i), minf(open_price, i), i, volume]))
			if c1.size() > KEEP_M1 * FIELDS * 2: c1 = c1.slice(c1.size() - KEEP_M1 * FIELDS)
		else:
			var n := c1.size()
			c1[n - 4] = maxf(c1[n - 4], i)
			c1[n - 3] = minf(c1[n - 3], i)
			c1[n - 2] = i
			c1[n - 1] += volume
		if k15 != b15:
			b15 = k15
			c15.append_array(PackedFloat32Array([open_price, maxf(open_price, i), minf(open_price, i), i, volume]))
			if c15.size() > KEEP_M15 * FIELDS * 2: c15 = c15.slice(c15.size() - KEEP_M15 * FIELDS)
		else:
			var n := c15.size()
			c15[n - 4] = maxf(c15[n - 4], i)
			c15[n - 3] = minf(c15[n - 3], i)
			c15[n - 2] = i
			c15[n - 1] += volume
		if kd != bd:
			bd = kd
			cd.append_array(PackedFloat32Array([open_price, maxf(open_price, i), minf(open_price, i), i, volume]))
			if cd.size() > KEEP_D1 * FIELDS * 2: cd = cd.slice(cd.size() - KEEP_D1 * FIELDS)
		else:
			var n := cd.size()
			cd[n - 4] = maxf(cd[n - 4], i)
			cd[n - 3] = minf(cd[n - 3], i)
			cd[n - 2] = i
			cd[n - 1] += volume

	func trim() -> void:
		if c1.size() > KEEP_M1 * FIELDS: c1 = c1.slice(c1.size() - KEEP_M1 * FIELDS)
		if c15.size() > KEEP_M15 * FIELDS: c15 = c15.slice(c15.size() - KEEP_M15 * FIELDS)
		if cd.size() > KEEP_D1 * FIELDS: cd = cd.slice(cd.size() - KEEP_D1 * FIELDS)

	func to_data() -> Dictionary:
		trim()
		return {"id": id, "i": i, "mu": mu, "lt": lt, "rg": rg, "rl": rl, "tr": tr, "p": p, "pj": pj, "sh": sh, "ew": ew, "mo": mo, "w0": w0, "wp": wp,
			"c1": c1, "c15": c15, "cd": cd, "b1": b1, "b15": b15, "bd": bd}

	func load(d: Dictionary) -> void:
		i = float(d.get("i", 1.0)); mu = float(d.get("mu", 1.0)); lt = float(d.get("lt", 1.0))
		rg = int(d.get("rg", 0)); rl = float(d.get("rl", 0.0)); tr = float(d.get("tr", 0.0))
		p = float(d.get("p", 0.0)); pj = float(d.get("pj", 0.0)); sh = float(d.get("sh", 0.0)); ew = float(d.get("ew", 0.0)); mo = float(d.get("mo", 0.0)); w0 = int(d.get("w0", 0)); wp = float(d.get("wp", i))
		c1 = d.get("c1", PackedFloat32Array()); c15 = d.get("c15", PackedFloat32Array()); cd = d.get("cd", PackedFloat32Array())
		b1 = int(d.get("b1", -1)); b15 = int(d.get("b15", -1)); bd = int(d.get("bd", -1))

var t := 0
var rng := RandomNumberGenerator.new()
var books := {}            # market id -> Book
var effects: Array = []    # {id, title, kind, until, scale, items: [{markets, mult, spread, depth, vol, quota, fee, halt_until, active_all}], rumor: {...}}
var news: Array = []       # {t, id, kind, title, region, cred, status, unread}
var calendar: Array = []   # {at, id, seasonal}
var flash: Array = []      # {id, faction, kind, category, material, mult, cap, left, until}
var swan := {}             # {at, id, precursor_at, precursor_done}
var rumors_low_until := 0
var threat := {}           # region -> {mult, until}
var post_boost := {}       # faction -> until
var penguin := {"fee": 1.0, "risk": 0.0, "until": 0}
var cfd_halt := {}         # issuer -> until
var seasonal_scanned := 0
## Linked events (MarketLinks): follow-ups waiting {at, id, cause, picks}, and
## odds changes id -> [{x, until}].
var chain: Array = []
var boosts := {}
## The world state (态势, MarketLinks.FACTORS): every event pushes it, every draw reads it.
var factors := {}
var barter_seed := 1
var _mods := {}
var _all_day := {}
var _mods_dirty := true
var _next_flash_id := 1
## on_news(entry: Dictionary, event: Dictionary), on_step(t: int, dt: int).
var on_news := Callable()
var on_step := Callable()
var on_flash := Callable()

func _init() -> void:
	rng.randomize()

## A fresh market at `now`, with two hours of history behind it.
func start(now: int, seed_value: int = 0) -> void:
	if seed_value != 0: rng.seed = seed_value
	books.clear()
	for id in FactionCatalog.markets():
		var b := Book.new()
		b.setup(id)
		b.i = clampf(1.0 + rng.randfn(0.0, 0.04), 0.85, 1.15)
		b.mu = b.i
		b.wp = b.i
		_new_regime(b)
		books[id] = b
	t = now - 2 * 3600
	for b in books.values(): b.w0 = t
	_schedule_swan()
	var cb := on_news
	on_news = Callable()        # the made-up history makes no headlines
	var sb := on_step
	on_step = Callable()
	advance_to(now)
	news.clear()
	on_news = cb
	on_step = sb

# --- Time ------------------------------------------------------------------------

static func tz() -> int:
	if tz_override >= 0: return tz_override
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60

static func local(at: int) -> int:
	return at + tz()

static func hour_at(at: int) -> int:
	return int(posmod(local(at), DAY) / 3600)

## The trading day (local 08:00 to 08:00) `at` falls in.
static func day_key(at: int) -> int:
	return floori(float(local(at) - DAY_START) / DAY)

## Unix time of the next local 08:00 after `at`.
static func next_day_start(at: int) -> int:
	return (day_key(at) + 1) * DAY + DAY_START - tz()

## Runs the market up to `now`: exact ticks for the last six hours of a gap,
## one-minute steps before that, nothing older than seven days.
func advance_to(now: int) -> void:
	if t <= 0:
		start(now)
		return
	if now - t > MAX_SIM: t = now - MAX_SIM
	while t + TICK <= now:
		var left := now - t
		var dt := TICK
		if left > MID_WINDOW: dt = mini(COARSE, left - MID_WINDOW)
		elif left > EXACT_WINDOW: dt = mini(MID_STEP, left - EXACT_WINDOW)
		_step(maxi(dt, TICK))

func _step(dt: int) -> void:
	t += dt
	if _mods_dirty: _rebuild_mods()
	var lt := local(t)
	var minute_of_day := int(posmod(lt, DAY) / 60)
	var hour := minute_of_day / 60
	var fx_rate_before := fx_rate()
	# One shock for every book at once, bigger in a panic (contagion), and a
	# panic drags goods down and 赤金 up while it lasts.
	var panic := maxf(0.0, factor("panic"))
	_common = rng.randfn(0.0, COMMON_NOISE * (1.0 + PANIC_VOL * panic)) * sqrt(float(dt) / TICK)
	_crash = PANIC_DRIFT * panic * float(dt) / TICK
	for b: Book in books.values():
		_move(b, dt, hour, minute_of_day, lt)
	_events(dt)
	if fx_rate_before != fx_rate(): Economy.fx = fx_rate()
	if on_step.is_valid(): on_step.call(t, dt)

func _move(b: Book, dt: int, hour: int, minute_of_day: int, lt: int) -> void:
	var m: Dictionary = _mods.get(b.id, EMPTY)
	var ticks := float(dt) / TICK
	b.rl -= dt
	if b.rl <= 0.0: _new_regime(b)
	var regime: Dictionary = REGIMES[b.rg]
	var vol := float(regime.noise) * float(m.get("vol", 1.0))
	if b.fx: vol *= FX_NOISE
	else:
		vol *= b.noise
		if not _active_book(b, hour): vol *= OFF_HOURS.vol
		for h in b.switches:
			var gap := absi(minute_of_day - int(h) * 60)
			if mini(gap, 1440 - gap) <= 30: vol *= SWITCH_VOL
	var root := sqrt(ticks)
	# Volatility clusters: after big moves, bigger moves.
	vol *= clampf(b.ew / CLUSTER_BASE, 0.7, CLUSTER_MAX) if b.ew > 0.0 else 1.0
	# Fat tails: now and then a move several times the usual.
	if rng.randf() < TAIL_CHANCE * ticks: vol *= TAIL_SIZE
	# The day's mean wanders back to 1, slowly.
	b.mu = exp(log(b.mu) * (1.0 - K_MEAN * dt) + rng.randfn(0.0, MEAN_NOISE) * root)
	if absf(b.sh) > 0.0001: b.sh *= pow(0.5, dt / SHOCK_HALF)
	var target := b.mu * b.lt * float(m.get("mult", 1.0)) * exp(b.sh)
	var x := log(b.i)
	# A running market forgets where "normal" is (bubbles): momentum weakens the pull back.
	var pull := K_INTRADAY / (1.0 + absf(b.mo) / MOMENTUM_REF)
	var beta := FX_BETA if b.fx else (BLACK_BETA if b.noise > 1.0 else 1.0)
	var move := (log(target) - x) * minf(1.0, pull * dt) + b.tr * ticks + HERDING * b.mo * dt + rng.randfn(0.0, vol) * root + beta * (_common - _crash)
	x += move
	# News moves come in under the rate limit, the rest next window.
	if t - b.w0 >= LIMIT_WINDOW:
		b.w0 = t
		b.wp = b.i
	var lo := log(b.wp * (1.0 - LIMIT))
	var hi := log(b.wp * (1.0 + LIMIT))
	if absf(b.pj) > 0.0001:
		var release := clampf(b.pj, minf(0.0, lo - x), maxf(0.0, hi - x))
		x += release
		b.pj -= release
	else: b.pj = 0.0
	x = clampf(x, lo, hi)
	var old := b.i
	b.i = clampf(exp(x), 0.05, 20.0)
	var r := log(b.i / old)
	var keep_c := pow(CLUSTER_KEEP, ticks)
	b.ew = b.ew * keep_c + (1.0 - keep_c) * absf(r) / maxf(root, 1.0)
	var keep_m := pow(MOMENTUM_KEEP, dt)
	b.mo = b.mo * keep_m + (1.0 - keep_m) * r / float(dt)
	if b.p > 0.0001: b.p *= pow(0.5, dt / PRESSURE_HALF)
	b.candle(lt, old, absf(b.i - old) * 4000.0 * rng.randf())

const EMPTY := {}
## Market behaviour (用户: 股市的事情你知道的).
const CLUSTER_BASE := 0.0010
const CLUSTER_MAX := 3.0
const CLUSTER_KEEP := 0.97
const TAIL_CHANCE := 0.0008
const TAIL_SIZE := 6.0
## Herding: a share of the recent drift (per second, ~15 min memory) carries on.
## Below 1, so trends run and then tire instead of exploding.
const HERDING := 0.6
const MOMENTUM_KEEP := 0.9989
const MOMENTUM_REF := 0.00002
const COMMON_NOISE := 0.0005
const PANIC_VOL := 1.5
const PANIC_DRIFT := 0.00001
const FX_BETA := -0.8
const BLACK_BETA := 1.3
var _common := 0.0
var _crash := 0.0

func _active_book(b: Book, hour: int) -> bool:
	if _all_day.has(b.faction): return true
	match b.active_kind:
		"day": return hour >= 8 and hour < 20
		"night": return hour >= 20 or hour < 8
	return true

func _new_regime(b: Book) -> void:
	var roll := rng.randf()
	var acc := 0.0
	for k in range(REGIMES.size()):
		acc += float(REGIMES[k].odds)
		if roll <= acc or k == REGIMES.size() - 1:
			b.rg = k
			break
	var secs: Array = REGIMES[b.rg].secs
	b.rl = rng.randf_range(float(secs[0]), float(secs[1]))
	b.tr = float(REGIMES[b.rg].trend) * (1.0 if rng.randf() < 0.5 else -1.0)

# --- Candles -------------------------------------------------------------------------

## Candles of `market` at `period` ("1m", "5m", "15m", "1h", "4h", "1d", "1w"):
## [[o, h, l, c, v], …], oldest first, in display units (FX in 龙门币 per 赤金,
## others ×100).
func candles(market: String, period: String, limit: int = 120) -> Array:
	var b: Book = books.get(market)
	if b == null: return []
	var src := b.c1
	var group := 1
	match period:
		"5m": group = 5
		"15m": src = b.c15
		"1h":
			src = b.c15
			group = 4
		"4h":
			src = b.c15
			group = 16
		"1d": src = b.cd
		"1w":
			src = b.cd
			group = 7
		_: pass
	var scale := display_scale(market)
	var out: Array = []
	var n := src.size() / FIELDS
	# Groups end at the newest candle; the oldest group may be partial.
	var end := n
	while end > 0 and out.size() < limit:
		var begin := maxi(0, end - group)
		var o := src[begin * FIELDS]
		var h := -INF
		var lo := INF
		var c := src[(end - 1) * FIELDS + 3]
		var v := 0.0
		for k in range(begin, end):
			h = maxf(h, src[k * FIELDS + 1])
			lo = minf(lo, src[k * FIELDS + 2])
			v += src[k * FIELDS + 4]
		out.append([o * scale, h * scale, lo * scale, c * scale, v])
		end = begin
	out.reverse()
	if out.size() > limit: out = out.slice(out.size() - limit)
	return out

static func display_scale(market: String) -> float:
	return 1000.0 if market == FactionCatalog.FX else 100.0

# --- Quotes ----------------------------------------------------------------------------

func active(faction: String, hour: int = -1) -> bool:
	if hour < 0: hour = hour_at(t)
	if _mods_dirty: _rebuild_mods()
	if _all_day.has(faction): return true
	return FactionCatalog.active_at(faction, hour)

func index(market: String) -> float:
	var b: Book = books.get(market)
	return b.i if b != null else 1.0

func price(market: String) -> float:
	return index(market) * display_scale(market)

## The day's change of `market` (from the trading day's open).
func change(market: String) -> float:
	var b: Book = books.get(market)
	if b == null or b.cd.size() < FIELDS: return 0.0
	var o := b.cd[b.cd.size() - FIELDS]
	return (b.i - o) / maxf(o, 0.0001)

func mods(market: String) -> Dictionary:
	if _mods_dirty: _rebuild_mods()
	return _mods.get(market, {})

## Full bid/ask gap now (fraction).
func spread(market: String) -> float:
	var b: Book = books.get(market)
	if b == null: return 0.0
	if market == FactionCatalog.FX: return 0.0
	var s := float(FactionCatalog.info(b.faction).get("spread", 0.03)) * float(mods(market).get("spread", 1.0))
	if not active(b.faction): s *= OFF_HOURS.spread
	return s

func depth(market: String) -> float:
	var b: Book = books.get(market)
	if b == null: return DEPTH_LMD
	var d := DEPTH_LMD * float(FactionCatalog.info(b.faction).get("depth", 1.0)) * float(mods(market).get("depth", 1.0))
	if not active(b.faction): d *= OFF_HOURS.depth
	return maxf(d, 1000.0)

## What the faction pays, as a multiple of base price before preference.
func bid(market: String) -> float:
	var b: Book = books.get(market)
	if b == null: return 0.0
	return b.i * (1.0 - b.p) * (1.0 - spread(market) * 0.5)

func ask(market: String) -> float:
	var b: Book = books.get(market)
	if b == null: return 0.0
	return b.i * (1.0 + spread(market) * 0.5)

func halted(market: String) -> bool:
	return int(mods(market).get("halt_until", 0)) > t

func locked(market: String) -> bool:
	var b: Book = books.get(market)
	return b != null and b.lock > t

func fee_extra(market: String) -> float:
	return float(mods(market).get("fee", 0.0))

func quota_mult(faction: String) -> float:
	var m := 1.0
	for e in effects:
		for item in e.items:
			if item.has("quota") and faction in item.get("factions", []): m = minf(m, float(item.quota))
	return m

## Selling `value` (龙门币 of base price) into `market` pushes it down.
func add_pressure(market: String, value: float) -> void:
	var b: Book = books.get(market)
	if b == null: return
	b.p = minf(PRESSURE_CAP, b.p + value / depth(market))
	if b.c1.size() >= FIELDS: b.c1[b.c1.size() - 1] += value

## The faction's composite index: the mean of its markets.
func composite(faction: String) -> float:
	var total := 0.0
	var n := 0
	for b: Book in books.values():
		if b.faction == faction:
			total += b.i
			n += 1
	return total / maxf(n, 1)

func fx_rate() -> float:
	return index(FactionCatalog.FX) * 1000.0

func threat_mult(region: String) -> float:
	var entry: Dictionary = threat.get(region, {})
	return float(entry.get("mult", 1.0)) if int(entry.get("until", 0)) > t else 1.0

func penguin_fee() -> float:
	return float(penguin.fee) if int(penguin.until) > t else 1.0

func penguin_risk() -> float:
	return float(penguin.risk) if int(penguin.until) > t else 0.0

func cfd_halted(issuer: String) -> bool:
	return int(cfd_halt.get(issuer, 0)) > t

func post_boosted(faction: String) -> bool:
	return int(post_boost.get(faction, 0)) > t

# --- Effects -------------------------------------------------------------------------

func _rebuild_mods() -> void:
	_mods.clear()
	_all_day.clear()
	var now_effects: Array = []
	for e in effects:
		if int(e.until) > t: now_effects.append(e)
	effects = now_effects
	for e in effects:
		var scale := float(e.get("scale", 1.0))
		for item in e.items:
			for id in item.markets:
				var m: Dictionary = _mods.get(id, {})
				if item.has("mult"): m["mult"] = float(m.get("mult", 1.0)) * (1.0 + (float(item.mult) - 1.0) * scale)
				for key in ["spread", "depth", "vol"]:
					if item.has(key): m[key] = float(m.get(key, 1.0)) * float(item[key])
				if item.has("fee"): m["fee"] = float(m.get("fee", 0.0)) + float(item.fee)
				if item.has("halt_until"): m["halt_until"] = maxi(int(m.get("halt_until", 0)), int(item.halt_until))
				_mods[id] = m
			if item.get("active_all", false):
				for f in item.get("factions", []): _all_day[f] = true
	# Stacked news cannot push a book past half or double its level.
	for id in _mods:
		if _mods[id].has("mult"): _mods[id]["mult"] = clampf(float(_mods[id].mult), 0.2, 5.0)
	_mods_dirty = false

func _expire_effects() -> void:
	for e in effects:
		if int(e.until) <= t:
			_mods_dirty = true
			return

func _resolve(sel: String, region_factions: Array, picked: String) -> Array:
	var parts := sel.split(":")
	if sel == FactionCatalog.FX: return [FactionCatalog.FX]
	var faction_part := parts[0]
	var category_part := parts[1] if parts.size() > 1 else "*"
	var factions: Array = []
	match faction_part:
		"*": factions = FactionCatalog.trading()
		"@": factions = region_factions
		"#": factions = [picked]
		_: factions = [faction_part]
	var out: Array = []
	for f in factions:
		for c in FactionCatalog.info(f).get("prefs", {}):
			if category_part == "*" or category_part == c:
				out.append("%s:%s" % [f, c])
	return out

## Fires event `id` now. `scale` < 1 for a rumor before it is verified.
## `cause` is the headline it follows from (MarketLinks), "" for none.
func fire(id: String, picks: Dictionary = {}, cause: String = "", depth: int = 0) -> Dictionary:
	picks = picks.duplicate()
	var ev: Dictionary = MarketEvents.EVENTS.get(id, {})
	if ev.is_empty(): return {}
	var title := str(ev.title)
	var region_factions: Array = []
	var picked := ""
	var pick_cat := ""
	if ev.get("pick_region", false):
		var region: String = picks.get("region", "")
		if region.is_empty():
			var regions := MarketEvents.regions()
			region = regions[rng.randi() % regions.size()]
		region_factions = MarketEvents.factions_in(region)
		title = title % region
		picks["region"] = region
	if ev.get("pick_faction", false) or ev.get("pick_issuer", false):
		picked = picks.get("faction", "")
		if picked.is_empty():
			var pool: Array = FactionCatalog.CFD_ISSUERS if ev.get("pick_issuer", false) else FactionCatalog.trading()
			picked = pool[rng.randi() % pool.size()]
		title = title % FactionCatalog.name_of(picked)
		picks["faction"] = picked
	if ev.has("pick"):
		var prefs: Array = FactionCatalog.info(str(ev.pick)).get("prefs", {}).keys()
		pick_cat = picks.get("category", prefs[rng.randi() % prefs.size()])
		title = title % FactionCatalog.CATEGORIES.get(pick_cat, pick_cat)
		picks["category"] = pick_cat
	var signs := {}
	var items: Array = []
	var until := t + int(float(ev.hours) * MarketEvents.HOUR)
	var rumor := str(ev.kind) == "rumor"
	var scale := RUMOR_FIRST if rumor else 1.0
	for spec in ev.effects:
		var sel := str(spec.sel)
		if sel.contains("%s"): sel = sel % pick_cat
		var markets := _resolve(sel, region_factions, picked)
		var item := {"markets": markets, "factions": markets.map(func(m): return FactionCatalog.split(m)[0])}
		var link := str(spec.get("link", ""))
		var sign := 1.0 if rng.randf() < 0.5 else -1.0
		if not link.is_empty():
			if not signs.has(link): signs[link] = sign
			sign = signs[link]
		if spec.has("mult"): item["mult"] = float(spec.mult)
		if spec.has("mult_range"): item["mult"] = 1.0 + sign * rng.randf_range(float(spec.mult_range[0]), float(spec.mult_range[1]))
		for key in ["spread", "depth", "vol", "quota", "fee"]:
			if spec.has(key): item[key] = spec[key]
		if spec.has("halt_hours"): item["halt_until"] = t + int(float(spec.halt_hours) * MarketEvents.HOUR)
		if spec.get("active_all", false): item["active_all"] = true
		var jump := 0.0
		if spec.has("jump"): jump = float(spec.jump)
		if spec.has("jump_range"): jump = sign * rng.randf_range(float(spec.jump_range[0]), float(spec.jump_range[1]))
		if jump != 0.0:
			item["jump"] = jump
			for m in markets: _jump(m, jump * scale)
		if spec.has("longterm"):
			for m in markets:
				var b: Book = books.get(m)
				if b != null: b.lt *= float(spec.longterm)
		for m in markets:
			var b: Book = books.get(m)
			if b != null: b.lock = t + LOCK_TICKS * TICK
		items.append(item)
	var entry := {"id": id, "title": title, "kind": ev.kind, "until": until, "scale": scale, "items": items, "picks": picks}
	if rumor:
		var creds := CREDIBILITY.keys()
		var cred: String = creds[rng.randi() % creds.size()]
		entry["rumor"] = {"cred": cred, "verify_at": t + rng.randi_range(60, 300), "truth": rng.randf() < float(CREDIBILITY[cred]), "false_mult": float(ev.get("false_mult", 1.0))}
	effects.append(entry)
	_mods_dirty = true
	# Event-level extras.
	if ev.has("penguin_fee") or ev.has("penguin_risk"):
		penguin = {"fee": float(ev.get("penguin_fee", 1.0)), "risk": float(ev.get("penguin_risk", 0.0)), "until": until}
	if ev.has("cfd_halt"): cfd_halt[str(ev.cfd_halt)] = until
	if ev.has("rumors_low"): rumors_low_until = maxi(rumors_low_until, t + int(float(ev.rumors_low) * MarketEvents.HOUR))
	if ev.has("threat"): threat[str(ev.threat.region)] = {"mult": float(ev.threat.mult), "until": until}
	if ev.has("post_boost"): post_boost[str(ev.post_boost)] = until
	if ev.get("barter_reroll", false): barter_seed = rng.randi()
	var shown_cred := ""
	if rumor: shown_cred = "低" if rumors_low_until > t else str(entry.rumor.cred)
	var touched: Array = []
	var moves := {}   # market -> +1 / -1: the arrows the headline shows (§6.1)
	for item in items:
		var sign := 0
		if item.has("jump"): sign = 1 if float(item.jump) > 0.0 else -1
		elif item.has("mult") and absf(float(item.mult) - 1.0) > 0.001: sign = 1 if float(item.mult) > 1.0 else -1
		for m in item.markets:
			if not touched.has(m): touched.append(m)
			if sign != 0 and not moves.has(m): moves[m] = sign
	var headline := {"t": t, "id": id, "kind": ev.kind, "title": title, "region": ev.region, "cred": shown_cred,
		"status": "待证实" if rumor else "", "unread": true, "markets": touched, "moves": moves, "cause": cause}
	news.append(headline)
	if news.size() > NEWS_KEEP: news = news.slice(news.size() - NEWS_KEEP)
	if on_news.is_valid(): on_news.call(headline, ev)
	_follow(id, title, picks, "", depth)
	_push(id, float(MarketLinks.PUSH.get(str(ev.kind), 0.3)))
	return entry

## Moves the world state along an event's affinities (calming events pull it down).
func _push(id: String, amount: float) -> void:
	var sign := MarketLinks.push_sign(id)
	var aff := MarketLinks.affinity(id)
	for f in aff:
		var v := float(factors.get(f, 0.0))
		var step := float(aff[f]) * amount * sign
		# Saturation: the further it already leans that way, the less it moves.
		var room := (MarketLinks.FACTOR_RANGE.y - v) / MarketLinks.FACTOR_RANGE.y if step > 0.0 else (v - MarketLinks.FACTOR_RANGE.x) / -MarketLinks.FACTOR_RANGE.x
		factors[f] = clampf(v + step * clampf(room, 0.0, 1.0), MarketLinks.FACTOR_RANGE.x, MarketLinks.FACTOR_RANGE.y)

## How the world state leans an event's odds: exp(affinity · factors).
func lean(id: String) -> float:
	var aff := MarketLinks.affinity(id)
	var x := 0.0
	for f in aff: x += float(aff[f]) * tanh(float(factors.get(f, 0.0)))
	return clampf(exp(x * MarketLinks.LEAN_GAIN), MarketLinks.WEIGHT_RANGE.x, MarketLinks.WEIGHT_RANGE.y)

func factor(f: String) -> float:
	return float(factors.get(f, 0.0))

## What `id` sets off (MarketLinks): follow-ups by chance, odds for a while.
## `phase` is "" on firing, "true" / "false" when a rumor is settled.
## Each generation down a chain is less likely to go on (CHAIN_DAMP), so loops
## in the web die out instead of running away.
## Loose on purpose (用户: 不用过于考虑平衡): chains run long, odds stack.
const CHAIN_DAMP := 0.85
const BOOST_CAP := 8.0

func _follow(id: String, title: String, picks: Dictionary, phase: String, depth: int = 0) -> void:
	for link in MarketLinks.LINKS.get(id, []):
		if link.has("b"):
			if not phase.is_empty(): continue
			var list: Array = boosts.get(str(link.b), [])
			list.append({"x": float(link.x), "until": t + int(float(link.h) * 3600.0)})
			boosts[str(link.b)] = list
			continue
		if str(link.get("if", "")) != phase: continue
		if rng.randf() >= float(link.p) * pow(CHAIN_DAMP, depth): continue
		var at := t + int(rng.randf_range(float(link.h[0]), float(link.h[1])) * 3600.0)
		var to := str(link.f)
		var entry := {"at": at, "id": to, "cause": title, "picks": picks.duplicate(), "depth": depth + 1}
		# A follow-up announcement is on the calendar; anything else comes unannounced.
		if str(MarketEvents.EVENTS.get(to, {}).get("kind", "")) == "announce":
			entry["linked"] = true
			calendar.append(entry)
		else: chain.append(entry)

## The odds multiplier on drawing `id` now: everything in force, stacked, capped.
func boost_of(id: String) -> float:
	var x := 1.0
	for b in boosts.get(id, []):
		if int(b.until) > t: x *= float(b.x)
	return clampf(x, 1.0 / BOOST_CAP, BOOST_CAP)

func _weight(id: String) -> float:
	return boost_of(id) * lean(id) * (float(weight_hook.call(id)) if weight_hook.is_valid() else 1.0)

func _jump(market: String, fraction: float) -> void:
	var b: Book = books.get(market)
	if b != null:
		var x := log(maxf(0.05, 1.0 + fraction))
		b.pj += x
		b.sh += x

func _verify(e: Dictionary) -> void:
	var r: Dictionary = e.rumor
	r["verified"] = true
	_follow(str(e.id), str(e.title), e.get("picks", {}), "true" if r.truth else "false")
	# A confirmed rumor pushes the world state as hard again; a denied one takes it back.
	_push(str(e.id), float(MarketLinks.PUSH.rumor) * (1.0 if r.truth else -1.0))
	var headline := {}
	for n in news:
		if n.id == e.id and n.status == "待证实": headline = n
	if r.truth:
		e.scale = 1.0
		for item in e.items:
			if item.has("jump"):
				for m in item.markets: _jump(m, float(item.jump) * (1.0 - RUMOR_FIRST))
		if not headline.is_empty(): headline.status = "已证实"
	else:
		for item in e.items:
			if item.has("jump"):
				for m in item.markets: _jump(m, -float(item.jump) * RUMOR_FIRST)
			if item.has("mult"): item["mult"] = float(r.false_mult)
		e.scale = 1.0
		if float(r.false_mult) == 1.0: e.until = t
		if not headline.is_empty(): headline.status = "已辟谣"
	for item in e.items:
		for m in item.markets:
			var b: Book = books.get(m)
			if b != null: b.lock = t + LOCK_TICKS * TICK
	_mods_dirty = true
	if on_news.is_valid() and not headline.is_empty():
		on_news.call({"t": t, "id": e.id, "kind": "verify", "title": "%s（%s）" % [e.title, headline.status], "region": "", "cred": "", "status": headline.status, "unread": true}, {})

# --- News generation ---------------------------------------------------------------------

func _events(dt: int) -> void:
	_expire_effects()
	for e in effects:
		if e.has("rumor") and not e.rumor.get("verified", false) and int(e.rumor.verify_at) <= t: _verify(e)
	if rng.randf() < dt * BREAKING_PER_DAY / DAY: fire(MarketEvents.pick("breaking", rng, _weight))
	if rng.randf() < dt * RUMOR_PER_DAY / DAY: fire(MarketEvents.pick("rumor", rng, _weight))
	# Follow-ups come when their time comes.
	if not chain.is_empty():
		for entry in chain.duplicate():
			if int(entry.at) <= t:
				chain.erase(entry)
				fire(str(entry.id), entry.get("picks", {}), str(entry.get("cause", "")), int(entry.get("depth", 0)))
	# Surprises only: the usual flow of news is taken off, then everything fades.
	var drift := MarketLinks.drift(BREAKING_PER_DAY, RUMOR_PER_DAY)
	var fade := pow(0.5, dt / (MarketLinks.FACTOR_HALF_HOURS * 3600.0))
	for f in drift:
		factors[f] = clampf((float(factors.get(f, 0.0)) - float(drift[f]) * dt) * fade, MarketLinks.FACTOR_RANGE.x, MarketLinks.FACTOR_RANGE.y)
	if t % 3600 < dt:
		for id in boosts.keys():
			boosts[id] = boosts[id].filter(func(b): return int(b.until) > t)
			if boosts[id].is_empty(): boosts.erase(id)
	_calendar_step()
	_swan_step()
	_flash_step(dt)

## Weights hooked to the player's behaviour (事件表 §10), set by Exchange.
var weight_hook := Callable()

func _calendar_step() -> void:
	# Seasonal events on the real calendar, a week ahead.
	if t - seasonal_scanned > 3600:
		var from := maxi(seasonal_scanned, t)
		for entry in MarketEvents.seasonal_between(local(from), local(t + 8 * DAY)):
			var at: int = int(entry[0]) - tz()
			if not calendar.any(func(c): return c.id == entry[1] and absi(int(c.at) - at) < 3600):
				calendar.append({"at": at, "id": entry[1], "seasonal": true})
		seasonal_scanned = t + 8 * DAY - 3600
	var random_count := calendar.filter(func(c): return not c.get("seasonal", false) and not c.get("linked", false)).size()
	while random_count < RANDOM_ANNOUNCES:
		var id := MarketEvents.pick("announce", rng)
		if id.is_empty(): break
		calendar.append({"at": t + rng.randi_range(6 * 3600, 48 * 3600), "id": id, "seasonal": false})
		random_count += 1
	calendar.sort_custom(func(a, b): return int(a.at) < int(b.at))
	while not calendar.is_empty() and int(calendar[0].at) <= t:
		var entry: Dictionary = calendar.pop_front()
		fire(str(entry.id), entry.get("picks", {}), str(entry.get("cause", "")), int(entry.get("depth", 0)))

func _schedule_swan() -> void:
	var wait := -log(maxf(1e-9, rng.randf())) * SWAN_MEAN
	var at := t + int(wait)
	var id := MarketEvents.pick("swan", rng)
	swan = {"at": at, "id": id, "precursor_at": (at - rng.randi_range(0, DAY)) if rng.randf() < 0.5 else -1, "precursor_done": false}

func _swan_step() -> void:
	if swan.is_empty(): _schedule_swan()
	if int(swan.precursor_at) > 0 and not swan.precursor_done and int(swan.precursor_at) <= t:
		swan.precursor_done = true
		var headline := {"t": t, "id": "omen", "kind": "rumor", "title": "传闻：%s方面有异动" % str(MarketEvents.EVENTS[swan.id].region), "region": MarketEvents.EVENTS[swan.id].region, "cred": "低", "status": "", "unread": true}
		news.append(headline)
		if on_news.is_valid(): on_news.call(headline, {})
	if int(swan.at) <= t:
		var id := str(swan.id)
		# Without an omen the odds of the moment decide which swan it is.
		if int(swan.precursor_at) == -1:
			var drawn := MarketEvents.pick("swan", rng, _weight)
			if not drawn.is_empty(): id = drawn
		_schedule_swan()
		fire(id)

func _flash_step(dt: int) -> void:
	flash = flash.filter(func(f): return int(f.until) > t and int(f.left) > 0)
	if rng.randf() >= dt * FLASH_PER_DAY / DAY: return
	var factions := FactionCatalog.trading()
	var faction: String = factions[rng.randi() % factions.size()]
	if not active(faction) and rng.randf() < 0.5: return
	var info: Dictionary = FactionCatalog.info(faction)
	var offer := {"id": _next_flash_id, "faction": faction, "until": t + rng.randi_range(60, 120)}
	_next_flash_id += 1
	var shelf := FactionSpecials.plain_shelf(faction)
	if rng.randf() < 0.6 or shelf.is_empty():
		var cats: Array = (info.prefs as Dictionary).keys()
		offer["kind"] = "buy"
		offer["category"] = cats[rng.randi() % cats.size()]
		offer["mult"] = rng.randf_range(1.3, 1.6)
		offer["left"] = 20000
	else:
		offer["kind"] = "sell"
		offer["material"] = shelf[rng.randi() % shelf.size()]
		offer["mult"] = rng.randf_range(0.6, 0.75)
		offer["left"] = rng.randi_range(5, 20)
	flash.append(offer)
	var what: String = FactionCatalog.CATEGORIES.get(offer.get("category", ""), str(offer.get("material", "")))
	var title := "%s限时%s%s" % [FactionCatalog.name_of(faction), "高价收购" if offer.kind == "buy" else "低价抛售", what]
	var headline := {"t": t, "id": "flash", "kind": "flash", "title": title, "region": info.region, "cred": "", "status": "", "unread": true, "flash": offer.id}
	news.append(headline)
	if news.size() > NEWS_KEEP: news = news.slice(news.size() - NEWS_KEEP)
	if on_news.is_valid(): on_news.call(headline, {})

func unread() -> int:
	return news.filter(func(n): return n.unread).size()

func mark_read() -> void:
	for n in news: n.unread = false

# --- Saving ------------------------------------------------------------------------------

func to_data() -> Dictionary:
	var b_data := {}
	for id in books: b_data[id] = books[id].to_data()
	return {"version": 1, "t": t, "seed": rng.seed, "state": rng.state, "books": b_data, "effects": effects, "news": news,
		"calendar": calendar, "flash": flash, "swan": swan, "rumors_low_until": rumors_low_until, "threat": threat,
		"post_boost": post_boost, "penguin": penguin, "cfd_halt": cfd_halt, "seasonal_scanned": seasonal_scanned,
		"barter_seed": barter_seed, "next_flash": _next_flash_id, "chain": chain, "boosts": boosts, "factors": factors}

func load_data(d: Dictionary) -> void:
	t = int(d.get("t", 0))
	rng.seed = int(d.get("seed", rng.seed))
	rng.state = int(d.get("state", rng.state))
	books.clear()
	var saved: Dictionary = d.get("books", {})
	for id in FactionCatalog.markets():
		var b := Book.new()
		b.setup(id)
		if saved.has(id): b.load(saved[id])
		else:
			b.w0 = t
			_new_regime(b)
		books[id] = b
	effects = d.get("effects", [])
	news = d.get("news", [])
	calendar = d.get("calendar", [])
	flash = d.get("flash", [])
	swan = d.get("swan", {})
	rumors_low_until = int(d.get("rumors_low_until", 0))
	threat = d.get("threat", {})
	post_boost = d.get("post_boost", {})
	penguin = d.get("penguin", {"fee": 1.0, "risk": 0.0, "until": 0})
	cfd_halt = d.get("cfd_halt", {})
	seasonal_scanned = int(d.get("seasonal_scanned", 0))
	barter_seed = int(d.get("barter_seed", 1))
	_next_flash_id = int(d.get("next_flash", 1))
	chain = d.get("chain", [])
	boosts = d.get("boosts", {})
	factors = d.get("factors", {})
	_mods_dirty = true
	Economy.fx = fx_rate()

func save_file(path: String) -> void:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return
	file.store_var(to_data(), false)
	file.close()
	DirAccess.rename_absolute(path + ".tmp", path)

func load_file(path: String) -> bool:
	if not FileAccess.file_exists(path): return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return false
	var data: Variant = file.get_var(false)
	file.close()
	if not data is Dictionary or int(data.get("version", 0)) != 1: return false
	load_data(data)
	return true
