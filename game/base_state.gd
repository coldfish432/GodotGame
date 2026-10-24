class_name BaseState
extends RefCounted

## Where every item at the base is, and the rules for moving it
## (基地玩法策划案_v1_0.md §3.1, 仓库修订 用户 2026-10-23): the warehouse
## (`shelf`, was GameManager.stash) is one count of cells for every kind of
## item, a stack of one material per cell up to its limit × stack_mult().
## What comes home stays in the bags until it is put away (at settlement's
## 仓库 page or the 仓管台); what the base itself brings back (insured gear,
## the workshop, a parcel) goes straight in. No crates, staging or carrying.
##
## Equipped and packed items (the loadout) belong to GameManager and the player;
## they are not tracked here. Every move checks first and changes nothing when
## it fails, so a refused move never loses or duplicates an item.

var shelf: Array[Item] = []
## Category -> racks drawn in the warehouse room (by 仓储部 level, racks_shown).
var racks := {}
## Facility id -> level (BaseCatalog.FACILITIES). Levels unlock convenience and
## capacity only, never combat strength.
var facilities := {}
## Facilities connected to the 基建总控台 (upgraded from there as well as on site).
var connected: Array[String] = []
var orders := OrderBoard.new()
## Medical (§4). An injury belongs to the operator who fell and stays on her
## until it is treated (博士主角叙事修订案 §5, 用户 2026-10-15); contamination
## does not leave the field (用户 2026-10-15: 污染不带出局外). id -> the tier
## of the floor she fell on (true in saves from before tiers: tier Ⅰ).
var injuries := {}
## Whether the operator who deploys next is injured.
var injured: bool:
	get: return injuries.has(operator)
	set(value):
		if value: injuries[operator] = maxi(1, int(injuries.get(operator, 1)))
		else: injuries.erase(operator)
## Free 标准急救剂 still to be issued for the next contract (药剂进背包). They go
## into the pack at departure; reset after every settlement.
var free_potions := BaseCatalog.FREE_POTIONS
## 可露希尔特供 left this window, and when she restocks (unix seconds;
## 用户 2026-10-21: 每日不限量，单位时间限量，需要时间补货).
var closure_stock := {}
var closure_restock_at := 0
## What the medical report adds to the item list: whether this settlement
## left an injury. Unread until she opens it.
var medical_report := {}
var report_unread := false
## Saves from before 仓库修订 bought a drone; it only lifts their 仓储部 level now.
var drone := false
## The 仓管台 always browses the whole warehouse (仓库修订: no console to buy).
var console := true
## Contract offers at the dispatch desk, region -> [contract] (局内节奏与目标策划案 §6 B1).
var contract_offers := {}
## Expansion levels into BaseCatalog.PACK_SIZES / SAFE_SIZES.
var pack_level := 0
var safe_level := 0
## A free order reroll (仓库修订 took 仓储部 Lv4's away; nothing grants one now).
var reroll_available := false
## Bad-luck protection for drops (掉落物策划案 §5.2), kept across contracts.
var loot_pity := {"rare_gear": 0.0, "rare_material": 0.0}
## 定向重铸's failures in a row (GameManager.directed_chance).
var directed_fails := 0
## Region bosses fallen at each tier, "region:tier" -> true (Boss与守卫者策划案 §10).
var boss_falls := {}
## Insured items lost on a death, waiting to come back (保全系统修订案 §3):
## {"item": Item, "left": contracts still to settle}. Every settlement counts
## one down; at zero the item arrives as a sealed crate.
var insurance_queue: Array[Dictionary] = []
## Camps reached (撤离与营地修订案 §3), per region: the deepest one unlocked (0 none).
## Any unlocked camp is a start point for that region.
var camps := {}
## Where Rhodes Island is on Terra (TerraMap place): it sails to whichever
## region a contract is run in, and the sand table shows it there.
var ship_at := TerraMap.START
## The camp upgrade, bought once for every region.
var camp_upgraded := false
## The first time she ever reaches floor 5 it has a random extraction for sure
## (用户 2026-10-22: 第一次下图 5 层必定有一个随机撤离点); set once that is given.
var first_extract_given := false
## She has extracted at least once (GameManager.first_run_lock).
var extracted_once := false
## 主线引导 (Story.fresh()).
var story := Story.fresh()
## 随队物资 bought from 可露希尔 (地图特色策划案 §8): "kit id@tier" -> count
## (tiers: v1.1 §4.1). Kept at the base, off the shelves; one taken per contract.
var kits := {}

## Kits of `id` in stock, every tier.
func kit_stock(id: String) -> int:
	var n := 0
	for key in kits:
		if str(key).get_slice("@", 0) == id: n += int(kits[key])
	return n

## The highest tier of `id` in stock (0 with none).
func kit_best_tier(id: String) -> int:
	var best := 0
	for key in kits:
		if str(key).get_slice("@", 0) == id and int(kits[key]) > 0: best = maxi(best, int(str(key).get_slice("@", 1)))
	return best

func add_kit(id: String, tier: int) -> void:
	var key := "%s@%d" % [id, tier]
	kits[key] = int(kits.get(key, 0)) + 1

## Takes one of `id`, the highest tier; returns its tier (0 with none).
func take_kit(id: String) -> int:
	var tier := kit_best_tier(id)
	if tier <= 0: return 0
	var key := "%s@%d" % [id, tier]
	kits[key] = int(kits[key]) - 1
	if int(kits[key]) <= 0: kits.erase(key)
	return tier
## The operator who deploys next (Operators.ORDER), picked at the departure screen.
var operator := default_operator()
## Who has joined (干员寻访策划案 §9): a new Doctor has only Amiya; the debug
## build keeps Lappland too (用户 2026-10-16: debug版本先保留).
var roster: Array[String] = []
## 踪迹 per operator (§2.1): a counter, never an item; a fall loses none.
var recruit_clues := {}
## id -> the trace keys of hers found so far (RecruitCatalog.TRACE_SMALL/BIG).
var recruit_found := {}
## Each operator's growth (精英化与加点策划案_v0_2.md): id -> OperatorProgress.
var progress := {}
## 作战记录 (§4.2): counters at 人事部. They drop in the field as items and
## turn into counters when they come home (龙门币平衡与科研部策划案 v1.1 §2.1).
var records := {}
## 科研部 (v1.1 §5): finished node ids; running research [{id, start, end}];
## signed projects id -> sorties left; endless line -> level; the projects
## charged for the contract under way.
var research := {"done": [], "active": [], "projects": {}, "endless": {}, "run": []}
## 农业部 and 食堂 (Provisions): basins, the kitchen queue, the 补给 eaten and the one mailed.
var farm := Provisions.fresh_state()
## Rhodes standard gear's rarity, raised by 工程部Ⅱ/Ⅳ (复利清单 D): 0 white, 1 blue, 2 gold.
var rhodes_rarity := 0
## 外勤部Ⅱ: one free contract reroll per return.
var contract_reroll := false
## A medical stay has run at least an hour (医疗部Ⅲ's requirement).
var stayed := false

## Whether research node `key` ("rack_cells") or id ("logistics_3") is done.
func researched(key: String) -> bool:
	var id := key if ResearchCatalog.valid(key) else ResearchCatalog.id_of_key(key)
	return id in (research.done as Array)

func endless_level(line: String) -> int:
	return int((research.endless as Dictionary).get(line, 0))

## A project paid for on the contract under way.
func project_on(project: String) -> bool:
	return project in (research.run as Array)

## The order board: 3 (仓库修订 moved 仓储部's extra slot to everyone), one
## more with 后勤部Ⅰ.
func order_slot_count() -> int:
	return BaseCatalog.ORDER_SLOTS + 1 + (1 if researched("order_slot") else 0)

## Free 标准急救剂 per contract: 4 with 医疗部Ⅰ.
func free_potion_count() -> int:
	return BaseCatalog.FREE_POTIONS + (1 if researched("free_potion") else 0)

func progress_for(id: String) -> OperatorProgress:
	if not progress.has(id): progress[id] = OperatorProgress.create(id)
	return progress[id]

func add_records(found: Dictionary) -> void:
	for name in found: records[name] = int(records.get(name, 0)) + int(found[name])

func unlock_camp(region: String, depth: int) -> void:
	if depth > 0 and depth % FieldCatalog.CAMP_INTERVAL == 0:
		camps[region] = maxi(int(camps.get(region, 0)), depth)

func camp_unlocked(region: String, depth: int) -> bool:
	return depth > 0 and depth % FieldCatalog.CAMP_INTERVAL == 0 and depth <= int(camps.get(region, 0))

func unlocked_camps(region: String) -> Array[int]:
	var out: Array[int] = []
	for depth in range(FieldCatalog.CAMP_INTERVAL, int(camps.get(region, 0)) + 1, FieldCatalog.CAMP_INTERVAL): out.append(depth)
	return out

func _init() -> void:
	roster = starting_roster()
	for category in range(Item.Category.size()):
		racks[category] = BaseCatalog.STARTING_RACKS
	orders.start_fresh()
	reset_facilities()
	orders.resize(order_slot_count())

func reset_facilities() -> void:
	facilities = {}
	for id in BaseCatalog.FACILITY_ORDER: facilities[id] = BaseCatalog.facility_start(id)
	connected = []
	_show_racks()

## The racks the warehouse room draws: three a level, every zone alike.
func _show_racks() -> void:
	for category in range(Item.Category.size()):
		racks[category] = clampi(facility_level("warehouse") * 3 - 2, BaseCatalog.STARTING_RACKS, BaseCatalog.RACK_SLOTS)

func hub_built() -> bool:
	return facility_level("hub") >= 1

func is_connected_to_hub(id: String) -> bool:
	return id == "hub" or id in connected

func connect_facility(id: String) -> void:
	if not is_connected_to_hub(id) and id in BaseCatalog.connectable(): connected.append(id)

## `id` at `level`, clamped (tools, tests and old saves).
func set_facility(id: String, level: int) -> void:
	facilities[id] = clampi(level, BaseCatalog.facility_start(id), BaseCatalog.facility_max(id))
	orders.resize(order_slot_count())
	_show_racks()

## Every facility at its top level (tools and tests).
func max_facilities() -> void:
	for id in BaseCatalog.FACILITY_ORDER: facilities[id] = BaseCatalog.facility_max(id)
	connected.assign(BaseCatalog.connectable())
	orders.resize(order_slot_count())
	_show_racks()

func facility_level(id: String) -> int:
	return int(facilities.get(id, BaseCatalog.facility_start(id)))

## Why `id` cannot go up a level now ("" if it can, given the gold; materials
## are GameManager's to check).
func facility_refusal(id: String, money: int) -> String:
	var step := BaseCatalog.facility_step(id, facility_level(id) + 1)
	if step.is_empty(): return "已满级"
	if money < int(step.price): return "龙门币不足"
	return ""

## Raises `id` one level; the caller pays. Returns the new level.
func raise_facility(id: String) -> int:
	facilities[id] = mini(facility_level(id) + 1, BaseCatalog.facility_max(id))
	orders.resize(order_slot_count())
	_show_racks()
	return facility_level(id)

## Max HP lost on the next contract: the injury's.
func hp_penalty() -> float:
	return BaseCatalog.hp_penalty(0.0, injured)

## Price of one flask (龙门币), or -1 when 可露希尔商店 does not stock it yet. A
## 标准急救剂 is free while some of this contract's free issue is left.
func potion_price(type: String) -> int:
	var p: Dictionary = BaseCatalog.POTIONS[type]
	if facility_level("store") < int(p.store): return -1
	if type == "A": return 0 if free_potions > 0 else BaseCatalog.POTION_A_PRICE
	return int(p.price)

## Who deploys on a new save: Amiya, the only operator a new Doctor has.
static func default_operator() -> String:
	return Operators.AMIYA_GUARD

## Everyone else is recruited (干员寻访策划案).
static func starting_roster() -> Array[String]:
	var out: Array[String] = [Operators.AMIYA_GUARD]
	return out

func recruited(id: String) -> bool:
	return id in roster

## Who can deploy: recruited, with her kit built (Operators.has_kit).
func deployable() -> Array[String]:
	var out: Array[String] = []
	for id in Operators.ORDER:
		if id in roster and Operators.has_kit(id): out.append(id)
	return out

func clues(id: String) -> int:
	return int(recruit_clues.get(id, 0))

## One more trace of `id`; true when it was her first.
func add_clue(id: String) -> bool:
	if recruited(id) or clues(id) >= RecruitCatalog.CLUES_NEEDED: return false
	recruit_clues[id] = clues(id) + 1
	return clues(id) == 1

## Trace `key` of `id` found on the floor: what it adds (a small one found
## before adds nothing, a big one found before half), kept within the need.
func add_trace(id: String, key: String) -> int:
	if recruited(id) or clues(id) >= RecruitCatalog.CLUES_NEEDED: return 0
	var found: Array = recruit_found.get(id, [])
	var gain := RecruitCatalog.trace_value(key, key in found)
	if not key in found:
		found.append(key)
		recruit_found[id] = found
	recruit_clues[id] = mini(RecruitCatalog.CLUES_NEEDED, clues(id) + gain)
	return gain

func found_before(id: String, key: String) -> bool:
	return key in (recruit_found.get(id, []) as Array)

## Her contract is on offer: enough traces, not yet joined.
func recruit_ready(id: String) -> bool:
	return not recruited(id) and clues(id) >= RecruitCatalog.CLUES_NEEDED

func recruit(id: String) -> void:
	if not Operators.valid(id) or recruited(id): return
	roster.append(id)
	Story.note(story, "joined")
	recruit_clues.erase(id)
	recruit_found.erase(id)

func reset_potions() -> void:
	free_potions = free_potion_count()

## Any operator still carrying an injury (the reception's marker).
func any_injured() -> bool:
	return not injuries.is_empty()

## Injured operators in Operators.ORDER.
func injured_operators() -> Array[String]:
	var out: Array[String] = []
	for id in Operators.ORDER:
		if injuries.has(id): out.append(id)
	return out

## After a settlement: a fall injures the operator who fell; an injury already
## there stays until treated. Returns the report it records.
## `tier` is the floor's she fell on: it sets the treatment's price.
func settle_medical(died: bool, tier: int = 1) -> Dictionary:
	if died: injuries[operator] = tier
	reset_potions()
	medical_report = {"injured": died, "operator": operator}
	report_unread = true
	return medical_report

## The wall clock insurance runs on (unix seconds); tests move it with clock_offset.
static var clock_offset := 0
## Tests that need the clock to stand still between their own moves pin it here (0: live).
static var frozen_clock := 0
## 可露希尔特供 on her base shelf: what is left of `type` this window. The
## whole line refills to its caps once the window has run out.
func closure_left(type: String) -> int:
	if now() >= closure_restock_at:
		closure_stock = {}
		for id in BaseCatalog.CLOSURE_LINE: closure_stock[id] = int(BaseCatalog.POTIONS[id].cap)
		closure_restock_at = now() + BaseCatalog.RESTOCK_SECONDS
	return int(closure_stock.get(type, 0))

## Seconds until she restocks.
func closure_restock_in() -> int:
	return maxi(0, closure_restock_at - now())

static func now() -> int:
	return (frozen_clock if frozen_clock > 0 else int(Time.get_unix_time_from_system())) + clock_offset

## Everything insured whose time has come arrives at receiving; returns those items.
func tick_insurance() -> Array[Item]:
	var arrived: Array[Item] = []
	var t := now()
	for entry in insurance_queue.duplicate():
		if int(entry.due) <= t:
			insurance_queue.erase(entry)
			if receive(entry.item): arrived.append(entry.item)
	return arrived

## `item` comes back `seconds` from now.
func queue_insured(item: Item, seconds: int) -> void:
	insurance_queue.append({"item": item, "due": now() + maxi(seconds, 1)})

## 送回 and other arrivals (the squad, the workshop, a parcel): straight into
## the warehouse, full or not — nothing that comes home is lost.
func receive_to_staging(item: Item) -> bool:
	return receive(item)

# --- Expansion (§3.5) -------------------------------------------------------------

## "" when the next pack ("pack") or safe-bag ("safe") level can be bought.
func upgrade_refusal(kind: String, money: int) -> String:
	var level := pack_level if kind == "pack" else safe_level
	var prices: Array = BaseCatalog.PACK_PRICES if kind == "pack" else BaseCatalog.SAFE_PRICES
	var needs: Array = BaseCatalog.PACK_LEVELS if kind == "pack" else BaseCatalog.SAFE_LEVELS
	if level + 1 >= prices.size(): return "已满配"
	if facility_level("outfit") < int(needs[level + 1]): return "需要整备部 Lv%d" % int(needs[level + 1])
	if money < int(prices[level + 1]): return "龙门币不足"
	return ""

func can_upgrade(kind: String, money: int) -> bool:
	return upgrade_refusal(kind, money).is_empty()

## Nothing to sort any more (仓库修订): kept so old callers read an empty result.
func sort_all() -> Dictionary:
	return {"revealed": [], "shelved": [], "staged": [], "left": []}

func sort_staging() -> Dictionary:
	return sort_all()

# --- Queries -----------------------------------------------------------------

## The warehouse's cells (仓库修订: one count for every kind of item). The
## category argument is kept for old callers and ignored.
func capacity(_category: int = 0) -> int:
	var cells := int(BaseCatalog.WAREHOUSE_CELLS[clampi(facility_level("warehouse"), 1, BaseCatalog.WAREHOUSE_CELLS.size() - 1)])
	if researched("rack_cells"): cells = roundi(cells * (1.0 + BaseCatalog.RESEARCH_CELLS))
	return cells

## How many times a stack's own limit one warehouse cell holds.
func stack_mult() -> int:
	return int(BaseCatalog.WAREHOUSE_STACK[clampi(facility_level("warehouse"), 1, BaseCatalog.WAREHOUSE_STACK.size() - 1)])

## Cells in use (one per item or stack).
func shelf_count(_category: int = 0) -> int:
	return shelf.size()

func shelf_has_room(_category: int = 0) -> bool:
	return shelf.size() < capacity()

## Cells on one rack, for the racks drawn in the warehouse room.
func rack_cells() -> int:
	return BaseCatalog.RACK_CELLS

func staging_has_room() -> bool:
	return false

func location_of(item: Item) -> String:
	if item == null: return ""
	if shelf.has(item): return "shelf"
	return ""

## Every item at the base, each exactly once.
func all_items() -> Array[Item]:
	var out: Array[Item] = []
	out.append_array(shelf)
	return out

func sealed_count() -> int:
	return 0

# --- Moves -------------------------------------------------------------------

## Rhodes standard gear is never kept (制式保底修订): pieces a save from before
## holds in the warehouse or on the way back are handed back. Returns how many.
func purge_bound() -> int:
	var before := shelf.size() + insurance_queue.size()
	shelf.assign(shelf.filter(func(it): return not GearCatalog.bound(it)))
	insurance_queue.assign(insurance_queue.filter(func(e): return not GearCatalog.bound(e.item)))
	return before - (shelf.size() + insurance_queue.size())

## Something brought back by the base itself: into the warehouse over its
## cells if need be. False if already here.
func receive(item: Item) -> bool:
	if item == null or not location_of(item).is_empty(): return false
	if not _merge_onto_shelf(item): shelf.append(item)
	return true

## Units of `item`'s material that the warehouse's matching stacks still take.
func shelf_merge_room(item: Item) -> int:
	if not item.is_stackable(): return 0
	var room := 0
	for other in shelf:
		if other.can_stack_with(item): room += _cell_room(other)
	return room

## What one warehouse cell's stack still takes (its limit × stack_mult()).
func _cell_room(stack: Item) -> int:
	return maxi(0, stack.max_stack * stack_mult() - stack.quantity)

## Pours a stack onto the warehouse's matching stacks. True when nothing is left of it.
func _merge_onto_shelf(item: Item) -> bool:
	if not item.is_stackable(): return false
	for other in shelf:
		if not other.can_stack_with(item): continue
		var moved := mini(_cell_room(other), item.quantity)
		if moved <= 0: continue
		other.set_quantity(other.quantity + moved)
		item.set_quantity(item.quantity - moved)
		if item.quantity <= 0: return true
	return false

## Out of the warehouse, for the caller to put in the pack. A cell holding more
## than one stack gives one stack (the rest stays in the cell).
func take_from_shelf(item: Item) -> bool:
	if not shelf.has(item): return false
	shelf.erase(item)
	return true

## The piece of a warehouse stack that fits a bag: the stack itself, or one
## bag-sized stack split off it (仓库修订: cells stack past a bag's limit).
func bag_piece(item: Item) -> Item:
	if not shelf.has(item) or item.quantity <= item.max_stack: return item
	return item.split(item.max_stack)

## Where an item from the loadout would be stored: "shelf", or "" when the
## warehouse has no room for it.
func store_target(item: Item) -> String:
	if item == null or not location_of(item).is_empty(): return ""
	if shelf_has_room() or shelf_merge_room(item) >= item.quantity: return "shelf"
	return ""

func store(item: Item) -> String:
	var target := store_target(item)
	if target == "shelf" and not _merge_onto_shelf(item): shelf.append(item)
	return target

## Out of the base.
func remove_item(item: Item) -> bool:
	if location_of(item).is_empty(): return false
	shelf.erase(item)
	return true

## Undo of take_from_shelf when the pack refuses the item.
func put_back(item: Item, _where: String = "shelf") -> void:
	if not location_of(item).is_empty(): return
	if not _merge_onto_shelf(item): shelf.append(item)

## Loose items from a load or a migration: all into the warehouse. Never drops one.
func place_loose(items: Array) -> void:
	for item: Item in items:
		receive(item)

# --- Save --------------------------------------------------------------------

func to_data() -> Dictionary:
	return {"shelf": shelf.map(func(x): return x.to_data()), "facilities": facilities.duplicate(), "connected": connected.duplicate(), "orders": orders.to_data(),
		"injuries": injuries.duplicate(), "free_potions": free_potions, "closure_stock": closure_stock.duplicate(), "closure_restock_at": closure_restock_at,
		"medical_report": medical_report, "report_unread": report_unread,
		"contract_offers": contract_offers.duplicate(true),
		"pack_level": pack_level, "safe_level": safe_level, "loot_pity": loot_pity.duplicate(), "directed_fails": directed_fails,
		"insurance_queue": insurance_queue.map(func(e): return {"item": e.item.to_data(), "due": e.due}),
		"camps": camps.duplicate(), "ship_at": ship_at, "camp_upgraded": camp_upgraded, "first_extract_given": first_extract_given, "extracted_once": extracted_once, "story": story.duplicate(true), "kits": kits.duplicate(), "operator": operator,
		"roster": roster.duplicate(), "recruit_clues": recruit_clues.duplicate(), "recruit_found": recruit_found.duplicate(true),
		"progress": _progress_data(), "records": records.duplicate(), "boss_falls": boss_falls.duplicate(),
		"research": research.duplicate(true), "rhodes_rarity": rhodes_rarity, "contract_reroll": contract_reroll, "stayed": stayed, "farm": farm.duplicate(true)}

func _progress_data() -> Dictionary:
	var out := {}
	for id in progress: out[id] = (progress[id] as OperatorProgress).to_data()
	return out

## Version 2 data. `seen` holds uids already loaded elsewhere; duplicates are
## skipped and new uids are added to it.
func load_data(data: Dictionary, seen: Dictionary) -> void:
	shelf.clear()
	boss_falls = (data.get("boss_falls", {}) as Dictionary).duplicate()
	injuries = {}
	var saved_injuries: Variant = data.get("injuries", [])
	for id in saved_injuries:
		var tier: int = int(saved_injuries[id]) if saved_injuries is Dictionary and (saved_injuries[id] is float or saved_injuries[id] is int) else 1
		if Operators.valid(str(id)): injuries[str(id)] = maxi(tier, 1)
	_load_research(data)
	farm = Provisions.load_state(data.get("farm"))
	reset_potions()
	free_potions = clampi(int(data.get("free_potions", free_potion_count())), 0, free_potion_count())
	closure_stock = (data.get("closure_stock", {}) as Dictionary).duplicate() if data.get("closure_stock") is Dictionary else {}
	closure_restock_at = int(data.get("closure_restock_at", 0))
	medical_report = data.get("medical_report", {})
	report_unread = bool(data.get("report_unread", false))
	# Saves from before 仓库修订 had a drone (it counts toward 仓储部 below).
	drone = bool(data.get("drone", false))
	contract_offers = (data.get("contract_offers", {}) as Dictionary).duplicate(true)
	pack_level = clampi(int(data.get("pack_level", 0)), 0, BaseCatalog.PACK_SIZES.size() - 1)
	safe_level = clampi(int(data.get("safe_level", 0)), 0, BaseCatalog.SAFE_SIZES.size() - 1)
	directed_fails = maxi(0, int(data.get("directed_fails", 0)))
	var pity: Dictionary = data.get("loot_pity", {})
	loot_pity = {"rare_gear": clampf(float(pity.get("rare_gear", 0.0)), 0.0, LootTables.RARE_GEAR_PITY_CAP),
		"rare_material": clampf(float(pity.get("rare_material", 0.0)), 0.0, LootTables.RARE_MATERIAL_PITY_CAP)}
	# Saves from before recruiting had both operators.
	roster = starting_roster()
	for id in data.get("roster", [Operators.AMIYA_GUARD, Operators.LAPPLAND]):
		if Operators.valid(str(id)) and not str(id) in roster: roster.append(str(id))
	recruit_clues = {}
	var saved_clues: Dictionary = data.get("recruit_clues", {})
	for id in saved_clues:
		if RecruitCatalog.RECRUITS.has(str(id)): recruit_clues[str(id)] = clampi(int(saved_clues[id]), 0, RecruitCatalog.CLUES_NEEDED)
	recruit_found = {}
	var saved_found: Dictionary = data.get("recruit_found", {})
	for id in saved_found:
		if not RecruitCatalog.RECRUITS.has(str(id)): continue
		var keys: Array = []
		for key in saved_found[id]:
			if str(key) in RecruitCatalog.TRACE_SMALL or str(key) in RecruitCatalog.TRACE_BIG: keys.append(str(key))
		recruit_found[str(id)] = keys
	operator = str(data.get("operator", default_operator()))
	if not operator in deployable(): operator = default_operator()
	# Saves from before per-operator injuries: the one injury was whoever deploys.
	if bool(data.get("injured", false)): injured = true
	# Saves from before growth: every operator starts at 精英 0, level 1.
	progress = {}
	var saved_progress: Dictionary = data.get("progress", {})
	for id in saved_progress:
		if Operators.valid(str(id)): progress[str(id)] = OperatorProgress.from_data(str(id), saved_progress[id])
	records = {}
	var saved_records: Dictionary = data.get("records", {})
	for name in saved_records:
		if Progression.RECORD_EXP.has(str(name)): records[str(name)] = maxi(0, int(saved_records[name]))
	insurance_queue.clear()
	camps = {}
	ship_at = str(data.get("ship_at", TerraMap.START))
	if not TerraMap.has_place(ship_at): ship_at = TerraMap.START
	var saved_camps: Dictionary = data.get("camps", {})
	for region in saved_camps:
		if FieldCatalog.REGIONS.has(str(region)): unlock_camp(str(region), int(saved_camps[region]))
	camp_upgraded = bool(data.get("camp_upgraded", false))
	first_extract_given = bool(data.get("first_extract_given", false))
	# A save from before these: she has been out before, the thread is behind her.
	extracted_once = bool(data.get("extracted_once", true))
	var saved_story: Variant = data.get("story", null)
	story = Story.fresh()
	if saved_story is Dictionary:
		for key in story: story[key] = (saved_story as Dictionary).get(key, story[key])
	else: story = Story.finished_state()
	kits = {}
	var saved_kits: Dictionary = data.get("kits", {})
	for id in saved_kits:
		# Saves from before tiers hold plain ids: tier Ⅰ.
		var kit_id := str(id).get_slice("@", 0)
		var tier := clampi(int(str(id).get_slice("@", 1)) if "@" in str(id) else 1, 1, Economy.INCOME_INDEX.size())
		if FeatureCatalog.KITS.has(kit_id) and int(saved_kits[id]) > 0: kits["%s@%d" % [kit_id, tier]] = int(saved_kits[id])
	for entry in data.get("insurance_queue", []):
		var queued := _fresh(entry.get("item", {}), seen)
		# Saves from before the clock counted contracts left: an hour each.
		var due := int(entry.get("due", now() + maxi(int(entry.get("left", 1)), 1) * 3600))
		if queued: insurance_queue.append({"item": queued, "due": due})
	var racks_in: Dictionary = data.get("racks", {})
	for category in racks:
		racks[category] = clampi(int(racks_in.get(str(category), BaseCatalog.STARTING_RACKS)), BaseCatalog.STARTING_RACKS, BaseCatalog.RACK_SLOTS)
	_load_facilities(data)
	_show_racks()
	if data.has("orders"): orders.load_data(data.orders)
	else: orders.start_fresh()
	orders.resize(order_slot_count())
	# Saves from before 仓库修订: crates and staging go into the warehouse too.
	var loose: Array[Item] = []
	for entry in data.get("crates", []):
		var item := _fresh(entry.get("item", {}), seen)
		if item: loose.append(item)
	for key in ["shelf", "staging"]:
		for entry in data.get(key, []):
			var item := _fresh(entry, seen)
			if item: loose.append(item)
	place_loose(loose)

## Saves from before facilities had prestige ranks: each facility gets the
## level that opens what the rank opened, and at least what was built.
func _load_facilities(data: Dictionary) -> void:
	reset_facilities()
	var saved: Variant = data.get("facilities")
	if saved is Dictionary:
		for id in BaseCatalog.FACILITY_ORDER:
			facilities[id] = clampi(int(saved.get(id, BaseCatalog.facility_start(id))), BaseCatalog.facility_start(id), BaseCatalog.facility_max(id))
		if saved.has("hub"):
			for id in data.get("connected", []):
				if str(id) in BaseCatalog.connectable(): connect_facility(str(id))
		else:
			# v1.0 saves (no hub yet): the hub built and everything connected;
			# their exchange was open from the start (v1.1 §七).
			facilities.hub = 1
			facilities.exchange = maxi(1, int(saved.get("exchange", 1)))
			connected.assign(BaseCatalog.connectable())
		return
	var prestige := maxi(int(data.get("prestige", 0)), 0)
	var rank := 0
	for threshold in [20, 60, 120, 200]:
		if prestige >= threshold: rank += 1
	var warehouse := 1 + mini(rank, 3)
	if drone: warehouse = maxi(warehouse, BaseCatalog.DRONE_LEVEL)
	for category in racks: warehouse = maxi(warehouse, int(BaseCatalog.RACK_LEVELS[int(racks[category]) - 1]))
	var outfit := maxi(1 + mini(rank, 3), maxi(int(BaseCatalog.PACK_LEVELS[pack_level]), int(BaseCatalog.SAFE_LEVELS[safe_level])))
	facilities = {"hub": 1, "warehouse": warehouse, "outfit": outfit, "store": 1 + rank, "workshop": 2 if rank >= 3 else 1,
		"lab": 2 if rank >= 4 else (1 if rank >= 2 or not (research.done as Array).is_empty() else 0), "exchange": 1 + rank}
	connected.assign(BaseCatalog.connectable())

## 科研部 state; saves from before it start empty.
func _load_research(data: Dictionary) -> void:
	var saved: Dictionary = data.get("research", {})
	research = {"done": [], "active": [], "projects": {}, "endless": {}, "run": []}
	for id in saved.get("done", []):
		if ResearchCatalog.valid(str(id)) and not str(id) in research.done: research.done.append(str(id))
	for entry in saved.get("active", []):
		if entry is Dictionary and ResearchCatalog.valid(str(entry.get("id", ""))) and not str(entry.id) in research.done:
			research.active.append({"id": str(entry.id), "start": int(entry.get("start", 0)), "end": int(entry.get("end", 0))})
	var projects: Dictionary = saved.get("projects", {})
	for id in projects:
		if ResearchCatalog.PROJECTS.has(str(id)) and int(projects[id]) > 0: research.projects[str(id)] = int(projects[id])
	var endless: Dictionary = saved.get("endless", {})
	for line in endless:
		if ResearchCatalog.ENDLESS.has(str(line)): research.endless[str(line)] = clampi(int(endless[line]), 0, ResearchCatalog.ENDLESS_CAP)
	for id in saved.get("run", []):
		if ResearchCatalog.PROJECTS.has(str(id)): research.run.append(str(id))
	rhodes_rarity = clampi(int(data.get("rhodes_rarity", 0)), 0, 2)
	contract_reroll = bool(data.get("contract_reroll", false))
	stayed = bool(data.get("stayed", false))

## Version 1 had one flat warehouse list; it goes on the shelves, overflow to staging.
func migrate_v1(stash_data: Array, seen: Dictionary) -> void:
	reset_facilities()
	orders.start_fresh()
	shelf.clear()
	var loose: Array[Item] = []
	for entry in stash_data:
		var item := _fresh(entry, seen)
		if item: loose.append(item)
	place_loose(loose)

static func _fresh(entry: Dictionary, seen: Dictionary) -> Item:
	var item := Item.from_data(entry)
	if seen.has(item.uid): return null
	seen[item.uid] = true
	return item
