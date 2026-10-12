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
	check("level caps are PRTS 50/70/80 ÷ 5", Progression.LEVEL_CAPS == [10, 14, 16])
	var e0 := 0
	for l in range(1, 10): e0 += Progression.exp_to_next(0, l)
	var e1 := 0
	for l in range(1, 14): e1 += Progression.exp_to_next(1, l)
	var e2 := 0
	for l in range(1, 16): e2 += Progression.exp_to_next(2, l)
	check("stage totals 4500 / 18200 / 39750 (§4.1)", e0 == 4500 and e1 == 18200 and e2 == 39750, [e0, e1, e2])
	check("kill exp 8/50/120/300, +25% a block", Progression.kill_exp("normal", 1) == 8 and Progression.kill_exp("elite", 1) == 50
		and Progression.kill_exp("leader", 1) == 120 and Progression.kill_exp("boss", 1) == 300 and Progression.kill_exp("elite", 11) == 63)
	var r := Progression.records_for({"normal": 27, "elite": 3, "leader": 1, "boss": 2})
	check("records by kill count: 10 normals → 1 basic, elite → 初级, leader → 中级, boss → 高级 (零头作废)",
		r == {"基础作战记录": 2, "初级作战记录": 3, "中级作战记录": 1, "高级作战记录": 2}, r)
	check("record exp is PRTS halved", Progression.RECORD_EXP == {"基础作战记录": 100, "初级作战记录": 200, "中级作战记录": 500, "高级作战记录": 1000})
	check("promotion recipes are PRTS 拉普兰德's (龙门币 ×0.3)", Progression.PROMOTION[1] == {"lmd": 6000, "materials": {"近卫芯片": 4, "装置": 3, "固源岩": 4}}
		and Progression.PROMOTION[2] == {"lmd": 36000, "materials": {"近卫双芯片": 3, "改量装置": 6, "异铁组": 10}})
	var sums := []
	for id in Progression.START:
		var total := 0
		for key in Progression.START[id]: total += int(Progression.START[id][key])
		sums.append(total)
	check("starting attributes sum to 40 for both", sums == [40, 40], sums)
	var sheet := Progression.attribute_sheet({"phy": 40, "tec": 12, "agi": 10, "arts": 8}, Progression.START.lappland)
	check("30 体魄 points: HP +720, DEF +60, regen +15", is_equal_approx(sheet.hp, 720.0) and is_equal_approx(sheet.def, 60.0) and is_equal_approx(sheet.regen, 15.0), sheet)
	check("grades: layer + block, capped at 6", Progression.grade_for(0, 1) == 1 and Progression.grade_for(2, 1) == 3 and Progression.grade_for(1, 15) == 3
		and Progression.grade_for(2, 25) == 5 and Progression.grade_for(2, 40, 1) == 6)
	check("requirement table T4 刃 22 / 重 25 / 防具 19, T6 needs 精英 2", Progression.REQ_TABLE.light[4] == 22 and Progression.REQ_TABLE.heavy[4] == 25
		and Progression.REQ_TABLE.gear[4] == 19 and Progression.REQ_ELITE[6] == 2 and Progression.REQ_ELITE[4] == 1 and Progression.REQ_ELITE[3] == 0)

func _progress_rules() -> void:
	var g := OperatorProgress.create(Operators.LAPPLAND)
	check("a fresh operator: E0 Lv1, 剑气 rank 1 free, no points", g.elite == 0 and g.level == 1 and g.rank("wave") == 1 and g.skill_points == 0 and g.attribute_points == 0)
	var gained := g.add_exp(300 + 350)
	check("650 exp: two levels, one attribute and one skill point each", gained == 2 and g.level == 3 and g.attribute_points == 2 and g.skill_points == 2)
	g.add_exp(1000000)
	check("experience past the cap is lost", g.level == 10 and g.exp == 0 and g.at_cap() and g.add_exp(500) == 0)
	check("9 + 9 points by E0 max", g.attribute_points == 9 and g.skill_points == 9)
	check("a skill caps at 4 before 精英 1", _buy(g, "sundial", 5) == 4 and g.rank_block("sundial") == "需要精英 1")
	check("a modifier needs its parent", g.rank_block("no_decay") == "需要精英 1")
	check("精英 1 nodes are locked at 精英 0", not g.rank_block("wolf_spirit").is_empty())
	g.promote()
	check("promotion: level 1, +2 / +2 points, 精英 1", g.elite == 1 and g.level == 1 and g.attribute_points == 11 and g.skill_points == 7)
	check("精英 1 opens ranks 5–7", _buy(g, "sundial", 3) == 3 and g.rank("sundial") == 7)
	check("专精 needs 精英 2", g.rank_block("sundial") == "需要精英 2")
	g.add_exp(1000000)
	g.promote()
	g.skill_points = 20
	check("专精 1 costs 2 points", g.add_rank("sundial") and g.rank("sundial") == 8 and g.skill_points == 18)
	check("transmuters are bought for 2 and the first one switches on", g.add_rank("wave_pack") and g.transmuter("wave") == "wave_pack" and g.skill_points == 16)
	g.add_rank("wave_fang")
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
	check("feeding stops when the records run out, pays 0.5 龙门币 per exp", fed == 3 and game.gold == 100000 - 150 and g.exp == 0 and g.level == 2, [fed, game.gold, g.level, g.exp])
	check("records are counters, not shelf items", game.base.shelf.filter(func(x): return x.item_name.contains("作战记录")).is_empty() and int(game.base.records.get("基础作战记录", 0)) == 0)
	check("promotion needs the level cap", game.promotion_refusal() == "需要等级 10")
	g.add_exp(1000000)
	check("then the materials", game.promotion_refusal().begins_with("缺少"))
	stock("近卫芯片", 4)
	stock("装置", 3)
	stock("固源岩", 4)
	check("promotion takes 龙门币 and materials", game.promote_operator() and g.elite == 1 and game.gold == 100000 - 150 - 6000 and game.material_count("近卫芯片") == 0)
	stock("近卫芯片组", 2)
	stock("芯片助剂", 1)
	check("双芯片 is crafted from 芯片组 ×2 + 芯片助剂", game.craft("近卫双芯片") and game.material_count("近卫双芯片") == 1 and game.material_count("近卫芯片组") == 0)
	var hp_before := game.player.max_hp
	g.attribute_points = 5
	for i in range(5): game.add_attribute_point("phy")
	check("five 体魄 points: max HP +120 on the sheet", is_equal_approx(game.player.max_hp - hp_before, 120.0), game.player.max_hp - hp_before)
	g.skill_points = 3
	game.add_skill_rank("sundial")
	game.add_skill_rank("sundial")
	var cost := Progression.respec_cost(g.refundable_points(), g.elite)
	var gold := game.gold
	check("respec costs 200 × (stage + 1) a point", game.respec_skills() and game.gold == gold - cost and cost == 2 * 400 and g.skill_points == 3)
	g.elite = 2
	g.module_level = 0
	stock("模组数据块", 2)
	game.gold += 12000
	var atk := game.player.attack_power()
	check("the module unlocks and adds its PRTS stats", game.upgrade_module() and g.module_level == 1 and is_equal_approx(game.player.attack_power() - atk, 40.0 * (1.0 + float(game.player.stats.get("atk_pct", 0.0)))))
	fresh(Operators.LAPPLAND)

func _requirements() -> void:
	var g := fresh(Operators.LAPPLAND)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var blade := LootTables.roll_equipment(Item.Category.WEAPON, "纠察队佩刀", "mine", 21, 1, rng)
	check("a 中 blade on floor 21 is Ⅳ", blade.grade == 4 and blade.display_name().begins_with("Ⅳ · "), blade.display_name())
	var req := Progression.requirement(blade)
	check("Ⅳ 刃 asks 精英 1 and 技巧 22", req.elite == 1 and req.attribute == "tec" and req.value == 22, req)
	check("an E0 operator is refused", Progression.refusal(blade, g) == "需要精英 1")
	g.elite = 1
	check("then by 技巧", Progression.refusal(blade, g) == "需要技巧 22")
	g.attributes.tec = 22
	check("and accepted when both are met", Progression.refusal(blade, g) == "")
	var axe := LootTables.roll_equipment(Item.Category.WEAPON, "断镐战斧", "mine", 1, 0, rng)
	check("a deep heavy weapon on floor 1 is Ⅲ and asks 体魄 18 (heavy column)", axe.grade == 3 and Progression.requirement(axe).attribute == "phy" and Progression.requirement(axe).value == 18)
	var suit := LootTables.roll_equipment(Item.Category.ARMOR, "矿场重型防护服", "mine", 1, 0, rng)
	check("heavy armour (移速 −4%) asks 体魄 on the heavy column", Progression.requirement(suit).attribute == "phy" and Progression.requirement(suit).value == 18)
	var coat := LootTables.roll_equipment(Item.Category.ARMOR, "纠察队防寒大衣", "mine", 1, 0, rng)
	check("法抗 armour asks 源石技艺", Progression.requirement(coat).attribute == "arts" and Progression.requirement(coat).value == 11)
	var flask := LootTables.roll_equipment(Item.Category.TRINKET, "烈酒扁壶", "mine", 1, 0, rng)
	check("a T1 trinket asks nothing", flask.grade == 1 and Progression.requirement(flask).value == 0 and Progression.refusal(flask, OperatorProgress.create(Operators.LAPPLAND)) == "")
	var copy := Item.from_data(blade.to_data())
	check("grade survives a save round trip", copy.grade == 4)
	var old := blade.to_data()
	old.erase("grade")
	check("gear saved before grades gets one from its layer and power", Item.from_data(old).grade >= 2)
	var hunter := LootTables.roll_equipment(Item.Category.WEAPON, "林线猎矛", "snow", 1, 0, rng)
	check("a polearm asks 技巧 on the heavy column", Progression.requirement(hunter).attribute == "tec" and Progression.requirement(hunter).value == 12)
	game.inventory.items.clear()
	fresh(Operators.LAPPLAND)
	var deep := LootTables.roll_equipment(Item.Category.WEAPON, "纠察队佩刀", "mine", 21, 1, rng)
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
	var elite := dummy(Vector3(1.5, 0, 0), "elite", 10.0)
	swing(elite)
	await step(2)
	check("an elite kill levels her up in the field", g.level == 2 and g.attribute_points == 1 and int(game.run_kills.get("elite", 0)) == 1)
	game.add_attribute_point("phy")
	check("points can be spent in the field", g.attribute("phy") == 11 and is_equal_approx(p.max_hp - hp_before, 24.0))
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
	var base3 := swing(foe, 2)
	g.ranks["sundial"] = 7
	var with3 := swing(foe, 2)
	check("日晷 7: stage 3 +35% and 20% evasion for 4 s after", absf(with3 / base3 - 1.35) < 0.02 and p.sundial_timer > 3.9 and absf(p.evasion() - 0.20) < 0.001, [with3 / base3, p.evasion()])
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
	check("狼魂 turns her blade to arts (defence ignored)", arts_hit > p.attack_power() * 0.9, arts_hit)
	p.wolf_timer = 0
	g.ranks["shadow_step"] = 5
	p.step_timer = 1.5
	check("影步 5: +50% crit after a dodge", p.step_timer > 0.0 and is_equal_approx(0.10 * p.rank("shadow_step"), 0.5))
	g.elite = 1
	var picket := dummy(Vector3(-1.5, 0, 0), "picket")
	swing(picket)
	check("精神摧毁 (精英 1): her hit silences the target's abilities", picket.silenced())
	g.ranks["no_decay"] = 5
	p._spawn_wave(Vector3.FORWARD, 100.0, false, false)
	var wave: SwordWave = null
	for child in game.get_children():
		if child is SwordWave: wave = child
	check("远程攻击不再降低攻击力 5: the wave keeps its damage", wave != null and is_zero_approx(wave.decay))
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
	g.ranks["shadow"] = 7
	var foe := dummy(Vector3(1.5, 0, 0))
	check("绝影 7 cools down in 6.5 s", p.cast_shadow(foe.global_position) and is_equal_approx(p.shadow_cooldown, 6.5))
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
	game.settle(false)
	await step(2)
	check("settlement pays records by kill count even on death", game.base.records == {"基础作战记录": 2, "初级作战记录": 2, "高级作战记录": 1}, game.base.records)
	check("the settlement view lists them", game.settlement_view.get("records", {}) == game.base.records)
	check("nothing of them landed in the crates", game.base.crates.filter(func(c): return str(c.item.item_name).contains("作战记录")).is_empty())
