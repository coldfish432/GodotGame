extends SceneTree
## Effect A config test (CHANGE-BRIEF.md, Effect A "Settings"). Loads
## res://effects/hit_spark.tscn and reads every setting the brief names back
## from the loaded resources, with the brief's values as the expected values.
## Run: ./scripts/run-test.sh test_hit_spark_config.gd 60

const SCENE := "res://effects/hit_spark.tscn"
const EPS := 1e-4

var checks := 0
var failures: Array[String] = []

# The brief's table, one column per emitter.
const EXPECT := {
	"Flash": {
		"amount": 1, "lifetime": 0.10, "randomness": 0.0,
		"shape": ParticleProcessMaterial.EMISSION_SHAPE_POINT, "radius": -1.0,
		"direction": Vector3(0, 1, 0), "spread": 0.0,
		"velocity": [0.0, 0.0], "gravity": Vector3(0, 0, 0), "damping": [0.0, 0.0],
		"scale": [1.0, 1.0], "scale_curve": [[0.0, 1.0], [1.0, 0.3]],
		"ramp": [[0.0, Color(1, 1, 1, 1)], [1.0, Color(1, 0.85, 0.5, 0)]],
		"hue": [0.0, 0.0], "angle": [0.0, 0.0], "quad": Vector2(0.9, 0.9),
		"blend": BaseMaterial3D.BLEND_MODE_ADD, "aabb": AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2)),
	},
	"Sparks": {
		"amount": 14, "lifetime": 0.35, "randomness": 0.4,
		"shape": ParticleProcessMaterial.EMISSION_SHAPE_SPHERE, "radius": 0.10,
		"direction": Vector3(0, 1, 0), "spread": 180.0,
		"velocity": [3.0, 6.0], "gravity": Vector3(0, -9.8, 0), "damping": [6.0, 10.0],
		"scale": [0.6, 1.2], "scale_curve": [[0.0, 1.0], [1.0, 0.0]],
		"ramp": [[0.0, Color(1, 1, 0.9, 1)], [0.4, Color(1, 0.6, 0.15, 1)], [1.0, Color(0.6, 0.1, 0.02, 0)]],
		"hue": [-0.03, 0.03], "angle": [0.0, 0.0], "quad": Vector2(0.12, 0.12),
		"blend": BaseMaterial3D.BLEND_MODE_ADD, "aabb": AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4)),
	},
	"Puff": {
		"amount": 4, "lifetime": 0.45, "randomness": 0.2,
		"shape": ParticleProcessMaterial.EMISSION_SHAPE_SPHERE, "radius": 0.15,
		"direction": Vector3(0, 1, 0), "spread": 180.0,
		"velocity": [0.4, 0.9], "gravity": Vector3(0, 0.6, 0), "damping": [1.0, 1.0],
		"scale": [0.8, 1.2], "scale_curve": [[0.0, 0.6], [1.0, 1.4]],
		"ramp": [[0.0, Color(0.16, 0.15, 0.18, 0.55)], [1.0, Color(0.16, 0.15, 0.18, 0)]],
		"hue": [0.0, 0.0], "angle": [0.0, 360.0], "quad": Vector2(1.0, 1.0),  # r1 (2026-11-07), was 0.5
		"blend": BaseMaterial3D.BLEND_MODE_MIX, "aabb": AABB(Vector3(-1.5, -1, -1.5), Vector3(3, 3, 3)),
	},
}

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)
		print("FAIL ", what)

func near(a: float, b: float) -> bool:
	return absf(a - b) <= EPS

func near_v3(a: Vector3, b: Vector3) -> bool:
	return near(a.x, b.x) and near(a.y, b.y) and near(a.z, b.z)

func near_c(a: Color, b: Color) -> bool:
	return near(a.r, b.r) and near(a.g, b.g) and near(a.b, b.b) and near(a.a, b.a)

func run() -> void:
	var packed := load(SCENE) as PackedScene
	check(packed != null, "scene loads: %s" % SCENE)
	if packed == null:
		finish()
		return
	var root := packed.instantiate()
	check(root is Node3D, "root is Node3D (got %s)" % root.get_class())
	check(root.name == "HitSpark", "root named HitSpark (got %s)" % root.name)
	var script := root.get_script() as Script
	check(script != null and script.resource_path == "res://effects/hit_spark.gd", "root script is res://effects/hit_spark.gd")
	if script != null:
		var consts := script.get_script_constant_map()
		check(consts.has("FREE_AFTER") and near(float(consts.FREE_AFTER), 0.55), "root frees itself after 0.55 s (Revisions r1 b), got %s" % str(consts.get("FREE_AFTER")))
	var emitters: Array = []
	for child in root.get_children():
		if child is GPUParticles3D: emitters.append(String(child.name))
	check(emitters == ["Flash", "Sparks", "Puff"], "exactly three GPUParticles3D children Flash, Sparks, Puff (got %s)" % str(emitters))
	for emitter_name in EXPECT:
		var node := root.get_node_or_null(NodePath(emitter_name))
		check(node is GPUParticles3D, "%s is GPUParticles3D" % emitter_name)
		if node is GPUParticles3D:
			check_emitter(node, EXPECT[emitter_name])
	root.free()
	finish()

func check_emitter(p: GPUParticles3D, e: Dictionary) -> void:
	var n := String(p.name)
	# Shared emission settings.
	check(p.emitting == false, "%s emitting false in the scene" % n)
	check(p.one_shot == true, "%s one_shot true" % n)
	check(near(p.explosiveness, 1.0), "%s explosiveness 1.0 (got %s)" % [n, p.explosiveness])
	check(p.local_coords == false, "%s local_coords false" % n)
	check(p.fixed_fps == 0, "%s fixed_fps 0 (got %d)" % [n, p.fixed_fps])
	check(p.interpolate == true, "%s interpolate true" % n)
	check(p.use_fixed_seed == false, "%s use_fixed_seed false" % n)
	check(near(p.preprocess, 0.0), "%s preprocess 0.0 (got %s)" % [n, p.preprocess])
	# Per-emitter table.
	check(p.amount == int(e.amount), "%s amount %d (got %d)" % [n, e.amount, p.amount])
	check(near(p.lifetime, e.lifetime), "%s lifetime %s (got %s)" % [n, e.lifetime, p.lifetime])
	check(near(p.randomness, e.randomness), "%s randomness %s (got %s)" % [n, e.randomness, p.randomness])
	var aabb: AABB = e.aabb
	check(near_v3(p.visibility_aabb.position, aabb.position) and near_v3(p.visibility_aabb.size, aabb.size), "%s visibility_aabb %s (got %s)" % [n, aabb, p.visibility_aabb])
	# Process material.
	var m := p.process_material as ParticleProcessMaterial
	check(m != null, "%s process_material is ParticleProcessMaterial (got %s)" % [n, p.process_material])
	if m != null:
		check(m.particle_flag_disable_z == false, "%s particle_flag_disable_z false" % n)
		check(m.emission_shape == int(e.shape), "%s emission_shape %d (got %d)" % [n, e.shape, m.emission_shape])
		if e.radius >= 0.0:
			check(near(m.emission_sphere_radius, e.radius), "%s emission_sphere_radius %s (got %s)" % [n, e.radius, m.emission_sphere_radius])
		check(near_v3(m.direction, e.direction), "%s direction %s (got %s)" % [n, e.direction, m.direction])
		check(near(m.spread, e.spread), "%s spread %s (got %s)" % [n, e.spread, m.spread])
		check(near(m.initial_velocity_min, e.velocity[0]) and near(m.initial_velocity_max, e.velocity[1]), "%s initial_velocity_min/max %s (got %s, %s)" % [n, e.velocity, m.initial_velocity_min, m.initial_velocity_max])
		check(near_v3(m.gravity, e.gravity), "%s gravity %s (got %s)" % [n, e.gravity, m.gravity])
		check(near(m.damping_min, e.damping[0]) and near(m.damping_max, e.damping[1]), "%s damping_min/max %s (got %s, %s)" % [n, e.damping, m.damping_min, m.damping_max])
		check(near(m.scale_min, e.scale[0]) and near(m.scale_max, e.scale[1]), "%s scale_min/max %s (got %s, %s)" % [n, e.scale, m.scale_min, m.scale_max])
		check(near(m.hue_variation_min, e.hue[0]) and near(m.hue_variation_max, e.hue[1]), "%s hue_variation_min/max %s (got %s, %s)" % [n, e.hue, m.hue_variation_min, m.hue_variation_max])
		check(near(m.angle_min, e.angle[0]) and near(m.angle_max, e.angle[1]), "%s angle_min/max %s (got %s, %s)" % [n, e.angle, m.angle_min, m.angle_max])
		# scale_curve: a CurveTexture whose curve has exactly the brief's points.
		var ct := m.scale_curve as CurveTexture
		check(ct != null and ct.curve != null, "%s scale_curve is a CurveTexture with a Curve" % n)
		if ct != null and ct.curve != null:
			var c := ct.curve
			check(c.point_count == e.scale_curve.size(), "%s scale_curve has %d points (got %d)" % [n, e.scale_curve.size(), c.point_count])
			for i in range(mini(c.point_count, e.scale_curve.size())):
				var want: Array = e.scale_curve[i]
				var got := c.get_point_position(i)
				check(near(got.x, want[0]) and near(got.y, want[1]), "%s scale_curve point %d = %s (got %s)" % [n, i, want, got])
				check(near(c.sample(want[0]), want[1]), "%s scale_curve sample(%s) = %s (got %s)" % [n, want[0], want[1], c.sample(want[0])])
		# color_ramp: a GradientTexture1D whose gradient has exactly the brief's stops.
		var rt := m.color_ramp as GradientTexture1D
		check(rt != null and rt.gradient != null, "%s color_ramp is a GradientTexture1D with a Gradient" % n)
		if rt != null and rt.gradient != null:
			var g := rt.gradient
			check(g.get_point_count() == e.ramp.size(), "%s color_ramp has %d stops (got %d)" % [n, e.ramp.size(), g.get_point_count()])
			for i in range(mini(g.get_point_count(), e.ramp.size())):
				var stop: Array = e.ramp[i]
				check(near(g.get_offset(i), stop[0]) and near_c(g.get_color(i), stop[1]), "%s color_ramp stop %d = %s (got %s %s)" % [n, i, stop, g.get_offset(i), g.get_color(i)])
	# Draw pass.
	var q := p.draw_pass_1 as QuadMesh
	check(q != null, "%s draw_pass_1 is QuadMesh (got %s)" % [n, p.draw_pass_1])
	if q == null: return
	check(near(q.size.x, e.quad.x) and near(q.size.y, e.quad.y), "%s QuadMesh size %s (got %s)" % [n, e.quad, q.size])
	var mat := q.material as StandardMaterial3D
	check(mat != null, "%s QuadMesh material is StandardMaterial3D (got %s)" % [n, q.material])
	if mat == null: return
	check(mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "%s shading_mode UNSHADED (got %d)" % [n, mat.shading_mode])
	check(mat.billboard_mode == BaseMaterial3D.BILLBOARD_PARTICLES, "%s billboard_mode BILLBOARD_PARTICLES (got %d)" % [n, mat.billboard_mode])
	check(mat.vertex_color_use_as_albedo == true, "%s vertex_color_use_as_albedo true" % n)
	check(mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "%s transparency TRANSPARENCY_ALPHA (got %d)" % [n, mat.transparency])
	check(mat.disable_fog == true, "%s disable_fog true" % n)
	check(mat.blend_mode == int(e.blend), "%s blend_mode %d (got %d)" % [n, e.blend, mat.blend_mode])
	var tex := mat.albedo_texture as GradientTexture2D
	check(tex != null, "%s albedo_texture is GradientTexture2D (got %s)" % [n, mat.albedo_texture])
	if tex == null: return
	check(tex.resource_path == "" or tex.resource_path.begins_with(SCENE + "::"), "%s albedo_texture written in the scene, not a file (path '%s')" % [n, tex.resource_path])
	check(tex.fill == GradientTexture2D.FILL_RADIAL, "%s albedo_texture fill FILL_RADIAL (got %d)" % [n, tex.fill])
	check(tex.width == 32 and tex.height == 32, "%s albedo_texture 32x32 (got %dx%d)" % [n, tex.width, tex.height])
	var tg := tex.gradient
	check(tg != null, "%s albedo_texture has a Gradient" % n)
	if tg != null:
		var last := tg.get_point_count() - 1
		check(near(tg.get_offset(0), 0.0) and near_c(tg.get_color(0), Color(1, 1, 1, 1)), "%s albedo gradient starts white opaque at the centre (got %s %s)" % [n, tg.get_offset(0), tg.get_color(0)])
		check(near(tg.get_offset(last), 1.0) and near(tg.get_color(last).a, 0.0), "%s albedo gradient ends transparent at the edge (got %s %s)" % [n, tg.get_offset(last), tg.get_color(last)])
	# Radial fill from the texture's centre to its edge: centre at fill_from, radius reaching the side.
	check(tex.fill_from.is_equal_approx(Vector2(0.5, 0.5)), "%s albedo_texture fill_from centre (0.5,0.5) (got %s)" % [n, tex.fill_from])
	check(near(tex.fill_from.distance_to(tex.fill_to), 0.5), "%s albedo_texture radius reaches the edge (|fill_to-fill_from| 0.5, got %s)" % [n, tex.fill_from.distance_to(tex.fill_to)])

func finish() -> void:
	print("test_hit_spark_config: %d checks, %d failed" % [checks, failures.size()])
	if failures.is_empty():
		print("PASS test_hit_spark_config")
		quit(0)
	else:
		print("FAILED test_hit_spark_config")
		quit(1)
