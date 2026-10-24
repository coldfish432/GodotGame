extends SceneTree

## 属性伤害与地区装备策划案 v1.1: the rarity ladder grey → orange (+ red for
## named gear) and its old-save mapping, the floors instead of Roman tiers,
## the four elements and their resistances, the depth's 压制, enemies'
## resistances and the 克制 cycle, gauges and bursts, damage over time, her
## side (elemental share of hits, her gauge, stuns, map features), the regional
## affix tables, orange signatures and the resistance line, the regional
## prefixes and the 爆发 family, Rhodes standard gear grey → green → blue.

var game: GameManager
var checks := 0
var failures := 0
var origin := Vector3.ZERO

func _initialize() -> void: call_deferred("run")
func step(n: int = 2) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool, seen: Variant = null) -> void:
	checks += 1
	if not passed:
		failures += 1
		if seen != null: print("   seen: ", seen)
	print(("PASS " if passed else "FAIL ") + label)

func enemy(type: String) -> Enemy:
	var e := game._spawn_enemy(origin + Vector3(1.5, 0, 0), type == "elite", false, type)
	e.set_physics_process(false)
	return e

func run() -> void:
	_ladder()
	_labels()
	_arithmetic()
	game = GameManager.new()
	game.start_at_base = false
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	await step(10)
	origin = ContinuousWorldMap.ENTRY_POSITION
	origin.y = 0.65
	game.player.set_physics_process(false)
	game.pressure = 0
	SystemScreens.settings["auto_potion"] = false
	await _enemies()
	await _her()
	_affixes()
	_prefixes()
	_rhodes()
	print("DOWNFALL TEST_ELEMENTS: %d checks / %d failures" % [checks, failures])
	game.queue_free()
	await step(2)
	quit(1 if failures else 0)

# --- §2 ------------------------------------------------------------------------------

func _ladder() -> void:
	var colours := {}
	for c in Item.RARITY_COLORS: colours[c.to_html()] = true
	colours[Item.LEGEND_COLOR.to_html()] = true
	check("six colours: grey, green, blue, purple, orange and red; named gear is red too", colours.size() == 6 and Item.RARITY_COLORS.size() == 6 and Item.RARITY_COLORS[Item.RED] == Item.LEGEND_COLOR)
	check("the prefixes read the same ladder", PrefixCatalog.GRADE_COLORS[0] == Item.RARITY_COLORS[Item.GREEN] and PrefixCatalog.GRADE_COLORS[1] == Item.RARITY_COLORS[Item.BLUE]
		and PrefixCatalog.GRADE_COLORS[2] == Item.RARITY_COLORS[Item.PURPLE] and PrefixCatalog.TOP_COLOR == Item.RARITY_COLORS[Item.ORANGE])
	var bands_climb := true
	for i in range(1, Scaling.BANDS.size()): bands_climb = bands_climb and float(Scaling.BANDS[i][0]) >= float(Scaling.BANDS[i - 1][1]) - 0.0001
	check("six bands climb without overlap; blue stays 90–110%", bands_climb and is_equal_approx(Scaling.band_mid(Item.BLUE), 1.0))
	check("orange's floor is above the next tier's blue floor (always crosses)", float(Scaling.BANDS[Item.ORANGE][0]) > float(Scaling.BANDS[Item.BLUE][0]) * Scaling.TIER_GROWTH)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var lines_ok := true
	for r in range(6):
		var item := LootTables.roll_equipment(Item.Category.CHEST, "x", "", 5, r, rng)
		var random := item.modifiers.filter(func(m): return m.is_random_affix() and not m.stat in ItemModifier.RESISTS)
		lines_ok = lines_ok and random.size() == int(LootTables.AFFIX_LINES[r])
	check("lines per rarity 0 / 1 / 1 / 2 / 2 / 3", lines_ok)
	var red_rng := RandomNumberGenerator.new()
	red_rng.seed = 21
	var red := LootTables.roll_equipment(Item.Category.WEAPON, "断镐战斧", "snow", 15, Item.RED, red_rng)
	check("a random red drop: red name, 传说, three lines and its region's signature", red.rarity_color() == Item.LEGEND_COLOR and red.display_name().begins_with("传说")
		and red.modifiers.any(func(m): return m.stat == ItemModifier.Stat.SIG_SHATTER))
	# Saves before the ladder: white / blue / gold.
	var gold := LootTables.roll_equipment(Item.Category.WEAPON, "x", "mine", 5, Item.PURPLE, rng)
	var data := gold.to_data()
	data.erase("ladder")
	data["rarity"] = 2
	var low := data.duplicate(true)
	low["power"] = float(data.power_mid) * 1.2 / 1.225
	var high := data.duplicate(true)
	high["power"] = float(data.power_mid) * 1.39 / 1.225
	low["power_mid"] = float(data.power_mid) / 1.225 * 1.3
	high["power_mid"] = low["power_mid"]
	low["power"] = float(low.power_mid) * 1.2 / 1.3
	high["power"] = float(high.power_mid) * 1.39 / 1.3
	check("old gold low in its band is purple, high is orange", Item.from_data(low).rarity == Item.PURPLE and Item.from_data(high).rarity == Item.ORANGE,
		[Item.from_data(low).rarity, Item.from_data(high).rarity])
	var blue := data.duplicate(true)
	blue["rarity"] = 1
	var white := data.duplicate(true)
	white["rarity"] = 0
	check("old blue stays blue, old white is grey", Item.from_data(blue).rarity == Item.BLUE and Item.from_data(white).rarity == Item.GREY)
	check("a new save keeps its rarity", Item.from_data(gold.to_data()).rarity == Item.PURPLE)
	var shares := LootTables.quality_shares("normal", 0.0, 90)
	check("from floor 90 a normal enemy's purple + orange + red is still 5%, red a tenth of orange or less", absf(float(shares[3]) + float(shares[4]) + float(shares[5]) - 0.05) < 0.003
		and float(shares[5]) > 0.0 and float(shares[5]) < float(shares[4]) * 0.2, shares)

func _labels() -> void:
	check("tiers read as floors", Progression.grade_label(1) == "1–10 层" and Progression.grade_label(4) == "31–40 层" and Progression.grade_label(10) == "91+ 层")
	check("a cell's corner shows the tier's last floor", Progression.grade_corner(4) == "40" and Progression.grade_corner(10) == "91+")
	check("names carry no tier mark", not LootTables.roll_equipment(Item.Category.WEAPON, "x", "mine", 35, Item.BLUE, RandomNumberGenerator.new()).display_name().contains("4"))
	check("flasks are named without their tier", BaseCatalog.potion_name(BaseCatalog.POTIONS.keys()[0], 5) == str(BaseCatalog.POTIONS[BaseCatalog.POTIONS.keys()[0]].name))
	check("research tiers read 5 阶", ResearchCatalog.tier_label(5) == "5 阶")

# --- §3, §4, §9 ------------------------------------------------------------------------

func _arithmetic() -> void:
	check("elemental multiplier 1 − res/100, 10% to 150%", is_equal_approx(Elements.multiplier(0), 1.0) and is_equal_approx(Elements.multiplier(80), 0.2)
		and is_equal_approx(Elements.multiplier(-50), 1.5) and is_equal_approx(Elements.multiplier(-90), 1.5) and is_equal_approx(Elements.multiplier(100), 0.1))
	check("elements ignore DEF", is_equal_approx(CombatStats.mitigate(100.0, "burn", 9999.0, 0.0), 100.0) and is_equal_approx(CombatStats.mitigate(100.0, "bleed", 9999.0, 50.0), 50.0))
	check("the depth's 压制: none to 20, −5 every ten floors, −40 at most", Elements.penalty(20) == 0.0 and Elements.penalty(21) == 5.0 and Elements.penalty(45) == 15.0
		and Elements.penalty(91) == 40.0 and Elements.penalty(300) == 40.0)
	var mine := Elements.enemy_resists("mine", false, false)
	var elite := Elements.enemy_resists("mine", true, false)
	var boss := Elements.enemy_resists("mine", false, true)
	check("mine enemies: 侵蚀 50, weak to 寒冷 −5, the rest 20", is_equal_approx(mine.corr, 50.0) and is_equal_approx(mine.cold, -5.0) and is_equal_approx(mine.burn, 20.0))
	check("elites +10 on all; bosses 80 own, 5 on the weakness", is_equal_approx(elite.cold, 5.0) and is_equal_approx(boss.corr, 80.0) and is_equal_approx(boss.cold, 5.0))
	var cycle := true
	for region in Elements.LOCAL:
		var beaten_by: String = Elements.WEAKNESS[region]
		# The element that beats a region is some other region's own.
		cycle = cycle and Elements.LOCAL.values().has(beaten_by) and Elements.LOCAL[region] != beaten_by
	check("克制 cycle: 萨米 → 矿区 → 叙拉古 → 龙门 → 萨米", cycle and Elements.WEAKNESS.mine == "cold" and Elements.WEAKNESS.siracusa == "corr" and Elements.WEAKNESS.city == "nerve" and Elements.WEAKNESS.snow == "burn")
	var s := ElementState.new()
	s.apply_dot("bleed", 100.0, 4.0, "bleed")
	s.apply_dot("bleed", 50.0, 4.0, "bleed")
	var kept := float(s.dots.bleed.per_tick) * 8.0
	s.apply_dot("bleed", 200.0, 4.0, "bleed")
	check("a DoT never stacks: a weaker one is ignored, a stronger one replaces it", is_equal_approx(kept, 100.0) and is_equal_approx(float(s.dots.bleed.per_tick) * 8.0, 200.0))
	var g := ElementState.new()
	var burst := g.fill("cold", 50.0, 100.0, 8.0)
	var then := g.fill("cold", 60.0, 100.0, 8.0)
	check("a gauge bursts at its threshold and cools down", not burst and then and g.cooling("cold") and not g.fill("cold", 500.0, 100.0, 8.0))
	g.tick(9.0, 100.0)
	check("…and fills again after its cooldown", not g.cooling("cold"))

func _enemies() -> void:
	var e := enemy("thug")
	var dealt := e.take_hit(100.0, "corr")
	var weak := e.take_hit(100.0, "cold")
	check("a mine thug takes 50% 侵蚀 and 105% 寒冷", is_equal_approx(dealt, 50.0) and is_equal_approx(weak, 105.0), [dealt, weak])
	e.health = e.max_health
	var threshold := e.gauge_threshold()
	check("its gauge threshold is 20% of its life", is_equal_approx(threshold, e.max_health * 0.2))
	e.take_hit(threshold / 1.05 + 1.0, "cold")
	e._tick_elements(0.1)
	check("a full 寒冷 gauge freezes it", e.stun_timer > 0.0 and e.elements.cooling("cold") and e.statuses.has("frozen"), [e.stun_timer, e.elements.cooldowns])
	var before := e.health
	e.apply_dot("bleed", 400.0, 4.0)
	for i in range(8): e._tick_elements(0.5)
	check("流血 ticks its total over its seconds (cut by bleed resistance 0)", absf(before - e.health - 400.0) < 2.0, before - e.health)
	var c := enemy("thug")
	c.take_hit(c.gauge_threshold() / 0.5 + 1.0, "corr")
	c._tick_elements(0.1)
	check("侵蚀爆发 cuts its defence 15% for good", c.corr_stacks == 1 and is_equal_approx(c.effective_defense(), c.defense * 0.85))
	c.queue_free()
	e.queue_free()
	await step()

func _her() -> void:
	var p := game.player
	for slot in p.equipped.keys(): p.unequip(slot)
	p.invulnerable = false
	p.hp = p.max_hp
	# Her hits: an elemental part on top of the hit, its own number.
	var a := enemy("thug")
	var b := enemy("thug")
	p._deal(a, 1000.0, "phys", false)
	p.stats["add_cold"] = 0.06
	p._deal(b, 1000.0, "phys", false)
	var plain := a.max_health - a.health
	var added := b.max_health - b.health
	check("附加 6% 寒冷 adds 1000 × 6% × 105% on a mine thug", absf(added - plain - 63.0) < 0.5, [plain, added])
	p.stats["add_cold"] = 0.0
	p.stats["conv_cold"] = 0.25
	a.health = a.max_health
	p._deal(a, 1000.0, "phys", false)
	var conv := a.max_health - a.health
	check("转化 25% moves a quarter of the hit past DEF to 寒冷", absf(conv - (plain * 0.75 + 250.0 * 1.05)) < 0.5, [conv, plain])
	p.stats["conv_cold"] = 0.0
	# Hits on her: a caster's 侵蚀 share (half on floors 1–10) is cut by her resistance.
	var caster := enemy("caster")
	p.hp = p.max_hp
	var hp := p.hp
	p.take_damage(1000.0, "arts", caster)
	var open := hp - p.hp
	p.stats["res_corr"] = 80.0
	p.hp = p.max_hp
	p.elements.state.clear()
	p.take_damage(1000.0, "arts", caster)
	var guarded := p.max_hp - p.hp
	check("侵蚀抗性 80 cuts a caster's 侵蚀 share (a quarter on floor 1)", guarded < open and absf((open - guarded) - 1000.0 * 0.25 * 0.8 * (1.0 if true else 0.0)) < 260.0, [open, guarded])
	check("her resistance is gear less the floor's 压制, within −50 and 80", is_equal_approx(p.elements.res("corr"), 80.0))
	game.floor_number = 45
	check("…on floor 45 it is 65", is_equal_approx(p.elements.res("corr"), 65.0))
	check("…and an empty one is −15", is_equal_approx(p.elements.res("burn"), -15.0))
	game.floor_number = 1
	p.stats["res_corr"] = 0.0
	p.elements.state.clear()
	p.hp = p.max_hp
	p.elements._fill("corr", p.max_hp * 0.61)
	check("her full 侵蚀 gauge takes 10% of her defence this floor", p.hexes.has("corr_burst") and is_equal_approx(float(p.hexes.corr_burst.def), -0.10))
	p.clear_hex("corr_burst")
	p.stats["res_nerve"] = 50.0
	check("神经抗性 50 halves her stuns", is_equal_approx(p.elements.stun_factor(), 0.5))
	p.stats["res_cold"] = 80.0
	p.stats["cold_pct"] = -0.15
	check("寒冷抗性 and the 萨米 line slow the cold meter", is_equal_approx(p.elements.feature_mult("cold"), 0.85 * 0.6))
	for key in ["res_nerve", "res_cold", "cold_pct"]: p.stats[key] = 0.0
	# A damage over time on her ticks and is cut by her resistance.
	p.elements.state.clear()
	p.hp = p.max_hp
	p.elements.state.apply_dot("bleed", 300.0, 4.0, "bleed")
	for i in range(8): p.elements.tick(0.5)
	check("流血 on her ticks its whole total", absf(p.max_hp - p.hp - 300.0) < 2.0, p.max_hp - p.hp)
	# Regional affixes that ask about the fight.
	p.stats["full_hp_dmg"] = 0.25
	var fresh := enemy("thug")
	check("对满血敌人 +25%", is_equal_approx(p.elements.damage_mult(fresh), 1.25))
	fresh.health = fresh.max_health * 0.5
	check("…not once hurt", is_equal_approx(p.elements.damage_mult(fresh), 1.0))
	p.stats["full_hp_dmg"] = 0.0
	for x in [a, b, caster, fresh]: x.queue_free()
	await step()

# --- §7, §8 --------------------------------------------------------------------------

func _affixes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var mine_only := true
	var purple_has := true
	var any_regional := false
	var signature_ok := true
	var resist_ok := true
	var weapon_resist := false
	for i in range(300):
		var r: int = [Item.GREEN, Item.BLUE, Item.PURPLE, Item.ORANGE][i % 4]
		var w := LootTables.roll_equipment(Item.Category.WEAPON, "断镐战斧", "mine", 15, r, rng)
		var regional := w.modifiers.filter(func(m): return m.is_random_affix() and FieldCatalog.region_of_affix(m.stat, Item.Category.WEAPON) != "")
		any_regional = any_regional or not regional.is_empty()
		mine_only = mine_only and regional.all(func(m): return FieldCatalog.region_of_affix(m.stat, Item.Category.WEAPON, "mine") == "mine")
		if r >= Item.PURPLE: purple_has = purple_has and not regional.is_empty()
		var sigs := w.modifiers.filter(func(m): return ItemModifier.is_signature(m.stat))
		signature_ok = signature_ok and (sigs.size() == 1 and sigs[0].stat == ItemModifier.Stat.SIG_CASCADE if r == Item.ORANGE else sigs.is_empty())
		weapon_resist = weapon_resist or w.modifiers.any(func(m): return m.stat in ItemModifier.RESISTS)
		var chest := LootTables.roll_equipment(Item.Category.CHEST, "x", "snow", 15, Item.PURPLE, rng)
		resist_ok = resist_ok and chest.modifiers.any(func(m): return m.stat in ItemModifier.RESISTS)
	check("gear found in the mine rolls the mine's own lines, never another region's", any_regional and mine_only)
	check("purple and orange carry at least one regional line", purple_has)
	check("orange alone carries the region's signature (晶簇裂解 on a mine weapon)", signature_ok)
	check("a purple chest always has its resistance line, a weapon never", resist_ok and not weapon_resist)
	var staff_bleed := false
	for i in range(200):
		var staff := LootTables.roll_equipment(Item.Category.WEAPON, "雪祀仪杖", "city", 15, Item.PURPLE, rng)
		staff_bleed = staff_bleed or staff.modifiers.any(func(m): return m.stat == ItemModifier.Stat.BLEED_CHANCE)
	check("流血 lines want an edge or fists: a staff never rolls one", not staff_bleed)
	var local := 0
	var total := 0
	for i in range(1500):
		for mod in LootTables.roll_resist(Item.BLUE, "snow", rng):
			if mod.stat == ItemModifier.Stat.RES_ALL_ELEM: continue
			total += 1
			if mod.stat == ItemModifier.Stat.RES_COLD: local += 1
	check("a 萨米 resistance is 寒冷 about three times as often (3/7)", absf(float(local) / total - 3.0 / 7.0) < 0.05, float(local) / total)
	var ring := ItemModifier.roll_affix(ItemModifier.Stat.ADD_CORR, Item.BLUE, rng, 0.5, 1, Item.Category.RING)
	check("a ring's 附加侵蚀 is its own size (2.5%)", is_equal_approx(ring.amount, 0.025), ring.amount)
	var item := LootTables.roll_equipment(Item.Category.WEAPON, "断镐战斧", "mine", 15, Item.ORANGE, rng)
	var mark_ok := false
	for mod in item.modifiers:
		if ItemModifier.is_signature(mod.stat): mark_ok = ItemTooltip._affix_mark(item, mod).contains("◆")
	check("the tooltip marks a signature ◆", mark_ok)
	check("every new line has its text", ItemModifier.TEXTS.keys().all(func(s): var m := ItemModifier.stat_mod(s, 0.1 if not ItemModifier.is_signature(s) else 1.0); return not m.describe().is_empty() and not m.describe().contains("%s") and not m.describe().contains("%+d")))
	var boss := SpecialGear.create("bg_patriot_0", 21, rng, true)
	check("a boss weapon converts 35% to its region's element", boss.modifiers.any(func(m): return m.stat == ItemModifier.Stat.CONV_CORR and is_equal_approx(m.amount, SpecialGear.BOSS_CONVERT)))
	var cap := SpecialGear.create("bg_patriot_3", 21, rng, true)
	check("…its first chest lifts the elemental cap by 5", cap.modifiers.any(func(m): return m.stat == ItemModifier.Stat.RES_CAP and is_equal_approx(m.amount, 5.0)))

func _prefixes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var outside := false
	var inside := false
	for i in range(1500):
		var w := LootTables.roll_equipment(Item.Category.WEAPON, "断镐战斧", "city", 15, Item.BLUE, rng)
		if w.prefixes.any(func(e): return str(e.id) == "crystalline"): outside = true
		var m := LootTables.roll_equipment(Item.Category.WEAPON, "断镐战斧", "mine", 15, Item.BLUE, rng)
		if m.prefixes.any(func(e): return str(e.id) == "crystalline"): inside = true
	check("晶蚀的 appears only on gear found in the mine", inside and not outside)
	check("爆发 is the thirteenth family", PrefixFamilies.FAMILIES.has("burst") and PrefixFamilies.ORDER.back() == "burst")

func _rhodes() -> void:
	var grey := GearCatalog.make_rhodes("rhodes_sword", 0)
	var green := GearCatalog.make_rhodes("rhodes_sword", 1)
	var blue := GearCatalog.make_rhodes("rhodes_sword", 2)
	check("制式 grey → green → blue", grey.rarity == Item.GREY and green.rarity == Item.GREEN and blue.rarity == Item.BLUE and grey.power < green.power and green.power < blue.power)
	check("…and resists every element a little", blue.modifiers.any(func(m): return m.stat == ItemModifier.Stat.RES_ALL_ELEM))
	check("the research reads 灰 → 绿 → 蓝", str(ResearchCatalog.NODES.engineering_2[3]).contains("灰 → 绿") and str(ResearchCatalog.NODES.engineering_4[3]).contains("绿 → 蓝"))
