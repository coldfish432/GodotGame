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
## The flames and embers (GPU particles; every setting lives in the scene).
const FLAMES_SCENE := preload("res://effects/fire_pit_flames.tscn")
## Fuel at or above this shows the full fire; below it the flames thin, down to
## LOW_RATIO at the last second (CHANGE-BRIEF.md Effect B, feedback mapping).
const FULL_FIRE := 120.0
const LOW_RATIO := 0.3

var burn_left := 0.0
var _emitters: Array[GPUParticles3D] = []
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
	var flames := FLAMES_SCENE.instantiate()
	add_child(flames)
	for child in flames.get_children():
		if child is GPUParticles3D: _emitters.append(child)
	# A pit already holding fuel when it enters the tree burns from its first frame.
	_set_lit(lit())

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
	else: _show_fuel()

func _set_lit(on: bool) -> void:
	_show_fuel()
	if _glow != null and not on: _glow.albedo_color = Color.BLACK

## Presentation only, read from burn_left (never written here): the flames burn
## while there is fuel, and thin below FULL_FIRE. `amount` is never touched (it
## would restart the buffer); a fire lit from cold restarts so the scene's
## preprocess shows it full at once.
func _show_fuel() -> void:
	var on := burn_left > 0.0
	var ratio := LOW_RATIO + (1.0 - LOW_RATIO) * clampf(burn_left / FULL_FIRE, 0.0, 1.0)
	for p in _emitters:
		p.amount_ratio = ratio
		if on and not p.emitting: p.restart()
		elif p.emitting != on: p.emitting = on

func _process(delta: float) -> void:
	if not lit() or _glow == null: return
	_time += delta
	var flicker := 0.85 + 0.1 * sin(_time * FLICKER) + 0.05 * sin(_time * FLICKER * 2.7)
	_glow.albedo_color = GLOW * GLOW_GAIN * flicker
