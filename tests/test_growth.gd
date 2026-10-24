extends SceneTree

## 精英化与加点策划案_v0_2.md against real game state: levels and kill
## experience (paid on the spot), 作战记录 by kill count at settlement (counters,
## never items), feeding records, promotion with PRTS materials, the four
## attributes, the skill tree (caps, 专精, transmuters, respec), the module,
## gear grades and requirements, save round trips, and the tree's effects in
## combat (剑气, 日晷, 狼魂, 影步, 精神摧毁, Amiya's nodes).

var game: GameManager
var p: Player
var failures := 0
var checks := 0
var origin := Vector3(0, 0.7, -22)

func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool, seen: Variant = null) -> void:
	checks += 1
	if not passed and seen != null: print("   seen: ", seen)
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label)

func dummy(offset: Vector3, type: String = "thug", life: float = 100000.0) -> Enemy:
	var enemy := game._spawn_enemy(origin + offset, EnemyAttacks.is_elite_type(type), false, type)
	enemy.set_physics_process(false)
	enemy.max_health = life
	enemy.health = life
	enemy.defense = 0
	enemy.res = 0
	return enemy

func swing(enemy: Enemy, stage: int = 0) -> float:
	p._attack_cooldown = 0
	p.hitstop_remaining = 0
	p.dash_remaining = 0
	p.combo_step = stage
	p.combo_idle = 0
	var before := enemy.health
	p.attack(enemy)
	return before - enemy.health

func fresh(id: String) -> OperatorProgress:
	game.base.progress[id] = OperatorProgress.create(id)
	game.player._recompute_stats()
	return game.base.progress[id]

func stock(id: String, count: int) -> void:
	game.base.shelf.append(MaterialCatalog.create(id, count))

func run() -> void:
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	await step(4)
	_rules()
	_progress_rules()
	_base_actions()
	_requirements()
	_save()
	await game.start_contract("city")
	p = game.player
	game.set_process(false)
	p.set_physics_process(false)
	p._sprite.set_process(false)
	game._clear_field()
	await step(2)
	p.teleport(origin)
	await _kills()
	await _combat_lappland()
	await _combat_amiya()
	await _settlement()
	print("GROWTH RESULT: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)

func _rules() -> void:
	check("level caps are 60 / 80 / 90 (复利数值改造清单 J)", Progression.LEVEL_CAPS == [60, 80, 90])
	var e0 := 0
	for l in range(1, 60): e0 += Progression.exp_to_next(0, l)
	var e1 := 0
	for l in range(1, 80): e1 += Progression.exp_to_next(1, l)
	var e2 := 0
	for l in range(1, 90): e2 += Progression.exp_to_next(2, l)
	check("stage totals 32450 / 97960 / 185120: the n-th level-up of her career needs 250 × (1 + n / 25)", e0 == 32450 and e1 == 97960 and e2 == 185120
		and Progression.exp_to_next(0, 1) == 260 and Progression.exp_to_next(2, 89) == roundi(250 * (1 + 227 / 25.0)), [e0, e1, e2])
	check("experience keeps climbing across a promotion", Progression.exp_to_next(1, 1) == Progression.exp_to_next(0, 59) + 10
		and Progression.levels_before(1) == 59 and Progression.levels_before(2) == 138)
	check("points over a career: 30 / 40 / 45 attribute and 59 / 79 / 89 skill points by stage", Progression.level_attribute_points(0, 60) == 30
		and Progression.level_attribute_points(1, 80) == 70 and Progression.level_attribute_points(2, 90) == 115 and Progression.level_skill_points(0, 60) == 59
		and Progression.level_skill_points(2, 90) == 227 and Progression.level_attribute_points(0, 1) == 0 and Progression.level_skill_points(0, 1) == 0)
	check("kill exp 8/50/120/300, +25% a block", Progression.kill_exp("normal", 1) == 8 and Progression.kill_exp("elite", 1) == 50
		and Progression.kill_exp("leader", 1) == 120 and Progression.kill_exp("boss", 1) == 300 and Progression.kill_exp("elite", 11) == 63)
	var r := Progression.records_for({"normal": 27, "elite": 3, "leader": 1, "boss": 2})
	check("records by kill count: 10 normals → 1 basic, elite → 初级, leader → 中级, boss → 高级 (零头作废)",
		r == {"基础作战记录": 2, "初级作战记录": 3, "中级作战记录": 1, "高级作战记录": 2}, r)
	check("record exp is PRTS halved", Progression.RECORD_EXP == {"基础作战记录": 100, "初级作战记录": 200, "中级作战记录": 500, "高级作战记录": 1000})
	check("promotion recipes are PRTS 拉普兰德's (龙门币 ×0.84)", Progression.PROMOTION[1] == {"lmd": 22000, "materials": {"近卫芯片": 4, "装置": 3, "固源岩": 4}}
		and Progression.PROMOTION[2] == {"lmd": 168000, "materials": {"近卫双芯片": 3, "改量装置": 6, "异铁组": 10}})
	var sums := []
	for id in Progression.START:
		var total := 0
		for key in Progression.START[id]: total += int(Progression.START[id][key])
		sums.append(total)
	check("starting attributes sum to 40 for both", sums == [40, 40], sums)
	var sheet := Progression.attribute_sheet({"phy": 40, "tec": 12, "agi": 10, "arts": 8}, Progression.START.lappland)
	check("30 体魄 points: life and DEF +10.5%, regen +5.1 (shares now, no flat life)", is_equal_approx(float(sheet.hp_pct), 30 * 0.0035) and is_equal_approx(float(sheet.def_pct), 30 * 0.0035)
		and is_equal_approx(float(sheet.regen), 30 * 0.17) and not sheet.has("hp") and not sheet.has("def"), sheet)
	var tec := Progression.attribute_sheet({"phy": 10, "tec": 22, "agi": 10, "arts": 18}, Progression.START.lappland)
	check("技巧 and 源石技艺 points are shares too", is_equal_approx(float(tec.atk_pct), 10 * 0.0028) and is_equal_approx(float(tec.crit), 10 * 0.0007)
		and is_equal_approx(float(tec.arts_pct), 10 * 0.0038) and is_equal_approx(float(tec.res), 10 * 0.1) and not tec.has("atk") and not tec.has("arts"), tec)
	check("grades are the ten-floor tiers 1–10, whatever the layer", Progression.GRADE_MAX == 10 and Progression.grade_for(0, 1) == 1 and Progression.grade_for(2, 1) == 1
		and Progression.grade_for(1, 15) == 2 and Progression.grade_for(2, 25) == 3 and Progression.grade_for(2, 40, 1) == 5 and Progression.grade_for(0, 91) == 10
		and Progression.grade_for(0, 200, 3) == 10 and Progression.grade_for(0, 37) == Scaling.tier_of(37))
	var climbs := true
	for column in Progression.REQ_TABLE:
		var row: Array = Progression.REQ_TABLE[column]
		climbs = climbs and row.size() == 11 and int(row[1]) == 0
		for t in range(2, 11): climbs = climbs and int(row[t]) > int(row[t - 1])
	for t in range(2, 11): climbs = climbs and Progression.REQ_TABLE.heavy[t] > Progression.REQ_TABLE.light[t] and Progression.REQ_TABLE.light[t] > Progression.REQ_TABLE.gear[t]
	check("requirement table: 1 asks nothing, every column climbs, heavy > light > gear; 3–4 need 精英 1, 5 on 精英 2", climbs and Progression.REQ_TABLE.light[4] == 28
		and Progression.REQ_TABLE.heavy[4] == 34 and Progression.REQ_TABLE.gear[4] == 23 and Progression.REQ_ELITE.slice(1) == [0, 0, 1, 1, 2, 2, 2, 2, 2, 2])
	var sundial := SkillTrees.node(Operators.LAPPLAND, "sundial")
	var tx := SkillTrees.node(Operators.LAPPLAND, "wave_pack")
	check("fine ranks: ×5 ranks, rank 1 is the old 1, the top the old top", SkillTrees.max_rank(sundial) == 50 and is_equal_approx(SkillTrees.effect_rank(sundial, 1), 1.0)
		and is_equal_approx(SkillTrees.effect_rank(sundial, 50), 10.0) and is_equal_approx(SkillTrees.effect_rank(sundial, 0), 0.0) and SkillTrees.max_rank(tx) == 1
		and is_equal_approx(SkillTrees.effect_rank(tx, 1), 1.0) and SkillTrees.fine_rank(sundial, 10) == 50 and SkillTrees.fine_rank(sundial, 1) == 1)
	check("rank costs: 1, 2 from fine rank 35, a transmuter 10; labels 17/35 and 专精 6/15", SkillTrees.rank_cost(sundial, 34) == 1 and SkillTrees.rank_cost(sundial, 35) == 2
		and SkillTrees.rank_cost(tx, 0) == 10 and SkillTrees.rank_label(sundial, 17) == "17/35" and SkillTrees.rank_label(sundial, 41) == "专精 6/15"
		and SkillTrees.rank_elite(sundial, 19) == 0 and SkillTrees.rank_elite(sundial, 20) == 1 and SkillTrees.rank_elite(sundial, 35) == 2)
	check("专精 materials on reaching 40 / 45 / 50", SkillTrees.rank_materials(sundial, 39) == SkillTrees.MASTERY[0] and SkillTrees.rank_materials(sundial, 44) == SkillTrees.MASTERY[1]
		and SkillTrees.rank_materials(sundial, 49) == SkillTrees.MASTERY[2] and SkillTrees.rank_materials(sundial, 35).is_empty() and SkillTrees.rank_materials(sundial, 40).is_empty())

func _progress_rules() -> void:
	var g := OperatorProgress.create(Operators.LAPPLAND)
	check("a fresh operator: E0 Lv1, 剑气 rank 1 free, no points", g.elite == 0 and g.level == 1 and g.rank("wave") == 1 and g.skill_points == 0 and g.attribute_points == 0)
	var gained := g.add_exp(Progression.exp_to_next(0, 1) + Progression.exp_to_next(0, 2))
	check("two levels: a skill point each, an attribute point on the even one", gained == 2 and g.level == 3 and g.attribute_points == 1 and g.skill_points == 2 and g.exp == 0)
	g.add_exp(100000000)
	check("experience past the cap is lost", g.level == 60 and g.exp == 0 and g.at_cap() and g.add_exp(500) == 0)
	check("30 + 59 points by E0 max", g.attribute_points == 30 and g.skill_points == 59, [g.attribute_points, g.skill_points])
	check("a skill caps at fine rank 20 before 精英 1", _buy(g, "sundial", 25) == 20 and g.rank("sundial") == 20 and g.rank_block("sundial") == "需要精英 1" and g.skill_points == 39)
	check("a modifier needs its parent", g.rank_block("no_decay") == "需要精英 1")
	check("精英 1 nodes are locked at 精英 0", not g.rank_block("wolf_spirit").is_empty())
	g.promote()
	check("promotion: level 1, +2 / +2 points, 精英 1", g.elite == 1 and g.level == 1 and g.attribute_points == 32 and g.skill_points == 41)
	check("精英 1 opens fine ranks 21–35", _buy(g, "sundial", 20) == 15 and g.rank("sundial") == 35 and g.skill_points == 26)
	check("专精 needs 精英 2", g.rank_block("sundial") == "需要精英 2")
	g.add_exp(100000000)
	g.promote()
	g.skill_points = 30
	check("专精 costs 2 points a fine rank", g.add_rank("sundial") and g.rank("sundial") == 36 and g.skill_points == 28)
	check("transmuters are bought for 10 and the first one switches on", g.add_rank("wave_pack") and g.transmuter("wave") == "wave_pack" and g.skill_points == 18)
	check("a second transmuter needs another 10", g.add_rank("wave_fang") and g.skill_points == 8)
	check("a second transmuter is bought but not active until switched", g.transmuter("wave") == "wave_pack" and g.set_transmuter("wave", "wave_fang") and g.transmuter("wave") == "wave_fang")
	var refund := g.refundable_points()
	var before := g.skill_points
	g.reset_skills()
	check("respec gives every point back, 剑气 back to 1, no transmuter", g.skill_points == before + refund and g.rank("wave") == 1 and g.rank("sundial") == 0 and g.transmuter("wave") == "")
	check("attribute points cannot be refunded (no API) and spend one at a time", g.add_attribute("tec") and g.attribute("tec") == 13)
	check("module needs 精英 2 and goes to 3", g.module_block() == "" and (func(): g.upgrade_module(); g.upgrade_module(); g.upgrade_module(); g.upgrade_module(); return g.module_level == 3).call())

func _buy(g: OperatorProgress, id: String, times: int) -> int:
	var n := 0
	for i in range(times):
		if g.add_rank(id): n += 1
	return n

func _base_actions() -> void:
	var g := fresh(Operators.LAPPLAND)
	game.gold = 100000
	game.base.records = {"基础作战记录": 3}
	var fed := game.feed_record("基础作战记录", 5)
	var feed_cost := 3 * game.record_price("基础作战记录")
	check("feeding stops when the records run out, pays %s 龙门币 per exp" % Progression.LMD_PER_EXP, fed == 3 and feed_cost == roundi(300 * Progression.LMD_PER_EXP) and game.gold == 100000 - feed_cost and g.level == 2 and g.exp == 300 - Progression.exp_to_next(0, 1), [fed, game.gold, g.level, g.exp])
	check("records are counters, not shelf items", game.base.shelf.filter(func(x): return x.item_name.contains("作战记录")).is_empty() and int(game.base.records.get("基础作战记录", 0)) == 0)
	check("promotion needs the level cap", game.promotion_refusal() == "需要等级 60")
	g.add_exp(100000000)
	check("then the materials", game.promotion_refusal().begins_with("缺少"))
	stock("近卫芯片", 4)
	stock("装置", 3)
	stock("固源岩", 4)
	check("promotion takes 龙门币 and materials", game.promote_operator() and g.elite == 1 and game.gold == 100000 - feed_cost - int(Progression.PROMOTION[1].lmd) and game.material_count("近卫芯片") == 0)
	stock("近卫芯片组", 2)
	stock("芯片助剂", 1)
	check("双芯片 is crafted from 芯片组 ×2 + 芯片助剂", game.craft("近卫双芯片") and game.material_count("近卫双芯片") == 1 and game.material_count("近卫芯片组") == 0)
	var hp_before := game.player.max_hp
	var share := _hp_share()
	g.attribute_points = 5
	for i in range(5): game.add_attribute_point("phy")
	check("five 体魄 points: max HP +1.75% on the sheet", is_equal_approx(game.player.max_hp / hp_before, (share + 5 * 0.0035) / share), game.player.max_hp / hp_before)
	g.skill_points = 3
	game.add_skill_rank("sundial")
	game.add_skill_rank("sundial")
	var cost := Progression.respec_cost(g.refundable_points(), g.elite)
	var gold := game.gold
	check("respec costs 560 × (stage + 1) a point", game.respec_skills() and game.gold == gold - cost and cost == 2 * 1120 and g.skill_points == 3)
	g.elite = 2
	g.module_level = 0
	stock("模组数据块", 2)
	game.gold += 20000
	var atk := game.player.attack_power()
	var hp := game.player.max_hp
	var aspd := game.player.current_aspd()
	var hp_share := _hp_share()
	var module: Dictionary = SkillTrees.MODULES.lappland.stats
	check("the module unlocks and adds its PRTS stats as shares (ATK +6.7%, life +7.3%, 攻速 +6)", game.upgrade_module() and g.module_level == 1
		and is_equal_approx(game.player.attack_power() - atk, (CombatStats.BASE.atk + float(game.player.stats.get("atk", 0.0))) * 0.067)
		and is_equal_approx(game.player.max_hp / hp, (hp_share + 0.073) / hp_share) and is_equal_approx(game.player.current_aspd() - aspd, 6.0)
		and is_equal_approx(float(module.atk_pct), 0.067), [game.player.attack_power() - atk, game.player.max_hp / hp])
	fresh(Operators.LAPPLAND)

## 1 + every life share she has now (Player._recompute_stats), to compare max HP before and after.
func _hp_share() -> float:
	var pl := game.player
	return 1.0 + float(pl.stats.get("hp_pct", 0.0)) + (pl.kit.hp_pct() if pl.kit != null else 0.0)

func _requirements() -> void:
	var g := fresh(Operators.LAPPLAND)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var blade := LootTables.roll_equipment(Item.Category.WEAPON, "纠察队佩刀", "mine", 21, Item.BLUE, rng)
	check("a blade on floor 21 is 21–30 层 (its ten-floor tier), not in its name", blade.grade == 3 and Progression.grade_label(blade.grade) == "21–30 层" and blade.display_name().begins_with("精良 · "), blade.display_name())
	var req := Progression.requirement(blade)
	var need: int = Progression.REQ_TABLE.light[3]
	check("3 刃 asks 精英 1 and 技巧 on the light column", req.elite == 1 and req.attribute == "tec" and req.value == need and need == 21, req)
	check("an E0 operator is refused", Progression.refusal(blade, g) == "需要精英 1")
	g.elite = 1
	check("then by 技巧", Progression.refusal(blade, g) == "需要技巧 %d" % need)
	g.attributes.tec = need
	check("and accepted when both are met", Progression.refusal(blade, g) == "")
	var axe := LootTables.roll_equipment(Item.Category.WEAPON, "断镐战斧", "mine", 11, 0, rng)
	check("a heavy weapon on floor 11 is 2 and asks 体魄 on the heavy column", axe.grade == 2 and Progression.requirement(axe).attribute == "phy"
		and Progression.requirement(axe).value == Progression.REQ_TABLE.heavy[2] and Progression.REQ_TABLE.heavy[2] > Progression.REQ_TABLE.light[2])
	var suit := LootTables.roll_equipment(Item.Category.ARMOR, "矿场重型防护服", "mine", 11, 0, rng)
	check("heavy armour (移速 −4%) asks 体魄 on the heavy column", Progression.requirement(suit).attribute == "phy" and Progression.requirement(suit).value == Progression.REQ_TABLE.heavy_armor[2])
	var coat := LootTables.roll_equipment(Item.Category.ARMOR, "纠察队防寒大衣", "mine", 11, 0, rng)
	# A chest asks on the heavy column (装备部位拆分与数值案 §9); its 法抗 asks 源石技艺.
	check("法抗 chest asks 源石技艺 on the heavy column", Progression.requirement(coat).attribute == "arts" and Progression.requirement(coat).value == Progression.REQ_TABLE.heavy_armor[2])
	var early := LootTables.roll_equipment(Item.Category.WEAPON, "断镐战斧", "mine", 1, 0, rng)
	check("tier 1 gear asks no attribute", early.grade == 1 and Progression.requirement(early).value == 0 and Progression.refusal(early, OperatorProgress.create(Operators.LAPPLAND)) == "")
	var flask := LootTables.roll_equipment(Item.Category.TRINKET, "烈酒扁壶", "mine", 1, 0, rng)
	check("a T1 trinket asks nothing", flask.grade == 1 and Progression.requirement(flask).value == 0 and Progression.refusal(flask, OperatorProgress.create(Operators.LAPPLAND)) == "")
	var copy := Item.from_data(blade.to_data())
	check("grade survives a save round trip", copy.grade == blade.grade and copy.grade == 3)
	var old := blade.to_data()
	old.erase("grade")
	# A save that old is from before the ladder too: white / blue / gold.
	old.erase("ladder")
	old["rarity"] = 1
	check("gear saved before grades gets one from its layer and power", Item.from_data(old).grade >= 2)
	var hunter := LootTables.roll_equipment(Item.Category.WEAPON, "林线猎矛", "snow", 11, 0, rng)
	check("a polearm asks 技巧 on the heavy column", Progression.requirement(hunter).attribute == "tec" and Progression.requirement(hunter).value == Progression.REQ_TABLE.heavy[2])
	game.inventory.items.clear()
	fresh(Operators.LAPPLAND)
	var deep := LootTables.roll_equipment(Item.Category.WEAPON, "纠察队佩刀", "mine", 21, Item.BLUE, rng)
	game.inventory.try_add(deep)
	check("equipping from the pack refuses unmet requirements", not game.equip_from(deep, game.inventory) and game.player.equipped.get(Item.Category.WEAPON) != deep)
	game.inventory.items.clear()

func _save() -> void:
	var g := fresh(Operators.AMIYA_GUARD)
	g.add_exp(2000)
	g.add_attribute("arts")
	g.ranks["nightrun"] = 3
	game.base.records = {"中级作战记录": 4}
	var copy := BaseState.new()
	copy.load_data(game.base.to_data(), {})
	var c := copy.progress_for(Operators.AMIYA_GUARD)
	check("progress and records survive a save", c.level == g.level and c.exp == g.exp and c.attribute("arts") == 13 and c.rank("nightrun") == 3 and copy.records == {"中级作战记录": 4})
	var old := game.base.to_data()
	old.erase("progress")
	old.erase("records")
	copy.load_data(old, {})
	check("saves from before growth start everyone at 精英 0 Lv 1", copy.progress_for(Operators.LAPPLAND).level == 1 and copy.records.is_empty())
	game.base.progress.clear()
	game.base.records.clear()

func _kills() -> void:
	var g := fresh(Operators.LAPPLAND)
	game.run_kills = {}
	var foe := dummy(Vector3(1.5, 0, 0), "thug", 10.0)
	swing(foe)
	await step(2)
	check("a kill pays experience on the spot", g.exp == 8 and int(game.run_kills.get("normal", 0)) == 1, [g.exp, game.run_kills])
	g.exp = Progression.exp_to_next(0, 1) - 10
	var hp_before := p.max_hp
	var share := _hp_share()
	var elite := dummy(Vector3(1.5, 0, 0), "elite", 10.0)
	swing(elite)
	await step(2)
	check("an elite kill levels her up in the field", g.level == 2 and g.attribute_points == 1 and int(game.run_kills.get("elite", 0)) == 1)
	game.add_attribute_point("phy")
	check("points can be spent in the field", g.attribute("phy") == 11 and is_equal_approx(p.max_hp / hp_before, (share + 0.0035) / share), p.max_hp / hp_before)
	check("but records cannot be fed outside the base", game.feed_record("基础作战记录", 1) == 0)

func _combat_lappland() -> void:
	var g := fresh(Operators.LAPPLAND)
	p.reset_stats()
	p.teleport(origin)
	check("剑气 is hers without an affix", p.has_sword_wave())
	var plain := Item.create("测试刀", Item.Category.WEAPON, 2, 1, 0.0)
	plain.modifiers = [ItemModifier.trigger_mod(ItemModifier.Trigger.SWORD_WAVE)]
	p.equip(plain)
	check("the old 剑气 affix is now 剑气强化 +25%", is_equal_approx(p.wave_multiplier(), 1.25))
	p.unequip(Item.Category.WEAPON)
	check("剑气 rank sets the wave scale", is_equal_approx(SkillTrees.wave_scale(1), 1.5) and is_equal_approx(SkillTrees.wave_scale(7), 2.1))
	var foe := dummy(Vector3(1.5, 0, 0))
	var sundial := SkillTrees.node(Operators.LAPPLAND, "sundial")
	g.ranks["sundial"] = SkillTrees.fine_rank(sundial, 7)
	check("fine rank 34 reads as old rank 7.06 (rank 1 old 1, 50 old 10)", g.rank("sundial") == 34 and is_equal_approx(p.rank("sundial"), 1.0 + 33.0 * 9.0 / 49.0))
	g.ranks["sundial"] = SkillTrees.max_rank(sundial)
	var atk_before := p.attack_power()
	var eva_before := p.evasion()
	p.kit.cooldown = 0.0
	p.hitstop_remaining = 0
	check("日晷 is her Space: 专精 3 (fine rank 50) gives +70% ATK and +40% evasion for 8 s, 14 s cooldown", p.has_skill() and p.cast_skill(foe.global_position) and absf(p.attack_power() / atk_before - 1.70) < 0.001
		and absf(p.evasion() - eva_before - 0.40) < 0.001 and is_equal_approx(p.kit.timer, 8.0) and is_equal_approx(p.skill_cooldown_total(), 14.0), [p.attack_power() / atk_before, p.evasion(), p.skill_cooldown_total()])
	g.ranks["sundial"] = 18
	var blended: Array = SkillTrees.sundial(SkillTrees.effect_rank(sundial, 18))
	check("between old ranks the effect moves evenly", is_equal_approx(p.rank("sundial"), 1.0 + 17.0 * 9.0 / 49.0) and is_equal_approx(float(blended[0]), 0.30 + 0.04 * p.rank("sundial")))
	p.kit.reset()
	g.ranks["wolf_spirit"] = 1
	p.wolf_waves = 0
	for i in range(4): p._on_wave_released()
	check("狼魂: four waves start it, charge drops to 1 hit", p.wolf_timer > 5.9 and p.wave_hits_needed() == 1)
	var waves_now := p.wolf_waves
	p._on_wave_released()
	check("waves during 狼魂 do not count toward the next", p.wolf_waves == waves_now)
	foe.res = 0
	foe.defense = 300
	var arts_hit := swing(foe, 0)
	foe.defense = 0
	var bare_hit := swing(foe, 0)
	check("狼魂 turns her blade to arts (defence ignored, off arts power)", arts_hit > 0.0 and is_equal_approx(arts_hit, bare_hit) and arts_hit > CombatStats.physical(bare_hit, 300) * 1.3, [arts_hit, bare_hit])
	p.wolf_timer = 0
	g.ranks["shadow_step"] = SkillTrees.max_rank(SkillTrees.node(Operators.LAPPLAND, "shadow_step"))
	p.step_timer = 1.5
	check("影步 at its top (fine 25 = old 5): +50% crit after a dodge", g.rank("shadow_step") == 25 and p.step_timer > 0.0 and is_equal_approx(0.10 * p.rank("shadow_step"), 0.5))
	g.elite = 1
	var picket := dummy(Vector3(-1.5, 0, 0), "picket")
	swing(picket)
	check("精神摧毁 rides on her wave now: a blade hit does not silence", not picket.silenced())
	p.on_wave_hit(picket, 1.0, null)
	check("精神摧毁 (精英 1): her wave silences the target's abilities for 3 s", picket.silenced() and is_equal_approx(picket.silence_timer, 3.0))
	g.ranks["no_decay"] = SkillTrees.max_rank(SkillTrees.node(Operators.LAPPLAND, "no_decay"))
	p._spawn_wave(Vector3.FORWARD, 100.0, false, false)
	var wave: SwordWave = null
	for child in game.get_children():
		if child is SwordWave: wave = child
	check("远程攻击不再降低攻击力 at its top (fine 25): the wave keeps its damage", wave != null and is_zero_approx(wave.decay))
	g.ranks["wave_pack"] = 1
	g.transmuters["wave"] = "wave_pack"
	game._clear_field()
	await step(1)
	p.sword_charge = p.wave_hits_needed()
	p._attack_cooldown = 0
	p.hitstop_remaining = 0
	p.dash_remaining = 0
	p.attack_direction(Vector3.FORWARD)
	var count := game.get_children().filter(func(c): return c is SwordWave).size()
	check("狼群: the wave splits in three", count == 3, count)
	game._clear_field()
	await step(1)
	fresh(Operators.LAPPLAND)
	p.reset_stats()

func _combat_amiya() -> void:
	game.in_base = true
	game.choose_operator(Operators.AMIYA_GUARD)
	game.in_base = false
	var g := fresh(Operators.AMIYA_GUARD)
	p.reset_stats()
	p.teleport(origin)
	g.ranks["shadow"] = SkillTrees.max_rank(SkillTrees.node(Operators.AMIYA_GUARD, "shadow"))
	var foe := dummy(Vector3(1.5, 0, 0))
	check("绝影 at 专精 3 (fine 50 = old 10) cools down in 5 s", g.rank("shadow") == 50 and p.cast_shadow(foe.global_position) and is_equal_approx(p.shadow_cooldown, 5.0), p.shadow_cooldown)
	p._end_shadow(false)
	g.ranks["shadow_flash"] = 1
	g.transmuters["shadow"] = "shadow_flash"
	p.shadow_cooldown = 0
	p.cast_shadow(foe.global_position)
	check("一闪: a single strike", p._shadow_strikes_total == 1)
	p._end_shadow(false)
	g.elite = 2
	p._recompute_stats()
	p.fury_timer = 0.0
	var atk := p.attack_power()
	p.fury_timer = 3.0
	check("青色怒火 (精英 2) doubles for 3 s after 绝影", absf(p.attack_power() / atk - (1.0 + 0.14 + float(p.stats.get("atk_pct", 0.0))) / (1.0 + 0.07 + float(p.stats.get("atk_pct", 0.0)))) < 0.01)
	game.in_base = true
	game.choose_operator(Operators.LAPPLAND)
	game.in_base = false
	fresh(Operators.AMIYA_GUARD)

func _settlement() -> void:
	game.show_settlement_screen = false
	game.base.records = {}
	game.run_kills = {"normal": 23, "elite": 2, "boss": 1}
	game.inventory.try_add(MaterialCatalog.create("初级作战记录", 2))
	game.settle(false)
	await step(2)
	check("records are field drops now: kills pay none, and a death loses the ones in the pack", game.base.records.is_empty()
		and game.settlement_view.get("kills", {}) == {"normal": 23, "elite": 2, "boss": 1}, game.base.records)
	await game.start_contract("city")
	game.set_process(false)
	p.set_physics_process(false)
	game.inventory.try_add(MaterialCatalog.create("初级作战记录", 2))
	game.settle(true)
	await step(2)
	check("records brought out go to the counters", game.base.records == {"初级作战记录": 2}, game.base.records)
	check("the settlement view lists them", game.settlement_view.get("records", {}) == game.base.records)
	# 仓库修订: finds stay in her bags now, but 作战记录 still go only to the counters.
	check("nothing of them stayed in her bags or landed in the warehouse", (game.base.all_items() + game.carried_items()).filter(func(x): return str(x.item_name).contains("作战记录")).is_empty())
