extends SceneTree
## Screenshots of the v1.2 ground warnings (新敌人攻击动画与预警设计案): see-through
## red with rings spreading from the middle as the countdown, lanes counting
## from their near end, the white edge and body ring of an unstoppable attack.
## Writes evidence/warnings-<progress>.png at three points of the countdown. Not in run_all.
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
	game.player.set_physics_process(false)
	var enemies: Array[Enemy] = []
	for spot in [["bully", Vector3(-4.5, 0, 0)], ["breacher", Vector3(3.0, 0, -2.5)], ["avenger", Vector3(2.5, 0, 2.0)]]:
		var e := game._spawn_enemy(stage + spot[1], true, false, spot[0])
		e.set_physics_process(false)
		e.begin_chase()
		if spot[0] == "breacher": e._attack_count = 2
		enemies.append(e)
	var markers: Array = []
	for e in enemies:
		e._begin_telegraphed_attack()
		markers.append_array(e._warning_markers)
	# A plain one too, next to her, to see the fight through it.
	var plain := game.spawn_warning_area(stage + Vector3(-1.0, 0, 3.0), 1.6, 1.0)
	markers.append(plain)
	game.camera.size = 12.0
	game.camera.global_position = stage + GameManager.CAMERA_OFFSET
	for progress in [0.15, 0.5, 0.85]:
		for marker in markers:
			if not is_instance_valid(marker): continue
			marker.set_process(false)
			marker.life = marker.total * (1.0 - progress)
			(marker.material_override as ShaderMaterial).set_shader_parameter("progress", progress)
		for e in enemies: e._update_attack_visual()
		await step(6)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../evidence/warnings-%d.png" % int(progress * 100))
	quit(0)
