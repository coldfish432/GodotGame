class_name VoyageState
extends RefCounted

## Rhodes Island on Terra (沙盘航行策划案_v1_0.md): where the ship lies, its
## voyages, the medical stay at the anchor and the factions' bulk orders. All
## on the wall clock (BaseState.now()), caught up on load like the workshop.
## The ship's place itself stays BaseState.ship_at (saved with the base);
## numbers are in VoyageCatalog.

var game: GameManager
## {} when lying at anchor, else {"from", "to", "mode", "start", "due"}.
var sailing := {}
## The medical stay (§4). kinds: kind -> on. last: the wall clock the next
## hour counts from. budget/spent: 龙门币 (0 budget = none). target: a
## faction and the relation to stop at ("" = none).
var stay := {"injured": false, "infected": false, "supplies": false, "last": 0,
	"budget": 0, "spent": 0, "target_faction": "", "target": 0}
## Hours of stay at the current anchor since the ship arrived (posts, §3.3).
var anchor_hours := 0
## Infected hours per anchor towards the next conflict step.
var infected_hours := {}
## Field effects waiting for the next contract in a region (§4.4).
var mine_threat := 0.0
var siracusa_debt := 1.0
## Fractional relation per faction, carried until it makes a whole point.
var relation_frac := {}
## Bulk orders (§5): see _new_order for the fields.
var orders: Array = []
var last_refill := 0
var _next_id := 1
## notify(text): PRTS reports what happened.
var notify := Callable()

func setup(p_game: GameManager) -> void:
	game = p_game

func _say(text: String) -> void:
	if notify.is_valid(): notify.call(text)

# --- Where the ship is ------------------------------------------------------------------------

func place() -> String:
	return game.base.ship_at

func is_sailing() -> bool:
	return not sailing.is_empty()

## The anchor she lies at, "" under way.
func docked_at() -> String:
	return "" if is_sailing() else place()

## Under way: 0–1 along the leg.
func progress(now: int) -> float:
	if not is_sailing(): return 1.0
	var span := maxf(1.0, float(int(sailing.due) - int(sailing.start)))
	return clampf(float(now - int(sailing.start)) / span, 0.0, 1.0)

## Whether `faction`'s home is where the ship lies.
func in_waters(faction: String) -> bool:
	return not is_sailing() and VoyageCatalog.home_of(faction) == place()

# --- Voyages (§3) -----------------------------------------------------------------------------

## 龙门币 for one unit of `material`, at the live ask of the anchor's factions
## (the first that trades its category), else 龙门商会's, else its base.
func supply_price(material: String, at: String = "") -> float:
	if at.is_empty(): at = place()
	var unit := float(Economy.price(MaterialCatalog.create(material, 1)))
	var category := FactionCatalog.material_category(material)
	var candidates: Array = (VoyageCatalog.ANCHOR_FACTIONS.get(at, []) as Array).duplicate()
	candidates.append("lungmen")
	for f in candidates:
		var m := "%s:%s" % [f, category]
		if game.market.books.has(m): return unit * game.market.ask(m)
	return unit

## `fuel`: a 高能燃料 from 喀兰贸易 (势力特供策划案 §二) — 全速 costs no more
## than 标准, and the voyage takes FactionSpecials.FUEL_TIME of the time.
func voyage_cost(to: String, mode: String, fuel := false) -> int:
	var total := 0.0
	var supplies := VoyageCatalog.voyage_supplies(VoyageCatalog.distance(place(), to))
	for id in supplies: total += supply_price(id) * int(supplies[id])
	var mult := float(VoyageCatalog.MODE_COST.get(mode, 1.0))
	total *= minf(mult, 1.0) if fuel else mult
	if game.base.researched("voyage_supply"): total *= 0.85
	return roundi(total / VoyageCatalog.COST_ROUND) * VoyageCatalog.COST_ROUND

func voyage_seconds(to: String, mode: String, fuel := false) -> int:
	return roundi(VoyageCatalog.voyage_seconds(VoyageCatalog.distance(place(), to), mode) * game.research.voyage_time_factor() * (FactionSpecials.FUEL_TIME if fuel else 1.0))

func voyage_refusal(to: String, mode: String, fuel := false) -> String:
	if is_sailing(): return "航行中"
	if not to in VoyageCatalog.ANCHORS or to == place(): return "已在此地"
	if not mode in VoyageCatalog.MODES: return "航速无效"
	if game.gold < voyage_cost(to, mode, fuel): return "龙门币不足"
	if fuel: return game.materials_refusal({GameManager.SPECIAL_FUEL: 1})
	return ""

func sail(to: String, mode: String, now: int, fuel := false) -> bool:
	if not voyage_refusal(to, mode, fuel).is_empty(): return false
	game.gold -= voyage_cost(to, mode, fuel)
	if fuel: game.consume_materials({GameManager.SPECIAL_FUEL: 1})
	sailing = {"from": place(), "to": to, "mode": mode, "start": now, "due": now + voyage_seconds(to, mode, fuel), "fuel": fuel}
	for kind in VoyageCatalog.STAY_KINDS: stay[kind] = false
	anchor_hours = 0
	_say("罗德岛号起航：%s → %s。" % [sailing.from, to])
	return true

func _arrive() -> void:
	game.base.ship_at = str(sailing.to)
	sailing = {}
	_say("罗德岛号抵达%s。" % game.base.ship_at)

# --- Medical stay (§4) ------------------------------------------------------------------------

func stay_on() -> bool:
	return not is_sailing() and (bool(stay.injured) or bool(stay.infected))

## Turns a kind of care on or off. Starting a stay starts its hour now.
func set_stay(kind: String, on: bool, now: int) -> bool:
	if not kind in VoyageCatalog.STAY_KINDS or (on and is_sailing()): return false
	var was := stay_on()
	stay[kind] = on
	if stay_on() and not was:
		stay.last = now
		stay.spent = 0
	return true

func set_supplies(on: bool) -> void:
	stay.supplies = on

func set_budget(amount: int) -> void:
	stay.budget = maxi(amount, 0)

func set_target(faction: String, value: int) -> void:
	stay.target_faction = faction if faction in local_factions() else ""
	stay.target = clampi(value, 0, cap())

## The stay's ceiling (R3).
static func cap() -> int:
	return int(Exchange.RANK_AT[VoyageCatalog.STAY_CAP_RANK])

## The factions a stay here touches (not 企鹅物流).
func local_factions(at: String = "") -> Array[String]:
	if at.is_empty(): at = docked_at()
	var out: Array[String] = []
	for f in VoyageCatalog.ANCHOR_FACTIONS.get(at, []):
		if not FactionCatalog.info(f).get("transport", false): out.append(f)
	return out

## Relation an hour for `faction` with the care now on (before the cap).
func stay_rate(faction: String) -> float:
	var rate := 0.0
	for kind in VoyageCatalog.STAY_KINDS:
		if bool(stay[kind]): rate += float(VoyageCatalog.STAY_BASE[kind]) * VoyageCatalog.stay_mult(faction, kind)
	if rate > 0.0 and game.base.researched("stay_care"): rate *= 1.2
	if faction == "ursus" and bool(stay.infected): rate += VoyageCatalog.URSUS_INFECTED_LOSS
	return rate

## 龙门币 an hour before supplies.
func hour_cost() -> int:
	var cost := 0
	for kind in VoyageCatalog.STAY_KINDS:
		if bool(stay[kind]): cost += int(VoyageCatalog.STAY_COST[kind])
	if bool(stay.infected) and docked_at() == "叙拉古": cost += VoyageCatalog.SIRACUSA_INSURANCE
	return roundi(cost * 0.8) if game.base.researched("stay_care") else cost

## Medical goods on the shelves that would pay for this hour: [[item, units]], value.
func supply_plan(cost: int) -> Array:
	var limit := float(cost) * VoyageCatalog.SUPPLY_SHARE
	var goods: Array[Item] = []
	for item in game.base.shelf:
		if item.effect.is_empty() and FactionCatalog.material_category(item.material_id) == "medical": goods.append(item)
	goods.sort_custom(func(a, b): return a.unit_value < b.unit_value)
	var plan: Array = []
	var value := 0.0
	for item in goods:
		var unit := float(Economy.lmd(item.unit_value))
		if unit <= 0.0 or value + unit > limit: continue
		var units := mini(item.quantity, floori((limit - value) / unit))
		if units <= 0: continue
		plan.append([item, units])
		value += unit * units
	return [plan, roundi(value)]

## Settles every whole hour up to `now`; stops the stay when it must.
func _tick_stay(now: int) -> void:
	if not stay_on(): return
	var hours := 0
	while stay_on() and now - int(stay.last) >= 3600 and hours < VoyageCatalog.CATCH_UP_HOURS:
		hours += 1
		stay.last = int(stay.last) + 3600
		if not _settle_hour(int(stay.last)): _stop_stay()
	if hours >= VoyageCatalog.CATCH_UP_HOURS: stay.last = now

func _stop_stay(why: String = "") -> void:
	for kind in VoyageCatalog.STAY_KINDS: stay[kind] = false
	_say("医疗驻留结束%s。" % ("：" + why if not why.is_empty() else ""))

## One hour of care; false when the stay stops instead.
func _settle_hour(at: int) -> bool:
	var here := docked_at()
	var cost := hour_cost()
	var plan: Array = supply_plan(cost) if bool(stay.supplies) else [[], 0]
	var cash := cost - int(plan[1])
	if int(stay.budget) > 0 and int(stay.spent) + cash > int(stay.budget): return false
	if game.gold < cash: return false
	game.gold -= cash
	stay.spent = int(stay.spent) + cash
	for entry in plan[0]:
		var item: Item = entry[0]
		if item.quantity > int(entry[1]): item.set_quantity(item.quantity - int(entry[1]))
		else: game.base.take_from_shelf(item)
	anchor_hours += 1
	game.base.stayed = true
	var struck := bool(stay.infected) and here == "卡西米尔" and game.rng.randf() < VoyageCatalog.KAZ_CHANCE
	if struck:
		game.exchange.add_relation("kazimierz", VoyageCatalog.KAZ_LOSS)
		_say("无胄盟袭击了接受治疗的感染者骑士。")
	for f in local_factions(here):
		if struck and f == "kazimierz": continue
		_gain(f, stay_rate(f))
	if bool(stay.infected): _conflict_hour(here)
	# Stop when the target is met, or nobody here can gain any more.
	var target := str(stay.target_faction)
	if not target.is_empty() and game.exchange.relation(target) >= int(stay.target):
		_stop_stay("%s 已达 %d" % [FactionCatalog.name_of(target), int(stay.target)])
		return true
	var locals := local_factions(here)
	if not locals.is_empty() and locals.all(func(f): return stay_rate(f) <= 0.0 or game.exchange.relation(f) >= cap()):
		_stop_stay("已达上限")
	return true

## Adds `rate` to a faction through its fraction; gains stop at the cap.
func _gain(faction: String, rate: float) -> void:
	if rate == 0.0: return
	var have := game.exchange.relation(faction)
	if rate > 0.0 and have >= cap():
		relation_frac.erase(faction)
		return
	var total := float(relation_frac.get(faction, 0.0)) + rate
	var whole := int(total) if total >= 0.0 else -int(-total)
	relation_frac[faction] = total - whole
	if whole > 0: whole = mini(whole, cap() - have)
	if whole != 0: game.exchange.add_relation(faction, whole)

func _conflict_hour(here: String) -> void:
	infected_hours[here] = int(infected_hours.get(here, 0)) + 1
	if int(infected_hours[here]) % VoyageCatalog.CONFLICT_HOURS != 0: return
	match here:
		"切尔诺伯格": mine_threat = minf(VoyageCatalog.MINE_THREAT_CAP, mine_threat + VoyageCatalog.MINE_THREAT_STEP)
		"叙拉古": siracusa_debt = maxf(VoyageCatalog.SIRACUSA_DEBT_FLOOR, siracusa_debt * VoyageCatalog.SIRACUSA_DEBT_STEP)

## The threat a contract in `region` starts with (0–1 of the meter).
func threat_start(region: String) -> float:
	return mine_threat if region == "mine" else 0.0

## The 血债 rate of a contract in `region`.
func debt_mult(region: String) -> float:
	return siracusa_debt if region == "siracusa" else 1.0

## A day's stay here: the anchor's field posts are likelier (§3.3).
func post_boost(region: String) -> bool:
	return not is_sailing() and VoyageCatalog.region_at(place()) == region and anchor_hours >= VoyageCatalog.POST_HOURS

## A contract in `region` is over: its waiting field effects are spent.
func contract_done(region: String) -> void:
	match region:
		"mine": mine_threat = 0.0
		"siracusa": siracusa_debt = 1.0

# --- Bulk orders (§5) -------------------------------------------------------------------------

## Materials an order may ask of `faction`: in its liked categories, ★1–3.
static func order_materials(faction: String) -> Array[String]:
	var out: Array[String] = []
	for id in MaterialCatalog.MATERIALS:
		if id == Economy.GOLD_ID or int(MaterialCatalog.MATERIALS[id].star) > 3: continue
		if str(MaterialCatalog.MATERIALS[id].get("source", "")) in ["pack", "trade"]: continue
		var category := FactionCatalog.material_category(id)
		if category in VoyageCatalog.ORDER_CATEGORIES and FactionCatalog.preference(faction, category) > 0.0: out.append(id)
	return out

static func order_factions() -> Array[String]:
	var out: Array[String] = []
	for f in FactionCatalog.trading():
		if not order_materials(f).is_empty(): out.append(f)
	return out

func _new_order(now: int) -> Dictionary:
	var rng := game.rng
	var factions := order_factions()
	var faction: String = factions[rng.randi() % factions.size()]
	var pool := order_materials(faction)
	var lines := {}
	var value := 0.0
	var pay_lmd := 0.0
	var room := VoyageCatalog.ORDER_TOTAL
	for i in range(rng.randi_range(VoyageCatalog.ORDER_LINES.x, VoyageCatalog.ORDER_LINES.y)):
		var id: String = pool[rng.randi() % pool.size()]
		if lines.has(id) or room < VoyageCatalog.ORDER_COUNT.x: continue
		var count := rng.randi_range(VoyageCatalog.ORDER_COUNT.x, mini(VoyageCatalog.ORDER_COUNT.y, room))
		room -= count
		lines[id] = count
		var worth := float(Economy.price(MaterialCatalog.create(id, 1))) * count
		value += worth
		pay_lmd += worth * FactionCatalog.preference(faction, FactionCatalog.material_category(id)) * VoyageCatalog.ORDER_PREMIUM
	var currency := FactionCatalog.currency(faction)
	var lo := VoyageCatalog.ORDER_RELATION.x
	var relation := lo + mini(VoyageCatalog.ORDER_RELATION.y - lo, roundi(value / VoyageCatalog.ORDER_RELATION_VALUE * (VoyageCatalog.ORDER_RELATION.y - lo)))
	var order := {"id": _next_id, "faction": faction, "lines": lines, "value": roundi(value),
		"pay": snappedf(Exchange.from_lmd(currency, pay_lmd), 0.01), "currency": currency, "relation": relation,
		"expires": now + VoyageCatalog.ORDER_TERM, "state": "open", "due": 0, "cargo": "", "floors": {}}
	_next_id += 1
	return order

## Bulk-order slots and refill time: 5 and 4 h with 后勤部 5 阶.
func order_slots() -> int:
	return VoyageCatalog.ORDER_SLOTS + (1 if game.base.researched("bulk_orders") else 0)

func order_refill() -> int:
	return 4 * 3600 if game.base.researched("bulk_orders") else VoyageCatalog.ORDER_REFILL

func _tick_orders(now: int) -> void:
	var slots := order_slots()
	var refill := order_refill()
	if last_refill == 0:
		last_refill = now
		while orders.size() < slots: orders.append(_new_order(now))
	while orders.size() < slots and now - last_refill >= refill:
		last_refill += refill
		orders.append(_new_order(last_refill))
	if orders.size() >= slots: last_refill = maxi(last_refill, now - refill)
	for order in orders.duplicate():
		match str(order.state):
			"handover":
				if now >= int(order.due): _complete(order)
			"open", "packed":
				if now >= int(order.expires): _expire(order)

func order(id: int) -> Dictionary:
	for o in orders:
		if int(o.id) == id: return o
	return {}

## "" when the order's goods are all in the warehouse.
func goods_refusal(o: Dictionary) -> String:
	return game.materials_refusal(o.lines)

## Handover in the faction's waters: from the warehouse, or the packed crate.
func submit_refusal(id: int) -> String:
	var o := order(id)
	if o.is_empty() or not str(o.state) in ["open", "packed"]: return "订单不可提交"
	if not in_waters(str(o.faction)): return "不在境内"
	if str(o.state) == "packed": return "" if cargo_item(o) != null and game.base.location_of(cargo_item(o)) != "" else "货箱不在仓库"
	return goods_refusal(o)

func submit(id: int, now: int) -> bool:
	if not submit_refusal(id).is_empty(): return false
	var o := order(id)
	if str(o.state) == "packed": game.base.remove_item(cargo_item(o))
	else: game.consume_materials(o.lines)
	o.state = "handover"
	o.due = now + VoyageCatalog.HANDOVER
	o.cargo = ""
	return true

func pack_refusal(id: int) -> String:
	var o := order(id)
	if o.is_empty() or str(o.state) != "open": return "订单不可装箱"
	if in_waters(str(o.faction)): return "已在境内"
	return goods_refusal(o)

## Packs the goods into the crate: it goes to staging (or receiving), and the
## delivery floors are drawn from where she has been (§5.3).
func pack(id: int) -> bool:
	if not pack_refusal(id).is_empty(): return false
	var o := order(id)
	game.consume_materials(o.lines)
	var crate := make_cargo(o)
	if not game.base.receive_to_staging(crate): game.base.receive(crate)
	o.cargo = crate.uid
	o.state = "packed"
	var floors := {}
	for region in VoyageCatalog.DELIVERY_MAPS.get(str(o.faction), []):
		floors[region] = delivery_floor(int(game.base.camps.get(region, 0)), game.rng)
	o.floors = floors
	return true

## A floor she can reach: 1 .. deepest camp + DELIVERY_REACH, never a camp.
static func delivery_floor(camp: int, rng: RandomNumberGenerator) -> int:
	var top := maxi(camp, 0) + VoyageCatalog.DELIVERY_REACH
	var pick := rng.randi_range(1, top)
	while pick % FieldCatalog.CAMP_INTERVAL == 0: pick = rng.randi_range(1, top)
	return pick

static func make_cargo(o: Dictionary) -> Item:
	var size := VoyageCatalog.CARGO_SIZE
	var crate := Item.create(VoyageCatalog.CARGO_NAME, Item.Category.MATERIAL, size.x, size.y)
	crate.effect = VoyageCatalog.CARGO_EFFECT
	crate.value = 0
	crate.rarity = Item.PURPLE
	crate.description = "%s · %s" % [FactionCatalog.name_of(str(o.faction)), "、".join((o.lines as Dictionary).keys().map(func(k): return "%s×%d" % [k, int(o.lines[k])]))]
	return crate

## The order's crate, wherever it is (base or carried), or null.
func cargo_item(o: Dictionary) -> Item:
	if str(o.get("cargo", "")).is_empty(): return null
	var pool: Array[Item] = game.base.all_items()
	pool.append_array(game.carried_items())
	for item in pool:
		if item.uid == str(o.cargo): return item
	return null

## Delivery contracts for `region`'s dispatch desk (§5.3).
func delivery_offers(region: String) -> Array:
	var out := []
	for o in orders:
		if str(o.state) != "packed" or not (o.floors as Dictionary).has(region): continue
		if in_waters(str(o.faction)): continue
		out.append({"type": "deliver", "order": int(o.id), "faction": str(o.faction), "floor": int(o.floors[region]),
			"pay": float(o.pay), "currency": str(o.currency), "relation": int(o.relation)})
	return out

## The crate was handed over in the field: paid at settlement.
func handed_over(id: int) -> void:
	var o := order(id)
	if o.is_empty(): return
	o.state = "delivered"
	o.cargo = ""

## After a contract: delivered orders pay; a packed crate that is nowhere any
## more was lost with her pack, and the order is open again.
func on_settle() -> void:
	for o in orders.duplicate():
		if str(o.state) == "delivered": _complete(o)
		elif str(o.state) == "packed" and cargo_item(o) == null:
			o.state = "open"
			o.cargo = ""
			o.floors = {}

func _complete(o: Dictionary) -> void:
	orders.erase(o)
	game.exchange.credit(str(o.currency), float(o.pay))
	game.exchange.add_relation(str(o.faction), int(o.relation))
	_say("大宗订单完成：%s，%s，关系 +%d。" % [FactionCatalog.name_of(str(o.faction)), Exchange.format_money(str(o.currency), float(o.pay)), int(o.relation)])

## Expired: a packed crate is unpacked and the goods go back to staging.
func _expire(o: Dictionary) -> void:
	orders.erase(o)
	var crate := cargo_item(o)
	if crate == null: return
	if game.base.location_of(crate) != "": game.base.remove_item(crate)
	else:
		game.inventory.remove(crate)
		game.safe_bag.remove(crate)
	for id in o.lines:
		var left := int(o.lines[id])
		while left > 0:
			var stack := MaterialCatalog.create(id, mini(left, MaterialCatalog.stack_size(id)))
			left -= stack.quantity
			if not game.base.receive_to_staging(stack): game.base.receive(stack)

# --- Clock and save --------------------------------------------------------------------------

## Everything up to `now`, in order: arrival, the stay's hours, orders.
func tick(now: int) -> void:
	if is_sailing() and now >= int(sailing.due): _arrive()
	_tick_stay(now)
	_tick_orders(now)

func to_data() -> Dictionary:
	return {"sailing": sailing.duplicate(), "stay": stay.duplicate(), "anchor_hours": anchor_hours,
		"infected_hours": infected_hours.duplicate(), "mine_threat": mine_threat, "siracusa_debt": siracusa_debt,
		"relation_frac": relation_frac.duplicate(),
		"orders": orders.duplicate(true), "last_refill": last_refill, "next_id": _next_id}

func load_data(d: Dictionary) -> void:
	sailing = (d.get("sailing", {}) as Dictionary).duplicate()
	if not sailing.is_empty() and not str(sailing.get("to", "")) in VoyageCatalog.ANCHORS: sailing = {}
	var saved: Dictionary = d.get("stay", {})
	for key in stay:
		if saved.has(key): stay[key] = saved[key]
	anchor_hours = int(d.get("anchor_hours", 0))
	infected_hours = (d.get("infected_hours", {}) as Dictionary).duplicate()
	mine_threat = clampf(float(d.get("mine_threat", 0.0)), 0.0, VoyageCatalog.MINE_THREAT_CAP)
	siracusa_debt = clampf(float(d.get("siracusa_debt", 1.0)), VoyageCatalog.SIRACUSA_DEBT_FLOOR, 1.0)
	relation_frac = (d.get("relation_frac", {}) as Dictionary).duplicate()
	orders = (d.get("orders", []) as Array).duplicate(true)
	for o in orders:
		o.id = int(o.id)
		o.lines = (o.lines as Dictionary)
		for k in o.lines: o.lines[k] = int(o.lines[k])
		var floors := {}
		for region in (o.get("floors", {}) as Dictionary): floors[region] = int(o.floors[region])
		o.floors = floors
	last_refill = int(d.get("last_refill", 0))
	_next_id = int(d.get("next_id", 1))
