class_name BaseScreens
extends RefCounted

## The base stations in the Arknights sub-page shell (界面策划案 v1.1 #11, #13–#17,
## art/ui_mockup): back / home, title, tabs and currency pills along the top, a
## watermark, the station's own layout below. Built on FieldMenu.stage.
## Data, state and buttons only — no rule text (用户 2026-10-05).

const TOP := 72.0
const BOTTOM := 690.0
const STATION_TITLES := {
	"contracts": ["调度台", "DISPATCH"], "insurance": ["后勤柜台", "LOGISTICS"], "loadout": ["整备台", "WORKBENCH"],
	"stash": ["仓管台", "DEPOT"], "outbound": ["出库区", "OUTBOUND"], "report": ["医疗部", "MEDICAL"],
	"pharmacy": ["医疗部", "MEDICAL"], "decon": ["医疗部", "MEDICAL"], "store": ["可露希尔的商店", "CLOSURE'S STORE"],
}
static var _detail: RichTextLabel

## The sub-page shell. `currencies` are [kind, value] pairs: "lmd", "gold", "rank", "ori".
static func shell(menu: FieldMenu, cn_title: String, en_title: String, tabs: Array = [], tab: int = 0, on_tab: Callable = Callable(), watermark: String = "", currencies: Array = []) -> Control:
	var stage := menu.stage_begin(1.0)
	stage.add_child(AK.rect(AK.BG, Vector2.ZERO, Vector2(1280, 720)))
	if not watermark.is_empty():
		var mark := AK.label(watermark, 120, Color(1, 1, 1, 0.04), AK.en())
		AK.put(stage, mark, Vector2(1290 - AK.en().get_string_size(watermark, HORIZONTAL_ALIGNMENT_LEFT, -1, 120).x, 556))
	stage.add_child(AK.rect(Color("0c0c0c"), Vector2.ZERO, Vector2(1280, 60)))
	var back := AK.button("‹", "plain", 22)
	AK.put(stage, back, Vector2(14, 8), Vector2(44, 44))
	back.pressed.connect(menu.game.go_back)
	var home := AK.button("⌂", "plain", 18)
	AK.put(stage, home, Vector2(60, 8), Vector2(44, 44))
	home.pressed.connect(menu.game.close_modal)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -2)
	titles.add_child(AK.label(en_title, 10, AK.MUTE, AK.en()))
	titles.add_child(AK.label(cn_title, 22, AK.FG))
	AK.put(stage, titles, Vector2(120, 8))
	if not tabs.is_empty():
		AK.put(stage, AK.toggle(tabs, tab, on_tab, 13), Vector2(140 + maxf(110.0, cn_title.length() * 23.0), 12))
	var pills := HBoxContainer.new()
	pills.alignment = BoxContainer.ALIGNMENT_END
	pills.add_theme_constant_override("separation", 6)
	for entry in (currencies if not currencies.is_empty() else [["lmd", Economy.format(menu.game.gold)]]):
		pills.add_child(pill(entry[0], entry[1]))
	AK.put(stage, pills, Vector2(700, 14), Vector2(564, 32))
	AK.put(stage, AK.label("RHODES ISLAND · PRTS", 9, AK.DIM, AK.en()), Vector2(1140, 700))
	return stage

static func pill(kind: String, value: String) -> PanelContainer:
	var p := PanelContainer.new()
	var style := AK.box(Color(0, 0, 0, 0.6), Color.TRANSPARENT, 0, 0)
	style.content_margin_left = 10
	style.content_margin_right = 12
	p.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	match kind:
		"lmd", "gold": row.add_child(AK.money(kind, value, 16))
		"rank":
			row.add_child(AK.tag("声望", AK.SP))
			row.add_child(AK.label(value, 15, AK.FG, AK.en()))
		"ori":
			row.add_child(AK.tag("污染", AK.ORI))
			row.add_child(AK.label(value, 15, AK.ORI, AK.en()))
	p.add_child(row)
	return p

static func _rank_text(base: BaseState) -> String:
	var rank := base.rank()
	return "R%d" % rank

static func _section(stage: Control, text: String, en_text: String, at: Vector2) -> void:
	AK.put(stage, AK.section(text, en_text), at)

## Runs one of FieldMenu's list builders into `holder` (reusing its data rows).
static func _list_into(menu: FieldMenu, holder: VBoxContainer, builder: Callable) -> void:
	var saved := menu.body
	menu.body = holder
	builder.call()
	menu.body = saved

static func _wrap(text: String, size: int, colour: Color, width: float) -> Label:
	var l := AK.label(text, size, colour)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	return l

# --- #13 调度台 ----------------------------------------------------------------------

static func contracts(menu: FieldMenu) -> void:
	var game := menu.game
	var regions: Array = FieldCatalog.REGIONS.keys()
	if not menu.region_pick in regions: menu.region_pick = regions[0]
	var region: String = menu.region_pick
	var data: Dictionary = FieldCatalog.REGIONS[region]
	var parts: PackedStringArray = str(data.name).split(" · ")
	var code: String = AK.REGION_CODE.get(region, "LG")
	var en_names := {"mine": "CHERNOBOG", "city": "LUNGMEN", "snow": "SAMI"}
	var stage := shell(menu, "调度台", "DISPATCH", [], 0, Callable(), en_names.get(region, ""))
	# Regions as chapters.
	for i in range(regions.size()):
		var id: String = regions[i]
		var r: Dictionary = FieldCatalog.REGIONS[id]
		var names: PackedStringArray = str(r.name).split(" · ")
		var on := id == region
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.set_meta("label", names[0])
		for s in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(s, AK.box(AK.PAPER if on else (AK.PLATE_3 if s == "hover" else AK.PLATE_2)))
		AK.put(stage, b, Vector2(16, TOP + 6 + i * 104), Vector2(200, 98))
		var ink := AK.INK if on else AK.FG
		AK.put(b, AK.label(AK.REGION_CODE.get(id, "LG"), 22, ink, AK.en()), Vector2(14, 8))
		AK.put(b, AK.label(names[0], 14, ink), Vector2(14, 36))
		AK.put(b, AK.label(names[1] if names.size() > 1 else "", 11, Color(ink, 0.7)), Vector2(14, 56))
		var orders := game.base.orders.pointing_at(id)
		if orders > 0: AK.put(b, AK.tag("订单 %d" % orders, AK.SP), Vector2(14, 74))
		for child in b.get_children(): child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.pressed.connect(func(): menu.region_pick = id; menu.pick = 0; contracts(menu))
	# The floors of a block, snaking, the random-extraction band tinted, the camp.
	var chain := ChainLines.new()
	AK.put(stage, chain, Vector2(232, TOP), Vector2(640, 600))
	for n in range(1, FieldCatalog.CAMP_INTERVAL + 1):
		var i := n - 1
		var row := 0 if i < 5 else 1
		var col := i if row == 0 else 9 - i
		var at := Vector2(232 + 20 + col * 104, TOP + 190 + row * 80)
		var node := AK.label("%s-%02d" % [code, n], 14, AK.FG, AK.en())
		node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var style := AK.box(Color("3b3b2a") if FieldCatalog.RANDOM_EXTRACTION_ODDS.has(n) else AK.PLATE_3)
		node.add_theme_stylebox_override("normal", style)
		AK.put(stage, node, at, Vector2(84, 34))
		chain.points.append(at - Vector2(232, TOP) + Vector2(42, 17))
	var camp := HBoxContainer.new()
	camp.alignment = BoxContainer.ALIGNMENT_CENTER
	camp.add_theme_constant_override("separation", 6)
	camp.add_child(AK.label(game.camp_label(FieldCatalog.CAMP_INTERVAL), 14, AK.INK, AK.en()))
	camp.add_child(AK.label("撤离 · 可露希尔", 11, AK.INK))
	var camp_plate := PanelContainer.new()
	camp_plate.add_theme_stylebox_override("panel", AK.box(AK.GREEN))
	camp_plate.add_child(camp)
	AK.put(stage, camp_plate, Vector2(252, TOP + 350), Vector2(188, 40))
	chain.points.append(Vector2(20 + 94, 350 + 20))
	# The detail, right.
	var x := 884.0
	stage.add_child(AK.rect(Color(0.04, 0.04, 0.04, 0.92), Vector2(x, 60), Vector2(396, 660)))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(AK.tag(code, AK.PAPER))
	head.add_child(AK.label("FIELD CONTRACT", 10, AK.MUTE, AK.en()))
	AK.put(stage, head, Vector2(x + 18, TOP + 8))
	AK.put(stage, AK.label(parts[0], 28, AK.FG), Vector2(x + 18, TOP + 30))
	AK.put(stage, AK.label(parts[1] if parts.size() > 1 else "", 15, AK.FG), Vector2(x + 18, TOP + 70))
	AK.put(stage, _wrap(data.brief, 12, AK.MUTE, 350), Vector2(x + 18, TOP + 96))
	stage.add_child(AK.rect(AK.LINE, Vector2(x + 18, TOP + 140), Vector2(350, 1)))
	_section(stage, "掉落", "DROPS", Vector2(x + 18, TOP + 154))
	var drops := HBoxContainer.new()
	drops.add_theme_constant_override("separation", 8)
	drops.add_child(AK.tag("常规", AK.PAPER))
	drops.add_child(AK.label(data.loot, 12, AK.FG))
	AK.put(stage, drops, Vector2(x + 18, TOP + 182))
	var special := HBoxContainer.new()
	special.add_theme_constant_override("separation", 8)
	special.add_child(AK.tag("专属", AK.SP))
	var exclusive := FieldCatalog.exclusive(region)
	special.add_child(AK.item_icon(exclusive, Vector2(46, 46)))
	special.add_child(AK.label(exclusive.item_name, 12, exclusive.rarity_color()))
	AK.put(stage, special, Vector2(x + 18, TOP + 208))
	AK.put(stage, AK.label("藏品倾向", 12, AK.MUTE), Vector2(x + 18, TOP + 272))
	AK.put(stage, _wrap(str(data.build).split("（")[0], 12, AK.FG, 260), Vector2(x + 100, TOP + 272))
	_section(stage, "起点", "START", Vector2(x + 18, TOP + 310))
	var starts: Array = [0] + game.base.unlocked_camps(region)
	var start: int = int(menu.pick) if menu.pick is int and int(menu.pick) in starts else 0
	var names: Array = starts.map(func(d): return "%s-01" % code if d == 0 else game.camp_label(d))
	var toggle := AK.toggle(names, starts.find(start), func(i): menu.pick = starts[i]; contracts(menu), 13)
	for b in toggle.get_children(): b.custom_minimum_size.x = 96
	AK.put(stage, toggle, Vector2(x + 18, TOP + 338))
	var go := AK.go_button("开始行动", "OPERATION START")
	AK.put(stage, go, Vector2(x + 18, BOTTOM - 84), Vector2(360, 72))
	go.pressed.connect(func():
		game._pending_start_camp = start
		menu.show_departure(region)
		menu.back_to = func(): game.open_station("contracts"))

# --- #14 仓库 -------------------------------------------------------------------------

const STASH_TABS := ["全部", "武器", "防具", "饰品", "材料", "扩建"]

static func stash(menu: FieldMenu) -> void:
	var game := menu.game
	var base: BaseState = game.base
	var tab: int = menu.stash_tab
	var stage := shell(menu, "仓管台", "DEPOT", STASH_TABS, tab, func(i): menu.stash_tab = i; stash(menu), "DEPOT",
		[["lmd", Economy.format(game.gold)], ["rank", _rank_text(base)]])
	if tab == STASH_TABS.size() - 1:
		var holder := VBoxContainer.new()
		holder.add_theme_constant_override("separation", 12)
		AK.put(stage, holder, Vector2(16, TOP + 8), Vector2(1248, 0))
		_list_into(menu, holder, menu._expansion_section)
		return
	# Search, store-all, zone loads (red when full).
	var search := LineEdit.new()
	search.placeholder_text = "搜索"
	search.text = menu.stash_query
	search.add_theme_font_override("font", AK.cn())
	search.text_submitted.connect(func(value: String): menu.stash_query = value; stash(menu))
	AK.put(stage, search, Vector2(16, TOP + 4), Vector2(220, 34))
	var store_all := AK.button("背包材料全部存回", "plain", 12)
	AK.put(stage, store_all, Vector2(244, TOP + 4), Vector2(150, 34))
	store_all.disabled = not game.carried_items().any(func(x): return not x.is_equippable())
	store_all.pressed.connect(func(): game.store_all_materials(); stash(menu))
	var loads := HBoxContainer.new()
	loads.add_theme_constant_override("separation", 14)
	for category in range(Item.Category.size()):
		var have := base.shelf_count(category)
		var room := base.capacity(category)
		var cell := VBoxContainer.new()
		cell.custom_minimum_size.x = 70
		var row := HBoxContainer.new()
		row.add_child(AK.label(BaseCatalog.CATEGORY_NAMES[category], 12, AK.MUTE))
		var fill := Control.new()
		fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(fill)
		row.add_child(AK.label("%d/%d" % [have, room], 12, AK.RED if have >= room else AK.FG, AK.en()))
		cell.add_child(row)
		var bar := FieldPanels.Bar.new()
		bar.ratio = float(have) / maxf(room, 1)
		bar.colour = AK.RED if have >= room else Color("cfcfcf")
		bar.custom_minimum_size.y = 3
		cell.add_child(bar)
		loads.add_child(cell)
	AK.put(stage, loads, Vector2(560, TOP + 6))
	# The shelves as one 16-wide grid, items flowed in.
	var shown: Array = game.stash.filter(func(x: Item): return (tab == 0 or x.category == tab - 1) and menu._matches(x))
	var grid := FlowGrid.make(shown, 16, 10, func(item: Item): game.bring_item(item); stash(menu), func(item: Item): _show_detail(game, item))
	AK.put(stage, grid, Vector2(16, TOP + 50))
	# What goes out with her next.
	var carry_y := TOP + 50 + 10 * 40 + 12
	_section(stage, "将带入", "CARRY-IN", Vector2(16, carry_y + 14))
	var carry := HBoxContainer.new()
	carry.add_theme_constant_override("separation", 6)
	for item in game.carried_items():
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(46, 46)
		b.set_meta("item", item)
		b.add_child(AK.item_icon(item, Vector2(46, 46)))
		var shown_item: Item = item
		b.pressed.connect(func(): game.store_item(shown_item); stash(menu))
		b.mouse_entered.connect(func(): _show_detail(game, shown_item))
		carry.add_child(b)
	AK.put(stage, carry, Vector2(150, carry_y))
	# The detail column.
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", AK.box(Color("0d0d0d"), AK.LINE_2, 1, 12))
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.fit_content = true
	_detail.scroll_active = false
	_detail.custom_minimum_size = Vector2(276, 120)
	_detail.add_theme_font_override("normal_font", AK.cn())
	_detail.add_theme_font_size_override("normal_font_size", 13)
	card.add_child(_detail)
	AK.put(stage, card, Vector2(964, TOP + 50))
	card.visible = not shown.is_empty()
	if not shown.is_empty(): _show_detail(game, shown[0])

static func _show_detail(game: GameManager, item: Item) -> void:
	if is_instance_valid(_detail): _detail.text = ItemTooltip.text(game, item, false, false)

# --- #15 出库区 -----------------------------------------------------------------------

static func outbound(menu: FieldMenu) -> void:
	var game := menu.game
	var base: BaseState = game.base
	var orders: OrderBoard = base.orders
	var tab: int = menu.outbound_tab
	var stage := shell(menu, "出库区", "OUTBOUND", ["订单", "直接交付"], tab, func(i): menu.outbound_tab = i; menu.pick = null; outbound(menu), "ORDERS",
		[["lmd", Economy.format(game.gold)], ["rank", _rank_text(base)]])
	var deliverable := game.deliverable_items()
	if tab == 1:
		var pick: Item = menu.pick if menu.pick is Item else null
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		AK.put(stage, scroll, Vector2(16, TOP + 8), Vector2(1248, 540))
		var list := GridContainer.new()
		list.columns = 4
		list.add_theme_constant_override("h_separation", 6)
		list.add_theme_constant_override("v_separation", 6)
		scroll.add_child(list)
		for item in deliverable:
			var row := EventScreens._item_row(item, Economy.format(Economy.price(item)), "个人仓库" if game.stash.has(item) else "背包", true, item == pick)
			row.custom_minimum_size.x = 306
			var chosen: Item = item
			row.pressed.connect(func(): menu.pick = chosen; outbound(menu))
			list.add_child(row)
		EventScreens._footer(stage, Vector2(16, BOTTOM - 62), 1248, "", "交付" + (" +%s" % Economy.format(Economy.price(pick)) if pick != null else ""), Callable(), func():
			if pick != null: game.sell(pick)
			menu.pick = null
			outbound(menu), pick != null)
		return
	# Prestige, then the order strips.
	var rank := base.rank()
	stage.add_child(AK.rect(AK.PLATE_2, Vector2(16, TOP + 8), Vector2(1248, 64)))
	AK.put(stage, AK.label("PRESTIGE", 9, AK.MUTE, AK.en()), Vector2(32, TOP + 16))
	AK.put(stage, AK.label("R%d" % rank, 30, AK.FG, AK.en()), Vector2(32, TOP + 28))
	if rank < BaseCatalog.PRESTIGE_RANKS.size():
		var need: int = BaseCatalog.PRESTIGE_RANKS[rank]
		AK.put(stage, AK.label("R%d 解锁：%s" % [rank + 1, BaseCatalog.RANK_UNLOCKS[rank + 1]], 12, AK.MUTE), Vector2(110, TOP + 18))
		var count := AK.label("%d / %d" % [base.prestige, need], 12, AK.FG, AK.en())
		AK.put(stage, count, Vector2(1180, TOP + 18))
		var bar := FieldPanels.Bar.new()
		bar.ratio = float(base.prestige) / maxf(need, 1)
		bar.colour = AK.SP
		AK.put(stage, bar, Vector2(110, TOP + 46), Vector2(1138, 6))
	var y := TOP + 86
	for i in range(orders.slots.size()):
		var order = orders.slots[i]
		_order_strip(menu, stage, Vector2(16, y), i, order, deliverable)
		y += 82

static func _order_strip(menu: FieldMenu, stage: Control, at: Vector2, slot: int, order, deliverable: Array[Item]) -> void:
	var game := menu.game
	var orders: OrderBoard = game.base.orders
	if order == null:
		var empty := AK.rect(AK.PLATE_2, at, Vector2(1248, 72))
		empty.modulate.a = 0.4
		stage.add_child(empty)
		AK.put(stage, AK.label("ORDER %02d" % (slot + 1), 10, AK.MUTE, AK.en()), at + Vector2(16, 28))
		return
	var t: Dictionary = BaseCatalog.ORDERS[order.id]
	var colour: Color = GameManager.DEPT_COLOURS.get(t.dept, AK.FG)
	stage.add_child(AK.rect(colour, at, Vector2(110, 72)))
	AK.put(stage, AK.label("ORDER %02d" % (slot + 1), 8, AK.INK, AK.en()), at + Vector2(12, 16))
	AK.put(stage, AK.label(t.dept, 16, AK.INK), at + Vector2(12, 30))
	stage.add_child(AK.rect(AK.PLATE_2, at + Vector2(110, 0), Vector2(1138, 72)))
	var fits: Array = deliverable.filter(func(x): return orders.matches(slot, x))
	if not fits.is_empty(): AK.put(stage, AK.item_icon(fits[0], Vector2(50, 50)), at + Vector2(124, 11))
	var count := int(t.count)
	var what := BaseCatalog.order_text(order.id).trim_prefix(str(t.dept) + "：")
	AK.put(stage, AK.label(what, 14, AK.FG), at + Vector2(188, 14))
	var done: bool = order.state == "done"
	AK.put(stage, AK.label("已完成" if done else "已交付 %d / %d  ·  可交付 %d" % [orders.delivered_count(slot), count, fits.size()], 12, AK.GREEN if done or not fits.is_empty() else AK.MUTE), at + Vector2(188, 40))
	var reward := VBoxContainer.new()
	reward.alignment = BoxContainer.ALIGNMENT_CENTER
	var money := AK.money("lmd", Economy.format(int(t.gold)) if t.has("gold") else "×%s" % str(t.mult), 16)
	money.alignment = BoxContainer.ALIGNMENT_END
	reward.add_child(money)
	var prestige := AK.label("声望 +%d" % int(t.prestige), 12, AK.MUTE)
	prestige.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reward.add_child(prestige)
	AK.put(stage, reward, at + Vector2(840, 10), Vector2(120, 52))
	if done: return
	var small := HBoxContainer.new()
	small.add_theme_constant_override("separation", 4)
	if game.base.reroll_available:
		var reroll := AK.button("刷新", "plain", 12)
		reroll.pressed.connect(func(): game.reroll_order(slot); outbound(menu))
		small.add_child(reroll)
	var drop := AK.button("放弃", "plain", 12)
	drop.pressed.connect(func(): game.abandon_order(slot); outbound(menu))
	small.add_child(drop)
	AK.put(stage, small, at + Vector2(980, 20))
	var deliver := AK.button("交付" if fits.is_empty() or not fits[0].is_stackable() else "交付 ×%d" % orders.takes(slot, fits[0]), "blue" if not fits.is_empty() else "plain", 14)
	deliver.disabled = fits.is_empty()
	AK.put(stage, deliver, at + Vector2(1140, 0), Vector2(108, 72))
	deliver.pressed.connect(func():
		if not fits.is_empty(): game.deliver_to_order(slot, fits[0])
		outbound(menu))

# --- #16 医疗部 -----------------------------------------------------------------------

const MEDICAL_TABS := ["药房窗口", "回收报告", "污染检测门"]

static func medical(menu: FieldMenu, tab: int) -> void:
	var game := menu.game
	var base: BaseState = game.base
	var stage := shell(menu, "医疗部", "MEDICAL", MEDICAL_TABS, tab, func(i): medical(menu, i), "MEDICAL",
		[["lmd", Economy.format(game.gold)], ["ori", str(roundi(base.contamination))]])
	_contamination_card(stage, base, Vector2(924, TOP + 8))
	match tab:
		0:
			_section(stage, "将带入 · 背包", "CARRY-IN", Vector2(16, TOP + 8))
			AK.put(stage, AK.BagGrid.make(game.inventory), Vector2(16, TOP + 36))
			var y := TOP + 36 + game.inventory.height * 40 + 20
			_section(stage, "可配药剂", "PHARMACY", Vector2(16, y))
			var x := 16.0
			for type in BaseCatalog.POTIONS:
				var potion: Dictionary = BaseCatalog.POTIONS[type]
				var price := base.potion_price(type)
				var card := Button.new()
				card.focus_mode = Control.FOCUS_NONE
				card.set_meta("label", potion.name)
				for s in ["normal", "hover", "pressed", "disabled"]:
					var style := AK.box(AK.PLATE_3 if s == "hover" else AK.PLATE_2)
					style.border_color = AK.ORI if type == "C" else AK.GREEN
					style.border_width_bottom = 3
					card.add_theme_stylebox_override(s, style)
				card.disabled = price < 0 or game.gold < price or not game.inventory.can_fit(BaseCatalog.create_potion(type))
				if price < 0: card.modulate.a = 0.4
				AK.put(stage, card, Vector2(x, y + 30), Vector2(290, 92))
				AK.put(card, AK.item_icon(BaseCatalog.create_potion(type), Vector2(52, 52)), Vector2(12, 12))
				AK.put(card, AK.label(potion.name, 14, AK.FG), Vector2(76, 10))
				var effect := _wrap(potion.text, 11, AK.MUTE, 200)
				AK.put(card, effect, Vector2(76, 30))
				var cost := "R%d" % int(potion.rank) if price < 0 else ("免费" if price == 0 else Economy.format(price) + " 龙门币")
				AK.put(card, AK.label(cost, 13, AK.SP, AK.en() if price > 0 else AK.cn()), Vector2(76, 66))
				for child in card.get_children(): child.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var kind: String = type
				card.pressed.connect(func(): game.buy_potion(kind); medical(menu, 0))
				x += 300
			AK.put(stage, AK.label("免费急救剂 %d" % base.free_potions, 12, AK.MUTE), Vector2(16, y + 132))
		1:
			var holder := VBoxContainer.new()
			holder.add_theme_constant_override("separation", 10)
			AK.put(stage, holder, Vector2(16, TOP + 8), Vector2(880, 0))
			_list_into(menu, holder, menu._medical_summary)
			holder.add_child(AK.section("回收明细", "RECOVERY"))
			if game.settlement.is_empty(): holder.add_child(AK.label("暂无回收记录", 14, AK.MUTE))
			for entry in game.settlement:
				var row := HBoxContainer.new()
				row.add_child(AK.label(entry.name, 14, AK.FG))
				var fill := Control.new()
				fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(fill)
				var colour: Color = {"撤离带回": AK.GREEN, "安全袋保全": AK.GREEN, "投保送回": AK.HP}.get(entry.reason, AK.RED)
				row.add_child(AK.label(entry.reason + (" · %d 份合同后" % int(entry.contracts) if entry.has("contracts") else ""), 13, colour))
				holder.add_child(row)
		2:
			var holder := VBoxContainer.new()
			holder.add_theme_constant_override("separation", 10)
			AK.put(stage, holder, Vector2(16, TOP + 8), Vector2(880, 0))
			_list_into(menu, holder, menu._decon_section)

static func _contamination_card(stage: Control, base: BaseState, at: Vector2) -> void:
	_section(stage, "污染", "CONTAMINATION", at)
	stage.add_child(AK.rect(AK.PLATE_2, at + Vector2(0, 30), Vector2(340, 130)))
	var value := roundi(base.contamination)
	AK.put(stage, AK.label(str(value), 52, AK.ORI, AK.en()), at + Vector2(16, 38))
	AK.put(stage, AK.tag(BaseCatalog.CONTAMINATION_TIER_NAMES[base.contamination_tier()], AK.ORI), at + Vector2(120, 66))
	var bar := FieldPanels.Bar.new()
	bar.ratio = base.contamination / 100.0
	bar.colour = AK.ORI
	AK.put(stage, bar, at + Vector2(16, 112), Vector2(308, 6))
	for tier in BaseCatalog.CONTAMINATION_TIERS:
		var threshold := int(tier[0])
		var name: String = BaseCatalog.CONTAMINATION_TIER_NAMES[BaseCatalog.CONTAMINATION_TIERS.find(tier)]
		AK.put(stage, AK.label("%d %s" % [threshold, name] if threshold > 0 else "0", 10, AK.MUTE), at + Vector2(16 + 308 * threshold / 100.0 - (0 if threshold == 0 else 14), 124))

# --- #17 出发准备 / 整备 ----------------------------------------------------------------

## `region` empty = the workbench / logistics counter: the same loadout, with item
## actions on the right instead of the deployment target.
static func departure(menu: FieldMenu, region: String, kind: String = "") -> void:
	var game := menu.game
	var base: BaseState = game.base
	var deploying := not region.is_empty()
	var titles: Array = ["出发准备", "SQUAD"] if deploying else STATION_TITLES.get(kind, ["整备台", "WORKBENCH"])
	var stage := shell(menu, titles[0], titles[1], [], 0, Callable(), AK.REGION_CODE.get(region, "") if deploying else "")
	# The operator card.
	var card := Control.new()
	card.clip_contents = true
	AK.put(stage, card, Vector2(16, TOP + 6), Vector2(250, BOTTOM - TOP - 6))
	card.add_child(AK.rect(Color("262626"), Vector2.ZERO, card.size))
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 0.77, 0, 0.0))
	gradient.set_color(1, Color(1, 0.77, 0, 0.28))
	var fade := GradientTexture2D.new()
	fade.gradient = gradient
	fade.fill_from = Vector2(0, 0)
	fade.fill_to = Vector2(0, 1)
	var glow := TextureRect.new()
	glow.texture = fade
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	AK.put(card, glow, Vector2(0, card.size.y * 0.45), Vector2(250, card.size.y * 0.55))
	var sprite := TextureRect.new()
	if ResourceLoader.exists("res://ui/art/lappland_portrait.png"): sprite.texture = load("res://ui/art/lappland_portrait.png")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	AK.put(card, sprite, Vector2(-1, 90), Vector2(252, 252))
	var cls := AK.label("近卫", 13, AK.FG)
	cls.add_theme_stylebox_override("normal", AK.box(Color.BLACK, Color.TRANSPARENT, 0, 10))
	AK.put(card, cls, Vector2.ZERO)
	AK.put(card, AK.label("★★★★★", 13, AK.SP), Vector2(12, card.size.y - 58))
	AK.put(card, AK.label("拉普兰德", 20, AK.FG), Vector2(12, card.size.y - 40))
	card.add_child(AK.rect(AK.SP, Vector2(0, card.size.y - 4), Vector2(250, 4)))
	# Loadout: the worn three, insurable; then the pack.
	var pick: Item = menu.pick if menu.pick is Item else null
	_section(stage, "带入装备", "LOADOUT", Vector2(282, TOP + 8))
	var y := TOP + 36
	for category in [Item.Category.WEAPON, Item.Category.ARMOR, Item.Category.TRINKET]:
		var item: Item = game.player.equipped.get(category)
		var row := Button.new()
		row.focus_mode = Control.FOCUS_NONE
		for s in ["normal", "hover", "pressed", "disabled"]:
			row.add_theme_stylebox_override(s, AK.box(Color("333333") if item != null and (item == pick or s == "hover") else AK.PLATE_2))
		AK.put(stage, row, Vector2(282, y), Vector2(610, 64))
		if item == null:
			AK.put(row, AK.label("%s · 空" % Item.CATEGORY_NAMES[category], 13, AK.MUTE), Vector2(16, 22))
			row.disabled = true
		else:
			row.set_meta("item", item)
			AK.put(row, AK.item_icon(item, Vector2(60, 60)), Vector2(2, 2))
			AK.put(row, AK.label(item.display_name(), 14, item.rarity_color()), Vector2(74, 12))
			AK.put(row, AK.label("%s · 价值 %s" % [Item.CATEGORY_NAMES[category], Economy.format(Economy.price(item))], 12, AK.MUTE), Vector2(74, 36))
			for child in row.get_children(): child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var chosen := item
			row.pressed.connect(func(): menu.pick = chosen; _refresh(menu, region, kind))
			_insure_control(menu, stage, item, Vector2(282 + 610 - 150, y + 14), region, kind)
			if pick == item: AK.frame(row)
		y += 70
	_section(stage, "背包", "PACK %d×%d" % [game.inventory.width, game.inventory.height], Vector2(282, y + 6))
	var pick_item := func(item: Item): menu.pick = item; _refresh(menu, region, kind)
	AK.put(stage, AK.BagGrid.make(game.inventory, Callable(), pick_item, pick), Vector2(282, y + 34))
	# Right column.
	var x := 924.0
	stage.add_child(AK.rect(Color(0.04, 0.04, 0.04, 0.92), Vector2(x - 16, 60), Vector2(372, 660)))
	if deploying:
		var data: Dictionary = FieldCatalog.REGIONS[region]
		var parts: PackedStringArray = str(data.name).split(" · ")
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		head.add_child(AK.tag(AK.REGION_CODE.get(region, "LG"), AK.PAPER))
		head.add_child(AK.label("DEPLOY TO", 10, AK.MUTE, AK.en()))
		AK.put(stage, head, Vector2(x, TOP + 8))
		AK.put(stage, AK.label(parts[0], 30, AK.FG), Vector2(x, TOP + 30))
		AK.put(stage, AK.label(parts[1] if parts.size() > 1 else "", 15, AK.FG), Vector2(x, TOP + 72))
		var start: int = game._pending_start_camp
		var cells := [["起点", game.camp_label(start) if start > 0 else AK.floor_code(region, 1), AK.GREEN if start > 0 else AK.FG],
			["深度", AK.floor_code(region, start + 1), AK.FG], ["污染", str(roundi(base.contamination)), AK.ORI]]
		for i in range(3):
			stage.add_child(AK.rect(AK.PLATE_2, Vector2(x + i * 114, TOP + 104), Vector2(108, 56)))
			AK.put(stage, AK.label(cells[i][0], 11, AK.MUTE), Vector2(x + i * 114 + 8, TOP + 110))
			AK.put(stage, AK.label(cells[i][1], 15, cells[i][2], AK.en() if i > 0 or start == 0 else AK.cn()), Vector2(x + i * 114 + 8, TOP + 130))
		var tags := HBoxContainer.new()
		tags.add_theme_constant_override("separation", 6)
		var orders := base.orders.pointing_at(region)
		if orders > 0: tags.add_child(AK.tag("订单 %d" % orders, AK.SP))
		if base.contamination_tier() > 0: tags.add_child(AK.tag("污染 " + BaseCatalog.CONTAMINATION_TIER_NAMES[base.contamination_tier()], AK.ORI))
		if base.injured: tags.add_child(AK.tag("重伤", AK.RED))
		AK.put(stage, tags, Vector2(x, TOP + 172))
		var warn_y := TOP + 204
		for warning in game.departure_warnings():
			AK.put(stage, _wrap(warning, 12, AK.SP, 340), Vector2(x, warn_y))
			warn_y += 40
		AK.put(stage, AK.label("药剂 %d" % game.carried_potions().size(), 12, AK.MUTE), Vector2(x, BOTTOM - 120))
		var go := AK.go_button("开始行动", "OPERATION START")
		AK.put(stage, go, Vector2(x, BOTTOM - 96), Vector2(340, 84))
		go.pressed.connect(func(): game.start_contract(region, game._pending_start_camp))
		return
	# Workbench / logistics: what the picked item can do here.
	if pick == null or not game.carried_items().has(pick):
		var all := AK.button("背包与安全袋的材料全部存回仓库", "plain", 13)
		all.disabled = not game.carried_items().any(func(it): return not it.is_equippable())
		all.pressed.connect(func(): game.store_all_materials(); _refresh(menu, region, kind))
		AK.put(stage, all, Vector2(x, TOP + 8), Vector2(340, 44))
		return
	EventScreens._info(stage, game, pick, "交付价", Economy.format(Economy.price(pick)), Vector2(x, TOP + 8))
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	if game.inventory.items.has(pick) and pick.is_equippable():
		var equip := AK.button("装备", "blue", 14)
		equip.pressed.connect(func(): game.equip_from(pick, game.inventory); game.save_base(); menu.pick = null; _refresh(menu, region, kind))
		actions.add_child(equip)
	if game.player.equipped.values().has(pick):
		var off := AK.button("卸下", "plain", 14)
		off.pressed.connect(func(): game.unequip_to_pack(pick); game.save_base(); _refresh(menu, region, kind))
		actions.add_child(off)
	var store := AK.button("存回仓库", "plain", 14)
	store.pressed.connect(func(): game.store_item(pick); menu.pick = null; _refresh(menu, region, kind))
	actions.add_child(store)
	for b in actions.get_children(): b.custom_minimum_size = Vector2(340, 44)
	AK.put(stage, actions, Vector2(x, BOTTOM - actions.get_child_count() * 50))

static func _insure_control(menu: FieldMenu, stage: Control, item: Item, at: Vector2, region: String, kind: String) -> void:
	var game := menu.game
	if item.insured:
		AK.put(stage, AK.tag("已投保", AK.HP, false), at + Vector2(70, 10))
		return
	var price := game.insurance_price(item)
	var b := AK.button("投保 %s" % Economy.format(price), "plain", 12)
	b.disabled = game.gold < price
	b.pressed.connect(func(): game.insure(item); _refresh(menu, region, kind))
	AK.put(stage, b, at, Vector2(140, 36))

static func _refresh(menu: FieldMenu, region: String, kind: String) -> void:
	departure(menu, region, kind)

# --- 可露希尔的商店 (base) ---------------------------------------------------------

static func store(menu: FieldMenu) -> void:
	EventScreens.camp(menu, true)

# --- #11 暂停与设置 ------------------------------------------------------------------

const PAUSE_ITEMS := ["继续作业", "设置", "按键说明", "放弃合同", "回到标题"]
const SETTING_TABS := ["画面", "界面", "音频"]

static func pause(menu: FieldMenu) -> void:
	var game := menu.game
	var stage := menu.stage_begin(0.85)
	var page: int = menu.pause_page
	stage.add_child(AK.rect(Color("0e0e0e"), Vector2.ZERO, Vector2(280, 720)))
	AK.put(stage, AK.label("PAUSED", 10, AK.MUTE, AK.en()), Vector2(26, 36))
	AK.put(stage, AK.label("暂停", 28, AK.FG), Vector2(26, 50))
	var y := 110.0
	for i in range(PAUSE_ITEMS.size()):
		if i == 3 and game.in_base: continue
		if i == 4 and not is_instance_valid(game.system_screens): continue
		var on := i == page
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.text = "确认放弃" if i == 3 and menu.pause_confirm else PAUSE_ITEMS[i]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", AK.cn())
		b.add_theme_font_size_override("font_size", 15)
		for s in ["normal", "hover", "pressed"]:
			var style := AK.box(AK.PAPER if on else (Color(1, 1, 1, 0.06) if s == "hover" else Color.TRANSPARENT))
			style.content_margin_left = 26
			b.add_theme_stylebox_override(s, style)
		var colour := AK.INK if on else (AK.RED if i == 3 else AK.FG)
		for c in ["font_color", "font_hover_color", "font_pressed_color"]: b.add_theme_color_override(c, colour)
		AK.put(stage, b, Vector2(0, y), Vector2(280, 46))
		var index := i
		b.pressed.connect(func(): _pause_pick(menu, index))
		y += 46
	if page == 1: _settings(menu, stage)
	elif page == 2: _keys(stage)

static func _pause_pick(menu: FieldMenu, index: int) -> void:
	var game := menu.game
	match index:
		0:
			menu.pause_confirm = false
			game.close_modal()
		1, 2:
			menu.pause_page = index
			pause(menu)
		3:
			if not menu.pause_confirm:
				menu.pause_confirm = true
				pause(menu)
				return
			menu.pause_confirm = false
			game.close_modal()
			game.player.hp = 0
			game._on_player_died()
		4:
			game.close_modal()
			game.system_screens.show_title()

static func _panel(stage: Control) -> Control:
	var panel := AK.rect(AK.PLATE_SOLID, Vector2(310, 36), Vector2(934, 648))
	stage.add_child(panel)
	return panel

static func _settings(menu: FieldMenu, stage: Control) -> void:
	_panel(stage)
	var tab: int = menu.settings_tab
	AK.put(stage, AK.toggle(SETTING_TABS, tab, func(i): menu.settings_tab = i; pause(menu), 14), Vector2(324, 48))
	var s := SystemScreens.settings
	var rows: Array = []
	match tab:
		0: rows = [["窗口模式", ["窗口", "全屏"], "fullscreen"], ["垂直同步", ["关", "开"], "vsync"]]
		1: rows = [["伤害数字", ["关", "开"], "damage_numbers"], ["订单追踪", ["隐藏", "显示"], "tracker"], ["PRTS 播报", ["隐藏", "显示"], "broadcasts"]]
		2: rows = [["主音量", [], "master_volume"]]
	var y := 104.0
	for row in rows:
		AK.put(stage, AK.label(row[0], 14, AK.FG), Vector2(334, y + 12))
		var key: String = row[2]
		if row[1].is_empty():
			var slider := HSlider.new()
			slider.min_value = 0.0
			slider.max_value = 1.0
			slider.step = 0.05
			slider.value = float(s.get(key, 0.8))
			slider.value_changed.connect(func(v): SystemScreens.set_setting(key, v))
			AK.put(stage, slider, Vector2(900, y + 12), Vector2(320, 24))
		else:
			var current := 1 if bool(s.get(key, false)) else 0
			var toggle := AK.toggle(row[1], current, func(i): SystemScreens.set_setting(key, i == 1); pause(menu), 13)
			toggle.alignment = BoxContainer.ALIGNMENT_END
			AK.put(stage, toggle, Vector2(900, y + 6), Vector2(320, 38))
		stage.add_child(AK.rect(AK.LINE, Vector2(334, y + 49), Vector2(886, 1)))
		y += 50

static func _keys(stage: Control) -> void:
	_panel(stage)
	var rows := [["移动", "WASD  方向键  右键"], ["攻击", "左键"], ["闪避 / 药剂 / 交互", "Shift  Q  E"], ["干员 · 背包", "I  C"], ["藏品 / 地图 / 合同", "R  M  J"],
		["地面物品名", "Alt"], ["安全袋", "Ctrl + 左键"], ["暂停", "Esc"]]
	var y := 60.0
	for row in rows:
		AK.put(stage, AK.label(row[0], 14, AK.FG), Vector2(334, y + 12))
		var keys := AK.label(row[1], 14, AK.FG, AK.en())
		keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		AK.put(stage, keys, Vector2(900, y + 12), Vector2(320, 24))
		stage.add_child(AK.rect(AK.LINE, Vector2(334, y + 49), Vector2(886, 1)))
		y += 50


## The dashed path through a block's floors to its camp.
class ChainLines extends Control:
	var points: Array[Vector2] = []
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		for i in range(1, points.size()): draw_dashed_line(points[i - 1], points[i], Color("5a5a5a"), 2.0, 5.0)


## The depot shelves as one grid: items flowed left to right into rows, as the
## Arknights depot lists them. Click brings one out; hover shows its detail.
class FlowGrid extends Control:
	const CELL := 40
	var items: Array = []
	var columns := 16
	var rows := 10
	var on_pick: Callable
	var on_hover: Callable

	static func make(shown: Array, w: int, h: int, pick: Callable, hover: Callable) -> FlowGrid:
		var grid := FlowGrid.new()
		grid.items = shown
		grid.columns = w
		grid.rows = h
		grid.on_pick = pick
		grid.on_hover = hover
		grid.custom_minimum_size = Vector2(w, h) * CELL
		grid.size = grid.custom_minimum_size
		return grid

	func _ready() -> void:
		var x := 0
		var y := 0
		var row_h := 0
		for item: Item in items:
			if x + item.width > columns:
				x = 0
				y += row_h
				row_h = 0
			if y + item.height > rows: break
			var tile := Button.new()
			tile.flat = true
			tile.focus_mode = Control.FOCUS_NONE
			tile.position = Vector2(x, y) * CELL
			tile.size = Vector2(item.width, item.height) * CELL - Vector2.ONE
			tile.set_meta("item", item)
			tile.add_child(AK.item_icon(item, tile.size))
			var shown := item
			tile.pressed.connect(func(): on_pick.call(shown))
			tile.mouse_entered.connect(func(): on_hover.call(shown))
			add_child(tile)
			x += item.width
			row_h = maxi(row_h, item.height)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(columns, rows) * CELL), Color(0, 0, 0, 0.55))
		for gx in range(columns + 1): draw_line(Vector2(gx * CELL, 0), Vector2(gx * CELL, rows * CELL), Color(1, 1, 1, 0.07))
		for gy in range(rows + 1): draw_line(Vector2(0, gy * CELL), Vector2(columns * CELL, gy * CELL), Color(1, 1, 1, 0.07))

# --- 开箱卡片 / 暂存区 (界面策划案 §6: reuse the item tile and detail) ---------------

static func item_card(menu: FieldMenu, item: Item) -> void:
	var game := menu.game
	var base: BaseState = game.base
	var stage := menu.stage_begin(0.85)
	var panel := AK.rect(Color("101010"), Vector2(260, 130), Vector2(760, 460))
	stage.add_child(panel)
	stage.add_child(AK.rect(AK.tier_color(item), Vector2(260, 130), Vector2(760, 4)))
	AK.put(stage, AK.label("CRATE", 10, AK.MUTE, AK.en()), Vector2(284, 152))
	AK.put(stage, AK.label("开箱", 24, AK.FG), Vector2(284, 166))
	AK.put(stage, AK.item_icon(item, Vector2(item.width, item.height) * 80), Vector2(284, 214))
	EventScreens._info(stage, game, item, "交付价", Economy.format(Economy.price(item)), Vector2(620, 152))
	var holding := base.hand != null
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var take := AK.button("拿起 · %s %d/%d" % [BaseCatalog.CATEGORY_NAMES[item.category], base.shelf_count(item.category), base.capacity(item.category)], "blue", 14)
	take.disabled = holding
	take.pressed.connect(func(): game.pick_up_item(item); game.close_modal())
	row.add_child(take)
	var stage_it := AK.button("放入暂存区 %d/%d" % [base.staging.size(), BaseCatalog.STAGING_CAPACITY], "plain", 14)
	stage_it.disabled = not base.staging_has_room()
	stage_it.pressed.connect(func(): game.stage_item(item); game.close_modal())
	row.add_child(stage_it)
	if base.drone:
		var sort := AK.button("全部开箱并归类", "plain", 14)
		sort.pressed.connect(func(): game.close_modal(); game.sort_everything())
		row.add_child(sort)
	var later := AK.button("先留在箱里", "plain", 14)
	later.pressed.connect(game.close_modal)
	row.add_child(later)
	for b in row.get_children(): b.custom_minimum_size.y = 48
	AK.put(stage, row, Vector2(284, 520))

static func staging(menu: FieldMenu) -> void:
	var game := menu.game
	var base: BaseState = game.base
	var stage := shell(menu, "暂存区", "STAGING", [], 0, Callable(), "STAGING", [["lmd", Economy.format(game.gold)]])
	var pick: Item = menu.pick if menu.pick is Item else null
	AK.put(stage, AK.section("暂存区", "%d / %d" % [base.staging.size(), BaseCatalog.STAGING_CAPACITY]), Vector2(16, TOP + 8))
	var list := GridContainer.new()
	list.columns = 3
	list.add_theme_constant_override("h_separation", 6)
	list.add_theme_constant_override("v_separation", 6)
	AK.put(stage, list, Vector2(16, TOP + 40))
	for item in base.staging:
		var row := EventScreens._item_row(item, "", BaseCatalog.CATEGORY_NAMES[item.category], true, item == pick)
		row.custom_minimum_size.x = 290
		var chosen: Item = item
		row.pressed.connect(func(): menu.pick = chosen; staging(menu))
		list.add_child(row)
	var x := 924.0
	if pick != null and base.staging.has(pick):
		EventScreens._info(stage, game, pick, "交付价", Economy.format(Economy.price(pick)), Vector2(x, TOP + 8))
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	var hand := AK.button("拿到手上", "blue", 14)
	hand.disabled = pick == null or base.hand != null
	hand.pressed.connect(func(): game.pick_up_item(pick); game.close_modal())
	actions.add_child(hand)
	var pack := AK.button("放进背包", "plain", 14)
	pack.disabled = pick == null
	pack.pressed.connect(func(): game.unstage_to_pack(pick); menu.pick = null; staging(menu))
	actions.add_child(pack)
	if base.drone and (base.sealed_count() > 0 or not base.staging.is_empty()):
		var sort := AK.button("全部开箱并归类", "plain", 14)
		sort.pressed.connect(func(): game.close_modal(); game.sort_everything())
		actions.add_child(sort)
	for b in actions.get_children(): b.custom_minimum_size = Vector2(340, 44)
	AK.put(stage, actions, Vector2(x, BOTTOM - actions.get_child_count() * 50))
