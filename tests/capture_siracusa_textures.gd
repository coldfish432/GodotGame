extends SceneTree
## Two close terrain captures for 叙拉古贴图美术需求_v1.md.
## Writes ../evidence/siracusa-texture-<weather>-<seed>.png.

const SEEDS := [2026, 523645]
var rig: Node
var game: GameManager

func _initialize() -> void:
	call_deferred("run")

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
		await game.start_contract("siracusa")
		game.open_modal("capture")
		var map := game.world_map
		var at: Vector2 = map.main_path[0] + Vector2(0, 8)
		game.player.teleport(map.nearest_walkable(Vector3(at.x, 0.7, at.y)))
		game.camera.size = 20.0
		game.camera.global_position = game.player.global_position + GameManager.CAMERA_OFFSET * (20.0 / 24.0)
		game._hud.hide()
		await step(16)
		await RenderingServer.frame_post_draw
		var path := "res://../evidence/siracusa-texture-%s-%d.png" % [map.weather, map_seed]
		var error := root.get_texture().get_image().save_png(path)
		print("TEXTURE CAPTURE ", map.weather, " ", path, " error ", error)
		game.close_modal()
		game.settle(true)
		await step()
	quit()
