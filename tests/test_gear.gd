extends SceneTree

## Equipment bases (装备策划案_v1_0.md §2, §4, §7): the table itself (39 bases,
## 13 per region, no relic names, no ranged bases yet), depth gating and its
## early unlock, enemy-carried weapons, elites' deep weapons, vault tiers,
## intrinsic stats that do not use an affix slot, the power factor, the
## wallet's price and save compatibility.

var failures := 0
var checks := 0

func _initialize() -> void: call_deferred("run")
func check(label: String, passed: bool, seen: Variant = null) -> void:
	checks += 1
	if not passed:
		failures += 1
		if seen != null: print("   seen: ", seen)
	print(("PASS " if passed else "FAIL ") + label)

func ctx(region: String, depth: int, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return {"region": region, "depth": depth, "reward": 0.0, "rng": rng, "pity": {}}

func gear_of(drops: Array) -> Array:
	return drops.filter(func(d): return d.has("item") and d.item.is_equippable() and d.item.special.is_empty() and d.item.exclusive_region.is_empty()).map(func(d): return d.item)

func tiers_at(category: int, region: String, depth: int, source: String) -> Array:
	var out := []
	for id in GearCatalog.eligible(category, region, depth, source): out.append(int(GearCatalog.BASES[id].tier))
	return out

func run() -> void:
	var B := GearCatalog.BASES
	check("39 bases", B.size() == 39, B.size())
	for region in ["mine", "city", "snow"]:
		var counts := [0, 0, 0]
		for id in B:
			if B[id].region == region: counts[int(B[id].category)] += 1
		check("%s has 5 weapons, 4 armour, 4 trinkets" % region, counts == [5, 4, 4], counts)
		for category in [Item.Category.WEAPON, Item.Category.ARMOR, Item.Category.TRINKET]:
			var tiers := []
			for id in B:
				if B[id].region == region and int(B[id].category) == category: tiers.append(int(B[id].tier))
			check("%s %s covers shallow, mid and deep" % [region, Item.CATEGORY_NAMES[category]], 0 in tiers and 1 in tiers and 2 in tiers, tiers)
	var relic_names := RelicCatalog.all().map(func(r): return r.name)
	check("no base shares a name with a relic", B.values().all(func(b): return not b.name in relic_names))
	var names := {}
	for id in B: names[B[id].name] = true
	check("base names are unique", names.size() == B.size())
	check("weapons use only the forms Lappland can wield (blade / heavy / fist)",
		B.values().all(func(b): return int(b.category) != Item.Category.WEAPON or str(b.form) in ["blade", "heavy", "fist"]))

	# Depth gating (§2.2).
	check("segment 1 boxes: shallow only", tiers_at(Item.Category.ARMOR, "mine", 1, "box").max() == 0)
	check("floor 4 boxes: mid unlocked (ten-floor rhythm)", tiers_at(Item.Category.ARMOR, "mine", 3, "box").max() == 0 and tiers_at(Item.Category.ARMOR, "mine", 4, "box").max() == 1)
	check("floor 7 boxes: deep unlocked", tiers_at(Item.Category.ARMOR, "mine", 6, "box").max() == 1 and tiers_at(Item.Category.ARMOR, "mine", 7, "box").max() == 2)
	check("guards see tiers two floors early", tiers_at(Item.Category.ARMOR, "city", 5, "guard").max() == 2 and tiers_at(Item.Category.ARMOR, "city", 2, "guard").max() == 1)
	check("vaults never give shallow bases", tiers_at(Item.Category.ARMOR, "snow", 6, "vault").min() == 1 and not tiers_at(Item.Category.ARMOR, "snow", 1, "vault").is_empty())

	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var deep := 0
	for i in range(3000):
		if int(B[GearCatalog.pick(Item.Category.TRINKET, "city", 7, "box", "", rng)].tier) == 2: deep += 1
	# City trinkets: two shallow, one mid, one deep → weights 1+1+1+2.
	check("the newest tier is drawn twice as often (≈ 2/5)", absf(deep / 3000.0 - 2.0 / 5.0) < 0.03, deep / 3000.0)

	# Enemy weapons and elites (§2.3).
	check("mine thugs carry 改装砍刀, city thugs 帮派砍刀", B[GearCatalog.pick(Item.Category.WEAPON, "mine", 1, "normal", "thug", rng)].name == "改装砍刀"
		and B[GearCatalog.pick(Item.Category.WEAPON, "city", 1, "normal", "thug", rng)].name == "帮派砍刀")
	check("crossbow leaders (city) carry the captured 制式短刀", B[GearCatalog.pick(Item.Category.WEAPON, "city", 1, "normal", "crossbow_leader", rng)].name == "制式短刀")
	check("brawlers carry 指刃", B[GearCatalog.pick(Item.Category.WEAPON, "city", 1, "normal", "brawler", rng)].name == "指刃")
	check("ice hunters carry 猎刀", B[GearCatalog.pick(Item.Category.WEAPON, "snow", 1, "normal", "ice_hunter", rng)].name == "猎刀")
	for region in ["mine", "city", "snow"]:
		var id := GearCatalog.pick(Item.Category.WEAPON, region, 1, "elite", "elite", rng)
		check("%s elites drop the deep weapon「%s」" % [region, B[id].name], int(B[id].tier) == 2 and B[id].region == region)
	var real_drops := true
	var count := 0
	var c := ctx("mine", 1, 22)
	for i in range(600):
		for item in gear_of(LootTables.enemy_drops("crossbow", false, false, c)):
			count += 1
			if item.category == Item.Category.WEAPON and item.item_name != "制式短刀": real_drops = false
			if item.base_id.is_empty(): real_drops = false
	check("dropped gear carries a base id; crossbows drop 制式短刀", real_drops and count > 0, count)
	var seen := {}
	c = ctx("snow", 7, 23)  # deep bases open at floor 7 (ten-floor rhythm)
	for i in range(600):
		for kind in ["weapon_box", "armor_box", "tool_box"]:
			for item in gear_of(LootTables.container_drops(kind, c)): seen[item.base_id] = true
	var snow_box := B.keys().filter(func(id): return B[id].region == "snow" and not B[id].has("enemies"))
	check("deep Sami boxes reach every Sami box base", snow_box.all(func(id): return seen.has(id)), snow_box.filter(func(id): return not seen.has(id)))

	# Intrinsic stats, factor, price (§2.1).
	rng.seed = 24
	var plain := LootTables.roll_equipment(Item.Category.WEAPON, "x", "mine", 3, 1, rng)
	rng.seed = 24
	var axe := LootTables.roll_equipment(Item.Category.WEAPON, "断镐战斧", "mine", 3, 1, rng)
	var implicit := axe.modifiers.filter(func(m): return m.tier == GearCatalog.IMPLICIT_TIER)
	var random := axe.modifiers.filter(func(m): return m.tier != GearCatalog.IMPLICIT_TIER)
	check("断镐战斧 has its two intrinsic stats", implicit.size() == 2
		and implicit.any(func(m): return m.stat == ItemModifier.Stat.ATK_PCT and is_equal_approx(m.amount, 0.04))
		and implicit.any(func(m): return m.stat == ItemModifier.Stat.MOVE_SPEED_PCT and is_equal_approx(m.amount, -0.04)))
	check("intrinsics do not use the rarity's affix slots", random.size() == plain.modifiers.size(), [random.size(), plain.modifiers.size()])
	check("the power factor applies (×1.15)", is_equal_approx(axe.power, plain.power * 1.15), [axe.power, plain.power])
	check("intrinsics are not random affixes (no tier mark)", implicit.all(func(m): return not m.is_random_affix()))
	rng.seed = 25
	var purse := LootTables.roll_equipment(Item.Category.TRINKET, "龙门币钱夹", "city", 3, 0, rng)
	rng.seed = 25
	var other := LootTables.roll_equipment(Item.Category.TRINKET, "x", "city", 3, 0, rng)
	check("龙门币钱夹 sells for ×1.5", purse.value == roundi(other.value * 1.5), [purse.value, other.value])
	check("bases carry their flavour text", axe.description == B.mine_pickaxe.text)

	# Saves (§2.3).
	var back := Item.from_data(axe.to_data())
	check("base id and intrinsics survive a save", back.base_id == "mine_pickaxe" and back.modifiers.filter(func(m): return m.tier == GearCatalog.IMPLICIT_TIER).size() == 2)
	var migrated := Item.from_data(Item.create("镐柄战刃", Item.Category.WEAPON, 2, 1, 2.0).to_data())
	check("an old 镐柄战刃 loads as 断镐战斧 with a base id", migrated.item_name == "断镐战斧" and migrated.base_id == "mine_pickaxe")
	var generic := Item.create("外勤战刃", Item.Category.WEAPON, 2, 1, 2.0)
	generic.origin_region = "city"
	var g := Item.from_data(generic.to_data())
	check("an old generic 外勤战刃 from Lungmen becomes 近卫局警用刀", g.item_name == "近卫局警用刀" and g.base_id == "city_lgd_knife")
	check("exclusives get no base", Item.from_data(FieldCatalog.exclusive("city").to_data()).base_id.is_empty())

	print("\n%d/%d checks passed" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)
