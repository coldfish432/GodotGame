extends SceneTree
## The squad's random triangle (用户 2026-10-13) at four encounter spots:
## evidence/squad-triangle-<n>.png. Not part of run_all.
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
func run() -> void:
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(15)
	game = find_game(rig)
	await game.start_contract("mine")
	game._clear_field()
	var map: ContinuousWorldMap = game.world_map
	game.encounter = "squad"
	game.encounter_used = false
	var base := map.encounter_position
	for n in range(4):
		if is_instance_valid(map.encounter_node): map.encounter_node.queue_free()
		# Small moves of the spot reseed the triangle.
		var at := base + Vector3(0.37 * n, 0, 0)
		map.encounter_node = map._set_piece("罗德岛小队 · E", at, Color("5fd0d8"), ContinuousWorldMap.ENCOUNTER_MODELS.squad, "squad")
		game.player.teleport(map.nearest_walkable(at + Vector3(0, 0, 2.6)))
		game.camera.global_position = map.encounter_node.global_position + GameManager.CAMERA_OFFSET
		game.fog.reveal(at)
		await step(8)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../evidence/squad-triangle-%d.png" % n)
	quit()
