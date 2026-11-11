class_name HitSpark
extends Node3D
## The landed-hit burst (GPU粒子特效推广策划案 v0.6 §3 P0b; A6 Effect A). One
## scene, three one-shot emitters (Flash, Sparks, Puff). Every operator's hit
## uses it, tinted from her OperatorVfx palette, with a style for how it lands:
##   melee  the A6 throw (sparks spray out, droop under gravity);
##   ranged small, fast chips thrown along the shot's direction;
##   arts   light motes, no gravity, drifting out slower.
## A crit fills the emitters (amount_ratio 1) and is a third larger.
## Each burst is a new instance under the GameManager (overlap, never parented
## to the enemy); it frees itself after FREE_AFTER. At most LIMIT alive.

const SCENE := preload("res://effects/hit_spark.tscn")
const FREE_AFTER := 0.55
const LIMIT := 8
const GROUP := &"hit_spark"
## Share of the scene's particle counts on an ordinary hit; a crit uses all.
const NORMAL_RATIO := 0.7
const CRIT_SCALE := 1.3

var _age := 0.0

## Spawns one burst at `at` (world). `palette_id` is an OperatorVfx palette key
## ("" keeps the A6 white-orange look). Returns null when the cap is reached.
static func spawn(game: Node3D, at: Vector3, palette_id: String = "", crit: bool = false, style: String = "melee", direction: Vector3 = Vector3.UP) -> HitSpark:
	if not is_instance_valid(game) or not game.is_inside_tree(): return null
	if game.get_tree().get_nodes_in_group(GROUP).size() >= LIMIT: return null
	var burst := SCENE.instantiate() as HitSpark
	burst.add_to_group(GROUP)
	var mats := _materials(palette_id, style)
	for child in burst.get_children():
		var p := child as GPUParticles3D
		if p == null: continue
		if mats.has(String(p.name)): p.process_material = mats[String(p.name)]
		p.amount_ratio = 1.0 if crit else NORMAL_RATIO
	# Placed before it enters the tree, so it is where it belongs from its first frame.
	var basis := Basis.IDENTITY
	# The emitters throw along local +Y; ranged chips fly on along the shot.
	var up := direction.normalized() if style == "ranged" and direction.length_squared() > 0.001 else Vector3.UP
	var axis := Vector3.UP.cross(up)
	if axis.length_squared() > 1e-6: basis = Basis(axis.normalized(), Vector3.UP.angle_to(up))
	if crit: basis = basis.scaled(Vector3.ONE * CRIT_SCALE)
	burst.transform = game.global_transform.affine_inverse() * Transform3D(basis, at)
	game.add_child(burst)
	return burst

func _ready() -> void:
	for child in get_children():
		if child is GPUParticles3D:
			(child as GPUParticles3D).restart()

func _process(delta: float) -> void:
	_age += delta
	if _age >= FREE_AFTER:
		queue_free()

## Process materials per palette and style, made once from the scene's own
## (GpuFx keeps them; GameManager.release_static_caches clears them).
static func _materials(palette_id: String, style: String) -> Dictionary:
	var key := "hit:%s:%s" % [palette_id, style]
	if GpuFx.cache.has(key): return GpuFx.cache[key]
	var out := {}
	if palette_id == "" and style == "melee":
		GpuFx.cache[key] = out
		return out
	var probe := SCENE.instantiate()
	var palette: Dictionary = OperatorVfx.PALETTES.get(palette_id, {})
	for child in probe.get_children():
		var p := child as GPUParticles3D
		if p == null: continue
		var m := (p.process_material as ParticleProcessMaterial).duplicate() as ParticleProcessMaterial
		var main: Color = palette.get("main", Color(1, 0.6, 0.15))
		var hot: Color = palette.get("hot", Color(1, 1, 0.9))
		var dark: Color = palette.get("dark", Color(0.16, 0.15, 0.18))
		match String(p.name):
			"Flash":
				if not palette.is_empty(): m.color_ramp = GpuFx.ramp([Color(1, 1, 1, 1), Color(hot.r, hot.g, hot.b, 0.0)])
			"Sparks":
				if not palette.is_empty(): m.color_ramp = GpuFx.ramp([Color(hot.r, hot.g, hot.b, 1), Color(main.r, main.g, main.b, 1), Color(dark.r, dark.g, dark.b, 0)], [0.0, 0.4, 1.0])
				match style:
					"ranged":
						m.spread = 35.0
						m.initial_velocity_min = 4.0
						m.initial_velocity_max = 8.0
						m.scale_min = 0.4
						m.scale_max = 0.8
					"arts":
						m.gravity = Vector3.ZERO
						m.initial_velocity_min = 1.5
						m.initial_velocity_max = 3.0
						m.damping_min = 2.0
						m.damping_max = 3.0
						m.scale_min = 0.8
						m.scale_max = 1.4
			"Puff":
				if not palette.is_empty(): m.color_ramp = GpuFx.ramp([Color(dark.r, dark.g, dark.b, 0.5), Color(dark.r, dark.g, dark.b, 0.0)])
		out[String(p.name)] = m
	probe.free()
	GpuFx.cache[key] = out
	return out
