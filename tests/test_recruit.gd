extends SceneTree

## 干员寻访 R1 (干员寻访策划案_v0_1.md §2, §9): the roster a new Doctor starts
## with, traces, the 寻访合同 card, her floor's 寻访点 and guard, joining on
## extraction (not on a fall), the 人事部 screen, the hall's roster figures and
## the save; and the first recruits' sheets.

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
	game.fixed_map_seed = 4242
	root.add_child(game)
	await step(8)
	await _traces_and_card()
	await _recruit_floor()
	await _fall_keeps_traces()
	await _base_and_save()
	print("RECRUIT RESULT: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await step(2)
	quit(1 if failures else 0)

func _catalog() -> void:
	var state := BaseState.new()
	check("a new Doctor has only Amiya", state.roster == [Operators.AMIYA_GUARD] and state.operator == Operators.AMIYA_GUARD)
	check("every recruit has a region the game has", RecruitCatalog.RECRUITS.keys().all(func(id): return FieldCatalog.REGIONS.has(RecruitCatalog.region_of(id))))
	check("two recruits per region", FieldCatalog.REGIONS.keys().all(func(r): return RecruitCatalog.in_region(r).size() == 2))
	check("every operator has its sheets and portrait", Operators.ORDER.all(func(id): return LapplandAnimator3D.CHARACTERS.has(id) and LapplandAnimator3D.sheet(id, "walk") != null and LapplandAnimator3D.sheet(id, "idle") != null and Operators.portrait(id) != null))
	var offsets := RecruitCatalog.RECRUITS.keys().map(func(id): return RecruitCatalog.floor_offset(id))
	check("her floor is 4–6 past the start %s" % [offsets], offsets.all(func(o): return o >= 4 and o <= 6))
	check("only built kits deploy", state.deployable().all(func(id): return Operators.has_kit(id)))
	for id in ["hellagur", "typhon"]:
		var walk: Texture2D = LapplandAnimator3D.sheet(id, "walk")
		var image := walk.get_image()
		# The 1 px dark outline (用户 2026-10-16): the front frame's edge is near black.
		var dark := 0
		var edge := 0
		for y in range(32):
			for x in range(32, 64):
				if image.get_pixel(x, y).a == 0.0: continue
				var open := false
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q: Vector2i = Vector2i(x, y) + d
					if q.x < 32 or q.x >= 64 or q.y < 0 or q.y >= 32 or image.get_pixel(q.x, q.y).a == 0.0: open = true
				if open:
					edge += 1
					if image.get_pixel(x, y).v < 0.1: dark += 1
		# A few may touch the cell's own edge, where there is no room for the line.
		check("%s is outlined in dark (%d/%d edge texels)" % [id, dark, edge], edge > 0 and dark >= edge * 0.95)

func _traces_and_card() -> void:
	game.base.recruit_clues.clear()
	var offers := game.contract_offers("mine").size()
	check("no 寻访合同 before her traces are in", not game.contract_offers("mine").any(func(o): return o.type == "recruit"))
	game.region_id = "mine"
	var before := game.prts_log.size()
	for i in range(RecruitCatalog.CLUES_NEEDED * 2 + 2): game._find_clue()
	check("traces go to this region's recruits, at most %d each" % RecruitCatalog.CLUES_NEEDED, RecruitCatalog.in_region("mine").all(func(id): return game.base.clues(id) == RecruitCatalog.CLUES_NEEDED))
	check("PRTS speaks at the first trace", game.prts_log.size() > before)
	var cards: Array = game.contract_offers("mine").filter(func(o): return o.type == "recruit")
	check("the dispatch desk offers a 寻访合同 for each, besides the three (%d)" % cards.size(), cards.size() == 2 and game.contract_offers("mine").size() == offers + 2)
	check("other regions get none", not game.contract_offers("snow").any(func(o): return o.type == "recruit"))
	check("its goal and reward read on the card", FieldCatalog.contract_goal(cards[0], "mine", 1).begins_with("寻访") and FieldCatalog.contract_bonus_text(cards[0]).ends_with("入职"))

func _recruit_floor() -> void:
	var id := "hellagur"
	game._pending_contract = RecruitCatalog.contract_for(id)
	await game.start_contract("mine")
	await step(2)
	check("no 寻访点 before her floor", not is_instance_valid(game.recruit_node))
	game.floor_number = game.start_floor + int(game.contract.offset) - 1
	await game.advance(0)
	await step(4)
	check("on her floor she stands at her 寻访点", is_instance_valid(game.recruit_node) and game.floor_number == game.start_floor + int(game.contract.offset), game.floor_number)
	check("guarded by a squad led by an elite", game._recruit_post != null and game._recruit_post.guards.size() >= 2 and game._recruit_post.guards.any(func(e): return e.elite))
	game.player.teleport(game.recruit_node.global_position + Vector3(0.6, 0, 0))
	await step(2)
	check("the prompt names her", game.interaction_prompt() == Operators.display_name(id), game.interaction_prompt())
	game._interact()
	check("she will not come while the guard stands", not game.recruit_met)
	for enemy in game._recruit_post.guards: kill(enemy)
	# Nothing else on the floor may cut in (a wanderer, a trap under her).
	for enemy in game.floor_enemies(): kill(enemy)
	for trap in game.traps: trap.spent = true
	await step(3)
	game.player.teleport(game.recruit_node.global_position + Vector3(0.6, 0, 0))
	await step(2)
	var before := "sim=%s busy=%s nearby=%s cleared=%s near=%s" % [game.simulation_active(), game.hands_busy(), game._recruit_nearby(), game.recruit_guard_cleared(), game.player.global_position.distance_to(game.recruit_node.global_position)]
	game._interact()
	check("cleared, she agrees: the objective is done", game.recruit_met and game.contract_progress().done, before)
	game.settle(true)
	await step(2)
	check("extracting, she joins the roster", game.base.recruited(id) and game.base.clues(id) == 0)
	check("and her card is gone", not game.contract_offers("mine").any(func(o): return o.get("operator", "") == id))
	# R2 (干员寻访策划案 §14): every recruit's kit is built, so she deploys.
	check("with her kit built she deploys", id in game.base.deployable())
	var walker := game.base.operator
	game.choose_operator(id)
	check("so she can be chosen at the departure card", game.base.operator == id)
	game.choose_operator(walker)

func _fall_keeps_traces() -> void:
	var id := "rosa"
	game._pending_contract = RecruitCatalog.contract_for(id)
	await game.start_contract("mine")
	await step(2)
	game.settle(false)
	await step(2)
	check("a fall: she has not joined", not game.base.recruited(id))
	check("her traces stay and the card stays", game.base.clues(id) == RecruitCatalog.CLUES_NEEDED and game.contract_offers("mine").any(func(o): return o.get("operator", "") == id))

func _base_and_save() -> void:
	await step(4)
	check("the hall shows the joined operators but the walker", is_instance_valid(game._roster_figures) and game._roster_figures.get_children().any(func(f): return f.get_meta("operator", "") == "hellagur"))
	game.open_station("personnel")
	await step(2)
	check("the 人事部 terminal opens its roster", game.modal == "station")
	game.close_modal()
	check("the hall has a 人事部 terminal", not game.base_map.station("personnel").is_empty())
	var data := game.base.to_data()
	var copy := BaseState.new()
	copy.load_data(data, {})
	check("roster and traces survive a save", copy.recruited("hellagur") and copy.clues("rosa") == RecruitCatalog.CLUES_NEEDED)
	var old := data.duplicate(true)
	old.erase("roster")
	old.erase("recruit_clues")
	var legacy := BaseState.new()
	legacy.load_data(old, {})
	check("a save from before recruiting keeps both its operators", legacy.recruited(Operators.AMIYA_GUARD) and legacy.recruited(Operators.LAPPLAND))
