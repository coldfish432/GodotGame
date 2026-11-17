class_name Indicators
extends RefCounted

## 罗德岛运营与资产管理策划案 §4: the indicators the strategy templates use.
## Every function reads closes (or candles) up to and including the bar it is
## asked about, never after it (v0.2 §4.4: the homework's look-ahead fixed).

static func closes(candles: Array) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for c in candles: out.append(float(c[3]))
	return out

static func sma(x: PackedFloat64Array, n: int, at: int = -1) -> float:
	if at < 0: at = x.size() - 1
	if at + 1 < n or n <= 0: return NAN
	var s := 0.0
	for k in range(at - n + 1, at + 1): s += x[k]
	return s / n

## The whole EMA series (seeded with the first value).
static func ema_series(x: PackedFloat64Array, n: int) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	if x.is_empty(): return out
	var a := 2.0 / (n + 1.0)
	var v := x[0]
	for k in range(x.size()):
		v = x[k] if k == 0 else a * x[k] + (1.0 - a) * v
		out.append(v)
	return out

static func ema(x: PackedFloat64Array, n: int) -> float:
	var s := ema_series(x, n)
	return s[-1] if not s.is_empty() else NAN

## MACD (12, 26, 9): [macd, signal, histogram] at the last bar.
static func macd(x: PackedFloat64Array) -> Array:
	if x.size() < 35: return [NAN, NAN, NAN]
	var f := ema_series(x, 12)
	var s := ema_series(x, 26)
	var line := PackedFloat64Array()
	for k in range(x.size()): line.append(f[k] - s[k])
	var sig := ema_series(line, 9)
	return [line[-1], sig[-1], line[-1] - sig[-1]]

## RSI with Wilder's smoothing (the homework used a plain mean: fixed).
static func rsi(x: PackedFloat64Array, n: int = 14) -> float:
	if x.size() <= n: return NAN
	var gain := 0.0
	var loss := 0.0
	for k in range(1, n + 1):
		var d := x[k] - x[k - 1]
		if d > 0.0: gain += d
		else: loss -= d
	gain /= n
	loss /= n
	for k in range(n + 1, x.size()):
		var d := x[k] - x[k - 1]
		gain = (gain * (n - 1) + maxf(d, 0.0)) / n
		loss = (loss * (n - 1) + maxf(-d, 0.0)) / n
	if loss <= 1e-12: return 100.0
	return 100.0 - 100.0 / (1.0 + gain / loss)

## Highest high / lowest low of the `n` candles before `at` (the bar itself excluded).
static func highest(candles: Array, n: int, at: int = -1) -> float:
	if at < 0: at = candles.size() - 1
	var h := -INF
	for k in range(maxi(0, at - n), at): h = maxf(h, float(candles[k][1]))
	return h

static func lowest(candles: Array, n: int, at: int = -1) -> float:
	if at < 0: at = candles.size() - 1
	var l := INF
	for k in range(maxi(0, at - n), at): l = minf(l, float(candles[k][2]))
	return l

static func mean_volume(candles: Array, n: int, at: int = -1) -> float:
	if at < 0: at = candles.size() - 1
	var v := 0.0
	var c := 0
	for k in range(maxi(0, at - n), at):
		v += float(candles[k][4])
		c += 1
	return v / maxf(1.0, c)

## Ordinary least squares y = a + b·x: [a, b].
static func ols(x: PackedFloat64Array, y: PackedFloat64Array) -> Array:
	var n := mini(x.size(), y.size())
	if n < 3: return [0.0, 0.0]
	var mx := 0.0
	var my := 0.0
	for k in range(n):
		mx += x[k]
		my += y[k]
	mx /= n
	my /= n
	var sxy := 0.0
	var sxx := 0.0
	for k in range(n):
		sxy += (x[k] - mx) * (y[k] - my)
		sxx += (x[k] - mx) * (x[k] - mx)
	var b := sxy / sxx if sxx > 1e-12 else 0.0
	return [my - b * mx, b]

## Engle–Granger in two steps: the hedge ratio by OLS on log prices, then a
## Dickey–Fuller regression of the spread's change on its lag. Cointegrated
## when the t statistic is below −3.34 (5%, two variables). [ok, beta, t, mean, sd].
static func cointegration(a: PackedFloat64Array, b: PackedFloat64Array) -> Array:
	var n := mini(a.size(), b.size())
	if n < 30: return [false, 0.0, 0.0, 0.0, 0.0]
	var la := PackedFloat64Array()
	var lb := PackedFloat64Array()
	for k in range(n):
		la.append(log(maxf(a[a.size() - n + k], 1e-9)))
		lb.append(log(maxf(b[b.size() - n + k], 1e-9)))
	var fit := ols(lb, la)
	var spread := PackedFloat64Array()
	for k in range(n): spread.append(la[k] - float(fit[0]) - float(fit[1]) * lb[k])
	var lag := PackedFloat64Array()
	var diff := PackedFloat64Array()
	for k in range(1, n):
		lag.append(spread[k - 1])
		diff.append(spread[k] - spread[k - 1])
	var df := ols(lag, diff)
	var rho := float(df[1])
	var resid := 0.0
	var sxx := 0.0
	var ml := 0.0
	for v in lag: ml += v
	ml /= lag.size()
	for k in range(lag.size()):
		var e := diff[k] - float(df[0]) - rho * lag[k]
		resid += e * e
		sxx += (lag[k] - ml) * (lag[k] - ml)
	var se := sqrt(resid / maxf(1.0, lag.size() - 2) / maxf(sxx, 1e-12))
	var t := rho / maxf(se, 1e-12)
	var mean := 0.0
	for v in spread: mean += v
	mean /= n
	var sd := 0.0
	for v in spread: sd += (v - mean) * (v - mean)
	sd = sqrt(sd / maxf(1.0, n - 1))
	return [t < -3.34, float(fit[1]), t, mean, sd]

## K-means on 2D points (k from the template, seeded deterministically): labels.
static func kmeans(points: Array, k: int, iterations: int = 20) -> Array:
	var n := points.size()
	k = mini(k, n)
	if k <= 0: return []
	var centres: Array = []
	# Seeds spread along the first axis (deterministic, no randomness).
	var order := range(n)
	order.sort_custom(func(i, j): return float(points[i][0]) < float(points[j][0]))
	for c in range(k): centres.append((points[order[int(float(c) * (n - 1) / maxf(1.0, k - 1))]] as Array).duplicate())
	var labels: Array = []
	labels.resize(n)
	labels.fill(0)
	for it in range(iterations):
		for i in range(n):
			var best := 0
			var bd := INF
			for c in range(k):
				var dx := float(points[i][0]) - float(centres[c][0])
				var dy := float(points[i][1]) - float(centres[c][1])
				var d := dx * dx + dy * dy
				if d < bd:
					bd = d
					best = c
			labels[i] = best
		for c in range(k):
			var sx := 0.0
			var sy := 0.0
			var cnt := 0
			for i in range(n):
				if int(labels[i]) == c:
					sx += float(points[i][0])
					sy += float(points[i][1])
					cnt += 1
			if cnt > 0: centres[c] = [sx / cnt, sy / cnt]
	return labels
