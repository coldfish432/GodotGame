extends SceneTree
## Reproducible rendered evidence at the production 640x360 viewport.
var rig: Node
var game: GameManager
var target: Enemy
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
func shot(label: String) -> void:
	# Freeze after real simulation has produced the pose/effect being inspected.
	for child in game.player.get_children():
		if child is PlayerAura: child._process(0)
	game.open_modal("capture")
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://../evidence/lappland-" + label + ".png"
	var result := root.get_texture().get_image().save_png(path)
	if result != OK: failures += 1
	print("CAPTURE " + path)
	game.close_modal()
func clean_fx() -> void:
	for node in game.get_children():
		if node is CombatVfx or node is SwordWave or node is CombatMarker:
			game.remove_child(node)
			node.queue_free()
func run() -> void:
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(10)
	game = find_game(rig)
	game.fixed_map_seed = 1729
	var weapon := Item.create("幼狼之牙演示剑", Item.Category.WEAPON, 2, 1)
	weapon.rarity = 1
	weapon.modifiers = [ItemModifier.trigger_mod(ItemModifier.Trigger.SWORD_WAVE)]
	for region in FieldCatalog.REGIONS:
		await game.start_contract(region)
		game._clear_field()
		await step(2)
		game.player.equip(weapon)
		var origin := ContinuousWorldMap.ENTRY_POSITION
		game.player.teleport(origin)
		game.camera.size = 24
		game.camera.global_position = origin + GameManager.CAMERA_OFFSET
		game._spawn_enemy(origin + Vector3(2, 0, 0), true, false)
		target = game.get_child(game.get_child_count() - 1) as Enemy
		target.health = 10000
		target.set_physics_process(false)
		game.player.set_physics_process(false)
		for i in range(3):
			clean_fx()
			game.player._attack_cooldown = 0
			game.player.hitstop_remaining = 0
			game.player.attack(target)
			game.player.hitstop_remaining = 0
			game.player._sprite._process(1.0 / 12.0)
			if target.elite: game.spawn_warning_area(origin + Vector3(2, 0, 0), 1.25, 1)
			await shot(region + "-combo-" + str(i + 1))
		clean_fx()
		game.player._sprite.cancel_action()
		await step(3)
		await shot(region + "-ready")
		game.player._attack_cooldown = 0
		game.player.hitstop_remaining = 0
		game.player.attack(target)
		game.player.hitstop_remaining = 0
		game.player._sprite._process(1.0 / 12)
		for node in game.get_children():
			if node is SwordWave:
				node.set_physics_process(false)
				node._physics_process(0.28)
		if target.elite: game.spawn_warning_area(origin + Vector3(2, 0, 0), 1.25, 1)
		await shot(region + "-wave")
		clean_fx()
		game.player._dash_cooldown = 0
		game.player._start_dash(Vector3.RIGHT)
		await shot(region + "-dash")
		game.player.set_physics_process(true)
		game.settle(true)
	# Give the audio mixer time to release its last playback before shutdown.
	await create_timer(0.3).timeout
	rig.queue_free()
	await create_timer(0.3).timeout
	print("CAPTURE_LAPPLAND: %d failures" % failures)
	quit(1 if failures else 0)
