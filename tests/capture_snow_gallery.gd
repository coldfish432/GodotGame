extends SceneTree
## A gallery of random snowfield floors under the normal follow camera, HUD hidden:
## for each seed, a cliff, a ramp, a timber frame and a room where the floor
## has them. Written to ../evidence/snow-gallery-<seed>-<shot>.png.
var rig: Node
var game: GameManager
const SEEDS := [2026, 3141, 4477, 5813, 6620, 7919]

func _initialize() -> void: call_deferred("run")

func step(count: int = 8) -> void:
	for i in range(count): await process_frame

func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null

func shot(at: Vector2, label: String) -> void:
	game.player.teleport(game.world_map.nearest_walkable(Vector3(at.x, 0.7, at.y)))
	game.camera.global_position = game.player.global_position + GameManager.CAMERA_OFFSET
	await step()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/snow-gallery-" + label + ".png")

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
		game._hud.hide()
		game.camera.size = 24
		var map := game.world_map
		var dressing: TerraceDressing = map.terrace_dressing
		var taken := 0
		# A cliff: the middle of the longest face.
		var longest := {}
		for chain in dressing.cliff_face.chains:
			if not chain.bank and (longest.is_empty() or chain.length > longest.length): longest = chain
		if not longest.is_empty():
			var points: PackedVector2Array = longest.points
			await shot(points[points.size() / 2] + longest.front[points.size() / 2] * 3.0, "%d-cliff" % map_seed)
			taken += 1
		var ramps := map.ramp_midpoints()
		if not ramps.is_empty():
			await shot(ramps[0].point, "%d-ramp" % map_seed)
			taken += 1
		if not dressing.frame_caps.is_empty():
			var under: Vector3 = dressing.frame_caps[dressing.frame_caps.size() / 2].origin
			await shot(Vector2(under.x, under.z + 2.0), "%d-frame" % map_seed)
			taken += 1
		if dressing.rail_network != null and not dressing.rail_network.switches.is_empty():
			var points: Vector3 = dressing.rail_network.switches[0].origin
			await shot(Vector2(points.x, points.z), "%d-junction" % map_seed)
		if not dressing.marker_points.is_empty():
			var mark: Vector3 = dressing.marker_points[dressing.marker_points.size() / 2].origin
			await shot(Vector2(mark.x, mark.z + 1.5), "%d-waymark" % map_seed)
		# The way down, under its headframe.
		var marker: Vector3 = map.route_nodes[1].position
		await shot(Vector2(marker.x, marker.z), "%d-exit" % map_seed)
		if map.exit_node.visible:
			await shot(Vector2(map.exit_node.position.x, map.exit_node.position.z + 1.5), "%d-extract" % map_seed)
		# A big room, for the floor and banks at large.
		var room: Vector3 = map._open_circles[map.main_path.size() / 2]
		for circle in map._open_circles:
			if circle.z > room.z: room = circle
		await shot(Vector2(room.x, room.y), "%d-room" % map_seed)
		game._hud.show()
		game.close_modal()
		game.settle(true)
	rig.queue_free()
	await create_timer(0.4).timeout
	quit()
