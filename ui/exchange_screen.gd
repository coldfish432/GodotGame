class_name ExchangeScreen
extends RefCounted

## The exchange terminal (喀兰贸易, 势力与交易所策划案_v0_7.md §6), 加工部's
## workshop (§2), and a faction's post in the field (§12). Laid out after
## 《FX 简单!》: account on top, market list left, the chart in the middle,
## the order panel right. Data, state and buttons only (用户: 界面不写说明文字).

const TABS := ["行情", "持仓", "新闻", "资金"]
const PERIODS := ["1m", "5m", "15m", "1h", "4h", "1d", "1w"]
const PERIOD_NAMES := ["1分", "5分", "15分", "1时", "4时", "日", "周"]
const FILTERS := ["全部", "自选", "龙门币", "赤金", "指数"]
const MODES := ["现货", "挂单", "远期", "差价"]
const TOP := BaseScreens.TOP
const BOTTOM := BaseScreens.BOTTOM

static var tab := 0
static var selected := FactionCatalog.FX
static var period := 2
static var filter := 0
static var mode := 0
# Order panel state.
static var pick := 0
static var order_kind := 0          # 0 限价卖, 1 止损卖, 2 限价买, 3 条件卖
static var order_term := 1
static var order_offset := 0.0      # % from the current price
static var qty := 5
static var fwd_material := 0
static var fwd_deliver := true
static var fwd_term := 1
static var lev := 1
static var cfd_dir := 1
static var cfd_margin := 5000.0
static var fx_amount := 10000
static var bars := 1
static var ship_pick := 0
static var ship_to := 0

## A compact segmented control: AK.toggle's look, sized to fit `width`.
static func _seg(names: Array, current: int, on_pick: Callable, size: int = 12, width: float = 0.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	var each := (width / names.size()) if width > 0.0 else maxf(44.0, 12.0 + size * 0.62 * 4)
	for i in range(names.size()):
		var b := AK.button(str(names[i]), "paper" if i == current else "plain", size)
		b.custom_minimum_size = Vector2(each, 28)
		b.clip_text = true
		var index := i
		b.pressed.connect(func(): on_pick.call(index))
		row.add_child(b)
	return row

static func _redraw(menu: FieldMenu) -> void:
	build(menu)

static func build(menu: FieldMenu) -> void:
	var game := menu.game
	var ex := game.exchange
	var stage := BaseScreens.shell(menu, "交易所", "EXCHANGE · KARLAN TRADE", TABS, tab, func(i):
		tab = i
		if i == 2: game.market.mark_read()
		build(menu), "MARKET",
		[["lmd", Economy.format(game.gold)], ["gold", "%.2f" % ex.gold_account]])
	_account_bar(stage, game)
	if not ex.unlocked():
		AK.put(stage, AK.label("喀兰贸易关系 R1", 18, AK.MUTE), Vector2(560, 360))
		return
	match tab:
		0: _market_page(menu, stage)
		1: _positions_page(menu, stage)
		2: _news_page(menu, stage)
		3: _money_page(menu, stage)

static func _account_bar(stage: Control, game: GameManager) -> void:
	var ex := game.exchange
	stage.add_child(AK.rect(AK.PLATE_2, Vector2(16, TOP), Vector2(1248, 30)))
	var line := MarketWidgets.live(func():
		return "龙门币 %s   赤金账户 %.2f   待还贷款 %s   保证金 %s   浮动盈亏 %s   账户总值 %s   龙门币 / 赤金 %.1f" % [
			Economy.format(game.gold), ex.gold_account, Economy.format(ex.loan), Economy.format(roundi(ex.margin_total())),
			("+" if ex.floating() >= 0 else "") + Economy.format(roundi(ex.floating())), Economy.format(roundi(ex.account_value())), Economy.fx], 13)
	AK.put(stage, line, Vector2(28, TOP + 6))

# --- 行情 -------------------------------------------------------------------------------

static func _list_ids(game: GameManager) -> Array:
	var out: Array = []
	match filter:
		1: out = game.exchange.watch.duplicate()
		4:
			for f in FactionCatalog.trading():
				if not FactionCatalog.info(f).get("field_only", false): out.append("comp:" + f)
		_:
			out.append(FactionCatalog.FX)
			for m in game.market.books:
				if m == FactionCatalog.FX: continue
				var cur := FactionCatalog.currency(FactionCatalog.split(m)[0])
				if filter == 2 and cur != "lmd": continue
				if filter == 3 and cur != "gold": continue
				out.append(m)
	return out

static func _market_page(menu: FieldMenu, stage: Control) -> void:
	var game := menu.game
	AK.put(stage, _seg(FILTERS, filter, func(i): filter = i; build(menu), 11, 330.0), Vector2(16, TOP + 36))
	var list := MarketWidgets.MarketList.new()
	list.game = game
	list.ids = _list_ids(game)
	list.selected = selected
	list.on_pick = func(id): selected = id; pick = 0; fwd_material = 0; build(menu)
	AK.put(stage, list, Vector2(16, TOP + 78), Vector2(330, BOTTOM - TOP - 78))
	# Chart.
	var x := 356.0
	AK.put(stage, AK.label(Exchange.cfd_name(selected), 18, AK.FG), Vector2(x, TOP + 38))
	var star := AK.button("★ 自选" if game.exchange.watch.has(selected) else "☆ 自选", "plain", 11)
	star.pressed.connect(func(): game.exchange.toggle_watch(selected); game.save_base(); build(menu))
	AK.put(stage, star, Vector2(x + 510, TOP + 38), Vector2(80, 26))
	AK.put(stage, _seg(PERIOD_NAMES, period, func(i): period = i; build(menu), 10, 590.0), Vector2(x, TOP + 70))
	var chart := KLineChart.new()
	chart.game = game
	chart.market_id = selected
	chart.period = PERIODS[period]
	AK.put(stage, chart, Vector2(x, TOP + 104), Vector2(590, 330))
	var info := MarketWidgets.live(func(): return _quote_line(game), 12, AK.MUTE)
	AK.put(stage, info, Vector2(x, TOP + 440))
	var ticker := MarketWidgets.live(func():
		var n: Array = game.market.news
		return ("PRTS 快讯：" + str(n[-1].title)) if not n.is_empty() else "", 12, AK.CYAN)
	AK.put(stage, ticker, Vector2(x, TOP + 462))
	_recent_news(stage, game, Vector2(x, TOP + 490), 590, 5)
	_order_panel(menu, stage, Vector2(956, TOP + 36))

static func _quote_line(game: GameManager) -> String:
	var m := game.market
	if selected == FactionCatalog.FX: return "龙门币 / 赤金 %.1f   换汇价差 %.1f%%   本日 %+.2f%%" % [m.fx_rate(), Economy.EXCHANGE_FX_SPREAD * 100, m.change(selected) * 100]
	if selected.begins_with("comp:"): return "综合指数 %.2f   本日 %+.2f%%" % [game.exchange.cfd_price(selected), MarketWidgets.change_of(game, selected) * 100]
	var faction: String = FactionCatalog.split(selected)[0]
	return "买 %.2f   卖 %.2f   价差 %.1f%%   深度 %s   手续费 %.1f%%   额度 %s   %s" % [m.bid(selected) * 100, m.ask(selected) * 100, m.spread(selected) * 100,
		Economy.format(roundi(m.depth(selected))), game.exchange.remote_fee(faction, selected) * 100, Economy.format(roundi(game.exchange.quota_left(faction))),
		"暂停收货" if m.halted(selected) else ("活跃" if m.active(faction) else "盘口薄")]

static func _recent_news(stage: Control, game: GameManager, at: Vector2, width: float, count: int) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var news: Array = game.market.news.slice(maxi(0, game.market.news.size() - count))
	news.reverse()
	for n in news: box.add_child(_news_row(game, n, width))
	AK.put(stage, box, at, Vector2(width, 0))

static func _news_row(game: GameManager, n: Dictionary, width: float) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var colour: Color = {"swan": AK.RED, "announce": AK.SP, "rumor": AK.SPECIAL, "flash": AK.GREEN}.get(str(n.kind), AK.CYAN)
	var when := Time.get_datetime_string_from_unix_time(MarketState.local(int(n.t)), true).substr(5, 11)
	row.add_child(AK.label(when, 11, AK.MUTE, AK.en()))
	row.add_child(AK.tag(MarketEvents.KIND_NAMES.get(str(n.kind), "快讯") if str(n.kind) != "flash" else "限时", colour))
	var title := str(n.title)
	# Which markets it moves, and which way (§6.1: 方向箭头).
	var moves: Dictionary = n.get("moves", {})
	var arrows: Array[String] = []
	for m in moves.keys().slice(0, 3):
		arrows.append(("%s %s" % [FactionCatalog.market_name(m), "↑" if int(moves[m]) > 0 else "↓"]))
	if moves.size() > 3: arrows.append("…")
	if not arrows.is_empty(): title += "  ·  " + "  ".join(arrows)
	if not str(n.get("cred", "")).is_empty(): title += "  ·  可信度 " + str(n.cred)
	if not str(n.get("status", "")).is_empty(): title += "  ·  " + str(n.status)
	if not str(n.get("cause", "")).is_empty(): title += "  ·  ← " + str(n.cause)
	var l := AK.label(title, 12, AK.FG if n.get("unread", false) else AK.MUTE)
	l.clip_text = true
	l.custom_minimum_size.x = width - 150
	row.add_child(l)
	return row

# --- The order panel ----------------------------------------------------------------------

static func _order_panel(menu: FieldMenu, stage: Control, at: Vector2) -> void:
	var game := menu.game
	stage.add_child(AK.rect(AK.PLATE_2, at, Vector2(308, BOTTOM - at.y)))
	AK.put(stage, _seg(MODES, mode, func(i): mode = i; build(menu), 12, 292.0), at + Vector2(8, 8))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	AK.put(stage, body, at + Vector2(10, 52), Vector2(288, 0))
	match mode:
		0: _spot_form(menu, body)
		1: _order_form(menu, body)
		2: _forward_form(menu, body)
		3: _cfd_form(menu, body)
	# Alerts at ±2% of now.
	var alert := HBoxContainer.new()
	for op in [">=", "<="]:
		var b := AK.button("提醒 %s %.1f" % [op, game.exchange.cfd_price(selected) * (1.02 if op == ">=" else 0.98)], "plain", 11)
		var chosen_op: String = op
		b.pressed.connect(func():
			game.exchange.add_alert(selected, chosen_op, game.exchange.cfd_price(selected) * (1.02 if chosen_op == ">=" else 0.98))
			game.save_base()
			build(menu))
		alert.add_child(b)
	AK.put(stage, alert, Vector2(at.x + 10, BOTTOM - 40))

static func _faction() -> String:
	if selected == FactionCatalog.FX: return ""
	if selected.begins_with("comp:"): return selected.substr(5)
	return FactionCatalog.split(selected)[0]

static func _category() -> String:
	return "" if selected == FactionCatalog.FX or selected.begins_with("comp:") else FactionCatalog.split(selected)[1]

static func _stepper(parent: Node, caption: String, value: String, on_minus: Callable, on_plus: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var c := AK.label(caption, 12, AK.MUTE)
	c.custom_minimum_size.x = 64
	row.add_child(c)
	var minus := AK.button("−", "plain", 13)
	minus.custom_minimum_size = Vector2(30, 26)
	minus.pressed.connect(on_minus)
	row.add_child(minus)
	var v := AK.label(value, 13, AK.FG, AK.en())
	v.custom_minimum_size.x = 120
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(v)
	var plus := AK.button("+", "plain", 13)
	plus.custom_minimum_size = Vector2(30, 26)
	plus.pressed.connect(on_plus)
	row.add_child(plus)
	parent.add_child(row)

static func _go(parent: Node, text: String, enabled: bool, on_press: Callable, kind: String = "blue") -> void:
	var b := AK.button(text, kind if enabled else "plain", 13)
	b.custom_minimum_size = Vector2(288, 34)
	b.disabled = not enabled
	b.pressed.connect(on_press)
	parent.add_child(b)

static func _matching_items(game: GameManager, category: String) -> Array[Item]:
	var out: Array[Item] = []
	for item in game.deliverable_items():
		if FactionCatalog.category_of(item) == category: out.append(item)
	return out

static func _spot_form(menu: FieldMenu, body: VBoxContainer) -> void:
	var game := menu.game
	var ex := game.exchange
	if selected == FactionCatalog.FX or selected.begins_with("comp:"):
		body.add_child(AK.label("资金页换汇", 12, AK.MUTE))
		return
	var faction := _faction()
	var category := _category()
	body.add_child(AK.section("卖给" + FactionCatalog.name_of(faction), "SELL"))
	var items := _matching_items(game, category)
	if items.is_empty(): body.add_child(AK.label("可卖 0", 12, AK.MUTE))
	for item in items.slice(0, 5):
		var q := ex.quote_sell(item, faction, true)
		var b := AK.button("%s  →  %s" % [item.display_name() + item.stack_suffix(), Exchange.format_money(str(q.currency), float(q.net)) if q.ok else str(q.why)], "plain", 11)
		b.custom_minimum_size = Vector2(288, 30)
		b.disabled = not q.ok
		var chosen: Item = item
		b.pressed.connect(func():
			if ex.sell_item(chosen, faction, true): game.save_base()
			build(menu))
		body.add_child(b)
	body.add_child(AK.section("买入", "BUY"))
	var shelf: Array = FactionCatalog.info(faction).get("sells", [])
	for material in shelf:
		if FactionCatalog.material_category(material) != category and shelf.size() > 3: continue
		var q := ex.quote_buy(faction, material)
		if not q.ok: continue
		var row := HBoxContainer.new()
		var l := AK.label("%s  %s" % [material, Exchange.format_money(str(q.currency), float(q.unit))], 11, AK.FG)
		l.custom_minimum_size.x = 170
		row.add_child(l)
		for n in [1, 5]:
			var b := AK.button("×%d" % n, "plain", 11)
			var chosen_material: String = material
			var count: int = n
			b.pressed.connect(func():
				if ex.buy_material(faction, chosen_material, count): game.save_base()
				build(menu))
			row.add_child(b)
		body.add_child(row)
	# Flash offers on this faction.
	for offer in game.market.flash:
		if offer.faction != faction: continue
		var tag := "限时%s %s ×%.2f" % ["收购" if offer.kind == "buy" else "抛售", FactionCatalog.CATEGORIES.get(offer.get("category", ""), str(offer.get("material", ""))), float(offer.mult)]
		body.add_child(MarketWidgets.live(func(): return "%s   %ds" % [tag, maxi(0, int(offer.until) - game.market.t)], 12, AK.GREEN))
		if offer.kind == "buy":
			for item in _matching_items(game, str(offer.category)).slice(0, 3):
				var chosen: Item = item
				var id := int(offer.id)
				_go(body, "卖出 %s" % item.display_name(), true, func():
					if ex.sell_to_flash(id, chosen): game.save_base()
					build(menu), "yellow")
		else:
			var id := int(offer.id)
			_go(body, "买入 %s ×5" % offer.material, true, func():
				if ex.buy_from_flash(id, 5): game.save_base()
				build(menu), "yellow")

static func _order_form(menu: FieldMenu, body: VBoxContainer) -> void:
	var game := menu.game
	var ex := game.exchange
	if selected == FactionCatalog.FX or selected.begins_with("comp:"):
		body.add_child(AK.label("选择商品市场", 12, AK.MUTE))
		return
	var faction := _faction()
	var category := _category()
	body.add_child(_seg(["限价卖", "止损卖", "限价买", "条件卖"], order_kind, func(i): order_kind = i; build(menu), 11, 288.0))
	var now := game.market.price(selected)
	var price := now * (1.0 + order_offset / 100.0)
	_stepper(body, "价格", "%.2f (%+.0f%%)" % [price, order_offset], func(): order_offset -= 1.0; build(menu), func(): order_offset += 1.0; build(menu))
	body.add_child(_seg(["当日", "1日", "3日", "7日", "结算"], order_term, func(i): order_term = i; build(menu), 10, 288.0))
	var term: String = ["session", "1d", "3d", "7d", "settle"][order_term]
	if order_kind == 2:
		var shelf: Array = FactionCatalog.info(faction).get("sells", [])
		if shelf.is_empty():
			body.add_child(AK.label("不出售", 12, AK.MUTE))
			return
		var material: String = shelf[posmod(pick, shelf.size())]
		_stepper(body, "商品", material, func(): pick -= 1; build(menu), func(): pick += 1; build(menu))
		_stepper(body, "数量", str(qty), func(): qty = maxi(1, qty - 1); build(menu), func(): qty += 1; build(menu))
		_go(body, "挂单", true, func():
			if ex.place_buy_order(faction, material, qty, price, term): game.save_base()
			build(menu))
		return
	var items := _matching_items(game, category)
	if items.is_empty():
		body.add_child(AK.label("可卖 0", 12, AK.MUTE))
		return
	var item: Item = items[posmod(pick, items.size())]
	_stepper(body, "物品", item.display_name() + item.stack_suffix(), func(): pick -= 1; build(menu), func(): pick += 1; build(menu))
	if order_kind == 3:
		var watched: Array = ex.watch.filter(func(w): return game.market.books.has(w))
		if watched.is_empty():
			body.add_child(AK.label("自选 0", 12, AK.MUTE))
			return
		var w: String = watched[0]
		body.add_child(AK.label("条件：%s ≥ %.2f" % [FactionCatalog.market_name(w), game.market.price(w) * (1.0 + order_offset / 100.0)], 11, AK.FG))
		_go(body, "挂条件单", true, func():
			if ex.place_conditional(w, ">=", game.market.price(w) * (1.0 + order_offset / 100.0), item, faction, term): game.save_base()
			build(menu))
		return
	var kind := "limit" if order_kind == 0 else "stop"
	_go(body, "挂单", true, func():
		if ex.place_sell_order(item, faction, kind, price, term): game.save_base()
		build(menu))

static func _forward_form(menu: FieldMenu, body: VBoxContainer) -> void:
	var game := menu.game
	var ex := game.exchange
	var faction := _faction()
	if faction.is_empty():
		body.add_child(AK.label("选择势力市场", 12, AK.MUTE))
		return
	var materials := ex.forward_materials(faction)
	if materials.is_empty():
		body.add_child(AK.label("不签合约", 12, AK.MUTE))
		return
	var material: String = materials[posmod(fwd_material, materials.size())]
	_stepper(body, "商品", material, func(): fwd_material -= 1; build(menu), func(): fwd_material += 1; build(menu))
	body.add_child(_seg(["交货合约", "收货合约"], 0 if fwd_deliver else 1, func(i): fwd_deliver = i == 0; build(menu), 11, 288.0))
	body.add_child(_seg(Exchange.TERM_NAMES, fwd_term, func(i): fwd_term = i; build(menu), 10, 288.0))
	body.add_child(_seg(["1×", "2×", "3×"], lev - 1, func(i): lev = i + 1; build(menu), 11, 288.0))
	_stepper(body, "数量", str(qty), func(): qty = maxi(1, qty - 1); build(menu), func(): qty += 1; build(menu))
	var currency := FactionCatalog.currency(faction)
	var k := ex.forward_price(faction, material, fwd_term, fwd_deliver)
	var notional := k * qty
	body.add_child(AK.label("约定价 %s   名义 %s" % [Exchange.format_money(currency, k), Exchange.format_money(currency, notional)], 11, AK.FG))
	body.add_child(AK.label("保证金 %s   开仓费 %s   库存 %d" % [Exchange.format_money(currency, notional / lev), Exchange.format_money(currency, notional * Exchange.OPEN_FEE[lev - 1]), game.material_count(material)], 11, AK.MUTE))
	var refusal := ex.forward_refusal(faction, lev)
	if not refusal.is_empty(): body.add_child(AK.label(refusal, 12, AK.RED))
	_go(body, "签约", refusal.is_empty(), func():
		if ex.open_forward(faction, material, qty, fwd_term, fwd_deliver, lev): game.save_base()
		build(menu))

static func _cfd_form(menu: FieldMenu, body: VBoxContainer) -> void:
	var game := menu.game
	var ex := game.exchange
	var underlying := selected
	if not underlying in ex.cfd_underlyings():
		body.add_child(AK.label("局内据点不发行", 12, AK.MUTE))
		return
	var currency := Exchange.cfd_currency(underlying)
	var unit := 1000.0 if currency == "lmd" else 1.0
	if currency == "gold" and cfd_margin > 500.0: cfd_margin = 5.0
	if currency == "lmd" and cfd_margin < 500.0: cfd_margin = 5000.0
	body.add_child(AK.label(Exchange.cfd_name(underlying) + " · " + FactionCatalog.name_of(Exchange.cfd_issuer(underlying)), 12, AK.FG))
	body.add_child(_seg(["做多", "做空"], 0 if cfd_dir > 0 else 1, func(i): cfd_dir = 1 if i == 0 else -1; build(menu), 12, 288.0))
	body.add_child(_seg(["1×", "2×", "3×"], lev - 1, func(i): lev = i + 1; build(menu), 11, 288.0))
	_stepper(body, "保证金", Exchange.format_money(currency, cfd_margin), func(): cfd_margin = maxf(unit, cfd_margin - unit); build(menu), func(): cfd_margin += unit; build(menu))
	var issuer := Exchange.cfd_issuer(underlying)
	body.add_child(AK.label("名义 %s   持仓 %s / %s" % [Exchange.format_money(currency, cfd_margin * lev), Economy.format(roundi(ex.cfd_notional_used(issuer))), Economy.format(roundi(ex.cfd_notional_cap(issuer)))], 11, AK.MUTE))
	body.add_child(MarketWidgets.live(func(): return "今日额度 %s / %s   待入账 %s" % [Economy.format(roundi(ex.cfd_day.used)), Economy.format(roundi(ex.cfd_cap())), Economy.format(roundi(ex.cfd_pending()))], 11, AK.MUTE))
	var refusal := ex.cfd_refusal(underlying, lev, cfd_margin)
	if not refusal.is_empty(): body.add_child(AK.label(refusal, 12, AK.RED))
	_go(body, "开仓", refusal.is_empty(), func():
		if ex.open_cfd(underlying, cfd_dir, lev, cfd_margin): game.save_base()
		build(menu))

# --- 持仓 ---------------------------------------------------------------------------------

static func _positions_page(menu: FieldMenu, stage: Control) -> void:
	var game := menu.game
	var ex := game.exchange
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	AK.put(stage, scroll, Vector2(16, TOP + 40), Vector2(1248, BOTTOM - TOP - 40))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.custom_minimum_size.x = 1230
	scroll.add_child(box)
	box.add_child(AK.section("远期合约", "FORWARDS  %d" % ex.forwards.size()))
	for f in ex.forwards:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var pos: Dictionary = f
		row.add_child(MarketWidgets.live(func():
			var pnl := ex.forward_pnl(pos)
			return "%s  %s ×%d @ %s  ·  %s  ·  约定 %s  现价 %s  ·  盈亏 %s  ·  保证金率 %d%%  ·  剩 %s" % [
				"交货" if pos.dir == "deliver" else "收货", pos.material, int(pos.count), FactionCatalog.name_of(str(pos.faction)), "%d×" % int(pos.lev),
				Exchange.format_money(str(pos.currency), float(pos.k)), Exchange.format_money(str(pos.currency), ex.material_spot(str(pos.faction), str(pos.material), pos.dir == "deliver")),
				Exchange.format_money(str(pos.currency), pnl), roundi(ex.margin_ratio(pos, pnl) * 100), _left(int(pos.expires) - game.market.t)], 12))
		var act := AK.button("交割" if pos.dir == "deliver" else "收货", "blue", 12)
		act.pressed.connect(func():
			if (ex.deliver_forward(int(pos.id)) if pos.dir == "deliver" else ex.take_forward(int(pos.id))): game.save_base()
			build(menu))
		row.add_child(act)
		_margin_buttons(menu, row, pos)
		box.add_child(row)
	box.add_child(AK.section("差价合约", "CFD  %d" % ex.cfds.size()))
	for c in ex.cfds:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var pos: Dictionary = c
		row.add_child(MarketWidgets.live(func():
			var pnl := ex.cfd_pnl(pos)
			return "%s %s %d×  ·  开仓 %.2f  现价 %.2f  ·  盈亏 %s  ·  保证金率 %d%%%s" % [Exchange.cfd_name(str(pos.underlying)), "做多" if int(pos.dir) > 0 else "做空", int(pos.lev),
				float(pos.entry), ex.cfd_price(str(pos.underlying)), Exchange.format_money(str(pos.currency), pnl), roundi(ex.margin_ratio(pos, pnl) * 100),
				("  ·  止盈 %.2f 止损 %.2f" % [float(pos.tp), float(pos.sl)]) if float(pos.tp) > 0 or float(pos.sl) > 0 else ""], 12))
		var close := AK.button("平仓", "blue", 12)
		close.pressed.connect(func(): ex.close_cfd(int(pos.id)); game.save_base(); build(menu))
		row.add_child(close)
		var limits := AK.button("止盈止损 ±5%", "plain", 12)
		limits.pressed.connect(func():
			var p := ex.cfd_price(str(pos.underlying))
			ex.set_cfd_limits(int(pos.id), p * (1.0 + 0.05 * int(pos.dir)), p * (1.0 - 0.05 * int(pos.dir)))
			game.save_base()
			build(menu))
		row.add_child(limits)
		_margin_buttons(menu, row, pos)
		box.add_child(row)
	box.add_child(AK.section("挂单", "ORDERS  %d" % ex.orders.size()))
	for o in ex.orders:
		var row := HBoxContainer.new()
		var order: Dictionary = o
		var what := Item.from_data(order.item).display_name() if order.has("item") else "%s ×%d" % [order.material, int(order.count)]
		var kind: String = {"limit": "限价", "stop": "止损", "cond": "条件"}.get(str(order.type), "")
		row.add_child(MarketWidgets.live(func(): return "%s%s  %s  ·  %s  ·  %.2f  ·  现价 %.2f  ·  %s" % [kind, "卖" if order.side == "sell" else "买", what,
			FactionCatalog.market_name(str(order.market)), float(order.price), game.market.price(str(order.market)),
			"到结算" if int(order.expires) == 0 else "剩 " + _left(int(order.expires) - game.market.t)], 12))
		var cancel := AK.button("撤单", "plain", 12)
		cancel.pressed.connect(func(): ex.cancel_order(int(order.id)); game.save_base(); build(menu))
		row.add_child(cancel)
		box.add_child(row)
	box.add_child(AK.section("运单", "PENGUIN LOGISTICS  %d" % ex.shipments.size()))
	for s in ex.shipments:
		box.add_child(AK.label("%s → %s  ·  运输中" % [Item.from_data(s.item).display_name(), FactionCatalog.name_of(str(s.faction))], 12, AK.FG))
	box.add_child(AK.section("提醒", "ALERTS  %d" % ex.alerts.size()))
	for a in ex.alerts:
		var row := HBoxContainer.new()
		row.add_child(AK.label("%s %s %.2f" % [Exchange.cfd_name(str(a.market)), a.op, float(a.price)], 12, AK.FG))
		var id := int(a.id)
		var drop := AK.button("删除", "plain", 11)
		drop.pressed.connect(func(): ex.remove_alert(id); game.save_base(); build(menu))
		row.add_child(drop)
		box.add_child(row)
	box.add_child(AK.section("最近结算", "HISTORY"))
	var history := ex.history.duplicate()
	history.reverse()
	for h in history:
		box.add_child(AK.label("%s  %s  %s  ·  %s  ·  %s" % [Time.get_datetime_string_from_unix_time(MarketState.local(int(h.t)), true).substr(5, 11), _history_kind(str(h.kind)),
			str(h.what), FactionCatalog.name_of(str(h.faction)), Exchange.format_money(str(h.currency), float(h.amount))], 11, AK.MUTE))

static func _history_kind(kind: String) -> String:
	return {"sell": "卖出", "buy": "买入", "fill": "成交", "forward": "签约", "delivered": "交割", "default": "违约", "liquidated": "强平",
		"cfd": "开仓", "closed": "平仓", "arrived": "送达"}.get(kind, kind)

static func _margin_buttons(menu: FieldMenu, row: HBoxContainer, pos: Dictionary) -> void:
	var game := menu.game
	var add := AK.button("追加保证金", "plain", 12)
	add.pressed.connect(func():
		if game.exchange.add_margin(int(pos.id), float(pos.margin) * 0.5): game.save_base()
		build(menu))
	row.add_child(add)
	var auto := AK.button("自动追加 %s" % ("开" if float(pos.get("auto", 0.0)) > 0.0 else "关"), "plain", 12)
	auto.pressed.connect(func():
		game.exchange.set_auto_margin(int(pos.id), 0.0 if float(pos.get("auto", 0.0)) > 0.0 else 0.5)
		game.save_base()
		build(menu))
	row.add_child(auto)

static func _left(seconds: int) -> String:
	seconds = maxi(0, seconds)
	if seconds >= 86400: return "%d天%d时" % [seconds / 86400, (seconds % 86400) / 3600]
	if seconds >= 3600: return "%d时%d分" % [seconds / 3600, (seconds % 3600) / 60]
	return "%d分%d秒" % [seconds / 60, seconds % 60]

# --- 新闻 -----------------------------------------------------------------------------------

static func _news_page(menu: FieldMenu, stage: Control) -> void:
	var game := menu.game
	AK.put(stage, AK.section("新闻中心", "NEWS  %d" % game.market.news.size()), Vector2(16, TOP + 40))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	AK.put(stage, scroll, Vector2(16, TOP + 70), Vector2(820, BOTTOM - TOP - 70))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	scroll.add_child(box)
	var news: Array = game.market.news.duplicate()
	news.reverse()
	for n in news: box.add_child(_news_row(game, n, 820))
	AK.put(stage, AK.section("财经日历", "CALENDAR"), Vector2(852, TOP + 40))
	var cal := VBoxContainer.new()
	cal.add_theme_constant_override("separation", 4)
	AK.put(stage, cal, Vector2(852, TOP + 70), Vector2(412, 0))
	for c in game.market.calendar.slice(0, 10):
		var entry: Dictionary = c
		var ev: Dictionary = MarketEvents.EVENTS.get(str(entry.id), {})
		var title := str(ev.get("title", entry.id)).replace("%s", "…")
		cal.add_child(MarketWidgets.live(func(): return "%s  %s  ·  %s" % [Time.get_datetime_string_from_unix_time(MarketState.local(int(entry.at)), true).substr(5, 11), title, _left(int(entry.at) - game.market.t)], 12))
	AK.put(stage, AK.section("态势", "WORLD STATE"), Vector2(852, TOP + 330))
	var bars := MarketWidgets.FactorBars.new()
	bars.game = game
	AK.put(stage, bars, Vector2(852, TOP + 358), Vector2(412, 6 * 22))
	AK.put(stage, AK.section("限时", "FLASH  %d" % game.market.flash.size()), Vector2(852, TOP + 500))
	var fl := VBoxContainer.new()
	AK.put(stage, fl, Vector2(852, TOP + 528), Vector2(412, 0))
	for f in game.market.flash:
		var offer: Dictionary = f
		var row := HBoxContainer.new()
		row.add_child(MarketWidgets.live(func(): return "%s %s %s ×%.2f  %ds" % [FactionCatalog.name_of(str(offer.faction)), "收购" if offer.kind == "buy" else "抛售",
			FactionCatalog.CATEGORIES.get(offer.get("category", ""), str(offer.get("material", ""))), float(offer.mult), maxi(0, int(offer.until) - game.market.t)], 12, AK.GREEN))
		var go := AK.button("去交易", "plain", 11)
		go.pressed.connect(func():
			tab = 0
			mode = 0
			var faction := str(offer.faction)
			selected = "%s:%s" % [faction, offer.get("category", FactionCatalog.material_category(str(offer.get("material", ""))))]
			if not game.market.books.has(selected): selected = FactionCatalog.FX
			build(menu))
		row.add_child(go)
		fl.add_child(row)

# --- 资金 -----------------------------------------------------------------------------------

static func _money_page(menu: FieldMenu, stage: Control) -> void:
	var game := menu.game
	var ex := game.exchange
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	AK.put(stage, col, Vector2(16, TOP + 44), Vector2(600, 0))
	col.add_child(AK.section("换汇", "FX  %.1f" % Economy.fx))
	_stepper(col, "龙门币", Economy.format(fx_amount), func(): fx_amount = maxi(1000, fx_amount - 1000); build(menu), func(): fx_amount += 1000; build(menu))
	col.add_child(MarketWidgets.live(func(): return "→ 赤金 %.2f   ·   ← 需要赤金 %.2f" % [fx_amount / (Economy.fx * (1.0 + Economy.EXCHANGE_FX_SPREAD)), fx_amount / (Economy.fx * (1.0 - Economy.EXCHANGE_FX_SPREAD))], 12, AK.MUTE))
	var fx_row := HBoxContainer.new()
	var buy := AK.button("龙门币换赤金", "blue", 13)
	buy.pressed.connect(func():
		if ex.convert(true, fx_amount): game.save_base()
		build(menu))
	fx_row.add_child(buy)
	var sell := AK.button("赤金换龙门币", "plain", 13)
	sell.pressed.connect(func():
		if ex.convert(false, fx_amount / (Economy.fx * (1.0 - Economy.EXCHANGE_FX_SPREAD))): game.save_base()
		build(menu))
	fx_row.add_child(sell)
	col.add_child(fx_row)
	col.add_child(AK.section("赤金账户", "GOLD ACCOUNT  %.2f" % ex.gold_account))
	_stepper(col, "赤金", "%d 块  ·  库存 %d" % [bars, game.material_count(Economy.GOLD_ID)], func(): bars = maxi(1, bars - 1); build(menu), func(): bars += 1; build(menu))
	var bar_row := HBoxContainer.new()
	var dep := AK.button("存入", "blue", 13)
	dep.pressed.connect(func():
		if ex.deposit_bars(bars): game.save_base()
		build(menu))
	bar_row.add_child(dep)
	var wd := AK.button("取出", "plain", 13)
	wd.pressed.connect(func():
		if ex.withdraw_bars(bars): game.save_base()
		build(menu))
	bar_row.add_child(wd)
	col.add_child(bar_row)
	col.add_child(AK.section("势力关系", "RELATIONS"))
	for f in FactionCatalog.ORDER:
		col.add_child(AK.label("%s  R%d  ·  %d / %d%s" % [FactionCatalog.name_of(f), ex.rank(f), ex.relation(f), Exchange.RELATION_MAX,
			("  ·  违约冷却 " + _left(int(ex.forward_cooldown.get(f, 0)) - game.market.t)) if int(ex.forward_cooldown.get(f, 0)) > game.market.t else ""], 12, AK.FG))
	# 企鹅物流.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	AK.put(stage, right, Vector2(660, TOP + 44), Vector2(600, 0))
	right.add_child(AK.section("企鹅物流", "PENGUIN LOGISTICS  R%d" % ex.rank("penguin")))
	var items: Array[Item] = game.deliverable_items().filter(func(i): return not FactionCatalog.category_of(i).is_empty())
	if items.is_empty():
		right.add_child(AK.label("可运 0", 12, AK.MUTE))
		return
	var item: Item = items[posmod(ship_pick, items.size())]
	_stepper(right, "货物", item.display_name() + item.stack_suffix(), func(): ship_pick -= 1; build(menu), func(): ship_pick += 1; build(menu))
	var buyers := FactionCatalog.buyers(FactionCatalog.category_of(item))
	var to: String = buyers[posmod(ship_to, buyers.size())]
	_stepper(right, "送往", FactionCatalog.name_of(to), func(): ship_to -= 1; build(menu), func(): ship_to += 1; build(menu))
	var q := ex.quote_sell(item, to, false)
	right.add_child(AK.label("现价 %s   运费 %s" % [Exchange.format_money(str(q.currency), float(q.net)) if q.ok else str(q.why), Economy.format(ex.ship_fee(item))], 12, AK.MUTE))
	_go(right, "托运", q.ok, func():
		if ex.ship(item, to): game.save_base()
		build(menu))

# --- 加工部 (§2) ----------------------------------------------------------------------------

static var workshop_count := 1
static var workshop_pick := ""

static func workshop(menu: FieldMenu) -> void:
	var game := menu.game
	var stage := BaseScreens.shell(menu, "加工站", "WORKSHOP · PROCESSING DEPT", [], 0, Callable(), "PROCESS",
		[["lmd", Economy.format(game.gold)], ["rank", "R%d" % game.base.rank()]])
	var names: Array = Workshop.RECIPES.keys() + Workshop.PACKS.keys() + Workshop.GEAR.keys()
	if workshop_pick.is_empty(): workshop_pick = names[0]
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	AK.put(stage, scroll, Vector2(16, TOP + 8), Vector2(560, BOTTOM - TOP - 8))
	scroll.add_child(list)
	for output in names:
		var r := Workshop.recipe(output)
		var inputs: Array[String] = []
		for id in r["in"]: inputs.append("%s×%d（%d）" % [id, int(r["in"][id]), game.material_count(id)])
		var b := AK.button("%s   ←   %s   ·   %s 龙门币" % [output, "  ".join(inputs), Economy.format(int(r.lmd))], "blue" if output == workshop_pick else "plain", 12)
		b.custom_minimum_size = Vector2(540, 34)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var chosen: String = output
		b.pressed.connect(func(): workshop_pick = chosen; workshop(menu))
		list.add_child(b)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	AK.put(stage, right, Vector2(600, TOP + 8), Vector2(660, 0))
	right.add_child(AK.section(workshop_pick, "RECIPE"))
	var have := MaterialCatalog.create(workshop_pick, 1) if MaterialCatalog.MATERIALS.has(workshop_pick) else null
	if have != null:
		var holder := HBoxContainer.new()
		var icon := AK.item_icon(have, Vector2(72, 72))
		icon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		icon.custom_minimum_size = Vector2(72, 72)
		holder.add_child(icon)
		right.add_child(holder)
	_stepper(right, "数量", str(workshop_count), func(): workshop_count = maxi(1, workshop_count - 1); workshop(menu), func(): workshop_count += 1; workshop(menu))
	var r := Workshop.recipe(workshop_pick)
	right.add_child(AK.label("耗时 %d 分   ·   %s 龙门币" % [int(r.minutes) * workshop_count, Economy.format(int(r.lmd) * workshop_count)], 12, AK.MUTE))
	var refusal := game.workshop_refusal(workshop_pick, workshop_count)
	if not refusal.is_empty(): right.add_child(AK.label(refusal, 12, AK.RED))
	var go := AK.button("开始加工", "blue" if refusal.is_empty() else "plain", 15)
	go.custom_minimum_size = Vector2(300, 44)
	go.disabled = not refusal.is_empty()
	go.pressed.connect(func(): game.workshop_start(workshop_pick, workshop_count); workshop(menu))
	right.add_child(go)
	right.add_child(AK.section("队列", "QUEUE  %d / %d" % [game.workshop.busy(), Workshop.slots(game.base.rank())]))
	for j in game.workshop.jobs:
		var job: Dictionary = j
		right.add_child(MarketWidgets.live(func(): return "%s ×%d  ·  %s" % [job.output, int(job.count), "完成" if int(job.due) <= BaseState.now() else "进行中"], 13))

# --- A faction's post in the field (§12) ---------------------------------------------------

static func post(menu: FieldMenu) -> void:
	var game := menu.game
	var ex := game.exchange
	var faction := game.post_faction
	var stage := menu.stage_begin(0.97)
	var side := EventScreens._side(stage, 380, Color("2a1838"), "POST", AK.SPECIAL)
	AK.put(side, AK.label(FactionCatalog.name_of(faction), 26, AK.FG), Vector2(32, 40))
	AK.put(side, AK.label(str(FactionCatalog.info(faction).region).to_upper() + " · FIELD POST", 10, AK.MUTE, AK.en()), Vector2(32, 78))
	AK.put(side, AK.label("关系 R%d" % ex.rank(faction), 14, AK.FG), Vector2(32, 110))
	var leave := AK.button("离开", "plain", 15)
	AK.put(side, leave, Vector2(24, 662), Vector2(332, 44))
	leave.pressed.connect(game.close_modal)
	AK.put(stage, AK.money("gold", str(game.gold_bars()), 18), Vector2(410, 32))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	AK.put(stage, scroll, Vector2(410, 80), Vector2(850, 620))
	scroll.add_child(box)
	box.add_child(AK.section("收购", "SELL"))
	var carried: Array[Item] = []
	carried.append_array(game.inventory.items)
	carried.append_array(game.safe_bag.items)
	var any := false
	for item in carried:
		var q := ex.quote_sell(item, faction, false)
		if not q.ok: continue
		any = true
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(AK.item_icon(item, Vector2(40, 40)))
		var l := AK.label("%s  →  %s" % [item.display_name() + item.stack_suffix(), Exchange.format_field(str(q.currency), float(q.net))], 13, AK.FG)
		l.custom_minimum_size.x = 360
		row.add_child(l)
		var chosen: Item = item
		var sell := AK.button("卖出", "blue", 12)
		sell.disabled = str(q.currency) == "gold" and Exchange.field_bars(float(q.net)) <= 0
		sell.pressed.connect(func(): game.post_sell(chosen); post(menu))
		row.add_child(sell)
		if FactionCatalog.info(faction).get("barter", false):
			for want in FactionCatalog.info(faction).get("sells", []):
				var n := game.barter_count(item, want)
				if n <= 0: continue
				var want_id: String = want
				var swap := AK.button("换 %s ×%d" % [want, n], "plain", 12)
				swap.pressed.connect(func(): game.barter(chosen, want_id); post(menu))
				row.add_child(swap)
		box.add_child(row)
	if not any: box.add_child(AK.label("可卖 0", 12, AK.MUTE))
	box.add_child(AK.section("出售", "BUY"))
	for material in FactionCatalog.info(faction).get("sells", []):
		var bq := ex.quote_buy(faction, material)
		if not bq.ok: continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var l := AK.label(material, 13, AK.FG)
		l.custom_minimum_size.x = 360
		row.add_child(l)
		for n in [1, 5]:
			var count: int = n
			var chosen_material: String = material
			var b := AK.button("×%d  %s" % [n, Exchange.format_field(str(bq.currency), float(bq.unit) * n, true)], "plain", 12)
			b.disabled = str(bq.currency) == "gold" and game.gold_bars() < Exchange.field_bars(float(bq.unit) * n, true)
			b.pressed.connect(func(): game.post_buy(chosen_material, count); post(menu))
			row.add_child(b)
		box.add_child(row)
	for offer in game.market.flash:
		if offer.faction != faction or offer.kind != "buy": continue
		box.add_child(AK.label("限时收购 %s ×%.2f" % [FactionCatalog.CATEGORIES.get(str(offer.category), ""), float(offer.mult)], 13, AK.GREEN))
		for item in carried:
			if FactionCatalog.category_of(item) != str(offer.category): continue
			var chosen: Item = item
			var id := int(offer.id)
			var b := AK.button("卖出 %s" % item.display_name(), "yellow", 12)
			b.pressed.connect(func():
				if ex.sell_to_flash(id, chosen, true): game.save_base(true)
				post(menu))
			box.add_child(b)
