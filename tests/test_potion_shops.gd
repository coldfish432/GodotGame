extends SceneTree

## 药剂与商人界面策划案 v1.0: 可露希尔特供 on her shelf with hourly restock, a
## camp's draw of three, 坎诺特's wider flask pool, each post's own flask, the
## new flasks' effects, and drag trading on the trader screen.

var game: GameManager
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool, detail: Variant = null) -> void:
	checks += 1
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label + ("" if detail == null or passed else "  %s" % str(detail)))

func run() -> void:
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 4343
	root.add_child(game)
	await step(8)
	await _base_shelf()
	await _field_shops()
	await _effects()
	print("POTION SHOPS RESULT: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await step(2)
	quit(1 if failures else 0)

func _base_shelf() -> void:
	game.base.max_facilities()
	check("at the base she shows her 特供 line", game.closure_goods() == BaseCatalog.CLOSURE_LINE)
	var gel_bars := maxi(1, ceili(Economy.tiered(int(BaseCatalog.POTIONS.B.price), game.closure_potion_tier()) / Economy.bar_lmd()))
	check("A costs one bar, B as many bars as its 龙门币 needs (%d)" % gel_bars, game.closure_potion_price("A") == 1 and game.closure_potion_price("B") == gel_bars, [game.closure_potion_price("A"), game.closure_potion_price("B")])
	game.base.closure_restock_at = 0
	var cap := int(BaseCatalog.POTIONS["F"].cap)
	check("a fresh window fills her line to its caps", game.closure_stock_left("F") == cap and game.base.closure_restock_in() > 3500)
	check("强心针 is one a window", game.closure_stock_left("L") == 1)
	# 赤金 stacks ten to a slot: enough bars for every bottle of the window and more.
	for i in range(ceili(game.closure_potion_price("F") * (cap + 2) / 10.0)):
		game.inventory.add_stack(MaterialCatalog.create(Economy.GOLD_ID, 10))
	var bought := 0
	for i in range(cap + 2):
		if game.closure_buy_potion("F"): bought += 1
	check("she sells only what is left this window", bought >= 1 and game.closure_stock_left("F") == 0 and game.potion_count("F") == cap, [bought, game.closure_stock_left("F")])
	check("the stock and restock time survive a save", _reloaded().closure_stock.get("F", -1) == 0)
	BaseState.clock_offset += BaseCatalog.RESTOCK_SECONDS + 5
	check("after the hour she has restocked", game.closure_stock_left("F") == cap)
	# The shelf on screen.
	game.open_station("store")
	await step(2)
	var tiles := _tiles(game.menu)
	check("her shelf shows the whole line", tiles.size() == BaseCatalog.CLOSURE_LINE.size(), tiles.size())
	check("with a live restock clock", _find(game.menu, func(n): return n is TraderScreen.Countdown) != null)
	game.close_modal()
	# The pharmacy keeps A and B, in the 白舱 skin.
	game.open_station("pharmacy")
	await step(2)
	check("the pharmacy shelf holds A and B", _tiles(game.menu).size() == 2)
	check("on white plates", _find(game.menu, func(n): return n is TraderScreen.Shelf and n.white) != null)
	game.close_modal()

func _field_shops() -> void:
	await game.start_contract("snow")
	await step(4)
	game.floor_number = 10
	game._enter_camp()
	await step(2)
	var specials: Array = game.camp_closure_stock.keys()
	check("a camp draws three 特供", specials.size() == BaseCatalog.CAMP_SPECIALS, specials)
	check("next to A and B", game.closure_goods().size() == 2 + BaseCatalog.CAMP_SPECIALS)
	game.give_gold_bars(30)
	var k: String = specials[0]
	var before := game.closure_stock_left(k)
	game.closure_buy_potion(k)
	check("buying in a camp draws its stock down", game.closure_stock_left(k) < before)
	# Drag trading: a shelf tile dropped on the pack buys it.
	game.menu.camp_tab = 0
	EventScreens.camp(game.menu, false)
	await step(1)
	var grid: AK.BagGrid = _find(game.menu, func(n): return n is AK.BagGrid)
	var a_before := game.potion_count("A")
	check("the pack takes a dragged shelf tile", grid != null and grid._can_drop_data(Vector2.ZERO, {"trade_buy": 0}))
	SystemScreens.settings["trade_confirm"] = true
	grid._drop_data(Vector2.ZERO, {"trade_buy": 0})
	await step(1)
	var prompt: Node = _find(game.menu, func(n): return n.name == "TradePrompt")
	check("a dropped buy asks first", prompt != null and game.potion_count("A") == a_before)
	var skip: CheckBox = _find(prompt, func(n): return n is CheckBox)
	skip.button_pressed = true
	(_find(prompt, func(n): return n is Button and n.text == "确认") as Button).pressed.emit()
	await step(1)
	check("and 确认 buys it", game.potion_count("A") > a_before)
	check("不再提示 turns the prompt off", SystemScreens.settings.get("trade_confirm", true) == false)
	game.leave_camp()
	await step(4)
	# 坎诺特 carries the wider pool.
	var seen := {}
	for i in range(40):
		game._roll_trader_stock()
		for e in game.trader_stock:
			if e.kind == "item" and e.item.is_potion(): seen[e.item.potion_type] = true
	check("坎诺特 brings 特供 and regional flasks too", seen.keys().any(func(t): return not t in ["A", "B", "C"]), seen.keys())
	check("but never the 强心针", not seen.has("L"))
	# Selling by drag at 坎诺特.
	game.encounter = "trader"
	game._roll_trader_stock()
	game.menu.trader_tab = "buy"
	game._open_encounter()
	await step(1)
	var gear := Item.create("刀", Item.Category.WEAPON, 1, 2, 1.0)
	gear.value = 40
	game.inventory.try_add(gear)
	game.menu.trader_tab = "buy"
	game._open_encounter()
	await step(1)
	if true:
		var shelf: TraderScreen.Shelf = _find(game.menu, func(n): return n is TraderScreen.Shelf)
		var bars := game.gold_bars()
		check("his shelf takes a dragged pack item", shelf._can_drop_data(Vector2.ZERO, {"trade_sell": gear}))
		shelf._drop_data(Vector2.ZERO, {"trade_sell": gear})
		check("and dropping it sells", game.gold_bars() > bars and not game.inventory.items.has(gear))
	game.close_modal()
	# A post's own flask.
	game.encounter = "post"
	game.post_faction = "ursus"
	game.give_gold_bars(10)
	check("a post sells its own flask", game.post_potion() == "ursus" and game.post_buy_potion() and game.potion_count("ursus") == 1)
	game.post_faction = "sami"
	check("萨米 wants herbs for it", game.post_potion_refusal().begins_with("需要"))
	game.inventory.try_add(MaterialCatalog.create("林地草药", 2))
	check("and trades them for it", game.post_buy_potion() and game.potion_count("sami") == 1 and game.material_count("林地草药") == 0)
	game.menu.trader_tab = "buy"
	TraderScreen.post(game.menu)
	await step(1)
	check("the post's shelf lists the flask first", _tiles(game.menu).size() > 0 and _tiles(game.menu)[0].item.potion_type == "sami")
	game.close_modal()

func _effects() -> void:
	var p := game.player
	p.hp = p.max_hp
	game.inventory.try_add(BaseCatalog.create_potion("H", 1))
	game.drink(_flask("H"))
	check("护盾凝胶 gives a shield", p.shield > 0.0)
	game.inventory.try_add(BaseCatalog.create_potion("L", 1))
	check("强心针 is not drunk", not game.drink(_flask("L")))
	game.potion_fx.emergency_used = false
	p.hp = 5
	p.shield = 0.0
	# The camp may have drawn (and sold) a 强心针 too, so it can stack to two:
	# the save uses up exactly one.
	var shots := game.potion_count("L")
	# True damage: an evasion roll must not make this flaky.
	p.take_damage(p.max_hp * 3.0, "true")
	check("强心针 saves a killing blow once", shots >= 1 and is_equal_approx(p.hp, 1.0 + p.max_hp * PotionEffects.EMERGENCY_HEAL)
		and game.potion_count("L") == shots - 1 and game.potion_fx.emergency_used, [p.hp, shots, game.potion_count("L"), game.in_base])

func _reloaded() -> BaseState:
	var copy := BaseState.new()
	copy.load_data(game.base.to_data(), {})
	return copy

func _flask(type: String) -> Item:
	for item in game.inventory.items:
		if item.potion_type == type: return item
	return null

func _tiles(root_node: Node) -> Array:
	var out: Array = []
	_walk(root_node, func(n): if n is TraderScreen.ShelfTile: out.append(n))
	return out

func _find(root_node: Node, pred: Callable) -> Node:
	if pred.call(root_node): return root_node
	for c in root_node.get_children():
		var f := _find(c, pred)
		if f != null: return f
	return null

func _walk(n: Node, fn: Callable) -> void:
	fn.call(n)
	for c in n.get_children(): _walk(c, fn)
