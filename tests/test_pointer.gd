extends SceneTree
## The field's mouse on enemies (用户 2026-10-14): the attack arrow over an
## enemy's hit box, and a long left press on one attacking until release.
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
## `frames` frames of the mouse with the left button `left`, `pointed` under it.
func hold(left: bool, pointed: Enemy, frames: int) -> void:
	for i in range(frames):
		game.pointer_step(left, false, pointed, 1.0 / 60.0)
		await step()
func run() -> void:
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	await game.start_contract("mine")
	game._clear_field()
	await step(3)
	# The real (headless) mouse is never down; drive the pointer by hand.
	game.set_process(false)
	var p := game.player
	var origin := p.global_position
	game._spawn_enemy(origin + Vector3(1.5, 0, 0), true, false)
	var enemy := game.get_child(game.get_child_count() - 1) as Enemy
	enemy.max_health = 1000000
	enemy.health = 1000000
	enemy.set_physics_process(false)
	await step(2)

	var arrow := AttackCursor.texture()
	# 用户 2026-10-21: only the PRTS hand and the attack sword, both 32 px.
	var hand := AttackCursor.texture(AttackCursor.HAND)
	check("the pointers are the 32 px sword and hand", arrow.get_width() == 32 and hand.get_width() == 32 and arrow.get_image().get_pixel(1, 1).a > 0.5 and hand.get_image().get_pixel(AttackCursor.HAND_HOTSPOT.x, AttackCursor.HAND_HOTSPOT.y).a > 0.1)
	game._update_pointer_cursor(enemy)
	check("over an enemy the pointer is the attack arrow", game.attack_cursor_on)
	game._update_pointer_cursor(null)
	check("off it the default pointer returns", not game.attack_cursor_on)
	game.open_modal("inventory")
	var shown: Enemy = game._get_enemy_under_pointer() if game.simulation_active() and not game.hands_busy() else null
	game._update_pointer_cursor(shown)
	check("with a menu open there is no attack arrow", not game.attack_cursor_on)
	game.close_modal()
	await step(2)
	# Closing a menu gates the pointer until the buttons are up.
	await hold(false, null, 1)

	# A long press: click on it, slide off, keep holding.
	await hold(true, enemy, 1)
	check("the press locks the enemy", p.attack_target == enemy)
	var before := enemy.health
	var swings := 0
	var last := enemy.health
	for i in range(150):
		await hold(true, null, 1)
		if enemy.health < last: swings += 1
		last = enemy.health
	check("held with the cursor off it, she keeps the lock", p.attack_target == enemy)
	check("held, she swings again and again on her cooldown (%d hits)" % swings, swings >= 3 and enemy.health < before)
	check("held off the enemy, no air swings or walking", not p._has_move_target or p._move_target.distance_to(enemy.global_position) < 0.5)
	await hold(false, null, 1)
	check("release ends the attack", p.attack_target == null)
	last = enemy.health
	await step(90)
	check("after release no more hits", enemy.health == last)

	# A short click keeps the lock, as before.
	await hold(true, enemy, 3)
	await hold(false, enemy, 1)
	check("a short click keeps the lock", p.attack_target == enemy)
	last = enemy.health
	await step(90)
	check("and she keeps attacking it", enemy.health < last)

	# The held target switches to whichever enemy is under the cursor.
	game._spawn_enemy(origin + Vector3(-1.5, 0, 0), true, false)
	var other := game.get_child(game.get_child_count() - 1) as Enemy
	other.max_health = 1000000
	other.health = 1000000
	other.set_physics_process(false)
	await hold(false, null, 1)
	await hold(true, enemy, 1)
	await hold(true, null, 30)
	await hold(true, other, 1)
	check("held over another enemy, the lock moves to it", p.attack_target == other)
	await hold(false, null, 1)
	check("and release stops it too", p.attack_target == null)

	# A press on the ground walks there (用户 2026-10-20), never swings.
	p._attack_cooldown = 0.0
	var steps_before := p.combo_step
	await hold(true, null, 1)
	check("a ground press walks", p._has_move_target and p.combo_step == steps_before)
	await hold(true, null, 30)
	await hold(false, null, 1)
	check("a ground press never locks", p.attack_target == null)

	# A press on a ground item's name plate (用户 2026-10-13 / 10-15): it takes
	# the item and does not swing while the cursor stays there, even once the
	# plate is gone; moved off the plate, the held press attacks again.
	await hold(false, null, 2)
	var loot := Loot.new()
	loot.game = game
	loot.item = Item.create("测试物品", Item.Category.MATERIAL, 1, 1)
	loot.pickup_delay = 99.0
	game.add_child(loot)
	loot.global_position = origin + Vector3(6, 0, 6)
	await step(2)
	game._pointer_position = Vector2(400, 300)
	game._has_pointer_position = true
	var at := game.pointer_ui()
	game._hud._loot_plates = [[Rect2(at - Vector2(50, 10), Vector2(100, 20)), loot]]
	p._attack_cooldown = 0.0
	game.pointer_step(true, false, null, 1.0 / 60.0)
	check("a press on a plate walks to take the item", game.pickup_target == loot)
	game._hud._loot_plates = []
	game.pointer_step(true, false, null, 1.0 / 60.0)
	check("held still where the plate was, it does not swing", game.pickup_target == loot and p.combo_step == 0)
	game._pointer_position = Vector2(400, 360)
	game.pointer_step(true, false, null, 1.0 / 60.0)
	check("moved off the plate onto the ground, the held press walks", game.pickup_target == null and p.combo_step == 0 and p._has_move_target)
	game.pointer_step(false, false, null, 1.0 / 60.0)

	# Plates with enemies about (用户 2026-10-15): hidden unless Alt is held,
	# then faded and still clickable; with no enemy near, shown as before.
	loot.global_position = p.global_position + Vector3(0.8, 0, 0.8)
	game._hud.queue_redraw()
	await step(3)
	check("with an enemy near, no plates without Alt", game._hud._loot_plates.is_empty())
	Input.action_press("show_items")
	game._hud.queue_redraw()
	await step(3)
	check("holding Alt shows them (faded, clickable)", game._hud._loot_plates.any(func(e): return e[1] == loot))
	Input.action_release("show_items")
	for node in get_nodes_in_group("enemies"): node.queue_free()
	game._hud.queue_redraw()
	await step(3)
	check("with no enemy near, plates show without Alt", game._hud._loot_plates.any(func(e): return e[1] == loot))
	loot.queue_free()

	print("POINTER TESTS ", "FAILED %d" % failures if failures else "PASSED")
	quit(1 if failures > 0 else 0)
