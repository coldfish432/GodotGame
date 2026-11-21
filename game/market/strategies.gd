class_name Strategies
extends RefCounted

## §4: the automated strategies. Each runs on its own capital (龙门币 taken
## from the balance), decides every 15 minutes of the Rhodes clock with its
## template, and trades at the live price with the usual costs; its orders
## move the books like anyone's (§3.4). Shorts are contracts for difference
## (positions below zero). It stops at its drawdown line or its end, and pays
## 0.05% of what it holds a day. Backtests replay the kept candles without
## moving anything, 10 a day.

const ROUND := 900
const KEEP_EQUITY := 240

var ex: Exchange
var list: Array = []
var backtests_day := -1
var backtests_used := 0
var _next_id := 1
var _round := -1

func _init(p_ex: Exchange = null) -> void:
	ex = p_ex

func m() -> MarketState: return ex.market

# --- Slots and unlocks (§4.1) ------------------------------------------------------------

func slots() -> int:
	var lv := ex.game.base.facility_level("exchange")
	var n := 0
	if lv >= 4: n = StrategyCatalog.SLOTS_LV4
	elif lv >= 3: n = StrategyCatalog.SLOTS_LV3
	if ex.game.base.researched("quant_trading"): n += 1
	return mini(n, StrategyCatalog.MAX_SLOTS)

func unlocked(tpl: String) -> bool:
	var lv := ex.game.base.facility_level("exchange")
	match str(StrategyCatalog.info(tpl).get("unlock", "lv4")):
		"start": return true
		"lv3": return lv >= 3
		_: return lv >= 4 or ex.game.base.researched("quant_trading")

func create_refusal(tpl: String, capital: float) -> String:
	if not StrategyCatalog.TEMPLATES.has(tpl): return "无效"
	if not unlocked(tpl): return "未解锁"
	if list.size() >= slots(): return "槽位已满"
	if capital < 10000.0: return "资金不足 10,000"
	if ex.game.gold < capital: return "龙门币不足"
	if ex.fin.facility_stopped("strategies"): return "欠费暂停"
	return ""

## The markets a template may trade, for the pool picker.
func universe(tpl: String) -> Array:
	var out: Array = []
	match str(StrategyCatalog.info(tpl).get("universe", "any")):
		"stocks", "pair":
			for id in FirmCatalog.ORDER: out.append("stock:" + id)
		"fx":
			for c in Currencies.foreign(): out.append(Currencies.book(c))
		_:
			for id in m().books:
				if not Currencies.is_fx(str(id)): out.append(str(id))
			for id in FirmCatalog.ORDER: out.append("stock:" + id)
			for c in Currencies.foreign(): out.append(Currencies.book(c))
	return out

func default_pool(tpl: String) -> Array:
	var u := universe(tpl)
	match str(StrategyCatalog.info(tpl).get("universe", "any")):
		"stocks", "fx": return u
		"pair": return ["stock:swire", "stock:penguin"]
		"one": return [u[0]] if not u.is_empty() else []
	return u.slice(0, mini(3, u.size()))

func create(tpl: String, capital: float, pool: Array = [], params: Dictionary = {}, stop_dd := 0.2, end_days := 0) -> bool:
	if ex.blocked() or not create_refusal(tpl, capital).is_empty(): return false
	ex.game.gold -= ceili(capital)
	var p := StrategyCatalog.defaults(tpl)
	for k in params: p[k] = params[k]
	var st := {"id": _next_id, "tpl": tpl, "capital": capital, "cash": capital, "pos": {}, "params": p, "pool": pool if not pool.is_empty() else default_pool(tpl),
		"stop_dd": stop_dd, "end_day": (MarketState.day_key(m().t) + end_days) if end_days > 0 else -1, "equity": [], "bench": [], "bench_start": {},
		"peak": capital, "trades": 0, "wins": 0, "running": true, "state": {}, "start_t": m().t, "marks": []}
	for mk in st.pool: st.bench_start[mk] = price(str(mk))
	_next_id += 1
	list.append(st)
	return true

func get_strategy(id: int) -> Dictionary:
	for st in list:
		if int(st.id) == id: return st
	return {}

## Stops and closes it; the money comes back to the balance.
func stop(id: int, reason := "手动") -> bool:
	var st := get_strategy(id)
	if st.is_empty(): return false
	_close_all(st)
	ex.credit("lmd", maxf(0.0, float(st.cash)))
	list.erase(st)
	ex._say("策略 %s 已停止（%s）" % [StrategyCatalog.name_of(str(st.tpl)), reason], "strategy")
	return true

func liquidate_all(reason: String) -> void:
	for st in list.duplicate(): stop(int(st.id), reason)

func value_lmd() -> float:
	var v := 0.0
	for st in list: v += equity(st)
	return v

# --- Prices ------------------------------------------------------------------------------

## The index of any market a strategy trades ("stock:<firm>" for shares).
func price(market: String) -> float:
	if market.begins_with("stock:"):
		var b: MarketState.Book = m().stocks.get(market.substr(6))
		return b.i if b != null else 1.0
	return m().index(market)

## 龙门币 a unit of index (base price): a share's base, else 1.
func unit_lmd(market: String) -> float:
	if market.begins_with("stock:"): return m().firms.base_lmd(market.substr(6))
	return 1.0

func candles(market: String, period: String, limit := 200) -> Array:
	return m().candles(market, period, limit)

func equity(st: Dictionary) -> float:
	var v := float(st.cash)
	for mk in st.pos: v += float(st.pos[mk].qty) * price(str(mk)) * unit_lmd(str(mk))
	return v

# --- Trading -----------------------------------------------------------------------------

## Moves a position to `target_lmd` (signed value at today's price).
func _trade_to(st: Dictionary, market: String, target_lmd: float) -> void:
	var p := price(market) * unit_lmd(market)
	if p <= 0.0: return
	var pos: Dictionary = st.pos.get(market, {"qty": 0.0, "entry": p, "adds": 0})
	var now_lmd := float(pos.qty) * p
	var delta := target_lmd - now_lmd
	if absf(delta) < StrategyCatalog.MIN_TRADE: return
	var spread := m().spread(market) * 0.5 if not market.begins_with("stock:") else 0.002
	var cost := absf(delta) * (StrategyCatalog.FEE + spread)
	st.cash = float(st.cash) - delta - cost
	var closing := signf(delta) != signf(float(pos.qty)) and absf(float(pos.qty)) > 0.0
	if closing:
		var realised := (p - float(pos.entry)) * minf(absf(delta) / p, absf(float(pos.qty))) * signf(float(pos.qty))
		if realised > 0.0: st.wins = int(st.wins) + 1
	elif absf(float(pos.qty)) < 1e-9: pos.entry = p
	else: pos.entry = (float(pos.entry) * absf(float(pos.qty)) + p * absf(delta / p)) / (absf(float(pos.qty)) + absf(delta / p))
	pos.qty = float(pos.qty) + delta / p
	st.trades = int(st.trades) + 1
	if absf(float(pos.qty)) * p < 1.0: st.pos.erase(market)
	else: st.pos[market] = pos
	# The order moves the book (base-price 龙门币 of flow).
	var flow := delta / maxf(price(market), 0.01) / unit_lmd(market) * unit_lmd(market)
	if market.begins_with("stock:"): m().actors.place(m(), market.substr(6), flow, "rhodes_strategy", true)
	else: m().actors.place(m(), market, flow, "rhodes_strategy")
	st.marks.append([m().t, market, delta])
	if st.marks.size() > 60: st.marks = st.marks.slice(st.marks.size() - 60)

func _close_all(st: Dictionary) -> void:
	for mk in st.pos.keys(): _trade_to(st, str(mk), 0.0)

## Weights (−1…1 of equity) into positions; the gross capped at 2× equity.
func _apply(st: Dictionary, weights: Dictionary) -> void:
	var eq := maxf(equity(st), 0.0)
	var gross := 0.0
	for k in weights: gross += absf(float(weights[k]))
	var scale := minf(1.0, StrategyCatalog.MAX_GROSS / gross) if gross > 0.0 else 1.0
	for mk in st.pos.keys():
		if not weights.has(mk): _trade_to(st, str(mk), 0.0)
	for mk in weights: _trade_to(st, str(mk), float(weights[mk]) * scale * eq)

# --- The round ---------------------------------------------------------------------------

func step() -> void:
	if list.is_empty(): return
	var r := int(m().t / ROUND)
	if r == _round: return
	_round = r
	if ex.fin.facility_stopped("strategies"): return
	for st in list.duplicate():
		if not bool(st.running): continue
		var w: Variant = decide(st, live_ctx())
		if w is Dictionary: _apply(st, w)
		var eq := equity(st)
		st.peak = maxf(float(st.peak), eq)
		if eq < float(st.peak) * (1.0 - float(st.stop_dd)): stop(int(st.id), "止损")
		elif int(st.end_day) >= 0 and MarketState.day_key(m().t) >= int(st.end_day): stop(int(st.id), "到期")

## Once a day: custody, carry on held currencies, the curves.
func new_day() -> void:
	for st in list:
		var eq := equity(st)
		# A trading day is ÷ scale of the design's day (时间缩放策划案 v0.2 §6.3).
		var share := BaseState.day_share()
		st.cash = float(st.cash) - maxf(eq, 0.0) * StrategyCatalog.CUSTODY * share
		for mk in st.pos:
			var cur := Currencies.of_book(str(mk))
			if cur.is_empty(): continue
			# Short the book = holding the currency: it earns that currency's rate.
			var lmd := float(st.pos[mk].qty) * price(str(mk))
			st.cash = float(st.cash) - lmd * (m().policy_rate(cur) - m().policy_rate("lmd")) / 365.0 * share
		st.equity.append(roundi(equity(st)))
		var bench := 0.0
		for mk in st.bench_start: bench += price(str(mk)) / maxf(float(st.bench_start[mk]), 1e-6)
		st.bench.append(float(st.capital) * bench / maxf(1.0, st.bench_start.size()))
		if st.equity.size() > KEEP_EQUITY:
			st.equity = st.equity.slice(st.equity.size() - KEEP_EQUITY)
			st.bench = st.bench.slice(st.bench.size() - KEEP_EQUITY)

## {candles(market, period) -> Array, price(market) -> float, ratios(firm) -> Dictionary, t}.
func live_ctx() -> Dictionary:
	return {"candles": func(mk, period): return candles(str(mk), str(period)), "price": func(mk): return price(str(mk)) * unit_lmd(str(mk)), "equity": func(x): return equity(x),
		"ratios": func(firm): return m().firms.ratios(str(firm), m().firms.share_price_lmd(str(firm), m())), "t": m().t,
		"rate": func(cur): return m().policy_rate(str(cur))}

# --- The templates (§4.2) ----------------------------------------------------------------

## Target weights by market, or null to leave things as they are.
func decide(st: Dictionary, ctx: Dictionary) -> Variant:
	var p: Dictionary = st.params
	var pool: Array = st.pool
	var s: Dictionary = st.state
	match str(st.tpl):
		"S1":
			var hold: Array = []
			for mk in pool:
				var r: Dictionary = ctx.ratios.call(str(mk).substr(6))
				var held: bool = st.pos.has(mk)
				var buy := float(r.peg) <= float(p.peg_buy) and float(r.net_cash) > 0.0
				var sell := float(r.peg) > float(p.peg_sell) or str(r.class_id) == "cycle"
				if buy or (held and not sell): hold.append(mk)
			return _equal(hold, 1.0)
		"S2":
			var pts: Array = []
			for mk in pool:
				var r: Dictionary = ctx.ratios.call(str(mk).substr(6))
				var value := clampf(1.0 / maxf(float(r.pe), 1.0), 0.0, 0.5) * 4.0 + clampf(float(r.fcf_yield), -0.2, 0.3)
				var quality := float(r.moat_count) / 12.0 + clampf(float(r.growth), -0.5, 0.5)
				pts.append([value, quality])
			if pts.size() < 2: return {}
			var labels := Indicators.kmeans(pts, mini(int(p.k), pts.size()))
			var score := {}
			var count := {}
			for i in range(pts.size()):
				var c := int(labels[i])
				score[c] = float(score.get(c, 0.0)) + float(pts[i][0]) + float(pts[i][1])
				count[c] = int(count.get(c, 0)) + 1
			var best := -1
			var worst := -1
			for c in score:
				var avg := float(score[c]) / int(count[c])
				if best < 0 or avg > float(score[best]) / int(count[best]): best = int(c)
				if worst < 0 or avg < float(score[worst]) / int(count[worst]): worst = int(c)
			var w := {}
			var longs: Array = []
			var shorts: Array = []
			for i in range(pts.size()):
				if int(labels[i]) == best: longs.append(pool[i])
				elif int(labels[i]) == worst and worst != best: shorts.append(pool[i])
			for mk in longs: w[mk] = 0.5 / longs.size()
			for mk in shorts: w[mk] = -0.5 / shorts.size()
			return w
		"S3":
			var hold: Array = []
			for mk in pool:
				var r: Dictionary = ctx.ratios.call(str(mk).substr(6))
				var n := int(r.moat_count)
				if n >= int(p.n) or (st.pos.has(mk) and n >= int(p.n) - 3): hold.append(mk)
			return _equal(hold, 1.0)
		"S4":
			if pool.size() < 2: return {}
			var a := Indicators.closes(ctx.candles.call(pool[0], "1h"))
			var b := Indicators.closes(ctx.candles.call(pool[1], "1h"))
			var n := mini(int(p.window), mini(a.size(), b.size()))
			if n < 30: return null
			var test := Indicators.cointegration(a.slice(a.size() - n), b.slice(b.size() - n))
			var bad := int(s.get("bad", 0))
			if not bool(test[0]):
				s.bad = bad + 1
				return {} if int(s.bad) >= 3 * 24 or st.pos.is_empty() else null
			s.bad = 0
			var beta := float(test[1])
			var z := (log(a[-1]) - beta * log(b[-1]) - _spread_mean(a.slice(a.size() - n), b.slice(b.size() - n), beta)) / maxf(float(test[4]), 1e-6)
			var side := int(s.get("side", 0))
			if side == 0 and absf(z) > float(p.c): side = -1 if z > 0.0 else 1
			elif side != 0 and absf(z) < 0.1: side = 0
			s.side = side
			if side == 0: return {}
			var wa := 0.5 / (1.0 + absf(beta))
			return {pool[0]: side * wa, pool[1]: -side * wa * absf(beta)}
		"S5":
			var w := {}
			for mk in pool:
				var c: Array = ctx.candles.call(mk, "1h")
				if c.size() < 60: continue
				var x := Indicators.closes(c)
				var close := x[-1]
				var hi := Indicators.highest(c, int(p.n))
				var lo := Indicators.lowest(c, int(p.n))
				var ma50 := Indicators.sma(x, 50)
				var ma200 := Indicators.sma(x, mini(200, x.size()))
				var adds := int((s.get("adds", {}) as Dictionary).get(mk, 0))
				var held: bool = st.pos.has(mk)
				if close > hi and close > ma50 and close > ma200:
					adds = mini(adds + 1, 1 + int(p.adds)) if held else 1
				elif held and close < lo: adds = 0
				elif not held: adds = 0
				if not s.has("adds"): s.adds = {}
				s.adds[mk] = adds
				if adds > 0: w[mk] = float(adds) / (1.0 + int(p.adds)) / pool.size()
			return w
		"S6":
			var w := {}
			for mk in pool:
				var d := Indicators.closes(ctx.candles.call(mk, "1d"))
				var h := Indicators.closes(ctx.candles.call(mk, "1h"))
				var q := Indicators.closes(ctx.candles.call(mk, "15m"))
				if d.size() < 5 or h.size() < 35 or q.size() < 20: continue
				var dir := 1 if Indicators.ema(d, mini(15, d.size())) >= Indicators.ema(d, mini(200, d.size())) else -1
				var mac := Indicators.macd(h)
				var rsi := Indicators.rsi(q)
				var held := float((st.pos.get(mk, {}) as Dictionary).get("qty", 0.0))
				if dir > 0 and float(mac[2]) > 0.0 and rsi < float(p.rsi_low): w[mk] = 1.0 / pool.size()
				elif dir < 0 and float(mac[2]) < 0.0 and rsi > float(p.rsi_high): w[mk] = -1.0 / pool.size()
				elif held != 0.0 and signf(held) == dir: w[mk] = signf(held) / pool.size()
			return w
		"S7":
			var w := {}
			for mk in pool:
				var c: Array = ctx.candles.call(mk, "1h")
				var n := int(p.range)
				if c.size() < n + 2: continue
				var lo := Indicators.lowest(c, n, c.size() - 1)
				var hi := Indicators.highest(c, n, c.size() - 1)
				var last: Array = c[-1]
				var vol := Indicators.mean_volume(c, n)
				var held: bool = st.pos.has(mk)
				var stops: Dictionary = s.get("stops", {})
				if not held and float(last[2]) < lo and float(last[3]) > lo and float(last[4]) > vol * float(p.vol):
					w[mk] = 0.5 / pool.size()
					stops[mk] = float(last[2])
				elif held:
					var size := 0.5
					if float(last[3]) > hi and float(last[4]) > vol * float(p.vol): size = 1.0
					if float(last[3]) < float(stops.get(mk, 0.0)) or float(last[3]) < (lo + hi) * 0.5: size = 0.0
					if size > 0.0: w[mk] = size / pool.size()
				s.stops = stops
			return w
		"S8":
			if pool.is_empty(): return null
			var last := int(s.get("last", 0))
			if int(ctx.t) - last < int(p.hours) * 3600: return null
			s.last = int(ctx.t)
			var mk := str(pool[0])
			var eq := float(ctx.equity.call(st))
			var now_lmd := float((st.pos.get(mk, {}) as Dictionary).get("qty", 0.0)) * float(ctx.price.call(mk))
			var add := minf(float(p.amount), float(st.cash))
			if add < StrategyCatalog.MIN_TRADE or eq <= 0.0: return null
			return {mk: (now_lmd + add) / eq}
		"S9":
			if pool.is_empty(): return null
			var mk := str(pool[0])
			var px := float(ctx.price.call(mk)) / maxf(unit_lmd(mk), 1e-9)
			var lo := float(p.low)
			var hi := float(p.high)
			var step := (hi - lo) / maxf(1.0, int(p.levels))
			var level := clampf(roundf((hi - px) / maxf(step, 1e-6)) * step / maxf(hi - lo, 1e-6), 0.0, 1.0)
			return {mk: level}
		"S10":
			var best := ""
			var rate := -INF
			for mk in pool:
				var cur := Currencies.of_book(str(mk))
				var r := float(ctx.rate.call(cur))
				if r > rate:
					rate = r
					best = str(mk)
			if best.is_empty(): return {}
			var entry := float(s.get("entry", 0.0))
			var held := str(s.get("held", ""))
			if held != best:
				s.held = best
				s.entry = float(ctx.price.call(best))
				entry = float(s.entry)
			# Short the book is long the currency: a rise of the book is the loss.
			if float(ctx.price.call(best)) > entry * (1.0 + float(p.stop)):
				s.held = ""
				return {}
			return {best: -1.0}
	return null

static func _spread_mean(a: PackedFloat64Array, b: PackedFloat64Array, beta: float) -> float:
	var n := mini(a.size(), b.size())
	var t := 0.0
	for k in range(n): t += log(maxf(a[k], 1e-9)) - beta * log(maxf(b[k], 1e-9))
	return t / maxf(1.0, n)

static func _equal(markets: Array, total: float) -> Dictionary:
	var w := {}
	for mk in markets: w[mk] = total / markets.size()
	return w

# --- Backtests (§4.3) -------------------------------------------------------------------

func backtest_refusal() -> String:
	if MarketState.day_key(m().t) != backtests_day: return ""
	return "今日回测次数已用完" if backtests_used >= StrategyCatalog.BACKTESTS_A_DAY else ""

## Replays the template over the kept candles of its period without moving
## any book: {equity: [..], bench: [..], ret, dd, trades, wins}.
func backtest(tpl: String, capital: float, pool: Array = [], params: Dictionary = {}) -> Dictionary:
	if not backtest_refusal().is_empty(): return {}
	var day := MarketState.day_key(m().t)
	if day != backtests_day:
		backtests_day = day
		backtests_used = 0
	backtests_used += 1
	var period := str(StrategyCatalog.info(tpl).get("period", "1h"))
	var p := StrategyCatalog.defaults(tpl)
	for k in params: p[k] = params[k]
	if pool.is_empty(): pool = default_pool(tpl)
	var hist := {}
	var n := 999999
	for mk in pool:
		hist[mk] = candles(str(mk), period, 400)
		n = mini(n, (hist[mk] as Array).size())
	var st := {"id": 0, "tpl": tpl, "capital": capital, "cash": capital, "pos": {}, "params": p, "pool": pool, "state": {}, "trades": 0, "wins": 0, "marks": []}
	var eq: Array = []
	var bench: Array = []
	var peak := capital
	var dd := 0.0
	var start := mini(60, maxi(0, n - 2))
	var cursor := {"k": start}
	var bt_price := func(mk): return float((hist[mk] as Array)[(hist[mk] as Array).size() - n + int(cursor.k)][3]) / MarketState.display_scale_any(str(mk), m()) * unit_lmd(str(mk))
	var ctx := {"candles": func(mk, _period): return (hist[mk] as Array).slice(0, (hist[mk] as Array).size() - n + int(cursor.k) + 1),
		"price": bt_price, "equity": func(x): return _bt_equity(x, bt_price), "ratios": func(firm): return m().firms.ratios(str(firm), m().firms.share_price_lmd(str(firm), m())), "t": 0,
		"rate": func(cur): return m().policy_rate(str(cur))}
	for k in range(start, n):
		cursor.k = k
		ctx.t = k * 3600
		var w: Variant = decide(st, ctx)
		if w is Dictionary:
			var e := _bt_equity(st, bt_price)
			for mk in st.pos.keys():
				if not (w as Dictionary).has(mk): _bt_trade(st, str(mk), 0.0, bt_price)
			for mk in w: _bt_trade(st, str(mk), float(w[mk]) * e, bt_price)
		var e2 := _bt_equity(st, bt_price)
		peak = maxf(peak, e2)
		dd = maxf(dd, 1.0 - e2 / maxf(peak, 1.0))
		eq.append(e2)
		var b := 0.0
		for mk in pool: b += float((hist[mk] as Array)[(hist[mk] as Array).size() - n + k][3]) / maxf(float((hist[mk] as Array)[(hist[mk] as Array).size() - n + start][3]), 1e-9)
		bench.append(capital * b / maxf(1.0, pool.size()))
	var ret := (float(eq[-1]) / capital - 1.0) if not eq.is_empty() else 0.0
	return {"equity": eq, "bench": bench, "ret": ret, "dd": dd, "trades": int(st.trades), "wins": int(st.wins)}

func _bt_equity(st: Dictionary, px: Callable) -> float:
	var v := float(st.cash)
	for mk in st.pos: v += float(st.pos[mk].qty) * float(px.call(mk))
	return v

func _bt_trade(st: Dictionary, market: String, target: float, px: Callable) -> void:
	var p := float(px.call(market))
	if p <= 0.0: return
	var pos: Dictionary = st.pos.get(market, {"qty": 0.0, "entry": p, "adds": 0})
	var delta := target - float(pos.qty) * p
	if absf(delta) < StrategyCatalog.MIN_TRADE: return
	st.cash = float(st.cash) - delta - absf(delta) * StrategyCatalog.FEE
	if signf(delta) != signf(float(pos.qty)) and absf(float(pos.qty)) > 0.0 and (p - float(pos.entry)) * signf(float(pos.qty)) > 0.0: st.wins = int(st.wins) + 1
	if absf(float(pos.qty)) < 1e-9: pos.entry = p
	pos.qty = float(pos.qty) + delta / p
	st.trades = int(st.trades) + 1
	if absf(float(pos.qty)) * p < 1.0: st.pos.erase(market)
	else: st.pos[market] = pos

# --- Saving ------------------------------------------------------------------------------

func to_data() -> Dictionary:
	return {"list": list.duplicate(true), "backtests_day": backtests_day, "backtests_used": backtests_used, "next_id": _next_id}

func load_data(d: Dictionary) -> void:
	list = (d.get("list", []) as Array).duplicate(true) if d.get("list") is Array else []
	backtests_day = int(d.get("backtests_day", -1))
	backtests_used = int(d.get("backtests_used", 0))
	_next_id = maxi(1, int(d.get("next_id", 1)))
