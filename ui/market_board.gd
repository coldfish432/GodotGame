class_name MarketBoard
extends Control

## The exchange floor's hologram (用户 2026-10-18: 重新制作交易行区域，改为全息
## 超大屏，显示 K 线和一些涨跌信息；参考现实交易所). Drawn into a SubViewport and
## shown in the hall as added light (base_hologram.gdshader), so black is
## empty air. Live from MarketState, the same data as the exchange screen,
## and in its colours (KLineChart: green up, orange down). No names, only
## numbers, arrows and each faction's colour chip (场景里不挂文字).
##   "wall":   a big 15-minute K-line of 龙门币/赤金 with MA5/MA20 and the last
##             price, and a column of the factions' markets (chip, sparkline,
##             ▲▼ %) — after Nasdaq MarketSite's video wall and the trading
##             halls' red-green boards.
##   "ticker": the running quotes, for the strip under the wall and the ring
##             over the counter (after the Tokyo Stock Exchange's revolving
##             quote ring); the shader scrolls it.

const UP := KLineChart.UP
const DOWN := KLineChart.DOWN
const MA5 := KLineChart.MA5
const MA20 := KLineChart.MA20
const LINE := Color(0.35, 0.8, 1.0)
const DIM := Color(0.2, 0.45, 0.6)
## A chip colour per faction, so the board reads without names.
const CHIPS := {
	"lungmen": Color("e0b030"), "rat": Color("a070e0"), "rhine": Color("e8f0f8"), "karlan": Color("50c8c0"),
	"ursus": Color("d05040"), "reunion": Color("c03838"), "sami": Color("70b860"), "kazimierz": Color("b8c0d0"),
	"fx": Color("ffd060"),
}
const REDRAW := 0.5

var market: MarketState
var mode := "wall"
var _wait := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_wait -= delta
	if _wait <= 0.0:
		_wait = REDRAW
		queue_redraw()

## The markets on the board: one per trading faction (its busiest category,
## the first it prefers), then the FX.
func rows() -> Array:
	var out: Array = []
	if market == null: return out
	var seen := {}
	for m in market.books:
		var faction: String = FactionCatalog.split(m)[0]
		if m == FactionCatalog.FX or seen.has(faction): continue
		seen[faction] = true
		out.append(m)
	return out

func _draw() -> void:
	if market == null: return
	if mode == "ticker":
		_ticker(Rect2(Vector2.ZERO, size), size.y * 0.5)
		return
	var w := size.x
	var h := size.y
	_frame(Rect2(4, 4, w - 8, h - 8))
	_kline(Rect2(24, 28, w * 0.6 - 36, h - 56), FactionCatalog.FX)
	_column(Rect2(w * 0.6 + 4, 28, w * 0.4 - 28, h - 56))

func _frame(r: Rect2) -> void:
	# Corner brackets and a thin rule, the hologram's edge.
	var c := LINE * Color(1, 1, 1, 0.9)
	for corner in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
		var sx := 1.0 if corner.x == r.position.x else -1.0
		var sy := 1.0 if corner.y == r.position.y else -1.0
		draw_line(corner, corner + Vector2(40 * sx, 0), c, 4)
		draw_line(corner, corner + Vector2(0, 40 * sy), c, 4)
	draw_rect(r, DIM * Color(1, 1, 1, 0.5), false, 1.0)

func _kline(r: Rect2, m: String) -> void:
	# 15-minute candles once there is a day of them; a young market in minutes.
	var data := market.candles(m, "15m", 64)
	if data.size() < 30: data = market.candles(m, "1m", 64)
	if data.size() < 2: return
	var lo := INF
	var hi := -INF
	var vmax := 0.0
	for c in data:
		lo = minf(lo, float(c[2]))
		hi = maxf(hi, float(c[1]))
		vmax = maxf(vmax, float(c[4]))
	var pad := (hi - lo) * 0.1 + 0.0001
	lo -= pad
	hi += pad
	var plot := Rect2(r.position, Vector2(r.size.x - 120, r.size.y * 0.8))
	var vol := Rect2(Vector2(r.position.x, plot.end.y + 10), Vector2(plot.size.x, r.size.y * 0.2 - 10))
	var y_of := func(p: float) -> float: return plot.end.y - (p - lo) / (hi - lo) * plot.size.y
	for k in range(6):
		var y := plot.position.y + plot.size.y * k / 5.0
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), DIM * Color(1, 1, 1, 0.35), 1.0)
		var p := hi - (hi - lo) * k / 5.0
		draw_string(AK.en(), Vector2(plot.end.x + 10, y + 7), "%.1f" % p, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, DIM * Color(1.6, 1.6, 1.6))
	var step := plot.size.x / data.size()
	var ma5: Array[Vector2] = []
	var ma20: Array[Vector2] = []
	for k in range(data.size()):
		var c: Array = data[k]
		var x := plot.position.x + step * (k + 0.5)
		var col := UP if float(c[3]) >= float(c[0]) else DOWN
		draw_line(Vector2(x, y_of.call(float(c[1]))), Vector2(x, y_of.call(float(c[2]))), col, 2.0)
		var top: float = y_of.call(maxf(float(c[0]), float(c[3])))
		var bottom: float = y_of.call(minf(float(c[0]), float(c[3])))
		draw_rect(Rect2(x - step * 0.36, top, step * 0.72, maxf(bottom - top, 2.0)), col)
		if vmax > 0.0:
			var vh := float(c[4]) / vmax * vol.size.y
			draw_rect(Rect2(x - step * 0.36, vol.end.y - vh, step * 0.72, vh), col * Color(1, 1, 1, 0.55))
		if k >= 4: ma5.append(Vector2(x, y_of.call(_mean(data, k, 5))))
		if k >= 19: ma20.append(Vector2(x, y_of.call(_mean(data, k, 20))))
	if ma5.size() > 1: draw_polyline(PackedVector2Array(ma5), MA5, 3.0)
	if ma20.size() > 1: draw_polyline(PackedVector2Array(ma20), MA20, 3.0)
	# The last price: a dashed line across and its tag on the scale, with the day's change.
	var last := float(data[-1][3])
	var ly: float = y_of.call(last)
	var rising := market.change(m) >= 0.0
	var tag := UP if rising else DOWN
	draw_dashed_line(Vector2(plot.position.x, ly), Vector2(plot.end.x, ly), tag, 2.0, 10.0)
	draw_rect(Rect2(plot.end.x + 4, ly - 16, 112, 32), tag)
	draw_string(AK.en(), Vector2(plot.end.x + 10, ly + 9), "%.1f" % last, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.BLACK)
	draw_rect(Rect2(plot.position.x, plot.position.y - 2, 18, 18), CHIPS.fx)
	draw_string(AK.en(), Vector2(plot.position.x + 28, plot.position.y + 15), "%s %+.2f%%" % ["▲" if rising else "▼", market.change(m) * 100.0],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 28, tag)

static func _mean(data: Array, k: int, n: int) -> float:
	var s := 0.0
	for j in range(k - n + 1, k + 1): s += float(data[j][3])
	return s / n

func _column(r: Rect2) -> void:
	var list := rows()
	if list.is_empty(): return
	var row_h := minf(r.size.y / list.size(), 80.0)
	for i in range(list.size()):
		var m: String = list[i]
		var y := r.position.y + i * row_h
		var faction: String = FactionCatalog.split(m)[0]
		var ch := market.change(m)
		var col := UP if ch >= 0.0 else DOWN
		draw_rect(Rect2(r.position.x, y + 10, 26, row_h - 22), CHIPS.get(faction, LINE))
		# Sparkline of the last half hour.
		var spark := market.candles(m, "1m", 30)
		var area := Rect2(r.position.x + 40, y + 8, r.size.x * 0.48, row_h - 18)
		if spark.size() > 1:
			var lo := INF
			var hi := -INF
			for c in spark:
				lo = minf(lo, float(c[3]))
				hi = maxf(hi, float(c[3]))
			var pts := PackedVector2Array()
			for k in range(spark.size()):
				var t := (float(spark[k][3]) - lo) / maxf(hi - lo, 0.0001)
				pts.append(Vector2(area.position.x + area.size.x * k / (spark.size() - 1), area.end.y - t * area.size.y))
			draw_polyline(pts, col, 2.5)
		draw_string(AK.en(), Vector2(area.end.x + 16, y + row_h * 0.5 + 10), "%s %+.2f%%" % ["▲" if ch >= 0.0 else "▼", ch * 100.0],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 26, col)
		draw_line(Vector2(r.position.x, y + row_h - 2), Vector2(r.end.x, y + row_h - 2), DIM * Color(1, 1, 1, 0.3), 1.0)

## The running quotes: chip, ▲▼ and change for every market, twice over so it
## loops; it scrolls in the shader (uv_scroll), so this only redraws values.
func _ticker(r: Rect2, font_size: float) -> void:
	var list := rows() + [FactionCatalog.FX]
	if list.is_empty(): return
	var cell := r.size.x / (list.size() * 2)
	draw_line(Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), DIM, 1.0)
	for i in range(list.size() * 2):
		var m: String = list[i % list.size()]
		var faction: String = FactionCatalog.split(m)[0]
		var ch := market.change(m)
		var col := UP if ch >= 0.0 else DOWN
		var x := r.position.x + i * cell
		var mid := r.position.y + r.size.y * 0.5
		draw_rect(Rect2(x + 8, mid - font_size * 0.4, font_size * 0.8, font_size * 0.8), CHIPS.get(faction, LINE))
		draw_string(AK.en(), Vector2(x + 16 + font_size, mid + font_size * 0.36), "%s%.2f%%" % ["▲" if ch >= 0.0 else "▼", absf(ch) * 100.0],
			HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size), col)
