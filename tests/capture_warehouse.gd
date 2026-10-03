extends SceneTree
## Engine screenshots of the warehouse in use (evidence/rhodes-engine/b2-*, b3-*):
## crates at receiving, the item card, carrying to a lit zone, a shelved item,
## loaded staging pallets, the order board and the outbound menu.
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
## Animations run on game time; uncapped rendering gets through frames faster than that.
func wait(seconds: float) -> void:
	await create_timer(seconds).timeout
func shot(label: String) -> void:
	await frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/rhodes-engine/b2-" + label + ".png")
func place(p: Array) -> void:
	game.player.teleport(game.base_map.to_world(p[0], p[1], BaseMap.PLAYER_Y))
	game.camera.global_position = game.camera_target() + GameManager.CAMERA_OFFSET
func run() -> void:
	var rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await frames(20)
	game = find_game(rig)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in range(9): game.base.receive(FieldCatalog.roll_item(["mine", "city", "snow"][i % 3], 3, rng))
	for i in range(30): game.base.staging.append(FieldCatalog.roll_item("mine", 2, rng))
	var a: Dictionary = game.warehouse_view.anchors
	place([a.bays[1][0], a.bays[1][1] + 1.2])
	await wait(3.0)  # lights and shelves settle
	await shot("receiving")
	game._base_interact()
	await shot("item-card")
	var opened: Item = game.base.crates[1].item
	game.close_modal()
	game.pick_up_item(opened)
	var zone: Array = a.zones[WarehouseView.CATEGORY_KEYS[opened.category]]
	place([(zone[0] + zone[2]) * 0.5, (zone[1] + zone[3]) * 0.5])
	await wait(2.5)
	await shot("carrying")
	game.shelve_carried(opened.category)
	await shot("shelved")
	place([(a.staging[0] + a.staging[2]) * 0.5, a.staging[1] - 1.0])
	await wait(0.5)
	await shot("staging")
	# B3: the order board over the outbound pallets, and the outbound menu.
	game.base.orders.slots = [{"id": "starter", "state": "open", "delivered": []}, {"id": "log_fine_weapon", "state": "open", "delivered": []}]
	var spare := Item.create("封装矿料", Item.Category.MATERIAL, 1, 1)
	spare.value = 22
	game.base.shelf.append(spare)
	var station: Dictionary = game.base_map.station("outbound")
	game.player.teleport(station.position)
	game.camera.global_position = game.camera_target() + GameManager.CAMERA_OFFSET
	await wait(0.5)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/rhodes-engine/b3-outbound.png")
	game._base_interact()
	await frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/rhodes-engine/b3-outbound-menu.png")
	quit()
