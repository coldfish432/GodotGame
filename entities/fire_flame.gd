class_name FireFlame
extends MultiMeshInstance3D

## The flames over a burning bottle's fire: short tongues spread over the whole
## patch like burning alcohol (用户 2026-10-30), one MultiMesh card each on
## res://shaders/burning_bottle_fire.gdshader, beside the hazard's Decal scorch.
## The shader turns the cards to the camera. It only reads the hazard:
## `fire_remaining` is lasting / initial lasting, written each physics step
## after the hazard has counted down. It never writes game state and keeps no
## timer of its own.

const SHADER := preload("res://shaders/burning_bottle_fire.gdshader")
## Tongues per square metre of patch, and their size range in metres.
const DENSITY := 2.6
const WIDTH := Vector2(0.6, 0.95)
const HEIGHT := Vector2(0.55, 1.0)
## Share of the tongues that burn to the very end; the rest go out along the way.
const LAST := 0.4

var hazard: GroundHazard
## The hazard's `lasting` before its first countdown; the denominator.
var initial_lasting := 0.0
var _material: ShaderMaterial
var _spots: Array[Vector2] = []

func _init() -> void:
	name = "Flame"
	# The hazard counts down at priority 0; this reads after it.
	process_physics_priority = 10

func _ready() -> void:
	hazard = get_parent() as GroundHazard
	initial_lasting = hazard.lasting
	var r := hazard.radius
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	# Each card stands on its foot.
	quad.center_offset = Vector3(0.0, 0.5, 0.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	var count := maxi(6, roundi(PI * r * r * DENSITY))
	mm.instance_count = count
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# Sunflower spread with a jitter: even cover, no rings.
	for i in range(count):
		var d := r * 0.75 * sqrt((i + 0.5) / count)
		var a := i * 2.39996 + rng.randf_range(-0.4, 0.4)
		var spot := Vector2(cos(a), sin(a)) * d
		_spots.append(spot)
		# Taller in the middle, low at the rim.
		var tall := rng.randf_range(HEIGHT.x, HEIGHT.y) * lerpf(1.0, 0.65, d / r)
		var basis := Basis.from_scale(Vector3(rng.randf_range(WIDTH.x, WIDTH.y), tall, 1.0))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(spot.x, 0.0, spot.y)))
		var out_at := 0.0 if rng.randf() < LAST else rng.randf_range(0.1, 0.85)
		mm.set_instance_custom_data(i, Color(rng.randf(), out_at, 0.0, 0.0))
	multimesh = mm
	# The cards turn in the shader; the box must hold them at any angle.
	custom_aabb = AABB(Vector3(-r - 1.0, -r, -r - 1.0), Vector3(2.0 * r + 2.0, 2.0 * r + 1.0, 2.0 * r + 2.0))
	position.y = 0.04
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Its own material on the shared shader, so each fire keeps its own value.
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("fire_remaining", 1.0)
	material_override = _material
	# spawn_hazard moves the hazard after adding it; stand the tongues on the
	# ground (a ramp) once it is there.
	_follow_ground.call_deferred()

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(hazard) or not is_instance_valid(hazard.game): return
	if not hazard.game.simulation_active(): return
	_material.set_shader_parameter("fire_remaining", clampf(hazard.lasting / initial_lasting, 0.0, 1.0))

func _follow_ground() -> void:
	if not is_inside_tree() or not is_instance_valid(hazard) or not is_instance_valid(hazard.game): return
	var at := global_position
	for i in range(_spots.size()):
		var spot := _spots[i]
		var y := hazard.game.ground_y(Vector3(at.x + spot.x, at.y, at.z + spot.y)) - at.y
		var xf := multimesh.get_instance_transform(i)
		xf.origin.y = clampf(y, -hazard.radius, hazard.radius)
		multimesh.set_instance_transform(i, xf)
