class_name ItemContainer
extends RefCounted

## Grid-based inventory container: the pack and the safe bag (2x2) are
## instances of this, a 2D grid sized by footprint; an item may be turned a
## quarter (用户 2026-10-24: 物体可以旋转, Item.rotate).
##
## The pack has pages (用户 2026-11-02, 恐怖黎明): the main pack and the bags
## its expansions add, each a grid of its own (Item.grid_page). Width and
## height are the first page's; filling goes page by page, so a full page
## spills onto the next.

var width: int
var height: int
var items: Array[Item] = []
## Page sizes after the first; empty for a single grid.
var extra_pages: Array[Vector2i] = []

func _init(p_width: int, p_height: int) -> void:
	width = p_width
	height = p_height

func page_count() -> int:
	return 1 + extra_pages.size()

func page_size(page: int) -> Vector2i:
	if page <= 0 or page > extra_pages.size(): return Vector2i(width, height)
	return extra_pages[page - 1]

## The page `item` lies on here (always 0 in a single grid).
func page_of(item: Item) -> int:
	return clampi(item.grid_page, 0, extra_pages.size()) if not extra_pages.is_empty() else 0

func items_on(page: int) -> Array[Item]:
	var out: Array[Item] = []
	for item in items:
		if page_of(item) == page: out.append(item)
	return out

func _cell_free(x: int, y: int, item: Item, page: int = 0) -> bool:
	var size := page_size(page)
	if item == null or page < 0 or page >= page_count() or x < 0 or y < 0 or item.width < 1 or item.height < 1 or x + item.width > size.x or y + item.height > size.y:
		return false
	for other in items:
		if page_of(other) != page: continue
		var overlaps_x := x < other.grid_x + other.width and x + item.width > other.grid_x
		var overlaps_y := y < other.grid_y + other.height and y + item.height > other.grid_y
		if overlaps_x and overlaps_y:
			return false
	return true

func _put(item: Item, x: int, y: int, page: int) -> void:
	item.grid_x = x
	item.grid_y = y
	item.grid_page = page
	items.append(item)

## The first free spot, page by page.
func try_add(item: Item) -> bool:
	if item == null or items.has(item):
		return false
	for page in range(page_count()):
		if try_add_on(item, page): return true
	return false

## The first free spot on one page.
func try_add_on(item: Item, page: int) -> bool:
	if item == null or items.has(item): return false
	var size := page_size(page)
	for y in range(size.y - item.height + 1):
		for x in range(size.x - item.width + 1):
			if _cell_free(x, y, item, page):
				_put(item, x, y, page)
				return true
	return false

## Whether `item` would fit somewhere right now (no rotation).
func can_fit(item: Item) -> bool:
	if item == null: return false
	for page in range(page_count()):
		var size := page_size(page)
		for y in range(size.y - item.height + 1):
			for x in range(size.x - item.width + 1):
				if can_place(item, x, y, page): return true
	return false

func remove(item: Item) -> void:
	items.erase(item)

func last_equipment() -> Item:
	for i in range(items.size() - 1, -1, -1):
		if items[i].is_equippable():
			return items[i]
	return null

func take_all() -> Array[Item]:
	var taken := items.duplicate()
	items.clear()
	return taken

func is_empty() -> bool:
	return items.is_empty()

## Moving a stack merges it into matching stacks first; if only part of it
## fits, the rest stays here and the move counts as done.
func transfer_to(item: Item, target: ItemContainer) -> bool:
	if target == self or not items.has(item): return false
	if item.is_stackable():
		var before := item.quantity
		target.merge_into(item)
		if item.quantity <= 0:
			remove(item)
			return true
		items.erase(item)
		var placed := target.try_add(item)
		if not placed: items.append(item)
		return placed or item.quantity < before
	if not target.try_add(item):
		return false
	remove(item)
	return true

## Pours a stack into this container's matching stacks; `item` keeps what is left.
func merge_into(item: Item) -> void:
	if not item.is_stackable(): return
	for other in items:
		if item.quantity <= 0: return
		if other.can_stack_with(item): other.absorb(item)

## Whether `item` fits: in a free cell, or wholly onto stacks already here.
func can_take(item: Item) -> bool:
	if can_fit(item): return true
	if item == null or not item.is_stackable(): return false
	var room := 0
	for other in items:
		if other.can_stack_with(item): room += other.room()
	return room >= item.quantity

## Picks up a stack: merges first, then takes a new cell for the rest.
## Returns how many units are left over (0 when it all fit).
func add_stack(item: Item) -> int:
	if not item.is_stackable(): return 0 if try_add(item) else item.quantity
	merge_into(item)
	if item.quantity <= 0: return 0
	return 0 if try_add(item) else item.quantity

## Units of a material held here.
func count_material(id: String) -> int:
	var total := 0
	for item in items:
		if item.material_id == id: total += item.quantity
	return total

func occupied_cells() -> int:
	var total := 0
	for item in items:
		total += item.width * item.height
	return total

func reposition(item: Item, x: int, y: int, page: int = 0) -> bool:
	if not items.has(item): return false
	items.erase(item)
	var allowed := _cell_free(x, y, item, page)
	if allowed:
		item.grid_x = x
		item.grid_y = y
		item.grid_page = page
	items.append(item)
	return allowed

## Moves `item` (already here) to the first free spot on `page`.
func move_to_page(item: Item, page: int) -> bool:
	if not items.has(item) or page == page_of(item) or page < 0 or page >= page_count(): return false
	items.erase(item)
	if try_add_on(item, page): return true
	items.append(item)
	return false

## Whether `item` could sit at (x, y) on `page`, ignoring its own current
## cells — the drop preview for dragging (装备与背包界面调研 §5.4).
func can_place(item: Item, x: int, y: int, page: int = 0) -> bool:
	var had := items.has(item)
	if had: items.erase(item)
	var allowed := _cell_free(x, y, item, page)
	if had: items.append(item)
	return allowed

## Puts an item that is not in this container at (x, y) on `page`. Fails without change.
func place(item: Item, x: int, y: int, page: int = 0) -> bool:
	if item == null or items.has(item) or not _cell_free(x, y, item, page): return false
	_put(item, x, y, page)
	return true

## Repacks by category, then rarity (best first), then size (largest first),
## the order Grim Dawn / Last Epoch sort by, page by page. If the repack
## somehow does not fit, every item goes back where it was.
func sort_items() -> bool:
	var before := {}
	for item in items: before[item] = Vector3i(item.grid_x, item.grid_y, item.grid_page)
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
				kept.grid_page = before[kept].z
				items.append(kept)
			return false
	return true

## Turns `item` a quarter where it lies, if the turned footprint fits there.
func rotate_in_place(item: Item) -> bool:
	if not items.has(item): return false
	item.rotate()
	if can_place(item, item.grid_x, item.grid_y, page_of(item)): return true
	item.rotate()
	return false

## Grows the first grid (the safe bag's expansions). Never shrinks under
## existing items.
func resize(p_width: int, p_height: int) -> void:
	for item in items:
		if page_of(item) != 0: continue
		p_width = maxi(p_width, item.grid_x + item.width)
		p_height = maxi(p_height, item.grid_y + item.height)
	width = maxi(width, p_width)
	height = maxi(height, p_height)

## The pack's pages from the base's expansions: the first is the main grid,
## the rest its bags. Items that no longer fit where they were (an old save's
## taller pack) move to the first free spot.
func set_pages(sizes: Array) -> void:
	if sizes.is_empty(): return
	width = (sizes[0] as Vector2i).x
	height = (sizes[0] as Vector2i).y
	extra_pages.clear()
	for i in range(1, sizes.size()): extra_pages.append(sizes[i])
	var loose: Array[Item] = []
	for item in items.duplicate():
		items.erase(item)
		if _cell_free(item.grid_x, item.grid_y, item, page_of(item)): items.append(item)
		else: loose.append(item)
	for item in loose:
		if not try_add(item): items.append(item)   # never lost: it stays listed until moved

func cell_count() -> int:
	var total := width * height
	for size in extra_pages: total += size.x * size.y
	return total
