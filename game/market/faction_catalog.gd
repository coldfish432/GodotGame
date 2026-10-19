class_name FactionCatalog
extends RefCounted

## The outside factions of the exchange (势力与交易所策划案_v0_7.md §3), checked
## against PRTS on 2026-10-16 (交易所事件表_v1_0.md §0). Names marked 原 in the
## spec are this game's own.
##
## A market is one faction's book for one category of goods ("rhine:originium").
## Its quote in the faction's currency is base price × preference × index ×
## pressure, with the spread on top (§4). Gear can only be sold (用户: 不卖装备).

## Goods categories the markets trade in.
const CATEGORIES := {
	"weapon": "武器", "armor": "防具", "trinket": "饰品",
	"elite": "养成材料", "originium": "源石类", "medical": "医疗物资",
	"build": "建材", "electronic": "电子", "fuel": "燃料",
	"cold": "寒地物资", "trade": "贸易品", "contraband": "违禁品",
}
## Categories nobody sells to the player (gear only goes one way).
const SELL_ONLY := ["weapon", "armor", "trinket", "contraband"]

## currency: "lmd" 龙门币 / "gold" 赤金 (its 赤金账户). active: "day" 08–20,
## "night" 20–08, "all". spread: full bid/ask gap in the active hours. depth:
## the market's size against selling pressure. noise: volatility multiplier.
## prefs: category -> preference (absent = not traded). sells: material ids on
## its shelf. field_only: only traded at its posts in the field or by 企鹅物流.
const FACTIONS := {
	"lungmen": {"name": "龙门商会", "region": "龙门", "currency": "lmd", "active": "day", "spread": 0.03, "depth": 1.0, "noise": 1.0,
		"prefs": {"armor": 1.25, "medical": 1.2, "build": 1.1, "electronic": 1.0, "fuel": 1.0, "weapon": 0.9, "trinket": 0.9, "elite": 0.9, "trade": 1.1},
		"sells": ["螺栓", "金属板", "胶带", "电线", "灯泡", "蓄电池", "医用耗材包", "代糖", "糖"]},
	"rat": {"name": "鼠王的下城区", "region": "龙门", "currency": "lmd", "active": "night", "spread": 0.10, "depth": 0.5, "noise": 1.5, "black": true,
		"prefs": {"contraband": 1.6, "weapon": 1.2, "armor": 0.95, "trinket": 1.0, "elite": 0.95, "electronic": 1.0, "medical": 1.05, "originium": 1.1},
		"sells": ["装置", "全新装置", "研磨石", "化合切削液", "电路板", "继电器"]},
	"rhine": {"name": "莱茵生命", "region": "哥伦比亚", "currency": "gold", "active": "all", "spread": 0.04, "depth": 0.8, "noise": 1.0,
		"prefs": {"originium": 1.5, "medical": 1.2, "elite": 1.25, "electronic": 1.15, "cold": 1.3, "trinket": 0.9},
		"sells": ["全新装置", "凝胶", "晶体元件", "糖", "聚酸酯"]},
	"karlan": {"name": "喀兰贸易", "region": "谢拉格", "currency": "gold", "active": "all", "spread": 0.03, "depth": 1.0, "noise": 1.0,
		"prefs": {"trinket": 1.3, "weapon": 1.1, "armor": 1.05, "cold": 1.4, "trade": 1.2, "build": 0.9, "fuel": 1.05},
		"sells": ["帆布", "固体燃料", "密封泡沫", "碳素"]},
	"ursus": {"name": "乌萨斯西北矿场", "region": "乌萨斯", "currency": "gold", "active": "day", "spread": 0.05, "depth": 0.7, "noise": 1.0,
		"prefs": {"originium": 1.3, "electronic": 1.2, "weapon": 1.15, "fuel": 1.1, "build": 1.0, "elite": 1.0},
		"sells": ["源岩", "固源岩", "异铁", "异铁碎片", "燃料罐"]},
	"reunion": {"name": "整合运动残党", "region": "乌萨斯", "currency": "gold", "active": "night", "spread": 0.10, "depth": 0.4, "noise": 1.5, "black": true, "field_only": true,
		"prefs": {"medical": 1.5, "originium": 1.2, "weapon": 1.2, "fuel": 1.2, "contraband": 1.3},
		"sells": ["源岩", "固源岩", "固源岩组"]},
	"sami": {"name": "萨米林地部族", "region": "萨米", "currency": "gold", "active": "day", "spread": 0.08, "depth": 0.3, "noise": 1.0, "barter": true, "field_only": true,
		"prefs": {"fuel": 1.4, "medical": 1.3, "build": 1.2, "trade": 1.15},
		"sells": ["林地草药", "鞣制兽皮"]},
	"kazimierz": {"name": "卡西米尔商业联合会", "region": "卡西米尔", "currency": "gold", "active": "all", "spread": 0.03, "depth": 1.5, "noise": 1.0, "fee_extra": 0.01,
		"prefs": {"trinket": 1.35, "weapon": 1.2, "armor": 1.15, "trade": 1.25, "build": 1.0, "electronic": 1.0},
		"sells": ["螺栓", "螺母", "钉子", "电源线", "工业补给箱"]},
	"penguin": {"name": "企鹅物流", "region": "龙门", "currency": "lmd", "active": "all", "spread": 0.0, "depth": 1.0, "noise": 0.0, "transport": true,
		"prefs": {}, "sells": []},
}
const ORDER: Array[String] = ["lungmen", "rat", "rhine", "karlan", "ursus", "reunion", "sami", "kazimierz", "penguin"]
## Selling contraband to one side costs relation with the other (§3).
const RIVALS := {"rat": ["lungmen"], "lungmen": ["rat"], "reunion": ["ursus", "lungmen"], "ursus": ["reunion"]}
## Who issues 差价合约 (§9.1).
const CFD_ISSUERS := ["karlan", "kazimierz"]
## Field posts by region (§12): who can be met where.
const POSTS := {"city": ["rat"], "mine": ["reunion", "ursus"], "snow": ["sami"]}
## The LMD/赤金 rate's market id.
const FX := "fx"

static func info(id: String) -> Dictionary:
	return FACTIONS.get(id, {})

static func name_of(id: String) -> String:
	return "龙门币 / 赤金" if id == FX else str(FACTIONS.get(id, {}).get("name", id))

static func currency(id: String) -> String:
	return str(FACTIONS.get(id, {}).get("currency", "lmd"))

static func trading() -> Array[String]:
	var out: Array[String] = []
	for id in ORDER:
		if not FACTIONS[id].get("transport", false): out.append(id)
	return out

## Every market id: "faction:category" for each traded category, then "fx".
static func markets() -> Array[String]:
	var out: Array[String] = []
	for id in trading():
		for category in FACTIONS[id].prefs:
			out.append("%s:%s" % [id, category])
	out.append(FX)
	return out

static func split(market: String) -> Array:
	if market == FX: return [FX, ""]
	var parts := market.split(":")
	return [parts[0], parts[1] if parts.size() > 1 else ""]

static func market_name(market: String) -> String:
	if market == FX: return name_of(FX)
	var parts := split(market)
	return "%s @ %s" % [CATEGORIES.get(parts[1], parts[1]), name_of(parts[0])]

static func preference(faction: String, category: String) -> float:
	return float(FACTIONS.get(faction, {}).get("prefs", {}).get(category, 0.0))

## The market category of an item, "" when no market takes it (potions, 赤金).
static func category_of(item: Item) -> String:
	if item == null or item.is_potion(): return ""
	match item.effect:
		"raw_ore": return "contraband"
		"frozen_relic": return "cold"
	match item.category:
		Item.Category.WEAPON: return "weapon"
		Item.Category.ARMOR: return "armor"
		Item.Category.TRINKET: return "trinket"
	return material_category(item.material_id)

const ORIGINIUM := ["源岩", "固源岩", "固源岩组", "提纯源岩", "源石碎片"]
const MEDICAL := ["代糖", "糖", "糖组", "糖聚块", "医用耗材包", "林地草药"]
const ELECTRONIC_PRTS := ["破损装置", "装置", "全新装置", "改量装置", "晶体元件"]

static func material_category(id: String) -> String:
	if id.is_empty() or id == Economy.GOLD_ID: return ""
	if not MaterialCatalog.MATERIALS.has(id): return ""
	if id in ORIGINIUM: return "originium"
	if id in MEDICAL: return "medical"
	if id in ELECTRONIC_PRTS: return "electronic"
	var data: Dictionary = MaterialCatalog.MATERIALS[id]
	if str(data.get("source", "")) == "trade": return "trade"
	match str(data.get("group", "")):
		"电子", "能源": return "electronic"
		"燃料": return "fuel"
		"医疗": return "medical"
		"建材", "日用", "工具": return "cold" if id in ["帆布", "鞣制兽皮"] else "build"
	if id == "鞣制兽皮": return "cold"
	return "build" if str(data.get("kind", "")) == "base" else "elite"

## Factions that take this category, in ORDER.
static func buyers(category: String, include_field_only: bool = true) -> Array[String]:
	var out: Array[String] = []
	for id in trading():
		if preference(id, category) <= 0.0: continue
		if not include_field_only and FACTIONS[id].get("field_only", false): continue
		out.append(id)
	return out

## Whether the faction is in its active hours at local hour `hour` (0–23).
static func active_at(faction: String, hour: int) -> bool:
	match str(FACTIONS.get(faction, {}).get("active", "all")):
		"day": return hour >= 8 and hour < 20
		"night": return hour >= 20 or hour < 8
	return true

## Hours (local) where the active window opens or closes: ±30 min busy.
static func switch_hours(faction: String) -> Array[int]:
	match str(FACTIONS.get(faction, {}).get("active", "all")):
		"day", "night": return [8, 20]
	return []
