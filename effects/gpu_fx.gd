class_name GpuFx
extends RefCounted
## Shared pieces of the GPU particle effects (GPU粒子特效推广策划案 v0.6 §8):
## one cache for the materials and textures they make once, gradient helpers,
## and the soft round dot every billboard uses. GameManager.release_static_caches
## calls release() so the export build exits clean.

static var cache := {}

static func release() -> void:
	cache.clear()

## A GradientTexture1D through `colours` at `offsets` (even spacing if empty).
static func ramp(colours: Array, offsets: Array = []) -> GradientTexture1D:
	var g := Gradient.new()
	var points := PackedFloat32Array()
	var packed := PackedColorArray()
	for i in range(colours.size()):
		points.append(float(offsets[i]) if i < offsets.size() else float(i) / maxf(1.0, colours.size() - 1.0))
		packed.append(colours[i])
	g.offsets = points
	g.colors = packed
	var t := GradientTexture1D.new()
	t.gradient = g
	return t

## A curve texture from (t, value) pairs.
static func curve(points: Array, max_value: float = 1.0) -> CurveTexture:
	var c := Curve.new()
	c.max_value = max_value
	for pt in points: c.add_point(Vector2(pt[0], pt[1]))
	var t := CurveTexture.new()
	t.curve = c
	return t

## The soft white dot (radial, white centre to clear edge), 32×32.
static func dot() -> GradientTexture2D:
	if cache.has("dot"): return cache["dot"]
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 32
	t.height = 32
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	cache["dot"] = t
	return t

## An unshaded, vertex-coloured billboard material for particle quads.
static func billboard(texture: Texture2D, additive: bool, mode: int = BaseMaterial3D.BILLBOARD_PARTICLES) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.disable_fog = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = texture
	m.billboard_mode = mode
	if mode == BaseMaterial3D.BILLBOARD_PARTICLES: m.billboard_keep_scale = true
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return m

## A quad mesh carrying `material`.
static func quad(size: Vector2, material: Material) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = size
	q.material = material
	return q

## A CPU emitter built the old way, carried over to the GPU (GPU粒子特效推广策划案
## §7 P4): same settings (GPUParticles3D.convert_from_particles), the same
## name and place, plus turbulence [strength, scale, influence min, max] when
## given. The CPU node is freed; the GPU one is returned unparented.
static func from_cpu(cpu: CPUParticles3D, turbulence: Array = [], reach: float = 4.0) -> GPUParticles3D:
	var gpu := GPUParticles3D.new()
	gpu.convert_from_particles(cpu)
	gpu.name = cpu.name
	gpu.transform = cpu.transform
	gpu.emitting = cpu.emitting
	gpu.interpolate = true
	gpu.fixed_fps = 0
	gpu.visibility_aabb = AABB(-Vector3.ONE * reach, Vector3.ONE * reach * 2.0)
	var m := gpu.process_material as ParticleProcessMaterial
	if m != null and turbulence.size() == 4:
		m.turbulence_enabled = true
		m.turbulence_noise_strength = float(turbulence[0])
		m.turbulence_noise_scale = float(turbulence[1])
		m.turbulence_influence_min = float(turbulence[2])
		m.turbulence_influence_max = float(turbulence[3])
	cpu.free()
	return gpu
