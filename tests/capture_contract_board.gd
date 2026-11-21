extends SceneTree
## 合同板修订案_v0_1.md on screen: 调度台's 出发 page with this run's contracts,
## the 合同板 page, the field tracker with several cards, and the settlement.
## ../evidence/contract-board-<shot>.png.
var rig: Node
var game: GameManager
func _initialize() -> void: call_deferred("run")
func step(count: int = 8) -> void:
	for i in range(count): await process_frame
func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null
func save(label: String) -> void:
	# The terminal's wipe has to finish first.
	await step(90)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/contract-board-" + label + ".png")
func run() -> void:
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step()
	game = find_game(rig)
	game.save_enabled = false
	game.board_cards()
	# Two run cards for 切尔诺伯格 and a delivery, beside the first contract.
	for c in game.base.board.posted.duplicate():
		if game.base.board.active.size() >= 3: break
		if str(c.type) in ["deep", "hunt"] and str(c.region) == "mine": game.take_contract(c)
	BaseScreens.dispatch_tab = 0
	game.open_station("contracts")
	await save("depart")
	BaseScreens.dispatch_tab = 1
	game.open_station("contracts")
	await save("board")
	BaseScreens.dispatch_tab = 0
	game.close_modal()
	await game.start_contract("mine")
	await step(30)
	game.inventory.try_add(MaterialCatalog.create("源岩", 2))
	await step(4)
	await save("tracker")
	game.floor_number = game.start_floor + 4
	game.settle(true)
	await step(10)
	await save("settle")
	quit()
