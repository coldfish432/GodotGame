extends SceneTree
## Close-ups of the Blender terrace kit (TerraceDressing) at a cliff and a ramp,
## one seed per region, written to ../evidence/terrain-dress-*.png.
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
	var shot := {}
	for attempt in range(18):
		var region: String = ["mine", "city", "snow"][attempt % 3]
		if shot.has(region): continue
		game.fixed_map_seed = 1000 + attempt * 37
		await game.start_contract(region)
		game.open_modal("capture")
		game.camera.size = 24
		var pair := _cliff_pair(game.world_map)
		var ramps: Array[Dictionary] = game.world_map.ramp_midpoints()
		if not pair.is_empty() and not ramps.is_empty():
			var middle: Vector2 = (pair[0] + pair[1]) * 0.5
			game.player.teleport(game.world_map.nearest_walkable(Vector3(pair[1].x, 0.7, pair[1].y)))
			game.camera.global_position = Vector3(middle.x, game.player.global_position.y, middle.y) + GameManager.CAMERA_OFFSET
			await capture("dress-" + region + "-cliff")
			var foot: Vector2 = ramps[0].point
			game.player.teleport(game.world_map.nearest_walkable(Vector3(foot.x, 0.7, foot.y)))
			game.camera.global_position = game.player.global_position + GameManager.CAMERA_OFFSET
			await capture("dress-" + region + "-ramp")
			var caps: Array[Transform3D] = game.world_map.terrace_dressing.frame_caps
			if not caps.is_empty():
				var under: Vector3 = caps[0].origin
				game.player.teleport(game.world_map.nearest_walkable(Vector3(under.x, 0.7, under.z + 2.0)))
				game.camera.global_position = game.player.global_position + GameManager.CAMERA_OFFSET
				await capture("dress-" + region + "-frame")
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
