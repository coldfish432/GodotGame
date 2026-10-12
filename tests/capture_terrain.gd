extends SceneTree
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
func capture(label: String) -> void:
	await step()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/terrain-" + label + ".png")
func run() -> void:
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step()
	game = find_game(rig)
	game.fixed_map_seed = 1729
	for region in ["mine", "city", "snow"]:
		await game.start_contract(region)
		game.open_modal("capture")
		var point: Vector2 = game.world_map.main_path[3]
		game.player.teleport(Vector3(point.x, 0.7, point.y))
		game.camera.size = 24
		game.camera.global_position = game.player.global_position + GameManager.CAMERA_OFFSET
		await capture(region + "-road")
		if region == "mine":
			for prop in get_nodes_in_group("field_props"): prop.hide()
			for child in game.world_map._generated_root.get_children():
				if child.get_meta("art_kind", "") == "RouteTrace": child.hide()
			await capture("mine-terrain-only")
			for prop in get_nodes_in_group("field_props"): prop.show()
			for child in game.world_map._generated_root.get_children():
				if child.get_meta("art_kind", "") == "RouteTrace": child.show()
		point = game.world_map.main_path[2]
		game.player.teleport(Vector3(point.x - 2, 0.7, point.y - 4))
		game.camera.global_position = game.player.global_position + GameManager.CAMERA_OFFSET
		await capture(region + "-arena")
		# Terraces (地图场景改造 2026-10-12): a ramp from its foot, and the same
		# ramp's top looking back over the cliff it climbs beside.
		var ramps: Array[Dictionary] = game.world_map.ramp_midpoints()
		if not ramps.is_empty():
			var ramp: Dictionary = ramps[0]
			var foot: Vector2 = ramp.point - ramp.up * 6.0
			game.player.teleport(game.world_map.nearest_walkable(Vector3(foot.x, 0.7, foot.y)))
			game.camera.global_position = game.player.global_position + GameManager.CAMERA_OFFSET
			await capture(region + "-ramp")
			var top: Vector2 = ramp.point + ramp.up * 7.0
			game.player.teleport(game.world_map.nearest_walkable(Vector3(top.x, 0.7, top.y)))
			game.camera.global_position = game.player.global_position + GameManager.CAMERA_OFFSET
			await capture(region + "-terrace")
		# Art review views use the unchanged gameplay camera, with HUD hidden.
		game._hud.set_process(false)
		game._hud.hide()
		for stage in [3, 5]:
			point = game.world_map.main_path[stage]
			game.player.teleport(Vector3(point.x, 0.7, point.y))
			game.camera.global_position = game.player.global_position + GameManager.CAMERA_OFFSET
			await capture(region + "-scene-" + str(stage))
		game._hud.show()
		game._hud.set_process(true)
		# Independent overhead camera: the follow camera keeps its real angle.
		var overview := Camera3D.new()
		game.add_child(overview)
		overview.projection = Camera3D.PROJECTION_ORTHOGONAL
		# Framed from the map's own bounds rather than a fixed number, so this
		# shot keeps showing the whole segment when the layout is rescaled.
		var bounds: Vector2 = ContinuousWorldMap.SPINE_MAX - ContinuousWorldMap.SPINE_MIN
		overview.size = maxf(bounds.y, bounds.x * 720.0 / 1280.0) * 1.05
		overview.global_position = game.world_map.map_center + Vector3(0, 150, 0)
		overview.look_at(game.world_map.map_center, Vector3.BACK)
		overview.make_current()
		await capture(region + "-overview")
		overview.queue_free()
		game.camera.make_current()
		game.close_modal()
		game.settle(true)
	# A cliff between terraces, from the normal camera, in each region.
	var shot := {}
	for attempt in range(18):
		var region: String = ["mine", "city", "snow"][attempt % 3]
		if shot.has(region): continue
		game.fixed_map_seed = 1000 + attempt * 37
		await game.start_contract(region)
		game.open_modal("capture")
		var pair := _cliff_pair(game.world_map)
		if not pair.is_empty():
			var middle: Vector2 = (pair[0] + pair[1]) * 0.5
			game.player.teleport(game.world_map.nearest_walkable(Vector3(pair[1].x, 0.7, pair[1].y)))
			game.camera.global_position = Vector3(middle.x, game.player.global_position.y, middle.y) + GameManager.CAMERA_OFFSET
			await capture(region + "-cliff")
			shot[region] = true
		game.close_modal()
		game.settle(true)
	rig.queue_free()
	await create_timer(0.4).timeout
	quit()

## Two level spots a few metres apart across a cliff (see test_elevation).
func _cliff_pair(map: ContinuousWorldMap) -> Array:
	for z in range(int(map.SPINE_MIN.y), int(map.SPINE_MAX.y), 2):
		for x in range(int(map.SPINE_MIN.x), int(map.SPINE_MAX.x), 2):
			var high := Vector2(x, z)
			if not map._has_clearance(high): continue
			var h := map.ground_height(high)
			if h < map.TIER - 0.1: continue
			for k in range(8):
				var direction := Vector2.from_angle(TAU * k / 8.0)
				var low := high + direction * 5.0
				if not map._has_clearance(low) or map.ground_height(low) > h - map.TIER + 0.1: continue
				var open := true
				for t in range(1, 10):
					if not map._is_open(high.x + direction.x * t * 0.5, high.y + direction.y * t * 0.5, 0.0): open = false
				if open: return [high, low]
	return []
