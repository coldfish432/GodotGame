class_name FieldCatalog
extends RefCounted

## All numbers here are initial playtest tuning, not additional hard design rules.
const SWORD_WAVE_CHANCE := 0.25 # provisional; rolled once per eligible weapon
const ATTACK_SPEED_AFFIX := 0.10 # provisional; weapon and trinket loot only
## Camps (撤离与营地修订案 §1): after every ten floors, a squad camp with the
## fixed extraction and 可露希尔.
const CAMP_INTERVAL := 10
## The outpost (局内节奏与目标策划案 §6 B2): the last floor of every block, the
## one before the camp (the camp is the in-between level, 用户 2026-10-09), is
## held by a squad whose leader must fall before the floor's route markers open.
const OUTPOST_PLACE := 10
const OUTPOST_BOSS_HP := 3.0
const OUTPOST_BOSS_ATK := 1.2
const OUTPOST_GUARDS := 2

## Contract objectives (局内节奏与目标策划案 §6 B1): three offers per region at
## the dispatch desk, refreshed after every settlement; one is chosen before
## leaving. The bonus is paid only on extraction with the objective done.
const CONTRACT_OFFERS := 3
const CONTRACT_TYPES := ["deep", "recover", "hunt", "search"]
const CONTRACT_NAMES := {"deep": "深入", "recover": "回收", "hunt": "猎杀", "search": "搜索", "recruit": "寻访", "deliver": "运送"}
const DEEP_STEPS := [4, 6, 9]          # floors past the start: LG-05 / 07 / 10 from LG-01
const DEEP_BONUS := 0.5                # of the contract pay
## Common drops of each region's own enemies, so the target always exists there.
const RECOVER_TARGETS := {
	"mine": [["源岩", 6], ["破损装置", 4], ["异铁碎片", 4]],
	"city": [["代糖", 4], ["糖", 2], ["异铁", 3]],
	"snow": [["双酮", 4], ["异铁碎片", 4]],
	"siracusa": [["代糖", 4], ["异铁碎片", 4]],
}
const RECOVER_REWARD := {"money": 6000}
const HUNT_OFFSETS := Vector2i(3, 6)   # the bounty's floor, past the start
const HUNT_HP := 2.5
## 密室 are found on about one floor in five now (密室与陷阱修订案 §2.1): one is enough.
const SEARCH_VAULTS := 1
const SEARCH_REWARD := {"money": 5000}

## Three offers of different kinds for `region`.
static func roll_contracts(region: String, rng: RandomNumberGenerator) -> Array:
	var kinds: Array = CONTRACT_TYPES.duplicate()
	var out := []
	for i in range(CONTRACT_OFFERS):
		var kind: String = kinds.pop_at(rng.randi() % kinds.size())
		match kind:
			"deep": out.append({"type": kind, "steps": DEEP_STEPS[rng.randi() % DEEP_STEPS.size()]})
			"recover":
				var pick: Array = RECOVER_TARGETS[region][rng.randi() % RECOVER_TARGETS[region].size()]
				out.append({"type": kind, "material": pick[0], "count": pick[1]})
			"hunt": out.append({"type": kind, "offset": rng.randi_range(HUNT_OFFSETS.x, HUNT_OFFSETS.y)})
			"search": out.append({"type": kind, "vaults": SEARCH_VAULTS})
	return out

## What the objective asks, with floors counted from `start_floor`.
static func contract_goal(contract: Dictionary, region: String, start_floor: int) -> String:
	match str(contract.get("type", "")):
		"deep": return "抵达 %s 后撤离" % AK.floor_code(region, start_floor + int(contract.steps))
		"recover": return "带回 %s ×%d" % [contract.material, int(contract.count)]
		"hunt": return "击破悬赏目标 · %s" % AK.floor_code(region, start_floor + int(contract.offset))
		"search": return "开启密室 ×%d" % int(contract.vaults)
		"recruit": return "寻访 %s · %s" % [Operators.display_name(str(contract.operator)), AK.floor_code(region, start_floor + int(contract.offset))]
		"deliver": return "运送 %s · %s" % [FactionCatalog.name_of(str(contract.faction)), AK.floor_code(region, int(contract.floor))]
	return ""

## What finishing it pays, as shown on the card.
static func contract_bonus_text(contract: Dictionary) -> String:
	match str(contract.get("type", "")):
		"deep": return "合同报酬 +%d%%" % roundi(DEEP_BONUS * 100)
		"recover": return "%s 龙门币" % Economy.format(RECOVER_REWARD.money)
		"hunt": return "稀有装备 ×1"
		"search": return "%s 龙门币" % Economy.format(SEARCH_REWARD.money)
		"recruit": return "%s 入职" % Operators.display_name(str(contract.operator))
		"deliver": return "%s · 关系 +%d" % [Exchange.format_money(str(contract.currency), float(contract.pay)), int(contract.relation)]
	return ""
## Random extraction (§2): at most one in each block of ten, on floor 4, 5 or 6,
## 50% in all. Rolled floor by floor with these conditional odds, so each of the
## three floors carries exactly 1/6.
const RANDOM_EXTRACTION_ODDS := {4: 1.0 / 6.0, 5: 1.0 / 5.0, 6: 1.0 / 4.0}
## The random extraction is a green zone (用户 2026-10-14): standing in it runs
## the extraction; hits do not stop it, only stepping out does.
const EXTRACT_RADIUS := 2.2
const EXTRACT_SECONDS := 6.0
## Time a camp visit counts for contamination until the camp is upgraded (§3).
const CAMP_EXPOSURE_SECONDS := 30.0
## 可露希尔's 寄存 fee: this share of the 交付价, in 赤金, rounded up, at least one.
const DEPOSIT_FEE := 0.2
## Hidden difficulty (§4): this much per floor below the first, plus the route.
const DIFFICULTY_PER_FLOOR := 3.5
## Affix sizes by stat (局内构筑与数值策划案 §7.2). Weapons lean offensive,
## armour defensive, trinkets toward arts and tempo.
const AFFIX_AMOUNTS := {
	ItemModifier.Stat.MAX_HP_PCT: 0.08, ItemModifier.Stat.MOVE_SPEED_PCT: 0.08,
	ItemModifier.Stat.ATTACK_SPEED_PCT: 0.10, ItemModifier.Stat.ATK_PCT: 0.08,
	ItemModifier.Stat.ARTS_PCT: 0.10, ItemModifier.Stat.DEF_FLAT: 40.0,
	ItemModifier.Stat.RES_FLAT: 8.0, ItemModifier.Stat.CRIT_RATE: 0.05, ItemModifier.Stat.CRIT_DMG: 0.20,
	# Flat affixes at tier Ⅰ, a blue's middle (复利数值改造清单 C): about 12% of a
	# floor-1 Doctor's ATK / arts / HP; DEF 40 about 16%. ×1.30 a tier.
	ItemModifier.Stat.ATK_FLAT: 95.0, ItemModifier.Stat.ARTS_FLAT: 95.0, ItemModifier.Stat.HP_FLAT: 390.0,
	# Slot leanings (装备部位拆分与数值案 §4); their slots' own sizes are in
	# SLOT_AFFIX_AMOUNTS. Lower is better for the two negatives.
	ItemModifier.Stat.EVASION: 0.08, ItemModifier.Stat.SKILL_CD_PCT: -0.15, ItemModifier.Stat.SKILL_PCT: 0.25,
	ItemModifier.Stat.STAMINA_REGEN_PCT: 0.30, ItemModifier.Stat.DASH_COST_PCT: -0.25,
}
## Each slot leans toward its own stats (装备部位拆分与数值案 §4). ARMOR and
## TRINKET are the old pools, kept for old saves' rerolls.
const AFFIX_POOLS := {
	Item.Category.WEAPON: [ItemModifier.Stat.ATK_PCT, ItemModifier.Stat.ATK_FLAT, ItemModifier.Stat.ARTS_FLAT, ItemModifier.Stat.ATTACK_SPEED_PCT,
		ItemModifier.Stat.CRIT_RATE, ItemModifier.Stat.CRIT_DMG],
	Item.Category.CHEST: [ItemModifier.Stat.MAX_HP_PCT, ItemModifier.Stat.HP_FLAT, ItemModifier.Stat.DEF_FLAT, ItemModifier.Stat.RES_FLAT],
	Item.Category.LEGS: [ItemModifier.Stat.MAX_HP_PCT, ItemModifier.Stat.DEF_FLAT, ItemModifier.Stat.EVASION],
	Item.Category.HEAD: [ItemModifier.Stat.RES_FLAT, ItemModifier.Stat.ARTS_PCT, ItemModifier.Stat.SKILL_CD_PCT],
	Item.Category.HANDS: [ItemModifier.Stat.ATTACK_SPEED_PCT, ItemModifier.Stat.CRIT_RATE, ItemModifier.Stat.ATK_PCT],
	Item.Category.FEET: [ItemModifier.Stat.MOVE_SPEED_PCT, ItemModifier.Stat.STAMINA_REGEN_PCT, ItemModifier.Stat.DASH_COST_PCT,
		ItemModifier.Stat.DEF_FLAT, ItemModifier.Stat.HP_FLAT],
	Item.Category.AMULET: [ItemModifier.Stat.SKILL_PCT, ItemModifier.Stat.ARTS_PCT, ItemModifier.Stat.ATK_PCT, ItemModifier.Stat.HP_FLAT],
	Item.Category.RING: [ItemModifier.Stat.ATK_FLAT, ItemModifier.Stat.ARTS_FLAT, ItemModifier.Stat.CRIT_RATE, ItemModifier.Stat.CRIT_DMG],
	Item.Category.ARMOR: [ItemModifier.Stat.MAX_HP_PCT, ItemModifier.Stat.DEF_FLAT, ItemModifier.Stat.RES_FLAT, ItemModifier.Stat.MOVE_SPEED_PCT,
		ItemModifier.Stat.HP_FLAT],
	Item.Category.TRINKET: [ItemModifier.Stat.ARTS_PCT, ItemModifier.Stat.ATTACK_SPEED_PCT, ItemModifier.Stat.CRIT_DMG, ItemModifier.Stat.MAX_HP_PCT, ItemModifier.Stat.RES_FLAT,
		ItemModifier.Stat.ATK_PCT, ItemModifier.Stat.ATK_FLAT, ItemModifier.Stat.ARTS_FLAT, ItemModifier.Stat.HP_FLAT],
}

## Each slot's own affix sizes, as players see them (部位词条数值表 v1.0, 用户
## 2026-10-21: no slot multiplier): a blue's middle at tier Ⅰ. Combat stats
## keep a full set's sum (the seven non-weapon slots 2.00 full affixes); a
## slot's own stat (legs' dodge, head's cooldown, amulet's skill damage) is
## larger than the shared ones; feet's movement, stamina and dodge cost are
## sized by feel. The weapon, and old ARMOR / TRINKET, use AFFIX_AMOUNTS.
const SLOT_AFFIX_AMOUNTS := {
	Item.Category.CHEST: {ItemModifier.Stat.MAX_HP_PCT: 0.032, ItemModifier.Stat.HP_FLAT: 156.0, ItemModifier.Stat.DEF_FLAT: 16.0, ItemModifier.Stat.RES_FLAT: 2.2},
	Item.Category.AMULET: {ItemModifier.Stat.SKILL_PCT: 0.11, ItemModifier.Stat.ARTS_PCT: 0.027, ItemModifier.Stat.ATK_PCT: 0.022, ItemModifier.Stat.HP_FLAT: 129.0},
	Item.Category.LEGS: {ItemModifier.Stat.MAX_HP_PCT: 0.021, ItemModifier.Stat.DEF_FLAT: 10.0, ItemModifier.Stat.EVASION: 0.03},
	Item.Category.HEAD: {ItemModifier.Stat.RES_FLAT: 1.8, ItemModifier.Stat.ARTS_PCT: 0.021, ItemModifier.Stat.SKILL_CD_PCT: -0.051},
	Item.Category.HANDS: {ItemModifier.Stat.ATTACK_SPEED_PCT: 0.026, ItemModifier.Stat.CRIT_RATE: 0.013, ItemModifier.Stat.ATK_PCT: 0.021},
	Item.Category.RING: {ItemModifier.Stat.ATK_FLAT: 25.0, ItemModifier.Stat.ARTS_FLAT: 25.0, ItemModifier.Stat.CRIT_RATE: 0.013, ItemModifier.Stat.CRIT_DMG: 0.052},
	Item.Category.FEET: {ItemModifier.Stat.DEF_FLAT: 9.0, ItemModifier.Stat.HP_FLAT: 86.0,
		ItemModifier.Stat.MOVE_SPEED_PCT: 0.06, ItemModifier.Stat.STAMINA_REGEN_PCT: 0.25, ItemModifier.Stat.DASH_COST_PCT: -0.20},
}

## `stat`'s size on `slot` as a share of AFFIX_AMOUNTS (an affix keeps it in
## its scale, so its range and rerolls follow); the old slot share for a
## stat a slot's table leaves out.
static func slot_ratio(stat: int, slot: int) -> float:
	var table: Dictionary = SLOT_AFFIX_AMOUNTS.get(slot, {})
	if not table.has(stat): return GearSlots.affix(slot)
	return float(table[stat]) / float(AFFIX_AMOUNTS[stat])

## Per-depth authoring, in the manner of 贪婪洞窟's level_N.plist, where every
## floor is its own record rather than a point on a curve. Before this, depth
## only scaled numbers smoothly, so no segment could be written to feel like
## anything in particular. See 贪婪洞窟地图设计调研.md §3.1.
##
## Depth is unbounded and that game's table is not, so entries repeat on a
## cycle. The cycle is the camp interval on purpose: the floor before every
## camp lands on the same authored entry, and so does the random-extraction
## window (floors 4–6 of each block).
## Loot no longer cycles with it: LootTables.stair only climbs (掉落阶梯, 2026-10-18).
const DEPTH_CYCLE := 10
const DEPTH_PROFILE := {
	1: {"enemies": 0, "elites": 0, "note": "开局层，照地区基准"},
	2: {"enemies": 1, "elites": 0, "note": ""},
	3: {"enemies": 1, "elites": 0, "note": ""},
	4: {"enemies": 1, "elites": 1, "note": "随机撤离区间"},
	5: {"enemies": 2, "elites": 0, "note": "随机撤离区间"},
	6: {"enemies": 2, "elites": 1, "note": "随机撤离区间"},
	7: {"enemies": 2, "elites": 1, "note": ""},
	8: {"enemies": 3, "elites": 1, "note": ""},
	9: {"enemies": 3, "elites": 1, "note": ""},
	10: {"enemies": 3, "elites": 2, "note": "营地前一层，压力与回报同时抬高"},
}

static func depth_profile(depth: int) -> Dictionary:
	return DEPTH_PROFILE[((maxi(depth, 1) - 1) % DEPTH_CYCLE) + 1]
## Insurance always brings back insured gear that did not come out of a contract
## (a death, or dropped on a floor) 2–4 real hours later (用户 2026-10-15: 从合同
## 计数改为时钟计时); that return uses it up, while carrying it out keeps it. At
## the base it costs the item's 交付价 in 龙门币.
const INSURANCE_DELAY_SECONDS := Vector2i(2 * 3600, 4 * 3600)
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
## 坎诺特's chance per stock roll of one enemy exclusive (装备扩充策划案 §1.1).
const TRADER_EXCLUSIVE_CHANCE := 0.10
const TRADER_RELIC_PRICES := [8, 12, 16]
const TRADER_GEAR_MARKUP := 1.5
const TRADER_POTION_PRICES := {"A": 4, "B": 6, "C": 10}
## 坎诺特 also carries the 特供 and regional flasks (not the 强心针).
const TRADER_POTION_POOL := ["C", "D", "E", "F", "G", "H", "I", "J", "K", "rat", "reunion", "ursus", "sami"]

## His 赤金 price: the old three as set, the rest about 1 bar per 100 龙门币 of
## the pharmacy price, a regional one twice its post price.
static func trader_potion_price(type: String) -> int:
	if TRADER_POTION_PRICES.has(type): return int(TRADER_POTION_PRICES[type])
	var p: Dictionary = BaseCatalog.POTIONS[type]
	if p.has("bars"): return int(p.bars) * 2
	if p.has("barter"): return 6
	return maxi(4, roundi(int(p.get("price", 1000)) / 100.0))
const TRADER_BUYBACK := 0.5
const TRADER_REROLL_BASE := 3
const TRADER_REROLL_STEP := 3
const SOURCE := "https://prts.wiki/w/萨卡兹的无终奇语/想象实体图鉴"
const REGIONS := {
	"mine": {"name": "切尔诺伯格 · 坍塌矿区", "brief": "回收矿料，测绘污染。狭窄矿道 / 密集追击",
		"loot": "材料多，装备少", "exclusive": "未封装源石原矿：高价值，但携带时污染上涨",
		"build": "防御与生命类藏品更常见（承伤与持续作战）", "color": Color("514b3b"), "weights": [0.12, 0.12, 0.11, 0.65]},
	# 改造案 v1.1 §1.1 (用户 2026-10-21): 龙门城区, each floor 上城 or 下城 (place_name).
	"city": {"name": "龙门城区", "brief": "回收防务与医疗物资。曲折街区 / 近战伏击",
		"loot": "防具多，制式装备品质较高", "exclusive": "近卫局暴动盾：更能承伤，但降低移速",
		"build": "攻击、防御与攻速类藏品更常见（近战与格挡）", "color": Color("354656"), "weights": [0.18, 0.56, 0.14, 0.12]},
	"snow": {"name": "萨米 · 冻土林线", "brief": "采集极寒样本，回收冻土旧物。开阔林线 / 稀疏强敌",
		"loot": "低频高值，饰品与稀有装备", "exclusive": "冻土下的旧物：强化伤害，降低体力恢复",
		"build": "技能与攻击类藏品更常见（先手与爆发）", "color": Color("9eafb8"), "weights": [0.25, 0.18, 0.42, 0.15]},
	# 叙拉古地图调研与方案_v1.md (用户 2026-10-16: 沃尔西尼旧城区).
	"siracusa": {"name": "叙拉古 · 沃尔西尼旧城区", "brief": "回收家族火并后的遗留物。弯巷内院 / 埋伏精英",
		"loot": "饰品与遗物最多，材料少", "exclusive": "萨卢佐家族的旧徽记：伤害提高，但精英更早盯上你",
		"build": "高风险高回报的藏品更常见", "color": Color("8a4a3a"), "weights": [0.16, 0.14, 0.52, 0.18]}
}
## 龙门城区's two looks (ContinuousWorldMap.city_variant).
const CITY_VARIANT_NAMES := {"upper": "上城", "lower": "下城"}

## The region's name for a floor, with the upper or lower city in Lungmen.
static func place_name(region: String, city_variant: String = "") -> String:
	var name: String = REGIONS[region].name
	return name + " · " + CITY_VARIANT_NAMES[city_variant] if region == "city" and CITY_VARIANT_NAMES.has(city_variant) else name

## Regions laid out as a town (flush streets, buildings on every block):
## Lungmen and Siracusa. The rest are dug ground.
const URBAN := ["city", "siracusa"]

static func urban(region: String) -> bool:
	return region in URBAN

## The region whose art a region borrows until its own exists (叙拉古 S2: the
## models, textures and enemy sheets are Lungmen's placeholders).
static func art_region(region: String) -> String:
	return "city" if region == "siracusa" else region

## The regions whose gear tables a region draws from. Siracusa has its own
## weapons (装备策划案 §11); its armour and trinkets are still goods from
## everywhere, left in a family quarter emptied by a feud.
static func gear_regions(region: String, category: int = -1) -> Array:
	if region != "siracusa": return [region]
	return ["siracusa"] if category == Item.Category.WEAPON else ["mine", "city", "snow"]
const ROUTES := [
	{"name": "巡检支路", "detail": "低危险 / 常规掉落 / 敌人较少", "danger": -3.0, "reward": 0.0},
	{"name": "物资作业面", "detail": "中危险 / 更多搜刮 / 更多守卫", "danger": 0.0, "reward": 0.25},
	{"name": "深部污染带", "detail": "高危险 / 稀有率提高 / 精英增援", "danger": 5.0, "reward": 0.5}
]

## The in-run relic pool now lives in RelicCatalog (局内构筑与数值策划案 §10);
## the twelve relics that used to be here are part of it with the same ids.
static func builds() -> Array[Dictionary]:
	return RelicCatalog.all()

## `depth` sets the gear's tier (复利数值改造清单 D): the written power is its
## tier-Ⅰ size, multiplied by the tier's base.
static func exclusive(region: String, depth: int = 1) -> Item:
	var item: Item
	match region:
		"mine":
			item = Item.create("未封装源石原矿", Item.Category.MATERIAL, 1, 2)
			item.effect = "raw_ore"
			item.description = "携带时每块每秒污染 +0.06；安全袋也不能隔绝污染。"
			item.value = 100
		"city":
			item = Item.create("近卫局暴动盾", Item.Category.CHEST, 2, 2, 3.5)
			item.effect = "riot_shield"
			item.description = "装备时减伤 25%，移速降低 20%。"
			item.modifiers = [ItemModifier.stat_mod(ItemModifier.Stat.MOVE_SPEED_PCT, -0.2)]
			item.value = 90
		"siracusa":
			item = Item.create("萨卢佐家族的旧徽记", Item.Category.AMULET, 1, 1, 2.0)
			item.effect = "saluzzo_crest"
			item.description = "装备时伤害提高 30%，精英发现你的距离提高 50%。"
			item.value = 150
		_:
			item = Item.create("冻土下的旧物", Item.Category.AMULET, 2, 1, 2.0)
			item.effect = "frozen_relic"
			item.description = "装备时伤害提高 40%，体力恢复降低 40%。"
			item.value = 150
	item.exclusive_region = region
	item.origin_region = region
	item.rarity = 2
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if item.is_equippable():
		item.grade = Scaling.tier_of(depth)
		item.power *= Scaling.tier_base(item.grade)
		if Item.is_jewel_slot(item.category): item.atk_share = Item.roll_atk_share(rng)
	PrefixCatalog.roll_onto(item, region, depth, rng)
	return item

static func roll_item(region: String, depth: int, rng: RandomNumberGenerator, reward: float = 0.0) -> Item:
	if rng.randf() < 0.12 + reward * 0.08:
		return exclusive(region, depth)
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
	if category == 3:
		var ore := Item.create("封装矿料", Item.Category.MATERIAL, 1, 1)
		ore.origin_region = region
		ore.value = 10 + depth * 4
		return ore
	# Equipment rolls the way drops do (复利数值改造清单 B): its tier, its
	# rarity's band, its affixes and prefixes.
	var rarity := 2 if rng.randf() < (0.1 + reward * 0.2 + (0.2 if region == "snow" else 0.0)) else (1 if rng.randf() < 0.45 else 0)
	if region == "city" and category == Item.Category.ARMOR: rarity = maxi(1, rarity)
	# The old armour / trinket roll picks one of its slots (装备部位拆分与数值案 §6).
	if category == Item.Category.ARMOR or category == Item.Category.TRINKET: category = GearSlots.roll(rng, category)
	var id := GearCatalog.pick(category, region, depth, "box", "", rng)
	var item := LootTables.roll_equipment(category, GearCatalog.BASES[id].name, region, depth, rarity, rng)
	return item
