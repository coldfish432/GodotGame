class_name FieldCatalog
extends RefCounted

## All numbers here are initial playtest tuning, not additional hard design rules.
const SWORD_WAVE_CHANCE := 0.25 # provisional; rolled once per eligible weapon
const ATTACK_SPEED_AFFIX := 0.10 # provisional; weapon and trinket loot only
## Camps (撤离与营地修订案 §1): after every ten floors, a squad camp with the
## fixed extraction and 可露希尔.
const CAMP_INTERVAL := 10
## Random extraction (§2): at most one in each block of ten, on floor 4, 5 or 6,
## 50% in all. Rolled floor by floor with these conditional odds, so each of the
## three floors carries exactly 1/6.
const RANDOM_EXTRACTION_ODDS := {4: 1.0 / 6.0, 5: 1.0 / 5.0, 6: 1.0 / 4.0}
## Time a camp visit counts for contamination until the camp is upgraded (§3).
const CAMP_EXPOSURE_SECONDS := 30.0
## 可露希尔's 寄存 fee: this share of the 交付价, in 赤金, rounded up, at least one.
const DEPOSIT_FEE := 0.2
## Hidden difficulty (§4): this much per floor below the first, plus the route.
const DIFFICULTY_PER_FLOOR := 3.5
## Life lost per second for each unsealed ore carried (2.5% of the base 2400,
## the same share as the old 0.25 of 10).
const RAW_ORE_DRAIN := 60.0
## Affix sizes by stat (局内构筑与数值策划案 §7.2). Weapons lean offensive,
## armour defensive, trinkets toward arts and tempo.
const AFFIX_AMOUNTS := {
	ItemModifier.Stat.MAX_HP_PCT: 0.08, ItemModifier.Stat.MOVE_SPEED_PCT: 0.08,
	ItemModifier.Stat.ATTACK_SPEED_PCT: 0.10, ItemModifier.Stat.ATK_PCT: 0.08,
	ItemModifier.Stat.ARTS_PCT: 0.10, ItemModifier.Stat.DEF_FLAT: 40.0,
	ItemModifier.Stat.RES_FLAT: 8.0, ItemModifier.Stat.CRIT_RATE: 0.05, ItemModifier.Stat.CRIT_DMG: 0.20,
}
const AFFIX_POOLS := {
	Item.Category.WEAPON: [ItemModifier.Stat.ATK_PCT, ItemModifier.Stat.ATTACK_SPEED_PCT, ItemModifier.Stat.CRIT_RATE, ItemModifier.Stat.CRIT_DMG, ItemModifier.Stat.MOVE_SPEED_PCT],
	Item.Category.ARMOR: [ItemModifier.Stat.MAX_HP_PCT, ItemModifier.Stat.DEF_FLAT, ItemModifier.Stat.RES_FLAT, ItemModifier.Stat.MOVE_SPEED_PCT],
	Item.Category.TRINKET: [ItemModifier.Stat.ARTS_PCT, ItemModifier.Stat.ATTACK_SPEED_PCT, ItemModifier.Stat.CRIT_DMG, ItemModifier.Stat.MAX_HP_PCT, ItemModifier.Stat.RES_FLAT],
}

## Per-depth authoring, in the manner of 贪婪洞窟's level_N.plist, where every
## floor is its own record rather than a point on a curve. Before this, depth
## only scaled numbers smoothly, so no segment could be written to feel like
## anything in particular. See 贪婪洞窟地图设计调研.md §3.1.
##
## Depth is unbounded and that game's table is not, so entries repeat on a
## cycle. The cycle is the camp interval on purpose: the floor before every
## camp lands on the same authored entry, and so does the random-extraction
## window (floors 4–6 of each block).
const DEPTH_CYCLE := 10
const DEPTH_PROFILE := {
	1: {"enemies": 0, "elites": 0, "reward": 0.0, "note": "开局层，照地区基准"},
	2: {"enemies": 1, "elites": 0, "reward": 0.2, "note": ""},
	3: {"enemies": 1, "elites": 0, "reward": 0.3, "note": ""},
	4: {"enemies": 1, "elites": 1, "reward": 0.5, "note": "随机撤离区间"},
	5: {"enemies": 2, "elites": 0, "reward": 0.5, "note": "随机撤离区间"},
	6: {"enemies": 2, "elites": 1, "reward": 0.6, "note": "随机撤离区间"},
	7: {"enemies": 2, "elites": 1, "reward": 0.5, "note": ""},
	8: {"enemies": 3, "elites": 1, "reward": 0.6, "note": ""},
	9: {"enemies": 3, "elites": 1, "reward": 0.8, "note": ""},
	10: {"enemies": 3, "elites": 2, "reward": 1.0, "note": "营地前一层，压力与回报同时抬高"},
}

static func depth_profile(depth: int) -> Dictionary:
	return DEPTH_PROFILE[((maxi(depth, 1) - 1) % DEPTH_CYCLE) + 1]
## Insurance always brings the item back, after 1–3 more contracts (保全系统修订案
## §3); at the base it costs the item's 交付价 in 龙门币.
const INSURANCE_DELAY := Vector2i(1, 3)
## A Rhodes squad on a floor (§2): one service, its price 物品价值 × 1.0–1.5 ÷ 10 in 赤金.
const SQUAD_CHANCE := 0.3
const SQUAD_PRICE_STEPS := [1.0, 1.1, 1.2, 1.3, 1.4, 1.5]
## 坎诺特 (坎诺特商店策划案 §1–3): on 20% of floors, never with a squad. Prices in
## 赤金 (one 赤金 is one 源石锭: relics at their 集成战略 shop prices).
const TRADER_CHANCE := 0.2
const TRADER_RELICS := 2
const TRADER_GEAR := 3
const TRADER_POTIONS := 2
const TRADER_SPECIAL_CHANCE := 0.25
const TRADER_RELIC_PRICES := [8, 12, 16]
const TRADER_GEAR_MARKUP := 1.5
const TRADER_POTION_PRICES := {"A": 4, "B": 6, "C": 10}
const TRADER_BUYBACK := 0.5
const TRADER_REROLL_BASE := 3
const TRADER_REROLL_STEP := 3
const SOURCE := "https://prts.wiki/w/萨卡兹的无终奇语/想象实体图鉴"
const REGIONS := {
	"mine": {"name": "切尔诺伯格 · 坍塌矿区", "brief": "回收矿料，测绘污染。狭窄矿道 / 密集追击",
		"loot": "材料多，装备少", "exclusive": "未封装源石原矿：高价值，但携带持续失血",
		"build": "防御与生命类藏品更常见（承伤与持续作战）", "color": Color("514b3b"), "weights": [0.12, 0.12, 0.11, 0.65]},
	"city": {"name": "龙门 · 下城区废墟", "brief": "回收防务与医疗物资。曲折街区 / 近战伏击",
		"loot": "防具多，制式装备品质较高", "exclusive": "近卫局暴动盾：更能承伤，但降低移速",
		"build": "攻击、防御与攻速类藏品更常见（近战与格挡）", "color": Color("354656"), "weights": [0.18, 0.56, 0.14, 0.12]},
	"snow": {"name": "萨米 · 冻土林线", "brief": "采集极寒样本，回收冻土旧物。开阔林线 / 稀疏强敌",
		"loot": "低频高值，饰品与稀有装备", "exclusive": "冻土下的旧物：强化伤害，降低体力恢复",
		"build": "剑气与攻击类藏品更常见（先手与爆发）", "color": Color("9eafb8"), "weights": [0.25, 0.18, 0.42, 0.15]}
}
const ROUTES := [
	{"name": "巡检支路", "detail": "低危险 / 常规掉落 / 敌人较少", "danger": -3.0, "reward": 0.0},
	{"name": "物资作业面", "detail": "中危险 / 更多搜刮 / 更多守卫", "danger": 0.0, "reward": 0.25},
	{"name": "深部污染带", "detail": "高危险 / 稀有率提高 / 精英增援", "danger": 5.0, "reward": 0.5}
]

## The in-run relic pool now lives in RelicCatalog (局内构筑与数值策划案 §10);
## the twelve relics that used to be here are part of it with the same ids.
static func builds() -> Array[Dictionary]:
	return RelicCatalog.all()

static func exclusive(region: String) -> Item:
	var item: Item
	match region:
		"mine":
			item = Item.create("未封装源石原矿", Item.Category.MATERIAL, 1, 2)
			item.effect = "raw_ore"
			item.description = "携带时每秒失去 60 生命；安全袋也不能隔绝污染。材料不可点金。"
			item.value = 100
		"city":
			item = Item.create("近卫局暴动盾", Item.Category.ARMOR, 2, 2, 3.5)
			item.effect = "riot_shield"
			item.description = "装备时减伤 25%，移速降低 20%。"
			item.modifiers = [ItemModifier.stat_mod(ItemModifier.Stat.MOVE_SPEED_PCT, -0.2)]
			item.value = 90
		_:
			item = Item.create("冻土下的旧物", Item.Category.TRINKET, 2, 1, 2.0)
			item.effect = "frozen_relic"
			item.description = "装备时伤害提高 40%，体力恢复降低 40%。"
			item.value = 150
	item.exclusive_region = region
	item.origin_region = region
	item.rarity = 2
	return item

## Better items roll better tiers: weights for Ⅰ/Ⅱ/Ⅲ by rarity.
const TIER_WEIGHTS := [[0.5, 0.4, 0.1], [0.3, 0.5, 0.2], [0.15, 0.45, 0.4]]

static func _roll_tier(rarity: int, rng: RandomNumberGenerator) -> int:
	var roll := rng.randf()
	var weights: Array = TIER_WEIGHTS[clampi(rarity, 0, 2)]
	for i in range(3):
		roll -= float(weights[i])
		if roll <= 0.0: return i
	return 2

static func roll_item(region: String, depth: int, rng: RandomNumberGenerator, reward: float = 0.0) -> Item:
	if rng.randf() < 0.12 + reward * 0.08:
		return exclusive(region)
	if rng.randf() < SpecialGear.drop_chance(reward):
		return SpecialGear.roll(region, depth, rng)
	var roll := rng.randf()
	var category := 3
	var weights: Array = REGIONS[region].weights
	for i in range(4):
		roll -= float(weights[i])
		if roll <= 0:
			category = i
			break
	var names := ["外勤战刃", "防护甲胄", "战术挂饰", "封装矿料"]
	var item := Item.create(names[category], category as Item.Category, 2 if category < 2 else 1, 2 if category == 1 else 1, 1.0 + depth * 0.3 + rng.randf())
	item.origin_region = region
	item.rarity = 2 if rng.randf() < (0.1 + reward * 0.2 + (0.2 if region == "snow" else 0.0)) else (1 if rng.randf() < 0.45 else 0)
	if region == "city" and category == Item.Category.ARMOR:
		item.rarity = maxi(1, item.rarity)
	item.power *= 1.0 + item.rarity * 0.3
	item.value = (10 + depth * 4) * (1 + item.rarity)
	if item.is_equippable():
		var possible: Array = AFFIX_POOLS[category].duplicate()
		var wave_slot := category == Item.Category.WEAPON and item.rarity >= 1 and rng.randf() < SWORD_WAVE_CHANCE
		if wave_slot: item.modifiers.append(ItemModifier.trigger_mod(ItemModifier.Trigger.SWORD_WAVE))
		for i in range(item.rarity - (1 if wave_slot else 0)):
			var index := rng.randi_range(0, possible.size() - 1)
			var stat: int = possible[index]
			possible.remove_at(index)
			var tier := _roll_tier(item.rarity, rng)
			var mod := ItemModifier.stat_mod(stat as ItemModifier.Stat, float(AFFIX_AMOUNTS[stat]) * ItemModifier.TIER_SCALES[tier])
			mod.tier = tier
			item.modifiers.append(mod)
	return item
