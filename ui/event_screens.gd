class_name EventScreens
extends RefCounted

## The in-run event screens, laid out as in the prototype (界面策划案 v1.1 #7–#10,
## art/ui_mockup): relic pick, route node map, the Rhodes squad, 坎诺特, the camp
## and the settlement. Each builds onto FieldMenu.stage (absolute 1280×720
## layout); FieldMenu.pick holds what is selected on the screen.
## Data, state and buttons only — no rule text (用户 2026-10-05).

const SOURCE_EN := {"device": "ENHANCEMENT DEVICE", "cache": "COMBAT CACHE", "vault": "SEALED VAULT"}
const ROUTE_EN := ["INSPECTION", "SUPPLY FACE", "DEEP ZONE"]
const ROUTE_COLOURS := [AK.FG, AK.SP, AK.RED]

static func _title(stage: Control, at: Vector2, en_text: String, cn_text: String, sub: String = "", en_color: Color = AK.MUTE) -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.add_child(AK.label(en_text, 11, en_color, AK.en()))
	column.add_child(AK.label(cn_text, 34, AK.FG))
	if not sub.is_empty(): column.add_child(AK.label(sub, 13, AK.MUTE))
	AK.put(stage, column, at)

static func _close(stage: Control, menu: FieldMenu, at: Vector2 = Vector2(1216, 12)) -> Button:
	var b := AK.button("✕", "ghost", 18)
	AK.put(stage, b, at, Vector2(52, 52))
	b.pressed.connect(menu.game.close_modal)
	return b

## The ✕ / ✓ pair at the foot of AK event screens.
static func _footer(stage: Control, at: Vector2, width: float, leave: String, confirm: String, on_leave: Callable, on_confirm: Callable, enabled: bool) -> Button:
	var half := width * 0.5
	if not leave.is_empty():
		var out := AK.button("✕ " + leave, "plain", 16)
		AK.style_button(out, "plain")
		AK.put(stage, out, at, Vector2(half, 58))
		out.pressed.connect(on_leave)
	else:
		half = 0.0
	var go := AK.button("✓ " + confirm, "blue", 16)
	AK.put(stage, go, at + Vector2(half, 0), Vector2(width - half, 58))
	go.disabled = not enabled
	go.pressed.connect(on_confirm)
	return go

## A dark side panel with a tinted gradient, an outlined watermark and a figure
## placeholder (the portraits wait for Sol's art).
static func _side(stage: Control, width: float, tint: Color, watermark: String, figure: Color) -> Control:
	var side := Control.new()
	AK.put(stage, side, Vector2.ZERO, Vector2(width, 720))
	side.clip_contents = true
	var gradient := Gradient.new()
	gradient.set_color(0, tint)
	gradient.set_color(1, Color("0b0b0b"))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0.75, 0.9)
	var back := TextureRect.new()
	back.texture = texture
	back.stretch_mode = TextureRect.STRETCH_SCALE
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_child(back)
	var mark := AK.label(watermark, 104, Color(figure, 0.1), AK.en())
	mark.position = Vector2(-8, 470)
	side.add_child(mark)
	var silhouette := Silhouette.new()
	silhouette.colour = figure
	AK.put(side, silhouette, Vector2(width * 0.5 - 75, 200), Vector2(150, 260))
	return side

# --- #7 藏品三选一 -------------------------------------------------------------------

static func builds(menu: FieldMenu) -> void:
	var game := menu.game
	var stage := menu.stage_begin(0.86)
	var offers: Array = game.build_offers
	var pick := int(menu.pick) if menu.pick is int else -1
	_title(stage, Vector2(60, 40), SOURCE_EN.get(game.offer_source, "ENHANCEMENT DEVICE"), "选择藏品", FieldMenu.OFFER_TITLES.get(game.offer_source, "强化装置"))
	_close(stage, menu)
	var total := offers.size() * 250 + maxi(0, offers.size() - 1) * 70
	for i in range(offers.size()):
		var offer: Dictionary = offers[i]
		var colour: Color = RelicCatalog.RARITY_COLORS[offer.rarity]
		var card := Button.new()
		card.flat = true
		card.focus_mode = Control.FOCUS_NONE
		card.set_meta("label", "选择 " + offer.name)
		AK.put(stage, card, Vector2((1280 - total) * 0.5 + i * 320, 150), Vector2(250, 320))
		var icon := AK.relic_icon(offer, 144)
		AK.put(card, icon, Vector2(53, 3))
		if i == pick: AK.frame(icon, AK.SP, 3.0)
		var tags := HBoxContainer.new()
		tags.alignment = BoxContainer.ALIGNMENT_CENTER
		tags.add_theme_constant_override("separation", 6)
		tags.add_child(AK.tag(RelicCatalog.RARITY_NAMES[offer.rarity], colour))
		tags.add_child(AK.tag(AK.KIND_NAMES.get(offer.kind, offer.kind), AK.PLATE_3, false))
		AK.put(card, tags, Vector2(0, 166), Vector2(250, 20))
		var name := AK.label(offer.name, 20, AK.FG)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		AK.put(card, name, Vector2(0, 194), Vector2(250, 30))
		var effect := AK.label(offer.effect, 14, AK.FG)
		effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		AK.put(card, effect, Vector2(0, 230), Vector2(250, 60))
		for child in card.get_children(): child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var index := i
		card.pressed.connect(func(): menu.pick = index; builds(menu))
	# The band: the PRTS original of the selected one, refresh, acquire.
	AK.put(stage, AK.rect(Color(0.055, 0.055, 0.055, 0.96), Vector2(0, 608), Vector2(1280, 112)), Vector2(0, 608))
	AK.put(stage, AK.label("ORIGINAL EFFECT · PRTS", 9, AK.DIM, AK.en()), Vector2(60, 632))
	if pick >= 0 and pick < offers.size():
		var original := AK.label(offers[pick].original, 13, AK.MUTE, AK.italic())
		original.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		AK.put(stage, original, Vector2(60, 650), Vector2(620, 50))
	var reroll := AK.button("刷新 %d" % game.reroll_cost(), "plain", 15)
	AK.put(stage, reroll, Vector2(760, 636), Vector2(150, 56))
	reroll.disabled = game.gold_bars() < game.reroll_cost()
	reroll.pressed.connect(func(): menu.pick = -1; game.reroll_offers())
	var take := AK.go_button("获取", "ACQUIRE")
	AK.put(stage, take, Vector2(1000, 632), Vector2(220, 64))
	take.disabled = pick < 0 or pick >= offers.size()
	take.pressed.connect(func():
		if pick >= 0 and pick < offers.size():
			menu.pick = null
			game.choose_build(offers[pick].id))

# --- #8 路线选择 ---------------------------------------------------------------------

static func routes(menu: FieldMenu, index: int) -> void:
	var game := menu.game
	var stage := menu.stage_begin(0.97)
	var pick := int(menu.pick) if menu.pick is int else index
	_title(stage, Vector2(84, 18), "INTEGRATED ROUTE", "选择去向")
	var back := AK.button("‹", "ghost", 24)
	AK.put(stage, back, Vector2(24, 26), Vector2(48, 48))
	back.pressed.connect(game.close_modal)
	var money := AK.money("gold", str(game.gold_bars()))
	AK.put(stage, money, Vector2(1160, 30))
	var map := Control.new()
	AK.put(stage, map, Vector2(-180, 0), Vector2(1280, 720))
	var lines := RouteLines.new()
	AK.put(map, lines, Vector2.ZERO, Vector2(1280, 720))
	# The floors walked (last three) and the current one in paper.
	var history: Array = game.route_history if not game.route_history.is_empty() else [{"floor": game.floor_number, "name": "入口"}]
	var walked: Array = history.slice(maxi(0, history.size() - 4), history.size() - 1)
	var points: Array[Vector2] = []
	for i in range(walked.size()):
		var at := Vector2(600 - (walked.size() - i) * 200, 360)
		points.append(at)
		_node(map, at, AK.floor_code(game.region_id, walked[i].floor), walked[i].name, "done")
	var here := Vector2(600, 360)
	points.append(here)
	_node(map, here, AK.floor_code(game.region_id, game.floor_number), history[-1].name, "here")
	lines.walked = points
	lines.from = here
	var next := game.floor_number + 1
	var camp_next := game.floor_number % FieldCatalog.CAMP_INTERVAL == 0
	for i in range(FieldCatalog.ROUTES.size()):
		var route: Dictionary = FieldCatalog.ROUTES[i]
		var at := Vector2(820, [220, 360, 500][i])
		lines.targets.append(at)
		var node := _node(map, at, AK.floor_code(game.region_id, next), route.name, "next", ROUTE_COLOURS[i], i == pick)
		node.set_meta("label", "进入 " + route.name)
		var chosen := i
		node.pressed.connect(func(): menu.pick = chosen; routes(menu, index))
	var beyond := Vector2(1040, 360)
	lines.beyond = beyond
	_node(map, beyond, game.camp_label(game.floor_number) if camp_next else AK.floor_code(game.region_id, next + 1), "—", "far")
	# The detail of the picked route, on the right.
	var route: Dictionary = FieldCatalog.ROUTES[pick]
	var colour: Color = ROUTE_COLORS_SAFE(pick)
	AK.put(stage, AK.rect(Color(0.055, 0.055, 0.055, 0.96), Vector2(980, 80), Vector2(300, 640)), Vector2(980, 80))
	AK.put(stage, AK.rect(Color("0b0b0b"), Vector2(980, 80), Vector2(300, 150)), Vector2(980, 80))
	AK.put(stage, AK.rect(colour, Vector2(980, 227), Vector2(300, 3)), Vector2(980, 227))
	AK.put(stage, AK.label("0%d" % (pick + 1), 80, Color(1, 1, 1, 0.06), AK.en()), Vector2(988, 128))
	AK.put(stage, AK.label(ROUTE_EN[pick], 10, AK.MUTE, AK.en()), Vector2(996, 96))
	AK.put(stage, AK.label(route.name, 24, colour), Vector2(996, 112))
	var detail: String = route.detail.replace(" / ", " · ")
	if game.region_id == "mine": detail = detail.replace("精英增援", "敌群增援")
	var detail_label := AK.label(detail, 13, AK.MUTE)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	AK.put(stage, detail_label, Vector2(996, 246), Vector2(268, 40))
	AK.put(stage, AK.label("掉落加成", 13, AK.MUTE), Vector2(996, 300))
	AK.put(stage, AK.label("+%d%%" % roundi(float(route.reward) * 100), 20, AK.SP, AK.en()), Vector2(1200, 294))
	AK.put(stage, AK.rect(AK.LINE, Vector2(996, 330), Vector2(268, 1)), Vector2(996, 330))
	var go := AK.go_button("前进", "PROCEED")
	AK.put(stage, go, Vector2(996, 634), Vector2(268, 66))
	go.pressed.connect(func(): menu.pick = null; game.advance(pick))

static func ROUTE_COLORS_SAFE(i: int) -> Color:
	return ROUTE_COLOURS[clampi(i, 0, ROUTE_COLOURS.size() - 1)]

## A node on the route map: code over name, a glyph square on the left.
static func _node(parent: Control, centre: Vector2, code: String, name: String, state: String, colour: Color = AK.FG, selected: bool = false) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	var fill: Color = {"done": Color("1c1c1c"), "here": AK.PAPER, "next": AK.PLATE_2, "far": Color("1c1c1c")}[state]
	for s in ["normal", "hover", "pressed", "disabled"]:
		var style := AK.box(fill.lightened(0.08) if s == "hover" and state == "next" else fill)
		if state == "next":
			style.border_color = colour
			style.border_width_bottom = 3
		b.add_theme_stylebox_override(s, style)
	b.disabled = state != "next"
	if state in ["done", "far"]: b.modulate.a = 0.6
	AK.put(parent, b, centre - Vector2(75, 28), Vector2(150, 56))
	var dark := state == "here"
	var glyph := AK.rect(Color.BLACK if not dark else AK.INK, Vector2(8, 8), Vector2(40, 40))
	b.add_child(glyph)
	var letter := AK.label(name.left(1) if name != "—" else "·", 16, colour if state == "next" else (AK.PAPER if dark else AK.MUTE))
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	AK.put(b, letter, Vector2(8, 8), Vector2(40, 40))
	var code_label := AK.label(code, 10, Color("555555") if dark else AK.MUTE, AK.en())
	code_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	AK.put(b, code_label, Vector2(56, 8))
	var name_label := AK.label(name, 14, AK.INK if dark else AK.FG)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	AK.put(b, name_label, Vector2(56, 24))
	if selected: AK.frame(b, AK.SP, 2.0)
	return b

# --- #9 罗德岛小队 -------------------------------------------------------------------

static func squad(menu: FieldMenu) -> void:
	var game := menu.game
	var stage := menu.stage_begin(0.8)
	var side := _side(stage, 430, Color("0f2a30"), "RHODES", AK.CYAN)
	_title(side, Vector2(36, 40), "ENCOUNTER", "罗德岛小队", "外勤支援 · " + AK.floor_code(game.region_id, game.floor_number), AK.CYAN)
	var service := menu.squad_service
	var pick: Item = menu.pick if menu.pick is Item else null
	var services := [["投保", "INSURE", "insure", AK.HP], ["送回", "SEND HOME", "send", AK.GREEN]]
	for i in range(2):
		var entry: Array = services[i]
		var on: bool = service == entry[2]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.set_meta("label", entry[0])
		for s in ["normal", "hover", "pressed"]:
			var style := AK.box(AK.PAPER if on else (AK.PLATE_2.lightened(0.06) if s == "hover" else AK.PLATE_2))
			style.border_color = entry[3]
			style.border_width_left = 4
			b.add_theme_stylebox_override(s, style)
		AK.put(stage, b, Vector2(470 + i * 391, 40), Vector2(379, 62))
		AK.put(b, AK.label(entry[1], 9, Color(AK.INK if on else AK.FG, 0.7), AK.en()), Vector2(20, 10))
		AK.put(b, AK.label(entry[0], 20, AK.INK if on else AK.FG), Vector2(20, 22))
		var key: String = entry[2]
		b.pressed.connect(func(): menu.squad_service = key; menu.pick = null; squad(menu))
	AK.put(stage, AK.section("可投保" if service == "insure" else "可送回"), Vector2(470, 120))
	AK.put(stage, AK.money("gold", str(game.gold_bars()), 16), Vector2(1180, 116))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	AK.put(stage, scroll, Vector2(470, 150), Vector2(770, 456))
	# Rows at fixed places (not a GridContainer), so nothing shifts under the pointer.
	var list := Control.new()
	scroll.add_child(list)
	var index := 0
	for item in game.carried_items():
		if not item.is_equippable(): continue
		var refusal := game.squad_refusal(item, service)
		var price := game.squad_price(item)
		var row := _item_row(item, str(price), "已投保" if item.insured else Item.CATEGORY_NAMES[item.category], refusal.is_empty(), item == pick, refusal == "赤金不足")
		var chosen := item
		row.pressed.connect(func(): menu.pick = chosen; squad(menu))
		AK.put(list, row, Vector2((index % 3) * 258, (index / 3) * 66), Vector2(252, 60))
		index += 1
	list.custom_minimum_size = Vector2(770, ceili(index / 3.0) * 66)
	var label := "投保" if service == "insure" else "送回"
	var ok := pick != null and game.squad_refusal(pick, service).is_empty()
	_footer(stage, Vector2(470, 622), 770, "离开", label + (" · %d" % game.squad_price(pick) if pick != null else ""), game.close_modal, func():
		if pick == null: return
		menu.pick = null
		if service == "insure": game.squad_insure(pick)
		else: game.squad_send_home(pick)
		game.close_modal(), ok)

## One pickable item: icon, name, a sub line, the price on the right.
static func _item_row(item: Item, price: String, sub: String, enabled: bool, selected: bool, short: bool = false) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(252, 60)
	b.set_meta("item", item)
	for s in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(s, AK.box(Color("333333") if selected or s == "hover" else AK.PLATE_2))
	b.disabled = not enabled
	if not enabled: b.modulate.a = 0.35
	AK.put(b, AK.item_icon(item, Vector2(48, 48)), Vector2(6, 6))
	var name := AK.label(item.display_name(), 13, item.rarity_color())
	name.clip_text = true
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	AK.put(b, name, Vector2(62, 10), Vector2(140, 20))
	var sub_label := AK.label(sub, 11, AK.MUTE)
	sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	AK.put(b, sub_label, Vector2(62, 32))
	var cost := AK.label(price, 15, AK.RED if short else AK.SP, AK.en())
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	AK.put(b, cost, Vector2(190, 20), Vector2(52, 20))
	if selected: AK.frame(b)
	return b

# --- #9b 坎诺特 -----------------------------------------------------------------------

static func trader(menu: FieldMenu) -> void:
	var game := menu.game
	var stage := menu.stage_begin(0.82)
	var side := _side(stage, 360, Color("3a2c12"), "TRADER", AK.TRADER)
	_title(side, Vector2(32, 36), "ROGUE TRADER", "坎诺特", "诡意行商 · " + AK.floor_code(game.region_id, game.floor_number), AK.TRADER)
	var selling := menu.trader_tab == "sell"
	AK.put(stage, AK.toggle(["购买", "出售"], 1 if selling else 0, func(i): menu.trader_tab = ["buy", "sell"][i]; menu.pick = null; trader(menu)), Vector2(390, 32))
	AK.put(stage, AK.money("gold", str(game.gold_bars())), Vector2(1170, 38))
	var ok := false
	var confirm := Callable()
	if not selling:
		var pick := int(menu.pick) if menu.pick is int else -1
		for i in range(game.trader_stock.size()):
			var entry: Dictionary = game.trader_stock[i]
			var refusal := game.trader_buy_refusal(i)
			var cell := _shelf_cell(entry, refusal, i == pick, func(): menu.pick = i; trader(menu))
			AK.put(stage, cell, Vector2(390 + (i % 4) * 215, 84 + (i / 4) * 158), Vector2(207, 150))
		var reroll := AK.button("刷新 %d" % game.trader_reroll_cost(), "plain", 15)
		AK.put(stage, reroll, Vector2(390, 548), Vector2(150, 52))
		reroll.disabled = game.gold_bars() < game.trader_reroll_cost()
		reroll.pressed.connect(func(): menu.pick = null; game.trader_reroll(); trader(menu))
		ok = pick >= 0 and game.trader_buy_refusal(pick).is_empty()
		confirm = func():
			if pick >= 0: game.trader_buy(pick)
			menu.pick = null
			trader(menu)
	else:
		var pick: Item = menu.pick if menu.pick is Item else null
		var can_sell := func(item: Item) -> bool: return game.trader_offer(item) > 0
		var pick_item := func(item: Item): menu.pick = item; trader(menu)
		AK.put(stage, AK.BagGrid.make(game.inventory, can_sell, pick_item, pick), Vector2(390, 84))
		AK.put(stage, AK.section("安全袋"), Vector2(390, 84 + game.inventory.height * 40 + 12))
		AK.put(stage, AK.BagGrid.make(game.safe_bag, can_sell, pick_item, pick), Vector2(390, 84 + game.inventory.height * 40 + 40))
		if pick != null: _info(stage, game, pick, "收购价", str(game.trader_offer(pick)), Vector2(390 + game.inventory.width * 40 + 18, 84))
		ok = pick != null and game.trader_offer(pick) > 0
		confirm = func():
			if pick != null: game.trader_sell(pick)
			menu.pick = null
			trader(menu)
	_footer(stage, Vector2(390, 630), 854, "离开", "出售" if selling else "购买", game.close_modal, confirm, ok)

static func _shelf_cell(entry: Dictionary, refusal: String, selected: bool, on_pick: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(207, 150)
	for s in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(s, AK.box(Color("333333") if selected or s == "hover" else AK.PLATE_2))
	var enabled := refusal.is_empty()
	b.disabled = not enabled
	if not enabled: b.modulate.a = 0.35
	var is_relic: bool = entry.kind == "relic"
	var name: String = entry.relic.name if is_relic else entry.item.display_name()
	b.set_meta("label", name)
	var icon: Control = AK.relic_icon(entry.relic, 72) if is_relic else AK.item_icon(entry.item, Vector2(72, 72))
	AK.put(b, icon, Vector2(67, 8))
	var title := AK.label(name, 12, RelicCatalog.RARITY_COLORS[entry.relic.rarity] if is_relic else entry.item.rarity_color())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	AK.put(b, title, Vector2(8, 82), Vector2(191, 34))
	var price := AK.money("gold", "已售出" if entry.sold else str(int(entry.price)), 16)
	price.alignment = BoxContainer.ALIGNMENT_CENTER
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if refusal == "赤金不足": (price.get_child(1) as Label).add_theme_color_override("font_color", AK.RED)
	AK.put(b, price, Vector2(0, 120), Vector2(207, 20))
	if is_relic: b.tooltip_text = entry.relic.effect
	if selected: AK.frame(b)
	b.pressed.connect(on_pick)
	return b

## The tooltip of `item` with one price row under it.
static func _info(stage: Control, game: GameManager, item: Item, key: String, value: String, at: Vector2) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", AK.box(Color("0d0d0d"), AK.LINE_2, 1, 10))
	var column := VBoxContainer.new()
	card.add_child(column)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.custom_minimum_size.x = 300
	text.add_theme_font_override("normal_font", AK.cn())
	text.add_theme_font_size_override("normal_font_size", 13)
	text.text = ItemTooltip.text(game, item, false, false)
	column.add_child(text)
	var row := HBoxContainer.new()
	row.add_child(AK.label(key, 13, AK.MUTE))
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(fill)
	row.add_child(AK.money("gold", value, 20))
	column.add_child(row)
	AK.put(stage, card, at)

# --- #9c 营地 ------------------------------------------------------------------------

## In a camp, or (`at_base`) her counter at the base: the same shop and 赤金
## buying, no deposit and no way out there (用户：不区分).
static func camp(menu: FieldMenu, at_base: bool = false) -> void:
	var game := menu.game
	var stage := menu.stage_begin(0.97)
	var side := _side(stage, 380, Color("13321f"), "STORE" if at_base else "CAMP", AK.GREEN)
	if at_base:
		AK.put(side, AK.label("可露希尔的商店", 26, AK.FG), Vector2(32, 40))
		AK.put(side, AK.label("CLOSURE'S STORE · RHODES ISLAND", 10, AK.MUTE, AK.en()), Vector2(32, 78))
		var back := AK.button("返回", "plain", 15)
		AK.put(side, back, Vector2(24, 662), Vector2(332, 44))
		back.pressed.connect(game.close_modal)
	else:
		var plate := AK.tag(game.camp_label(game.floor_number), AK.PAPER)
		AK.put(side, plate, Vector2(32, 32))
		AK.put(side, AK.label("可露希尔", 30, AK.FG), Vector2(32, 62))
		AK.put(side, AK.label("CLOSURE · RHODES ISLAND", 10, AK.MUTE, AK.en()), Vector2(32, 104))
		var extract := AK.go_button("撤离", "EXTRACT", "green")
		AK.put(side, extract, Vector2(24, 592), Vector2(332, 64))
		extract.pressed.connect(game.camp_extract)
		var on := AK.button("继续 · %s" % AK.floor_code(game.region_id, game.floor_number + 1), "plain", 15)
		AK.put(side, on, Vector2(24, 662), Vector2(332, 44))
		on.pressed.connect(game.leave_camp)
	var tabs := ["商店", "出售赤金"] if at_base else ["商店", "寄存", "出售赤金"]
	var tab: int = clampi(menu.camp_tab, 0, tabs.size() - 1)
	var redraw := func(): camp(menu, at_base)
	AK.put(stage, AK.toggle(tabs, tab, func(i): menu.camp_tab = i; menu.pick = null; camp(menu, at_base)), Vector2(410, 32))
	if at_base and tab == 1: tab = 2
	AK.put(stage, AK.money("gold", str(game.gold_available())), Vector2(950, 38))
	AK.put(stage, AK.money("lmd", Economy.format(game.gold)), Vector2(1070, 38))
	var ok := false
	var confirm := Callable()
	match tab:
		0:
			var pick: String = menu.pick if menu.pick is String else ""
			var x := 410.0
			for type in BaseCatalog.POTIONS:
				var price := game.closure_potion_price(type)
				var card := Button.new()
				card.focus_mode = Control.FOCUS_NONE
				card.set_meta("label", BaseCatalog.POTIONS[type].name)
				for s in ["normal", "hover", "pressed", "disabled"]:
					var style := AK.box(Color("333333") if pick == type or s == "hover" else AK.PLATE_2)
					style.border_color = AK.ORI if type == "C" else AK.GREEN
					style.border_width_bottom = 3
					card.add_theme_stylebox_override(s, style)
				card.disabled = price < 0
				if price < 0: card.modulate.a = 0.35
				AK.put(stage, card, Vector2(x, 84), Vector2(270, 160))
				AK.put(card, AK.item_icon(BaseCatalog.create_potion(type), Vector2(72, 72)), Vector2(99, 14))
				var name := AK.label(BaseCatalog.POTIONS[type].name, 14, AK.FG)
				name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				name.mouse_filter = Control.MOUSE_FILTER_IGNORE
				AK.put(card, name, Vector2(0, 94), Vector2(270, 22))
				var cost := AK.money("gold", ("R%d" % int(BaseCatalog.POTIONS[type].rank)) if price < 0 else str(price), 16)
				cost.alignment = BoxContainer.ALIGNMENT_CENTER
				cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
				AK.put(card, cost, Vector2(0, 124), Vector2(270, 22))
				if pick == type: AK.frame(card)
				var chosen: String = type
				card.pressed.connect(func(): menu.pick = chosen; redraw.call())
				x += 280
			AK.put(stage, AK.section("背包", "%d / %d" % [game.inventory.occupied_cells(), game.inventory.cell_count()]), Vector2(410, 262))
			AK.put(stage, AK.BagGrid.make(game.inventory), Vector2(410, 292))
			ok = not pick.is_empty() and game.closure_potion_price(pick) >= 0 and game.gold_available() >= game.closure_potion_price(pick) and game.inventory.can_fit(BaseCatalog.create_potion(pick))
			confirm = func():
				game.closure_buy_potion(pick)
				redraw.call()
		1:
			var pick: Item = menu.pick if menu.pick is Item else null
			var can_deposit := func(item: Item) -> bool: return game.deposit_refusal(item) in ["", "赤金不足"]
			var pick_item := func(item: Item): menu.pick = item; camp(menu)
			AK.put(stage, AK.BagGrid.make(game.inventory, can_deposit, pick_item, pick), Vector2(410, 84))
			AK.put(stage, AK.section("安全袋"), Vector2(410, 84 + game.inventory.height * 40 + 12))
			AK.put(stage, AK.BagGrid.make(game.safe_bag, can_deposit, pick_item, pick), Vector2(410, 84 + game.inventory.height * 40 + 40))
			if pick != null: _info(stage, game, pick, "费用", str(game.deposit_fee(pick)), Vector2(410 + game.inventory.width * 40 + 18, 84))
			ok = pick != null and game.deposit_refusal(pick).is_empty()
			confirm = func():
				game.deposit_item(pick)
				menu.pick = null
				camp(menu)
		2:
			var have := game.gold_available()
			var amount: int = clampi(int(menu.pick) if menu.pick is int else 10, 0, have)
			var panel := AK.rect(AK.PLATE_2, Vector2(410, 84), Vector2(834, 150))
			stage.add_child(panel)
			AK.put(stage, AK.item_icon(MaterialCatalog.create(Economy.GOLD_ID, maxi(have, 1)), Vector2(96, 96)), Vector2(434, 111))
			var choices := [1, 10, have]
			AK.put(stage, AK.toggle(["1", "10", "全部"], choices.find(amount) if amount in choices else -1, func(i): menu.pick = [1, 10, have][i]; redraw.call()), Vector2(560, 104))
			var flow := HBoxContainer.new()
			flow.add_theme_constant_override("separation", 12)
			flow.add_child(AK.money("gold", str(amount), 24))
			flow.add_child(AK.label("→", 18, AK.MUTE))
			flow.add_child(AK.money("lmd", Economy.format(amount * Economy.GOLD_BAR_LMD), 24))
			AK.put(stage, flow, Vector2(560, 160))
			ok = amount > 0
			confirm = func():
				game.sell_gold_bars(amount)
				redraw.call()
	_footer(stage, Vector2(410, 630), 834, "", ["购买", "寄存", "出售"][tab], Callable(), confirm, ok)

# --- #10 行动结束 / 失败 ----------------------------------------------------------------

const FATE_TAGS := {"安全袋保全": ["保留", AK.GREEN], "投保送回": ["投保", AK.HP]}

static func settlement(menu: FieldMenu) -> void:
	var game := menu.game
	var stage := menu.stage_begin(0.97)
	var view: Dictionary = game.settlement_view
	var ok: bool = view.get("extracted", false)
	var accent := AK.GREEN if ok else AK.RED
	stage.add_child(AK.rect(accent, Vector2.ZERO, Vector2(1280, 6)))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(AK.tag(view.get("plate", ""), AK.PAPER))
	head.add_child(AK.label("%s · %s" % [FieldCatalog.REGIONS[view.region].name, view.get("time", "")], 12, AK.MUTE))
	AK.put(stage, head, Vector2(48, 44))
	AK.put(stage, AK.label("行动结束" if ok else "行动失败", 52, AK.FG if ok else AK.RED), Vector2(48, 76))
	AK.put(stage, AK.label("MISSION ACCOMPLISHED" if ok else "MISSION FAILED", 12, AK.SP if ok else AK.RED, AK.en()), Vector2(50, 146))
	var cells: Array = []
	if ok:
		cells = [["赤金", str(view.get("gold", 0)), AK.SP], ["合同报酬", "+" + Economy.format(view.reward), AK.FG],
			["污染", "%d → %d" % [view.get("contamination_before", 0), view.get("contamination_after", 0)], AK.ORI], ["可交付订单", str(view.get("orders", 0)), AK.SP]]
	else:
		var n := {"安全袋保全": 0, "投保送回": 0, "遗失": 0}
		for entry in view.pack + view.safe + view.worn: n[entry.reason] = int(n.get(entry.reason, 0)) + 1
		cells = [["保留", "%d 件" % n["安全袋保全"], AK.GREEN], ["投保", "%d 件" % n["投保送回"], AK.HP],
			["丢失", "%d 件" % n["遗失"], AK.RED], ["污染", "%d → %d" % [view.get("contamination_before", 0), view.get("contamination_after", 0)], AK.ORI]]
	stage.add_child(AK.rect(AK.PLATE, Vector2(48, 176), Vector2(330, 136)))
	for i in range(4):
		var at := Vector2(48 + (i % 2) * 165, 176 + (i / 2) * 68)
		AK.put(stage, AK.label(cells[i][0], 11, AK.MUTE), at + Vector2(12, 10))
		AK.put(stage, AK.label(cells[i][1], 22, cells[i][2], AK.en()), at + Vector2(12, 28))
		stage.add_child(AK.rect(AK.LINE, at + Vector2(0, 67), Vector2(165, 1)))
	var sprite := TextureRect.new()
	if ResourceLoader.exists("res://ui/art/lappland_portrait.png"): sprite.texture = load("res://ui/art/lappland_portrait.png")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if not ok: sprite.modulate = Color(0.5, 0.5, 0.5, 0.5)
	AK.put(stage, sprite, Vector2(129, 330), Vector2(168, 168))
	var back := AK.go_button("返回罗德岛", "RETURN")
	AK.put(stage, back, Vector2(48, 624), Vector2(330, 60))
	back.pressed.connect(game.close_modal)
	# The bags as they came out, enlarged, items where they were.
	var worn: Array = view.worn
	var worn_h := 1
	for entry in worn: worn_h = maxi(worn_h, entry.h)
	var pack_size: Vector2i = view.pack_size
	var safe_size: Vector2i = view.safe_size
	var scale := minf(820.0 / (pack_size.x * 40.0), 560.0 / ((maxi(worn_h, safe_size.y) + pack_size.y) * 40.0))
	scale = minf(scale, 1.8)
	var y := 44.0
	var x := 420.0
	AK.put(stage, AK.section("装备", "EQUIPPED"), Vector2(x, y))
	for entry in worn:
		var grid := FateGrid.make(Vector2i(entry.w, entry.h), [_at_origin(entry)], ok, scale)
		AK.put(stage, grid, Vector2(x, y + 28))
		x += entry.w * 40 * scale + 8
	x = maxf(x + 14, 420 + 3 * 80 * scale * 0.5)
	AK.put(stage, AK.section("安全袋", "SAFE"), Vector2(x, y))
	AK.put(stage, FateGrid.make(safe_size, view.safe, ok, scale), Vector2(x, y + 28))
	y += 28 + maxi(worn_h, safe_size.y) * 40 * scale + 16
	AK.put(stage, AK.section("背包", "PACK %d×%d" % [pack_size.x, pack_size.y]), Vector2(420, y))
	AK.put(stage, FateGrid.make(pack_size, view.pack, ok, scale), Vector2(420, y + 28))

static func _at_origin(entry: Dictionary) -> Dictionary:
	var copy := entry.duplicate()
	copy.x = 0
	copy.y = 0
	return copy


## A bag at settlement, scaled up: items where they lay. On a death the kept and
## insured keep their colour with a corner tag, the lost are dimmed.
class FateGrid extends Control:
	const CELL := 40
	var cells := Vector2i.ZERO
	var entries: Array = []
	var extracted := true

	static func make(size_cells: Vector2i, shown: Array, ok: bool, k: float) -> FateGrid:
		var grid := FateGrid.new()
		grid.cells = size_cells
		grid.entries = shown
		grid.extracted = ok
		grid.scale = Vector2(k, k)
		grid.size = Vector2(size_cells) * CELL
		grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		return grid

	func _ready() -> void:
		for entry in entries:
			var square := AK.item_icon(entry.item, Vector2(entry.w, entry.h) * CELL - Vector2.ONE)
			square.position = Vector2(entry.x, entry.y) * CELL
			square.dim = not extracted and entry.reason == "遗失"
			add_child(square)
			if not extracted and FATE_TAGS.has(entry.reason):
				var tag := AK.tag(FATE_TAGS[entry.reason][0], FATE_TAGS[entry.reason][1])
				tag.scale = Vector2(0.6, 0.6)
				tag.position = square.position
				add_child(tag)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(cells) * CELL), Color(0, 0, 0, 0.55))
		for x in range(cells.x + 1): draw_line(Vector2(x * CELL, 0), Vector2(x * CELL, cells.y * CELL), Color(1, 1, 1, 0.07))
		for y in range(cells.y + 1): draw_line(Vector2(0, y * CELL), Vector2(cells.x * CELL, y * CELL), Color(1, 1, 1, 0.07))


## The links of the route map: walked solid, the three choices dashed white.
class RouteLines extends Control:
	var walked: Array[Vector2] = []
	var from := Vector2.ZERO
	var targets: Array[Vector2] = []
	var beyond := Vector2.ZERO

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for i in range(1, walked.size()): draw_line(walked[i - 1], walked[i], Color("666666"), 2.0)
		for t in targets:
			draw_dashed_line(from, t, Color.WHITE, 2.0, 6.0)
			draw_line(t, beyond, Color("444444"), 2.0)


## A placeholder figure until the portraits are drawn (界面策划案 §8).
class Silhouette extends Control:
	var colour := AK.FG

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		draw_circle(Vector2(w * 0.5, 48), 30, Color(colour, 0.85))
		draw_colored_polygon(PackedVector2Array([Vector2(w * 0.5 - 20, 84), Vector2(w * 0.5 + 20, 84), Vector2(w - 8, size.y), Vector2(8, size.y)]), Color("262a2c"))
