class_name StatusLines
extends Node3D
## The buff / debuff ring on one figure (GPU粒子特效推广策划案 v0.6 §7a P6).
## Child of the figure, at its feet; the lines themselves are left in the world
## (local_coords off) so they do not jump when she does. `show_state(up, down)`
## turns the rising and the falling lines on or off; however many buffs or
## debuffs, there is only ever this one layer of each. `fit(radius, height)`
## sizes the ring to the figure (process materials cached per size).

var _radius := -1.0
var _height := -1.0

func up() -> GPUParticles3D: return get_node("Up") as GPUParticles3D
func down() -> GPUParticles3D: return get_node("Down") as GPUParticles3D

func show_state(rising: bool, falling: bool) -> void:
	if up().emitting != rising: up().emitting = rising
	if down().emitting != falling: down().emitting = falling

func active() -> bool:
	return up().emitting or down().emitting

func fit(radius: float, height: float) -> void:
	radius = snappedf(radius, 0.05)
	height = snappedf(height, 0.1)
	if is_equal_approx(radius, _radius) and is_equal_approx(height, _height): return
	_radius = radius
	_height = height
	for p in [up(), down()]:
		var key := "status:%s:%.2f" % [p.name, radius]
		if not GpuFx.cache.has(key):
			var m := (p.process_material as ParticleProcessMaterial).duplicate() as ParticleProcessMaterial
			m.emission_ring_radius = radius
			m.emission_ring_inner_radius = radius * 0.94
			GpuFx.cache[key] = m
		p.process_material = GpuFx.cache[key]
	down().position.y = height
	# The lines run about the figure's height.
	for p in [up(), down()]:
		p.speed_scale = clampf(height / 1.9, 0.6, 1.6)

func _process(_delta: float) -> void:
	if not active(): return
	var feet := global_position
	up().set_instance_shader_parameter("centre", feet)
	down().set_instance_shader_parameter("centre", feet)
