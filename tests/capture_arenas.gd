extends SceneTree
## Boss战场地策划案: each region's boss arena from above. Writes ../evidence/arena-<region>.png.
var rig: Node
var game: GameManager
func _initialize() -> void: call_deferred("run")
func step(count: int = 1) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
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
	await step(5)
	game = find_game(rig)
	game.fixed_map_seed = 1729
	for region in ["mine", "city", "snow", "siracusa"]:
		if not game.in_base:
			game.settle(true)
			await step(2)
		await game.start_contract(region)
		game.floor_number = 19
		await game.advance(0)
		await step(4)
		game.player.invulnerable = true
		game.player.teleport(game.world_map.nearest_walkable(game.arena.centre + Vector3(0, 0, -8.0)) + Vector3.UP * 0.7)
		game.fog.reveal_all() if game.fog.has_method("reveal_all") else null
		game.set_process(false)
		game.camera.size = 34
		game.camera.global_position = game.arena.centre + GameManager.CAMERA_OFFSET * (34.0 / 14.0)
		await step(6)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../evidence/arena-%s.png" % region)
		game.set_process(true)
	rig.queue_free()
	await create_timer(0.4).timeout
	quit()
