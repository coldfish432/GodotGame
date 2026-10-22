extends SceneTree
## 陷阱与踪迹 close up in each region: both trap kinds and a trace laid round
## her, then the traps sprung. ../evidence/traps-<region>-<armed|sprung>.png.
## Env TRAP_REGIONS (mine,city,snow,siracusa), TRAP_CAM (camera size, 9),
## TRAP_TRACE (operator id; default the region's first).
var game: GameManager
func _initialize() -> void: call_deferred("run")
func step(count: int = 8) -> void:
	for i in range(count): await process_frame
func save(label: String) -> void:
	await step(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/traps-" + label + ".png")
func run() -> void:
	game = GameManager.new()
	game.save_enabled = false
	root.add_child(game)
	await step()
	var regions := OS.get_environment("TRAP_REGIONS")
	for region in (regions if regions != "" else "mine,city,snow,siracusa").split(","):
		game.world_map.force_vault = 0
		game.fixed_map_seed = 31337
		await game.start_contract(region)
		await step(6)
		game._hud.visible = false
		for e in game.floor_enemies(): e.global_position += Vector3(300, 0, 300)
		game.player.invulnerable = true
		var at := game.player.global_position
		# Lay one heavy, one light and a trace on open ground round her.
		var heavy: FieldTrap = game.traps[0]
		var light: FieldTrap = game.traps[1]
		heavy.queue_free()
		light.queue_free()
		game.traps.clear()
		var spots := [Vector3(-2.6, 0, 0.6), Vector3(2.4, 0, 0.4), Vector3(0.0, 0, -2.4)]
		var placed: Array[FieldTrap] = []
		for k in range(2):
			var trap := FieldTrap.new()
			trap.setup(game, "heavy" if k == 0 else "light", region)
			game.world_map._generated_root.add_child(trap)
			var p := game.world_map.nearest_walkable(at + spots[k])
			trap.global_position = Vector3(p.x, game.ground_y(p), p.z)
			placed.append(trap)
			game.traps.append(trap)
		if is_instance_valid(game.trace_point): game.trace_point.queue_free()
		var trace_id := OS.get_environment("TRAP_TRACE")
		if trace_id == "": trace_id = RecruitCatalog.in_region(region)[0]
		game.trace_point = TracePoint.new()
		game.trace_point.setup(trace_id, game)
		game.world_map._generated_root.add_child(game.trace_point)
		var tp := game.world_map.nearest_walkable(at + spots[2])
		game.trace_point.global_position = Vector3(tp.x, game.ground_y(tp), tp.z)
		game.camera.size = float(OS.get_environment("TRAP_CAM")) if OS.get_environment("TRAP_CAM") != "" else 9.0
		game.camera_size_goal = game.camera.size
		await step(90)
		await save(region + "-armed")
		for trap in placed: trap.spring(game.player)
		await step(14)
		await save(region + "-warn")
		await step(22)
		await save(region + "-burst")
		await step(120)
		await save(region + "-sprung")
		# The trace close up, stirred by her, then picked up.
		var spot := game.trace_point.global_position
		game.player.teleport(spot + Vector3(1.2, 0, 0.4))
		game.camera.size = 6.0
		game.camera_size_goal = 6.0
		await step(90)
		await save(region + "-trace")
		game.trace_point.collect(game.player)
		await step(10)
		await save(region + "-pick")
		game.player.invulnerable = false
		game.settle(true)
		await step(6)
	quit(0)
