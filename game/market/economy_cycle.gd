class_name EconomyCycle
extends RefCounted

## §3.6: the 景气指数 E, every 15 minutes of the Rhodes clock. Five parts
## (firms, goods, credit, factions, mood) plus a slow wave of 20–40 trading
## days and a little noise. It lifts deposits, funds, firms' demand, the
## crowd's appetite and the policy rates by at most ±30% (轻微扰动).

const STEP := 900
const WEIGHTS := {"firms": 0.25, "goods": 0.2, "credit": 0.2, "factions": 0.15, "mood": 0.2}
const WAVE_DAYS := Vector2(20.0, 40.0)
const WAVE_AMP := 0.25
const NOISE := 0.04
const SWING := 0.3
const POLICY_BIAS := 0.005
const KEEP := 30
const PHASES := ["扩张", "过热", "收缩", "低迷"]

var e := 0.0
var parts := {"firms": 0.0, "goods": 0.0, "credit": 0.0, "factions": 0.0, "mood": 0.0}
var wave_start := 0
var wave_len := 30.0 * 86400.0
var history: Array = []        # [day, E]
var goods_days: Array = []     # the goods composite at each day's close, 30 days
var faction_net := 0.0         # 龙门币 the factions bought less sold since the last step
var _last := 0
var _prev_e := 0.0

func start(t: int, rng: RandomNumberGenerator) -> void:
	wave_start = t
	wave_len = _wave_len(rng)
	_last = t

## 20–40 real days (时间缩放策划案 v0.2 §4.1): × scale on the Rhodes clock.
static func _wave_len(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(WAVE_DAYS.x, WAVE_DAYS.y) * 86400.0 * BaseState.time_scale

## A one-to-one save: the wave keeps its phase and its real length.
func rescale_wave(t: int, scale: int) -> void:
	var done := clampf(float(t - wave_start) / maxf(wave_len, 1.0), 0.0, 1.0)
	wave_len *= scale
	wave_start = t - int(done * wave_len)

## The wave: a sine over this round, a new length each time it ends.
func wave(t: int, rng: RandomNumberGenerator) -> float:
	if float(t - wave_start) >= wave_len:
		wave_start = t
		wave_len = _wave_len(rng)
	return WAVE_AMP * sin(TAU * float(t - wave_start) / wave_len)

func step(m: MarketState) -> void:
	if m.t - _last < STEP: return
	_last = m.t
	parts.firms = clampf(m.firms.profit_growth() * 4.0, -1.0, 1.0) if m.firms != null else 0.0
	var comp := _goods_composite(m)
	var mean := comp
	if not goods_days.is_empty():
		mean = 0.0
		for v in goods_days: mean += float(v)
		mean /= goods_days.size()
	parts.goods = clampf((comp / maxf(mean, 0.01) - 1.0) * 8.0, -1.0, 1.0)
	parts.credit = clampf((1.0 - m.credit.tightness()) * 1.5, -1.0, 1.0) if m.credit != null else 0.0
	parts.factions = clampf(faction_net / 2000000.0, -1.0, 1.0)
	faction_net *= 0.5
	parts.mood = clampf(-m.factor("panic") * 0.5 + _fx_mood(m), -1.0, 1.0)
	var raw := 0.0
	for k in WEIGHTS: raw += float(WEIGHTS[k]) * float(parts[k])
	_prev_e = e
	# Slow: E moves a tenth of the way each step, so it reinforces and corrects over days.
	var target := clampf(raw + wave(m.t, m.rng) + m.rng.randfn(0.0, NOISE), -1.0, 1.0)
	e = clampf(lerpf(e, target, 0.1), -1.0, 1.0)

func day_close(m: MarketState, day: int) -> void:
	goods_days.append(_goods_composite(m))
	if goods_days.size() > KEEP: goods_days = goods_days.slice(goods_days.size() - KEEP)
	history.append([day, snappedf(e, 0.001)])
	if history.size() > KEEP: history = history.slice(history.size() - KEEP)

static func _goods_composite(m: MarketState) -> float:
	var total := 0.0
	var n := 0
	for b: MarketState.Book in m.books.values():
		if b.fx: continue
		total += b.i
		n += 1
	return total / maxf(1.0, n)

static func _fx_mood(m: MarketState) -> float:
	# Calm money is good mood: the mean recent size of the rate books' moves.
	var total := 0.0
	var n := 0
	for b: MarketState.Book in m.books.values():
		if not b.fx: continue
		total += b.ew
		n += 1
	var ew := total / maxf(1.0, n)
	return clampf((0.0008 - ew) * 300.0, -0.5, 0.5)

## "扩张" rising above 0, "过热" falling above 0, "收缩" falling below, "低迷" rising below.
func phase() -> String:
	var rising := e >= _prev_e
	if e >= 0.0: return PHASES[0] if rising else PHASES[1]
	return PHASES[3] if rising else PHASES[2]

func deposit_mult() -> float: return 1.0 + SWING * e
## Funds: a better payout in good times, a lower fee in bad ones.
func fund_payout_mult() -> float: return 1.0 + SWING * maxf(e, 0.0)
func fund_fee_mult() -> float: return 1.0 + SWING * minf(e, 0.0)
func demand_mult() -> float: return 1.0 + SWING * e
func policy_bias() -> float: return POLICY_BIAS * e

func to_data() -> Dictionary:
	return {"e": e, "parts": parts.duplicate(), "wave_start": wave_start, "wave_len": wave_len, "history": history.duplicate(true), "goods_days": goods_days.duplicate(),
		"faction_net": faction_net, "last": _last, "prev": _prev_e}

func load_data(d: Dictionary) -> void:
	e = float(d.get("e", 0.0))
	var p: Variant = d.get("parts", {})
	if p is Dictionary:
		for k in parts: parts[k] = float(p.get(k, 0.0))
	wave_start = int(d.get("wave_start", wave_start))
	wave_len = float(d.get("wave_len", wave_len))
	history = (d.get("history", []) as Array).duplicate(true) if d.get("history") is Array else []
	goods_days = (d.get("goods_days", []) as Array).duplicate() if d.get("goods_days") is Array else []
	faction_net = float(d.get("faction_net", 0.0))
	_last = int(d.get("last", 0))
	_prev_e = float(d.get("prev", e))
