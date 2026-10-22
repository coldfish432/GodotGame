class_name ProvisionScreens
extends RefCounted

## The second deck's terminals (势力特供策划案_v0_2 §三–§六): 农业部's basins
## laid out as the swirl they stand in, 食堂's kitchen, the meal before a
## contract and 企鹅物流's cold chain, and the lift between the decks.
## Data, state and buttons only (用户: 界面不写说明文字).

const TOP := BaseScreens.TOP
const BOTTOM := BaseScreens.BOTTOM
const FARM_ACCENT := Color("8fc31f")
const CANTEEN_ACCENT := Color("e0a040")
## The swirl's tile on screen.
const TILE := 22.0
## Where each swirl's lamp is drawn, as the rooms stand (BaseMap.FARM_CENTRES).
const SWIRL_CENTRES := [Vector2(150, TOP + 136), Vector2(410, TOP + 136), Vector2(336, TOP + 430)]
const CROP_COLOURS := {"舰载麦": Color("d8c060"), "块茎薯": Color("b08850"), "温室豆": Color("7fbf5a"),
	"闪耀作物": Color("8ff0ff"), "闪耀作物·变种": Color("d9a6ff")}

static var basin := 0
static var crop := "舰载麦"
static var canteen_tab := 0
static var meal_pick := "舰内口粮"
static var cook_count := 1

# --- 农业部 ------------------------------------------------------------------------------

static func farm(menu: FieldMenu) -> void:
	var game := menu.game
	var p := game.provisions
	BaseScreens.accent_override = FARM_ACCENT
	var stage := BaseScreens.shell(menu, "农业部", "AGRICULTURE · HYDROPONICS", [], 0, Callable(), "FARM", [["lmd", Economy.format(game.gold)]])
	BaseScreens.accent_override = Color(0, 0, 0, 0)
	var basins := p.basins()
	# The three sun-lamp rooms as they stand on the deck: two side by side, the third below them, east.
	for k in range(Provisions.SWIRLS):
		var c: Vector2 = SWIRL_CENTRES[k]
		stage.add_child(AK.rect(Color(0, 0, 0, 0.35), c - Vector2(5.5, 5.5) * TILE, Vector2(11, 11) * TILE))
		var lamp := Panel.new()
		lamp.add_theme_stylebox_override("panel", AK.box(Color("fff1b0") if k * Provisions.SWIRL_BASINS < basins else AK.PLATE_3, Color("ffd060"), 2))
		lamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		AK.put(stage, lamp, c - Vector2(0.6, 0.6) * TILE, Vector2(1.2, 1.2) * TILE)
	for i in range(Provisions.BASINS):
		var r := Provisions.basin_rect(i)
		# Tiles to screen: x right, z up.
		var centre: Vector2 = SWIRL_CENTRES[Provisions.swirl_of(i)]
		var at := centre + Vector2(r.position.x, -(r.position.y + r.size.y)) * TILE + Vector2(2, 2)
		var size := r.size * TILE - Vector2(4, 4)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		var built := i < basins
		var plot := p.plot(i) if built else {}
		var fill := AK.PLATE_2 if built else Color(0.1, 0.1, 0.1, 0.5)
		if not plot.is_empty():
			var c: Color = CROP_COLOURS.get(str(plot.crop), AK.GREEN)
			fill = c.darkened(0.65).lerp(c.darkened(0.15), p.growth(i))
		for st in ["normal", "hover", "pressed", "disabled"]:
			var style := AK.box(fill.lightened(0.08) if st == "hover" else fill, AK.SP if i == basin else (AK.GREEN if p.ripe(i) else AK.LINE), 2 if i == basin or p.ripe(i) else 1)
			b.add_theme_stylebox_override(st, style)
		b.disabled = not built
		var index := i
		b.pressed.connect(func(): basin = index; farm(menu))
		AK.put(stage, b, at, size)
	# The selected basin and what to sow.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	AK.put(stage, right, Vector2(700, TOP + 16), Vector2(560, 0))
	right.add_child(AK.section("水培槽 %d / %d" % [basins, Provisions.BASINS], "BASINS"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var harvest_all := AK.button("全部收获 · %d" % p.ripe_count(), "green" if p.ripe_count() > 0 else "plain", 13)
	harvest_all.disabled = p.ripe_count() <= 0
	harvest_all.pressed.connect(func(): p.harvest_all(); farm(menu))
	row.add_child(harvest_all)
	var sow_all := AK.button("全部播种 · %s" % crop, "blue", 13)
	sow_all.pressed.connect(func(): p.sow_all(crop); farm(menu))
	row.add_child(sow_all)
	right.add_child(row)
	if basin >= basins: basin = 0
	if basins <= 0:
		right.add_child(AK.label("需要农业部 Lv1", 14, AK.MUTE))
		return
	right.add_child(AK.section("第 %d 槽" % (basin + 1), "BASIN %02d" % (basin + 1)))
	var plot := p.plot(basin)
	if plot.is_empty():
		right.add_child(AK.label("空", 15, AK.MUTE))
	else:
		var grown := MarketWidgets.live(func():
			if p.ripe(basin): return "%s · 可收获" % str(p.plot(basin).get("crop", ""))
			return "%s · %d%% · %s" % [str(p.plot(basin).get("crop", "")), roundi(p.growth(basin) * 100), ExchangeScreen._left(p.seconds_left(basin))], 16)
		right.add_child(grown)
		var take := AK.button("收获", "green" if p.ripe(basin) else "plain", 14)
		take.disabled = not p.ripe(basin)
		take.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		take.pressed.connect(func(): p.harvest(basin); farm(menu))
		right.add_child(take)
	right.add_child(AK.section("作物", "CROPS"))
	for id in Provisions.CROP_ORDER:
		var c: Dictionary = Provisions.CROPS[id]
		var seed := ("%s ×%d" % [str(c.seed), game.material_count(str(c.seed))]) if c.has("seed") else ("%s 龙门币" % Economy.format(int(c.seed_lmd)))
		var b := AK.button("%s   ·   %d h   ·   ×%d   ·   %s" % [id, int(c.hours), int(c.yield), seed], "paper" if id == crop else "plain", 12)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(540, 32)
		var chosen: String = id
		b.pressed.connect(func(): crop = chosen; farm(menu))
		right.add_child(b)
	var refusal := p.sow_refusal(basin, crop)
	var sow := AK.button("播种" if refusal.is_empty() else refusal, "blue" if refusal.is_empty() else "plain", 15)
	sow.disabled = not refusal.is_empty()
	sow.custom_minimum_size = Vector2(300, 44)
	sow.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	sow.pressed.connect(func(): p.sow(basin, crop); farm(menu))
	right.add_child(sow)

# --- 食堂 -------------------------------------------------------------------------------

const CANTEEN_TABS := ["厨房", "用餐", "冷链"]

static func canteen(menu: FieldMenu) -> void:
	var game := menu.game
	var p := game.provisions
	BaseScreens.accent_override = CANTEEN_ACCENT
	var stage := BaseScreens.shell(menu, "食堂", "CANTEEN · GALLEY", CANTEEN_TABS, canteen_tab, func(i): canteen_tab = i; canteen(menu), "GALLEY",
		[["lmd", Economy.format(game.gold)]])
	BaseScreens.accent_override = Color(0, 0, 0, 0)
	if game.base.facility_level("canteen") <= 0:
		AK.put(stage, AK.label("需要食堂 Lv1", 16, AK.MUTE), Vector2(32, TOP + 24))
		return
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	AK.put(stage, list, Vector2(16, TOP + 16), Vector2(640, 0))
	for id in Provisions.MEAL_ORDER:
		var line := "%s   ·   %s ×%d" % [id, "库存", game.material_count(id)]
		if canteen_tab == 0:
			var parts: Array[String] = []
			for mat in Provisions.RECIPES[id]["in"]: parts.append("%s×%d（%d）" % [mat, int(Provisions.RECIPES[id]["in"][mat]), game.material_count(mat)])
			line = "%s   ←   %s" % [id, "  ".join(parts)]
		var b := AK.button(line, "paper" if id == meal_pick else "plain", 12)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(640, 40)
		var chosen: String = id
		b.pressed.connect(func(): meal_pick = chosen; canteen(menu))
		list.add_child(b)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	AK.put(stage, right, Vector2(690, TOP + 16), Vector2(570, 0))
	var icon_row := HBoxContainer.new()
	icon_row.add_theme_constant_override("separation", 14)
	var icon := AK.item_icon(MaterialCatalog.create(meal_pick, 1), Vector2(72, 72))
	icon.custom_minimum_size = Vector2(72, 72)
	icon_row.add_child(icon)
	var words := VBoxContainer.new()
	words.add_child(AK.label(meal_pick, 20, AK.FG))
	words.add_child(AK.label(Provisions.meal_text(meal_pick), 13, AK.GREEN))
	if not Provisions.squad_text(meal_pick).is_empty(): words.add_child(AK.label(Provisions.squad_text(meal_pick), 12, AK.CYAN))
	icon_row.add_child(words)
	right.add_child(icon_row)
	match canteen_tab:
		0:
			var r: Dictionary = Provisions.RECIPES[meal_pick]
			ExchangeScreen._number(right, "数量", cook_count, 0, 1, 1, func(v): cook_count = maxi(1, int(v)); canteen(menu))
			right.add_child(AK.label("%d 分" % (int(r.minutes) * cook_count), 13, AK.MUTE))
			_go(right, "开始烹饪", p.cook_refusal(meal_pick, cook_count), func(): p.cook(meal_pick, cook_count); canteen(menu))
			right.add_child(AK.section("队列", "QUEUE  %d / %d" % [p.jobs().size(), p.kitchen_slots()]))
			for j in p.jobs():
				var job: Dictionary = j
				right.add_child(MarketWidgets.live(func(): return "%s ×%d  ·  %s" % [job.output, int(job.count), ExchangeScreen._left(int(job.due) - BaseState.now())], 13))
		1:
			right.add_child(AK.section("本次出发", "NEXT CONTRACT"))
			right.add_child(AK.label(p.meal() if not p.meal().is_empty() else "无", 16, AK.FG if not p.meal().is_empty() else AK.MUTE))
			_go(right, "用餐", p.eat_refusal(meal_pick), func(): p.eat(meal_pick); canteen(menu))
		2:
			right.add_child(AK.section("寄给罗德岛小队", "COLD CHAIN  R%d" % game.exchange.rank("penguin")))
			right.add_child(AK.label(p.mailed() if not p.mailed().is_empty() else "无", 16, AK.FG if not p.mailed().is_empty() else AK.MUTE))
			right.add_child(AK.money("lmd", Economy.format(Provisions.MAIL_LMD), 15))
			_go(right, "寄出", p.mail_refusal(meal_pick), func(): p.mail(meal_pick); canteen(menu))

static func _go(parent: Control, text: String, refusal: String, on_press: Callable) -> void:
	var b := AK.button(text if refusal.is_empty() else refusal, "blue" if refusal.is_empty() else "plain", 15)
	b.disabled = not refusal.is_empty()
	b.custom_minimum_size = Vector2(300, 44)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(on_press)
	parent.add_child(b)

# --- 升降梯 ------------------------------------------------------------------------------

static func lift(menu: FieldMenu) -> void:
	var game := menu.game
	var stage := menu.stage_begin(0.75)
	stage.add_child(AK.rect(Color(0, 0, 0, 0.55), Vector2.ZERO, Vector2(1280, 720)))
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", Terminal.panel_style("plate"))
	AK.put(stage, panel, Vector2(440, 200), Vector2(400, 320))
	AK.put(panel, AK.label("LIFT", 10, AK.MUTE, AK.en()), Vector2(28, 20))
	AK.put(panel, AK.label("升降梯", 24, AK.FG), Vector2(28, 34))
	var decks := [[1, "一层", "舰桥大厅"], [2, "二层", "农业部 · 食堂"]]
	for i in range(decks.size()):
		var entry: Array = decks[i]
		var here: bool = game.deck == int(entry[0])
		var b := AK.go_button(str(entry[1]), str(entry[2]), "plain" if here else "blue", 22)
		b.disabled = here
		var to: int = entry[0]
		b.pressed.connect(func(): game.ride_lift(to))
		AK.put(panel, b, Vector2(28, 86 + i * 96), Vector2(344, 80))
	var close := AK.button("✕", "ghost", 16)
	AK.put(panel, close, Vector2(348, 12), Vector2(40, 40))
	close.pressed.connect(game.close_modal)
