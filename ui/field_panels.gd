class_name FieldPanels
extends Control

## The docked field windows (界面策划案 v1.1 #4–#6, §2.5): relics (R, 520 wide)
## and the contract journal (J, 500 wide) dock on the left like Grim Dawn's
## side panels, the battlefield and HUD visible beside them. The map (M) is an
## overlay the HUD draws itself (it owns the minimap cache); this only adds its
## close button. Data and state only, no rule text (用户 2026-10-05).

const WIDTHS := {"relics": 520, "journal": 500}
const MAP_CLOSE := Vector2(1216, 12)

var game: GameManager
var _dock: PanelContainer
var _body: VBoxContainer
var _title: Label
var _title_en: Label
var _tabs: HBoxContainer
var _key: Label
var _map_frame: Control
var kind := ""
var _tab := 0
var _relic_pick := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock = PanelContainer.new()
	_dock.position = Vector2.ZERO
	_dock.size = Vector2(520, 720)
	_dock.add_theme_stylebox_override("panel", AK.box(Color(0.063, 0.063, 0.063, 0.96)))
	add_child(_dock)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	_dock.add_child(outer)
	var bar := PanelContainer.new()
	var bar_style := AK.box(Color("0c0c0c"))
	bar_style.content_margin_top = 6
	bar_style.content_margin_bottom = 6
	bar.add_theme_stylebox_override("panel", bar_style)
	outer.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bar.add_child(row)
	var pad := Control.new()
	pad.custom_minimum_size.x = 6
	row.add_child(pad)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -2)
	_title_en = AK.label("", 10, AK.MUTE, AK.en())
	_title = AK.label("", 20, AK.FG)
	titles.add_child(_title_en)
	titles.add_child(_title)
	row.add_child(titles)
	_tabs = HBoxContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_tabs)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(fill)
	_key = AK.label("", 11, AK.FG, AK.en())
	_key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_key.add_theme_stylebox_override("normal", AK.box(AK.PLATE_3, Color.TRANSPARENT, 0, 4))
	row.add_child(_key)
	var close := AK.button("✕", "ghost", 16)
	close.custom_minimum_size = Vector2(52, 52)
	close.pressed.connect(func(): game.close_modal())
	row.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 16)
	for side in ["top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 14)
	scroll.add_child(margin)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	margin.add_child(_body)
	_map_frame = Control.new()
	_map_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_map_frame)
	var map_close := AK.button("✕", "ghost", 16)
	AK.put(_map_frame, map_close, MAP_CLOSE, Vector2(52, 52))
	map_close.pressed.connect(func(): game.close_modal())
	hide_all()

func open(which: String) -> void:
	if which != kind: _tab = 0
	kind = which
	show()
	_dock.visible = which in WIDTHS
	_map_frame.visible = which == "map"
	if _dock.visible:
		_dock.size = Vector2(WIDTHS[which], 720)
	match which:
		"relics": _relics()
		"journal": _journal()

func hide_all() -> void:
	kind = ""
	hide()

func _process(_delta: float) -> void:
	if visible and kind != "" and is_instance_valid(game) and game.modal != kind: hide_all()

func _clear(title: String, en_title: String, key: String, tabs: Array) -> void:
	_title.text = title
	_title_en.text = en_title
	_key.text = key
	for child in _tabs.get_children():
		_tabs.remove_child(child)
		child.queue_free()
	_tabs.add_child(AK.toggle(tabs, _tab, func(i): _tab = i; open(kind), 13))
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()

# --- R: relics — this contract's, or the whole codex -----------------------------

func _relics() -> void:
	_clear("藏品", "COLLECTIBLES", "R", ["本次 %d" % game.builds.size(), "图鉴 %d" % RelicCatalog.all().size()])
	var shown: Array = []
	if _tab == 0:
		for id in game.builds:
			var relic := RelicCatalog.get_relic(id)
			if not relic.is_empty(): shown.append(relic)
	else:
		shown = RelicCatalog.all()
	if _relic_pick.is_empty() or not shown.any(func(r): return r.id == _relic_pick):
		_relic_pick = shown[0].id if not shown.is_empty() else ""
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for relic in shown:
		var cell := Button.new()
		cell.flat = true
		cell.focus_mode = Control.FOCUS_NONE
		cell.custom_minimum_size = Vector2(72, 72)
		cell.set_meta("label", relic.name)
		var icon := AK.relic_icon(relic, 72)
		cell.add_child(icon)
		if _tab == 1 and not game.builds.has(relic.id): cell.modulate.a = 0.35
		if relic.id == _relic_pick: AK.frame(cell, AK.SP, 3.0)
		var id: String = relic.id
		cell.pressed.connect(func(): _relic_pick = id; open(kind))
		grid.add_child(cell)
	# Empty sockets round the shelf out to whole rows (two at least), as in IS.
	var sockets := maxi(12, ceili(shown.size() / 6.0) * 6) - shown.size()
	for i in range(sockets):
		var empty := Panel.new()
		empty.custom_minimum_size = Vector2(72, 72)
		empty.add_theme_stylebox_override("panel", AK.box(Color("1b1b1b")))
		empty.modulate.a = 0.4
		grid.add_child(empty)
	if _tab == 1:
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(492, 410)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.add_child(grid)
		_body.add_child(scroll)
	else:
		_body.add_child(grid)
	if not _relic_pick.is_empty(): _body.add_child(_relic_detail(RelicCatalog.get_relic(_relic_pick)))

func _relic_detail(relic: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", AK.box(AK.PLATE_2, Color.TRANSPARENT, 0, 14))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	var icon := AK.relic_icon(relic, 72)
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 6)
	row.add_child(text)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(AK.label(relic.name, 18, AK.FG))
	head.add_child(AK.tag(RelicCatalog.RARITY_NAMES[relic.rarity], RelicCatalog.RARITY_COLORS[relic.rarity]))
	head.add_child(AK.tag(AK.KIND_NAMES.get(relic.kind, relic.kind), AK.PLATE_3, false))
	text.add_child(head)
	var effect := AK.label(relic.effect, 14, AK.FG)
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.custom_minimum_size.x = 340
	text.add_child(effect)
	var original := AK.label(relic.original, 12, AK.MUTE, AK.italic())
	original.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	original.custom_minimum_size.x = 340
	text.add_child(original)
	return card

# --- J: the contract — objectives and orders ---------------------------------------

func _journal() -> void:
	_clear("外勤合同", "CONTRACT", "J", ["目标", "订单"])
	var region: Dictionary = FieldCatalog.REGIONS[game.region_id]
	if _tab == 0:
		var plate := HBoxContainer.new()
		plate.add_theme_constant_override("separation", 0)
		var code := PanelContainer.new()
		code.custom_minimum_size = Vector2(84, 64)
		code.add_theme_stylebox_override("panel", AK.box(AK.PAPER))
		var code_label := AK.label(AK.REGION_CODE.get(game.region_id, "LG"), 24, AK.INK, AK.en())
		code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		code_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		code.add_child(code_label)
		plate.add_child(code)
		var info := PanelContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_stylebox_override("panel", AK.box(AK.PLATE_2, Color.TRANSPARENT, 0, 10))
		var lines := VBoxContainer.new()
		lines.add_child(AK.label(region.name, 16, AK.FG))
		var stats := HBoxContainer.new()
		stats.add_theme_constant_override("separation", 16)
		stats.add_child(_pair("层", str(game.floor_number), AK.FG))
		stats.add_child(_pair("赤金", str(game.gold_bars()), AK.SP))
		lines.add_child(stats)
		info.add_child(lines)
		plate.add_child(info)
		_body.add_child(plate)
		var block_start := (game.floor_number - 1) / FieldCatalog.CAMP_INTERVAL * FieldCatalog.CAMP_INTERVAL
		var camp_at := block_start + FieldCatalog.CAMP_INTERVAL
		_objective("到达" + game.camp_label(camp_at), game.floor_number - block_start, FieldCatalog.CAMP_INTERVAL, AK.GREEN)
		var mechanisms: int = game.world_map.mechanism_nodes.size()
		if mechanisms > 0: _objective("开启密室", mini(game._mechanisms_done.size(), mechanisms), mechanisms, AK.SP)
		if not game._cache_spawned: _objective("战斗缴获", mini(game.segment_threat, RelicCatalog.CACHE_THREAT), RelicCatalog.CACHE_THREAT, AK.SP)
		if game.is_extraction_floor(): _objective("撤离点", 1, 1, AK.GREEN)
		_body.add_child(AK.section("订单"))
	for entry in game.order_progress(): _body.add_child(_order_card(entry))

func _pair(key: String, value: String, colour: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.add_child(AK.label(key, 12, AK.MUTE))
	row.add_child(AK.label(value, 13, colour, AK.en()))
	return row

func _objective(title: String, have: int, need: int, colour: Color) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", AK.box(AK.PLATE_2, Color.TRANSPARENT, 0, 10))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	card.add_child(column)
	var row := HBoxContainer.new()
	row.add_child(AK.label(title, 13, AK.FG))
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(fill)
	row.add_child(AK.label("%d / %d" % [have, need], 13, colour, AK.en()))
	column.add_child(row)
	var bar := Bar.new()
	bar.ratio = float(have) / maxf(need, 1)
	bar.colour = colour
	bar.custom_minimum_size.y = 4
	column.add_child(bar)
	_body.add_child(card)

## An order as a 贸易站 strip: department block, what and how many, reward.
func _order_card(entry: Dictionary) -> Control:
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 0)
	var dept := PanelContainer.new()
	dept.custom_minimum_size = Vector2(92, 64)
	dept.add_theme_stylebox_override("panel", AK.box(entry.color, Color.TRANSPARENT, 0, 10))
	var dept_column := VBoxContainer.new()
	dept_column.alignment = BoxContainer.ALIGNMENT_CENTER
	dept_column.add_theme_constant_override("separation", -2)
	dept_column.add_child(AK.label("ORDER %02d" % (int(entry.slot) + 1), 8, AK.INK, AK.en()))
	dept_column.add_child(AK.label(entry.dept, 15, AK.INK))
	dept.add_child(dept_column)
	strip.add_child(dept)
	var body := PanelContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_stylebox_override("panel", AK.box(AK.PLATE_2, Color.TRANSPARENT, 0, 10))
	var row := HBoxContainer.new()
	body.add_child(row)
	var what := VBoxContainer.new()
	what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	what.add_child(AK.label("%s ×%d" % [entry.what, entry.need], 14, AK.FG))
	what.add_child(AK.label("持有 %d / %d" % [entry.have, entry.need], 12, AK.GREEN if entry.have >= entry.need else AK.MUTE))
	row.add_child(what)
	var reward := VBoxContainer.new()
	reward.alignment = BoxContainer.ALIGNMENT_CENTER
	var mult := AK.money("lmd", "×%s" % str(entry.mult), 15)
	mult.alignment = BoxContainer.ALIGNMENT_END
	reward.add_child(mult)
	var prestige := AK.label("声望 +%d" % int(entry.prestige), 12, AK.MUTE)
	prestige.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reward.add_child(prestige)
	row.add_child(reward)
	strip.add_child(body)
	return strip


class Bar extends Control:
	var ratio := 0.0
	var colour := AK.FG
	func _draw() -> void:
		AK.draw_bar(self, Rect2(Vector2.ZERO, size), ratio, colour, Color(0, 0, 0, 0.6))
