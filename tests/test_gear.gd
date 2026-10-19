extends SceneTree

## Equipment bases (装备策划案_v1_0.md §2, §4, §7): the table itself (105 bases,
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
	# 装备扩充策划案 §4.4: 39 + 63 + 3 polearms; §11 Siracusa 11 weapons; §10 Rhodes 9;
	# §12 ranged and staves 5 per region.
	check("145 bases", B.size() == 145, B.size())
	for region in ["mine", "city", "snow"]:
		var counts := [0, 0, 0]
		for id in B:
			if B[id].region == region: counts[int(B[id].category)] += 1
		var want: Array = {"mine": [18, 10, 12], "city": [18, 10, 11], "snow": [18, 11, 12]}[region]
		check("%s has %d weapons, %d armour, %d trinkets" % [region, want[0], want[1], want[2]], counts == want, counts)
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
	check("every weapon has a known form (§12)",
		B.values().all(func(b): return int(b.category) != Item.Category.WEAPON or GearCatalog.FORMS.has(str(b.form))))

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
	# City trinkets: five shallow, four mid, two deep → weights 9 × 1 + 2 × 2.
	check("the newest tier is drawn twice as often (≈ 4/13)", absf(deep / 3000.0 - 4.0 / 13.0) < 0.03, deep / 3000.0)

	# Enemy weapons and elites (§2.3).
	check("mine thugs carry 改装砍刀, city thugs 帮派砍刀", B[GearCatalog.pick(Item.Category.WEAPON, "mine", 1, "normal", "thug", rng)].name == "改装砍刀"
		and B[GearCatalog.pick(Item.Category.WEAPON, "city", 1, "normal", "thug", rng)].name == "帮派砍刀")
	check("crossbow leaders (city) carry 组长连弩", B[GearCatalog.pick(Item.Category.WEAPON, "city", 1, "normal", "crossbow_leader", rng)].name == "组长连弩")
	check("brawlers carry 指刃", B[GearCatalog.pick(Item.Category.WEAPON, "city", 1, "normal", "brawler", rng)].name == "指刃")
	check("ice hunters carry 冰原猎铳", B[GearCatalog.pick(Item.Category.WEAPON, "snow", 1, "normal", "ice_hunter", rng)].name == "冰原猎铳")
	for region in ["mine", "city", "snow"]:
		var id := GearCatalog.pick(Item.Category.WEAPON, region, 1, "elite", "elite", rng)
		check("%s elites drop the deep weapon「%s」" % [region, B[id].name], int(B[id].tier) == 2 and B[id].region == region)
	var real_drops := true
	var count := 0
	var c := ctx("mine", 1, 22)
	for i in range(600):
		for item in gear_of(LootTables.enemy_drops("crossbow", false, false, c)):
			count += 1
			if item.category == Item.Category.WEAPON and item.item_name != "整合运动手弩": real_drops = false
			if item.base_id.is_empty(): real_drops = false
	check("dropped gear carries a base id; crossbows drop 整合运动手弩", real_drops and count > 0, count)
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
	# Intrinsics roll within ±20% of the table (装备前缀策划案 §2.8).
	check("断镐战斧 has its two intrinsic stats", implicit.size() == 2
		and implicit.any(func(m): return m.stat == ItemModifier.Stat.ATK_PCT and is_equal_approx(m.mid, 0.04) and m.amount >= 0.032 - 0.0001 and m.amount <= 0.048 + 0.0001)
		and implicit.any(func(m): return m.stat == ItemModifier.Stat.MOVE_SPEED_PCT and is_equal_approx(m.mid, -0.04) and m.amount <= -0.032 + 0.0001 and m.amount >= -0.048 - 0.0001))
	check("intrinsics do not use the rarity's affix slots", random.size() == plain.modifiers.size(), [random.size(), plain.modifiers.size()])
	check("the power factor applies (×1.15)", is_equal_approx(axe.power_mid, plain.power_mid * 1.15), [axe.power_mid, plain.power_mid])
	check("intrinsics are not random affixes (no tier mark)", implicit.all(func(m): return not m.is_random_affix()))
	rng.seed = 25
	var purse := LootTables.roll_equipment(Item.Category.TRINKET, "龙门币钱夹", "city", 3, 0, rng)
	rng.seed = 25
	var other := LootTables.roll_equipment(Item.Category.TRINKET, "x", "city", 3, 0, rng)
	# Before prefixes and roll quality (PrefixCatalog.refresh_value).
	check("龙门币钱夹 sells for ×1.5", purse.value_base == roundi(other.value_base * 1.5), [purse.value_base, other.value_base])
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

	# 叙拉古 weapons (§11): its own table for weapons only.
	var sira := B.keys().filter(func(id): return B[id].region == "siracusa")
	check("Siracusa has 16 bases, all weapons", sira.size() == 16 and sira.all(func(id): return int(B[id].category) == Item.Category.WEAPON), sira.size())
	check("Siracusa weapons come from its own table", GearCatalog.eligible(Item.Category.WEAPON, "siracusa", 9, "normal").all(func(id): return B[id].region == "siracusa"))
	var sira_armour := GearCatalog.eligible(Item.Category.ARMOR, "siracusa", 9, "normal")
	check("Siracusa armour still comes from the other three", not sira_armour.is_empty() and sira_armour.all(func(id): return B[id].region in ["mine", "city", "snow"]))
	var srng := RandomNumberGenerator.new()
	srng.seed = 7
	check("a family soldier carries the stiletto", GearCatalog.pick(Item.Category.WEAPON, "siracusa", 1, "normal", "family_soldier", srng) == "sira_stiletto")
	check("a Siracusa elite drops a deep Siracusa weapon", int(B[GearCatalog.pick(Item.Category.WEAPON, "siracusa", 1, "elite", "family_eraser", srng)].tier) == 2)
	check("each Siracusa tier is open", [0, 1, 2].all(func(t): return sira.any(func(id): return int(B[id].tier) == t)))

	# 罗德岛制式装备 (§10): never dropped; a set per operator; 加工部 makes them.
	var never := true
	for region in ["mine", "city", "snow", "siracusa"]:
		for category in [Item.Category.WEAPON, Item.Category.ARMOR, Item.Category.TRINKET]:
			for source in ["normal", "elite", "vault"]:
				if GearCatalog.eligible(category, region, 30, source).any(func(id): return GearCatalog.is_rhodes(id)): never = false
	check("Rhodes gear never drops", never)
	var kit := GearCatalog.rhodes_kit(srng, Operators.AMIYA_GUARD)
	check("a kit is a weapon, an armour and a trinket", kit.map(func(i): return i.category) == [Item.Category.WEAPON, Item.Category.ARMOR, Item.Category.TRINKET])
	check("kit pieces are 精良 Rhodes bases", kit.all(func(i): return i.rarity == 1 and GearCatalog.is_rhodes(i.base_id)))
	srng.seed = 7
	var badge := GearCatalog.make_rhodes("rhodes_badge", srng)
	srng.seed = 7
	var plain_badge := LootTables.roll_equipment(Item.Category.TRINKET, "x", "city", GearCatalog.RHODES_DEPTH, 1, srng)
	check("Rhodes gear is worth ×1.5 to a buyer", badge.value_base == roundi(plain_badge.value_base * 1.5), [badge.value_base, plain_badge.value_base])
	check("every Rhodes base has a 加工部 recipe", Workshop.GEAR.size() == 9 and Workshop.GEAR.values().all(func(r): return GearCatalog.is_rhodes(str(r.base))))
	check("recipes use known materials", Workshop.GEAR.values().all(func(r): return r["in"].keys().all(func(m): return MaterialCatalog.MATERIALS.has(m))))

	# 远程与法杖 (§12): each region has 3 ranged and 2 staves; classes wield their own forms.
	for region in ["mine", "city", "snow", "siracusa"]:
		var ranged := B.keys().filter(func(id): return B[id].region == region and str(B[id].get("form", "")) in GearCatalog.RANGED_FORMS)
		var staves := B.keys().filter(func(id): return B[id].region == region and str(B[id].get("form", "")) == "staff")
		check("%s has 3 ranged weapons and 2 staves" % region, ranged.size() == 3 and staves.size() == 2, [ranged.size(), staves.size()])
	check("a crossbowman carries his crossbow", GearCatalog.pick(Item.Category.WEAPON, "mine", 1, "normal", "crossbow", srng) == "mine_r1")
	check("an ice hunter carries the hunting gun", GearCatalog.pick(Item.Category.WEAPON, "snow", 1, "normal", "ice_hunter", srng) == "snow_r2")
	var gun := LootTables.roll_equipment(Item.Category.WEAPON, "冰原猎铳", "snow", 4, 1, srng)
	var staff := LootTables.roll_equipment(Item.Category.WEAPON, "雪祀仪杖", "snow", 4, 1, srng)
	var blade := LootTables.roll_equipment(Item.Category.WEAPON, "猎刀", "snow", 4, 1, srng)
	check("a sniper wields a gun, not a blade or a staff", GearCatalog.can_wield("rosa", gun) and not GearCatalog.can_wield("rosa", blade) and not GearCatalog.can_wield("rosa", staff))
	check("a caster wields a staff only", GearCatalog.can_wield("lin", staff) and not GearCatalog.can_wield("lin", gun) and not GearCatalog.can_wield("lin", blade))
	check("a guard wields a blade, not a gun", GearCatalog.can_wield(Operators.LAPPLAND, blade) and not GearCatalog.can_wield(Operators.LAPPLAND, gun))
	check("armour fits everyone", GearCatalog.can_wield("lin", kit[1]))
	check("a sniper's kit carries the Rhodes crossbow", GearCatalog.rhodes_kit(srng, "rosa")[0].base_id == "rhodes_crossbow")
	check("a caster's kit carries the Rhodes staff", GearCatalog.rhodes_kit(srng, "santalla")[0].base_id == "rhodes_staff")
	check("a guard's kit carries a blade", GearCatalog.form_of(GearCatalog.rhodes_kit(srng, "hellagur")[0]) == "blade")

	print("\n%d/%d checks passed" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)
