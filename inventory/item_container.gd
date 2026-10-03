class_name ItemContainer
extends RefCounted

## Grid-based inventory container: the pack (10x6) and the safe bag (2x2)
## are two instances of this, per the design doc's "2D grid pack, sized by
## footprint, no rotation" hard rule.

var width: int
var height: int
var items: Array[Item] = []

func _init(p_width: int, p_height: int) -> void:
	width = p_width
	height = p_height

func _cell_free(x: int, y: int, item: Item) -> bool:
	if item == null or x < 0 or y < 0 or item.width < 1 or item.height < 1 or x + item.width > width or y + item.height > height:
		return false
	for other in items:
		var overlaps_x := x < other.grid_x + other.width and x + item.width > other.grid_x
		var overlaps_y := y < other.grid_y + other.height and y + item.height > other.grid_y
		if overlaps_x and overlaps_y:
			return false
	return true

func try_add(item: Item) -> bool:
	if item == null or items.has(item):
		return false
	for y in range(height - item.height + 1):
		for x in range(width - item.width + 1):
			if _cell_free(x, y, item):
				item.grid_x = x
				item.grid_y = y
				items.append(item)
				return true
	return false

func remove(item: Item) -> void:
	items.erase(item)

func last_equipment() -> Item:
	for i in range(items.size() - 1, -1, -1):
		if items[i].is_equippable() and not items[i].gilded:
			return items[i]
	return null

func take_all() -> Array[Item]:
	var taken := items.duplicate()
	items.clear()
	return taken

func is_empty() -> bool:
	return items.is_empty()

func transfer_to(item: Item, target: ItemContainer) -> bool:
	if target == self or not items.has(item) or not target.try_add(item):
		return false
	remove(item)
	return true

func occupied_cells() -> int:
	var total := 0
	for item in items:
		total += item.width * item.height
	return total

func reposition(item: Item, x: int, y: int) -> bool:
	if not items.has(item): return false
	items.erase(item)
	var allowed := _cell_free(x, y, item)
	if allowed:
		item.grid_x = x
		item.grid_y = y
	items.append(item)
	return allowed
