class_name BaseHud
extends Control

## The hall HUD (界面策划案 v1.1 #12), after AK's 基建 overview: the place's
## name on a plate top left (the currency pills are GameManager._status_bar), a station list down
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
	_buttons.position = Vector2(1268 - 5 * 60 + 4, 708 - 48)
	_buttons.size = Vector2(5 * 60 - 4, 48)
	_buttons.alignment = BoxContainer.ALIGNMENT_END
	add_child(_buttons)
	# 用户 2026-11-04: 让基地也能看干员面板和升级项 — 干员 (C, with its upgrades) here too.
	for entry in [["PRTS", "prts"], ["干员", "training"], ["基建", "construction"], ["合同", "contracts"], ["菜单", "pause"]]:
		var b := AK.button(entry[0], "ghost", 12)
		b.custom_minimum_size = Vector2(56, 48)
		var kind: String = entry[1]
		b.pressed.connect(func():
			if kind == "pause": game.toggle_panel("pause")
			elif kind == "training": game.toggle_panel("training")
			else: game.open_station(kind))
		b.set_meta("kind", kind)
		_buttons.add_child(b)

func _process(_delta: float) -> void:
	if not is_instance_valid(game): return
	visible = game.base_walk_active()
	# The 基建 quick button only once the hub stands (用户 2026-10-22).
	for b in _buttons.get_children():
		if b.get_meta("kind", "") == "construction": b.visible = game.base.hub_built()
		# Mail waiting shows on the PRTS button.
		if b.get_meta("kind", "") == "prts":
			var mails := game.base.mail_count()
			var label := "PRTS %d" % mails if mails > 0 else "PRTS"
			if (b as Button).text != label: (b as Button).text = label
	if visible: queue_redraw()

func _text(at: Vector2, text: String, size: int, color: Color, font: Font = null) -> float:
	var f := font if font != null else AK.cn()
	text = I18n.t(text)
	draw_string(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	return f.get_string_size(I18n.t(text), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

func _draw() -> void:
	# One look per kind for this frame: the list's width and its rows share it.
	_memo.clear()
	_memo_on = true
	_draw_hud()
	_memo_on = false
	_memo.clear()

## Station statuses and counts already worked out during this _draw.
var _memo := {}
var _memo_on := false

func _draw_hud() -> void:
	# The place's name on a plate of its own (用户 2026-11-04: 黑蒙版改为只在有内容的
	# 地方有), fading out past its right end; no bar across the screen.
	var en := "RHODES ISLAND · DECK 2" if game.deck == 2 else "RHODES ISLAND · BRIDGE HALL"
	var cn := "罗德岛 · 第二层" if game.deck == 2 else "罗德岛 · 舰桥大厅"
	var wide := maxf(AK.en().get_string_size(en, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x, AK.cn().get_string_size(I18n.t(cn), HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x) + 32
	draw_rect(Rect2(0, 0, wide, 58), Color(0, 0, 0, 0.7))
	for i in range(8): draw_rect(Rect2(wide + i * 4, 0, 4, 58), Color(0, 0, 0, 0.7 * (1.0 - (i + 1) / 9.0)))
	_text(Vector2(18, 22), en, 10, AK.MUTE, AK.en())
	_text(Vector2(18, 46), cn, 20, AK.FG)
	_draw_stations()
	# PRTS log.
	# A line too long for the box goes on under itself (用户 2026-10-24: 超出的文字起第二行).
	var lines: Array = game.prts_log.slice(maxi(0, game.prts_log.size() - 4))
	# Up for LOG_SHOW seconds after PRTS speaks, fading over its last LOG_FADE.
	var since := (Time.get_ticks_msec() - game.prts_said_at) / 1000.0
	var fade := clampf((LOG_SHOW - since) / LOG_FADE, 0.0, 1.0)
	if not lines.is_empty() and fade > 0.0:
		var stamp := AK.en().get_string_size("00:00", HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		var rows: Array = []
		for line in lines:
			var parts := wrap_text(I18n.t(str(line[1])), 12, LOG_WIDTH - 26 - stamp)
			for k in range(parts.size()): rows.append([str(line[0]).left(5) if k == 0 else "", parts[k]])
		var box := Rect2(14, 706 - 22 - rows.size() * 18, LOG_WIDTH, 22 + rows.size() * 18)
		draw_rect(box, Color(0, 0, 0, 0.7 * fade))
		for i in range(rows.size()):
			var ly := box.position.y + 24 + i * 18
			if not str(rows[i][0]).is_empty(): _text(Vector2(box.position.x + 10, ly), rows[i][0], 10, Color(AK.DIM, AK.DIM.a * fade), AK.en())
			_text(Vector2(box.position.x + 16 + stamp, ly), rows[i][1], 12, Color(AK.FG, AK.FG.a * fade))

const LOG_WIDTH := 380.0
const LOG_SHOW := 6.0
const LOG_FADE := 1.0

## `text` cut into lines no wider than `room` at `size`: at a space when the
## line has one (English), else at any character (Chinese).
static func wrap_text(text: String, size: int, room: float) -> Array[String]:
	var font := AK.cn()
	var key := [text, size, room, font.get_instance_id()]
	if _wrapped.has(key): return _wrapped[key]
	var out := _wrap(font, text, size, room)
	if _wrapped.size() > WRAP_CACHE_LIMIT: _wrapped.clear()
	_wrapped[key] = out
	return out

## wrap_text's rows by text, size, room and font (the text is already in its language).
static var _wrapped := {}
const WRAP_CACHE_LIMIT := 256

static func _wrap(font: Font, text: String, size: int, room: float) -> Array[String]:
	var out: Array[String] = []
	var line := ""
	for c in text:
		if font.get_string_size(line + c, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= room or line.is_empty():
			line += c
			continue
		var cut := line.rfind(" ")
		if c != " " and cut > 0:
			out.append(line.left(cut))
			line = line.substr(cut + 1) + c
		else:
			out.append(line)
			line = "" if c == " " else c
	if not line.is_empty() or out.is_empty(): out.append(line)
	return out

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
	if not _memo_on: return _status_now(kind)
	var key := "status:" + kind
	if not _memo.has(key): _memo[key] = _status_now(kind)
	return _memo[key]

func _status_now(kind: String) -> String:
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
			var ready := _construction_ready()
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
		"construction": return _construction_ready() > 0
		"farm": return game.provisions.ripe_count() > 0
	return false

func _construction_ready() -> int:
	if not _memo_on: return game.construction_ready()
	if not _memo.has("construction_ready"): _memo["construction_ready"] = game.construction_ready()
	return _memo["construction_ready"]

func _ready_orders() -> int:
	if not _memo_on: return _ready_orders_now()
	if not _memo.has("ready_orders"): _memo["ready_orders"] = _ready_orders_now()
	return _memo["ready_orders"]

func _ready_orders_now() -> int:
	var board: OrderBoard = game.base.orders
	var deliverable := game.deliverable_items()
	var n := 0
	for slot in range(board.slots.size()):
		var order = board.slots[slot]
		if order != null and order.state == "open" and deliverable.any(func(x): return board.matches(slot, x)): n += 1
	return n
