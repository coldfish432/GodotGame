extends SceneTree
## Boss与守卫者策划案 §11: the eight on their own boards, in their own regions,
## next to Lappland: idle, then mid-move. Writes ../evidence/bosses-<id>-*.png.
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
	root.get_texture().get_image().save_png("res://../evidence/bosses-" + label + ".png")

func run() -> void:
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(5)
	game = find_game(rig)
	game.fixed_map_seed = 1729
	for region in ["mine", "city", "snow", "siracusa"]:
		for floor in [10, 20]:
			if not game.in_base:
				game.settle(true)
				await step(2)
			await game.start_contract(region)
			game.floor_number = floor - 1
			await game.advance(0)
			await step(4)
			game.player.invulnerable = true
			var figure := game.outpost_boss
			var at := figure.global_position
			game.player.teleport(game.world_map.nearest_walkable(at + Vector3(3.0, 0, 1.5)) + Vector3.UP * 0.7)
			game.camera.size = 14
			game.camera.global_position = at + Vector3(1.5, 0, 0.8) + GameManager.CAMERA_OFFSET
			game.set_process(false)
			await step(4)
			await capture("%s-1-idle" % figure.figure_id)
			var moves := BossCatalog.moves_for(figure.figure_id, figure.tier, 1).filter(func(m): return str(m.shape) not in ["family", "sandstorm", "backstep", "summon"])
			figure._engage()
			figure._start(moves[mini(1, moves.size() - 1)])
			await step(int(float(moves[mini(1, moves.size() - 1)].get("windup", 1.0)) * 40))
			await capture("%s-2-move" % figure.figure_id)
			game.set_process(true)
	rig.queue_free()
	await create_timer(0.4).timeout
	quit()
