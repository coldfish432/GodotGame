class_name EnemyAttackVfx
extends Node3D
## Physical marks and fragments appear only when an attack is released.
var game: GameManager
var age := 0.0
var duration := 0.15
var kind := "slash"
var direction := Vector3.RIGHT
var reach := 2.4
var owner_enemy: Enemy
## Enemy weapon trails are rust, never Lappland's white / grey-blue arcs, so a
## swing on screen always says whose it is.
const TRAIL := Color("a24a36")

static func part(parent: Node3D, point: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	node.position = point
	return node

static func stroke(parent: Node3D, start: Vector3, end: Vector3, width: float, color: Color) -> MeshInstance3D:
	var line := part(parent, (start + end) * 0.5, Vector3(width, width, maxf(0.001, start.distance_to(end))), color)
	if start.distance_squared_to(end) > 0.00001: line.basis = Basis.looking_at((end - start).normalized())
	return line

static func spawn(manager: GameManager, point: Vector3, forward: Vector3, type: String, length: float = 2.4) -> EnemyAttackVfx:
	var fx := EnemyAttackVfx.new()
	fx.game = manager
	fx.kind = type
	fx.direction = forward
	fx.reach = length
	manager.add_child(fx)
	fx.global_position = point
	fx._build()
	return fx

func _build() -> void:
	var side := direction.cross(Vector3.UP)
	match kind:
		"cuts":
			duration = 0.15
			for i in range(3):
				var start := side * (i - 1) * 0.22
				stroke(self, start - direction * 0.3, start + direction * 0.5, 0.065, Color("6b2428"))
		"ice":
			duration = 0.3
			for i in range(6):
				var ray := Vector3(cos(i * TAU / 6), 0, sin(i * TAU / 6))
				stroke(self, Vector3.ZERO, ray * 0.8, 0.065, Color("bbdfea"))
				part(self, ray * 0.6 + Vector3.UP * 0.15, Vector3(0.09, 0.14, 0.09), Color("e4eff4"))
		"wood":
			duration = 0.18
			for i in range(4):
				stroke(self, side * (i - 1.5) * 0.12, side * (i - 1.5) * 0.2 - direction * 0.18 + Vector3.UP * 0.12, 0.06, Color("bc9761"))
		"muzzle":
			duration = 0.06
			stroke(self, Vector3.ZERO, direction * 0.27, 0.10, Color("fff3c7"))
		"sector":
			duration = 0.10
			for i in range(12):
				var a := direction.rotated(Vector3.UP, deg_to_rad(-50 + i * 100.0 / 12)) * reach
				var b := direction.rotated(Vector3.UP, deg_to_rad(-50 + (i + 1) * 100.0 / 12)) * reach
				stroke(self, a, b, 0.065, TRAIL)
		"thrust":
			duration = 0.10
			stroke(self, Vector3.ZERO, direction * reach, 0.07, TRAIL)
		"bite":
			# Slug connects: amber originium sparks spray from the jaws.
			duration = 0.16
			for i in range(5):
				var ray := direction.rotated(Vector3.UP, deg_to_rad(-60 + i * 30))
				stroke(self, ray * 0.1, ray * 0.45 + Vector3.UP * 0.1 * (i % 2), 0.07, Color("ffb347"))
		"stab":
			# Fist blade connects: a rust X at the point of impact.
			duration = 0.14
			for tilt in [-45.0, 45.0]:
				var ray := direction.rotated(Vector3.UP, deg_to_rad(tilt))
				stroke(self, -ray * 0.3, ray * 0.3, 0.08, TRAIL)

func _process(delta: float) -> void:
	if not is_instance_valid(game) or not game.simulation_active(): return
	if is_instance_valid(owner_enemy) and owner_enemy.hitstop_remaining > 0: return
	if kind == "thrust" and is_instance_valid(owner_enemy): global_position = owner_enemy.global_position + Vector3.UP * 0.2
	age += delta
	if kind in ["ice", "wood"]:
		for child in get_children():
			if child.position.y > 0.1: child.position += (Vector3.UP + child.position.normalized()) * delta
	if age >= duration: queue_free()
