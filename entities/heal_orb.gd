class_name HealOrb
extends Node3D

## 用户 2026-10-14: 敌人概率掉落治疗球立即回复血量. A green orb pops out of a
## fallen enemy (LootTables.HEAL_ORBS); it drifts to her when she comes near
## and heals `fraction` of her life the moment it touches her. Fades after
## LIFETIME.

const LIFETIME := 25.0
## She draws it in from this far, and takes it at TOUCH.
const ATTRACT := 2.5
const TOUCH := 0.6
const PULL_SPEED := 9.0
const FLY_SECONDS := 0.35
const COLOUR := Color(0.35, 1.0, 0.45)

var game: GameManager
var fraction := 0.12
var from := Vector3.INF
var _rest := Vector3.ZERO
var _age := 0.0
var _core: MeshInstance3D
var _halo: MeshInstance3D

func _ready() -> void:
	add_to_group("heal_orbs")
	_rest = global_position
	if from != Vector3.INF: global_position = from
	_core = _ball(0.16, COLOUR.lightened(0.3), 0.95)
	_halo = _ball(0.3, COLOUR, 0.35)

func _ball(radius: float, colour: Color, alpha: float) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(colour, alpha)
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	part.position = Vector3.UP * 0.35
	add_child(part)
	return part

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game) or not game.simulation_active(): return
	_age += delta
	if _age < FLY_SECONDS:
		var f := _age / FLY_SECONDS
		global_position = from.lerp(_rest, f) + Vector3.UP * sin(f * PI) * 0.8 if from != Vector3.INF else _rest
		return
	var bob := sin(_age * 4.0) * 0.06
	_core.position.y = 0.35 + bob
	_halo.position.y = 0.35 + bob
	_halo.scale = Vector3.ONE * (1.0 + sin(_age * 6.0) * 0.12)
	if _age > LIFETIME - 2.0: visible = fmod(_age, 0.25) < 0.15
	if _age > LIFETIME:
		queue_free()
		return
	var player := game.player
	if not is_instance_valid(player) or player.hp <= 0.0: return
	var to := player.global_position - global_position
	to.y = 0.0
	var distance := to.length()
	if distance <= TOUCH:
		_take()
	elif distance <= ATTRACT:
		var step := minf(distance, PULL_SPEED * delta)
		global_position += to.normalized() * step
		global_position.y = game.ground_y(global_position)

func _take() -> void:
	game.player.heal(game.player.max_hp * fraction, true)
	game.sound.play("loot")
	queue_free()
