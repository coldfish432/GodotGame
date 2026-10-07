class_name BaseCatalog
extends RefCounted

## Rhodes Island base numbers (基地玩法策划案_v1_0.md, appendix A). Initial
## playtest tuning, like FieldCatalog. Constants for later phases (orders,
## prestige, contamination, pharmacy) are added with those phases.

## Receiving: one crate per item brought back; this many sit on numbered bays
## (R01-R06), the rest stack along the south wall and move up as bays free.
const RECEIVING_BAYS := 6
## Personal storage: every rack holds this many items, one per cell, whatever
## the item's size (the cells drawn on a rack's face).
const RACK_CELLS := 12
const RACK_SLOTS := 9          # 3 rows x 3 per category, built front row first
const STARTING_RACKS := 1
## Staging: unsorted holding next to receiving. Not part of the warehouse: its
## items cannot be delivered, and are brought along only by taking them out
## there. Sized for roughly three full hauls (a 64-cell pack and safe bag carry
## 20-30 items once packing gaps are counted); a design figure, not a rule.
const STAGING_CAPACITY := 72

const CATEGORY_NAMES := ["武器", "防具", "饰品", "材料"]
const CRATE_SIZES := ["small", "medium", "large"]
const CRATE_SIZE_NAMES := ["小", "中", "大"]

## Crates show only their size: 1 cell small, 2 medium, 3 or more large.
static func crate_size(item: Item) -> int:
	return clampi(item.width * item.height - 1, 0, 2)

# --- Prestige and orders (§2, §3.8) --------------------------------------------

## Cumulative prestige for ranks R1..R4. Prestige only ever unlocks convenience
## and capacity, never combat strength.
const PRESTIGE_RANKS := [20, 60, 120, 200]
const PRESTIGE_EXTRACTION := 2
## Order board slots: two to start, a third from R2.
const ORDER_SLOTS := 2
const ORDER_SLOTS_R2 := 3

## Order templates. An item qualifies by `category` (with optional `min_rarity`
## and origin `region`), by a PRTS `material` id, or, for exclusives, by its
## `effect`. `count` counts units: a stack of 5 delivers 5 (掉落物策划案 §7.2).
## Reward (龙门币) is either the delivered items' 交付价 times `mult`, or a fixed `gold`.
## `region` is the region the order points the player to ("" for any).
## Departments are the three already in the project docs (用户 2026-10-02 暂定).
const ORDERS := {
	"starter": {"dept": "工程部", "count": 4, "category": Item.Category.MATERIAL, "mult": 1.3, "prestige": 5, "weight": 0},
	"eng_materials": {"dept": "工程部", "count": 10, "category": Item.Category.MATERIAL, "mult": 1.3, "prestige": 5, "weight": 3},
	"eng_mine_materials": {"dept": "工程部", "count": 8, "category": Item.Category.MATERIAL, "region": "mine", "mult": 1.4, "prestige": 6, "weight": 2},
	"eng_carbon": {"dept": "工程部", "count": 8, "material": "碳", "mult": 1.5, "prestige": 6, "weight": 2},
	"eng_device": {"dept": "工程部", "count": 3, "material": "装置", "mult": 1.6, "prestige": 7, "weight": 2},
	"med_sugar": {"dept": "医疗部", "count": 4, "material": "糖", "mult": 1.6, "prestige": 7, "weight": 2},
	"log_furniture": {"dept": "后勤部", "count": 4, "material": "家具零件", "mult": 1.5, "prestige": 7, "weight": 2},
	"eng_bolts": {"dept": "工程部", "count": 12, "material": "螺栓", "mult": 1.5, "prestige": 5, "weight": 2},
	"eng_wires": {"dept": "工程部", "count": 8, "material": "电线", "mult": 1.5, "prestige": 6, "weight": 2},
	"med_supplies": {"dept": "医疗部", "count": 3, "material": "医用耗材包", "mult": 1.6, "prestige": 7, "weight": 2},
	"log_fuel": {"dept": "后勤部", "count": 10, "material": "固体燃料", "mult": 1.5, "prestige": 6, "weight": 2},
	"med_city_armor": {"dept": "医疗部", "count": 1, "category": Item.Category.ARMOR, "region": "city", "mult": 1.4, "prestige": 6, "weight": 2},
	"log_fine_weapon": {"dept": "后勤部", "count": 1, "category": Item.Category.WEAPON, "min_rarity": 1, "mult": 1.5, "prestige": 8, "weight": 2},
	"log_trinkets": {"dept": "后勤部", "count": 2, "category": Item.Category.TRINKET, "mult": 1.3, "prestige": 6, "weight": 2},
	"eng_raw_ore": {"dept": "工程部", "count": 1, "effect": "raw_ore", "region": "mine", "gold": 16000, "prestige": 12, "weight": 1},
	"log_riot_shield": {"dept": "后勤部", "count": 1, "effect": "riot_shield", "region": "city", "gold": 14000, "prestige": 12, "weight": 1},
	"med_frozen_relic": {"dept": "医疗部", "count": 1, "effect": "frozen_relic", "region": "snow", "gold": 22000, "prestige": 15, "weight": 1},
}

static func rank_of(prestige: int) -> int:
	var rank := 0
	for threshold in PRESTIGE_RANKS:
		if prestige >= threshold: rank += 1
	return rank

static func is_exclusive_order(id: String) -> bool:
	return ORDERS[id].has("effect")

## What an order asks for, in words: "工程部：材料 ×3（切尔诺伯格）".
static func order_text(id: String) -> String:
	var t: Dictionary = ORDERS[id]
	var what := ""
	if t.has("effect"):
		what = {"raw_ore": "未封装源石原矿", "riot_shield": "近卫局暴动盾", "frozen_relic": "冻土下的旧物"}[t.effect]
	elif t.has("material"):
		what = "★%d %s" % [MaterialCatalog.star(t.material), t.material]
	else:
		what = CATEGORY_NAMES[t.category]
		if int(t.get("min_rarity", 0)) >= 1: what = "精良及以上" + what
	var where := ""
	if t.has("region") and not t.has("effect"): where = "（产地：%s）" % FieldCatalog.REGIONS[t.region].name.split(" · ")[0]
	return "%s：%s ×%d%s" % [t.dept, what, t.count, where]

# --- Medical: contamination, injury, pharmacy (§4) -----------------------------

## Contamination per second in the field, from each source.
const CONTAMINATION_MINE := 0.02          # working in the mine at all
const CONTAMINATION_DEEP_ROUTE := 0.02    # on the 深部污染带 route (route index 2), any region
const CONTAMINATION_PER_ORE := 0.06       # each unsealed ore carried, pack or safe bag
const CONTAMINATION_DECAY := 5            # off at every settlement, before this run's dose
const CONTAMINATION_MAX := 100
## Tiers by the value at departure: [from, max HP penalty, potion healing penalty, self-regen stops].
const CONTAMINATION_TIERS := [
	[0, 0.0, 0.0, false],
	[40, 0.10, 0.0, false],
	[70, 0.20, 0.25, false],
	[100, 0.30, 0.25, true],
]
const CONTAMINATION_TIER_NAMES := ["无", "轻度", "中度", "重度"]
## Prices are 龙门币 (经济修订案 §3, the old 资金 ×100).
const DECON_PRICE_PER_POINT := 150.0
const DECON_MIN_PRICE := 1000

const INJURY_HP_PENALTY := 0.25
const INJURY_TREATMENT := 3000
const HP_PENALTY_CAP := 0.40              # injury and contamination add up to at most this

## Pharmacy. A is the free standard flask; B and C cost per bottle per contract.
const POTIONS := {
	"A": {"name": "标准急救剂", "price": 0, "rank": 0, "text": "立即回复 960 生命"},
	"B": {"name": "缓释凝胶", "price": 600, "rank": 0, "text": "6 秒内共回复 1680 生命；再用一瓶会覆盖剩余回复"},
	"C": {"name": "抑制喷剂", "price": 1000, "rank": 2, "text": "回复 480 生命，污染 −6，之后 30 秒污染累积减半"},
}
## Flasks are pack items (药剂进背包): three 标准急救剂 are issued free for every
## contract and go into the pack at departure; more are bought at the pharmacy
## (or from 可露希尔), each taking a cell.
const FREE_POTIONS := 3
const POTION_A_PRICE := 300
## The old "flask capacity" stat (relics, affixes) now changes flask healing:
## each point is ±20%.
const POTION_HEAL_PER_CAP := 0.2

static func create_potion(type: String) -> Item:
	var p: Dictionary = POTIONS[type]
	var item := Item.create(str(p.name), Item.Category.MATERIAL, 1, 1)
	item.potion_type = type
	item.description = str(p.text)
	item.value = int(p.price) / Economy.LMD_PER_VALUE if type != "A" else POTION_A_PRICE / Economy.LMD_PER_VALUE
	return item
## Scaled with Lappland's life (局内构筑与数值策划案 §5.5): 40% / 70% / 20% of the base 2400.
const POTION_A_HEAL := 960.0
const POTION_B_HEAL := 1680.0
const POTION_B_SECONDS := 6.0
const POTION_C_HEAL := 480.0
const POTION_C_CLEANSE := 6.0
const POTION_C_SUPPRESS_SECONDS := 30.0

static func contamination_tier(value: float) -> int:
	var tier := 0
	for i in range(CONTAMINATION_TIERS.size()):
		if value >= CONTAMINATION_TIERS[i][0]: tier = i
	return tier

static func decon_price(points: int) -> int:
	return 0 if points <= 0 else maxi(DECON_MIN_PRICE, ceili(points * DECON_PRICE_PER_POINT))

# --- Prestige unlocks, expansion, the drone (§2.2, §3.5, §3.6) -----------------

## Price and rank needed for each rack slot in build order (slot 0 is there from
## the start): front row 2nd and 3rd, then the middle row, then the back row.
const RACK_PRICES := [0, 6000, 9000, 14000, 14000, 14000, 20000, 20000, 20000]
const RACK_RANKS := [0, 1, 1, 2, 2, 2, 3, 3, 3]
## Pack and safe-bag expansions (装备与背包界面调研 §5.11, after Grim Dawn's
## extra bags and Tarkov's secure containers). Level 0 is what she starts with.
const PACK_SIZES := [Vector2i(10, 6), Vector2i(10, 8), Vector2i(12, 8)]
const PACK_PRICES := [0, 12000, 26000]
const PACK_RANKS := [0, 1, 2]
const SAFE_SIZES := [Vector2i(2, 2), Vector2i(3, 2), Vector2i(3, 3)]
const SAFE_PRICES := [0, 15000, 32000]
const SAFE_RANKS := [0, 2, 3]
const DRONE_PRICE := 15000
const DRONE_RANK := 1
## Construction also takes base materials from points of interest: basic
## hardware plus a theme supply plus PRTS materials (基建资源策划案 §3, after
## Tarkov's hideout and Duckov's facilities). {material id: units}, by rack slot
## / expansion level.
const RACK_MATERIALS := [{}, {"螺栓": 4, "金属板": 2}, {"螺栓": 4, "金属板": 2},
	{"碳": 3, "螺栓": 6, "基础加固建材": 1}, {"碳": 3, "螺栓": 6, "基础加固建材": 1}, {"碳": 3, "螺栓": 6, "基础加固建材": 1},
	{"碳素": 3, "金属板": 4, "进阶加固建材": 1}, {"碳素": 3, "金属板": 4, "进阶加固建材": 1}, {"碳素": 3, "金属板": 4, "进阶加固建材": 1}]
const PACK_MATERIALS := [{}, {"帆布": 3, "胶带": 2, "碳": 2}, {"帆布": 5, "密封泡沫": 2, "家具零件": 3}]
const SAFE_MATERIALS := [{}, {"金属板": 4, "继电器": 1, "赤金": 1}, {"碳素组": 1, "电路板": 2, "赤金": 2}]
## The camp upgrade (撤离与营地修订案 §3, 基地建设, all regions at once): camps stop
## adding contamination. Price provisional (用户：营地升级价格待定).
const CAMP_UPGRADE_PRICE := 30000
const CAMP_UPGRADE_MATERIALS := {"碳素": 3, "金属板": 4, "继电器": 1}
const DRONE_MATERIALS := {"微型电机": 1, "电路板": 2, "蓄电池": 2, "家具零件": 2}

## "碳×4 + 基础加固建材×1".
static func cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for id in cost: parts.append("%s×%d" % [id, int(cost[id])])
	return " + ".join(parts)
const REROLL_RANK := 3            # one free order reroll after every settlement
## Staging warns at departure and its marker turns yellow from this share full.
const STAGING_WARNING := 0.9

## What each rank opens, for the rank-up message and the warehouse terminal.
const RANK_UNLOCKS := [
	"",
	"仓管台可以购买一键分类无人机，以及各区前排的第 2、3 个货架；背包扩容到 10×8",
	"中排货架；药房的抑制喷剂；第 3 个订单栏；背包扩容到 12×8；安全袋扩容到 3×2",
	"后排货架；每次结算后可以免费刷新 1 张订单；安全袋扩容到 3×3",
	"预留：两翼走廊的清理",
]
