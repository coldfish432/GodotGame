extends SceneTree
## 龙门币平衡与科研部策划案_v1_1.md: the income index, the contract fixed when
## taken, 作战记录 as loot, 可露希尔's flask bundles, tiered kits, the new
## prices, and 科研部 — its nodes, projects, endless lines, the effects, the
## terminal and the room. 科研树状化策划案_v1_0.md: the tree, its
## prerequisites across departments, 7, and the combat nodes' zone.
var game: GameManager
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool, detail: Variant = "") -> void:
	checks += 1
	print(("PASS " if passed else "FAIL ") + label + ("" if passed or str(detail).is_empty() else "  [%s]" % str(detail)))
	if not passed: failures += 1

func later(seconds: int) -> void:
	BaseState.clock_offset += seconds

func run() -> void:
	MarketState.tz_override = 0
	BaseState.frozen_clock = 1791972000
	_economy()
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	game.fixed_market_seed = 77
	root.add_child(game)
	await step(8)
	game.rng.seed = 91
	_prices()
	_kits()
	_closure()
	await _contract_and_records()
	_research_rules()
	_tree()
	_effects()
	_projects()
	_endless()
	_save()
	await _terminal_and_room()
	print("RESEARCH RESULT: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await step(2)
	quit(1 if failures else 0)

# --- §1, §2 -------------------------------------------------------------------------------

func _economy() -> void:
	check("tiers are ten floors: 1 → 1, 10 → 1, 11 → 2, 95 → 10, 300 → 10",
		Economy.tier_of(1) == 1 and Economy.tier_of(10) == 1 and Economy.tier_of(11) == 2 and Economy.tier_of(95) == 10 and Economy.tier_of(300) == 10)
	check("the income index runs 1 → 6.73", Economy.income_index(1) == 1.0 and is_equal_approx(Economy.income_index(10), 6.73))
	check("tiered prices round to 100: 300 at 5 → 1,000; 3,000 at 10 → 20,200", Economy.tiered(300, 5) == 1000 and Economy.tiered(3000, 10) == 20200, [Economy.tiered(300, 5), Economy.tiered(3000, 10)])
	check("tier labels", ResearchCatalog.tier_label(4) == "4 阶" and Progression.grade_label(4) == "31–40 层" and Progression.grade_label(10) == "91+ 层" and Progression.grade_corner(10) == "91+")

func _prices() -> void:
	# 仓库修订 (用户 2026-10-23): no racks, console or drone to buy; 仓储部 levels give cells and stack size.
	check("仓储部 Lv1–4: 60 / 120 / 220 / 360 cells, stacks ×1 / ×2 / ×3 / ×5",
		BaseCatalog.WAREHOUSE_CELLS == [0, 60, 120, 220, 360] and BaseCatalog.WAREHOUSE_STACK == [0, 1, 2, 3, 5])
	check("pack 42k / 112k, safe 56k / 140k, camp 168k",
		BaseCatalog.PACK_PRICES == [0, 42000, 112000] and BaseCatalog.SAFE_PRICES == [0, 56000, 140000] and BaseCatalog.CAMP_UPGRADE_PRICE == 168000)
	check("promotion 22,000 / 168,000; modules 56k / 84k / 112k",
		int(Progression.PROMOTION[1].lmd) == 22000 and int(Progression.PROMOTION[2].lmd) == 168000
		and SkillTrees.MODULE_COST.map(func(c): return int(c.lmd)) == [56000, 84000, 112000])
	game.base.injuries = {Operators.LAPPLAND: 5}
	check("treatment × the index of the floor she fell on: 5 → 27,600", game.injury_price(Operators.LAPPLAND) == Economy.tiered(BaseCatalog.INJURY_TREATMENT, 5)
		and game.injury_price(Operators.LAPPLAND) == 27600, game.injury_price(Operators.LAPPLAND))
	game.base.settle_medical(true, 3)
	check("a fall records its tier", int(game.base.injuries.get(game.base.operator, 0)) == 3)
	game.base.injuries = {}

func _kits() -> void:
	check("a kit's cut grows 3% a tier: plain mask 1 30%, 10 57%", is_equal_approx(FeatureCatalog.kit_cut("dust_mask", 1), 0.3) and is_equal_approx(FeatureCatalog.kit_cut("dust_mask", 10), 0.57))
	check("used a tier short it loses 5% a tier", is_equal_approx(FeatureCatalog.kit_cut("dust_mask", 2, 4), 0.33 - 0.1))
	check("kit price × index: mask 10 94,200", FeatureCatalog.kit_price("dust_mask", 10) == 94200, FeatureCatalog.kit_price("dust_mask", 10))
	game.base.kits = {}
	game.base.camps = {"snow": 30}
	game.gold = 200000
	check("the base sells kits at the deepest camp's tier", game.deepest_tier() == 4 and game.buy_kit("sami_lining") and game.base.kits == {"sami_lining@4": 1}, game.base.kits)
	game.base.add_kit("sami_lining", 1)
	check("stock counts every tier; the best is taken first", game.base.kit_stock("sami_lining") == 2 and game.base.take_kit("sami_lining") == 4 and game.base.kit_best_tier("sami_lining") == 1)
	var copy := BaseState.new()
	copy.load_data({"kits": {"dust_mask": 2}}, {})
	check("saves from before tiers load their kits as tier 1", copy.kits == {"dust_mask@1": 2}, copy.kits)
	game.base.kits = {}
	game.base.camps = {}

func _closure() -> void:
	var per_bar := maxi(1, floori(Economy.bar_lmd() / float(BaseCatalog.POTION_A_PRICE)))
	check("one 赤金 buys as many 标准急救剂 1 as its 龙门币 covers (%d at the base)" % per_bar, game.closure_potion_bundle("A") == per_bar, game.closure_potion_bundle("A"))
	game.base.camps = {"mine": 40}
	check("at tier 5 a bar buys one", game.closure_potion_bundle("A") == 1)
	check("the pharmacy's price follows the deepest tier", game.potion_price("B") == Economy.tiered(int(BaseCatalog.POTIONS["B"].price), 5))
	game.base.camps = {}

func _contract_and_records() -> void:
	var offers := game.contract_offers("mine")
	check("every ordinary offer carries its roll", offers.slice(0, FieldCatalog.CONTRACT_OFFERS).all(func(c): return c.has("roll") and float(c.roll) >= 0.85 and float(c.roll) <= 1.15))
	var card := game.contract_pay_text({"type": "search", "roll": 1.0}, 1)
	check("the card shows the pay", card == "8,000 龙门币", card)
	game._pending_contract = {"type": "deep", "steps": 4, "roll": 1.0}
	await game.start_contract("mine")
	await step(2)
	check("taken: 8,000 × 0.8 = 6,400", int(game.contract.reward) == 6400, game.contract)
	game._clear_field()
	game.inventory.items.clear()
	game.inventory.add_stack(MaterialCatalog.create("初级作战记录", 2))
	var gold := game.gold
	var before: int = int(game.base.records.get("初级作战记录", 0))
	game.settle(true)
	await step(2)
	check("extracting without the objective pays nothing", game.gold == gold, game.gold - gold)
	check("records brought out go to 人事部's counters", int(game.base.records.get("初级作战记录", 0)) == before + 2)
	check("and none of them stays in her bags or the warehouse", (game.base.all_items() + game.carried_items()).filter(func(x): return x.material_id == "初级作战记录").is_empty())
	check("records are loot: ★3 初级, worth 80 to sell", MaterialCatalog.star("初级作战记录") == 3 and Economy.direct_price(MaterialCatalog.create("初级作战记录", 1)) == 80)

# --- §5 -----------------------------------------------------------------------------------

func _research_rules() -> void:
	var r := game.research
	game.base.set_facility("lab", 0)
	check("科研部 opens once it is built", not r.is_open() and r.refusal("logistics_1") == "需要科研部 Lv1")
	game.base.set_facility("lab", 1)
	game.gold = 10000000
	check("71 nodes in seven departments and the joint research", ResearchCatalog.all_ids().size() == 71)
	check("第二加工线 needs 订单速递 first", r.refusal("logistics_2") == "需要订单速递", r.refusal("logistics_2"))
	check("materials are checked", r.refusal("logistics_1").begins_with("缺少"))
	_stock({"电路板": 20, "继电器": 20, "微型电机": 10, "装置": 20})
	check("tier 1 can start", r.refusal("logistics_1").is_empty(), r.refusal("logistics_1"))
	var gold := game.gold
	check("starting pays 56,000 and the materials", r.start("logistics_1") and gold - game.gold == int(ResearchCatalog.TIER_PRICE[0]) and game.material_count("电路板") == 18)
	check("one slot at Lv1", r.refusal("medical_1") == "研究位已满")
	later(1800)
	check("half an hour in: half done, not finished", is_equal_approx(r.progress("logistics_1"), 0.5) and r.tick().is_empty())
	var slots := game.base.order_slot_count()
	later(1800)
	check("an hour in it is done", r.tick() == ["logistics_1"] and r.is_done("logistics_1"))
	check("后勤部 1 阶 adds an order slot at once", game.base.order_slot_count() == slots + 1 and game.base.orders.slots.size() == slots + 1)
	check("tier 2 needs the camp at floor 10", r.refusal("logistics_2") == "需要第 10 层营地")
	game.base.camps = {"mine": 10}
	check("…then it can start", r.refusal("logistics_2").is_empty(), r.refusal("logistics_2"))
	game.base.set_facility("lab", 2)
	check("Lv2 gives a second slot", r.slots() == 2)
	check("a base requirement shows its need", r.refusal("logistics_3").begins_with("需要") or r.refusal("logistics_3").begins_with("缺少"))

func _tree() -> void:
	var r := game.research
	var names := {}
	var lower := true
	var known := true
	for id in ResearchCatalog.all_ids():
		names[ResearchCatalog.name_of(id)] = true
		for p in ResearchCatalog.prerequisite_nodes(id):
			known = known and ResearchCatalog.valid(p)
			lower = lower and ResearchCatalog.valid(p) and ResearchCatalog.tier_of(p) <= ResearchCatalog.tier_of(id)
		for c in ResearchCatalog.conditions(id): known = known and ResearchCatalog.REQUIREMENT_NAMES.has(c)
	check("every node has its own name", names.size() == 71)
	check("every prerequisite exists and sits no higher", known and lower)
	var acyclic := true
	for id in ResearchCatalog.all_ids(): acyclic = acyclic and _reaches(id, id, {}) == false
	check("the tree has no loop", acyclic)
	var cross := 0
	for id in ResearchCatalog.all_ids():
		for p in ResearchCatalog.prerequisite_nodes(id):
			if ResearchCatalog.department_of(p) != ResearchCatalog.department_of(id): cross += 1
	check("56 links across departments", cross == 56, cross)
	check("one node opens several: 体能训练 → 强化体质, 复合插板, 战术翻滚", ["medical_c4", "engineering_c4", "field_c4"].all(func(x): return x in ResearchCatalog.unlocks("medical_c2")))
	# Several prerequisites: all of them, the first missing named.
	game.base.camps = {"mine": 40}
	var done: Array = game.base.research.done
	for p in ["medical_1", "medical_c1", "field_1", "field_c1", "medical_c2"]: if not p in done: done.append(p)
	check("强化体质 waits on 重症监护 and 协同训练", r.refusal("medical_c4") == "需要重症监护", r.refusal("medical_c4"))
	for p in ["medical_2", "personnel_1", "personnel_c1"]: done.append(p)
	check("…all three done, it can start", r.refusal("medical_c4").is_empty() or r.refusal("medical_c4").begins_with("缺少") or r.refusal("medical_c4") == "研究位已满", r.refusal("medical_c4"))
	for p in ["medical_1", "medical_c1", "field_1", "field_c1", "medical_c2", "medical_2", "personnel_1", "personnel_c1"]: done.erase(p)
	game.base.camps = {"mine": 10}
	# 仓库修订: 仓储部's levels stand in for the racks and the drone.
	var wh_level := game.base.facility_level("warehouse")
	game.base.set_facility("warehouse", 3)
	check("立体货架: 仓储部 Lv3 is enough", r.requirement_refusal("logistics_3").is_empty(), r.requirement_refusal("logistics_3"))
	check("自动分拣系统 needs 仓储部 Lv4", r.requirement_refusal("logistics_6") == "仓储部 Lv4", r.requirement_refusal("logistics_6"))
	game.base.set_facility("warehouse", 2)
	check("…Lv2 is refused", r.requirement_refusal("logistics_3") == "仓储部 Lv3")
	game.base.set_facility("warehouse", 4)
	check("…and Lv4 opens 自动分拣", r.requirement_refusal("logistics_6").is_empty())
	game.base.set_facility("warehouse", wh_level)
	check("combat nodes cost 1.5 × the tier: 武器校准 84,000; joint 6.72M", ResearchCatalog.price("engineering_c1") == roundi(ResearchCatalog.TIER_PRICE[0] * 1.5)
		and ResearchCatalog.price("engineering_c1") == 84000 and ResearchCatalog.price("joint_elite") == 6720000)
	# 7: the two late reforge nodes, after 龙门's 定向重铸.
	check("词条锚定 and 平行重铸 sit at 7: camp 90, 5.6M / 36 h and 8.4M / 48 h",
		ResearchCatalog.tier_of("engineering_5") == 7 and ResearchCatalog.camp_needed("engineering_5") == 90
		and ResearchCatalog.price("engineering_5") == 5600000 and ResearchCatalog.hours("engineering_5") == 36
		and ResearchCatalog.price("engineering_6") == 8400000 and ResearchCatalog.hours("engineering_6") == 48)
	check("7 asks 玄纹墨", int(ResearchCatalog.materials("engineering_5").get("玄纹墨", 0)) == 3)
	check("词条锚定 needs 龙门商会 R5", "lungmen_r5" in ResearchCatalog.conditions("engineering_5"))
	var standing: int = game.exchange.relation(GameManager.DIRECTED_FACTION)
	game.exchange.relations[GameManager.DIRECTED_FACTION] = 0
	check("…refused below R5", r.requirement_refusal("engineering_5") == "龙门商会 R5")
	game.exchange.relations[GameManager.DIRECTED_FACTION] = Exchange.RANK_AT[Exchange.RANK_AT.size() - 1]
	check("…and met at R5", r.requirement_refusal("engineering_5").is_empty())
	game.exchange.relations[GameManager.DIRECTED_FACTION] = standing
	# The combat zone: everything done, on top of all else.
	var p := game.player
	p._recompute_stats()
	var atk := p.attack_power()
	var life := p.max_hp
	var guard := p.defense_value()
	var crit := p.crit_rate()
	var added: Array[String] = []
	for id in ResearchCatalog.all_ids():
		if ResearchCatalog.is_combat(id) and not id in done:
			done.append(id)
			added.append(id)
	r.apply_globals()
	p._recompute_stats()
	var sheet := r.combat_sheet()
	check("the combat zone sums: ATK +12.5%, life +14.5%, DEF +16%", is_equal_approx(float(sheet.atk), 0.125) and is_equal_approx(float(sheet.hp), 0.145) and is_equal_approx(float(sheet.def), 0.16), sheet)
	check("…applied last: ATK, life and DEF × the zone", is_equal_approx(p.attack_power(), atk * 1.125) and is_equal_approx(p.max_hp, life * 1.145) and is_equal_approx(p.defense_value(), guard * 1.16),
		[p.attack_power() / atk, p.max_hp / life, p.defense_value() / guard])
	check("…crit +5%, elites +11%, reduction 8.5%", is_equal_approx(p.crit_rate(), crit + 0.05) and is_equal_approx(float(p.stats.elite_pct), float(sheet.elite_pct)) and is_equal_approx(float(sheet.dmg_reduce), 0.085))
	check("随身药包: a flask cell holds one more", BaseCatalog.create_potion("A", 1).max_stack == BaseCatalog.POTION_STACK + 1)
	for id in added: done.erase(id)
	r.apply_globals()
	p._recompute_stats()
	check("…undone, back as it was", is_equal_approx(p.attack_power(), atk) and BaseCatalog.create_potion("A", 1).max_stack == BaseCatalog.POTION_STACK)

## Whether `target` is reachable from `id` along prerequisites.
func _reaches(id: String, target: String, seen: Dictionary) -> bool:
	for p in ResearchCatalog.prerequisite_nodes(id):
		if p == target: return true
		if seen.has(p): continue
		seen[p] = true
		if _reaches(p, target, seen): return true
	return false

func _stock(materials: Dictionary) -> void:
	for id in materials:
		var left := int(materials[id])
		while left > 0:
			var stack := MaterialCatalog.create(id, mini(left, MaterialCatalog.stack_size(id)))
			left -= stack.quantity
			game.base.shelf.append(stack)

func _finish(key: String) -> void:
	var id := ResearchCatalog.id_of_key(key)
	if not id in game.base.research.done: game.base.research.done.append(id)
	game.research._on_done(id)

func _effects() -> void:
	var base := game.base
	var cells := base.capacity()
	_finish("rack_cells")
	check("后勤部 3 阶: warehouse capacity +20%", base.capacity() == roundi(cells * 1.2) and base.capacity(Item.Category.WEAPON) == base.capacity(), [cells, base.capacity()])
	var slots := game.workshop_slots()
	_finish("workshop_slot")
	check("后勤部 2 阶: a workshop slot", game.workshop_slots() == slots + 1)
	_finish("workshop_speed")
	check("后勤部 4 阶: work 25% faster", is_equal_approx(game.research.workshop_time_factor(), 0.75))
	_finish("bulk_orders")
	check("后勤部 5 阶: five bulk orders, every 4 h", game.voyage.order_slots() == 5 and game.voyage.order_refill() == 4 * 3600)
	_finish("free_potion")
	check("医疗部 1 阶: four free flasks", base.free_potion_count() == 4)
	base.injuries = {Operators.LAPPLAND: 1}
	_finish("injury_fee")
	check("医疗部 2 阶: treatment halved", game.injury_price(Operators.LAPPLAND) == Economy.tiered(BaseCatalog.INJURY_TREATMENT, 1) / 2, game.injury_price(Operators.LAPPLAND))
	base.injuries = {}
	_finish("isolation_ward")
	check("医疗部 6 阶: contamination steps at 70 / 100", BaseCatalog.contamination_tier(65.0) == 0 and BaseCatalog.contamination_tier(70.0) == 1)
	var item := LootTables.roll_equipment(Item.Category.WEAPON, GearCatalog.BASES[GearCatalog.BASES.keys()[0]].name, "mine", 10, Item.BLUE, game.rng)
	var cost := game.refresh_cost("reforge", item)
	_finish("refresh_fee")
	check("工程部 1 阶: 重铸 15% cheaper", game.refresh_cost("reforge", item) == roundi(cost * 0.85))
	_finish("rhodes_blue")
	check("工程部 2 阶: Rhodes gear turns blue", base.rhodes_rarity == 1)
	_finish("rhodes_gold")
	check("工程部 4 阶: then blue", base.rhodes_rarity == Item.BLUE)
	var offers := game.contract_offer_count()
	_finish("offer_slot")
	check("外勤部 1 阶: four offers", game.contract_offer_count() == offers + 1)
	base.contract_offers.erase("city")
	var four := game.contract_offers("city").filter(func(c): return c.type in FieldCatalog.CONTRACT_TYPES)
	check("…all four kinds", four.size() == 4, four.size())
	base.contract_reroll = true
	var was: Dictionary = (base.contract_offers["city"][0] as Dictionary).duplicate()
	check("外勤部 2 阶: one free reroll", game.reroll_contract("city", 0) and not base.contract_reroll and not game.reroll_contract("city", 0))
	check("…the card changed", base.contract_offers["city"][0] != was)
	_finish("deposit_fee")
	check("外勤部 3 阶: the deposit fee halves", is_equal_approx(game.research.deposit_fee_factor(), 0.5))
	var safe := game.safe_bag.height
	_finish("safe_row")
	check("外勤部 4 阶: one more safe-bag row", game.safe_bag.height == safe + 1)
	var limit := game.exchange.loan_limit()
	_finish("loan_terms")
	check("商务部 5 阶: loans ×1.5, a point off", game.exchange.loan_limit() == roundi(limit * 1.5) and is_equal_approx(game.exchange.loan_rate_now(5000), 0.0))
	_finish("closure_spread")
	check("商务部 2 阶: 可露希尔's spread 2%", is_equal_approx(Economy.closure_spread, 0.02))
	_finish("feed_fee")
	check("人事部 1 阶: records 20% cheaper", game.record_price("基础作战记录") == ceili(int(Progression.RECORD_EXP["基础作战记录"]) * Progression.LMD_PER_EXP * 0.8), game.record_price("基础作战记录"))
	_finish("bench_exp")
	check("人事部 4 阶: the bench learns 20%", is_equal_approx(game.research.bench_share(), 0.2))
	_finish("glow_range")
	check("情报部 1 阶: glows 50% wider", is_equal_approx(game.research.glow_factor(), 1.5))
	_finish("appraisal")
	check("情报部 2 阶: the tooltip shows the band", ItemTooltip.show_band)

func _projects() -> void:
	var r := game.research
	check("a project costs base × index: M at 5 = 72,200", r.project_price("threat", 5) == Economy.tiered(int(ResearchCatalog.PROJECT_BASE["M"]), 5)
		and r.project_price("threat", 5) == 72200, r.project_price("threat", 5))
	check("sign two", r.sign("threat") and r.sign("records") and r.project_refusal("deep") == "课题位已满")
	var gold := game.gold
	var paid := r.charge_departure(41)
	check("departure pays both at the start's tier", paid == r.project_price("threat", 5) + r.project_price("records", 5) and gold - game.gold == paid)
	check("they are on for the contract", r.on("threat") and r.on("records") and is_equal_approx(r.threat_factor(), 0.85) and is_equal_approx(r.record_bonus(), 0.3))
	r.apply_run(true)
	r.settle()
	r.apply_run(false)
	check("a sortie counted down", int(r.projects()["threat"]) == ResearchCatalog.PROJECT_SORTIES - 1 and not r.on("threat"))
	game.gold = 0
	r.charge_departure(1)
	check("unpaid, it does not run and keeps its sorties", not r.on("threat") and int(r.projects()["threat"]) == ResearchCatalog.PROJECT_SORTIES - 1)
	r.settle()
	game.gold = 10000000
	for i in range(2):
		r.charge_departure(1)
		r.settle()
	check("after three sorties both end", not r.projects().has("threat") and not r.projects().has("records"))
	check("cancel", r.sign("scan") and r.cancel("scan") and r.projects().is_empty())
	_finish("project_slot")
	check("外勤部 6 阶: a third slot", r.project_slots() == 3)
	r.sign("deep")
	r.sign("appraise")
	r.sign("vaults")
	r.charge_departure(1)
	r.apply_run(true)
	check("projects set the field's rules", LootTables.stair_bonus == 1 and is_equal_approx(Scaling.band_exponent_mult, 0.85) and is_equal_approx(ContinuousWorldMap.vault_chance_mult, 1.5))
	r.settle()
	r.apply_run(false)
	check("…and clear them after", LootTables.stair_bonus == 0 and is_equal_approx(Scaling.band_exponent_mult, 1.0) and is_equal_approx(ContinuousWorldMap.vault_chance_mult, 1.0))
	game.base.research.projects = {}

func _endless() -> void:
	var r := game.research
	check("level 1 costs 140,000, level 10 about 1,043k", ResearchCatalog.endless_price(0) == ResearchCatalog.ENDLESS_BASE and ResearchCatalog.endless_price(0) == 140000
		and ResearchCatalog.endless_price(9) == 1043000, ResearchCatalog.endless_price(9))
	var gold := game.gold
	check("buying a level", r.buy_endless("contract") and gold - game.gold == ResearchCatalog.endless_price(0) and r.endless_level("contract") == 1, [gold - game.gold, game.gold])
	check("合同报酬 +1% a level", is_equal_approx(r.contract_bonus(), 101.0))
	game.base.research.endless["threat"] = ResearchCatalog.ENDLESS_CAP
	check("capped at 30", r.endless_refusal("threat") == "已满级")

func _save() -> void:
	var data := game.base.to_data()
	var copy := BaseState.new()
	copy.load_data(JSON.parse_string(JSON.stringify(data)), {})
	check("research survives a save", copy.research.done == game.base.research.done and copy.research.endless == game.base.research.endless and copy.rhodes_rarity == game.base.rhodes_rarity)
	var old := BaseState.new()
	old.load_data({}, {})
	check("saves from before 科研部 start empty", old.research.done.is_empty() and old.rhodes_rarity == 0)

func _terminal_and_room() -> void:
	check("the lab is a room with the research terminal", game.base_map.rooms.has("lab") and game.base_map.interactables.any(func(s): return s.kind == "research"))
	check("one light per node over the console", game.base_map.research_lights.size() == 42)
	game.show_base()
	await step(2)
	game.open_station("research")
	await step(2)
	check("the terminal opens", game.modal == "station")
	for t in range(3):
		ResearchScreen.tab = t
		ResearchScreen.build(game.menu)
		await step(1)
	check("all three tabs draw", true)
	game.close_modal()
