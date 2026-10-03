extends SceneTree
## Frames of the warehouse entry: lights and floor hatches opening together,
## then the personal-storage shelves rising out of the hatches (evidence/rhodes-engine/).
var rig: Node
var game: GameManager
func _initialize() -> void: call_deferred("run")
func step(count: int = 1) -> void:
	for i in range(count): await process_frame
func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null
func grab(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/rhodes-engine/warehouse-reveal-" + label + ".png")
func place(x: float, z: float) -> void:
	game.player.teleport(game.base_map.to_world(x, z, BaseMap.PLAYER_Y))
	game.camera.global_position = game.camera_target() + GameManager.CAMERA_OFFSET
func run() -> void:
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(15)
	game = find_game(rig)
	var reveal := game.base_map.warehouse_reveal
	# With the racks on screen: dark, then lights and hatches opening together, then shelves rising.
	place(3.0, -26.0)
	await step(10)
	place(-44.0, -30.0)
	await step(2)
	game.base_map.warehouse_reveal.reset()  # the camera jumped; start from dark with the racks in view
	await grab("00-dark")
	var n := 1
	for i in range(120):
		await step()
		if i % 3 == 0:
			await grab("%02d" % n)
			n += 1
		if reveal.settled(): break
	await step(5)
	await grab("final")
	rig.queue_free()
	await create_timer(0.3).timeout
	quit()
