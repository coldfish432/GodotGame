extends SceneTree
## Actual mouse/key events through the production low-resolution viewport.
var rig: Node
var game: GameManager
var failures := 0
var checks: Array[Dictionary] = []
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool) -> void:
	checks.append({"check": label, "passed": passed})
	print(("PASS " if passed else "FAIL ") + label)
	if not passed: failures += 1
func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null
## The window is real, so the desktop cursor passing over it sends its own
## motion events and moves the pointer; re-assert ours every held frame.
func hover(point: Vector3) -> Vector2:
	var screen := game.camera.unproject_position(point) * root.get_visible_rect().size / game.get_viewport().get_visible_rect().size
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	Input.parse_input_event(motion)
	return screen
func mouse(point: Vector3, pressed: bool) -> void:
	var screen := hover(point)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = screen
	event.global_position = screen
	event.pressed = pressed
	Input.parse_input_event(event)
	await step(1)
func run() -> void:
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(10)
	game = find_game(rig)
	game.fixed_map_seed = 1729
	await game.start_contract("mine")
	game._clear_field()
	await step(3)
	var p := game.player
	var origin := p.global_position
	game._spawn_enemy(origin + Vector3(2, 0, 0), true, false)
	var enemy := game.get_child(game.get_child_count() - 1) as Enemy
	enemy.max_health = 1000000
	enemy.health = 1000000
	enemy.set_physics_process(false)
	var item := Item.create("输入测试剑", Item.Category.WEAPON, 2, 1)
	item.modifiers = [ItemModifier.trigger_mod(ItemModifier.Trigger.SWORD_WAVE)]
	p.equip(item)
	await step(3)
	await mouse(enemy.global_position, true)
	var poses: Dictionary = {}
	var saw_wave := false
	var saw_ready := false
	for i in range(150):
		poses[p._sprite.action_name] = true
		if p.sword_charge == 3: saw_ready = true
		for node in game.get_children():
			if node is SwordWave: saw_wave = true
		hover(enemy.global_position)
		await step()
	print("INPUT STATE ", {"poses": poses, "charge": p.sword_charge, "hp": enemy.health, "ready": saw_ready, "wave": saw_wave, "cooldown": p._attack_cooldown})
	await mouse(enemy.global_position, false)
	check("held mouse attacks through all three poses", poses.has("attack_1") and poses.has("attack_2") and poses.has("attack_3"))
	check("real-time held attack readies then releases wave", saw_ready and saw_wave and poses.has("wave"))
	check("actual melee and wave damage reach target", enemy.health <= 1000000 - 4 * CombatStats.physical(600.0, enemy.defense))
	await step(30)
	var charges := p.sword_charge
	var hp := enemy.health
	await mouse(origin + Vector3(0, 0, -2), true)
	await step(3)
	await mouse(origin + Vector3(0, 0, -2), false)
	check("ground click swings without moving or charging", not p._has_move_target and p.sword_charge == charges and enemy.health == hp)
	await step(30)
	Input.action_press("dash")
	await step(2)
	Input.action_release("dash")
	check("Shift action produces invulnerable dash pose", p.invulnerable and p._sprite.action_name == "dash")
	await step(20)
	check("dash ends and locomotion resumes", not p.invulnerable and p._sprite.action_name != "dash")
	check("removed controls are absent", not InputMap.has_action("switch_weapon") and not InputMap.has_action("weapon_skill"))
	var file := FileAccess.open("res://../evidence/lappland-input-tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures}, "  "))
	file.close()
	print("LAPPLAND_INPUT: %d checks / %d failures" % [checks.size(), failures])
	await create_timer(0.3).timeout
	rig.queue_free()
	await create_timer(0.3).timeout
	quit(1 if failures else 0)
