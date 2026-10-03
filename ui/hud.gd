class_name Hud
extends Control

## Ported from DownfallPrototype.OnGUI() as real Control/Label nodes instead
## of immediate-mode GUI calls — see downfall-godot/README.md for why.

var game: GameManager

var _status_label: Label
var _charge_label: Label
var _stats_label: Label
var _charge_time := 0.0
var _seed_label: Label
var _loot_label: Label
var _message_label: Label
var _map_source: NavigationRegion3D
var _map_mesh: ArrayMesh
var _map_outline := PackedVector2Array()
var _all_triangles := PackedVector2Array()
var _triangle_keys := PackedVector2Array()
var _all_outline := PackedVector2Array()
var _outline_keys := PackedVector2Array()
var _mapped_cells := -1
var _mapped_stamp := 0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel := _make_panel(Vector2(15, 15), Vector2(520, 300))
	add_child(panel)

	var title := Label.new()
	title.text = "DOWNFALL / 罗德岛外勤"
	title.position = Vector2(15, 8)
	panel.add_child(title)

	_status_label = Label.new()
	_status_label.position = Vector2(15, 34)
	panel.add_child(_status_label)

	_seed_label = Label.new()
	_seed_label.position = Vector2(15, 88)
	panel.add_child(_seed_label)

	_loot_label = Label.new()
	_loot_label.position = Vector2(15, 113)
	panel.add_child(_loot_label)

	_stats_label = Label.new()
	_stats_label.position = Vector2(15, 165)
	_stats_label.add_theme_font_size_override("font_size", 14)
	panel.add_child(_stats_label)

	_charge_label = Label.new()
	_charge_label.position = Vector2(15, 218)
	panel.add_child(_charge_label)

	var help := Label.new()
	help.text = "右键移动 · 左键攻击 · Shift 闪避\nQ 药瓶 · E 交互 · I 背包 · B 安全袋"
	help.position = Vector2(15, 246)
	panel.add_child(help)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_message_label = Label.new()
	_message_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_message_label.position = Vector2(-560, -65)
	_message_label.custom_minimum_size = Vector2(1120, 50)
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_message_label)

func _make_panel(pos: Vector2, size: Vector2) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.75)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _process(_delta: float) -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.player):
		return
	visible = not game.in_base and game.modal not in ["inventory", "build", "route", "gild"]
	queue_redraw()
	var p := game.player
	# Flasks by the first character of their name, in the order Q uses them (§4.3).
	var belt := " ".join(game.potion_belt.map(func(t): return BaseCatalog.POTIONS[t].name.left(1)))
	var status := "生命 %d / %d%s   体力 %d   药瓶 %d（%s）\n区段 %d · 近战双剑" % [roundi(maxf(p.hp, 0)), roundi(p.max_hp), ("  护盾 %d" % roundi(p.shield)) if p.shield > 0 else "", int(p.stamina), game.potions, belt, game.floor_number]
	# Contamination only where it moves (§4.1): the mine, the deep route, ore in the pack.
	if game.contamination_visible():
		status += "   污染 %d → 本段 +%.2f/s" % [roundi(game.current_contamination()), game.contamination_rate()]
	_status_label.text = status
	_charge_label.visible = p.has_sword_wave()
	var needed := p.wave_hits_needed()
	_charge_label.text = "◇ 幼狼之牙  " + "■ ".repeat(p.sword_charge) + "□ ".repeat(maxi(0, needed - p.sword_charge)) + ("  下一刀：剑气" if p.sword_charge >= needed else "")
	if game.simulation_active(): _charge_time += _delta
	_charge_label.modulate = CombatVfx.LIGHT if p.sword_charge >= needed else CombatVfx.BLUE
	if p.sword_charge >= needed: _charge_label.modulate.a = 0.75 + 0.25 * sin(_charge_time * TAU * 2)
	var counts := RelicCatalog.school_counts(game.builds)
	var schools: Array[String] = []
	for school in counts:
		if counts[school] > 0: schools.append("%s%d" % [RelicCatalog.school_name(school), counts[school]])
	_stats_label.text = "攻 %d  法 %d  防 %d  抗 %d  攻速 %d  暴 %d%%\n构筑 %s" % [roundi(p.attack_power()), roundi(p.arts_power()), roundi(p.defense_value()), roundi(p.resistance()),
		roundi(p.current_aspd()), roundi(p.crit_rate() * 100), " ".join(schools) if not schools.is_empty() else "无"]
	_seed_label.text = "%s · 警戒 %d / 100（敌伤 +%d%%）" % [FieldCatalog.REGIONS[game.region_id].name, game.pressure, game.pressure / 1.6]
	_loot_label.text = "背包 %d / 60 格 · 构筑 %d 件 · 待交付 %d\n%s" % [game.inventory.occupied_cells(), game.builds.size(), game.run_gold, "本段有撤离点：绿色标记 E 撤离" if game.is_extraction_floor() else "下个固定撤离：第 %d 区段" % ((game.floor_number / 3 + 1) * 3)]
	_message_label.text = game.message if game.message_timer > 0 else "橙：强化 / 金：点金 / 蓝：深入 / 绿：撤离 / 浅蓝菱形：战斗缴获"

func map_point(position: Vector3) -> Vector2:
	# The panel is 200px wide with a 20px margin, so 80px covers the field's
	# half-extent however large the region's layout is.
	var scale := 80.0 / maxf(game.world_map.map_extent, 1.0)
	var centre: Vector3 = game.world_map.map_center
	return Vector2(1135 - (position.x - centre.x) * scale, 120 - (position.z - centre.z) * scale)

func _draw() -> void:
	if not is_instance_valid(game) or game.in_base or not is_instance_valid(game.world_map._generated_root): return
	draw_style_box(_map_style(), Rect2(1035, 20, 200, 200))
	if _map_source != game.world_map._generated_root: _cache_minimap()
	_refresh_mapped_area()
	# Both are empty on the first frames of a segment, before anything has been
	# mapped, and draw_multiline asserts on an empty array.
	if _map_mesh.get_surface_count() > 0:
		draw_mesh(_map_mesh, null, Transform2D.IDENTITY, Color("52616a"))
	if _map_outline.size() >= 2:
		draw_multiline(_map_outline, Color("839291"), 0.65)
	# Devices and beacons are map knowledge: they appear once the player has
	# been near enough to have found them, and stay once found.
	var markers: Array = [game.world_map.buff_device_node, game.world_map.gilding_device_node, game.world_map.exit_node, game.world_map.vault_node]
	var colors := [Color("ef9b42"), Color("f9d86f"), Color("63eca7"), Color("d8b24a")]
	for i in range(markers.size()):
		if is_instance_valid(markers[i]) and markers[i].visible and game.fog.is_point_revealed(markers[i].position):
			draw_circle(map_point(markers[i].position), 4, colors[i])
	for i in range(game.world_map.mechanism_nodes.size()):
		var node: Node3D = game.world_map.mechanism_nodes[i]
		if not is_instance_valid(node) or not game.fog.is_point_revealed(node.position): continue
		draw_circle(map_point(node.position), 3, Color("55627a") if game._mechanisms_done.has(i) else Color("b47ae0"))
	for node in game.world_map.route_nodes:
		if is_instance_valid(node) and game.fog.is_point_revealed(node.position):
			draw_circle(map_point(node.position), 3, Color("69b7ea"))
	# Relic caches (局内构筑与数值策划案 §8.2): blue combat cache, gold vault relic.
	for node in get_tree().get_nodes_in_group("relic_caches"):
		var cache := node as RelicCache
		if cache.game == game and game.fog.is_point_revealed(cache.position):
			draw_circle(map_point(cache.position), 3, Color("8a8f96") if cache.sealed else (Color("f3b04a") if cache.source == "vault" else Color("72b8ff")))
	draw_circle(map_point(game.player.position), 4, Color.WHITE)

## Panel-space geometry is computed once; which of it is drawn is decided per
## refresh from the fog. Each triangle and each outline segment keeps the world
## point it is judged by, so the filter never has to touch the source data.
func _cache_minimap() -> void:
	_map_source = game.world_map._generated_root
	_all_triangles = PackedVector2Array()
	_triangle_keys = PackedVector2Array()
	for face in game.world_map.minimap_faces:
		for i in range(1, face.size() - 1):
			var corners: Array[Vector2] = [face[0], face[i], face[i + 1]]
			for p in corners:
				_all_triangles.append(map_point(Vector3(p.x, 0, p.y)))
			_triangle_keys.append((corners[0] + corners[1] + corners[2]) / 3.0)
	_all_outline = PackedVector2Array()
	_outline_keys = PackedVector2Array()
	for edge in game.world_map.terrain_edges:
		for i in range(1, edge.size()):
			_all_outline.append(map_point(Vector3(edge[i - 1].x, 0, edge[i - 1].y)))
			_all_outline.append(map_point(Vector3(edge[i].x, 0, edge[i].y)))
			_outline_keys.append((edge[i - 1] + edge[i]) * 0.5)
	_mapped_cells = -1
	_refresh_mapped_area()

## Rebuilding the drawn arrays is the expensive part, and walking reveals a
## couple of cells at a time, so this throttles rather than rebuilding every
## frame. A fraction of a second of lag filling the map in is not noticeable.
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
	if not vertices.is_empty():
		_map_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	_map_outline = PackedVector2Array()
	for s in range(_outline_keys.size()):
		var key := _outline_keys[s]
		if not game.fog.is_revealed(key.x, key.y): continue
		_map_outline.append(_all_outline[s * 2])
		_map_outline.append(_all_outline[s * 2 + 1])

func _map_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.04, 0.07, 0.85)
	return style
