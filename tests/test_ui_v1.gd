extends SceneTree
var game: GameManager
var rig: Node
var failures := 0
var checks: Array[Dictionary] = []
func _initialize() -> void: call_deferred("run")
func step(count: int = 3) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func check(label: String, result: bool) -> void:
	checks.append({"check": label, "passed": result})
	if not result: failures += 1
	print(("PASS " if result else "FAIL ") + label)
func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null
func find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text: return node
	for child in node.get_children():
		var found := find_button(child, text)
		if found != null: return found
	return null
func click_button(label: String) -> void:
	# Menus rebuilt this frame (auto-wrapping cards and panels) take a frame or
	# two to settle; measuring earlier aims at where the button used to be.
	await step(2)
	var button := find_button(rig, label)
	if button == null:
		check("button exists: " + label, false)
		return
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		await step(1)
	await step(8)
func run() -> void:
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(15)
	game = find_game(rig)
	# Walk-up station: stand at the dispatch console and press E to open the contract board.
	game.player.teleport(game.base_map.station("dispatch").position + Vector3(0, 0, -1.6))
	await step(2)
	Input.action_press("interact")
	await step(1)
	Input.action_release("interact")
	await step(3)
	check("E at the dispatch console opens the contract board", game.modal == "station" and game.menu.visible)
	await click_button("接下合同 →")
	check("rendered GUI click starts a mine contract", not game.in_base and game.region_id == "mine")
	game._clear_field()
	await step(2)
	game.player.teleport(game.world_map.buff_position)
	Input.action_press("interact")
	await step(1)
	Input.action_release("interact")
	await step(3)
	check("E opens three-choice GUI", game.modal == "build" and game.build_offers.size() == 3)
	if game.build_offers.size() == 3:
		await click_button("选择 " + game.build_offers[0].name)
	check("actual choice button grants build and resumes gameplay", game.builds.size() == 1 and game.modal.is_empty())
	var shield := FieldCatalog.exclusive("city")
	game.try_collect(shield)
	Input.action_press("toggle_inventory")
	await step(1)
	Input.action_release("toggle_inventory")
	await step(3)
	check("I opens inventory with clickable spatial item", game._inventory_panel.visible)
	await click_button("近卫")
	await click_button("装备")
	check("inventory mouse equip changes stats", game.player.equipped.get(Item.Category.ARMOR) == shield and game.player.move_speed < 5)
	await click_button("返回战斗 [ I ]")
	check("closing inventory does not click-through move", game.modal.is_empty() and not game.player._has_move_target)
	game.player.teleport(game.world_map.gilding_position)
	game._interact()
	await step(3)
	await click_button(shield.display_name() + "  /  " + shield.details())
	check("gilding selection button protects chosen equipped item", shield.gilded)
	game.player.teleport(game.world_map.route_nodes[0].position)
	game._interact()
	await step(3)
	await click_button("进入 巡检支路")
	check("route GUI enters another segment", game.floor_number == 2)
	# Mouse ground projection through low-resolution SubViewport at its real screen coordinates.
	game._clear_field()
	game.player.teleport(ContinuousWorldMap.ENTRY_POSITION)
	game.camera.global_position = game.player.position + GameManager.CAMERA_OFFSET
	await step(3)
	var target := game.player.position + Vector3(3, 0, 0)
	var viewport_point := game.camera.unproject_position(target)
	var viewport := game.get_viewport()
	var rect: Rect2 = viewport.get_parent().get_global_rect()
	var point := rect.position + viewport_point / Vector2(viewport.size) * rect.size
	var start := game.player.position
	var event := InputEventMouseMotion.new()
	event.position = point
	Input.parse_input_event(event)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.position = point
	press.global_position = point
	press.pressed = true
	Input.parse_input_event(press)
	await step(5)
	press = press.duplicate()
	press.pressed = false
	Input.parse_input_event(press)
	await step(45)
	check("right-click projected through pixel viewport moves player", game.player.position.distance_to(start) > 1)
	game.settle(true)
	await step(20)
	var report := {"checks": checks, "failures": failures, "scope": "Rendered Godot input-event integration, not Windows physical mouse automation"}
	FileAccess.open("res://../evidence/downfall-v1-ui-tests.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("UI RESULT: %d checks, %d failures" % [checks.size(), failures])
	rig.queue_free()
	await create_timer(0.3).timeout
	quit(1 if failures else 0)
