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
const ENEMY_SOURCE := {
	"normal": {"picks": 1, "weights": [12.0, 60.0, 20.0, 8.0]},
	"guard": {"picks": 1, "weights": [0.0, 65.0, 20.0, 15.0]},
	"elite": {"picks": 3, "weights": [0.0, 55.0, 20.0, 25.0]},
}
## Equipment category weights for enemy drops: weapon / armour / trinket.
const ENEMY_GEAR_WEIGHTS := [6.0, 1.0, 1.0]
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
	"construction": {"name": "建材堆", "color": Color("8a7a5c"), "region": {"mine": 2.0, "city": 1.0, "snow": 1.0}, "base": true},
	"ore_vein": {"name": "源石矿脉", "color": Color("d07a2a"), "region": {"mine": 3.0}, "base": true},
	"depot": {"name": "物资仓", "color": Color("6c7f8f"), "region": {"city": 3.0}, "base": true},
	"safe": {"name": "保险柜", "color": Color("b59a3a"), "region": {"mine": 0.5, "city": 1.5}, "base": true},
	"camp": {"name": "冰原营地", "color": Color("9fb6c2"), "region": {"snow": 3.0}, "base": true},
	"weapon_box": {"name": "武器箱", "color": Color("8c5a4a"), "region": {"mine": 1.0, "city": 2.0, "snow": 1.5}, "base": false},
	"armor_box": {"name": "护具箱", "color": Color("4f6f8f"), "region": {"mine": 1.0, "city": 2.0, "snow": 1.0}, "base": false},
	"tool_box": {"name": "工具箱", "color": Color("5f7f5a"), "region": {"mine": 1.0, "city": 1.0, "snow": 2.0}, "base": false},
	"electronics": {"name": "电子柜", "color": Color("4a8a8a"), "region": {"mine": 1.0, "city": 2.0, "snow": 0.5}, "base": true},
	"medical": {"name": "医疗柜", "color": Color("c8d4dc"), "region": {"mine": 0.5, "city": 1.0, "snow": 1.0}, "base": true},
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

## Quality: rare weight gets `rare_bonus` × 100 points (route reward, guards, pity).
static func roll_quality(table: String, rare_bonus: float, rng: RandomNumberGenerator) -> int:
	var weights: Array = QUALITY[table].duplicate()
	weights[2] = float(weights[2]) + maxf(rare_bonus, 0.0) * 100.0
	return _pick_weighted(weights, rng)

## One piece of equipment. Affix tiers are capped by depth (§5): Ⅲ from segment 3.
static func roll_equipment(category: int, title: String, region: String, depth: int, rarity: int, rng: RandomNumberGenerator) -> Item:
	var size := Vector2i(2, 1) if category == Item.Category.WEAPON else (Vector2i(2, 2) if category == Item.Category.ARMOR else Vector2i(1, 1))
	var item := Item.create(title, category as Item.Category, size.x, size.y, 1.0 + depth * 0.3 + rng.randf())
	item.origin_region = region
	item.rarity = rarity
	item.power *= 1.0 + item.rarity * 0.3
	item.value = (10 + depth * 4) * (1 + item.rarity)
	var possible: Array = FieldCatalog.AFFIX_POOLS[category].duplicate()
	var wave_slot := category == Item.Category.WEAPON and item.rarity >= 1 and rng.randf() < FieldCatalog.SWORD_WAVE_CHANCE
	if wave_slot: item.modifiers.append(ItemModifier.trigger_mod(ItemModifier.Trigger.SWORD_WAVE))
	var tier_cap := 2 if depth >= 3 else 1
	for i in range(item.rarity - (1 if wave_slot else 0)):
		var index := rng.randi_range(0, possible.size() - 1)
		var stat: int = possible[index]
		possible.remove_at(index)
		var tier := mini(FieldCatalog._roll_tier(item.rarity, rng), tier_cap)
		var mod := ItemModifier.stat_mod(stat as ItemModifier.Stat, float(FieldCatalog.AFFIX_AMOUNTS[stat]) * ItemModifier.TIER_SCALES[tier])
		mod.tier = tier
		item.modifiers.append(mod)
	# A base name gets the base's factor and intrinsic stats (装备策划案 §2.1).
	var base_id := GearCatalog.id_for_name(title)
	if not base_id.is_empty() and int(GearCatalog.BASES[base_id].category) == category: GearCatalog.apply(item, base_id)
	return item

## Quality roll with the rare-gear pity (only on "effective" sources: elites,
## equipment boxes, vault chests). Updates the counter.
static func _quality_with_pity(table: String, ctx: Dictionary, extra_bonus: float, effective: bool) -> int:
	var pity: Dictionary = ctx.get("pity", {})
	var bonus := float(ctx.get("reward", 0.0)) * 0.2 + extra_bonus + (float(pity.get("rare_gear", 0.0)) if effective else 0.0)
	var rarity := roll_quality(table, bonus, ctx.rng)
	if effective:
		if rarity >= 2: pity.rare_gear = 0.0
		else: pity.rare_gear = minf(RARE_GEAR_PITY_CAP, float(pity.get("rare_gear", 0.0)) + RARE_GEAR_PITY_STEP)
	return rarity

## One piece of ordinary gear from `table` (normal / guard / elite / box /
## vault); the base comes from GearCatalog (装备策划案 §2.3).
static func _gear(category: int, enemy_type: String, table: String, ctx: Dictionary, extra_bonus: float, effective: bool) -> Item:
	var rarity := _quality_with_pity(table, ctx, extra_bonus, effective)
	var id := GearCatalog.pick(category, ctx.region, int(ctx.depth), table, enemy_type, ctx.rng)
	return roll_equipment(category, GearCatalog.BASES[id].name, ctx.region, int(ctx.depth), rarity, ctx.rng)

## One enemy-material pick: common / uncommon / rare, with the rare pity.
static func _enemy_material(enemy_type: String, ctx: Dictionary) -> Item:
	var table: Dictionary = ENEMY_MATERIALS.get(enemy_type, ENEMY_MATERIALS.thug)
	var depth := int(ctx.depth)
	var pity: Dictionary = ctx.get("pity", {})
	var rare_weight := MATERIAL_TIER_WEIGHTS.rare * (1.0 + 0.1 * (depth - 1)) + float(pity.get("rare_material", 0.0)) * 100.0
	var tier: String = ["common", "uncommon", "rare"][_pick_weighted([MATERIAL_TIER_WEIGHTS.common, MATERIAL_TIER_WEIGHTS.uncommon, rare_weight], ctx.rng)]
	if tier == "rare": pity.rare_material = 0.0
	else: pity.rare_material = minf(RARE_MATERIAL_PITY_CAP, float(pity.get("rare_material", 0.0)) + RARE_MATERIAL_PITY_STEP)
	var options: Array = table[tier]
	var pick: Array = options[ctx.rng.randi_range(0, options.size() - 1)]
	var count := _range(ctx.rng, int(pick[1]), int(pick[2])) + (1 if tier == "common" and depth >= 4 else 0)
	return MaterialCatalog.create(pick[0], count, ctx.region)

## Everything one enemy drops (§3).
static func enemy_drops(enemy_type: String, elite: bool, guard: bool, ctx: Dictionary) -> Array:
	var out: Array = []
	var rng: RandomNumberGenerator = ctx.rng
	var source := "elite" if elite else ("guard" if guard else "normal")
	var table: Dictionary = ENEMY_SOURCE[source]
	var weights: Array = table.weights.duplicate()
	if enemy_type == "slug":
		# Unarmed infected creatures carry no gear (掉落机制调研 §5.13).
		weights[1] = float(weights[1]) + float(weights[3])
		weights[3] = 0.0
	for pick in range(int(table.picks)):
		match _pick_weighted(weights, rng):
			1: out.append({"item": _enemy_material(enemy_type, ctx)})
			2:
				var gold: Array = ENEMY_GOLD[source]
				out.append({"gold": roundi(_range(rng, gold[0], gold[1]) * (1.5 if ctx.region == "snow" else 1.0))})
			3:
				var category := _pick_weighted(ENEMY_GEAR_WEIGHTS, rng)
				out.append({"item": _gear(category, enemy_type, source, ctx, 0.0, elite)})
	var mats: Dictionary = ENEMY_MATERIALS.get(enemy_type, {})
	if elite:
		if mats.has("guaranteed"): out.append({"item": MaterialCatalog.create(mats.guaranteed[0], _range(rng, mats.guaranteed[1], mats.guaranteed[2]), ctx.region)})
		if mats.has("ultra") and rng.randf() < float(mats.ultra[1]): out.append({"item": MaterialCatalog.create(mats.ultra[0], 1, ctx.region)})
		if rng.randf() < SPECIAL_FROM_ELITE: out.append({"item": SpecialGear.roll(ctx.region, int(ctx.depth), rng)})
		if ctx.region in ["city", "snow"] and rng.randf() < 0.05: out.append({"item": FieldCatalog.exclusive(ctx.region)})
	if enemy_type == "slug" and ctx.region == "mine" and rng.randf() < 0.02: out.append({"item": FieldCatalog.exclusive("mine")})
	return out

# --- Points of interest -------------------------------------------------------

static func _mat(id: String, low: int, high: int, ctx: Dictionary) -> Dictionary:
	return {"item": MaterialCatalog.create(id, _range(ctx.rng, low, high), ctx.region)}

## Everything a point of interest gives when opened (§4.1–4.2). `guarded`: it
## had a guard post (better quality); `vault`: one of the sealed vault chests.
static func container_drops(kind: String, ctx: Dictionary, guarded: bool = false) -> Array:
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
			if rng.randf() < 0.12: out.append(_mat("密封泡沫", 1, 1, ctx))
			if rng.randf() < 0.06: out.append(_mat("碳素组" if rng.randf() < 0.5 else "进阶加固建材", 1, 1, ctx))
		"ore_vein":
			out.append(_mat("源岩", 3, 6, ctx))
			out.append(_mat("固源岩", 1, 2, ctx))
			if rng.randf() < 0.30: out.append(_mat("金属板", 1, 2, ctx))
			if rng.randf() < 0.05: out.append(_mat("燃料罐", 1, 1, ctx))
			if rng.randf() < 0.20: out.append(_mat("固源岩组", 1, 1, ctx))
			if rng.randf() < 0.03: out.append(_mat("源石碎片", 1, 1, ctx))
			if rng.randf() < 0.25: out.append({"item": FieldCatalog.exclusive("mine")})
		"depot":
			out.append(_mat("家具零件", 1, 2, ctx))
			out.append(_mat("胶带", 2, 4, ctx))
			out.append(_mat("灯泡" if rng.randf() < 0.5 else "蓄电池", 1, 3, ctx))
			out.append(_mat("碳", 1, 2, ctx))
			if rng.randf() < 0.35: out.append(_mat("电源线", 1, 1, ctx))
			if rng.randf() < 0.25: out.append(_mat("软管", 1, 1, ctx))
			if rng.randf() < 0.04: out.append(_mat("车用蓄电池", 1, 1, ctx))
			if rng.randf() < 0.20: out.append(_mat("进阶加固建材", 1, 1, ctx))
			if rng.randf() < 0.05: out.append(_mat("赤金", 1, 1, ctx))
		"safe":
			out.append({"gold": _range(rng, 30, 60)})
			if rng.randf() < 0.35: out.append(_mat("赤金", 1, 1, ctx))
			if rng.randf() < 0.25: out.append(_mat("电路板", 1, 1, ctx))
		"camp":
			out.append(_mat("碳", 2, 3, ctx))
			out.append(_mat("木板", 2, 4, ctx))
			out.append(_mat("固体燃料", 3, 6, ctx))
			out.append(_mat("基础加固建材", 1, 1, ctx))
			if rng.randf() < 0.40: out.append(_mat("帆布", 1, 2, ctx))
			if rng.randf() < 0.25: out.append(_mat("蓄电池", 1, 2, ctx))
			if rng.randf() < 0.20: out.append(_mat("碳素组", 1, 1, ctx))
			if rng.randf() < 0.15: out.append({"item": FieldCatalog.exclusive("snow")})
		"weapon_box", "armor_box", "tool_box":
			var category: int = {"weapon_box": Item.Category.WEAPON, "armor_box": Item.Category.ARMOR, "tool_box": Item.Category.TRINKET}[kind]
			out.append({"item": _gear(category, "", "box", ctx, bonus, true)})
			if kind == "weapon_box" and rng.randf() < 0.30: out.append({"item": _gear(category, "", "box", ctx, bonus, true)})
			if kind == "armor_box" and ctx.region == "city" and rng.randf() < 0.15: out.append({"item": FieldCatalog.exclusive("city")})
			if kind == "tool_box":
				# Tarkov's toolbox: hardware, tools and a little electronics.
				if rng.randf() < 0.60: out.append(_mat(_one(["螺栓", "螺母", "钉子", "胶带"], rng), 2, 5, ctx))
				if rng.randf() < 0.30: out.append(_mat("电线", 1, 3, ctx))
				if rng.randf() < 0.15: out.append(_mat("扳手", 1, 1, ctx))
				if rng.randf() < 0.03: out.append(_mat("工具套装", 1, 1, ctx))
				if rng.randf() < 0.25: out.append(_mat(["碳", "基础加固建材", "家具零件"][rng.randi_range(0, 2)], 1, 2, ctx))
			if rng.randf() < SPECIAL_FROM_BOX: out.append({"item": _special_of(category, ctx)})
		"electronics":
			out.append(_mat("电线", 2, 5, ctx))
			out.append(_mat("继电器" if rng.randf() < 0.5 else "电路板", 1, 1, ctx))
			if rng.randf() < 0.40: out.append(_mat("电源线", 1, 1, ctx))
			if rng.randf() < 0.30: out.append(_mat("电路板", 1, 1, ctx))
			if rng.randf() < 0.06: out.append(_mat("微型电机", 1, 1, ctx))
		"medical":
			out.append(_mat("医用耗材包", 1, 2, ctx))
			out.append(_mat("胶带", 1, 3, ctx))
			if rng.randf() < 0.30: out.append(_mat("帆布", 1, 1, ctx))
			if rng.randf() < 0.25: out.append(_mat("糖", 1, 2, ctx))
		"vault_weapon", "vault_gear":
			var category := Item.Category.WEAPON if kind == "vault_weapon" else (Item.Category.ARMOR if rng.randf() < 0.5 else Item.Category.TRINKET)
			out.append({"item": _gear(category, "", "vault", ctx, 0.0, true)})
			if rng.randf() < SPECIAL_FROM_VAULT: out.append({"item": _special_of(category, ctx)})
		"vault_base":
			out.append(_mat("碳素组", 1, 2, ctx))
			out.append(_mat("赤金", 1, 2, ctx))
			if rng.randf() < 0.10: out.append(_mat("源石碎片", 1, 1, ctx))
	return out

static func _one(ids: Array, rng: RandomNumberGenerator) -> String:
	return ids[rng.randi_range(0, ids.size() - 1)]

## Special gear of a slot, the region's own pieces more likely.
static func _special_of(category: int, ctx: Dictionary) -> Item:
	var ids := SpecialGear.GEAR.keys().filter(func(id): return int(SpecialGear.GEAR[id].category) == category)
	if ids.is_empty(): return SpecialGear.roll(ctx.region, int(ctx.depth), ctx.rng)
	var weights: Array = ids.map(func(id): return SpecialGear.REGION_WEIGHT if SpecialGear.GEAR[id].region == ctx.region else 1.0)
	var item := SpecialGear.create(ids[_pick_weighted(weights, ctx.rng)], int(ctx.depth), ctx.rng)
	item.origin_region = ctx.region
	return item

## The kinds of point of interest for one segment (§4.1): at least one weapon
## box and two base-material points, the rest by the region's weights.
static func plan_points(region: String, count: int, rng: RandomNumberGenerator) -> Array[String]:
	var weighted: Array[String] = []
	var weights: Array = []
	for kind in POI:
		var w := float(POI[kind].region.get(region, 0.0))
		if w > 0.0:
			weighted.append(kind)
			weights.append(w)
	var base_kinds := weighted.filter(func(k): return POI[k].base)
	var base_weights: Array = base_kinds.map(func(k): return float(POI[k].region[region]))
	var plan: Array[String] = []
	if count >= 1: plan.append("weapon_box")
	for i in range(2):
		if plan.size() < count: plan.append(base_kinds[_pick_weighted(base_weights, rng)])
	while plan.size() < count: plan.append(weighted[_pick_weighted(weights, rng)])
	# Shuffle so the guaranteed kinds are not always on the first spurs.
	for i in range(plan.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := plan[i]
		plan[i] = plan[j]
		plan[j] = tmp
	return plan
