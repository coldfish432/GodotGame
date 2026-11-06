extends SceneTree

## 失散干员 (失散干员与主线流程策划案_v0_2.md): the eight special operators,
## their floors (base ±2, never a camp or boss floor, rolled every contract),
## the departments shut until they are back, her spot with its squad, E only
## once the squad is down, back at once (a retreat does not undo it), the
## roster tab, who walks the base, and the save (old saves: all back, nothing shut).

var game: GameManager
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool, detail: Variant = null) -> void:
	checks += 1
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label + ("" if detail == null or passed else "  %s" % str(detail)))

func kill(enemy) -> void:
	if is_instance_valid(enemy) and not enemy._dead: enemy.take_hit(99999999.0, "true")

func run() -> void:
	_catalog()
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 5150
	game.route_plain = true
	root.add_child(game)
	await step(8)
	game.base.start_locked()
	_locks()
	await _field()
	await _base_side()
	_save()
	print("LOST RESULT: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await step(2)
	quit(1 if failures else 0)

func _catalog() -> void:
	check("eight special operators", LostCatalog.LOST.size() == 8)
	check("each in a region the game has", LostCatalog.LOST.keys().all(func(id): return FieldCatalog.REGIONS.has(LostCatalog.region_of(id))))
	var floors_ok := true
	for id in LostCatalog.LOST:
		for f in LostCatalog.floors(id):
			if f % 10 == 0 or absi(f - int(LostCatalog.LOST[id].floor)) > LostCatalog.SPREAD: floors_ok = false
	check("floors stay within ±2 and skip camp / boss floors", floors_ok)
	check("机械师: 7–9 and 11 (10 skipped)", LostCatalog.floors("mechanist") == [7, 8, 9, 11] and LostCatalog.range_text("mechanist") == "7–11")
	# Every find goal names the floors the catalog gives.
	var texts_ok := true
	for beat in Story.BEATS:
		for g in beat.goals:
			if Story.FIND_GOALS.has(g[0]):
				var id: String = Story.FIND_GOALS[g[0]]
				if not str(g[1]).contains("第 %s 层" % LostCatalog.range_text(id)) or not str(g[1]).contains(LostCatalog.name_of(id)): texts_ok = false
	check("the find goals name her floors and name", texts_ok and Story.FIND_GOALS.size() == 8)
	check("every department key has one owner", ["outfit", "voyage", "warehouse", "lab", "workshop", "intel", "farm", "canteen", "exchange"].all(func(d): return LostCatalog.LOST.has(LostCatalog.owner_of(d))))
	check("可露希尔's store and the hub have none", LostCatalog.owner_of("store").is_empty() and LostCatalog.owner_of("hub").is_empty())
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var seen := {}
	for i in range(200): seen[LostCatalog.roll("sharp", 1, rng)] = true
	check("a roll lands on each of her floors over time", seen.keys().size() == LostCatalog.floors("sharp").size())
	check("a start past all her floors: she is not there", LostCatalog.roll("sharp", 11, rng) == -1)
	check("a start inside her range only rolls the floors ahead", range(50).all(func(_i): return LostCatalog.roll("stormeye", 17, rng) >= 17))
	var bare := BaseState.new()
	check("a bare BaseState (tools, tests): all back, nothing shut", not bare.dept_lock and bare.lost_found.size() == 8 and bare.dept_missing("lab").is_empty())

func _locks() -> void:
	game.gold = 99999999
	check("a new save: every special operator missing", game.base.lost_found.is_empty() and game.base.dept_lock)
	check("the 整备部 levels wait for Sharp", game.facility_refusal("outfit").contains("Sharp"))
	check("so do the pack and the safe bag", game.upgrade_refusal("pack").contains("Sharp") and game.upgrade_refusal("safe").contains("Sharp"))
	check("the 仓储部 levels wait for Misery", game.facility_refusal("warehouse").contains("Misery"))
	check("the 科研部 waits for Pith", game.facility_refusal("lab").contains("Pith"))
	check("the 加工部 is shut until 机械师", game.facility_refusal("workshop").contains("机械师") and game.workshop_refusal(Workshop.RECIPES.keys()[0], 1).contains("机械师"))
	check("the farm and the canteen wait for Touch", game.facility_refusal("farm").contains("Touch") and game.facility_refusal("canteen").contains("Touch"))
	check("the exchange waits for 郁金香 (after its faction gate)", game.dept_refusal("exchange").contains("郁金香"))
	check("no voyage until Stormeye", game.voyage.voyage_refusal("萨米", "standard").contains("Stormeye"))
	check("可露希尔's store is never shut", not game.facility_refusal("store").contains("失散"))
	check("linking to the hub is not shut", not game.connect_refusal("warehouse").contains("失散"))
	game.base.set_facility("lab", 1)
	game.base.find_lost("pith")
	var intel := "intel_1"
	check("情报部 research waits for 电弧", game.research.refusal(intel).contains("电弧"))
	game.base.find_lost("raidian")
	check("back, 情报部 research is open", not game.research.refusal(intel).contains("失散"))
	check("Pith back: the 科研部 levels open", not game.facility_refusal("lab").contains("失散"))
	# Undo for the field run below.
	game.base.lost_found.clear()
	game.base.set_facility("lab", 0)

func _field() -> void:
	game.base.find_lost("stormeye")
	await game.start_contract("mine")
	await step(2)
	check("the contract rolls Sharp's floor, in her range", game.lost_floor.has("sharp") and int(game.lost_floor.sharp) in LostCatalog.floors("sharp"), game.lost_floor)
	check("one already back is not rolled", not game.lost_floor.has("stormeye"))
	check("nobody on floor 1", not is_instance_valid(game.lost_node))
	game.lost_floor.sharp = game.floor_number + 1
	var before := game.prts_log.size()
	await game.advance(0)
	await step(4)
	check("on her floor she stands guarded", is_instance_valid(game.lost_node) and game.lost_id == "sharp" and game._lost_post != null and game._lost_post.guards.any(func(e): return e.elite))
	check("PRTS names her signal", game.prts_log.size() > before)
	game.player.teleport(game.lost_node.global_position + Vector3(0.6, 0, 0))
	await step(2)
	check("the prompt names her", game.interaction_prompt() == "Sharp", game.interaction_prompt())
	game._interact()
	check("she will not come while the squad stands", not game.base.lost_back("sharp"))
	for enemy in game._lost_post.guards: kill(enemy)
	for enemy in game.floor_enemies(): kill(enemy)
	for trap in game.traps: trap.spent = true
	await step(3)
	game.player.teleport(game.lost_node.global_position + Vector3(0.6, 0, 0))
	await step(2)
	game._interact()
	check("cleared, E: she is back at once", game.base.lost_back("sharp") and not is_instance_valid(game.lost_node))
	check("the run's save keeps the rolled floors", "lost_floor" in RunSave.GAME_KEYS)
	game.settle(false)
	for i in range(240):
		if game.in_base and not game.transitioning: break
		await step()
	check("a retreat after does not undo it", game.base.lost_back("sharp") and game.dept_refusal("outfit").is_empty())

func _base_side() -> void:
	game.close_modal()
	var walkers := BaseCrew.pool(game.base)
	check("the base: Sharp and Stormeye walk, the ones still missing do not", "sharp" in walkers and "stormeye" in walkers and not "pith" in walkers and not "misery" in walkers)
	check("the reserve operators no longer walk", not walkers.any(func(id): return str(id).begins_with("reserve_")))
	check("杜宾 and 凯尔希 walk (sheets in)", ["dobermann", "kaltsit"].all(func(id): return id in walkers or not LapplandAnimator3D.has_sheets(id)))
	BaseScreens.personnel_tab = 1
	game.open_station("personnel")
	await step(2)
	check("the 人事部 has the special operators' tab", game.modal == "station")
	game.close_modal()
	BaseScreens.personnel_tab = 0

func _save() -> void:
	var copy := BaseState.new()
	copy.load_data(game.base.to_data(), {})
	check("saved: who is back and that departments wait", copy.dept_lock and copy.lost_found == game.base.lost_found)
	var old := BaseState.new()
	old.load_data({}, {})
	check("an old save: everyone back, nothing shut", not old.dept_lock and old.lost_found.size() == 8 and old.dept_missing("workshop").is_empty())
	var finished := Story.finished_state()
	finished.done.erase("found_sharp")
	var thread_done := BaseState.new()
	thread_done.load_data({"story": {"done": ["exchange"], "seen": [], "counts": {}, "fell": false}}, {})
	check("an old finished thread stays finished", Story.all_done(thread_done.story))
	check("no return talks on an old save", Story.lost_back_talks(old).is_empty())
