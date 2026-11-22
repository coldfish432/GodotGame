extends SceneTree
## Windowed capture (剑气骨骼移植策划案 §4, facing): a release at an enemy on
## Lappland's screen LEFT, then one on her screen RIGHT; saves the frames at
## the click, design frame 3 (startup), 6 (the wave leaves) and 12 (recovery)
## to evidence/wave_facing/. Real input (Input.parse_input_event).
##   godot --path . --script res://tests/capture_wave_facing.gd   (needs a window)
var game: GameManager
func find_game(n: Node) -> GameManager:
	if n is GameManager: return n
	for c in n.get_children():
		var f := find_game(c)
		if f != null: return f
	return null
func click(point: Vector3, pressed: bool) -> void:
	var screen := game.camera.unproject_position(point) * root.get_visible_rect().size / game.get_viewport().get_visible_rect().size
	for e in [InputEventMouseMotion.new(), InputEventMouseButton.new()]:
		e.position = screen; e.global_position = screen
		if e is InputEventMouseButton:
			e.button_index = MOUSE_BUTTON_LEFT; e.pressed = pressed
			e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		Input.parse_input_event(e)
		root.push_input(e, true)
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://evidence/wave_facing/%s.png" % name))
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var main: Node = load("res://game/main.tscn").instantiate()
	main.persist_sessions = false
	root.add_child(main)
	for i in 10: await process_frame
	game = find_game(main)
	game.fixed_map_seed = 1729
	game.seed_rng(1729)
	await game.start_contract("mine")
	game._clear_field()
	for i in 3: await process_frame
	var p := game.player
	p.set_operator("lappland")
	game.zoom_camera(-3)
	var origin := p.global_position
	var right := game.camera.global_basis.x
	right.y = 0
	right = right.normalized()
	for side in ["left", "right"]:
		var at := origin + right * (2.0 if side == "right" else -2.0)
		var e := game._spawn_enemy(at, false, false)
		e.global_position = at
		e.max_health = 1e8; e.health = 1e8
		e.set_physics_process(false)
		for i in 30: await physics_frame
		p._attack_cooldown = 0.0
		p.sword_charge = p.wave_hits_needed()
		click(e.global_position, true)
		await physics_frame
		click(e.global_position, false)
		var taken := {}
		for i in 120:
			await process_frame
			var f := p.wave_frame if p.wave_state != Player.WaveState.READY else -1
			for want in [0, 3, 6, 12]:
				if f == want and not taken.has(want) and p.wave_state != Player.WaveState.READY:
					taken[want] = true
					await shot("%s_f%02d" % [side, want])
			if p.wave_state == Player.WaveState.READY and taken.size() > 0: break
		print("%s: shots %s rig scale.x %s" % [side, taken.keys(), p._wave_rig_root.scale.x])
		e.queue_free()
		for i in 60: await physics_frame
	quit(0)
