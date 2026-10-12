extends SceneTree
## Screenshot of the shared barrier shell (BarrierFx) on 灰尾, 灰尾香主 and on
## Lappland's own shield. Writes evidence/barrier-shell.png. Not in run_all.
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
	game.save_enabled = false
	await game.start_contract("city")
	var stage: Vector3 = game.world_map.try_sample_navigation_position(game.world_map.buff_position, 25.0)
	stage.y = 0.7
	game.player.teleport(stage)
	game._clear_field()
	var x := -4.5
	# Intact and cracked on each (用户 2026-10-11: 加一个有裂纹的屏障).
	for type in ["greytail", "greytail", "greytail_lord", "greytail_lord"]:
		var e := game._spawn_enemy(stage + Vector3(x, 0, -1.5), EnemyAttacks.is_elite_type(type), false, type)
		e.set_physics_process(false)
		if x > -4.0 and int(x + 4.5) % 6 == 3: e.barrier_hp *= 0.4
		e._sync_shell()
		x += 3.0
	game.player.shield = 500.0
	game.camera.size = 8.0
	game.camera.global_position = game.player.global_position + GameManager.CAMERA_OFFSET
	await step(20)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/barrier-shell.png")
	quit(0)
