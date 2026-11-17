extends SceneTree
## 界面首次打开介绍与经济系统教程 (用户 2026-11-15: 做每个ui界面的首次开启介绍，
## 增加经济系统玩法教程). TutorialSpotlight.SCREENS: every entry names a tip
## that exists; the 资产 page's economy chain comes card by card, each boxing
## its part; a sub-page's card comes when it is picked; leaving a screen drops
## its cards, and opening it again brings back only what was not seen; each
## card once; off with the setting.
var game: GameManager
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
func wait_tip(id: String) -> bool:
	for i in range(300):
		if spot.showing == id: return true
		await step()
	return false
## Dismisses whatever is up, then waits for the next card (its id, "" none).
func next_tip() -> String:
	spot.dismiss()
	for i in range(40):
		await step()
		if not spot.showing.is_empty(): return spot.showing
	return ""

func run() -> void:
	SystemScreens.settings.tutorial_tips = true
	SystemScreens.settings.tutorial_seen = []
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	await step(3)
	spot = game.tutorial_spotlight
	spot.forced = true
	SystemScreens.settings.tutorial_step = TutorialCard.STEPS.size()
	game.base.max_facilities()
	for f in FactionCatalog.FACTIONS: game.exchange.add_relation(str(f), Exchange.RELATION_MAX)

	var missing: Array = []
	for key in TutorialSpotlight.SCREENS:
		for entry in TutorialSpotlight.SCREENS[key]:
			if not TutorialSpotlight.TIPS.has(str(entry[0])): missing.append(entry[0])
	check("every screen tip exists", missing.is_empty())
	check("the economy chain is eight cards", TutorialSpotlight.SCREENS["交易所/资产"].size() == 8)

	# The exchange: its station card first, then the 行情 page's.
	ExchangeScreen.tab = 0
	game.open_station("exchange")
	check("the station's own card comes first", await wait_tip("base_exchange"))
	check("then the page's, round its tab button", await next_tip() == "ui_ex_market" and spot.ring_box.size.x > 0.0 and spot.ring_box.size.x < 200.0)
	spot.dismiss()
	await step(10)
	check("nothing more on the 行情 page", spot.showing.is_empty())

	# 资产: the economy chain, in order.
	ExchangeScreen.tab = 5
	AssetsScreen.asset_tab = 0
	ExchangeScreen.build(game.menu)
	check("资产 opens the economy chain with the money card in the middle", await wait_tip("ui_econ_money") and spot.ring_box.size.x == 0.0)
	var order: Array = ["ui_econ_money"]
	for i in range(7): order.append(await next_tip())
	var want: Array = TutorialSpotlight.SCREENS["交易所/资产"].map(func(e): return e[0])
	check("the cards come in order: %s" % [order], order == want)
	check("the last one boxes the 存款 tab", spot.showing == "ui_econ_grow" and spot.ring_box.size.x > 0.0)
	spot.dismiss()
	await step(10)
	check("then the page is left alone", spot.showing.is_empty() and game.modal == "station")

	# Sub-pages: picked, their card.
	AssetsScreen.asset_tab = 2
	ExchangeScreen.build(game.menu)
	check("信贷 sub-page: its card", await wait_tip("ui_econ_credit"))
	spot.dismiss()

	# Leaving drops a screen's cards; coming back brings them back.
	ExchangeScreen.tab = 6
	ExchangeScreen.build(game.menu)
	check("企业: the watchlist first", await wait_tip("ui_firm_list"))
	game.close_modal()
	for i in range(300):
		await step()
		if spot._queue.is_empty(): break
	check("closed: the rest are dropped, not shown over the base", spot.showing.is_empty() and spot._queue.is_empty())
	game.open_station("exchange")
	check("opened again: the next one not yet seen", await wait_tip("ui_firm_detail"))
	check("then the order card", await next_tip() == "ui_firm_order")
	spot.dismiss()

	# Seen once.
	ExchangeScreen.tab = 5
	AssetsScreen.asset_tab = 0
	ExchangeScreen.build(game.menu)
	await step(30)
	check("资产 a second time: nothing", spot.showing.is_empty())

	# Another station's page; and the setting.
	game.close_modal()
	game.menu.workbench_tab = 4
	game.open_station("loadout")
	var shown: Array = []
	for i in range(6):
		if spot.showing.is_empty():
			await step(20)
		if spot.showing.is_empty(): break
		shown.append(spot.showing)
		spot.dismiss()
		await step(2)
	check("the 整备台's 增益 page has its card: %s" % [shown], "ui_bench_support" in shown)
	game.close_modal()
	SystemScreens.settings.tutorial_tips = false
	ExchangeScreen.tab = 7
	game.open_station("exchange")
	await step(30)
	check("off: no card", spot.showing.is_empty())

	print("SCREEN TIPS FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
