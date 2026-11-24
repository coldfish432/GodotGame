extends SceneTree
## Screenshots of the 界面首次打开介绍 (TutorialSpotlight.SCREENS): the 2026-11-24 page cards: 界面 settings, 收藏品, 换汇.
## (用户: 其余分页都补上)
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
	root.get_texture().get_image().save_png("res://../evidence/page-tips-" + ("en-" if I18n.is_english() else "") + label + ".png")
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
	SystemScreens.settings["tutorial_seen"] = ["base_exchange", "base_departure", "base_stash", "ui_ex_market", "ui_ex_fx"]
	game.toggle_panel("pause")
	game.menu.settings_tab = 1
	game.menu.pause_page = 1
	BaseScreens.pause(game.menu)
	if await wait_tip() == "ui_set_ui": await capture("settings-ui")
	spot.dismiss()
	game.close_modal()
	await step(4)
	game.menu.stash_tab = 6
	game.open_station("stash")
	if await wait_tip() == "ui_stash_collect": await capture("stash-collect")
	spot.dismiss()
	game.close_modal()
	await step(4)
	ExchangeScreen.tab = 1
	ExchangeScreen.fx_mode = 0
	game.open_station("exchange")
	for i in range(4):
		var id := await wait_tip()
		if id == "ui_ex_changer":
			await capture("fx-changer")
			break
		spot.dismiss()
		await step(2)
	quit(0)
