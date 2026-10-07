class_name InventoryPanel
extends Control

## 干员 · 背包 (界面策划案 v1.1 #2, 用户 2026-10-06): one centred, wide and short
## window in three flat columns, after Grim Dawn / Diablo —
##   operator, paper doll and the skill | pack, safe bag, 赤金 | attributes.
## Hovering an item floats its tooltip beside it, with the worn item of the same
## slot alongside. Drag between cells, the safe bag and the slots; dragging out
## of the window asks before dropping. Right click equips / unequips / drinks,
## Ctrl+click moves between pack and safe bag, Delete drops, Alt shows affix
## ranges. No 战力, no value-at-stake line, no key hints (用户 2026-10-05/06).

const CELL := 40
const INSURED := Color("4fd1c5")
const WINDOW := Rect2(80, 125, 1120, 470)

var game: GameManager
var panel: PanelContainer
var body: HBoxContainer
var selected: Item
var selected_container: ItemContainer
var hovered: Item
var hovered_container: ItemContainer
var _hover_rect := Rect2()
var _float: HBoxContainer
var _actions: HBoxContainer
var _detail := false
var _confirm: ConfirmationDialog
var _pending_drop: Item
var _pending_from: ItemContainer
var _drag_item: Item
var _drag_from: ItemContainer
var _drag_from_equip := false
var _last_pointer := Vector2.ZERO
var _pointer_known := false
static var _portrait: Texture2D

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	panel.position = WINDOW.position
	panel.size = WINDOW.size
	panel.add_theme_stylebox_override("panel", AK.box(Color(0.063, 0.063, 0.063, 0.97), AK.LINE_2, 1))
	add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	panel.add_child(outer)
	outer.add_child(_title_bar())
	body = HBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body)
	_float = HBoxContainer.new()
	_float.add_theme_constant_override("separation", 6)
	_float.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_float.z_index = 20
	_float.visible = false
	add_child(_float)
	_confirm = ConfirmationDialog.new()
	_confirm.title = "丢弃物品"
	_confirm.ok_button_text = "丢到地面"
	_confirm.cancel_button_text = "取消"
	_confirm.confirmed.connect(func():
		if _pending_drop != null: game.drop_item(_pending_drop, _pending_from)
		_pending_drop = null
		_rebuild())
	add_child(_confirm)

func _title_bar() -> Control:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", AK.box(Color("0c0c0c"), Color.TRANSPARENT, 0, 0))
	bar.custom_minimum_size.y = 52
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bar.add_child(row)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 6
	row.add_child(spacer)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -2)
	titles.add_child(AK.label("OPERATOR · INVENTORY", 10, AK.MUTE, AK.en()))
	titles.add_child(AK.label("干员 · 背包", 20, AK.FG))
	row.add_child(titles)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(fill)
	var close := AK.button("✕", "ghost", 16)
	close.custom_minimum_size = Vector2(52, 52)
	close.pressed.connect(game_close)
	row.add_child(close)
	return bar

func game_close() -> void:
	if is_instance_valid(game): game.close_modal()

func open() -> void:
	selected = null
	hovered = null
	show()
	_rebuild()

func _process(_delta: float) -> void:
	if not visible: return
	var detail := Input.is_key_pressed(KEY_ALT)
	if detail != _detail:
		_detail = detail
		_refresh_tooltip()

func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_last_pointer = event.position
		_pointer_known = true

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event.pressed or event.echo: return
	if event.keycode in [KEY_DELETE, KEY_X] and selected != null and selected_container != null:
		ask_drop(selected, selected_container)
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible and is_instance_valid(_confirm):
		_confirm.hide()
		_pending_drop = null
		if is_instance_valid(_float): _float.visible = false
	if what == NOTIFICATION_DRAG_END and _drag_item != null:
		var item := _drag_item
		var from := _drag_from
		var from_equip := _drag_from_equip
		_drag_item = null
		if not get_viewport().gui_is_drag_successful() and visible and not panel.get_global_rect().has_point(_last_pointer):
			if from_equip:
				if game.unequip_to_pack(item): ask_drop(item, game.inventory)
			elif from != null: ask_drop(item, from)

func _rebuild() -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	body.add_child(_operator_column())
	body.add_child(_divider())
	body.add_child(_pack_column())
	body.add_child(_divider())
	body.add_child(_stats_column())
	_fit_window()
	_refresh_tooltip()

## Flat and centred (用户 2026-10-06): 1120×470 for the starting pack, wider
## and taller only as far as a larger pack needs (icons stay 1:1 at 40 px).
func _fit_window() -> void:
	var w := 400.0 + 1 + maxf(400.0, game.inventory.width * CELL + 24) + 1 + 318
	var h := 52.0 + 50 + game.inventory.height * CELL + 36 + game.safe_bag.height * CELL + 16
	var size := Vector2(maxf(WINDOW.size.x, w), maxf(WINDOW.size.y, h))
	panel.size = size
	panel.position = ((Vector2(1280, 720) - size) * 0.5).floor()

func _divider() -> ColorRect:
	var line := ColorRect.new()
	line.color = AK.LINE
	line.custom_minimum_size.x = 1
	return line

# --- Left: operator, paper doll, skill -------------------------------------------------

func _operator_column() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 400
	column.add_theme_constant_override("separation", 6)
	var doll := Control.new()
	doll.custom_minimum_size = Vector2(400, 290)
	doll.clip_contents = true
	column.add_child(doll)
	var back := ColorRect.new()
	back.color = Color("151515")
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	doll.add_child(back)
	var head := HBoxContainer.new()
	head.position = Vector2(12, 10)
	head.add_theme_constant_override("separation", 8)
	doll.add_child(head)
	var cls := PanelContainer.new()
	cls.add_theme_stylebox_override("panel", AK.box(Color.BLACK))
	cls.custom_minimum_size = Vector2(40, 40)
	var mark := AK.label("近卫", 12, AK.FG)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cls.add_child(mark)
	head.add_child(cls)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -3)
	names.add_child(AK.label("★★★★★", 11, AK.SP))
	names.add_child(AK.label("拉普兰德", 19, AK.FG))
	names.add_child(AK.label("GUARD · LORD", 9, AK.MUTE, AK.en()))
	head.add_child(names)
	if _portrait == null and ResourceLoader.exists("res://ui/art/lappland_portrait.png"): _portrait = load("res://ui/art/lappland_portrait.png")
	if _portrait != null:
		var image := TextureRect.new()
		image.texture = _portrait
		image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.position = Vector2(116, 50)
		image.size = Vector2(168, 168)
		doll.add_child(image)
	var spots := {Item.Category.WEAPON: Rect2(12, 90, 110, 64), Item.Category.ARMOR: Rect2(282, 46, 106, 106), Item.Category.TRINKET: Rect2(282, 174, 62, 62)}
	for category in spots:
		var slot := EquipSlot.new()
		slot.panel = self
		slot.category = category
		slot.item = game.player.equipped.get(category)
		slot.position = spots[category].position
		slot.custom_minimum_size = spots[category].size
		slot.size = spots[category].size
		doll.add_child(slot)
		var tag := AK.label(Item.CATEGORY_NAMES[category], 11, AK.MUTE)
		tag.position = spots[category].position + Vector2(0, spots[category].size.y + 2)
		doll.add_child(tag)
	var skill := PanelContainer.new()
	skill.add_theme_stylebox_override("panel", AK.box(AK.PLATE_2, Color.TRANSPARENT, 0, 10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	skill.add_child(row)
	var icon := ColorRect.new()
	icon.color = Color.BLACK
	icon.custom_minimum_size = Vector2(44, 44)
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 6)
	title.add_child(AK.label("幼狼之牙", 14, AK.FG))
	title.add_child(AK.tag("攻击回复", AK.GREEN))
	title.add_child(AK.tag("自动触发", AK.PAPER))
	text.add_child(title)
	var desc := AK.label("双剑三段连斩，每次命中回复 1 点技力；技力满后，下一次攻击放出剑气，造成法术伤害。", 12, AK.FG)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = 300
	text.add_child(desc)
	row.add_child(text)
	var pad := MarginContainer.new()
	for side in ["left", "right"]: pad.add_theme_constant_override("margin_" + side, 12)
	pad.add_child(skill)
	column.add_child(pad)
	return column

# --- Middle: pack, safe bag, 赤金 ---------------------------------------------------------

func _pack_column() -> Control:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top"]: margin.add_theme_constant_override("margin_" + side, 12)
	margin.custom_minimum_size.x = maxf(400.0, game.inventory.width * CELL + 24)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	column.add_child(head)
	head.add_child(AK.section("背包", "%d / %d" % [game.inventory.occupied_cells(), game.inventory.cell_count()]))
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(fill)
	for i in range(GameManager.PICKUP_FILTER_NAMES.size()):
		var b := AK.button(GameManager.PICKUP_FILTER_NAMES[i], "blue" if game.pickup_filter == i else "ghost", 11)
		var index := i
		b.pressed.connect(func():
			while game.pickup_filter != index: game.cycle_pickup_filter()
			_rebuild())
		head.add_child(b)
	var sort := AK.button("整理", "plain", 11)
	sort.pressed.connect(func(): game.sort_pack(); _rebuild())
	head.add_child(sort)
	column.add_child(_grid(game.inventory))
	var lower := HBoxContainer.new()
	lower.add_theme_constant_override("separation", 14)
	column.add_child(lower)
	var safe_box := VBoxContainer.new()
	safe_box.add_child(AK.section("安全袋"))
	safe_box.add_child(_grid(game.safe_bag))
	lower.add_child(safe_box)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lower.add_child(spacer)
	var money := VBoxContainer.new()
	money.alignment = BoxContainer.ALIGNMENT_END
	money.add_child(AK.label("赤金 %d" % game.gold_bars(), 16, AK.SP))
	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation", 4)
	money.add_child(_actions)
	lower.add_child(money)
	_fill_actions()
	return margin

## Select-then-act still works for keyboards and the old click flow.
func _fill_actions() -> void:
	if selected == null or not game.carried_items().has(selected): return
	if selected_container != null:
		if selected.is_equippable():
			var equip := AK.button("装备", "blue", 12)
			equip.pressed.connect(func(): game.equip_from(selected, selected_container); selected = null; _rebuild())
			_actions.add_child(equip)
		if selected.is_potion():
			var drink := AK.button("饮用", "blue", 12)
			drink.pressed.connect(func(): game.drink(selected); selected = null; _rebuild())
			_actions.add_child(drink)
		var move := AK.button("移到安全袋" if selected_container == game.inventory else "移回背包", "plain", 12)
		move.pressed.connect(func(): game.quick_move(selected, selected_container); selected = null; _rebuild())
		_actions.add_child(move)
		var drop := AK.button("丢到地面", "plain", 12)
		drop.pressed.connect(func(): ask_drop(selected, selected_container))
		_actions.add_child(drop)
	else:
		var off := AK.button("卸下", "plain", 12)
		off.pressed.connect(func(): game.unequip_to_pack(selected); selected = null; _rebuild())
		_actions.add_child(off)

func _grid(container: ItemContainer) -> GridView:
	var grid := GridView.new()
	grid.panel = self
	grid.container = container
	grid.custom_minimum_size = Vector2(container.width * CELL, container.height * CELL)
	for item in container.items:
		var tile := ItemTile.new()
		tile.panel = self
		tile.item = item
		tile.container = container
		tile.position = Vector2(item.grid_x * CELL, item.grid_y * CELL)
		tile.size = Vector2(item.width * CELL - 1, item.height * CELL - 1)
		grid.add_child(tile)
	return grid

# --- Right: attributes ------------------------------------------------------------------

func _stats_column() -> Control:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top"]: margin.add_theme_constant_override("margin_" + side, 14)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	margin.add_child(column)
	var p := game.player
	var preview := hovered if hovered != null and hovered.is_equippable() and game.player.equipped.get(hovered.category) != hovered else null
	var after: Dictionary = p.preview_equip(preview).after if preview != null else p.snapshot()
	var now: Dictionary = p.snapshot()
	var groups := [["基础", [["生命", "hp"], ["攻击", "atk"], ["法术攻击", "arts"], ["防御", "def"], ["法术抗性", "res"]]],
		["战斗", [["攻击速度", "aspd"], ["暴击率", "crit"], ["暴击伤害", "crit_dmg"]]],
		["其他", [["移动速度", "move"]]]]
	for group in groups:
		column.add_child(AK.section(group[0]))
		for entry in group[1]:
			var key: String = entry[1]
			var row := HBoxContainer.new()
			row.add_child(AK.label(entry[0], 12, AK.MUTE))
			var fill := Control.new()
			fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(fill)
			var value := AK.label(ItemTooltip._value(key, now[key]) if key != "hp" else "%d / %d" % [roundi(maxf(p.hp, 0)), roundi(p.max_hp)], 14, AK.FG, AK.en())
			row.add_child(value)
			var delta := float(after[key]) - float(now[key])
			if not is_zero_approx(delta) and not (ItemTooltip._value(key, absf(delta)) in ["0", "0%", "0.0"]):
				row.add_child(AK.label(" %s%s" % ["+" if delta > 0 else "−", ItemTooltip._value(key, absf(delta))], 12, Color("9fe04a") if delta > 0 else AK.RED, AK.en()))
			column.add_child(row)
	var regen := HBoxContainer.new()
	regen.add_child(AK.label("生命回复", 12, AK.MUTE))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	regen.add_child(gap)
	regen.add_child(AK.label("%d / 秒" % roundi(p.regen_rate()), 14, AK.FG, AK.en()))
	column.add_child(regen)
	return margin

# --- Floating tooltip ---------------------------------------------------------------------

func hover(item: Item, container: ItemContainer, rect: Rect2 = Rect2()) -> void:
	hovered = item
	hovered_container = container
	_hover_rect = rect
	_refresh_tooltip()

func unhover(item: Item) -> void:
	if hovered == item:
		hovered = null
		_refresh_tooltip()

func select(item: Item, container: ItemContainer) -> void:
	selected = item
	selected_container = container
	_rebuild()

func _shown() -> Item:
	return hovered if hovered != null else selected

func _refresh_tooltip() -> void:
	if not is_instance_valid(_float): return
	for child in _float.get_children():
		_float.remove_child(child)
		child.queue_free()
	var item := _shown()
	if item == null:
		_float.visible = false
		return
	_float.add_child(_tip_card(ItemTooltip.text(game, item, _detail, false)))
	var worn: Item = game.player.equipped.get(item.category) if item.is_equippable() else null
	if worn != null and worn != item: _float.add_child(_tip_card("[color=#101010][bgcolor=#e9e9e9] 已装备 [/bgcolor][/color]\n" + ItemTooltip.text(game, worn, _detail, false)))
	_float.visible = true
	_float.reset_size()
	var anchor := _hover_rect if _hover_rect.size != Vector2.ZERO else Rect2(_last_pointer, Vector2.ZERO)
	var size := _float.get_combined_minimum_size()
	var at := Vector2(anchor.end.x + 10, anchor.position.y)
	if at.x + size.x > 1272: at.x = anchor.position.x - size.x - 10
	at.y = clampf(at.y, 8, 712 - size.y)
	at.x = clampf(at.x, 8, 1272 - size.x)
	_float.position = at

func _tip_card(bbcode: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", AK.box(Color("0d0d0d"), AK.LINE_2, 1, 10))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.custom_minimum_size.x = 270
	text.add_theme_font_override("normal_font", AK.cn())
	text.add_theme_font_size_override("normal_font_size", 13)
	text.text = bbcode
	card.add_child(text)
	return card

# --- Actions shared by tiles, slots and keys --------------------------------------

func ask_drop(item: Item, from: ItemContainer) -> void:
	if item == null: return
	_pending_drop = item
	_pending_from = from
	_confirm.dialog_text = "把 %s 丢到地面？" % item.display_name()
	_confirm.popup_centered()

func right_click(item: Item, container: ItemContainer) -> void:
	if container == null: game.unequip_to_pack(item)
	elif item.is_potion(): game.drink(item)
	elif item.is_equippable(): game.equip_from(item, container)
	selected = null
	hovered = null
	_rebuild()

func ctrl_click(item: Item, container: ItemContainer) -> void:
	if container != null: game.quick_move(item, container)
	selected = null
	_rebuild()

func begin_drag(item: Item, from: ItemContainer, from_equip: bool) -> void:
	_drag_item = item
	_drag_from = from
	_drag_from_equip = from_equip
	hovered = null
	_refresh_tooltip()

func drop_on_grid(data: Dictionary, container: ItemContainer, cell: Vector2i) -> void:
	var from: ItemContainer = data.get("from")
	if not game.move_item(data.item, from, container, cell.x, cell.y):
		game.set_message("放不下：位置被占用或超出边界。")
	_drag_item = null
	selected = null
	_rebuild()

func drop_on_slot(data: Dictionary, category: int) -> void:
	var item: Item = data.item
	var from: ItemContainer = data.get("from")
	if from != null and item.category == category: game.equip_from(item, from)
	_drag_item = null
	selected = null
	_rebuild()


## One grid (pack or safe bag): empty cells, the tiles on top, and the drop
## preview — green where the dragged item fits, red where it does not.
class GridView extends Control:
	var panel: InventoryPanel
	var container: ItemContainer
	var _preview := Rect2i()
	var _preview_ok := false

	func _draw() -> void:
		var c := InventoryPanel.CELL
		draw_rect(Rect2(Vector2.ZERO, Vector2(container.width * c, container.height * c)), Color(0, 0, 0, 0.55))
		for x in range(container.width + 1): draw_line(Vector2(x * c, 0), Vector2(x * c, container.height * c), Color(1, 1, 1, 0.07))
		for y in range(container.height + 1): draw_line(Vector2(0, y * c), Vector2(container.width * c, y * c), Color(1, 1, 1, 0.07))
		if _preview.size != Vector2i.ZERO:
			draw_rect(Rect2(_preview.position * c, _preview.size * c), Color(0.3, 0.9, 0.45, 0.28) if _preview_ok else Color(0.95, 0.3, 0.25, 0.3))

	func _local(at: Vector2) -> Vector2:
		if panel._pointer_known: return panel._last_pointer - global_position
		return at

	func _cell_for(at: Vector2, data: Dictionary) -> Vector2i:
		at = _local(at)
		var grab: Vector2 = data.get("grab", Vector2.ZERO)
		return Vector2i(roundi((at.x - grab.x) / InventoryPanel.CELL), roundi((at.y - grab.y) / InventoryPanel.CELL))

	func _can_drop_data(at: Vector2, data: Variant) -> bool:
		if not data is Dictionary or not data.has("item"): return false
		var item: Item = data.item
		var cell := _cell_for(at, data)
		_preview = Rect2i(cell, Vector2i(item.width, item.height))
		_preview_ok = container.can_place(item, cell.x, cell.y)
		queue_redraw()
		return _preview_ok

	func _drop_data(at: Vector2, data: Variant) -> void:
		var cell := _cell_for(at, data)
		_preview = Rect2i()
		panel.drop_on_grid(data, container, cell)

	func _notification(what: int) -> void:
		if what in [NOTIFICATION_MOUSE_EXIT, NOTIFICATION_DRAG_END]:
			_preview = Rect2i()
			queue_redraw()


## An item on a grid, in the depot style (界面策划案 §2.4): the rarity glows up
## from the bottom with a 3 px bar, the count sits in a black box. A Button, so
## keyboard and the select-then-act flow still work.
class ItemTile extends Button:
	var panel: InventoryPanel
	var item: Item
	var container: ItemContainer

	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		text = "" if ItemIcons.texture_for(item) != null else item.item_name.left(2 if item.width < 2 else item.width * 2 + 1)
		add_theme_font_override("font", AK.cn())
		add_theme_font_size_override("font_size", 12)
		ItemTile.style_for(self, item)
		pressed.connect(func():
			if Input.is_key_pressed(KEY_CTRL): panel.ctrl_click(item, container)
			else: panel.select(item, container))
		mouse_entered.connect(func(): panel.hover(item, container, get_global_rect()))
		mouse_exited.connect(func(): panel.unhover(item))

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			panel.right_click(item, container)
			accept_event()

	func _get_drag_data(at: Vector2) -> Variant:
		var preview := ItemTile.drag_preview(item, size)
		preview.text = text
		preview.modulate.a = 0.8
		set_drag_preview(preview)
		panel.begin_drag(item, container, false)
		return {"item": item, "from": container, "grab": at}

	func _draw() -> void:
		ItemTile.draw_glow(self, item)
		ItemIcons.draw(self, item, Rect2(Vector2.ZERO, size))
		ItemTile.draw_badges(self, item, container == panel.game.safe_bag)

	static func drag_preview(shown: Item, tile_size: Vector2) -> Button:
		var preview := Button.new()
		preview.size = tile_size
		ItemTile.style_for(preview, shown)
		var texture := ItemIcons.texture_for(shown)
		if texture != null:
			var image := TextureRect.new()
			image.texture = texture
			image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			image.position = ((tile_size - texture.get_size()) * 0.5).floor()
			image.size = texture.get_size()
			preview.add_child(image)
		else:
			preview.text = shown.item_name.left(2)
		return preview

	static func tier_color(shown: Item) -> Color:
		if shown.is_potion(): return AK.GREEN
		if not shown.special.is_empty(): return AK.SPECIAL
		if not shown.material_id.is_empty(): return shown.rarity_color()
		return AK.TIER[clampi(shown.rarity, 0, 2)]

	static func style_for(button: Button, shown: Item) -> void:
		for state in ["normal", "hover", "pressed"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color("2b2b2b") if state == "normal" else Color("363636")
			if shown.insured:
				style.border_color = InventoryPanel.INSURED
				style.set_border_width_all(1)
			elif state == "hover":
				style.border_color = Color.WHITE
				style.set_border_width_all(1)
			button.add_theme_stylebox_override(state, style)
		button.add_theme_color_override("font_color", AK.FG)

	static func draw_glow(control: Control, shown: Item) -> void:
		var c := tier_color(shown)
		var s := control.size
		var steps := 8
		for i in range(steps):
			var t := float(i) / steps
			control.draw_rect(Rect2(0, s.y * (0.4 + 0.6 * t), s.x, s.y * 0.6 / steps + 1), Color(c.r, c.g, c.b, 0.06 + 0.32 * t))
		control.draw_rect(Rect2(0, s.y - 3, s.x, 3), c)

	## Badges (§5.3): shield = insured, lock = in the safe bag, diamond =
	## regional exclusive; stack counts in a black box, bottom right.
	static func draw_badges(control: Control, shown: Item, in_safe: bool) -> void:
		var s := control.size
		if shown.insured:
			control.draw_colored_polygon(PackedVector2Array([Vector2(3, 3), Vector2(13, 3), Vector2(13, 9), Vector2(8, 14), Vector2(3, 9)]), InventoryPanel.INSURED)
		if in_safe:
			control.draw_rect(Rect2(3, s.y - 13, 9, 7), AK.GREEN)
			control.draw_arc(Vector2(7.5, s.y - 13), 3.0, PI, TAU, 8, AK.GREEN, 1.5)
		if shown.is_stackable():
			var label := str(shown.quantity)
			var font := AK.en()
			var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			control.draw_rect(Rect2(s.x - w - 6, s.y - 18, w + 6, 14), Color.BLACK)
			control.draw_string(font, Vector2(s.x - w - 3, s.y - 7), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
		if not shown.exclusive_region.is_empty():
			var c := Vector2(s.x - 8, 8)
			control.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -5), c + Vector2(5, 0), c + Vector2(0, 5), c + Vector2(-5, 0)]), AK.ORI)


## An equipment slot on the paper doll: shows the worn item, accepts drops of its
## category, drags out to unequip, right click unequips.
class EquipSlot extends Button:
	var panel: InventoryPanel
	var category: int
	var item: Item

	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		text = "" if item == null or ItemIcons.texture_for(item) != null else item.item_name.left(4)
		add_theme_font_override("font", AK.cn())
		add_theme_font_size_override("font_size", 12)
		for state in ["normal", "hover", "pressed"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color("232323") if item == null else Color("2b2b2b")
			if state == "hover":
				style.border_color = Color.WHITE
				style.set_border_width_all(1)
			add_theme_stylebox_override(state, style)
		if item != null:
			mouse_entered.connect(func(): panel.hover(item, null, get_global_rect()))
			mouse_exited.connect(func(): panel.unhover(item))
			pressed.connect(func(): panel.select(item, null))

	func _gui_input(event: InputEvent) -> void:
		if item != null and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			panel.right_click(item, null)
			accept_event()

	func _draw() -> void:
		if item == null: return
		ItemTile.draw_glow(self, item)
		ItemIcons.draw(self, item, Rect2(Vector2.ZERO, size))
		ItemTile.draw_badges(self, item, false)

	func _get_drag_data(_at: Vector2) -> Variant:
		if item == null: return null
		var preview := ItemTile.drag_preview(item, Vector2(item.width * InventoryPanel.CELL - 1, item.height * InventoryPanel.CELL - 1))
		set_drag_preview(preview)
		panel.begin_drag(item, null, true)
		return {"item": item, "from": null, "grab": Vector2(InventoryPanel.CELL, InventoryPanel.CELL) * 0.5}

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("item") and data.item.category == category and data.get("from") != null

	func _drop_data(_at: Vector2, data: Variant) -> void:
		panel.drop_on_slot(data, category)
