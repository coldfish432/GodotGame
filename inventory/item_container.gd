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

## Whether `item` could sit at (x, y), ignoring its own current cells — the
## drop preview for dragging (装备与背包界面调研 §5.4).
func can_place(item: Item, x: int, y: int) -> bool:
	var had := items.has(item)
	if had: items.erase(item)
	var allowed := _cell_free(x, y, item)
	if had: items.append(item)
	return allowed

## Puts an item that is not in this container at (x, y). Fails without change.
func place(item: Item, x: int, y: int) -> bool:
	if item == null or items.has(item) or not _cell_free(x, y, item): return false
	item.grid_x = x
	item.grid_y = y
	items.append(item)
	return true

## Repacks by category, then rarity (best first), then size (largest first),
## the order Grim Dawn / Last Epoch sort by. If the repack somehow does not
## fit, every item goes back where it was.
func sort_items() -> bool:
	var before := {}
	for item in items: before[item] = Vector2i(item.grid_x, item.grid_y)
	var order := items.duplicate()
	order.sort_custom(func(a: Item, b: Item) -> bool:
		if a.category != b.category: return a.category < b.category
		if a.rarity != b.rarity: return a.rarity > b.rarity
		if a.width * a.height != b.width * b.height: return a.width * a.height > b.width * b.height
		return a.item_name < b.item_name)
	items.clear()
	for item in order:
		if not try_add(item):
			items.clear()
			for kept in before:
				kept.grid_x = before[kept].x
				kept.grid_y = before[kept].y
				items.append(kept)
			return false
	return true

## Grows the grid (base expansions). Never shrinks under existing items.
func resize(p_width: int, p_height: int) -> void:
	for item in items:
		p_width = maxi(p_width, item.grid_x + item.width)
		p_height = maxi(p_height, item.grid_y + item.height)
	width = maxi(width, p_width)
	height = maxi(height, p_height)

func cell_count() -> int:
	return width * height
