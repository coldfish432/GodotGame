class_name SwordWave
extends Node3D
## Swept collision prevents tunnelling; each enemy is damaged once per wave.
const SPEED := 14.0
const RANGE := 9.0
const WIDTH := 1.2
var direction := Vector3.FORWARD
## Arts damage before the target's resistance (局内构筑与数值策划案 §5.3).
var damage := 2.0
var kind := "arts"
var crit := false
## 穿透咒印 widens and lengthens it; extra waves (双生剑气, 月下双刃) never
## trigger relics that spawn further waves.
var width_scale := 1.0
var range_bonus := 0.0
var extra := false
## It loses up to this share of its damage over its full flight (精英化案 §8.1
## 远程攻击不再降低攻击力 takes it away), and with 猎犬 it steers to the nearest enemy.
const BASE_DECAY := 0.3
var decay := 0.0
var homing := false
const HOMING_TURN := 6.0
var travelled := 0.0
var game: GameManager
var hit_ids: Dictionary = {}

func _ready() -> void:
	game = get_parent() as GameManager
	CombatVfx.spawn(self, global_position, direction, "wave", 0, true).game = game

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game) or not game.simulation_active(): return
	var reach := maxf(1.0, RANGE + range_bonus)
	if homing: _steer(delta)
	var distance := minf(SPEED * delta, reach - travelled)
	var start := global_position
	var end := start + direction * distance
	var blocked := not game.line_of_sight(start, end)
	if blocked:
		# Locate the last visible point so enemies before a wall can still be hit.
		var lo := 0.0
		var hi := distance
		for i in range(10):
			var mid := (lo + hi) * 0.5
			if game.line_of_sight(start, start + direction * mid): lo = mid
			else: hi = mid
		end = start + direction * lo
	# Nearest first along the way: a 家族恫吓者 stops a piercing attack where it
	# stands (用户 2026-10-16: 穿透类攻击打到他就停下), so those behind it are spared.
	var struck: Array = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy.game != game or enemy._dead or hit_ids.has(enemy.get_instance_id()): continue
		var point := Vector3(enemy.global_position.x, start.y, enemy.global_position.z)
		var nearest := Geometry3D.get_closest_point_to_segment(point, start, end)
		if point.distance_to(nearest) <= WIDTH * width_scale * 0.5 and game.line_of_sight(start, point):
			struck.append([start.distance_to(nearest), enemy, point, nearest])
	struck.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	for entry in struck:
		var enemy: Enemy = entry[1]
		var point: Vector3 = entry[2]
		hit_ids[enemy.get_instance_id()] = true
		var amount := damage * (1.0 - decay * clampf(travelled / reach, 0.0, 1.0)) * (game.player.wave_bonus_against(enemy) if is_instance_valid(game.player) else 1.0)
		var dealt := enemy.take_hit(amount, kind, crit)
		if is_instance_valid(game.player): game.player.on_wave_hit(enemy, dealt, self)
		CombatVfx.spawn(game, point, direction, "spark", 0, true)
		if enemy.attack_profile.get("blocks_pierce", false):
			end = entry[3]
			blocked = true
			break
	global_position = end
	travelled += start.distance_to(end)
	if blocked or travelled >= reach - 0.0001:
		CombatVfx.spawn(game, end, direction, "mist", 0, true)
		queue_free()

func _steer(delta: float) -> void:
	var best: Enemy = null
	var best_distance := 7.0
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.game != game or enemy._dead or hit_ids.has(enemy.get_instance_id()): continue
		var d := Vector2(enemy.global_position.x - global_position.x, enemy.global_position.z - global_position.z).length()
		if d < best_distance:
			best = enemy
			best_distance = d
	if best == null: return
	var to := best.global_position - global_position
	to.y = 0
	if to.length_squared() < 0.001: return
	var turn := direction.signed_angle_to(to.normalized(), Vector3.UP)
	direction = direction.rotated(Vector3.UP, clampf(turn, -HOMING_TURN * delta, HOMING_TURN * delta)).normalized()
