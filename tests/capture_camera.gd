extends SceneTree
## The turnable, zoomable follow camera at a few turns and zooms: the base's
## hall and warehouse, a Lungmen street and a mine floor
## (../evidence/camera/<place>-<turn>-<size>.png).
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
func view(label: String, at: Vector3, turn: float, size: float, tilt: float = 58.0) -> void:
	game.player.teleport(at)
	game.camera_pitch = GameManager.CAMERA_PITCH if tilt == 58.0 else deg_to_rad(tilt)
	game.camera_pitch_goal = game.camera_pitch
	game.camera_yaw = deg_to_rad(turn)
	game.camera_yaw_goal = game.camera_yaw
	game.camera_size_goal = size
	game.camera.size = size
	game.camera.global_position = game.camera_target() + game.camera_offset()
	await step(30)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/camera/%s-%d-%d%s.png" % [label, roundi(turn), roundi(size), "" if tilt == 58.0 else "-t%d" % roundi(tilt)])
func sweep(label: String, at: Vector3) -> void:
	for turn in [0.0, 45.0, 90.0, 135.0, 180.0, -90.0, -45.0]:
		await view(label, at, turn, 24.0)
	await view(label, at, 0.0, GameManager.CAMERA_SIZE_MIN)
	await view(label, at, 0.0, GameManager.CAMERA_SIZE_MAX)
	await view(label, at, 135.0, GameManager.CAMERA_SIZE_MAX)
	for tilt in [50.0, 70.0]:
		await view(label, at, 0.0, 24.0, tilt)
		await view(label, at, 180.0, 24.0, tilt)
		await view(label, at, 0.0, GameManager.CAMERA_SIZE_MIN, tilt)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../evidence/camera"))
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(15)
	game = find_game(rig)
	# Pause → 按键设置, with the 视角 group.
	game.toggle_panel("pause")
	game.menu.pause_page = 2
	BaseScreens.pause(game.menu)
	await step(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/camera/_keys.png")
	game.toggle_panel("pause")
	await step(2)
	if "--keys" in OS.get_cmdline_user_args():
		quit()
		return
	await sweep("base-hall", game.base_map.to_world(64, -24, BaseMap.PLAYER_Y))
	# Stand in the warehouse until its lights are on and the racks have risen.
	game.player.teleport(game.base_map.to_world(-30, -27, BaseMap.PLAYER_Y))
	for i in range(8): await create_timer(1.0).timeout
	await sweep("base-warehouse", game.base_map.to_world(-40, -27, BaseMap.PLAYER_Y))
	await sweep("base-medical", game.base_map.to_world(158, -15, BaseMap.PLAYER_Y))
	for region in [["city", 2026], ["mine", 1729], ["snow", 4242], ["siracusa", 2026]]:
		game.fixed_map_seed = region[1]
		await game.start_contract(region[0])
		game._clear_field()
		game.open_modal("capture")
		var map := game.world_map
		await sweep(region[0], map.nearest_walkable(Vector3(map.main_path[map.main_path.size() / 2].x, 0.7, map.main_path[map.main_path.size() / 2].y)))
		# Under a terrace's cliff: the ground north of her a good step higher.
		var cliff := Vector2.INF
		var rise := 0.0
		var points: Array[Vector2] = []
		for x in range(-int(map.map_extent), int(map.map_extent), 3):
			for z in range(-int(map.map_extent), int(map.map_extent), 3):
				var at := Vector2(map.map_center.x + x, map.map_center.z + z)
				if map._is_open(at.x, at.y, -0.3): points.append(at)
		for point in points:
			for reach in [4.0, 7.0]:
				var up := map.ground_height(point + Vector2(0, reach)) - map.ground_height(point)
				if up > rise:
					rise = up
					cliff = point
		print("%s cliff rise %.1f" % [region[0], rise])
		if cliff != Vector2.INF: await sweep(region[0] + "-cliff", map.nearest_walkable(Vector3(cliff.x, 0.7, cliff.y)))
		game.close_modal()
		game.settle(true)
		await step(20)
	rig.queue_free()
	await create_timer(0.4).timeout
	quit()
