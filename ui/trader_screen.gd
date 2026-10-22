class_name TraderScreen
extends RefCounted

## Every shop as a Tarkov trader (药剂与商人界面策划案 §4, 用户 2026-10-21):
## the trader on the left (portrait, standing, balance, the deal and 成交),
## the shop's stock in the middle as a backpack-style shelf running the
## column's full height (10×13, 顶天立地), the player's pack on the right.
## 可露希尔, 坎诺特, the faction posts and the pharmacy all fill one `spec`.
## Data, state and buttons only (用户 2026-10-05).

const CELL := 40
const SHELF := Vector2i(10, 13)
const LEFT := Rect2(16, 76, 300, 608)
const MID := Rect2(328, 76, 440, 608)
const RIGHT := Rect2(780, 76, 484, 608)
const SHELF_AT := Vector2(348, 128)
const PORTRAITS := "res://art/ui/portraits/"

static var _game: GameManager

## `spec` keys:
##   title, en, tabs (station tabs), tab, on_tab — the shell's top bar
##   accent: Color; portrait: "npc_closure" …; who, who_en; standing: "商店 Lv2" …
##   balance: [[kind, value], …] for the pills and the trader's line
##   trade_tabs: ["购买"] or ["购买", "出售"]; selling: bool; on_trade_tab(i)
##   goods: [{item?, relic?, price (text), currency, stock, lock, sold, refusal}]
##   on_buy(index); refresh: [text, enabled, callable] or []; restock: "18:42"
##   offer(item) -> String ("" = not bought here); on_sell(item); sell_extra(item) -> [[text, kind, callable]]
##   buttons: rows of [text, kind, callable] for the left column's foot
##   restock_in: Callable -> seconds (a live mm:ss countdown); skin: "white" (药房)
## Drag a shelf tile onto the pack to buy it, a pack item onto the shelf to sell it.
static func build(menu: FieldMenu, spec: Dictionary) -> Control:
	var game := menu.game
	_game = game
	var accent: Color = spec.get("accent", AK.HOLO)
	BaseScreens.accent_override = accent
	var stage := BaseScreens.shell(menu, spec.title, spec.en, spec.get("tabs", []), spec.get("tab", 0), spec.get("on_tab", Callable()), "", spec.get("balance", []))
	BaseScreens.accent_override = Color(0, 0, 0, 0)
	var selling: bool = spec.get("selling", false)
	var redraw: Callable = spec.redraw
	var white: bool = spec.get("skin", "") == "white"
	var fg := Color("1c2428") if white else AK.FG
	var mute := Color("46525a") if white else AK.MUTE
	var skin := "white" if white else "plate"
	if white: stage.add_child(AK.rect(Color("515c62"), Vector2(0, 60), Vector2(1280, 660)))
	# --- left: the trader ------------------------------------------------------------
	var left := _plate(stage, LEFT, accent, skin)
	stage.add_child(AK.rect(Color(accent, 0.12 if white else 0.07), LEFT.position + Vector2(8, 8), Vector2(LEFT.size.x - 16, 300)))
	var portrait: Texture2D = load(PORTRAITS + str(spec.get("portrait", "")) + ".png") if not str(spec.get("portrait", "")).is_empty() else null
	if portrait != null:
		var art := TextureRect.new()
		art.texture = portrait
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		AK.put(stage, art, LEFT.position + Vector2(roundf((LEFT.size.x - portrait.get_width()) * 0.5), 300 - portrait.get_height() + 12), portrait.get_size())
	AK.put(stage, AK.label(spec.get("who", ""), 26, fg), LEFT.position + Vector2(20, 318))
	AK.put(stage, AK.label(spec.get("who_en", ""), 10, mute, AK.en()), LEFT.position + Vector2(20, 352))
	if not str(spec.get("standing", "")).is_empty():
		AK.put(stage, AK.tag(spec.standing, accent), LEFT.position + Vector2(20, 376))
	# The deal: what is picked, what it costs or fetches, and 成交.
	var deal := Control.new()
	AK.put(stage, deal, LEFT.position + Vector2(14, 404), Vector2(LEFT.size.x - 28, 64))
	deal.add_child(AK.rect(Color(0, 0, 0, 0.6), Vector2.ZERO, deal.size))
	var pick_index := int(menu.pick) if menu.pick is int else -1
	var pick_item: Item = menu.pick if menu.pick is Item else null
	var ok := false
	var confirm := Callable()
	var goods: Array = spec.get("goods", [])
	if not selling and pick_index >= 0 and pick_index < goods.size():
		var g: Dictionary = goods[pick_index]
		_deal_line(deal, g.get("item"), g.get("relic", {}), str(g.price), str(g.get("currency", "gold")), str(g.get("refusal", "")))
		ok = str(g.get("refusal", "")).is_empty() and not g.get("sold", false) and str(g.get("lock", "")).is_empty()
		var i := pick_index
		confirm = func(): spec.on_buy.call(i); menu.pick = null; redraw.call()
	elif selling and pick_item != null:
		var offer: String = spec.offer.call(pick_item)
		_deal_line(deal, pick_item, {}, offer, str(spec.get("sell_currency", "gold")), "" if not offer.is_empty() else "不收")
		ok = not offer.is_empty()
		var it := pick_item
		confirm = func(): spec.on_sell.call(it); menu.pick = null; redraw.call()
	else:
		AK.put(deal, AK.label("—", 16, AK.DIM), Vector2(14, 20))
	var go := AK.go_button("成交" if not selling else "出售", "DEAL", "blue", 20)
	AK.put(stage, go, LEFT.position + Vector2(14, 476), Vector2(LEFT.size.x - 28, 56))
	go.disabled = not ok
	go.pressed.connect(confirm if confirm.is_valid() else func(): pass)
	var rows: Array = spec.get("buttons", [])
	if selling and pick_item != null and spec.has("sell_extra"):
		rows = [spec.sell_extra.call(pick_item)] + rows
	var y := 540.0
	for row in rows:
		if row.is_empty(): continue
		var w: float = (LEFT.size.x - 28 - 6 * (row.size() - 1)) / row.size()
		var x := 14.0
		for entry in row:
			var b := AK.button(str(entry[0]), str(entry[1]), 14)
			AK.put(stage, b, LEFT.position + Vector2(x, y), Vector2(w, 40))
			b.set_meta("label", str(entry[0]))
			if entry.size() > 2 and entry[2] is Callable: b.pressed.connect(entry[2])
			else: b.disabled = true
			x += w + 6
		y += 46
	# --- middle: the shop's shelf -------------------------------------------------------
	_plate(stage, MID, accent, skin)
	var trade_tabs: Array = spec.get("trade_tabs", ["购买"])
	if trade_tabs.size() > 1:
		AK.put(stage, AK.toggle(trade_tabs, 1 if selling else 0, spec.on_trade_tab, 14), MID.position + Vector2(20, 10))
	elif white:
		AK.put(stage, AK.label(trade_tabs[0], 18, fg), MID.position + Vector2(20, 16))
	else:
		AK.put(stage, AK.section(trade_tabs[0], "STOCK"), MID.position + Vector2(20, 20))
	if not selling and spec.get("restock_in", Callable()) is Callable and (spec.get("restock_in", Callable()) as Callable).is_valid():
		var restock := HBoxContainer.new()
		restock.add_child(AK.label("补货", 12, mute))
		var clock := Countdown.new()
		clock.left = spec.restock_in
		clock.on_zero = redraw
		clock.add_theme_font_override("font", AK.en())
		clock.add_theme_font_size_override("font_size", 14)
		clock.add_theme_color_override("font_color", fg)
		restock.add_child(clock)
		AK.put(stage, restock, MID.position + Vector2(MID.size.x - 110, 18))
	var refresh: Array = spec.get("refresh", [])
	if not selling and not refresh.is_empty():
		var r := AK.button(str(refresh[0]), "plain", 13)
		AK.put(stage, r, MID.position + Vector2(MID.size.x - 128, 10), Vector2(108, 36))
		r.disabled = not bool(refresh[1])
		r.pressed.connect(refresh[2])
	var shelf := Shelf.new()
	shelf.selling = selling
	shelf.white = white
	AK.put(stage, shelf, SHELF_AT, Vector2(SHELF) * CELL)
	# Drag trading: a pack item dropped on the shelf is sold, a shelf tile
	# dropped on the pack is bought (the same checks as 成交).
	var sells := func(data: Variant) -> bool:
		return data is Dictionary and data.has("trade_sell") and spec.has("offer") and not str(spec.offer.call(data.trade_sell)).is_empty()
	# A drop asks first (用户 2026-10-21: 拖拽至背包时添加提示是否购买/卖出，可勾选不再提示).
	var sell_drop := func(data: Variant):
		var it: Item = data.trade_sell
		ask(stage, "出售", it, {}, str(spec.offer.call(it)), str(spec.get("sell_currency", "gold")),
			func(): spec.on_sell.call(it); menu.pick = null; redraw.call())
	var buys := func(data: Variant) -> bool:
		if not (data is Dictionary and data.has("trade_buy")): return false
		var g: Dictionary = goods[int(data.trade_buy)]
		return str(g.get("refusal", "")).is_empty() and not g.get("sold", false) and str(g.get("lock", "")).is_empty()
	var buy_drop := func(data: Variant):
		var i := int(data.trade_buy)
		var g: Dictionary = goods[i]
		ask(stage, "购买", g.get("item"), g.get("relic", {}), str(g.price), str(g.get("currency", "gold")),
			func(): spec.on_buy.call(i); menu.pick = null; redraw.call())
	shelf.accept = sells
	shelf.take = sell_drop
	if not selling:
		var taken := _taken()
		for i in range(goods.size()):
			var g: Dictionary = goods[i]
			var cells := _cells(g)
			var at := _place(taken, cells)
			if at.x < 0: continue
			var index := i
			var tile := _tile(shelf, at, cells, g, i == pick_index, func(): menu.pick = index; redraw.call())
			tile.payload = {"trade_buy": index}
	else:
		# 出售: what this trader would take, laid out in the box with its price.
		var taken := _taken()
		var carried: Array = game.inventory.items + game.safe_bag.items
		for item in carried:
			var offer: String = spec.offer.call(item)
			if offer.is_empty(): continue
			var cells := Vector2i(item.width, item.height)
			var at := _place(taken, cells)
			if at.x < 0: continue
			var chosen: Item = item
			_tile(shelf, at, cells, {"item": item, "price": offer, "currency": spec.get("sell_currency", "gold")}, item == pick_item,
				func(): menu.pick = chosen; redraw.call())
	# --- right: her pack ----------------------------------------------------------------
	var right := _plate(stage, RIGHT, AK.HOLO)
	right.mouse_filter = Control.MOUSE_FILTER_PASS
	right.set_drag_forwarding(Callable(), func(_at, data): return buys.call(data), func(_at, data): buy_drop.call(data))
	var pack_at := RIGHT.position + Vector2(20, 44)
	AK.put(stage, AK.section("背包", "%d / %d" % [game.inventory.occupied_cells(), game.inventory.cell_count()]), RIGHT.position + Vector2(20, 16))
	var sellable := func(item: Item) -> bool: return not selling or not str(spec.offer.call(item)).is_empty()
	var pick_from_pack := func(item: Item): menu.pick = item; redraw.call()
	var drag_out := func(item: Item) -> Variant: return {"trade_sell": item} if sells.call({"trade_sell": item}) else null
	var pack := AK.BagGrid.make(game.inventory, sellable if selling else Callable(), pick_from_pack if selling else Callable(), pick_item)
	pack.drag_out = drag_out
	pack.accept = buys
	pack.take = buy_drop
	AK.put(stage, pack, pack_at)
	var safe_y := pack_at.y + game.inventory.height * CELL + 14
	AK.put(stage, AK.section("安全袋"), Vector2(pack_at.x, safe_y))
	var safe := AK.BagGrid.make(game.safe_bag, sellable if selling else Callable(), pick_from_pack if selling else Callable(), pick_item)
	safe.drag_out = drag_out
	safe.accept = buys
	safe.take = buy_drop
	AK.put(stage, safe, Vector2(pack_at.x, safe_y + 28))
	var money := VBoxContainer.new()
	for entry in spec.get("balance", []):
		if entry[0] in ["lmd", "gold"]: money.add_child(AK.money(entry[0], entry[1], 18))
	AK.put(stage, money, Vector2(pack_at.x + game.safe_bag.width * CELL + 24, safe_y + 34))
	return stage

## The drag-trade prompt: what, for how much, 确认 / 取消 and 不再提示. With
## the prompt turned off (settings "trade_confirm") the deal goes through at once.
static func ask(stage: Control, verb: String, item: Item, relic: Dictionary, price: String, currency: String, deal: Callable) -> void:
	if not bool(SystemScreens.settings.get("trade_confirm", true)):
		deal.call()
		return
	var veil := ColorRect.new()
	veil.name = "TradePrompt"
	veil.color = Color(0, 0, 0, 0.55)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	AK.put(stage, veil, Vector2.ZERO, Vector2(1280, 720))
	var box := Panel.new()
	box.add_theme_stylebox_override("panel", Terminal.panel_style("plate"))
	AK.put(veil, box, Vector2(440, 250), Vector2(400, 220))
	Terminal.frame(box, AK.HOLO, 0.0)
	AK.put(box, AK.label(verb, 20, AK.FG), Vector2(24, 18))
	var line := Control.new()
	AK.put(box, line, Vector2(16, 56), Vector2(368, 64))
	line.add_child(AK.rect(Color(0, 0, 0, 0.6), Vector2.ZERO, line.size))
	_deal_line(line, item, relic, price, currency, "")
	var skip := CheckBox.new()
	skip.text = "不再提示"
	skip.focus_mode = Control.FOCUS_NONE
	skip.add_theme_font_override("font", AK.cn())
	skip.add_theme_font_size_override("font_size", 13)
	skip.set_meta("label", "不再提示")
	AK.put(box, skip, Vector2(22, 130))
	var yes := AK.button("确认", "blue", 15)
	AK.put(box, yes, Vector2(204, 164), Vector2(176, 40))
	var no := AK.button("取消", "plain", 15)
	AK.put(box, no, Vector2(20, 164), Vector2(176, 40))
	no.pressed.connect(veil.queue_free)
	yes.pressed.connect(func():
		if skip.button_pressed:
			SystemScreens.settings["trade_confirm"] = false
			SystemScreens.save_settings()
		veil.queue_free()
		deal.call())

static func _plate(stage: Control, r: Rect2, accent: Color, skin: String = "plate") -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", Terminal.panel_style(skin))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	AK.put(stage, p, r.position, r.size)
	Terminal.frame(p, accent, 0.0)
	return p

static func _cells(g: Dictionary) -> Vector2i:
	var item: Item = g.get("item")
	if item != null: return Vector2i(item.width, item.height)
	return Vector2i(2, 2)

static func _taken() -> Array:
	var t: Array = []
	t.resize(SHELF.x * SHELF.y)
	t.fill(false)
	return t

## First fit, row by row, like an AK depot shelf.
static func _place(taken: Array, cells: Vector2i) -> Vector2i:
	for y in range(SHELF.y - cells.y + 1):
		for x in range(SHELF.x - cells.x + 1):
			var free := true
			for dy in range(cells.y):
				for dx in range(cells.x):
					if taken[(y + dy) * SHELF.x + x + dx]: free = false
			if not free: continue
			for dy in range(cells.y):
				for dx in range(cells.x): taken[(y + dy) * SHELF.x + x + dx] = true
			return Vector2i(x, y)
	return Vector2i(-1, -1)

static func _tile(shelf: Shelf, at: Vector2i, cells: Vector2i, g: Dictionary, selected: bool, on_pick: Callable) -> ShelfTile:
	var tile := ShelfTile.new()
	tile.focus_mode = Control.FOCUS_NONE
	tile.flat = true
	tile.item = g.get("item")
	tile.relic = g.get("relic", {})
	AK.put(shelf, tile, Vector2(at) * CELL, Vector2(cells) * CELL - Vector2.ONE)
	var item: Item = g.get("item")
	tile.set_meta("label", item.display_name() if item != null else str(tile.relic.get("name", "")))
	if item != null:
		var square := AK.item_icon(item, tile.size)
		square.dim = g.get("sold", false) or not str(g.get("lock", "")).is_empty()
		# The price tag takes the bottom-left; a bundle shows as ×n at the top-right.
		square.hide_count = true
		if item.is_stackable() and item.quantity > 1 and str(g.get("stock", "")).is_empty(): g["stock"] = "×%d" % item.quantity
		tile.add_child(square)
	elif not tile.relic.is_empty():
		var icon := AK.relic_icon(tile.relic, tile.size.x)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(icon)
	var tag := PriceTag.new()
	tag.text = str(g.get("tag", g.price))
	tag.currency = str(g.get("currency", "gold"))
	tag.stock = str(g.get("stock", ""))
	tag.lock = str(g.get("lock", ""))
	tag.sold = g.get("sold", false)
	tag.short = str(g.get("refusal", "")).ends_with("不足")  # i18n: skip
	tag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(tag)
	if selected: AK.frame(tile, AK.HOLO)
	tile.pressed.connect(on_pick)
	tile.set_drag_forwarding(tile.drag, func(_at, data): return shelf._can_drop_data(_at, data), func(_at, data): shelf._drop_data(_at, data))
	return tile

static func _deal_line(deal: Control, item: Item, relic: Dictionary, price: String, currency: String, refusal: String) -> void:
	if item != null: AK.put(deal, AK.item_icon(item, Vector2(48, 48)), Vector2(8, 8))
	elif not relic.is_empty():
		var icon := AK.relic_icon(relic, 48)
		AK.put(deal, icon, Vector2(8, 8))
	var name := item.display_name() + item.stack_suffix() if item != null else str(relic.get("name", ""))
	var title := AK.label(name, 13, item.rarity_color() if item != null else AK.FG)
	title.clip_text = true
	AK.put(deal, title, Vector2(64, 10), Vector2(deal.size.x - 72, 20))
	if not refusal.is_empty():
		AK.put(deal, AK.label(refusal, 12, AK.RED), Vector2(64, 36))
	var money := AK.money(currency, price, 18)
	money.alignment = BoxContainer.ALIGNMENT_END
	AK.put(deal, money, Vector2(deal.size.x - 130, 34), Vector2(122, 22))


class Shelf extends Control:
	var selling := false
	var white := false
	var accept: Callable
	var take: Callable
	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return accept.is_valid() and bool(accept.call(data))
	func _drop_data(_at: Vector2, data: Variant) -> void:
		take.call(data)
	func _draw() -> void:
		var s := size
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.1, 0.13, 0.15, 0.22) if white else Color(0, 0, 0, 0.55))
		var line := Color("7a858b") if white else Color(AK.LINE, 0.9)
		for x in range(SHELF.x + 1): draw_line(Vector2(x * CELL, 0), Vector2(x * CELL, s.y), line)
		for y in range(SHELF.y + 1): draw_line(Vector2(0, y * CELL), Vector2(s.x, y * CELL), line)
		if selling: draw_rect(Rect2(Vector2.ZERO, s), Color(AK.GREEN, 0.35), false, 2.0)


## The price tag on a shelf tile (white, cut corner), the stock at the
## top-right, a hazard-striped lock or a 售罄 band.
class PriceTag extends Control:
	var text := ""
	var currency := "gold"
	var stock := ""
	var lock := ""
	var sold := false
	var short := false
	func _draw() -> void:
		var s := size
		var font := AK.en()
		if not lock.is_empty():
			for i in range(int((s.x + s.y) / 8.0) + 1):
				var a := Vector2(i * 8.0, 0)
				draw_line(a, a + Vector2(-s.y, s.y), Color(AK.HAZARD, 0.22), 3.0)
			draw_string(font, Vector2(3, 12), lock, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, AK.HAZARD)
			return
		if not stock.is_empty():
			var sw := font.get_string_size(stock, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
			draw_string(font, Vector2(s.x - sw - 3, 11), stock, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, AK.MUTE)
		if sold:
			draw_rect(Rect2(0, s.y * 0.5 - 7, s.x, 14), Color(AK.RED, 0.85))
			var w := AK.cn().get_string_size("售罄", HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
			draw_string(AK.cn(), Vector2((s.x - w) * 0.5, s.y * 0.5 + 4), I18n.t("售罄"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, AK.FG)
			return
		if text.is_empty(): return
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		var w := tw + 14
		var r := Rect2(1, s.y - 17, minf(w, s.x - 2), 12)
		draw_colored_polygon(PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0), r.position + Vector2(r.size.x, r.size.y - 4),
			r.position + Vector2(r.size.x - 4, r.size.y), r.position + Vector2(0, r.size.y)]), Color.WHITE)
		var mark := Color("b8860b") if currency == "gold" else Color.BLACK
		draw_circle(r.position + Vector2(5, 6), 2.6, mark)
		draw_string(font, r.position + Vector2(10, 10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, AK.RED if short else Color.BLACK)


## A shelf tile whose hover card is the item's full tooltip (or the relic's effect).
class ShelfTile extends Button:
	var item: Item
	var relic := {}
	var payload: Variant = null
	func drag(_at: Vector2) -> Variant:
		if payload == null: return null
		var ghost: Control = AK.item_icon(item, size) if item != null else AK.relic_icon(relic, size.x)
		ghost.modulate.a = 0.8
		set_drag_preview(ghost)
		return payload
	func _ready() -> void:
		tooltip_text = " "
	func _make_custom_tooltip(_for_text: String) -> Object:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", AK.box(Color(0.04, 0.05, 0.06, 0.97), AK.LINE_2, 1, 10))
		var text := RichTextLabel.new()
		text.bbcode_enabled = true
		text.fit_content = true
		text.scroll_active = false
		text.custom_minimum_size.x = 280
		text.add_theme_font_override("normal_font", AK.cn())
		text.add_theme_font_size_override("normal_font_size", 13)
		if item != null and is_instance_valid(TraderScreen._game): text.text = ItemTooltip.text(TraderScreen._game, item, false, false)
		elif not relic.is_empty(): text.text = "[b]%s[/b]\n%s" % [I18n.t(str(relic.get("name", ""))), I18n.t(str(relic.get("effect", "")))]
		card.add_child(text)
		return card

## mm:ss until `left` reaches 0, then `on_zero` (the shelf has restocked).
class Countdown extends Label:
	var left: Callable
	var on_zero: Callable
	var _fired := false
	func _ready() -> void:
		_show()
	func _process(_delta: float) -> void:
		_show()
	func _show() -> void:
		var s := maxi(0, int(left.call()))
		text = "%02d:%02d" % [s / 60, s % 60]
		if s == 0 and not _fired and on_zero.is_valid():
			_fired = true
			on_zero.call_deferred()

# --- The four shops -----------------------------------------------------------------------

## 坎诺特 (诡意行商): relics and gear for 赤金, a rerollable shelf; buys gear back.
static func cannot(menu: FieldMenu) -> void:
	var game := menu.game
	var selling := menu.trader_tab == "sell"
	var goods: Array = []
	for i in range(game.trader_stock.size()):
		var entry: Dictionary = game.trader_stock[i]
		var relic: bool = entry.kind == "relic"
		goods.append({"item": null if relic else entry.item, "relic": entry.relic if relic else {}, "price": str(int(entry.price)),
			"currency": "gold", "sold": entry.sold, "refusal": game.trader_buy_refusal(i)})
	var cost := game.trader_reroll_cost()
	build(menu, {
		"title": "诡意行商", "en": "ROGUE TRADER · " + AK.floor_code(game.region_id, game.floor_number), "accent": Color("c8643c"),
		"portrait": "npc_cannot", "who": "坎诺特", "who_en": "CANNOT",
		"balance": [["gold", str(game.gold_bars())]],
		"trade_tabs": ["购买", "出售"], "selling": selling,
		"on_trade_tab": func(i): menu.trader_tab = ["buy", "sell"][i]; menu.pick = null; cannot(menu),
		"goods": goods, "on_buy": func(i): game.trader_buy(i),
		"refresh": ["刷新 %d" % cost, game.gold_bars() >= cost, func(): menu.pick = null; game.trader_reroll(); cannot(menu)],
		"offer": func(item: Item) -> String: return str(game.trader_offer(item)) if game.trader_offer(item) > 0 else "",
		"on_sell": func(item: Item): game.trader_sell(item),
		"buttons": [[["离开", "plain", game.close_modal]]],
		"redraw": func(): cannot(menu),
	})

const POST_ACCENTS := {"rat": Color("5fe08a"), "reunion": Color("e6e6e6"), "ursus": Color("a34a4a"), "sami": Color("5f9e6e")}
const POST_TRADERS := {"rat": ["下城区货郎", "npc_post_rat"], "reunion": ["整合运动残党", "npc_post_reunion"], "ursus": ["矿场采购员", "npc_post_ursus"], "sami": ["林地行商", "npc_post_sami"]}

## A faction's post (势力与交易所策划案 §12): its materials for sale, the
## carried goods it takes, barter and its flash buys.
static func post(menu: FieldMenu) -> void:
	var game := menu.game
	var ex := game.exchange
	var faction := game.post_faction
	var info := FactionCatalog.info(faction)
	var currency := FactionCatalog.currency(faction)
	var selling := menu.trader_tab == "sell"
	var goods: Array = []
	var materials: Array = []
	var flask_type := game.post_potion()
	if not flask_type.is_empty():
		var p: Dictionary = BaseCatalog.POTIONS[flask_type]
		var barter: Dictionary = p.get("barter", {})
		var refusal := game.post_potion_refusal()
		goods.append({"item": BaseCatalog.create_potion(flask_type, Economy.tier_of(game.floor_number)),
			"price": ("%s×%d" % [barter.keys()[0], int(barter.values()[0])]) if not barter.is_empty() else str(int(p.bars)),
			"tag": ("×%d" % int(barter.values()[0])) if not barter.is_empty() else str(int(p.bars)),
			"currency": "barter" if not barter.is_empty() else "gold", "refusal": refusal})
		materials.append("")
	for material in info.get("sells", []):
		var q := ex.quote_buy(faction, material)
		if not q.ok: continue
		var bars := Exchange.field_bars(float(q.unit), true)
		var price := str(bars) if currency == "gold" else Economy.format(roundi(float(q.unit)))
		var short := (currency == "gold" and game.gold_bars() < bars) or (currency != "gold" and game.gold < float(q.unit))
		goods.append({"item": MaterialCatalog.create(material, 1) if MaterialCatalog.MATERIALS.has(material) else null, "price": price,
			"currency": currency, "refusal": ("赤金不足" if currency == "gold" else "龙门币不足") if short else ""})
		materials.append(material)
	var offer := func(item: Item) -> String:
		var q := ex.quote_sell(item, faction, false)
		if not q.ok: return ""
		if currency == "gold":
			var bars := Exchange.field_bars(float(q.net))
			return str(bars) if bars > 0 else ""
		return Economy.format(roundi(float(q.net)))
	var extra := func(item: Item) -> Array:
		var row: Array = []
		if info.get("barter", false):
			for want in info.get("sells", []):
				var n := game.barter_count(item, want)
				if n <= 0: continue
				var want_id: String = want
				row.append(["换 %s ×%d" % [want, n], "plain", func(): game.barter(item, want_id); menu.pick = null; post(menu)])
		for flash in game.market.flash:
			if flash.faction != faction or flash.kind != "buy" or FactionCatalog.category_of(item) != str(flash.category): continue
			var id := int(flash.id)
			row.append(["限时收购 ×%.2f" % float(flash.mult), "yellow", func(): _flash_sell(menu, id, item)])
		return row
	var trader: Array = POST_TRADERS.get(faction, [FactionCatalog.name_of(faction), ""])
	var balance := [["gold", str(game.gold_bars())]] if currency == "gold" else [["lmd", Economy.format(game.gold)]]
	build(menu, {
		"title": FactionCatalog.name_of(faction), "en": str(info.get("region", "")).to_upper() + " · FIELD POST", "accent": POST_ACCENTS.get(faction, AK.SPECIAL),
		"portrait": trader[1], "who": trader[0], "who_en": FactionCatalog.name_of(faction), "standing": "关系 R%d" % ex.rank(faction),
		"balance": balance, "trade_tabs": ["购买", "出售"], "selling": selling, "sell_currency": currency,
		"on_trade_tab": func(i): menu.trader_tab = ["buy", "sell"][i]; menu.pick = null; post(menu),
		"goods": goods, "on_buy": func(i): (game.post_buy_potion() if materials[i] == "" else game.post_buy(materials[i], 1)),
		"offer": offer, "on_sell": func(item: Item): game.post_sell(item), "sell_extra": extra,
		"buttons": [[["离开", "plain", game.close_modal]]],
		"redraw": func(): post(menu),
	})

static func _flash_sell(menu: FieldMenu, id: int, item: Item) -> void:
	if menu.game.exchange.sell_to_flash(id, item, true): menu.game.save_base(true)
	menu.pick = null
	post(menu)

## 可露希尔's shop (the camp's and the base's 商店 tab): her flasks for 赤金.
## Her other services stay on the camp screen's tabs (EventScreens.camp).
static func closure(menu: FieldMenu, at_base: bool) -> void:
	var game := menu.game
	var goods: Array = []
	var types: Array = []
	for type in game.closure_goods():
		var price := game.closure_potion_price(type)
		var left := game.closure_stock_left(type)
		var flask := BaseCatalog.create_potion(type, game.closure_potion_tier())
		flask.set_quantity(mini(game.closure_potion_bundle(type), flask.max_stack) if left < 0 else maxi(1, mini(mini(game.closure_potion_bundle(type), flask.max_stack), left)))
		var refusal := ""
		if price >= 0 and game.gold_available() < price: refusal = "赤金不足"
		elif not game.inventory.can_take(flask): refusal = "背包已满"
		goods.append({"item": flask, "price": str(maxi(price, 0)), "currency": "gold", "lock": ("商店 Lv%d" % int(BaseCatalog.POTIONS[type].store)) if price < 0 else "",
			"refusal": refusal, "sold": left == 0, "stock": ("%d/%d" % [left, int(BaseCatalog.POTIONS[type].cap)]) if left >= 0 else ""})
		types.append(type)
	var tabs := ["商店", "出售赤金", "换汇", "贷款", "随队物资"] if at_base else ["商店", "寄存", "出售赤金", "换汇", "交割", "补给", "处理"]
	var buttons: Array = []
	if at_base:
		buttons = [[["离开", "plain", game.close_modal]]]
	else:
		buttons = [[["撤离", "green", game.camp_extract], ["继续 · %s" % AK.floor_code(game.region_id, game.floor_number + 1), "plain", game.leave_camp]]]
	build(menu, {
		"title": "可露希尔的商店" if at_base else game.camp_label(game.floor_number), "en": "CLOSURE'S STORE" if at_base else "CAMP · CLOSURE",
		"tabs": tabs, "tab": 0, "on_tab": func(i): menu.camp_tab = i; menu.pick = null; EventScreens.camp(menu, at_base),
		"accent": Terminal.DEPT.store, "portrait": "npc_closure", "who": "可露希尔", "who_en": "CLOSURE · ENGINEERING",
		"standing": "商店 Lv%d" % game.base.facility_level("store"),
		"balance": [["gold", str(game.gold_available())], ["lmd", Economy.format(game.gold)]],
		"goods": goods, "on_buy": func(i): game.closure_buy_potion(types[i]),
		"buttons": buttons, "redraw": func(): EventScreens.camp(menu, at_base),
		"restock_in": (func() -> int: return game.base.closure_restock_in()) if at_base else Callable(),
	})

## 药房窗口: only the 制式 restoratives, A and B (药剂与商人界面策划案 §1).
const PHARMACY_TYPES := ["A", "B"]

static func pharmacy(menu: FieldMenu) -> void:
	var game := menu.game
	var goods: Array = []
	for type in PHARMACY_TYPES:
		var price := game.potion_price(type)
		var flask := BaseCatalog.create_potion(type, game.deepest_tier())
		var refusal := ""
		if price > 0 and game.gold < price: refusal = "龙门币不足"
		elif not game.inventory.can_take(flask): refusal = "背包已满"
		goods.append({"item": flask, "price": "免费" if price == 0 else Economy.format(maxi(price, 0)), "currency": "lmd",
			"lock": ("商店 Lv%d" % int(BaseCatalog.POTIONS[type].store)) if price < 0 else "", "refusal": refusal,
			"stock": ("%d/%d" % [game.base.free_potions, game.base.free_potion_count()]) if type == "A" and price == 0 else ""})
	build(menu, {
		"title": "医疗部", "en": "MEDICAL", "tabs": BaseScreens.MEDICAL_TABS, "tab": 0, "on_tab": func(i): BaseScreens.medical(menu, i),
		"accent": Terminal.DEPT.med, "portrait": "npc_medic", "who": "药房窗口", "who_en": "PHARMACY · MEDICAL DEPT.",
		"standing": "免费急救剂 %d" % game.base.free_potions,
		"balance": [["lmd", Economy.format(game.gold)]],
		"skin": "white", "goods": goods, "on_buy": func(i): game.buy_potion(PHARMACY_TYPES[i]),
		"buttons": [[["离开", "plain", game.close_modal]]], "redraw": func(): pharmacy(menu),
	})
