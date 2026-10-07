class_name BaseHud
extends Control

## The hall HUD (界面策划案 v1.1 #12), after AK's 基建 overview: the sub-page top
## bar with the currency pills (GameManager._status_bar), a station list down
## the left in department colours with a yellow "!" where something waits, a
## banner when prestige ranks up, the PRTS log bottom left and quick buttons
## bottom right. Shown while she walks the base.

var game: GameManager
var _buttons: HBoxContainer
var _last_rank := -1
var _banner_left := 0.0

## [name, kind, colour] — kinds are the station menus they open.
const STATIONS := [
	["调度台", "contracts", Color("ffffff")], ["整备台", "loadout", Color("0098dc")], ["仓管台", "stash", Color("0098dc")],
	["出库区", "outbound", Color("f5c000")], ["医疗前台", "report", Color("8fc31f")], ["药房窗口", "pharmacy", Color("8fc31f")],
	["污染检测门", "decon", Color("e0782a")], ["可露希尔的商店", "store", Color("8fc31f")],
]

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 4)
	_buttons.position = Vector2(1268 - 2 * 60 + 4, 708 - 48)
	add_child(_buttons)
	for entry in [["合同", "contracts"], ["菜单", "pause"]]:
		var b := AK.button(entry[0], "ghost", 12)
		b.custom_minimum_size = Vector2(56, 48)
		var kind: String = entry[1]
		b.pressed.connect(func():
			if kind == "pause": game.toggle_panel("pause")
			else: game.open_station(kind))
		_buttons.add_child(b)

func _process(delta: float) -> void:
	if not is_instance_valid(game): return
	visible = game.base_walk_active()
	var rank := game.base.rank()
	if _last_rank >= 0 and rank > _last_rank: _banner_left = 8.0
	_last_rank = rank
	_banner_left = maxf(0.0, _banner_left - delta)
	if visible: queue_redraw()

func _text(at: Vector2, text: String, size: int, color: Color, font: Font = null) -> float:
	var f := font if font != null else AK.cn()
	draw_string(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

func _draw() -> void:
	# Top bar.
	for i in range(8):
		draw_rect(Rect2(0, i * 7, 1280, 7), Color(0, 0, 0, 0.85 - i * 0.06))
	_text(Vector2(18, 22), "RHODES ISLAND · BRIDGE HALL", 10, AK.MUTE, AK.en())
	_text(Vector2(18, 46), "罗德岛 · 舰桥大厅", 20, AK.FG)
	# Prestige banner, for a while after a rank up.
	if _banner_left > 0.0:
		var rank := game.base.rank()
		var line := "声望提升：" + str(BaseCatalog.RANK_UNLOCKS[rank]).replace("；", " · ")
		var w := AK.cn().get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var x := 640 - (w + 60) * 0.5
		draw_rect(Rect2(x, 66, w + 60, 30), Color(0, 0, 0, 0.85))
		draw_rect(Rect2(x, 66, 36, 30), AK.SP)
		_text(Vector2(x + 7, 87), "R%d" % rank, 13, AK.INK, AK.en())
		_text(Vector2(x + 48, 87), line, 13, AK.FG)
	# Station overview.
	_text(Vector2(16, 86), "站点总览", 13, AK.FG)
	_text(Vector2(200, 86), "FACILITIES", 8, AK.DIM, AK.en())
	var y := 94.0
	for entry in STATIONS:
		var r := Rect2(14, y, 236, 36)
		draw_rect(r, Color(0, 0, 0, 0.8))
		draw_rect(Rect2(r.position, Vector2(6, r.size.y)), entry[2])
		_text(r.position + Vector2(16, 23), entry[0], 12, AK.FG)
		var status := _status(entry[1])
		var sw := AK.cn().get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		_text(Vector2(r.end.x - sw - 10, r.position.y + 23), status, 11, AK.MUTE)
		if _claimable(entry[1]):
			var c := Vector2(r.end.x, r.position.y + 3)
			draw_colored_polygon(AK.diamond(c, 9), AK.SP)
			_text(c + Vector2(-2.5, 4.5), "!", 12, AK.INK, AK.en())
		y += 39
	# PRTS log.
	var lines: Array = game.prts_log.slice(maxi(0, game.prts_log.size() - 4))
	if not lines.is_empty():
		var box := Rect2(14, 706 - 22 - lines.size() * 18, 380, 22 + lines.size() * 18)
		draw_rect(box, Color(0, 0, 0, 0.7))
		for i in range(lines.size()):
			var ly := box.position.y + 24 + i * 18
			var w := _text(Vector2(box.position.x + 10, ly), str(lines[i][0]).left(5), 10, AK.DIM, AK.en())
			_text(Vector2(box.position.x + 16 + w, ly), lines[i][1], 12, AK.FG)

func _status(kind: String) -> String:
	var base: BaseState = game.base
	match kind:
		"contracts": return "外勤合同"
		"loadout": return "装备 · 投保"
		"stash":
			var have := 0
			var room := 0
			for category in range(Item.Category.size()):
				have += base.shelf_count(category)
				room += base.capacity(category)
			return "仓库 %d/%d" % [have, room]
		"outbound":
			var ready := _ready_orders()
			return "订单 · 可交付 %d" % ready if ready > 0 else "订单"
		"report": return "返还中 %d" % base.insurance_queue.size() if not base.insurance_queue.is_empty() else "回收报告"
		"pharmacy": return "配药"
		"decon": return "污染 %d" % roundi(base.contamination)
		"store": return "药剂 · 赤金"
	return ""

func _claimable(kind: String) -> bool:
	match kind:
		"outbound": return _ready_orders() > 0
		"report": return game.base.report_unread
		"stash": return game.base.unseen_unlocks
	return false

func _ready_orders() -> int:
	var board: OrderBoard = game.base.orders
	var deliverable := game.deliverable_items()
	var n := 0
	for slot in range(board.slots.size()):
		var order = board.slots[slot]
		if order != null and order.state == "open" and deliverable.any(func(x): return board.matches(slot, x)): n += 1
	return n
