extends SceneTree
## Lungmen floors (CityDressing): a wide overview and a few street-level shots
## under the follow camera, HUD hidden. ../evidence/city-<seed>-<shot>.png.
var rig: Node
var game: GameManager
const SEEDS := [2026, 3141, 4477]
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
	game.camera.size = size
	game.camera.global_position = game.player.global_position + GameManager.CAMERA_OFFSET * (size / 24.0)
	game._hud.hide()
	await step()
	await step(2)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/city-" + label + ".png")
func run() -> void:
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step()
	game = find_game(rig)
	for map_seed in SEEDS:
		game.fixed_map_seed = map_seed
		await game.start_contract("city")
		game.open_modal("capture")
		var map := game.world_map
		var kinds := []
		for d in map.districts: kinds.append(d.kind)
		print("neon %d" % map.terrace_dressing.city.neon_count)
		print("seed %d districts %s buildings %d gates %d barricades %d bridges %d culverts %d scaffolds %d fronts %d sides %d fences %d lights %d furniture %d wrecks %d cables %d borders %s cranes %d zebras %d" % [map_seed, kinds, map.terrace_dressing.city.building_count, map.terrace_dressing.city.gate_count, map.terrace_dressing.city.barricade_count, map.bridges.size(), map.terrace_dressing.city.culvert_count, map.terrace_dressing.city.scaffold_count, map.terrace_dressing.city.frontage_count, map.terrace_dressing.city.side_streets.size(), map.terrace_dressing.city.fence_count, map.terrace_dressing.city.traffic_light_count, map.terrace_dressing.city.furniture_count, map.terrace_dressing.city.wreck_count, map.terrace_dressing.city.cable_count, map.terrace_dressing.city.border_counts, map.terrace_dressing.city.landmark_count, map.terrace_dressing.city.zebra_count])
		await shot(map.main_path[0] + Vector2(0, 8), "%d-entry" % map_seed)
		await shot(map.main_path[map.main_path.size() / 2], "%d-mid" % map_seed)
		await shot(map.main_path[map.main_path.size() / 2], "%d-wide" % map_seed, 60.0)
		await shot(map.main_path[map.main_path.size() / 2], "%d-over" % map_seed, 150.0)
		for d in map.districts:
			if d.kind == "slum":
				await shot(d.point, "%d-slum" % map_seed)
				break
		if map._closed_circles.size() > 0:
			var pillar: Vector3 = map._closed_circles[0]
			await shot(Vector2(pillar.x, pillar.y + pillar.z + 3.0), "%d-pillar" % map_seed)
		var city = map.terrace_dressing.city
		for k in range(mini(2, city.zebra_points.size())):
			await shot(city.zebra_points[k * 3 % city.zebra_points.size()], "%d-zebra%d" % [map_seed, k])
		for k in range(mini(2, city._gate_points.size())):
			await shot(city._gate_points[k] - Vector2(0, 3.0), "%d-gate%d" % [map_seed, k])
		if not city._border_lines.is_empty():
			await shot(city._border_lines[city._border_lines.size() / 2].at - Vector2(0, 3.0), "%d-border" % map_seed)
		for k in range(mini(2, city.neon_points.size())):
			await shot(city.neon_points[k * 7 % city.neon_points.size()], "%d-neon%d" % [map_seed, k], 30.0)
		for k in range(city.landmark_points.size()):
			await shot(city.landmark_points[k] - Vector2(0, 10.0), "%d-crane" % map_seed, 40.0)
		var mouth_shots := 0
		for street in map.terrace_dressing.city.side_streets:
			if mouth_shots >= 2: break
			for mouth in street.mouths:
				if mouth_shots >= 2: break
				await shot(mouth.tip - (mouth["in"] as Vector2) * 4.0, "%d-mouth%d" % [map_seed, mouth_shots])
				mouth_shots += 1
		for k in range(mini(2, map.terrace_dressing.city.bank_points.size())):
			await shot(map.terrace_dressing.city.bank_points[k] + Vector2(0, -4.0), "%d-bank%d" % [map_seed, k])
		game._hud.visible = true
		game.close_modal()
		game.settle(true)
	rig.queue_free()
	await create_timer(0.4).timeout
	quit()
