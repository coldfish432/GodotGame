class_name FeatureCatalog
extends RefCounted

## 地图特色 (地图特色策划案_v1_0.md, 用户 2026-10-19): one meter a region of its
## own, 0–100, only in the field, gone at settlement. 源石污染 (the mine; its own
## numbers stay in BaseCatalog), 血债 (叙拉古), 寒冷 (萨米). 龙门 has none.
## Initial tuning, like FieldCatalog.

const KINDS := ["contamination", "debt", "cold"]
const NAMES := {"contamination": "源石污染", "debt": "血债", "cold": "寒冷"}
## The region whose own feature it is.
const REGION_OF := {"contamination": "mine", "debt": "siracusa", "cold": "snow"}
const MAX := 100.0
## Two steps for every feature (§2): from 60 medium, from 90 heavy.
const TIER_AT := [0.0, 60.0, 90.0]
const TIER_NAMES := {"contamination": ["无", "中度", "重度"], "debt": ["无", "仇家", "清算"], "cold": ["无", "失温", "冻僵"]}
## The badge's one character (HUD).
const BADGES := {"contamination": "染", "debt": "债", "cold": "寒"}

static func tier(value: float) -> int:
	var out := 0
	for i in range(TIER_AT.size()):
		if value >= TIER_AT[i]: out = i
	return out

static func feature_of(region: String) -> String:
	for kind in REGION_OF:
		if REGION_OF[kind] == region: return kind
	return ""

# --- Depth (§6): every 20 floors the growth is one step faster ---------------------

const DEPTH_BLOCK := 20
const DEPTH_STEP := 0.1

## ×1.0 on 1–20, ×1.1 on 21–40, ×1.2 on 41–60, and on, never capped.
static func depth_mult(floor_number: int) -> float:
	return 1.0 + DEPTH_STEP * floori(maxi(floor_number - 1, 0) / DEPTH_BLOCK)

# --- 血债 (§4) ---------------------------------------------------------------------

## The old kill weights (EnemyAttacks "debt", CAPO_DEBT, "incite") were made
## for a meter that emptied when full; the meter is kept now, at half weight.
const DEBT_SCALE := 0.5
## 仇家 (60): the families hit harder and see her from further.
const FEUD_DAMAGE := 0.15
const FEUD_SIGHT := 0.3
## 清算 (90): a reckoning at once, another every RECKONING_EVERY s while it
## stays there; each one sent takes RECKONING_PAYOFF off.
const RECKONING_EVERY := 90.0
const RECKONING_PAYOFF := 20.0
## 萨卢佐家族的旧徽记 worn: 血债 grows this much faster.
const CREST_DEBT := 0.25

static func family(enemy_type: String) -> bool:
	return enemy_type.begins_with("family_")

# --- 寒冷 (§5) ---------------------------------------------------------------------

## A second on a 萨米 floor; the deep route (暴风雪带) adds COLD_DEEP.
const COLD_RATE := 0.10
const COLD_DEEP := 0.05
## [move cut, stamina regeneration cut, attack speed cut, regeneration stopped, drain (share of max HP a second)]
const COLD_TIERS := [
	[0.0, 0.0, 0.0, false, 0.0],
	[0.10, 0.30, 0.0, false, 0.0],
	[0.20, 0.30, 0.15, true, 0.001],
]

static func cold_move(value: float) -> float:
	return 1.0 - float(COLD_TIERS[tier(value)][0])

static func cold_stamina(value: float) -> float:
	return 1.0 - float(COLD_TIERS[tier(value)][1])

static func cold_aspd(value: float) -> float:
	return 1.0 - float(COLD_TIERS[tier(value)][2])

static func cold_stops_regen(value: float) -> bool:
	return bool(COLD_TIERS[tier(value)][3])

static func cold_drain(value: float) -> float:
	return float(COLD_TIERS[tier(value)][4])

## 火堆: two on every 萨米 floor and half the time a third, along the main path
## at a quarter, a half and three quarters of the way, FIRE_OFFSET m to its side.
const FIRES := 2
const FIRE_EXTRA := 0.5
const FIRE_OFFSET := Vector2(3.0, 6.0)
const FIRE_ENEMY_CLEAR := 10.0
const FIRE_RADIUS := 4.5
## Cold a second taken off inside a lit fire's radius (it does not grow there).
const FIRE_WARM := 3.0
## What a fire can hold, in seconds.
const FIRE_MAX := 300.0
## Seconds one piece burns (用户 2026-10-19: she picks which to burn).
const FUELS := {"帆布": 30.0, "家具零件": 45.0, "木板": 60.0, "固体燃料": 120.0, "燃料罐": 240.0}
## 萨米's ordinary enemies sometimes carry a plank.
const SNOW_PLANK := 0.05

# --- 降低的手段 (§3.3, §4.5, §5.4) -----------------------------------------------------

## Field supplies: stackable pack items used with a right click.
## cut: what one use takes off (the sealer seals an ore instead).
const SUPPLIES := {
	"源石矿封装器": {"feature": "contamination", "cut": 0.0, "stack": 5, "bars": 2,
		"text": "简易封装一块未封装源石原矿：携带时污染降到每秒 +0.01，交付价不变。"},
	"中间人信物": {"feature": "debt", "cut": 20.0, "stack": 3, "bars": 4,
		"text": "叙拉古中间人的信物，递出去，仇家会退一步。血债 −20。"},
	"自热罐头": {"feature": "cold", "cut": 30.0, "stack": 5, "bars": 2,
		"text": "拉开就热的罐头。寒冷 −30。"},
}
## 可露希尔 sells these in a camp for 赤金, with 固体燃料.
const CAMP_SUPPLIES := ["源石矿封装器", "中间人信物", "自热罐头", "固体燃料"]
const FUEL_BARS := 1
## Where they turn up: point-of-interest kind -> [supply, chance].
const SUPPLY_DROPS := {
	"construction": [["源石矿封装器", 0.15, "mine"]],
	"ore_vein": [["源石矿封装器", 0.20, "mine"]],
	"safe": [["中间人信物", 0.15, "siracusa"]],
	"camp": [["自热罐头", 0.30, "snow"]],
}
## A sealed ore: a sixth of an unsealed one.
const SEALED_ORE_RATE := 0.01
const SEALED_ORE_NAME := "简易封装的源石原矿"

## 净化喷淋点 (矿区): on this share of mine floors, one; E held SHOWER_SECONDS.
const SHOWER_CHANCE := 0.4
const SHOWER_SECONDS := 3.0
const SHOWER_CUT := 25.0

## 营地处理 (可露希尔, in a camp): contamination −CAMP_CLEANSE for
## CAMP_CLEANSE_BARS, once a camp; 血债 −CAMP_DEBT for CAMP_DEBT_BARS, one more
## each time in the same camp. A camp's fire clears the cold.
const CAMP_CLEANSE := 30.0
const CAMP_CLEANSE_BARS := 3
const CAMP_DEBT := 10.0
const CAMP_DEBT_BARS := 2

static func create_supply(id: String, count: int = 1) -> Item:
	var data: Dictionary = SUPPLIES[id]
	var item := Item.create(id, Item.Category.MATERIAL, 1, 1)
	item.material_id = id
	item.max_stack = int(data.stack)
	item.unit_value = int(data.bars) * Economy.GOLD_BAR_LMD / Economy.LMD_PER_VALUE / 2
	item.description = str(data.text)
	item.set_quantity(clampi(count, 1, item.max_stack))
	return item

static func is_supply(item: Item) -> bool:
	return item != null and SUPPLIES.has(item.material_id)

# --- 基地随队物资 (§8) ------------------------------------------------------------

## Bought at the base for 龙门币, kept at the base (no shelf space), one taken
## per contract when ticked at departure. A kind's plain and refined versions
## do not stack: one of them a contract.
const KITS := {
	"dust_mask": {"name": "防尘过滤面罩", "feature": "contamination", "cut": 0.3, "price": 14000, "store": 1},
	"dust_mask_plus": {"name": "精制防尘过滤面罩", "feature": "contamination", "cut": 0.5, "price": 34000, "store": 3},
	"broker_letter": {"name": "中间人的担保函", "feature": "debt", "cut": 0.3, "price": 20000, "store": 1},
	"broker_letter_plus": {"name": "精制中间人的担保函", "feature": "debt", "cut": 0.5, "price": 45000, "store": 3},
	"sami_lining": {"name": "萨米防寒内衬", "feature": "cold", "cut": 0.3, "price": 14000, "store": 1},
	"sami_lining_plus": {"name": "精制萨米防寒内衬", "feature": "cold", "cut": 0.5, "price": 34000, "store": 3},
}

## Kits come in ten tiers (龙门币平衡与科研部策划案 v1.1 §4.1): each tier cuts
## KIT_TIER_STEP more and costs price × Economy.income_index; used below the
## floor's tier, each tier short loses KIT_TIER_LOSS.
const KIT_TIER_STEP := 0.03
const KIT_TIER_LOSS := 0.05

static func kit_cut(id: String, tier: int, floor_tier: int = 0) -> float:
	var cut := float(KITS[id].cut) + KIT_TIER_STEP * (tier - 1)
	if floor_tier > tier: cut -= KIT_TIER_LOSS * (floor_tier - tier)
	return clampf(cut, 0.0, 0.95)

static func kit_price(id: String, tier: int) -> int:
	return Economy.tiered(int(KITS[id].price), tier)

## "防尘过滤面罩 · Ⅳ".
static func kit_name(id: String, tier: int) -> String:
	return "%s · %s" % [KITS[id].name, Economy.roman(tier)]

## The kits that can go on a contract in `region`: its own feature's, and the
## mask everywhere (the deep route and ore raise contamination anywhere).
static func kits_for(region: String) -> Array[String]:
	var out: Array[String] = []
	for id in KITS:
		var feature: String = KITS[id].feature
		if feature == "contamination" or REGION_OF[feature] == region: out.append(id)
	return out
