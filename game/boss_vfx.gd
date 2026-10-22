class_name BossVfx
extends Node3D

## The bosses' and wardens' own attack effects (用户 2026-10-20: 完善各 boss 的
## 攻击特效; 添加粒子、光影等特效; 特效不要盖在人物上面; 方块用更细致的表现方式).
## BossVfx.play(game, figure, seg, ctx) is called from Boss._resolve.
##
## What they are made of:
## - bands: one smooth strip of geometry per arc, ring, beam or crack, coloured
##   by a small shader (bright core to soft edge across it, a brighter leading
##   edge), that sweeps open, holds and fades (`arc`, `ring`, `beam`, `crack`);
## - crystals: faceted hexagonal bipyramids, each face shaded by its facing and
##   lit toward the tip, that break out of the ground and shatter (`crystal`);
## - particles: one-shot CPUParticles3D bursts of fine texel chips, sparks,
##   embers, ice glitter, blood, and soft round dust and mist (`burst` and the
##   helpers after it);
## - textures and fluids (tools/fx/bake_boss_fx.py, art/fx/boss/): a tileable
##   noise for erosion and flow, a blade-arc mask, and 8×8 flipbooks baked from
##   a small 2D fluid simulation — smoke and fire puffs for the particles, and
##   a liquid splash seen from above that the ground shader plays, wobbles with
##   flowing noise and dries away (`splat`: blood, sand, molten originium, frost);
## - light shafts: open cylinders with a rising, scrolling additive glow (`shaft`);
## - light: the field is lit by a baked texture (FieldLight), so a blow's light
##   is an additive soft pool on the ground that flares and dies (`glow`), and a
##   soft halo where something burns in the air (`halo`); heavy blows shake the
##   camera a few pixels (GameManager.start_impact_shake).
##
## Characters stay on top: everything is depth-tested; arcs, rings, cracks and
## light lie flat on the ground (GROUND), which a standing sprite always hides
## or stands in front of; nothing that stands up (crystals, halos, particles) is
## made within CLEAR of a figure, and what runs along a strip (rats, wolves, the
## spear) is hidden while it passes one.
## Every figure has its own colours (its region's: 矿区 originium orange, 龙门
## sand, 萨米 teal ice, 叙拉古 blood red) so a blow on screen says whose it is.

const P := 1.0 / 15.0
const GRAVITY := 9.0
## Flat things lie this high off the ground.
const GROUND := 0.045
## Nothing stands up within this of a figure (flat distance, metres).
const CLEAR := 0.9

## main: the blow itself; hot: its bright core; dark: debris; dust: what it throws up.
const PALETTES := {
	"patriot": {"main": Color("ff8a2a"), "hot": Color("ffd08a"), "dark": Color("2a2420"), "dust": Color("8a7c6c")},
	"rat_king": {"main": Color("d8b060"), "hot": Color("f6e4a8"), "dark": Color("6a5434"), "dust": Color("c8a868")},
	"eikthyrnir": {"main": Color("4ab8a0"), "hot": Color("d8f4f0"), "dark": Color("5a4430"), "dust": Color("dcecf0")},
	"zaro": {"main": Color("c0392b"), "hot": Color("ff8a7a"), "dark": Color("2a1a1e"), "dust": Color("6a4a4e")},
	"crownslayer": {"main": Color("e05a3a"), "hot": Color("ffc0a0"), "dark": Color("3a2a2a"), "dust": Color("7a6a62")},
	"skullshatterer": {"main": Color("ff9a3a"), "hot": Color("fff0b0"), "dark": Color("3a3a40"), "dust": Color("8a8a90")},
	"hollow_snowpriest": {"main": Color("9a8ae8"), "hot": Color("e8e4ff"), "dark": Color("4a3a7a"), "dust": Color("dcd8f4")},
	"father_agnir": {"main": Color("f0d890"), "hot": Color("fffbe8"), "dark": Color("3a3640"), "dust": Color("9a96a0")},
}

const BAND_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled%s;
uniform vec4 core : source_color = vec4(1.0);
uniform vec4 edge : source_color = vec4(1.0);
uniform float progress = 1.0;
uniform float wipe = 0.0;
uniform float alpha = 1.0;
uniform float soft = 0.6;
// Erosion: the band eats away from its thin, noisy parts first, a hot rim at the edge.
uniform float erode = 0.0;
uniform float flow = 0.0;
uniform vec2 tiling = vec2(3.0, 1.0);
uniform float steps = 5.0;
uniform float use_mask = 0.0;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform sampler2D mask_tex : filter_linear;
void fragment() {
	float x = UV.x;
	if (x > progress || x < wipe) discard;
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	float n = texture(noise_tex, vec2(UV.x * tiling.x - flow, UV.y * tiling.y + flow * 0.3)).r;
	float shape = smoothstep(0.0, soft, across);
	if (use_mask > 0.5) shape *= 0.45 + 0.55 * texture(mask_tex, UV).a;
	float body = shape * (0.55 + 0.45 * n);
	float cut = erode * 1.05;
	if (body < cut) discard;
	float rim = 1.0 - smoothstep(cut, cut + 0.14, body);
	vec4 c = mix(edge, core, pow(across, 1.3) * (0.7 + 0.3 * n));
	float lead = smoothstep(progress - 0.1, progress, x) * (1.0 - step(0.999, progress));
	float tail = smoothstep(wipe, wipe + 0.12, x);
	vec3 rgb = c.rgb + (lead * 0.35 + rim * 0.5 * step(0.001, erode)) * core.rgb;
	float a = clamp(c.a * max(shape, rim * 0.8) * alpha * tail, 0.0, 1.0);
	// A few flat steps of light, in keeping with the pixel field.
	ALBEDO = floor(rgb * steps + 0.5) / steps;
	ALPHA = floor(a * steps + 0.5) / steps;
}
"""

## The ground fluid: a splash flipbook frame, its UV wobbled by flowing noise,
## tinted core to edge by its own brightness, drying away by erosion.
const SPLAT_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled%s;
uniform vec4 core : source_color = vec4(1.0);
uniform vec4 edge : source_color = vec4(1.0);
uniform float frame = 0.0;
uniform float erode = 0.0;
uniform float flow = 0.0;
uniform float wobble = 0.03;
uniform float steps = 5.0;
uniform float spin = 0.0;
uniform sampler2D flip_tex : filter_linear;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
void fragment() {
	vec2 uv = UV - 0.5;
	uv = mat2(vec2(cos(spin), -sin(spin)), vec2(sin(spin), cos(spin))) * uv + 0.5;
	vec2 n = texture(noise_tex, uv * 1.5 + vec2(flow, -flow * 0.7)).rg - 0.5;
	uv = clamp(uv + n * wobble, 0.0, 1.0);
	float f = clamp(floor(frame), 0.0, 63.0);
	vec2 cell = vec2(mod(f, 8.0), floor(f / 8.0));
	vec4 s = texture(flip_tex, (cell + uv) / 8.0);
	float grain = texture(noise_tex, uv * 3.0).b;
	float body = s.a * (0.6 + 0.4 * grain);
	if (body < erode) discard;
	float rim = 1.0 - smoothstep(erode, erode + 0.12, body);
	vec4 c = mix(edge, core, clamp(s.r * s.a, 0.0, 1.0));
	vec3 rgb = c.rgb + rim * 0.4 * core.rgb * step(0.001, erode);
	float a = clamp(c.a * s.a * 2.2, 0.0, 1.0);
	ALBEDO = floor(rgb * steps + 0.5) / steps;
	ALPHA = floor(a * steps + 0.5) / steps;
}
"""

## A light shaft: an open cylinder whose glow rises and scrolls up it.
const SHAFT_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_add, fog_disabled;
uniform vec4 colour : source_color = vec4(1.0);
uniform float gain = 0.0;
uniform float flow = 0.0;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
void fragment() {
	float h = 1.0 - UV.y;
	float n = texture(noise_tex, vec2(UV.x * 2.0, UV.y * 0.8 + flow)).r;
	float fall = pow(1.0 - h, 1.6) * smoothstep(0.0, 0.08, h);
	ALBEDO = colour.rgb * gain * fall * (0.4 + 0.9 * n);
}
"""

var game: GameManager
var age := 0.0
var life := 0.6
## Crystals and solid pieces: {node, mat, vel, grav, delay, life, fade, alpha, from, to, grow}.
var _bits: Array[Dictionary] = []
## Bands: {node, mat, delay, sweep, hold, fade, wipe, from, to}.
var _bands: Array[Dictionary] = []
## Runners along a strip: {node, from, to, delay, time, flat}.
var _runs: Array[Dictionary] = []
## Additive glows: {mat, colour, delay, life, rise} — brightness, not alpha, fades.
var _glows: Array[Dictionary] = []
static var _soft: GradientTexture2D
static var _band_shaders := {}
static var _textures := {}
## Ground fluids: {mat, delay, spread, hold, dry}. Shafts: {mat, delay, life, gain}.
var _splats: Array[Dictionary] = []
var _shafts: Array[Dictionary] = []

## A baked effect texture (art/fx/boss/<name>.png), loaded once.
static func tex(name: String) -> Texture2D:
	if not _textures.has(name):
		var path := "res://art/fx/boss/%s.png" % name
		_textures[name] = load(path) if ResourceLoader.exists(path) else null
	return _textures[name]

static func colours(figure_id: String) -> Dictionary:
	return PALETTES.get(figure_id, PALETTES.patriot)

static func make(manager: GameManager, at: Vector3) -> BossVfx:
	var fx := BossVfx.new()
	fx.game = manager
	fx.add_to_group("boss_vfx")
	manager.add_child(fx)
	fx.global_position = at
	return fx

# --- Who is standing where ------------------------------------------------------------------

## Her, every foe and every 平民 on the field.
func _figures() -> Array[Vector3]:
	var out: Array[Vector3] = []
	if not is_instance_valid(game): return out
	if is_instance_valid(game.player): out.append(game.player.global_position)
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e._dead: out.append(e.global_position)
	return out

## Nothing stands within `r` (flat) of this world point.
func clear_at(world: Vector3, r: float = CLEAR) -> bool:
	for f in _figures():
		if Vector2(f.x - world.x, f.z - world.z).length() < r: return false
	return true

## The nearest figure's flat distance from this world point.
func _nearest(world: Vector3) -> float:
	var best := 999.0
	for f in _figures(): best = minf(best, Vector2(f.x - world.x, f.z - world.z).length())
	return best

# --- The loop -------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not is_instance_valid(game) or not game.simulation_active(): return
	age += delta
	for b in _bits:
		var node: MeshInstance3D = b.node
		if not is_instance_valid(node): continue
		var t := age - float(b.delay)
		if t < 0.0: continue
		node.visible = true
		var u := clampf(t / maxf(0.01, float(b.life)), 0.0, 1.0)
		var v: Vector3 = b.vel
		node.position += v * delta
		if float(b.grav) > 0.0:
			b.vel = v + Vector3.DOWN * float(b.grav) * delta
			if node.position.y < 0.0:
				node.position.y = 0.0
				b.vel = Vector3.ZERO
		var g := clampf(u / maxf(0.01, float(b.grow)), 0.0, 1.0) if float(b.grow) > 0.0 else 1.0
		node.scale = (b.from as Vector3).lerp(b.to, 1.0 - pow(1.0 - g, 3.0))
		var fade := float(b.fade)
		var a := 1.0 if u < 1.0 - fade else clampf((1.0 - u) / maxf(0.01, fade), 0.0, 1.0)
		var c: Color = (b.mat as StandardMaterial3D).albedo_color
		c.a = float(b.alpha) * a
		(b.mat as StandardMaterial3D).albedo_color = c
		if u >= 1.0: node.visible = false
	for b in _bands:
		var node: MeshInstance3D = b.node
		if not is_instance_valid(node): continue
		var t := age - float(b.delay)
		if t < 0.0:
			node.visible = false
			continue
		var sweep := float(b.sweep)
		var total := sweep + float(b.hold) + float(b.fade)
		node.visible = t <= total
		var mat: ShaderMaterial = b.mat
		mat.set_shader_parameter("progress", 1.0 if sweep <= 0.0 else clampf(t / sweep, 0.0, 1.0))
		var after := t - sweep - float(b.hold)
		var f := clampf(after / maxf(0.01, float(b.fade)), 0.0, 1.0) if after > 0.0 else 0.0
		if bool(b.wipe): mat.set_shader_parameter("wipe", f)
		if bool(b.erode): mat.set_shader_parameter("erode", f)
		elif not bool(b.wipe): mat.set_shader_parameter("alpha", 1.0 - f)
		mat.set_shader_parameter("flow", float(b.phase) + t * float(b.flow))
		var g := clampf(t / maxf(0.01, total), 0.0, 1.0)
		node.scale = (b.from as Vector3).lerp(b.to, 1.0 - pow(1.0 - g, 2.0))
	if not _runs.is_empty():
		var figures := _figures()
		for r in _runs:
			var node: Node3D = r.node
			if not is_instance_valid(node): continue
			var t := (age - float(r.delay)) / float(r.time)
			node.visible = t >= 0.0 and t <= 1.0
			if not node.visible: continue
			node.position = (r.from as Vector3).lerp(r.to, t)
			if bool(r.get("flat", false)): continue
			var at := node.global_position
			for f in figures:
				if Vector2(f.x - at.x, f.z - at.z).length() < CLEAR * 0.8:
					node.visible = false
					break
	for s in _splats:
		var t := age - float(s.delay)
		var mat: ShaderMaterial = s.mat
		(s.node as Node3D).visible = t >= 0.0
		if t < 0.0: continue
		var spread := float(s.spread)
		# The splash plays its first 40 frames as it spreads, then holds and dries.
		mat.set_shader_parameter("frame", clampf(t / spread, 0.0, 1.0) * 40.0)
		var dry := clampf((t - spread - float(s.hold)) / float(s.dry), 0.0, 1.0)
		mat.set_shader_parameter("erode", dry * 0.95)
		mat.set_shader_parameter("flow", float(s.phase) + t * 0.25)
	for s in _shafts:
		var t := age - float(s.delay)
		var mat: ShaderMaterial = s.mat
		var u := clampf(t / float(s.life), 0.0, 1.0) if t >= 0.0 else 0.0
		var k := 0.0 if t < 0.0 else (u / 0.2 if u < 0.2 else 1.0 - (u - 0.2) / 0.8)
		mat.set_shader_parameter("gain", k * float(s.gain))
		mat.set_shader_parameter("flow", -t * 0.8)
	for g in _glows:
		var t := age - float(g.delay)
		var mat: StandardMaterial3D = g.mat
		if t < 0.0:
			mat.albedo_color = Color.BLACK
			continue
		var u := clampf(t / maxf(0.01, float(g.life)), 0.0, 1.0)
		var k := u / float(g.rise) if u < float(g.rise) else 1.0 - (u - float(g.rise)) / (1.0 - float(g.rise))
		var c: Color = g.colour
		mat.albedo_color = Color(c.r * k, c.g * k, c.b * k, 1.0)
	if age >= life: queue_free()

# --- Bands: arcs, rings, beams, cracks ------------------------------------------------------

static func _band_material(additive: bool) -> ShaderMaterial:
	var key := "add" if additive else "mix"
	if not _band_shaders.has(key):
		var shader := Shader.new()
		shader.code = BAND_CODE % (", blend_add, fog_disabled" if additive else "")
		_band_shaders[key] = shader
	var mat := ShaderMaterial.new()
	mat.shader = _band_shaders[key]
	mat.set_shader_parameter("noise_tex", tex("noise"))
	mat.set_shader_parameter("mask_tex", tex("slash"))
	return mat

## A strip through `points` (local), each with its half-width; UV.x runs along it.
static func _strip_mesh(points: PackedVector3Array, halves: PackedFloat32Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var n := points.size()
	for i in range(n):
		var a := points[maxi(i - 1, 0)]
		var b := points[mini(i + 1, n - 1)]
		var along := b - a
		along.y = 0.0
		along = along.normalized() if along.length_squared() > 0.000001 else Vector3.FORWARD
		var side := along.cross(Vector3.UP)
		verts.append(points[i] - side * halves[i])
		verts.append(points[i] + side * halves[i])
		var u := float(i) / float(n - 1)
		uvs.append(Vector2(u, 0.0))
		uvs.append(Vector2(u, 1.0))
		if i < n - 1:
			var k := i * 2
			idx.append_array(PackedInt32Array([k, k + 1, k + 2, k + 1, k + 3, k + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## One band. opts: delay, sweep (s to open along its length), hold, fade, wipe
## (erase from its start instead of fading), additive, soft, from/to (scale), at.
func band(points: PackedVector3Array, halves: PackedFloat32Array, core: Color, edge: Color, opts: Dictionary = {}) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = _strip_mesh(points, halves)
	var mat := _band_material(bool(opts.get("additive", false)))
	mat.set_shader_parameter("core", core)
	mat.set_shader_parameter("edge", edge)
	mat.set_shader_parameter("soft", float(opts.get("soft", 0.6)))
	mat.set_shader_parameter("use_mask", 1.0 if bool(opts.get("mask", false)) else 0.0)
	mat.set_shader_parameter("tiling", opts.get("tiling", Vector2(3.0, 1.0)))
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	node.position = opts.get("at", Vector3.ZERO)
	var entry := {"node": node, "mat": mat, "delay": float(opts.get("delay", 0.0)), "sweep": float(opts.get("sweep", 0.0)),
		"hold": float(opts.get("hold", 0.08)), "fade": float(opts.get("fade", 0.25)), "wipe": bool(opts.get("wipe", false)),
		"from": opts.get("from", Vector3.ONE), "to": opts.get("to", Vector3.ONE), "erode": bool(opts.get("erode", true)),
		"flow": float(opts.get("flow", 1.2)), "phase": randf()}
	_bands.append(entry)
	life = maxf(life, float(entry.delay) + float(entry.sweep) + float(entry.hold) + float(entry.fade) + 0.05)
	return node

## A crescent swept round the figure: `reach` out, `degrees` wide, thickest in
## the middle and sharp at both tips, opening from one side to the other.
func arc(forward: Vector3, reach: float, degrees: float, width: float, core: Color, edge: Color, opts: Dictionary = {}) -> void:
	var points := PackedVector3Array()
	var halves := PackedFloat32Array()
	var n := maxi(12, int(degrees / 5.0))
	var flip := -1.0 if bool(opts.get("flip", false)) else 1.0
	for i in range(n + 1):
		var u := float(i) / float(n)
		var thick := pow(sin(u * PI), 0.6)
		var r := reach - width * 0.5 * thick
		points.append(forward.rotated(Vector3.UP, deg_to_rad(-degrees * 0.5 + degrees * u) * flip) * r + Vector3.UP * GROUND)
		halves.append(maxf(P * 0.3, width * 0.5 * thick))
	var o := opts.duplicate()
	o.sweep = float(opts.get("sweep", 0.12))
	o.wipe = bool(opts.get("wipe", true))
	band(points, halves, core, edge, o)

## A ring on the ground spreading from `from_share` of `radius` out to it.
func ring(radius: float, width: float, core: Color, edge: Color, opts: Dictionary = {}) -> void:
	var points := PackedVector3Array()
	var halves := PackedFloat32Array()
	var n := maxi(32, int(radius * 12.0))
	for i in range(n + 1):
		var a := TAU * i / n
		points.append(Vector3(cos(a), 0.0, sin(a)) * radius + Vector3.UP * GROUND)
		halves.append(width * 0.5)
	var o := opts.duplicate()
	var s := float(opts.get("from_share", 0.3))
	o.from = Vector3(s, 1.0, s)
	o.to = Vector3.ONE
	o.hold = float(opts.get("hold", 0.0))
	o.fade = float(opts.get("fade", 0.35))
	band(points, halves, core, edge, o)

## A beam along `dir` from `start` out `length`, tapering to its point.
func beam(dir: Vector3, length: float, width: float, core: Color, edge: Color, opts: Dictionary = {}) -> void:
	var points := PackedVector3Array()
	var halves := PackedFloat32Array()
	var start := float(opts.get("start", 0.0))
	var n := maxi(6, int(length / 0.4))
	for i in range(n + 1):
		var u := float(i) / float(n)
		points.append(dir * (start + length * u) + Vector3.UP * GROUND)
		halves.append(width * 0.5 * (1.0 - 0.75 * pow(u, 3.0)) * minf(1.0, u * 8.0 + 0.3))
	var o := opts.duplicate()
	o.erase("start")
	o.sweep = float(opts.get("sweep", 0.08))
	band(points, halves, core, edge, o)

## A jagged crack out along `dir`, opening fast and fading slow.
func crack(dir: Vector3, reach: float, colour: Color, glow_colour: Color) -> void:
	var points := PackedVector3Array()
	var halves := PackedFloat32Array()
	var side := dir.cross(Vector3.UP)
	var n := 6
	var wander := 0.0
	for i in range(n + 1):
		var u := float(i) / float(n)
		wander += randf_range(-0.12, 0.12) * reach
		points.append(dir * reach * u + side * wander * u + Vector3.UP * (GROUND - 0.01))
		halves.append(P * 0.9 * (1.0 - u * 0.7))
	band(points, halves, colour, glow_colour, {"sweep": 0.08, "hold": 0.5, "fade": 0.4, "soft": 0.3})

# --- Crystals and solid pieces --------------------------------------------------------------

## A faceted hexagonal bipyramid, `w` wide and `h` tall, each face shaded by
## its facing (light from the upper left), lit toward the tip.
static func _crystal_mesh(w: float, h: float, body: Color, hot: Color) -> ArrayMesh:
	var top := Vector3(0.0, h, 0.0)
	var foot := Vector3(0.0, -h * 0.06, 0.0)
	var corners: Array[Vector3] = []
	for i in range(6):
		var a := TAU * i / 6.0 + 0.26
		corners.append(Vector3(cos(a) * w, h * 0.3, sin(a) * w * 0.85))
	var light := Vector3(-0.55, 0.75, 0.45).normalized()
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	for i in range(6):
		var a := corners[i]
		var b := corners[(i + 1) % 6]
		var normal := (b - a).cross(top - a).normalized()
		var k := clampf(0.3 + 0.7 * maxf(0.0, normal.dot(light) if normal.y >= 0.0 else -normal.dot(light)), 0.0, 1.0)
		var face := body.darkened(0.5).lerp(body.lightened(0.3), k)
		verts.append_array(PackedVector3Array([a, b, top]))
		cols.append_array(PackedColorArray([face, face, hot.lerp(face, 0.25)]))
		var low := face.darkened(0.45)
		verts.append_array(PackedVector3Array([b, a, foot]))
		cols.append_array(PackedColorArray([low, low, body.darkened(0.7)]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _piece(mesh: Mesh, at: Vector3, opts: Dictionary) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = opts.get("tint", Color.WHITE)
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	node.position = at
	var delay := float(opts.get("delay", 0.0))
	node.visible = delay <= 0.0
	var span := float(opts.get("life", 0.6))
	_bits.append({"node": node, "mat": mat, "vel": opts.get("vel", Vector3.ZERO), "grav": float(opts.get("grav", 0.0)), "delay": delay, "life": span,
		"fade": float(opts.get("fade", 0.3)), "alpha": (mat.albedo_color as Color).a, "from": opts.get("from", Vector3.ONE), "to": opts.get("to", Vector3.ONE), "grow": float(opts.get("grow", 0.0))})
	life = maxf(life, delay + span + 0.05)
	return node

## A crystal (or ice spike) breaking out of the ground at `at` (local), leaning
## a little, then shattering into fine chips. Not next to a figure.
func crystal(at: Vector3, tall: float, body: Color, hot: Color, delay: float = 0.0, keep: float = 0.5) -> void:
	if not clear_at(global_position + at): return
	tall *= 1.4
	var w := maxf(P * 3.0, tall * 0.26)
	var node := _piece(_crystal_mesh(w, tall, body, hot), at, {"delay": delay, "life": keep, "fade": 0.25, "from": Vector3(0.6, 0.02, 0.6), "to": Vector3.ONE, "grow": 0.22})
	node.basis = Basis(Vector3.UP, randf() * TAU) * Basis(Vector3.RIGHT, randf_range(-0.22, 0.22)) * Basis(Vector3.FORWARD, randf_range(-0.22, 0.22))
	burst({"at": at + Vector3.UP * tall * 0.5, "radius": w, "amount": 8, "time": 0.5, "speed": [0.8, 2.2], "spread": 70.0, "gravity": Vector3(0, -GRAVITY, 0),
		"size": P * 1.0, "colours": [hot, body, Color(body.r, body.g, body.b, 0.0)], "delay": delay + keep * 0.8, "near_ok": true})
	burst({"at": at + Vector3.UP * 0.05, "radius": w, "amount": 6, "time": 0.4, "speed": [0.6, 1.6], "spread": 60.0, "gravity": Vector3(0, -GRAVITY, 0),
		"size": P * 0.9, "colours": [body.lightened(0.2), body, Color(body.r, body.g, body.b, 0.0)], "delay": delay, "near_ok": true})

# --- Ground fluids and light shafts ---------------------------------------------------------

static var _splat_shaders := {}

## A liquid splash on the ground, `radius` across, spreading over `spread` s,
## then holding and drying away. Flat, so it never covers anyone standing in it.
func splat(radius: float, core: Color, edge: Color, opts: Dictionary = {}) -> void:
	var key := "add" if bool(opts.get("additive", false)) else "mix"
	if not _splat_shaders.has(key):
		var shader := Shader.new()
		shader.code = SPLAT_CODE % (", blend_add, fog_disabled" if key == "add" else "")
		_splat_shaders[key] = shader
	var mat := ShaderMaterial.new()
	mat.shader = _splat_shaders[key]
	mat.set_shader_parameter("flip_tex", tex("splash_8x8"))
	mat.set_shader_parameter("noise_tex", tex("noise"))
	mat.set_shader_parameter("core", core)
	mat.set_shader_parameter("edge", edge)
	mat.set_shader_parameter("spin", randf() * TAU)
	mat.set_shader_parameter("wobble", float(opts.get("wobble", 0.035)))
	var node := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(radius * 2.0, radius * 2.0)
	node.mesh = plane
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	node.position = opts.get("at", Vector3.ZERO) + Vector3.UP * (GROUND - 0.015)
	var entry := {"node": node, "mat": mat, "delay": float(opts.get("delay", 0.0)), "spread": float(opts.get("spread", 0.35)),
		"hold": float(opts.get("hold", 0.6)), "dry": float(opts.get("dry", 0.8)), "phase": randf() * 4.0}
	_splats.append(entry)
	life = maxf(life, float(entry.delay) + float(entry.spread) + float(entry.hold) + float(entry.dry) + 0.05)

static var _shaft_shader: Shader

## A shaft of light rising `height` from a circle of `radius` — only where nobody stands.
func shaft(at: Vector3, radius: float, height: float, colour: Color, gain: float = 1.0, time: float = 0.7, delay: float = 0.0) -> void:
	if not clear_at(global_position + at, CLEAR + radius): return
	if _shaft_shader == null:
		_shaft_shader = Shader.new()
		_shaft_shader.code = SHAFT_CODE
	var mat := ShaderMaterial.new()
	mat.shader = _shaft_shader
	mat.set_shader_parameter("noise_tex", tex("noise"))
	mat.set_shader_parameter("colour", colour)
	var node := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = radius * 0.7
	tube.bottom_radius = radius
	tube.height = height
	tube.cap_top = false
	tube.cap_bottom = false
	tube.radial_segments = 20
	node.mesh = tube
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	node.position = at + Vector3.UP * height * 0.5
	_shafts.append({"mat": mat, "delay": delay, "life": time, "gain": gain})
	life = maxf(life, delay + time)

# --- Light ----------------------------------------------------------------------------------

static func soft_texture() -> GradientTexture2D:
	if _soft == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color.WHITE)
		gradient.add_point(0.3, Color(0.6, 0.6, 0.6))
		gradient.set_color(gradient.get_point_count() - 1, Color(0, 0, 0, 0))
		_soft = GradientTexture2D.new()
		_soft.gradient = gradient
		_soft.fill = GradientTexture2D.FILL_RADIAL
		_soft.fill_from = Vector2(0.5, 0.5)
		_soft.fill_to = Vector2(0.5, 0.0)
		_soft.width = 64
		_soft.height = 64
	return _soft

func _glow_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	# Additive light ignores fog: fog would tint the quad's black corners and
	# add them, drawing the whole quad as a pale square (用户 2026-10-21).
	mat.disable_fog = true
	mat.albedo_texture = soft_texture()
	mat.albedo_color = Color.BLACK
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return mat

## Light thrown on the ground round the blow: an additive soft pool of `radius`.
func glow(radius: float, colour: Color, gain: float = 0.8, time: float = 0.35, delay: float = 0.0, at: Vector3 = Vector3.ZERO, rise: float = 0.15) -> void:
	var node := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(radius * 2.0, radius * 2.0)
	node.mesh = plane
	var mat := _glow_material()
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	node.position = at + Vector3.UP * 0.03
	_glows.append({"mat": mat, "colour": colour * gain, "delay": delay, "life": time, "rise": rise})
	life = maxf(life, delay + time)

## A soft halo in the air round a hot core (it faces the camera). Not by a figure.
func halo(at: Vector3, size: float, colour: Color, gain: float = 0.7, time: float = 0.3, delay: float = 0.0) -> void:
	if not clear_at(global_position + at, CLEAR + size * 0.35): return
	var node := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	node.mesh = quad
	var mat := _glow_material()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	node.material_override = mat
	add_child(node)
	node.position = at
	_glows.append({"mat": mat, "colour": colour * gain, "delay": delay, "life": time, "rise": 0.12})
	life = maxf(life, delay + time)

# --- Particles ------------------------------------------------------------------------------

## One burst. opts: at (local), amount, time, speed [min, max], dir, spread,
## gravity, size, radius / box / ring [inner, outer], additive, soft (round),
## colours [start, mid, end], tints (random start colours), radial, tangential,
## damping, explosive, delay, flat (stays on the ground), near_ok.
## Unless `near_ok`, its emitter keeps clear of every figure: it is moved out
## to a ring round one that stands at its centre, or shrunk off one at its edge.
func burst(opts: Dictionary) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var at: Vector3 = opts.get("at", Vector3.UP * 0.3)
	var radius := float(opts.get("radius", 0.2))
	p.amount = maxi(1, int(opts.get("amount", 16)))
	p.lifetime = float(opts.get("time", 0.6))
	p.one_shot = true
	p.explosiveness = float(opts.get("explosive", 0.95))
	p.local_coords = false
	if opts.has("box"):
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = opts.box
	elif opts.has("ring"):
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		p.emission_ring_axis = Vector3.UP
		p.emission_ring_height = 0.05
		p.emission_ring_inner_radius = float(opts.ring[0])
		p.emission_ring_radius = float(opts.ring[1])
	else:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = radius
		if not bool(opts.get("near_ok", false)):
			var d := _nearest(global_position + at)
			if d < CLEAR:
				# A figure stands at its heart: throw from a ring round it instead.
				p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
				p.emission_ring_axis = Vector3.UP
				p.emission_ring_height = 0.05
				p.emission_ring_inner_radius = CLEAR - d + 0.1
				p.emission_ring_radius = maxf(radius, CLEAR - d + 0.6)
				p.radial_accel_min = 1.5
				p.radial_accel_max = 2.5
			elif d < radius + CLEAR:
				p.emission_sphere_radius = maxf(0.05, d - CLEAR)
	p.direction = opts.get("dir", Vector3.UP)
	p.spread = float(opts.get("spread", 60.0))
	var speed: Array = opts.get("speed", [1.0, 3.0])
	p.initial_velocity_min = float(speed[0])
	p.initial_velocity_max = float(speed[1])
	p.gravity = opts.get("gravity", Vector3(0, -6.0, 0))
	if opts.has("radial"):
		p.radial_accel_min = float(opts.radial)
		p.radial_accel_max = float(opts.radial)
	if opts.has("tangential"):
		p.tangential_accel_min = float(opts.tangential)
		p.tangential_accel_max = float(opts.tangential)
	p.damping_min = float(opts.get("damping", 0.0))
	p.damping_max = float(opts.get("damping", 0.0))
	if bool(opts.get("flat", false)):
		p.direction = Vector3(opts.get("dir", Vector3.RIGHT).x, 0.0, opts.get("dir", Vector3.RIGHT).z)
		p.gravity = Vector3.ZERO
	var size := float(opts.get("size", P * 1.2))
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var ramp := Gradient.new()
	var colours: Array = opts.get("colours", [Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	ramp.set_color(0, colours[0])
	ramp.add_point(0.35, colours[1])
	ramp.set_color(ramp.get_point_count() - 1, colours[2])
	p.color_ramp = ramp
	if opts.has("tints"):
		var tints := Gradient.new()
		var list: Array = opts.tints
		tints.set_color(0, list[0])
		tints.set_color(1, list[list.size() - 1])
		for i in range(1, list.size() - 1): tints.add_point(float(i) / float(list.size() - 1), list[i])
		tints.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
		p.color_initial_ramp = tints
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if bool(opts.get("additive", false)):
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.disable_fog = true
	if bool(opts.get("soft", false)): mat.albedo_texture = soft_texture()
	if opts.has("flip") and tex(str(opts.flip)) != null:
		# A baked fluid puff: each particle plays the 8×8 sheet once over its life, turned at random.
		mat.albedo_texture = tex(str(opts.flip))
		mat.particles_anim_h_frames = 8
		mat.particles_anim_v_frames = 8
		mat.particles_anim_loop = false
		p.anim_speed_min = 1.0
		p.anim_speed_max = 1.0
		p.angle_min = -180.0
		p.angle_max = 180.0
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	quad.material = mat
	p.mesh = quad
	add_child(p)
	p.position = at
	var delay := float(opts.get("delay", 0.0))
	if delay > 0.0:
		p.emitting = false
		get_tree().create_timer(delay, false).timeout.connect(func(): if is_instance_valid(p): p.restart())
	else:
		p.emitting = true
	life = maxf(life, delay + p.lifetime + 0.1)
	return p

## Fine chips of stone thrown up and falling back.
func chips(at: Vector3, count: int, radius: float, colour: Color, up: float = 3.0, delay: float = 0.0) -> void:
	burst({"at": at, "radius": radius, "amount": count, "time": 0.7, "speed": [up * 0.4, up], "spread": 55.0, "gravity": Vector3(0, -GRAVITY, 0),
		"size": P * 1.1, "tints": [colour.darkened(0.25), colour, colour.lightened(0.2)], "colours": [Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)], "delay": delay})

## Sparks: bright additive points thrown out (blades, steel on stone).
func sparks(at: Vector3, colour: Color, hot: Color, amount: int = 14, speed: float = 4.0, dir: Vector3 = Vector3.UP, spread: float = 70.0, delay: float = 0.0) -> void:
	burst({"at": at, "amount": amount, "time": 0.35, "speed": [speed * 0.5, speed], "dir": dir, "spread": spread, "gravity": Vector3(0, -9.0, 0),
		"size": P * 0.9, "additive": true, "colours": [hot, colour, Color(colour.r, colour.g, colour.b, 0.0)], "delay": delay})

## Embers: slow, glowing, rising (originium, fire).
func embers(at: Vector3, colour: Color, hot: Color, amount: int = 16, radius: float = 1.0, delay: float = 0.0, time: float = 1.0) -> void:
	burst({"at": at, "amount": amount, "time": time, "speed": [0.4, 1.4], "dir": Vector3.UP, "spread": 35.0, "gravity": Vector3(0, 0.6, 0),
		"radius": radius, "size": P * 1.0, "additive": true, "explosive": 0.6, "colours": [hot, colour, Color(colour.r * 0.5, colour.g * 0.5, colour.b * 0.5, 0.0)], "delay": delay})

## Dust: a soft round plume that hangs and spreads.
func dust(at: Vector3, colour: Color, amount: int = 14, radius: float = 0.6, delay: float = 0.0, up: float = 1.0) -> void:
	burst({"at": at, "amount": amount, "time": 0.9, "speed": [0.3 * up, 1.1 * up], "dir": Vector3.UP, "spread": 80.0, "gravity": Vector3(0, -0.3, 0),
		"radius": radius, "size": P * 14.0, "flip": "smoke_8x8", "damping": 1.5,
		"colours": [Color(colour.r, colour.g, colour.b, 0.9), Color(colour.r, colour.g, colour.b, 0.7), Color(colour.r, colour.g, colour.b, 0.0)], "delay": delay})

## Small bursts every `step` along a strip (local), skipping the stretches a figure stands on.
func along_strip(from: Vector3, to: Vector3, step: float, opts: Dictionary) -> void:
	var line := to - from
	line.y = 0.0
	var n := maxi(1, int(line.length() / step))
	for k in range(n):
		var at := from + line * ((k + 0.5) / n)
		if not clear_at(global_position + at): continue
		var o := opts.duplicate()
		o.at = at + Vector3.UP * float(opts.get("lift", 0.15))
		o.near_ok = true
		burst(o)

static func shake(manager: GameManager, pixels: float, frames: int) -> void:
	if manager.has_method("start_impact_shake"): manager.start_impact_shake(pixels, frames)

# --- Things that run along a strip ----------------------------------------------------------

static func _unlit(colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = colour
	return mat

func _ball(parent: Node3D, radius: float, squash: Vector3, at: Vector3, colour: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	node.mesh = mesh
	node.material_override = _unlit(colour)
	node.scale = squash
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	node.position = at

## Rats (鼠潮) or wolves (群狼) pouring down a strip from `a` to `b` (local).
func runners(a: Vector3, b: Vector3, count: int, kind: String, time: float, spread: float) -> void:
	var along := b - a
	along.y = 0.0
	var side := along.normalized().cross(Vector3.UP)
	for i in range(count):
		var off := side * randf_range(-spread, spread) * 0.5
		var holder := Node3D.new()
		add_child(holder)
		if kind == "rat":
			var fur := Color("8a847c").lerp(Color("b0a89c"), randf())
			_ball(holder, 0.11, Vector3(1.0, 0.65, 1.7), Vector3(0, 0.08, 0), fur)
			_ball(holder, 0.06, Vector3(1.0, 0.9, 1.3), Vector3(0, 0.1, -0.2), fur.lightened(0.1))
			_ball(holder, 0.018, Vector3.ONE, Vector3(0.03, 0.13, -0.27), Color("ff4a4a"))
			_ball(holder, 0.018, Vector3.ONE, Vector3(-0.03, 0.13, -0.27), Color("ff4a4a"))
			var tail := PackedVector3Array([Vector3(0, 0.06, 0.18), Vector3(0.04, 0.05, 0.3), Vector3(-0.02, 0.04, 0.42)])
			var t := MeshInstance3D.new()
			t.mesh = _strip_mesh(tail, PackedFloat32Array([0.012, 0.009, 0.004]))
			t.material_override = _unlit(Color("c89a94"))
			holder.add_child(t)
		else:
			var coat := Color("1e1618").lerp(Color("3a3034"), randf())
			_ball(holder, 0.17, Vector3(1.0, 0.8, 2.2), Vector3(0, 0.22, 0), coat)
			_ball(holder, 0.1, Vector3(1.0, 0.9, 1.4), Vector3(0, 0.3, -0.42), coat.lightened(0.05))
			_ball(holder, 0.025, Vector3.ONE, Vector3(0.05, 0.34, -0.53), colours("zaro").hot)
			_ball(holder, 0.025, Vector3.ONE, Vector3(-0.05, 0.34, -0.53), colours("zaro").hot)
		holder.basis = Basis.looking_at(along.normalized())
		holder.visible = false
		var delay := randf() * time * 0.35
		_runs.append({"node": holder, "from": a + off, "to": b + off, "delay": delay, "time": time})
	life = maxf(life, time * 1.4 + 0.2)

# --- Who does what --------------------------------------------------------------------------

## The effect of one landed segment. `ctx`: what the windup worked out (spots, lanes, end).
static func play(manager: GameManager, figure: Boss, seg: Dictionary, ctx: Dictionary) -> void:
	var c := colours(figure.figure_id)
	var shape := str(seg.shape)
	var id := str(seg.get("id", ""))
	var me := figure.global_position
	var dir := figure.attack_direction
	var floor_me := Vector3(me.x, manager.ground_y(me) + 0.01, me.z)
	var edge := Color(c.main.r, c.main.g, c.main.b, 0.0)
	match shape:
		"sector":
			var fx := make(manager, floor_me)
			var reach := float(seg.reach)
			var angle := float(seg.angle)
			if id == "bite":
				# 撕咬: two jaws of red close flat on the ground, blood spatters out.
				var mid := dir * reach * 0.62
				var side := dir.cross(Vector3.UP)
				for k in [-1.0, 1.0]:
					var jaw := PackedVector3Array()
					var halves := PackedFloat32Array()
					for i in range(9):
						var u := float(i) / 8.0
						jaw.append(dir * (u - 0.5) * reach * 1.2 + side * k * sin(u * PI) * reach * 0.2 + Vector3.UP * GROUND)
						halves.append(P * 3.2 * sin(u * PI) + P * 0.5)
					var node := fx.band(jaw, halves, c.hot, c.main, {"hold": 0.15, "fade": 0.3, "at": mid + side * k * reach * 0.6})
					fx._runs.append({"node": node, "from": mid + side * k * reach * 0.6, "to": mid + side * k * reach * 0.12, "delay": 0.0, "time": 0.1, "flat": true})
				fx.burst({"at": mid + Vector3.UP * 0.05, "ring": [0.2, 0.5], "amount": 24, "time": 0.6, "speed": [1.0, 2.5], "dir": Vector3.UP, "spread": 80.0, "gravity": Vector3(0, -9.0, 0), "size": P * 1.1,
					"radial": 3.0, "colours": [c.hot, c.main, Color(c.dark.r, c.dark.g, c.dark.b, 0.0)], "delay": 0.1})
				fx.glow(1.2, c.main, 0.6, 0.3, 0.1, mid)
				fx.splat(reach * 0.8, c.main, Color(c.dark.r, c.dark.g, c.dark.b, 0.9), {"at": mid, "delay": 0.1, "spread": 0.3, "hold": 0.9, "dry": 1.0})
				shake(manager, 2.0, 6)
			elif figure.figure_id == "zaro" or id == "twin":
				# Claws: three (two for 弑君者's blades) slashes laid across the cone.
				var count := 2 if id == "twin" else 3
				for i in range(count):
					var side := dir.cross(Vector3.UP) * (i - (count - 1) * 0.5) * reach * 0.22
					var tilt := dir.rotated(Vector3.UP, deg_to_rad(35.0 if i % 2 == 0 else -35.0) if id == "twin" else deg_to_rad(28.0))
					var mid := dir * reach * 0.6 + side
					var points := PackedVector3Array()
					var halves := PackedFloat32Array()
					for k in range(11):
						var u := float(k) / 10.0
						points.append(mid + tilt * (u - 0.5) * reach * 1.2 + tilt.cross(Vector3.UP) * sin(u * PI) * reach * 0.08 + Vector3.UP * GROUND)
						halves.append(P * 2.6 * pow(sin(u * PI), 0.7) + P * 0.2)
					fx.band(points, halves, c.hot, c.main, {"sweep": 0.07, "hold": 0.15, "fade": 0.3, "wipe": true, "delay": 0.04 * i, "soft": 0.5})
				fx.burst({"at": dir * reach * 0.6 + Vector3.UP * 0.3, "amount": 26, "time": 0.55, "speed": [2.0, 4.5], "dir": dir + Vector3.UP * 0.6, "spread": 55.0, "gravity": Vector3(0, -9.0, 0), "size": P * 1.0,
					"colours": [c.hot, c.main, Color(c.dark.r, c.dark.g, c.dark.b, 0.0)]})
				fx.glow(reach * 0.8, c.main, 0.55, 0.3, 0.0, dir * reach * 0.5)
				fx.splat(reach * 0.8, c.main, Color(c.dark.r, c.dark.g, c.dark.b, 0.9), {"at": dir * reach * 0.8, "delay": 0.06, "spread": 0.3, "hold": 0.8, "dry": 0.9})
			elif id == "buckshot":
				# 鹿弹: a cone of pellet tracers, the muzzle flash and its smoke.
				for i in range(9):
					var ray := dir.rotated(Vector3.UP, deg_to_rad(randf_range(-angle, angle) * 0.5))
					fx.beam(ray, reach * randf_range(0.7, 1.0), P * 1.4, c.hot, c.main, {"start": 0.5, "sweep": 0.06, "hold": 0.02, "fade": 0.12, "additive": true})
				fx.halo(dir * 0.6 + Vector3.UP * 0.4, 1.2, c.hot, 0.9, 0.12)
				fx.glow(reach * 0.6, c.main, 0.5, 0.18, 0.0, dir * reach * 0.4)
				fx.sparks(dir * 0.6 + Vector3.UP * 0.4, c.main, c.hot, 16, 7.0, dir, 25.0)
				fx.burst({"at": dir * 0.6 + Vector3.UP * 0.4, "amount": 10, "time": 0.9, "speed": [0.3, 0.9], "dir": dir + Vector3.UP, "spread": 40.0, "gravity": Vector3(0, 0.3, 0), "size": P * 6.0, "soft": true, "damping": 1.0,
					"colours": [Color(0.8, 0.8, 0.8, 0.45), Color(0.6, 0.6, 0.62, 0.3), Color(0.5, 0.5, 0.5, 0.0)]})
			else:
				# A swing: the crescent opens across, sparks off its edge, dust under it.
				var w := P * (8.0 if reach >= 2.8 else 6.0)
				fx.arc(dir, reach, angle, w * 1.4, c.hot, edge, {"sweep": 0.12, "hold": 0.06, "fade": 0.3, "mask": true, "tiling": Vector2(2.0, 0.6)})
				fx.arc(dir, reach * 0.78, angle * 0.9, w * 0.45, c.main, edge, {"sweep": 0.14, "hold": 0.04, "fade": 0.22, "additive": true})
				for i in range(4):
					var ray := dir.rotated(Vector3.UP, deg_to_rad(-angle * 0.5 + angle * (i + 0.5) / 4.0))
					fx.sparks(ray * reach + Vector3.UP * 0.2, c.main, c.hot, 7, 3.5, ray + Vector3.UP * 0.5, 40.0, 0.03 * i)
				fx.glow(reach, c.main, 0.45, 0.3, 0.0, dir * reach * 0.45)
				fx.dust(dir * reach * 0.6 + Vector3.UP * 0.1, c.dust, 8, reach * 0.4, 0.06)
				fx.chips(dir * reach * 0.7 + Vector3.UP * 0.1, 10, reach * 0.3, c.dust, 1.8, 0.06)
		"lane":
			var fx := make(manager, floor_me)
			var reach := float(seg.reach)
			fx.beam(dir, reach, P * 6.0, c.hot, edge, {"start": 0.3, "hold": 0.08, "fade": 0.25})
			fx.beam(dir, reach, P * 2.5, c.main, edge, {"start": 0.3, "hold": 0.06, "fade": 0.2, "additive": true})
			var tip := make(manager, Vector3(me.x, 0, me.z) + dir * reach)
			tip.global_position.y = manager.ground_y(tip.global_position) + 0.01
			tip.ring(1.1, P * 2.5, c.hot, edge, {"delay": 0.08, "fade": 0.3})
			tip.glow(1.6, c.main, 0.8, 0.3, 0.06)
			tip.halo(Vector3.UP * 0.35, 1.0, c.hot, 0.8, 0.15, 0.06)
			tip.sparks(Vector3.UP * 0.2, c.main, c.hot, 16, 4.5, dir + Vector3.UP * 0.4, 60.0, 0.06)
			tip.chips(Vector3.UP * 0.1, 12, 0.3, c.dust, 2.4, 0.08)
			fx.glow(reach * 0.6, c.main, 0.35, 0.25, 0.0, dir * reach * 0.5)
		"charge":
			# A trail down the run, dust hanging along it, a ring where it stops.
			var from: Vector3 = figure.attack_origin
			var fx := make(manager, Vector3(from.x, manager.ground_y(from) + 0.01, from.z))
			var run := me - from
			run.y = 0.0
			var length := run.length()
			if length > 0.3:
				fx.beam(run.normalized(), length, P * 7.0, Color(c.main.r, c.main.g, c.main.b, 0.85), edge, {"sweep": 0.06, "hold": 0.1, "fade": 0.35, "wipe": true})
				fx.along_strip(Vector3.ZERO, run, 0.8, {"amount": 6, "time": 0.8, "speed": [0.2, 0.7], "spread": 80.0, "gravity": Vector3(0, -0.3, 0), "size": P * 6.0, "soft": true, "damping": 1.5, "radius": 0.2,
					"colours": [Color(c.dust.r, c.dust.g, c.dust.b, 0.5), Color(c.dust.r, c.dust.g, c.dust.b, 0.3), Color(c.dust.r, c.dust.g, c.dust.b, 0.0)]})
			var end := make(manager, floor_me)
			end.ring(1.4, P * 3.0, c.hot, edge, {"fade": 0.3})
			end.glow(2.0, c.main, 0.7, 0.35)
			end.chips(Vector3.UP * 0.1, 14, 0.6, c.dust, 2.6)
			end.dust(Vector3.UP * 0.1, c.dust, 12, 0.8)
			shake(manager, 2.0, 6)
		"self":
			var fx := make(manager, floor_me)
			var r := float(seg.radius)
			fx.ring(r, P * 4.0, c.hot, edge, {"fade": 0.4})
			fx.ring(r * 0.75, P * 2.0, c.main, edge, {"delay": 0.05, "fade": 0.35, "additive": true})
			for i in range(7): fx.crack(dir.rotated(Vector3.UP, TAU * i / 7.0 + randf_range(-0.3, 0.3)), r * randf_range(0.6, 0.95), c.dark, c.main)
			fx.glow(r * 1.5, c.main, 1.0, 0.45)
			if figure.figure_id == "patriot": fx.splat(r * 0.95, c.hot, Color(c.main.r, c.main.g, c.main.b, 0.0), {"additive": true, "spread": 0.3, "hold": 0.5, "dry": 0.9})
			else: fx.splat(r * 0.9, c.dust, Color(c.dark.r, c.dark.g, c.dark.b, 0.0), {"spread": 0.3, "hold": 0.4, "dry": 0.8})
			fx.chips(Vector3.UP * 0.1, 26, r * 0.7, c.dust, 3.2)
			fx.dust(Vector3.UP * 0.1, c.dust, 22, r * 0.8, 0.02, 1.4)
			fx.sparks(Vector3.UP * 0.2, c.main, c.hot, 20, 5.0, Vector3.UP, 75.0)
			if figure.figure_id == "patriot": fx.embers(Vector3.UP * 0.2, c.main, c.hot, 18, r * 0.7, 0.1)
			shake(manager, 3.0, 9)
		"front_circle", "hurl":
			var at: Vector3 = ctx.get("at", me)
			var fx := make(manager, Vector3(at.x, manager.ground_y(at) + 0.01, at.z))
			var r := float(seg.radius)
			fx.ring(r, P * 4.0, c.hot, edge, {"fade": 0.4})
			for i in range(6): fx.crack(dir.rotated(Vector3.UP, TAU * i / 6.0 + randf_range(-0.3, 0.3)), r * randf_range(0.7, 1.0), c.dark, c.main)
			# 木裂's hammer: ice crystals stand up round the blow, glitter and cold breath out of it.
			for i in range(9):
				var a := TAU * i / 9.0 + randf() * 0.4
				fx.crystal(Vector3(cos(a), 0, sin(a)) * r * randf_range(0.55, 0.95), randf_range(0.5, 0.95), c.dust, c.hot, 0.03 * i, 0.6)
			fx.glow(r * 1.6, c.main, 0.9, 0.5)
			fx.splat(r * 1.6, c.hot, Color(c.main.r, c.main.g, c.main.b, 0.3), {"spread": 0.35, "hold": 1.0, "dry": 1.0, "wobble": 0.02})
			fx.halo(Vector3.UP * 0.5, r * 1.1, c.hot, 0.6, 0.2)
			fx.burst({"at": Vector3.UP * 0.3, "radius": r * 0.5, "amount": 30, "time": 0.9, "speed": [1.5, 4.0], "spread": 80.0, "gravity": Vector3(0, -5.0, 0), "size": P * 0.9, "additive": true,
				"colours": [Color(1, 1, 1, 1), c.hot, Color(c.main.r, c.main.g, c.main.b, 0.0)]})
			fx.dust(Vector3.UP * 0.1, c.dust, 16, r * 0.7, 0.03, 1.2)
			fx.chips(Vector3.UP * 0.1, 18, r * 0.6, c.dust, 3.0)
			shake(manager, 3.0, 9)
		"ground":
			var spots: Array = ctx.get("spots", [ctx.get("at", manager.player.global_position)])
			var r := float(seg.radius)
			for spot in spots:
				var fx := make(manager, Vector3(spot.x, manager.ground_y(spot) + 0.01, spot.z))
				if id == "prison":
					# 沙狱: sand swirls in flat along the ground, a wall of sand pillars at the edge, a storm hanging inside it.
					fx.burst({"at": Vector3.UP * GROUND, "ring": [r * 0.7, r], "amount": 70, "time": 0.7, "speed": [0.2, 0.6], "dir": Vector3.RIGHT, "spread": 180.0, "flat": true,
						"radial": -3.0, "tangential": 4.0, "size": P * 1.4, "colours": [c.hot, c.main, Color(c.dark.r, c.dark.g, c.dark.b, 0.0)], "near_ok": true})
					fx.ring(r, P * 3.0, c.main, Color(c.dark.r, c.dark.g, c.dark.b, 0.0), {"from_share": 0.95, "fade": 0.6})
					for i in range(16):
						var a := TAU * i / 16.0
						fx.crystal(Vector3(cos(a), 0, sin(a)) * r, randf_range(0.35, 0.6), c.main.darkened(0.15), c.hot, 0.02 * i, 0.8)
					fx.burst({"at": Vector3.UP * 0.3, "radius": r * 0.9, "amount": 60, "time": 1.2, "speed": [0.4, 1.2], "dir": Vector3.UP, "spread": 80.0, "gravity": Vector3(0, -0.6, 0), "size": P * 1.2, "damping": 0.8, "explosive": 0.5,
						"colours": [Color(c.hot.r, c.hot.g, c.hot.b, 0.9), Color(c.main.r, c.main.g, c.main.b, 0.7), Color(c.dark.r, c.dark.g, c.dark.b, 0.0)]})
					fx.glow(r * 1.2, c.main, 0.45, 0.8, 0.0, Vector3.ZERO, 0.3)
					fx.splat(r * 1.15, c.hot, Color(c.main.r, c.main.g, c.main.b, 0.0), {"spread": 0.45, "hold": 1.2, "dry": 1.0, "wobble": 0.05})
				elif id == "grenade":
					_explosion(fx, r, c)
				elif id == "spike":
					for i in range(5):
						var a := TAU * i / 5.0 + randf()
						fx.crystal(Vector3(cos(a), 0, sin(a)) * r * randf_range(0.3, 0.7), randf_range(0.5, 0.85), c.main, c.hot, 0.02 * i, 0.55)
					fx.crystal(Vector3.ZERO, 0.95, c.main, c.hot, 0.0, 0.6)
					fx.ring(r, P * 2.0, c.hot, edge, {"fade": 0.35})
					fx.glow(r * 1.4, c.main, 0.8, 0.45)
					fx.splat(r * 1.1, c.hot, Color(c.main.r, c.main.g, c.main.b, 0.0), {"spread": 0.3, "hold": 0.8, "dry": 0.9, "wobble": 0.02})
					fx.halo(Vector3.UP * 0.6, r * 1.2, c.hot, 0.6, 0.3)
					fx.burst({"at": Vector3.UP * 0.4, "radius": r * 0.5, "amount": 24, "time": 0.9, "speed": [0.6, 2.0], "spread": 70.0, "gravity": Vector3(0, -1.0, 0), "size": P * 0.9, "additive": true,
						"colours": [Color(1, 1, 1, 1), c.hot, Color(c.main.r, c.main.g, c.main.b, 0.0)]})
				else:
					fx.ring(r, P * 2.5, c.hot, edge)
					fx.chips(Vector3.UP * 0.1, 12, r * 0.6, c.dust, 2.4)
		"safe_zones":
			# 源石爆发: originium breaks out everywhere but the safe circles; the floor lights from below.
			var centre := figure.centre()
			var fx := make(manager, Vector3(centre.x, manager.ground_y(centre) + 0.01, centre.z))
			var safe: Array = ctx.get("spots", [])
			var placed := 0
			for attempt in range(260):
				if placed >= 80: break
				var a := randf() * TAU
				var d := sqrt(randf()) * BossCatalog.ARENA_RADIUS
				var p := centre + Vector3(cos(a), 0, sin(a)) * d
				if safe.any(func(s): return Vector2(s.x - p.x, s.z - p.z).length() < BossCatalog.SAFE_RADIUS + 0.4): continue
				fx.crystal(p - centre, randf_range(0.6, 1.4), c.main.darkened(0.35), c.hot, d / BossCatalog.ARENA_RADIUS * 0.25, 0.75)
				if placed % 5 == 0: fx.splat(randf_range(0.9, 1.4), c.hot, Color(c.main.r, c.main.g, c.main.b, 0.0), {"at": p - centre, "additive": true, "delay": d / BossCatalog.ARENA_RADIUS * 0.25, "spread": 0.3, "hold": 0.6, "dry": 0.8})
				if placed % 16 == 0: fx.shaft(p - centre, 0.6, 3.5, c.main, 1.2, 1.0, d / BossCatalog.ARENA_RADIUS * 0.25)
				placed += 1
			fx.ring(BossCatalog.ARENA_RADIUS, P * 5.0, c.hot, edge, {"fade": 0.5})
			fx.glow(BossCatalog.ARENA_RADIUS * 1.2, c.main, 0.9, 1.1, 0.0, Vector3.ZERO, 0.2)
			fx.burst({"at": Vector3.UP * 0.2, "box": Vector3(BossCatalog.ARENA_RADIUS, 0.2, BossCatalog.ARENA_RADIUS), "amount": 180, "time": 1.4, "speed": [0.6, 2.2], "dir": Vector3.UP, "spread": 25.0,
				"gravity": Vector3(0, 0.4, 0), "size": P * 1.0, "additive": true, "explosive": 0.7, "near_ok": true, "colours": [c.hot, c.main, Color(c.main.r * 0.4, c.main.g * 0.4, c.main.b * 0.4, 0.0)]})
			for spot in safe:
				# The safe circles stay dark: a dim cool pool marks them out against the glare.
				fx.glow(BossCatalog.SAFE_RADIUS, Color(0.3, 0.6, 0.55), 0.35, 1.1, 0.0, Vector3(spot.x - centre.x, 0, spot.z - centre.z), 0.2)
			shake(manager, 5.0, 16)
		"lanes":
			var lanes: Array = ctx.get("lanes", [])
			var w := float(seg.width)
			for lane in lanes:
				var a: Vector3 = lane[0]
				var b: Vector3 = lane[1]
				var fx := make(manager, Vector3(a.x, manager.ground_y(a) + 0.01, a.z))
				var to := b - a
				to.y = 0.0
				match figure.figure_id:
					"rat_king":
						# 鼠潮: rats pour down the strip in a cloud of dust.
						fx.runners(Vector3.ZERO, to, 22, "rat", 0.55, w)
						fx.along_strip(Vector3.ZERO, to, 1.2, {"amount": 4, "time": 1.0, "speed": [0.2, 0.8], "spread": 80.0, "gravity": Vector3(0, -0.3, 0), "size": P * 14.0, "flip": "smoke_8x8", "damping": 1.2, "radius": w * 0.3,
							"colours": [Color(c.dust.r, c.dust.g, c.dust.b, 0.85), Color(c.dust.r, c.dust.g, c.dust.b, 0.6), Color(c.dust.r, c.dust.g, c.dust.b, 0.0)]})
						shake(manager, 2.0, 12)
					"zaro":
						# 群狼: red-eyed wolves run the strip; a red mist hangs where they ran.
						fx.runners(Vector3.ZERO, to, 6, "wolf", 0.45, w)
						fx.beam(to.normalized(), to.length(), w * 0.45, Color(c.main.r, c.main.g, c.main.b, 0.55), edge, {"sweep": 0.45, "hold": 0.1, "fade": 0.4, "wipe": true})
						fx.along_strip(Vector3.ZERO, to, 1.4, {"amount": 4, "time": 1.1, "speed": [0.1, 0.4], "spread": 80.0, "gravity": Vector3(0, 0.2, 0), "size": P * 14.0, "flip": "smoke_8x8", "damping": 0.8, "radius": w * 0.3,
							"colours": [Color(c.main.r, c.main.g, c.main.b, 0.7), Color(c.main.r * 0.7, c.main.g * 0.7, c.main.b * 0.7, 0.5), Color(c.dark.r, c.dark.g, c.dark.b, 0.0)]})
						for k in range(int(to.length() / 2.2)):
							fx.splat(randf_range(0.4, 0.7), c.main, Color(c.dark.r, c.dark.g, c.dark.b, 0.9), {"at": to.normalized() * (k + 0.5) * 2.2, "delay": 0.45 * (k + 0.5) * 2.2 / to.length(), "spread": 0.25, "hold": 0.8, "dry": 0.9})
						shake(manager, 2.5, 12)
					_:
						# 萨米之熵: ice breaks up along each strip out from its feet, glittering.
						var n := int(to.length() / 0.8)
						for k in range(n):
							var at := to.normalized() * (k + 0.5) * 0.8 + to.normalized().cross(Vector3.UP) * randf_range(-w, w) * 0.35
							fx.crystal(at, randf_range(0.45, 0.9), c.dust, c.hot, k * 0.025, 0.65)
							if k % 2 == 0: fx.glow(w * 0.9, c.main, 0.6, 0.6, k * 0.025, at)
							if k % 3 == 0: fx.splat(w * 0.8, c.hot, Color(c.main.r, c.main.g, c.main.b, 0.0), {"at": at, "delay": k * 0.025, "spread": 0.3, "hold": 0.8, "dry": 0.9, "wobble": 0.02})
						fx.along_strip(Vector3.ZERO, to, 1.0, {"amount": 6, "time": 1.0, "speed": [0.3, 1.2], "spread": 80.0, "gravity": Vector3(0, -0.8, 0), "size": P * 0.9, "additive": true, "radius": w * 0.3,
							"colours": [Color(1, 1, 1, 1), c.hot, Color(c.main.r, c.main.g, c.main.b, 0.0)]})
						shake(manager, 2.5, 10)
		"cross":
			pass  # 唱沙's sand is laid in Boss._cross_hit (sand_strip), for the second cross too.
		"javelin", "sniper":
			var target: Vector3 = ctx.get("target", manager.player.global_position)
			var to := target - me
			to.y = 0.0
			var d := to.normalized() if to.length_squared() > 0.001 else dir
			var reach := float(seg.reach)
			var fx := make(manager, floor_me)
			if shape == "javelin":
				# 投戟: the spear flies the strip trailing embers, then the ground breaks out in crystal.
				var spear := Node3D.new()
				fx.add_child(spear)
				var shaft := MeshInstance3D.new()
				var rod := CylinderMesh.new()
				rod.top_radius = 0.025
				rod.bottom_radius = 0.025
				rod.height = 1.8
				shaft.mesh = rod
				shaft.material_override = _unlit(Color("3a302a"))
				shaft.rotation = Vector3(PI * 0.5, 0, 0)
				spear.add_child(shaft)
				var head := MeshInstance3D.new()
				head.mesh = _crystal_mesh(0.07, 0.42, c.main, c.hot)
				head.rotation = Vector3(-PI * 0.5, 0, 0)
				spear.add_child(head)
				head.position = Vector3(0, 0, -0.9)
				spear.basis = Basis.looking_at(d)
				spear.visible = false
				var time := reach / 32.0
				fx._runs.append({"node": spear, "from": Vector3.UP * 0.5, "to": d * reach + Vector3.UP * 0.5, "delay": 0.0, "time": time})
				var trail := fx.burst({"at": Vector3.ZERO, "amount": 50, "time": 0.5, "speed": [0.1, 0.5], "spread": 180.0, "gravity": Vector3(0, 0.5, 0), "size": P * 1.0, "additive": true, "explosive": 0.0, "near_ok": true,
					"colours": [c.hot, c.main, Color(c.main.r * 0.4, c.main.g * 0.4, c.main.b * 0.4, 0.0)]})
				trail.one_shot = false
				trail.reparent(spear, false)
				trail.position = Vector3(0, 0, -0.9)
				fx.beam(d, reach, P * 2.5, Color(c.main.r, c.main.g, c.main.b, 0.7), edge, {"sweep": time, "hold": 0.05, "fade": 0.35, "wipe": true, "additive": true})
				var land: Vector3 = target if to.length() < reach else me + d * reach
				var hit := make(manager, Vector3(land.x, manager.ground_y(land) + 0.01, land.z))
				for i in range(6):
					var a := TAU * i / 6.0
					hit.crystal(Vector3(cos(a), 0, sin(a)) * 0.7, randf_range(0.55, 1.0), c.main.darkened(0.35), c.hot, time + 0.02 * i, 0.75)
				hit.crystal(Vector3.ZERO, 1.3, c.main.darkened(0.35), c.hot, time, 0.85)
				hit.ring(2.0, P * 3.0, c.hot, edge, {"delay": time, "fade": 0.35})
				hit.glow(2.6, c.main, 1.0, 0.6, time)
				hit.splat(1.5, c.hot, Color(c.main.r, c.main.g, c.main.b, 0.0), {"additive": true, "delay": time, "spread": 0.3, "hold": 0.8, "dry": 1.0})
				hit.shaft(Vector3.ZERO, 0.5, 3.0, c.main, 1.2, 0.8, time)
				hit.halo(Vector3.UP * 0.7, 1.8, c.hot, 0.7, 0.3, time)
				hit.embers(Vector3.UP * 0.2, c.main, c.hot, 22, 0.8, time)
				hit.sparks(Vector3.UP * 0.3, c.main, c.hot, 18, 5.0, Vector3.UP, 70.0, time)
				hit.chips(Vector3.UP * 0.1, 14, 0.6, c.dust, 3.0, time)
				manager.get_tree().create_timer(time, false).timeout.connect(func(): shake(manager, 3.5, 10))
			else:
				# 终傅: a bright tracer the length of the shot, light along it, the muzzle flash.
				fx.beam(d, reach, P * 2.0, c.hot, c.main, {"start": 0.5, "sweep": 0.04, "hold": 0.03, "fade": 0.2, "additive": true})
				fx.halo(d * 0.6 + Vector3.UP * 0.4, 1.6, c.hot, 1.0, 0.12)
				for k in range(int(reach / 2.0)): fx.glow(0.7, c.main, 0.5, 0.25, k * 0.004, d * (k + 0.5) * 2.0)
				shake(manager, 2.0, 5)
		"blink":
			var fx := make(manager, floor_me)
			fx.arc(dir, float(seg.radius), 220.0, P * 4.0, c.hot, edge, {"sweep": 0.08})
			var from: Vector3 = figure.attack_origin
			var left := make(manager, Vector3(from.x, manager.ground_y(from) + 0.01, from.z))
			fx.dust(Vector3.UP * 0.2, c.dust, 16, 0.6)
			left.dust(Vector3.UP * 0.2, c.dust, 16, 0.6)
			fx.sparks(Vector3.UP * 0.4, c.main, c.hot, 14, 4.0, Vector3.UP, 80.0)
			fx.glow(float(seg.radius) * 1.2, c.main, 0.5, 0.25)
		"channel":
			# 狼嚎 / 赦罪: rings and light go out from it while it holds; embers rise round it.
			var fx := make(manager, floor_me)
			for i in range(int(float(seg.time) / 0.5)):
				fx.ring(4.4, P * 4.0, c.hot, edge, {"delay": i * 0.5, "fade": 0.5})
				fx.glow(4.0, c.main, 0.6, 0.45, i * 0.5, Vector3.ZERO, 0.2)
			var rise := fx.burst({"at": Vector3.UP * 0.2, "ring": [CLEAR, 1.8], "amount": 50, "time": 1.2, "speed": [0.5, 1.5], "dir": Vector3.UP, "spread": 20.0, "gravity": Vector3(0, 0.5, 0),
				"size": P * 1.0, "additive": true, "explosive": 0.0, "near_ok": true, "colours": [c.hot, c.main, Color(c.main.r * 0.4, c.main.g * 0.4, c.main.b * 0.4, 0.0)]})
			rise.one_shot = false
			fx.get_tree().create_timer(float(seg.time), false).timeout.connect(func(): if is_instance_valid(rise): rise.emitting = false)
			fx.life = maxf(fx.life, float(seg.time) + 1.4)
		"curse":
			# 溶血骇惧: blood mist creeps in flat along the ground to her; drops rise round her.
			var her := manager.player.global_position
			var fx := make(manager, Vector3(her.x, manager.ground_y(her) + 0.01, her.z))
			fx.burst({"at": Vector3.UP * GROUND, "ring": [1.0, 1.8], "amount": 60, "time": 0.7, "speed": [0.1, 0.3], "dir": Vector3.RIGHT, "spread": 180.0, "flat": true,
				"radial": -2.2, "tangential": 3.0, "size": P * 2.0, "soft": true, "near_ok": true, "colours": [Color(c.dark.r, c.dark.g, c.dark.b, 0.0), Color(c.main.r, c.main.g, c.main.b, 0.7), Color(c.dark.r, c.dark.g, c.dark.b, 0.0)]})
			fx.burst({"at": Vector3.UP * 0.1, "ring": [CLEAR, 1.4], "amount": 24, "time": 1.0, "speed": [0.4, 1.1], "dir": Vector3.UP, "spread": 20.0, "gravity": Vector3(0, 0.2, 0), "size": P * 1.1,
				"near_ok": true, "colours": [c.hot, c.main, Color(c.dark.r, c.dark.g, c.dark.b, 0.0)], "delay": 0.3})
			fx.ring(1.6, P * 2.0, c.main, Color(c.dark.r, c.dark.g, c.dark.b, 0.0), {"from_share": 1.0, "fade": 0.6})
			fx.glow(1.4, c.main, 0.5, 0.9, 0.0, Vector3.ZERO, 0.3)
			fx.splat(1.7, c.main, Color(c.dark.r, c.dark.g, c.dark.b, 0.85), {"spread": 0.6, "hold": 0.6, "dry": 1.0, "wobble": 0.05})
		"summon", "raise_shrine", "shrine_call", "smoke", "bless", "projectile":
			pass

## 唱沙's strip as it lands: sand thrown up all along it and hanging, light off the gold.
static func sand_strip(manager: GameManager, from: Vector3, to: Vector3, width: float) -> void:
	var c := colours("rat_king")
	var fx := make(manager, Vector3(from.x, manager.ground_y(from) + 0.01, from.z))
	fx.set_meta("kind", "sand_strip")
	var along := to - from
	along.y = 0.0
	var edge := Color(c.main.r, c.main.g, c.main.b, 0.0)
	fx.beam(along.normalized(), along.length(), width * 0.8, Color(c.hot.r, c.hot.g, c.hot.b, 0.7), edge, {"sweep": 0.1, "hold": 0.15, "fade": 0.4})
	fx.along_strip(Vector3.ZERO, along, 1.0, {"amount": 10, "time": 1.0, "speed": [0.8, 2.4], "dir": Vector3.UP, "spread": 30.0, "gravity": Vector3(0, -2.5, 0), "size": P * 1.2, "damping": 0.6, "explosive": 0.8, "radius": width * 0.3,
		"tints": [c.hot, c.main, c.dust], "colours": [Color.WHITE, Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.0)]})
	for k in range(int(along.length() / 2.5)):
		fx.glow(width * 0.9, c.main, 0.45, 0.45, 0.0, along.normalized() * ((k + 0.5) * 2.5))
		fx.splat(width * 0.7, c.hot, Color(c.main.r, c.main.g, c.main.b, 0.0), {"at": along.normalized() * ((k + 0.5) * 2.5), "spread": 0.3, "hold": 0.6, "dry": 0.8, "wobble": 0.05})
	shake(manager, 2.5, 8)

## The phase-change roar: a blast of air, dust thrown out, light flaring and a hard shake.
static func roar(manager: GameManager, at: Vector3, figure_id: String, radius: float) -> void:
	var c := colours(figure_id)
	var edge := Color(c.main.r, c.main.g, c.main.b, 0.0)
	var fx := make(manager, Vector3(at.x, manager.ground_y(at) + 0.01, at.z))
	fx.ring(radius, P * 5.0, c.hot, edge, {"fade": 0.35})
	fx.ring(radius * 0.7, P * 2.5, c.main, edge, {"delay": 0.08, "fade": 0.35, "additive": true})
	fx.glow(radius * 1.3, c.main, 1.0, 0.6)
	fx.burst({"at": Vector3.UP * 0.2, "ring": [CLEAR, CLEAR + 0.5], "amount": 24, "time": 0.9, "speed": [3.0, 6.0], "dir": Vector3.UP, "spread": 70.0, "gravity": Vector3(0, -1.0, 0), "size": P * 14.0, "flip": "smoke_8x8",
		"damping": 4.0, "radial": 6.0, "near_ok": true, "colours": [Color(c.dust.r, c.dust.g, c.dust.b, 0.6), Color(c.dust.r, c.dust.g, c.dust.b, 0.4), Color(c.dust.r, c.dust.g, c.dust.b, 0.0)]})
	shake(manager, 5.0, 18)

## A puff of dust where help comes in (Boss._summon), so it reads as arriving.
static func arrival(manager: GameManager, at: Vector3, figure_id: String) -> void:
	var c := colours(figure_id)
	var fx := make(manager, Vector3(at.x, manager.ground_y(at) + 0.01, at.z))
	fx.ring(1.1, P * 2.5, c.hot, Color(c.main.r, c.main.g, c.main.b, 0.0), {"fade": 0.3})
	fx.glow(1.2, c.main, 0.5, 0.4)
	fx.burst({"at": Vector3.UP * 0.1, "ring": [CLEAR, CLEAR + 0.4], "amount": 10, "time": 1.0, "speed": [0.4, 1.0], "dir": Vector3.UP, "spread": 60.0, "gravity": Vector3(0, -0.3, 0), "size": P * 14.0, "flip": "smoke_8x8",
		"damping": 1.5, "radial": 1.5, "near_ok": true, "colours": [Color(c.dust.r, c.dust.g, c.dust.b, 0.55), Color(c.dust.r, c.dust.g, c.dust.b, 0.35), Color(c.dust.r, c.dust.g, c.dust.b, 0.0)]})

## A blast: a ground flash of light, fire, smoke, sparks and fine shrapnel.
static func _explosion(fx: BossVfx, r: float, c: Dictionary) -> void:
	var edge := Color(c.main.r, c.main.g, c.main.b, 0.0)
	fx.ring(r, P * 3.0, c.hot, edge, {"fade": 0.3})
	fx.glow(r * 1.8, c.main, 1.2, 0.5, 0.0, Vector3.ZERO, 0.08)
	fx.halo(Vector3.UP * 0.6, r * 1.4, c.hot, 0.9, 0.2)
	fx.burst({"at": Vector3.UP * 0.35, "radius": r * 0.35, "amount": 10, "time": 0.6, "speed": [0.6, 1.8], "dir": Vector3.UP, "spread": 70.0, "gravity": Vector3(0, 1.0, 0), "size": P * 16.0, "flip": "fire_8x8", "additive": true,
		"damping": 2.0, "colours": [Color(1, 1, 0.9, 1), c.main.lightened(0.2), Color(c.main.r, c.main.g, c.main.b, 0.0)]})
	fx.burst({"at": Vector3.UP * 0.5, "radius": r * 0.4, "amount": 10, "time": 1.3, "speed": [0.4, 1.2], "dir": Vector3.UP, "spread": 50.0, "gravity": Vector3(0, 0.4, 0), "size": P * 18.0, "flip": "smoke_8x8", "damping": 1.0, "delay": 0.08,
		"colours": [Color(0.3, 0.29, 0.28, 0.9), Color(0.4, 0.39, 0.38, 0.7), Color(0.45, 0.45, 0.45, 0.0)]})
	fx.splat(r * 0.9, Color(0.12, 0.1, 0.09, 0.85), Color(0.1, 0.08, 0.07, 0.0), {"spread": 0.2, "hold": 1.0, "dry": 1.0, "wobble": 0.02})
	fx.sparks(Vector3.UP * 0.4, c.main, c.hot, 26, 6.0, Vector3.UP, 85.0)
	fx.embers(Vector3.UP * 0.3, c.main, c.hot, 12, r * 0.5, 0.05, 0.9)
	fx.chips(Vector3.UP * 0.1, 16, r * 0.4, c.dark.lightened(0.3), 3.2)
	if is_instance_valid(fx.game): shake(fx.game, 3.0, 9)

## A 源石祭坛's pulse (BossArena) or 爱国者's kneel: crystals round its reach, light and embers.
static func shrine_pulse(manager: GameManager, at: Vector3, radius: float) -> void:
	var c := colours("patriot")
	var edge := Color(c.main.r, c.main.g, c.main.b, 0.0)
	var fx := make(manager, Vector3(at.x, manager.ground_y(at) + 0.01, at.z))
	fx.ring(radius, P * 5.0, c.hot, edge, {"fade": 0.45})
	for i in range(16):
		var a := TAU * i / 16.0 + randf() * 0.3
		fx.crystal(Vector3(cos(a), 0, sin(a)) * radius * randf_range(0.45, 0.95), randf_range(0.55, 1.15), c.main.darkened(0.35), c.hot, 0.02 * i, 0.7)
	fx.glow(radius * 1.4, c.main, 1.0, 0.7, 0.0, Vector3.ZERO, 0.15)
	fx.splat(radius * 0.9, c.hot, Color(c.main.r, c.main.g, c.main.b, 0.0), {"additive": true, "spread": 0.35, "hold": 0.5, "dry": 0.9})
	fx.shaft(Vector3.ZERO, 0.9, 4.0, c.main, 1.3, 0.9)
	fx.halo(Vector3.UP * 1.4, 2.2, c.hot, 0.8, 0.4)
	fx.embers(Vector3.UP * 0.3, c.main, c.hot, 40, radius * 0.8, 0.0, 1.2)
	shake(manager, 3.0, 10)

## A 源石祭坛 rising where 爱国者 raised it.
static func shrine_rise(manager: GameManager, at: Vector3) -> void:
	var c := colours("patriot")
	var fx := make(manager, Vector3(at.x, manager.ground_y(at) + 0.01, at.z))
	fx.ring(1.6, P * 3.0, c.hot, Color(c.main.r, c.main.g, c.main.b, 0.0))
	for i in range(6):
		var a := TAU * i / 6.0
		fx.crystal(Vector3(cos(a), 0, sin(a)) * 0.95, randf_range(0.45, 0.8), c.main.darkened(0.35), c.hot, 0.03 * i, 0.65)
	fx.glow(2.2, c.main, 0.9, 0.7)
	fx.shaft(Vector3.ZERO, 0.7, 3.5, c.main, 1.2, 0.9)
	fx.dust(Vector3.UP * 0.2, c.dust, 10, 0.8, 0.0, 1.4)
	fx.chips(Vector3.UP * 0.1, 18, 0.8, c.dust, 3.0)
	fx.embers(Vector3.UP * 0.3, c.main, c.hot, 18, 0.8, 0.1, 1.2)
