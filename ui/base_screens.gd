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
	"pharmacy": ["医疗部", "MEDICAL"], "store": ["可露希尔的商店", "CLOSURE'S STORE"],
	"personnel": ["人事部", "PERSONNEL"],
}
static var _detail: RichTextLabel
## The piece last under the pointer in the warehouse or the workshop (one-key packing's pick).
static var hovered: Item = null
## A screen's own accent for the shell (a trader's colour); clear = the station's department.
static var accent_override := Color(0, 0, 0, 0)

## The sub-page shell. `currencies` are [kind, value] pairs: "lmd", "gold", "ori".
static func shell(menu: FieldMenu, cn_title: String, en_title: String, tabs: Array = [], tab: int = 0, on_tab: Callable = Callable(), watermark: String = "", currencies: Array = []) -> Control:
	var stage := menu.stage_begin(1.0)
	var accent := accent_override if accent_override.a > 0.0 else Terminal.dept_color(menu._station)
	stage.add_child(AK.rect(AK.BG, Vector2.ZERO, Vector2(1280, 720)))
	if not watermark.is_empty():
		var mark := AK.label(watermark, 120, Color(1, 1, 1, 0.04), AK.en())
		AK.put(stage, mark, Vector2(1290 - AK.en().get_string_size(watermark, HORIZONTAL_ALIGNMENT_LEFT, -1, 120).x, 540))
	stage.add_child(AK.rect(Color(0.035, 0.047, 0.055, 0.96), Vector2.ZERO, Vector2(1280, 60)))
	# The header's light strip in the department colour, brightest in the middle.
	stage.add_child(AK.rect(Color(accent, 0.28), Vector2(0, 60), Vector2(1280, 2)))
	stage.add_child(AK.rect(Color(accent, 0.85), Vector2(160, 60), Vector2(960, 2)))
	var back := AK.button("‹", "plain", 22)
	AK.put(stage, back, Vector2(14, 8), Vector2(44, 44))
	back.pressed.connect(menu.game.go_back)
	var home := AK.button("⌂", "plain", 18)
	AK.put(stage, home, Vector2(60, 8), Vector2(44, 44))
	home.pressed.connect(menu.game.close_modal)
	stage.add_child(AK.rect(accent, Vector2(114, 8), Vector2(5, 44)))
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -2)
	titles.add_child(AK.label(en_title, 10, AK.MUTE, AK.en()))
	var title_label := AK.label(cn_title, 22, AK.FG)
	titles.add_child(title_label)
	if menu.reveal_pending: Terminal.type_in(title_label)
	AK.put(stage, titles, Vector2(128, 8))
	if not tabs.is_empty():
		AK.put(stage, AK.toggle(tabs, tab, on_tab, 13), Vector2(148 + maxf(110.0, AK.cn().get_string_size(I18n.t(cn_title), HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 8.0), 12))
	var pills := HBoxContainer.new()
	pills.alignment = BoxContainer.ALIGNMENT_END
	pills.add_theme_constant_override("separation", 6)
	for entry in (currencies if not currencies.is_empty() else [["lmd", Economy.format(menu.game.gold)]]):
		pills.add_child(pill(entry[0], entry[1]))
	AK.put(stage, pills, Vector2(700, 14), Vector2(564, 32))
	# Footer: the Rhodes mark and the department, as on the ship's terminals.
	stage.add_child(AK.rect(Color(0.035, 0.047, 0.055, 0.85), Vector2(0, 694), Vector2(1280, 26)))
	var logo := TextureRect.new()
	logo.texture = load("res://art/kit/textures/base_rhodes_logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	logo.modulate = Color(1, 1, 1, 0.7)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	AK.put(stage, logo, Vector2(14, 699), Vector2(16, 16))
	AK.put(stage, AK.label("RHODES ISLAND · %s" % en_title, 9, AK.DIM, AK.en()), Vector2(38, 700))
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
		"ori":
			row.add_child(AK.tag("污染", AK.ORI))
			row.add_child(AK.label(value, 15, AK.ORI, AK.en()))
	p.add_child(row)
	return p

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
	if not menu.region_pick in regions or not game.region_open(menu.region_pick): menu.region_pick = regions[0]
	var region: String = menu.region_pick
	var data: Dictionary = FieldCatalog.REGIONS[region]
	var parts: PackedStringArray = str(data.name).split(" · ")
	var code: String = AK.REGION_CODE.get(region, "LG")
	var en_names := {"mine": "CHERNOBOG", "city": "LUNGMEN", "snow": "SAMI", "siracusa": "SIRACUSA"}
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
		# Before the first voyage only 切尔诺伯格 (主线引导): the others greyed out.
		if not game.region_open(id):
			b.disabled = true
			b.modulate = Color(1, 1, 1, 0.35)
		b.pressed.connect(func(): menu.region_pick = id; menu.pick = 0; menu.contract_pick = 0; contracts(menu))
	# The middle picks the floors (用户 2026-10-21: 中间改为层数选择): every block
	# she can start from, CH-01 or a camp she has reached, then the block's
	# floors snaking, the random-extraction band tinted, the camp at its end.
	var starts: Array = [0] + game.base.unlocked_camps(region)
	var start: int = int(menu.pick) if menu.pick is int and int(menu.pick) in starts else 0
	_section(stage, "层数", "FLOORS", Vector2(248, TOP + 8))
	for i in range(starts.size()):
		var depth: int = starts[i]
		var on := depth == start
		var tile := Button.new()
		tile.focus_mode = Control.FOCUS_NONE
		tile.set_meta("label", "%s-01" % code if depth == 0 else game.camp_label(depth))
		for s in ["normal", "hover", "pressed"]:
			tile.add_theme_stylebox_override(s, AK.box(AK.PAPER if on else (AK.PLATE_3 if s == "hover" else AK.PLATE_2), AK.GREEN if depth > 0 and not on else Color.TRANSPARENT, 1 if depth > 0 and not on else 0))
		AK.put(stage, tile, Vector2(248 + (i % 4) * 152, TOP + 40 + (i / 4) * 78), Vector2(144, 70))
		var ink := AK.INK if on else AK.FG
		AK.put(tile, AK.label(str(tile.get_meta("label")), 18, ink, AK.en()), Vector2(12, 8))
		AK.put(tile, AK.label("%s-%02d – %s-%02d" % [code, depth + 1, code, depth + FieldCatalog.CAMP_INTERVAL], 11, Color(ink, 0.7), AK.en()), Vector2(12, 42))
		for child in tile.get_children(): child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var chosen := depth
		tile.pressed.connect(func(): menu.pick = chosen; contracts(menu))
	var chain_top: float = TOP + 40 + ceili(starts.size() / 4.0) * 78 + 24
	var chain := ChainLines.new()
	AK.put(stage, chain, Vector2(232, chain_top), Vector2(640, 260))
	for n in range(1, FieldCatalog.CAMP_INTERVAL + 1):
		var i := n - 1
		var row := 0 if i < 5 else 1
		var col := i if row == 0 else 9 - i
		var at := Vector2(232 + 20 + col * 104, chain_top + row * 80)
		var node := AK.label("%s-%02d" % [code, start + n], 14, AK.FG, AK.en())
		node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var style := AK.box(Color("3b3b2a") if FieldCatalog.RANDOM_EXTRACTION_ODDS.has(n) else AK.PLATE_3)
		node.add_theme_stylebox_override("normal", style)
		AK.put(stage, node, at, Vector2(84, 34))
		chain.points.append(at - Vector2(232, chain_top) + Vector2(42, 17))
	var camp := HBoxContainer.new()
	camp.alignment = BoxContainer.ALIGNMENT_CENTER
	camp.add_theme_constant_override("separation", 6)
	camp.add_child(AK.label(game.camp_label(start + FieldCatalog.CAMP_INTERVAL), 14, AK.INK, AK.en()))
	camp.add_child(AK.label("撤离 · 可露希尔", 11, AK.INK))
	var camp_plate := PanelContainer.new()
	camp_plate.add_theme_stylebox_override("panel", AK.box(AK.GREEN))
	camp_plate.add_child(camp)
	AK.put(stage, camp_plate, Vector2(252, chain_top + 160), Vector2(188, 40))
	chain.points.append(Vector2(20 + 94, 160 + 20))
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
	# Only the region's own drop (用户 2026-10-21: 只保留专属掉落提示).
	var special := HBoxContainer.new()
	special.add_theme_constant_override("separation", 8)
	special.add_child(AK.tag("专属", AK.SP))
	var exclusive := FieldCatalog.exclusive(region)
	special.add_child(AK.item_icon(exclusive, Vector2(46, 46)))
	special.add_child(AK.label(exclusive.item_name, 12, exclusive.rarity_color()))
	AK.put(stage, special, Vector2(x + 18, TOP + 182))
	# The objective: three cards, one picked (§6 B1).
	_section(stage, "合同目标", "OBJECTIVE", Vector2(x + 18, TOP + 256))
	var offers: Array = game.contract_offers(region)
	var chosen := clampi(menu.contract_pick, 0, offers.size() - 1)
	# 寻访合同 come after the three: then the rows go to one line each.
	var compact := offers.size() > FieldCatalog.CONTRACT_OFFERS
	var row := 34 if compact else 50
	for i in range(offers.size()):
		var offer: Dictionary = offers[i]
		var card := Button.new()
		card.focus_mode = Control.FOCUS_NONE
		card.set_meta("label", "合同 %d" % (i + 1))
		var on := i == chosen
		for s in ["normal", "hover", "pressed"]:
			card.add_theme_stylebox_override(s, AK.box(AK.PAPER if on else (AK.PLATE_3 if s == "hover" else AK.PLATE_2)))
		AK.put(stage, card, Vector2(x + 18, TOP + 284 + i * row), Vector2(360, row - 4))
		var ink := AK.INK if on else AK.FG
		var kind: String = FieldCatalog.CONTRACT_NAMES[offer.type]
		AK.put(card, AK.tag(kind, AK.SP), Vector2(10, 4 if compact else 10))
		# The text starts after the tag, however long its shown name is.
		var text_x := maxf(64.0, 10.0 + AK.cn().get_string_size(I18n.t(kind), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 12.0 + 8.0)
		AK.put(card, AK.label(FieldCatalog.contract_goal(offer, region, start + 1), 13, ink), Vector2(text_x, 4 if compact else 2))
		var bonus := AK.label(game.contract_pay_text(offer, start + 1), 11, Color(ink, 0.7))
		if compact:
			bonus.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			AK.put(card, bonus, Vector2(150, 7), Vector2(200, 16))
		else:
			AK.put(card, bonus, Vector2(text_x, 21))
		for child in card.get_children(): child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var index := i
		card.pressed.connect(func(): menu.contract_pick = index; contracts(menu))
	# 外勤部Ⅱ: one free reroll of the chosen ordinary card per return.
	if game.base.contract_reroll and chosen < (game.base.contract_offers.get(region, []) as Array).size():
		var reroll := AK.button("重抽", "ghost", 11)
		AK.put(stage, reroll, Vector2(x + 318, TOP + 252), Vector2(60, 24))
		reroll.pressed.connect(func(): game.reroll_contract(region, chosen); contracts(menu))
	# 最终准备: who goes and what she carries, then 开始行动 there.
	var go := AK.go_button("最终准备", "FINAL PREP")
	if compact: AK.put(stage, go, Vector2(x + 18, BOTTOM - 56), Vector2(360, 50))
	else: AK.put(stage, go, Vector2(x + 18, BOTTOM - 84), Vector2(360, 72))
	go.pressed.connect(func():
		game._pending_contract = (offers[chosen] as Dictionary).duplicate()
		game._pending_start_camp = start
		menu.show_departure(region)
		menu.back_to = func(): game.open_station("contracts"))

# --- 人事部 (干员寻访策划案 §2.3) ----------------------------------------------------

## The roster: every operator, her portrait, her region, her traces and where
## she stands. Data only (用户: 界面不写说明文字).
static func personnel(menu: FieldMenu) -> void:
	var game := menu.game
	var stage := shell(menu, "人事部", "PERSONNEL", [], 0, Callable(), "ROSTER")
	_section(stage, "干员名册", "ROSTER", Vector2(16, TOP + 8))
	var ids: Array = Operators.ORDER
	for i in range(ids.size()):
		var id: String = ids[i]
		var joined := game.base.recruited(id)
		var at := Vector2(16 + (i % 3) * 416, TOP + 40 + (i / 3) * 196)
		stage.add_child(AK.rect(AK.PLATE_2, at, Vector2(404, 184)))
		# Standing to attention: her idle's first south frame, at a whole 5× so
		# the pixels stay square (用户 2026-10-17: 改为立正状态).
		var stand := AtlasTexture.new()
		stand.atlas = LapplandAnimator3D.sheet(id, "idle")
		stand.region = Rect2(0, 0, LapplandAnimator3D.CELL_TEXELS, LapplandAnimator3D.CELL_TEXELS)
		var picture := TextureRect.new()
		picture.texture = stand
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# Not yet found: her silhouette only.
		if not joined and game.base.clues(id) == 0: picture.modulate = Color(0, 0, 0, 0.85)
		AK.put(stage, picture, at + Vector2(12, 12), Vector2(160, 160))
		var data := Operators.info(id)
		var known := joined or game.base.clues(id) > 0
		AK.put(stage, AK.label(Operators.display_name(id) if known else "？？？", 18, AK.FG), at + Vector2(188, 12))
		AK.put(stage, AK.label("%s · %s" % [data.get("class", ""), data.get("branch", "")], 11, AK.MUTE, AK.en()), at + Vector2(188, 40))
		var region := RecruitCatalog.region_of(id)
		if not region.is_empty():
			AK.put(stage, AK.label(str(FieldCatalog.REGIONS[region].name).split(" · ")[0], 13, AK.FG), at + Vector2(188, 64))
		var status := "已入职"
		var colour := AK.GREEN
		if not joined:
			var have := game.base.clues(id)
			status = "未发现" if have == 0 else ("可寻访" if game.base.recruit_ready(id) else "追踪中")
			colour = AK.MUTE if have == 0 else (AK.SP if game.base.recruit_ready(id) else AK.BLUE)
			AK.put(stage, AK.label("踪迹 %d/%d" % [have, RecruitCatalog.CLUES_NEEDED], 13, AK.FG), at + Vector2(188, 88))
		elif not Operators.has_kit(id):
			status = "整备中"
			colour = AK.BLUE
		AK.put(stage, AK.tag(status, colour), at + Vector2(188, 144))

# --- #14 仓库 -------------------------------------------------------------------------

const STASH_TABS := ["全部", "武器", "防具", "饰品", "材料", "拆包"]
## The 拆包 page (交易所交易包修订案 §4): the pack picked and the pick so far.
const UNPACK_TAB := 5
static var unpack_pick := ""
static var unpack_counts := {}

## At the 仓管台 (zone -1): the 基建 page until the master console is bought,
## then every zone. At a zone's floor frame (zone = its category): that zone's
## shelves and its next rack (用户 2026-10-07).
static func stash(menu: FieldMenu, zone: int = -1) -> void:
	var game := menu.game
	var base: BaseState = game.base
	if zone < 0 and not base.console:
		construction(menu, "仓管台", "warehouse")
		return
	var currencies := [["lmd", Economy.format(game.gold)]]
	var tab: int = clampi(menu.stash_tab, 0, STASH_TABS.size() - 1) if zone < 0 else zone + 1
	var stage: Control
	if zone >= 0:
		stage = shell(menu, "%s区货架" % BaseCatalog.CATEGORY_NAMES[zone], "SHELVES", [], 0, Callable(), "DEPOT", currencies)
	else:
		stage = shell(menu, "仓管台", "DEPOT", STASH_TABS, tab, func(i): menu.stash_tab = i; stash(menu), "DEPOT", currencies)
		if tab == UNPACK_TAB:
			_unpack_page(menu, stage)
			return
	if zone >= 0: _rack_button(menu, stage, zone)
	else:
		var search := LineEdit.new()
		search.placeholder_text = "搜索"
		search.text = menu.stash_query
		search.add_theme_font_override("font", AK.cn())
		search.text_submitted.connect(func(value: String): menu.stash_query = value; stash(menu))
		AK.put(stage, search, Vector2(16, TOP + 4), Vector2(220, 34))
	if zone < 0 or zone == Item.Category.MATERIAL:
		var store_all := AK.button("背包材料全部存回", "plain", 12)
		AK.put(stage, store_all, Vector2(244 if zone < 0 else 420, TOP + 4), Vector2(150, 34))
		store_all.disabled = not game.carried_items().any(func(x): return not x.is_equippable())
		store_all.pressed.connect(func(): game.store_all_materials(); stash(menu, zone))
	# Zone loads (red when full).
	var loads := HBoxContainer.new()
	loads.add_theme_constant_override("separation", 14)
	for category in range(Item.Category.size()):
		if zone >= 0 and category != zone: continue
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
	var shown: Array = game.stash.filter(func(x: Item): return (tab == 0 or x.category == tab - 1) and (zone >= 0 or menu._matches(x)))
	# Drag: shelf → carry-in brings it, carry-in → shelf stores it.
	var stores := func(item: Item) -> bool: return game.carried_items().has(item)
	var brings := func(item: Item) -> bool: return game.stash.has(item)
	var grid := FlowGrid.make(shown, 16, 10, func(item: Item): game.bring_item(item); stash(menu, zone), func(item: Item): _show_detail(game, item))
	grid.dragging(stores, func(item: Item): game.store_item(item); stash(menu, zone))
	AK.put(stage, grid, Vector2(16, TOP + 50))
	# What goes out with her next.
	var carry_y := TOP + 50 + 10 * 40 + 12
	var bring_drop := func(item: Item): game.bring_item(item); stash(menu, zone)
	ItemDrag.zone(stage, Vector2(16, carry_y - 4), Vector2(932, 56), brings, bring_drop)
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
		b.pressed.connect(func(): game.store_item(shown_item); stash(menu, zone))
		b.mouse_entered.connect(func(): _show_detail(game, shown_item))
		ItemDrag.wire(b, shown_item, brings, bring_drop)
		carry.add_child(b)
	AK.put(stage, carry, Vector2(150, carry_y))
	# The detail column.
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", AK.box(Color("0b0d0f"), AK.LINE_2, 1, 12))
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

## 拆包 (§4): the packs held on the left, the pack's list with points and
## − / + in the middle, the points left and 拆包 on the right.
static func _unpack_page(menu: FieldMenu, stage: Control) -> void:
	var game := menu.game
	var held: Array[String] = []
	for pack in Packs.ORDER:
		if Packs.can_open(pack) and game.material_count(pack) > 0: held.append(pack)
	if not unpack_pick in held:
		unpack_pick = held[0] if not held.is_empty() else ""
		unpack_counts.clear()
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	AK.put(stage, left, Vector2(16, TOP + 8), Vector2(240, 0))
	left.add_child(AK.section("持有", "PACKS  %d" % held.size()))
	for pack in held:
		var b := AK.button("%s  ×%d" % [pack, game.material_count(pack)], "blue" if pack == unpack_pick else "plain", 13)
		b.custom_minimum_size = Vector2(240, 34)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var chosen: String = pack
		b.pressed.connect(func(): unpack_pick = chosen; unpack_counts.clear(); stash(menu))
		left.add_child(b)
	if unpack_pick.is_empty(): return
	var points := game.open_points(unpack_pick)
	var spent := Packs.pick_cost(unpack_pick, unpack_counts)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	AK.put(stage, scroll, Vector2(272, TOP + 8), Vector2(640, BOTTOM - TOP - 16))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	list.custom_minimum_size.x = 620
	scroll.add_child(list)
	for id in Packs.open_list(unpack_pick):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var sample := MaterialCatalog.create(id, 1)
		var icon := AK.item_icon(sample, Vector2(32, 32))
		icon.custom_minimum_size = Vector2(32, 32)
		row.add_child(icon)
		var title := AK.label(id, 13, AK.FG)
		title.custom_minimum_size.x = 200
		row.add_child(title)
		var cost := Packs.open_cost(id)
		var pts := AK.label(str(cost), 13, AK.MUTE, AK.en())
		pts.custom_minimum_size.x = 60
		row.add_child(pts)
		var n := int(unpack_counts.get(id, 0))
		var material: String = id
		var minus := AK.button("−", "plain", 13)
		minus.custom_minimum_size = Vector2(30, 28)
		minus.disabled = n <= 0
		minus.pressed.connect(func():
			unpack_counts[material] = maxi(0, int(unpack_counts.get(material, 0)) - 1)
			if int(unpack_counts[material]) == 0: unpack_counts.erase(material)
			stash(menu))
		row.add_child(minus)
		var count := AK.label(str(n), 14, AK.HOLO if n > 0 else AK.MUTE, AK.en())
		count.custom_minimum_size.x = 40
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(count)
		var plus := AK.button("+", "plain", 13)
		plus.custom_minimum_size = Vector2(30, 28)
		plus.disabled = spent + cost > points
		plus.pressed.connect(func(): unpack_counts[material] = int(unpack_counts.get(material, 0)) + 1; stash(menu))
		row.add_child(plus)
		list.add_child(row)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	AK.put(stage, right, Vector2(932, TOP + 8), Vector2(330, 0))
	right.add_child(AK.section(unpack_pick, "POINTS"))
	right.add_child(AK.label("%d / %d" % [points - spent, points], 28, AK.HOLO, AK.en()))
	var refusal := game.unpack_refusal(unpack_pick, unpack_counts) if not unpack_counts.is_empty() else "未选"
	var go := AK.button("拆包" if refusal.is_empty() else refusal, "blue" if refusal.is_empty() else "plain", 15)
	go.custom_minimum_size = Vector2(320, 44)
	go.disabled = not refusal.is_empty()
	go.pressed.connect(func():
		if game.unpack(unpack_pick, unpack_counts): unpack_counts.clear()
		stash(menu))
	right.add_child(go)

## The zone's next rack: the front row first, then further back.
static func _rack_button(menu: FieldMenu, stage: Control, zone: int) -> void:
	var game := menu.game
	var slot := game.base.next_rack_slot(zone)
	var label := "货架已满配"
	var refusal := "已满配"
	if slot >= 0:
		refusal = game.rack_refusal(zone)
		var cost: Dictionary = BaseCatalog.RACK_MATERIALS[slot]
		label = "扩建第 %d 个货架  %s%s" % [slot + 1, Economy.format(BaseCatalog.RACK_PRICES[slot]), "" if cost.is_empty() else " + " + BaseCatalog.cost_text(cost)]
		if not refusal.is_empty(): label += "（%s）" % refusal.trim_suffix("。")
	var build := AK.button(label, "blue" if refusal.is_empty() else "plain", 13)
	build.set_meta("label", "扩建货架")
	AK.put(stage, build, Vector2(16, TOP + 4), Vector2(396, 34))
	build.disabled = not refusal.is_empty()
	build.pressed.connect(func(): game.build_rack(zone); stash(menu, zone))

# --- 基建 ---------------------------------------------------------------------------

## The 基建总控台 (基建设施修订案 v1.1 §四, 用户 2026-10-22): the facilities down
## the left, the picked one's upgrades on the right. From the hub (`site` "")
## only connected facilities can be upgraded; at a facility's own site
## (`site` its id) its page alone, connected or not.
static func construction(menu: FieldMenu, title: String = "基建总控台", site: String = "") -> void:
	var game := menu.game
	var base: BaseState = game.base
	var stage := shell(menu, title, "CONSTRUCTION", [], 0, Callable(), "BUILD", [["lmd", Economy.format(game.gold)]])
	var redraw := func(): construction(menu, title, site)
	if not site.is_empty():
		_facility_page(menu, stage, site, false, Vector2(16, TOP + 4), 1248, redraw)
		return
	if not menu.build_pick in BaseCatalog.FACILITY_ORDER: menu.build_pick = "hub"
	_section(stage, "设施", "FACILITIES", Vector2(16, TOP + 4))
	var y := TOP + 34
	for id in BaseCatalog.FACILITY_ORDER:
		var row := Button.new()
		row.flat = true
		row.focus_mode = Control.FOCUS_NONE
		row.set_meta("facility_row", id)
		var picked: bool = id == menu.build_pick
		row.add_child(AK.rect(AK.PLATE if picked else AK.PLATE_2, Vector2.ZERO, Vector2(300, 64)))
		row.add_child(AK.rect(Terminal.DEPT.eng if picked else AK.LINE_2, Vector2.ZERO, Vector2(6, 64)))
		AK.put(row, AK.label(BaseCatalog.facility_name(id), 15, AK.FG), Vector2(18, 10))
		AK.put(row, AK.label("Lv%d / %d" % [base.facility_level(id), BaseCatalog.facility_max(id)], 12, AK.MUTE, AK.en()), Vector2(18, 36))
		if id != "hub":
			var linked := base.is_connected_to_hub(id)
			var dot := AK.rect(AK.HOLO if linked else AK.DIM, Vector2(204, 41), Vector2(8, 8))
			row.add_child(dot)
			AK.put(row, AK.label("已接入" if linked else "未接入", 12, AK.HOLO if linked else AK.MUTE), Vector2(218, 34))
		if game.facility_refusal(id, true).is_empty() or game.connect_refusal(id).is_empty():
			var c := Vector2(286, 14)
			var mark := Polygon2D.new()
			mark.polygon = AK.diamond(c, 8)
			mark.color = AK.SP
			row.add_child(mark)
		var pick: String = id
		row.pressed.connect(func(): menu.build_pick = pick; redraw.call())
		AK.put(stage, row, Vector2(16, y), Vector2(300, 64))
		y += 70
	_facility_page(menu, stage, menu.build_pick, true, Vector2(336, TOP + 4), 928, redraw)

## One facility's upgrades: its link to the hub, its next level, then the
## projects it owns. `remote`: seen from the hub, where an unconnected one
## shows only its link.
static func _facility_page(menu: FieldMenu, stage: Control, id: String, remote: bool, at: Vector2, width: float, redraw: Callable) -> void:
	var game := menu.game
	var base: BaseState = game.base
	_section(stage, BaseCatalog.facility_name(id), "Lv%d / %d" % [base.facility_level(id), BaseCatalog.facility_max(id)], at)
	var y := at.y + 30
	var gate := game.gate_refusal(id)
	if not gate.is_empty():
		var g: Dictionary = BaseCatalog.FACILITIES[id].gate
		var rel := game.exchange.relation(str(g.faction))
		var need: int = Exchange.RANK_AT[int(g.rank)]
		stage.add_child(AK.rect(AK.PLATE_2, Vector2(at.x, y), Vector2(width, 54)))
		AK.put(stage, AK.label("%s 关系 R%d" % [FactionCatalog.name_of(str(g.faction)), int(g.rank)], 14, AK.FG), Vector2(at.x + 14, y + 8))
		AK.put(stage, AK.label("%d / %d" % [rel, need], 12, AK.MUTE, AK.en()), Vector2(at.x + 14, y + 30))
		var bar := FieldPanels.Bar.new()
		bar.ratio = float(rel) / maxf(need, 1)
		bar.colour = AK.SP
		AK.put(stage, bar, Vector2(at.x + 160, y + 36), Vector2(width - 180, 4))
		return
	if id != "hub" and not base.is_connected_to_hub(id) and (remote or base.hub_built()):
		var c_refusal := game.connect_refusal(id)
		_project_row(menu, stage, Vector2(at.x, y), ["接入基建总控台", "", int(BaseCatalog.CONNECT_COST.price), BaseCatalog.connect_materials(id), c_refusal,
			func(): return game.connect_facility(id)], redraw, width, "接入")
		y += 60
		if remote: return
	var level := base.facility_level(id)
	var step := BaseCatalog.facility_step(id, level + 1)
	if step.is_empty(): _project_row(menu, stage, Vector2(at.x, y), ["Lv%d" % level, "已满级", 0, {}, "", Callable()], redraw, width)
	else:
		var refusal := game.facility_refusal(id, remote)
		_project_row(menu, stage, Vector2(at.x, y), ["Lv%d  %s" % [level + 1, step.opens], "", int(step.price), step.materials, refusal,
			func(): return game.upgrade_facility(id, remote)], redraw, width, "建成" if level == 0 else "升级", "facility", id)
	y += 60
	for row in _projects(game, id):
		_project_row(menu, stage, Vector2(at.x, y), row, redraw, width)
		y += 60

## The projects a facility owns: [title, done text ("" while open), price, materials, refusal, buy].
static func _projects(game: GameManager, id: String) -> Array:
	var base: BaseState = game.base
	var rows: Array = []
	match id:
		"hub":
			rows.append(["营地升级", "已升级" if base.camp_upgraded else "", BaseCatalog.CAMP_UPGRADE_PRICE, BaseCatalog.CAMP_UPGRADE_MATERIALS, game.camp_upgrade_refusal(), game.buy_camp_upgrade])
		"warehouse":
			rows.append(["仓库总控面板", "已就位" if base.console else "", BaseCatalog.CONSOLE_PRICE, BaseCatalog.CONSOLE_MATERIALS, game.console_refusal(), game.buy_console])
			rows.append(["搬运无人机", "已就位" if base.drone else "", BaseCatalog.DRONE_PRICE, BaseCatalog.DRONE_MATERIALS, game.drone_refusal(), game.buy_drone])
			for category in GameManager.RACK_ZONES:
				var slot := base.next_rack_slot(category)
				var zone: int = category
				rows.append(["%s区货架 %d/%d" % [BaseCatalog.CATEGORY_NAMES[category], int(base.racks[category]), BaseCatalog.RACK_SLOTS], "已满配" if slot < 0 else "",
					int(BaseCatalog.RACK_PRICES[slot]) if slot >= 0 else 0, game.rack_cost(category), game.rack_refusal(category).trim_suffix("。"), func(): return game.build_rack(zone)])
		"outfit":
			for kind in ["pack", "safe"]:
				var level := base.pack_level if kind == "pack" else base.safe_level
				var sizes: Array = BaseCatalog.PACK_SIZES if kind == "pack" else BaseCatalog.SAFE_SIZES
				var prices: Array = BaseCatalog.PACK_PRICES if kind == "pack" else BaseCatalog.SAFE_PRICES
				var now: Vector2i = sizes[level]
				var full := level + 1 >= sizes.size()
				var next: Vector2i = now if full else sizes[level + 1]
				var label := "%s %d×%d" % ["背包" if kind == "pack" else "安全袋", now.x, now.y] + ("" if full else " → %d×%d" % [next.x, next.y])
				rows.append([label, "已满配" if full else "", 0 if full else int(prices[level + 1]), game.upgrade_cost(kind), game.upgrade_refusal(kind),
					game.buy_pack_upgrade if kind == "pack" else game.buy_safe_upgrade])
	return rows

## One upgrade card: title, cost (short materials in red), button; or its done state.
static func _project_row(menu: FieldMenu, stage: Control, at: Vector2, row: Array, redraw: Callable, width: float = 396.0, verb: String = "建造", meta_key: String = "project", meta_value: Variant = null) -> void:
	var game := menu.game
	stage.add_child(AK.rect(AK.PLATE_2, at, Vector2(width, 54)))
	AK.put(stage, AK.label(row[0], 14, AK.FG), at + Vector2(14, 7))
	if not str(row[1]).is_empty():
		AK.put(stage, AK.label(row[1], 12, AK.GREEN), at + Vector2(14, 31))
		return
	_cost_line(game, stage, at + Vector2(14, 31), int(row[2]), row[3], 12)
	var refusal: String = row[4]
	var b := AK.button(verb if refusal.is_empty() else _short_refusal(refusal), "blue" if refusal.is_empty() else "plain", 12)
	b.set_meta(meta_key, meta_value if meta_value != null else row[0])
	b.disabled = not refusal.is_empty()
	var buy: Callable = row[5]
	b.pressed.connect(func(): buy.call(); redraw.call())
	AK.put(stage, b, at + Vector2(width - 160, 10), Vector2(150, 34))

## The cost line already marks what is short in red, so the button just says so.
static func _short_refusal(refusal: String) -> String:
	return "材料不足" if refusal.begins_with("缺少") else refusal

## 龙门币 then each material, red where the warehouse is short.
static func _cost_line(game: GameManager, stage: Control, at: Vector2, price: int, materials: Dictionary, size: int = 12) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	line.add_child(AK.money("lmd", Economy.format(price), size + 2))
	for mat in materials:
		var short := game.material_count(mat) < int(materials[mat])
		line.add_child(AK.label("%s×%d" % [mat, int(materials[mat])], size, AK.RED if short else AK.MUTE))
	AK.put(stage, line, at)

static func _show_detail(game: GameManager, item: Item) -> void:
	hovered = item
	if is_instance_valid(_detail): _detail.text = ItemTooltip.text(game, item, false, false)

# --- #15 出库区 -----------------------------------------------------------------------

static func outbound(menu: FieldMenu) -> void:
	var game := menu.game
	var base: BaseState = game.base
	var orders: OrderBoard = base.orders
	var tab: int = menu.outbound_tab
	var stage := shell(menu, "出库区", "OUTBOUND", ["订单", "直接交付"], tab, func(i): menu.outbound_tab = i; menu.pick = null; outbound(menu), "ORDERS",
		[["lmd", Economy.format(game.gold)]])
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
	# The order strips.
	var y := TOP + 8
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

const MEDICAL_TABS := ["药房窗口", "回收报告"]

static func medical(menu: FieldMenu, tab: int) -> void:
	if tab == 0:
		TraderScreen.pharmacy(menu)
		return
	var game := menu.game
	var base: BaseState = game.base
	var stage := shell(menu, "医疗部", "MEDICAL", MEDICAL_TABS, tab, func(i): medical(menu, i), "MEDICAL",
		[["lmd", Economy.format(game.gold)]])
	match tab:
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
				row.add_child(AK.label(entry.reason, 13, colour))
				holder.add_child(row)

# --- #17 出发准备 / 整备 ----------------------------------------------------------------

## One entry, four screens (界面美术与布局策划案 v2 S2, LoadoutScreens): a region
## is 出发准备; "insurance" the logistics counter; otherwise the workbench.
static func departure(menu: FieldMenu, region: String, kind: String = "") -> void:
	if not region.is_empty(): LoadoutScreens.deploy(menu, region)
	elif kind == "insurance": LoadoutScreens.logistics(menu)
	else: LoadoutScreens.workbench(menu)

## The item whose lines 精调 is choosing from (null otherwise).
static var _tuning: Item = null

static func _back_from_training(menu: FieldMenu, region: String, kind: String) -> void:
	menu.game.open_modal("station")
	if region.is_empty(): menu.game.open_station(kind if not kind.is_empty() else "loadout")
	else: menu.show_departure(region)

static func _refresh(menu: FieldMenu, region: String, kind: String) -> void:
	departure(menu, region, kind)

# --- 可露希尔的商店 (base) ---------------------------------------------------------

static func store(menu: FieldMenu) -> void:
	EventScreens.camp(menu, true)

# --- #11 暂停与设置 ------------------------------------------------------------------

const PAUSE_ITEMS := ["继续作业", "设置", "按键设置", "放弃合同", "回到标题"]
const SETTING_TABS := ["画面", "界面", "音频", "基地"]

static func pause(menu: FieldMenu) -> void:
	var game := menu.game
	var stage := menu.stage_begin(0.85)
	var page: int = menu.pause_page
	stage.add_child(AK.rect(Color("0c0e10"), Vector2.ZERO, Vector2(280, 720)))
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
	elif page == 2: _hotbar_page(menu, stage)

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
		1: rows = [["界面动效", ["精简", "完整"], "ui_motion"], ["交易确认", ["关", "开"], "trade_confirm"], ["伤害数字", ["关", "开"], "damage_numbers"], ["订单追踪", ["隐藏", "显示"], "tracker"], ["PRTS 提示", ["隐藏", "显示"], "broadcasts"], ["新手引导", ["关", "开"], "tutorial"], ["主线引导", ["关", "开"], "story_guide"], ["language"],
			["自动喝药下限", [], "auto_potion_low", 0.05, 0.95], ["自动喝药上限", [], "auto_potion_high", 0.05, 0.95]]
		2: rows = [["主音量", [], "master_volume"]]
		3:
			_base_settings(menu, stage)
			return
	var y := 104.0
	for row in rows:
		if row[0] == "language":
			AK.put(stage, SystemScreens.language_toggle(func(): pause(menu)), Vector2(334, y + 6), Vector2(886, 38))
			stage.add_child(AK.rect(AK.LINE, Vector2(334, y + 49), Vector2(886, 1)))
			y += 50
			continue
		AK.put(stage, AK.label(row[0], 14, AK.FG), Vector2(334, y + 12))
		var key: String = row[2]
		if row[1].is_empty():
			# A ranged row ([label, [], key, min, max]) is a share shown as a percentage.
			var ranged: bool = row.size() >= 5
			var slider := HSlider.new()
			slider.min_value = float(row[3]) if ranged else 0.0
			slider.max_value = float(row[4]) if ranged else 1.0
			slider.step = 0.05
			slider.value = float(s.get(key, 0.8))
			if ranged:
				var shown := AK.label("%d%%" % roundi(slider.value * 100), 13, AK.FG, AK.en())
				AK.put(stage, shown, Vector2(846, y + 14))
				slider.value_changed.connect(func(v): SystemScreens.set_setting(key, v); shown.text = "%d%%" % roundi(v * 100))
			else:
				slider.value_changed.connect(func(v): SystemScreens.set_setting(key, v))
			AK.put(stage, slider, Vector2(900, y + 12), Vector2(320, 24))
		else:
			var current := 1 if bool(s.get(key, false)) else 0
			var pick := func(i): SystemScreens.set_setting(key, i == 1); pause(menu)
			# 新手引导: on starts it over, off skips the rest.
			if key == "tutorial":
				current = 0 if TutorialCard.finished() and not bool(s.get("tutorial_tips", true)) else 1
				pick = func(i): TutorialCard.set_on(i == 1); pause(menu)
			var toggle := AK.toggle(row[1], current, pick, 13)
			toggle.alignment = BoxContainer.ALIGNMENT_END
			AK.put(stage, toggle, Vector2(900, y + 6), Vector2(320, 38))
		stage.add_child(AK.rect(AK.LINE, Vector2(334, y + 49), Vector2(886, 1)))
		y += 50

## 基地 (用户 2026-10-18): whether the station overview is open (its key
## toggles it too), and which stations it lists.
static func _base_settings(menu: FieldMenu, stage: Control) -> void:
	var s := SystemScreens.settings
	var y := 104.0
	var rows: Array = [["站点总览", "station_panel", BaseHud.panel_open()]]
	for entry in BaseHud.STATIONS: rows.append([entry[0], entry[1], not entry[1] in s.get("station_hidden", [])])
	for i in range(rows.size()):
		var row: Array = rows[i]
		var x := 334.0 if i == 0 else 360.0
		AK.put(stage, AK.label(row[0], 14 if i == 0 else 13, AK.FG if i == 0 else AK.MUTE), Vector2(x, y + 12))
		var key: String = row[1]
		var toggle := AK.toggle(["隐藏", "显示"], 1 if row[2] else 0, func(pick):
			if key == "station_panel":
				SystemScreens.set_setting("station_panel", pick == 1)
			else:
				var hidden: Array = Array(SystemScreens.settings.get("station_hidden", [])).filter(func(k): return k != key)
				if pick == 0: hidden.append(key)
				SystemScreens.set_setting("station_hidden", hidden)
			pause(menu), 13)
		toggle.alignment = BoxContainer.ALIGNMENT_END
		AK.put(stage, toggle, Vector2(900, y + 6), Vector2(320, 38))
		stage.add_child(AK.rect(AK.LINE, Vector2(334, y + (49 if i == 0 else 43)), Vector2(886, 1)))
		y += 50 if i == 0 else 44
	# 交易终端与盯盘小窗策划案 §1: the exchange outside the game.
	AK.put(stage, AK.label("交易终端与盯盘小窗", 14, AK.FG), Vector2(334, y + 12))
	var links := AK.button("创建桌面快捷方式", "plain", 13)
	links.pressed.connect(func():
		Toast.desktop_shortcuts()
		menu.game.set_message("桌面上已创建：罗德岛交易终端、罗德岛盯盘。"))
	AK.put(stage, links, Vector2(1020, y + 6), Vector2(200, 34))

## 按键设置 (用户 2026-10-10, after Grim Dawn's Options → Keybindings): every
## Keybinds function with a primary and a secondary binding, keyboard or mouse
## (middle, side buttons, wheel). Click a binding, then press a key or mouse
## button; Esc cancels, Backspace clears. A binding another function had is
## taken from it. The hotbar's contents are picked on the bar itself.
const KEY_ROW := 24.0

static func _hotbar_page(menu: FieldMenu, stage: Control) -> void:
	_panel(stage)
	var reset := AK.button("恢复默认", "plain", 12)
	reset.pressed.connect(func(): Keybinds.reset(); menu.hotbar_capture = -1; pause(menu))
	AK.put(stage, reset, Vector2(1110, 46), Vector2(120, 28))
	for col in range(2):
		AK.put(stage, AK.label("主键", 11, AK.MUTE), Vector2(334 + col * 470 + 196, 54))
		AK.put(stage, AK.label("副键", 11, AK.MUTE), Vector2(334 + col * 470 + 342, 54))
	var binds := Keybinds.all()
	var columns := {"快捷栏": 0, "专用键": 0, "视角": 0, "界面": 1}
	var y := [76.0, 76.0]
	var last_group := ["", ""]
	for f in Keybinds.FUNCTIONS:
		var col: int = columns[f[2]]
		var x := 334.0 + col * 470.0
		if f[2] != last_group[col]:
			last_group[col] = f[2]
			AK.put(stage, AK.label(f[2], 13, AK.SP), Vector2(x, y[col] + 4))
			y[col] += KEY_ROW
		AK.put(stage, AK.label(f[1], 13, AK.FG), Vector2(x, y[col] + 5))
		var index := Keybinds.FUNCTIONS.find(f)
		for which in range(2):
			var flat := index * 2 + which
			var waiting := menu.hotbar_capture == flat
			var text := "按下按键…" if waiting else Keybinds.label(binds[f[0]][which])
			var b := AK.button(text if not text.is_empty() else "—", "paper" if waiting else "plain", 12)
			b.set_meta("binding", flat)
			b.pressed.connect(func(): menu.hotbar_capture = flat; pause(menu))
			AK.put(stage, b, Vector2(x + 140 + which * 146, y[col]), Vector2(140, KEY_ROW - 4))
		y[col] += KEY_ROW
	var fy: float = y[1] + 6
	AK.put(stage, AK.label("固定", 13, AK.SP), Vector2(804, fy + 4))
	fy += KEY_ROW
	for row in Keybinds.FIXED:
		AK.put(stage, AK.label(row[0], 12, AK.MUTE), Vector2(804, fy + 4))
		var keys := AK.label(row[1], 12, AK.FG, AK.en())
		keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		AK.put(stage, keys, Vector2(944, fy + 4), Vector2(286, 20))
		fy += 24
	if menu.hotbar_capture >= 0:
		var catcher := KeyCatcher.new()
		catcher.menu = menu
		stage.add_child(catcher)

## Takes the next key or mouse button for the waiting binding; Esc cancels,
## Backspace clears it. Left and right mouse are ignored (they click the page).
class KeyCatcher extends Control:
	var menu: FieldMenu
	func _input(event: InputEvent) -> void:
		var key: bool = event is InputEventKey and event.pressed and not event.echo
		var mouse: bool = event is InputEventMouseButton and event.pressed and not event.button_index in Keybinds.BLOCKED_MOUSE
		if not key and not mouse: return
		get_viewport().set_input_as_handled()
		var flat := menu.hotbar_capture
		menu.hotbar_capture = -1
		menu.hotbar_capture_frame = Engine.get_process_frames()
		var f: Array = Keybinds.FUNCTIONS[flat / 2]
		if key and event.physical_keycode == KEY_BACKSPACE: Keybinds.bind(f[0], flat % 2, null)
		elif not (key and event.physical_keycode == KEY_ESCAPE):
			var binding: Variant = Keybinds.from_event(event)
			if binding != null: Keybinds.bind(f[0], flat % 2, binding)
		BaseScreens.pause(menu)

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
	## Drag (ItemDrag): its items drag out when `drag`; it takes what accept(item) allows.
	var drag := false
	var accept: Callable
	var take: Callable
	## Packed (the workbench depot): each item at the first cell it fits, row by
	## row, so small pieces fill the gaps beside big ones; the grid grows to fit.
	var places := {}
	## Right click (a quick action) and the item's full hover card.
	var on_alt: Callable
	var cards := false

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

	## The packed grid: `w` wide, at least `min_rows` tall, every item placed.
	static func packed(shown: Array, w: int, min_rows: int, pick: Callable) -> FlowGrid:
		var taken := {}
		var places := {}
		var rows := min_rows
		for item: Item in shown:
			var at := Vector2i(-1, -1)
			var y := 0
			while at.x < 0:
				for x in range(w - item.width + 1):
					var free := true
					for dy in range(item.height):
						for dx in range(item.width):
							if taken.has(Vector2i(x + dx, y + dy)): free = false
					if free:
						at = Vector2i(x, y)
						break
				y += 1
			for dy in range(item.height):
				for dx in range(item.width): taken[at + Vector2i(dx, dy)] = true
			places[item] = at
			rows = maxi(rows, at.y + item.height)
		var grid := make(shown, w, rows, pick, func(_it): pass)
		grid.places = places
		grid.cards = true
		return grid

	## Cells the items take.
	func used_cells() -> int:
		var n := 0
		for item: Item in items: n += item.width * item.height
		return n

	## Its items drag out; drops that `accept_item(item)` allows go to `take_item(item)`.
	func dragging(accept_item: Callable, take_item: Callable) -> FlowGrid:
		drag = true
		accept = accept_item
		take = take_item
		return self

	func _ready() -> void:
		if accept.is_valid(): ItemDrag.wire(self, null, accept, take)
		var x := 0
		var y := 0
		var row_h := 0
		for item: Item in items:
			if places.has(item):
				x = places[item].x
				y = places[item].y
			elif x + item.width > columns:
				x = 0
				y += row_h
				row_h = 0
			if y + item.height > rows: break
			var tile: Button = TraderScreen.ShelfTile.new() if cards else Button.new()
			if cards: tile.item = item
			tile.flat = true
			tile.focus_mode = Control.FOCUS_NONE
			tile.position = Vector2(x, y) * CELL
			tile.size = Vector2(item.width, item.height) * CELL - Vector2.ONE
			tile.set_meta("item", item)
			tile.add_child(AK.item_icon(item, tile.size))
			var shown := item
			tile.pressed.connect(func(): on_pick.call(shown))
			tile.mouse_entered.connect(func(): on_hover.call(shown))
			if on_alt.is_valid():
				tile.gui_input.connect(func(e: InputEvent):
					if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT: on_alt.call(shown))
			if drag or accept.is_valid(): ItemDrag.wire(tile, shown if drag else null, accept, take)
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
	var panel := AK.rect(Color("0d1012"), Vector2(260, 130), Vector2(760, 460))
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
