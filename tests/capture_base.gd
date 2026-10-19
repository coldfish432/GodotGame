extends SceneTree
## Engine screenshots of the walkable Rhodes Island base (evidence/rhodes-engine/).
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
func shot(label: String, x: float, z: float) -> void:
	game.player.teleport(game.base_map.to_world(x, z, BaseMap.PLAYER_Y))
	game.camera.global_position = game.camera_target() + GameManager.CAMERA_OFFSET
	await step(12)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/rhodes-engine/base-" + label + ".png")
func run() -> void:
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(15)
	game = find_game(rig)
	await shot("arrival", 64, -53)
	await shot("workshop-room", -22, -2)
	await shot("workshop-door", 4, -6)
	await shot("exchange", 25.5, -13)
	await shot("lounge", 20, -41)
	await shot("dais", 64, -16)
	await shot("loadout", 78, -9)
	await shot("personnel", 113, 4)
	await shot("directory", 64, -33)
	await shot("behind-wall", 7.5, 1.4)
	await shot("behind-partition", 147.0, -2.0)
	await shot("center", 64, -24)
	await shot("lift", 64, -14)
	await shot("logistics", 101.3, -16)
	await shot("duty-desks", 29, -16)
	await shot("north-wall", 64, -3)
	await shot("sand-table", 64, -42)
	await shot("logo", 64, -40)
	await shot("logistics-bay", 104, -10)
	await shot("briefing", 106, -40)
	await shot("intel-wall", 26, -6)
	await shot("south", 64, -44)
	await shot("west-door", 3, -26)
	await shot("warehouse", -20, -26)
	# Stand in the warehouse until its lights are on and the racks have risen.
	game.player.teleport(game.base_map.to_world(-30, -27, BaseMap.PLAYER_Y))
	for i in range(8): await create_timer(1.0).timeout
	await shot("warehouse-racks", -40, -27)
	await shot("warehouse-west", -55, -27)
	await shot("medical", 150, -22)
	await shot("medical-corridor", 136, -10)
	await shot("medical-wards", 158, -1)
	await shot("medical-treatment", 158, -15)
	await shot("medical-lobby-south", 136, -28)
	await shot("medical-south-wards", 158, -31)
	await shot("store", 9, 5)
	await shot("armory", 113, 6)
	rig.queue_free()
	await create_timer(0.3).timeout
	quit()
