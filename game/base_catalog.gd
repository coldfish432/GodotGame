class_name BaseCatalog
extends RefCounted

## Rhodes Island base numbers (基地玩法策划案_v1_0.md, appendix A). Initial
## playtest tuning, like FieldCatalog. Constants for later phases (orders,
## facilities, contamination, pharmacy) are added with those phases.

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

## The warehouse zone of each Item.Category: the five armour slots sit in the
## armour zone, the amulet and ring in the trinket zone (Item.group_of).
const CATEGORY_NAMES := ["武器", "防具", "饰品", "材料", "防具", "防具", "防具", "防具", "防具", "饰品", "饰品"]
const CRATE_SIZES := ["small", "medium", "large"]
const CRATE_SIZE_NAMES := ["小", "中", "大"]

## Crates show only their size: 1 cell small, 2 medium, 3 or more large.
static func crate_size(item: Item) -> int:
	return clampi(item.width * item.height - 1, 0, 2)

# --- Facilities and orders (§2, §3.8) ------------------------------------------

## Rhodes facilities (用户 2026-10-21: 取消声望，原来按声望解锁的都变成基建，
## 升级相应设施解锁). Each upgrade costs 龙门币 and base materials; what a level
## opens is checked with BaseState.facility_level. `start` is the level a new
## save has; `levels[i]` is what level start + i + 1 costs and opens.
## 基建设施修订案 v1.1 (用户 2026-10-22): the 基建总控台 ("hub") is built
## first; each other facility is upgraded at its own site until it is
## connected to the hub (CONNECT_COST), then from the hub too. `gate` is a
## faction relation the facility's building waits for.
const FACILITY_ORDER := ["hub", "warehouse", "outfit", "store", "workshop", "lab", "exchange", "farm", "canteen"]
const FACILITIES := {
	"hub": {"name": "基建总控台", "start": 0, "levels": [
		{"price": 8000, "materials": {"电线": 2, "继电器": 1, "灯泡": 2}, "opens": "基建总控台"},
	]},
	"warehouse": {"name": "仓储部", "start": 1, "levels": [
		{"price": 10000, "materials": {"螺栓": 4, "金属板": 2}, "opens": "搬运无人机 · 前排货架"},
		{"price": 30000, "materials": {"碳": 3, "螺栓": 6, "基础加固建材": 1}, "opens": "中排货架 · 订单栏 +1"},
		{"price": 60000, "materials": {"碳素": 3, "金属板": 4, "进阶加固建材": 1}, "opens": "后排货架 · 每次结算免费刷新 1 张订单"},
	]},
	"outfit": {"name": "整备部", "start": 1, "levels": [
		{"price": 10000, "materials": {"帆布": 2, "胶带": 2}, "opens": "背包扩容 10×8"},
		{"price": 30000, "materials": {"帆布": 3, "密封泡沫": 2}, "opens": "背包扩容 12×8 · 安全袋扩容 3×2"},
		{"price": 60000, "materials": {"碳素组": 1, "电路板": 2}, "opens": "安全袋扩容 3×3"},
	]},
	"store": {"name": "可露希尔商店", "start": 1, "levels": [
		{"price": 10000, "materials": {"家具零件": 2, "电线": 2}, "opens": "热能饮剂 · 急行针剂 · 广谱解毒剂"},
		{"price": 25000, "materials": {"家具零件": 3, "灯泡": 2}, "opens": "抑制喷剂 · 镇静合剂 · 战术兴奋剂 · 精制随队物资"},
		{"price": 50000, "materials": {"电路板": 2, "继电器": 2}, "opens": "源石护盾凝胶 · 静默喷剂"},
		{"price": 90000, "materials": {"全新装置": 1, "电路板": 3}, "opens": "技艺增幅剂 · 应急强心针"},
	]},
	"workshop": {"name": "加工部", "start": 1, "levels": [
		{"price": 40000, "materials": {"微型电机": 1, "装置": 2}, "opens": "加工队列 +1"},
	]},
	"lab": {"name": "科研部", "start": 0, "levels": [
		{"price": 40000, "materials": {"电路板": 2, "继电器": 2}, "opens": "科研部开放"},
		{"price": 150000, "materials": {"微型电机": 2, "改量装置": 2}, "opens": "研究位 +1"},
	]},
	"exchange": {"name": "交易所", "start": 0, "gate": {"faction": "karlan", "rank": 2}, "levels": [
		{"price": 30000, "materials": {"电路板": 2, "继电器": 2}, "opens": "交易所开放 · 贷款额度 20,000"},
		{"price": 15000, "materials": {"电线": 2, "电路板": 1}, "opens": "贷款额度 40,000"},
		{"price": 35000, "materials": {"电路板": 2, "继电器": 1}, "opens": "贷款额度 60,000"},
		{"price": 70000, "materials": {"电路板": 3, "继电器": 2}, "opens": "贷款额度 80,000"},
		{"price": 120000, "materials": {"全新装置": 1, "电路板": 3}, "opens": "贷款额度 100,000"},
	]},
	# 罗德岛第二层 (势力特供策划案_v0_2 §三): two groups of six basins a level, three sun lamps in all.
	"farm": {"name": "农业部", "start": 0, "levels": [
		{"price": 20000, "materials": {"金属板": 3, "软管": 2, "灯泡": 2}, "opens": "农业部开放 · 水培槽 12 个"},
		{"price": 40000, "materials": {"金属板": 4, "软管": 3, "电线": 2}, "opens": "水培槽 24 个"},
		{"price": 70000, "materials": {"金属板": 6, "软管": 4, "灯泡": 3}, "opens": "水培槽 36 个"},
		{"price": 110000, "materials": {"碳素": 3, "软管": 6, "继电器": 1}, "opens": "水培槽 48 个"},
		{"price": 160000, "materials": {"碳素": 4, "软管": 6, "电路板": 2}, "opens": "水培槽 60 个"},
		{"price": 220000, "materials": {"碳素组": 1, "软管": 8, "电路板": 3}, "opens": "水培槽 72 个"},
	]},
	"canteen": {"name": "食堂", "start": 0, "levels": [
		{"price": 20000, "materials": {"家具零件": 3, "金属板": 2, "燃料罐": 1}, "opens": "食堂开放 · 舰内口粮 · 食堂便当"},
		{"price": 50000, "materials": {"家具零件": 4, "电线": 3, "灯泡": 2}, "opens": "闪耀定食"},
		{"price": 90000, "materials": {"全新装置": 1, "家具零件": 4, "继电器": 2}, "opens": "变种盛宴 · 厨房队列 +1"},
	]},
}

## Connecting a facility to the hub; the exchange's link also takes a board.
const CONNECT_COST := {"price": 5000, "materials": {"电线": 2, "继电器": 1}}
const CONNECT_EXTRA := {"exchange": {"电路板": 1}}

static func connect_materials(id: String) -> Dictionary:
	var out: Dictionary = (CONNECT_COST.materials as Dictionary).duplicate()
	for mat in CONNECT_EXTRA.get(id, {}): out[mat] = int(out.get(mat, 0)) + int(CONNECT_EXTRA[id][mat])
	return out

## The facilities that connect to the hub (all but the hub).
static func connectable() -> Array:
	return FACILITY_ORDER.filter(func(id): return id != "hub")

static func facility_name(id: String) -> String:
	return str(FACILITIES[id].name)

static func facility_start(id: String) -> int:
	return int(FACILITIES[id].start)

static func facility_max(id: String) -> int:
	return facility_start(id) + (FACILITIES[id].levels as Array).size()

## The step that takes `id` to `level` ({} past the top or at the start).
static func facility_step(id: String, level: int) -> Dictionary:
	var i := level - facility_start(id) - 1
	var levels: Array = FACILITIES[id].levels
	return levels[i] if i >= 0 and i < levels.size() else {}

## Order board slots: two to start, a third from 仓储部 Lv3.
const ORDER_SLOTS := 2
const ORDER_SLOTS_LEVEL := 3

## Order templates. An item qualifies by `category` (with optional `min_rarity`
## and origin `region`), by a PRTS `material` id, or, for exclusives, by its
## `effect`. `count` counts units: a stack of 5 delivers 5 (掉落物策划案 §7.2).
## Reward (龙门币) is either the delivered items' 交付价 times `mult`, or a fixed `gold`.
## `region` is the region the order points the player to ("" for any).
## Departments are the three already in the project docs (用户 2026-10-02 暂定).
const ORDERS := {
	"starter": {"dept": "工程部", "count": 4, "category": Item.Category.MATERIAL, "mult": 1.3, "weight": 0},
	"eng_materials": {"dept": "工程部", "count": 10, "category": Item.Category.MATERIAL, "mult": 1.3, "weight": 3},
	"eng_mine_materials": {"dept": "工程部", "count": 8, "category": Item.Category.MATERIAL, "region": "mine", "mult": 1.4, "weight": 2},
	"eng_carbon": {"dept": "工程部", "count": 8, "material": "碳", "mult": 1.5, "weight": 2},
	"eng_device": {"dept": "工程部", "count": 3, "material": "装置", "mult": 1.6, "weight": 2},
	"med_sugar": {"dept": "医疗部", "count": 4, "material": "糖", "mult": 1.6, "weight": 2},
	"log_furniture": {"dept": "后勤部", "count": 4, "material": "家具零件", "mult": 1.5, "weight": 2},
	"eng_bolts": {"dept": "工程部", "count": 12, "material": "螺栓", "mult": 1.5, "weight": 2},
	"eng_wires": {"dept": "工程部", "count": 8, "material": "电线", "mult": 1.5, "weight": 2},
	"med_supplies": {"dept": "医疗部", "count": 3, "material": "医用耗材包", "mult": 1.6, "weight": 2},
	"log_fuel": {"dept": "后勤部", "count": 10, "material": "固体燃料", "mult": 1.5, "weight": 2},
	"med_city_armor": {"dept": "医疗部", "count": 1, "category": Item.Category.ARMOR, "region": "city", "mult": 1.4, "weight": 2},
	"log_fine_weapon": {"dept": "后勤部", "count": 1, "category": Item.Category.WEAPON, "min_rarity": 1, "mult": 1.5, "weight": 2},
	"log_trinkets": {"dept": "后勤部", "count": 2, "category": Item.Category.TRINKET, "mult": 1.3, "weight": 2},
	"eng_raw_ore": {"dept": "工程部", "count": 1, "effect": "raw_ore", "region": "mine", "gold": 16000, "weight": 1},
	"log_riot_shield": {"dept": "后勤部", "count": 1, "effect": "riot_shield", "region": "city", "gold": 14000, "weight": 1},
	"med_frozen_relic": {"dept": "医疗部", "count": 1, "effect": "frozen_relic", "region": "snow", "gold": 22000, "weight": 1},
	# 加工部 (势力与交易所策划案 §2.3): what the workshop makes.
	"proc_cube": {"dept": "加工部", "count": 2, "material": "固源岩组", "mult": 1.6, "weight": 2},
	"proc_device": {"dept": "加工部", "count": 2, "material": "全新装置", "mult": 1.6, "weight": 2},
	"proc_iron": {"dept": "加工部", "count": 3, "material": "异铁组", "mult": 1.5, "weight": 1},
	"proc_crate": {"dept": "加工部", "count": 1, "material": "建材包", "mult": 1.5, "weight": 1},
}

static func is_exclusive_order(id: String) -> bool:
	return ORDERS[id].has("effect")

## What an order asks for, in words: "工程部：材料 ×3（切尔诺伯格）".
static func order_text(id: String) -> String:
	var t: Dictionary = ORDERS[id]
	var what := ""
	if t.has("effect"):
		what = {"raw_ore": "未封装源石原矿", "riot_shield": "近卫局暴动盾", "frozen_relic": "冻土下的旧物", "saluzzo_crest": "萨卢佐家族的旧徽记"}[t.effect]
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
const CONTAMINATION_MAX := 100
## Contamination acts live, in the field (局内节奏与目标策划案 §6 D), in steps
## (用户 2026-10-15: 污染改为阶梯式影响，60、90 更加严重): nothing below 60; from
## 60 max HP −15% and self-regeneration halved; from 90 max HP −30%,
## self-regeneration stopped and 0.1% of max HP lost a second (never the last
## point), potions heal 25% less.
## [from, max HP cut, potion penalty, regeneration stopped, regeneration factor, drain (share of max HP a second)]
const CONTAMINATION_TIERS := [
	[0, 0.0, 0.0, false, 1.0, 0.0],
	[60, 0.15, 0.0, false, 0.5, 0.0],
	[90, 0.30, 0.25, true, 0.0, 0.001],
]
const CONTAMINATION_TIER_NAMES := ["无", "中度", "重度"]

const INJURY_HP_PENALTY := 0.25

## Max HP cut from contamination (live) plus injury, capped.
static func hp_penalty(contamination: float, injured: bool) -> float:
	return minf(HP_PENALTY_CAP, contamination_hp_cut(contamination) + (INJURY_HP_PENALTY if injured else 0.0))

static func contamination_hp_cut(value: float) -> float:
	return float(CONTAMINATION_TIERS[contamination_tier(value)][1])

## Potions heal this much less at this contamination.
static func contamination_potion_penalty(value: float) -> float:
	return float(CONTAMINATION_TIERS[contamination_tier(value)][2])

## Self-regeneration is multiplied by this at this contamination.
static func contamination_regen_factor(value: float) -> float:
	return float(CONTAMINATION_TIERS[contamination_tier(value)][4])

## Share of max HP lost a second at this contamination.
static func contamination_drain(value: float) -> float:
	return float(CONTAMINATION_TIERS[contamination_tier(value)][5])
## At tier Ⅰ; × Economy.income_index of the floor she fell on (v1.1 §4.1).
const INJURY_TREATMENT := 3000
const HP_PENALTY_CAP := 0.40              # injury and contamination add up to at most this

## Pharmacy. A is the free standard flask; B and C cost per bottle per contract.
## 复利数值改造清单 E: each kind comes in ten tiers (one a camp), a fixed amount
## × the tier's base, never changed by any bonus (赫拉格's 武者 trait aside);
## the tier is Item.grade and shows in the name.
## line: "pharmacy" (医疗部's 制式 restoratives), "closure" (可露希尔特供,
## 药剂与商人界面策划案 §2) or a faction for the regional ones (§3, sold only at
## its post, `bars` 赤金 each, or bartered). store: the 可露希尔商店 level that
## stocks it. cap: how many she stocks per
## restock window (用户 2026-10-21: 单位时间限量，需要时间补货).
## fx (PotionEffects): hex = {stat: share} for `secs`, then `after` hex for
## `after_secs` (the side effect); meters and specials by key.
const POTIONS := {
	"A": {"name": "标准急救剂", "price": 0, "store": 1, "line": "pharmacy", "text": "立即回复 %d 生命"},
	"B": {"name": "缓释凝胶", "price": 600, "store": 1, "line": "pharmacy", "text": "6 秒内共回复 %d 生命；再用一瓶会覆盖剩余回复"},
	"C": {"name": "抑制喷剂", "price": 1000, "store": 3, "line": "closure", "cap": 5, "text": "回复 %d 生命，污染 −6，之后 30 秒污染累积减半"},
	"D": {"name": "热能饮剂", "price": 900, "store": 2, "line": "closure", "cap": 5, "text": "寒冷 −15，之后 60 秒寒冷累积减半",
		"fx": {"cold": 15.0, "cold_half": 60.0}},
	"E": {"name": "镇静合剂", "price": 1200, "store": 3, "line": "closure", "cap": 5, "text": "血债 −5，60 秒内击杀不增加血债；同 60 秒内移速 −10%",
		"fx": {"debt": 5.0, "debt_block": 60.0, "hex": {"move": -0.10}, "secs": 60.0}},
	"F": {"name": "战术兴奋剂", "price": 1500, "store": 3, "line": "closure", "cap": 3, "text": "20 秒内攻击 +20%、攻速 +10%；结束后 15 秒受到伤害 +15%",
		"fx": {"hex": {"atk": 0.20, "aspd": 0.10}, "secs": 20.0, "after": {"taken": 0.15}, "after_secs": 15.0}},
	"G": {"name": "急行针剂", "price": 1200, "store": 2, "line": "closure", "cap": 3, "text": "20 秒内移速 +25%、体力回复 +60%；结束后 10 秒体力回复 −50%",
		"fx": {"hex": {"move": 0.25, "stamina": 0.60}, "secs": 20.0, "after": {"stamina": -0.50}, "after_secs": 10.0}},
	"H": {"name": "源石护盾凝胶", "price": 1800, "store": 4, "line": "closure", "cap": 2, "text": "获得生命上限 15% 的护盾，持续 20 秒",
		"fx": {"shield": 0.15, "shield_secs": 20.0}},
	"I": {"name": "广谱解毒剂", "price": 800, "store": 2, "line": "closure", "cap": 5, "text": "清除眩晕和减速，之后 10 秒免疫",
		"fx": {"cleanse": 10.0}},
	"J": {"name": "静默喷剂", "price": 1400, "store": 4, "line": "closure", "cap": 2, "text": "45 秒内威胁值累积 −50%、敌人发现距离 −30%；同 45 秒内攻击 −10%",
		"fx": {"quiet": 45.0, "hex": {"atk": -0.10}, "secs": 45.0}},
	"K": {"name": "技艺增幅剂", "price": 1600, "store": 5, "line": "closure", "cap": 2, "text": "被动积攒立刻 +1 格；当前生命 −5%",
		"fx": {"charge": 1, "hp_cost": 0.05}},
	"L": {"name": "应急强心针", "price": 5000, "store": 5, "line": "closure", "cap": 1, "text": "放在背包里即生效：受到致命伤害时保留 1 点生命并回复生命上限的 25%；每份合同 1 次，之后 30 秒生命回复停止",
		"fx": {"auto": true}},
	"rat": {"name": "黑市兴奋剂", "bars": 5, "store": 1, "line": "rat", "text": "20 秒内攻击 +30%、攻速 +15%；结束后 20 秒受到伤害 +25%",
		"fx": {"hex": {"atk": 0.30, "aspd": 0.15}, "secs": 20.0, "after": {"taken": 0.25}, "after_secs": 20.0}},
	"reunion": {"name": "自制抑制剂", "bars": 2, "store": 1, "line": "reunion", "text": "污染 −4；带“脏”标记", "dirty": true,
		"fx": {"contamination": 4.0}},
	"ursus": {"name": "矿工烈酒", "bars": 3, "store": 1, "line": "ursus", "text": "寒冷 −10，30 秒内攻击 +10%；同 30 秒内移速 −10%",
		"fx": {"cold": 10.0, "hex": {"atk": 0.10, "move": -0.10}, "secs": 30.0}},
	"sami": {"name": "林地草药茶", "barter": {"林地草药": 2}, "store": 1, "line": "sami", "text": "60 秒内寒冷累积减半，每秒回复生命上限的 0.3%",
		"fx": {"cold_half": 60.0, "regen_share": 0.003, "regen_secs": 60.0}},
}
const CLOSURE_LINE := ["C", "D", "E", "F", "G", "H", "I", "J", "K", "L"]
const REGIONAL := {"rat": "rat", "reunion": "reunion", "ursus": "ursus", "sami": "sami"}   # faction -> type
const RESTOCK_SECONDS := 3600
## How many of her line a camp counter carries (A and B there always).
const CAMP_SPECIALS := 3
## Flasks are pack items (药剂进背包): three 标准急救剂 are issued free for every
## contract and go into the pack at departure; more are bought at the pharmacy
## (or from 可露希尔). One kind stacks in a cell up to POTION_STACK (用户 2026-10-17).
const FREE_POTIONS := 3
const POTION_STACK := 5
## 随身药包 (科研树状化策划案 §4.2): one more flask a cell (Research.apply_globals).
static var potion_stack_bonus := 0
const POTION_A_PRICE := 300
## The old "flask capacity" stat (relics, affixes) now changes flask healing:
## each point is ±20%.
const POTION_HEAL_PER_CAP := 0.2

static func create_potion(type: String, tier: int = 1) -> Item:
	var p: Dictionary = POTIONS[type]
	var t := clampi(tier, 1, Scaling.TIER_MAX)
	var item := Item.create(potion_name(type, t), Item.Category.MATERIAL, 1, 1)
	item.potion_type = type
	item.grade = t
	item.description = (str(p.text) % roundi(potion_heal(type, t))) if str(p.text).contains("%d") else str(p.text)
	var lmd := POTION_A_PRICE if type == "A" else int(p.get("price", int(p.get("bars", 2)) * 1000))
	item.unit_value = lmd / Economy.LMD_PER_VALUE
	# 整合运动's home-made batch carries the 脏 mark (势力与交易所策划案 §12).
	if p.get("dirty", false): item.effect = "dirty"
	item.max_stack = POTION_STACK + potion_stack_bonus
	item.set_quantity(1)
	return item
## "标准急救剂 · Ⅲ"; a flask that does not heal has no tier in its name.
static func potion_name(type: String, tier: int) -> String:
	if potion_heal(type, 1) <= 0.0: return str(POTIONS[type].name)
	return "%s · %s" % [str(POTIONS[type].name), Progression.GRADE_MARKS[clampi(tier, 1, Scaling.TIER_MAX)]]

## What one flask of `type` and `tier` heals (清单 E): tier Ⅰ × the tier's base.
## The new 特供 and regional ones heal nothing (药剂与商人界面策划案 §2).
static func potion_heal(type: String, tier: int) -> float:
	var base: float = {"A": POTION_A_HEAL, "B": POTION_B_HEAL, "C": POTION_C_HEAL}.get(type, 0.0)
	return base * Scaling.tier_base(tier)

## Tier Ⅰ amounts (局内构筑与数值策划案 §5.5: once 40% / 70% / 20% of 2400; about
## 30% / 50% / 15% of a floor-1 Doctor in matching gear now).
const POTION_A_HEAL := 960.0
const POTION_B_HEAL := 1680.0
const POTION_B_SECONDS := 6.0
const POTION_C_HEAL := 480.0
const POTION_C_CLEANSE := 6.0
const POTION_C_SUPPRESS_SECONDS := 30.0

## 医疗部Ⅵ moves the steps up by this (60/90 → 70/100; Research.apply_globals).
static var contamination_shift := 0.0

static func contamination_tier(value: float) -> int:
	var tier := 0
	for i in range(CONTAMINATION_TIERS.size()):
		if value >= float(CONTAMINATION_TIERS[i][0]) + (contamination_shift if i > 0 else 0.0): tier = i
	return tier

# --- Facility unlocks, expansion, the drone (§2.2, §3.5, §3.6) -----------------

## Price and 仓储部 level needed for each rack slot in build order (slot 0 is there from
## the start): front row 2nd and 3rd, then the middle row, then the back row.
## 龙门币平衡与科研部策划案 v1.1 §4.2: about 1.9× the first prices.
const RACK_PRICES := [0, 8000, 12000, 25000, 25000, 25000, 45000, 45000, 45000]
const RACK_LEVELS := [1, 2, 2, 3, 3, 3, 4, 4, 4]
## Pack and safe-bag expansions (装备与背包界面调研 §5.11, after Grim Dawn's
## extra bags and Tarkov's secure containers). Level 0 is what she starts with;
## each level needs 整备部 at the level beside it.
const PACK_SIZES := [Vector2i(10, 6), Vector2i(10, 8), Vector2i(12, 8)]
const PACK_PRICES := [0, 15000, 40000]
const PACK_LEVELS := [1, 2, 3]
const SAFE_SIZES := [Vector2i(2, 2), Vector2i(3, 2), Vector2i(3, 3)]
const SAFE_PRICES := [0, 20000, 50000]
const SAFE_LEVELS := [1, 3, 4]
## The warehouse master console (用户 2026-10-07): until it is bought the 仓管台
## only sells upgrades, and the shelves are reached zone by zone at their floor
## frames. Bought in any order with the drone.
const CONSOLE_PRICE := 10000
const CONSOLE_MATERIALS := {"电源线": 2, "继电器": 1, "灯泡": 2}
const DRONE_PRICE := 20000
const DRONE_LEVEL := 2            # 仓储部
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
const CAMP_UPGRADE_PRICE := 60000
const CAMP_UPGRADE_MATERIALS := {"碳素": 3, "金属板": 4, "继电器": 1}
const DRONE_MATERIALS := {"微型电机": 1, "电路板": 2, "蓄电池": 2, "家具零件": 2}

## "碳×4 + 基础加固建材×1".
static func cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for id in cost: parts.append("%s×%d" % [id, int(cost[id])])
	return " + ".join(parts)
const REROLL_LEVEL := 4           # 仓储部: one free order reroll after every settlement
## Staging warns at departure and its marker turns yellow from this share full.
const STAGING_WARNING := 0.9
