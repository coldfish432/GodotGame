class_name BaseState
extends RefCounted

## Where every item at the base is, and the rules for moving it between those
## places (基地玩法策划案_v1_0.md §3.1). An item is in exactly one place:
##
##   crate_sealed  a receiving crate, not yet opened
##   crate_open    an opened crate, not yet shelved or staged
##   staging       unsorted holding; not the warehouse: no delivery, and it
##                 reaches the pack only by being taken out at staging
##   shelf         personal storage, the warehouse proper (was GameManager.stash)
##   hand          carried by Lappland across the warehouse, one item at most;
##                 never leaves the base (returned on departure, saved as where it came from)
##
## Equipped and packed items (the loadout) belong to GameManager and the player;
## they are not tracked here. Every move checks first and changes nothing when
## it fails, so a refused move never loses or duplicates an item.

var shelf: Array[Item] = []
## {"item": Item, "opened": bool}, in arrival order. The first
## BaseCatalog.RECEIVING_BAYS sit on the numbered bays.
var crates: Array[Dictionary] = []
var staging: Array[Item] = []
var hand: Item = null
## Where the carried item was picked up: "crate" or "staging". Put back there.
var hand_from := ""
## Category -> racks built.
var racks := {}
## Cumulative, never spent (§2). Ranks unlock convenience and capacity only.
var prestige := 0
var orders := OrderBoard.new()
## Medical (§4). Contamination carries across contracts; so does an untreated injury.
var contamination := 0.0
var injured := false
## Flasks for the next contract, by type ("A", "B", "C"); `extra_potion` is a
## bought fourth bottle ("" for none). Reset to three A after every settlement.
var potions: Array[String] = ["A", "A", "A"]
var extra_potion := ""
## What the medical report adds to the item list: contamination before and
## after, and whether this settlement left an injury. Unread until she opens it.
var medical_report := {}
var report_unread := false
## The engineering drone (§3.5): bought once at R1, sorts on command and empties
## staging onto the shelves at every return.
var drone := false
## Expansion levels into BaseCatalog.PACK_SIZES / SAFE_SIZES.
var pack_level := 0
var safe_level := 0
## R3: one free order reroll per settlement.
var reroll_available := false
## A rank-up opened something to buy at the warehouse terminal, not yet looked at.
var unseen_unlocks := false

func _init() -> void:
	for category in range(Item.Category.size()):
		racks[category] = BaseCatalog.STARTING_RACKS
	orders.start_fresh()

func rank() -> int:
	return BaseCatalog.rank_of(prestige)

func contamination_tier() -> int:
	return BaseCatalog.contamination_tier(contamination)

## Max HP lost on the next contract: injury plus contamination tier, capped.
func hp_penalty() -> float:
	var tier: Array = BaseCatalog.CONTAMINATION_TIERS[contamination_tier()]
	return minf(BaseCatalog.HP_PENALTY_CAP, float(tier[1]) + (BaseCatalog.INJURY_HP_PENALTY if injured else 0.0))

## The flasks she will carry, in the order Q uses them.
func potion_belt() -> Array[String]:
	var belt := potions.duplicate()
	if not extra_potion.is_empty(): belt.append(extra_potion)
	return belt

## Price of a flask type, or -1 when the rank does not allow it yet.
func potion_price(type: String) -> int:
	var p: Dictionary = BaseCatalog.POTIONS[type]
	return -1 if rank() < int(p.rank) else int(p.price)

func reset_potions() -> void:
	potions.assign(["A", "A", "A"])
	extra_potion = ""

## After a settlement: contamination decays then takes this run's dose; an
## injury is whatever this settlement left. Returns the report it records.
func settle_medical(dose: float, died: bool) -> Dictionary:
	var before := contamination
	# Decay first, down to 0, then the dose: a clean start keeps the whole dose.
	contamination = clampf(maxf(contamination - BaseCatalog.CONTAMINATION_DECAY, 0.0) + dose, 0.0, BaseCatalog.CONTAMINATION_MAX)
	injured = died
	reset_potions()
	medical_report = {"contamination_before": roundi(before), "contamination_after": roundi(contamination), "injured": died}
	report_unread = true
	return medical_report

## Adds prestige; returns the new rank if it went up, else -1.
func add_prestige(amount: int) -> int:
	var before := rank()
	prestige += maxi(amount, 0)
	orders.resize(BaseCatalog.ORDER_SLOTS_R2 if rank() >= 2 else BaseCatalog.ORDER_SLOTS)
	if rank() > before:
		unseen_unlocks = true
		return rank()
	return -1

# --- Expansion and the drone (§3.5, §3.6) ---------------------------------------

## "" when the next pack ("pack") or safe-bag ("safe") level can be bought.
func upgrade_refusal(kind: String, money: int) -> String:
	var level := pack_level if kind == "pack" else safe_level
	var prices: Array = BaseCatalog.PACK_PRICES if kind == "pack" else BaseCatalog.SAFE_PRICES
	var ranks: Array = BaseCatalog.PACK_RANKS if kind == "pack" else BaseCatalog.SAFE_RANKS
	if level + 1 >= prices.size(): return "已满配"
	if rank() < int(ranks[level + 1]): return "需要声望 R%d" % int(ranks[level + 1])
	if money < int(prices[level + 1]): return "资金不足"
	return ""

func can_upgrade(kind: String, money: int) -> bool:
	return upgrade_refusal(kind, money).is_empty()

## The next rack slot for `category`, or -1 when all nine are built.
func next_rack_slot(category: int) -> int:
	var built := int(racks[category])
	return built if built < BaseCatalog.RACK_SLOTS else -1

## Why the next rack cannot be built now ("" if it can, given the gold).
func rack_refusal(category: int, gold: int) -> String:
	var slot := next_rack_slot(category)
	if slot < 0: return "%s区的 9 个货架位都建好了。" % BaseCatalog.CATEGORY_NAMES[category]
	if rank() < int(BaseCatalog.RACK_RANKS[slot]): return "需要声望 R%d。" % BaseCatalog.RACK_RANKS[slot]
	if gold < int(BaseCatalog.RACK_PRICES[slot]): return "资金不足（%d）。" % BaseCatalog.RACK_PRICES[slot]
	return ""

## Builds the next rack; the caller pays BaseCatalog.RACK_PRICES[slot].
func build_rack(category: int) -> int:
	var slot := next_rack_slot(category)
	if slot < 0: return -1
	racks[category] = slot + 1
	return slot

## "Open and sort everything" (§3.5): opens every sealed crate, then shelves
## everything opened or staged that has room. What does not fit goes to staging
## (from crates) or stays (in staging, or in a crate once staging is full).
## Returns {"revealed": [Item], "shelved": [Item], "staged": [Item], "left": [Item]}.
func sort_all() -> Dictionary:
	var revealed: Array[Item] = []
	for crate in crates:
		if not crate.opened:
			crate.opened = true
			revealed.append(crate.item)
	var result := sort_staging()
	result.revealed = revealed
	for crate in crates.duplicate():
		var item: Item = crate.item
		if shelf_has_room(item.category):
			shelve(item)
			result.shelved.append(item)
		elif stage(item): result.staged.append(item)
		else: result.left.append(item)
	return result

## Staging onto the shelves where there is room (also what the drone does on
## every return).
func sort_staging() -> Dictionary:
	var result := {"revealed": [], "shelved": [], "staged": [], "left": []}
	for item in staging.duplicate():
		if shelf_has_room(item.category):
			shelve(item)
			result.shelved.append(item)
		else: result.left.append(item)
	return result

# --- Queries -----------------------------------------------------------------

func capacity(category: int) -> int:
	return int(racks[category]) * BaseCatalog.RACK_CELLS

func shelf_count(category: int) -> int:
	return shelf.filter(func(x): return x.category == category).size()

func shelf_has_room(category: int) -> bool:
	return shelf_count(category) < capacity(category)

func staging_has_room() -> bool:
	return staging.size() < BaseCatalog.STAGING_CAPACITY

func location_of(item: Item) -> String:
	if item == null: return ""
	if shelf.has(item): return "shelf"
	if hand == item: return "hand"
	if staging.has(item): return "staging"
	var crate := _crate_of(item)
	if not crate.is_empty(): return "crate_open" if crate.opened else "crate_sealed"
	return ""

## Every item at the base, each exactly once.
func all_items() -> Array[Item]:
	var out: Array[Item] = []
	out.append_array(shelf)
	out.append_array(staging)
	for crate in crates: out.append(crate.item)
	if hand: out.append(hand)
	return out

func sealed_count() -> int:
	return crates.filter(func(c): return not c.opened).size()

func _crate_of(item: Item) -> Dictionary:
	for crate in crates:
		if crate.item == item: return crate
	return {}

# --- Moves -------------------------------------------------------------------

## Something brought back: it arrives as a sealed crate. False if already here.
func receive(item: Item) -> bool:
	if item == null or not location_of(item).is_empty(): return false
	crates.append({"item": item, "opened": false})
	return true

func open_crate(item: Item) -> bool:
	var crate := _crate_of(item)
	if crate.is_empty() or crate.opened: return false
	crate.opened = true
	return true

## Why `item` cannot go on its shelf right now, or "" if it can.
func shelve_refusal(item: Item) -> String:
	if not location_of(item) in ["crate_open", "staging"]: return "只能上架已开箱或暂存区里的物品。"
	if not shelf_has_room(item.category):
		return "%s区已满（%d/%d）：放进暂存区，或在仓管台扩建。" % [
			BaseCatalog.CATEGORY_NAMES[item.category], shelf_count(item.category), capacity(item.category)]
	return ""

func shelve(item: Item) -> bool:
	if not shelve_refusal(item).is_empty(): return false
	_take(item)
	shelf.append(item)
	return true

## From an opened crate into staging.
func stage(item: Item) -> bool:
	if location_of(item) != "crate_open" or not staging_has_room(): return false
	_take(item)
	staging.append(item)
	return true

## Out of staging, for the caller to put in the pack. Only callable at staging.
func unstage(item: Item) -> bool:
	if not staging.has(item): return false
	staging.erase(item)
	return true

## Off the shelf, for the caller to put in the pack (bring into a contract).
func take_from_shelf(item: Item) -> bool:
	if not shelf.has(item): return false
	shelf.erase(item)
	return true

## Where an item from the loadout would be stored: its shelf, or staging when
## that is full, or "" when neither has room.
func store_target(item: Item) -> String:
	if item == null or not location_of(item).is_empty(): return ""
	if shelf_has_room(item.category): return "shelf"
	if staging_has_room(): return "staging"
	return ""

func store(item: Item) -> String:
	var target := store_target(item)
	match target:
		"shelf": shelf.append(item)
		"staging": staging.append(item)
	return target

# --- Carrying ------------------------------------------------------------------

## From an opened crate or staging into her hands. One item at a time.
func pick_up(item: Item) -> bool:
	if hand != null: return false
	var from := location_of(item)
	if not from in ["crate_open", "staging"]: return false
	_take(item)
	hand = item
	hand_from = "staging" if from == "staging" else "crate"
	return true

## Why the carried item cannot go into `category`'s zone, or "" if it can.
func shelve_hand_refusal(category: int) -> String:
	if hand == null: return "手上没有东西。"
	if hand.category != category:
		return "这是%s区。%s要放到%s区，已为你高亮。" % [BaseCatalog.CATEGORY_NAMES[category], hand.item_name, BaseCatalog.CATEGORY_NAMES[hand.category]]
	if not shelf_has_room(category):
		return "%s区已满（%d/%d）：放进暂存区，或在仓管台扩建。" % [BaseCatalog.CATEGORY_NAMES[category], shelf_count(category), capacity(category)]
	return ""

func shelve_hand(category: int) -> bool:
	if not shelve_hand_refusal(category).is_empty(): return false
	shelf.append(hand)
	_drop_hand()
	return true

func stage_hand() -> bool:
	if hand == null or not staging_has_room(): return false
	staging.append(hand)
	_drop_hand()
	return true

## Back where it came from: staging, or an opened crate at receiving. Used when
## she sets it down at receiving, and when she leaves the base holding it.
func return_hand() -> bool:
	if hand == null: return false
	if hand_from == "staging" and staging_has_room(): staging.append(hand)
	else: crates.append({"item": hand, "opened": true})
	_drop_hand()
	return true

func _drop_hand() -> void:
	hand = null
	hand_from = ""

## Undo of take_from_shelf / unstage when the pack refuses the item.
func put_back(item: Item, where: String) -> void:
	if not location_of(item).is_empty(): return
	if where == "staging": staging.append(item)
	else: shelf.append(item)

func _take(item: Item) -> void:
	shelf.erase(item)
	staging.erase(item)
	for i in range(crates.size()):
		if crates[i].item == item:
			crates.remove_at(i)
			return

## Puts loose items away the way a migration or load must: shelf while its
## category has room, then staging, then an opened crate. Never drops one.
func place_loose(items: Array) -> void:
	for item: Item in items:
		if not location_of(item).is_empty(): continue
		if shelf_has_room(item.category): shelf.append(item)
		elif staging_has_room(): staging.append(item)
		else: crates.append({"item": item, "opened": true})

# --- Save --------------------------------------------------------------------

func to_data() -> Dictionary:
	var crate_data: Array = []
	for crate in crates: crate_data.append({"item": crate.item.to_data(), "opened": crate.opened})
	# The carried item is saved where it would go back to; a save never holds a hand.
	var staging_data: Array = staging.map(func(x): return x.to_data())
	if hand:
		if hand_from == "staging" and staging_has_room(): staging_data.append(hand.to_data())
		else: crate_data.append({"item": hand.to_data(), "opened": true})
	var rack_data := {}
	for category in racks: rack_data[str(category)] = racks[category]
	return {"shelf": shelf.map(func(x): return x.to_data()), "crates": crate_data,
		"staging": staging_data, "racks": rack_data, "prestige": prestige, "orders": orders.to_data(),
		"contamination": contamination, "injured": injured, "potions": potions.duplicate(), "extra_potion": extra_potion,
		"medical_report": medical_report, "report_unread": report_unread,
		"drone": drone, "reroll_available": reroll_available, "unseen_unlocks": unseen_unlocks,
		"pack_level": pack_level, "safe_level": safe_level}

## Version 2 data. `seen` holds uids already loaded elsewhere; duplicates are
## skipped and new uids are added to it.
func load_data(data: Dictionary, seen: Dictionary) -> void:
	shelf.clear()
	staging.clear()
	crates.clear()
	_drop_hand()
	prestige = maxi(int(data.get("prestige", 0)), 0)
	contamination = clampf(float(data.get("contamination", 0.0)), 0.0, BaseCatalog.CONTAMINATION_MAX)
	injured = bool(data.get("injured", false))
	reset_potions()
	var saved_potions: Array = data.get("potions", [])
	if saved_potions.size() == BaseCatalog.POTION_SLOTS and saved_potions.all(func(t): return BaseCatalog.POTIONS.has(str(t))):
		potions.assign(saved_potions.map(func(t): return str(t)))
	extra_potion = str(data.get("extra_potion", ""))
	if not BaseCatalog.POTIONS.has(extra_potion): extra_potion = ""
	medical_report = data.get("medical_report", {})
	report_unread = bool(data.get("report_unread", false))
	drone = bool(data.get("drone", false))
	pack_level = clampi(int(data.get("pack_level", 0)), 0, BaseCatalog.PACK_SIZES.size() - 1)
	safe_level = clampi(int(data.get("safe_level", 0)), 0, BaseCatalog.SAFE_SIZES.size() - 1)
	reroll_available = bool(data.get("reroll_available", false)) and rank() >= BaseCatalog.REROLL_RANK
	unseen_unlocks = bool(data.get("unseen_unlocks", false))
	if data.has("orders"): orders.load_data(data.orders)
	else: orders.start_fresh()
	orders.resize(BaseCatalog.ORDER_SLOTS_R2 if rank() >= 2 else BaseCatalog.ORDER_SLOTS)
	var racks_in: Dictionary = data.get("racks", {})
	for category in racks:
		racks[category] = clampi(int(racks_in.get(str(category), BaseCatalog.STARTING_RACKS)), BaseCatalog.STARTING_RACKS, BaseCatalog.RACK_SLOTS)
	for entry in data.get("crates", []):
		var item := _fresh(entry.get("item", {}), seen)
		if item: crates.append({"item": item, "opened": bool(entry.get("opened", false))})
	var loose: Array[Item] = []
	for key in ["shelf", "staging"]:
		for entry in data.get(key, []):
			var item := _fresh(entry, seen)
			if item:
				if key == "staging" and staging_has_room(): staging.append(item)
				else: loose.append(item)
	place_loose(loose)

## Version 1 had one flat warehouse list; it goes on the shelves, overflow to staging.
func migrate_v1(stash_data: Array, seen: Dictionary) -> void:
	prestige = 0
	orders.start_fresh()
	shelf.clear()
	staging.clear()
	crates.clear()
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
