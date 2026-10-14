extends SceneTree
## The encounter set pieces in the field (NPC_brief_v3.md Part C): the
## squad's post and 坎诺特's stall, from the follow camera, in the mine and
## the snow. Writes evidence/encounter-<region>-<kind>.png. Not part of run_all.
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
	for region in ["mine", "snow"]:
		await game.start_contract(region)
		game._clear_field()
		var map: ContinuousWorldMap = game.world_map
		for kind in ["squad", "trader"]:
			if is_instance_valid(map.encounter_node): map.encounter_node.queue_free()
			map.encounter_kind = kind
			map.encounter_node = map._set_piece("坎诺特 · E" if kind == "trader" else "罗德岛小队 · E", map.encounter_position,
				Color("e6c25a") if kind == "trader" else Color("5fd0d8"), ContinuousWorldMap.ENCOUNTER_MODELS[kind], kind)
			var at: Vector3 = map.encounter_node.global_position
			game.player.teleport(map.nearest_walkable(at + Vector3(0, 0, 2.2)))
			game.camera.global_position = game.player.global_position + GameManager.CAMERA_OFFSET
			game.fog.reveal(at)
			await step(8)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://../evidence/encounter-%s-%s.png" % [region, kind])
	quit()
