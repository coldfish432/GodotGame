class_name Molotov
extends Node3D
## 燃烧瓶投掷者's bottle (新敌人攻击动画与预警设计案 §三第 8 条): a 3×5 px bottle
## with a 2 px flame on the rag, lobbed in an arc to the marked spot over
## FLIGHT seconds with a shadow shrinking under it. It shatters there: a hit on
## whoever stands in the circle, then a patch of fire (GroundHazard).

const FLIGHT := 0.6
## Highest point above the straight line, in world units.
const APEX := 2.0
const P := 1.0 / 15.0

var game: GameManager
var source: Enemy
var start := Vector3.ZERO
var target := Vector3.ZERO
var radius := 1.3
var damage := 100.0
var kind := "arts"
var fire_time := 3.0
var fire_damage := 20.0
## The red circle at the landing spot; cleared when it lands.
var warning: CombatMarker
var age := 0.0
var _bottle: Node3D
var _shadow: MeshInstance3D

func _ready() -> void:
	_bottle = Node3D.new()
	add_child(_bottle)
	EnemyAttackVfx.part(_bottle, Vector3.ZERO, Vector3(3 * P, 5 * P, 3 * P), Color("5a7a4a"))
	EnemyAttackVfx.part(_bottle, Vector3.UP * 3 * P, Vector3(P, P, P), Color("d8c8a0"))
	EnemyAttackVfx.part(_bottle, Vector3.UP * 4.5 * P, Vector3(P, 2 * P, P), Color("ffb040"))
	_shadow = EnemyAttackVfx.part(self, Vector3.ZERO, Vector3(4 * P, 0.01, 3 * P), Color(0.05, 0.05, 0.06))
	var shade := _shadow.material_override as StandardMaterial3D
	shade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shade.albedo_color.a = 0.45
	global_position = Vector3.ZERO
	_place()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game) or not game.simulation_active(): return
	age += delta
	if age >= FLIGHT:
		_land()
		return
	_place()

func _place() -> void:
	var t := clampf(age / FLIGHT, 0.0, 1.0)
	var ground := start.lerp(target, t)
	ground.y = game.ground_y(ground)
	var height := lerpf(start.y - game.ground_y(start), 0.0, t) + APEX * 4.0 * t * (1.0 - t)
	_bottle.position = ground + Vector3.UP * height
	_bottle.rotation.z = t * TAU * 1.5
	_shadow.position = ground + Vector3.UP * 0.05
	_shadow.scale = Vector3.ONE * lerpf(0.6, 1.0, 1.0 - height / (APEX + 0.5))

func _land() -> void:
	if is_instance_valid(warning): warning.queue_free()
	var at := Vector3(target.x, game.ground_y(target), target.z)
	CombatVfx.spawn(game, at + Vector3.UP * 0.09, Vector3.FORWARD, "burst", 0, true)
	game.sound.play("molotov_shatter")
	if is_instance_valid(game.player) and Vector2(game.player.global_position.x - at.x, game.player.global_position.z - at.z).length() <= radius:
		game.player.take_damage(damage, kind, source if is_instance_valid(source) else null)
	if fire_time > 0.0:
		game.spawn_hazard(at, radius, 0.0, fire_time, fire_damage, "arts", false, source if is_instance_valid(source) else null)
	queue_free()
