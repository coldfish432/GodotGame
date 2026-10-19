extends SceneTree
## Screenshots of the exchange (势力与交易所策划案_v0_7.md): every page, 加工站,
## 可露希尔's money desk, the base watch window, the swan popup and a post.
## Writes evidence/exchange-*.png. Not part of run_all (no checks).
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
	root.get_texture().get_image().save_png("res://../evidence/exchange-" + ("en-" if I18n.is_english() else "") + label + ".png")
func page(tab: int, market_id: String = "", mode: int = 0) -> void:
	ExchangeScreen.tab = tab
	if not market_id.is_empty(): ExchangeScreen.selected = market_id
	ExchangeScreen.mode = mode
	game.menu.show_station("exchange")
func run() -> void:
	if OS.get_environment("DOWNFALL_LANG") == "en": I18n.set_language("en")
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(15)
	game = find_game(rig)
	game.save_enabled = false
	if is_instance_valid(game.system_screens): game.system_screens.hide()
	game.gold = 240000
	var ex := game.exchange
	ex.relations = {"karlan": 220, "lungmen": 160, "rhine": 120, "kazimierz": 100}
	ex.gold_account = 36.5
	for item in [MaterialCatalog.create("螺栓", 24), MaterialCatalog.create("医用耗材包", 6), MaterialCatalog.create("固源岩", 12), MaterialCatalog.create("源岩", 30)]:
		game.base.shelf.append(item)
	var armor := Item.create("近卫局制式护甲", Item.Category.ARMOR, 2, 2)
	armor.value = 130
	game.base.shelf.append(armor)
	ex.toggle_watch("fx")
	ex.toggle_watch("lungmen:armor")
	ex.toggle_watch("rhine:originium")
	game.market.fire("C2")
	game.market.fire("X2")
	ex.open_forward("lungmen", "螺栓", 20, 1, true, 1)
	ex.open_forward("karlan", "帆布", 6, 2, false, 2)
	ex.open_cfd("fx", 1, 2, 15000.0)
	ex.open_cfd("comp:kazimierz", -1, 1, 4.0)
	ex.add_alert("fx", ">=", ex.cfd_price("fx") * 1.03)
	game.open_exchange()
	page(0, "fx", 3)
	await capture("market-fx-cfd")
	page(0, "lungmen:armor", 0)
	await capture("market-spot")
	page(0, "lungmen:build", 2)
	await capture("market-forward")
	page(0, "lungmen:medical", 1)
	await capture("market-orders")
	page(1)
	await capture("positions")
	page(2)
	await capture("news")
	page(3)
	await capture("funds")
	game.menu.show_station("workshop")
	await capture("workshop")
	game.close_modal()
	game.open_station("store")
	game.menu.camp_tab = 2
	game.menu.show_station("store")
	await capture("closure-fx")
	game.menu.camp_tab = 3
	game.menu.show_station("store")
	await capture("closure-loan")
	game.close_modal()
	game.watch_widget.set_meta("on", true)
	game.swan_popup = "乌萨斯主矿脉枯竭，远北矿区停产"
	await capture("base-watch-swan")
	game.close_swan_popup()
	await game.start_contract("snow")
	await step(10)
	game.encounter = "post"
	game.post_faction = "sami"
	game.inventory.try_add(MaterialCatalog.create("固体燃料", 12))
	game.inventory.try_add(MaterialCatalog.create("医用耗材包", 4))
	game.open_modal("post")
	game.menu.show_post()
	await capture("post-sami")
	quit()
