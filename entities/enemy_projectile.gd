class_name EnemyProjectile
extends Node3D
## Straight physical projectiles; swept collision prevents fast bullets tunneling.
var direction := Vector3.FORWARD
var damage := 1.0
var kind := "arrow"
var speed := 12.0
var hit_radius := 0.5
var max_range := 12.0
var travelled := 0.0
var game: GameManager
## Who fired it, so retaliation (坚壁 4) knows where to answer.
var shooter: Enemy

func _ready() -> void:
	speed = 22.0 if kind == "bullet" else 12.0
	var pixel := Enemy.PIXEL
	if kind == "bullet":
		EnemyAttackVfx.stroke(self, -direction * 8 * pixel, Vector3.ZERO, pixel, Color("f4f6f4"))
	else:
		EnemyAttackVfx.stroke(self, -direction * 8 * pixel, -direction * 6 * pixel, pixel, Color("aaa69b"))
		# Light shaft: a dark one vanished against the city's dark asphalt.
		EnemyAttackVfx.stroke(self, -direction * 6 * pixel, Vector3.ZERO, pixel, Color("d9c08c"))
		EnemyAttackVfx.stroke(self, -direction * pixel, direction * pixel, pixel, Color("f6f1df"))

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game) or not game.simulation_active(): return
	var remaining := minf(speed * delta, max_range - travelled)
	# Short substeps give walls priority without missing a nearer player.
	while remaining > 0.00001:
		var distance := minf(0.08, remaining)
		var next := global_position + direction * distance
		if not game.line_of_sight(global_position, next):
			if kind == "arrow": EnemyAttackVfx.spawn(game, global_position, direction, "wood")
			queue_free()
			return
		if is_instance_valid(game.player):
			var a := Vector2(global_position.x, global_position.z)
			var b := Vector2(next.x, next.z)
			var player := Vector2(game.player.global_position.x, game.player.global_position.z)
			if Geometry2D.get_closest_point_to_segment(player, a, b).distance_to(player) <= hit_radius:
				game.player.take_damage(damage, "phys", shooter if is_instance_valid(shooter) else null)
				queue_free()
				return
		global_position = next
		travelled += distance
		remaining -= distance
	if travelled >= max_range - 0.0001: queue_free()
