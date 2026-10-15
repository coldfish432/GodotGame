extends SceneTree
## 威胁值: the bar under the top strip, a patrol on the minimap, a sentinel's alarm.
var rig: Node
var game: GameManager
func _initialize() -> void: call_deferred("run")
func step(count: int = 1) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/threat-" + label + ".png")
func run() -> void:
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(5)
	game = find_game(rig)
	game.fixed_map_seed = 1729
	await game.start_contract("mine")
	game.player.invulnerable = true
	await step(10)
	game.threat.value = 60.0
	await step(4)
	await capture("01-bar")
	game.threat.value = ThreatMeter.FULL - 0.01
	await step(2)
	game.threat.value = 92.0
	# Map what lies around the patrol so its dots show.
	for e in get_nodes_in_group("patrols"): game.fog.reveal(e.global_position)
	await step(4)
	await capture("02-patrol")
	while get_nodes_in_group("sentinels").is_empty(): game._spawn_sentinels()
	var sentinel: Enemy = get_nodes_in_group("sentinels")[0]
	game.player.teleport(game.world_map.nearest_walkable(sentinel.global_position + Vector3(3, 0, 0)) + Vector3.UP * 0.7)
	await step(15)
	await capture("03-alarm")
	game.camera.size = 10
	await capture("05-startle")
	for i in range(900):
		await step()
		if sentinel.sentinel_mode == "hold": break
	game.player.teleport(game.world_map.nearest_walkable(sentinel.global_position + Vector3(2.5, 0, 1.5)) + Vector3.UP * 0.7)
	await step(30)
	await capture("06-hold")
	game.camera.size = 24
	game._random_extraction_available = true
	game.world_map.exit_node.visible = true
	var holder := Node3D.new()
	game.world_map._generated_root.add_child(holder)
	game.world_map.terrace_dressing._place_extraction(holder)
	game.world_map.terrace_dressing.add_lamps([])
	game.player.teleport(game.world_map.nearest_walkable(game.world_map.exit_node.global_position) + Vector3.UP * 0.7)
	await step(150)
	await capture("04-extract")
	rig.queue_free()
	await create_timer(0.4).timeout
	quit()
