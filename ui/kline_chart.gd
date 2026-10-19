class_name KLineChart
extends Control

## The exchange's candlestick chart (势力与交易所策划案_v0_7.md §5.3, layout after
## 《FX 简单!》): candles, volume, MA5 / MA20, the base line, news marks, and
## the lines of the Doctor's own positions on this market. Redraws itself from
## MarketState twice a second; data only, no captions.

const UP := Color("8fc31f")
const DOWN := Color("e0782a")
const GRID := Color(1, 1, 1, 0.06)
const MA5 := Color("5fd0d8")
const MA20 := Color("f5c000")
const VOLUME_SHARE := 0.18

var game: GameManager
var market_id := FactionCatalog.FX
var period := "15m"
var count := 90
var _wait := 0.0

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_wait -= delta
	if _wait <= 0.0:
		_wait = 0.5
		queue_redraw()

## Price of the selected underlying in display units.
func _series() -> Array:
	if market_id.begins_with("comp:"):
		# Composites have no book of their own: the mean of the faction's candles.
		var faction := market_id.substr(5)
		var all: Array = []
		for m in game.market.books:
			if FactionCatalog.split(m)[0] == faction: all.append(game.market.candles(m, period, count))
		if all.is_empty(): return []
		var n: int = all.map(func(a): return a.size()).min()
		var out: Array = []
		for k in range(n):
			var row := [0.0, 0.0, 0.0, 0.0, 0.0]
			for a in all:
				var c: Array = a[a.size() - n + k]
				for j in range(5): row[j] += float(c[j]) / all.size()
			out.append(row)
		return out
	return game.market.candles(market_id, period, count)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("101214"))
	if game == null: return
	var data := _series()
	if data.size() < 2: return
	var plot := Rect2(Vector2(6, 8), Vector2(size.x - 70, size.y * (1.0 - VOLUME_SHARE) - 16))
	var vol_rect := Rect2(Vector2(6, plot.end.y + 6), Vector2(plot.size.x, size.y * VOLUME_SHARE - 4))
	var lo := INF
	var hi := -INF
	var vmax := 0.0
	for c in data:
		lo = minf(lo, float(c[2]))
		hi = maxf(hi, float(c[1]))
		vmax = maxf(vmax, float(c[4]))
	var base := 1000.0 if market_id == FactionCatalog.FX else 100.0
	var marks := _position_lines()
	# Entry lines widen the scale; a far liquidation line only shows when in range.
	for label in marks:
		if not (str(label).begins_with("开仓") or str(label).begins_with("约定")): continue
		lo = minf(lo, float(marks[label]))
		hi = maxf(hi, float(marks[label]))
	var pad := (hi - lo) * 0.08 + 0.0001
	lo -= pad
	hi += pad
	var y_of := func(p: float) -> float: return plot.end.y - (p - lo) / (hi - lo) * plot.size.y
	# Grid and the right-hand scale.
	for k in range(5):
		var p := lo + (hi - lo) * k / 4.0
		var y: float = y_of.call(p)
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), GRID)
		draw_string(AK.en(), Vector2(plot.end.x + 6, y + 4), _fmt(p), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, AK.MUTE)
	if base > lo and base < hi:
		var yb: float = y_of.call(base)
		var x := plot.position.x
		while x < plot.end.x:
			draw_line(Vector2(x, yb), Vector2(minf(x + 6, plot.end.x), yb), Color(1, 1, 1, 0.25))
			x += 12
	var step := plot.size.x / data.size()
	var body := maxf(1.0, step * 0.62)
	var closes: Array = []
	for k in range(data.size()):
		var c: Array = data[k]
		var x := plot.position.x + step * (k + 0.5)
		var col := UP if float(c[3]) >= float(c[0]) else DOWN
		draw_line(Vector2(x, y_of.call(float(c[1]))), Vector2(x, y_of.call(float(c[2]))), col)
		var top: float = y_of.call(maxf(float(c[0]), float(c[3])))
		var bottom: float = y_of.call(minf(float(c[0]), float(c[3])))
		draw_rect(Rect2(x - body * 0.5, top, body, maxf(1.0, bottom - top)), col)
		if vmax > 0.0:
			var h := float(c[4]) / vmax * vol_rect.size.y
			draw_rect(Rect2(x - body * 0.5, vol_rect.end.y - h, body, h), Color(col, 0.45))
		closes.append(float(c[3]))
	_ma(closes, 5, MA5, plot, step, y_of)
	_ma(closes, 20, MA20, plot, step, y_of)
	# The Doctor's own lines.
	for label in marks:
		var v: float = marks[label]
		if v <= lo or v >= hi: continue
		var y: float = y_of.call(v)
		var col := AK.HP if label.begins_with("开仓") or label.begins_with("约定") else AK.RED
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(col, 0.7), 1.0)
		draw_string(AK.cn(), Vector2(plot.position.x + 4, y - 3), I18n.t(label), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)
	# Current price.
	var last: float = closes[-1]
	var yl: float = y_of.call(last)
	draw_line(Vector2(plot.position.x, yl), Vector2(plot.end.x, yl), Color(1, 1, 1, 0.5))
	draw_rect(Rect2(plot.end.x + 2, yl - 8, 62, 16), AK.PAPER)
	draw_string(AK.en(), Vector2(plot.end.x + 6, yl + 4), _fmt(last), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, AK.INK)
	_news_marks(data.size(), plot, step)

func _ma(closes: Array, n: int, col: Color, plot: Rect2, step: float, y_of: Callable) -> void:
	if closes.size() < n: return
	var pts := PackedVector2Array()
	var sum := 0.0
	for k in range(closes.size()):
		sum += float(closes[k])
		if k >= n: sum -= float(closes[k - n])
		if k >= n - 1: pts.append(Vector2(plot.position.x + step * (k + 0.5), y_of.call(sum / n)))
	if pts.size() >= 2: draw_polyline(pts, col, 1.0)

## Lines of open positions on this market: 开仓 / 强平 for CFDs, 约定 for forwards.
func _position_lines() -> Dictionary:
	var out := {}
	var ex := game.exchange
	var k := 0
	var j := 0
	for f in ex.forwards:
		var category := FactionCatalog.material_category(str(f.material))
		if "%s:%s" % [f.faction, category] != market_id: continue
		# The agreed unit price back on the index scale (×100) of this book.
		var unit_lmd := float(MaterialCatalog.create(str(f.material), 1).unit_value * Economy.LMD_PER_VALUE)
		var unit := Exchange.from_lmd(str(f.currency), unit_lmd)
		var pref := FactionCatalog.preference(str(f.faction), category) if f.dir == "deliver" else 1.0
		if unit * pref <= 0.0: continue
		j += 1
		out["约定 %d" % j] = float(f.k) / (unit * pref) * 100.0
	for c in ex.cfds:
		if str(c.underlying) != market_id: continue
		k += 1
		out["开仓 %d" % k] = float(c.entry)
		var liq := float(c.entry) * (1.0 - float(c.dir) * float(c.margin) / float(c.notional))
		out["强平 %d" % k] = liq
	return out

func _news_marks(n: int, plot: Rect2, step: float) -> void:
	var seconds := {"1m": 60, "5m": 300, "15m": 900, "1h": 3600, "4h": 14400, "1d": 86400, "1w": 604800}
	var span: int = seconds.get(period, 900)
	var now := game.market.t
	for headline in game.market.news:
		if not market_id in headline.get("markets", []) and not (market_id == FactionCatalog.FX and headline.get("markets", []).has("fx")): continue
		var back := int((now - int(headline.t)) / span)
		if back >= n: continue
		var x := plot.position.x + step * (n - 1 - back + 0.5)
		var col := AK.RED if headline.kind == "swan" else (AK.SP if headline.kind == "announce" else AK.CYAN)
		draw_colored_polygon(AK.diamond(Vector2(x, plot.position.y + 6), 4.0), col)

static func _fmt(p: float) -> String:
	return "%.1f" % p if p >= 100.0 else "%.2f" % p
