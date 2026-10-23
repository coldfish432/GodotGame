class_name TickerView
extends Control

## B, the ticker (交易终端与盯盘小窗策划案_v1_0.md §2): a small window that stays
## on top — the rate, the watch list, the account in one line, the latest news,
## and three buttons. It only looks; trading is in the terminal.

const SIZE := Vector2i(380, 560)
const HEAD := 36.0
const ROW := 38.0
const ROWS := 8
const PAD := 12.0

var game: GameManager
var _wait := 0.0
var _dragging := false
var _drag_from := Vector2i.ZERO
var _on_top := true

func _ready() -> void:
	position = Vector2.ZERO
	size = Vector2(SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	bar.position = Vector2(PAD, SIZE.y - 42)
	bar.size = Vector2(SIZE.x - PAD * 2, 32)
	add_child(bar)
	var open := AK.button("打开终端", "blue", 13)
	open.custom_minimum_size = Vector2(150, 32)
	open.pressed.connect(func(): game.launch_app("exchange"))
	bar.add_child(open)
	var top := AK.button("置顶 ✓", "plain", 13)
	top.custom_minimum_size = Vector2(90, 32)
	top.pressed.connect(func():
		_on_top = not _on_top
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, _on_top)
		top.text = "置顶 ✓" if _on_top else "置顶")
	bar.add_child(top)
	var close := AK.button("关闭", "plain", 13)
	close.custom_minimum_size = Vector2(90, 32)
	close.pressed.connect(func(): get_tree().quit())
	bar.add_child(close)

func _process(delta: float) -> void:
	_wait -= delta
	if _wait <= 0.0:
		_wait = 0.5
		queue_redraw()
	if _dragging:
		DisplayServer.window_set_position(DisplayServer.mouse_get_position() - _drag_from)

## Dragging the head moves the window (it has no frame).
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and event.position.y < HEAD:
			_dragging = true
			_drag_from = DisplayServer.mouse_get_position() - DisplayServer.window_get_position()
		elif not event.pressed:
			_dragging = false

## What the list shows: the rate, then the watch list (or the composites when
## nothing is watched).
func ids() -> Array:
	var out: Array = [FactionCatalog.FX]
	var ex := game.exchange
	var watched: Array = ex.watch.filter(func(w): return w != FactionCatalog.FX)
	if watched.is_empty():
		for f in FactionCatalog.trading():
			if not FactionCatalog.info(f).get("field_only", false): watched.append("comp:" + f)
	for w in watched:
		if out.size() >= ROWS: break
		out.append(w)
	return out

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), AK.PLATE_2)
	draw_rect(Rect2(0, 0, size.x, HEAD), Color("0d1013"))
	draw_rect(Rect2(0, HEAD - 2, size.x, 2), AK.HOLO)
	if game == null: return
	var font := AK.cn()
	draw_string(font, Vector2(PAD, 24), I18n.t("罗德岛盯盘"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, AK.FG)
	var state := game.trade_block() if not game.writer() else "实时"
	draw_string(font, Vector2(size.x - 160 - PAD, 24), I18n.t(state), HORIZONTAL_ALIGNMENT_RIGHT, 160, 11, AK.MUTE)
	var y := HEAD + 6
	for id in ids():
		var price := game.exchange.cfd_price(id)
		var change := MarketWidgets.change_of(game, id)
		var col := KLineChart.UP if change >= 0.0 else KLineChart.DOWN
		draw_string(font, Vector2(PAD, y + 16), I18n.t(Exchange.cfd_name(id)), HORIZONTAL_ALIGNMENT_LEFT, 170, 12, AK.FG)
		draw_string(font, Vector2(PAD, y + 31), I18n.t(MarketWidgets.status_of(game, id)), HORIZONTAL_ALIGNMENT_LEFT, 170, 9, AK.MUTE)
		MarketWidgets.sparkline(self, game, id, Rect2(190, y + 6, 70, ROW - 14), col)
		draw_string(AK.en(), Vector2(size.x - 104 - PAD, y + 16), KLineChart._fmt(price), HORIZONTAL_ALIGNMENT_RIGHT, 104, 13, AK.FG)
		draw_string(AK.en(), Vector2(size.x - 104 - PAD, y + 31), "%+.2f%%" % (change * 100.0), HORIZONTAL_ALIGNMENT_RIGHT, 104, 10, col)
		draw_rect(Rect2(PAD, y + ROW - 1, size.x - PAD * 2, 1), AK.LINE)
		y += ROW
	# The account in one line: margin, floating, warnings.
	y = HEAD + 6 + ROWS * ROW + 6
	var ex := game.exchange
	var warned := 0
	for p in ex.forwards + ex.cfds:
		if p.get("warned", false): warned += 1
	var pnl := ex.floating()
	draw_string(font, Vector2(PAD, y + 14), I18n.t("保证金") + " " + Economy.format(roundi(ex.margin_total())), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, AK.FG)
	draw_string(font, Vector2(150, y + 14), I18n.t("浮动盈亏") + " " + ("+" if pnl >= 0 else "") + Economy.format(roundi(pnl)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, KLineChart.UP if pnl >= 0 else KLineChart.DOWN)
	if warned > 0: draw_string(font, Vector2(size.x - 80 - PAD, y + 14), I18n.t("预警") + " %d" % warned, HORIZONTAL_ALIGNMENT_RIGHT, 80, 12, AK.RED)
	# The latest news.
	y += 26
	var news: Array = game.market.news.slice(maxi(0, game.market.news.size() - 3))
	news.reverse()
	for n in news:
		draw_string(font, Vector2(PAD, y + 13), I18n.t(str(n.title)), HORIZONTAL_ALIGNMENT_LEFT, size.x - PAD * 2, 11, AK.CYAN if n.get("unread", false) else AK.MUTE)
		y += 18
