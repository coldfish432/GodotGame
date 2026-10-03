class_name AiDriver
extends RefCounted

## A reactive bot for the record_demo script: reads real game/player/enemy
## state each tick and picks one action, same priority a careful human
## player would use — no scripted positions or timings. Same technique as
## walker-jumpman/tests/route_driver.gd (read state, emit input), just with
## richer state to react to.
##
## Player movement itself has no pathfinding (matches the source: it's a
## straight line to the click point, same as a human's right-click), so
## walking straight at a destination on the far side of a cliff band just
## gets the player stuck against it. The bot works around this the way a
## human does — by aiming for the nearer mountain pass instead of the
## destination directly — using a NavigationAgent3D it owns itself purely
## for steering decisions, not attached to the player.

const DODGE_MARGIN := 1.5
const DODGE_DISTANCE := 4.0
const POTION_HP_RATIO := 0.5
const INTERACT_RANGE := 2.0

var _nav_agent: NavigationAgent3D

func decide(game: GameManager) -> void:
	if game.in_base or game.transitioning: return
	if game.modal == "build":
		game.choose_build(game.build_offers[0].id)
		return
	if game.modal == "route":
		game.advance(0)
		return
	var player: Player = game.player
	if not is_instance_valid(player):
		return

	# 1. React to the pose/locked direction of ordinary enemies and the
	# warning circle of elites. The bot does not require ordinary UI markers.
	var danger := _telegraph_danger(game, player)
	if danger.length_squared() > 0.0001:
		player.set_move_target(player.global_position + danger.normalized() * DODGE_DISTANCE)
		return

	# 2. Heal before it becomes urgent, but don't waste potions topping off.
	if game.potions > 0 and player.hp < player.max_hp * POTION_HP_RATIO:
		game._use_potion()

	# 3. Close distance and attack with the twin swords.
	var nearest := _nearest_enemy(game, player)
	if is_instance_valid(nearest):
		if player.is_target_in_range(nearest):
			player.clear_move_target()
			player.attack(nearest)
		else:
			_move_toward(game, player, nearest.global_position)
		return

	# 4. Room is clear. Bank the buff if it's still on offer.
	if game.is_buff_available() and is_instance_valid(game.world_map.buff_device_node):
		_approach_and_interact(game, player, game.world_map.buff_device_node.global_position)
		return

	# 5. Nothing left to do here — dive.
	if game.is_extraction_floor() and is_instance_valid(game.world_map.exit_node):
		_approach_and_interact(game, player, game.world_map.exit_node.global_position)
	else:
		_approach_and_interact(game, player, game.world_map.route_nodes[0].global_position)

func _telegraph_danger(game: GameManager, player: Player) -> Vector3:
	var away := Vector3.ZERO
	for node in game.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if not is_instance_valid(enemy) or not enemy.preparing_attack:
			continue
		if not enemy.elite:
			if enemy.threatens(player.global_position):
				away += enemy.attack_direction.cross(Vector3.UP)
			continue
		var offset := player.global_position - enemy.pending_warning_position
		offset.y = 0.0
		var safe_margin := enemy.pending_warning_radius + DODGE_MARGIN
		if offset.length() < safe_margin:
			away += offset if offset.length_squared() > 0.01 else Vector3(1.0, 0.0, 0.0)
	return away

func _nearest_enemy(game: GameManager, player: Player) -> Enemy:
	var nearest: Enemy = null
	var nearest_dist := INF
	for node in game.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		var dist := enemy.global_position.distance_to(player.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	return nearest

func _approach_and_interact(game: GameManager, player: Player, target_position: Vector3) -> void:
	if player.global_position.distance_to(target_position) < INTERACT_RANGE:
		player.clear_move_target()
		game._interact()
	else:
		_move_toward(game, player, target_position)

func _move_toward(game: GameManager, player: Player, destination: Vector3) -> void:
	# NavigationAgent3D has no global_position of its own — it steers from
	# whatever Node3D owns it, so this is parented directly to the player
	# (not to `game`) purely so the bot can query a path; the real Player
	# class still only ever gets a single move_target point, same as source.
	var agent := _ensure_nav_agent(player)
	agent.target_position = destination
	if agent.is_navigation_finished():
		player.set_move_target(destination)
	else:
		player.set_move_target(agent.get_next_path_position())

func _ensure_nav_agent(player: Player) -> NavigationAgent3D:
	if not is_instance_valid(_nav_agent):
		_nav_agent = NavigationAgent3D.new()
		_nav_agent.radius = 0.45
		_nav_agent.path_desired_distance = 0.5
		_nav_agent.target_desired_distance = 0.5
		player.add_child(_nav_agent)
	return _nav_agent
