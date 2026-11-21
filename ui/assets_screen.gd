class_name AssetsScreen
extends RefCounted

## 罗德岛运营与资产管理策划案 v0.12 §6: the exchange terminal's three new
## pages, laid out like a broker's app (用户 2026-11-14: "ui太乱了，整理一下，
## 参考lynch作业和一些交易软件"): a row of figure tiles, cards, column tables
## with the numbers right-aligned, gains and losses in the chart's colours.
## 资产: tiles, worth and the cycle on the left, four sub-pages on the right
## (运营 / 存款 / 信贷 / 证券). 企业: a watchlist table, the chart, the ratio
## tiles and the moat checklist, the order card. 策略: the slots table, the
## picked strategy (or a backtest), the new-strategy form. Data, state and
## buttons only (no notes).

const TOP := BaseScreens.TOP
const BOTTOM := BaseScreens.BOTTOM
const UP := KLineChart.UP
const DOWN := KLineChart.DOWN
const ASSET_TABS := ["运营", "存款", "信贷", "证券"]
const ROW_H := 24.0

static var firm := "swire"
static var amount := 10000.0
static var gold_amount := 1.0
static var term := 1
static var bond_pick := 0
static var bond_term := 0
static var fund_pick := 0
static var gold_pick := 0           # 0 存单, 1… a fund
static var asset_tab := 0
static var tpl_pick := 0
static var strat_pick := -1
static var strat_capital := 50000.0
static var strat_dd := 0.2
static var strat_days := 0
static var strat_params := {}
static var strat_pool: Array = []
static var backtest := {}

## A small line chart: series of numbers, the first in HOLO, the second muted.
class LineCurve extends Control:
	var series: Array = []
	var colours: Array = [AK.HOLO, AK.MUTE]
	var zero_line := false
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
		for k in range(1, 4):
			draw_line(Vector2(0, size.y * k / 4.0), Vector2(size.x, size.y * k / 4.0), Color(1, 1, 1, 0.05), 1.0)
		var lo := INF
		var hi := -INF
		for s in series:
			for v in s:
				lo = minf(lo, float(v))
				hi = maxf(hi, float(v))
		if lo == INF: return
		if zero_line:
			lo = minf(lo, 0.0)
			hi = maxf(hi, 0.0)
		var span := maxf(hi - lo, 1e-6)
		lo -= span * 0.06
		span *= 1.12
		if zero_line:
			var zy := size.y - (0.0 - lo) / span * size.y
			draw_line(Vector2(0, zy), Vector2(size.x, zy), AK.LINE, 1.0)
		for k in range(series.size() - 1, -1, -1):
			var s: Array = series[k]
			if s.size() < 2: continue
			var pts := PackedVector2Array()
			for i in range(s.size()): pts.append(Vector2(size.x * i / (s.size() - 1), size.y - (float(s[i]) - lo) / span * size.y))
			draw_polyline(pts, colours[mini(k, colours.size() - 1)], 1.5 if k == 0 else 1.0)

## A bar from the middle: right in UP for a gain, left in DOWN for a loss (−1…1).
class SignedBar extends Control:
	var value := 0.0
	func _draw() -> void:
		var r := Rect2(0, size.y / 2.0 - 3.0, size.x, 6.0)
		draw_rect(r, Color(1, 1, 1, 0.06))
		var mid := size.x / 2.0
		draw_line(Vector2(mid, r.position.y - 2), Vector2(mid, r.end.y + 2), AK.DIM)
		var w := mid * clampf(value, -1.0, 1.0)
		if w >= 0.0: draw_rect(Rect2(mid, r.position.y, w, r.size.y), UP)
		else: draw_rect(Rect2(mid + w, r.position.y, -w, r.size.y), DOWN)

## One bar split by share: [[value, colour], …].
class StackBar extends Control:
	var parts: Array = []
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.06))
		var total := 0.0
		for p in parts: total += maxf(0.0, float(p[0]))
		if total <= 0.0: return
		var x := 0.0
		for p in parts:
			var w := size.x * maxf(0.0, float(p[0])) / total
			draw_rect(Rect2(x, 0, w, size.y), p[1])
			x += w

## A label or row whose hover shows a card made by `make` (用户 2026-11-14).
class TipLabel extends Label:
	var make := Callable()
	func _make_custom_tooltip(_t: String) -> Object:
		return make.call() if make.is_valid() else null

class TipButton extends Button:
	var make := Callable()
	func _make_custom_tooltip(_t: String) -> Object:
		return make.call() if make.is_valid() else null

## The hover card of a strategy template: its rule, period, universe, unlock.
static func strategy_card(game: GameManager, tpl: String) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", AK.box(AK.PLATE_SOLID, AK.HOLO, 1, 12))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(AK.section(StrategyCatalog.name_of(tpl), tpl))
	var d := AK.label(StrategyCatalog.desc(tpl), 12, AK.FG)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.x = 300
	v.add_child(d)
	var info := StrategyCatalog.info(tpl)
	var pi := ExchangeScreen.PERIODS.find(str(info.get("period", "")))
	var rows: Array = [["K 线", ExchangeScreen.PERIOD_NAMES[pi] if pi >= 0 else "—"],
		["标的", str(StrategyCatalog.UNIVERSE_NAMES.get(str(info.get("universe", "")), ""))]]
	var open := game.exchange.strategies.unlocked(tpl)
	rows.append(["解锁", [str(StrategyCatalog.UNLOCK_NAMES.get(str(info.get("unlock", "")), "")), AK.GREEN if open else AK.RED]])
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 2)
	for r in rows:
		g.add_child(AK.label(str(r[0]), 11, AK.MUTE))
		var val = r[1]
		g.add_child(AK.label(str(val[0]) if val is Array else str(val), 11, val[1] if val is Array else AK.FG))
	v.add_child(g)
	return p

# --- Building blocks ------------------------------------------------------------------------

static func _fmt(v: float) -> String:
	return ("−" if v < 0.0 else "") + Economy.format(roundi(absf(v)))

static func _pct(v: float) -> String:
	return "%+.2f%%" % (v * 100.0)

## A gain in UP, a loss in DOWN, flat in FG.
static func _tone(v: float) -> Color:
	return UP if v > 0.00005 else (DOWN if v < -0.00005 else AK.FG)

static func _num(v: float, d := 2) -> String:
	return ("%." + str(d) + "f") % v if absf(v) < 1e6 and not is_inf(v) and not is_nan(v) else "—"

## 5.41M / 12.3k / 0.85: a figure in a narrow cell.
static func _compact(v: float) -> String:
	if absf(v) >= 1e6: return "%.2fM" % (v / 1e6)
	if absf(v) >= 1e4: return "%.1fk" % (v / 1e3)
	return "%.2f" % v

static func _row(col: Control, sep := 6) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", sep)
	col.add_child(r)
	return r

static func _line(col: Control, text: String, colour: Color = AK.FG, size := 12) -> Label:
	var l := AK.label(text, size, colour)
	col.add_child(l)
	return l

static func _btn(row: Control, text: String, enabled: bool, cb: Callable, kind := "blue", w := 0.0) -> Button:
	var b := AK.button(text, kind if enabled else "plain", 12)
	if w > 0.0: b.custom_minimum_size = Vector2(w, 28)
	b.disabled = not enabled or not ExchangeScreen._blocked.is_empty()
	b.pressed.connect(cb)
	row.add_child(b)
	return b

static func _gap(col: Control, h := 4.0) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	col.add_child(c)

## A card: a plate with a 1 px edge and its heading; returns the body.
static func _card(stage: Control, at: Vector2, sz: Vector2, title: String, en := "") -> VBoxContainer:
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", AK.box(AK.PLATE_2, AK.LINE, 1))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	AK.put(stage, bg, at, sz)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	body.custom_minimum_size = Vector2(sz.x - 24, 0)
	AK.put(stage, body, at + Vector2(12, 10), Vector2(sz.x - 24, 0))
	if not title.is_empty(): body.add_child(AK.section(title, en))
	return body

## A figure tile: a small grey caption over a large number.
static func _tile(row: Control, caption: String, value: String, colour: Color = AK.FG, w := 0.0) -> void:
	var p := PanelContainer.new()
	var style := AK.box(AK.PLATE_SOLID, AK.LINE, 1, 0)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", style)
	if w > 0.0: p.custom_minimum_size.x = w
	else: p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.add_child(AK.label(caption, 10, AK.MUTE))
	v.add_child(AK.label(value, 16, colour, AK.en()))
	p.add_child(v)
	row.add_child(p)

## A row of tiles filling `width`.
static func _tiles(parent: Control, width: float) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 6)
	r.custom_minimum_size.x = width
	parent.add_child(r)
	return r

static func _cell(text: String, w: float, align: int, colour: Color, size := 11) -> Label:
	var l := AK.label(text, size, colour)
	l.custom_minimum_size = Vector2(w, 0)
	l.horizontal_alignment = align
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static var _row_styles := {}

static func _row_style(kind: String) -> StyleBoxFlat:
	if not _row_styles.has(kind):
		var s: StyleBoxFlat
		match kind:
			"odd": s = AK.box(Color(1, 1, 1, 0.025))
			"hover": s = AK.box(AK.PLATE_3)
			"picked":
				s = AK.box(Color(AK.HOLO.r, AK.HOLO.g, AK.HOLO.b, 0.16))
				s.border_color = AK.HOLO
				s.border_width_left = 3
			_: s = AK.box(Color(0, 0, 0, 0))
		_row_styles[kind] = s
	return _row_styles[kind]

## A table. cols: [[title, width, align]] (align: 0 left, 2 right). rows: arrays
## of cells, each a String, [String, Color] or a Control (a button). With
## on_pick the rows are clickable and `picked` is lit.
static func _table(parent: Control, cols: Array, rows: Array, picked := -1, on_pick := Callable(), tips: Array = []) -> VBoxContainer:
	var t := VBoxContainer.new()
	t.add_theme_constant_override("separation", 0)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 0)
	var pad := Control.new()
	pad.custom_minimum_size.x = 6
	head.add_child(pad)
	for c in cols: head.add_child(_cell(str(c[0]), float(c[1]), int(c[2]), AK.DIM, 10))
	t.add_child(head)
	var rule := ColorRect.new()
	rule.color = AK.LINE
	rule.custom_minimum_size = Vector2(0, 1)
	t.add_child(rule)
	for i in range(rows.size()):
		var holder: Control
		if on_pick.is_valid():
			var b := TipButton.new()
			if i < tips.size() and (tips[i] as Callable).is_valid():
				b.make = tips[i]
				b.tooltip_text = " "
			b.focus_mode = Control.FOCUS_NONE
			b.add_theme_stylebox_override("normal", _row_style("picked" if i == picked else ("odd" if i % 2 == 1 else "even")))
			b.add_theme_stylebox_override("hover", _row_style("picked" if i == picked else "hover"))
			b.add_theme_stylebox_override("pressed", _row_style("picked"))
			b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
			var index := i
			b.pressed.connect(func(): on_pick.call(index))
			holder = b
		else:
			var p := Panel.new()
			p.add_theme_stylebox_override("panel", _row_style("odd" if i % 2 == 1 else "even"))
			p.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder = p
		holder.custom_minimum_size = Vector2(0, ROW_H)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 0)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var p2 := Control.new()
		p2.custom_minimum_size.x = 6
		p2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(p2)
		var cells: Array = rows[i]
		for k in range(cols.size()):
			var w := float(cols[k][1])
			var cell = cells[k] if k < cells.size() else ""
			if cell is Control:
				var box := CenterContainer.new()
				box.custom_minimum_size = Vector2(w, ROW_H)
				box.add_child(cell)
				line.add_child(box)
				continue
			var text := str(cell[0]) if cell is Array else str(cell)
			var colour: Color = cell[1] if cell is Array else AK.FG
			var lab := _cell(text, w, int(cols[k][2]), colour)
			lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			line.add_child(lab)
		holder.add_child(line)
		t.add_child(holder)
	parent.add_child(t)
	return t

## A small button for a table cell.
static func _cell_btn(text: String, enabled: bool, cb: Callable, w := 60.0) -> Button:
	var b := AK.button(text, "plain", 11)
	b.custom_minimum_size = Vector2(w, 20)
	b.disabled = not enabled or not ExchangeScreen._blocked.is_empty()
	b.pressed.connect(cb)
	return b

## Legend chips: [[name, colour], …].
static func _legend(parent: Control, items: Array) -> HBoxContainer:
	var r := _row(parent, 12)
	for it in items:
		var sw := ColorRect.new()
		sw.color = it[1]
		sw.custom_minimum_size = Vector2(10, 3)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(sw)
		r.add_child(AK.label(str(it[0]), 10, AK.MUTE))
	return r

static func _curve(parent: Control, series: Array, sz: Vector2, zero := false, colours: Array = []) -> LineCurve:
	var c := LineCurve.new()
	c.series = series
	c.zero_line = zero
	if not colours.is_empty(): c.colours = colours
	c.custom_minimum_size = sz
	parent.add_child(c)
	return c

# --- 资产 ---------------------------------------------------------------------------------

static func assets_page(menu: FieldMenu, stage: Control) -> void:
	var game := menu.game
	var ex := game.exchange
	var fin := ex.fin
	var bill: Dictionary = fin.bills[-1] if not fin.bills.is_empty() else {}
	# Tiles.
	var top := VBoxContainer.new()
	AK.put(stage, top, Vector2(16, TOP + 38), Vector2(1248, 0))
	var tiles := _tiles(top, 1248)
	_tile(tiles, "账户净值", _fmt(fin.net_worth()))
	var net_today := fin.today_in - fin.today_out
	_tile(tiles, "今日盈亏", ("+" if net_today >= 0.0 else "") + _fmt(net_today), _tone(net_today))
	_tile(tiles, "日账", _fmt(float(bill.get("total", 0))))
	_tile(tiles, "龙门币", _fmt(game.gold))
	_tile(tiles, "赤金", Economy.format(ex.home_bars()))
	_tile(tiles, "存款", _fmt(fin.deposits_lmd()))
	_tile(tiles, "证券与策略", _fmt(fin.holdings_lmd()))
	_tile(tiles, "罗德岛库存", _fmt(fin.stock_value()))
	_tile(tiles, "欠款", _fmt(ex.loan), AK.RED if ex.loan > 0 else AK.FG)
	# Left: worth and its mix, the cycle.
	var y := TOP + 102
	var wl := _card(stage, Vector2(16, y), Vector2(500, 236), "净值走势", "NET WORTH")
	_curve(wl, [fin.worth.map(func(x): return float(x[1]))], Vector2(476, 136))
	var gold_lmd := Exchange.live_lmd("gold", ex.home_bars())
	var mix := [["龙门币", float(maxi(game.gold, 0)), AK.FG], ["存款", fin.deposits_lmd(), AK.CYAN], ["证券与策略", fin.holdings_lmd(), AK.HOLO],
		["库存", fin.stock_value(), AK.SP], ["赤金", gold_lmd, AK.SPECIAL]]
	var bar := StackBar.new()
	bar.parts = mix.map(func(p): return [p[1], p[2]])
	bar.custom_minimum_size = Vector2(476, 8)
	wl.add_child(bar)
	var total := 0.0
	for p in mix: total += maxf(0.0, float(p[1]))
	var leg := GridContainer.new()
	leg.columns = 3
	leg.add_theme_constant_override("h_separation", 10)
	leg.add_theme_constant_override("v_separation", 2)
	wl.add_child(leg)
	for p in mix:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 6)
		item.custom_minimum_size.x = 150
		var sw := ColorRect.new()
		sw.color = p[2]
		sw.custom_minimum_size = Vector2(8, 8)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(sw)
		var nm := AK.label(str(p[0]), 10, AK.MUTE)
		nm.custom_minimum_size.x = 100
		nm.clip_text = true
		item.add_child(nm)
		item.add_child(AK.label("%.0f%%" % (maxf(0.0, float(p[1])) / maxf(total, 1.0) * 100.0), 10, AK.FG, AK.en()))
		leg.add_child(item)
	var econ := game.market.econ
	var cy := _card(stage, Vector2(16, y + 244), Vector2(500, BOTTOM - y - 252), "景气指数", "CYCLE")
	var head := _row(cy, 10)
	head.add_child(AK.label("%+.2f" % econ.e, 20, _tone(econ.e), AK.en()))
	var ph := AK.tag(econ.phase(), AK.PLATE_3, false)
	ph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(ph)
	_curve(cy, [econ.history.map(func(x): return float(x[1]))], Vector2(476, 70), true)
	var parts := econ.parts
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 2)
	for p in [["企业", parts.firms], ["货价", parts.goods], ["信贷", parts.credit], ["势力", parts.factions], ["情绪", parts.mood]]:
		grid.add_child(_cell(str(p[0]), 40, 0, AK.MUTE))
		var sb := SignedBar.new()
		sb.value = float(p[1])
		sb.custom_minimum_size = Vector2(70, 14)
		grid.add_child(sb)
		grid.add_child(_cell("%+.2f" % float(p[1]), 40, 2, _tone(float(p[1]))))
	cy.add_child(grid)
	var tight := game.market.credit.tightness()
	var rates := _tiles(cy, 476)
	_tile(rates, "信贷松紧", "%.2f" % tight)
	_tile(rates, "基础利率/日", "%.3f%%" % (game.market.credit.base_rate(game.market) * 100.0))
	_tile(rates, "活期/日", "%.3f%%" % (fin.demand_rate("lmd") * 100.0))
	# Right: the sub-pages.
	var x := 526.0
	AK.put(stage, ExchangeScreen._seg(ASSET_TABS, asset_tab, func(i): asset_tab = i; ExchangeScreen.build(menu), 12, 738.0), Vector2(x, y))
	var card := _card(stage, Vector2(x, y + 34), Vector2(738, BOTTOM - y - 42), "", "")
	TutorialSpotlight.screen(game, ["交易所", "交易所/资产", "交易所/资产/" + ASSET_TABS[asset_tab]])  # i18n: skip
	match asset_tab:
		0: _upkeep_tab(menu, card, bill)
		1: _deposit_tab(menu, card)
		2: _credit_tab(menu, card)
		3: _securities_tab(menu, card)

static func _redo(menu: FieldMenu) -> Callable:
	return func(): menu.game.save_base(); ExchangeScreen.build(menu)

static func _upkeep_tab(menu: FieldMenu, card: VBoxContainer, bill: Dictionary) -> void:
	var fin := menu.game.exchange.fin
	var redo := _redo(menu)
	card.add_child(AK.section("运营账单", "UPKEEP  DAY %d" % int(bill.get("day", fin.today()))))
	var items := {}
	for it in bill.get("items", []): items[str(it.facility)] = it
	var rows: Array = []
	for f in RhodesFinance.UPKEEP_ORDER:
		var it: Dictionary = items.get(f, {})
		var have := 0
		for mm in RhodesFinance.UPKEEP[f]: have += fin.stock_count(str(mm))
		var need := fin.need_lmd(f)
		var days := fin.days_left(f)
		var short := need > 0.0 and days < 1.0
		var used := 0
		for k in it.get("from_stock", {}): used += int(it.from_stock[k])
		rows.append([RhodesFinance.FACILITY_NAMES[f], str(it.get("material", RhodesFinance.UPKEEP[f][0])),
			[str(have), AK.RED if short else AK.FG], [("%.1f" % days) if need > 0.0 and days < 9999.0 else "—", AK.RED if short else AK.FG],
			str(used), str(int(it.get("bought", 0))), _fmt(float(it.get("cost", 0))), _fmt(fin.family_value(f))])
	var cols := [["设施", 100, 0], ["材料", 104, 0], ["库存", 60, 2], ["可用天数", 80, 2], ["今日用库存", 90, 2], ["今日买进", 80, 2], ["今日费用", 96, 2], ["库存估值", 96, 2]]
	if fin.facility_stopped("strategies"): rows.append(["策略", "—", "—", "—", "—", "—", ["停用", AK.RED], "—"])
	_table(card, cols, rows)
	_gap(card, 6)
	var t := _tiles(card, 714)
	_tile(t, "薪资", _fmt(float(bill.get("salary", 0))))
	_tile(t, "利息", _fmt(float(bill.get("interest", 0))))
	_tile(t, "合计", _fmt(float(bill.get("total", 0))))
	_tile(t, "欠费", _fmt(fin.arrears), AK.RED if fin.arrears > 0.5 else AK.FG)
	if not fin.stopped.is_empty():
		_line(card, "停用  " + "  ".join(fin.stopped.map(func(s): return str(RhodesFinance.FACILITY_NAMES.get(s, "策略" if s == "strategies" else s)))), AK.RED, 12)
	_gap(card, 6)
	card.add_child(AK.section("作物口粮", "RATIONS"))
	var meal := "热餐" if fin.hot_meal() else ("停发补给" if fin.supply_stopped() else "—")
	_table(card, [["库存", 110, 2], ["每日", 110, 2], ["可用天数", 110, 2], ["今日", 110, 2]],
		[[str(fin.crops_in_stock()), "%.2f" % fin.daily_rations(), ("%.1f" % fin.ration_days()) if fin.rations() > 0 else "—",
			[meal, AK.GREEN if fin.hot_meal() else (AK.RED if fin.supply_stopped() else AK.FG)]]])
	_gap(card, 4)
	var hrow := _row(card)
	_btn(hrow, "收成直入库存：%s" % ("开" if fin.harvest_to_stock else "关"), true, func(): fin.harvest_to_stock = not fin.harvest_to_stock; redo.call(), "plain", 200)

static func _deposit_tab(menu: FieldMenu, card: VBoxContainer) -> void:
	var game := menu.game
	var fin := game.exchange.fin
	var redo := _redo(menu)
	card.add_child(AK.section("存款", "DEPOSITS  %s" % _fmt(fin.deposits_lmd())))
	var rows: Array = [
		["活期", "龙门币", _fmt(float(fin.demand.lmd)), "%.3f%%" % (fin.demand_rate("lmd") * 100.0), "—", ""]]
	for tm in fin.terms:
		var tid := int(tm.id)
		rows.append(["定存 %d 天" % int(tm.days), "龙门币", _fmt(float(tm.amount)),
			"%.3f%%" % (float(tm.rate) * 100.0), "%d 天" % (int(tm.due) - fin.today()), _cell_btn("提前取出", true, func(): fin.break_term(tid); redo.call(), 72)])
	_table(card, [["账户", 110, 0], ["币种", 80, 0], ["金额", 130, 2], ["利率/日", 100, 2], ["到期", 90, 2], ["", 110, 2]], rows)
	_gap(card, 10)
	card.add_child(AK.section("存入", "NEW"))
	ExchangeScreen._number(card, "金额", amount, 0, 5000.0, 0.0, func(v): amount = v; ExchangeScreen.build(menu), "龙门币", func(): return float(game.gold))
	var ok := game.gold >= amount and amount > 0.0
	var drow := _row(card)
	_btn(drow, "存入活期", ok, func(): fin.deposit("lmd", amount); redo.call(), "blue", 130)
	_btn(drow, "取出活期", float(fin.demand.lmd) >= amount and amount > 0.0, func(): fin.withdraw("lmd", amount); redo.call(), "plain", 130)
	var trow := _row(card)
	for i in range(RhodesFinance.TERM_DAYS.size()):
		var d := int(RhodesFinance.TERM_DAYS[i])
		_btn(trow, "定存 %d 天  %.3f%%" % [d, fin.term_rate(d) * 100.0], ok, func(): fin.open_term("lmd", amount, d); redo.call(), "plain", 150)

static func _credit_tab(menu: FieldMenu, card: VBoxContainer) -> void:
	var game := menu.game
	var ex := game.exchange
	var fin := ex.fin
	var redo := _redo(menu)
	card.add_child(AK.section("信贷", "CREDIT"))
	var state := "严重超额" if fin.severe() else ("逾期" if fin.loan_locked() else "正常")
	var t := _tiles(card, 714)
	_tile(t, "已借", _fmt(ex.loan), AK.RED if ex.loan > 0 else AK.FG)
	_tile(t, "额度", _fmt(fin.loan_limit()))
	_tile(t, "利率/日", "%.3f%%" % (fin.loan_rate() * 100.0))
	_tile(t, "状态", state, AK.FG if state == "正常" else AK.RED)
	var used := StackBar.new()
	var limit := float(maxi(fin.loan_limit(), 1))
	used.parts = [[minf(float(ex.loan), limit), AK.RED if fin.loan_locked() else AK.SP], [maxf(0.0, limit - float(ex.loan)), Color(1, 1, 1, 0.0)]]
	used.custom_minimum_size = Vector2(714, 8)
	card.add_child(used)
	_gap(card, 8)
	var lrow := _row(card)
	for n in [10000, 50000, 200000]:
		var amt := int(n)
		_btn(lrow, "借 %s" % Economy.format(amt), not fin.loan_locked() and ex.loan + amt <= fin.loan_limit(), func(): fin.borrow(amt); redo.call(), "plain", 120)
	var pay := mini(ex.loan, maxi(game.gold, 0))
	_btn(lrow, "还 %s" % Economy.format(pay), ex.loan > 0 and game.gold > 0, func(): fin.repay(mini(ex.loan, game.gold)); redo.call(), "blue", 140)
	_gap(card, 8)
	card.add_child(AK.section("自动还款", "AUTO"))
	var arow := _row(card)
	_btn(arow, "自动还款：%s" % ("开" if fin.auto_repay else "关"), true, func(): fin.auto_repay = not fin.auto_repay; redo.call(), "plain", 140)
	_btn(arow, "−", fin.reserve_days > 0, func(): fin.reserve_days = maxi(0, fin.reserve_days - 1); redo.call(), "plain", 30)
	var keep := AK.label("保留 %d 天  %s" % [fin.reserve_days, _fmt(fin.reserve())], 12, AK.FG)
	keep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	arow.add_child(keep)
	_btn(arow, "+", fin.reserve_days < 30, func(): fin.reserve_days = mini(30, fin.reserve_days + 1); redo.call(), "plain", 30)

static func _securities_tab(menu: FieldMenu, card: VBoxContainer) -> void:
	var game := menu.game
	var ex := game.exchange
	var sec := ex.securities
	var redo := _redo(menu)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	card.add_child(cols)
	# Left: the 赤金 funds (bought with whole bars from the warehouse), one picked.
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.custom_minimum_size.x = 348
	cols.add_child(left)
	left.add_child(AK.section("赤金基金", "GOLD FUNDS  %s" % _fmt(sec.value_lmd())))
	var funds := Securities.FUNDS.keys()
	gold_pick = posmod(gold_pick, funds.size())
	var rows: Array = []
	for f in funds:
		var held := float((sec.funds.get(f, {}) as Dictionary).get("units", 0.0))
		rows.append([str(Securities.FUNDS[f].name), "%.4f" % sec.nav(str(f)), "%.2f" % held])
	_table(left, [["产品", 170, 0], ["净值", 80, 2], ["份额", 90, 2]], rows, gold_pick, func(i): gold_pick = i; ExchangeScreen.build(menu))
	_gap(left, 4)
	gold_amount = maxf(1.0, roundf(gold_amount))
	ExchangeScreen._number(left, "赤金", gold_amount, 0, 1.0, 1.0, func(v): gold_amount = maxf(1.0, roundf(v)); ExchangeScreen.build(menu), "块", func(): return float(ex.home_bars()))
	var have := ex.home_bars() >= int(gold_amount)
	var brow := _row(left)
	var fund := str(funds[gold_pick])
	var held := float((sec.funds.get(fund, {}) as Dictionary).get("units", 0.0))
	_btn(brow, "买入", have, func(): sec.buy_fund(fund, gold_amount); redo.call(), "blue", 100)
	_btn(brow, "全部卖出", held > 0.0, func(): sec.sell_fund(fund, held); redo.call(), "plain", 110)
	# Right: bonds.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.custom_minimum_size.x = 348
	cols.add_child(right)
	right.add_child(AK.section("债券", "BONDS"))
	var issuers := sec.bond_issuers()
	var issuer := str(issuers[posmod(bond_pick, issuers.size())])
	var bname := FirmCatalog.name_of(issuer.substr(5)) if issuer.begins_with("firm:") else Currencies.name_of(issuer)
	var prow := _row(right)
	_btn(prow, "‹", true, func(): bond_pick -= 1; ExchangeScreen.build(menu), "plain", 28)
	var nm := AK.label(bname, 13, AK.FG)
	nm.custom_minimum_size.x = 150
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prow.add_child(nm)
	_btn(prow, "›", true, func(): bond_pick += 1; ExchangeScreen.build(menu), "plain", 28)
	var cp := AK.label("票息 %.3f%%/日" % (sec.bond_coupon(issuer) / 365.0 * 100.0), 12, AK.CYAN)
	cp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prow.add_child(cp)
	var terms: Array = Securities.BOND_TERMS.map(func(d): return "%d 天" % int(d))
	bond_term = posmod(bond_term, terms.size())
	right.add_child(ExchangeScreen._seg(terms, bond_term, func(i): bond_term = i; ExchangeScreen.build(menu), 11, 348.0))
	ExchangeScreen._number(right, "金额", amount, 0, 5000.0, 0.0, func(v): amount = v; ExchangeScreen.build(menu), "", func(): return float(game.gold))
	var days := int(Securities.BOND_TERMS[bond_term])
	var orow := _row(right)
	_btn(orow, "买入", game.gold >= amount and amount >= 1000.0, func(): sec.buy_bond(issuer, amount, days); redo.call(), "blue", 100)
	_gap(right, 4)
	var held_rows: Array = []
	for b in sec.bonds:
		var bid := int(b.id)
		var name := FirmCatalog.name_of(str(b.issuer).substr(5)) if bool(b.corp) else Currencies.name_of(str(b.cur))
		held_rows.append([name, _fmt(sec.bond_value(b)), "%d 天" % (int(b.due) - ex.fin.today()), _cell_btn("卖出", true, func(): sec.sell_bond(bid); redo.call(), 52)])
	_table(right, [["持有债券", 130, 0], ["市值", 80, 2], ["到期", 60, 2], ["", 70, 2]], held_rows)

# --- 企业 ---------------------------------------------------------------------------------

## 用户 2026-11-14 (the Lynch homework's Signal column): PEG under 1 green, over 2 orange.
static func _peg_tone(peg: float) -> Color:
	if peg <= 0.0 or peg >= 999.0: return AK.MUTE
	return UP if peg < 1.0 else (DOWN if peg > 2.0 else AK.FG)

static func firms_page(menu: FieldMenu, stage: Control) -> void:
	var game := menu.game
	var m := game.market
	var sec := game.exchange.securities
	var redo := _redo(menu)
	if not FirmCatalog.FIRMS.has(firm): firm = FirmCatalog.ORDER[0]
	# Left: the watchlist.
	var list := _card(stage, Vector2(16, TOP + 38), Vector2(330, BOTTOM - TOP - 46), "上市企业", "LISTED  %d" % FirmCatalog.ORDER.size())
	var rows: Array = []
	var picked := 0
	for i in range(FirmCatalog.ORDER.size()):
		var id: String = FirmCatalog.ORDER[i]
		if id == firm: picked = i
		var r := m.firms.cached_ratios(id)
		var ch := MarketWidgets.change_of(game, "stock:" + id) if m.stocks.has(id) else 0.0
		rows.append([FirmCatalog.name_of(id), KLineChart._fmt(m.stock_price(id)), [_pct(ch), _tone(ch)],
			_num(float(r.pe), 1) if float(r.pe) < 999.0 else "—", [_num(float(r.peg)) if float(r.peg) > 0.0 and float(r.peg) < 999.0 else "—", _peg_tone(float(r.peg))]])
	_table(list, [["名称", 112, 0], ["现价", 54, 2], ["涨跌", 56, 2], ["市盈率", 42, 2], ["PEG", 42, 2]], rows, picked,
		func(i): firm = FirmCatalog.ORDER[i]; ExchangeScreen.build(menu))
	# Middle: the quote, the chart, the ratios.
	var x := 356.0
	var w := 524.0
	var info := FirmCatalog.info(firm)
	var price_lmd := m.firms.share_price_lmd(firm, m)
	var r := m.firms.ratios(firm, price_lmd)
	var ch := MarketWidgets.change_of(game, "stock:" + firm) if m.stocks.has(firm) else 0.0
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 6)
	AK.put(stage, mid, Vector2(x, TOP + 36), Vector2(w, 0))
	var head := _row(mid, 10)
	head.add_child(AK.label(FirmCatalog.name_of(firm), 18, AK.FG))
	var px := AK.label(KLineChart._fmt(m.stock_price(firm)), 18, _tone(ch), AK.en())
	head.add_child(px)
	var pc := AK.label(_pct(ch), 13, _tone(ch), AK.en())
	pc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(pc)
	for tg in [str(FirmCatalog.TONE_NAMES.get(str(r.class_id), "")), "护城河 %d / 12" % int(r.moat_count)]:
		if tg.is_empty(): continue
		var tag := AK.tag(tg, AK.PLATE_3, false)
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(tag)
	var cur := FirmCatalog.currency(firm)
	_line(mid, "%s  ·  %s  ·  %s" % [str(info.region), str(info.industry), Currencies.name_of(cur) if cur != "gold" else "赤金"], AK.MUTE, 11)
	mid.add_child(ExchangeScreen._seg(ExchangeScreen.PERIOD_NAMES, ExchangeScreen.period, func(i): ExchangeScreen.period = i; ExchangeScreen.build(menu), 10, w))
	var chart := KLineChart.new()
	chart.game = game
	chart.market_id = "stock:" + firm
	chart.period = ExchangeScreen.PERIODS[ExchangeScreen.period]
	chart.custom_minimum_size = Vector2(w, 196)
	mid.add_child(chart)
	var t := _tiles(mid, w)
	_tile(t, "市盈率", _num(float(r.pe), 1))
	_tile(t, "PEG", _num(float(r.peg)), _peg_tone(float(r.peg)))
	_tile(t, "股息调整 PEG", _num(float(r.dpeg)), _peg_tone(float(r.dpeg)))
	_tile(t, "增长", _pct(float(r.growth)), _tone(float(r.growth)))
	_tile(t, "股息率", _pct(float(r.yield)))
	_tile(t, "自由现金流收益率", _pct(float(r.fcf_yield)), _tone(float(r.fcf_yield)))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 3)
	for rule in r.moat:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 6)
		cell.custom_minimum_size.x = (w - 12.0) / 3.0
		var dot := ColorRect.new()
		dot.color = UP if bool(rule[1]) else DOWN
		dot.custom_minimum_size = Vector2(6, 6)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.add_child(dot)
		var nm := AK.label(str(rule[0]), 10, AK.FG if bool(rule[1]) else AK.MUTE)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(nm)
		cell.add_child(AK.label(_compact(float(rule[2])), 10, UP if bool(rule[1]) else DOWN, AK.en()))
		grid.add_child(cell)
	mid.add_child(grid)
	var q: Array = m.firms.f_of(firm).get("quarters", [])
	if not q.is_empty():
		var last: Dictionary = q[-1]
		var c := func(v): return _fmt(Exchange.from_lmd(cur, float(v)))
		var qw := w / 8.0
		_table(mid, [["营收", qw, 2], ["成本", qw, 2], ["费用", qw, 2], ["研发", qw, 2], ["折旧", qw, 2], ["利息", qw, 2], ["净利", qw, 2], ["EPS", qw - 6, 2]],
			[[c.call(last.rev), c.call(last.cogs), c.call(last.sga), c.call(last.rd), c.call(last.dep), c.call(last.interest), [c.call(last.ni), _tone(float(last.ni))], "%.2f" % Exchange.from_lmd(cur, float(last.eps))]])
		_table(mid, [["现金", qw, 2], ["负债", qw, 2], ["权益", qw, 2], ["留存", qw, 2], ["资本开支", qw, 2], ["分红", qw, 2], ["净现金", qw * 2 - 6, 2]],
			[[c.call(last.cash), c.call(last.debt), c.call(last.equity), c.call(last.retained), c.call(last.capex), c.call(last.div), [_fmt(Exchange.from_lmd(cur, float(r.net_cash))), _tone(float(r.net_cash))]]])
	# Right: the order card, the holders, the research note.
	var rx := 890.0
	var held := sec.held(firm)
	var cost := float((sec.shares.get(firm, {}) as Dictionary).get("cost", 0.0))
	var value := held * price_lmd
	var order := _card(stage, Vector2(rx, TOP + 38), Vector2(374, 222), "交易", "ORDER")
	var gain := value / maxf(cost, 1.0) - 1.0 if cost > 0.0 else 0.0
	var t1 := _tiles(order, 350)
	_tile(t1, "持股", _num(held, 1))
	_tile(t1, "市值", _fmt(value))
	var t2 := _tiles(order, 350)
	_tile(t2, "成本", _fmt(cost))
	_tile(t2, "盈亏", _pct(gain), _tone(gain))
	_tile(t2, "占比", "%.2f%%" % (held / maxf(float(m.firms.f_of(firm).get("shares", 1.0)), 1.0) * 100.0))
	ExchangeScreen._number(order, "金额", amount, 0, 5000.0, 0.0, func(v): amount = v; ExchangeScreen.build(menu), "", func(): return float(game.gold))
	var trow := _row(order)
	var why := sec.buy_stock_refusal(firm, amount)
	_btn(trow, "买入" if why.is_empty() else why, why.is_empty(), func(): sec.buy_stock(firm, amount); redo.call(), "blue", 170)
	_btn(trow, "全部卖出", held > 0.0, func(): sec.sell_stock(firm, held); redo.call(), "plain", 170)
	var hold := _card(stage, Vector2(rx, TOP + 268), Vector2(374, 212), "主要持有人", "HOLDERS")
	var hrows: Array = []
	for h in m.firms.holders(m, firm).slice(0, 6): hrows.append([str(h[0]), "%.2f%%" % (float(h[1]) * 100.0)])
	_table(hold, [["持有人", 240, 0], ["占比", 100, 2]], hrows)
	var note := _card(stage, Vector2(rx, TOP + 488), Vector2(374, BOTTOM - TOP - 496), "PRTS 研报", "NOTE")
	for n in m.news.filter(func(n): return str(n.id) == "PRTS研报").slice(-3):  # i18n: skip
		var l := _line(note, str(n.title), AK.CYAN, 11)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 350

# --- 策略 ---------------------------------------------------------------------------------

static func strategies_page(menu: FieldMenu, stage: Control) -> void:
	var game := menu.game
	var ex := game.exchange
	var sts := ex.strategies
	var redo := _redo(menu)
	# Left: the slots.
	var left := _card(stage, Vector2(16, TOP + 38), Vector2(330, BOTTOM - TOP - 46), "策略槽", "SLOTS  %d / %d" % [sts.list.size(), sts.slots()])
	var rows: Array = []
	var picked := -1
	for i in range(sts.list.size()):
		var st: Dictionary = sts.list[i]
		if int(st.id) == strat_pick: picked = i
		var eq := sts.equity(st)
		var ret := eq / maxf(float(st.capital), 1.0) - 1.0
		rows.append([StrategyCatalog.name_of(str(st.tpl)), _fmt(float(st.capital)), _fmt(eq), [_pct(ret), _tone(ret)]])
	for i in range(maxi(0, sts.slots() - sts.list.size())): rows.append([["空槽", AK.DIM], "", "", ""])
	var ids: Array = sts.list.map(func(s): return int(s.id))
	var tips: Array = sts.list.map(func(s): var tp := str(s.tpl); return func(): return strategy_card(game, tp))
	_table(left, [["策略", 100, 0], ["资金", 70, 2], ["净值", 70, 2], ["收益", 66, 2]], rows, picked, func(i):
		if i < ids.size():
			strat_pick = int(ids[i])
			backtest = {}
		ExchangeScreen.build(menu), tips)
	if ex.fin.facility_stopped("strategies"):
		_gap(left, 4)
		left.add_child(AK.tag("欠费暂停", AK.RED, false))
	# Middle: the picked one, or the last backtest.
	var x := 356.0
	var w := 524.0
	var st := sts.get_strategy(strat_pick)
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 6)
	AK.put(stage, mid, Vector2(x, TOP + 38), Vector2(w, 0))
	if not backtest.is_empty():
		var head := _row(mid, 10)
		head.add_child(AK.section("回测", "BACKTEST"))
		var close := AK.button("×", "plain", 12)
		close.custom_minimum_size = Vector2(28, 24)
		close.pressed.connect(func(): backtest = {}; ExchangeScreen.build(menu))
		head.add_child(close)
		_legend(mid, [["策略", AK.HOLO], ["基准", AK.MUTE]])
		_curve(mid, [backtest.equity, backtest.bench], Vector2(w, 240))
		var t := _tiles(mid, w)
		_tile(t, "收益", _pct(float(backtest.ret)), _tone(float(backtest.ret)))
		_tile(t, "最大回撤", _pct(-float(backtest.dd)), DOWN if float(backtest.dd) > 0.0 else AK.FG)
		_tile(t, "成交", str(int(backtest.trades)))
		_tile(t, "胜率", "%.0f%%" % (float(backtest.wins) / maxf(1.0, float(backtest.trades)) * 100.0))
	elif not st.is_empty():
		var eq := sts.equity(st)
		var ret := eq / maxf(float(st.capital), 1.0) - 1.0
		var dd := 1.0 - eq / maxf(float(st.peak), 1.0)
		var head := _row(mid, 10)
		head.add_child(AK.section(StrategyCatalog.name_of(str(st.tpl)), "STRATEGY"))
		var eql := AK.label(_fmt(eq), 16, _tone(ret), AK.en())
		head.add_child(eql)
		_legend(mid, [["策略", AK.HOLO], ["基准", AK.MUTE]])
		_curve(mid, [st.equity, st.bench], Vector2(w, 220))
		var t := _tiles(mid, w)
		_tile(t, "资金", _fmt(float(st.capital)))
		_tile(t, "累计", _pct(ret), _tone(ret))
		_tile(t, "回撤", _pct(-dd), DOWN if dd > 0.0005 else AK.FG)
		_tile(t, "止损", _pct(-float(st.stop_dd)))
		_tile(t, "成交", str(int(st.trades)))
		_tile(t, "胜率", "%.0f%%" % (float(st.wins) / maxf(1.0, float(st.trades)) * 100.0))
		var prow: Array = []
		for mk in st.pos:
			var p: Dictionary = st.pos[mk]
			var short := float(p.qty) < 0.0
			prow.append([_market_name(str(mk)), ["空" if short else "多", DOWN if short else UP], _fmt(absf(float(p.qty)) * sts.price(str(mk)) * sts.unit_lmd(str(mk)))])
		_table(mid, [["持仓", 300, 0], ["方向", 80, 2], ["市值", 130, 2]], prow)
		var sid := int(st.id)
		var srow := _row(mid)
		_btn(srow, "停止", true, func(): sts.stop(sid); strat_pick = -1; redo.call(), "plain", 120)
	# Right: a new one.
	var tpls := StrategyCatalog.ORDER
	var tpl := str(tpls[posmod(tpl_pick, tpls.size())])
	var right := _card(stage, Vector2(890, TOP + 38), Vector2(374, BOTTOM - TOP - 46), "新策略", "NEW")
	var prow2 := _row(right)
	_btn(prow2, "‹", true, func(): tpl_pick -= 1; strat_params = {}; strat_pool = []; ExchangeScreen.build(menu), "plain", 28)
	var tn := TipLabel.new()
	tn.text = StrategyCatalog.name_of(tpl)
	tn.add_theme_font_override("font", AK.cn())
	tn.add_theme_font_size_override("font_size", 14)
	tn.add_theme_color_override("font_color", AK.FG if sts.unlocked(tpl) else AK.MUTE)
	tn.mouse_filter = Control.MOUSE_FILTER_STOP
	tn.tooltip_text = " "
	tn.make = func(): return strategy_card(game, tpl)
	tn.custom_minimum_size.x = 180
	tn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prow2.add_child(tn)
	_btn(prow2, "›", true, func(): tpl_pick += 1; strat_params = {}; strat_pool = []; ExchangeScreen.build(menu), "plain", 28)
	if not sts.unlocked(tpl):
		var lk := AK.tag("未解锁", AK.HAZARD)
		lk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		prow2.add_child(lk)
	if strat_pool.is_empty(): strat_pool = sts.default_pool(tpl)
	_gap(right, 2)
	ExchangeScreen._number(right, "资金", strat_capital, 0, 10000.0, 10000.0, func(v): strat_capital = v; ExchangeScreen.build(menu), "", func(): return float(game.gold))
	_line(right, "有 %s / 需 %s" % [Economy.format(game.gold), Economy.format(roundi(strat_capital))], AK.FG if game.gold >= strat_capital else AK.RED, 11)
	ExchangeScreen._number(right, "止损", strat_dd * 100.0, 0, 5.0, 5.0, func(v): strat_dd = clampf(v / 100.0, 0.05, 0.9); ExchangeScreen.build(menu), "%")
	ExchangeScreen._number(right, "天数", float(strat_days), 0, 1.0, 0.0, func(v): strat_days = int(v); ExchangeScreen.build(menu), "不限" if strat_days == 0 else "天")
	var params: Dictionary = StrategyCatalog.info(tpl).get("params", {})
	if not params.is_empty():
		_gap(right, 2)
		right.add_child(AK.section("参数", "PARAMS"))
	for k in params:
		var spec: Array = params[k]
		var key := str(k)
		var pct := StrategyCatalog.param_is_pct(key)
		var scale := 100.0 if pct else 1.0
		var step := float(spec[3]) * scale
		var dec := StrategyCatalog.decimals(step)
		var cur := float(strat_params.get(k, spec[0])) * scale
		ExchangeScreen._number(right, StrategyCatalog.param_name(tpl, key), cur, dec, step, float(spec[1]) * scale,
			func(v): strat_params[key] = clampf(v / scale, float(spec[1]), float(spec[2])); ExchangeScreen.build(menu), "%" if pct else StrategyCatalog.param_unit(key))
	_gap(right, 2)
	right.add_child(AK.section("标的", "UNIVERSE  %d" % strat_pool.size()))
	var universe := sts.universe(tpl)
	var kind := str(StrategyCatalog.info(tpl).get("universe", "any"))
	if kind in ["stocks", "fx"]:
		# The whole universe: nothing to pick.
		var names: Array = strat_pool.slice(0, 4).map(func(mk): return _market_name(str(mk)))
		var pool := _line(right, "  ".join(names) + ("  …" if strat_pool.size() > 4 else ""), AK.FG, 11)
		pool.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pool.custom_minimum_size.x = 350
	else:
		# 用户 2026-11-14 "换标的用下拉栏选择": one list per place (two for a
		# pair; up to three for any, the 2nd and 3rd may be left empty).
		var places := 1 if kind == "one" else (2 if kind == "pair" else 3)
		for k in range(places):
			var at := k
			var cur := str(strat_pool[k]) if k < strat_pool.size() else ""
			var caption := "标的" if places == 1 else "标的 %d" % (k + 1)
			_dropdown(right, caption, _universe_items(universe, kind == "any" and k > 0), cur, func(id: String):
				var p: Array = strat_pool.duplicate()
				while p.size() <= at: p.append("")
				p[at] = id
				strat_pool = p.filter(func(x): return not str(x).is_empty())
				if strat_pool.is_empty(): strat_pool = sts.default_pool(tpl)
				ExchangeScreen.build(menu))
	_gap(right, 6)
	var arow := _row(right)
	var bwhy := sts.backtest_refusal()
	_btn(arow, "回测" if bwhy.is_empty() else bwhy, bwhy.is_empty(), func(): backtest = sts.backtest(tpl, strat_capital, strat_pool, strat_params); ExchangeScreen.build(menu), "plain", 140)
	var why := sts.create_refusal(tpl, strat_capital)
	_btn(arow, "启动" if why.is_empty() else why, why.is_empty(), func():
		if sts.create(tpl, strat_capital, strat_pool, strat_params, strat_dd, strat_days):
			strat_pick = int(sts.list[-1].id)
			backtest = {}
		redo.call(), "blue", 200)

## The universe as dropdown rows, grouped: [id, name] or ["", group heading].
static func _universe_items(universe: Array, blank: bool) -> Array:
	var groups := {"货物": [], "股票": [], "外汇": []}
	for mk in universe:
		var id := str(mk)
		var g := "股票" if id.begins_with("stock:") else ("外汇" if Currencies.is_fx(id) else "货物")
		(groups[g] as Array).append([id, _market_name(id)])
	var out: Array = []
	if blank: out.append(["-", "—"])
	for g in groups:
		if (groups[g] as Array).is_empty(): continue
		out.append(["", g])
		out.append_array(groups[g])
	return out

## A caption and a dropdown (OptionButton) styled like the terminal's buttons.
static func _dropdown(parent: Control, caption: String, items: Array, current: String, on_pick: Callable) -> OptionButton:
	var row := _row(parent)
	var c := AK.label(caption, 12, AK.MUTE)
	c.custom_minimum_size.x = 64
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(c)
	var ob := OptionButton.new()
	ob.focus_mode = Control.FOCUS_NONE
	ob.fit_to_longest_item = false
	ob.clip_text = true
	ob.custom_minimum_size = Vector2(270, 28)
	ob.add_theme_font_override("font", AK.cn())
	ob.add_theme_font_size_override("font_size", 12)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var b := AK.box(AK.PLATE_3 if st != "hover" else AK.PLATE_3.lightened(0.12), AK.LINE, 1, 0)
		b.content_margin_left = 10
		b.content_margin_right = 26
		ob.add_theme_stylebox_override(st, b)
	ob.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for k in ["font_color", "font_hover_color", "font_pressed_color"]: ob.add_theme_color_override(k, AK.FG)
	var pm := ob.get_popup()
	pm.add_theme_stylebox_override("panel", AK.box(AK.PLATE_SOLID, AK.HOLO, 1, 4))
	pm.add_theme_stylebox_override("hover", AK.box(Color(AK.HOLO.r, AK.HOLO.g, AK.HOLO.b, 0.25)))
	pm.add_theme_font_override("font", AK.cn())
	pm.add_theme_font_size_override("font_size", 12)
	pm.add_theme_font_override("font_separator", AK.cn())
	pm.add_theme_font_size_override("font_separator_size", 11)
	pm.add_theme_color_override("font_color", AK.FG)
	pm.add_theme_color_override("font_hover_color", AK.FG)
	pm.add_theme_color_override("font_separator_color", AK.HOLO)
	# The goods list runs past the screen: at most 400 high, opening under the
	# button (above it when there is no room below), the rest scrolls.
	pm.max_size = Vector2i(800, 400)
	pm.about_to_popup.connect(func(): _fit_popup.call_deferred(ob, pm))
	var picked := -1
	for it in items:
		if str(it[0]).is_empty():
			ob.add_separator(str(it[1]))
			continue
		ob.add_item(str(it[1]))
		var idx := ob.item_count - 1
		ob.set_item_metadata(idx, str(it[0]))
		if str(it[0]) == current or (current.is_empty() and str(it[0]) == "-"): picked = idx
	if picked >= 0: ob.select(picked)
	ob.disabled = not ExchangeScreen._blocked.is_empty()
	ob.item_selected.connect(func(i: int):
		var id := str(ob.get_item_metadata(i))
		on_pick.call("" if id == "-" else id))
	row.add_child(ob)
	return ob

static func _fit_popup(ob: OptionButton, pm: PopupMenu) -> void:
	if not is_instance_valid(ob) or not pm.visible: return
	var h := mini(pm.size.y, 400)
	pm.size = Vector2i(maxi(pm.size.x, int(ob.size.x)), h)
	if pm.is_embedded():
		# A subwindow of the game's viewport: its coordinates are the canvas's.
		var r := ob.get_global_rect()
		var room := ob.get_viewport().get_visible_rect()
		var y := r.end.y if r.end.y + h <= room.end.y else r.position.y - h
		pm.position = Vector2i(int(r.position.x), int(maxf(room.position.y, y)))
		return
	var win := ob.get_window()
	var scale := Vector2(win.size) / Vector2(win.content_scale_size) if win.content_scale_size.x > 0 else Vector2.ONE
	var top := Vector2i(ob.get_screen_position())
	var hp := int(h * scale.y)
	var bottom := mini(DisplayServer.screen_get_usable_rect(win.current_screen).end.y, win.position.y + win.size.y)
	var y2 := top.y + int(ob.size.y * scale.y)
	pm.position = Vector2i(top.x, y2 if y2 + hp <= bottom else top.y - hp)

static func _market_name(mk: String) -> String:
	if mk.begins_with("stock:"): return FirmCatalog.name_of(mk.substr(6))
	return Exchange.cfd_name(mk)
