class_name BaseHud
extends Control

## The hall HUD (界面策划案 v1.1 #12), after AK's 基建 overview: the sub-page top
## bar with the currency pills (GameManager._status_bar), a station list down
## the left in department colours with a yellow "!" where something waits
## (open with its key, toggle_stations; which stations it lists is a setting),
## the PRTS log bottom left and quick buttons bottom right. Shown while she
## walks the base.

var game: GameManager
var _buttons: HBoxContainer

## [name, kind, colour] — kinds are the station menus they open.
const STATIONS := [
	["调度台", "contracts", Color("ffffff")], ["整备台", "loadout", Color("0098dc")], ["仓管台", "stash", Color("0098dc")],
	["出库区", "outbound", Color("f5c000")], ["医疗前台", "report", Color("8fc31f")], ["药房窗口", "pharmacy", Color("8fc31f")],
	["可露希尔的商店", "store", Color("8fc31f")], ["交易所", "exchange", Color("c48cff")], ["加工站", "workshop", Color("e0782a")],
	["人事部", "personnel", Color("0098dc")], ["沙盘", "sand_table", Color("5fd0d8")], ["科研部", "research", Color("e0782a")],
	["基建总控台", "construction", Color("e8b730")], ["农业部", "farm", Color("8fc31f")], ["食堂", "canteen", Color("e0a040")],
]

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 4)
	_buttons.position = Vector2(1268 - 3 * 60 + 4, 708 - 48)
	_buttons.size = Vector2(3 * 60 - 4, 48)
	_buttons.alignment = BoxContainer.ALIGNMENT_END
	add_child(_buttons)
	for entry in [["基建", "construction"], ["合同", "contracts"], ["菜单", "pause"]]:
		var b := AK.button(entry[0], "ghost", 12)
		b.custom_minimum_size = Vector2(56, 48)
		var kind: String = entry[1]
		b.pressed.connect(func():
			if kind == "pause": game.toggle_panel("pause")
			else: game.open_station(kind))
		b.set_meta("kind", kind)
		_buttons.add_child(b)

func _process(_delta: float) -> void:
	if not is_instance_valid(game): return
	visible = game.base_walk_active()
	# The 基建 quick button only once the hub stands (用户 2026-10-22).
	for b in _buttons.get_children():
		if b.get_meta("kind", "") == "construction": b.visible = game.base.hub_built()
	if visible: queue_redraw()

func _text(at: Vector2, text: String, size: int, color: Color, font: Font = null) -> float:
	var f := font if font != null else AK.cn()
	text = I18n.t(text)
	draw_string(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	return f.get_string_size(I18n.t(text), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

func _draw() -> void:
	# Top bar.
	for i in range(8):
		draw_rect(Rect2(0, i * 7, 1280, 7), Color(0, 0, 0, 0.85 - i * 0.06))
	if game.deck == 2:
		_text(Vector2(18, 22), "RHODES ISLAND · DECK 2", 10, AK.MUTE, AK.en())
		_text(Vector2(18, 46), "罗德岛 · 第二层", 20, AK.FG)
	else:
		_text(Vector2(18, 22), "RHODES ISLAND · BRIDGE HALL", 10, AK.MUTE, AK.en())
		_text(Vector2(18, 46), "罗德岛 · 舰桥大厅", 20, AK.FG)
	_draw_stations()
	# PRTS log.
	var lines: Array = game.prts_log.slice(maxi(0, game.prts_log.size() - 4))
	if not lines.is_empty():
		var box := Rect2(14, 706 - 22 - lines.size() * 18, 380, 22 + lines.size() * 18)
		draw_rect(box, Color(0, 0, 0, 0.7))
		for i in range(lines.size()):
			var ly := box.position.y + 24 + i * 18
			var w := _text(Vector2(box.position.x + 10, ly), str(lines[i][0]).left(5), 10, AK.DIM, AK.en())
			_text(Vector2(box.position.x + 16 + w, ly), lines[i][1], 12, AK.FG)

## The stations listed in the overview, in order (all but the ones hidden in the settings).
static func shown_stations() -> Array:
	var hidden: Array = SystemScreens.settings.get("station_hidden", [])
	return STATIONS.filter(func(e): return not e[1] in hidden)

static func panel_open() -> bool:
	return bool(SystemScreens.settings.get("station_panel", false))

## Station overview, while it is open.
func _draw_stations() -> void:
	var stations := shown_stations()
	if not panel_open() or stations.is_empty(): return
	_text(Vector2(16, 86), "站点总览", 13, AK.FG)
	_text(Vector2(200, 86), "FACILITIES", 8, AK.DIM, AK.en())
	var y := 94.0
	# As wide as its longest name and status (English runs longer).
	var width := 236.0
	for entry in stations:
		width = maxf(width, 16 + AK.cn().get_string_size(I18n.t(entry[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 16
			+ AK.cn().get_string_size(I18n.t(_status(entry[1])), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 10)
	for entry in stations:
		var r := Rect2(14, y, width, 36)
		draw_rect(r, Color(0, 0, 0, 0.8))
		draw_rect(Rect2(r.position, Vector2(6, r.size.y)), entry[2])
		_text(r.position + Vector2(16, 23), entry[0], 12, AK.FG)
		var status := _status(entry[1])
		var sw := AK.cn().get_string_size(I18n.t(status), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		_text(Vector2(r.end.x - sw - 10, r.position.y + 23), status, 11, AK.MUTE)
		if _claimable(entry[1]):
			var c := Vector2(r.end.x, r.position.y + 3)
			draw_colored_polygon(AK.diamond(c, 9), AK.SP)
			_text(c + Vector2(-2.5, 4.5), "!", 12, AK.INK, AK.en())
		y += 39

func _status(kind: String) -> String:
	var base: BaseState = game.base
	match kind:
		"contracts": return "外勤合同"
		"loadout": return "装备 · 投保"
		"stash":
			return "仓库 %d/%d" % [base.shelf_count(), base.capacity()]
		"outbound":
			var ready := _ready_orders()
			return "订单 · 可交付 %d" % ready if ready > 0 else "订单"
		"report": return "返还中 %d" % base.insurance_queue.size() if not base.insurance_queue.is_empty() else "回收报告"
		"pharmacy": return "配药"
		"store": return "药剂 · 换汇 · 贷款"
		"exchange":
			var rate := "龙门币 / 赤金 %.1f" % Economy.fx
			return ("限时 %d · " % game.market.flash.size() if not game.market.flash.is_empty() else "") + rate
		"personnel":
			var ready := RecruitCatalog.RECRUITS.keys().filter(func(id): return game.base.recruit_ready(id)).size()
			return "可寻访 %d" % ready if ready > 0 else "干员名册"
		"sand_table":
			var v := game.voyage
			if v.is_sailing(): return "航行 → %s" % v.sailing.to
			return "%s%s" % [v.place(), " · 驻留" if v.stay_on() else ""]
		"workshop":
			var jobs := game.workshop.busy()
			return "加工中 %d" % jobs if jobs > 0 else "加工 · 打包"
		"research":
			if not game.research.is_open(): return "未建成"
			var running := game.research.active().size()
			return "研究中 %d · 课题 %d" % [running, game.research.projects().size()]
		"construction":
			if not game.base.hub_built(): return "未建成"
			var ready := game.construction_ready()
			return "可升级 %d" % ready if ready > 0 else "设施 · 扩建"
		"farm":
			if game.base.facility_level("farm") <= 0: return "未建成"
			var ripe := game.provisions.ripe_count()
			return "可收获 %d" % ripe if ripe > 0 else "水培槽 %d" % game.provisions.basins()
		"canteen":
			if game.base.facility_level("canteen") <= 0: return "未建成"
			var meal := game.provisions.meal()
			return ("烹饪中 %d" % game.provisions.jobs().size()) if not game.provisions.jobs().is_empty() else (meal if not meal.is_empty() else "厨房 · 用餐")
	return ""

func _claimable(kind: String) -> bool:
	match kind:
		"outbound": return _ready_orders() > 0
		"report": return game.base.report_unread
		"exchange": return not game.market.flash.is_empty()
		"personnel": return RecruitCatalog.RECRUITS.keys().any(func(id): return game.base.recruit_ready(id))
		"construction": return game.construction_ready() > 0
		"farm": return game.provisions.ripe_count() > 0
	return false

func _ready_orders() -> int:
	var board: OrderBoard = game.base.orders
	var deliverable := game.deliverable_items()
	var n := 0
	for slot in range(board.slots.size()):
		var order = board.slots[slot]
		if order != null and order.state == "open" and deliverable.any(func(x): return board.matches(slot, x)): n += 1
	return n
