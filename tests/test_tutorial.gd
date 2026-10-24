extends SceneTree
## 新手引导 (用户 2026-10-22: 做简单教程 → 游戏内首次引导；以 PRTS 的口吻，
## 群星式挂在右侧的教程卡片；教程覆盖所有操作，基础操作游戏开始就教；密室、
## 踪迹、火堆、陷阱等第一次在屏幕中遇到后暂停、蒙板高亮圈出目标并显示 PRTS
## 卡片). The basic card: eleven steps, each box ticks when she does it and the
## next follows; hidden under menus; skip and the settings switch. The
## first-sight card: the field stops, a ring round the thing, once per kind.
var game: GameManager
var card: TutorialCard
var spot: TutorialSpotlight
var failures := 0
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool) -> void:
	print(("PASS " if passed else "FAIL ") + label)
	if not passed: failures += 1
## Lets the check run, then waits out the ticked box.
func tick_through() -> bool:
	await step(2)
	var ticked := card.ticked()
	card._process(TutorialCard.TICK_SECONDS + 0.05)
	await step(2)
	return ticked
## Waits (up to a few seconds) for `id`'s card; the spotlight checks every
## CHECK_SECONDS of real time.
func wait_tip(id: String) -> void:
	for i in range(600):
		if spot.showing == id: return
		await step()
func at_step(id: String) -> bool:
	return TutorialCard.step() < TutorialCard.STEPS.size() and TutorialCard.STEPS[TutorialCard.step()][0] == id
func run() -> void:
	SystemScreens.settings.tutorial_step = 0
	SystemScreens.settings.tutorial_tips = true
	SystemScreens.settings.tutorial_seen = []
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	await step(3)
	card = game.tutorial_card
	spot = game.tutorial_spotlight
	check("not shown outside the real game", not card.visible)
	card.forced = true
	await step(2)
	check("first step in the base, PRTS speaking", card.visible and at_step("move") and card._title.text == "行动确认" and "博士" in card._text.text)
	check("hangs on the right, above the bottom edge", is_equal_approx(card.position.x + card.size.x, TutorialCard.RIGHT) and is_equal_approx(card.position.y + card.size.y, TutorialCard.BOTTOM) and card.position.x > 900)
	game.player.teleport(game.player.global_position + Vector3(5, 0, 0))
	var ticked := await tick_through()
	check("walking ticks the box first", ticked)
	check("then the dodge, on board (用户 2026-10-24: 左键移动、右键闪现)", at_step("dodge") and card._keys.text == Keybinds.short_label(TutorialCard.dodge_action()) and card._keys.text != "")
	game.player.dash_remaining = 0.2
	await tick_through()
	game.player.dash_remaining = 0.0
	check("a dodge in the base ticks it off; then the camera", at_step("camera"))
	game.zoom_camera(1)
	await tick_through()
	check("zooming ticks it off", at_step("contract"))
	game.open_station("contracts")
	await step(2)
	check("hidden under a menu", not card.visible)
	game.close_modal()
	await game.start_contract("mine")
	await tick_through()
	check("starting a contract ticks it off", at_step("kill") and card.visible)
	game.run_kills["normal"] = int(game.run_kills.get("normal", 0)) + 1
	await tick_through()
	check("a kill ticks it off", at_step("skill") and card._keys.text == Keybinds.short_label(TutorialCard.skill_action()))
	game.player.dash_remaining = 0.0
	game.player._dash_cooldown = 0.0
	if game.player.has_skill():
		game.perform_hotbar_action("shadow")
	await tick_through()
	check("casting the skill ticks it off", at_step("search"))
	var box: LootContainer = null
	for node in game.get_tree().get_nodes_in_group("loot_containers"):
		if (node as LootContainer).game == game: box = node
	check("the floor has a box to search", box != null)
	if box != null: game.open_loot(box)
	await tick_through()
	check("opening a box ticks it off", at_step("pickup"))
	game.close_modal()
	game.try_collect(MaterialCatalog.create(Economy.GOLD_ID, 1, "mine"))
	await tick_through()
	check("a pickup ticks it off", at_step("inventory"))
	game.toggle_panel("inventory")
	await tick_through()
	check("opening the pack ticks it off", at_step("equip") and card._next.visible)
	var gear := Item.create("测试护手", Item.Category.HANDS, 1, 1)
	game.inventory.try_add(gear)
	game.equip_from(gear, game.inventory)
	await tick_through()
	check("putting on gear ticks it off", at_step("safe_bag"))
	game.safe_bag.try_add(Item.create("测试物", Item.Category.ARMOR, 1, 1))
	await tick_through()
	check("the safe bag ticks it off", at_step("operator"))
	game.close_modal()
	for entry in [["training", "operator", "relics"], ["relics", "relics", "journal"], ["journal", "journal", "map"]]:
		game.toggle_panel(entry[0])
		await tick_through()
		check("the %s panel ticks it off" % entry[1], at_step(entry[2]))
		game.close_modal()
	game.toggle_panel("map")
	await tick_through()
	check("the map ticks it off", at_step("hotbar"))
	game.close_modal()
	await step(2)
	check("a reading step: no objective, a 下一步 button", card.visible and not card._goal_row.visible and card._next.visible)
	card._next.pressed.emit()
	await tick_through()
	check("下一步 goes on", at_step("descend"))
	game.close_modal()
	await game.advance(0)
	await tick_through()
	check("going down a floor ticks it off", at_step("extract"))
	game.base.extracted_once = true
	await tick_through()
	check("extracting finishes it", TutorialCard.finished())
	check("PRTS signs off for a moment", card.visible and card._title.text == "引导完成" and not card._goal_row.visible)
	card._process(TutorialCard.DONE_SECONDS + 0.1)
	await step(1)
	check("then goes away", not card.visible)

	# --- First sight ---------------------------------------------------------------
	await step(3)
	check("no first-sight card outside the real game", spot.showing.is_empty())
	# Everything but the elite already seen, so the one in front of her is the one.
	SystemScreens.settings.tutorial_seen = TutorialSpotlight.TIPS.keys().filter(func(k): return k != "elite")
	spot.forced = true
	var elite := game._spawn_enemy(game.player.global_position + Vector3(3, 0, 1), true, false)
	elite.elite = true
	await step(20)
	check("an elite on screen stops the field", spot.showing == "elite" and game.modal == "tutorial" and not game.simulation_active())
	check("dim, a ring round it, PRTS's card", spot.visible and spot._title.text == "精英敌人" and spot.ring_at.distance_to(game.screen_point(elite.global_position + Vector3.UP * 0.8)) < 2.0)
	check("the card sits beside the ring, on screen", not Rect2(spot._card.position, spot._card.size).has_point(spot.ring_at) and Rect2(Vector2.ZERO, TutorialSpotlight.SCREEN).encloses(Rect2(spot._card.position, spot._card.size)))
	check("each kind is kept as seen", TutorialSpotlight.seen("elite"))
	spot.dismiss()
	await step(2)
	check("知道了 lets the field run", game.modal.is_empty() and game.simulation_active() and not spot.visible)
	game._spawn_enemy(game.player.global_position + Vector3(-3, 0, 1), true, false)
	await step(20)
	check("a second one is not shown again", spot.showing.is_empty())
	# Esc closes it too.
	SystemScreens.settings.tutorial_seen = []
	var found := spot.first_in_sight()
	check("something on screen to show", not found.is_empty())
	spot.show_tip(found.id, found.at)
	game.go_back()
	await step(2)
	check("Esc closes it", spot.showing.is_empty() and game.modal.is_empty())
	# A trap counts only up close.
	var trap_ids := spot.candidates().filter(func(e): return e[0] == "trap")
	check("the floor's traps are candidates", not trap_ids.is_empty())
	# A bar: a box, not a ring, and the card under it.
	SystemScreens.settings.tutorial_seen = []
	spot.show_tip("threat", TutorialSpotlight.TOP_BAR)
	check("a bar gets a box", spot.ring_box.size.x > 600.0 and spot._card.position.y > spot.ring_box.end.y)
	spot.dismiss()
	# An event with nothing to point at: the whole screen dims, the card in the middle.
	spot.request("death")
	await step(15)
	check("a retreat's card goes over whatever is up, no ring", spot.showing == "death" and spot.ring_radius == 0.0 and spot.ring_box.size.x == 0.0 and absf(spot._card.position.x + spot._card.size.x * 0.5 - 640.0) < 2.0)
	spot.dismiss()
	spot.request("death")
	check("an event's card comes once", spot._queue.is_empty())
	# Off: no cards at all.
	TutorialCard.set_on(false)
	SystemScreens.settings.tutorial_seen = []
	game._spawn_enemy(game.player.global_position + Vector3(2, 0, -1), true, false)
	await step(20)
	check("switched off, nothing shows", spot.showing.is_empty() and not card.visible)
	TutorialCard.set_on(true)
	await step(2)
	check("switching it on starts over", TutorialCard.step() == 0 and TutorialSpotlight.tips_on() and SystemScreens.settings.tutorial_seen.is_empty())
	card.skip_all()
	await step(1)
	check("skip ends the basic steps, first-sight cards stay on", TutorialCard.finished() and TutorialSpotlight.tips_on())
	# The base (用户 2026-10-23): before the first contract, once the waking talk
	# is over, one card rings 整备台, 调度台 (出击) and 后勤柜台 together; after
	# it a station's card comes the first time its screen opens, not on walking up.
	TutorialCard.set_on(true)
	SystemScreens.settings.tutorial_step = TutorialCard.index_of("contract")
	SystemScreens.settings.tutorial_seen = []
	game.settle(true)
	for i in range(240):
		if game.in_base and not game.transitioning: break
		await step()
	game.close_modal()
	if not "wake" in game.base.story.seen: game.base.story.seen.append("wake")
	check("the departure stations are all in the base", TutorialSpotlight.DEPARTURE.all(func(e): return not game.base_map.station(str(e[0])).is_empty()))
	await wait_tip("base_departure")
	check("before the first contract one card rings all three at once", spot.showing == "base_departure" and spot.more_rings.size() == 2 and game.modal == "tutorial")
	check("each has its own card: 调度台 is where to sortie, 后勤柜台 says 制式 needs no insurance", "出击" in spot._text.text and spot._notes.size() == 2
		and spot._notes.any(func(n): return "整备台" in str(n.find_children("*", "Label", true, false).map(func(l): return l.text)))
		and spot._notes.any(func(n): return "无需投保" in str(n.find_children("*", "Label", true, false).map(func(l): return l.text))))
	var screen := Rect2(Vector2.ZERO, TutorialSpotlight.SCREEN)
	check("all three rings are on screen, a card beside each", screen.has_point(spot.ring_at) and spot.more_rings.all(func(p): return screen.has_point(p))
		and spot._notes.all(func(n): return screen.encloses(Rect2(n.position, n.size))))
	spot.dismiss()
	await step(4)
	check("after it the base walks on, the cards gone, and the 后勤柜台's own card is not repeated", game.modal.is_empty() and spot.showing.is_empty() and spot._notes.is_empty() and TutorialSpotlight.seen("base_insurance"))
	SystemScreens.settings.tutorial_step = TutorialCard.index_of("contract") + 1
	game.player.teleport(game.base_map.station("lift").position)
	await step(20)
	check("walking up to a station shows nothing (the lift, not a deck_lift)", spot.showing.is_empty() and game.modal.is_empty() and game.base_map.station("deck_lift").is_empty())
	game.open_station("stash")
	await wait_tip("base_stash")
	check("the 仓管台's card comes up the first time its screen opens, over it", spot.showing == "base_stash" and game.modal == "station")
	spot.dismiss()
	await step(2)
	check("dismissing it leaves the screen up", game.modal == "station" and spot.showing.is_empty())
	game.close_modal()
	game.open_station("stash")
	await step(30)
	check("the second time it does not", spot.showing.is_empty() and spot._queue.is_empty())
	game.close_modal()
	game.open_station("contracts")
	await wait_tip("dispatch_contract")
	check("the dispatch desk: first the contract, a box round the right column", spot.showing == "dispatch_contract" and spot.ring_box.encloses(TutorialSpotlight.DISPATCH_CONTRACT))
	spot.dismiss()
	await wait_tip("dispatch_floors")
	var floors: Array = FieldCatalog.RANDOM_EXTRACTION_ODDS.keys()
	check("then the floors, a box round the middle, the random-extraction range filled in", spot.showing == "dispatch_floors" and spot.ring_box.encloses(TutorialSpotlight.DISPATCH_FLOORS)
		and ("%d–%d" % [floors.min(), floors.max()]) in spot._text.text)
	spot.dismiss()
	game.close_modal()
	game.open_build_site("lab")
	await wait_tip("base_build_site")
	check("a construction site's card when its screen opens", spot.showing == "base_build_site")
	spot.dismiss()
	game.close_modal()
	check("the warehouse's old tips are gone", ["base_crate", "base_zone", "base_shelf_zone", "base_staging"].all(func(k): return not TutorialSpotlight.TIPS.has(k)))
	card.skip_all()
	# The first visit's order (用户 2026-10-24): the waking talk, then at once the
	# three departure stations, then the card's move and dodge — nothing before.
	TutorialCard.set_on(true)
	SystemScreens.settings.tutorial_step = 0
	SystemScreens.settings.tutorial_seen = []
	game.close_modal()
	game.base.story = Story.fresh()
	game.story_card.forced = true
	SystemScreens.settings.story_guide = true
	for i in range(120):
		if game.story_card.speaking == "wake": break
		await step()
	check("first the waking talk", game.story_card.speaking == "wake" and not card.visible and spot.showing.is_empty())
	var from := game.player.global_position
	game.player.teleport(from + Vector3(6, 0, 0))
	await step(5)
	check("moving under it counts for nothing", TutorialCard.step() == 0)
	game.story_card.go_back()
	await wait_tip("base_departure")
	check("right after it, the three stations", spot.showing == "base_departure" and not card.visible)
	await step(5)
	check("still nothing counted, the card hidden", TutorialCard.step() == 0 and not card.visible)
	spot.dismiss()
	await step(10)
	check("then the card: left-click to move", card.visible and at_step("move") and card._keys.text == "左键")
	game.player.teleport(game.player.global_position + Vector3(5, 0, 0))
	await tick_through()
	check("then the dodge on the right button", at_step("dodge") and card._keys.text == Keybinds.short_label(TutorialCard.dodge_action()))
	game.story_card.forced = false
	print("TUTORIAL FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
