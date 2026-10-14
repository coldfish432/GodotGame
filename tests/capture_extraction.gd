extends SceneTree
## The extraction marker (signal flare, green smoke and light) in each region,
## under the normal camera. Extraction is forced on for the shot, since only
## some floors have it. Written to ../evidence/extraction-<region>.png.
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
	for region in ["mine", "city", "snow"]:
		game.fixed_map_seed = 2026
		await game.start_contract(region)
		game.open_modal("capture")
		game._clear_field()
		var map := game.world_map
		map.extraction_available = true
		map.generate(map.seed_value, 1)
		await step(4)
		var at: Vector3 = map.exit_node.position
		game.player.teleport(map.nearest_walkable(Vector3(at.x + 2.5, 0.7, at.z - 1.5)))
		game.camera.size = 24
		game.camera.global_position = Vector3(at.x, game.player.global_position.y, at.z) + GameManager.CAMERA_OFFSET
		# Let the smoke column build before the shot.
		await create_timer(2.0).timeout
		await step()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../evidence/extraction-" + region + ".png")
		game.close_modal()
		game.settle(true)
	rig.queue_free()
	await create_timer(0.4).timeout
	quit()
