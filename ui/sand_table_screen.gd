class_name SandTableScreen
extends RefCounted

## The bridge's sand table (沙盘航行策划案_v1_0.md §6): the ship and its
## voyages, the medical stay at the anchor, and the bulk orders. Data, state
## and buttons only (用户: 界面不写说明文字).

const TOP := BaseScreens.TOP
const BOTTOM := BaseScreens.BOTTOM
const BUDGET_STEP := 10000
const TARGET_STEP := 50

static var destination := ""
static var use_fuel := false

static func build(menu: FieldMenu) -> void:
	var game := menu.game
	var stage := BaseScreens.shell(menu, "沙盘", "SAND TABLE · RHODES ISLAND", [], 0, Callable(), "TERRA",
		[["lmd", Economy.format(game.gold)], ["gold", "%.2f" % game.exchange.gold_account]])
	_ship_panel(menu, stage)
	_stay_panel(menu, stage)
	_orders_panel(menu, stage)

# --- 罗德岛号 ------------------------------------------------------------------------------

static func _ship_panel(menu: FieldMenu, stage: Control) -> void:
	var game := menu.game
	var v := game.voyage
	stage.add_child(AK.rect(AK.PLATE_2, Vector2(16, TOP), Vector2(624, 262)))
	AK.put(stage, AK.section("罗德岛号", "LANDSHIP"), Vector2(28, TOP + 8))
	var status := MarketWidgets.live(func():
		if v.is_sailing():
			return "航行 · %s → %s · %s · %s" % [v.sailing.from, v.sailing.to, VoyageCatalog.MODE_NAMES[v.sailing.mode], ExchangeScreen._left(int(v.sailing.due) - BaseState.now())]
		return "停泊 · %s" % v.place(), 15)
	AK.put(stage, status, Vector2(28, TOP + 40))
	if destination.is_empty() or destination == v.place() or not destination in VoyageCatalog.ANCHORS:
		destination = VoyageCatalog.ANCHORS[1] if v.place() == VoyageCatalog.ANCHORS[0] else VoyageCatalog.ANCHORS[0]
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	for place in VoyageCatalog.ANCHORS:
		var here: bool = place == v.place()
		var b := AK.button(place, "paper" if place == destination else "plain", 13)
		b.custom_minimum_size = Vector2(148, 28)
		b.disabled = here
		if here: b.text = "%s ·" % place
		var p: String = place
		b.pressed.connect(func(): destination = p; build(menu))
		grid.add_child(b)
	AK.put(stage, grid, Vector2(28, TOP + 70))
	# 喀兰贸易's 高能燃料 (势力特供策划案 §二), when there is one in the warehouse.
	var fuels := game.material_count(GameManager.SPECIAL_FUEL)
	if fuels <= 0: use_fuel = false
	else:
		var toggle := AK.button("高能燃料 ×%d" % fuels, "paper" if use_fuel else "plain", 12)
		toggle.pressed.connect(func(): use_fuel = not use_fuel; build(menu))
		AK.put(stage, toggle, Vector2(480, TOP + 40), Vector2(148, 26))
	for i in range(VoyageCatalog.MODES.size()):
		var mode: String = VoyageCatalog.MODES[i]
		var y := TOP + 140 + i * 38
		var cost := v.voyage_cost(destination, mode, use_fuel)
		var hours := v.voyage_seconds(destination, mode, use_fuel) / 3600.0
		AK.put(stage, AK.label(VoyageCatalog.MODE_NAMES[mode], 13, AK.MUTE), Vector2(28, y + 4))
		AK.put(stage, AK.money("lmd", Economy.format(cost), 15), Vector2(120, y))
		AK.put(stage, AK.label("%.1f h" % hours, 13, AK.FG, AK.en()), Vector2(300, y + 4))
		var refusal := v.voyage_refusal(destination, mode, use_fuel)
		var go := AK.button("出发" if refusal.is_empty() else refusal, "blue" if refusal.is_empty() else "plain", 13)
		go.disabled = not refusal.is_empty()
		var m := mode
		go.pressed.connect(func():
			if game.sail(destination, m, use_fuel):
				use_fuel = false
				build(menu))
		AK.put(stage, go, Vector2(480, y), Vector2(148, 30))

# --- 医疗驻留 ------------------------------------------------------------------------------

static func _stay_panel(menu: FieldMenu, stage: Control) -> void:
	var game := menu.game
	var v := game.voyage
	var top := TOP + 270
	stage.add_child(AK.rect(AK.PLATE_2, Vector2(16, top), Vector2(624, BOTTOM - top)))
	AK.put(stage, AK.section("医疗驻留", "MEDICAL STAY"), Vector2(28, top + 8))
	if v.is_sailing():
		AK.put(stage, AK.label("航行中", 15, AK.MUTE), Vector2(28, top + 44))
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for kind in VoyageCatalog.STAY_KINDS:
		var on := bool(v.stay[kind])
		var b := AK.button("%s %s · %s/时" % [VoyageCatalog.STAY_NAMES[kind], "开" if on else "关", Economy.format(int(VoyageCatalog.STAY_COST[kind]))], "paper" if on else "plain", 13)
		b.custom_minimum_size = Vector2(180, 30)
		var k: String = kind
		b.pressed.connect(func():
			if game.set_stay(k, not on): build(menu))
		row.add_child(b)
	var supplies := AK.button("医疗物资抵扣 %s" % ("开" if bool(v.stay.supplies) else "关"), "paper" if bool(v.stay.supplies) else "plain", 13)
	supplies.custom_minimum_size = Vector2(160, 30)
	supplies.pressed.connect(func(): v.set_supplies(not bool(v.stay.supplies)); game.save_base(); build(menu))
	row.add_child(supplies)
	AK.put(stage, row, Vector2(28, top + 40))
	var cost := v.hour_cost()
	var plan: Array = v.supply_plan(cost) if bool(v.stay.supplies) else [[], 0]
	AK.put(stage, AK.label("每小时 %s · 物资 −%s · 本次 %s" % [Economy.format(cost - int(plan[1])), Economy.format(int(plan[1])), Economy.format(int(v.stay.spent))], 13, AK.FG), Vector2(28, top + 80))
	# Stop conditions.
	var budget := int(v.stay.budget)
	ExchangeScreen._number(stage, "总花费", budget, 0, BUDGET_STEP, 0,
		func(value): v.set_budget(int(value)); game.save_base(); build(menu))
	(stage.get_child(stage.get_child_count() - 1) as Control).position = Vector2(28, top + 108)
	var locals := v.local_factions()
	if not locals.is_empty():
		var names: Array = ["—"]
		names.append_array(locals.map(func(f): return FactionCatalog.name_of(f)))
		var current := locals.find(str(v.stay.target_faction)) + 1
		AK.put(stage, ExchangeScreen._seg(names, current, func(i):
			v.set_target("" if i == 0 else locals[i - 1], maxi(int(v.stay.target), game.exchange.relation(locals[i - 1]) + TARGET_STEP) if i > 0 else 0)
			game.save_base()
			build(menu), 12, 300.0), Vector2(28, top + 142))
		if not str(v.stay.target_faction).is_empty():
			var target := int(v.stay.target)
			ExchangeScreen._number(stage, "目标关系", target, 0, TARGET_STEP, 0,
				func(value): v.set_target(str(v.stay.target_faction), int(value)); game.save_base(); build(menu))
			(stage.get_child(stage.get_child_count() - 1) as Control).position = Vector2(340, top + 142)
	# The factions here: rank, relation towards the next rank, gain an hour.
	var y := top + 182
	for f in locals:
		var rel := game.exchange.relation(f)
		var rate := v.stay_rate(f) if v.stay_on() else 0.0
		var drift := game.exchange.relation_drift(f)
		AK.put(stage, AK.label("%s  R%d · %d / %d   %s/时%s" % [FactionCatalog.name_of(f), game.exchange.rank(f), rel, Exchange.next_rank_at(rel),
			("+" if rate >= 0.0 else "") + ("%.2f" % rate).trim_suffix("0").trim_suffix(".0"), ("   修正 −%d/日" % drift) if drift > 0 else ""], 13, AK.RED if rate < 0.0 else AK.FG), Vector2(28, y))
		y += 24
	var region := VoyageCatalog.region_at(v.place())
	if region == "mine" and v.mine_threat > 0.0:
		AK.put(stage, AK.label("切尔诺伯格 威胁起点 +%d%%" % roundi(v.mine_threat * 100), 13, AK.RED), Vector2(28, y))
	elif region == "siracusa" and v.siracusa_debt < 1.0:
		AK.put(stage, AK.label("叙拉古 血债 ×%.2f" % v.siracusa_debt, 13, AK.GREEN), Vector2(28, y))

# --- 大宗订单 ------------------------------------------------------------------------------

static func _orders_panel(menu: FieldMenu, stage: Control) -> void:
	var game := menu.game
	var v := game.voyage
	stage.add_child(AK.rect(AK.PLATE_2, Vector2(656, TOP), Vector2(608, BOTTOM - TOP)))
	AK.put(stage, AK.section("大宗订单", "BULK ORDERS"), Vector2(668, TOP + 8))
	var y := TOP + 44
	for o in v.orders:
		var block := 134.0
		stage.add_child(AK.rect(Color(0, 0, 0, 0.35), Vector2(668, y), Vector2(584, block - 8)))
		var faction := str(o.faction)
		AK.put(stage, AK.label("%s · %s" % [FactionCatalog.name_of(faction), VoyageCatalog.home_of(faction)], 15, AK.FG), Vector2(680, y + 6))
		var id := int(o.id)
		var left := MarketWidgets.live(func():
			var order := v.order(id)
			if order.is_empty(): return ""
			if str(order.state) == "handover": return "交接 %s" % ExchangeScreen._left(int(order.due) - BaseState.now())
			if str(order.state) == "delivered": return "已交接"
			return ExchangeScreen._left(int(order.expires) - BaseState.now()), 12, AK.MUTE)
		AK.put(stage, left, Vector2(1120, y + 8))
		var goods: Array = []
		for m in o.lines: goods.append("%s ×%d (%d)" % [m, int(o.lines[m]), game.material_count(m)])
		AK.put(stage, AK.label("  ".join(goods), 13, AK.FG), Vector2(680, y + 32))
		AK.put(stage, AK.label("%s   关系 +%d" % [Exchange.format_money(str(o.currency), float(o.pay)), int(o.relation)], 13, AK.SP), Vector2(680, y + 56))
		var state := str(o.state)
		if state == "packed":
			var floors: Array = []
			for region in o.floors: floors.append(AK.floor_code(region, int(o.floors[region])))
			AK.put(stage, AK.label("运送 · " + "  ".join(floors), 13, AK.BLUE), Vector2(680, y + 80))
		if state in ["open", "packed"]:
			var submit_why := _short(v.submit_refusal(id))
			var submit := AK.button("提交" if submit_why.is_empty() else submit_why, "blue" if submit_why.is_empty() else "plain", 12)
			submit.disabled = not submit_why.is_empty()
			submit.pressed.connect(func():
				if game.submit_bulk(id): build(menu))
			AK.put(stage, submit, Vector2(1000, y + 92), Vector2(120, 28))
			if state == "open":
				var pack_why := _short(v.pack_refusal(id))
				var pack := AK.button("装箱" if pack_why.is_empty() else pack_why, "paper" if pack_why.is_empty() else "plain", 12)
				pack.disabled = not pack_why.is_empty()
				pack.pressed.connect(func():
					if game.pack_bulk(id): build(menu))
				AK.put(stage, pack, Vector2(1126, y + 92), Vector2(120, 28))
		y += block

## A refusal short enough for its button: the goods line already shows what is missing.
static func _short(why: String) -> String:
	return "缺货" if why.begins_with("缺少") else why
