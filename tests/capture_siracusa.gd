extends SceneTree
## 叙拉古 floors (SiracusaDressing, stage S2): the overview, a lane, a piazza,
## a mansion's court and the landmarks under the follow camera.
## ../evidence/siracusa-<seed>-<shot>.png.
var rig: Node
var game: GameManager
const SEEDS := [2026, 523645]
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
	root.get_texture().get_image().save_png("res://../evidence/siracusa-" + label + ".png")
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
		var town = map.terrace_dressing.city
		print("seed %d weather %s turfs %s mansions %s landmarks %s buildings %d angled %d fountains %d lanterns %d banners %d" % [map_seed, map.weather, map.districts.map(func(d): return d.kind), map.mansion_rooms, map.landmarks, town.building_count, town.angled_fronts, town.fountain_count, town.lantern_count, town.banner_count])
		await shot(map.main_path[0] + Vector2(0, 8), "%d-entry" % map_seed)
		await shot(map.main_path[map.main_path.size() / 2], "%d-mid" % map_seed)
		await shot(map.main_path[map.main_path.size() / 2], "%d-wide" % map_seed, 60.0)
		await shot(map.main_path[map.main_path.size() / 2], "%d-over" % map_seed, 150.0)
		for room in map.mansion_rooms:
			await shot(map._centre(room), "%d-mansion%d" % [map_seed, room], 32.0)
		for k in range(town.gate_points.size()):
			await shot(town.gate_points[k] - Vector2(0, 2.0), "%d-gate%d" % [map_seed, k], 20.0)
		for l in map.landmarks:
			await shot(map._centre(int(l.room)) - Vector2(0, 4.0), "%d-%s" % [map_seed, l.kind], 40.0)
		for i in range(map._open_circles.size()):
			if map._open_circles[i].z >= 7.0 and not map.is_mansion(i) and map.landmark_of(i).is_empty() and i > 0:
				await shot(map._centre(i) - Vector2(0, 3.0), "%d-piazza" % map_seed, 28.0)
				break
		game.close_modal()
		game.settle(true)
		await step()
	quit()
