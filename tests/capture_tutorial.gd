extends SceneTree
## Screenshots of the 新手引导 card (TutorialCard): a base step, a field step,
## the ticked box, and in English. Writes evidence/tutorial-*.png. Not in run_all.
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
	root.get_texture().get_image().save_png("res://../evidence/tutorial-" + ("en-" if I18n.is_english() else "") + label + ".png")
func run() -> void:
	if OS.get_environment("DOWNFALL_LANG") == "en": I18n.set_language("en")
	SystemScreens.settings["ui_motion"] = false
	SystemScreens.settings["tutorial_step"] = 0
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(15)
	game = find_game(rig)
	var card := game.tutorial_card
	card.forced = true
	await capture("base-move")
	SystemScreens.settings["tutorial_step"] = 1
	await capture("base-contract")
	await game.start_contract("mine")
	# The contract step's box ticks for TICK_SECONDS first.
	await step(90)
	game.fog.reveal(game.player.global_position)
	await capture("field-kill")
	game.run_kills["normal"] = 1
	await step(3)
	await capture("field-ticked")
	# First sight: an elite, the field stopped, the ring and PRTS's card.
	SystemScreens.settings["tutorial_seen"] = TutorialSpotlight.TIPS.keys().filter(func(k): return k != "elite")
	var spot := game.tutorial_spotlight
	spot.forced = true
	game._spawn_enemy(game.player.global_position + Vector3(4, 0, 2), true, false)
	await step(30)
	await capture("spot-elite")
	spot.dismiss()
	# And a trap, up close.
	SystemScreens.settings["tutorial_seen"] = TutorialSpotlight.TIPS.keys().filter(func(k): return k != "trap")
	for trap in game.traps:
		if is_instance_valid(trap) and not trap.spent:
			game.player.teleport(trap.global_position + Vector3(-3, 0, -2))
			game.camera.global_position = game.camera_target() + game.camera_offset()
			break
	await step(30)
	await capture("spot-trap")
	spot.dismiss()
	# A box round a bar: the 威胁值 and the hotbar's first-aid slot.
	SystemScreens.settings["tutorial_seen"] = []
	spot.show_tip("threat", TutorialSpotlight.TOP_BAR)
	await capture("spot-threat")
	spot.dismiss()
	spot.show_tip("low_hp", spot.potion_slot_rect())
	await capture("spot-low-hp")
	spot.dismiss()
	# The basic card's reading step (快捷栏).
	SystemScreens.settings["tutorial_step"] = TutorialCard.index_of("hotbar")
	await step(20)
	await capture("card-hotbar")
	# A screen card: the first retreat, over the settlement.
	SystemScreens.settings["tutorial_step"] = TutorialCard.STEPS.size()
	game.settle(false)
	await step(90)
	await capture("spot-death")
	spot.dismiss()
	# The base: the 整备台, the first time she walks up to it.
	for i in range(240):
		if game.in_base and not game.transitioning: break
		await step(1)
	game.close_modal()
	SystemScreens.settings["tutorial_seen"] = []
	game.player.teleport(game.base_map.station("workbench").position)
	game.camera.global_position = game.camera_target() + game.camera_offset()
	await step(30)
	await capture("spot-base-loadout")
	quit(0)
