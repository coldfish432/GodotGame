extends SceneTree
## Real rendered frames at the production 640x360 viewport. No save writes.
var rig: Node
var game: GameManager
var failures := 0
func _initialize() -> void: call_deferred("run")
func step(n: int = 2) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null
func shot(label: String) -> void:
	game.open_modal("capture")
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://../evidence/enemy-" + label + ".png")
	if result != OK: failures += 1
	if label.ends_with("-glint"):
		var before := root.get_texture().get_image()
		var lights: Array[MeshInstance3D] = []
		for actor in get_nodes_in_group("enemies"):
			if actor._glint.visible:
				lights.append(actor._glint)
				actor._glint.visible = false
		await process_frame
		await RenderingServer.frame_post_draw
		var after := root.get_texture().get_image()
		var changed := 0
		for y in range(before.get_height()):
			for x in range(before.get_width()):
				if before.get_pixel(x, y) != after.get_pixel(x, y): changed += 1
		for light in lights: light.visible = true
		if changed < lights.size() * 4: failures += 1
		print("RENDERED GLINT " + label + ": %d changed display pixels for %d lights" % [changed, lights.size()])
	print("CAPTURE enemy-" + label)
	game.close_modal()
func clear_fx() -> void:
	for node in game.get_children():
		if node is EnemyProjectile or node is EnemyAttackVfx:
			game.remove_child(node)
			node.queue_free()
func run() -> void:
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(10)
	game = find_game(rig)
	game.fixed_map_seed = 1729
	for region in ["mine", "city", "snow"]:
		await game.start_contract(region)
		game._clear_field()
		await step()
		var origin := ContinuousWorldMap.ENTRY_POSITION
		game.player.teleport(origin)
		game.player.set_physics_process(false)
		game.player.invulnerable = true
		game.camera.global_position = origin + GameManager.CAMERA_OFFSET
		game.set_process(false)
		var types: Array = {"mine": ["thug", "crossbow", "slug"], "city": ["brawler", "crossbow_leader"], "snow": ["ice_warrior", "ice_hunter"]}[region]
		var actors: Array[Enemy] = []
		for index in range(types.size()):
			var actor := game._spawn_enemy(origin + Vector3(-4 + index * 4, 0, -3), false, false, types[index])
			actor.set_physics_process(false)
			actor.begin_chase()
			actors.append(actor)
		game.set_message("敌人动作验证：待机 → 起手 → 蓄力 → 出手 → 收招")
		await shot(region + "-idle")
		for actor in actors: actor._begin_telegraphed_attack()
		await shot(region + "-startup")
		for actor in actors: actor._tick_attack(0.2)
		await shot(region + "-charge")
		for actor in actors: actor._tick_attack(float(actor.attack_profile.windup) - 0.25)
		await shot(region + "-glint")
		for actor in actors: actor._tick_attack(0.051)
		# Keep the actual released projectile visible in the captured frame.
		for node in game.get_children():
			if node is EnemyProjectile:
				node.set_physics_process(false)
				node._physics_process(0.06)
			if node is EnemyAttackVfx: node.set_process(false)
		await shot(region + "-release")
		for actor in actors: actor._tick_attack(0.05)
		await shot(region + "-lunge")
		for actor in actors: actor._tick_attack(0.051)
		clear_fx()
		await shot(region + "-recovery")
		for actor in actors: actor._tick_attack(0.36)
		await shot(region + "-idle-return")
		# A second camera shows sprite silhouettes and weapon attachment clearly.
		game.camera.size = 12
		for actor in actors:
			actor._begin_telegraphed_attack()
			actor._tick_attack(0.2)
		await shot(region + "-detail")
		if region == "snow":
			actors[1]._tick_attack(0.5)
			await shot("hunter-lock")
		game.player.teleport(origin + Vector3(6, 0, -3))
		for actor in actors:
			actor._cancel_attack()
			actor._begin_telegraphed_attack()
			actor._tick_attack(0.2)
		await shot(region + "-side-aim")
		game.camera.size = 24
		game.set_process(true)
		game.settle(true)
	await create_timer(0.3).timeout
	rig.queue_free()
	await create_timer(0.3).timeout
	print("CAPTURE_ENEMY_ATTACKS: %d failures" % failures)
	quit(1 if failures else 0)
