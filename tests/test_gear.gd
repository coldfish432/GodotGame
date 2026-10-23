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
	# 装备部位拆分与数值案 §7: + E15's 64 head, hands, legs, feet and ring bases.
	check("214 bases", B.size() == 214, B.size())
	for region in ["mine", "city", "snow"]:
		var counts := [0, 0, 0]
		for id in B:
			if B[id].region == region: counts[Item.group_of(int(B[id].category))] += 1
		# Armour = chest + head + hands + legs + feet, trinkets = amulet + ring.
		var want: Array = {"mine": [18, 26, 16], "city": [18, 26, 15], "snow": [18, 26, 16]}[region]
		check("%s has %d weapons, %d armour, %d trinkets" % [region, want[0], want[1], want[2]], counts == want, counts)
		for category in Item.SLOTS:
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
	# Intrinsics roll in the item's rarity band, a blue's 90–110% of the table;
	# its cost stays fixed (底材固有属性表 v1.0).
	check("断镐战斧 has its two intrinsic stats", implicit.size() == 2
		and implicit.any(func(m): return m.stat == ItemModifier.Stat.ATK_PCT and is_equal_approx(m.mid, 0.04) and m.band == 1 and m.amount >= 0.036 - 0.0001 and m.amount <= 0.044 + 0.0001)
		and implicit.any(func(m): return m.stat == ItemModifier.Stat.MOVE_SPEED_PCT and is_equal_approx(m.amount, -0.04) and not m.is_rollable()))
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
	check("a kit fills all eight slots", kit.map(func(i): return i.category) == Item.SLOTS, kit.map(func(i): return i.category))
	# 装备部位拆分与数值案 (用户 2026-10-21): eight slots, the same totals.
	var armour_share := 0.0
	for slot in Item.ARMOR_SLOTS: armour_share += GearSlots.panel(slot)
	var jewel_share := GearSlots.panel(Item.Category.AMULET) + GearSlots.panel(Item.Category.RING)
	var affix_sum := 0.0
	for slot in Item.SLOTS: if slot != Item.Category.WEAPON: affix_sum += GearSlots.affix(slot)
	check("five armour slots share one armour's panel, amulet + ring one trinket's", is_equal_approx(armour_share, 1.0) and is_equal_approx(jewel_share, 1.0), [armour_share, jewel_share])
	check("the seven non-weapon slots' affixes add up to the old two pieces", is_equal_approx(affix_sum, 2.0), affix_sum)
	var hp_full := 0.0
	for slot in Item.ARMOR_SLOTS: hp_full += float(CombatStats.power_stats(slot, 3.0).hp)
	check("a set of armour at one power gives one old armour's life", is_equal_approx(hp_full, 3.0 * CombatStats.ARMOR_HP_PER_POWER), hp_full)
	var old_armour := Item.create("矿工护甲", Item.Category.ARMOR, 2, 2, 3.0)
	old_armour.modifiers = [ItemModifier.stat_mod(ItemModifier.Stat.MAX_HP_PCT, 0.08)]
	var saved := old_armour.to_data()
	saved.erase("slots")
	var moved := Item.from_data(saved)
	var moved_affix: Array = moved.modifiers.filter(func(m): return m.is_random_affix())
	check("an old save's armour is a chest at the chest's own sizes", moved.category == Item.Category.CHEST and moved_affix.size() == 1
		and is_equal_approx(moved_affix[0].amount, 0.08 * FieldCatalog.slot_ratio(ItemModifier.Stat.MAX_HP_PCT, Item.Category.CHEST)), [moved.category, moved.modifiers.map(func(m): return m.amount)])
	check("…and its base's intrinsics come from the new table", moved.modifiers.any(func(m): return m.tier == GearCatalog.IMPLICIT_TIER and m.stat == ItemModifier.Stat.MAX_HP_PCT and m.amount >= 0.02 * 0.6 - 0.0001 and m.amount <= 0.02 * 0.8 + 0.0001))
	var fx_ok := true
	for slot in Item.SLOTS:
		var probe := Item.create("x", slot as Item.Category, 1, 1, 1.0)
		probe.grade = 3
		for id in PrefixCatalog.all():
			if (PrefixCatalog.all()[id].fx as Dictionary).is_empty(): continue
			if PrefixCatalog.fits(id, probe, [], true) and not slot in GearSlots.FX_SLOTS: fx_ok = false
	check("effect prefixes only roll on the weapon, chest and amulet", fx_ok)
	var drops := {}
	for i in range(4000):
		var slot := GearSlots.roll(srng)
		drops[slot] = int(drops.get(slot, 0)) + 1
	check("drops cover every slot, the weapon about a third", drops.size() == 8 and absf(float(drops[Item.Category.WEAPON]) / 4000.0 - 3.0 / 9.2) < 0.03, drops)
	# 复利数值改造清单 D: white until 制式换代, two tiers below the deepest camp, a fixed value.
	check("kit pieces are white Rhodes bases of tier Ⅰ", kit.all(func(i): return i.rarity == 0 and i.grade == 1 and GearCatalog.is_rhodes(i.base_id)))
	var badge := GearCatalog.make_rhodes("rhodes_badge", srng)
	check("Rhodes gear is worth a fixed 5", badge.value == GearCatalog.RHODES_VALUE and badge.value_base == GearCatalog.RHODES_VALUE)
	var late := GearCatalog.rhodes_kit(srng, Operators.AMIYA_GUARD, GearCatalog.rhodes_tier(50), 2)
	check("from the floor-50 camp the kit is tier Ⅳ, gold after 换代", late.all(func(i): return i.grade == 4 and i.rarity == 2))
	var made := Workshop.GEAR.values().map(func(r): return str(r.base))
	var rhodes_ids := B.keys().filter(func(id): return GearCatalog.is_rhodes(id))
	check("every Rhodes base has a 加工部 recipe", made.size() == rhodes_ids.size() and rhodes_ids.all(func(id): return id in made), [made.size(), rhodes_ids.size()])
	var heavy := {}
	for i in range(200):
		for piece in GearCatalog.rhodes_kit(srng, Operators.AMIYA_GUARD):
			if piece.base_id.ends_with("_heavy") or piece.base_id == "rhodes_ring_monitor": heavy[piece.base_id] = true
	check("kits also hand out the E16 protective line", heavy.size() == 5, heavy.keys())
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

	# Each slot's own sizes (部位词条数值表 v1.0) and intrinsics by look
	# (底材固有属性表 v1.0).
	var functional := [ItemModifier.Stat.MOVE_SPEED_PCT, ItemModifier.Stat.STAMINA_REGEN_PCT, ItemModifier.Stat.DASH_COST_PCT]
	var budget := 0.0
	var tables_cover := true
	for slot in FieldCatalog.SLOT_AFFIX_AMOUNTS:
		var combat: Array = []
		for stat in FieldCatalog.SLOT_AFFIX_AMOUNTS[slot]:
			if not stat in functional: combat.append(FieldCatalog.slot_ratio(stat, slot))
		var mean := 0.0
		for r in combat: mean += r
		budget += mean / combat.size()
		for stat in FieldCatalog.AFFIX_POOLS[slot]:
			if not (FieldCatalog.SLOT_AFFIX_AMOUNTS[slot] as Dictionary).has(stat): tables_cover = false
	check("the seven non-weapon slots' combat affixes still sum to 2.00 full affixes", absf(budget - 2.0) < 0.02, budget)
	check("every slot's pool has its own sizes", tables_cover)
	var boots := LootTables.roll_equipment(Item.Category.FEET, "外卖员跑鞋", "city", 1, 2, srng)
	var boot_affix := boots.modifiers.filter(func(m): return m.is_random_affix())
	var boots_ok := boot_affix.size() == 2
	for m in boot_affix:
		var size := absf(float(FieldCatalog.SLOT_AFFIX_AMOUNTS[Item.Category.FEET][m.stat]))
		if absf(m.amount) < size * 1.2 - 0.0001 or absf(m.amount) > size * 1.4 + 0.0001: boots_ok = false
	check("feet roll their own sizes in the gold band", boots_ok, boot_affix.map(func(m): return [m.stat, m.amount]))
	var boot_cost := boots.modifiers.filter(func(m): return m.tier == GearCatalog.IMPLICIT_TIER and m.stat == ItemModifier.Stat.DEF_FLAT)
	check("外卖员跑鞋's cost is a fixed 防御 −5", boot_cost.size() == 1 and is_equal_approx(boot_cost[0].amount, -5.0) and not boot_cost[0].is_rollable())
	var same := []
	var seen_sig := {}
	for id in B:
		var cat := int(B[id].category)
		if cat == Item.Category.WEAPON or str(B[id].region) == "rhodes": continue
		var sig := "%s|%d|%d|%s" % [B[id].region, cat, int(B[id].tier), str(B[id].implicit)]
		if seen_sig.has(sig): same.append([seen_sig[sig], id])
		seen_sig[sig] = id
	check("no two bases of one region, slot and layer share their intrinsics", same.is_empty(), same)
	var dice := LootTables.roll_equipment(Item.Category.AMULET, "老千骰子", "city", 1, 1, srng)
	check("老千骰子 rolls 装备掉率 in the blue band", dice.modifiers.any(func(m): return m.stat == ItemModifier.Stat.DROP_RATE_PCT and m.amount >= 0.075 * 0.9 - 0.0001 and m.amount <= 0.075 * 1.1 + 0.0001))
	check("…and reads 装备掉率", dice.modifiers.any(func(m): return m.describe().begins_with("装备掉率")))
	var gear_counts := {}
	var drop_rng := RandomNumberGenerator.new()
	for bonus in [0.0, 1.0]:
		drop_rng.seed = 77
		var n := 0
		for i in range(3000):
			var ctx := {"region": "mine", "depth": 5, "rng": drop_rng, "pity": {}, "set_seen": {}, "drop_pct": bonus}
			n += LootTables.enemy_drops("thug", false, false, ctx).filter(func(d): return d.has("item") and d.item.is_equippable() and d.item.special.is_empty()).size()
		gear_counts[bonus] = n
	check("装备掉率 +100% drops clearly more gear", gear_counts[1.0] > gear_counts[0.0] * 1.4, gear_counts)

	print("\n%d/%d checks passed" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)
