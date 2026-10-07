extends SceneTree
## Engine screenshots of B5 (evidence/rhodes-engine/b5-*): station markers and
## the base's top bar, the warehouse terminal's expansion menu, a newly built
## rack in place, the drone's sort reveal, and the departure card.
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
	game._grant(0, 60)   # R2
	game.base.contamination = 46
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in range(6): game.base.receive(FieldCatalog.roll_item(["mine", "city", "snow"][i % 3], 3, rng))
	place(game.base_map.spawn_point("arrival") + Vector3(0, 0, 10))
	await wait(0.5)
	await shot("hall-markers")
	place(game.base_map.station("stash").position + Vector3(0, 0, -1.5))
	await wait(3.0)
	await shot("receiving-markers")
	game.open_station("stash")
	await shot("terminal")
	game.build_rack(Item.Category.ARMOR)
	game.build_rack(Item.Category.ARMOR)
	game.buy_drone()
	game.close_modal()
	var zone: Array = game.warehouse_view.anchors.zones.armor
	place(game.base_map.to_world((zone[0] + zone[2]) * 0.5, zone[3] + 2.0, BaseMap.PLAYER_Y))
	await wait(3.5)
	await shot("new-racks")
	game.sort_everything()
	await wait(1.0)
	await shot("sort-reveal")
	await wait(4.0)
	game.close_modal()
	await wait(0.4)
	await shot("drone")
	game.base.receive(Item.create("未开的货", Item.Category.MATERIAL, 1, 1))
	game.request_contract("mine")
	await shot("departure")
	quit()
