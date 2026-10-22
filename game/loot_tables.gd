class_name LootTables
extends RefCounted

## Where things drop from and what drops (掉落物策划案 §3–§5). Layered like
## Diablo II's treasure classes: a source table decides how many picks and
## which kind each pick is; a kind table decides the exact item; equipment
## rolls its quality last. Drops come back as an Array of {"item": Item} or
## {"gold": int}; the caller puts them on the ground.
##
## ctx: {"region", "depth", "reward" (route reward), "rng", "pity" (Dictionary,
## the cross-contract bad-luck counters kept in BaseState)}.

# --- Enemy-specific materials (§2.2): [id, min, max] -------------------------
const ENEMY_MATERIALS := {
	"thug": {"common": [["破损装置", 1, 2], ["代糖", 1, 2]], "uncommon": [["装置", 1, 1]], "rare": [["全新装置", 1, 1]]},
	"crossbow": {"common": [["异铁碎片", 1, 2], ["破损装置", 1, 1]], "uncommon": [["异铁", 1, 1]], "rare": [["研磨石", 1, 1]]},
	"crossbow_leader": {"common": [["异铁", 1, 2]], "uncommon": [["装置", 1, 1], ["异铁组", 1, 1]], "rare": [["研磨石", 1, 1], ["化合切削液", 1, 1]]},
	"slug": {"common": [["源岩", 1, 3]], "uncommon": [["固源岩", 1, 1]], "rare": [["晶体元件", 1, 1]]},
	"brawler": {"common": [["代糖", 1, 2], ["糖", 1, 1]], "uncommon": [["酯原料", 1, 2], ["聚酸酯", 1, 1]], "rare": [["扭转醇", 1, 1]]},
	"ice_warrior": {"common": [["双酮", 1, 2]], "uncommon": [["酮凝集", 1, 1], ["轻锰矿", 1, 1]], "rare": [["褐素纤维", 1, 1]]},
	"ice_hunter": {"common": [["异铁碎片", 1, 2]], "uncommon": [["研磨石", 1, 1]], "rare": [["凝胶", 1, 1], ["轻锰矿", 1, 1]]},
	"elite": {"common": [["固源岩组", 1, 1]], "uncommon": [["轻锰矿", 1, 1], ["全新装置", 1, 1]], "rare": [["改量装置", 1, 1], ["提纯源岩", 1, 1]],
		"guaranteed": ["固源岩组", 1, 1], "ultra": ["D32钢", 0.01]},
}
const MATERIAL_TIER_WEIGHTS := {"common": 85.0, "uncommon": 12.0, "rare": 3.0}
const RARE_MATERIAL_PITY_STEP := 0.005
const RARE_MATERIAL_PITY_CAP := 0.15

# --- Source tables (§3.1): weights for [nothing, material, gold, equipment] ---
## 用户 2026-10-14: 敌人掉落普通装备概率增加 — the gear share doubled for normal
## enemies (8% → 16%), raised for guards and elites, from material and gold.
## 用户 2026-10-17: 爆率太高、3 层背包就满 — about 1.5× the enemies, so a normal
## one drops something 37% of the time (was 88%), a guard 62% (was 100%), an
## elite rolls twice (was three times): roughly 60% of the old loot per floor.
const ENEMY_SOURCE := {
	"normal": {"picks": 1, "weights": [150.0, 54.0, 18.0, 16.0]},
	"guard": {"picks": 1, "weights": [60.0, 58.0, 20.0, 22.0]},
	"elite": {"picks": 2, "weights": [15.0, 47.0, 18.0, 35.0]},
}
## 用户 2026-10-14: 敌人概率掉落治疗球立即回复血量，小概率掉治疗药水. Per source:
## the chance of healing orbs (HealOrb), how many, and what each gives back; and the chance of a 标准急救剂 in the drop.
## 用户 2026-10-17: 治疗球让压力降得太多 — with 1.5× the enemies, about 3/4 of
## the old orbs per floor (elites half), and about as many flasks as before.
## 复利数值改造清单 E: each orb heals a fixed amount × the floor's 档位系数 (the
## old shares of a 2400 life), no longer a share of her life.
const HEAL_ORBS := {
	"normal": {"chance": 0.12, "count": 1, "heal": 240.0},
	"guard": {"chance": 0.18, "count": 1, "heal": 290.0},
	"elite": {"chance": 0.5, "count": 1, "heal": 360.0},
}
const POTION_DROP := {"normal": 0.02, "guard": 0.035, "elite": 0.1}

static func source_of(elite: bool, guard: bool) -> String:
	return "elite" if elite else ("guard" if guard else "normal")
## Equipment category weights for enemy drops: weapon / armour / trinket.
## Which slot an enemy's gear is: GearSlots.DROP_WEIGHTS (装备部位拆分与数值案 §6);
## the old weapon : armour : trinket = 6 : 1 : 1 is gone with the three slots.
const ENEMY_GOLD := {"normal": [8, 14], "guard": [8, 14], "elite": [25, 40]}

# --- Equipment quality (§3.2, §4.1): common / fine / rare weights ------------
const QUALITY := {
	"normal": [70.0, 25.0, 5.0], "guard": [60.0, 32.0, 8.0], "elite": [25.0, 50.0, 25.0],
	"box": [50.0, 38.0, 12.0], "vault": [0.0, 45.0, 55.0],
}
const RARE_GEAR_PITY_STEP := 0.015
const RARE_GEAR_PITY_CAP := 0.30


# --- Points of interest (§4.1) -----------------------------------------------
const POI := {
	"construction": {"name": "建材堆", "color": Color("8a7a5c"), "region": {"mine": 2.0, "city": 1.0, "snow": 1.0, "siracusa": 0.5}, "base": true},
	"ore_vein": {"name": "源石矿脉", "color": Color("d07a2a"), "region": {"mine": 3.0}, "base": true},
	"depot": {"name": "物资仓", "color": Color("6c7f8f"), "region": {"city": 3.0}, "base": true},
	"safe": {"name": "保险柜", "color": Color("b59a3a"), "region": {"mine": 0.5, "city": 1.5, "siracusa": 2.0}, "base": true},
	"camp": {"name": "冰原营地", "color": Color("9fb6c2"), "region": {"snow": 3.0}, "base": true},
	"weapon_box": {"name": "武器箱", "color": Color("8c5a4a"), "region": {"mine": 1.0, "city": 2.0, "snow": 1.5, "siracusa": 1.0}, "base": false},
	"armor_box": {"name": "护具箱", "color": Color("4f6f8f"), "region": {"mine": 1.0, "city": 2.0, "snow": 1.0, "siracusa": 1.0}, "base": false},
	"tool_box": {"name": "工具箱", "color": Color("5f7f5a"), "region": {"mine": 1.0, "city": 1.0, "snow": 2.0, "siracusa": 2.5}, "base": false},
	"electronics": {"name": "电子柜", "color": Color("4a8a8a"), "region": {"mine": 1.0, "city": 2.0, "snow": 0.5, "siracusa": 0.5}, "base": true},
	"medical": {"name": "医疗柜", "color": Color("c8d4dc"), "region": {"mine": 0.5, "city": 1.0, "snow": 1.0, "siracusa": 1.0}, "base": true},
}
const SPECIAL_FROM_BOX := 0.03
const SPECIAL_FROM_VAULT := 0.15
const SPECIAL_FROM_ELITE := 0.04
const GUARDED_RARE_BONUS := 0.10

static func _pick_weighted(weights: Array, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for w in weights: total += float(w)
	var roll := rng.randf() * total
	for i in range(weights.size()):
		roll -= float(weights[i])
		if roll <= 0.0: return i
	return weights.size() - 1

static func _range(rng: RandomNumberGenerator, low: int, high: int) -> int:
	return rng.randi_range(low, high)

# --- 掉落阶梯 (用户 2026-10-18: 玩家深入的重要原因是深处会掉落更好的装备和材料) ---
## Every ten-floor block has four steps — floors 1–3, 4–6, 7–9 and the 10th
## before the camp — and each block starts one step above the last one's end,
## so the stair only climbs: floor 11 beats floor 10. `deep` = step / 15 drives
## everything below and is full from floor 40 (step 15). Rare gear alone keeps
## climbing to step 35, floor 90 (用户 2026-10-18: 以普通敌人装备稀有 5% 为顶).
const STAIR_STEP_ENDS := [3, 6, 9, 10]
const STAIR_BLOCKS := 9
const DEEP_TOP := 15
const STAIR_TOP := 35
## Quality weights [common, fine, rare] at step 15, as multipliers of the
## table's own (QUALITY); in between they move linearly with `deep`.
const DEEP_QUALITY := [0.3, 1.6, 4.0]
## From step 15 to 35 the rare multiplier alone goes on from 4 to this: a
## normal enemy's rare share reaches 50% before RARE_SCALE, so 5% on floor 90
## (elites 7.8%, boxes 6.6%, vaults 9%).
const RARE_TOP_QUALITY := 12.2
## Enemy material tiers [common, uncommon, rare] at the top step, likewise.
const DEEP_MATERIAL := [0.4, 3.0, 6.0]
## Rare finds at the top step: named gear (exclusive, set, special) ×2.5,
## growth drops (chips, books, module data) ×2, D32钢 ×5, a box's rare
## materials (the ones at 12% or less) ×3, at most 60%.
const DEEP_NAMED := 1.5
const DEEP_GROWTH := 1.0
const DEEP_ULTRA := 4.0
const DEEP_BOX_RARE := 2.0
const BOX_RARE_CAP := 0.6
## 用户 2026-10-18: 稀有概率全部 ÷10 — every rare chance (rare gear quality with
## its route, guard and pity bonuses; an enemy's rare material; named gear;
## D32钢; a box's rare materials) is a tenth of what the tables and the stair
## give. Growth drops (chips, books) keep theirs. The stair's multipliers stand.
const RARE_SCALE := 0.1

## Past the top step (floor 90) the stair is done; from there on each floor
## makes good prefixes likelier instead (用户 2026-10-18: 之后的层好前缀的概率逐渐变高).
## 0 up to floor 90, ½ at floor 90 + GOOD_PREFIX_HALF, nearing 1 further down.
const GOOD_PREFIX_HALF := 40.0

static func top_floor() -> int:
	return STAIR_BLOCKS * FieldCatalog.DEPTH_CYCLE

static func past_top(depth: int) -> float:
	var beyond := float(maxi(0, depth - top_floor()))
	return beyond / (beyond + GOOD_PREFIX_HALF)

## Research hook (课题"深层勘测"): extra steps on the stair, 0 otherwise.
static var stair_bonus := 0

static func stair(depth: int) -> int:
	if Progression.block(depth) >= STAIR_BLOCKS: return STAIR_TOP
	var block := Progression.block(depth)
	var place := (maxi(depth, 1) - 1) % FieldCatalog.DEPTH_CYCLE + 1
	var step := 0
	while place > int(STAIR_STEP_ENDS[step]): step += 1
	return mini(block * STAIR_STEP_ENDS.size() + step + stair_bonus, STAIR_TOP)

## 0 on floors 1–3, 1 from floor 40 on.
static func deep(depth: int) -> float:
	return minf(1.0, float(stair(depth)) / DEEP_TOP)

## Rare gear past floor 40: 0 there, 1 from floor 90 on.
static func rare_reach(depth: int) -> float:
	return clampf(float(stair(depth) - DEEP_TOP) / (STAIR_TOP - DEEP_TOP), 0.0, 1.0)

## `base` × (1 + extra × deep) for this ctx's floor.
static func deeper(ctx: Dictionary, base: float, extra: float) -> float:
	return base * (1.0 + extra * deep(int(ctx.get("depth", 1))))

## A rare roll: `base` along the stair, then RARE_SCALE.
static func _rare(ctx: Dictionary, base: float, extra: float) -> bool:
	return ctx.rng.randf() < deeper(ctx, base, extra) * RARE_SCALE

## A box's rare-material roll, more likely deeper down.
static func _rare_find(ctx: Dictionary, chance: float) -> bool:
	return ctx.rng.randf() < minf(BOX_RARE_CAP, deeper(ctx, chance, DEEP_BOX_RARE)) * RARE_SCALE

## Weights whose last entry is the rare one, with its share of the total
## scaled by `scale` and the others keeping their proportions.
static func _scale_rare(weights: Array, scale: float) -> Array:
	var others := 0.0
	for i in range(weights.size() - 1): others += float(weights[i])
	var share := float(weights[-1]) / maxf(others + float(weights[-1]), 0.0001)
	var target := share * scale
	if others <= 0.0: return weights   # nothing else to roll (never happens with these tables)
	weights[-1] = target * others / (1.0 - target)
	return weights

## Quality on floor `depth`: the table's weights moved along the stair, then
## the rare weight gets `rare_bonus` × 100 points (route reward, guards, pity).
static func roll_quality(table: String, rare_bonus: float, rng: RandomNumberGenerator, depth: int = 1) -> int:
	# White / blue / gold move along the shared S curve (复利数值改造清单 B):
	# slow to floor 30, steep around 35–60, flat from 70; same end as before.
	var weights: Array = QUALITY[table].duplicate()
	var s := Scaling.s_curve(depth)
	for i in range(2): weights[i] = float(weights[i]) * lerpf(1.0, float(DEEP_QUALITY[i]), s)
	weights[2] = float(weights[2]) * lerpf(1.0, RARE_TOP_QUALITY, s)
	weights[2] = float(weights[2]) + maxf(rare_bonus, 0.0) * 100.0
	return _pick_weighted(_scale_rare(weights, RARE_SCALE), rng)

## One piece of equipment. Its panel and every affix roll inside its rarity's
## band on the floor's tier (复利数值改造清单 B), and it gets its prefixes last
## (装备前缀策划案 §2.3).
static func roll_equipment(category: int, title: String, region: String, depth: int, rarity: int, rng: RandomNumberGenerator) -> Item:
	category = Item.slot_of(category)
	var size := GearSlots.size(category)
	# The floor's ten-floor tier fixes the range; the rarity's band and the
	# floor's roll exponent place it inside (复利数值改造清单 B).
	var tier := Scaling.tier_of(depth)
	var item := Item.create(title, category as Item.Category, size.x, size.y, Scaling.gear_power(tier, rarity, Scaling.roll_position(depth, rng)))
	item.origin_region = region
	item.rarity = rarity
	item.grade = tier
	item.value = (10 + depth * 4) * (1 + item.rarity)
	if Item.is_jewel_slot(category): item.atk_share = Item.roll_atk_share(rng)
	var possible: Array = FieldCatalog.AFFIX_POOLS[category].duplicate()
	var wave_slot := category == Item.Category.WEAPON and item.rarity >= 1 and rng.randf() < FieldCatalog.SWORD_WAVE_CHANCE
	if wave_slot: item.modifiers.append(ItemModifier.roll_skill_boost(rng))
	for i in range(item.rarity - (1 if wave_slot else 0)):
		var index := rng.randi_range(0, possible.size() - 1)
		var stat: int = possible[index]
		possible.remove_at(index)
		item.modifiers.append(ItemModifier.roll_affix(stat as ItemModifier.Stat, item.rarity, rng, Scaling.roll_position(depth, rng), tier, category))
	item.power_mid = Scaling.gear_power(tier, rarity, 0.5)
	# A base name gets the base's factor and intrinsic stats (装备策划案 §2.1).
	var base_id := GearCatalog.id_for_name(title)
	if not base_id.is_empty() and int(GearCatalog.BASES[base_id].category) == category:
		GearCatalog.apply(item, base_id, rng)
		item.power_mid *= float(GearCatalog.BASES[base_id].factor)
	PrefixCatalog.roll_onto(item, region, depth, rng)
	return item

## Quality roll with the rare-gear pity (only on "effective" sources: elites,
## equipment boxes, vault chests). Updates the counter.
static func _quality_with_pity(table: String, ctx: Dictionary, extra_bonus: float, effective: bool) -> int:
	var pity: Dictionary = ctx.get("pity", {})
	var bonus := float(ctx.get("reward", 0.0)) * 0.2 + extra_bonus + (float(pity.get("rare_gear", 0.0)) if effective else 0.0)
	var rarity := roll_quality(table, bonus, ctx.rng, int(ctx.get("depth", 1)))
	if effective:
		if rarity >= 2: pity.rare_gear = 0.0
		else: pity.rare_gear = minf(RARE_GEAR_PITY_CAP, float(pity.get("rare_gear", 0.0)) + RARE_GEAR_PITY_STEP)
	return rarity

## One piece of ordinary gear from `table` (normal / guard / elite / box /
## vault); the base comes from GearCatalog (装备策划案 §2.3).
## `category` may be a group (ARMOR / TRINKET), which picks one of its slots.
static func _gear(category: int, enemy_type: String, table: String, ctx: Dictionary, extra_bonus: float, effective: bool) -> Item:
	if category == Item.Category.ARMOR or category == Item.Category.TRINKET: category = GearSlots.roll(ctx.rng, category)
	var rarity := _quality_with_pity(table, ctx, extra_bonus, effective)
	var id := GearCatalog.pick(category, ctx.region, int(ctx.depth), table, enemy_type, ctx.rng)
	return roll_equipment(category, GearCatalog.BASES[id].name, ctx.region, int(ctx.depth), rarity, ctx.rng)

## One enemy-material pick: common / uncommon / rare, with the rare pity.
static func _enemy_material(enemy_type: String, ctx: Dictionary) -> Item:
	var table: Dictionary = ENEMY_MATERIALS.get(enemy_type, ENEMY_MATERIALS.thug)
	var depth := int(ctx.depth)
	var pity: Dictionary = ctx.get("pity", {})
	var d := deep(depth)
	var weights := [MATERIAL_TIER_WEIGHTS.common * lerpf(1.0, DEEP_MATERIAL[0], d), MATERIAL_TIER_WEIGHTS.uncommon * lerpf(1.0, DEEP_MATERIAL[1], d),
		MATERIAL_TIER_WEIGHTS.rare * lerpf(1.0, DEEP_MATERIAL[2], d) + float(pity.get("rare_material", 0.0)) * 100.0]
	var tier: String = ["common", "uncommon", "rare"][_pick_weighted(_scale_rare(weights, RARE_SCALE), ctx.rng)]
	if tier == "rare": pity.rare_material = 0.0
	else: pity.rare_material = minf(RARE_MATERIAL_PITY_CAP, float(pity.get("rare_material", 0.0)) + RARE_MATERIAL_PITY_STEP)
	var options: Array = table[tier]
	var pick: Array = options[ctx.rng.randi_range(0, options.size() - 1)]
	return MaterialCatalog.create(pick[0], _range(ctx.rng, int(pick[1]), int(pick[2])), ctx.region)

# --- Growth materials (精英化与加点策划案 §3.2): chips, skill summaries, module data.
## [material, chance] per source; bosses and outpost leaders use "boss".
const GROWTH_DROPS := {
	"normal": [["技巧概要·卷1", 0.03]],
	"guard": [["技巧概要·卷1", 0.06], ["近卫芯片", 0.03]],
	"elite": [["近卫芯片", 0.12], ["近卫芯片组", 0.03], ["技巧概要·卷2", 0.10]],
	"boss": [["近卫芯片组", 0.35], ["模组数据块", 0.15], ["技巧概要·卷3", 0.30], ["近卫芯片", 0.50]],
}

## Everything one enemy drops (§3). ctx may carry "boss" (outpost leader or
## bounty) and "set_seen" (set ids found this contract).
## 用户 2026-10-17: 一个敌人最多爆一个材料 + 一件装备，材料只会 ×1. Everything is
## rolled as before, then the best material (highest ★) and the best piece of
## gear (named before ordinary, then rarity) are kept; 赤金 and flasks are apart.
static func enemy_drops(enemy_type: String, elite: bool, guard: bool, ctx: Dictionary) -> Array:
	var best_mat: Dictionary = {}
	var best_gear: Dictionary = {}
	var out: Array = []
	for drop in _enemy_drops_rolled(enemy_type, elite, guard, ctx):
		var item: Item = drop.get("item")
		if item == null or item.is_potion(): out.append(drop)
		elif item.is_equippable():
			if best_gear.is_empty() or _gear_rank(item) > _gear_rank(best_gear.item): best_gear = drop
		elif best_mat.is_empty() or _material_rank(item) > _material_rank(best_mat.item): best_mat = drop
	if not best_mat.is_empty():
		best_mat.item.set_quantity(1)
		out.push_front(best_mat)
	if not best_gear.is_empty(): out.push_front(best_gear)
	return out

static func _material_rank(item: Item) -> int:
	return MaterialCatalog.star(item.material_id) if not item.material_id.is_empty() else 4 + item.rarity

static func _gear_rank(item: Item) -> int:
	return (10 if not item.named_kind().is_empty() else 0) + item.rarity

static func _enemy_drops_rolled(enemy_type: String, elite: bool, guard: bool, ctx: Dictionary) -> Array:
	var out: Array = []
	var rng: RandomNumberGenerator = ctx.rng
	var boss := bool(ctx.get("boss", false))
	var source := "elite" if elite else ("guard" if guard else "normal")
	var growth_source := "boss" if boss else source
	for entry in GROWTH_DROPS[growth_source]:
		if rng.randf() < deeper(ctx, float(entry[1]), DEEP_GROWTH): out.append({"item": MaterialCatalog.create(entry[0], 1, ctx.region)})
	# Enemy exclusives and set pieces (装备扩充策划案 §1.1).
	# A region boss's own chance by tier, a warden none (BossCatalog, GameManager.spawn_enemy_drops).
	if _rare(ctx, float(ctx.get("exclusive_chance", SpecialGear.EXCLUSIVE_CHANCE["boss" if boss else source])), DEEP_NAMED):
		var exclusive := SpecialGear.roll_exclusive(enemy_type, ctx.region, int(ctx.depth), rng, boss)
		if exclusive != null: out.append({"item": exclusive})
	var set_chance := deeper(ctx, float(ctx.get("set_chance", SpecialGear.SET_CHANCE.get("boss" if boss else source, 0.0))), DEEP_NAMED) * RARE_SCALE
	if set_chance > 0.0 and rng.randf() < set_chance:
		var piece := SpecialGear.roll_set_piece(ctx.region, int(ctx.depth), rng, ctx.get("set_seen", {}), boss)
		if piece != null: out.append({"item": piece})
	var table: Dictionary = ENEMY_SOURCE[source]
	var weights: Array = table.weights.duplicate()
	if enemy_type == "slug":
		# Unarmed infected creatures carry no gear (掉落机制调研 §5.13).
		weights[1] = float(weights[1]) + float(weights[3])
		weights[3] = 0.0
	# 装备掉率 (底材固有属性表 v1.0) raises the gear pick's weight only.
	weights[3] = float(weights[3]) * (1.0 + float(ctx.get("drop_pct", 0.0)))
	for pick in range(int(table.picks)):
		match _pick_weighted(weights, rng):
			1: out.append({"item": _enemy_material(enemy_type, ctx)})
			2:
				var gold: Array = ENEMY_GOLD[source]
				out.append({"gold": roundi(_range(rng, gold[0], gold[1]) * (1.5 if ctx.region == "snow" else 1.0))})
			3:
				var category := GearSlots.roll(rng)
				out.append({"item": _gear(category, enemy_type, source, ctx, 0.0, elite)})
	if rng.randf() < float(POTION_DROP[source]): out.append({"item": BaseCatalog.create_potion("A", Scaling.tier_of(int(ctx.depth)))})
	var mats: Dictionary = ENEMY_MATERIALS.get(enemy_type, {})
	if elite:
		if mats.has("guaranteed"): out.append({"item": MaterialCatalog.create(mats.guaranteed[0], _range(rng, mats.guaranteed[1], mats.guaranteed[2]), ctx.region)})
		if mats.has("ultra") and _rare(ctx, float(mats.ultra[1]), DEEP_ULTRA): out.append({"item": MaterialCatalog.create(mats.ultra[0], 1, ctx.region)})
		if _rare(ctx, SPECIAL_FROM_ELITE, DEEP_NAMED): out.append({"item": SpecialGear.roll(ctx.region, int(ctx.depth), rng)})
		if ctx.region in ["city", "snow", "siracusa"] and rng.randf() < 0.05: out.append({"item": FieldCatalog.exclusive(ctx.region, int(ctx.depth))})
	if enemy_type == "slug" and ctx.region == "mine" and rng.randf() < 0.02: out.append({"item": FieldCatalog.exclusive("mine", int(ctx.depth))})
	# 萨米's ordinary enemies now and then carry a plank for the fires (地图特色策划案 §5.3).
	if ctx.region == "snow" and source == "normal" and rng.randf() < FeatureCatalog.SNOW_PLANK: out.append({"item": MaterialCatalog.create("木板", 1, ctx.region)})
	return out

# --- Points of interest -------------------------------------------------------

static func _mat(id: String, low: int, high: int, ctx: Dictionary) -> Dictionary:
	return {"item": MaterialCatalog.create(id, _range(ctx.rng, low, high), ctx.region)}

## Everything a point of interest gives when opened (§4.1–4.2). `guarded`: it
## had a guard post (better quality); `vault`: one of the sealed vault chests.
## 用户 2026-10-18: 兴趣点里刷的材料不堆叠，一个最多一个 — every material entry,
## 赤金 included, is a single one; the same material can turn up more than
## once, each in its own cell (they stack again once in the pack).
static func container_drops(kind: String, ctx: Dictionary, guarded: bool = false) -> Array:
	var out := _container_rolled(kind, ctx, guarded)
	for drop in out:
		if drop.has("gold"): drop.single = true
		elif drop.item.is_stackable() and not drop.item.is_potion(): drop.item.set_quantity(1)
	return out

static func _container_rolled(kind: String, ctx: Dictionary, guarded: bool) -> Array:
	var rng: RandomNumberGenerator = ctx.rng
	var out: Array = []
	var bonus := GUARDED_RARE_BONUS if guarded else 0.0
	match kind:
		"construction":
			out.append(_mat("碳", 2, 4, ctx))
			out.append(_mat(_one(["螺栓", "螺母", "钉子"], rng), 3, 6, ctx))
			out.append(_mat("金属板" if rng.randf() < 0.5 else "木板", 1, 3, ctx))
			out.append(_mat("碳" if rng.randf() < 0.6 else "基础加固建材", 1, 2, ctx))
			if rng.randf() < 0.25: out.append(_mat("碳素", 1, 2, ctx))
			if rng.randf() < 0.35: out.append(_mat("软管", 1, 2, ctx))
			if _rare_find(ctx, 0.12): out.append(_mat("密封泡沫", 1, 1, ctx))
			if _rare_find(ctx, 0.06): out.append(_mat("碳素组" if rng.randf() < 0.5 else "进阶加固建材", 1, 1, ctx))
		"ore_vein":
			out.append(_mat("源岩", 3, 6, ctx))
			out.append(_mat("固源岩", 1, 2, ctx))
			if rng.randf() < 0.30: out.append(_mat("金属板", 1, 2, ctx))
			if _rare_find(ctx, 0.05): out.append(_mat("燃料罐", 1, 1, ctx))
			if rng.randf() < 0.20: out.append(_mat("固源岩组", 1, 1, ctx))
			if _rare_find(ctx, 0.03): out.append(_mat("源石碎片", 1, 1, ctx))
			if rng.randf() < 0.25: out.append({"item": FieldCatalog.exclusive("mine", int(ctx.depth))})
		"depot":
			out.append(_mat("家具零件", 1, 2, ctx))
			out.append(_mat("胶带", 2, 4, ctx))
			out.append(_mat("灯泡" if rng.randf() < 0.5 else "蓄电池", 1, 3, ctx))
			out.append(_mat("碳", 1, 2, ctx))
			if rng.randf() < 0.35: out.append(_mat("电源线", 1, 1, ctx))
			if rng.randf() < 0.25: out.append(_mat("软管", 1, 1, ctx))
			if _rare_find(ctx, 0.04): out.append(_mat("车用蓄电池", 1, 1, ctx))
			if rng.randf() < 0.20: out.append(_mat("进阶加固建材", 1, 1, ctx))
			if _rare_find(ctx, 0.05): out.append(_mat("赤金", 1, 1, ctx))
		"safe":
			out.append({"gold": _range(rng, 30, 60)})
			if _rare(ctx, float(SpecialGear.SET_CHANCE.vault), DEEP_NAMED):
				var piece := SpecialGear.roll_set_piece(ctx.region, int(ctx.depth), rng, ctx.get("set_seen", {}))
				if piece != null: out.append({"item": piece})
			if rng.randf() < 0.35: out.append(_mat("赤金", 1, 1, ctx))
			if rng.randf() < 0.25: out.append(_mat("电路板", 1, 1, ctx))
			# The family vaults of the old Volsini quarter keep the crest.
			if ctx.region == "siracusa" and rng.randf() < 0.2: out.append({"item": FieldCatalog.exclusive("siracusa", int(ctx.depth))})
		"camp":
			out.append(_mat("碳", 2, 3, ctx))
			out.append(_mat("木板", 2, 4, ctx))
			out.append(_mat("固体燃料", 3, 6, ctx))
			out.append(_mat("基础加固建材", 1, 1, ctx))
			if rng.randf() < 0.40: out.append(_mat("帆布", 1, 2, ctx))
			if rng.randf() < 0.25: out.append(_mat("蓄电池", 1, 2, ctx))
			if rng.randf() < 0.20: out.append(_mat("碳素组", 1, 1, ctx))
			if rng.randf() < 0.15: out.append({"item": FieldCatalog.exclusive("snow", int(ctx.depth))})
		"weapon_box", "armor_box", "tool_box":
			var category: int = {"weapon_box": Item.Category.WEAPON, "armor_box": Item.Category.ARMOR, "tool_box": Item.Category.TRINKET}[kind]
			out.append({"item": _gear(category, "", "box", ctx, bonus, true)})
			if kind == "weapon_box" and rng.randf() < 0.30 * (1.0 + float(ctx.get("drop_pct", 0.0))): out.append({"item": _gear(category, "", "box", ctx, bonus, true)})
			if kind == "armor_box" and ctx.region == "city" and rng.randf() < 0.15: out.append({"item": FieldCatalog.exclusive("city", int(ctx.depth))})
			if kind == "tool_box":
				# Tarkov's toolbox: hardware, tools and a little electronics.
				if rng.randf() < 0.60: out.append(_mat(_one(["螺栓", "螺母", "钉子", "胶带"], rng), 2, 5, ctx))
				if rng.randf() < 0.30: out.append(_mat("电线", 1, 3, ctx))
				if rng.randf() < 0.15: out.append(_mat("扳手", 1, 1, ctx))
				if _rare_find(ctx, 0.03): out.append(_mat("工具套装", 1, 1, ctx))
				if rng.randf() < 0.25: out.append(_mat(["碳", "基础加固建材", "家具零件"][rng.randi_range(0, 2)], 1, 2, ctx))
			if _rare(ctx, SPECIAL_FROM_BOX, DEEP_NAMED): out.append({"item": _special_of(category, ctx)})
		"electronics":
			out.append(_mat("电线", 2, 5, ctx))
			if _rare_find(ctx, 0.05): out.append(_mat("芯片助剂", 1, 1, ctx))
			if _rare_find(ctx, 0.06): out.append(_mat("技巧概要·卷1", 1, 1, ctx))
			out.append(_mat("继电器" if rng.randf() < 0.5 else "电路板", 1, 1, ctx))
			if rng.randf() < 0.40: out.append(_mat("电源线", 1, 1, ctx))
			if rng.randf() < 0.30: out.append(_mat("电路板", 1, 1, ctx))
			if _rare_find(ctx, 0.06): out.append(_mat("微型电机", 1, 1, ctx))
		"medical":
			out.append(_mat("医用耗材包", 1, 2, ctx))
			out.append(_mat("胶带", 1, 3, ctx))
			if rng.randf() < 0.30: out.append(_mat("帆布", 1, 1, ctx))
			if rng.randf() < 0.25: out.append(_mat("糖", 1, 2, ctx))
		"vault_weapon", "vault_gear":
			var category := Item.Category.WEAPON if kind == "vault_weapon" else (Item.Category.ARMOR if rng.randf() < 0.5 else Item.Category.TRINKET)
			out.append({"item": _gear(category, "", "vault", ctx, 0.0, true)})
			if _rare(ctx, SPECIAL_FROM_VAULT, DEEP_NAMED): out.append({"item": _special_of(category, ctx)})
			if _rare(ctx, float(SpecialGear.SET_CHANCE.vault), DEEP_NAMED):
				var piece := SpecialGear.roll_set_piece(ctx.region, int(ctx.depth), rng, ctx.get("set_seen", {}))
				if piece != null: out.append({"item": piece})
		"vault_base":
			out.append(_mat("碳素组", 1, 2, ctx))
			out.append(_mat("赤金", 1, 2, ctx))
			if _rare_find(ctx, 0.10): out.append(_mat("源石碎片", 1, 1, ctx))
	# 地图特色's field supplies (地图特色策划案 §3.3, §4.5, §5.4), in their own region.
	for entry in FeatureCatalog.SUPPLY_DROPS.get(kind, []):
		if ctx.region == entry[2] and rng.randf() < float(entry[1]): out.append({"item": FeatureCatalog.create_supply(entry[0])})
	return out

static func _one(ids: Array, rng: RandomNumberGenerator) -> String:
	return ids[rng.randi_range(0, ids.size() - 1)]

## Special gear of a slot, the region's own pieces more likely.
static func _special_of(category: int, ctx: Dictionary) -> Item:
	# By group: a box's ARMOR / TRINKET takes the chest and amulet specials (8 slots).
	var ids := SpecialGear.GEAR.keys().filter(func(id): return SpecialGear.kind(id) == "special" and Item.group_of(int(SpecialGear.GEAR[id].category)) == Item.group_of(category))
	if ids.is_empty(): return SpecialGear.roll(ctx.region, int(ctx.depth), ctx.rng)
	var weights: Array = ids.map(func(id): return SpecialGear.REGION_WEIGHT if SpecialGear.GEAR[id].region == ctx.region else 1.0)
	var item := SpecialGear.create(ids[_pick_weighted(weights, ctx.rng)], int(ctx.depth), ctx.rng)
	item.origin_region = ctx.region
	return item

## What each Lungmen district keeps (城市地图调研与方案_v1.md §2): the yards'
## depots and weapon crates, the sites' building stock and tools, the slums'
## medicine and safes, the streets' electronics. A point there is this many
## times likelier to be one of these.
const DISTRICT_POI := {
	"yard": {"depot": 4.0, "weapon_box": 3.0},
	"site": {"construction": 4.0, "tool_box": 4.0},
	"slum": {"medical": 4.0, "safe": 3.0},
	"street": {"electronics": 4.0, "armor_box": 2.0},
}

## The kinds of point of interest for one segment (§4.1): at least one weapon
## box and two base-material points, the rest by the region's weights.
## `places` (optional) is the district each point stands in, which tilts the
## weights there (DISTRICT_POI); the weapon box goes to a yard if there is one.
static func plan_points(region: String, count: int, rng: RandomNumberGenerator, places: Array = []) -> Array[String]:
	var weighted: Array[String] = []
	for kind in POI:
		if float(POI[kind].region.get(region, 0.0)) > 0.0: weighted.append(kind)
	var base_kinds := weighted.filter(func(k): return POI[k].base)
	var plan: Array[String] = []
	plan.resize(count)
	var order: Array[int] = []
	for i in range(count): order.append(i)
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := order[i]
		order[i] = order[j]
		order[j] = tmp
	var place_of := func(i: int) -> String: return String(places[i]) if i < places.size() else ""
	var weights_at := func(kinds: Array, i: int) -> Array:
		var tilt: Dictionary = DISTRICT_POI.get(place_of.call(i), {})
		return kinds.map(func(k): return float(POI[k].region[region]) * float(tilt.get(k, 1.0)))
	if count >= 1:
		var slot := order[0]
		for i in order:
			if place_of.call(i) == "yard":
				slot = i
				break
		order.erase(slot)
		plan[slot] = "weapon_box"
	for n in range(order.size()):
		var i := order[n]
		var kinds: Array = base_kinds if n < 2 else weighted
		plan[i] = kinds[_pick_weighted(weights_at.call(kinds, i), rng)]
	return plan
