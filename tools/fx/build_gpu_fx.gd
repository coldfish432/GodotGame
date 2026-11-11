extends SceneTree
## Writes the GPU particle scenes of GPU粒子特效推广策划案 v0.6 into effects/
## (every setting lives in the scene; the game only switches them on, sets
## amount_ratio and frees them). Re-run after changing a setting here:
##   ../Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/fx/build_gpu_fx.gd
## Textures are procedural (用户裁决 7): soft dots, a streak and a shard, made
## here and stored inside each scene.

const OUT := "res://effects/"
const ONE_SHOT := preload("res://effects/one_shot.gd")
const WEATHER := "res://effects/weather_fx.gd"
const STATUS_SHADER := preload("res://effects/status_line.gdshader")

func _initialize() -> void:
	var built := 0
	for spec in [hazard_fire(), molotov_shards(), hazard_fuse(), hazard_blast(), snowfall(), rainfall(),
			snow_kick(), status_lines(), vault_grit(), barrier_shards()]:
		var root: Node3D = spec[1]
		_own(root, root)
		var packed := PackedScene.new()
		var error := packed.pack(root)
		if error == OK: error = ResourceSaver.save(packed, OUT + spec[0] + ".tscn")
		print("BUILD ", spec[0], " -> ", error_string(error))
		if error == OK: built += 1
		root.free()
	print("BUILD_GPU_FX %d scenes" % built)
	quit(0 if built == 10 else 1)

func _own(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_own(child, owner)

# --- Pieces ---------------------------------------------------------------------

func dot(size := 32) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = size
	t.height = size
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t

## A rain streak: clear at both ends, bright in the lower middle.
func streak() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 4
	t.height = 32
	t.fill_from = Vector2(0.5, 0.0)
	t.fill_to = Vector2(0.5, 1.0)
	return t

func ramp(colours: Array, offsets: Array = []) -> GradientTexture1D:
	var g := Gradient.new()
	var o := PackedFloat32Array()
	var c := PackedColorArray()
	for i in range(colours.size()):
		o.append(float(offsets[i]) if i < offsets.size() else float(i) / maxf(1.0, colours.size() - 1.0))
		c.append(colours[i])
	g.offsets = o
	g.colors = c
	var t := GradientTexture1D.new()
	t.gradient = g
	return t

func tints(colours: Array) -> GradientTexture1D:
	var t := ramp(colours)
	t.gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	return t

func curve(points: Array, max_value := 1.0) -> CurveTexture:
	var c := Curve.new()
	c.max_value = max_value
	for pt in points: c.add_point(Vector2(pt[0], pt[1]))
	var t := CurveTexture.new()
	t.curve = c
	return t

func look(texture: Texture2D, additive: bool, size: Vector2, billboard := BaseMaterial3D.BILLBOARD_PARTICLES) -> QuadMesh:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.disable_fog = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = texture
	m.billboard_mode = billboard
	if billboard == BaseMaterial3D.BILLBOARD_PARTICLES: m.billboard_keep_scale = true
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var q := QuadMesh.new()
	q.size = size
	q.material = m
	return q

## One emitter. `o` keys map straight onto GPUParticles3D / ParticleProcessMaterial.
func emitter(name: String, o: Dictionary) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = name
	p.amount = int(o.get("amount", 16))
	p.lifetime = float(o.get("life", 1.0))
	p.one_shot = bool(o.get("one_shot", false))
	p.explosiveness = float(o.get("explosive", 1.0 if p.one_shot else 0.0))
	p.randomness = float(o.get("randomness", 0.0))
	p.preprocess = float(o.get("preprocess", 0.0))
	p.local_coords = false
	p.interpolate = true
	p.fixed_fps = 0
	p.emitting = not p.one_shot and bool(o.get("emitting", true))
	p.use_fixed_seed = false
	p.visibility_aabb = o.get("aabb", AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4)))
	p.position = o.get("at", Vector3.ZERO)
	var m := ParticleProcessMaterial.new()
	m.particle_flag_disable_z = false
	match String(o.get("shape", "point")):
		"sphere":
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			m.emission_sphere_radius = float(o.get("radius", 0.2))
		"box":
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			m.emission_box_extents = o.get("box", Vector3.ONE)
		"ring":
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
			m.emission_ring_axis = Vector3.UP
			m.emission_ring_height = float(o.get("ring_height", 0.0))
			m.emission_ring_radius = float(o.get("ring", [0.9, 1.0])[1])
			m.emission_ring_inner_radius = float(o.get("ring", [0.9, 1.0])[0])
		_: m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	m.direction = o.get("dir", Vector3.UP)
	m.spread = float(o.get("spread", 0.0))
	var v: Array = o.get("speed", [0.0, 0.0])
	m.initial_velocity_min = float(v[0])
	m.initial_velocity_max = float(v[1])
	m.gravity = o.get("gravity", Vector3.ZERO)
	var damp: Array = o.get("damping", [0.0, 0.0])
	m.damping_min = float(damp[0])
	m.damping_max = float(damp[1])
	var radial: Array = o.get("radial", [0.0, 0.0])
	m.radial_accel_min = float(radial[0])
	m.radial_accel_max = float(radial[1])
	var sc: Array = o.get("scale", [1.0, 1.0])
	m.scale_min = float(sc[0])
	m.scale_max = float(sc[1])
	if o.has("scale_curve"): m.scale_curve = curve(o.scale_curve, float(o.get("scale_max", 1.0)))
	if o.has("colours"): m.color_ramp = ramp(o.colours, o.get("offsets", []))
	if o.has("tints"): m.color_initial_ramp = tints(o.tints)
	var ang: Array = o.get("angle", [0.0, 0.0])
	m.angle_min = float(ang[0])
	m.angle_max = float(ang[1])
	if o.has("turbulence"):
		var t: Array = o.turbulence
		m.turbulence_enabled = true
		m.turbulence_noise_strength = float(t[0])
		m.turbulence_noise_scale = float(t[1])
		m.turbulence_influence_min = float(t[2])
		m.turbulence_influence_max = float(t[3])
	match String(o.get("collide", "")):
		"hide": m.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
		"rigid":
			m.collision_mode = ParticleProcessMaterial.COLLISION_RIGID
			m.collision_bounce = float(o.get("bounce", 0.3))
			m.collision_friction = float(o.get("friction", 0.5))
	if bool(o.get("align", false)): m.particle_flag_align_y = true
	if o.has("sub_at_collision"):
		m.sub_emitter_mode = ParticleProcessMaterial.SUB_EMITTER_AT_COLLISION
		m.sub_emitter_amount_at_collision = int(o.sub_at_collision)
	p.process_material = m
	p.draw_pass_1 = o.get("mesh")
	if p.draw_pass_1 != null and bool(o.get("no_shadow", true)): p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

func root(name: String, script_path: Variant = null) -> Node3D:
	var r := Node3D.new()
	r.name = name
	if script_path is Script: r.set_script(script_path)
	elif script_path is String: r.set_script(load(script_path))
	return r

# --- Scenes ---------------------------------------------------------------------

## P3: a bottle's fire patch (radius 1.3 at scale 1; HazardFx scales the root
## to the hazard's radius). Flames waver (turbulence), embers drift up and
## wander, a thin smoke leans off. amount_ratio follows the fire's time left.
func hazard_fire() -> Array:
	var r := root("HazardFire")
	var d := dot()
	r.add_child(emitter("Flames", {"amount": 30, "life": 0.7, "preprocess": 0.7, "randomness": 0.3, "shape": "sphere", "radius": 0.75,
		"dir": Vector3.UP, "spread": 18.0, "speed": [0.6, 1.4], "gravity": Vector3(0, 0.6, 0), "scale": [0.7, 1.2],
		"scale_curve": [[0.0, 1.0], [1.0, 0.25]], "colours": [Color(1, 0.92, 0.55, 0), Color(1, 0.58, 0.16, 0.85), Color(0.62, 0.12, 0.03, 0)], "offsets": [0.0, 0.2, 1.0],
		"turbulence": [1.2, 2.0, 0.08, 0.16], "mesh": look(d, true, Vector2(0.34, 0.34)), "aabb": AABB(Vector3(-2, -0.5, -2), Vector3(4, 3, 4)), "at": Vector3(0, 0.12, 0)}))
	r.add_child(emitter("Embers", {"amount": 12, "life": 1.6, "preprocess": 1.6, "randomness": 0.4, "shape": "sphere", "radius": 0.8,
		"dir": Vector3.UP, "spread": 25.0, "speed": [0.6, 1.2], "gravity": Vector3(0, 0.3, 0), "scale": [0.6, 1.0],
		"colours": [Color(1, 0.75, 0.35, 0), Color(1, 0.55, 0.15, 0.9), Color(0.6, 0.15, 0.05, 0)], "offsets": [0.0, 0.15, 1.0],
		"turbulence": [1.0, 3.5, 0.18, 0.32], "mesh": look(d, true, Vector2(0.06, 0.06)), "aabb": AABB(Vector3(-2.5, -0.5, -2.5), Vector3(5, 4.5, 5)), "at": Vector3(0, 0.25, 0)}))
	r.add_child(emitter("Smoke", {"amount": 6, "life": 1.8, "preprocess": 1.8, "randomness": 0.3, "shape": "sphere", "radius": 0.6,
		"dir": Vector3(0.2, 1, 0.1), "spread": 15.0, "speed": [0.4, 0.8], "gravity": Vector3(0.2, 0.2, 0), "scale": [0.8, 1.3], "angle": [0.0, 360.0],
		"scale_curve": [[0.0, 0.6], [1.0, 1.6]], "scale_max": 2.0, "colours": [Color(0.14, 0.12, 0.12, 0), Color(0.14, 0.12, 0.12, 0.22), Color(0.14, 0.12, 0.12, 0)], "offsets": [0.0, 0.25, 1.0],
		"turbulence": [0.8, 2.5, 0.05, 0.1], "mesh": look(d, false, Vector2(0.9, 0.9)), "aabb": AABB(Vector3(-2.5, -0.5, -2.5), Vector3(5, 4.5, 5)), "at": Vector3(0, 0.5, 0)}))
	return ["hazard_fire", r]

## P3: the bottle shattering: glass chips bouncing on the ground, a flare of flame.
func molotov_shards() -> Array:
	var r := root("MolotovShards", ONE_SHOT)
	r.add_child(emitter("Glass", {"amount": 14, "life": 0.7, "one_shot": true, "randomness": 0.3, "shape": "sphere", "radius": 0.1,
		"dir": Vector3.UP, "spread": 70.0, "speed": [2.5, 4.5], "gravity": Vector3(0, -12, 0), "scale": [0.6, 1.3], "angle": [0.0, 360.0],
		"tints": [Color(0.62, 0.78, 0.66), Color(0.82, 0.9, 0.86), Color(0.45, 0.6, 0.5)], "colours": [Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)], "offsets": [0.0, 0.7, 1.0],
		"collide": "rigid", "bounce": 0.35, "friction": 0.6, "mesh": look(null, false, Vector2(0.07, 0.05)), "aabb": AABB(Vector3(-2.5, -0.5, -2.5), Vector3(5, 3, 5))}))
	r.add_child(emitter("Flare", {"amount": 12, "life": 0.35, "one_shot": true, "randomness": 0.3, "shape": "sphere", "radius": 0.2,
		"dir": Vector3.UP, "spread": 90.0, "speed": [2.0, 4.0], "gravity": Vector3(0, -2, 0), "damping": [4.0, 6.0], "scale": [0.7, 1.2],
		"colours": [Color(1, 0.95, 0.7, 1), Color(1, 0.55, 0.15, 0.9), Color(0.6, 0.1, 0.02, 0)], "offsets": [0.0, 0.35, 1.0],
		"mesh": look(dot(), true, Vector2(0.22, 0.22)), "aabb": AABB(Vector3(-2, -0.5, -2), Vector3(4, 3, 4))}))
	return ["molotov_shards", r]

## P3: a fused blast's warning: motes drawn in to the centre while it counts down.
func hazard_fuse() -> Array:
	var r := root("HazardFuse")
	r.add_child(emitter("Gather", {"amount": 18, "life": 0.8, "preprocess": 0.8, "randomness": 0.3, "shape": "ring", "ring": [0.85, 1.0], "ring_height": 0.05,
		"dir": Vector3.UP, "spread": 10.0, "speed": [0.1, 0.3], "radial": [-2.6, -2.0], "scale": [0.7, 1.1],
		"colours": [Color(1, 0.4, 0.3, 0), Color(1, 0.4, 0.3, 0.8), Color(1, 0.8, 0.6, 0)], "offsets": [0.0, 0.3, 1.0],
		"mesh": look(dot(), true, Vector2(0.08, 0.08)), "aabb": AABB(Vector3(-1.5, -0.5, -1.5), Vector3(3, 2, 3)), "at": Vector3(0, 0.1, 0)}))
	return ["hazard_fuse", r]

## P3: the blast itself (slug burst, a boss's last rite): sparks out, a dark puff.
func hazard_blast() -> Array:
	var r := root("HazardBlast", ONE_SHOT)
	r.add_child(emitter("Sparks", {"amount": 26, "life": 0.5, "one_shot": true, "randomness": 0.3, "shape": "sphere", "radius": 0.3,
		"dir": Vector3.UP, "spread": 80.0, "speed": [3.0, 6.0], "gravity": Vector3(0, -6, 0), "damping": [3.0, 4.0], "scale": [0.6, 1.2],
		"scale_curve": [[0.0, 1.0], [1.0, 0.0]], "colours": [Color(1, 1, 0.85, 1), Color(1, 0.55, 0.2, 1), Color(0.6, 0.1, 0.05, 0)], "offsets": [0.0, 0.35, 1.0],
		"mesh": look(dot(), true, Vector2(0.12, 0.12)), "aabb": AABB(Vector3(-3, -1, -3), Vector3(6, 4, 6)), "at": Vector3(0, 0.2, 0)}))
	r.add_child(emitter("Dust", {"amount": 8, "life": 0.9, "one_shot": true, "randomness": 0.2, "shape": "sphere", "radius": 0.5,
		"dir": Vector3.UP, "spread": 80.0, "speed": [0.5, 1.2], "gravity": Vector3(0, 0.3, 0), "damping": [1.0, 1.5], "scale": [0.8, 1.3], "angle": [0.0, 360.0],
		"scale_curve": [[0.0, 0.6], [1.0, 1.5]], "scale_max": 2.0, "colours": [Color(0.18, 0.16, 0.16, 0.5), Color(0.18, 0.16, 0.16, 0)],
		"mesh": look(dot(), false, Vector2(1.0, 1.0)), "aabb": AABB(Vector3(-3, -1, -3), Vector3(6, 4, 6)), "at": Vector3(0, 0.3, 0)}))
	return ["hazard_blast", r]

## P2: 萨米's snow over the view. Fall: the ordinary snow (amount_ratio follows
## the cold's growth); Driving: near-level snow of a blizzard; Near: big blurred
## flakes past the lens. Both blizzard layers sit at amount_ratio 0 until one.
## The flakes stop where they meet the ground (the heightfield collider).
func snowfall() -> Array:
	var r := root("Snowfall", WEATHER)
	var d := dot(16)
	r.add_child(emitter("Fall", {"amount": 800, "life": 6.0, "preprocess": 6.0, "shape": "box", "box": Vector3(22.0, 0.5, 18.0),
		"dir": Vector3.DOWN, "spread": 12.0, "speed": [0.6, 1.2], "gravity": Vector3(0.5, -1.4, 0.2), "scale": [0.6, 1.2],
		"colours": [Color(1, 1, 1, 0), Color(0.95, 0.97, 1, 0.85), Color(0.95, 0.97, 1, 0)], "offsets": [0.0, 0.12, 1.0],
		"turbulence": [1.0, 6.0, 0.05, 0.12], "collide": "hide", "mesh": look(d, false, Vector2(0.16, 0.16)), "aabb": AABB(Vector3(-30, -16, -26), Vector3(60, 20, 52))}))
	r.add_child(emitter("Driving", {"amount": 1200, "life": 2.2, "preprocess": 2.2, "shape": "box", "box": Vector3(26.0, 5.0, 20.0), "at": Vector3(-6, -5, 0),
		"dir": Vector3(1, -0.15, 0.25), "spread": 8.0, "speed": [9.0, 15.0], "gravity": Vector3(1.5, -1.0, 0.3), "scale": [0.6, 1.3],
		"colours": [Color(1, 1, 1, 0), Color(0.94, 0.96, 1, 0.8), Color(0.94, 0.96, 1, 0)], "offsets": [0.0, 0.15, 1.0],
		"turbulence": [1.5, 5.0, 0.1, 0.2], "collide": "hide", "mesh": look(d, false, Vector2(0.14, 0.14)), "aabb": AABB(Vector3(-40, -20, -30), Vector3(80, 26, 60))}))
	r.add_child(emitter("Near", {"amount": 90, "life": 1.0, "preprocess": 1.0, "randomness": 0.3, "shape": "box", "box": Vector3(16.0, 1.5, 3.0), "at": Vector3(-8, -3, 6),
		"dir": Vector3(1, -0.1, 0.1), "spread": 6.0, "speed": [16.0, 24.0], "scale": [0.7, 1.4], "angle": [0.0, 360.0],
		"colours": [Color(1, 1, 1, 0), Color(0.97, 0.98, 1, 0.35), Color(0.97, 0.98, 1, 0)], "offsets": [0.0, 0.2, 1.0],
		"mesh": look(dot(32), false, Vector2(0.7, 0.7)), "aabb": AABB(Vector3(-40, -10, -10), Vector3(80, 14, 24))}))
	return ["snowfall", r]

## P2: 叙拉古's rain: thin streaks falling fast and slanted; where one meets the
## ground or a roof it stops and throws a tiny splash (sub-emitter at collision).
func rainfall() -> Array:
	var r := root("Rainfall", WEATHER)
	var splash := emitter("Splash", {"amount": 400, "life": 0.25, "explosive": 0.0, "randomness": 0.3, "emitting": false, "shape": "point",
		"dir": Vector3.UP, "spread": 60.0, "speed": [0.6, 1.3], "gravity": Vector3(0, -7, 0), "scale": [0.6, 1.0],
		"colours": [Color(0.85, 0.9, 1, 0.55), Color(0.85, 0.9, 1, 0)], "mesh": look(dot(16), false, Vector2(0.05, 0.05)), "aabb": AABB(Vector3(-30, -20, -26), Vector3(60, 24, 52))})
	var rain := emitter("Rain", {"amount": 900, "life": 1.1, "preprocess": 1.1, "shape": "box", "box": Vector3(22.0, 0.5, 18.0),
		"dir": Vector3(0.12, -1.0, 0.05), "spread": 2.0, "speed": [11.0, 13.0], "gravity": Vector3(0, -2.0, 0),
		"colours": [Color(0.8, 0.86, 0.95, 0), Color(0.8, 0.86, 0.95, 0.45), Color(0.8, 0.86, 0.95, 0)], "offsets": [0.0, 0.2, 1.0],
		"collide": "hide", "sub_at_collision": 1, "align": true,
		"mesh": look(streak(), false, Vector2(0.03, 0.7), BaseMaterial3D.BILLBOARD_FIXED_Y), "aabb": AABB(Vector3(-30, -20, -26), Vector3(60, 24, 52))})
	r.add_child(rain)
	r.add_child(splash)
	rain.sub_emitter = NodePath("../Splash")
	return ["rainfall", r]

## P2: snow kicked up at her feet as she walks.
func snow_kick() -> Array:
	var r := root("SnowKick", ONE_SHOT)
	r.add_child(emitter("Kick", {"amount": 7, "life": 0.5, "one_shot": true, "randomness": 0.3, "shape": "sphere", "radius": 0.15,
		"dir": Vector3.UP, "spread": 55.0, "speed": [0.8, 1.6], "gravity": Vector3(0, -5, 0), "scale": [0.6, 1.1],
		"colours": [Color(0.95, 0.97, 1, 0.85), Color(0.95, 0.97, 1, 0)], "mesh": look(dot(16), false, Vector2(0.09, 0.09)), "aabb": AABB(Vector3(-1, -0.5, -1), Vector3(2, 1.5, 2)), "at": Vector3(0, 0.05, 0)}))
	return ["snow_kick", r]

## P6: the buff / debuff ring. Up: lines rising from her feet; Down: lines
## falling from above her head. Each a long thin triangle (status_line.gdshader)
## at a random place on the ring, appearing at random times. StatusLines sets
## the ring's size to the figure's and turns each emitter on and off.
func status_lines() -> Array:
	var r := root("StatusLines", load("res://effects/status_lines.gd"))
	for falls in [false, true]:
		var mat := ShaderMaterial.new()
		mat.shader = STATUS_SHADER
		mat.set_shader_parameter("falls", 1.0 if falls else 0.0)
		var q := QuadMesh.new()
		q.size = Vector2(0.14, 0.6)
		q.material = mat
		r.add_child(emitter("Down" if falls else "Up", {"amount": 12, "life": 0.9, "explosive": 0.0, "randomness": 0.5, "emitting": false,
			"shape": "ring", "ring": [0.38, 0.4], "dir": Vector3.DOWN if falls else Vector3.UP, "spread": 0.0, "speed": [0.9, 1.4],
			"colours": [Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)], "offsets": [0.0, 0.25, 1.0],
			"mesh": q, "aabb": AABB(Vector3(-1.5, -2, -1.5), Vector3(3, 4.5, 3)), "at": Vector3(0, 1.9 if falls else 0.05, 0)}))
	return ["status_lines", r]

## P4: a vault wall opening: grit thrown out and a cloud of dust.
func vault_grit() -> Array:
	var r := root("VaultGrit", ONE_SHOT)
	r.add_child(emitter("Grit", {"amount": 30, "life": 0.9, "one_shot": true, "randomness": 0.3, "shape": "box", "box": Vector3(1.2, 0.8, 0.2),
		"dir": Vector3(0, 0.5, 1), "spread": 45.0, "speed": [1.5, 3.5], "gravity": Vector3(0, -10, 0), "scale": [0.6, 1.3], "angle": [0.0, 360.0],
		"tints": [Color(0.45, 0.42, 0.38), Color(0.6, 0.56, 0.5), Color(0.35, 0.33, 0.3)], "colours": [Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)], "offsets": [0.0, 0.75, 1.0],
		"collide": "rigid", "bounce": 0.2, "friction": 0.8, "mesh": look(null, false, Vector2(0.08, 0.08)), "aabb": AABB(Vector3(-3, -1.5, -3), Vector3(6, 4, 6)), "at": Vector3(0, 0.6, 0)}))
	r.add_child(emitter("Dust", {"amount": 10, "life": 1.4, "one_shot": true, "randomness": 0.3, "shape": "box", "box": Vector3(1.2, 0.8, 0.3),
		"dir": Vector3(0, 0.3, 1), "spread": 50.0, "speed": [0.4, 1.0], "gravity": Vector3(0, 0.15, 0), "damping": [0.8, 1.2], "scale": [0.8, 1.4], "angle": [0.0, 360.0],
		"scale_curve": [[0.0, 0.6], [1.0, 1.6]], "scale_max": 2.0, "colours": [Color(0.5, 0.47, 0.42, 0.45), Color(0.5, 0.47, 0.42, 0)],
		"mesh": look(dot(), false, Vector2(1.1, 1.1)), "aabb": AABB(Vector3(-3, -1.5, -3), Vector3(6, 4, 6)), "at": Vector3(0, 0.6, 0)}))
	return ["vault_grit", r]

## P4: a barrier breaking: pale shards flung off the shell over Sol's break frames.
func barrier_shards() -> Array:
	var r := root("BarrierShards", ONE_SHOT)
	r.add_child(emitter("Shards", {"amount": 16, "life": 0.6, "one_shot": true, "randomness": 0.3, "shape": "sphere", "radius": 0.45,
		"dir": Vector3.UP, "spread": 90.0, "speed": [1.5, 3.0], "gravity": Vector3(0, -6, 0), "damping": [1.0, 2.0], "scale": [0.6, 1.2], "angle": [0.0, 360.0],
		"colours": [Color(0.9, 0.95, 1, 0.7), Color(0.75, 0.85, 1, 0.5), Color(0.75, 0.85, 1, 0)], "offsets": [0.0, 0.5, 1.0],
		"mesh": look(null, true, Vector2(0.09, 0.06)), "aabb": AABB(Vector3(-2, -1, -2), Vector3(4, 3.5, 4)), "at": Vector3(0, 0.8, 0)}))
	return ["barrier_shards", r]
