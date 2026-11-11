extends SceneTree
## Effect B config test (CHANGE-BRIEF.md, Effect B "Settings"). Loads
## res://effects/fire_pit_flames.tscn and reads every setting the brief names
## back from the loaded resources, with the brief's values as the expected values.
## fixed_fps and interpolate are not named for B; the scene follows Effect A's
## precedent (fixed_fps 0 = follow the render rate, interpolate true) and this
## test asserts that, labelled as precedent.
## Run: ./scripts/run-test.sh test_fire_pit_flames_config.gd 60

const SCENE := "res://effects/fire_pit_flames.tscn"
const EPS := 1e-4

var checks := 0
var failures: Array[String] = []

# The brief's table, one column per emitter.
const EXPECT := {
	"Flames": {
		"amount": 24, "lifetime": 0.8, "randomness": 0.3, "preprocess": 0.8,
		"pos_y": 0.2, "radius": 0.18,
		"velocity": [0.5, 1.1], "damping": [0.0, 0.0],
		"turb_strength": 1.0, "turb_scale": 2.5, "turb_influence": [0.05, 0.12],
		"scale": [0.8, 1.2], "scale_curve": [[0.0, 0.6], [0.3, 1.0], [1.0, 0.2]],
		"ramp": [[0.0, Color(1, 0.85, 0.4, 0)], [0.3, Color(1, 0.6, 0.2, 0.9)], [1.0, Color(0.8, 0.2, 0.05, 0)]],
		"quad": Vector2(0.55, 0.55),  # r2 (2026-11-07), was 0.30
		"aabb": AABB(Vector3(-0.6, -0.2, -0.6), Vector3(1.2, 2.0, 1.2)),
	},
	"Embers": {
		"amount": 10, "lifetime": 2.2, "randomness": 0.3, "preprocess": 2.2,
		"pos_y": 0.35, "radius": 0.25,
		"velocity": [0.4, 0.9], "damping": [0.2, 0.2],
		"turb_strength": 1.0, "turb_scale": 4.0, "turb_influence": [0.15, 0.30],
		"scale": [0.7, 1.3], "scale_curve": [[0.0, 1.0], [1.0, 0.0]],
		"ramp": [[0.0, Color(1, 0.7, 0.3, 0)], [0.3, Color(1, 0.5, 0.15, 0.9)], [1.0, Color(0.6, 0.15, 0.05, 0)]],
		"quad": Vector2(0.05, 0.05),
		"aabb": AABB(Vector3(-1.5, -0.2, -1.5), Vector3(3, 4, 3)),
	},
}

var textures: Array = []

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
	check(root.get_class() == "Node3D", "root is a plain Node3D (got %s)" % root.get_class())
	check(root.name == "FirePitFlames", "root named FirePitFlames (got %s)" % root.name)
	check(root.get_script() == null, "root has no script (got %s)" % str(root.get_script()))
	var emitters: Array = []
	for child in root.get_children():
		if child is GPUParticles3D: emitters.append(String(child.name))
	check(emitters == ["Flames", "Embers"], "exactly two GPUParticles3D children Flames, Embers (got %s)" % str(emitters))
	check(root.get_child_count() == 2, "root has only the two emitters as children (got %d)" % root.get_child_count())
	for emitter_name in EXPECT:
		var node := root.get_node_or_null(NodePath(emitter_name))
		check(node is GPUParticles3D, "%s is GPUParticles3D" % emitter_name)
		if node is GPUParticles3D:
			check_emitter(node, EXPECT[emitter_name])
	# "the same code-free radial GradientTexture2D": one shared resource.
	check(textures.size() == 2 and textures[0] != null and textures[0] == textures[1], "Flames and Embers share one albedo GradientTexture2D")
	root.free()
	finish()

func check_emitter(p: GPUParticles3D, e: Dictionary) -> void:
	var n := String(p.name)
	# Shared emission settings (brief: "Both emitters").
	check(p.one_shot == false, "%s one_shot false" % n)
	check(near(p.explosiveness, 0.0), "%s explosiveness 0.0 (got %s)" % [n, p.explosiveness])
	check(p.emitting == false, "%s emitting false in the scene" % n)
	check(p.local_coords == false, "%s local_coords false" % n)
	check(p.use_fixed_seed == false, "%s use_fixed_seed false" % n)
	check(near(p.amount_ratio, 1.0), "%s amount_ratio 1.0 in the scene (got %s)" % [n, p.amount_ratio])
	# Not named for B: Effect A's precedent.
	check(p.fixed_fps == 0, "%s fixed_fps 0 (Effect A precedent; got %d)" % [n, p.fixed_fps])
	check(p.interpolate == true, "%s interpolate true (Effect A precedent)" % n)
	# Per-emitter table.
	check(p.amount == int(e.amount), "%s amount %d (got %d)" % [n, e.amount, p.amount])
	check(near(p.lifetime, e.lifetime), "%s lifetime %s (got %s)" % [n, e.lifetime, p.lifetime])
	check(near(p.randomness, e.randomness), "%s randomness %s (got %s)" % [n, e.randomness, p.randomness])
	check(near(p.preprocess, e.preprocess), "%s preprocess %s (got %s)" % [n, e.preprocess, p.preprocess])
	check(near_v3(p.position, Vector3(0, e.pos_y, 0)), "%s position (local) (0,%s,0) (got %s)" % [n, e.pos_y, p.position])
	var aabb: AABB = e.aabb
	check(near_v3(p.visibility_aabb.position, aabb.position) and near_v3(p.visibility_aabb.size, aabb.size), "%s visibility_aabb %s (got %s)" % [n, aabb, p.visibility_aabb])
	# Process material.
	var m := p.process_material as ParticleProcessMaterial
	check(m != null, "%s process_material is ParticleProcessMaterial (got %s)" % [n, p.process_material])
	if m != null:
		check(m.emission_shape == ParticleProcessMaterial.EMISSION_SHAPE_SPHERE, "%s emission_shape SPHERE (got %d)" % [n, m.emission_shape])
		check(near(m.emission_sphere_radius, e.radius), "%s emission_sphere_radius %s (got %s)" % [n, e.radius, m.emission_sphere_radius])
		check(near_v3(m.direction, Vector3(0, 1, 0)), "%s direction (0,1,0) (got %s)" % [n, m.direction])
		check(near(m.spread, 15.0), "%s spread 15 (got %s)" % [n, m.spread])
		check(near_v3(m.gravity, Vector3.ZERO), "%s gravity (0,0,0) (got %s)" % [n, m.gravity])
		check(near(m.initial_velocity_min, e.velocity[0]) and near(m.initial_velocity_max, e.velocity[1]), "%s initial_velocity_min/max %s (got %s, %s)" % [n, e.velocity, m.initial_velocity_min, m.initial_velocity_max])
		check(near(m.damping_min, e.damping[0]) and near(m.damping_max, e.damping[1]), "%s damping_min/max %s (got %s, %s)" % [n, e.damping, m.damping_min, m.damping_max])
		check(m.turbulence_enabled == true, "%s turbulence_enabled true" % n)
		check(near(m.turbulence_noise_strength, e.turb_strength), "%s turbulence_noise_strength %s (got %s)" % [n, e.turb_strength, m.turbulence_noise_strength])
		check(near(m.turbulence_noise_scale, e.turb_scale), "%s turbulence_noise_scale %s (got %s)" % [n, e.turb_scale, m.turbulence_noise_scale])
		check(near(m.turbulence_influence_min, e.turb_influence[0]) and near(m.turbulence_influence_max, e.turb_influence[1]), "%s turbulence_influence_min/max %s (got %s, %s)" % [n, e.turb_influence, m.turbulence_influence_min, m.turbulence_influence_max])
		check(near(m.scale_min, e.scale[0]) and near(m.scale_max, e.scale[1]), "%s scale_min/max %s (got %s, %s)" % [n, e.scale, m.scale_min, m.scale_max])
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
	if q == null:
		textures.append(null)
		return
	check(near(q.size.x, e.quad.x) and near(q.size.y, e.quad.y), "%s QuadMesh size %s (got %s)" % [n, e.quad, q.size])
	var mat := q.material as StandardMaterial3D
	check(mat != null, "%s QuadMesh material is StandardMaterial3D (got %s)" % [n, q.material])
	if mat == null:
		textures.append(null)
		return
	check(mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "%s shading_mode UNSHADED (got %d)" % [n, mat.shading_mode])
	check(mat.billboard_mode == BaseMaterial3D.BILLBOARD_PARTICLES, "%s billboard_mode BILLBOARD_PARTICLES (got %d)" % [n, mat.billboard_mode])
	check(mat.vertex_color_use_as_albedo == true, "%s vertex_color_use_as_albedo true" % n)
	check(mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "%s transparency TRANSPARENCY_ALPHA (got %d)" % [n, mat.transparency])
	check(mat.blend_mode == BaseMaterial3D.BLEND_MODE_ADD, "%s blend_mode BLEND_MODE_ADD (got %d)" % [n, mat.blend_mode])
	check(mat.disable_fog == true, "%s disable_fog true" % n)
	var tex := mat.albedo_texture as GradientTexture2D
	textures.append(tex)
	check(tex != null, "%s albedo_texture is GradientTexture2D (got %s)" % [n, mat.albedo_texture])
	if tex == null: return
	# Same texture as Effect A: radial, white centre to transparent edge, 32x32, in the scene.
	check(tex.resource_path == "" or tex.resource_path.begins_with(SCENE + "::"), "%s albedo_texture written in the scene, not a file (path '%s')" % [n, tex.resource_path])
	check(tex.fill == GradientTexture2D.FILL_RADIAL, "%s albedo_texture fill FILL_RADIAL (got %d)" % [n, tex.fill])
	check(tex.width == 32 and tex.height == 32, "%s albedo_texture 32x32 (got %dx%d)" % [n, tex.width, tex.height])
	var tg := tex.gradient
	check(tg != null, "%s albedo_texture has a Gradient" % n)
	if tg != null:
		var last := tg.get_point_count() - 1
		check(near(tg.get_offset(0), 0.0) and near_c(tg.get_color(0), Color(1, 1, 1, 1)), "%s albedo gradient starts white opaque at the centre (got %s %s)" % [n, tg.get_offset(0), tg.get_color(0)])
		check(near(tg.get_offset(last), 1.0) and near(tg.get_color(last).a, 0.0), "%s albedo gradient ends transparent at the edge (got %s %s)" % [n, tg.get_offset(last), tg.get_color(last)])
	check(tex.fill_from.is_equal_approx(Vector2(0.5, 0.5)), "%s albedo_texture fill_from centre (0.5,0.5) (got %s)" % [n, tex.fill_from])
	check(near(tex.fill_from.distance_to(tex.fill_to), 0.5), "%s albedo_texture radius reaches the edge (|fill_to-fill_from| 0.5, got %s)" % [n, tex.fill_from.distance_to(tex.fill_to)])

func finish() -> void:
	print("test_fire_pit_flames_config: %d checks, %d failed" % [checks, failures.size()])
	if failures.is_empty():
		print("PASS test_fire_pit_flames_config")
		quit(0)
	else:
		print("FAILED test_fire_pit_flames_config")
		quit(1)
