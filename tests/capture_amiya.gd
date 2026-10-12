extends SceneTree
## Rendered evidence for Amiya (Guard) at the production viewport: departure
## tabs, idle, the three combo stages, the shadow strike and its finisher.
var rig: Node
var game: GameManager
var failures := 0
func _initialize() -> void: call_deferred("run")
func step(count: int = 3) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null
func save(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://../evidence/amiya-" + label + ".png"
	if root.get_texture().get_image().save_png(path) != OK: failures += 1
	print("CAPTURE " + path)
func shot(label: String) -> void:
	for child in game.player.get_children():
		if child is PlayerAura: child._process(0)
	game.open_modal("capture")
	await save(label)
	game.close_modal()
func clean_fx() -> void:
	for node in game.get_children():
		if node is CombatVfx or node is CombatMarker:
			game.remove_child(node)
			node.queue_free()
func run() -> void:
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(10)
	game = find_game(rig)
	game.fixed_map_seed = 1729
	game.choose_operator(Operators.AMIYA_GUARD)
	game.menu.show_departure("mine")
	await step(3)
	await save("departure")
	game.close_modal()
	# Every region: the snow field is the hardest backdrop for cyan (§七).
	for region in FieldCatalog.REGIONS:
		await game.start_contract(region)
		game._clear_field()
		await step(2)
		var p := game.player
		var origin := ContinuousWorldMap.ENTRY_POSITION
		p.teleport(origin)
		game.camera.size = 24
		game.camera.global_position = origin + GameManager.CAMERA_OFFSET
		var enemies: Array[Enemy] = []
		for offset in [Vector3(2, 0, 0), Vector3(3.5, 0, 1.5), Vector3(3.5, 0, -1.5)]:
			game._spawn_enemy(origin + offset, false, false)
			var e := game.get_child(game.get_child_count() - 1) as Enemy
			e.global_position = origin + offset
			e.max_health = 100000
			e.health = 100000
			e.set_physics_process(false)
			enemies.append(e)
		p.set_physics_process(false)
		await step(4)
		await shot(region + "-" + "idle")
		for i in range(3):
			clean_fx()
			p._attack_cooldown = 0
			p.hitstop_remaining = 0
			p.attack(enemies[0])
			p.hitstop_remaining = 0
			p._sprite._process(1.0 / 12.0)
			await shot(region + "-" + "combo-" + str(i + 1))
		clean_fx()
		p._sprite.cancel_action()
		p.shadow_cooldown = 0.0
		await step(3)
		await shot(region + "-" + "ready")
		# 绝影 cast on the nearest of the three: bounces across all of them.
		p.cast_shadow(enemies[0].global_position)
		p._tick_amiya(0.17)
		p._sprite._process(1.0 / 12.0)
		await shot(region + "-" + "shadow-flurry")
		p._tick_amiya(0.2)
		p._sprite._process(1.0 / 12.0)
		await shot(region + "-" + "shadow-finisher")
		p.set_physics_process(true)
		game.settle(true)
		await step(5)
	# Give the audio mixer time to release its last playback before shutdown.
	await create_timer(0.3).timeout
	rig.queue_free()
	await create_timer(0.3).timeout
	print("CAPTURE_AMIYA: %d failures" % failures)
	quit(1 if failures > 0 else 0)
