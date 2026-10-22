extends SceneTree
## Screenshots of the typed amounts and ◀ ▶ pickers on the exchange:
## evidence/exchange-money.png, exchange-forward.png. Not part of run_all.
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
	root.get_texture().get_image().save_png("res://../evidence/" + label + ".png")
func run() -> void:
	SystemScreens.settings["ui_motion"] = false
	var rig: Node = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(15)
	game = find_game(rig)
	game.exchange.relations["karlan"] = Exchange.RANK_AT[3]
	game.exchange.relations["lungmen"] = Exchange.RANK_AT[3]
	ExchangeScreen.tab = 3
	game.open_station("exchange")
	await capture("exchange-money")
	ExchangeScreen.tab = 0
	ExchangeScreen.mode = 2
	ExchangeScreen.selected = game.market.books.keys().filter(func(k): return str(k).begins_with("lungmen:"))[0]
	ExchangeScreen.build(game.menu)
	await capture("exchange-forward")
	quit(0)
