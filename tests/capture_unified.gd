extends SceneTree
## 交易所统一行情修订案 v0.3: the goods page with one row a pack, the pack's
## one K line and its faction books' quote table; a plan's headline in the
## news. Writes evidence/unified-*.png (DOWNFALL_LANG=en for English). Not in run_all.
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
	root.get_texture().get_image().save_png("res://../evidence/unified-" + ("en-" if I18n.is_english() else "") + label + ".png")
func run() -> void:
	if OS.get_environment("DOWNFALL_LANG") == "en": I18n.set_language("en")
	SystemScreens.settings["ui_motion"] = false
	SystemScreens.settings["tutorial_tips"] = false
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(15)
	game = find_game(rig)
	game.save_enabled = false
	if is_instance_valid(game.system_screens): game.system_screens.hide()
	game.base.set_facility("exchange", 3)
	game.gold = 500000
	for f in FactionCatalog.FACTIONS: game.exchange.add_relation(str(f), 1200)
	# A day of market behind it, so the line has candles and plans have run.
	game.market.advance_to(game.market.t + 86400)
	game.market.plans.begin(game.market, "f:ursus", "B10", "build")
	game.open_exchange()
	await step(30)
	game.close_swan_popup()
	ExchangeScreen.tab = 0
	ExchangeScreen.filter = 0
	ExchangeScreen.period = 2
	ExchangeScreen.selected = "build"
	game.menu.show_station("exchange")
	await capture("build")
	ExchangeScreen.selected = "rat:contraband"
	game.menu.show_station("exchange")
	await capture("contraband")
	ExchangeScreen.tab = 3
	game.menu.show_station("exchange")
	await capture("news")
	quit(0)
