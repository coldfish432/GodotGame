extends SceneTree
## Screenshots of the sand table (沙盘航行策划案_v1_0.md §6): at anchor with a
## stay running, under way, and the hall's table with the ship on its leg.
## Writes evidence/sand-table-*.png. Not part of run_all (no checks).
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
	root.get_texture().get_image().save_png("res://../evidence/sand-table-" + ("en-" if I18n.is_english() else "") + label + ".png")
func run() -> void:
	if OS.get_environment("DOWNFALL_LANG") == "en": I18n.set_language("en")
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(15)
	game = find_game(rig)
	game.save_enabled = false
	if is_instance_valid(game.system_screens): game.system_screens.hide()
	game.gold = 640000
	game.exchange.relations = {"karlan": 700, "lungmen": 342, "rat": 38, "rhine": 300, "kazimierz": 150}
	game.base.ship_at = "龙门"
	for item in [MaterialCatalog.create("螺栓", 24), MaterialCatalog.create("代糖", 12), MaterialCatalog.create("固源岩", 12)]:
		game.base.shelf.append(item)
	var v := game.voyage
	v.tick(BaseState.now())
	v.set_stay("injured", true, BaseState.now())
	v.set_supplies(true)
	v.set_budget(30000)
	v.set_target("lungmen", 500)
	game.open_station("sand_table")
	await capture("anchor")
	game.close_modal()
	game.sail("萨米", "fast")
	BaseState.clock_offset += int(v.sailing.due - v.sailing.start) / 3
	game.show_ship()
	game.open_station("sand_table")
	await capture("sailing")
	game.close_modal()
	quit(0)
