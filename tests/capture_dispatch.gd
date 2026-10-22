extends SceneTree
## Screenshots: the dispatch board's floor picker, the workbench, a trade prompt.
## Writes evidence/dispatch.png, workbench.png, trade-prompt.png. Not part of run_all.
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
	SystemScreens.settings["trade_confirm"] = true
	var rig: Node = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(15)
	game = find_game(rig)
	game.base.camps["mine"] = 30
	game.menu.pick = 20
	game.open_station("contracts")
	await capture("dispatch")
	game.close_modal()
	for i in range(6): game.base.put_back(Item.create("测试刀 %d" % i, Item.Category.WEAPON, 1, 2, 1.0), "shelf")
	for i in range(5): game.base.put_back(Item.create("测试甲 %d" % i, Item.Category.CHEST, 2, 2, 1.0), "shelf")
	for i in range(8): game.base.put_back(Item.create("测试戒 %d" % i, Item.Category.RING, 1, 1, 1.0), "shelf")
	game.open_station("loadout")
	await capture("workbench")
	game.close_modal()
	game.inventory.add_stack(MaterialCatalog.create(Economy.GOLD_ID, 20))
	game.base.max_facilities()
	game.open_station("store")
	await step(4)
	TraderScreen.ask(game.menu.get_child(game.menu.get_child_count() - 1) if false else _stage(game.menu), "购买", BaseCatalog.create_potion("F", 1), {}, "2", "gold", func(): pass)
	await capture("trade-prompt")
	quit(0)

func _stage(menu: Node) -> Control:
	# The newest full-screen stage under the menu.
	var best: Control = null
	for c in menu.get_children():
		if c is Control and c.size == Vector2(1280, 720): best = c
	return best if best != null else menu
