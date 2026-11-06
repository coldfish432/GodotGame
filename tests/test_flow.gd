extends SceneTree

## The whole thread from a new save (用户 2026-11-04: 写流程测试; 每一阶段不要求
## 一次外勤就完成). It walks the 13 beats of Story.BEATS in order and, for every
## goal, checks what stands in its way on a new save:
## - a department shut because its operator is still lost (dept_refusal);
## - a region not open yet (Story.region_open), a floor not reached yet (camps);
## - materials: each run is simulated with the real point-of-interest plan and
##   container drops (LootTables.plan_points / container_drops) of the regions
##   open at that point, on the floors the run covers; gold is the contract's pay.
## A goal may take as many runs as it needs; past RUN_CAP for one beat the beat
## counts as stuck. Prints a table of runs per beat and what was short.
## Combat, the pack's room and selling are not simulated: half the points on a
## floor are looted (OPEN_SHARE), and loot is not sold, so gold is a floor.

const RUN_CAP := 40
const CACHES_PER_FLOOR := 13
const OPEN_SHARE := 0.5
const SEED := 20261104

var game: GameManager
var failures := 0
var rng := RandomNumberGenerator.new()
## Materials brought home so far, by id; the gold so far.
var stock := {}
var gold := 0
## Per region, the deepest camp unlocked (0: none), and runs made.
var camp := {"mine": 0, "city": 0, "snow": 0, "siracusa": 0}
var runs := 0
var first_run := true
var report: Array = []
## What each beat ran out of before it could pay (the bottleneck), by beat.
var short_of := {}
var beat_now := ""

func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool, detail: Variant = null) -> void:
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label + ("" if detail == null or passed else "  %s" % str(detail)))

func open_regions() -> Array:
	return camp.keys().filter(func(r): return Story.region_open(game.base.story, r))

## One contract in `region` from its deepest camp to the next (the first run
## stops at its extraction, floor 5). Returns the floors it covered.
## `below`: start from the deepest camp under that floor (to go back for one shallower).
func sim_run(region: String, below: int = 100000) -> Array:
	runs += 1
	var from: int = int(camp[region])
	while from >= below: from -= FieldCatalog.CAMP_INTERVAL
	from = maxi(from, 0)
	var start: int = from + 1
	var last: int = 5 if first_run else from + FieldCatalog.CAMP_INTERVAL
	first_run = false
	var floors := range(start, last + 1)
	for f in floors:
		if f % FieldCatalog.CAMP_INTERVAL == 0: continue
		var kinds := LootTables.plan_points(region, CACHES_PER_FLOOR, rng)
		for i in range(roundi(kinds.size() * OPEN_SHARE)):
			var ctx := {"region": region, "depth": f, "reward": 1.0, "rng": rng, "pity": {}, "set_seen": {}, "drop_pct": 0.0, "field": {}}
			for drop in LootTables.container_drops(kinds[i], ctx):
				var it: Variant = drop.get("item")
				if it is Item and (it as Item).category == Item.Category.MATERIAL:
					stock[(it as Item).material_id] = int(stock.get((it as Item).material_id, 0)) + (it as Item).quantity
	if last % FieldCatalog.CAMP_INTERVAL == 0:
		camp[region] = maxi(int(camp[region]), last)
		game.base.unlock_camp(region, last)
	var offers: Array = game.contract_offers(region)
	gold += Economy.contract_reward(offers[0], start) if not offers.is_empty() else 0
	return floors

## Runs in the open regions, round robin, until `cost` (materials) and `price`
## (gold) are in hand; pays them. Returns "" or what was still short.
func farm(cost: Dictionary, price: int, beat_runs: Array) -> String:
	var turn := 0
	while true:
		var short := []
		for id in cost:
			if int(stock.get(id, 0)) < int(cost[id]): short.append("%s %d/%d" % [id, int(stock.get(id, 0)), int(cost[id])])
		if gold < price: short.append("龙门币 %d/%d" % [gold, price])
		if turn == 0 and not short.is_empty(): (short_of.get_or_add(beat_now, []) as Array).append(", ".join(short))
		if short.is_empty():
			for id in cost: stock[id] = int(stock[id]) - int(cost[id])
			gold -= price
			return ""
		if beat_runs[0] >= RUN_CAP: return ", ".join(short)
		var regions := open_regions()
		sim_run(regions[turn % regions.size()])
		turn += 1
		beat_runs[0] += 1
	return ""

## A facility one level up: its operator must be back, then the cost.
func build(id: String, beat_runs: Array) -> String:
	var lost := game.dept_refusal(id)
	if not lost.is_empty(): return "%s：%s" % [BaseCatalog.facility_name(id), lost]
	var gate := game.gate_refusal(id)
	if not gate.is_empty(): return "%s：%s" % [BaseCatalog.facility_name(id), gate]
	var level := game.base.facility_level(id) + 1
	var s := BaseCatalog.facility_step(id, level)
	var short := farm(s.get("materials", {}), int(s.get("price", 0)), beat_runs)
	if not short.is_empty(): return "%s Lv%d 缺 %s" % [BaseCatalog.facility_name(id), level, short]
	game.base.set_facility(id, level)
	return ""

## The first research of `dept` (or any) that needs nothing first.
func first_research(dept: String) -> String:
	for id in ResearchCatalog.NODES:
		if not dept.is_empty() and ResearchCatalog.department_of(id) != dept: continue
		if ResearchCatalog.prerequisite_nodes(id).is_empty() and ResearchCatalog.conditions(id).is_empty() and ResearchCatalog.camp_needed(id) <= 0: return id
	return ""

func research(dept: String, beat_runs: Array) -> String:
	if game.base.facility_level("lab") < 1:
		var b := build("lab", beat_runs)
		if not b.is_empty(): return b
	var id := first_research(dept)
	if id.is_empty(): return "没有可开始的%s研究" % ("" if dept.is_empty() else dept)
	var lost := game.research.refusal(id)
	if lost.contains("失散"): return lost
	var short := farm(ResearchCatalog.materials(id), ResearchCatalog.price(id), beat_runs)
	if not short.is_empty(): return "研究%s 缺 %s" % [ResearchCatalog.name_of(id), short]
	game.base.research.done.append(id)
	return ""

## Floor `f` of `region` reached: runs from the deepest camp below it on.
func reach(region: String, f: int, beat_runs: Array) -> String:
	if not Story.region_open(game.base.story, region): return "%s 还没开放" % FieldCatalog.REGIONS[region].name
	# A camp floor reached once counts (she has stood there).
	if f % FieldCatalog.CAMP_INTERVAL == 0 and int(camp[region]) >= f: return ""
	while true:
		var covered := sim_run(region, f)
		beat_runs[0] += 1
		if covered.has(f): return ""
		if beat_runs[0] >= RUN_CAP: return "%d 次外勤仍到不了第 %d 层" % [RUN_CAP, f]
	return ""

func goal(id: String, beat_runs: Array) -> String:
	var state: Dictionary = game.base.story
	if Story.FIND_GOALS.has(id):
		var who: String = Story.FIND_GOALS[id]
		# Her floor is rolled anew each run within her range: a run over all of it finds her.
		var floors := LostCatalog.floors(who)
		var out := reach(LostCatalog.region_of(who), floors[floors.size() - 1], beat_runs)
		if out.is_empty(): game.base.find_lost(who)
		return out
	match id:
		"first_contract":
			sim_run("mine")
			beat_runs[0] += 1
			game.story_note("contract")
		"shelve", "order", "bench_equip", "insure", "store_potion", "personnel", "lift":
			game.story_note(id)
		"treat": pass
		"camp":
			var out := reach("mine", FieldCatalog.CAMP_INTERVAL, beat_runs)
			if out.is_empty(): camp["mine"] = maxi(int(camp["mine"]), FieldCatalog.CAMP_INTERVAL)
			if not out.is_empty(): return out
			game.story_note("camp")
		"hub_parts", "hub_built":
			if game.base.hub_built(): return ""
			return build("hub", beat_runs)
		"hub_link":
			var short := farm(BaseCatalog.connect_materials("warehouse"), int(BaseCatalog.CONNECT_COST.price), beat_runs)
			if not short.is_empty(): return "接入总控台 缺 " + short
			game.base.connect_facility("warehouse")
		"outfit_up":
			var lost := game.dept_refusal("outfit")
			if not lost.is_empty(): return "背包扩容：" + lost
			var short := farm(BaseCatalog.PACK_MATERIALS[1], int(BaseCatalog.PACK_PRICES[1]), beat_runs)
			if not short.is_empty(): return "背包扩容 缺 " + short
			game.base.pack_level = 1
		"warehouse_up": return build("warehouse", beat_runs)
		"joined":
			# A trace on 20% of floors, six for a 寻访合同, then her floor.
			var clues := 0
			while clues < RecruitCatalog.CLUES_NEEDED:
				if beat_runs[0] >= RUN_CAP: return "踪迹 %d/%d" % [clues, RecruitCatalog.CLUES_NEEDED]
				for f in sim_run("mine"):
					if rng.randf() < 0.2: clues += 1
				beat_runs[0] += 1
			sim_run("mine")
			beat_runs[0] += 1
			game.base.recruit(RecruitCatalog.in_region("mine")[0])
		"sailed":
			var lost := game.dept_refusal("voyage")
			if not lost.is_empty(): return "航行：" + lost
			var to := "萨米"
			var short := farm({}, game.voyage.voyage_cost(to, "standard"), beat_runs)
			if not short.is_empty(): return "航行 缺 " + short
			game.story_note("sailed")
		"away":
			var other: Array = open_regions().filter(func(r): return r != "mine")
			if other.is_empty(): return "没有新的地区"
			sim_run(other[0])
			beat_runs[0] += 1
			game.story_note("away")
		"crafted":
			var lost := game.dept_refusal("workshop")
			if not lost.is_empty(): return "加工：" + lost
			var r: Dictionary = Workshop.recipe("固源岩")
			var short := farm(r["in"], int(r.lmd), beat_runs)
			if not short.is_empty(): return "加工 缺 " + short
			game.story_note("crafted")
		"researching":
			var out := research("", beat_runs)
			if not out.is_empty(): return out
			game.story_note("research")
		"intel_research": return research("intel", beat_runs)
		"sowed":
			var out := build("farm", beat_runs)
			if not out.is_empty(): return out
			game.story_note("sowed")
		"meal":
			var out := build("canteen", beat_runs)
			if not out.is_empty(): return out
			game.story_note("meal")
		"exchange": return build("exchange", beat_runs)
		_: return "测试不认识的目标 " + id
	return ""

func run() -> void:
	rng.seed = SEED
	SystemScreens.settings.story_guide = true
	game = GameManager.new()
	game.save_enabled = false
	root.add_child(game)
	await step(6)
	game.seed_rng(SEED)
	game.base.start_locked()
	game.base.story = Story.fresh()
	var state: Dictionary = game.base.story
	var safety := 0
	while not Story.all_done(state) and safety < 40:
		safety += 1
		var beats := Story.active(state)
		if beats.is_empty(): break
		for b in beats:
			beat_now = b.title
			var beat_runs := [0]
			var blocked := ""
			for g in b.goals:
				if g[0] in state.done: continue
				var out := goal(g[0], beat_runs)
				if not out.is_empty():
					blocked = out
					break
				Story.update(game, state)
			Story.update(game, state)
			report.append([b.title, beat_runs[0], blocked])
			check("%s：%d 次外勤%s" % [b.title, beat_runs[0], "" if blocked.is_empty() else "，卡在 " + blocked], blocked.is_empty() and beat_runs[0] <= RUN_CAP)
			if not blocked.is_empty():
				print("FLOW STOPPED at %s" % b.title)
				_print_report()
				quit(1)
				return
	check("all 13 beats done", Story.all_done(state), state.done)
	_print_report()
	quit(1 if failures else 0)

func _print_report() -> void:
	print("FLOW REPORT: %d runs in all, gold left %d" % [runs, gold])
	for row in report: print("  %-6s %3d 次外勤  %s  短缺：%s" % [row[0], row[1], row[2], " | ".join(short_of.get(row[0], []))])
	var left: Array = stock.keys().filter(func(k): return int(stock[k]) > 0 and not str(k).is_empty())
	left.sort_custom(func(a, b): return int(stock[a]) > int(stock[b]))
	print("  materials left: %s" % ", ".join(left.slice(0, 12).map(func(k): return "%s×%d" % [k, int(stock[k])])))
	print("FLOW FAILURES: %d" % failures)
