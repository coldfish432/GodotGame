extends SceneTree
## Real input in the production window (用户 2026-10-10): pick a hotbar slot's
## content by clicking it on the bar; bind a flask to a mouse side button on
## the 按键设置 page and drink with it; clicks on the bar never attack.
var rig: Node
var game: GameManager
var failures := 0
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool) -> void:
	print(("PASS " if passed else "FAIL ") + label)
	if not passed: failures += 1
func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null
func buttons(node: Node, text: String, out: Array = []) -> Array:
	if node is Button and node.is_visible_in_tree() and node.text == text: out.append(node)
	for child in node.get_children(): buttons(child, text, out)
	return out
func mouse(point: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	await step(1)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.position = point
		event.global_position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		await step(1)
	await step(2)
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/" + name + ".png")
func run() -> void:
	var saved_bar: Variant = SystemScreens.settings.get("hotbar", [])
	var saved_keys: Variant = SystemScreens.settings.get("keybinds", {})
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(10)
	game = find_game(rig)
	game.fixed_map_seed = 1729
	SystemScreens._game = null # never write the player's settings.cfg from a test
	Hotbar.reset()
	Keybinds.reset()
	await game.start_contract("mine")
	game._clear_field()
	await step(5)
	var hud: Hud = game._hud
	var p := game.player
	# Click slot 6 on the bar: its picker opens, and she does not swing.
	await mouse(hud._slot_rect(6).get_center())
	check("clicking a slot opens its picker", hud.picker_slot == 5)
	check("a click on the bar never attacks", p.combo_step == 0 and p.swing_remaining == 0.0)
	await shot("hotbar-picker")
	var gel: Rect2 = hud._picker_rows().filter(func(r): return r[1] == "potion_B")[0][0]
	await mouse(gel.get_center())
	check("clicking a choice puts it in the slot (and moves it off slot 4)", Hotbar.slots()[5].action == "potion_B" and Hotbar.slots()[3].action == "" and hud.picker_slot == -1)
	await mouse(hud._slot_rect(6).get_center())
	await mouse(Vector2(640, 300))
	check("a click elsewhere closes the picker without attacking", hud.picker_slot == -1 and p.combo_step == 0)
	# Pause → 按键设置: bind 急救剂's dedicated key to mouse side button 1.
	game.toggle_panel("pause")
	await step(2)
	game.menu.pause_page = 2
	BaseScreens.pause(game.menu)
	await step(3)
	check("the keys page lists functions with primary and secondary", buttons(rig, "⇧").size() >= 1 and buttons(rig, "W").size() == 1 and buttons(rig, "↑").size() == 1)
	var flask_index := Keybinds.ids().find("potion_A")
	# 急救剂's primary is the (flask_index)-th function's first button: click it.
	var target: Button = null
	for b in game.menu.get_tree().root.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and b.get_meta("binding", -1) == flask_index * 2: target = b
	if target != null: await mouse(target.get_global_rect().get_center())
	check("a binding waits for input", buttons(rig, "按下按键…").size() == 1)
	await shot("hotbar-keys")
	var side := InputEventMouseButton.new()
	side.button_index = MOUSE_BUTTON_XBUTTON1
	side.pressed = true
	Input.parse_input_event(side)
	await step(2)
	side.pressed = false
	Input.parse_input_event(side)
	await step(2)
	check("a mouse side button becomes 急救剂's key", Keybinds.short_label("potion_A") == "侧键 1" and game.modal == "pause")
	game.close_modal()
	await step(3)
	# In the field: the side button drinks a first-aid flask.
	for item in game.carried_potions():
		game.inventory.remove(item)
		game.safe_bag.remove(item)
	game.inventory.try_add(BaseCatalog.create_potion("A"))
	p.hp = p.max_hp * 0.4
	var before := p.hp
	await mouse(Vector2(640, 300), MOUSE_BUTTON_XBUTTON1)
	check("pressing the side button drinks it", game.carried_potions().is_empty() and p.hp > before)
	await shot("hotbar-bar")
	Hotbar.reset()
	Keybinds.reset()
	SystemScreens.settings["hotbar"] = saved_bar
	SystemScreens.settings["keybinds"] = saved_keys
	Keybinds.apply()
	print("HOTBAR_INPUT: %d failures" % failures)
	game.settle(true)
	await create_timer(0.3).timeout
	rig.queue_free()
	await create_timer(0.3).timeout
	quit(1 if failures else 0)
