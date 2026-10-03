class_name OrderBoard
extends RefCounted

## Delivery orders posted by Rhodes Island departments (基地玩法策划案_v1_0.md §3.8).
##
## Each slot is empty or holds {"id": template, "state": "open"|"done",
## "delivered": [{"uid", "name", "value"}]}. Items are handed over one at a time
## and leave the game when they do; an order pays out when its count is met.
## Open orders never expire. After every settlement, empty and done slots are
## refilled under three rules:
##   1. at most one exclusive-item order on the board;
##   2. at least one order points somewhere other than the last contract's region;
##   3. no template twice.

var slots: Array = []   # Dictionary or null

func _init() -> void:
	resize(BaseCatalog.ORDER_SLOTS)

func resize(count: int) -> void:
	while slots.size() < count: slots.append(null)

## New game: an easy first order, the second slot empty.
func start_fresh() -> void:
	slots = []
	resize(BaseCatalog.ORDER_SLOTS)
	slots[0] = _make("starter")

static func _make(id: String) -> Dictionary:
	return {"id": id, "state": "open", "delivered": []}

func open_orders() -> Array:
	return slots.filter(func(o): return o != null and o.state == "open")

## Whether `item` is what order `slot` asks for.
func matches(slot: int, item: Item) -> bool:
	var order = slots[slot]
	if order == null or order.state != "open" or item == null: return false
	var t: Dictionary = BaseCatalog.ORDERS[order.id]
	if t.has("effect"): return item.effect == t.effect
	if item.category != t.category or item.rarity < int(t.get("min_rarity", 0)): return false
	if t.has("region") and item.origin_region != t.region: return false
	return true

func remaining(slot: int) -> int:
	var order = slots[slot]
	if order == null: return 0
	return int(BaseCatalog.ORDERS[order.id].count) - order.delivered.size()

## Hands `item` over. Returns {} when refused, else {"done": bool, "gold", "prestige"}
## (gold and prestige are 0 until the order is complete). The caller removes the item.
func deliver(slot: int, item: Item) -> Dictionary:
	if not matches(slot, item): return {}
	var order: Dictionary = slots[slot]
	order.delivered.append({"uid": item.uid, "name": item.item_name, "value": item.value})
	if remaining(slot) > 0: return {"done": false, "gold": 0, "prestige": 0}
	order.state = "done"
	var t: Dictionary = BaseCatalog.ORDERS[order.id]
	var gold := int(t.gold) if t.has("gold") else int(round(order.delivered.reduce(func(sum, d): return sum + int(d.value), 0) * float(t.mult)))
	return {"done": true, "gold": gold, "prestige": int(t.prestige)}

## Replaces an open order with a different one (the R3 free reroll). What was
## already handed over for it is kept by the department. Rule 2 is not checked:
## the player chose to reroll.
func reroll(slot: int, rng: RandomNumberGenerator) -> bool:
	if slot < 0 or slot >= slots.size() or slots[slot] == null or slots[slot].state != "open": return false
	var old: String = slots[slot].id
	slots[slot] = null
	var id := _pick(rng, _ids_on_board() + [old])
	slots[slot] = _make(id if not id.is_empty() else old)
	return not id.is_empty()

## Clears a slot. Anything already handed over stays handed over.
func abandon(slot: int) -> bool:
	if slot < 0 or slot >= slots.size() or slots[slot] == null or slots[slot].state != "open": return false
	slots[slot] = null
	return true

## After a settlement: refill empty and done slots under the three rules.
func refill(rng: RandomNumberGenerator, last_region: String) -> void:
	var refill_slots: Array[int] = []
	for i in range(slots.size()):
		if slots[i] == null or slots[i].state == "done":
			slots[i] = null
			refill_slots.append(i)
	for i in refill_slots:
		var id := _pick(rng, _ids_on_board())
		if not id.is_empty(): slots[i] = _make(id)
	# Rule 2: if nothing on the board points away from the last region, swap a
	# newly posted order for one that does.
	if not refill_slots.is_empty() and not _points_away(last_region):
		var i: int = refill_slots[rng.randi_range(0, refill_slots.size() - 1)]
		slots[i] = null
		var away := _pick(rng, _ids_on_board(), func(id): return not str(BaseCatalog.ORDERS[id].get("region", "")).is_empty() and BaseCatalog.ORDERS[id].region != last_region)
		if not away.is_empty(): slots[i] = _make(away)

func _ids_on_board() -> Array:
	return slots.filter(func(o): return o != null).map(func(o): return o.id)

func _points_away(last_region: String) -> bool:
	for id in _ids_on_board():
		var region := str(BaseCatalog.ORDERS[id].get("region", ""))
		if not region.is_empty() and region != last_region: return true
	return false

## Weighted pick of a template not on the board, keeping to one exclusive order.
func _pick(rng: RandomNumberGenerator, on_board: Array, extra := Callable()) -> String:
	var has_exclusive := on_board.any(func(id): return BaseCatalog.is_exclusive_order(id))
	var pool: Array = []
	var total := 0
	for id in BaseCatalog.ORDERS:
		var weight := int(BaseCatalog.ORDERS[id].weight)
		if weight <= 0 or on_board.has(id): continue
		if has_exclusive and BaseCatalog.is_exclusive_order(id): continue
		if extra.is_valid() and not extra.call(id): continue
		pool.append(id)
		total += weight
	if pool.is_empty(): return ""
	var roll := rng.randi_range(1, total)
	for id in pool:
		roll -= int(BaseCatalog.ORDERS[id].weight)
		if roll <= 0: return id
	return pool.back()

## How many open orders point at `region`.
func pointing_at(region: String) -> int:
	return open_orders().filter(func(o): return BaseCatalog.ORDERS[o.id].get("region", "") == region).size()

func to_data() -> Array:
	return slots.duplicate(true)

func load_data(data: Array) -> void:
	slots = []
	for entry in data:
		if entry is Dictionary and BaseCatalog.ORDERS.has(str(entry.get("id", ""))):
			slots.append({"id": str(entry.id), "state": "done" if entry.get("state", "") == "done" else "open",
				"delivered": entry.get("delivered", []).duplicate(true)})
		else: slots.append(null)
	resize(BaseCatalog.ORDER_SLOTS)
