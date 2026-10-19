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
## Arts damage whatever it looks like (家族弩手's bolts in the 清算时刻).
var arts := false

## 清算时刻 (叙拉古敌人设计案 §三第 3 条): the bolt is arts, tinted pale violet
## with a 1 px trail.
func make_arts() -> void:
	arts = true
	for child in get_children():
		if child is MeshInstance3D: (child as MeshInstance3D).material_override.albedo_color = Color("c8a8f0")
	EnemyAttackVfx.stroke(self, -direction * 14 * Enemy.PIXEL, -direction * 8 * Enemy.PIXEL, Enemy.PIXEL, Color(0.78, 0.66, 0.94, 0.6)).material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

func _ready() -> void:
	speed = 22.0 if kind == "bullet" else 12.0
	var pixel := Enemy.PIXEL
	if kind == "ice_orb":
		# 陷落雪祀: a 4×4 orb, purple rim round a pale blue core, and a 3 px
		# snowflake trail (新敌人攻击案 §三第 17 条).
		EnemyAttackVfx.part(self, Vector3.ZERO, Vector3.ONE * 4 * pixel, Color("8a5ad0"))
		EnemyAttackVfx.part(self, Vector3.ZERO, Vector3.ONE * 2 * pixel + Vector3(0, 0, 2.2 * pixel), Color("d8f0ff"))
		EnemyAttackVfx.part(self, Vector3.ZERO, Vector3(2 * pixel, 4.2 * pixel, 2 * pixel), Color("d8f0ff"))
		EnemyAttackVfx.stroke(self, -direction * 5 * pixel, -direction * 2 * pixel, pixel, Color("eef6ff"))
		EnemyAttackVfx.part(self, -direction * 4 * pixel + Vector3.UP * pixel, Vector3.ONE * pixel, Color("eef6ff"))
		EnemyAttackVfx.part(self, -direction * 4 * pixel + Vector3.DOWN * pixel, Vector3.ONE * pixel, Color("eef6ff"))
	elif kind == "bullet":
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
				# An arts caster's orb is arts damage; arrows and bullets physical.
				var damage_kind := "arts" if arts else (shooter.damage_kind if is_instance_valid(shooter) and kind == "ice_orb" else "phys")
				game.player.take_damage(damage, damage_kind, shooter if is_instance_valid(shooter) else null)
				queue_free()
				return
		global_position = next
		travelled += distance
		remaining -= distance
	if travelled >= max_range - 0.0001: queue_free()
