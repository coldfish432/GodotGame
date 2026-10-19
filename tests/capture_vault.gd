extends SceneTree
## 密室与陷阱修订案 §2.1: a sealed vault's 暗墙 and cover in each region, then
## the same spot once the wall is broken. ../evidence/vault-<region>-<sealed|open>.png.
var game: GameManager
func _initialize() -> void: call_deferred("run")
func step(count: int = 8) -> void:
	for i in range(count): await process_frame
func save(label: String) -> void:
	await step(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/vault-" + label + ".png")
func run() -> void:
	game = GameManager.new()
	game.save_enabled = false
	root.add_child(game)
	await step()
	for region in (OS.get_environment("VAULT_REGIONS") if OS.get_environment("VAULT_REGIONS") != "" else "mine,city,snow,siracusa").split(","):
		game.world_map.force_vault = int(OS.get_environment("VAULT_FORCE")) if OS.get_environment("VAULT_FORCE") != "" else 1
		game.fixed_map_seed = 31337
		game.force_trace = true
		await game.start_contract(region)
		await step(6)
		var map := game.world_map
		var mouth: Vector2 = map.vault_mouth
		var inward: Vector2 = map.vault_inward
		# VAULT_AT "x,z,ix,iz": the same spot on the same floor without its vault.
		if not map.has_vault and OS.get_environment("VAULT_AT") != "":
			var at := OS.get_environment("VAULT_AT").split(",")
			mouth = Vector2(float(at[0]), float(at[1]))
			inward = Vector2(float(at[2]), float(at[3]))
		print("VAULT_AT=%f,%f,%f,%f" % [mouth.x, mouth.y, inward.x, inward.y])
		var stand := Vector3(mouth.x, 0, mouth.y) - Vector3(inward.x, 0, inward.y) * 4.5 + Vector3(-inward.y, 0, inward.x) * 2.0
		game.player.teleport(map.nearest_walkable(stand))
		game.camera.size = float(OS.get_environment("CAM")) if OS.get_environment("CAM") != "" else 16.0
		game.camera.global_position = game.player.global_position + Vector3(inward.x, 0, inward.y) * 6.0 + GameManager.CAMERA_OFFSET * (16.0 / 24.0)
		game._hud.visible = false
		for e in game.floor_enemies(): e.global_position += Vector3(300, 0, 300)
		await save(region + "-sealed")
		game.camera.size = 10.0
		game.player.invulnerable = true
		if not game.traps.is_empty():
			game.player.teleport(game.traps[game.traps.size() - 1].global_position + Vector3(2.5, 0, 0))
			await save(region + "-trap")
		if is_instance_valid(game.trace_point) and OS.get_environment("TRACE_IDS") != "":
			var spot := game.trace_point.global_position
			for id in OS.get_environment("TRACE_IDS").split(","):
				game.trace_point.queue_free()
				game.trace_point = TracePoint.new()
				game.trace_point.setup(id, game)
				game.world_map._generated_root.add_child(game.trace_point)
				game.trace_point.global_position = spot
				game.player.teleport(spot + Vector3(2.0, 0, 0))
				await step(60)
				await save(region + "-trace-" + id)
		elif is_instance_valid(game.trace_point):
			game.player.teleport(game.trace_point.global_position + Vector3(2.0, 0, 0))
			await step(60)
			print("TRACE ", game.trace_point.operator, " at ", game.trace_point.global_position, " player ", game.player.global_position, " motes ", game.trace_point._motes.emitting, " children ", game.trace_point.get_children())
			await save(region + "-trace")
		game.player.invulnerable = false
		game.player.teleport(map.nearest_walkable(stand))
		game.camera.size = float(OS.get_environment("CAM")) if OS.get_environment("CAM") != "" else 16.0
		game.camera.global_position = game.player.global_position + Vector3(inward.x, 0, inward.y) * 6.0 + GameManager.CAMERA_OFFSET * (16.0 / 24.0)
		var front := Vector3(mouth.x, 0, mouth.y) - Vector3(inward.x, 0, inward.y) * 1.2
		for i in range(VaultSeal.HITS): game.strike_vault_wall(front, Vector3(inward.x, 0, inward.y))
		await step(6)
		print(region, " opened=", game.vault_opened, " mouth=", mouth)
		await save(region + "-open")
		for e in game.floor_enemies(): e.global_position += Vector3(300, 0, 300)
		game.player.teleport(map.vault_position + Vector3(0, 0, 3.0))
		game.camera.size = 22.0
		await step(10)
		await save(region + "-room")
		# The field's other modelled pieces: the device, a route marker, a
		# heal ampoule and (Lungmen) a depot.
		game.camera.size = 10.0
		if is_instance_valid(map.buff_device_node):
			game.player.teleport(map.buff_device_node.global_position + Vector3(2.0, 0, 1.5))
			await step(10)
			await save(region + "-device")
		if not map.route_nodes.is_empty():
			game.player.teleport(map.route_nodes[1].global_position + Vector3(2.0, 0, 1.5))
			await step(10)
			await save(region + "-route")
		var orb := HealOrb.new()
		orb.game = game
		game.add_child(orb)
		orb.global_position = game.player.global_position + Vector3(1.2, 0, 0)
		await step(30)
		await save(region + "-orb")
		for box in game.get_tree().get_nodes_in_group("loot_containers"):
			if box.kind == "depot":
				game.player.teleport(box.global_position + Vector3(2.0, 0, 1.5))
				await step(10)
				await save(region + "-depot")
				break
		game._hud.show()
		game.settle(false)
		await step(4)
	quit()
