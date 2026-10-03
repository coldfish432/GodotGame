class_name InventoryPanel
extends Control

var game: GameManager
var panel: PanelContainer
var body: VBoxContainer
var selected: Item
var selected_container: ItemContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	panel.position = Vector2(120, 45)
	panel.size = Vector2(1040, 625)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101c29")
	for side in ["left", "right", "top", "bottom"]: style.set("content_margin_" + side, 20)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var scroll := ScrollContainer.new()
	panel.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)

func open() -> void:
	show()
	_rebuild()

func _rebuild() -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	game.menu.text(body, "外勤物资 / 点选格子查看物品", 24, FieldMenu.GOLD)
	game.menu.button(body, "返回战斗 [ I ]", game.close_modal)
	for category in [Item.Category.WEAPON, Item.Category.ARMOR, Item.Category.TRINKET]:
		var item: Item = game.player.equipped.get(category)
		var title: String = ["武器", "防具", "饰品"][category]
		var row := HBoxContainer.new()
		body.add_child(row)
		game.menu.text(row, title + " / " + (item.display_name() if item != null else "空"), 15)
		if item != null:
			game.menu.button(row, "查看", func(): selected = item; selected_container = null; _rebuild())
			game.menu.button(row, "卸下", func(): game.unequip_to_pack(item); _rebuild())
	var grids := HBoxContainer.new()
	grids.add_theme_constant_override("separation", 28)
	body.add_child(grids)
	_draw_grid(grids, game.inventory, "普通背包 10 × 6")
	_draw_grid(grids, game.safe_bag, "安全袋 2 × 2 / 阵亡保留")
	if selected != null and game.carried_items().has(selected):
		game.menu.text(body, selected.display_name() + (" / 已点金" if selected.gilded else "") + (" / 已投保" if selected.insured else ""), 20, FieldMenu.GOLD)
		game.menu.text(body, selected.details() + " / 尺寸 %d×%d / 交付价值 %d" % [selected.width, selected.height, selected.value])
		if selected_container != null:
			var row := HBoxContainer.new()
			body.add_child(row)
			if selected.is_equippable():
				game.menu.button(row, "装备", func(): game.equip_from(selected, selected_container); selected = null; _rebuild())
			game.menu.button(row, "移到安全袋" if selected_container == game.inventory else "移回背包", func():
				game.transfer_item(selected, selected_container, game.safe_bag if selected_container == game.inventory else game.inventory)
				selected = null
				_rebuild())
			game.menu.button(row, "丢到地面", func(): game.drop_item(selected, selected_container); selected = null; _rebuild(), selected.gilded)
	body.add_child(HSeparator.new())
	game.menu.stat_lines(body)
	game.menu.build_summary(body)

func _draw_grid(parent: Node, container: ItemContainer, title: String) -> void:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = maxf(container.width * 42, 260)
	parent.add_child(box)
	game.menu.text(box, title, 16)
	var grid := Control.new()
	grid.custom_minimum_size = Vector2(container.width * 42, container.height * 42)
	box.add_child(grid)
	for y in range(container.height):
		for x in range(container.width):
			var cell := Button.new()
			cell.focus_mode = Control.FOCUS_NONE
			cell.position = Vector2(x * 42, y * 42)
			cell.size = Vector2(40, 40)
			cell.pressed.connect(func():
				if selected != null and selected_container == container:
					container.reposition(selected, x, y)
					game.save_base(not game.in_base)
					_rebuild())
			grid.add_child(cell)
	for item in container.items:
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.position = Vector2(item.grid_x * 42, item.grid_y * 42)
		button.size = Vector2(item.width * 42 - 2, item.height * 42 - 2)
		button.text = item.item_name.left(2) + ("★" if item.gilded else "")
		button.add_theme_font_size_override("font_size", 13)
		button.modulate = [Color("a9bacb"), Color("86d2b7"), Color("f3ca7c")][item.rarity]
		button.tooltip_text = item.display_name() + "\n" + item.details()
		button.pressed.connect(func(): selected = item; selected_container = container; _rebuild())
		grid.add_child(button)

func _equip_from_inventory(item: Item) -> void:
	game.equip_from(item, game.inventory)
