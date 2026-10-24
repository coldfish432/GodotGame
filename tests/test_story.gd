extends SceneTree
## 主线引导 (主基地线性叙事与教程策划案 v0.2): the beats go in order, their
## goals tick themselves, the dialogue comes once per beat, the first contract
## is fixed, regions wait for the first voyage, the first run must extract at
## a random extraction, old saves count as done, and the setting turns it off.
var game: GameManager
var story: StoryCard
var failures := 0
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool) -> void:
	print(("PASS " if passed else "FAIL ") + label)
	if not passed: failures += 1
func current() -> Array:
	return Story.active(game.base.story).map(func(b): return b.id)
func run() -> void:
	SystemScreens.settings.story_guide = true
	SystemScreens.settings.tutorial_step = TutorialCard.STEPS.size()
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	await step(3)
	story = game.story_card
	var state: Dictionary = game.base.story
	check("a new Doctor starts at 苏醒", current() == ["wake"] and state.done.is_empty())
	check("not shown outside the real game", story.speaking.is_empty() and not story._card.visible)
	story.forced = true
	await step(15)
	check("苏醒's lines come up over the base, the base stopped", story.speaking == "wake" and game.modal == "story" and story._speaker.text == "PRTS" and story._line.text == "系统同步完成。欢迎回来，博士。")
	check("PRTS has no standing art", not story._face.visible)
	story.advance()
	check("继续: 阿米娅, her full-body art at 2× on the left, the box beside it", story._speaker.text == "阿米娅" and story._face.visible and story._face.size == StoryCard.STANDING and story._face.position.x < story._talk.position.x)
	story.advance()
	await step(2)
	check("after the last line the base walks on", story.speaking.is_empty() and game.modal.is_empty() and "wake" in state.seen)
	await step(15)
	check("the lines come once", story.speaking.is_empty())
	check("the objective card: 主线, its goal", story._card.visible and story._card_title.text == "苏醒" and story._goals.get_child_count() == 1)
	# Regions and the first contract.
	check("before the first voyage only 切尔诺伯格", game.region_open("mine") and not game.region_open("city") and not game.region_open("snow"))
	SystemScreens.settings.story_guide = false
	check("with the thread off, every region", game.region_open("city"))
	SystemScreens.settings.story_guide = true
	var first: Dictionary = game.contract_offers("mine")[0]
	check("the first contract is 回收 源岩 ×6", first.type == "recover" and first.material == "源岩" and int(first.count) == 6)
	await game.start_contract("mine")
	await step(20)
	check("starting it ends 苏醒 and begins 归舰", current() == ["return"] and "first_contract" in state.done)
	check("no card in the field", not story._card.visible)
	# The first run's 源岩: six by floor 2 at the latest, natural drops counted.
	var ore := func() -> int:
		var n := 0
		for node in game.get_children():
			if node is Loot and (node as Loot).item != null and (node as Loot).item.item_name == "源岩": n += (node as Loot).item.quantity
		return n
	var start_ore: int = ore.call()
	game.spawn_enemy_drops(game._spawn_enemy(game.player.global_position + Vector3(3, 0, 0), false, false))
	check("floor 1's first kill: at least 3 源岩 so far", game.first_run_ore >= 3 and ore.call() - start_ore >= 3)
	game.floor_number = 2
	game.spawn_enemy_drops(game._spawn_enemy(game.player.global_position + Vector3(-3, 0, 0), false, false))
	check("floor 2's: six in all", game.first_run_ore >= 6 and ore.call() - start_ore >= 6)
	game.floor_number = 3
	check("then nothing more is owed", game.orirock_owed() == 0)
	game.first_run_ore = 0
	game.base.extracted_once = true
	check("once she has extracted, no top-up", game.orirock_owed() == 0)
	game.base.extracted_once = false
	game.floor_number = 1
	# The first run: a floor with a random extraction lets her go no deeper.
	game.system_screens = SystemScreens.new()
	game.floor_number = 5
	game._roll_random_extraction()
	check("the first floor 5 has its extraction", game.is_extraction_floor())
	check("and until she extracts, no deeper", game.first_run_lock())
	game.floor_number = 3
	game._random_extraction_available = false
	check("a floor without one is free to leave", not game.first_run_lock())
	game.floor_number = 5
	game._random_extraction_available = true
	game.system_screens.free()
	game.system_screens = null
	game.settle(true)
	for i in range(240):
		if game.in_base and not game.transitioning: break
		await step()
	game.close_modal()
	check("extracting marks it", game.base.extracted_once and not state.fell)
	await step(15)
	check("归舰's lines, after an extraction: PRTS", story.speaking == "return" and story._speaker.text == "PRTS")
	story.go_back()
	await step(2)
	check("Esc skips the rest", story.speaking.is_empty() and game.modal.is_empty())
	check("a retreat would have had 凯尔希", Story.lines_of({"fell": true}, Story.beat("return"))[0][0] == "凯尔希")
	# 仓库修订 (用户 2026-10-23): no crates to open; 归舰 is shelve, order, treat.
	check("治疗重伤 is hidden when nobody is hurt", story._goals.get_child_count() == 2)
	check("归舰 has no crate goal any more", Story.beat("return").goals.map(func(g): return g[0]) == ["shelve", "order", "treat"])
	var brought := MaterialCatalog.create("螺栓", 3)
	game.inventory.try_add(brought)
	check("一键入库 stores what she brought and counts as 存进仓库", game.store_all_carried() >= 1 and not game.inventory.items.has(brought) and Story.count(state, "shelve") > 0)
	game.story_note("order")
	await step(20)
	check("shelf and order end 归舰; 整备 begins", current() == ["outfit"] and story.speaking == "outfit" and story._speaker.text == "杜宾")
	check("杜宾 (ST1a): her standing art, mirrored to face the box", story._face.visible and story._face.flip_h and story._face.texture.resource_path.ends_with("npc_dobermann.png"))
	story.go_back()
	for event in ["bench_equip", "insure"]: game.story_note(event)
	await step(20)
	check("then 基建, 可露希尔 with her standing art", current() == ["hub"] and story._speaker.text == "可露希尔" and story._face.visible and story._face.texture.resource_path.ends_with("npc_closure.png"))
	story.go_back()
	# 基建: parts, the hub, the warehouse connected.
	game.base.set_facility("hub", 1)
	game.base.connected.append("warehouse")
	await step(20)
	check("the hub built and connected ends 基建 (the parts count as had)", current() == ["supply"])
	story.go_back()
	for event in ["store_potion", "camp"]: game.story_note(event)
	await step(20)
	check("after 补给线, 寻访 and 航行 run side by side", current() == ["recruit", "voyage"])
	story.go_back()
	await step(15)
	story.go_back()
	await step(15)
	check("both cards at once on the objective card", story._card_title.text == "寻访 · 航行" and story._goals.get_child_count() == 4)
	game.story_note("sailed")
	check("a voyage opens the other regions", game.region_open("city") and game.region_open("siracusa"))
	# An old save: everything behind her.
	var old := BaseState.new()
	old.load_data({}, {})
	check("an old save: the thread done, extracted before", Story.all_done(old.story) and old.extracted_once)
	var again := BaseState.new()
	again.load_data(game.base.to_data(), {})
	check("the thread's state is saved", again.story.done == state.done and again.story.seen == state.seen and not again.extracted_once == false)
	# Off: no card, no lines.
	SystemScreens.settings.story_guide = false
	await step(5)
	check("off: no card", not story._card.visible)
	SystemScreens.settings.story_guide = true
	print("STORY FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
