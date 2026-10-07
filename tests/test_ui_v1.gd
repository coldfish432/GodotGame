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
	# AK confirm buttons and cards carry their Chinese label as meta.
	if node is Button and node.is_visible_in_tree() and (node.text == text or str(node.get_meta("label", "")) == text): return node
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
	await click(button)

## The pack tile showing `item` (tiles with an icon have no text).
func find_tile(node: Node, item: Item) -> Button:
	if node is Button and node.get("item") == item and node.get("container") != null: return node
	for child in node.get_children():
		var found := find_tile(child, item)
		if found != null: return found
	return null

## A pickable row on an AK event screen showing `item`.
func _find_meta(node: Node, item: Item) -> Button:
	if node is Button and node.has_meta("item") and node.get_meta("item") == item and node.is_visible_in_tree(): return node
	for child in node.get_children():
		var found := _find_meta(child, item)
		if found != null: return found
	return null

## Steps until `condition` holds, at most `frames` frames.
func until(condition: Callable, frames: int) -> void:
	for i in range(frames):
		if condition.call(): return
		await process_frame

func click(button: Button) -> void:
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
	await click_button("开始行动")
	await click_button("开始行动")
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
		await click_button("获取")
	await until(func(): return game.builds.size() == 1 and game.modal.is_empty(), 60)
	check("actual choice button grants build and resumes gameplay", game.builds.size() == 1 and game.modal.is_empty())
	var shield := FieldCatalog.exclusive("city")
	game.try_collect(shield)
	Input.action_press("toggle_inventory")
	await step(1)
	Input.action_release("toggle_inventory")
	await step(3)
	check("I opens inventory with clickable spatial item", game._inventory_panel.visible)
	await step(2)
	var tile := find_tile(rig, shield)
	check("the shield's pack tile exists", tile != null)
	if tile != null: await click(tile)
	await click_button("装备")
	check("inventory mouse equip changes stats", game.player.equipped.get(Item.Category.ARMOR) == shield and game.player.move_speed < 5)
	await click_button("✕")
	check("closing inventory does not click-through move", game.modal.is_empty() and not game.player._has_move_target)
	# The squad replaces gilding (保全系统修订案): meet one, insure with 赤金.
	game.encounter = "squad"
	game.encounter_used = false
	game.world_map.encounter_node.visible = true
	game.run_gold = 40
	game.player.teleport(game.world_map.encounter_position)
	game._interact()
	await step(3)
	# Grids inside scroll containers lay out a frame or two later.
	await step(3)
	var row := _find_meta(rig, shield)
	check("the squad lists the shield", row != null)
	if row != null: await click(row)
	await click_button("✓ 投保 · %d" % game.squad_price(shield))
	check("the squad's insure button insures the chosen item", shield.insured and game.encounter_used)
	game.player.teleport(game.world_map.route_nodes[0].position)
	game._interact()
	await step(3)
	await click_button("进入 巡检支路")
	await click_button("前进")
	# Advancing waits for the new floor's navigation to sync.
	await until(func(): return game.floor_number == 2 and not game.transitioning, 600)
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
