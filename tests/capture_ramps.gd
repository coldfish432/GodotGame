extends SceneTree
## Ramps under the follow camera (HUD hidden): the middle of each of the first
## few ramps on a few snowfield floors. ../evidence/ramp-<seed>-<n>.png.
var rig: Node
var game: GameManager
const SEEDS := [1005, 2026, 3141]

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
	for map_seed in SEEDS:
		game.fixed_map_seed = map_seed
		await game.start_contract("snow")
		game.open_modal("capture")
		game._hud.visible = false
		game.camera.size = 24
		var ramps: Array[Dictionary] = game.world_map.ramp_midpoints()
		for i in range(mini(3, ramps.size())):
			var at: Vector2 = ramps[i].point
			game.player.teleport(game.world_map.nearest_walkable(Vector3(at.x, 0.7, at.y)))
			game.camera.global_position = game.player.global_position + GameManager.CAMERA_OFFSET
			await step()
			await RenderingServer.frame_post_draw
			game._hud.visible = false
			await step(2)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://../evidence/ramp-%d-%d.png" % [map_seed, i])
		game.close_modal()
		game.settle(true)
	rig.queue_free()
	await create_timer(0.4).timeout
	quit()
