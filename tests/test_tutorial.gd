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
	check("then the next step: the camera", at_step("camera"))
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
	check("a kill ticks it off", at_step("dodge") and card._keys.text == Keybinds.short_label(TutorialCard.dodge_action()) and card._keys.text != "")
	game.player.dash_remaining = 0.2
	await tick_through()
	check("a dodge ticks it off", at_step("skill") and card._keys.text == Keybinds.short_label(TutorialCard.skill_action()))
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
	# The base: a station's card the first time she walks up to it, after the first contract.
	TutorialCard.set_on(true)
	SystemScreens.settings.tutorial_step = TutorialCard.index_of("contract")
	game.settle(true)
	for i in range(240):
		if game.in_base and not game.transitioning: break
		await step()
	game.close_modal()
	SystemScreens.settings.tutorial_seen = []
	var desk: Dictionary = game.base_map.station("workbench")
	game.player.teleport(desk.position)
	await step(20)
	check("before the first contract, the base does not stop her", spot.showing.is_empty())
	SystemScreens.settings.tutorial_step = TutorialCard.index_of("contract") + 1
	await step(20)
	check("after it, the 整备台's card comes up at the desk", spot.showing == "base_loadout" and game.modal == "tutorial")
	spot.dismiss()
	await step(2)
	check("and the base walks on", game.modal.is_empty())
	card.skip_all()
	print("TUTORIAL FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
