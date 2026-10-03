extends SceneTree
## Engine screenshots of the walkable Rhodes Island base (evidence/rhodes-engine/).
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
func shot(label: String, x: float, z: float) -> void:
	game.player.teleport(game.base_map.to_world(x, z, BaseMap.PLAYER_Y))
	game.camera.global_position = game.camera_target() + GameManager.CAMERA_OFFSET
	await step(12)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/rhodes-engine/base-" + label + ".png")
func run() -> void:
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(15)
	game = find_game(rig)
	await shot("arrival", 64, -53)
	await shot("center", 64, -24)
	await shot("lift", 64, -14)
	await shot("logistics", 101.3, -16)
	await shot("west-door", 3, -26)
	await shot("warehouse", -20, -26)
	await shot("medical", 150, -22)
	await shot("store", 9, 5)
	await shot("armory", 113, 6)
	rig.queue_free()
	await create_timer(0.3).timeout
	quit()
