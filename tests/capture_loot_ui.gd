extends SceneTree
## A point of interest from the follow camera: its yellow rim with Lappland
## beside it, then the pack and the box's grid a few seconds into the search.
## ../evidence/loot-ui-rim.png, ../evidence/loot-ui-window.png.
var rig: Node
var game: GameManager
func _initialize() -> void: call_deferred("run")
func step(count: int = 8) -> void:
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
	await step()
	game = find_game(rig)
	game.fixed_map_seed = 2026
	await game.start_contract("mine")
	game.player.invulnerable = true
	var box: LootContainer = null
	for node in get_nodes_in_group("loot_containers"):
		if node.game == game and not node.sealed and node.kind in ["weapon_box", "tool_box", "construction", "armor_box"]:
			box = node
			break
	game.player.teleport(game.world_map.nearest_walkable(box.global_position + Vector3(-1.6, 0.7, 0.6)))
	game.camera.global_position = game.player.global_position + GameManager.CAMERA_OFFSET
	await step(20)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/loot-ui-rim.png")
	game._interact()
	await create_timer(3.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/loot-ui-window.png")
	print("box %s looting %s found %s" % [box.kind, game.looting == box, box.search_state()])
	rig.queue_free()
	await create_timer(0.4).timeout
	quit()
