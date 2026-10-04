class_name InventoryPanel
extends Control

## The field inventory (I). Layout and conventions follow 装备与背包界面调研.md §5:
## equipment and stats on the left, the pack and safe bag in the middle, a fixed
## tooltip column on the right that compares against what is worn. Items are
## dragged between cells, the safe bag and the equipment slots; dragging out of
## the panel asks before dropping. Right click equips / unequips, Ctrl+click
## moves between pack and safe bag, Delete drops, Alt shows affix ranges,
## Shift shows the worn item in full. Select + buttons still works for keyboards.

const CELL := 40
const INSURED := Color("4fd1c5")
const SHORTCUTS := "右键 装备/卸下 · Ctrl+左键 背包⇄安全袋 · 拖拽 移动/装备/拖出面板丢弃 · Shift 查看已装备 · Alt 词缀范围 · Delete 丢弃"

var game: GameManager
var panel: PanelContainer
var body: VBoxContainer
var selected: Item
var selected_container: ItemContainer
var hovered: Item
var hovered_container: ItemContainer
var _tooltip: RichTextLabel
var _actions: HBoxContainer
var _stats: RichTextLabel
var _detail := false
var _show_worn := false
var _confirm: ConfirmationDialog
var _pending_drop: Item
var _pending_from: ItemContainer
var _drag_item: Item
var _drag_from: ItemContainer
var _drag_from_equip := false
## Where the pointer last was, from the GUI's own events: what a drag that
## lands nowhere is judged by (inside the panel = cancelled, outside = drop).
var _last_pointer := Vector2.ZERO
var _pointer_known := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	panel.position = Vector2(40, 24)
	panel.size = Vector2(1200, 672)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101c29")
	for side in ["left", "right", "top", "bottom"]: style.set("content_margin_" + side, 16)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var scroll := ScrollContainer.new()
	panel.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)
	_confirm = ConfirmationDialog.new()
	_confirm.title = "丢弃物品"
	_confirm.ok_button_text = "丢到地面"
	_confirm.cancel_button_text = "取消"
	_confirm.confirmed.connect(func():
		if _pending_drop != null: game.drop_item(_pending_drop, _pending_from)
		_pending_drop = null
		_rebuild())
	add_child(_confirm)

func open() -> void:
	selected = null
	hovered = null
	show()
	_rebuild()

func _process(_delta: float) -> void:
	if not visible: return
	var detail := Input.is_key_pressed(KEY_ALT)
	var worn := Input.is_key_pressed(KEY_SHIFT)
	if detail != _detail or worn != _show_worn:
		_detail = detail
		_show_worn = worn
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
	_top_bar()
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	body.add_child(columns)
	columns.add_child(_left_column())
	columns.add_child(_middle_column())
	columns.add_child(_right_column())
	game.menu.text(body, SHORTCUTS, 13, Color("99aab8"))
	_refresh_tooltip()

# --- Top: value at stake (§5.9) ---------------------------------------------------

func _top_bar() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	body.add_child(row)
	game.menu.text(row, "外勤物资 / 拖拽整理 · 悬停查看", 22, FieldMenu.GOLD)
	game.menu.button(row, "返回战斗 [ I ]", game.close_modal)
	var v := game.value_summary()
	game.menu.text(body, "携带价值 %d  ·  安全袋 %d  ·  点金 %d  ·  投保 %d    若此刻阵亡：必定保留 %d，保险期望返还 %d，丢失 %d" % [
		v.carried, v.safe, v.gilded, v.insured, v.kept, roundi(v.expected), v.lost], 14, Color("d8c27a"))

# --- Left: equipment and stats (§5.1, §5.14) ------------------------------------

func _left_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 300
	column.add_theme_constant_override("separation", 6)
	game.menu.text(column, "装备", 16, FieldMenu.GOLD)
	for category in [Item.Category.WEAPON, Item.Category.ARMOR, Item.Category.TRINKET]:
		var slot := EquipSlot.new()
		slot.panel = self
		slot.category = category
		slot.item = game.player.equipped.get(category)
		column.add_child(slot)
	game.menu.text(column, "属性", 16, FieldMenu.GOLD)
	_stats = RichTextLabel.new()
	_stats.bbcode_enabled = true
	_stats.fit_content = true
	_stats.scroll_active = false
	_stats.custom_minimum_size = Vector2(300, 150)
	_stats.add_theme_font_size_override("normal_font_size", 14)
	column.add_child(_stats)
	return column

# --- Middle: pack, safe bag, relics ---------------------------------------------

func _middle_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	var head := HBoxContainer.new()
	column.add_child(head)
	game.menu.text(head, "普通背包 %d × %d" % [game.inventory.width, game.inventory.height], 16)
	game.menu.button(head, "整理", func(): game.sort_pack(); _rebuild())
	game.menu.button(head, "拾取：%s" % GameManager.PICKUP_FILTER_NAMES[game.pickup_filter], func(): game.cycle_pickup_filter(); _rebuild())
	column.add_child(_grid(game.inventory))
	game.menu.text(column, "安全袋 %d × %d · 阵亡保留" % [game.safe_bag.width, game.safe_bag.height], 16)
	column.add_child(_grid(game.safe_bag))
	game.menu.text(column, "本次藏品 %d 件（详情见右侧）" % game.builds.size(), 14, Color("99aab8"))
	var relics := HFlowContainer.new()
	relics.custom_minimum_size.x = CELL * game.inventory.width
	column.add_child(relics)
	for id in game.builds:
		var relic := RelicCatalog.get_relic(id)
		if relic.is_empty(): continue
		var icon := ColorRect.new()
		icon.custom_minimum_size = Vector2(18, 18)
		icon.color = RelicCatalog.RARITY_COLORS[relic.rarity]
		icon.tooltip_text = "%s\n%s" % [relic.name, relic.effect]
		relics.add_child(icon)
	return column

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
		tile.size = Vector2(item.width * CELL - 2, item.height * CELL - 2)
		grid.add_child(tile)
	return grid

# --- Right: fixed tooltip and actions (§5.1, §5.7) -------------------------------

func _right_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 340
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tooltip = RichTextLabel.new()
	_tooltip.bbcode_enabled = true
	_tooltip.fit_content = true
	_tooltip.scroll_active = false
	_tooltip.custom_minimum_size = Vector2(340, 260)
	_tooltip.add_theme_font_size_override("normal_font_size", 14)
	column.add_child(_tooltip)
	_actions = HBoxContainer.new()
	column.add_child(_actions)
	if selected != null and game.carried_items().has(selected):
		if selected_container != null:
			if selected.is_equippable():
				game.menu.button(_actions, "装备", func(): game.equip_from(selected, selected_container); selected = null; _rebuild())
			game.menu.button(_actions, "移到安全袋" if selected_container == game.inventory else "移回背包", func():
				game.quick_move(selected, selected_container)
				selected = null
				_rebuild())
			game.menu.button(_actions, "丢到地面", func(): ask_drop(selected, selected_container), selected.gilded)
		else:
			game.menu.button(_actions, "卸下", func(): game.unequip_to_pack(selected); selected = null; _rebuild())
	column.add_child(HSeparator.new())
	game.menu.build_summary(column)
	return column

func hover(item: Item, container: ItemContainer) -> void:
	hovered = item
	hovered_container = container
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
	if not is_instance_valid(_tooltip): return
	var item := _shown()
	_tooltip.text = ItemTooltip.text(game, item, _detail, _show_worn) if item != null else "[color=#99aab8]把鼠标停在物品上查看属性；与已装备的同类装备逐项对比。[/color]"
	if is_instance_valid(_stats): _stats.text = ItemTooltip.stats_text(game, item if item != null and item.is_equippable() and game.player.equipped.get(item.category) != item else null)

# --- Actions shared by tiles, slots and keys --------------------------------------

func ask_drop(item: Item, from: ItemContainer) -> void:
	if item == null: return
	if item.gilded:
		game.set_message("点金装备本次合同不可丢弃。")
		return
	_pending_drop = item
	_pending_from = from
	_confirm.dialog_text = "把 %s 丢到地面？\n深入后不能回来捡。" % item.display_name()
	_confirm.popup_centered()

func right_click(item: Item, container: ItemContainer) -> void:
	if container == null: game.unequip_to_pack(item)
	elif item.is_equippable(): game.equip_from(item, container)
	selected = null
	_rebuild()

func ctrl_click(item: Item, container: ItemContainer) -> void:
	if container != null: game.quick_move(item, container)
	selected = null
	_rebuild()

func begin_drag(item: Item, from: ItemContainer, from_equip: bool) -> void:
	_drag_item = item
	_drag_from = from
	_drag_from_equip = from_equip

func drop_on_grid(data: Dictionary, container: ItemContainer, cell: Vector2i) -> void:
	var from: ItemContainer = data.get("from")
	if not game.move_item(data.item, from, container, cell.x, cell.y):
		game.set_message("放不下：位置被占用或超出边界（物品不能旋转）。")
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

func _equip_from_inventory(item: Item) -> void:
	game.equip_from(item, game.inventory)


## One grid (pack or safe bag): empty cells, the tiles on top, and the drop
## preview — green where the dragged item fits, red where it does not.
class GridView extends Control:
	var panel: InventoryPanel
	var container: ItemContainer
	var _preview := Rect2i()
	var _preview_ok := false

	func _draw() -> void:
		for y in range(container.height):
			for x in range(container.width):
				draw_rect(Rect2(x * InventoryPanel.CELL, y * InventoryPanel.CELL, InventoryPanel.CELL - 2, InventoryPanel.CELL - 2), Color("0b141d"))
				draw_rect(Rect2(x * InventoryPanel.CELL, y * InventoryPanel.CELL, InventoryPanel.CELL - 2, InventoryPanel.CELL - 2), Color("22313f"), false, 1.0)
		if _preview.size != Vector2i.ZERO:
			draw_rect(Rect2(_preview.position * InventoryPanel.CELL, _preview.size * InventoryPanel.CELL), Color(0.3, 0.9, 0.45, 0.28) if _preview_ok else Color(0.95, 0.3, 0.25, 0.3))

	## The pointer in this grid's space. The drop callbacks' own `at` is not
	## used: with the world in a scaled SubViewport (pixel_display.gd) it came
	## out offset under replayed input, while the panel's tracked pointer is
	## the same screen position the GUI hit-tests with.
	func _local(at: Vector2) -> Vector2:
		if panel._pointer_known: return panel._last_pointer - global_position
		return at

	func _cell_for(at: Vector2, data: Dictionary) -> Vector2i:
		at = _local(at)
		# `grab` is where inside the item it was picked up, so the item's top-left
		# is the pointer minus that; it snaps to the nearest cell.
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


## An item on a grid. A Button, so keyboard and the old select-then-act flow
## still work; it also starts drags and takes right / Ctrl clicks.
class ItemTile extends Button:
	var panel: InventoryPanel
	var item: Item
	var container: ItemContainer

	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		text = item.item_name.left(2) + ("★" if item.gilded else "")
		add_theme_font_size_override("font_size", 13)
		ItemTile.style_for(self, item)
		pressed.connect(func():
			if Input.is_key_pressed(KEY_CTRL): panel.ctrl_click(item, container)
			else: panel.select(item, container))
		mouse_entered.connect(func(): panel.hover(item, container))
		mouse_exited.connect(func(): panel.unhover(item))

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			panel.right_click(item, container)
			accept_event()

	func _get_drag_data(at: Vector2) -> Variant:
		var preview := Button.new()
		preview.text = text
		preview.size = size
		ItemTile.style_for(preview, item)
		preview.modulate.a = 0.8
		set_drag_preview(preview)
		panel.begin_drag(item, container, false)
		return {"item": item, "from": container, "grab": at}

	func _draw() -> void:
		ItemTile.draw_badges(self, item, container == panel.game.safe_bag)

	## Rarity border and tint (§5.2).
	static func style_for(button: Button, shown: Item) -> void:
		var color := shown.rarity_color()
		for state in ["normal", "hover", "pressed"]:
			var style := StyleBoxFlat.new()
			style.bg_color = color.darkened(0.78 if state == "normal" else 0.6)
			style.border_color = color
			style.set_border_width_all(2)
			if shown.insured: style.border_color = InventoryPanel.INSURED
			button.add_theme_stylebox_override(state, style)
		button.add_theme_color_override("font_color", color.lightened(0.2))

	## Status badges (§5.3): shield = insured (Tarkov's convention), gold ingot =
	## gilded, lock = in the safe bag, diamond = regional exclusive. Insurance is
	## teal rather than Tarkov's yellow, which would read as the 稀有 gold here.
	static func draw_badges(control: Control, shown: Item, in_safe: bool) -> void:
		var s := control.size
		if shown.insured:
			control.draw_colored_polygon(PackedVector2Array([Vector2(3, 3), Vector2(13, 3), Vector2(13, 9), Vector2(8, 14), Vector2(3, 9)]), InventoryPanel.INSURED)
		if shown.gilded:
			control.draw_colored_polygon(PackedVector2Array([Vector2(s.x - 15, 6), Vector2(s.x - 11, 2), Vector2(s.x - 3, 2), Vector2(s.x - 3, 6), Vector2(s.x - 7, 10), Vector2(s.x - 15, 10)]), Color("ffd45a"))
		if in_safe:
			control.draw_rect(Rect2(3, s.y - 11, 9, 7), Color("8fd0ff"))
			control.draw_arc(Vector2(7.5, s.y - 11), 3.0, PI, TAU, 8, Color("8fd0ff"), 1.5)
		if not shown.exclusive_region.is_empty():
			var c := Vector2(s.x - 8, s.y - 8)
			control.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -5), c + Vector2(5, 0), c + Vector2(0, 5), c + Vector2(-5, 0)]), Color("ee8a24"))


## An equipment slot: shows the worn item, accepts drops of its category,
## drags out to unequip, right click unequips.
class EquipSlot extends Button:
	var panel: InventoryPanel
	var category: int
	var item: Item

	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(300, 40)
		alignment = HORIZONTAL_ALIGNMENT_LEFT
		var name: String = Item.CATEGORY_NAMES[category]
		text = "%s / %s" % [name, item.display_name() if item != null else "空"]
		if item != null:
			ItemTile.style_for(self, item)
			mouse_entered.connect(func(): panel.hover(item, null))
			mouse_exited.connect(func(): panel.unhover(item))
			pressed.connect(func(): panel.select(item, null))

	func _gui_input(event: InputEvent) -> void:
		if item != null and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			panel.right_click(item, null)
			accept_event()

	func _draw() -> void:
		if item != null: ItemTile.draw_badges(self, item, false)

	func _get_drag_data(_at: Vector2) -> Variant:
		if item == null: return null
		var preview := Button.new()
		preview.text = item.item_name.left(2)
		preview.size = Vector2(item.width * InventoryPanel.CELL - 2, item.height * InventoryPanel.CELL - 2)
		ItemTile.style_for(preview, item)
		set_drag_preview(preview)
		panel.begin_drag(item, null, true)
		return {"item": item, "from": null, "grab": Vector2(InventoryPanel.CELL, InventoryPanel.CELL) * 0.5}

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("item") and data.item.category == category and data.get("from") != null

	func _drop_data(_at: Vector2, data: Variant) -> void:
		panel.drop_on_slot(data, category)
