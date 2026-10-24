extends SceneTree
## Engine screenshots of B5 (evidence/rhodes-engine/b5-*): station markers and
## the base's top bar, the warehouse terminal, a bigger warehouse (仓库修订:
## only capacity and stack size are upgraded), and the departure card.
var game: GameManager
func _initialize() -> void: call_deferred("run")
func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null
func frames(n: int) -> void:
	for i in range(n): await process_frame
func wait(seconds: float) -> void:
	await create_timer(seconds).timeout
func shot(label: String) -> void:
	await frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/rhodes-engine/b5-" + label + ".png")
func place(at: Vector3) -> void:
	game.player.teleport(at)
	game.camera.global_position = game.camera_target() + GameManager.CAMERA_OFFSET
func run() -> void:
	var rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await frames(20)
	game = find_game(rig)
	game.gold = 90000
	game.base.set_facility("warehouse", 3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in range(6): game.base.receive(FieldCatalog.roll_item(["mine", "city", "snow"][i % 3], 3, rng))
	place(game.base_map.spawn_point("arrival") + Vector3(0, 0, 10))
	await wait(0.5)
	await shot("hall-markers")
	place(game.base_map.station("stash").position + Vector3(0, 0, -1.5))
	await wait(3.0)
	await shot("stash-markers")
	game.open_station("stash")
	await shot("terminal")
	game.close_modal()
	game.base.set_facility("warehouse", 4)
	game.open_station("stash")
	await wait(0.5)
	await shot("warehouse-lv4")
	game.close_modal()
	game.base.receive(Item.create("未开的货", Item.Category.MATERIAL, 1, 1))
	game.request_contract("mine")
	await shot("departure")
	quit()
