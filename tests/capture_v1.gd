extends SceneTree
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
func capture(label: String) -> void:
	await step(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/v1-" + label + ".png")
func run() -> void:
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(15)
	game = find_game(rig)
	await capture("base")
	game.open_station("contracts")
	await capture("base-contracts")
	game.close_modal()
	for region in FieldCatalog.REGIONS:
		await game.start_contract(region)
		# Frame the shot on ground the layout actually carved. The old fixed
		# (0, -5) came from the open-box regions and lands inside rock once a
		# region generates its own layout, which made the captures show the
		# player and enemies standing in walls.
		var stage: Vector3 = game.world_map.try_sample_navigation_position(game.world_map.buff_position, 25.0)
		stage.y = 0.7
		game.player.teleport(stage)
		game.camera.size = 23
		game.camera.global_position = game.player.global_position + GameManager.CAMERA_OFFSET
		game.open_modal("capture")
		await capture(region)
		game._clear_field()
		game.player.teleport(stage)
		game.camera.size = 18
		game._spawn_enemy(stage + Vector3(-5, 0, -1), false, false)
		game._spawn_enemy(stage + Vector3(0, 0, 1), false, true)
		game._spawn_enemy(stage + Vector3(5, 0, -1), true, false)
		if region != "mine": game.spawn_warning_area(stage + Vector3(-3, 0, -4), 1.4, 1.0)
		await capture(region + "-enemies")
		game.close_modal()
		game.settle(true)
	await game.start_contract("mine")
	game.player.teleport(game.world_map.buff_position)
	game._interact()
	await capture("build")
	game.choose_build(game.build_offers[0].id)
	game.try_collect(FieldCatalog.exclusive("mine"))
	game.try_collect(FieldCatalog.exclusive("city"))
	game.try_collect(FieldCatalog.exclusive("snow"))
	game.open_modal("inventory")
	game._inventory_panel.open()
	await capture("inventory")
	game.close_modal()
	game.player.teleport(game.world_map.route_nodes[0].position)
	game._interact()
	await capture("routes")
	game.close_modal()
	game.settle(true)
	await capture("settlement")
	rig.queue_free()
	await create_timer(0.3).timeout
	quit()
