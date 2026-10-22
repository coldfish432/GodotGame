extends SceneTree
## Screenshots of the trader screens with the new flasks (药剂与商人界面策划案):
## 药房 (白舱), 可露希尔 at the base and in a camp, 坎诺特, a post.
## Writes evidence/shop-*.png. Not part of run_all (no checks).
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
	root.get_texture().get_image().save_png("res://../evidence/shop-" + label + ".png")
func run() -> void:
	SystemScreens.settings["ui_motion"] = false
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(15)
	game = find_game(rig)
	game.base.max_facilities()
	game.inventory.add_stack(MaterialCatalog.create(Economy.GOLD_ID, 20))
	game.open_station("pharmacy")
	await capture("pharmacy")
	game.close_modal()
	game.open_station("store")
	await capture("closure-base")
	game.close_modal()
	await game.start_contract("snow")
	await step(10)
	game.give_gold_bars(12)
	game.floor_number = 10
	game._enter_camp()
	await capture("closure-camp")
	game.leave_camp()
	await step(10)
	game.encounter = "trader"
	game._roll_trader_stock()
	game._open_encounter()
	await capture("cannot")
	game.close_modal()
	game.encounter = "post"
	game.post_faction = "sami"
	game.menu.trader_tab = "buy"
	game.open_modal("post")
	TraderScreen.post(game.menu)
	await capture("post-sami")
	quit(0)
