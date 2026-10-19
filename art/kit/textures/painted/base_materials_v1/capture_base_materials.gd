extends SceneTree
## Narrow runtime probe for newly delivered base floor textures only.
const OUTPUT := "res://art/kit/textures/painted/base_materials_v1/engine_evidence/"
var game: GameManager
var records: Array = []

func _initialize() -> void:
	call_deferred("run")

func step(n: int) -> void:
	for i in range(n): await process_frame

func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var result := find_game(child)
		if result != null: return result
	return null

func shot(label: String, x: float, z: float) -> void:
	game.player.teleport(game.base_map.to_world(x, z, BaseMap.PLAYER_Y))
	game.camera.global_position = game.camera_target() + GameManager.CAMERA_OFFSET
	await step(20)
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(OUTPUT + label + ".png")
	assert(result == OK)
	print("BASE_MATERIAL_SCREENSHOT ", label)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	for room in ["hall", "medical", "store"]:
		var plate := BaseMap.deck_tile(room)
		var texture: Texture2D = plate[0]
		assert(float(plate[1]) == 6.0)
		assert(texture.get_size() == Vector2(256, 256))
		assert(texture.resource_path.begins_with("res://art/kit/textures/painted/base_deck"))
		records.append({"room": room, "texture": texture.resource_path, "size": [texture.get_width(), texture.get_height()], "metres_per_tile": plate[1]})
	var rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(20)
	game = find_game(rig)
	assert(game != null)
	await shot("hall", 64, -24)
	await shot("warehouse", -20, -26)
	await shot("medical", 150, -22)
	await shot("store", 9, 5)
	await shot("armory", 113, 6)
	var file := FileAccess.open(OUTPUT + "floor_routes.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"status": "PASS", "floor_routes": records, "scope": "Five room screenshots; three direct floor routes only. Base-model material rebaking not performed."}, "\t"))
	file.close()
	rig.queue_free()
	await step(2)
	print("BASE_MATERIAL_FLOOR_PROBE PASS")
	quit()
