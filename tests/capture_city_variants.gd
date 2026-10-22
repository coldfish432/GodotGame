extends SceneTree
## 龙门城区与叙拉古地图改造案 v1.1 C5: the same Lungmen floor as 上城 and as 下城
## from the same spots, and Siracusa at dusk (its bell tower, arches, string
## lights), HUD hidden. ../evidence/variant-<label>.png.
var rig: Node
var game: GameManager
const CITY_SEED := 2026
const SIRACUSA_SEEDS := [2026, 3141]
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
	root.get_texture().get_image().save_png("res://../evidence/variant-" + label + ".png")
## The 上城 load card's source (art/ui/key/load_city_upper.png): the street
## with every overlay hidden.
func card_shot(at: Vector2) -> void:
	var layers: Array[CanvasLayer] = []
	for node in root.find_children("*", "CanvasLayer", true, false):
		# Not the one the world is drawn through.
		if node.find_children("*", "SubViewportContainer", true, false).size() > 0 or node.find_children("*", "SubViewport", true, false).size() > 0: continue
		if (node as CanvasLayer).visible:
			layers.append(node)
			(node as CanvasLayer).visible = false
	game.player.teleport(game.world_map.nearest_walkable(Vector3(at.x, 0.7, at.y)))
	game.camera.size = 40.0
	game.camera.global_position = game.player.global_position + GameManager.CAMERA_OFFSET * (40.0 / 24.0)
	await step(10)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/variant-card-upper.png")
	for layer in layers: layer.visible = true
func run() -> void:
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step()
	game = find_game(rig)
	var spots: Array[Vector2] = []
	for variant in ["lower", "upper"]:
		ContinuousWorldMap.force_city_variant = variant
		game.fixed_map_seed = CITY_SEED
		await game.start_contract("city")
		game.open_modal("capture")
		var map := game.world_map
		var city: CityDressing = map.terrace_dressing.city
		print("%s place=%s light=%s fronts %d buildings %d street lamps %d neon %d windows %d lanterns %d laundry %d skybridges %d" % [variant, game.place_name(), FieldLight.key(map), city.frontage_count, city.building_count, city.street_lamp_count, city.neon_count, city.window_light_count, city.red_lantern_count, city.laundry_count, city.skybridge_count])
		# The lower city first: its 牌楼连廊 are shot again in the upper city.
		if variant == "lower":
			spots = [map.main_path[0] + Vector2(0, 8), map.main_path[map.main_path.size() / 2]]
			for p in city.skybridge_points: spots.append(p - Vector2(0, 2.0))
		for k in range(spots.size()):
			await shot(spots[k], "city-%s-%d" % [variant, k])
		await shot(spots[1], "city-%s-wide" % variant, 48.0)
		if variant == "upper": await card_shot(spots[1])
		game._hud.visible = true
		game.close_modal()
		game.settle(true)
	ContinuousWorldMap.force_city_variant = ""
	for map_seed in SIRACUSA_SEEDS:
		game.fixed_map_seed = map_seed
		await game.start_contract("siracusa")
		game.open_modal("capture")
		var map := game.world_map
		var sira: SiracusaDressing = map.terrace_dressing.city
		print("siracusa %d weather %s tower %d arches %d strings %d bulbs %d lines %d" % [map_seed, map.weather, sira.bell_tower_count, sira.arch_count, sira.string_count, sira.bulb_count, sira.line_count])
		await shot(map.main_path[0] + Vector2(0, 8), "sira-%d-entry" % map_seed)
		if sira.bell_tower_count > 0: await shot(sira.bell_tower_point - Vector2(0, 10.0), "sira-%d-tower" % map_seed, 30.0)
		for k in range(sira.arch_points.size()): await shot(sira.arch_points[k], "sira-%d-arch%d" % [map_seed, k], 30.0)
		await shot(map.main_path[map.main_path.size() / 2], "sira-%d-mid" % map_seed)
		game._hud.visible = true
		game.close_modal()
		game.settle(true)
	rig.queue_free()
	await create_timer(0.4).timeout
	quit()
