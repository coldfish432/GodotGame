extends SceneTree

## Effect prefix families and the stronger stat prefixes (前缀放大与特效阶等案
## _v1_0.md): the table, 阶等 by pieces worn, three at a time, the specials,
## the slot sizes, and 定向重铸 at 龙门.

var checks := 0
var failures := 0
var game: GameManager

func _initialize() -> void: call_deferred("run")

func check(label: String, passed: bool, seen: Variant = null) -> void:
	checks += 1
	if not passed:
		failures += 1
		if seen != null: print("   seen: ", seen)
	print(("PASS " if passed else "FAIL ") + label)

func piece(slot: int, prefix: String) -> Item:
	var item := Item.create("x", slot as Item.Category, 1, 1, 1.0)
	item.grade = 1
	item.prefixes = [{"id": prefix, "rolls": {}}]
	return item

## The family's prefix for `slot`'s kind.
func prefix_of(fam: String, slot: int) -> String:
	var kind := "W" if slot == Item.Category.WEAPON else ("A" if Item.is_armor_slot(slot) else "T")
	for p in PrefixFamilies.FAMILIES[fam].prefixes:
		if p[3] == kind: return p[0]
	return ""

func wear_all(fam: String, pieces: int) -> void:
	for slot in Item.SLOTS: game.player.unequip(slot as Item.Category)
	for i in range(pieces): game.player.equip(piece(Item.SLOTS[i], prefix_of(fam, Item.SLOTS[i])))

func run() -> void:
	# --- The table ---------------------------------------------------------------
	check("thirteen families (爆发 joined)", PrefixFamilies.FAMILIES.size() == 13 and PrefixFamilies.ORDER.size() == 13)
	var table_ok := true
	for fam in PrefixFamilies.FAMILIES:
		var kinds := {}
		for p in PrefixFamilies.FAMILIES[fam].prefixes:
			kinds[p[3]] = true
			var e := PrefixCatalog.get_entry(p[0])
			if e.is_empty() or str(e.family) != fam or int(e.grade) != 1 or not (e.stats as Dictionary).is_empty(): table_ok = false
		if kinds.size() != 3: table_ok = false
		if (PrefixFamilies.FAMILIES[fam].values as Array).size() != 5 or (PrefixFamilies.FAMILIES[fam].specials as Array).size() != 3: table_ok = false
	check("each has a W, an A and a T prefix of grade +1 without stats, five numbers and three specials", table_ok)
	check("the old effect prefixes joined their families", PrefixFamilies.family_of("riot") == "riot" and PrefixFamilies.family_of("abyssal") == "blood"
		and PrefixFamilies.family_of("knightly") == "hunter" and PrefixFamilies.family_of("inhibited") == "inhibit" and PrefixFamilies.family_of("sharp") == "")
	check("(4) keeps (3)'s number, (6) (5)'s, (8) (7)'s", is_equal_approx(PrefixFamilies.value("rampart", 4), 0.05) and is_equal_approx(PrefixFamilies.value("rampart", 6), 0.08)
		and is_equal_approx(PrefixFamilies.value("rampart", 8), 0.11) and is_zero_approx(PrefixFamilies.value("rampart", 0)))
	var lines5 := PrefixFamilies.lines("riot", 5)
	check("at (5): the number, (4) lit, (6) next and grey", lines5.size() == 3 and lines5[1][1] and not lines5[2][1] and str(lines5[2][0]).begins_with("（6）"), lines5)
	check("at (8) every special is lit", PrefixFamilies.lines("riot", 8).size() == 4 and PrefixFamilies.lines("riot", 8).all(func(l): return l[1]))
	check("labels read 暴动（3）", PrefixFamilies.label("riot", 3) == "暴动（3）")

	# --- 阶等 and the three at a time -------------------------------------------------
	var worn := {}
	var plan := [["riot", 3], ["blood", 2], ["rite", 2], ["hunter", 1]]
	var at := 0
	for entry in plan:
		for i in range(int(entry[1])):
			var slot: int = Item.SLOTS[at]
			worn[slot] = piece(slot, prefix_of(entry[0], slot))
			at += 1
	var counts := PrefixFamilies.count(worn)
	var active := PrefixFamilies.active(counts)
	check("阶等 counts the pieces", counts == {"riot": 3, "blood": 2, "rite": 2, "hunter": 1}, counts)
	check("three work: the highest, ties by the paper doll", active.keys() == ["riot", "blood", "rite"], active)

	# --- Stat prefixes by slot ------------------------------------------------------
	var probe_w := Item.create("x", Item.Category.WEAPON, 1, 1, 1.0)
	var probe_c := Item.create("x", Item.Category.CHEST, 1, 1, 1.0)
	var probe_h := Item.create("x", Item.Category.HANDS, 1, 1, 1.0)
	check("stat prefixes: weapon ×1.6, chest and amulet ×1.5, small pieces as written",
		is_equal_approx(PrefixCatalog.stat_scale(probe_w, "atk_pct"), 1.6) and is_equal_approx(PrefixCatalog.stat_scale(probe_c, "hp_pct"), 1.5)
		and is_equal_approx(PrefixCatalog.stat_scale(probe_h, "hp_pct"), 1.0))
	probe_h.prefixes = [{"id": "sturdy", "rolls": {"hp_pct": 1.0}}]
	check("厚实的 on the hands is 生命 +6%", is_equal_approx(float(PrefixCatalog.stats_of(probe_h).hp_pct), 0.06))
	var hands_fx := false
	for id in PrefixCatalog.all():
		if not str(PrefixCatalog.all()[id].family).is_empty() and PrefixCatalog.fits(id, probe_h, [], true): hands_fx = true
	check("family prefixes roll on the small pieces too", hands_fx)

	# --- On her -----------------------------------------------------------------------
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	game.fixed_market_seed = 77
	root.add_child(game)
	await process_frame
	await process_frame
	var p := game.player
	wear_all("rampart", 8)
	check("eight pieces of 坚壁 make 坚壁（8）", p.families.tier("rampart") == 8, p.families.tiers)
	check("…and its number is on the sheet: 受到伤害 −11%", is_equal_approx(float(p.stats.taken_pct), -0.11), p.stats.taken_pct)
	check("城垣 (6) blocks once, then waits 15 s", p.families.take_block() and not p.families.take_block())
	p.families.tick(15.1)
	check("…and is ready again", p.families.take_block())
	check("磐石 (4) cuts a big hit by another 30%", is_equal_approx(p.families.incoming(p.max_hp * 0.2), p.max_hp * 0.2 * 0.7) and is_equal_approx(p.families.incoming(10.0), 10.0))
	wear_all("blood", 3)
	check("嗜血（3）: 吸血 2%, nothing special yet", is_equal_approx(p.lifesteal(), 0.02) and not p.families.has_special("blood", 4))
	wear_all("blood", 4)
	p.hp = p.max_hp
	p.shield = 0.0
	p.families.on_lifesteal(50.0, 0.0)
	check("潮涌 (4): lifesteal over full life becomes a shield, at most 10%", is_equal_approx(p.shield, 50.0))
	p.families.on_lifesteal(p.max_hp, 0.0)
	check("…capped at 10% of life", is_equal_approx(p.shield, p.max_hp * 0.10))
	wear_all("rite", 6)
	check("术式（6）: 技能伤害 +15%", is_equal_approx(float(p.stats.skill_pct), 0.15), p.stats.skill_pct)
	var free := 0
	for i in range(2000):
		if p.families.on_skill(func(): pass): free += 1
	check("连咏 (6): about one cast in four costs no cooldown", absf(free / 2000.0 - 0.25) < 0.03, free / 2000.0)
	wear_all("fickle", 6)
	check("诡意（6）: three stats at ×1.0", p.families.fickle_keys.size() == 3 and is_equal_approx(p.families.fickle_mult(), 1.0))
	wear_all("fickle", 8)
	check("诡意（8）: ×2.6", is_equal_approx(p.families.fickle_mult(), 2.6))
	# Four families: the fourth does not work.
	for slot in Item.SLOTS: p.unequip(slot as Item.Category)
	var four := [["riot", 3], ["blood", 2], ["rite", 2], ["hunter", 1]]
	at = 0
	for entry in four:
		for i in range(int(entry[1])):
			p.equip(piece(Item.SLOTS[at], prefix_of(entry[0], Item.SLOTS[at])))
			at += 1
	check("on her, a fourth family is worn but does not work", p.families.worn.has("hunter") and not p.families.tiers.has("hunter") and is_zero_approx(float(p.stats.get("elite_pct", 0.0))))
	check("the tooltip shows 阶等 and 未生效", ItemTooltip.text(game, p.equipped[Item.SLOTS[7]], false, false).contains("猎首（1）") and ItemTooltip.text(game, p.equipped[Item.SLOTS[7]], false, false).contains("未生效"))

	# --- 定向重铸 ---------------------------------------------------------------------
	check("the odds start at 40% and climb an S curve to certain at the eighth failure",
		is_equal_approx(GameManager.directed_chance(0), 0.4) and GameManager.directed_chance(2) < GameManager.directed_chance(3) and GameManager.directed_chance(3) - GameManager.directed_chance(2) > GameManager.directed_chance(1) - GameManager.directed_chance(0)
		and GameManager.directed_chance(7) < 1.0 and is_equal_approx(GameManager.directed_chance(8), 1.0),
		range(9).map(func(n): return snappedf(GameManager.directed_chance(n), 0.01)))
	var target: Item = p.equipped[Item.Category.HANDS]
	target.prefixes = [{"id": "sturdy", "rolls": {"hp_pct": 1.0}}]
	game.base.ship_at = "龙门"
	game.voyage.sailing = {}
	check("refused below 龙门商会's top rank", game.directed_refusal(target, "riot").begins_with("需要龙门商会关系"), game.directed_refusal(target, "riot"))
	game.exchange.add_relation("lungmen", Exchange.RELATION_MAX)
	game.base.ship_at = "萨米"
	check("refused away from 龙门", game.directed_refusal(target, "riot") == "需要停靠龙门")
	game.base.ship_at = "龙门"
	check("refused for a family she does not wear", game.directed_refusal(target, "forest") == "未装备该族")
	game.gold = 10000000
	check("refused without 玄纹墨", not game.directed_refusal(target, "riot").is_empty())
	game.base.shelf.append(MaterialCatalog.create(GameManager.DIRECTED_MATERIAL, 3))
	check("…open with it", game.directed_refusal(target, "riot").is_empty(), game.directed_refusal(target, "riot"))
	var rng := RandomNumberGenerator.new()
	game.base.directed_fails = 0
	# A seed whose first draw misses 40%.
	var seed := 0
	while true:
		rng.seed = seed
		if rng.randf() >= 0.4: break
		seed += 1
	rng.seed = seed
	var gold_before := game.gold
	var cost := game.directed_cost(target)
	var result := game.directed_reforge(target, "riot", rng)
	check("a failure leaves the piece as it was, keeps the 龙门币 and counts", result == "fail" and target.prefixes[0].id == "sturdy" and game.gold == gold_before - cost and game.base.directed_fails == 1,
		[result, target.prefixes, game.gold - gold_before, game.base.directed_fails])
	game.base.directed_fails = GameManager.DIRECTED_CERTAIN
	result = game.directed_reforge(target, "riot", rng)
	check("at 100% it turns the prefix into the family and the count starts over", result == "success" and PrefixFamilies.family_of(str(target.prefixes[0].id)) == "riot" and game.base.directed_fails == 0,
		[result, target.prefixes])
	check("…and 暴动 rises a 阶等", int(p.families.worn.get("riot", 0)) == 4, p.families.worn)
	check("龙门商会 sells 玄纹墨", game.exchange.quote_buy("lungmen", GameManager.DIRECTED_MATERIAL).ok)

	print("\n%d/%d checks passed" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)
