class_name Packs
extends RefCounted

## Trade packs (交易所交易包修订案_v1_0.md §2–§4, 用户 2026-10-23): the exchange
## trades one standard pack per category. 加工部 packs loose goods by value
## (what spills over the face is lost), the warehouse console opens a pack into
## goods picked by points (value × 1.1), and gear packs go one way.

## Pack id -> its market category and face value (points = Item.value).
## "open": whether it can be unpacked (gear and contraband cannot, §3.3).
const PACKS := {
	"源石包": {"category": "originium", "face": 120, "open": true},
	"医疗包": {"category": "medical", "face": 100, "open": true},
	"建材包": {"category": "build", "face": 100, "open": true},
	"电子包": {"category": "electronic", "face": 120, "open": true},
	"燃料包": {"category": "fuel", "face": 100, "open": true},
	"寒地物资包": {"category": "cold", "face": 100, "open": true},
	"养成材料包": {"category": "elite", "face": 300, "open": true},
	"违禁品包": {"category": "contraband", "face": 200, "open": false},
	"武器包": {"category": "weapon", "face": 400, "open": false},
	"防具包": {"category": "armor", "face": 400, "open": false},
	"饰品包": {"category": "trinket", "face": 400, "open": false},
}
const ORDER: Array[String] = ["建材包", "电子包", "医疗包", "燃料包", "寒地物资包", "源石包", "养成材料包", "违禁品包", "武器包", "防具包", "饰品包"]
## Per pack: 100 龙门币 and a minute in the 加工部 queue (§3.1).
const PACK_LMD := 100
const PACK_MINUTES := 1
## Unpacking costs value × this in points (§4): the round trip always loses.
const OPEN_COST := 1.1
## The old trade crates (v0.7 §2.2) and the pack each became (§7.3).
const LEGACY := {"工业补给箱": "建材包", "电子元件箱": "电子包", "野外生活包": "寒地物资包", "医疗补给箱": "医疗包"}

static func is_pack(id: String) -> bool:
	return PACKS.has(id)

static func category_of(pack: String) -> String:
	return str(PACKS.get(pack, {}).get("category", ""))

static func face(pack: String) -> int:
	return int(PACKS.get(pack, {}).get("face", 0))

static func can_open(pack: String) -> bool:
	return bool(PACKS.get(pack, {}).get("open", false))

static func pack_for(category: String) -> String:
	for id in ORDER:
		if category_of(id) == category: return id
	return ""

## Whether `item` may go into a pack (§3.2, §3.3): its category has a pack; not
## a pack, flask, 赤金, 势力特供, insured piece or bulk crate.
static func packable(item: Item) -> bool:
	if item == null or item.is_potion() or item.insured: return false
	if is_pack(item.material_id) or item.material_id == Economy.GOLD_ID: return false
	if item.effect == VoyageCatalog.CARGO_EFFECT: return false
	if str(MaterialCatalog.MATERIALS.get(item.material_id, {}).get("source", "")) == "special": return false
	return not pack_for(FactionCatalog.category_of(item)).is_empty()

## What one-key packing leaves alone in gear packs (§3.4): the top quality and
## named pieces (set, boss, special, exclusive) only go in by hand.
static func quick_skips(item: Item) -> bool:
	return item.is_equippable() and (item.rarity >= 2 or not item.named_kind().is_empty())

## Points one unit of `item` brings (a stack counts unit by unit).
static func unit_points(item: Item) -> int:
	if item.is_stackable() or item.unit_value > 0: return maxi(1, item.unit_value)
	return maxi(1, item.value)

static func units(item: Item) -> int:
	return item.quantity if item.is_stackable() else 1

static func points(item: Item) -> int:
	return unit_points(item) * units(item)

## The pieces of `pool` that may go into `pack` as {item, unit, left}, cheapest first.
static func _entries(pack: String, pool: Array, quick: bool) -> Array:
	var category := category_of(pack)
	var entries: Array = []
	for item: Item in pool:
		if not packable(item) or FactionCatalog.category_of(item) != category: continue
		if quick and quick_skips(item): continue
		entries.append({"item": item, "unit": unit_points(item), "left": units(item)})
	entries.sort_custom(func(a, b): return int(a.unit) < int(b.unit))
	return entries

## Picks goods for up to `count` packs of `pack` out of `pool` (§3.4): each
## pack is the fill with the least spill, the cheap pieces reached first.
## Returns {packs, take: {Item: units}, overflow, used}. With `quick`, top
## gear and named pieces are skipped.
static func auto_pick(pack: String, pool: Array, count: int, quick: bool = true) -> Dictionary:
	var entries := _entries(pack, pool, quick)
	var take := {}
	var overflow := 0
	var made := 0
	var target := face(pack)
	while made < count:
		var fill := _least_spill(entries, target)
		if fill.is_empty(): break
		made += 1
		for i in fill:
			var n := int(fill[i])
			entries[i].left = int(entries[i].left) - n
			overflow += n * int(entries[i].unit)
			var item: Item = entries[i].item
			take[item] = int(take.get(item, 0)) + n
		overflow -= target
	return {"packs": made, "take": take, "overflow": overflow, "used": take.size()}

## {entry index: units} reaching at least `target` with the smallest total, or
## {} if the entries cannot. Sums are tracked up to target + the dearest unit;
## the cheap entries go first, so they claim each sum before the dear ones.
static func _least_spill(entries: Array, target: int) -> Dictionary:
	var top := 0
	for e in entries:
		if int(e.left) > 0: top = maxi(top, int(e.unit))
	if top == 0: return {}
	var limit := target + top
	var from := PackedInt32Array()
	from.resize(limit + 1)
	from.fill(-1)
	var by := PackedInt32Array()
	by.resize(limit + 1)
	from[0] = 0
	for i in range(entries.size()):
		var u := int(entries[i].unit)
		for k in range(mini(int(entries[i].left), ceili(float(limit) / u))):
			for s in range(limit, u - 1, -1):
				if from[s] < 0 and from[s - u] >= 0:
					from[s] = s - u
					by[s] = i
	for s in range(target, limit + 1):
		if from[s] < 0: continue
		var out := {}
		var at := s
		while at > 0:
			out[by[at]] = int(out.get(by[at], 0)) + 1
			at = from[at]
		return out
	return {}

## How many packs `pool` could fill at most, by its total packable value (§3.4).
static func max_packs(pack: String, pool: Array, quick: bool = true) -> int:
	var total := 0
	for e in _entries(pack, pool, quick): total += int(e.unit) * int(e.left)
	return total / maxi(1, face(pack))

## Manual packing (§3.1): the chosen pieces' value against the face; whole
## pieces only, so what spills over the last pack is lost.
static func manual_packs(pack: String, chosen: Array) -> Dictionary:
	var total := 0
	for item: Item in chosen: total += points(item)
	var f := face(pack)
	return {"packs": total / f if f > 0 else 0, "points": total, "overflow": total % f if f > 0 else 0}

# --- Unpacking (§4) ---------------------------------------------------------------------

## The goods a pack of `category` opens into: plain market materials only — no
## 特产 (regional goods), 势力特供, crops, 补给, packs or old crates.
static func open_list(pack: String) -> Array[String]:
	var out: Array[String] = []
	if not can_open(pack): return out
	var category := category_of(pack)
	for id in MaterialCatalog.MATERIALS:
		if id == Economy.GOLD_ID or is_pack(id) or LEGACY.has(id): continue
		var source := str(MaterialCatalog.MATERIALS[id].get("source", ""))
		if source in ["special", "farm", "meal", "sami", "trade", "pack"]: continue
		if FactionCatalog.material_category(id) == category: out.append(id)
	return out

## Points one unit of `material` costs out of a pack.
static func open_cost(material: String) -> int:
	return ceili(MaterialCatalog.create(material, 1).unit_value * OPEN_COST - 0.0001)

## A pick {material: count} against `points`: the points it costs, or -1 if a
## material is not on the pack's list.
static func pick_cost(pack: String, pick: Dictionary) -> int:
	var list := open_list(pack)
	var total := 0
	for id in pick:
		if not id in list: return -1
		total += open_cost(id) * int(pick[id])
	return total
