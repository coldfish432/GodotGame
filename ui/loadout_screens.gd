class_name LoadoutScreens
extends RefCounted

## The workbench split in four (界面美术与布局策划案 v2 §3 S2, §5.3–§5.6):
##   整备台 · 换装   — the doll, the depot's gear and flasks, the pack
##   整备台 · 改造   — 重铸 / 校准 / 精调 on one piece, in a fixture
##   整备台 · 制式   — Rhodes standard gear, free into any slot for one contract
##   后勤柜台 · 投保 — every carried piece with its insurance
##   出发准备        — who goes (operator chips), a read-only loadout, the target
## Operators are picked on these screens (用户 2026-10-21: 还是得在准备出发的这几个界面能选择干员).
## No class, no stars. Data, state and buttons only.

const TOP := 76.0
const BOTTOM := 684.0
const LOG := Color("4b9be0")

static func _panel(stage: Control, r: Rect2, accent: Color) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", Terminal.panel_style("plate"))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	AK.put(stage, p, r.position, r.size)
	Terminal.frame(p, accent, 0.0)
	return p

## A row of operator chips (head and shoulders of the UA portrait); the one
## going out is framed in its colour. `chip` = the chip's size.
static func operator_chips(menu: FieldMenu, stage: Control, at: Vector2, chip: Vector2, redraw: Callable) -> void:
	var game := menu.game
	var x := at.x
	for id in game.base.deployable():
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.set_meta("operator", id)
		b.tooltip_text = Operators.display_name(id)
		var on: bool = id == game.player.operator_id
		for s in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(s, AK.box(AK.PLATE_3 if s == "hover" else AK.PLATE_2, AK.SP if on else AK.LINE, 2 if on else 1))
		AK.put(stage, b, Vector2(x, at.y), chip)
		var art := OperatorScreen.standing(id)
		if art != null:
			var head := AtlasTexture.new()
			head.atlas = art
			head.region = Rect2((art.get_width() - 72) * 0.5, 2, 72, 72 * chip.y / chip.x)
			var image := TextureRect.new()
			image.texture = head
			image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			image.mouse_filter = Control.MOUSE_FILTER_IGNORE
			AK.put(b, image, Vector2(2, 2), chip - Vector2(4, 4))
		else:
			var name := AK.label(Operators.display_name(id).left(2), 12, AK.FG)
			name.mouse_filter = Control.MOUSE_FILTER_IGNORE
			AK.put(b, name, Vector2(6, chip.y * 0.5 - 9))
		if game.base.injured and on: b.add_child(AK.rect(AK.RED, Vector2(chip.x - 10, 0), Vector2(10, 10)))
		var chosen: String = id
		b.pressed.connect(func(): game.choose_operator(chosen); redraw.call())
		x += chip.x + 4

## The 8-slot doll (PaperDoll) at `scale`; `on_pick` null = read-only. Returns its slots.
static func doll(game: GameManager, stage: Control, at: Vector2, scale: float, pick: Item, on_pick: Callable) -> Array:
	var slots: Array = []
	PaperDoll.decorate(game, stage, at, scale)
	for slot_category in PaperDoll.SPOTS:
		var r: Rect2 = PaperDoll.SPOTS[slot_category]
		var slot := DollSlot.new()
		slot.category = slot_category
		slot.item = PaperDoll.worn(game, slot_category)
		slot.picked = slot.item != null and slot.item == pick
		slot.focus_mode = Control.FOCUS_NONE
		slot.disabled = slot.item == null or not on_pick.is_valid()
		slot.tooltip_text = Item.slot_name(slot_category) if slot.item == null else ""
		AK.put(stage, slot, at + r.position * scale, r.size * scale)
		if slot.item != null:
			slot.set_meta("item", slot.item)
			var chosen := slot.item
			if on_pick.is_valid(): slot.pressed.connect(func(): on_pick.call(chosen))
		slots.append(slot)
	return slots


## A doll slot outside the I window: silhouette when empty, the piece (the
## weapon standing) in its rarity frame, a 保 mark when insured.
class DollSlot extends Button:
	var category := 0
	var item: Item
	var picked := false
	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		for s in ["normal", "hover", "pressed", "disabled"]:
			add_theme_stylebox_override(s, StyleBoxEmpty.new())
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0, 0, 0, 0.5))
		if item == null:
			draw_rect(r, AK.LINE, false, 1.0)
			PaperDoll.draw_silhouette(self, category, size)
			return
		var c := AK.tier_color(item)
		for i in range(8):
			var k := float(i) / 8
			draw_rect(Rect2(0, size.y * (0.4 + 0.6 * k), size.x, size.y * 0.6 / 8 + 1), Color(c, 0.05 + 0.25 * k))
		PaperDoll.draw_item(self, item, category, size)
		draw_rect(r, AK.HOLO if picked else c, false, 2.0 if picked else 1.0)
		if item.insured:
			draw_rect(Rect2(size.x - 14, 2, 12, 12), Color("4fd1c5"))

# --- 整备台 ------------------------------------------------------------------------

const WORKBENCH_TABS := ["换装", "改造", "制式"]

static func workbench(menu: FieldMenu) -> void:
	var tab: int = clampi(menu.workbench_tab, 0, WORKBENCH_TABS.size() - 1)
	var stage := BaseScreens.shell(menu, "整备台", "WORKBENCH", WORKBENCH_TABS, tab, func(i): menu.workbench_tab = i; menu.pick = null; workbench(menu), "LOADOUT")
	match tab:
		0: _change(menu, stage)
		1: _refit(menu, stage)
		_: _issue(menu, stage)

static func _change(menu: FieldMenu, stage: Control) -> void:
	var game := menu.game
	var redraw := func(): workbench(menu)
	var pick: Item = menu.pick if menu.pick is Item else null
	var pick_item := func(item: Item): menu.pick = item; redraw.call()
	# Left: who and what she wears.
	_panel(stage, Rect2(16, TOP, 360, BOTTOM - TOP), LOG)
	AK.put(stage, AK.label(Operators.display_name(game.player.operator_id), 22, AK.FG), Vector2(32, TOP + 12))
	var p: OperatorProgress = game.progress()
	AK.put(stage, AK.label("%s · Lv %d" % [Progression.ELITE_NAMES[p.elite], p.level], 12, AK.MUTE, AK.en()), Vector2(32, TOP + 44))
	var slots := doll(game, stage, Vector2(24, TOP + 66), 0.88, pick, pick_item)
	# Drag (用户 2026-10-21: 整备台实现拖拽装备/拖入背包): onto a slot wears it,
	# onto the pack or safe bag carries it, onto the depot stores it.
	for slot: DollSlot in slots:
		slot.disabled = false
		var category := slot.category
		ItemDrag.wire(slot, slot.item, func(item: Item) -> bool: return PaperDoll.fits(item, category) and _where(game, item) != "worn",
			func(item: Item): _wear(game, item); menu.pick = null; redraw.call())
	AK.put(stage, AK.section("干员", "OPERATOR"), Vector2(32, TOP + 446))
	operator_chips(menu, stage, Vector2(30, TOP + 472), Vector2(34, 40), redraw)
	var train := AK.button("干员 C" + (" ●" if p.attribute_points + p.skill_points > 0 else ""), "yellow" if p.attribute_points + p.skill_points > 0 else "plain", 13)
	train.pressed.connect(func(): game.open_training(func(): game.open_modal("station"); game.open_station("loadout")))
	AK.put(stage, train, Vector2(32, BOTTOM - 56), Vector2(150, 40))
	var shop := AK.button("加工站", "plain", 13)
	shop.pressed.connect(func():
		menu.show_station("workshop")
		menu.back_to = func(): menu.show_station("loadout"))
	AK.put(stage, shop, Vector2(194, BOTTOM - 56), Vector2(150, 40))
	# Middle: the depot (用户 2026-10-21 图): a tab per slot and 药剂, the pieces
	# packed into a 10-wide grid that runs the column's height and scrolls,
	# the cells taken over the cells shown. Hover shows the card; drag moves;
	# right click wears a piece or brings a flask.
	_panel(stage, Rect2(392, TOP, 440, BOTTOM - TOP), LOG)
	depot_tab = clampi(depot_tab, 0, DEPOT_TABS.size() - 1)
	var tabs := AK.toggle(DEPOT_TABS, depot_tab, func(i): depot_tab = i; menu.pick = null; redraw.call(), 12)
	# Ten tabs in the column: the text may not widen a button past its share.
	for b: Button in tabs.get_children():
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var box := b.get_theme_stylebox(state)
			if box == null: continue
			box = box.duplicate()
			box.content_margin_left = 2
			box.content_margin_right = 2
			b.add_theme_stylebox_override(state, box)
		b.custom_minimum_size = Vector2(42, 30)
	AK.put(stage, tabs, Vector2(406, TOP + 10))
	var shown: Array = game.stash.filter(func(it: Item): return _depot_shows(it, depot_tab))
	TraderScreen._game = game
	var depot := BaseScreens.FlowGrid.packed(shown, 10, DEPOT_ROWS, pick_item)
	depot.on_alt = func(item: Item):
		if item.is_equippable(): _wear(game, item)
		else: game.bring_item(item)
		menu.pick = null
		redraw.call()
	depot.dragging(func(item: Item) -> bool: return _where(game, item) in ["pack", "worn"],
		func(item: Item): _store(game, item); menu.pick = null; redraw.call())
	AK.put(stage, AK.section("仓库", "DEPOT · %d / %d" % [depot.used_cells(), depot.columns * depot.rows]), Vector2(412, TOP + 54))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	AK.put(stage, scroll, Vector2(412, TOP + 82), Vector2(10 * 40 + 12, BOTTOM - TOP - 94))
	scroll.add_child(depot)
	# Right: the pack and safe bag.
	_pack_column(menu, stage, Rect2(848, TOP, 416, BOTTOM - TOP), pick, pick_item, redraw)

## Where a piece is on the workbench: "stash", "worn", "pack" (pack or safe bag).
static func _where(game: GameManager, item: Item) -> String:
	if game.stash.has(item): return "stash"
	if game.player.equipped.values().has(item): return "worn"
	if game.inventory.items.has(item) or game.safe_bag.items.has(item): return "pack"
	return ""

static func _wear(game: GameManager, item: Item) -> void:
	match _where(game, item):
		"stash": game.equip_from_stash(item)
		"pack": game.equip_from(item, game.inventory if game.inventory.items.has(item) else game.safe_bag)
	game.save_base()

## Into `bag` (the pack or the safe bag), from the depot, her body or the other bag.
static func _carry(game: GameManager, item: Item, bag: ItemContainer) -> void:
	match _where(game, item):
		"stash": game.bring_item(item)
		"worn": game.unequip_to_pack(item)
	var other := game.safe_bag if bag == game.inventory else game.inventory
	if other.items.has(item): game.transfer_item(item, other, bag)
	game.save_base()

static func _store(game: GameManager, item: Item) -> void:
	if _where(game, item) == "worn": game.unequip_to_pack(item)
	game.store_item(item)

## The depot's tabs: everything, each of the eight slots, the flasks.
const DEPOT_TABS := ["全部", "武器", "头", "胸", "手", "腿", "脚", "项链", "戒指", "药剂"]
const DEPOT_ROWS := 16
static var depot_tab := 0

static func _depot_shows(item: Item, tab: int) -> bool:
	if tab == 0: return item.is_equippable() or item.is_potion()
	if tab == DEPOT_TABS.size() - 1: return item.is_potion()
	return item.is_equippable() and Item.slot_of(item.category) == Item.SLOTS[tab - 1]

static func _act(text: String, kind: String, on: Callable) -> Button:
	var b := AK.button(text, kind, 14)
	b.custom_minimum_size = Vector2(128, 40)
	b.pressed.connect(on)
	return b

static func _pack_column(menu: FieldMenu, stage: Control, r: Rect2, pick: Item, pick_item: Callable, redraw: Callable = Callable()) -> void:
	var game := menu.game
	_panel(stage, r, AK.HOLO)
	AK.put(stage, AK.section("背包", "PACK %d×%d" % [game.inventory.width, game.inventory.height]), r.position + Vector2(16, 14))
	var pack := AK.BagGrid.make(game.inventory, Callable(), pick_item, pick)
	var safe_y := r.position.y + 42 + game.inventory.height * 40 + 14
	var safe := AK.BagGrid.make(game.safe_bag, Callable(), pick_item, pick)
	if redraw.is_valid():
		for pair in [[pack, game.inventory], [safe, game.safe_bag]]:
			var bag: ItemContainer = pair[1]
			ItemDrag.bag(pair[0], func(item: Item) -> bool: return not bag.items.has(item) and _where(game, item) != "",
				func(item: Item): _carry(game, item, bag); menu.pick = null; redraw.call())
	AK.put(stage, pack, r.position + Vector2(8, 42))
	AK.put(stage, AK.section("安全袋"), Vector2(r.position.x + 16, safe_y))
	AK.put(stage, safe, Vector2(r.position.x + 8, safe_y + 28))
	if redraw.is_valid():
		var all := AK.button("材料全部存回仓库", "plain", 13)
		all.disabled = not game.carried_items().any(func(it): return not it.is_equippable() and not it.is_potion())
		all.pressed.connect(func(): game.store_all_materials(); redraw.call())
		AK.put(stage, all, Vector2(r.position.x + 16, r.end.y - 56), Vector2(r.size.x - 32, 40))

# --- 整备台 · 制式 -------------------------------------------------------------------

## 制式保底修订 (用户 2026-10-23): the doll on the left, each slot's Rhodes
## choices in the middle (a click wears it), the picked piece and 补齐空槽 /
## 交还制式 on the right.
static func _issue(menu: FieldMenu, stage: Control) -> void:
	var game := menu.game
	var redraw := func(): workbench(menu)
	var pick: Item = menu.pick if menu.pick is Item and game.player.equipped.values().has(menu.pick) else null
	_panel(stage, Rect2(16, TOP, 360, BOTTOM - TOP), LOG)
	AK.put(stage, AK.label(Operators.display_name(game.player.operator_id), 22, AK.FG), Vector2(32, TOP + 12))
	doll(game, stage, Vector2(24, TOP + 66), 0.88, pick, func(item: Item): menu.pick = item; redraw.call())
	AK.put(stage, AK.section("干员", "OPERATOR"), Vector2(32, TOP + 446))
	operator_chips(menu, stage, Vector2(30, TOP + 472), Vector2(34, 40), redraw)
	_panel(stage, Rect2(392, TOP, 440, BOTTOM - TOP), LOG)
	AK.put(stage, AK.section("罗德岛制式", "RHODES STANDARD"), Vector2(412, TOP + 14))
	var y := TOP + 46
	for slot in Item.SLOTS:
		var worn: Item = game.player.equipped.get(slot)
		AK.put(stage, AK.label(Item.slot_name(slot), 13, AK.MUTE), Vector2(412, y + 22))
		var x := 470.0
		for id in GearCatalog.rhodes_choices(slot, game.player.operator_id):
			var piece := GearCatalog.make_rhodes(str(id), game.base.rhodes_rarity, game.player.operator_id)
			var on := GearCatalog.bound(worn) and worn.base_id == str(id)
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.tooltip_text = piece.item_name
			b.set_meta("rhodes", str(id))
			for s in ["normal", "hover", "pressed"]:
				b.add_theme_stylebox_override(s, AK.box(AK.PLATE_3 if s == "hover" or on else AK.PLATE_2, AK.HOLO if on else Color.TRANSPARENT, 1 if on else 0))
			AK.put(stage, b, Vector2(x, y), Vector2(116, 62))
			AK.put(b, AK.item_icon(piece, Vector2(40, 40)), Vector2(4, 11))
			var name := AK.label(piece.item_name, 11, piece.rarity_color())
			name.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
			AK.put(b, name, Vector2(48, 8), Vector2(64, 46))
			for child in b.get_children(): child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var chosen: String = id
			b.pressed.connect(func():
				if game.issue_rhodes(chosen): menu.pick = game.player.equipped.get(slot)
				redraw.call())
			x += 120.0
		y += 66.0
	_panel(stage, Rect2(848, TOP, 416, BOTTOM - TOP), LOG)
	if pick != null:
		var card := RichTextLabel.new()
		card.bbcode_enabled = true
		card.add_theme_font_override("normal_font", AK.cn())
		card.add_theme_font_size_override("normal_font_size", 13)
		card.text = ItemTooltip.text(game, pick, false, false)
		AK.put(stage, card, Vector2(864, TOP + 16), Vector2(384, BOTTOM - TOP - 136))
	var fill := AK.button("补齐空槽", "blue", 14)
	fill.disabled = Item.SLOTS.all(func(s): return game.player.equipped.get(s) != null)
	fill.pressed.connect(func(): game.fill_rhodes(); redraw.call())
	AK.put(stage, fill, Vector2(864, BOTTOM - 104), Vector2(384, 40))
	var back := AK.button("交还制式", "plain", 14)
	back.disabled = not game.player.equipped.values().any(func(it): return GearCatalog.bound(it))
	back.pressed.connect(func():
		for it in game.player.equipped.values().duplicate(): game.return_rhodes(it)
		game.save_base()
		menu.pick = null
		redraw.call())
	AK.put(stage, back, Vector2(864, BOTTOM - 56), Vector2(384, 40))

# --- 整备台 · 改造 -------------------------------------------------------------------

static func _refit(menu: FieldMenu, stage: Control) -> void:
	var game := menu.game
	var redraw := func(): workbench(menu)
	var pick: Item = menu.pick if menu.pick is Item else null
	if pick != null and not PrefixCatalog.eligible_item(pick): pick = null
	# Left: every piece that can be refitted — worn, carried, on the shelves.
	_panel(stage, Rect2(16, TOP, 360, BOTTOM - TOP), LOG)
	AK.put(stage, AK.section("装备", "GEAR"), Vector2(32, TOP + 14))
	var pieces: Array = []
	for category in Item.SLOTS:
		var worn: Item = PaperDoll.worn(game, category)
		if worn != null and PrefixCatalog.eligible_item(worn): pieces.append(worn)
	for it in game.carried_items() + game.stash:
		if it.is_equippable() and PrefixCatalog.eligible_item(it) and not pieces.has(it): pieces.append(it)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	AK.put(stage, scroll, Vector2(28, TOP + 42), Vector2(336, BOTTOM - TOP - 54))
	scroll.add_child(list)
	for it in pieces:
		var row := Button.new()
		row.focus_mode = Control.FOCUS_NONE
		row.custom_minimum_size = Vector2(326, 48)
		row.set_meta("item", it)
		for s in ["normal", "hover", "pressed"]:
			row.add_theme_stylebox_override(s, AK.box(AK.PLATE_3 if s == "hover" or it == pick else AK.PLATE_2, AK.HOLO if it == pick else Color.TRANSPARENT, 1 if it == pick else 0))
		AK.put(row, AK.item_icon(it, Vector2(44, 44)), Vector2(2, 2))
		var name := AK.item_name(it, 13)
		AK.put(row, name, Vector2(54, 6))
		var where := "身上" if game.player.equipped.values().has(it) else ("仓库" if game.stash.has(it) else "背包")
		AK.put(row, AK.label(where, 11, AK.MUTE), Vector2(54, 28))
		for child in row.get_children(): child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var chosen: Item = it
		row.pressed.connect(func(): menu.pick = chosen; BaseScreens._tuning = null; redraw.call())
		list.add_child(row)
	# Middle: the fixture — the piece large, its lines, the prefix locks.
	_panel(stage, Rect2(392, TOP, 440, BOTTOM - TOP), LOG)
	if pick == null:
		AK.put(stage, AK.label("—", 18, AK.DIM), Vector2(600, TOP + 200))
	else:
		var fixture := AK.rect(Color(0, 0, 0, 0.5), Vector2(512, TOP + 24), Vector2(200, 200))
		stage.add_child(fixture)
		var edge := Panel.new()
		edge.add_theme_stylebox_override("panel", AK.box(Color.TRANSPARENT, LOG, 2))
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		AK.put(stage, edge, Vector2(512, TOP + 24), Vector2(200, 200))
		stage.add_child(AK.rect(AK.LINE_2, Vector2(494, TOP + 104), Vector2(14, 40)))
		stage.add_child(AK.rect(AK.LINE_2, Vector2(716, TOP + 104), Vector2(14, 40)))
		AK.put(stage, AK.item_icon(pick, Vector2(184, 184)), Vector2(520, TOP + 32))
		var title := AK.item_name(pick, 15)
		AK.put(stage, title, Vector2(412, TOP + 240))
		EventScreens._info(stage, game, pick, "交付价", Economy.format(Economy.direct_price(pick)), Vector2(412, TOP + 270), BOTTOM - TOP - 270 - 120)
		if game.base.researched("prefix_lock") and pick.prefixes.size() == 2:
			var locks := HBoxContainer.new()
			locks.add_theme_constant_override("separation", 6)
			for i in range(pick.prefixes.size()):
				var index := i
				var on := game.reforge_keep == i
				var lock := AK.button("%s 锁定 %s" % ["■" if on else "□", str(PrefixCatalog.get_entry(str(pick.prefixes[i].id)).name)], "blue" if on else "plain", 12)
				lock.custom_minimum_size = Vector2(197, 34)
				lock.pressed.connect(func(): game.reforge_keep = -1 if game.reforge_keep == index else index; redraw.call())
				locks.add_child(lock)
			AK.put(stage, locks, Vector2(412, BOTTOM - 52))
	# Right: the three operations, or the choice they opened.
	_panel(stage, Rect2(848, TOP, 416, BOTTOM - TOP), LOG)
	if pick == null: return
	if not game.reforge_choice.is_empty() and game.reforge_choice.item == pick:
		AK.put(stage, AK.section("重铸结果", "PICK ONE"), Vector2(864, TOP + 14))
		var choices := VBoxContainer.new()
		choices.add_theme_constant_override("separation", 6)
		for i in range((game.reforge_choice.options as Array).size()):
			var index := i
			var names: Array = (game.reforge_choice.options[i] as Array).map(func(e): return str(PrefixCatalog.get_entry(str(e.id)).name))
			var b := AK.button(" · ".join(names) if not names.is_empty() else "—", "blue", 14)
			b.custom_minimum_size = Vector2(384, 44)
			b.pressed.connect(func(): game.choose_reforge(index); redraw.call())
			choices.add_child(b)
		AK.put(stage, choices, Vector2(864, TOP + 44))
		return
	if BaseScreens._tuning == pick:
		AK.put(stage, AK.section("精调", "%s · 改量装置×1" % Economy.format(game.refresh_cost("tune", pick))), Vector2(864, TOP + 14))
		var lines := VBoxContainer.new()
		lines.add_theme_constant_override("separation", 4)
		for line in PrefixCatalog.rollable_lines(pick):
			var chosen: Array = line
			var b := AK.button(PrefixCatalog.line_label(pick, line), "plain", 13)
			b.custom_minimum_size = Vector2(384, 36)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.disabled = not game.refresh_refusal("tune", pick).is_empty()
			b.pressed.connect(func(): game.refresh_gear("tune", pick, chosen); redraw.call())
			lines.add_child(b)
		var back := AK.button("返回", "plain", 13)
		back.custom_minimum_size = Vector2(384, 40)
		back.pressed.connect(func(): BaseScreens._tuning = null; redraw.call())
		lines.add_child(back)
		AK.put(stage, lines, Vector2(864, TOP + 44))
		return
	var y := TOP + 16
	# 定向重铸 shows only where it can be done (龙门, 龙门商会 at the top rank).
	var directed := game.base.ship_at == GameManager.DIRECTED_ANCHOR and game.voyage.sailing.is_empty() \
		and game.exchange.rank(GameManager.DIRECTED_FACTION) >= Exchange.RANK_AT.size() - 1
	var card_h := 126.0 if directed else 150.0
	for entry in [["reforge", "重铸", "REFORGE"], ["calibrate", "校准", "CALIBRATE"], ["tune", "精调", "TUNE"]]:
		var kind: String = entry[0]
		var cost := game.refresh_cost(kind, pick)
		var mats: Dictionary = GameManager.REFRESH_MATERIALS[kind]
		stage.add_child(AK.rect(AK.PLATE_2, Vector2(864, y), Vector2(384, card_h)))
		AK.put(stage, AK.label(entry[1], 20, AK.FG), Vector2(880, y + 10))
		AK.put(stage, AK.label(entry[2], 10, AK.MUTE, AK.en()), Vector2(880, y + 40))
		AK.put(stage, AK.money("lmd", Economy.format(cost), 16), Vector2(880, y + 66))
		var parts := mats.keys().map(func(id): return "%s %d / %d" % [id, game.material_count(id), mats[id]])
		AK.put(stage, AK.label("  ".join(parts), 12, AK.MUTE), Vector2(880, y + 92))
		var refusal := game.refresh_refusal(kind, pick)
		var go := AK.button(entry[1] if refusal.is_empty() else refusal, "blue", 14)
		go.disabled = not refusal.is_empty()
		go.set_meta("label", entry[1])
		if kind == "tune": go.pressed.connect(func(): BaseScreens._tuning = pick; redraw.call())
		else: go.pressed.connect(func(): game.refresh_gear(kind, pick); redraw.call())
		AK.put(stage, go, Vector2(1108, y + card_h - 52), Vector2(128, 40))
		y += card_h + 10
	if directed:
		var h := BOTTOM - 8 - y
		stage.add_child(AK.rect(AK.PLATE_2, Vector2(864, y), Vector2(384, h)))
		AK.put(stage, AK.label("定向重铸", 20, AK.FG), Vector2(880, y + 10))
		AK.put(stage, AK.label("%d%%" % roundi(GameManager.directed_chance(game.base.directed_fails) * 100.0), 16, AK.HOLO), Vector2(1180, y + 12))
		AK.put(stage, AK.money("lmd", Economy.format(game.directed_cost(pick)), 16), Vector2(880, y + 40))
		AK.put(stage, AK.label("%s %d / 1" % [GameManager.DIRECTED_MATERIAL, game.material_count(GameManager.DIRECTED_MATERIAL)], 12, AK.MUTE), Vector2(1040, y + 44))
		var fams := HFlowContainer.new()
		fams.add_theme_constant_override("h_separation", 4)
		fams.add_theme_constant_override("v_separation", 4)
		for fam in PrefixFamilies.ORDER:
			if not game.player.families.worn.has(fam): continue
			var family: String = fam
			var refusal := game.directed_refusal(pick, family)
			var b := AK.button(str(PrefixFamilies.FAMILIES[fam].name), "blue" if refusal.is_empty() else "plain", 13)
			b.custom_minimum_size = Vector2(72, 32)
			b.disabled = not refusal.is_empty()
			b.tooltip_text = refusal
			b.pressed.connect(func(): game.directed_reforge(pick, family); redraw.call())
			fams.add_child(b)
		AK.put(stage, fams, Vector2(880, y + 70), Vector2(352, h - 78))

# --- 后勤柜台 · 投保 ------------------------------------------------------------------

static func logistics(menu: FieldMenu) -> void:
	var game := menu.game
	var stage := BaseScreens.shell(menu, "后勤柜台", "LOGISTICS", [], 0, Callable(), "INSURANCE")
	var redraw := func(): logistics(menu)
	_panel(stage, Rect2(16, TOP, 820, BOTTOM - TOP), LOG)
	AK.put(stage, AK.section("投保", "INSURANCE"), Vector2(32, TOP + 14))
	var pieces: Array = []
	for category in Item.SLOTS:
		var worn: Item = PaperDoll.worn(game, category)
		if worn != null: pieces.append(worn)
	for it in game.carried_items():
		if it.is_equippable() and not pieces.has(it): pieces.append(it)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	AK.put(stage, scroll, Vector2(32, TOP + 44), Vector2(788, BOTTOM - TOP - 60))
	scroll.add_child(list)
	var insured := 0
	var due := 0
	for it in pieces:
		var row := Control.new()
		row.custom_minimum_size = Vector2(776, 64)
		row.add_child(AK.rect(AK.PLATE_2, Vector2.ZERO, Vector2(776, 64)))
		AK.put(row, AK.item_icon(it, Vector2(60, 60)), Vector2(2, 2))
		AK.put(row, AK.item_name(it, 14), Vector2(74, 10))
		var where := "身上" if game.player.equipped.values().has(it) else ("安全袋" if game.safe_bag.items.has(it) else "背包")
		AK.put(row, AK.label("%s · %s" % [Item.slot_name(it.category), where], 12, AK.MUTE), Vector2(74, 36))
		if it.insured:
			insured += 1
			AK.put(row, AK.tag("已投保", Color("4fd1c5")), Vector2(670, 22))
		else:
			var price := game.insurance_price(it)
			due += price
			var b := AK.button("投保 %s" % Economy.format(price), "plain", 12)
			b.disabled = game.gold < price
			var chosen: Item = it
			b.pressed.connect(func(): game.insure(chosen); redraw.call())
			AK.put(row, b, Vector2(620, 14), Vector2(144, 36))
		list.add_child(row)
	if pieces.is_empty(): list.add_child(AK.label("—", 14, AK.DIM))
	_panel(stage, Rect2(852, TOP, 412, BOTTOM - TOP), LOG)
	AK.put(stage, AK.section("合计", "SUMMARY"), Vector2(868, TOP + 14))
	var rows := [["已投保", str(insured)], ["未投保", str(pieces.size() - insured)], ["全部投保需", Economy.format(due)]]
	for i in range(rows.size()):
		AK.put(stage, AK.label(rows[i][0], 13, AK.MUTE), Vector2(868, TOP + 48 + i * 30))
		AK.put(stage, AK.label(rows[i][1], 16, AK.FG, AK.en()), Vector2(1180, TOP + 46 + i * 30))
	var all := AK.go_button("全部投保", "INSURE ALL", "blue", 18)
	all.disabled = due <= 0 or game.gold < due
	all.pressed.connect(func():
		for it in pieces:
			if not it.insured: game.insure(it)
		redraw.call())
	AK.put(stage, all, Vector2(868, BOTTOM - 72), Vector2(380, 56))

# --- 出发准备 ----------------------------------------------------------------------

static func deploy(menu: FieldMenu, region: String) -> void:
	var game := menu.game
	var base: BaseState = game.base
	var stage := BaseScreens.shell(menu, "出发准备", "SQUAD", [], 0, Callable(), AK.REGION_CODE.get(region, ""))
	var redraw := func(): deploy(menu, region)
	# Left: who goes, and what she carries (read-only; change it at the workbench).
	_panel(stage, Rect2(16, TOP, 760, BOTTOM - TOP), AK.HOLO)
	AK.put(stage, AK.section("干员", "OPERATOR"), Vector2(32, TOP + 14))
	operator_chips(menu, stage, Vector2(32, TOP + 40), Vector2(66, 76), redraw)
	stage.add_child(AK.rect(AK.LINE, Vector2(28, TOP + 128), Vector2(736, 1)))
	AK.put(stage, AK.section("装备", "LOADOUT"), Vector2(32, TOP + 140))
	doll(game, stage, Vector2(20, TOP + 166), 0.82, null, Callable())
	AK.put(stage, AK.section("背包", "PACK %d×%d" % [game.inventory.width, game.inventory.height]), Vector2(366, TOP + 140))
	AK.put(stage, AK.BagGrid.make(game.inventory), Vector2(366, TOP + 168))
	# Right: the target and 开始行动.
	_panel(stage, Rect2(792, TOP, 472, BOTTOM - TOP), AK.HOLO)
	var x := 812.0
	var data: Dictionary = FieldCatalog.REGIONS[region]
	var parts: PackedStringArray = str(data.name).split(" · ")
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(AK.tag(AK.REGION_CODE.get(region, "LG"), AK.PAPER))
	head.add_child(AK.label("DEPLOY TO", 10, AK.MUTE, AK.en()))
	AK.put(stage, head, Vector2(x, TOP + 14))
	AK.put(stage, AK.label(parts[0], 30, AK.FG), Vector2(x, TOP + 36))
	AK.put(stage, AK.label(parts[1] if parts.size() > 1 else "", 15, AK.FG), Vector2(x, TOP + 78))
	var start: int = game._pending_start_camp
	var cells := [["起点", game.camp_label(start) if start > 0 else AK.floor_code(region, 1), AK.GREEN if start > 0 else AK.FG],
		["深度", AK.floor_code(region, start + 1), AK.FG]]
	for i in range(cells.size()):
		stage.add_child(AK.rect(AK.PLATE_2, Vector2(x + i * 114, TOP + 110), Vector2(108, 56)))
		AK.put(stage, AK.label(cells[i][0], 11, AK.MUTE), Vector2(x + i * 114 + 8, TOP + 116))
		AK.put(stage, AK.label(cells[i][1], 15, cells[i][2], AK.en() if i > 0 or start == 0 else AK.cn()), Vector2(x + i * 114 + 8, TOP + 136))
	# Who goes, in one line (no class, no stars).
	var p: OperatorProgress = game.progress()
	var who := HBoxContainer.new()
	who.add_theme_constant_override("separation", 10)
	who.add_child(AK.label(Operators.display_name(game.player.operator_id), 18, AK.FG))
	who.add_child(AK.label("%s · Lv %d" % [Progression.ELITE_NAMES[p.elite], p.level], 12, AK.MUTE, AK.en()))
	var orders := base.orders.pointing_at(region)
	if orders > 0: who.add_child(AK.tag("订单 %d" % orders, AK.SP))
	if base.injured: who.add_child(AK.tag("重伤", AK.RED))
	AK.put(stage, who, Vector2(x, TOP + 182))
	var y := TOP + 220
	for warning in game.departure_warnings():
		AK.put(stage, BaseScreens._wrap(warning, 12, AK.SP, 430), Vector2(x, y))
		y += 40
	# 随队物资 (地图特色策划案 §8): ticked ones go along, one each.
	for id in FeatureCatalog.kits_for(region):
		var stock := base.kit_stock(id)
		if stock <= 0: continue
		var on := game.kit_on(id, region)
		var toggle := AK.button("%s %s ×%d" % ["■" if on else "□", FeatureCatalog.kit_name(id, base.kit_best_tier(id)), stock], "blue" if on else "plain", 13)
		toggle.set_meta("kit", id)
		var kit_id: String = id
		toggle.pressed.connect(func(): game.toggle_kit(kit_id, region); redraw.call())
		AK.put(stage, toggle, Vector2(x, y), Vector2(432, 34))
		y += 40
	AK.put(stage, AK.label("药剂 %d" % game.potion_count(), 12, AK.MUTE), Vector2(x, BOTTOM - 126))
	# 食堂补给 eaten for this contract (势力特供策划案 §5.3).
	if not game.provisions.meal().is_empty():
		var meal := HBoxContainer.new()
		meal.add_theme_constant_override("separation", 6)
		var icon := AK.item_icon(MaterialCatalog.create(game.provisions.meal(), 1), Vector2(20, 20))
		icon.custom_minimum_size = Vector2(20, 20)
		meal.add_child(icon)
		meal.add_child(AK.label(game.provisions.meal(), 12, AK.GREEN))
		AK.put(stage, meal, Vector2(x + 120, BOTTOM - 130))
	var go := AK.go_button("开始行动", "OPERATION START")
	AK.put(stage, go, Vector2(x, BOTTOM - 102), Vector2(432, 88))
	go.pressed.connect(func(): game.start_contract(region, game._pending_start_camp))
