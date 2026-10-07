class_name Hud
extends Control

## The field HUD (界面策划案 v1.1 §3): MMO layout, Arknights look.
##   top left     floor plate, region, 赤金, relics, contamination; effect badges
##   top right    panel buttons (I R M J) and pause, the minimap, the order tracker
##   bottom left  PRTS broadcasts only
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
const CARD := Vector2(64, 82)

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
	_pulse += delta
	queue_redraw()

func _font() -> Font: return AK.cn()
func _en() -> Font: return AK.en()

func _text(at: Vector2, text: String, size: int, color: Color, font: Font = null, outline := true) -> float:
	var f := font if font != null else _font()
	if outline: draw_string_outline(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, 0.85))
	draw_string(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

func _draw() -> void:
	if not is_instance_valid(game) or game.in_base or game.in_camp: return
	if not is_instance_valid(game.world_map._generated_root): return
	_draw_world_marks()
	if game.modal == "map":
		# Diablo's overlay map (界面策划案 #5): lines straight over the paused
		# field; the minimap, tracker and pickup names step aside.
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.016, 0.024, 0.031, 0.62))
		_draw_top_bar()
		_draw_broadcasts()
		_draw_actions()
		_draw_map(BIG_MAP_RECT, true)
		_draw_map_info()
		return
	_draw_top_bar()
	_draw_map(MAP_RECT, false)
	if SystemScreens.settings.get("tracker", true): _draw_orders()
	if SystemScreens.settings.get("broadcasts", true): _draw_broadcasts()
	_draw_actions()
	_draw_message()

# --- Top left ---------------------------------------------------------------------

func _draw_top_bar() -> void:
	var code := AK.floor_code(game.region_id, game.floor_number)
	draw_rect(Rect2(0, 0, 640, 44), Color(0, 0, 0, 0.72))
	draw_rect(Rect2(0, 0, 88, 44), AK.PAPER)
	_text(Vector2(10, 14), "FLOOR", 9, AK.INK, _en(), false)
	_text(Vector2(10, 38), code, 20, AK.INK, _en(), false)
	var region: String = FieldCatalog.REGIONS[game.region_id].name
	_text(Vector2(100, 22), region, 14, AK.FG)
	var x := 100.0 + _font().get_string_size(region, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 24
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
	var w := _font().get_string_size(explored, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
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
	var cw := _en().get_string_size(code, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 20
	draw_rect(Rect2(right - cw, top, cw, 28), AK.PAPER)
	_text(Vector2(right - cw + 10, top + 22), code, 20, AK.INK, _en(), false)
	var region: String = FieldCatalog.REGIONS[game.region_id].name
	_text(Vector2(right - _font().get_string_size(region, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x, top + 54), region, 18, AK.FG)
	var explored := "已探索 %d%%" % roundi(game.fog.revealed_fraction() * 100.0)
	_text(Vector2(right - _font().get_string_size(explored, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x, top + 74), explored, 12, AK.MUTE)
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
		var lw := _en().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		_text(Vector2(right - w + (w - lw) * 0.5, y + 13), label, 12, AK.INK if current or camp else (AK.DIM if n < game.floor_number else AK.FG), _en() if not camp else _font(), false)
		var name: String = names.get(n, "")
		if current and game.is_extraction_floor(): name += " · 撤离"
		if not name.is_empty():
			var nw := _font().get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			_text(Vector2(right - w - 8 - nw, y + 13), name, 11, AK.DIM if n < game.floor_number else AK.FG)
		y += 20

## The tracker shows orders only (用户 2026-10-06): department, what, carried / needed.
func _draw_orders() -> void:
	var rows := game.order_progress()
	if rows.is_empty(): return
	var y := TRACK_TOP
	var x := MAP_RECT.position.x
	draw_rect(Rect2(x, y, MAP_RECT.size.x, 24), Color(0, 0, 0, 0.78))
	draw_rect(Rect2(x + 6, y + 5, 34, 14), AK.PAPER)
	_text(Vector2(x + 10, y + 17), "订单", 11, AK.INK, null, false)
	_text(Vector2(x + 48, y + 17), FieldCatalog.REGIONS[game.region_id].name.split(" · ")[0], 12, AK.FG, null, false)
	y += 26
	for row in rows:
		draw_rect(Rect2(x, y, MAP_RECT.size.x, 22), Color(0, 0, 0, 0.55))
		draw_rect(Rect2(x, y, 4, 22), row.color)
		_text(Vector2(x + 10, y + 16), row.dept, 11, AK.MUTE, null, false)
		_text(Vector2(x + 52, y + 16), row.what, 12, AK.FG, null, false)
		var count := "%d / %d" % [row.have, row.need]
		var w := _en().get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		_text(Vector2(x + MAP_RECT.size.x - w - 8, y + 16), count, 13, AK.GREEN if row.have >= row.need else AK.FG, _en(), false)
		y += 24

# --- Bottom left: PRTS broadcasts only -----------------------------------------------

func _draw_broadcasts() -> void:
	var r := Rect2(12, 708 - 146, 370, 146)
	draw_rect(r, Color(0, 0, 0, 0.6))
	draw_rect(Rect2(r.position.x + 8, r.position.y + 7, 38, 15), AK.HP)
	_text(r.position + Vector2(12, 19), "PRTS", 10, Color.WHITE, _en(), false)
	var lines: Array = game.prts_log.slice(maxi(0, game.prts_log.size() - 6))
	for i in range(lines.size()):
		var y := r.position.y + 42 + i * 18
		var w := _text(Vector2(r.position.x + 10, y), lines[i][0], 10, AK.DIM, _en(), false)
		_text(Vector2(r.position.x + 16 + w, y), lines[i][1], 12, AK.FG, null, false)

# --- Bottom right: stamina and the action cards ----------------------------------------

func _draw_actions() -> void:
	var p := game.player
	var cards: Array = []
	cards.append({"label": "连斩", "key": "LMB", "glyph": "slash", "colour": AK.FG})
	if p.has_sword_wave():
		var need := p.wave_hits_needed()
		cards.append({"label": "剑气", "key": "", "glyph": "wave", "colour": AK.SP, "cost": "就绪" if p.sword_charge >= need else "%d/%d" % [p.sword_charge, need], "cost_colour": AK.SP, "ready": p.sword_charge >= need})
	cards.append({"label": "闪避", "key": "⇧", "glyph": "dodge", "colour": AK.HP, "cost": str(roundi(p.dash_cost())), "cooldown": maxf(p._dash_cooldown, 0.0)})
	cards.append({"label": "药剂", "key": "Q", "glyph": "flask", "colour": AK.GREEN, "cost": str(game.carried_potions().size())})
	cards.append({"label": "交互", "key": "E", "glyph": "hand", "colour": AK.FG})
	for item in p.equipped.values():
		if item != null and not item.special.is_empty():
			cards.append({"label": item.item_name.left(4), "key": "", "glyph": "special", "colour": AK.SPECIAL, "cost": "特", "cost_colour": AK.SPECIAL, "item": item})
	var x := 1268.0 - cards.size() * (CARD.x + 4) + 4
	var y := 708.0 - CARD.y
	# Stamina, where Arknights keeps the deployment cost.
	var box := Rect2(1268 - 182, y - 44, 182, 38)
	draw_rect(box, Color(0, 0, 0, 0.82))
	draw_rect(Rect2(box.position, Vector2(60, box.size.y)), AK.PAPER)
	_text(box.position + Vector2(8, 14), "STAMINA", 8, AK.INK, _en(), false)
	_text(box.position + Vector2(8, 31), "体力", 12, AK.INK, null, false)
	_text(box.position + Vector2(70, 26), str(roundi(p.stamina)), 22, AK.FG, _en(), false)
	AK.draw_bar(self, Rect2(box.position.x + 70, box.end.y - 7, 104, 3), p.stamina / 100.0, Color.WHITE)
	for card in cards:
		_draw_card(Rect2(x, y, CARD.x, CARD.y), card)
		x += CARD.x + 4

func _draw_card(r: Rect2, card: Dictionary) -> void:
	draw_rect(r, Color("262626"))
	draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.5)), Color("333333"))
	draw_rect(Rect2(r.position.x, r.end.y - 3, r.size.x, 3), card.colour)
	if card.get("ready", false):
		var glow := 0.5 + 0.5 * sin(_pulse * TAU * 1.2)
		draw_rect(r.grow(2), Color(AK.SP.r, AK.SP.g, AK.SP.b, 0.45 + 0.4 * glow), false, 2.0)
	_draw_glyph(r.position + Vector2(r.size.x * 0.5, 30), card)
	draw_rect(Rect2(r.position.x, r.end.y - 22, r.size.x, 19), Color(0, 0, 0, 0.65))
	var text: String = ("%s %s" % [card.key, card.label]).strip_edges()
	var w := _font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	_text(Vector2(r.get_center().x - w * 0.5, r.end.y - 8), text, 11, AK.FG, null, false)
	if card.has("cost"):
		var cost: String = card.cost
		var cw := _en().get_string_size(cost, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 8
		draw_rect(Rect2(r.end.x - cw, r.position.y, cw, 17), card.get("cost_colour", Color.BLACK))
		_text(Vector2(r.end.x - cw + 4, r.position.y + 13), cost, 12, AK.INK if card.has("cost_colour") else Color.WHITE, _en(), false)
	var cooldown: float = card.get("cooldown", 0.0)
	if cooldown > 0.0:
		draw_rect(r, Color(0, 0, 0, 0.65))
		_text(r.get_center() + Vector2(-12, 6), "%.1f" % cooldown, 15, Color.WHITE, _en(), false)

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
			draw_rect(Rect2(c + Vector2(-7, -4), Vector2(14, 16)), AK.GREEN)
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

func _draw_message() -> void:
	if game.message_timer <= 0.0 or game.message.is_empty(): return
	var w := _font().get_string_size(game.message, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var at := Vector2(640 - w * 0.5, 600)
	draw_rect(Rect2(at.x - 12, at.y - 18, w + 24, 26), Color(0, 0, 0, 0.7))
	_text(at, game.message, 15, AK.FG, null, false)

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
		if enemy.elite:
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
	var prompt := game.interaction_prompt()
	if not prompt.is_empty():
		var w := _font().get_string_size(prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var at := game.screen_point(p.global_position) + Vector2(-w * 0.5 + 12, 48)
		draw_rect(Rect2(at.x - 30, at.y - 16, w + 40, 24), Color(0, 0, 0, 0.8))
		draw_rect(Rect2(at.x - 27, at.y - 13, 20, 18), AK.PAPER)
		_text(at + Vector2(-22, 0), "E", 12, AK.INK, _en(), false)
		_text(at, prompt, 13, AK.FG, null, false)

## Names over nearby points of interest, with the opening bar. Drawn here, not
## as Label3D, because the world renders at 640×360 where 3D text is unreadable.
func _draw_container_names() -> void:
	if not game.simulation_active(): return
	for node in get_tree().get_nodes_in_group("loot_containers"):
		var box := node as LootContainer
		if box.game != game or box.global_position.distance_to(game.player.global_position) > 7.0: continue
		var point := game.screen_point(box.global_position + Vector3.UP * 1.2)
		var label := box.status_text()
		var width := _font().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_rect(Rect2(point.x - width * 0.5 - 6, point.y - 15, width + 12, 20), Color(0, 0, 0, 0.75))
		_text(Vector2(point.x - width * 0.5, point.y), label, 13, Color("8a8f96") if box.opened or box.sealed else Color("f3dca0"), null, false)
		var progress := box.progress()
		if progress >= 0.0: AK.draw_bar(self, Rect2(point.x - 30, point.y + 8, 60, 4), progress, AK.SP)

## Hold Alt: names of the items on the ground, in rarity colour (PoE / Grim Dawn).
func _draw_ground_names() -> void:
	if not Input.is_key_pressed(KEY_ALT) or not game.simulation_active(): return
	for node in get_tree().get_nodes_in_group("loot"):
		var loot := node as Loot
		if loot.game != game or loot.item == null or loot.is_search_point: continue
		var point := game.screen_point(loot.global_position + Vector3.UP * 0.8)
		var label := loot.item.display_name() + loot.item.stack_suffix()
		var width := _font().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_rect(Rect2(point.x - width * 0.5 - 6, point.y - 15, width + 12, 20), Color(0, 0, 0, 0.75))
		draw_rect(Rect2(point.x - width * 0.5 - 6, point.y - 15, 3, 20), loot.item.rarity_color())
		_text(Vector2(point.x - width * 0.5, point.y), label, 13, loot.item.rarity_color(), null, false)

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
