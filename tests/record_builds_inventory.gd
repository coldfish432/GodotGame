extends SceneTree

## Not a test — records the relic system and the new inventory for Movie Maker:
## a fight with damage numbers and health bars, a relic offer, then the
## inventory (hover compare, Alt ranges, drag into the safe bag, drag onto the
## weapon slot, sort). Mouse input is real GUI events; a drawn cursor shows
## where it is, since Movie Maker does not capture the OS pointer. Run with:
##   godot --path downfall-godot --script res://tests/record_builds_inventory.gd
##        --rendering-method gl_compatibility --audio-driver Dummy
##        --resolution 1280x720 --fixed-fps 60 --write-movie <dir>/frame.png
## Then: ffmpeg -framerate 60 -i <dir>/frame%08d.png -c:v libx264 -crf 16 -pix_fmt yuv420p out.mp4

var rig: Node
var game: GameManager
var cursor := Vector2(640, 360)
var held := false
var _pointer: Control

func _initialize() -> void: call_deferred("run")

func frames(n: int) -> void:
	for i in range(n): await process_frame

func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null

func find_control(node: Node, predicate: Callable) -> Control:
	if node is Control and node.is_visible_in_tree() and predicate.call(node): return node
	for child in node.get_children():
		var found := find_control(child, predicate)
		if found != null: return found
	return null

## Glides the pointer to `to` over `n` frames, as real motion events.
func glide(to: Vector2, n: int = 24) -> void:
	var start := cursor
	for i in range(1, n + 1):
		var t := float(i) / n
		t = t * t * (3.0 - 2.0 * t)
		var motion := InputEventMouseMotion.new()
		motion.position = start.lerp(to, t)
		motion.global_position = motion.position
		motion.relative = motion.position - cursor
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
		cursor = motion.position
		Input.parse_input_event(motion)
		_pointer.queue_redraw()
		await process_frame

func button(pressed: bool, index: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = index
	event.pressed = pressed
	event.position = cursor
	event.global_position = cursor
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed and index == MOUSE_BUTTON_LEFT else 0
	held = pressed and index == MOUSE_BUTTON_LEFT
	Input.parse_input_event(event)
	_pointer.queue_redraw()
	await frames(2)

func click(at: Vector2) -> void:
	await glide(at)
	await frames(6)
	await button(true)
	await button(false)

func drag(from: Vector2, to: Vector2) -> void:
	await glide(from)
	await frames(8)
	await button(true)
	await glide(from + Vector2(12, 8), 6)
	await glide(to, 36)
	await frames(10)
	await button(false)

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	await frames(1)

func run() -> void:
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	_pointer = Control.new()
	_pointer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pointer.draw.connect(func():
		var c := cursor
		var arrow := PackedVector2Array([c, c + Vector2(0, 22), c + Vector2(6, 16), c + Vector2(11, 26), c + Vector2(15, 24), c + Vector2(10, 14), c + Vector2(18, 14)])
		_pointer.draw_colored_polygon(arrow, Color("f3b04a") if held else Color.WHITE)
		_pointer.draw_polyline(arrow + PackedVector2Array([c]), Color(0.05, 0.05, 0.06), 1.5))
	layer.add_child(_pointer)
	await frames(20)
	game = find_game(rig)
	await game.start_contract("snow")
	game.builds.assign(["显圣吊坠", "古高卢银币", "制式防暴用具", "皇帝的恩宠", "残破合影", "演出用香水"])
	game.player.equip(SpecialGear.create("twin_fang", 2, RandomNumberGenerator.new()))
	game.player._recompute_stats()
	game.player.reset_floor_state()

	# --- A fight: real enemies, real swings, numbers and bars.
	var stage: Vector3 = game.world_map.try_sample_navigation_position(game.world_map.buff_position, 25.0)
	stage.y = 0.7
	game._clear_field()
	game.player.teleport(stage)
	game.camera.global_position = game.camera_target() + GameManager.CAMERA_OFFSET
	for offset in [Vector3(3.5, 0, 0.5), Vector3(4, 0, -1.5), Vector3(-3, 0, 2)]:
		var enemy := game._spawn_enemy(stage + offset, offset.x < 0, false)
		enemy.max_health *= 2.0
		enemy.health = enemy.max_health
	var elapsed := 0
	while elapsed < 60 * 9:
		var target: Enemy = null
		for node in get_nodes_in_group("enemies"):
			if target == null or node.global_position.distance_to(game.player.global_position) < target.global_position.distance_to(game.player.global_position): target = node
		if target == null: break
		if game.player.is_target_in_range(target): game.player.attack(target)
		else: game.player.set_move_target(target.global_position)
		if game.player.hp < game.player.max_hp * 0.4: game.player.hp = game.player.max_hp * 0.8
		await process_frame
		elapsed += 1
	game.player.clear_move_target()
	await frames(40)

	# --- A relic offer.
	game._clear_field()
	game.player.teleport(game.world_map.buff_position)
	game._interact()
	await frames(100)
	var pick := find_control(game.menu, func(c): return c is Button and str(c.text).begins_with("选择 "))
	if pick != null: await click(pick.get_global_rect().get_center())
	await frames(60)

	# --- The inventory.
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in range(12):
		var loot := FieldCatalog.roll_item("snow", 4, rng, 1.5)
		if i == 3: loot.insured = true
		game.inventory.try_add(loot)
	var blade := Item.create("精工战刃", Item.Category.WEAPON, 2, 1, 3.2)
	blade.rarity = 2
	var crit := ItemModifier.stat_mod(ItemModifier.Stat.CRIT_RATE, 0.065)
	crit.tier = 2
	var atk_pct := ItemModifier.stat_mod(ItemModifier.Stat.ATK_PCT, 0.08)
	atk_pct.tier = 1
	blade.modifiers = [ItemModifier.trigger_mod(ItemModifier.Trigger.SWORD_WAVE), crit, atk_pct]
	blade.value = 96
	game.inventory.items.clear()
	for i in range(9):
		game.inventory.try_add(FieldCatalog.roll_item("snow", 4, rng, 1.5))
	game.inventory.try_add(blade)
	var charm := Item.create("战术挂饰", Item.Category.TRINKET, 1, 1, 2.0)
	charm.rarity = 1
	game.inventory.try_add(charm)
	game.safe_bag.try_add(FieldCatalog.exclusive("snow"))
	var worn := Item.create("外勤战刃", Item.Category.WEAPON, 2, 1, 1.0)
	game.player.equip(worn)
	game.open_modal("inventory")
	game._inventory_panel.open()
	await frames(50)
	var panel := game._inventory_panel
	var tile_of := func(item: Item) -> Control: return find_control(panel, func(c): return c is Button and "item" in c and "container" in c and c.get("item") == item)
	var better: Item = null
	for item in game.inventory.items:
		if item.category == Item.Category.WEAPON and (better == null or item.power > better.power): better = item
	if better != null:
		await glide(tile_of.call(better).get_global_rect().get_center(), 36)
		await frames(110)
		await key(KEY_ALT, true)
		await frames(90)
		await key(KEY_ALT, false)
		await key(KEY_SHIFT, true)
		await frames(90)
		await key(KEY_SHIFT, false)
		await frames(20)
	# Into the safe bag: a free cell beside the relic.
	var safe_grid := find_control(panel, func(c): return "container" in c and c.get("container") == game.safe_bag and c.has_method("_drop_data"))
	var target_cell := Vector2(1, 1)  # the relic fills the top row
	await drag(tile_of.call(charm).get_global_rect().get_center(), safe_grid.global_position + target_cell * InventoryPanel.CELL + Vector2(20, 20))
	await frames(60)
	if better != null and game.inventory.items.has(better):
		var slot := find_control(panel, func(c): return "category" in c and c.get("category") == Item.Category.WEAPON and c.has_method("_drop_data"))
		await drag(tile_of.call(better).get_global_rect().get_center(), slot.get_global_rect().get_center())
		await frames(80)
	var sort := find_control(panel, func(c): return c is Button and c.text == "整理")
	if sort != null:
		await click(sort.get_global_rect().get_center())
		await frames(90)
	game.close_modal()
	await frames(40)
	quit()
