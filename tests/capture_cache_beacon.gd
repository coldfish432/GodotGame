extends SceneTree
## A combat cache's beacon from afar, and her arrow on the minimap. Writes
## evidence/cache-beacon-*.png. Not in run_all.
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
func capture(label: String) -> void:
	await step(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/cache-beacon-" + label + ".png")
	print("captured ", label)
func run() -> void:
	SystemScreens.settings["ui_motion"] = false
	SystemScreens.settings["tutorial_step"] = TutorialCard.STEPS.size()
	SystemScreens.settings["tutorial_tips"] = false
	SystemScreens.settings["story_guide"] = false
	var rig: Node = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(15)
	game = find_game(rig)
	game.save_enabled = false
	game.fixed_map_seed = 2718
	game.route_plain = true
	await game.start_contract("mine")
	await step(30)
	for enemy in game.floor_enemies(): enemy.queue_free()
	var at := game.world_map.nearest_walkable(game.player.global_position + Vector3(6, 0, -10))
	game._spawn_relic_cache(at, "cache", false)
	game.player.teleport(at + Vector3(-3, 0, -6))
	game.camera.global_position = game.camera_target() + GameManager.CAMERA_OFFSET
	await step(40)
	await capture("far")
	var hud: Hud = game._hud
	print("player ", game.player.position, " map pt ", hud.map_point(game.player.position), " heading ", hud.player_heading(), " centre ", game.world_map.map_center, " extent ", game.world_map.map_extent)
	game.player.look_at(game.player.global_position + Vector3(1, 0, 0), Vector3.UP)
	await step(5)
	await capture("arrow-east")
	# The big map (M), with the cache, the route and the boxes on it.
	game.fog.reveal_all()
	game.toggle_panel("map")
	await step(10)
	await capture("bigmap")
	quit(0)
