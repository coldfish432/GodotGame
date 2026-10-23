class_name MarketWidgets
extends RefCounted

## Live pieces of the exchange screens: they read MarketState / Exchange on
## their own, so prices move without rebuilding the page (§5).

## A label whose text comes from `provider` every half second.
class LiveText extends Label:
	var provider := Callable()
	var colour_provider := Callable()
	var _wait := 0.0

	func _ready() -> void:
		_refresh()

	func _process(delta: float) -> void:
		_wait -= delta
		if _wait <= 0.0:
			_wait = 0.5
			_refresh()

	func _refresh() -> void:
		if provider.is_valid(): text = str(provider.call())
		if colour_provider.is_valid(): add_theme_color_override("font_color", colour_provider.call())

static func live(provider: Callable, font_size: int = 13, colour: Color = AK.FG, colour_provider: Callable = Callable()) -> LiveText:
	var l := LiveText.new()
	l.provider = provider
	l.colour_provider = colour_provider
	l.add_theme_font_override("font", AK.cn())
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", colour)
	return l

## The market list (§6 左栏): one row per market, price, the day's change and a
## sparkline. Click picks; the wheel scrolls.
class MarketList extends Control:
	const ROW := 46.0
	var game: GameManager
	var ids: Array = []
	var selected := ""
	var on_pick := Callable()
	var scroll := 0.0
	var _wait := 0.0
	## A name scrolled this draw: redraw every frame, not twice a second.
	var _marquee := false
	## The name band ends this far from the right edge (the sparkline starts at 170).
	const NAME_END := 186.0
	const SPEED := 30.0     # px a second
	const GAP := 40.0
	const PAUSE := 1.5      # s at the start of each lap

	func _ready() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _process(delta: float) -> void:
		_wait -= delta
		if _marquee or _wait <= 0.0:
			_wait = 0.5
			_marquee = false
			queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			match event.button_index:
				MOUSE_BUTTON_WHEEL_UP: scroll = maxf(0.0, scroll - ROW)
				MOUSE_BUTTON_WHEEL_DOWN: scroll = clampf(scroll + ROW, 0.0, maxf(0.0, ids.size() * ROW - size.y))
				MOUSE_BUTTON_LEFT:
					var k := int((event.position.y + scroll) / ROW)
					if k >= 0 and k < ids.size() and on_pick.is_valid(): on_pick.call(ids[k])
			queue_redraw()
			accept_event()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), AK.PLATE_2)
		if game == null: return
		var market := game.market
		for k in range(ids.size()):
			var y := k * ROW - scroll
			if y + ROW < 0 or y > size.y: continue
			var id: String = ids[k]
			if id == selected: draw_rect(Rect2(0, y, size.x, ROW - 2), Color("313a41"))
			else: draw_rect(Rect2(0, y + ROW - 2, size.x, 1), AK.LINE)
			var name := Exchange.cfd_name(id)
			var price := game.exchange.cfd_price(id)
			var change := MarketWidgets.change_of(game, id)
			var col := KLineChart.UP if change >= 0.0 else KLineChart.DOWN
			# The name keeps left of the sparkline; a long one scrolls (用户 2026-10-23: 不挡简略k线图，改为滚动字幕).
			var room := size.x - NAME_END
			var text := I18n.t(name)
			var width := AK.cn().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			if width <= room:
				draw_string(AK.cn(), Vector2(10, y + 18), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, AK.FG)
			else:
				_marquee = true
				var lap := width + GAP
				var t := fmod(Time.get_ticks_msec() / 1000.0, PAUSE + lap / SPEED)
				var x := 10.0 - maxf(0.0, t - PAUSE) * SPEED
				draw_string(AK.cn(), Vector2(x, y + 18), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, AK.FG)
				draw_string(AK.cn(), Vector2(x + lap, y + 18), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, AK.FG)
				# Mask what runs past the name's band, in the row's own colour.
				var bg := Color("313a41") if id == selected else AK.PLATE_2
				draw_rect(Rect2(0, y + 2, 10, 20), bg)
				draw_rect(Rect2(10 + room, y + 2, size.x - 10 - room, 20), bg)
			var sub := MarketWidgets.status_of(game, id)
			draw_string(AK.cn(), Vector2(10, y + 36), I18n.t(sub), HORIZONTAL_ALIGNMENT_LEFT, room, 10, AK.MUTE)
			draw_string(AK.en(), Vector2(size.x - 104, y + 18), KLineChart._fmt(price), HORIZONTAL_ALIGNMENT_RIGHT, 96, 13, AK.FG)
			draw_string(AK.en(), Vector2(size.x - 104, y + 36), "%+.2f%%" % (change * 100.0), HORIZONTAL_ALIGNMENT_RIGHT, 96, 11, col)
			MarketWidgets.sparkline(self, game, id, Rect2(size.x - 170, y + 8, 60, ROW - 18), col)

## Day change of a market, or of a faction composite.
static func change_of(game: GameManager, id: String) -> float:
	if id.begins_with("comp:"):
		var faction := id.substr(5)
		var total := 0.0
		var n := 0
		for m in game.market.books:
			if FactionCatalog.split(m)[0] == faction:
				total += game.market.change(m)
				n += 1
		return total / maxf(n, 1)
	return game.market.change(id)

## Currency and state under a market's name: 赤金计价 · 活跃 / 盘口薄 / 暂停收货.
static func status_of(game: GameManager, id: String) -> String:
	if id == FactionCatalog.FX: return "全天"
	var faction: String = id.substr(5) if id.begins_with("comp:") else FactionCatalog.split(id)[0]
	var parts: Array[String] = ["赤金" if FactionCatalog.currency(faction) == "gold" else "龙门币"]
	if not id.begins_with("comp:") and game.market.halted(id): parts.append("暂停收货")
	elif game.market.active(faction): parts.append("活跃")
	else: parts.append("盘口薄")
	if FactionCatalog.info(faction).get("field_only", false): parts.append("局内据点")
	return " · ".join(parts)

static func sparkline(canvas: CanvasItem, game: GameManager, id: String, rect: Rect2, col: Color) -> void:
	var src := id
	if id.begins_with("comp:"):
		for m in game.market.books:
			if FactionCatalog.split(m)[0] == id.substr(5):
				src = m
				break
	var data := game.market.candles(src, "1m", 30)
	if data.size() < 2: return
	var lo := INF
	var hi := -INF
	for c in data:
		lo = minf(lo, float(c[3]))
		hi = maxf(hi, float(c[3]))
	var span := maxf(hi - lo, 0.0001)
	var pts := PackedVector2Array()
	for k in range(data.size()):
		pts.append(Vector2(rect.position.x + rect.size.x * k / (data.size() - 1), rect.end.y - (float(data[k][3]) - lo) / span * rect.size.y))
	canvas.draw_polyline(pts, col, 1.0)

## The base watch window (§6.4): up to four markets of the watch list, in the
## corner of the screen. Only at the base (用户: 局内不能看行情).
class WatchWidget extends Control:
	var game: GameManager
	var _wait := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_wait -= delta
		if _wait <= 0.0:
			_wait = 0.5
			queue_redraw()

	func _draw() -> void:
		if game == null: return
		var ids: Array = game.exchange.watch.slice(0, 4)
		if ids.is_empty(): ids = [FactionCatalog.FX]
		var h := 20.0 + ids.size() * 34.0
		draw_rect(Rect2(0, 0, size.x, h), Color(0, 0, 0, 0.6))
		draw_string(AK.en(), Vector2(10, 14), "WATCH · PRTS", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, AK.MUTE)
		for k in range(ids.size()):
			var id: String = ids[k]
			var y := 20.0 + k * 34.0
			var change := MarketWidgets.change_of(game, id)
			var col := KLineChart.UP if change >= 0.0 else KLineChart.DOWN
			draw_string(AK.cn(), Vector2(10, y + 14), I18n.t(Exchange.cfd_name(id)), HORIZONTAL_ALIGNMENT_LEFT, size.x - 90, 12, AK.FG)
			draw_string(AK.en(), Vector2(size.x - 84, y + 14), KLineChart._fmt(game.exchange.cfd_price(id)), HORIZONTAL_ALIGNMENT_RIGHT, 76, 12, AK.FG)
			draw_string(AK.en(), Vector2(size.x - 84, y + 28), "%+.2f%%" % (change * 100.0), HORIZONTAL_ALIGNMENT_RIGHT, 76, 10, col)
			MarketWidgets.sparkline(self, game, id, Rect2(10, y + 18, size.x - 110, 12), col)

## The world state (态势): twelve factors in two columns, a bar each way from 0.
class FactorBars extends Control:
	var game: GameManager
	var _wait := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_wait -= delta
		if _wait <= 0.0:
			_wait = 1.0
			queue_redraw()

	func _draw() -> void:
		if game == null: return
		var keys: Array = MarketLinks.FACTORS.keys()
		var col_w := size.x / 2.0
		for k in range(keys.size()):
			var f: String = keys[k]
			var x := (k / 6) * col_w
			var y := (k % 6) * 22.0
			var v := game.market.factor(f)
			draw_string(AK.cn(), Vector2(x, y + 14), I18n.t(MarketLinks.FACTORS[f]), HORIZONTAL_ALIGNMENT_LEFT, 84, 11, AK.MUTE)
			var bar := Rect2(x + 88, y + 6, col_w - 100, 8)
			draw_rect(bar, Color(1, 1, 1, 0.06))
			var mid := bar.position.x + bar.size.x / 3.0
			draw_line(Vector2(mid, bar.position.y - 2), Vector2(mid, bar.end.y + 2), AK.DIM)
			var span := bar.size.x / 3.0 * clampf(v, -1.0, 2.0)
			var col := AK.RED if v > 1.0 else (AK.SP if v > 0.0 else AK.CYAN)
			if span >= 0.0: draw_rect(Rect2(mid, bar.position.y, span, bar.size.y), col)
			else: draw_rect(Rect2(mid + span, bar.position.y, -span, bar.size.y), col)
