extends SceneTree
## Screenshots of 罗德岛运营与资产管理策划案 v0.12's pages: the terminal's 资产 /
## 企业 / 策略, the 仓管台's 罗德岛库存 tab, the canteen's rations and the base
## HUD's money. Writes evidence/rhodes-ops-*.png. Not part of run_all.
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
	root.get_texture().get_image().save_png("res://../evidence/rhodes-ops-" + ("en-" if I18n.is_english() else "") + label + ".png")
func run() -> void:
	if OS.get_environment("DOWNFALL_LANG") == "en": I18n.set_language("en")
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(15)
	game = find_game(rig)
	game.save_enabled = false
	if is_instance_valid(game.system_screens): game.system_screens.hide()
	game.gold = 1800000
	var ex := game.exchange
	game.base.receive(MaterialCatalog.create(Economy.GOLD_ID, 64))
	for f in ["exchange", "workshop", "warehouse", "canteen", "hub", "lab", "farm", "outfit"]: game.base.set_facility(f, 2 if f != "exchange" else 4)
	for item in [MaterialCatalog.create("异铁碎片", 20), MaterialCatalog.create("螺栓", 20), MaterialCatalog.create("钉子", 20), MaterialCatalog.create("舰载麦", 20), MaterialCatalog.create("块茎薯", 20)]:
		game.base.shelf.append(item)
	ex.fin.transfer_in("异铁碎片", 12)
	ex.fin.transfer_in("舰载麦", 10)
	ex.fin.deposit("lmd", 200000)
	ex.fin.open_term("lmd", 100000, 7)
	ex.fin.borrow(30000)
	ex.securities.buy_stock("swire", 150000)
	ex.securities.buy_stock("raythean", 80000)
	ex.securities.buy_bond("col", 50000, 7)
	ex.securities.buy_fund("karlan_fund", 12.0)
	for i in range(3): ex._new_day()
	ex.strategies.create("S8", 100000.0, [], {"hours": 1, "amount": 10000})
	ex.strategies.create("S10", 150000.0)
	ex.strategies._round = -1
	ex.strategies.step()
	for i in range(4): ex.strategies.new_day()
	AssetsScreen.strat_pick = int(ex.strategies.list[0].id)
	await step(30)
	await capture("hud")
	game.open_exchange()
	await step(60)
	for t in [[5, "assets"], [6, "firms"], [7, "strategies"]]:
		ExchangeScreen.tab = int(t[0])
		ExchangeScreen.build(game.menu)
		await capture(str(t[1]))
	for sub in [[1, "deposits"], [2, "credit"], [3, "securities"]]:
		ExchangeScreen.tab = 5
		AssetsScreen.asset_tab = int(sub[0])
		ExchangeScreen.build(game.menu)
		await capture("assets-" + str(sub[1]))
	AssetsScreen.asset_tab = 0
	ExchangeScreen.tab = 7
	# The hover card of the form's template (drawn where its popup would open).
	ExchangeScreen.tab = 7
	ExchangeScreen.build(game.menu)
	var tip := AssetsScreen.strategy_card(game, "S3")
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	layer.add_child(tip)
	tip.position = Vector2(560, 150)
	await capture("strategy-tip")
	layer.queue_free()
	# The form's universe dropdowns: 突破追势 (up to three), its first list open.
	AssetsScreen.tpl_pick = StrategyCatalog.ORDER.find("S5")
	AssetsScreen.strat_pool = []
	ExchangeScreen.build(game.menu)
	await step(4)
	var obs := root.find_children("*", "OptionButton", true, false)
	if not obs.is_empty(): (obs[0] as OptionButton).show_popup()
	await capture("strategy-pool")
	if not obs.is_empty(): (obs[0] as OptionButton).get_popup().hide()
	AssetsScreen.tpl_pick = 0
	AssetsScreen.strat_pool = []
	AssetsScreen.backtest = ex.strategies.backtest("S5", 100000.0, ["lungmen:armor", "ursus:build"])
	ExchangeScreen.build(game.menu)
	await capture("backtest")
	game.close_modal()
	game.open_modal("station")
	game.menu.stash_tab = BaseScreens.RHODES_TAB
	BaseScreens.stash(game.menu)
	await capture("stock")
	ProvisionScreens.canteen_tab = 1
	ProvisionScreens.canteen(game.menu)
	await capture("canteen")
	SandTableScreen.tab = 1
	SandTableScreen.build(game.menu)
	await capture("relations")
	quit(0)
