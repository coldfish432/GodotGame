extends SceneTree
## A top-down orthographic overview of whole floors (region from the first
## user argument, default snow), to read the layout as a map.
## ../evidence/overview-<region>-<seed>.png.
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
	var region := "snow"
	for arg in OS.get_cmdline_user_args(): region = arg
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step()
	game = find_game(rig)
	for map_seed in [2026, 4477]:
		game.fixed_map_seed = map_seed
		await game.start_contract(region)
		game.open_modal("capture")
		game._hud.hide()
		var overview := Camera3D.new()
		game.add_child(overview)
		overview.projection = Camera3D.PROJECTION_ORTHOGONAL
		var bounds: Vector2 = game.world_map.SPINE_MAX - game.world_map.SPINE_MIN
		overview.size = maxf(bounds.y, bounds.x * 720.0 / 1280.0) * 1.05
		overview.global_position = game.world_map.map_center + Vector3(0, 150, 0)
		overview.look_at(game.world_map.map_center, Vector3.BACK)
		overview.make_current()
		await step()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../evidence/overview-%s-%d.png" % [region, map_seed])
		overview.queue_free()
		game.camera.make_current()
		game._hud.show()
		game.close_modal()
		game.settle(true)
	rig.queue_free()
	await create_timer(0.4).timeout
	quit()
