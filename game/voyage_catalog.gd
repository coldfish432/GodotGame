class_name VoyageCatalog
extends RefCounted

## Rhodes Island's voyages, medical stays and bulk orders (沙盘航行策划案_v1_0.md):
## the numbers only. The rules are in VoyageState.

## Where the ship can lie (§2): the four field maps' places and three factions' homes.
const ANCHORS: Array[String] = ["龙门", "切尔诺伯格", "萨米", "叙拉古", "哥伦比亚", "谢拉格", "卡西米尔"]
## The exchange factions at each anchor (FactionCatalog ids).
const ANCHOR_FACTIONS := {
	"龙门": ["lungmen", "rat", "penguin"], "切尔诺伯格": ["ursus", "reunion"], "萨米": ["sami"],
	"叙拉古": [], "哥伦比亚": ["rhine"], "谢拉格": ["karlan"], "卡西米尔": ["kazimierz"],
}
## Where a delivery contract can take a faction's crate: the two field maps
## nearest its home on the table (§2, x × aspect 1.7).
const DELIVERY_MAPS := {
	"lungmen": ["city", "mine"], "rat": ["city", "mine"],
	"ursus": ["mine", "siracusa"], "reunion": ["mine", "siracusa"],
	"sami": ["snow", "siracusa"], "rhine": ["snow", "siracusa"],
	"karlan": ["snow", "siracusa"], "kazimierz": ["snow", "siracusa"],
}

# --- Voyages (§3) ---------------------------------------------------------------------------

## What a voyage burns: a fixed fitting-out, and so much per unit of distance.
const VOYAGE_FIXED := {"燃料罐": 6, "金属板": 50, "医用耗材包": 20}
const VOYAGE_PER_DISTANCE := {"燃料罐": 80, "金属板": 60}
## Real hours: HOURS_BASE + HOURS_PER_DISTANCE × d at the standard pace.
const HOURS_BASE := 1.0
const HOURS_PER_DISTANCE := 6.0
## 全速 carries everything from the start; 边走边补 buys on the way (用户 2026-10-19).
const MODES: Array[String] = ["standard", "fast", "resupply"]
const MODE_NAMES := {"standard": "标准", "fast": "全速", "resupply": "边走边补"}
const MODE_COST := {"standard": 1.0, "fast": 1.25, "resupply": 0.75}
const MODE_TIME := {"standard": 1.0, "fast": 0.7, "resupply": 1.3}
const COST_ROUND := 100

# --- Medical stays (§4) ---------------------------------------------------------------------

const STAY_KINDS: Array[String] = ["injured", "infected"]
const STAY_NAMES := {"injured": "伤员", "infected": "感染者"}
## 龙门币 an hour (用户 2026-10-19: 3000/6000).
const STAY_COST := {"injured": 3000, "infected": 6000}
## Relation an hour before the anchor's multiplier (用户 2026-10-19: +1/+2).
const STAY_BASE := {"injured": 1.0, "infected": 2.0}
## faction -> [injured ×, infected ×]. A faction missing a column gains nothing from it.
const STAY_MULT := {
	"lungmen": [1.0, 0.5], "rat": [0.5, 1.5],
	"ursus": [0.5, 0.0], "reunion": [0.0, 1.5],
	"sami": [1.0, 1.25], "rhine": [0.75, 1.25], "karlan": [1.25, 0.5], "kazimierz": [1.0, 0.75],
}
## The mines live on infected labour: treating infected costs them this much an hour.
const URSUS_INFECTED_LOSS := -1.0
## A stay lifts no faction past R3 (§4.3).
const STAY_CAP_RANK := 3
## Medical supplies from the shelves pay at most this share of an hour (§4.1).
const SUPPLY_SHARE := 0.5
## At most this many hours are settled at once when the game catches up.
const CATCH_UP_HOURS := 24 * 14

## Conflicts (§4.4). Chernobog: every CONFLICT_HOURS of infected care add this
## much to the next mine contract's threat at the start, up to the cap.
const CONFLICT_HOURS := 6
const MINE_THREAT_STEP := 0.10
const MINE_THREAT_CAP := 0.40
## Kazimierz: 无胄盟 strike in an hour of infected care with this chance.
const KAZ_CHANCE := 0.05
const KAZ_LOSS := -10
## Siracusa: the families' insurance an hour of infected care, and the 血债
## rate of the next Siracusa contract per CONFLICT_HOURS, down to the floor.
const SIRACUSA_INSURANCE := 2000
const SIRACUSA_DEBT_STEP := 0.9
const SIRACUSA_DEBT_FLOOR := 0.6
## A day's stay at an anchor makes its field posts likelier while she stays (§3.3 v1 草案).
const POST_HOURS := 24
const POST_BOOST := 1.5

# --- Bulk orders (§5) -----------------------------------------------------------------------

const ORDER_SLOTS := 4
const ORDER_REFILL := 6 * 3600
const ORDER_TERM := 3 * 86400
const ORDER_PREMIUM := 1.3
const ORDER_RELATION := Vector2i(10, 20)
## The relation scale: the value (龙门币) that earns the top of ORDER_RELATION.
const ORDER_RELATION_VALUE := 80000.0
## Handover in the faction's waters takes an hour.
const HANDOVER := 3600
## Lines per order; each asks 30–100, all lines together at most 150 (用户 2026-10-19).
const ORDER_LINES := Vector2i(1, 2)
const ORDER_COUNT := Vector2i(30, 100)
const ORDER_TOTAL := 150
## Categories an order can ask for (gear only goes one way, contraband never).
const ORDER_CATEGORIES := ["originium", "medical", "electronic", "build", "fuel", "cold", "elite"]

## The crate a delivery contract carries: too big for any safe bag, worth
## nothing to anyone but its buyer.
const CARGO_NAME := "大宗货箱"
const CARGO_EFFECT := "bulk_cargo"
const CARGO_SIZE := Vector2i(4, 3)
## A delivery floor lies in 1 .. (deepest camp + DELIVERY_REACH) (用户: 过了30层 → 1~39).
const DELIVERY_REACH := 9

## The anchor a faction is at home in, "" for none.
static func home_of(faction: String) -> String:
	for place in ANCHORS:
		if faction in ANCHOR_FACTIONS[place]: return place
	return ""

## The field region whose maps are run at an anchor, "" for none.
static func region_at(place: String) -> String:
	for region in FieldCatalog.REGIONS:
		if TerraMap.place_for_region(region) == place: return region
	return ""

## The distance between two anchors on the table, 0–1 with x stretched by the map's aspect.
static func distance(a: String, b: String) -> float:
	var nations: Dictionary = TerraMap.data().nations
	if not nations.has(a) or not nations.has(b): return 0.0
	var aspect := float(TerraMap.data().get("aspect", 1.0))
	var pa: Array = nations[a]
	var pb: Array = nations[b]
	return Vector2((float(pa[0]) - float(pb[0])) * aspect, float(pa[1]) - float(pb[1])).length()

## Materials a voyage of distance `d` burns, rounded up.
static func voyage_supplies(d: float) -> Dictionary:
	var out := VOYAGE_FIXED.duplicate()
	for id in VOYAGE_PER_DISTANCE:
		out[id] = int(out.get(id, 0)) + ceili(float(VOYAGE_PER_DISTANCE[id]) * d)
	return out

## Real seconds at `mode`.
static func voyage_seconds(d: float, mode: String) -> int:
	return roundi((HOURS_BASE + HOURS_PER_DISTANCE * d) * float(MODE_TIME.get(mode, 1.0)) * 3600.0)

## [injured ×, infected ×] for `faction`.
static func stay_mult(faction: String, kind: String) -> float:
	var row: Array = STAY_MULT.get(faction, [0.0, 0.0])
	return float(row[0 if kind == "injured" else 1])
