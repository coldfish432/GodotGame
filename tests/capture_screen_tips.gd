extends SceneTree
## Screenshots of the 界面首次打开介绍 (TutorialSpotlight.SCREENS): the 资产
## page's economy chain card by card, a sub-page, 企业, 策略 and a tab card.
## Writes evidence/screen-tips-*.png (DOWNFALL_LANG=en for English). Not in run_all.
var rig: Node
var game: GameManager
var spot: TutorialSpotlight
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
	root.get_texture().get_image().save_png("res://../evidence/screen-tips-" + ("en-" if I18n.is_english() else "") + label + ".png")
func wait_tip() -> String:
	for i in range(400):
		if not spot.showing.is_empty(): return spot.showing
		await process_frame
	return ""
func run() -> void:
	if OS.get_environment("DOWNFALL_LANG") == "en": I18n.set_language("en")
	SystemScreens.settings["ui_motion"] = false
	SystemScreens.settings["tutorial_tips"] = true
	SystemScreens.settings["tutorial_seen"] = ["base_exchange", "base_departure"]
	SystemScreens.settings["tutorial_step"] = TutorialCard.STEPS.size()
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(15)
	game = find_game(rig)
	spot = game.tutorial_spotlight
	spot.forced = true
	game.base.max_facilities()
	for f in FactionCatalog.FACTIONS: game.exchange.add_relation(str(f), Exchange.RELATION_MAX)
	ExchangeScreen.tab = 5
	AssetsScreen.asset_tab = 0
	game.open_station("exchange")
	for i in range(8):
		var id := await wait_tip()
		if id.is_empty(): break
		await capture("%d-%s" % [i + 1, id])
		spot.dismiss()
		await step(4)
	AssetsScreen.asset_tab = 3
	ExchangeScreen.build(game.menu)
	var sub := await wait_tip()
	await capture("sub-" + sub)
	spot.dismiss()
	for tab in [6, 7]:
		ExchangeScreen.tab = tab
		ExchangeScreen.build(game.menu)
		for i in range(3):
			var id := await wait_tip()
			if id.is_empty(): break
			await capture("%d-%s" % [tab, id])
			spot.dismiss()
			await step(4)
	ExchangeScreen.tab = 1
	ExchangeScreen.build(game.menu)
	var fx := await wait_tip()
	await capture("tab-" + fx)
	spot.dismiss()
	quit(0)
