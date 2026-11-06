extends SceneTree
## Screenshots of 整备台 · 投保 and 整备台 · 增益 (用户 2026-11-02).
## A new base's 增益 too (only what is open). Writes evidence/workbench-*.png. Not part of run_all (no checks).
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
	root.get_texture().get_image().save_png("res://../evidence/workbench-" + ("en-" if I18n.is_english() else "") + label + ".png")
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
	# A new base: canteen and lab not built, the store at its start.
	for id in ["canteen", "lab", "store"]: game.base.set_facility(id, 0)
	game.menu.workbench_tab = 4
	game.open_station("loadout")
	await step(60)
	await capture("support-locked")
	game.close_modal()
	await step(10)
	game.base.max_facilities()
	for i in range(4): game.base.shelf.append(MaterialCatalog.create(Economy.GOLD_ID, 10))
	game.base.shelf.append(MaterialCatalog.create("食堂便当", 2))
	game.base.shelf.append(MaterialCatalog.create("闪耀定食", 1))
	game.base.shelf.append(MaterialCatalog.create("冰原熏肉", 1))
	game.provisions.eat("食堂便当")
	game.research.sign("scan")
	game.buy_kit("dust_mask")
	var gear := Item.create("刀", Item.Category.WEAPON, 1, 2, 1.0)
	gear.value = 400
	game.inventory.try_add(gear)
	for tab in [3, 4]:
		game.menu.workbench_tab = tab
		game.open_station("loadout")
		await step(60)
		await capture("insurance" if tab == 3 else "support")
		game.close_modal()
		await step(10)
	quit()
