extends SceneTree
## Guard Amiya through real mouse/key events in the production window: pick
## her on the departure screen, deploy, hold the mouse on an enemy through the
## combo, Space-cast 绝影 on a pack, dash. 阿米娅实现记录.md.
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
func find_button(node: Node, text: String) -> Button:
	# Operator chips are portraits: their name is the tooltip (LoadoutScreens).
	if node is Button and node.is_visible_in_tree() and (node.text == text or str(node.get_meta("label", "")) == text or (node.has_meta("operator") and node.tooltip_text == text)): return node
	for child in node.get_children():
		var found := find_button(child, text)
		if found != null: return found
	return null
## Whether any visible picture under `node` is Amiya's 84 px portrait, and
## drawn at a whole multiple of it (2x or 3x), so it stays crisp.
func shows_amiya(node: Node) -> bool:
	if node is TextureRect and node.is_visible_in_tree() and node.texture != null and node.texture.resource_path == str(Operators.info(Operators.AMIYA_GUARD).portrait):
		var ratio: float = (node as TextureRect).size.y / node.texture.get_height()
		if is_equal_approx(ratio, roundf(ratio)): return true
	for child in node.get_children():
		if shows_amiya(child): return true
	return false
func save_shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/" + label + ".png")
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
	await step(8)
func click_button(label: String) -> bool:
	await step(2)
	var button := find_button(rig, label)
	if button == null:
		check("button exists: " + label, false)
		return false
	await click_at(button.get_global_rect().get_center())
	return true
## The real window gets desktop cursor motion too; re-assert ours each frame.
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
	await step(15)
	game = find_game(rig)
	game.fixed_map_seed = 1729
	var p := game.player
	check("a fresh base deploys Lappland", not p.is_amiya())
	game.menu.show_departure("mine")
	await step(3)
	await click_button("阿米娅·剑兔")
	check("clicking her tab on the departure screen picks Amiya", p.is_amiya() and game.base.operator == Operators.AMIYA_GUARD and p._sprite.character == Operators.AMIYA_GUARD)
	check("the card now names her", find_button(rig, "阿米娅·剑兔") != null and find_button(rig, "拉普兰德") != null)
	await click_button("开始行动")
	for i in range(240):
		if not game.in_base and not game.transitioning: break
		await step()
	check("operation start deploys her into the mine", not game.in_base and p.is_amiya())
	game._clear_field()
	await step(3)
	var origin := p.global_position
	game._spawn_enemy(origin + Vector3(2, 0, 0), true, false)
	var enemy := game.get_child(game.get_child_count() - 1) as Enemy
	enemy.max_health = 1000000
	enemy.health = 1000000
	# Armour that would blank physical hits: hers are arts, so they land.
	enemy.defense = 3000
	enemy.res = 0
	enemy.set_physics_process(false)
	await step(3)
	# Hold the mouse on it: the combo, and every landed cut shortens 绝影's cooldown.
	p.shadow_cooldown = Player.SHADOW_COOLDOWN
	await mouse(enemy.global_position, true)
	var poses: Dictionary = {}
	for i in range(300):
		poses[p._sprite.action_name] = true
		hover(enemy.global_position)
		await step()
	await mouse(enemy.global_position, false)
	var armoured := 1000000 - enemy.health
	var cooled := p.shadow_ready()
	# The same hold on it with no armour: arts ignore DEF, so about the same.
	await step(30)
	enemy.defense = 0
	enemy.health = 1000000
	await mouse(enemy.global_position, true)
	for i in range(300):
		hover(enemy.global_position)
		await step()
	await mouse(enemy.global_position, false)
	var bare := 1000000 - enemy.health
	check("held mouse cuts through all three stages", poses.has("attack_1") and poses.has("attack_2") and poses.has("attack_3"))
	print("AMIYA DEALT armoured ", armoured, " bare ", bare)
	check("arts damage goes through heavy armour", armoured > 0.0 and armoured >= bare * 0.8)
	check("hitting brings 绝影 off cooldown well before 8 s", cooled)
	check("绝影 never fires by itself", not poses.has("shadow"))
	# A left click on open ground ends the lock (and walks there).
	await click_at(hover(origin + Vector3(-2, 0, 0)), MOUSE_BUTTON_LEFT)
	check("a click on the ground drops the lock", not p.has_target())
	await step(20)
	# Space with the cursor on a pack: four strikes bouncing across it.
	enemy.queue_free()
	var pack: Array[Enemy] = []
	for offset in [Vector3(2.5, 0, 0), Vector3(3.5, 0, 1.4), Vector3(4.5, 0, -0.6), Vector3(5.5, 0, 0.8)]:
		game._spawn_enemy(p.global_position + offset, false, false)
		var e := game.get_child(game.get_child_count() - 1) as Enemy
		e.global_position = p.global_position + offset
		e.max_health = 100000
		e.health = 100000
		e.set_physics_process(false)
		pack.append(e)
	await step(3)
	hover(pack[0].global_position)
	await step(1)
	Input.action_press("operator_skill")
	await step(1)
	Input.action_release("operator_skill")
	var cast := p.shadow_active
	var untouchable := true
	for i in range(40):
		if p.shadow_active: untouchable = untouchable and p.invulnerable
		hover(pack[0].global_position)
		await step()
	var struck := pack.filter(func(e): return e.health < 100000).size()
	check("Space casts 绝影 on the enemy under the cursor", cast and p.shadow_strikes == Player.SHADOW_STRIKES)
	check("four strikes land on four different enemies", struck == 4)
	check("she is untouchable for the whole skill", untouchable and not p.shadow_active)
	check("it went on cooldown", not p.shadow_ready() and p.shadow_cooldown > 0.0)
	Input.action_press("operator_skill")
	await step(1)
	Input.action_release("operator_skill")
	check("Space again on cooldown does nothing", not p.shadow_active)
	await click_at(hover(origin + Vector3(-2, 0, 0)), MOUSE_BUTTON_LEFT)
	await step(10)
	Input.action_press("dash")
	await step(2)
	Input.action_release("dash")
	check("the dodge plays her sheet", p.invulnerable and p._sprite.action_name == "dash")
	await step(20)
	check("dash ends and she walks again", not p.invulnerable and p._sprite.action_name != "dash")
	game.settle(true)
	await step(10)
	check("the settlement screen shows her crisp portrait, not Lappland", shows_amiya(rig))
	await save_shot("amiya-settlement")
	var file := FileAccess.open("res://../evidence/amiya-input-tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures}, "  "))
	file.close()
	print("AMIYA_INPUT: %d checks / %d failures" % [checks.size(), failures])
	await create_timer(0.3).timeout
	rig.queue_free()
	await create_timer(0.3).timeout
	quit(1 if failures else 0)
