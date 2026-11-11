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

## A 动态 headline's hover (用户 2026-10-25: 悬停可查看具体文本和效果): the
## headline, where and how long it lasts, then each effect on the field.
const NEWS_ENEMY_TAGS := {"family": "家族成员", "reunion": "整合运动", "ursus_army": "乌萨斯军队"}

static func _news_tip(game: GameManager, n: Dictionary) -> String:
	var ev: Dictionary = MarketEvents.EVENTS.get(str(n.id), {})
	var lines: Array[String] = [str(n.title)]
	var head: Array[String] = []
	if ev.has("kind"): head.append(str(MarketEvents.KIND_NAMES.get(str(ev.kind), "快讯")))
	if ev.has("region"): head.append(str(ev.region))
	head.append("剩余 " + ExchangeScreen._left(int(n.until) - game.market.t))
	lines.append(" · ".join(head))
	for e in n.effects: lines.append(_news_effect(str(e[0]), float(e[1]), bool(e[2])))
	return "
".join(lines)

static func _news_effect(key: String, value: float, adds: bool) -> String:
	var arg := key.get_slice(":", 1)
	var what: String = {
		"threat": "威胁值增长", "elite": "精英敌人", "kannot_buy": "坎诺特收购价", "kannot_stock": "坎诺特货架",
		"gold_drop": "赤金掉落", "feature_add": "地图特色起点", "feature_rate": "地图特色增长",
		"reward": "合同报酬", "camp_fx": "可露希尔差价",
	}.get(key, key)
	match key.get_slice(":", 0):
		"enemy": what = NEWS_ENEMY_TAGS.get(arg, arg) + "出现"
		"route": what = RouteMap.kind_name(arg) + "节点"
		"post": what = FactionCatalog.name_of(arg) + "据点"
		"post_price": what = FactionCatalog.name_of(arg) + "据点价格"
		"loot": what = str(FactionCatalog.CATEGORIES.get(arg, arg)) + "掉落"
	if adds: return "%s %+d" % [what, roundi(value)]
	return "%s %+d%%" % [what, roundi((value - 1.0) * 100.0)]

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
		# The block's last floor, the 前哨据点 or 首领战场 (肉鸽路线图策划案 v0.2);
		# the extraction is not marked here (用户 2026-10-25: 调度台不标撤离信标).
		var last := n == FieldCatalog.CAMP_INTERVAL
		var style := AK.box(Color("3a2224") if last else AK.PLATE_3)
		if last:
			style.border_color = AK.RED
			style.border_width_bottom = 2
		node.add_theme_stylebox_override("normal", style)
		AK.put(stage, node, at, Vector2(84, 34))
		if last: AK.put(stage, AK.tag(RouteMap.kind_name("boss" if BossCatalog.is_boss_floor(start + n) else "outpost"), AK.RED, false), at + Vector2(10, 38))
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
	# What the exchange's news does to this region now (地区货币策划案 §2.3):
	# the headlines only, red when it makes the field harder.
	var news: Array = game.market.field_news(region)
	if not news.is_empty():
		_section(stage, "动态", "NEWS", Vector2(248, chain_top + 224))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		AK.put(stage, flow, Vector2(248, chain_top + 256), Vector2(620, 0))
		for n in news:
			var t := AK.tag(str(n.title), AK.RED if n.harder else AK.SP)
			t.mouse_filter = Control.MOUSE_FILTER_STOP
			t.tooltip_text = _news_tip(game, n)
			flow.add_child(t)
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
	# 外勤部 2 阶: one free reroll of the chosen ordinary card per return.
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
	var stage := shell(menu, "人事部", "PERSONNEL", ["寻访干员", "特派干员"], personnel_tab, func(i): personnel_tab = i; personnel(menu), "ROSTER")
	if personnel_tab == 1:
		_lost_roster(menu, stage)
		return
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

## The 人事部 tab shown (0 寻访干员, 1 特派干员).
static var personnel_tab := 0

## 失散干员 (失散干员与主线流程策划案 v0.2 §八): the special operators, each with
## the department she runs; one still missing shows where her signal is from.
static func _lost_roster(menu: FieldMenu, stage: Control) -> void:
	var game := menu.game
	var base: BaseState = game.base
	_section(stage, "特派干员", "SPECIAL OPERATORS", Vector2(16, TOP + 8))
	if is_instance_valid(game.tutorial_spotlight): game.tutorial_spotlight.request("base_roster", Rect2(16, TOP + 40, 1248, 600))
	var ids: Array = LostCatalog.LOST.keys()
	for i in range(ids.size()):
		var id: String = ids[i]
		var back := base.lost_back(id)
		var at := Vector2(16 + (i % 4) * 312, TOP + 40 + (i / 4) * 300)
		stage.add_child(AK.rect(AK.PLATE_2, at, Vector2(300, 288)))
		var idle: Texture2D = LapplandAnimator3D.sheet(LostCatalog.figure_id(id), "idle") if LapplandAnimator3D.has_sheets(id) else null
		if idle != null:
			var stand := AtlasTexture.new()
			stand.atlas = idle
			stand.region = Rect2(0, 0, LapplandAnimator3D.CELL_TEXELS, LapplandAnimator3D.CELL_TEXELS)
			var picture := TextureRect.new()
			picture.texture = stand
			picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			if not back: picture.modulate = Color(0, 0, 0, 0.85)
			AK.put(stage, picture, at + Vector2(70, 8), Vector2(160, 160))
		AK.put(stage, AK.label(LostCatalog.name_of(id), 18, AK.FG), at + Vector2(14, 172))
		AK.put(stage, AK.label(LostCatalog.dept_text(id), 13, AK.MUTE), at + Vector2(14, 200))
		if back:
			AK.put(stage, AK.tag("已归队", AK.GREEN), at + Vector2(14, 248))
		else:
			var region := str(FieldCatalog.REGIONS[LostCatalog.region_of(id)].name).split(" · ")[0]
			AK.put(stage, AK.label("%s · 第 %s 层" % [region, LostCatalog.range_text(id)], 13, AK.FG), at + Vector2(14, 222))
			AK.put(stage, AK.tag("失散", AK.RED), at + Vector2(14, 248))

# --- #14 仓库 -------------------------------------------------------------------------

const STASH_TABS := ["全部", "武器", "防具", "饰品", "药剂", "材料", "收藏品", "拆包"]
## The 拆包 page (交易所交易包修订案 §4): the pack picked and the pick so far.
const UNPACK_TAB := 7
static var unpack_pick := ""
static var unpack_counts := {}

## The 仓管台: the whole warehouse, one count of cells (仓库修订, 用户 2026-10-23);
## `zone` is kept for old callers and ignored.
static func stash(menu: FieldMenu, zone: int = -1) -> void:
	zone = -1
	var game := menu.game
	var base: BaseState = game.base
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
	if true:
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
	# The warehouse's load (red when full) and its stack size.
	var have := base.shelf_count()
	var room := base.capacity()
	var cell := VBoxContainer.new()
	cell.custom_minimum_size.x = 300
	var row := HBoxContainer.new()
	row.add_child(AK.label("仓库", 12, AK.MUTE))
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(fill)
	row.add_child(AK.label("%d/%d  ·  ×%d" % [have, room, base.stack_mult()], 12, AK.RED if have >= room else AK.FG, AK.en()))
	cell.add_child(row)
	var bar := FieldPanels.Bar.new()
	bar.ratio = float(have) / maxf(room, 1)
	bar.colour = AK.RED if have >= room else Color("cfcfcf")
	bar.custom_minimum_size.y = 3
	cell.add_child(bar)
	AK.put(stage, cell, Vector2(560, TOP + 6))
	# The warehouse grid (用户 2026-10-24: 仓库自动整理不留空隙，但玩家可以随意
	# 摆放，物体可以旋转): on 全部 every item lies in its own cell and can be
	# dragged to any free one or turned (旋转物品); 整理 packs them without gaps.
	# A filtered tab packs what it shows.
	var shown: Array = game.stash.filter(func(x: Item): return tab_shows(x, tab) and menu._matches(x))
	var free_layout := tab == 0 and menu.stash_query.is_empty()
	var sort := AK.button("整理", "plain", 12)
	AK.put(stage, sort, Vector2(402, TOP + 4), Vector2(80, 34))
	sort.disabled = not free_layout
	sort.pressed.connect(func(): base.shelf_sort(); game.save_base(); stash(menu, zone))
	var redraw := func(): stash(menu, zone)
	var grid: FlowGrid
	if free_layout:
		grid = shelf_grid(game, FlowGrid.CELL, 14, redraw)
	else:
		grid = FlowGrid.packed(shown, BaseState.SHELF_COLUMNS, base.shelf_height(), func(item: Item): game.bring_item(item); stash(menu, zone))
		grid.on_hover = func(item: Item): _show_detail(game, item)
		# Drag: pack → shelf stores it (the pack takes drops on its own, below).
		grid.dragging(func(item: Item) -> bool: return game.carried_items().has(item), func(item: Item): game.store_item(item); stash(menu, zone))
	# Every tile shows its card on hover (the right column is the pack now).
	grid.cards = true
	TraderScreen._game = game
	var depot := ScrollContainer.new()
	depot.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	depot.add_child(grid)
	AK.put(stage, depot, Vector2(16, TOP + 50), Vector2(16 * 40 + 12, BOTTOM - TOP - 50))
	# Right (用户 2026-10-25: 右侧改为背包，可拖拽物品): the pack and safe bag;
	# a click stores, a drag from the warehouse carries, one between them moves.
	var r := Rect2(684, TOP + 50, 1264 - 684, BOTTOM - TOP - 50)
	LoadoutScreens._panel(stage, r, AK.HOLO)
	var safe_y := r.position.y + 42 + game.inventory.height * 40 + 14
	for entry in [[game.inventory, r.position.y + 42], [game.safe_bag, safe_y + 28]]:
		var bag: ItemContainer = entry[0]
		var pack := AK.BagGrid.make(bag, Callable(), func(item: Item): game.store_item(item); stash(menu, zone))
		pack.cards = true
		pack.on_hover = func(item: Item): hovered = item
		ItemDrag.bag(pack, func(item: Item) -> bool: return not bag.items.has(item) and not item.is_case() and LoadoutScreens._where(game, item) != "",
			func(item: Item): LoadoutScreens._carry(game, item, bag); stash(menu, zone))
		AK.put(stage, pack, Vector2(r.position.x + 16, entry[1]))
	_section(stage, "背包", "PACK %d / %d" % [game.inventory.occupied_cells(), game.inventory.cell_count()], r.position + Vector2(16, 14))
	_section(stage, "安全袋", "SAFE", Vector2(r.position.x + 16, safe_y))
	case_window(game, stage, Rect2(16, TOP + 50, 652, BOTTOM - TOP - 50))

## The tabs of the 仓管台 and the workbench's depot (整理箱与收藏品策划案 v0.2 §1):
## everything, the three gear groups, flasks, materials, collectibles.
static func tab_shows(item: Item, tab: int) -> bool:
	match tab:
		0: return true
		1, 2, 3: return item.is_equippable() and Item.group_of(item.category) == [Item.Category.WEAPON, Item.Category.ARMOR, Item.Category.TRINKET][tab - 1]
		4: return item.is_potion()
		5: return item.category == Item.Category.MATERIAL and not item.is_potion()
		6: return item.is_collectible()
	return false

## The warehouse as it lies (its 全部 page), at `size` pixels a cell, on the
## 仓管台 and the workbench: drag anywhere, T turns, a drop on a 整理箱 puts
## the item in it, a double click opens the box (§0-9).
static func shelf_grid(game: GameManager, size: int, min_rows: int, redraw: Callable, pick: Callable = Callable()) -> FlowGrid:
	var base: BaseState = game.base
	base.shelf_normalize()
	var shown: Array = base.shelf.duplicate()
	var grid := FlowGrid.make(shown, BaseState.SHELF_COLUMNS, base.shelf_height(),
		pick if pick.is_valid() else func(item: Item): game.bring_item(item); redraw.call(), func(item: Item): _show_detail(game, item), size)
	for item: Item in shown: grid.places[item] = Vector2i(item.grid_x, item.grid_y)
	grid.dragging(func(item: Item) -> bool: return game.carried_items().has(item) or base.case_of(item) != null,
		func(item: Item): shelf_drop(game, item, Vector2i(-1, -1)); redraw.call())
	grid.move_to = func(item: Item, cell: Vector2i): shelf_drop(game, item, cell); redraw.call()
	grid.on_rotate = func(item: Item):
		if base.shelf_rotate(item):
			game.save_base()
			redraw.call()
	grid.on_open = func(box: Item): open_case(box, redraw)
	grid.cards = true
	TraderScreen._game = game
	return grid

## `item` dropped on the warehouse at `cell`: into the 整理箱 lying there, else
## onto the shelves there (stored from the bags or taken out of its box).
static func shelf_drop(game: GameManager, item: Item, cell: Vector2i) -> void:
	var base: BaseState = game.base
	var under := base.shelf_at(cell) if cell.x >= 0 else null
	if under != null and under != item and under.is_case():
		game.box_item(under, item)
		return
	if game.carried_items().has(item):
		game.store_item(item)
		if base.shelf.has(item) and cell.x >= 0: base.shelf_move(item, cell.x, cell.y)
	elif base.case_of(item) != null: game.unbox_item(item, cell)
	elif base.shelf.has(item) and cell.x >= 0: base.shelf_move(item, cell.x, cell.y)
	game.save_base()

# --- 整理箱 window (§0-9) ------------------------------------------------------------

## The open box and the screen to redraw; the window is drawn over the screen
## by case_window, Esc shuts it first.
static var open_box: Item = null
static var _box_redraw: Callable

static func open_case(box: Item, redraw: Callable) -> void:
	open_box = box
	_box_redraw = redraw
	redraw.call()

static func close_case() -> bool:
	if open_box == null: return false
	open_box = null
	if _box_redraw.is_valid(): _box_redraw.call()
	return true

## The open box's grid in a window over `stage`, centred on `around`.
static func case_window(game: GameManager, stage: Control, around: Rect2) -> void:
	if open_box == null: return
	if not game.base.shelf.has(open_box) or not open_box.is_case():
		open_box = null
		return
	var box := open_box
	var inner := Vector2(box.contents.width, box.contents.height) * 40
	var size := inner + Vector2(32, 72)
	var at := (around.position + (around.size - size) * 0.5).clamp(Vector2(8, 56), Vector2(1272, 714) - size)
	var panel := LoadoutScreens._panel(stage, Rect2(at, size), AK.HOLO)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	AK.put(stage, AK.section(box.item_name, "%d / %d" % [box.contents.occupied_cells(), box.contents.cell_count()]), at + Vector2(16, 14))
	var close := AK.button("×", "plain", 14)
	close.pressed.connect(func(): close_case())
	AK.put(stage, close, at + Vector2(size.x - 44, 10), Vector2(32, 28))
	var grid := AK.BagGrid.make(box.contents, Callable(), func(item: Item): game.bring_item(item); _box_redraw.call())
	grid.cards = true
	grid.on_hover = func(item: Item): hovered = item
	TraderScreen._game = game
	ItemDrag.bag(grid, func(item: Item) -> bool: return game.can_box(box, item), func(item: Item): game.box_item(box, item); _box_redraw.call())
	AK.put(stage, grid, at + Vector2(16, 52))


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

## A faction standing a facility waits for: the rank, relation / needed, its bar.
## 失散干员 (失散干员与主线流程策划案 v0.2 §4.2): the department's operator,
## "失散" in red while she is missing.
static func lost_bar(stage: Control, id: String, missing: bool, at: Vector2, width: float, game: GameManager = null) -> void:
	stage.add_child(AK.rect(AK.PLATE_2, at, Vector2(width, 40)))
	if missing and game != null and is_instance_valid(game.tutorial_spotlight): game.tutorial_spotlight.request("base_locked", Rect2(at, Vector2(width, 40)))
	AK.put(stage, AK.label("负责干员", 13, AK.MUTE), at + Vector2(14, 11))
	AK.put(stage, AK.label(LostCatalog.name_of(id), 14, AK.FG), at + Vector2(96, 10))
	if missing: AK.put(stage, AK.label("失散", 14, AK.RED), at + Vector2(206, 10))

static func gate_bar(stage: Control, game: GameManager, faction: String, rank: int, at: Vector2, width: float) -> void:
	var rel := game.exchange.relation(faction)
	var need: int = Exchange.RANK_AT[rank]
	stage.add_child(AK.rect(AK.PLATE_2, at, Vector2(width, 54)))
	AK.put(stage, AK.label("%s 关系 %s" % [FactionCatalog.name_of(faction), Exchange.rank_name(rank)], 14, AK.FG), at + Vector2(14, 8))
	AK.put(stage, AK.label("%d / %d" % [rel, need], 12, AK.MUTE, AK.en()), at + Vector2(14, 30))
	var bar := FieldPanels.Bar.new()
	bar.ratio = float(rel) / maxf(need, 1)
	bar.colour = AK.SP
	AK.put(stage, bar, at + Vector2(160, 36), Vector2(width - 180, 4))

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
		gate_bar(stage, game, str(g.faction), int(g.rank), Vector2(at.x, y), width)
		return
	if id != "hub" and not base.is_connected_to_hub(id) and (remote or base.hub_built()):
		var c_refusal := game.connect_refusal(id)
		_project_row(menu, stage, Vector2(at.x, y), ["接入基建总控台", "", int(BaseCatalog.CONNECT_COST.price), BaseCatalog.connect_materials(id), c_refusal,
			func(): return game.connect_facility(id)], redraw, width, "接入")
		y += 60
		if remote: return
	# Linking to the hub goes on; the levels wait for her.
	var lost := base.dept_missing(id)
	if not lost.is_empty():
		lost_bar(stage, lost, true, Vector2(at.x, y), width, game)
		return
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
		"outfit":
			for kind in ["pack", "safe"]:
				var level := base.pack_level if kind == "pack" else base.safe_level
				var prices: Array = BaseCatalog.PACK_PRICES if kind == "pack" else BaseCatalog.SAFE_PRICES
				var full := level + 1 >= BaseCatalog.expansion_levels(kind)
				var label := "%s %s" % ["背包" if kind == "pack" else "安全袋", BaseCatalog.capacity_text(kind, level)] + ("" if full else " → %s" % BaseCatalog.capacity_text(kind, level + 1))
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

## What a build or upgrade costs, 龙门币 then each material, as what she has
## over what it needs (用户 2026-10-24: 显示差多少 — 9/10 red while short, 10/9
## white once enough).
static func _cost_line(game: GameManager, stage: Control, at: Vector2, price: int, materials: Dictionary, size: int = 12) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	var money := AK.money("lmd", "%s/%s" % [Economy.format(game.gold), Economy.format(price)], size + 2)
	if game.gold < price:
		for child in money.get_children(): if child is Label: child.add_theme_color_override("font_color", AK.RED)
	line.add_child(money)
	for mat in materials:
		var have := game.material_count(mat)
		var need := int(materials[mat])
		line.add_child(AK.label("%s %d/%d" % [mat, have, need], size, AK.RED if have < need else AK.FG))
	AK.put(stage, line, at)

static func _show_detail(game: GameManager, item: Item) -> void:
	hovered = item

# --- #15 出库区 -----------------------------------------------------------------------

static func outbound(menu: FieldMenu) -> void:
	var game := menu.game
	var base: BaseState = game.base
	var orders: OrderBoard = base.orders
	# Orders only (用户 2026-10-25: 不要出库区的直接交付；只能在可露希尔处卖).
	var stage := shell(menu, "出库区", "OUTBOUND", [], 0, Callable(), "ORDERS", [["lmd", Economy.format(game.gold)]])
	var deliverable := game.deliverable_items()
	# Picking what goes to one order (用户 2026-10-24: 玩家能够选择交什么材料).
	if order_choosing >= 0 and order_choosing < orders.slots.size() and orders.slots[order_choosing] != null and orders.slots[order_choosing].state == "open":
		_order_choice(menu, stage, order_choosing, deliverable)
		return
	order_choosing = -1
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
	# Never shown now: nothing sets reroll_available (BaseState).
	if game.base.reroll_available:
		var reroll := AK.button("刷新", "plain", 12)
		reroll.pressed.connect(func(): game.reroll_order(slot); outbound(menu))
		small.add_child(reroll)
	var drop := AK.button("放弃", "plain", 12)
	drop.pressed.connect(func(): game.abandon_order(slot); outbound(menu))
	small.add_child(drop)
	AK.put(stage, small, at + Vector2(980, 20))
	var deliver := AK.button("交付", "blue" if not fits.is_empty() else "plain", 14)
	deliver.disabled = fits.is_empty()
	AK.put(stage, deliver, at + Vector2(1140, 0), Vector2(108, 72))
	deliver.pressed.connect(func():
		order_choosing = slot
		menu.pick = null
		outbound(menu))

## The order being filled by hand, -1 for the board (用户 2026-10-24).
static var order_choosing := -1

## Everything that fits order `slot`: she picks one, and hands it over.
static func _order_choice(menu: FieldMenu, stage: Control, slot: int, deliverable: Array[Item]) -> void:
	var game := menu.game
	var orders: OrderBoard = game.base.orders
	var order: Dictionary = orders.slots[slot]
	var t: Dictionary = BaseCatalog.ORDERS[order.id]
	var head := AK.label("%s  ·  已交付 %d / %d" % [BaseCatalog.order_text(order.id), orders.delivered_count(slot), int(t.count)], 15, AK.FG)
	AK.put(stage, head, Vector2(16, TOP + 8))
	var pick: Item = menu.pick if menu.pick is Item and orders.matches(slot, menu.pick) else null
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	AK.put(stage, scroll, Vector2(16, TOP + 40), Vector2(1248, 500))
	var list := GridContainer.new()
	list.columns = 4
	list.add_theme_constant_override("h_separation", 6)
	list.add_theme_constant_override("v_separation", 6)
	scroll.add_child(list)
	for item in deliverable.filter(func(x: Item) -> bool: return orders.matches(slot, x)):
		var row := EventScreens._item_row(item, "×%d" % orders.takes(slot, item), "个人仓库" if game.stash.has(item) else "背包", true, item == pick)
		row.custom_minimum_size.x = 306
		var chosen: Item = item
		row.pressed.connect(func(): menu.pick = chosen; outbound(menu))
		list.add_child(row)
	EventScreens._footer(stage, Vector2(16, BOTTOM - 62), 1248, "返回", "交付" + (" ×%d" % orders.takes(slot, pick) if pick != null else ""), func():
		order_choosing = -1
		menu.pick = null
		outbound(menu), func():
		if pick != null: game.deliver_to_order(slot, pick)
		menu.pick = null
		outbound(menu), pick != null)

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

const PAUSE_ITEMS := ["继续作业", "设置", "按键设置", "放弃合同", "保存并退出", "回到标题"]
const SETTING_TABS := ["画面", "界面", "音频", "基地", "拾取过滤"]

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
		if i == 4 and not (game.can_save_run() and is_instance_valid(game.system_screens)): continue
		if i == 5 and not is_instance_valid(game.system_screens): continue
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
			game.save_and_quit()
		5:
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
		0: rows = [["窗口模式", ["窗口", "全屏"], "fullscreen"], ["垂直同步", ["关", "开"], "vsync"], ["gpu"], ["震屏强度", [], "shake_strength", 0.0, 1.0], ["Boss 亮相", ["跳过", "播放"], "boss_intro"]]
		1: rows = [["界面动效", ["精简", "完整"], "ui_motion"], ["交易确认", ["关", "开"], "trade_confirm"], ["伤害数字", ["关", "开"], "damage_numbers"], ["订单追踪", ["隐藏", "显示"], "tracker"], ["PRTS 提示", ["隐藏", "显示"], "broadcasts"], ["新手引导", ["关", "开"], "tutorial"], ["主线引导", ["关", "开"], "story_guide"], ["language"],
			["自动喝药下限", [], "auto_potion_low", 0.05, 0.95], ["自动喝药上限", [], "auto_potion_high", 0.05, 0.95],
			["撤离失败自动治疗", ["关", "开"], "auto_treat"]]
		2: rows = [["主音量", [], "master_volume"]]
		3:
			_base_settings(menu, stage)
			return
		4:
			_loot_settings(menu, stage)
			return
	var y := 104.0
	for row in rows:
		if row[0] == "language":
			AK.put(stage, SystemScreens.language_toggle(func(): pause(menu)), Vector2(334, y + 6), Vector2(886, 38))
			stage.add_child(AK.rect(AK.LINE, Vector2(334, y + 49), Vector2(886, 1)))
			y += 50
			continue
		if row[0] == "gpu":
			AK.put(stage, SystemScreens.gpu_toggle(func(): pause(menu)), Vector2(334, y + 6), Vector2(886, 56))
			stage.add_child(AK.rect(AK.LINE, Vector2(334, y + 67), Vector2(886, 1)))
			y += 68
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

## 拾取过滤 (用户 2026-11-02): which equipment shows a name plate on the ground —
## by rarity, by how many prefixes, by the lowest grade of its prefixes.
static func _loot_settings(menu: FieldMenu, stage: Control) -> void:
	var s := SystemScreens.settings
	var y := 104.0
	for row in [["装备品质", GameManager.LOOT_RARITY_NAMES, "loot_rarity"], ["前缀数量", GameManager.LOOT_PREFIX_NAMES, "loot_prefixes"],
			["前缀品质", GameManager.LOOT_GRADE_NAMES, "loot_prefix_grade"]]:
		AK.put(stage, AK.label(row[0], 14, AK.FG), Vector2(334, y + 12))
		var key: String = row[2]
		var names: Array = row[1]
		var toggle := AK.toggle(names, clampi(int(s.get(key, 0)), 0, names.size() - 1), func(i): SystemScreens.set_setting(key, i); pause(menu), 13)
		AK.put(stage, toggle, Vector2(520, y + 6))
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
const KEY_COLUMNS := 3
const KEY_PITCH := 302.0
const KEY_NAME_W := 110.0
const KEY_BUTTON_W := 92.0

static func _hotbar_page(menu: FieldMenu, stage: Control) -> void:
	_panel(stage)
	var reset := AK.button("恢复默认", "plain", 12)
	reset.pressed.connect(func(): Keybinds.reset(); menu.hotbar_capture = -1; pause(menu))
	AK.put(stage, reset, Vector2(1110, 530), Vector2(120, 28))
	for col in range(KEY_COLUMNS):
		AK.put(stage, AK.label("主键", 11, AK.MUTE), Vector2(334 + col * KEY_PITCH + KEY_NAME_W, 54))
		AK.put(stage, AK.label("副键", 11, AK.MUTE), Vector2(334 + col * KEY_PITCH + KEY_NAME_W + KEY_BUTTON_W + 4, 54))
	var binds := Keybinds.all()
	# 用户 2026-11-06: the base's station keys get a column of their own.
	var columns := {"快捷栏": 0, "专用键": 0, "视角": 0, "界面": 1, "基地站点": 2}
	var y := [76.0, 76.0, 76.0]
	var last_group := ["", "", ""]
	for f in Keybinds.FUNCTIONS:
		var col: int = columns[f[2]]
		var x := 334.0 + col * KEY_PITCH
		if f[2] != last_group[col]:
			last_group[col] = f[2]
			AK.put(stage, AK.label(f[2], 13, AK.SP), Vector2(x, y[col] + 4))
			y[col] += KEY_ROW
		var name := AK.label(f[1], 12, AK.FG)
		name.clip_text = true
		AK.put(stage, name, Vector2(x, y[col] + 5), Vector2(KEY_NAME_W - 6, 18))
		var index := Keybinds.FUNCTIONS.find(f)
		for which in range(2):
			var flat := index * 2 + which
			var waiting := menu.hotbar_capture == flat
			var text := "按下按键…" if waiting else Keybinds.label(binds[f[0]][which])
			var b := AK.button(text if not text.is_empty() else "—", "paper" if waiting else "plain", 12)
			b.set_meta("binding", flat)
			b.pressed.connect(func(): menu.hotbar_capture = flat; pause(menu))
			AK.put(stage, b, Vector2(x + KEY_NAME_W + which * (KEY_BUTTON_W + 4), y[col]), Vector2(KEY_BUTTON_W, KEY_ROW - 4))
		y[col] += KEY_ROW
	var fx := 334.0 + KEY_PITCH
	var fy: float = y[1] + 6
	AK.put(stage, AK.label("固定", 13, AK.SP), Vector2(fx, fy + 4))
	fy += KEY_ROW
	for row in Keybinds.FIXED:
		AK.put(stage, AK.label(row[0], 12, AK.MUTE), Vector2(fx, fy + 4))
		var keys := AK.label(row[1], 12, AK.FG, AK.en())
		keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		AK.put(stage, keys, Vector2(fx + 140, fy + 4), Vector2(KEY_PITCH - 146, 20))
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
	## The warehouse's free layout: a drop lands `item` at the cell under the
	## pointer (move_to(item, cell)); 旋转物品 over a tile calls on_rotate(item).
	var move_to: Callable
	var on_rotate: Callable
	## A double click on a 整理箱 opens it (整理箱与收藏品策划案 v0.2 §0-9).
	var on_open: Callable
	## Pixels a cell (CELL unless the caller passes another size).
	var cell := CELL
	var _hovered: Item

	func cell_at(point: Vector2) -> Vector2i:
		return Vector2i(floori(point.x / cell), floori(point.y / cell))

	func _unhandled_key_input(event: InputEvent) -> void:
		if on_rotate.is_valid() and _hovered != null and is_visible_in_tree() and event.is_action_pressed("rotate_item"):
			get_viewport().set_input_as_handled()
			on_rotate.call(_hovered)

	## Drag forwarding for the free layout: `offset` is the control's place on the grid.
	func _wire_free(control: Control, item: Item, offset: Vector2) -> void:
		var drag := (func(_at: Vector2) -> Variant: return ItemDrag.start(control, item)) if item != null else Callable()
		var can := func(_at: Vector2, data: Variant) -> bool:
			var it := ItemDrag.item_of(data)
			return it != null and (items.has(it) or (accept.is_valid() and bool(accept.call(it))))
		var drop := func(at: Vector2, data: Variant) -> void: move_to.call(ItemDrag.item_of(data), cell_at(offset + at))
		control.set_drag_forwarding(drag, can, drop)
		control.set_meta("drop_can", can)
		control.set_meta("drop_take", drop)

	static func make(shown: Array, w: int, h: int, pick: Callable, hover: Callable, size: int = CELL) -> FlowGrid:
		var grid := FlowGrid.new()
		grid.items = shown
		grid.columns = w
		grid.rows = h
		grid.on_pick = pick
		grid.on_hover = hover
		grid.cell = size
		grid.custom_minimum_size = Vector2(w, h) * size
		grid.size = grid.custom_minimum_size
		return grid

	## The packed grid: `w` wide, at least `min_rows` tall, every item placed.
	static func packed(shown: Array, w: int, min_rows: int, pick: Callable) -> FlowGrid:
		var taken := {}
		var places := {}
		var rows := min_rows
		# Rows above `full` are taken end to end: no item's top row can be
		# there, nor can one reach down across them, so the search starts below.
		var filled := {}
		var full := 0
		for item: Item in shown:
			var at := Vector2i(-1, -1)
			var y := full
			while at.x < 0:
				for x in range(w - item.width + 1):
					var free := true
					for dy in range(item.height):
						for dx in range(item.width):
							if taken.has(Vector2i(x + dx, y + dy)):
								free = false
								break
						if not free: break
					if free:
						at = Vector2i(x, y)
						break
				y += 1
			for dy in range(item.height):
				for dx in range(item.width): taken[at + Vector2i(dx, dy)] = true
				filled[at.y + dy] = int(filled.get(at.y + dy, 0)) + item.width
			while int(filled.get(full, 0)) >= w: full += 1
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
		if move_to.is_valid(): _wire_free(self, null, Vector2.ZERO)
		elif accept.is_valid(): ItemDrag.wire(self, null, accept, take)
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
			tile.position = Vector2(x, y) * cell
			tile.size = Vector2(item.width, item.height) * cell - Vector2.ONE
			tile.set_meta("item", item)
			tile.add_child(AK.item_icon(item, tile.size))
			var shown := item
			tile.pressed.connect(func(): on_pick.call(shown))
			tile.mouse_entered.connect(func():
				_hovered = shown
				on_hover.call(shown))
			tile.mouse_exited.connect(func(): if _hovered == shown: _hovered = null)
			if on_alt.is_valid() or (on_open.is_valid() and item.is_case()):
				tile.gui_input.connect(func(e: InputEvent):
					if not e is InputEventMouseButton or not e.pressed: return
					if e.button_index == MOUSE_BUTTON_RIGHT and on_alt.is_valid(): on_alt.call(shown)
					elif e.button_index == MOUSE_BUTTON_LEFT and e.double_click and shown.is_case() and on_open.is_valid(): on_open.call(shown))
			if move_to.is_valid(): _wire_free(tile, shown, tile.position)
			elif drag or accept.is_valid(): ItemDrag.wire(tile, shown if drag else null, accept, take)
			add_child(tile)
			x += item.width
			row_h = maxi(row_h, item.height)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(columns, rows) * cell), Color(0, 0, 0, 0.55))
		for gx in range(columns + 1): draw_line(Vector2(gx * cell, 0), Vector2(gx * cell, rows * cell), Color(1, 1, 1, 0.07))
		for gy in range(rows + 1): draw_line(Vector2(0, gy * cell), Vector2(columns * cell, gy * cell), Color(1, 1, 1, 0.07))
