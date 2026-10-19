class_name OperatorShot
extends Node3D
## A recruit's shot (干员寻访策划案 §4: 提丰's arrows, 早露's bolts and harpoons,
## 寒檀's ice orbs). It flies flat along `direction`, steering at `target`
## when it has one, and calls `on_hit(enemy, shot)` for the first enemy it
## touches (every one on its line with `pierce`). Walls stop it, as they stop
## the sword wave (SwordWave).
const SPEED := 22.0
var direction := Vector3.FORWARD
var speed := SPEED
var reach := 10.0
var width := 0.9
var pierce := false
var target: Enemy
var texture: Texture2D
var frames := 1
var on_hit: Callable
var travelled := 0.0
var game: GameManager
var hit_ids := {}

static func fire(p_game: GameManager, from: Vector3, p_direction: Vector3, p_reach: float, p_texture: Texture2D, hit: Callable, p_target: Enemy = null) -> OperatorShot:
	var shot := OperatorShot.new()
	shot.game = p_game
	shot.direction = Vector3(p_direction.x, 0, p_direction.z).normalized() if Vector2(p_direction.x, p_direction.z).length_squared() > 0.0001 else Vector3.FORWARD
	shot.reach = p_reach
	shot.texture = p_texture
	shot.on_hit = hit
	shot.target = p_target
	p_game.add_child(shot)
	shot.global_position = from
	return shot

func _ready() -> void:
	if game == null: game = get_parent() as GameManager
	if texture != null:
		var art := CombatVfx.painted(self, global_position, direction, texture, frames, 999.0, "ground", 0.0, 0.05, 12.0, false)
		art.game = game

func _alive(enemy) -> bool:
	return is_instance_valid(enemy) and not enemy._dead

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game) or not game.simulation_active(): return
	if _alive(target):
		var to := target.global_position - global_position
		to.y = 0
		if to.length_squared() > 0.0001: direction = to.normalized()
	basis = Basis.looking_at(direction)
	var distance := minf(speed * delta, reach - travelled)
	var start := global_position
	var end := start + direction * distance
	var blocked := not game.line_of_sight(start, end)
	if blocked:
		var lo := 0.0
		var hi := distance
		for i in range(10):
			var mid := (lo + hi) * 0.5
			if game.line_of_sight(start, start + direction * mid): lo = mid
			else: hi = mid
		end = start + direction * lo
	var struck: Array = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.game != game or enemy._dead or hit_ids.has(enemy.get_instance_id()): continue
		if absf(enemy.global_position.y - start.y) > Player.TIER_REACH: continue
		var point := Vector3(enemy.global_position.x, start.y, enemy.global_position.z)
		var nearest := Geometry3D.get_closest_point_to_segment(point, start, end)
		var radius := width * 0.5 + (0.6 if enemy == target else 0.0)
		if point.distance_to(nearest) <= radius: struck.append([start.distance_to(nearest), enemy, nearest])
	struck.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	for entry in struck:
		var enemy: Enemy = entry[1]
		hit_ids[enemy.get_instance_id()] = true
		if on_hit.is_valid(): on_hit.call(enemy, self)
		if not pierce or enemy.attack_profile.get("blocks_pierce", false):
			end = entry[2]
			blocked = true
			break
	global_position = end
	travelled += start.distance_to(end)
	if blocked or travelled >= reach - 0.0001: queue_free()
