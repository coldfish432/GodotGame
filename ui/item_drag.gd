class_name ItemDrag
extends RefCounted

## Drag-and-drop on the base screens (用户 2026-10-21: 所有物品转移都实现拖拽):
## the workbench, the depot, a camp's 寄存. A dragged item travels as
## {"carry": item}; each target says what it takes and what dropping does.
## The field I window has its own (InventoryPanel); the traders use trade_buy /
## trade_sell payloads (TraderScreen).

static func payload(item: Item) -> Dictionary:
	return {"carry": item}

static func item_of(data: Variant) -> Item:
	if data is Dictionary and data.get("carry") is Item: return data.carry
	return null

## Start dragging `item` out of `control`: its icon follows the pointer.
static func start(control: Control, item: Item) -> Variant:
	var ghost := AK.item_icon(item, Vector2(item.width, item.height) * 40 - Vector2.ONE)
	ghost.modulate.a = 0.8
	control.set_drag_preview(ghost)
	return payload(item)

## `control` drags `item` out (when given) and takes drops `accept(item)`
## allows, handing them to `take(item)`.
static func wire(control: Control, item: Item, accept: Callable, take: Callable) -> void:
	var drag := (func(_at: Vector2) -> Variant: return start(control, item)) if item != null else Callable()
	var can := (func(_at: Vector2, data: Variant) -> bool: return item_of(data) != null and bool(accept.call(item_of(data)))) if accept.is_valid() else Callable()
	var drop := (func(_at: Vector2, data: Variant) -> void: take.call(item_of(data))) if accept.is_valid() else Callable()
	control.set_drag_forwarding(drag, can, drop)
	# Kept on the control too, so a test can drop without a pointer.
	control.set_meta("drop_can", can)
	control.set_meta("drop_take", drop)

## An AK.BagGrid (pack, safe bag) on the same terms: its items drag out, and
## it takes what `accept(item)` allows.
static func bag(grid: AK.BagGrid, accept: Callable, take: Callable) -> AK.BagGrid:
	grid.drag_out = func(item: Item) -> Variant: return payload(item)
	grid.accept = func(data: Variant) -> bool: return item_of(data) != null and bool(accept.call(item_of(data)))
	grid.take = func(data: Variant) -> void: take.call(item_of(data))
	wire(grid, null, accept, take)
	return grid

## A bare drop area of `size` at `at` on `stage`, under what is placed later.
static func zone(stage: Control, at: Vector2, size: Vector2, accept: Callable, take: Callable) -> Control:
	var area := Control.new()
	area.mouse_filter = Control.MOUSE_FILTER_PASS
	AK.put(stage, area, at, size)
	wire(area, null, accept, take)
	return area
