extends SceneTree

## Not a test — a real-time verification clip of Guard Amiya. Everything goes
## through real input: the departure tab and the start button are clicked, each
## enemy is locked with a left click, Space casts 绝影, Shift dodges. Enemies chase and swing.
##   1. departure screen: pick 阿米娅·剑兔, start the operation;
##   2. one enemy from each side in turn (all five authored rows plus mirrors),
##      the three-stage combo;
##   3. a pack in front: Space casts 绝影 (剑圣 Q style), four strikes bouncing
##      across it;
##   4. a Shift dodge.
## Run with Movie Maker (needs a real renderer, so no --headless):
##   godot --path downfall-godot --script res://tests/record_amiya.gd
##        --rendering-method gl_compatibility --audio-driver Dummy
##        --resolution 1280x720 --fixed-fps 30 --write-movie <clip>.avi -- <region>
## Region is mine, city or snow (default mine); only mine shows the departure.

const SIDES := [Vector3(0, 0, 2.6), Vector3(-2.6, 0, 0), Vector3(0, 0, -2.6), Vector3(2.6, 0, 0)]
const FRAMES_PER_SIDE := 120  # 4 s at 30 fps

var rig: Node
var game: GameManager
var _first_frame := -1

## Movie frame index of a phase boundary, for cutting the clip (field phases
## are cropped and zoomed; menus stay full frame).
func mark(phase: String) -> void:
	print("PHASE %s %d" % [phase, Engine.get_frames_drawn() - _first_frame])

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

func find_button(node: Node, text: String) -> Button:
	if node is Button and node.is_visible_in_tree() and (node.text == text or str(node.get_meta("label", "")) == text): return node
	for child in node.get_children():
		var found := find_button(child, text)
		if found != null: return found
	return null

func click_at(point: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.position = point
		event.global_position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		await step(1)

func click_button(label: String) -> void:
	await step(2)
	var b := find_button(rig, label)
	if b != null: await click_at(b.get_global_rect().get_center())

func screen(point: Vector3) -> Vector2:
	return game.camera.unproject_position(point) * root.get_visible_rect().size / game.get_viewport().get_visible_rect().size

## Left-click an enemy: she locks on, walks into reach and cuts until it dies.
func lock(enemy: Enemy) -> void:
	await click_at(screen(enemy.global_position))

func spawn(point: Vector3, hp: float, chase: bool) -> Enemy:
	game._spawn_enemy(point, false, false)
	var enemy := game.get_child(game.get_child_count() - 1) as Enemy
	enemy.global_position = point
	enemy.max_health = maxf(hp, enemy.max_health)
	enemy.health = hp
	if chase: enemy.begin_chase()
	return enemy

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var region: String = args[0] if args.size() > 0 else "mine"
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(10)
	game = find_game(rig)
	game.fixed_map_seed = 1729
	_first_frame = Engine.get_frames_drawn()
	var player := game.player
	if region == "mine":
		game.menu.show_departure(region)
		await step(20)
		await click_button("阿米娅·剑兔")
		await step(30)
		await click_button("开始行动")
	else:
		game.choose_operator(Operators.AMIYA_GUARD)
		await game.start_contract(region)
	for i in range(240):
		if not game.in_base and not game.transitioning: break
		await step()
	game._clear_field()
	player.max_hp = 100000  # the clip is about visuals; keep her alive through it
	player.hp = 100000
	var origin := ContinuousWorldMap.ENTRY_POSITION
	player.teleport(origin)
	mark("field")
	await step(15)
	# One at a time from each side; sturdy enough to need a full combo or two.
	for side in SIDES:
		var enemy := spawn(player.global_position + side, 2400, true)
		await step(3)
		await lock(enemy)
		for i in range(FRAMES_PER_SIDE):
			if not is_instance_valid(enemy) or enemy._dead: break
			if i % 30 == 29 and not player.has_target(): await lock(enemy)
			await step(1)
		if is_instance_valid(enemy) and not enemy._dead: enemy.take_hit(100000, "true", false, 0.0, true)
		await step(10)
	# A weak pack ahead: 绝影 finishes the weakest and chains to the next.
	player.teleport(origin)
	await step(10)
	var pack: Array[Enemy] = []
	for offset in [Vector3(2.4, 0, 0), Vector3(4.0, 0, 1.6), Vector3(4.4, 0, -1.8), Vector3(6.0, 0, 0.2)]:
		var member := spawn(origin + offset, 5000, false)
		# Held in place so the bounces between them stay readable.
		member.set_physics_process(false)
		pack.append(member)
	await step(10)
	# Space with the cursor on the pack: four strikes bouncing across it.
	player.shadow_cooldown = 0.0
	player.stats_changed.emit()
	await step(20)
	var aim := screen(pack[0].global_position)
	var motion := InputEventMouseMotion.new()
	motion.position = aim
	Input.parse_input_event(motion)
	await step(2)
	Input.action_press("operator_skill")
	await step(1)
	Input.action_release("operator_skill")
	await step(75)
	# Shift dodge once she is free again.
	await click_at(screen(origin + Vector3(-3, 0, 0)), MOUSE_BUTTON_RIGHT)
	await step(15)
	Input.action_press("dash")
	await step(2)
	Input.action_release("dash")
	await step(40)
	mark("settle")
	game.settle(true)
	await step(45)
	mark("end")
	rig.queue_free()
	await create_timer(0.3).timeout
	quit()
