extends SceneTree
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
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/guards-" + label + ".png")
func run() -> void:
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(5)
	game = find_game(rig)
	game.fixed_map_seed = 1729
	await game.start_contract("city")
	game.player.invulnerable = true
	# Keep one genuine generated supply squad in view, with its search object.
	var post: GuardPost = get_nodes_in_group("guard_posts")[2]
	var anchor := post.global_position
	var main: Vector2 = game.world_map.main_path[2]
	var approach := (Vector3(main.x, 0, main.y) - anchor).normalized()
	game.set_process(false)
	game.camera.size = 24
	game.camera.global_position = anchor + approach * 4 + GameManager.CAMERA_OFFSET
	game.player.teleport(game.world_map.nearest_walkable(anchor + approach * 9) + Vector3.UP * 0.7)
	await step(6)
	await capture("01-idle")
	game.player.teleport(game.world_map.nearest_walkable(anchor + approach * 5) + Vector3.UP * 0.7)
	await step(45)
	await capture("02-alert")
	# Pull the melee guard away from its station while staying inside the
	# release radius, so the return capture shows actual travel home.
	game.player.teleport(game.world_map.nearest_walkable(anchor + approach * 9) + Vector3.UP * 0.7)
	await step(150)
	game.player.teleport(game.world_map.nearest_walkable(anchor + approach * 15) + Vector3.UP * 0.7)
	await step(2)
	await capture("03-return")
	await step(240)
	await capture("04-home")
	rig.queue_free()
	await create_timer(0.4).timeout
	quit()
