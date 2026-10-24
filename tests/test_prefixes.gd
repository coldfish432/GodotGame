extends SceneTree

## Named prefixes and rolled numbers (装备前缀策划案_v1_1.md): the 150-entry
## table, the grade odds 15/20/30/30/5, the 20% second prefix and its limits,
## region weight, top prefixes' depth gate, set pieces without prefixes, every
## line inside its range, names and colours, value, saves and old saves, the
## sheet stats (reach, skill, the melee / ranged dodge, damage reduction), and
## the base's 重铸 / 校准 / 精调.

const Game = preload("res://game/game_manager.gd")

var failures := 0
var checks := 0

func _initialize() -> void: call_deferred("run")
func check(label: String, passed: bool, seen: Variant = null) -> void:
	checks += 1
	if not passed:
		failures += 1
		if seen != null: print("   seen: ", seen)
	print(("PASS " if passed else "FAIL ") + label)

func weapon(rng: RandomNumberGenerator, depth: int = 5, region: String = "mine", base: String = "断镐战斧", rarity: int = 2) -> Item:
	return LootTables.roll_equipment(Item.Category.WEAPON, base, region, depth, rarity, rng)

func run() -> void:
	var table := PrefixCatalog.all()
	# 150 less the nine that became families, plus 12 families × 3 (前缀放大与特效阶等案 §3).
	check("177 prefixes", table.size() == 177, table.size())
	var names := {}
	for id in table: names[str(table[id].name)] = true
	check("prefix names are unique", names.size() == table.size())
	var taken := {}
	for relic in RelicCatalog.all(): taken[str(relic.name)] = true
	for id in GearCatalog.BASES: taken[str(GearCatalog.BASES[id].name)] = true
	for id in SpecialGear.GEAR: taken[str(SpecialGear.GEAR[id].name)] = true
	check("no prefix shares a relic, base or special gear name", names.keys().all(func(n): return not taken.has(n)))
	check("every name ends in 的", names.keys().all(func(n): return str(n).ends_with("的")))
	var keys_ok := true
	for id in table:
		for key in table[id].stats:
			if not CombatStats.KEYS.has(key) or not PrefixCatalog.LABELS.has(key): keys_ok = false
		for key in table[id].fx:
			if not PrefixCatalog.FX_TEXT.has(key): keys_ok = false
	check("every stat is a sheet key with a label, every fx has text", keys_ok)
	var cover := true
	for slot in [PrefixCatalog.W, PrefixCatalog.A, PrefixCatalog.T]:
		for g in range(-2, 3):
			var n := table.keys().filter(func(id): return str(table[id].slots).contains(slot) and int(table[id].grade) == g and str(table[id].form).is_empty() and not bool(table[id].top)).size()
			if n < 2: cover = false
	check("every slot has at least two prefixes of every grade", cover)
	check("four top prefixes, all +2", table.keys().filter(func(id): return bool(table[id].top)).size() == 4 and table.keys().all(func(id): return not bool(table[id].top) or int(table[id].grade) == 2))

	# Odds (§0.1-11, §0.2-1).
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var counts := {-2: 0, -1: 0, 0: 0, 1: 0, 2: 0}
	var doubles := 0
	var family_rolls := 0
	var limits_ok := true
	var mine_region := 0
	const N := 6000
	for i in range(N):
		var item := weapon(rng)
		if item.prefixes.is_empty():
			limits_ok = false
			continue
		# The first rolled sits first unless the second outranks it; count all
		# grades from single-prefix pieces plus both of the doubles.
		for entry in item.prefixes:
			if PrefixFamilies.family_of(str(entry.id)).is_empty(): counts[PrefixCatalog.grade_of(entry)] += 1
			else: family_rolls += 1
		if item.prefixes.size() == 2:
			doubles += 1
			var a := PrefixCatalog.get_entry(str(item.prefixes[0].id))
			var b := PrefixCatalog.get_entry(str(item.prefixes[1].id))
			if item.prefixes[0].id == item.prefixes[1].id: limits_ok = false
			if not str(a.group).is_empty() and a.group == b.group: limits_ok = false
			if not str(a.region).is_empty() and not str(b.region).is_empty(): limits_ok = false
			if bool(a.top) and bool(b.top): limits_ok = false
			if PrefixCatalog.grade_of(item.prefixes[1]) > PrefixCatalog.grade_of(item.prefixes[0]): limits_ok = false
		for entry in item.prefixes:
			if str(PrefixCatalog.get_entry(str(entry.id)).region) == "mine": mine_region += 1
	var total := 0
	for g in counts: total += counts[g]
	var shares := {}
	for g in counts: shares[g] = float(counts[g]) / total
	check("grades come 15/20/30/30/5 (±1.5%)", absf(shares[-2] - 0.15) < 0.015 and absf(shares[-1] - 0.20) < 0.015 and absf(shares[0] - 0.30) < 0.015 and absf(shares[1] - 0.30) < 0.015 and absf(shares[2] - 0.05) < 0.015, shares)
	var all_rolls := family_rolls
	for g in counts: all_rolls += counts[g]
	check("about 15% of prefix rolls are an effect family's", absf(float(family_rolls) / all_rolls - PrefixCatalog.FAMILY_SHARE) < 0.02, float(family_rolls) / all_rolls)
	check("one piece in five has two prefixes (±2%)", absf(float(doubles) / N - 0.2) < 0.02, float(doubles) / N)
	check("always a prefix; doubles never repeat, share a group, two regions, two tops, or put the lower grade first", limits_ok)
	var city_region := 0
	rng.seed = 8
	for i in range(N):
		for entry in weapon(rng, 5, "city").prefixes:
			if str(PrefixCatalog.get_entry(str(entry.id)).region) == "mine": city_region += 1
	check("a region's prefixes are about 3× as common there", mine_region > city_region * 2.1, [mine_region, city_region])
	var early_top := false
	rng.seed = 9
	for i in range(3000):
		for entry in weapon(rng, 1).prefixes:
			if PrefixCatalog.is_top(entry): early_top = true
	check("no top prefix before depth 3", not early_top)
	var form_ok := true
	rng.seed = 10
	for i in range(2000):
		var axe := weapon(rng)
		for entry in axe.prefixes:
			var form := str(PrefixCatalog.get_entry(str(entry.id)).form)
			if not form.is_empty() and form != "heavy": form_ok = false
	check("form prefixes only on their form (断镐战斧 is heavy)", form_ok)

	# Which gear (§0.1-5, §0.2-5).
	var set_ids := SpecialGear.GEAR.keys().filter(func(id): return SpecialGear.kind(id) == "set")
	var ex_ids := SpecialGear.GEAR.keys().filter(func(id): return SpecialGear.kind(id) == "exclusive")
	var piece := SpecialGear.create(set_ids[0], 5, rng)
	check("set pieces carry no prefix", piece.prefixes.is_empty() and not PrefixCatalog.eligible_item(piece))
	check("special and exclusive gear carry prefixes", not SpecialGear.roll("mine", 5, rng).prefixes.is_empty() and not SpecialGear.create(ex_ids[0], 5, rng).prefixes.is_empty())
	check("materials carry none", MaterialCatalog.create("研磨石", 1, "mine").prefixes.is_empty())

	# Ranges (§2.8).
	var in_range := true
	var skill_seen := false
	rng.seed = 11
	for i in range(1500):
		var item := weapon(rng, 5, "mine", "断镐战斧", 2)
		if item.power < item.power_mid * 0.9 - 0.0001 or item.power > item.power_mid * 1.1 + 0.0001: in_range = false
		for mod in item.modifiers:
			var r := mod.roll_range()
			if r.is_empty(): continue
			if mod.amount < float(r[0]) - 0.0001 or mod.amount > float(r[1]) + 0.0001: in_range = false
			if mod.trigger == ItemModifier.Trigger.SWORD_WAVE:
				skill_seen = true
				if mod.amount < 0.2 - 0.0001 or mod.amount > 0.3 + 0.0001: in_range = false
		for entry in item.prefixes:
			for key in entry.rolls:
				if float(entry.rolls[key]) < 0.8 or float(entry.rolls[key]) > 1.2: in_range = false
	check("power, intrinsics, affixes, 技能强化 and prefix lines stay in their ranges", in_range and skill_seen)
	var affix_mean := [0.0, 0.0, 0.0]
	var affix_n := [0, 0, 0]
	for i in range(3000):
		for t in range(3):
			var mod := ItemModifier.roll_affix(ItemModifier.Stat.ATK_PCT, t, rng)
			affix_mean[t] += mod.amount / 0.08
			affix_n[t] += 1
	check("affix tiers keep their averages 70/100/130%", absf(affix_mean[0] / affix_n[0] - 0.7) < 0.01 and absf(affix_mean[1] / affix_n[1] - 1.0) < 0.01 and absf(affix_mean[2] / affix_n[2] - 1.3) < 0.01)
	check("percentages under 10 keep one decimal", ItemModifier.pct(0.027) == "+2.7%" and ItemModifier.pct(0.05) == "+5%" and ItemModifier.pct(0.123) == "+12%")

	# Names, colours (§2.1).
	var item := weapon(rng)
	item.prefixes = [PrefixCatalog.roll_entry("deadly", rng), PrefixCatalog.roll_entry("frenzying", rng)]
	check("names read 致命的·狂暴的·断镐战斧", item.display_name().ends_with("致命的·狂暴的·断镐战斧"), item.display_name())
	var runs := item.name_runs()
	check("each prefix in its grade colour, the base in the item's", runs[1][1] == PrefixCatalog.GRADE_COLORS[2] and runs[3][1] == PrefixCatalog.GRADE_COLORS[0] and runs.back()[1] == item.rarity_color())
	var named := item.duplicate() as Item
	named.prefixes = item.prefixes.duplicate(true)

	# Value (§2.5).
	item.prefixes = [PrefixCatalog.roll_entry("smuggled", rng)]
	PrefixCatalog.refresh_value(item)
	var smuggled := item.value
	item.prefixes = [{"id": "frenzying", "rolls": {"atk_pct": 1.0, "aspd": 1.0}}]
	PrefixCatalog.refresh_value(item)
	var ratio := float(smuggled) / item.value
	check("走私的 doubles the value", ratio > 1.85 and ratio < 2.15, [smuggled, item.value])
	item.prefixes = [{"id": "broken", "rolls": {"atk_pct": 1.0, "aspd": 1.0}}]
	PrefixCatalog.refresh_value(item)
	var broken_value := item.value
	item.prefixes = [{"id": "deadly", "rolls": {"atk_pct": 1.0, "aspd": 1.0}}]
	PrefixCatalog.refresh_value(item)
	check("a +2 prefix is worth more than a −2", item.value > broken_value * 1.5, [item.value, broken_value])

	# Saves (§0.2-6).
	var back := Item.from_data(item.to_data())
	check("prefixes, rolls and midpoints survive a save", back.prefixes == item.prefixes and is_equal_approx(back.power_mid, item.power_mid) and back.value == item.value
		and back.modifiers.filter(func(m): return m.tier == GearCatalog.IMPLICIT_TIER).all(func(m): return not is_zero_approx(m.mid) or ItemModifier.is_cost(m.stat, m.amount)))
	var old := item.to_data()
	old.erase("prefixes")
	check("an old save's gear rolls its prefixes on load", not Item.from_data(old).prefixes.is_empty())
	var old_set := piece.to_data()
	old_set.erase("prefixes")
	check("an old set piece stays without", Item.from_data(old_set).prefixes.is_empty())

	# The sheet (§2.7, §6).
	var game := Game.new()
	game.save_enabled = false
	root.add_child(game)
	await process_frame
	await process_frame
	check("the tooltip lists the prefix lines", ItemTooltip.text(game, named, false, false).contains("前缀"))
	var p: Player = game.player
	for category in [Item.Category.WEAPON, Item.Category.ARMOR, Item.Category.TRINKET]: p.unequip(category)
	var range_before := p.weapon_range()
	var wave_before := p.wave_multiplier()
	var ring := Item.create("x", Item.Category.TRINKET, 1, 1, 0.0)
	ring.prefixes = [{"id": "alert", "rolls": {"evasion_melee": 1.0}}, {"id": "sheltered", "rolls": {"dmg_reduce": 1.0}}]
	p.equip(ring)
	check("prefix stats reach the sheet", is_equal_approx(float(p.stats.evasion_melee), 0.04) and is_equal_approx(float(p.stats.dmg_reduce), 0.04))
	var melee := Enemy.new()
	var ranged := Enemy.new()
	ranged.keeps_distance = true
	check("melee dodge counts against melee enemies only", is_equal_approx(p.evasion_against("phys", melee), p.evasion() + 0.04) and is_equal_approx(p.evasion_against("phys", ranged), p.evasion()))
	check("true damage cannot be dodged", is_zero_approx(p.evasion_against("true", melee)))
	melee.free()
	ranged.free()
	var blade := Item.create("x", Item.Category.WEAPON, 2, 1, 0.0)
	blade.prefixes = [{"id": "large", "rolls": {"reach_pct": 1.0}}]
	p.equip(blade)
	check("攻击范围 lengthens her reach", is_equal_approx(p.weapon_range(), range_before * (1.0 + 0.10 * PrefixCatalog.WEAPON_SCALE)), [p.weapon_range(), range_before])
	var charm := Item.create("x", Item.Category.TRINKET, 1, 1, 0.0)
	charm.prefixes = [{"id": "snowpriest", "rolls": {"skill_pct": 1.0, "arts_pct": 1.0}}]
	p.equip(charm)
	check("技能伤害 raises skill damage", is_equal_approx(p.wave_multiplier(), wave_before + 0.2), [p.wave_multiplier(), wave_before])
	var boosted := Item.create("x", Item.Category.WEAPON, 2, 1, 0.0)
	boosted.modifiers = [ItemModifier.trigger_mod(ItemModifier.Trigger.SWORD_WAVE)]
	p.equip(boosted)
	check("an old 剑气强化 still gives 25% skill damage", is_equal_approx(p.wave_multiplier(), wave_before + 0.45), p.wave_multiplier())
	var wit := Item.create("x", Item.Category.TRINKET, 1, 1, 0.0)
	wit.prefixes = [{"id": "flowing", "rolls": {"skill_cd_pct": 1.0}}]
	p.equip(wit)
	check("技能冷却 shortens the skill", is_equal_approx(p.skill_cd_factor(), 0.84))
	p.clear_charge()
	var hits := 0
	for wave in range(4):
		p.sword_charge = 0
		while p.sword_charge < p.wave_hits_needed():
			p.add_charge(1)
			hits += 1
	check("…and waves fill on fewer hits", hits < 4 * Player.WAVE_HITS, hits)

	# The workbench (§2.5, §2.8).
	var gear := weapon(rng)
	game.inventory.try_add(gear)
	game.gold = 1000000
	game.stash.append(MaterialCatalog.create("研磨石", 5, "mine"))
	game.stash.append(MaterialCatalog.create("改量装置", 5, "mine"))
	game.in_base = true
	var ids_before: Array = gear.prefixes.map(func(e): return e.id)
	var gold_before: int = game.gold
	check("校准 is done at the base", game.refresh_gear("calibrate", gear))
	check("校准 keeps the prefixes and takes 龙门币 and a 研磨石", gear.prefixes.map(func(e): return e.id) == ids_before and game.gold < gold_before and game.material_count("研磨石") == 4)
	var lines := PrefixCatalog.rollable_lines(gear)
	var first_cost := game.refresh_cost("tune", gear)
	check("精调 one line", game.refresh_gear("tune", gear, lines[0]) and gear.tune_count == 1 and game.material_count("改量装置") == 4)
	check("each 精调 costs half as much again", game.refresh_cost("tune", gear) == roundi(maxi(GameManager.REFRESH_MIN_LMD, ceili(Economy.price(gear) * GameManager.REFRESH_SHARE)) * GameManager.TUNE_STEP))
	check("重铸 rolls the prefixes again", game.refresh_gear("reforge", gear) and not gear.prefixes.is_empty())
	game.in_base = false
	check("nothing is refreshed outside the base", not game.refresh_gear("calibrate", gear))
	var _unused := first_cost

	print("\n%d/%d checks passed" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)

