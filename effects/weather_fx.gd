class_name WeatherFx
extends Node3D
## The floor's falling snow or rain (GPU粒子特效推广策划案 v0.6 §5.1), one
## scene per kind (effects/snowfall.tscn, effects/rainfall.tscn). It rides
## above her view (GameManager moves it). FieldWeather sets how hard it falls
## (`intensity`, the Fall/Rain layer's amount_ratio) and, in the snow, how far
## a blizzard has come (`blizzard`, the Driving and Near layers). Each instance
## owns its process materials, so BossShow's storm can lean the wind.

var intensity := 1.0
var blizzard := 0.0
var _calm_gravity := {}

func _ready() -> void:
	for child in get_children():
		var p := child as GPUParticles3D
		if p == null: continue
		p.process_material = p.process_material.duplicate()
		_calm_gravity[p.name] = (p.process_material as ParticleProcessMaterial).gravity
	apply()

func layer(name: String) -> GPUParticles3D:
	return get_node_or_null(name) as GPUParticles3D

## Pushes intensity and blizzard onto the layers (amount stays; only the ratio moves).
func apply() -> void:
	var fall := layer("Fall") if has_node("Fall") else layer("Rain")
	if fall != null: fall.amount_ratio = clampf(intensity * (1.0 - 0.6 * blizzard), 0.0, 1.0)
	for name in ["Driving", "Near"]:
		var p := layer(name)
		if p == null: continue
		p.amount_ratio = clampf(blizzard, 0.0, 1.0)
		p.speed_scale = 0.5 + 0.5 * clampf(blizzard, 0.0, 1.0)

var emitting: bool:
	get:
		var fall := layer("Fall") if has_node("Fall") else layer("Rain")
		return fall != null and fall.emitting
	set(value):
		for child in get_children():
			var p := child as GPUParticles3D
			if p != null and String(p.name) != "Splash": p.emitting = value

## BossShow's storm: `level` 0 calm, 1 a gale, 2 a gust. Faster and leaning.
func storm(level: float) -> void:
	for child in get_children():
		var p := child as GPUParticles3D
		if p == null or String(p.name) == "Splash": continue
		p.speed_scale = 1.0 + 0.6 * level
		var g: Vector3 = _calm_gravity.get(p.name, Vector3.ZERO)
		(p.process_material as ParticleProcessMaterial).gravity = Vector3(g.x + 2.2 * level, g.y, g.z + 0.6 * level)

func storm_level() -> float:
	var fall := layer("Fall") if has_node("Fall") else layer("Rain")
	return (fall.speed_scale - 1.0) / 0.6 if fall != null else 0.0
