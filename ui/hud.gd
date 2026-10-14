class_name Hud
extends Control

## The field HUD (界面策划案 v1.1 §3): MMO layout, Arknights look.
##   top left     floor plate, region, 赤金, relics, contamination; effect badges
##   top right    panel buttons (I R M J) and pause, the minimap, the order tracker
##   top centre   PRTS toasts: necessary notices only (no log box, no centre message)
##   bottom right stamina counter and the action cards
##   in the world her blue life / yellow SP bars and the ready mark, enemy bars
##                by tier (no names, Grim Dawn style), container names, the E
##                prompt, ground names while Alt is held
## No portrait panel, no pack bar, no target frame, no alert number (用户 2026-10-06).

var game: GameManager

var _map_source: NavigationRegion3D
var _map_mesh: ArrayMesh
var _map_outline := PackedVector2Array()
var _all_triangles := PackedVector2Array()
var _triangle_keys := PackedVector2Array()
var _all_outline := PackedVector2Array()
var _outline_keys := PackedVector2Array()
var _mapped_cells := -1
var _mapped_stamp := 0
var _pulse := 0.0
var _buttons: HBoxContainer

const MAP_RECT := Rect2(1036, 60, 232, 176)
## The M overlay: the same map, large (界面策划案 #4).
const BIG_MAP_RECT := Rect2(60, 52, 900, 500)
const MAP_LINE := Color(0.745, 0.902, 1.0, 0.8)
const TRACK_TOP := 244.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buttons = HBoxContainer.new()
	_buttons.position = Vector2(1012, 12)
	_buttons.add_theme_constant_override("separation", 4)
	add_child(_buttons)
	for entry in [["干员", "I", "inventory"], ["藏品", "R", "relics"], ["地图", "M", "map"], ["合同", "J", "journal"]]:
		var b := AK.button("%s\n%s" % [entry[0], entry[1]], "ghost", 11)
		b.custom_minimum_size = Vector2(46, 40)
		var kind: String = entry[2]
		b.pressed.connect(func(): game.toggle_panel(kind))
		_buttons.add_child(b)
	var pause := AK.button("II", "paper", 15)
	pause.custom_minimum_size = Vector2(46, 40)
	pause.pressed.connect(func(): game.toggle_panel("pause"))
	_buttons.add_child(pause)

func _process(delta: float) -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.player): return
	visible = not game.in_base and not game.in_camp and game.modal not in ["build", "route", "squad", "trader", "camp", "pause", "settlement"]
	_buttons.visible = visible and game.modal in ["", "inventory", "relics", "journal"]
	# Right-aligned: English names make the row wider than the Chinese one.
	_buttons.position.x = 1268.0 - _buttons.size.x
	_pulse += delta
	queue_redraw()

func _font() -> Font: return AK.cn()
func _en() -> Font: return AK.en()

func _text(at: Vector2, text: String, size: int, color: Color, font: Font = null, outline := true) -> float:
	var f := font if font != null else _font()
	text = I18n.t(text)
	if outline: draw_string_outline(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, 0.85))
	draw_string(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	return f.get_string_size(I18n.t(text), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

func _draw() -> void:
	if not is_instance_valid(game) or game.in_base or game.in_camp: return
	if not is_instance_valid(game.world_map._generated_root): return
	_draw_world_marks()
	if game.modal == "map":
		# Diablo's overlay map (界面策划案 #5): lines straight over the paused
		# field; the minimap, tracker and pickup names step aside.
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.016, 0.024, 0.031, 0.62))
		_draw_top_bar()
		_draw_toasts()
		_draw_actions()
		_draw_map(BIG_MAP_RECT, true)
		_draw_map_info()
		return
	_draw_top_bar()
	_draw_map(MAP_RECT, false)
	if SystemScreens.settings.get("tracker", true): _draw_orders()
	if SystemScreens.settings.get("broadcasts", true): _draw_toasts()
	_draw_actions()

# --- Top left ---------------------------------------------------------------------

func _draw_top_bar() -> void:
	var code := AK.floor_code(game.region_id, game.floor_number)
	draw_rect(Rect2(0, 0, 640, 44), Color(0, 0, 0, 0.72))
	draw_rect(Rect2(0, 0, 88, 44), AK.PAPER)
	_text(Vector2(10, 14), "FLOOR", 9, AK.INK, _en(), false)
	_text(Vector2(10, 38), code, 20, AK.INK, _en(), false)
	var region: String = FieldCatalog.REGIONS[game.region_id].name
	_text(Vector2(100, 22), region, 14, AK.FG)
	var x := 100.0 + _font().get_string_size(I18n.t(region), HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 24
	_draw_gold_icon(Vector2(x + 7, 23))
	x += 18 + _text(Vector2(x + 18, 30), str(game.gold_bars()), 17, AK.FG, _en())
	draw_rect(Rect2(x + 14, 16, 12, 12), AK.FG, false, 1.6)
	draw_rect(Rect2(x + 17, 19, 6, 6), AK.FG)
	x += 32 + _text(Vector2(x + 32, 30), str(game.builds.size()), 17, AK.FG, _en())
	if game.contamination_visible():
		draw_colored_polygon(AK.diamond(Vector2(x + 22, 23), 7), Color("111111"))
		draw_polyline(AK.diamond(Vector2(x + 22, 23), 7) + PackedVector2Array([Vector2(x + 22, 16)]), AK.ORI, 1.4)
		var w := _text(Vector2(x + 34, 30), str(roundi(game.current_contamination())), 17, AK.ORI, _en())
		_text(Vector2(x + 40 + w, 30), "+%.2f/s" % game.contamination_rate(), 11, AK.MUTE, _en())
	# Effect badges: what is ticking right now.
	var badges: Array = []
	if game._slow_heal_left > 0.0: badges.append(["缓", AK.HP, "%ds" % ceili(game._slow_heal_left / maxf(game._slow_heal_rate, 1.0))])
	if game._suppress_timer > 0.0: badges.append(["抑", AK.ORI, "%ds" % ceili(game._suppress_timer)])
	if game.player.shield > 0.0: badges.append(["盾", Color("bfe8ff"), str(roundi(game.player.shield))])
	var tier := BaseCatalog.contamination_tier(game.current_contamination())
	if tier > 0: badges.append(["染", AK.ORI, BaseCatalog.CONTAMINATION_TIER_NAMES[tier]])
	for i in range(badges.size()):
		var b: Array = badges[i]
		var r := Rect2(12 + i * 34, 54, 28, 28)
		draw_rect(r, Color.BLACK)
		draw_rect(Rect2(r.position.x, r.end.y - 2, r.size.x, 2), b[1])
		_text(r.position + Vector2(7, 19), b[0], 13, b[1], null, false)
		_text(r.position + Vector2(2, 40), b[2], 10, AK.FG, _en())

func _draw_gold_icon(c: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(-7, 4), c + Vector2(-4, -3), c + Vector2(4, -3), c + Vector2(7, 4)]), AK.SP)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-4, -3), c + Vector2(4, -3), c + Vector2(3, -1), c + Vector2(-3, -1)]), Color("fff6c2"))

# --- Top right: minimap and orders ----------------------------------------------------

func _map_scale(rect: Rect2) -> float:
	return (rect.size.y * 0.5 - 8.0) / maxf(game.world_map.map_extent, 1.0)

func map_point(position: Vector3, rect: Rect2 = MAP_RECT) -> Vector2:
	var scale := _map_scale(rect)
	var centre: Vector3 = game.world_map.map_center
	return rect.get_center() - Vector2((position.x - centre.x) * scale, (position.z - centre.z) * scale)

func _draw_map(rect: Rect2, big: bool) -> void:
	if not big: draw_rect(rect, Color(0, 0, 0, 0.78))
	if _map_source != game.world_map._generated_root: _cache_minimap()
	_refresh_mapped_area()
	# The cache is in world x / z; one transform places it in either rect.
	var scale := _map_scale(rect)
	var centre: Vector3 = game.world_map.map_center
	draw_set_transform(rect.get_center() + Vector2(centre.x, centre.z) * scale, 0.0, Vector2(-scale, -scale))
	if _map_mesh.get_surface_count() > 0: draw_mesh(_map_mesh, null, Transform2D.IDENTITY, Color(0.745, 0.902, 1.0, 0.07) if big else Color("2f2f2f"))
	if _map_outline.size() >= 2: draw_multiline(_map_outline, MAP_LINE if big else Color("8a8a8a"), 2.0 / scale if big else -1.0)
	draw_set_transform(Vector2.ZERO)
	var k := 1.6 if big else 1.0
	var markers: Array = [game.world_map.buff_device_node, game.world_map.encounter_node, game.world_map.exit_node, game.world_map.vault_node]
	var colours := [Color("ef9b42"), AK.TRADER if game.encounter == "trader" else AK.CYAN, AK.GREEN, AK.TIER[2]]
	for i in range(markers.size()):
		if is_instance_valid(markers[i]) and markers[i].visible and game.fog.is_point_revealed(markers[i].position):
			var at := map_point(markers[i].position, rect)
			draw_colored_polygon(AK.diamond(at, 4.5 * k), colours[i])
			if big: _text(at + Vector2(12, 5), _marker_name(i), 12, AK.FG)
	for i in range(game.world_map.mechanism_nodes.size()):
		var node: Node3D = game.world_map.mechanism_nodes[i]
		if is_instance_valid(node) and game.fog.is_point_revealed(node.position):
			draw_colored_polygon(AK.diamond(map_point(node.position, rect), 3 * k), Color("55627a") if game._mechanisms_done.has(i) else Color("b47ae0"))
	for node in get_tree().get_nodes_in_group("enemies"):
		var leader := node as Enemy
		if leader.boss and leader.game == game and not leader._dead and game.fog.is_point_revealed(leader.global_position):
			var at := map_point(leader.global_position, rect)
			draw_colored_polygon(AK.diamond(at, 5 * k), AK.RED)
			if big: _text(at + Vector2(12, 5), "头目", 12, AK.FG)
	for node in game.world_map.route_nodes:
		if is_instance_valid(node) and game.fog.is_point_revealed(node.position):
			draw_colored_polygon(AK.diamond(map_point(node.position, rect), 3.5 * k), Color("72b8ff"))
			if big: _text(map_point(node.position, rect) + Vector2(12, 5), "深入入口", 12, AK.FG)
	for node in get_tree().get_nodes_in_group("relic_caches"):
		var cache := node as RelicCache
		if cache.game == game and game.fog.is_point_revealed(cache.position):
			draw_colored_polygon(AK.diamond(map_point(cache.position, rect), 3 * k), Color("8a8f96") if cache.sealed else (AK.TIER[2] if cache.source == "vault" else AK.HP))
			if big and cache.source != "vault": _text(map_point(cache.position, rect) + Vector2(10, 5), "战斗缴获", 12, AK.FG)
	for node in get_tree().get_nodes_in_group("loot_containers"):
		var box := node as LootContainer
		if box.game == game and game.fog.is_point_revealed(box.position):
			draw_rect(Rect2(map_point(box.position, rect) - Vector2(2, 2) * k, Vector2(4, 4) * k), Color("55606a") if box.opened else box.color().lightened(0.25))
	if big:
		draw_colored_polygon(AK.diamond(map_point(game.player.position, rect), 8), Color.WHITE)
		return
	draw_circle(map_point(game.player.position, rect), 3.5 * k, Color.WHITE)
	draw_rect(Rect2(rect.position.x, rect.end.y - 18, rect.size.x, 18), Color.BLACK)
	_text(Vector2(rect.position.x + 8, rect.end.y - 5), AK.floor_code(game.region_id, game.floor_number) if big else "FIELD MAP", 9 if not big else 11, AK.MUTE, _en(), false)
	var explored := "已探索 %d%%" % roundi(game.fog.revealed_fraction() * 100.0)
	var w := _font().get_string_size(I18n.t(explored), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	_text(Vector2(rect.end.x - w - 8, rect.end.y - 5), explored, 11, AK.MUTE, null, false)

func _marker_name(i: int) -> String:
	match i:
		0: return "强化装置"
		1: return "坎诺特" if game.encounter == "trader" else "罗德岛小队"
		2: return "撤离信标"
		_: return "密室"

## Top right of the M overlay: the floor plate, region, explored share, and the
## floors of this block of ten down to its camp.
func _draw_map_info() -> void:
	var right := 1268.0
	var top := 76.0
	var code := AK.floor_code(game.region_id, game.floor_number)
	var cw := _en().get_string_size(I18n.t(code), HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 20
	draw_rect(Rect2(right - cw, top, cw, 28), AK.PAPER)
	_text(Vector2(right - cw + 10, top + 22), code, 20, AK.INK, _en(), false)
	var region: String = FieldCatalog.REGIONS[game.region_id].name
	_text(Vector2(right - _font().get_string_size(I18n.t(region), HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x, top + 54), region, 18, AK.FG)
	var explored := "已探索 %d%%" % roundi(game.fog.revealed_fraction() * 100.0)
	_text(Vector2(right - _font().get_string_size(I18n.t(explored), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x, top + 74), explored, 12, AK.MUTE)
	var names := {}
	for step in game.route_history: names[int(step.floor)] = step.name
	var block := (game.floor_number - 1) / FieldCatalog.CAMP_INTERVAL * FieldCatalog.CAMP_INTERVAL
	var y := top + 96
	for n in range(block + 1, block + FieldCatalog.CAMP_INTERVAL + 2):
		var camp := n == block + FieldCatalog.CAMP_INTERVAL + 1
		var current := n == game.floor_number
		var label := game.camp_label(block + FieldCatalog.CAMP_INTERVAL) if camp else AK.floor_code(game.region_id, n)
		var w := 84.0 if camp else 56.0
		draw_rect(Rect2(right - w, y, w, 17), AK.PAPER if current else (AK.GREEN if camp else Color(0, 0, 0, 0.6)))
		var lw := _en().get_string_size(I18n.t(label), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		_text(Vector2(right - w + (w - lw) * 0.5, y + 13), label, 12, AK.INK if current or camp else (AK.DIM if n < game.floor_number else AK.FG), _en() if not camp else _font(), false)
		var name: String = names.get(n, "")
		if current and game.is_extraction_floor(): name += " · 撤离"
		if not name.is_empty():
			var nw := _font().get_string_size(I18n.t(name), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			_text(Vector2(right - w - 8 - nw, y + 13), name, 11, AK.DIM if n < game.floor_number else AK.FG)
		y += 20

## Text in at most `room` pixels: a smaller font (to 9), then cut with "…".
func _text_within(at: Vector2, text: String, size: int, color: Color, room: float) -> void:
	var shown := I18n.t(text)
	while size > 9 and _font().get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > room: size -= 1
	while shown.length() > 2 and _font().get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > room:
		shown = shown.left(shown.length() - 2) + "…"
	_text(at, shown, size, color, null, false)

## A tag plate's width for its (shown) text: 34 for two Chinese characters.
func _tag_width(text: String) -> float:
	return maxf(34.0, _font().get_string_size(I18n.t(text), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 8)

## The tracker: the contract's objective first (局内节奏与目标策划案 §6 B1), then
## the orders (用户 2026-10-06): department, what, carried / needed.
func _draw_orders() -> void:
	var y := TRACK_TOP
	var x := MAP_RECT.position.x
	var goal := game.contract_progress()
	if not goal.is_empty():
		draw_rect(Rect2(x, y, MAP_RECT.size.x, 24), Color(0, 0, 0, 0.78))
		var tag := _tag_width("合同")
		draw_rect(Rect2(x + 6, y + 5, tag, 14), AK.SP)
		_text(Vector2(x + 10, y + 17), "合同", 11, AK.INK, null, false)
		_text(Vector2(x + 14 + tag, y + 17), FieldCatalog.CONTRACT_NAMES[game.contract.type], 12, AK.FG, null, false)
		y += 26
		draw_rect(Rect2(x, y, MAP_RECT.size.x, 22), Color(0, 0, 0, 0.55))
		draw_rect(Rect2(x, y, 4, 22), AK.SP)
		var mark := "✓" if goal.done else "%d / %d" % [goal.have, goal.need]
		var mw := _en().get_string_size(I18n.t(mark), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		_text_within(Vector2(x + 10, y + 16), goal.goal, 12, AK.FG, MAP_RECT.size.x - mw - 26)
		_text(Vector2(x + MAP_RECT.size.x - mw - 8, y + 16), mark, 13, AK.GREEN if goal.done else AK.FG, _en(), false)
		y += 30
	var rows := game.order_progress()
	if rows.is_empty(): return
	draw_rect(Rect2(x, y, MAP_RECT.size.x, 24), Color(0, 0, 0, 0.78))
	var tag := _tag_width("订单")
	draw_rect(Rect2(x + 6, y + 5, tag, 14), AK.PAPER)
	_text(Vector2(x + 10, y + 17), "订单", 11, AK.INK, null, false)
	_text(Vector2(x + 14 + tag, y + 17), FieldCatalog.REGIONS[game.region_id].name.split(" · ")[0], 12, AK.FG, null, false)
	var dept_w := 42.0
	for row in rows: dept_w = maxf(dept_w, _font().get_string_size(I18n.t(row.dept), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 6)
	y += 26
	for row in rows:
		draw_rect(Rect2(x, y, MAP_RECT.size.x, 22), Color(0, 0, 0, 0.55))
		draw_rect(Rect2(x, y, 4, 22), row.color)
		_text(Vector2(x + 10, y + 16), row.dept, 11, AK.MUTE, null, false)
		_text_within(Vector2(x + 10 + dept_w, y + 16), row.what, 12, AK.FG, MAP_RECT.size.x - dept_w - 70)
		var count := "%d / %d" % [row.have, row.need]
		var w := _en().get_string_size(I18n.t(count), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		_text(Vector2(x + MAP_RECT.size.x - w - 8, y + 16), count, 13, AK.GREEN if row.have >= row.need else AK.FG, _en(), false)
		y += 24

# --- Top centre: PRTS toasts ---------------------------------------------------------
# 用户 2026-10-10: 局内 prts 只保留提示必要信息（如背包已满无法拾取），教程类
# 不提示。GameManager.notice() feeds these: they pop in under the top bar with
# a blue PRTS tag, stack newest at the bottom, and fade out.

const TOAST_TOP := 54.0
const TOAST_HEIGHT := 30.0
const TOAST_FADE := 0.5

func _draw_toasts() -> void:
	var y := TOAST_TOP
	for toast in game.prts_toasts:
		var age: float = toast.age
		var life: float = toast.life
		var alpha := clampf(minf(age / 0.15, (life - age) / TOAST_FADE), 0.0, 1.0)
		var size := 14
		var text: String = toast.text
		var tag := "PRTS"
		var tag_w := _en().get_string_size(I18n.t(tag), HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 12
		var w := _font().get_string_size(I18n.t(text), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + tag_w + 24
		var r := Rect2(640.0 - w * 0.5, y - (1.0 - minf(age / 0.15, 1.0)) * 8.0, w, TOAST_HEIGHT)
		draw_rect(r, Color(0, 0, 0, 0.8 * alpha))
		draw_rect(Rect2(r.position.x, r.position.y, tag_w, r.size.y), Color(AK.HP, alpha))
		_text(r.position + Vector2(6, 19), tag, 10, Color(1, 1, 1, alpha), _en(), false)
		_text(r.position + Vector2(tag_w + 12, 20), text, size, Color(AK.FG, alpha), null, false)
		y += TOAST_HEIGHT + 4.0

# --- Bottom centre: the hotbar and her bars ----------------------------------------------
# Grim Dawn's layout (用户 2026-10-10): the skill slots sit in the middle of the
# bottom edge, life on the left of them, stamina and the passive build-up on
# the right. The E prompt is gone from the bar (E still works in the world).

const SLOT := 58.0
const SLOT_GAP := 6.0
const HOTBAR_BOTTOM := 706.0
const SIDE_BAR := 210.0

## Left-click attack (fixed), then the player's eight Hotbar slots, then any
## special gear (passive, shown for its state). Empty slots still show
## their key so the bar never changes width.
func _hotbar_slots() -> Array:
	var p := game.player
	var slots: Array = [{"key": "LMB", "glyph": "slash", "colour": AK.FG}]
	var bound := Hotbar.slots()
	for index in range(Hotbar.SLOTS):
		var key := Keybinds.short_label(Hotbar.input_of(index))
		var action: String = bound[index].action
		if action == "":
			slots.append({"key": key, "glyph": "", "colour": Color(0.25, 0.25, 0.25)})
			continue
		var info: Dictionary = Hotbar.ACTIONS[action]
		var slot := {"key": key, "glyph": info.glyph, "colour": AK.FG, "action": action}
		match action:
			"dash":
				slot.colour = AK.HP
				slot.cost = str(roundi(p.dash_cost()))
				slot.cooldown = maxf(p._dash_cooldown, 0.0)
				slot.cooldown_total = Player.DASH_COOLDOWN
			"shadow":
				slot.colour = AK.SP
				if p.is_amiya():
					var cd := maxf(p.shadow_cooldown, 0.0)
					slot.ready = cd <= 0.0
					slot.cooldown = cd
					slot.cooldown_total = Player.SHADOW_COOLDOWN
				else:
					slot.unavailable = true
			_:
				var type: String = info.potion
				var count := game.carried_potions().filter(func(x): return x.potion_type == type).size()
				slot.colour = {"A": AK.GREEN, "B": Color("4fb3f6"), "C": Color("8fd3c8")}[type]
				slot.potion = type
				slot.cost = str(count)
				if count == 0: slot.unavailable = true
		slots.append(slot)
	for item in p.equipped.values():
		if item != null and not item.special.is_empty():
			slots.append({"key": "", "glyph": "special", "colour": AK.SPECIAL, "item": item})
	return slots

## The hotbar slot whose picker is open (-1: none). GameManager opens and
## closes it from clicks on the bar.
var picker_slot := -1
const PICKER_ROW := 26.0
const PICKER_WIDTH := 104.0

## The rectangle of the i-th drawn slot (0 = the fixed LMB slot).
func _slot_rect(i: int) -> Rect2:
	var bar := hotbar_rect()
	return Rect2(bar.position.x + i * (SLOT + SLOT_GAP), bar.position.y, SLOT, SLOT)

## Which configurable slot is under `point` (HUD coordinates): 0..7, -1 for
## the bar but no slot (its frame, LMB, special gear), -2 off the bar.
func hotbar_slot_at(point: Vector2) -> int:
	if not visible or not is_instance_valid(game) or not game.simulation_active(): return -2
	if not hotbar_rect().grow(6).has_point(point): return -2
	for i in range(Hotbar.SLOTS):
		if _slot_rect(i + 1).has_point(point): return i
	return -1

## The picker's option rectangles, bottom-up above the open slot: [Rect2, choice].
func _picker_rows() -> Array:
	if picker_slot < 0: return []
	var anchor := _slot_rect(picker_slot + 1)
	var rows: Array = []
	var y := anchor.position.y - 10 - PICKER_ROW
	for k in range(Hotbar.CHOICES.size() - 1, -1, -1):
		rows.append([Rect2(anchor.get_center().x - PICKER_WIDTH * 0.5, y, PICKER_WIDTH, PICKER_ROW), Hotbar.CHOICES[k]])
		y -= PICKER_ROW + 2
	return rows

## The choice under `point` in the open picker, or null.
func picker_choice_at(point: Vector2) -> Variant:
	for row in _picker_rows():
		if (row[0] as Rect2).has_point(point): return row[1]
	return null

func _draw_picker() -> void:
	var rows := _picker_rows()
	if rows.is_empty(): return
	var current: String = Hotbar.slots()[picker_slot].action
	var hover := get_local_mouse_position()
	var frame := (rows[0][0] as Rect2)
	for row in rows: frame = frame.merge(row[0])
	draw_rect(frame.grow(4), Color(0, 0, 0, 0.88))
	for row in rows:
		var r: Rect2 = row[0]
		var choice: String = row[1]
		var on := choice == current
		var usable: bool = choice == "" or not Hotbar.ACTIONS[choice].has("operator") or Hotbar.ACTIONS[choice].operator == game.player.operator_id
		draw_rect(r, AK.PAPER if on else (Color("3a3a3a") if r.has_point(hover) else Color("262626")))
		_text(r.position + Vector2(10, 18), Hotbar.CHOICE_NAMES[choice], 13, AK.INK if on else (AK.FG if usable else AK.MUTE), null, false)
	var anchor := _slot_rect(picker_slot + 1)
	draw_colored_polygon(PackedVector2Array([Vector2(anchor.get_center().x - 6, anchor.position.y - 6), Vector2(anchor.get_center().x + 6, anchor.position.y - 6), Vector2(anchor.get_center().x, anchor.position.y)]), Color(0, 0, 0, 0.88))

## The hotbar's rectangle (centred on the bottom edge).
func hotbar_rect() -> Rect2:
	var count := _hotbar_slots().size()
	var width := count * SLOT + (count - 1) * SLOT_GAP
	return Rect2(640.0 - width * 0.5, HOTBAR_BOTTOM - SLOT, width, SLOT)

func _draw_actions() -> void:
	var p := game.player
	var bar := hotbar_rect()
	draw_rect(bar.grow(6), Color(0, 0, 0, 0.72))
	var drawn := _hotbar_slots()
	var hover := get_local_mouse_position()
	for i in range(drawn.size()):
		var r := _slot_rect(i)
		_draw_slot(r, drawn[i])
		if i >= 1 and i <= Hotbar.SLOTS and (r.has_point(hover) or picker_slot == i - 1): draw_rect(r, AK.FG, false, 1.0)
	if not game.simulation_active(): picker_slot = -1
	_draw_picker()
	# Left of the bar: life (and any shield over it).
	var left := Rect2(bar.position.x - 12 - SIDE_BAR, bar.position.y + 14, SIDE_BAR, 16)
	_side_bar(left, "生命", "%d / %d" % [roundi(p.hp), roundi(p.max_hp)], p.hp_ratio(), AK.RED if p.hp_ratio() < 0.3 else AK.HP, true)
	if p.shield > 0.0:
		draw_rect(Rect2(left.position.x, left.position.y - 4, left.size.x * clampf(p.shield / maxf(p.max_hp, 1.0), 0.0, 1.0), 3), Color("bfe8ff"))
	# Under it: elite stage, level and experience (精英化与加点策划案 §4.2); a
	# yellow dot while points wait to be spent.
	var growth := game.progress()
	var lv_text := "%s · Lv %d" % [Progression.ELITE_NAMES[growth.elite], growth.level]
	_text(Vector2(left.position.x, left.end.y + 6), lv_text, 11, AK.FG, _en(), false)
	var exp_ratio := 1.0 if growth.at_cap() else float(growth.exp) / maxf(1.0, growth.exp_needed())
	AK.draw_bar(self, Rect2(left.position.x, left.end.y + 22, left.size.x, 2), exp_ratio, AK.SP, Color(0.08, 0.08, 0.08, 0.95))
	if growth.attribute_points + growth.skill_points > 0:
		draw_circle(Vector2(left.end.x - 4, left.end.y + 13), 3.5, AK.SP)
	# Right of the bar: stamina, then the passive build-up (剑气) or 绝影's recharge.
	var right_x := bar.end.x + 12
	_side_bar(Rect2(right_x, bar.position.y + 6, SIDE_BAR, 10), "体力", str(roundi(p.stamina)), p.stamina / 100.0, Color(0.92, 0.92, 0.92), false)
	var passive := Rect2(right_x, bar.position.y + 34, SIDE_BAR, 10)
	if p.is_amiya():
		var cd := maxf(p.shadow_cooldown, 0.0)
		var ready := cd <= 0.0
		_side_bar(passive, "绝影", "就绪" if ready else "%.1f" % cd, 1.0 - cd / float(SkillTrees.shadow(p.rank("shadow"))[1]), CombatVfx.CYAN, false, ready)
	else:
		var need := p.wave_hits_needed()
		var has := p.has_sword_wave()
		var full := has and p.sword_charge >= need
		_segments(passive, need, p.sword_charge if has else 0, CombatVfx.PURPLE if full else AK.SP)
		_text(Vector2(passive.position.x, passive.position.y - 4), "剑气", 11, AK.FG if has else AK.MUTE, null, false)
		_text(Vector2(passive.end.x - 34, passive.position.y - 4), ("就绪" if full else "%d/%d" % [p.sword_charge, need]) if has else "—", 11, AK.SP if full else AK.FG, _en() if not full else null, false)
		if full:
			var glow := 0.5 + 0.5 * sin(_pulse * TAU * 1.2)
			draw_rect(passive.grow(2), Color(CombatVfx.PURPLE, 0.35 + 0.4 * glow), false, 1.5)
		if p.wolf_timer > 0.0:
			_text(Vector2(passive.position.x, passive.end.y + 6), "狼魂 %.1f" % p.wolf_timer, 11, CombatVfx.PURPLE.lightened(0.3), null, false)

## A labelled bar: name and value above it, the fill below.
func _side_bar(r: Rect2, label: String, value: String, ratio: float, colour: Color, big: bool, glow := false) -> void:
	_text(Vector2(r.position.x, r.position.y - 4), label, 11, AK.FG, null, false)
	var vw := _en().get_string_size(I18n.t(value), HORIZONTAL_ALIGNMENT_LEFT, -1, 12 if big else 11).x
	_text(Vector2(r.end.x - vw, r.position.y - 4), value, 12 if big else 11, colour.lightened(0.2) if glow else AK.FG, _en(), false)
	AK.draw_bar(self, r, clampf(ratio, 0.0, 1.0), colour, Color(0.08, 0.08, 0.08, 0.95))
	if glow:
		var pulse := 0.5 + 0.5 * sin(_pulse * TAU * 1.2)
		draw_rect(r.grow(2), Color(colour, 0.35 + 0.4 * pulse), false, 1.5)

func _segments(r: Rect2, count: int, lit: int, colour: Color) -> void:
	var seg := (r.size.x - (count - 1) * 3.0) / count
	for i in range(count):
		draw_rect(Rect2(r.position.x + i * (seg + 3.0), r.position.y, seg, r.size.y), colour if i < lit else Color(0.08, 0.08, 0.08, 0.95))

## One hotbar slot: glyph, key in the corner, a cost or count badge, and the
## cooldown as a dark curtain that lifts as it recharges.
func _draw_slot(r: Rect2, slot: Dictionary) -> void:
	draw_rect(r, Color("262626"))
	draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.5)), Color("303030"))
	draw_rect(Rect2(r.position.x, r.end.y - 3, r.size.x, 3), slot.colour)
	if slot.get("ready", false):
		var glow := 0.5 + 0.5 * sin(_pulse * TAU * 1.2)
		draw_rect(r.grow(2), Color(AK.SP.r, AK.SP.g, AK.SP.b, 0.45 + 0.4 * glow), false, 2.0)
	if not str(slot.glyph).is_empty(): _draw_glyph(r.get_center() + Vector2(0, 2), slot)
	if slot.get("unavailable", false): draw_rect(r, Color(0, 0, 0, 0.55))
	if not str(slot.key).is_empty():
		var kw := _en().get_string_size(I18n.t(slot.key), HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 6
		draw_rect(Rect2(r.position, Vector2(kw, 14)), Color(0, 0, 0, 0.8))
		_text(r.position + Vector2(3, 11), slot.key, 10, AK.FG, _en() if slot.key != "⇧" else null, false)
	if slot.has("cost"):
		var cost: String = slot.cost
		var cw := _en().get_string_size(I18n.t(cost), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 6
		draw_rect(Rect2(r.end.x - cw, r.position.y, cw, 14), Color.BLACK)
		_text(Vector2(r.end.x - cw + 3, r.position.y + 11), cost, 11, Color.WHITE, _en(), false)
	var cooldown: float = slot.get("cooldown", 0.0)
	if cooldown > 0.0:
		var share := clampf(cooldown / maxf(float(slot.get("cooldown_total", cooldown)), 0.01), 0.0, 1.0)
		draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * share)), Color(0, 0, 0, 0.7))
		var text := "%.1f" % cooldown
		var tw := _en().get_string_size(I18n.t(text), HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		_text(r.get_center() + Vector2(-tw * 0.5, 6), text, 15, Color.WHITE, _en(), false)

func _draw_glyph(c: Vector2, card: Dictionary) -> void:
	var white := Color(0.95, 0.95, 0.95)
	match card.glyph:
		"slash":
			draw_line(c + Vector2(-12, 12), c + Vector2(12, -12), white, 2.4)
			draw_line(c + Vector2(-6, 13), c + Vector2(13, -6), white, 2.4)
			draw_line(c + Vector2(-13, 6), c + Vector2(-7, 12), AK.SP, 2.4)
		"wave":
			draw_arc(c + Vector2(0, 10), 13, PI * 1.1, PI * 1.9, 16, AK.SP, 2.6)
			draw_arc(c + Vector2(0, 12), 8, PI * 1.15, PI * 1.85, 12, white, 2.4)
		"dodge":
			draw_arc(c + Vector2(-8, -8), 16, 0.2, 1.4, 12, white, 2.4)
			draw_line(c + Vector2(-13, 12), c + Vector2(-4, 12), AK.HP, 2.4)
		"flask":
			# The flask's own art (用户 2026-10-10: 消耗品的图标改为原画), 1:1 so
			# the pixels stay crisp; the drawn bottle only if the art is missing.
			var art := ItemIcons.texture_for(BaseCatalog.create_potion(card.potion)) if card.has("potion") else null
			if art != null:
				draw_texture(art, (c - art.get_size() * 0.5).floor() + Vector2(0, -2))
			else:
				draw_rect(Rect2(c + Vector2(-7, -4), Vector2(14, 16)), card.get("colour", AK.GREEN))
				draw_rect(Rect2(c + Vector2(-3, -11), Vector2(6, 7)), white)
		"hand":
			draw_polyline(AK.diamond(c, 11) + PackedVector2Array([c + Vector2(0, -11)]), white, 2.2)
			draw_circle(c, 3, AK.HP)
		"special":
			var texture := ItemIcons.texture_for(card.item)
			if texture != null:
				var size := texture.get_size().min(Vector2(36, 36))
				draw_texture_rect(texture, Rect2(c - size * 0.5, size), false)
			else: draw_colored_polygon(AK.diamond(c, 10), AK.SPECIAL)

# --- Centre: transient messages ------------------------------------------------------

# --- The world: her bars, enemy bars, names, the E prompt ------------------------------

func _draw_world_marks() -> void:
	if not game.simulation_active() and game.modal != "inventory": return
	var p := game.player
	# Enemy bars, shown once hurt (Grim Dawn): tier by form, no names.
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy.game != game or enemy._dead or enemy.health >= enemy.max_health: continue
		var head := game.screen_point(enemy.global_position + Vector3.UP * 1.9)
		var ratio := enemy.health / maxf(enemy.max_health, 1.0)
		if enemy.boss:
			# Grim Dawn's boss tier is lavender: a wider bar in a lavender frame.
			var b := Rect2(head.x - 48, head.y - 4, 96, 8)
			draw_rect(b.grow(2), Color("b49ae8"))
			draw_rect(b.grow(1), Color.BLACK)
			AK.draw_bar(self, b, ratio, Color("e8463a"), Color("1a0606"))
			draw_colored_polygon(AK.star(Vector2(b.position.x - 12, b.get_center().y), 8.0), Color.BLACK)
			draw_colored_polygon(AK.star(Vector2(b.position.x - 12, b.get_center().y), 6.5), Color("b49ae8"))
		elif enemy.elite:
			var r := Rect2(head.x - 32, head.y - 3, 64, 6)
			draw_rect(r.grow(2), Color("b8862e"))
			draw_rect(r.grow(1), Color.BLACK)
			AK.draw_bar(self, r, ratio, Color("e8463a"), Color("1a0606"))
			draw_colored_polygon(AK.star(Vector2(r.position.x - 11, r.get_center().y), 7.0), Color.BLACK)
			draw_colored_polygon(AK.star(Vector2(r.position.x - 11, r.get_center().y), 5.5), AK.SP)
		else:
			AK.draw_bar(self, Rect2(head.x - 20, head.y - 1.5, 40, 3), ratio, AK.RED, Color(0, 0, 0, 0.85))
	# Her bars under her feet: blue life, yellow SP in segments; the ready mark.
	var feet := game.screen_point(p.global_position) + Vector2(0, 14)
	AK.draw_bar(self, Rect2(feet.x - 27, feet.y, 54, 5), p.hp / maxf(p.max_hp, 1.0), AK.RED if p.hp < p.max_hp * 0.3 else AK.HP, Color(0, 0, 0, 0.8))
	if p.has_sword_wave():
		var need := p.wave_hits_needed()
		var seg := (54.0 - (need - 1) * 2.0) / need
		for i in range(need):
			draw_rect(Rect2(feet.x - 27 + i * (seg + 2), feet.y + 6, seg, 4), AK.SP if i < p.sword_charge else Color(0, 0, 0, 0.8))
		if p.sword_charge >= need:
			var top := game.screen_point(p.global_position + Vector3.UP * 2.2)
			draw_colored_polygon(AK.diamond(top, 11), AK.SP)
			draw_colored_polygon(PackedVector2Array([top + Vector2(0, -5), top + Vector2(5, 3), top + Vector2(-5, 3)]), AK.INK)
	_draw_container_names()
	_draw_ground_names()
	# Just the key, no name (用户 2026-10-13: 不要中文label了，只提示e即可).
	if not game.interaction_prompt().is_empty():
		var at := game.screen_point(p.global_position) + Vector2(0, 48)
		draw_rect(Rect2(at.x - 13, at.y - 16, 26, 24), Color(0, 0, 0, 0.8))
		draw_rect(Rect2(at.x - 10, at.y - 13, 20, 18), AK.PAPER)
		_text(at + Vector2(-5, 0), "E", 12, AK.INK, _en(), false)

## Bars over the box being opened or searched, and nothing else: no names
## over points of interest (用户 2026-10-12). The opening bar while the lid is
## worked; then the current item's bar with one pip per item underneath,
## filled for each found.
func _draw_container_names() -> void:
	if not game.simulation_active(): return
	for node in get_tree().get_nodes_in_group("loot_containers"):
		var box := node as LootContainer
		if box.game != game or box.global_position.distance_to(game.player.global_position) > 7.0: continue
		var point := game.screen_point(box.global_position + Vector3.UP * 1.4)
		var opening := box.progress()
		if opening >= 0.0:
			draw_rect(Rect2(point.x - 32, point.y - 2, 64, 8), Color(0, 0, 0, 0.75))
			AK.draw_bar(self, Rect2(point.x - 30, point.y, 60, 4), opening, AK.SP)
			continue
		var search := box.search_state()
		if search.is_empty(): continue
		var total: int = search.total
		var pip := clampf(60.0 / total - 2.0, 3.0, 8.0)
		var row := total * (pip + 2.0) - 2.0
		draw_rect(Rect2(point.x - maxf(row, 60.0) * 0.5 - 2, point.y - 2, maxf(row, 60.0) + 4, 15), Color(0, 0, 0, 0.75))
		if float(search.current) >= 0.0: AK.draw_bar(self, Rect2(point.x - 30, point.y, 60, 4), float(search.current), AK.SP)
		for i in range(total):
			var at := Vector2(point.x - row * 0.5 + i * (pip + 2.0), point.y + 7)
			draw_rect(Rect2(at, Vector2(pip, 4)), AK.SP if i < int(search.found) else Color(1, 1, 1, 0.22))

## Hold Alt: names of the items on the ground, in rarity colour (PoE / Grim Dawn).
## Name plates over ground items, the Grim Dawn way (用户 2026-10-10): always
## shown for items the pickup filter keeps, every item while Alt is held.
## Plates that would overlap are pushed up so each stays readable and
## clickable; GameManager asks loot_label_at() which plate a click hit.
const PLATE_FONT := 13
const PLATE_PAD := 6.0
const PLATE_HEIGHT := 20.0
## [Rect2, Loot] pairs from the last draw, topmost last.
var _loot_plates: Array = []

func _draw_ground_names() -> void:
	_loot_plates.clear()
	if not game.simulation_active(): return
	var all := Input.is_action_pressed("show_items")
	var shown: Array = []
	for node in get_tree().get_nodes_in_group("loot"):
		var loot := node as Loot
		if loot == null or loot.game != game or loot.item == null or loot.is_search_point or loot.is_queued_for_deletion(): continue
		var kept := game.passes_pickup_filter(loot.item)
		if not kept and not all: continue
		shown.append([loot, kept])
	# Nearest to the bottom of the screen first, so plates stack upward.
	var anchors := {}
	for entry in shown: anchors[entry[0]] = game.screen_point(entry[0].global_position + Vector3.UP * 1.0)
	shown.sort_custom(func(a, b): return anchors[a[0]].y > anchors[b[0]].y)
	var placed: Array[Rect2] = []
	var hover := get_local_mouse_position()
	for entry in shown:
		var loot: Loot = entry[0]
		var label := loot.item.display_name() + loot.item.stack_suffix() + ("（封印）" if loot.sealed else "")
		var width := _font().get_string_size(I18n.t(label), HORIZONTAL_ALIGNMENT_LEFT, -1, PLATE_FONT).x + PLATE_PAD * 2.0
		var point: Vector2 = anchors[loot]
		var rect := Rect2(point.x - width * 0.5, point.y - PLATE_HEIGHT, width, PLATE_HEIGHT)
		for i in range(12):
			var hit := false
			for other in placed:
				if other.grow(1.0).intersects(rect):
					rect.position.y = other.position.y - PLATE_HEIGHT - 2.0
					hit = true
			if not hit: break
		placed.append(rect)
		_loot_plates.append([rect, loot])
		var colour := loot.item.rarity_color()
		var lit := rect.has_point(hover)
		draw_rect(rect, Color(0, 0, 0, 0.82 if entry[1] else 0.6))
		draw_rect(Rect2(rect.position, Vector2(3, rect.size.y)), colour)
		if lit: draw_rect(rect, colour, false, 1.0)
		var text_colour := colour if entry[1] else colour.darkened(0.35)
		_text(Vector2(rect.position.x + PLATE_PAD, rect.end.y - 5), label, PLATE_FONT, text_colour.lightened(0.25) if lit else text_colour, null, false)

## The ground item whose name plate is under `point` (HUD coordinates).
func loot_label_at(point: Vector2) -> Loot:
	for i in range(_loot_plates.size() - 1, -1, -1):
		var entry: Array = _loot_plates[i]
		if (entry[0] as Rect2).has_point(point) and is_instance_valid(entry[1]): return entry[1]
	return null

# --- Minimap caching (unchanged logic) -------------------------------------------------

func _cache_minimap() -> void:
	_map_source = game.world_map._generated_root
	_all_triangles = PackedVector2Array()
	_triangle_keys = PackedVector2Array()
	for face in game.world_map.minimap_faces:
		for i in range(1, face.size() - 1):
			var corners: Array[Vector2] = [face[0], face[i], face[i + 1]]
			for p in corners: _all_triangles.append(p)
			_triangle_keys.append((corners[0] + corners[1] + corners[2]) / 3.0)
	_all_outline = PackedVector2Array()
	_outline_keys = PackedVector2Array()
	for edge in game.world_map.terrain_edges:
		for i in range(1, edge.size()):
			_all_outline.append(edge[i - 1])
			_all_outline.append(edge[i])
			_outline_keys.append((edge[i - 1] + edge[i]) * 0.5)
	_mapped_cells = -1
	_refresh_mapped_area()

func _refresh_mapped_area() -> void:
	var cells: int = game.fog.revealed_cells()
	var now := Time.get_ticks_msec()
	if cells == _mapped_cells: return
	if _mapped_cells >= 0 and now - _mapped_stamp < 200: return
	_mapped_cells = cells
	_mapped_stamp = now
	var vertices := PackedVector2Array()
	for t in range(_triangle_keys.size()):
		var key := _triangle_keys[t]
		if not game.fog.is_revealed(key.x, key.y): continue
		vertices.append(_all_triangles[t * 3])
		vertices.append(_all_triangles[t * 3 + 1])
		vertices.append(_all_triangles[t * 3 + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	_map_mesh = ArrayMesh.new()
	if not vertices.is_empty(): _map_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_map_outline = PackedVector2Array()
	for s in range(_outline_keys.size()):
		var key := _outline_keys[s]
		if not game.fog.is_revealed(key.x, key.y): continue
		_map_outline.append(_all_outline[s * 2])
		_map_outline.append(_all_outline[s * 2 + 1])
