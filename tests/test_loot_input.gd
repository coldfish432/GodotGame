extends SceneTree
## Grim Dawn style ground loot through real input in the production window
## (用户 2026-10-10): items pop out with their own icon and a name plate;
## walking over them takes nothing; a click on the plate walks her over and
## takes it, 赤金 included; filtered items show their plate only with Alt.
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
## Real click at a HUD point (the window shows the UI 1:1).
func click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	await step(1)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		await step(1)
func plate_of(loot: Loot) -> Rect2:
	for entry in game._hud._loot_plates:
		if entry[1] == loot: return entry[0]
	return Rect2()
func spawn(item: Item, at: Vector3, from: Vector3) -> Loot:
	var loot := Loot.new()
	loot.game = game
	loot.item = item
	loot.from = from
	game.add_child(loot)
	loot.global_position = at
	return loot
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
	var sword := LootTables.roll_equipment(Item.Category.WEAPON, "x", "mine", 1, Item.PURPLE, game.rng)
	var gold := MaterialCatalog.create(Economy.GOLD_ID, 7, "mine")
	var ore := MaterialCatalog.create(MaterialCatalog.MATERIALS.keys()[0], 2, "mine")
	var source := origin + Vector3(3, 0.6, 0)
	var a := spawn(sword, origin + Vector3(3.5, 0, 1.0), source)
	var b := spawn(gold, origin + Vector3(2.6, 0, -0.6), source)
	var c := spawn(ore, origin + Vector3(3.2, 0, 0.1), source)
	await step(3)
	check("drops pop out of their source in an arc", a.global_position.y > 0.4 and not a.landed())
	await step(30)
	check("they land where they were thrown", a.landed() and absf(a.global_position.y - (origin.y + 0.0)) < 0.2)
	check("each shows its own item icon, not a shape", a._sprite.texture == Loot.ground_texture(sword) and b._sprite.texture == Loot.ground_texture(gold) and a._sprite.texture.get_width() <= Loot.GROUND_ICON_TEXELS)
	var plates: Array[Rect2] = [plate_of(a), plate_of(b), plate_of(c)]
	var none_overlap: bool = not plates[0].intersects(plates[1]) and not plates[0].intersects(plates[2]) and not plates[1].intersects(plates[2])
	check("every drop has a name plate, none overlapping", plates.all(func(r): return r.size.x > 0) and none_overlap)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/loot-plates.png")
	# Walking over 赤金 does not take it.
	var before := game.gold_bars()
	p.teleport(b.global_position)
	await step(20)
	check("walking over 赤金 takes nothing", is_instance_valid(b) and game.gold_bars() == before)
	p.teleport(origin)
	await step(3)
	# A real click on the sword's plate: she walks over and takes it.
	await click(plate_of(a).get_center())
	check("clicking a plate sends her to it", game.pickup_target == a and p._has_move_target)
	for i in range(180):
		if not is_instance_valid(a) or a.is_queued_for_deletion(): break
		await step()
	check("she arrives and takes it", game.inventory.items.has(sword))
	await step(2)
	await click(plate_of(b).get_center())
	for i in range(180):
		if not is_instance_valid(b) or b.is_queued_for_deletion(): break
		await step()
	check("赤金 is taken the same way", game.gold_bars() == before + 7)
	# A filtered drop: no plate until Alt is held, then clickable.
	game.pickup_filter = 2
	var common := LootTables.roll_equipment(Item.Category.ARMOR, "x", "mine", 1, 0, game.rng)
	var d := spawn(common, p.global_position + Vector3(-2.5, 0, 0), p.global_position + Vector3.UP)
	await step(30)
	check("a filtered drop has no plate", plate_of(d).size.x == 0)
	var alt := InputEventKey.new()
	alt.keycode = KEY_ALT
	alt.physical_keycode = KEY_ALT
	alt.pressed = true
	Input.parse_input_event(alt)
	await step(3)
	check("holding Alt shows it", plate_of(d).size.x > 0)
	await click(plate_of(d).get_center())
	alt.pressed = false
	Input.parse_input_event(alt)
	for i in range(180):
		if not is_instance_valid(d) or d.is_queued_for_deletion(): break
		await step()
	check("and a click takes it", game.inventory.items.has(common))
	game.pickup_filter = 0
	print("LOOT_INPUT: %d failures" % failures)
	game.settle(true)
	await create_timer(0.3).timeout
	rig.queue_free()
	await create_timer(0.3).timeout
	quit(1 if failures else 0)
