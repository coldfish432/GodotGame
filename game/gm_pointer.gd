class_name GmPointer
extends RefCounted

## GameManager's mouse in the field and at the base: what the left button
## does each frame (pointer_step), and the pointer's rays onto enemies and the
## ground. Where the pointer is (_pointer_position) stays on GameManager.

const PLATE_LEAVE_PX := 10.0
const HOLD_ATTACK_TIME := 0.25

var game: GameManager
## Set when a screen closes or opens: the press still held does nothing until let go.
var gate := false
var _left_was_down := false
## A left press that began on an enemy (用户 2026-10-14: 长按敌人连续攻击):
## held past HOLD_ATTACK_TIME, she keeps at it while it is held, with the
## cursor on it or off it, and stops on release. A shorter click keeps the
## lock as before.
var _held_on_enemy := false
var _left_held_time := 0.0
## The name plate the held left press is on (or came from), and where the
## cursor last was over it; off by PLATE_LEAVE_PX, the press attacks again.
var _plate_held: Loot = null
var _plate_from := Vector2.ZERO
## One query for the pointer pick; only the ends change.
var _pick_query: PhysicsRayQueryParameters3D

func _init(owner: GameManager) -> void:
	game = owner

## One frame of the field's mouse: `left` is the button held now.
func step(left: bool, pointed_enemy: Enemy, delta: float) -> void:
	if gate:
		gate = left
		_held_on_enemy = false
		return

	var player := game.player
	var left_click := left and not _left_was_down
	var released := _left_was_down and not left
	_left_was_down = left
	if not left: _plate_held = null
	# Letting go of a long press on an enemy ends the attack there.
	if released and _held_on_enemy:
		_held_on_enemy = false
		if _left_held_time >= HOLD_ATTACK_TIME:
			player.clear_target()
			player.clear_move_target()
	# The hotbar (用户 2026-10-10: 在快捷栏上直接点格子换内容): a click on a slot
	# opens its picker, a click in the picker sets it, any other click closes it.
	# Clicks there never reach the field.
	var hud := game._hud
	if is_instance_valid(hud):
		var at := game.pointer_ui()
		var over := hud.hotbar_slot_at(at) # -2 off the bar, -1 the bar but no slot
		if left_click and hud.picker_slot >= 0:
			var choice: Variant = hud.picker_choice_at(at)
			var open := hud.picker_slot
			hud.picker_slot = -1
			if choice != null: Hotbar.set_action(open, str(choice))
			elif over >= 0 and over != open: hud.picker_slot = over
			gate = true # the closing click does nothing else
			return
		if over >= -1:
			if left_click and over >= 0: hud.picker_slot = over
			return
	if not left:
		return

	# Left on a ground item's name plate: she walks over and takes it (恐怖黎明式,
	# 用户 2026-10-10). Plates sit above everything else under the cursor.
	var plate := hud.loot_label_at(game.pointer_ui()) if is_instance_valid(hud) and (left_click or not _held_on_enemy) else null
	if is_instance_valid(plate):
		if plate != _plate_held:
			game.request_pickup(plate)
			_plate_held = plate
		_plate_from = game.pointer_ui()
		return
	# A press held from a name plate (用户 2026-10-13: 左键选中拾取物品时不触发
	# 攻击): while the cursor stays put — the plate gone because the item was
	# taken — nothing swings. Moved off it, the press counts again: an enemy
	# under it is attacked, the ground walked to (用户 2026-10-15 / 10-20).
	if _plate_held != null:
		if game.pointer_ui().distance_to(_plate_from) < PLATE_LEAVE_PX: return
		_plate_held = null
		left_click = true

	if left_click:
		_held_on_enemy = is_instance_valid(pointed_enemy)
		_left_held_time = 0.0
	elif _held_on_enemy:
		_left_held_time += delta
	# Left on an enemy locks it: she closes to her weapon's reach and attacks it
	# (Player._follow_target), one swing per cooldown. One click is enough;
	# holding keeps it, and moves it to whichever enemy is under the cursor.
	if is_instance_valid(pointed_enemy):
		game.pickup_target = null
		player.lock_target(pointed_enemy)
		return
	game.pickup_target = null
	# A press that began on an enemy never turns into air swings or a walk:
	# off the enemy she keeps at the lock (none once it died) until release.
	if _held_on_enemy: return

	# Left on the ground drops the lock and walks there, whatever she holds
	# (用户 2026-10-20: 左键点地面改为会移动; no more air swings). A vault's
	# 暗墙 is opened with E at its mouth (_vault_nearby), not by clicking it.
	var ground := ground_point()
	if player.wall_target and not left_click: return
	player.clear_target()
	player.set_move_target(ground)

## The base's mouse: held left walks her to the ground under it.
func base_step() -> void:
	if gate:
		gate = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		game.player.set_move_target(ground_point())

## The enemy whose pick box is under the pointer, or null.
func enemy_under() -> Enemy:
	var viewport := game.get_viewport()
	var camera := game.camera
	if viewport == null or not is_instance_valid(camera):
		return null
	var mouse_pos := game._pointer_in(viewport)
	var from := camera.project_ray_origin(mouse_pos)
	var to := from + camera.project_ray_normal(mouse_pos) * 200.0
	if _pick_query == null:
		_pick_query = PhysicsRayQueryParameters3D.create(from, to)
		_pick_query.collide_with_areas = true
		_pick_query.collide_with_bodies = false
		_pick_query.collision_mask = GameManager.ENEMY_PICK_MASK
	_pick_query.from = from
	_pick_query.to = to
	var result := game.get_world_3d().direct_space_state.intersect_ray(_pick_query)
	if result.is_empty():
		return null
	var collider: Node = result.get("collider")
	if collider == null:
		return null
	return collider.get_parent() as Enemy

## The ground point under the pointer (her own position when there is none).
func ground_point() -> Vector3:
	var viewport := game.get_viewport()
	var camera := game.camera
	var player := game.player
	if viewport == null or not is_instance_valid(camera):
		return player.global_position
	var mouse_pos := game._pointer_in(viewport)
	var from := camera.project_ray_origin(mouse_pos)
	var dir := camera.project_ray_normal(mouse_pos)
	if absf(dir.y) < 0.0001:
		return player.global_position
	# Onto the terraced ground: meet the plane at the last height found, read
	# the ground there, repeat. A steep camera settles in a few steps.
	# A bridge's deck is picked first, unless she is on the road under it:
	# then a click there means that road, not the deck overhead.
	var in_base := game.in_base
	var world_map := game.world_map
	if not in_base and is_instance_valid(world_map):
		var deck: Vector3 = world_map.deck_hit(from, dir)
		if deck != Vector3.INF:
			var bridge: Dictionary = world_map.bridge_at(Vector2(deck.x, deck.z))
			var under: bool = player.global_position.y < float(bridge.top) - world_map.BRIDGE_REACH and not world_map.bridge_at(Vector2(player.global_position.x, player.global_position.z), 6.0).is_empty()
			if not under: return deck
	var ground := player.global_position.y - 0.7 if not in_base else 0.0
	var hit := from
	for i in range(5):
		var t := (ground - from.y) / dir.y
		if t < 0.0:
			return player.global_position
		hit = from + dir * t
		var next := game.ground_y(hit)
		if absf(next - ground) < 0.02: break
		ground = next
	hit.y = game.ground_y(hit)
	return hit
