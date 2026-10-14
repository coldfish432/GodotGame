extends SceneTree
## Search points (兴趣点) under the normal camera: one shot per distinct model
## found over a few mine floors, HUD hidden. ../evidence/poi-<model>.png.
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

func run() -> void:
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step()
	game = find_game(rig)
	var shot := {}
	for map_seed in [2026, 3141, 4477, 5813, 6620, 7919, 8888, 9001]:
		game.fixed_map_seed = map_seed
		await game.start_contract("mine")
		game.open_modal("capture")
		game._hud.hide()
		game.camera.size = 14
		for node in get_nodes_in_group("loot_containers"):
			var box := node as LootContainer
			if box.game != game: continue
			var key := box.variant if not box.variant.is_empty() else box.kind
			if shot.has(key): continue
			shot[key] = true
			var at := box.global_position
			game.player.teleport(game.world_map.nearest_walkable(Vector3(at.x + 1.6, 0.7, at.z + 1.2)))
			game.camera.global_position = Vector3(at.x, game.player.global_position.y, at.z) + GameManager.CAMERA_OFFSET
			await step()
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://../evidence/poi-" + key + ".png")
		game._hud.show()
		game.close_modal()
		game.settle(true)
	print("POI SHOTS ", shot.keys())
	rig.queue_free()
	await create_timer(0.4).timeout
	quit()
