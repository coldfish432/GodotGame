class_name FirePit
extends Node3D

## 萨米's 火堆 (地图特色策划案 §5.3): a ring of stones round charred birch, a bone
## charm on a stick. Cold until she lights it with E and a piece of fuel from
## the pack; it burns as long as the fuel lasts (FeatureCatalog.FUELS, at most
## FIRE_MAX), and inside FIRE_RADIUS the cold falls. Out, it is cold again and
## can be lit again. No name; the HUD shows only the E key.

const MODEL := "res://art/kit/snow_fire_pit.glb"
const FLAME := Color(1.0, 0.55, 0.18)
## The warm pool of its light on the ground (additive), and how it flickers.
const GLOW := Color(0.95, 0.5, 0.2)
const GLOW_GAIN := 0.55
const FLICKER := 7.0

var burn_left := 0.0
var _flames: CPUParticles3D
var _embers: CPUParticles3D
var _glow: StandardMaterial3D
var _time := 0.0

func _ready() -> void:
	add_to_group("fire_pits")
	if ResourceLoader.exists(MODEL):
		var model := MeshInstance3D.new()
		model.name = "Model"
		model.mesh = TerraceDressing.kit_mesh(load(MODEL))
		add_child(model)
	else:
		_placeholder()
	var halo := TracePoint.halo(FeatureCatalog.FIRE_RADIUS * 2.0)
	halo.name = "Glow"
	_glow = halo.material_override
	_glow.albedo_color = Color.BLACK
	add_child(halo)
	_flames = _particles(18, 0.7, 0.18, Vector2(0.5, 1.1), 0.22, [Color(1.0, 0.85, 0.4, 0.0), Color(1.0, 0.6, 0.2, 0.9), Color(0.8, 0.2, 0.05, 0.0)])
	_flames.name = "Flames"
	_flames.position.y = 0.2
	_embers = _particles(8, 2.2, 0.25, Vector2(0.4, 0.9), 0.05, [Color(1.0, 0.7, 0.3, 0.0), Color(1.0, 0.5, 0.15, 0.9), Color(0.6, 0.15, 0.05, 0.0)])
	_embers.name = "Embers"
	_embers.position.y = 0.35
	_set_lit(false)

## Stones, logs and the charm in plain shapes until the model is in.
func _placeholder() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("6e7378")
	stone.roughness = 1.0
	for i in range(9):
		var rock := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.16
		mesh.height = 0.22
		rock.mesh = mesh
		rock.material_override = stone
		var a := TAU * i / 9.0
		rock.position = Vector3(cos(a) * 0.55, 0.08, sin(a) * 0.55)
		add_child(rock)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("2b2420")
	for i in range(3):
		var stick := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.06
		mesh.bottom_radius = 0.07
		mesh.height = 0.8
		stick.mesh = mesh
		stick.material_override = wood
		stick.position.y = 0.12
		stick.rotation = Vector3(PI / 2.0, TAU * i / 3.0, 0.0)
		add_child(stick)

func _particles(amount: int, lifetime: float, radius: float, speed: Vector2, size: float, ramp: Array) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector3.UP
	p.spread = 15.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = speed.x
	p.initial_velocity_max = speed.y
	var fade := Gradient.new()
	fade.set_color(0, ramp[0])
	fade.add_point(0.3, ramp[1])
	fade.set_color(fade.get_point_count() - 1, ramp[2])
	p.color_ramp = fade
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	# Fog on an additive quad lights its whole square.
	material.disable_fog = true
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = material
	p.mesh = quad
	add_child(p)
	return p

func lit() -> bool:
	return burn_left > 0.0

## Inside its warmth (flat distance).
func warms(at: Vector3) -> bool:
	return Vector2(at.x - global_position.x, at.z - global_position.z).length() <= FeatureCatalog.FIRE_RADIUS

## Fuel on: lit if it was out, burning longer if it was not.
func feed(seconds: float) -> void:
	burn_left = minf(FeatureCatalog.FIRE_MAX, burn_left + seconds)
	_set_lit(true)

func burn(delta: float) -> void:
	if burn_left <= 0.0: return
	burn_left = maxf(0.0, burn_left - delta)
	if burn_left <= 0.0: _set_lit(false)

func _set_lit(on: bool) -> void:
	if _flames != null: _flames.emitting = on
	if _embers != null: _embers.emitting = on
	if _glow != null and not on: _glow.albedo_color = Color.BLACK

func _process(delta: float) -> void:
	if not lit() or _glow == null: return
	_time += delta
	var flicker := 0.85 + 0.1 * sin(_time * FLICKER) + 0.05 * sin(_time * FLICKER * 2.7)
	_glow.albedo_color = GLOW * GLOW_GAIN * flicker
