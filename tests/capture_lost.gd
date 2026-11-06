extends SceneTree
## Screenshots of 失散干员 (失散干员与主线流程策划案_v0_2.md): a new save's
## shut departments (the hub page, the 加工站, the 沙盘), the 人事部's special
## operators, Sharp on her floor with her squad and the minimap mark, the
## first-sight card, her line when reached, and her lines back on board.
## Writes evidence/lost-*.png. Not in run_all.
var rig: Node
var game: GameManager
func _initialize() -> void: call_deferred("run")
func step(count: int = 10) -> void:
	for i in range(count): await process_frame
func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null
func capture(label: String) -> void:
	await step(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/lost-" + ("en-" if I18n.is_english() else "") + label + ".png")
	print("captured ", label)
func kill(enemy) -> void:
	if is_instance_valid(enemy) and not enemy._dead: enemy.take_hit(99999999.0, "true")
func run() -> void:
	if OS.get_environment("DOWNFALL_LANG") == "en": I18n.set_language("en")
	SystemScreens.settings["ui_motion"] = false
	SystemScreens.settings["tutorial_step"] = TutorialCard.STEPS.size()
	SystemScreens.settings["tutorial_tips"] = false
	SystemScreens.settings["story_guide"] = true
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(15)
	game = find_game(rig)
	game.save_enabled = false
	game.base.start_locked()
	game.base.story = Story.finished_state()
	game.gold = 500000
	# The hub built and the 仓储部 linked: its page shows Misery missing.
	game.base.set_facility("hub", 1)
	game.base.connected.append("warehouse")
	game.menu.build_pick = "warehouse"
	game.open_station("construction")
	await capture("hub-warehouse")
	game.close_modal()
	game.open_station("workshop")
	await capture("workshop")
	game.close_modal()
	game.open_station("sand_table")
	await capture("sand-table")
	game.close_modal()
	BaseScreens.personnel_tab = 1
	game.open_station("personnel")
	await capture("roster-new")
	game.close_modal()
	# The field: Sharp on floor 2 of 切尔诺伯格.
	game.fixed_map_seed = 2718
	game.route_plain = true
	await game.start_contract("mine")
	await step(20)
	game.lost_floor = {"sharp": game.floor_number + 1}
	await game.advance(0)
	await step(30)
	print("lost here: ", game.lost_id, " node ", is_instance_valid(game.lost_node))
	if not is_instance_valid(game.lost_node):
		quit(1)
		return
	var at: Vector3 = game.lost_node.global_position
	game.player.teleport(at + Vector3(0, 0, 10))
	game.camera.global_position = game.camera_target() + GameManager.CAMERA_OFFSET
	await step(30)
	await capture("field-guarded")
	# Her first-sight card.
	SystemScreens.settings["tutorial_tips"] = true
	game.tutorial_spotlight.forced = true
	game.tutorial_spotlight.show_tip("lost_operator", at + Vector3.UP * 0.6)
	await capture("field-tip")
	game.tutorial_spotlight.dismiss()
	SystemScreens.settings["tutorial_tips"] = false
	await step(5)
	print("after tip: floor ", game.floor_number, " in_base ", game.in_base, " modal ", game.modal, " post ", is_instance_valid(game._lost_post), " node ", is_instance_valid(game.lost_node), " hp ", game.player.hp, " transitioning ", game.transitioning, " log ", game.prts_log.slice(-4))
	if not is_instance_valid(game._lost_post):
		quit(1)
		return
	for enemy in game._lost_post.guards: kill(enemy)
	for enemy in game.floor_enemies(): kill(enemy)
	for trap in game.traps: trap.spent = true
	await step(20)
	game.player.teleport(at + Vector3(0.6, 0, 0))
	await step(10)
	game.story_card.forced = true
	game._interact()
	await capture("field-talk")
	game.story_card.advance()
	await capture("field-talk-prts")
	game.story_card.advance()
	await step(10)
	game.settle(true)
	for i in range(400):
		if game.in_base and not game.transitioning: break
		await process_frame
	game.close_modal()
	await step(40)
	await capture("base-back-sharp")
	game.story_card.go_back()
	await step(10)
	BaseScreens.personnel_tab = 1
	game.open_station("personnel")
	await capture("roster-sharp-back")
	game.close_modal()
	quit(0)
