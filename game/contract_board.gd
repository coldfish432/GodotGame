class_name ContractBoard
extends RefCounted

## 合同板 (合同板修订案_v0_1.md): the departments post what they need, she takes
## several at once and they stay taken until done or dropped.
##
## A card is a Dictionary {uid, dept, type, region ("" any), age, …}:
##   deep    {steps, roll}            外勤部 · reach start + steps, extract (one run)
##   hunt    {offset, roll}           外勤部 · the bounty on start + offset (one run)
##   recover {material, count, gold}  工程部 / 医疗部 · hand over at the base (cumulative)
##   order   {id}                     工程部 / 医疗部 / 后勤部 / 加工部 · BaseCatalog.ORDERS (cumulative)
##   deliver {order, faction, floor, pay, currency, relation}  商务部 · 沙盘订单 (one run)
## Taken cumulative cards carry "delivered": [{uid, name, value, count}].
## 运送 cards are never posted: they come live from the voyage's packed orders.
##
## After every settlement the untaken cards age; those up for AGE_LIMIT
## settlements go and the departments fill their slots again, under the old
## order-board rules: one exclusive-item order at most, one card pointing away
## from the last region, no template twice.

const CAP := 3
const AGE_LIMIT := 2
const DEPT_SLOTS := {"外勤部": 3, "工程部": 2, "医疗部": 1, "后勤部": 2, "加工部": 1}
const DEPT_ORDER := ["外勤部", "工程部", "医疗部", "后勤部", "加工部", "商务部"]
## Kinds done inside one run (the rest are handed over at the base).
const RUN_KINDS := ["deep", "hunt", "deliver"]
## Who asks for which region material (FieldCatalog.RECOVER_TARGETS).
const RECOVER_DEPT := {"代糖": "医疗部", "糖": "医疗部", "双酮": "医疗部"}

var posted: Array = []
var active: Array = []
var serial := 0

# --- What a card is ------------------------------------------------------------------

static func is_run(c: Dictionary) -> bool:
	return str(c.get("type", "")) in RUN_KINDS

static func is_delivery(c: Dictionary) -> bool:
	return not is_run(c)

static func dept_of_material(material: String) -> String:
	return str(RECOVER_DEPT.get(material, "工程部"))

## What a handed-over card asks for: the ORDERS template, or the recover card as one.
static func spec(c: Dictionary) -> Dictionary:
	if str(c.get("type", "")) == "order": return BaseCatalog.ORDERS.get(str(c.get("id", "")), {})
	if str(c.get("type", "")) == "recover": return {"dept": c.dept, "count": int(c.count), "material": str(c.material), "gold": int(c.get("gold", 0)), "region": str(c.get("region", ""))}
	return {}

static func is_exclusive(c: Dictionary) -> bool:
	return str(c.get("type", "")) == "order" and BaseCatalog.ORDERS.has(str(c.get("id", ""))) and BaseCatalog.is_exclusive_order(str(c.id))

## The same card twice: one template, one region material, one depth or bounty floor in one region.
static func _key(c: Dictionary) -> String:
	match str(c.get("type", "")):
		"order": return "order:" + str(c.get("id", ""))
		"recover": return "recover:%s:%s" % [c.get("region", ""), c.get("material", "")]
		"deliver": return "deliver:%d" % int(c.get("order", 0))
		"deep": return "deep:%s:%d" % [c.get("region", ""), int(c.get("steps", 0))]
		"hunt": return "hunt:%s:%d" % [c.get("region", ""), int(c.get("offset", 0))]
	return "%s:%s" % [c.get("type", ""), c.get("region", "")]

# --- Taking and dropping ---------------------------------------------------------------

func find_posted(uid: int) -> Dictionary:
	for c in posted:
		if int(c.uid) == uid: return c
	return {}

func find_active(uid: int) -> Dictionary:
	for c in active:
		if int(c.uid) == uid: return c
	return {}

## Why `card` cannot be taken now ("" when it can): the cap, or the same run
## kind already taken for its region (one bounty, one handover, one depth a run).
func refusal(card: Dictionary, cap: int) -> String:
	if active.size() >= cap: return "full"
	if is_run(card):
		for c in active:
			if str(c.type) == str(card.type) and str(c.get("region", "")) == str(card.get("region", "")): return "same"
	for c in active:
		if _key(c) == _key(card): return "same"
	return ""

## Takes a posted card (or a live 运送 card, given whole). Returns the taken card or {}.
func take(card: Dictionary, cap: int) -> Dictionary:
	if card.is_empty() or not refusal(card, cap).is_empty(): return {}
	var taken: Dictionary = card.duplicate(true)
	if taken.has("uid") and not find_posted(int(taken.uid)).is_empty():
		posted.erase(find_posted(int(taken.uid)))
	else:
		serial += 1
		taken.uid = serial
	taken.erase("age")
	if is_delivery(taken): taken.delivered = []
	active.append(taken)
	return taken

## Drops a taken card. What was handed over for it stays handed over.
func abandon(uid: int) -> bool:
	var c := find_active(uid)
	if c.is_empty(): return false
	active.erase(c)
	return true

func finish(uid: int) -> void:
	active.erase(find_active(uid))

## Taken run cards for `region` (and any-region ones), as this run carries them.
func run_cards(region: String) -> Array:
	return active.filter(func(c): return is_run(c) and str(c.get("region", "")) in ["", region])

func deliveries() -> Array:
	return active.filter(func(c): return is_delivery(c))

# --- Handing over (the old order board) ------------------------------------------------

## Whether `item` is what taken card `c` asks for.
static func matches(c: Dictionary, item: Item) -> bool:
	if c.is_empty() or not is_delivery(c) or item == null or item.is_potion() or GearCatalog.bound(item) or item.contents != null: return false
	var t := spec(c)
	if t.is_empty(): return false
	# A sealed ore is still the ore (地图特色策划案 §3.3).
	if t.has("effect"): return item.effect == t.effect or (t.effect == "raw_ore" and item.effect == GameManager.SEALED_ORE)
	if t.has("material"): return item.material_id == t.material
	if Item.group_of(item.category) != Item.group_of(int(t.category)) or item.rarity < int(t.get("min_rarity", 0)): return false
	if t.has("region") and item.origin_region != t.region: return false
	return true

static func delivered_count(c: Dictionary) -> int:
	return (c.get("delivered", []) as Array).reduce(func(sum, d): return sum + int(d.get("count", 1)), 0)

static func need(c: Dictionary) -> int:
	return int(spec(c).get("count", 0))

static func remaining(c: Dictionary) -> int:
	return need(c) - delivered_count(c)

## How many units of `item` card `c` would take (0 when it does not match).
static func takes(c: Dictionary, item: Item) -> int:
	if not matches(c, item): return 0
	return mini(remaining(c), item.quantity if item.is_stackable() else 1)

## Hands `item` over to taken card `uid`. {} when refused, else {"done", "gold",
## "used"}; a finished card leaves the board. gold is 0 until it is finished.
func deliver(uid: int, item: Item) -> Dictionary:
	var c := find_active(uid)
	var used := takes(c, item)
	if used <= 0: return {}
	var value := item.unit_value * used if item.is_stackable() else item.value
	(c.delivered as Array).append({"uid": item.uid, "name": item.item_name, "value": value, "count": used})
	if remaining(c) > 0: return {"done": false, "gold": 0, "used": used}
	active.erase(c)
	var t := spec(c)
	# 龙门币: fixed, or the delivered 交付价 times the template's multiplier.
	var gold := int(t.gold) if t.has("gold") else int(round(Economy.lmd(c.delivered.reduce(func(sum, d): return sum + int(d.value), 0)) * float(t.mult)))
	return {"done": true, "gold": gold, "used": used}

## Taken delivery cards pointing at `region`.
func pointing_at(region: String) -> int:
	return deliveries().filter(func(c): return str(spec(c).get("region", "")) == region).size()

# --- Posting ---------------------------------------------------------------------------

## ctx: {"regions": open regions, "depts": open departments, "extra": {dept: slots},
## "start": Callable(region) -> start floor the recover pay is fixed from,
## "bonus": int (合同报酬 research ×10000)}.
func slots_of(dept: String, ctx: Dictionary) -> int:
	return int(DEPT_SLOTS.get(dept, 0)) + int((ctx.get("extra", {}) as Dictionary).get(dept, 0))

## After a settlement: untaken cards age, the old ones go, empty slots fill.
func after_settlement(rng: RandomNumberGenerator, ctx: Dictionary, last_region: String) -> void:
	for c in posted: c.age = int(c.get("age", 0)) + 1
	posted = posted.filter(func(c): return int(c.age) < AGE_LIMIT and str(c.get("region", "")) in [""] + (ctx.regions as Array))
	fill(rng, ctx, last_region)

## Fills every open department's empty slots.
func fill(rng: RandomNumberGenerator, ctx: Dictionary, last_region := "") -> void:
	var fresh: Array = []
	for dept in DEPT_ORDER:
		if not dept in (ctx.depts as Array): continue
		var have := posted.filter(func(c): return c.dept == dept).size()
		for i in range(slots_of(dept, ctx) - have):
			var card := _roll(dept, rng, ctx)
			if card.is_empty(): break
			posted.append(card)
			fresh.append(card)
	# One card pointing somewhere other than the last region (old rule 2).
	if not last_region.is_empty() and not fresh.is_empty() and not _points_away(last_region):
		for attempt in range(8):
			var old: Dictionary = fresh[rng.randi_range(0, fresh.size() - 1)]
			var away := _roll(str(old.dept), rng, ctx, last_region, old)
			if away.is_empty(): continue
			posted[posted.find(old)] = away
			break

func _points_away(last_region: String) -> bool:
	for c in posted:
		var r := str(c.get("region", ""))
		if not r.is_empty() and r != last_region: return true
	return false

## A new card from `dept`, unlike what is on the board; `avoid` a region it must not be in.
func _roll(dept: String, rng: RandomNumberGenerator, ctx: Dictionary, avoid := "", replacing := {}) -> Dictionary:
	var on_board: Array = (posted + active).filter(func(c): return c != replacing).map(func(c): return _key(c))
	var has_exclusive := (posted + active).any(func(c): return c != replacing and is_exclusive(c))
	var regions: Array = (ctx.regions as Array).filter(func(r): return r != avoid)
	var pool: Array = []   # [weight, card]
	if dept == "外勤部":
		for region in regions:
			for steps in FieldCatalog.DEEP_STEPS: pool.append([4, {"type": "deep", "region": region, "steps": steps}])
			for offset in range(FieldCatalog.HUNT_OFFSETS.x, FieldCatalog.HUNT_OFFSETS.y + 1): pool.append([3, {"type": "hunt", "region": region, "offset": offset}])
	for region in regions:
		for pick in FieldCatalog.RECOVER_TARGETS.get(region, []):
			if dept_of_material(str(pick[0])) == dept:
				pool.append([2, {"type": "recover", "region": region, "material": str(pick[0]), "count": int(pick[1])}])
	for id in BaseCatalog.ORDERS:
		var t: Dictionary = BaseCatalog.ORDERS[id]
		if t.dept != dept or int(t.weight) <= 0: continue
		if has_exclusive and BaseCatalog.is_exclusive_order(id): continue
		var region := str(t.get("region", ""))
		if not region.is_empty() and not region in regions: continue
		if not avoid.is_empty() and region.is_empty(): continue
		pool.append([int(t.weight), {"type": "order", "id": id, "region": region}])
	pool = pool.filter(func(p): return not _key(p[1]) in on_board)
	if pool.is_empty(): return {}
	var total: int = pool.reduce(func(s, p): return s + int(p[0]), 0)
	var roll := rng.randi_range(1, total)
	var card: Dictionary = pool.back()[1]
	for p in pool:
		roll -= int(p[0])
		if roll <= 0:
			card = p[1]
			break
	return _post(card, dept, rng, ctx)

func _post(card: Dictionary, dept: String, rng: RandomNumberGenerator, ctx: Dictionary) -> Dictionary:
	serial += 1
	card.uid = serial
	card.dept = dept
	card.age = 0
	if str(card.type) in ["deep", "hunt", "recover"]:
		card.roll = snappedf(rng.randf_range(Economy.CONTRACT_ROLL.x, Economy.CONTRACT_ROLL.y), 0.01)
	# A recover card's pay is fixed when posted, from her deepest start there.
	if str(card.type) == "recover":
		var start: int = (ctx.start as Callable).call(str(card.region)) if ctx.get("start") is Callable else 1
		card.gold = roundi(Economy.contract_reward(card, start) * int(ctx.get("bonus", 10000)) / 10000.0) * 100
	return card

## 外勤部 2 阶: swaps posted card `uid` for a fresh one from the same department.
func reroll(uid: int, rng: RandomNumberGenerator, ctx: Dictionary) -> bool:
	var old := find_posted(uid)
	if old.is_empty(): return false
	var fresh := _roll(str(old.dept), rng, ctx, "", old)
	if fresh.is_empty(): return false
	posted[posted.find(old)] = fresh
	return true

## A taken card made by hand (the first contract, an old save's order).
func add_active(card: Dictionary, dept: String) -> Dictionary:
	serial += 1
	var c := card.duplicate(true)
	c.uid = serial
	c.dept = dept
	if is_delivery(c) and not c.has("delivered"): c.delivered = []
	active.append(c)
	return c

# --- Save ------------------------------------------------------------------------------

func to_data() -> Dictionary:
	return {"posted": posted.duplicate(true), "active": active.duplicate(true), "serial": serial}

func load_data(data: Dictionary) -> void:
	posted = (data.get("posted", []) as Array).filter(func(c): return _valid(c)).map(func(c): return (c as Dictionary).duplicate(true))
	active = (data.get("active", []) as Array).filter(func(c): return _valid(c)).map(func(c): return (c as Dictionary).duplicate(true))
	serial = int(data.get("serial", 0))
	for c in posted + active: serial = maxi(serial, int(c.get("uid", 0)))

static func _valid(c) -> bool:
	if not c is Dictionary or not c.has("uid") or not c.has("type"): return false
	match str(c.type):
		"order": return BaseCatalog.ORDERS.has(str(c.get("id", "")))
		"deep", "hunt", "recover", "deliver": return true
	return false

## An old save's order board: open orders become taken 交付 cards (past the cap
## if need be: this once), done or empty slots go.
func migrate_orders(slots: Array) -> void:
	for entry in slots:
		if not entry is Dictionary or str(entry.get("state", "")) != "open" or not BaseCatalog.ORDERS.has(str(entry.get("id", ""))): continue
		var t: Dictionary = BaseCatalog.ORDERS[entry.id]
		var c := add_active({"type": "order", "id": str(entry.id), "region": str(t.get("region", ""))}, str(t.dept))
		c.delivered = (entry.get("delivered", []) as Array).duplicate(true)
