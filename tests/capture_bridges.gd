extends SceneTree
## Rock bridges under the normal follow camera, HUD hidden: Lappland on a deck,
## on the road beneath it just past the arch, and a wider view of the crossing.
## Written to ../evidence/bridge-<region>-<seed>-<shot>.png; CAPTURE_REGIONS
## (comma list, default all four, 立交桥修订案 v0.1) picks the regions.
var rig: Node
var game: GameManager
const WANTED := 2

func _initialize() -> void: call_deferred("run")

func step(count: int = 8) -> void:
	for i in range(count): await process_frame

func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null

func shot(at: Vector3, label: String, size: float = 24.0) -> void:
	game.player.teleport(at)
	game.camera.size = size
	game.camera.global_position = game.player.global_position + GameManager.CAMERA_OFFSET * (size / 24.0)
	await step()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/bridge-" + label + ".png")

func run() -> void:
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step()
	game = find_game(rig)
	var regions := OS.get_environment("CAPTURE_REGIONS").split(",") if OS.get_environment("CAPTURE_REGIONS") != "" else PackedStringArray(["snow", "city", "mine", "siracusa"])
	for region in regions:
		await capture_region(region)
	rig.queue_free()
	await create_timer(0.4).timeout
	quit()

func capture_region(region: String) -> void:
	var taken := 0
	var map_seed := 1000
	while taken < WANTED and map_seed < 1040:
		map_seed += 1
		game.fixed_map_seed = map_seed
		await game.start_contract(region)
		var map := game.world_map
		if not map.bridges.is_empty():
			game.open_modal("capture")
			game._hud.hide()
			var bridge: Dictionary = map.bridges[0]
			var centre: Vector2 = bridge.centre
			var under: Vector2 = bridge.under
			var top: float = bridge.top
			await shot(Vector3(centre.x, top + 0.7, centre.y), "%s-%d-deck" % [region, map_seed])
			# On the road below, just north of the arch (the camera looks north).
			var below := centre + under * (signf(under.y) if absf(under.y) > 0.01 else 1.0) * 5.0
			await shot(Vector3(below.x, float(bridge.base) + 0.7, below.y), "%s-%d-under" % [region, map_seed])
			await shot(Vector3(centre.x, top + 0.7, centre.y), "%s-%d-wide" % [region, map_seed], 46.0)
			game._hud.show()
			game.close_modal()
			taken += 1
		game.settle(true)
	print("bridge captures %s: %d (last seed %d)" % [region, taken, map_seed])
