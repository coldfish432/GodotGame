class_name FactionSpecials
extends RefCounted

## 势力特供 (势力特供策划案_v0_2 §二, 用户 2026-10-22: 其他部也要): like 龙门商会's
## 玄纹墨, each is one item only its faction sells, from a relation rank on,
## used up in one department of the base (or, for 整合运动残党, in the field).
## The numbers are the spec's; the rules live where each department's do.

## material -> [faction, rank it is sold from, department].
const ITEMS := {
	"高能燃料": ["karlan", 3, "voyage"],
	"下城区耳目": ["rat", 2, "exchange"],
	"高纯源岩助熔剂": ["ursus", 3, "workshop"],
	"萨米冰原苔": ["sami", 3, "medical"],
	"骑士工坊专利授权": ["kazimierz", 4, "lab"],
	"企鹅专递单": ["penguin", 2, "warehouse"],
	"残党向导": ["reunion", 2, "field"],
	# 莱茵生命's seeds go to 农业部 (§四).
	"闪耀作物种子": ["rhine", 3, "farm"],
	"闪耀作物·变种种子": ["rhine", 5, "farm"],
}

## 高能燃料: one voyage takes this share of the time, and 全速 costs no more than 标准.
const FUEL_TIME := 0.75
## 下城区耳目: buying it costs this much relation with 龙门商会.
const RAT_RIVAL := "lungmen"
const RAT_RIVAL_COST := 5
## 高纯源岩助熔剂 on a 加工部 job: twice the byproducts, the rest of the time × 0.7.
const FLUX_BYPRODUCTS := 2
const FLUX_TIME := 0.7
## 骑士工坊专利授权 on a running research: the rest of its time halved.
const PATENT_TIME := 0.5
## 企鹅专递单: bought from 企鹅物流's desk at the exchange for 龙门币.
const SLIP_PRICE := 22000

static func is_special(material: String) -> bool:
	return ITEMS.has(material)

static func faction_of(material: String) -> String:
	return str(ITEMS[material][0]) if ITEMS.has(material) else ""

static func rank_needed(material: String) -> int:
	return int(ITEMS[material][1]) if ITEMS.has(material) else 0

## `faction`'s shelf without its specials (what the flash sales and forwards draw from).
static func plain_shelf(faction: String) -> Array:
	return (FactionCatalog.info(faction).get("sells", []) as Array).filter(func(m): return not ITEMS.has(m))
