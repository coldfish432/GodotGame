class_name Consignment
extends RefCounted

## 可露希尔's 代售 (交易所交易包修订案 §5, 用户 2026-10-23): the loose-goods
## market of one place, run for Rhodes by 可露希尔. At the base it is the market
## where the ship lies (none under way); in a camp, the map's own. Loose goods,
## the place's 特产 and its own gear; she takes loose goods and gear back, never
## packs. Prices follow the packs' books of the factions there (§5.2).

## The four field maps and the anchor each lies in (§5.1).
const REGION_ANCHOR := {"mine": "切尔诺伯格", "city": "龙门", "snow": "萨米", "siracusa": "叙拉古"}
## Bid/ask gap per anchor (§5.2).
const SPREAD := {"龙门": 0.04, "切尔诺伯格": 0.08, "萨米": 0.08, "叙拉古": 0.06, "哥伦比亚": 0.04, "谢拉格": 0.05, "卡西米尔": 0.03}
## Her commission: 6%, a point less a store level past the first, at least 3%.
const COMMISSION := 0.06
const COMMISSION_STEP := 0.01
const COMMISSION_MIN := 0.03
## Each anchor's leanings (§10-1): its own 特产's category cheap, 龙门 dear on
## medical goods and building stock; 1.0 otherwise.
const PREFS := {
	"切尔诺伯格": {"contraband": 0.8, "originium": 0.9},
	"龙门": {"armor": 0.8, "medical": 1.1, "build": 1.1},
	"萨米": {"cold": 0.8},
	"叙拉古": {"trinket": 0.8},
}
## Leanings every anchor shares: crops fetch about their delivery price, so the
## farm pays its seed × 1.25 whichever way they are sold (用户 2026-10-23).
const CATEGORY_PREFS := {"crop": 0.85}
## Loose goods on each shelf besides the local factions' own (§5.3).
const LOCAL_GOODS := {
	"切尔诺伯格": ["源岩", "固源岩", "破损装置", "异铁碎片", "异铁", "燃料罐", "金属板"],
	"龙门": ["代糖", "糖", "异铁", "螺栓", "电线", "灯泡", "医用耗材包"],
	"萨米": ["双酮", "异铁碎片", "帆布", "固体燃料"],
	"叙拉古": ["代糖", "异铁碎片", "酯原料", "聚酸酯", "螺母", "钉子", "木板"],
}
## Gear on the shelf (§5.3): its own map's only, 3–6 pieces, never the top
## quality or a named piece; 交付价 × this.
const GEAR_COUNT := Vector2i(3, 6)
const GEAR_MARKUP := 2.5
const SPECIALTY_COUNT := Vector2i(1, 2)
const RESTOCK := 3600

var game: GameManager
## anchor -> {"hour": int, "goods": [{"kind", "item": data, "sold": bool}]}
var stock := {}

func setup(p_game: GameManager) -> void:
	game = p_game

## The anchor whose market is open here: the ship's at the base (none under
## way), the map's in a camp (§5.1). "" when closed.
func anchor_here() -> String:
	if game.in_base: return game.voyage.docked_at()
	return str(REGION_ANCHOR.get(game.region_id, ""))

static func currency(anchor: String) -> String:
	return "lmd" if anchor == "龙门" else "gold"

static func region_of(anchor: String) -> String:
	for r in REGION_ANCHOR:
		if REGION_ANCHOR[r] == anchor: return r
	return ""

func commission() -> float:
	return maxf(COMMISSION_MIN, COMMISSION - COMMISSION_STEP * maxi(0, game.base.facility_level("store") - 1))

## The composite of the pack books for `category` at `anchor`: the factions
## there, by depth; everyone's when none there trades it (§5.2).
func index(anchor: String, category: String) -> float:
	var local: Array = VoyageCatalog.ANCHOR_FACTIONS.get(anchor, [])
	for pool in [local, FactionCatalog.trading()]:
		var total := 0.0
		var weight := 0.0
		for f in pool:
			var m := "%s:%s" % [f, category]
			if not game.market.books.has(m): continue
			var w := game.market.depth(m)
			total += (game.market.bid(m) + game.market.ask(m)) * 0.5 * w
			weight += w
		if weight > 0.0: return total / weight
	return 1.0

func pref(anchor: String, category: String) -> float:
	return float(PREFS.get(anchor, {}).get(category, CATEGORY_PREFS.get(category, 1.0)))

## What she gets for `item` at `anchor`, in its currency (unrounded); 0 if she does not take it.
func sell_quote(anchor: String, item: Item) -> float:
	if not takes(item): return 0.0
	var category := FactionCatalog.category_of(item)
	var lmd := float(Economy.price(item)) * pref(anchor, category) * index(anchor, category) * (1.0 - float(SPREAD.get(anchor, 0.05)) * 0.5 - commission())
	return Exchange.from_lmd(currency(anchor), lmd)

## Loose goods, 特产 and gear; never packs, flasks, 赤金, 势力特供 or bulk crates (§5.4).
static func takes(item: Item) -> bool:
	if item == null or item.is_potion() or item.insured: return false
	if Packs.is_pack(item.material_id) or Packs.LEGACY.has(item.material_id) or item.material_id == Economy.GOLD_ID: return false
	if item.effect == VoyageCatalog.CARGO_EFFECT or FactionSpecials.is_special(item.material_id): return false
	return not FactionCatalog.category_of(item).is_empty()

## The price of a shelf entry, in the anchor's currency (unrounded).
func buy_quote(anchor: String, entry: Dictionary) -> float:
	var item := Item.from_data(entry.item)
	if str(entry.kind) == "gear": return Exchange.from_lmd(currency(anchor), float(Economy.price(item)) * GEAR_MARKUP)
	if str(entry.kind) == "special":
		# 势力特供 at their faction's ask, her commission on top.
		var q := game.exchange.quote_buy(str(entry.faction), item.material_id)
		return Exchange.from_lmd(currency(anchor), Exchange.lmd_eq(str(q.currency), float(q.unit)) * item.quantity * (1.0 + commission())) if q.ok else -1.0
	var category := FactionCatalog.category_of(item)
	var lmd := float(Economy.price(item)) * pref(anchor, category) * index(anchor, category) * (1.0 + float(SPREAD.get(anchor, 0.05)) * 0.5 + commission())
	return Exchange.from_lmd(currency(anchor), lmd)

## A whole price: 赤金 is bars (up when she pays, down when she is paid).
static func whole(currency_id: String, amount: float, buying: bool) -> int:
	if currency_id == "gold": return Exchange.field_bars(amount, buying)
	return ceili(amount - 0.0001) if buying else floori(amount + 0.0001)

# --- The shelf -------------------------------------------------------------------------------

## The anchor's shelf, restocked every real hour (§5.3).
func goods(anchor: String) -> Array:
	if anchor.is_empty(): return []
	var hour := BaseState.now() / RESTOCK
	var s: Dictionary = stock.get(anchor, {})
	if s.is_empty() or int(s.hour) != hour:
		s = {"hour": hour, "goods": _roll(anchor)}
		stock[anchor] = s
	return s.goods

func restock_in() -> int:
	return RESTOCK - BaseState.now() % RESTOCK

func _roll(anchor: String) -> Array:
	var rng := game.rng
	var out: Array = []
	var region := region_of(anchor)
	var factions: Array = VoyageCatalog.ANCHOR_FACTIONS.get(anchor, [])
	# 特产: the map's own pieces; at the anchors without a map, the factions' 特供.
	if not region.is_empty():
		for i in range(rng.randi_range(SPECIALTY_COUNT.x, SPECIALTY_COUNT.y)):
			out.append({"kind": "specialty", "item": FieldCatalog.exclusive(region, _depth(region)).to_data(), "sold": false})
	else:
		for f in factions:
			for id in FactionCatalog.info(f).get("sells", []):
				if FactionSpecials.is_special(id): out.append({"kind": "special", "faction": f, "item": MaterialCatalog.create(id, 1).to_data(), "sold": false})
	# Loose goods: the factions' plain shelves and the map's common goods.
	var loose: Array[String] = []
	for f in factions:
		for id in FactionSpecials.plain_shelf(f):
			if MaterialCatalog.MATERIALS.has(id) and not loose.has(id): loose.append(id)
	for id in LOCAL_GOODS.get(anchor, []):
		if not loose.has(id): loose.append(id)
	for id in loose:
		var size := MaterialCatalog.stack_size(id)
		out.append({"kind": "loose", "item": MaterialCatalog.create(id, rng.randi_range(maxi(1, size / 2), size), region).to_data(), "sold": false})
	# Gear: only the map's own (§5.3; none where there is no map).
	if not region.is_empty():
		for i in range(rng.randi_range(GEAR_COUNT.x, GEAR_COUNT.y)):
			var piece := _roll_gear(region)
			if piece != null: out.append({"kind": "gear", "item": piece.to_data(), "sold": false})
	return out

## How deep she has been on that map (its deepest camp; floor 1 if none).
func _depth(region: String) -> int:
	return maxi(1, int(game.base.camps.get(region, 0)))

func _roll_gear(region: String) -> Item:
	for attempt in range(40):
		var item := FieldCatalog.roll_item(region, _depth(region), game.rng, 0.0)
		if item.is_equippable() and not item.is_rare(): return item
	return null

## Why entry `i` cannot be bought ("" = it can).
func buy_refusal(anchor: String, i: int) -> String:
	var list := goods(anchor)
	if i < 0 or i >= list.size(): return "没有这件"
	var entry: Dictionary = list[i]
	if entry.sold: return "已售出"
	if str(entry.kind) == "special" and game.exchange.rank(str(entry.faction)) < FactionSpecials.rank_needed(Item.from_data(entry.item).material_id):
		return "需要关系 R%d" % FactionSpecials.rank_needed(Item.from_data(entry.item).material_id)
	var price := buy_quote(anchor, entry)
	if price < 0.0: return "暂停出售"
	var cur := currency(anchor)
	var cost := whole(cur, price, true)
	if (cur == "gold" and game.gold_available() < cost) or (cur == "lmd" and game.gold < cost): return "赤金不足" if cur == "gold" else "龙门币不足"
	if not game.in_base and not game.inventory.can_take(Item.from_data(entry.item)): return "背包已满"
	return ""

func to_data() -> Dictionary:
	return {"stock": stock}

func load_data(d: Dictionary) -> void:
	stock = d.get("stock", {})
