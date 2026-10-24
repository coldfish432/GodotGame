extends SceneTree
## Screenshots of a new Doctor's first base visit (用户 2026-10-24): the waking
## talk, then at once the three departure stations, then the card's move and
## dodge. Writes evidence/first-visit-*.png. Not in run_all.
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
	root.get_texture().get_image().save_png("res://../evidence/first-visit-" + label + ".png")
func run() -> void:
	SystemScreens.settings["ui_motion"] = false
	SystemScreens.settings["tutorial_step"] = 0
	SystemScreens.settings["tutorial_tips"] = true
	SystemScreens.settings["tutorial_seen"] = []
	SystemScreens.settings["story_guide"] = true
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(15)
	game = find_game(rig)
	game.base.story = Story.fresh()
	game.story_card.forced = true
	game.tutorial_card.forced = true
	game.tutorial_spotlight.forced = true
	await step(30)
	await capture("1-talk")
	game.story_card.go_back()
	for i in range(120):
		if game.tutorial_spotlight.showing == "base_departure": break
		await step(1)
	await capture("2-stations")
	game.tutorial_spotlight.dismiss()
	await step(20)
	await capture("3-move")
	game.player.teleport(game.player.global_position + Vector3(5, 0, 0))
	await step(80)
	await capture("4-dodge")
	# The workbench's cards (用户 2026-10-24): the depot, the 制式 tab, the 制式 page.
	var spot := game.tutorial_spotlight
	game.open_station("loadout")
	for id in ["loadout_depot", "loadout_issue_tab"]:
		for i in range(120):
			if spot.showing == id: break
			await step(1)
		await capture("5-" + id)
		spot.dismiss()
	game.menu.workbench_tab = 2
	LoadoutScreens.workbench(game.menu)
	for i in range(120):
		if spot.showing == "loadout_issue": break
		await step(1)
	await capture("6-loadout_issue")
	quit(0)
