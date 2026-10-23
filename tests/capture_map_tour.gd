extends SceneTree
## A tour of every field map: per region (Lungmen as 下城 and 上城) two seeds,
## four spots along the main path at play zoom plus one wide shot, HUD hidden.
## ../evidence/map_tour/<map>-<seed>-<k>.png.
var rig: Node
var game: GameManager
const MAPS := [["mine", ""], ["city", "lower"], ["city", "upper"], ["snow", ""], ["siracusa", ""]]
const SEEDS := [2026, 4477]
func _initialize() -> void: call_deferred("run")
func step(count: int = 8) -> void:
	for i in range(count): await process_frame
func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null
func shot(at: Vector2, label: String, size: float = 24.0) -> void:
	game.player.teleport(game.world_map.nearest_walkable(Vector3(at.x, 0.7, at.y)))
	game.camera_size_goal = size
	game.camera.size = size
	game.camera.global_position = game.player.global_position + GameManager.CAMERA_OFFSET * (size / 24.0)
	# Every overlay off, not the layer the world is drawn through (capture_city_variants).
	var layers: Array[CanvasLayer] = []
	for node in root.find_children("*", "CanvasLayer", true, false):
		if node.find_children("*", "SubViewportContainer", true, false).size() > 0 or node.find_children("*", "SubViewport", true, false).size() > 0: continue
		if (node as CanvasLayer).visible:
			layers.append(node)
			(node as CanvasLayer).visible = false
	await step(16)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/map_tour/" + label + ".png")
	for layer in layers: layer.visible = true
	game.camera_size_goal = GameManager.CAMERA_SIZE
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../evidence/map_tour"))
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step()
	game = find_game(rig)
	for entry in MAPS:
		var region: String = entry[0]
		ContinuousWorldMap.force_city_variant = entry[1]
		var name: String = region if entry[1] == "" else region + "_" + entry[1]
		for map_seed in SEEDS:
			game.fixed_map_seed = map_seed
			await game.start_contract(region)
			game.open_modal("capture")
			var path: PackedVector2Array = game.world_map.main_path
			var k := 0
			for f in [0.08, 0.35, 0.62, 0.9]:
				await shot(path[int((path.size() - 1) * f)], "%s-%d-%d" % [name, map_seed, k])
				k += 1
			await shot(path[path.size() / 2], "%s-%d-wide" % [name, map_seed], 48.0)
			print("captured %s %d" % [name, map_seed])
			game._hud.visible = true
			game.close_modal()
			game.settle(true)
	ContinuousWorldMap.force_city_variant = ""
	rig.queue_free()
	await create_timer(0.4).timeout
	quit()
