class_name GuardPost
extends Node3D

## Anchored to a search location, independent of the collectible's lifetime.
## Shared hysteresis lets the whole squad defend and disengage together.
##
## The trigger boundary is deliberately not drawn. Nothing marks it on the
## ground and nothing marks it on the minimap: the player judges how close is
## too close by reading the guards and the ground they are standing on, the
## same way Grim Dawn never draws an aggro radius. The readable-danger rule
## this project holds to covers attacks — a telegraphed circle before damage
## resolves — not the question of how near a sentry will let you walk.
var game: Node3D
var guards: Array[Enemy] = []

var trigger_radius := 7.0
var release_radius := 12.0
var leash_radius := 14.0
var active := false
var title := "补给点"
var _cooldown := 0.0

func _ready() -> void:
	add_to_group("guard_posts")

func add_guard(enemy: Enemy) -> void:
	guards.append(enemy)
	enemy.configure_guard(self)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game) or not game.simulation_active(): return
	# Freed nodes can no longer be cast to Enemy when passed into a typed
	# callback. Check validity before accessing or retaining each reference.
	guards.assign(guards.filter(func(enemy) -> bool: return is_instance_valid(enemy) and not enemy._dead))
	_cooldown = maxf(0, _cooldown - delta)
	if guards.is_empty():
		active = false
		return
	var distance := _player_distance()
	if active:
		if distance > release_radius:
			active = false
			_cooldown = 0.8
			for guard in guards: guard.begin_return()
		else:
			for guard in guards:
				if guard.state == Enemy.State.IDLE: guard.begin_chase()
	else:
		var returning := guards.any(func(enemy: Enemy) -> bool: return enemy.state == Enemy.State.RETURNING or enemy._rearm_timer > 0)
		if not returning and _cooldown <= 0 and distance <= trigger_radius: _activate()

func _player_distance() -> float:
	var offset: Vector3 = game.player.global_position - global_position
	return Vector2(offset.x, offset.z).length()

func alert_from_hit() -> void:
	if _player_distance() > release_radius: return
	if guards.any(func(enemy) -> bool: return is_instance_valid(enemy) and enemy.state == Enemy.State.RETURNING): return
	_activate()

func _activate() -> void:
	active = true
	for guard in guards:
		if is_instance_valid(guard): guard.begin_chase()
