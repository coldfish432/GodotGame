class_name ShowerPoint
extends Node3D

## 矿区's 净化喷淋点 (地图特色策划案 §3.3): a steel frame with a shower head, a
## water tank and yellow-black hazard bands, its cyan lamp lit while it still
## works. E held FeatureCatalog.SHOWER_SECONDS beside it: contamination
## −SHOWER_CUT, once; then the lamp goes out. No name; only the E key.

const MODEL := "res://art/kit/mine_decon_shower.glb"
const LAMP := Color(0.35, 0.9, 1.0)
const LAMP_GAIN := 0.4

var used := false
var _lamp: StandardMaterial3D
var _spray: CPUParticles3D

func _ready() -> void:
	add_to_group("shower_points")
	if ResourceLoader.exists(MODEL):
		var model := MeshInstance3D.new()
		model.name = "Model"
		model.mesh = TerraceDressing.kit_mesh(load(MODEL))
		add_child(model)
	else:
		_placeholder()
	var halo := TracePoint.halo(2.4)
	halo.name = "Lamp"
	_lamp = halo.material_override
	_lamp.albedo_color = LAMP * LAMP_GAIN
	add_child(halo)
	_spray = CPUParticles3D.new()
	_spray.name = "Spray"
	_spray.amount = 40
	_spray.lifetime = 0.6
	_spray.emitting = false
	_spray.position = Vector3(0.0, 2.35, 0.5)
	_spray.direction = Vector3.DOWN
	_spray.spread = 18.0
	_spray.initial_velocity_min = 2.0
	_spray.initial_velocity_max = 3.2
	var drop := QuadMesh.new()
	drop.size = Vector2(0.04, 0.12)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.7, 0.95, 1.0, 0.6)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	drop.material = material
	_spray.mesh = drop
	add_child(_spray)

func _placeholder() -> void:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("5c6066")
	steel.metallic = 0.6
	for x in [-0.5, 0.5]:
		var post := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.1, 2.4, 0.1)
		post.mesh = mesh
		post.material_override = steel
		post.position = Vector3(x, 1.2, 0)
		add_child(post)
	var top := MeshInstance3D.new()
	var bar := BoxMesh.new()
	bar.size = Vector3(1.2, 0.1, 0.1)
	top.mesh = bar
	top.material_override = steel
	top.position.y = 2.35
	add_child(top)
	var hazard := StandardMaterial3D.new()
	hazard.albedo_color = Color("e0b020")
	var tank := MeshInstance3D.new()
	var drum := CylinderMesh.new()
	drum.top_radius = 0.3
	drum.bottom_radius = 0.3
	drum.height = 0.9
	tank.mesh = drum
	tank.material_override = hazard
	tank.position = Vector3(0.9, 0.45, 0)
	add_child(tank)

## Showering: the spray runs while she holds it.
func spraying(on: bool) -> void:
	if _spray != null and not used: _spray.emitting = on

func use() -> void:
	used = true
	if _spray != null: _spray.emitting = false
	if _lamp != null: _lamp.albedo_color = Color.BLACK
