extends SceneTree
## Screenshots of 燃料储备修订案 v0.6: cans with their fill on the warehouse grid,
## the 罗德岛库存 page's 燃料储备 and pour buttons, the exchange's fuel book by the
## barrel, a voyage's 燃料 有/需, and a fire's can row. Writes
## evidence/fuel-*.png (DOWNFALL_LANG=en for English). Not in run_all.
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
	root.get_texture().get_image().save_png("res://../evidence/fuel-" + ("en-" if I18n.is_english() else "") + label + ".png")
func can(units: int) -> Item:
	var t := MaterialCatalog.create(Fuel.TANK, 1)
	Fuel.set_fill(t, units)
	return t
func run() -> void:
	if OS.get_environment("DOWNFALL_LANG") == "en": I18n.set_language("en")
	SystemScreens.settings["ui_motion"] = false
	SystemScreens.settings["tutorial_tips"] = false
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(15)
	game = find_game(rig)
	game.base.max_facilities()
	for f in FactionCatalog.FACTIONS: game.exchange.add_relation(str(f), Exchange.RELATION_MAX)
	game.gold = 3000000
	for u in [60, 60, 42, 17, 0]: game.base.shelf.append(can(u))
	game.base.shelf.append(MaterialCatalog.create(Fuel.SOLID, 9))
	game.exchange.fin.add_fuel(1250)
	game.base.shelf_normalize()
	# The warehouse grid.
	game.menu.stash_tab = 0
	game.open_station("stash")
	await capture("stash")
	game.menu.stash_tab = BaseScreens.RHODES_TAB
	game.menu.show_station("stash")
	await capture("reserve")
	# The exchange's fuel book.
	ExchangeScreen.tab = 0
	ExchangeScreen.selected = "ursus:fuel"
	game.menu.show_station("exchange")
	await capture("exchange")
	# A voyage.
	for anchor in VoyageCatalog.ANCHORS:
		if anchor != game.voyage.place():
			SandTableScreen.destination = str(anchor)
			break
	SandTableScreen.tab = 0
	game.menu.show_station("sand_table")
	await capture("voyage")
	# A fire's row: the pack's cans, − / + and the seconds.
	game.close_modal()
	await step(4)
	game.inventory.try_add(can(36))
	game.inventory.try_add(MaterialCatalog.create(Fuel.SOLID, 2))
	var pit := FirePit.new()
	game.add_child(pit)
	await step(2)
	game.map_features.fuel_fire = pit
	game.open_modal("fuel")
	game.menu.show_fuel()
	await capture("fire")
	quit(0)
