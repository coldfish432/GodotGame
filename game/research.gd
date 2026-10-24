class_name Research
extends RefCounted

## 科研部 rules (龙门币平衡与科研部策划案_v1_1.md §5; the tree and its
## combat nodes, 科研树状化策划案_v1_0.md). The state lives on
## BaseState.research so it saves with the base; this reads and changes it,
## and answers the multipliers the rest of the game asks for. Research runs
## on the wall clock (BaseState.now) like insurance and voyages.

var game: GameManager

func _init(p_game: GameManager = null) -> void:
	game = p_game

func _state() -> Dictionary: return game.base.research
func done() -> Array: return _state().done
func active() -> Array: return _state().active

# --- Permanent research ------------------------------------------------------------------

func is_open() -> bool:
	return game.base.facility_level("lab") >= ResearchCatalog.OPEN_LEVEL

func slots() -> int:
	return 2 if game.base.facility_level("lab") >= ResearchCatalog.SECOND_SLOT_LEVEL else 1

func is_done(id: String) -> bool: return id in done()

func is_running(id: String) -> bool:
	return active().any(func(e): return str(e.id) == id)

## The deepest camp in any region.
func deepest_camp() -> int:
	var deepest := 0
	for region in game.base.camps: deepest = maxi(deepest, int(game.base.camps[region]))
	return deepest

## Why one of the node's base conditions is not met ("" when all are).
func requirement_refusal(id: String) -> String:
	var base := game.base
	for need in ResearchCatalog.conditions(id):
		var met := true
		match need:
			# 仓库修订: the warehouse's own levels stand in for the racks and the drone.
			"racks_3": met = base.facility_level("warehouse") >= 3
			"drone": met = base.facility_level("warehouse") >= 4
			"stayed": met = base.stayed
			"camp_upgrade": met = base.camp_upgraded
			"safe_2": met = base.safe_level >= 2
			"exchange": met = game.exchange.unlocked()
			"roster_3": met = base.roster.size() >= 3
			# The same standing 定向重铸 asks (GameManager.directed_refusal).
			"lungmen_r5": met = game.exchange.rank(GameManager.DIRECTED_FACTION) >= Exchange.RANK_AT.size() - 1
		if not met: return str(ResearchCatalog.REQUIREMENT_NAMES.get(need, need))
	return ""

## The first prerequisite node not yet done ("" when all are).
func missing_prerequisite(id: String) -> String:
	for p in ResearchCatalog.prerequisite_nodes(id):
		if not is_done(p): return p
	return ""

## "" when `id` can start now, else why not (short, data-like).
func refusal(id: String) -> String:
	if not ResearchCatalog.valid(id): return "无效"
	if not is_open(): return "需要科研部 Lv%d" % ResearchCatalog.OPEN_LEVEL
	if is_done(id): return "已完成"
	if is_running(id): return "研究中"
	var missing := missing_prerequisite(id)
	if not missing.is_empty(): return "需要%s" % ResearchCatalog.name_of(missing)
	if deepest_camp() < ResearchCatalog.camp_needed(id): return "需要第 %d 层营地" % ResearchCatalog.camp_needed(id)
	var need := requirement_refusal(id)
	if not need.is_empty(): return "需要%s" % need
	if active().size() >= slots(): return "研究位已满"
	if game.gold < ResearchCatalog.price(id): return "龙门币不足"
	return game.materials_refusal(ResearchCatalog.materials(id))

func start(id: String) -> bool:
	if not game.in_base or not refusal(id).is_empty(): return false
	game.gold -= ResearchCatalog.price(id)
	game.consume_materials(ResearchCatalog.materials(id))
	var now := BaseState.now()
	active().append({"id": id, "start": now, "end": now + ResearchCatalog.hours(id) * 3600})
	game.story_note("research")
	game.save_base()
	return true

## Seconds left on running research `id` (0 when not running).
func seconds_left(id: String) -> int:
	for e in active():
		if str(e.id) == id: return maxi(0, int(e.end) - BaseState.now())
	return 0

## Share done of running research `id`, 0–1.
func progress(id: String) -> float:
	for e in active():
		if str(e.id) == id: return clampf(float(BaseState.now() - int(e.start)) / maxf(1.0, float(int(e.end) - int(e.start))), 0.0, 1.0)
	return 0.0

## Finishes whatever research is due; returns the ids finished.
func tick() -> Array[String]:
	var finished: Array[String] = []
	var now := BaseState.now()
	for e in active().duplicate():
		if int(e.end) <= now:
			active().erase(e)
			if not is_done(str(e.id)): done().append(str(e.id))
			finished.append(str(e.id))
	for id in finished: _on_done(id)
	return finished

## Side effects a finished node has at once.
func _on_done(id: String) -> void:
	var base := game.base
	match ResearchCatalog.key_of(id):
		"order_slot": base.orders.resize(base.order_slot_count())
		"free_potion": base.free_potions = mini(base.free_potions + 1, base.free_potion_count())
		"rhodes_blue": base.rhodes_rarity = maxi(base.rhodes_rarity, 1)
		"rhodes_gold": base.rhodes_rarity = maxi(base.rhodes_rarity, 2)
		"safe_row": game.apply_container_sizes()
		"closure_spread", "isolation_ward", "appraisal": apply_globals()
	if ResearchCatalog.key_of(id) in ["rhodes_blue", "rhodes_gold"]: game.refresh_rhodes()
	if ResearchCatalog.is_combat(id):
		apply_globals()
		if is_instance_valid(game.player): game.player._recompute_stats()
	game.broadcast("研究完成：%s · %s。" % [ResearchCatalog.name_of(id), ResearchCatalog.effect_text(id)])

## Rules kept in static vars elsewhere, set from what is done (after a load too).
func apply_globals() -> void:
	Economy.closure_spread = 0.02 if game.base.researched("closure_spread") else Economy.CLOSURE_FX_SPREAD
	BaseCatalog.contamination_shift = 10.0 if game.base.researched("isolation_ward") else 0.0
	ItemTooltip.show_band = game.base.researched("appraisal")
	BaseCatalog.potion_stack_bonus = int(combat_sheet().get("potion_stack", 0.0))

## The combat nodes done, summed (科研树状化策划案 §2: their own zone, applied
## after gear, points and relics; Player._recompute_stats reads it).
func combat_sheet() -> Dictionary:
	var sheet := {}
	for id in done():
		if not ResearchCatalog.valid(str(id)): continue
		var stats: Dictionary = ResearchCatalog.stats_of(str(id))
		for key in stats: sheet[key] = float(sheet.get(key, 0.0)) + float(stats[key])
	return sheet

# --- Projects (§5.7) ---------------------------------------------------------------------

func project_slots() -> int:
	return ResearchCatalog.PROJECT_SLOTS + (1 if game.base.researched("project_slot") else 0)

func projects() -> Dictionary: return _state().projects

## One sortie's price departing at `tier` (the endless 课题费用 line takes its share).
func project_price(project: String, tier: int) -> int:
	return roundi(ResearchCatalog.project_price(project, tier) * (1.0 + endless_value("projects")) / 100.0) * 100

func project_refusal(project: String) -> String:
	if not ResearchCatalog.PROJECTS.has(project): return "无效"
	if not is_open(): return "需要科研部 Lv%d" % ResearchCatalog.OPEN_LEVEL
	if projects().has(project): return "已签订"
	if projects().size() >= project_slots(): return "课题位已满"
	return ""

## Signs `project` for PROJECT_SORTIES sorties; nothing is paid until departure.
func sign(project: String) -> bool:
	if not game.in_base or not project_refusal(project).is_empty(): return false
	projects()[project] = ResearchCatalog.PROJECT_SORTIES
	game.save_base()
	return true

func cancel(project: String) -> bool:
	if not game.in_base or not projects().has(project): return false
	projects().erase(project)
	game.save_base()
	return true

## At departure from `start_floor`: pays each signed project, in signing order,
## while the money lasts; the paid ones are on for this contract. Returns the
## total paid.
func charge_departure(start_floor: int) -> int:
	var run: Array = _state().run
	run.clear()
	var paid := 0
	var tier := Economy.tier_of(start_floor)
	for project in projects().keys():
		var price := project_price(project, tier)
		if game.gold < price:
			game.broadcast("课题%s未支付，本次不生效。" % ResearchCatalog.PROJECTS[project][0])
			continue
		game.gold -= price
		paid += price
		run.append(project)
	return paid

## After the settlement: every project that ran counts one sortie down.
func settle() -> void:
	for project in _state().run:
		if not projects().has(project): continue
		projects()[project] = int(projects()[project]) - 1
		if int(projects()[project]) <= 0: projects().erase(project)
	_state().run.clear()

func on(project: String) -> bool: return game.base.project_on(project)

# --- Endless lines (§5.8) -----------------------------------------------------------------

func endless_level(line: String) -> int: return game.base.endless_level(line)

## The line's total effect: level × per level (signed).
func endless_value(line: String) -> float:
	return endless_level(line) * float(ResearchCatalog.ENDLESS[line][1])

func endless_refusal(line: String) -> String:
	if not ResearchCatalog.ENDLESS.has(line): return "无效"
	if not is_open(): return "需要科研部 Lv%d" % ResearchCatalog.OPEN_LEVEL
	if endless_level(line) >= ResearchCatalog.ENDLESS_CAP: return "已满级"
	if game.gold < ResearchCatalog.endless_price(endless_level(line)): return "龙门币不足"
	return ""

func buy_endless(line: String) -> bool:
	if not game.in_base or not endless_refusal(line).is_empty(): return false
	game.gold -= ResearchCatalog.endless_price(endless_level(line))
	_state().endless[line] = endless_level(line) + 1
	game.save_base()
	return true

# --- What the rest of the game asks --------------------------------------------------------

## Contract pay, in percent (100 = as rolled).
func contract_bonus() -> float: return 100.0 * (1.0 + endless_value("contract"))

## Chance of one more 作战记录 from a drop.
func record_bonus() -> float: return 0.3 if on("records") else 0.0

func deposit_fee_factor() -> float: return 0.5 if game.base.researched("deposit_fee") else 1.0

func voyage_time_factor() -> float: return maxf(0.1, 1.0 + endless_value("voyage"))

func workshop_time_factor() -> float:
	return maxf(0.1, (0.75 if game.base.researched("workshop_speed") else 1.0) * (1.0 + endless_value("workshop")))

func feed_factor() -> float:
	return maxf(0.1, (0.8 if game.base.researched("feed_fee") else 1.0) * (1.0 + endless_value("feed")))

## Free flasks one tier higher (医疗部Ⅴ): 0 or 1.
func free_potion_tier_bonus() -> int: return 1 if game.base.researched("potion_grade") else 0

## What raises every map feature on this contract.
func feature_factor() -> float:
	return (0.9 if game.base.researched("feature_cut") else 1.0) * (0.8 if on("dust") else 1.0)

## The threat meter's natural fill on this contract.
func threat_factor() -> float:
	return maxf(0.1, (0.85 if on("threat") else 1.0) * (1.0 + endless_value("threat")))

## Gold units out of enemies.
func gold_factor() -> float: return 1.2 if on("refine") else 1.0

## The trace roll's chance multiplier.
func trace_factor() -> float:
	return (1.25 if game.base.researched("trace_odds") else 1.0) * (1.5 if on("scan") else 1.0)

## Share of the deployed operator's kill experience the benched ones get.
func bench_share() -> float:
	if game.base.researched("bench_exp_2"): return 0.4
	return 0.2 if game.base.researched("bench_exp") else 0.0

func glow_factor() -> float: return 1.5 if game.base.researched("glow_range") else 1.0

## 重铸 and 校准 price (工程部Ⅰ).
func refresh_factor() -> float: return 0.85 if game.base.researched("refresh_fee") else 1.0

func tune_step() -> float: return 1.3 if game.base.researched("tune_step") else 1.5

## Rules for the contract under way, set at departure (and cleared after).
func apply_run(on_contract: bool) -> void:
	LootTables.stair_bonus = 1 if on_contract and on("deep") else 0
	Scaling.band_exponent_mult = 0.85 if on_contract and on("appraise") else 1.0
	ContinuousWorldMap.vault_chance_mult = 1.5 if on_contract and on("vaults") else 1.0
	game.features.research_mult = feature_factor() if on_contract else 1.0
