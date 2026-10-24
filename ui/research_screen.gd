class_name ResearchScreen
extends RefCounted

## 科研部's terminal (龙门币平衡与科研部策划案_v1_1.md §5.9; the tree,
## 科研树状化策划案_v1_0.md §7): the research tree, the projects and the
## endless lines. Data, state and
## buttons only (用户: 界面不写说明文字), no rating of any kind.

const TOP := BaseScreens.TOP
const BOTTOM := BaseScreens.BOTTOM
const TABS := ["研究", "课题", "基础研究"]

static var tab := 0
static var pick := "logistics_1"

static func build(menu: FieldMenu) -> void:
	var game := menu.game
	game.research.tick()
	var stage := BaseScreens.shell(menu, "科研部", "RESEARCH · RHODES ISLAND", TABS, tab, func(i): tab = i; build(menu), "RESEARCH",
		[["lmd", Economy.format(game.gold)]])
	match tab:
		0: _trees(menu, stage)
		1: _projects(menu, stage)
		2: _endless(menu, stage)

# --- Tree ---------------------------------------------------------------------------------------

## The map of the tree (ResearchTreeView; 用户 2026-10-22: 左键拖动，滚轮缩放),
## the picked node's card on the right. The view's pan and zoom are kept
## across rebuilds.
const PANEL_W := 380.0
static var view_offset := Vector2(INF, INF)
static var view_zoom := 0.75

static func _trees(menu: FieldMenu, stage: Control) -> void:
	var game := menu.game
	if not ResearchCatalog.valid(pick): pick = "logistics_1"
	var view := ResearchTreeView.new()
	view.game = game
	view.pick = pick
	view.zoom = view_zoom
	view.on_pick = func(id: String): pick = id; build(menu)
	view.on_view = func(at: Vector2, z: float): view_offset = at; view_zoom = z
	var area := Vector2(1264 - PANEL_W - 28, BOTTOM - TOP - 14)
	AK.put(stage, view, Vector2(16, TOP + 6), area)
	view.size = area
	if view_offset.x == INF: view.centre_on(pick)
	else: view.offset = view_offset
	var reset := AK.button("复位", "plain", 12)
	reset.custom_minimum_size = Vector2(64, 28)
	reset.pressed.connect(func():
		view_zoom = 0.75
		view.zoom = 0.75
		view.centre_on(pick)
		view_offset = view.offset
		view.queue_redraw())
	AK.put(stage, reset, Vector2(26, TOP + 6 + area.y - 38))
	_detail(menu, stage)

static func _detail(menu: FieldMenu, stage: Control) -> void:
	var game := menu.game
	var r := game.research
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	var x := 1264 - PANEL_W
	AK.put(stage, right, Vector2(x, TOP + 10), Vector2(PANEL_W, 0))
	right.add_child(AK.section("研究位", "SLOTS  %d / %d" % [r.active().size(), r.slots()]))
	for e in r.active():
		var running: String = str(e.id)
		right.add_child(MarketWidgets.live(func(): return "%s · %s   %s" % [ResearchCatalog.name_of(running), ResearchCatalog.effect_text(running), _clock(r.seconds_left(running))], 13))
		# 卡西米尔's 骑士工坊专利授权 (势力特供策划案 §二): the rest of the time halved.
		if game.material_count(GameManager.SPECIAL_PATENT) > 0 and not e.get("patent", false):
			var patent := game.patent_refusal(running)
			var b := AK.button("专利授权" if patent.is_empty() else patent, "yellow" if patent.is_empty() else "plain", 11)
			b.disabled = not patent.is_empty()
			b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			b.pressed.connect(func(): game.use_patent(running); build(menu))
			right.add_child(b)
	right.add_child(AK.section(ResearchCatalog.name_of(pick), "%s · %s" % [ResearchCatalog.DEPARTMENT_NAMES[ResearchCatalog.department_of(pick)], ResearchCatalog.tier_label(ResearchCatalog.tier_of(pick))]))
	right.add_child(AK.label(ResearchCatalog.effect_text(pick), 18, AK.FG))
	var before := ResearchCatalog.prerequisite_nodes(pick)
	if not before.is_empty():
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 4)
		for p in before: flow.add_child(AK.tag(ResearchCatalog.name_of(p), ResearchCatalog.DEPARTMENT_COLORS[ResearchCatalog.department_of(p)] if r.is_done(p) else AK.RED))
		right.add_child(flow)
	if r.is_done(pick):
		right.add_child(AK.tag("已完成", AK.GREEN))
		return
	right.add_child(AK.label("%s 龙门币   ·   %d 小时" % [Economy.format(ResearchCatalog.price(pick)), ResearchCatalog.hours(pick)], 14, AK.FG if game.gold >= ResearchCatalog.price(pick) else AK.RED))
	var mats: Array[String] = []
	var cost := ResearchCatalog.materials(pick)
	for id in cost: mats.append("%s ×%d（%d）" % [id, int(cost[id]), game.material_count(id)])
	var mat_label := AK.label("  ".join(mats), 12, AK.FG if game.materials_refusal(cost).is_empty() else AK.RED)
	mat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(mat_label)
	var tags := HFlowContainer.new()
	tags.add_theme_constant_override("h_separation", 6)
	if ResearchCatalog.camp_needed(pick) > 0: tags.add_child(AK.tag("第 %d 层营地" % ResearchCatalog.camp_needed(pick), AK.PAPER if r.deepest_camp() >= ResearchCatalog.camp_needed(pick) else AK.RED))
	var unmet := r.requirement_refusal(pick)
	for need in ResearchCatalog.conditions(pick):
		var text := str(ResearchCatalog.REQUIREMENT_NAMES.get(need, need))
		tags.add_child(AK.tag(text, AK.RED if text == unmet else AK.PAPER))
	right.add_child(tags)
	if r.is_running(pick):
		right.add_child(MarketWidgets.live(func(): return _clock(r.seconds_left(pick)), 16, AK.SP))
		return
	var refusal := r.refusal(pick)
	if not refusal.is_empty(): right.add_child(AK.label(refusal, 12, AK.RED))
	var go := AK.button("开始研究", "blue" if refusal.is_empty() else "plain", 15)
	go.custom_minimum_size = Vector2(300, 44)
	go.disabled = not refusal.is_empty()
	go.pressed.connect(func(): r.start(pick); build(menu))
	right.add_child(go)

## "3:05:12".
static func _clock(seconds: int) -> String:
	return "%d:%02d:%02d" % [seconds / 3600, seconds / 60 % 60, seconds % 60]

# --- Projects ---------------------------------------------------------------------------------

static func _projects(menu: FieldMenu, stage: Control) -> void:
	var game := menu.game
	var r := game.research
	var tier := game.deepest_tier()
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	AK.put(stage, list, Vector2(16, TOP + 10), Vector2(1248, 0))
	list.add_child(AK.section("课题位", "PROJECTS  %d / %d   ·   %s" % [r.projects().size(), r.project_slots(), ResearchCatalog.tier_label(tier)]))
	for project in ResearchCatalog.PROJECTS:
		var info: Array = ResearchCatalog.PROJECTS[project]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(AK.tag(str(info[1]), AK.SP if r.projects().has(project) else AK.PAPER))
		var name := AK.label(str(info[0]), 14, AK.FG)
		name.custom_minimum_size.x = 140
		row.add_child(name)
		var effect := AK.label(str(info[2]), 13, AK.MUTE)
		effect.custom_minimum_size.x = 300
		row.add_child(effect)
		var price := AK.money("lmd", Economy.format(r.project_price(project, tier)), 14)
		price.custom_minimum_size.x = 140
		row.add_child(price)
		var left := AK.label("剩余 %d 次" % int(r.projects()[project]) if r.projects().has(project) else "", 13, AK.SP)
		left.custom_minimum_size.x = 100
		row.add_child(left)
		var chosen: String = project
		var b: Button
		if r.projects().has(project):
			b = AK.button("取消", "plain", 12)
			b.pressed.connect(func(): r.cancel(chosen); build(menu))
		else:
			var refusal := r.project_refusal(project)
			b = AK.button("签订 · %d 次" % ResearchCatalog.PROJECT_SORTIES if refusal.is_empty() else refusal, "blue" if refusal.is_empty() else "plain", 12)
			b.disabled = not refusal.is_empty()
			b.pressed.connect(func(): r.sign(chosen); build(menu))
		b.custom_minimum_size = Vector2(150, 34)
		row.add_child(b)
		list.add_child(row)

# --- Endless lines ----------------------------------------------------------------------------

static func _endless(menu: FieldMenu, stage: Control) -> void:
	var game := menu.game
	var r := game.research
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	AK.put(stage, list, Vector2(16, TOP + 10), Vector2(1248, 0))
	list.add_child(AK.section("基础研究", "ENDLESS"))
	for line in ResearchCatalog.ENDLESS:
		var info: Array = ResearchCatalog.ENDLESS[line]
		var level := r.endless_level(line)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var name := AK.label(str(info[0]), 15, AK.FG)
		name.custom_minimum_size.x = 180
		row.add_child(name)
		var lv := AK.label("%d / %d" % [level, ResearchCatalog.ENDLESS_CAP], 14, AK.SP)
		lv.custom_minimum_size.x = 90
		row.add_child(lv)
		var total := AK.label("%+.1f%%" % (r.endless_value(line) * 100.0), 14, AK.FG)
		total.custom_minimum_size.x = 110
		row.add_child(total)
		var price := AK.money("lmd", Economy.format(ResearchCatalog.endless_price(level)) if level < ResearchCatalog.ENDLESS_CAP else "—", 14)
		price.custom_minimum_size.x = 160
		row.add_child(price)
		var refusal := r.endless_refusal(line)
		var b := AK.button("研究" if refusal.is_empty() else refusal, "blue" if refusal.is_empty() else "plain", 12)
		b.custom_minimum_size = Vector2(150, 36)
		b.disabled = not refusal.is_empty()
		var chosen: String = line
		b.pressed.connect(func(): r.buy_endless(chosen); build(menu))
		row.add_child(b)
		list.add_child(row)
