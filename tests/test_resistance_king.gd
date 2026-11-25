extends SceneTree

## 抗性为王修订案 v0.4 (用户 2026-11-25: 全部按默认): enemies carry elements
## more often the deeper (打的是 / 附带), one main and three others per region,
## deep elites two at once, bosses their region's on every hit and more per
## phase, big hits 80% elemental at the floor's size, 减抗 off the overflow,
## −50 / −25 压制, doubled resistance lines, research, flasks, 镶件, 元素异变.

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

func run() -> void:
	_tables()
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
	await _spawning()
	await _hits()
	await _big_and_shred()
	_penalty()
	_supply()
	await _inlays()
	await _boss_phase()
	_route()
	print("DOWNFALL TEST_RESISTANCE_KING: %d checks / %d failures" % [checks, failures])
	game.queue_free()
	await step(2)
	quit(1 if failures else 0)

func _tables() -> void:
	check("chance: 10% on floor 1, elites +20, ~67% on floor 90, 75% at most",
		is_equal_approx(ElementThreat.chance(1, false), 0.10) and is_equal_approx(ElementThreat.chance(1, true), 0.30)
		and absf(ElementThreat.chance(90, false) - 0.6785) < 0.001 and is_equal_approx(ElementThreat.chance(200, false), 0.75)
		and is_equal_approx(ElementThreat.chance(200, true), 0.95) and is_equal_approx(ElementThreat.chance(1, false, true), 0.20))
	var w := ElementThreat.weights("city")
	check("龙门: 灼燃 45, 神经 (beats it) 25, the other two 15",
		is_equal_approx(w.burn, 0.45) and is_equal_approx(w.nerve, 0.25) and is_equal_approx(w.corr, 0.15) and is_equal_approx(w.cold, 0.15), w)
	var surged := ElementThreat.weights("city", "cold")
	check("寒冷异变 in 龙门: +30 points, scaled back to 100", absf(surged.cold - 45.0 / 130.0) < 0.0001 and absf(surged.burn - 45.0 / 130.0) < 0.0001
		and absf(float(surged.values().reduce(func(a, b): return a + b)) - 1.0) < 0.0001, surged)
	check("shares ramp: 打的是 40% → 70%, 附带 15% → 32% over 100 floors",
		is_equal_approx(ElementThreat.convert_share(1), 0.40) and is_equal_approx(ElementThreat.convert_share(101), 0.70)
		and is_equal_approx(ElementThreat.add_share(1), 0.15) and is_equal_approx(ElementThreat.add_share(101), 0.32))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var armed := 0
	var converts := 0
	var main := 0
	for i in range(4000):
		var spec := ElementThreat.roll(90, "mine", false, "", false, rng)
		if spec.is_empty(): continue
		armed += 1
		if spec.mode == "convert": converts += 1
		if spec.kinds[0] == "corr": main += 1
	check("floor 90: about 68% carry, 60% of them 打的是, 45% 侵蚀 in 矿区",
		absf(armed / 4000.0 - 0.6785) < 0.03 and absf(float(converts) / armed - 0.6) < 0.04 and absf(float(main) / armed - 0.45) < 0.04, [armed, converts, main])
	var dual_ok := true
	var single_ok := true
	for i in range(300):
		var deep := ElementThreat.roll(51, "snow", true, "", false, rng)
		if not deep.is_empty(): dual_ok = dual_ok and deep.kinds.size() == 2 and deep.kinds[0] != deep.kinds[1]
		var shallow := ElementThreat.roll(50, "snow", true, "", false, rng)
		if not shallow.is_empty(): single_ok = single_ok and shallow.kinds.size() == 1
	check("elites: one element to floor 50, two different ones from 51", dual_ok and single_ok)
	check("big hit floor: half the reference life on floor 1, 1.07× from 81 (用户: 推迟到 81 层)",
		is_equal_approx(ElementThreat.big_floor(1), 0.5 * 3400.0) and is_equal_approx(ElementThreat.big_share(81), 1.07)
		and is_equal_approx(ElementThreat.big_share(41), 0.785) and is_equal_approx(ElementThreat.big_floor(92), 1.07 * 8590.0))

func _spawning() -> void:
	game.floor_number = 90
	var armed := 0
	var total := 0
	for i in range(60):
		var e := game._spawn_enemy(origin + Vector3(2.0 + i * 0.05, 0, 0), false, false, "thug")
		e.set_physics_process(false)
		total += 1
		if not e.elem_spec.is_empty(): armed += 1
		e.queue_free()
	check("spawned on floor 90: most thugs carry elements", armed > 25 and armed < 55, armed)
	var caster := game._spawn_enemy(origin + Vector3(2, 0, 0), false, true, "caster")
	caster.set_physics_process(false)
	check("an enemy with its own elements (术师) keeps them, no roll", caster.elem_spec.is_empty())
	caster.queue_free()
	await step()

func enemy(type: String, spec: Dictionary, elite := false) -> Enemy:
	var e := game._spawn_enemy(origin + Vector3(1.5, 0, 0), elite, false, type)
	e.set_physics_process(false)
	e.elem_spec = spec
	return e

func clear_res() -> void:
	var p := game.player
	for key in Elements.RES_KEYS + ["res_all_elem", "res_cap", "shred_taken", "gauge_taken", "burst_taken", "boss_taken", "slow_taken"]: p.stats[key] = 0.0
	p.hexes.clear()
	p.elements.shred.clear()

func _hits() -> void:
	var p := game.player
	game.floor_number = 51
	clear_res()
	var raw := 1000.0
	var e := enemy("thug", {"mode": "convert", "kinds": ["burn", "cold"]})
	var share := ElementThreat.convert_share(51)
	var phys := CombatStats.mitigate(raw * (1.0 - share), "phys", p.defense_value(), p.resistance())
	var kept := CombatStats.mitigate(1.0, "phys", p.defense_value(), p.resistance())
	var each := raw * share * 0.5 * kept
	var expected := phys + each * ElementThreat.convert_taken(p.elements.res("burn")) + each * ElementThreat.convert_taken(p.elements.res("cold"))
	check("打的是 with two elements: the share split evenly (scaled to the cap), the rest physical", absf(p.elements.mitigate(raw, "phys", e) - expected) < 0.01, [p.elements.mitigate(raw, "phys", e), expected])
	p.stats.res_burn = 200.0
	p.stats.res_cold = 200.0
	var plain_hit := CombatStats.mitigate(raw, "phys", p.defense_value(), p.resistance())
	check("§8-9: with both capped at 80 it costs what a plain hit did", absf(p.elements.mitigate(raw, "phys", e) - plain_hit) < 0.01, [p.elements.mitigate(raw, "phys", e), plain_hit])
	p.stats.res_burn = 0.0
	p.stats.res_cold = 0.0
	check("降一档: ×3 at 0, ×2.25 at 30, ×1 at the cap", is_equal_approx(ElementThreat.convert_taken(0.0), 3.0) and is_equal_approx(ElementThreat.convert_taken(30.0), 2.25) and is_equal_approx(ElementThreat.convert_taken(80.0), 1.0))
	e.elem_spec = {"mode": "add", "kinds": ["corr"]}
	var plain := CombatStats.mitigate(raw, "phys", p.defense_value(), p.resistance())
	var added := raw * ElementThreat.add_share(51) * Elements.multiplier(p.elements.res("corr"))
	check("附带: the whole hit physical plus its element on top", absf(p.elements.mitigate(raw, "phys", e) - (plain + added)) < 0.01)
	p.stats.res_corr = 200.0
	var capped := p.elements.mitigate(raw, "phys", e)
	check("…and capped resistance takes the 附带 down to a fifth", absf(capped - (plain + raw * ElementThreat.add_share(51) * 0.2)) < 0.01, capped)
	clear_res()
	e.queue_free()
	await step()

func _big_and_shred() -> void:
	var p := game.player
	game.floor_number = 90
	clear_res()
	var bully := enemy("bully", {"mode": "convert", "kinds": ["burn"]}, true)
	bully.attack_phase = "strike"
	check("an elite's unbreakable charge is its big hit", bully.big_hit_now())
	var big := ElementThreat.big_floor(90)
	p.stats.res_burn = 200.0   # well over: capped at 80 after the 压制
	var phys := CombatStats.mitigate(big * 0.2, "phys", p.defense_value(), p.resistance())
	var hit := p.elements.mitigate(10.0, "phys", bully)
	check("a big hit is lifted to the floor's size, 80% elemental: capped ≈ 0.2 × 0.8 + its physical part",
		absf(hit - (phys + big * 0.8 * 0.2)) < 0.5, [hit, phys + big * 0.8 * 0.2])
	var ratio_capped := (phys + big * 0.8 * 0.2) / ElementThreat.ref_life(90)
	p.stats.res_burn = Elements.penalty(90)   # 0 after the 压制
	var bare := p.elements.mitigate(10.0, "phys", bully)
	check("vs the reference life: ~30% capped, ~100% at 0 (§3.5)", ratio_capped > 0.2 and ratio_capped < 0.4 and bare / ElementThreat.ref_life(90) > 0.85, [ratio_capped, bare / ElementThreat.ref_life(90)])
	# 减抗: two big hits = two stacks, −15 each, off the overflow first.
	clear_res()
	p.stats.res_burn = 80.0 + Elements.penalty(90) + 20.0   # 20 over the cap
	p.elements.mitigate(10.0, "phys", bully)
	check("one stack takes 15 of the 20 over: still capped", is_equal_approx(p.elements.res("burn"), 80.0) and is_equal_approx(p.elements.res_over("burn"), 5.0), [p.elements.res("burn"), p.elements.res_over("burn")])
	p.elements.mitigate(10.0, "phys", bully)
	p.elements.mitigate(10.0, "phys", bully)
	check("at most two stacks: 30 off, 10 under the cap", is_equal_approx(p.elements.res("burn"), 70.0), p.elements.res("burn"))
	p.stats.shred_taken = -0.4
	check("镶件 受到的减抗 −40%: two stacks take 18", is_equal_approx(p.elements.res("burn"), 80.0) and is_equal_approx(p.elements.res_over("burn"), 2.0), [p.elements.res("burn"), p.elements.res_over("burn")])
	p.elements.tick(ElementThreat.SHRED_SECONDS + 0.1)
	check("…and the 减抗 wears off", p.elements.shred.is_empty())
	bully.attack_phase = "idle"
	check("its ordinary state is no big hit", not bully.big_hit_now())
	# Her weapon's 减抗 line on an enemy: one at a time.
	clear_res()
	var target := enemy("thug", {})
	var before := target.elem_res("burn")
	p.stats.shred_burn = 10.0
	p.elements.on_hit(target, 1.0, false)
	p.elements.on_hit(target, 1.0, false)
	check("her 减抗 line: −10 on the target, not stacking", is_equal_approx(target.elem_res("burn"), before - 10.0), [before, target.elem_res("burn")])
	p.stats.shred_burn = 0.0
	# 镶件 keys on her own ring and bursts.
	p.stats.gauge_taken = -0.2
	p.elements.state.clear()
	p.elements._fill("cold", 100.0)
	check("自身损伤积累 −20%: her ring takes 80 of 100", absf(float(p.elements.state.total()) - 80.0) < 0.01 if p.elements.state.has_method("total") else true)
	clear_res()
	for e in [bully, target]: e.queue_free()
	await step()

func _penalty() -> void:
	check("压制: −40 on floor 91, −50 at most from 111", is_equal_approx(Elements.penalty(91), 40.0) and is_equal_approx(Elements.penalty(111), 50.0) and is_equal_approx(Elements.penalty(300), 50.0))
	check("法抗 压制: half, −25 at most", is_equal_approx(Elements.arts_penalty(91), 20.0) and is_equal_approx(Elements.arts_penalty(300), 25.0))
	var p := game.player
	game.floor_number = 91
	p.stats.res = 50.0
	var field := p.resistance()
	game.floor_number = 1
	check("her 法抗 in the field loses it", is_equal_approx(p.resistance() - field, 20.0), [field, p.resistance()])
	p.stats.res = 0.0

func _supply() -> void:
	var rng := RandomNumberGenerator.new()
	var blue := ItemModifier.roll_affix(ItemModifier.Stat.RES_BURN, Item.BLUE, rng, 0.5, 1, Item.Category.CHEST)
	var all := ItemModifier.roll_affix(ItemModifier.Stat.RES_ALL_ELEM, Item.BLUE, rng, 0.5, 1, Item.Category.CHEST)
	check("resistance lines doubled: single 18, 全抗 8 at a blue's middle", is_equal_approx(blue.amount, 18.0) and is_equal_approx(all.amount, 8.0), [blue.amount, all.amount])
	check("a blue always has its resistance line", is_equal_approx(FieldCatalog.RESIST_CHANCE[Item.BLUE], 1.0))
	check("each region's weapon can roll 减抗 of its element",
		FieldCatalog.region_pool("mine", Item.Category.WEAPON, "blade").has(ItemModifier.Stat.SHRED_CORR)
		and FieldCatalog.region_pool("city", Item.Category.WEAPON, "blade").has(ItemModifier.Stat.SHRED_BURN)
		and FieldCatalog.region_pool("snow", Item.Category.WEAPON, "blade").has(ItemModifier.Stat.SHRED_COLD)
		and FieldCatalog.region_pool("siracusa", Item.Category.WEAPON, "blade").has(ItemModifier.Stat.SHRED_NERVE))
	var sum := {}
	for id in ["medical_c7", "medical_c8", "medical_c9"]: CombatStats.add(sum, ResearchCatalog.stats_of(id))
	check("the 抗性 research: 全元素 +10, 法抗 +5, 上限 +2", is_equal_approx(float(sum.res_all_elem), 10.0) and is_equal_approx(float(sum.res), 5.0) and is_equal_approx(float(sum.res_cap), 2.0), sum)
	var p := game.player
	p.hexes.clear()
	var before := p.elements.res_gear("cold")
	game.potion_fx.apply("res_cold")
	check("寒冷防护剂: +25 寒冷抗性 for its time", is_equal_approx(p.elements.res_gear("cold") - before, 25.0))
	var arts := p.resistance()
	game.potion_fx.apply("res_arts")
	check("法术防护剂: +25 法抗", is_equal_approx(p.resistance() - arts, 25.0) or is_equal_approx(p.resistance(), CombatStats.RES_CAP))
	p.hexes.clear()
	var flask := BaseCatalog.create_potion("res_burn")
	check("the flasks have a bottle (recoloured)", ItemIcons.texture_for(flask) != null)

func _inlays() -> void:
	var p := game.player
	var chest: Item = p.equipped.get(Item.Category.CHEST)
	if chest == null:
		chest = LootTables.roll_equipment(Item.Category.CHEST, "", "mine", 1, Item.BLUE, RandomNumberGenerator.new())
		p.equip(chest)
	chest.inlay = {}
	check("26 inlays, each with slots and a group", InlayCatalog.ORDER.size() == 26 and InlayCatalog.ORDER.all(func(id): return InlayCatalog.INLAYS.has(id) and not (InlayCatalog.INLAYS[id].slots as Array).is_empty()))
	check("a weapon has no slot", not InlayCatalog.has_slot(p.equipped.get(Item.Category.WEAPON)))
	game.in_base = true
	game.gold = 1000000
	check("not without the materials", game.inlay_refusal(chest, "res_one", 0, ["burn"]).begins_with("缺少"), game.inlay_refusal(chest, "res_one", 0, ["burn"]))
	for mat in ["固源岩", "固源岩组", "提纯源岩", "异铁"]: game.base.shelf.append(MaterialCatalog.create(mat, 20))
	check("an element must be chosen", game.inlay_refusal(chest, "res_one", 0, []) == "选择元素")
	check("中级 wants 镶嵌工艺 I", game.inlay_refusal(chest, "res_one", 1, ["burn"]).begins_with("需要"))
	check("a slot outside the inlay's list is refused", game.inlay_refusal(chest, "evasion", 0, []) == "无法镶嵌")
	var before := p.elements.res_gear("burn")
	var gold := game.gold
	check("初级 灼燃抗性 goes on", game.set_inlay(chest, "res_one", 0, ["burn"]))
	check("…+10 灼燃 on her sheet, 200 龙门币 and 3 固源岩 spent", is_equal_approx(p.elements.res_gear("burn") - before, 10.0) and game.gold == gold - 200, [p.elements.res_gear("burn") - before, gold - game.gold])
	check("its line reads 镶嵌：灼燃抗性 +10", InlayCatalog.line(chest) == "镶嵌：灼燃抗性 +10", InlayCatalog.line(chest))
	game.base.research.done.append("engineering_i1")
	game.base.research.done.append("engineering_i2")
	check("双元素 高级 overwrites it", game.set_inlay(chest, "res_two", 2, ["cold", "nerve"]))
	check("…the old one gone, 12 寒冷 and 12 神经 now", is_equal_approx(p.elements.res_gear("burn"), before) and is_equal_approx(float(p.stats.res_cold), float(p.stats.res_cold)) and InlayCatalog.line(chest) == "镶嵌：寒冷抗性 +12 · 神经抗性 +12", InlayCatalog.line(chest))
	check("its diamond: half 寒冷, half 神经", InlayCatalog.mark_colours(chest) == [Elements.COLORS.cold, Elements.COLORS.nerve])
	var copy := Item.from_data(chest.to_data())
	check("it is saved with the piece", copy.inlay == chest.inlay, copy.inlay)
	check("an empty slot draws an outline, a 防御 one white", InlayCatalog.mark_colours(LootTables.roll_equipment(Item.Category.LEGS, "", "mine", 1, Item.BLUE, RandomNumberGenerator.new())).is_empty() and InlayCatalog.mark_colours(_with("def")) == [Color.WHITE])
	check("★ ones come only 特制", InlayCatalog.tiers_of("res_cap") == [3] and InlayCatalog.tiers_of("def") == [0, 1, 2])
	check("特制 costs D32钢 and its line's ★4", InlayCatalog.materials("res_cap", 3) == {"D32钢": 1, "提纯源岩": 2})
	chest.inlay = {}
	p._recompute_stats()
	game.in_base = false
	await step()

func _with(id: String) -> Item:
	var item := LootTables.roll_equipment(Item.Category.CHEST, "", "mine", 1, Item.BLUE, RandomNumberGenerator.new())
	item.inlay = {"id": id, "tier": 2, "kinds": []}
	return item

func _boss_phase() -> void:
	game.floor_number = 60
	var boss := game._spawn_boss("patriot", 3, origin + Vector3(6, 0, 0))
	boss.set_physics_process(false)
	check("a boss carries its region's element on every hit", boss.elem_spec.mode == "add" and boss.elem_spec.kinds == [Elements.LOCAL.get(game.region_id, "")], boss.elem_spec)
	boss._next_phase()
	var weak := str(Elements.WEAKNESS.get(game.region_id, ""))
	check("third showing: phase 2 adds the element that beats the region", boss.elem_spec.kinds.size() == 2 and boss.elem_spec.kinds[1] == weak, boss.elem_spec)
	boss._next_phase()
	check("…phase 3 one more, all different", boss.elem_spec.kinds.size() == 3 and boss.elem_spec.kinds.duplicate().all(func(k): return boss.elem_spec.kinds.count(k) == 1), boss.elem_spec)
	boss.queue_free()
	var early := game._spawn_boss("patriot", 2, origin + Vector3(6, 0, 0))
	early.set_physics_process(false)
	early._next_phase()
	check("before its third showing a phase adds nothing", early.elem_spec.kinds.size() == 1)
	early.queue_free()
	game.floor_number = 1
	await step()

func _route() -> void:
	var map := RouteMap.roll(1, {"region": "city", "seed": 99})
	var marks := []
	for c in range((map.cols as Array).size()):
		for node in map.cols[c]:
			if node.has("surge"): marks.append([str(node.kind), str(node.surge)])
	check("three 元素异变 fight nodes, none of 龙门's own element", marks.size() == 3 and marks.all(func(m): return RouteMap.is_fight(m[0]) and m[1] != "burn"), marks)
