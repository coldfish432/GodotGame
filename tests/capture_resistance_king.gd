extends SceneTree
## Screenshots for 抗性为王修订案 v0.4: 整备台 · 镶嵌, the pack grid with inlay
## diamonds, the C window's resistance rows, 出发准备 and the route map's
## 元素异变. Writes evidence/resist-*.png. Not part of run_all (no checks).
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
	root.get_texture().get_image().save_png("res://../evidence/resist-" + ("en-" if I18n.is_english() else "") + label + ".png")
func run() -> void:
	if OS.get_environment("DOWNFALL_LANG") == "en": I18n.set_language("en")
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(15)
	game = find_game(rig)
	game.save_enabled = false
	if is_instance_valid(game.system_screens): game.system_screens.hide()
	game.gold = 900000
	game.base.max_facilities()
	for mat in ["固源岩", "固源岩组", "提纯源岩", "异铁", "异铁组", "改量装置", "D32钢"]: game.base.shelf.append(MaterialCatalog.create(mat, 20))
	game.base.research.done.append("engineering_i1")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var pieces := []
	for slot in [Item.Category.CHEST, Item.Category.HEAD, Item.Category.LEGS, Item.Category.RING]:
		var it := LootTables.roll_equipment(slot, "", "city", 30, Item.BLUE, rng)
		game.inventory.try_add(it)
		pieces.append(it)
	game.set_inlay(pieces[0], "res_two", 1, ["burn", "nerve"])
	game.set_inlay(pieces[1], "hp", 0, [])
	game.set_inlay(pieces[2], "res_one", 1, ["cold"])
	game.menu.workbench_tab = 5
	game.menu.pick = pieces[3]
	LoadoutScreens._inlay_id = "res_two"
	LoadoutScreens._inlay_tier = 1
	LoadoutScreens._inlay_kinds = ["corr"]
	game.open_station("loadout")
	await step(20)
	game.menu.pick = pieces[3]
	LoadoutScreens.workbench(game.menu)
	await step(40)
	await capture("inlay")
	game.close_modal()
	await step(10)
	game.menu.workbench_tab = 0
	game.open_station("loadout")
	await step(60)
	await capture("pack-diamonds")
	game.close_modal()
	await step(10)
	game.player.stats.res_burn = 130.0
	game.player.stats.res_cold = 20.0
	game.menu.show_training(true)
	await step(60)
	await capture("sheet")
	game.close_modal()
	await step(10)
	game._pending_start_camp = 40
	game.open_modal("deploy")
	LoadoutScreens.deploy(game.menu, "city")
	await step(60)
	await capture("deploy")
	game.close_modal()
	await step(10)
	await game.start_contract("city")
	await step(30)
	var next_col: Array = game.route_map.cols[game.route_node.x + 1]
	for node in next_col: node["surge"] = "cold"
	game.open_modal("route")
	game.menu.show_routes(0)
	await step(60)
	await capture("route")
	quit()
