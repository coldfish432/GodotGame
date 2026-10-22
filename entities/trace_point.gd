class_name TracePoint
extends Node3D

## A 踪迹 left on the floor by one of the region's operators (干员寻访策划案 §13,
## 用户 2026-10-17: 整体冒幽幽的光，不明显也不可以隐藏): her own mark on the
## ground in the ground's own tones (art/kit/trace_<id>.glb), picked up with E.
## It glows faintly all the time: the mark breathes a pale light, a few motes
## drift up off it, and its glow is baked into the floor's light round it
## (GameManager, GLOW_RADIUS). No name, not on the minimap.
##
## 用户 2026-10-22 (优化踪迹的表现形式和效果，可以换建模): each mark now has one
## thing of hers in it (赫拉格's snapped sabre tip, 林's umbrella, 德克萨斯's
## snack box…); its glow leans toward her colour (TINT), a faint column of it
## rises off the mark, and as she comes near (STIR_REACH) the motes quicken and
## the light swells. Picked up, the motes stream into her and the mark fades.

const MODEL := "res://art/kit/trace_%s.glb"
## The glow: its colour, its strength in the light map, how far it reaches.
const GLOW := Color(0.45, 0.85, 0.7)
const GLOW_GAIN := 0.35
const GLOW_RADIUS := 2.6
## The mark's own light breathes between these, over BREATH seconds.
const PULSE := Vector2(0.18, 0.4)
const BREATH := 3.2
const HALO_SIZE := 1.8
## Her own colour, which the glow leans toward by TINT_SHARE.
const TINT := {
	"hellagur": Color("f0c878"), "rosa": Color("c8e0a0"), "hoshiguma": Color("70e0a0"), "lin": Color("a0f0d8"),
	"typhon": Color("f0b878"), "santalla": Color("a8dcff"), "texas": Color("ffa880"), "lappland": Color("c8c8ff"),
}
const TINT_SHARE := 0.45
## The column of light off the mark: radius, height, its gain breathing between.
const COLUMN := Vector3(0.32, 1.5, 0.0)
const COLUMN_GAIN := Vector2(0.06, 0.14)
## Within this of her the mark stirs: motes quicker and more, the light up by STIR_GAIN.
const STIR_REACH := 5.0
const STIR_GAIN := 1.8
## Picked up: how long the mark takes to go.
const FADE := 0.7

## Her glow: the trace's pale green leaning toward her colour.
static func glow_for(id: String) -> Color:
	return GLOW.lerp(TINT.get(id, GLOW), TINT_SHARE)

## A round soft pool of the glow, lying on the ground (additive, breathing
## from PULSE.x; the owner tweens or sets its colour).
static func halo(size: float) -> MeshInstance3D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.add_point(0.35, Color(0.55, 0.55, 0.55))
	gradient.set_color(gradient.get_point_count() - 1, Color.BLACK)
	var soft := GradientTexture2D.new()
	soft.gradient = gradient
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(0.5, 0.0)
	soft.width = 64
	soft.height = 64
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	# Fog on an additive quad lights its whole square.
	material.disable_fog = true
	material.albedo_texture = soft
	material.albedo_color = GLOW * PULSE.x
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var node := MeshInstance3D.new()
	node.name = "Halo"
	node.mesh = plane
	node.material_override = material
	node.position.y = 0.02
	return node
## Marks cut or scraped into the ground darken whatever ground they are on
## (multiplied, so they sit in the mine's dirt as in Siracusa's paving); rime
## lies pale over it. The rest (a bolt, an arrow, a wrapper) are things.
const DARKEN := ["hellagur", "lappland", "hoshiguma"]
const RIME := ["santalla"]

var operator := ""
## Which of her traces this is (RecruitCatalog.TRACE_SMALL / TRACE_BIG).
var key := "s1"
var game: Node
var _motes: CPUParticles3D
var _shine: StandardMaterial3D
var _column: ShaderMaterial
var _model: MeshInstance3D
var _time := 0.0
## 0 far, 1 with her at the mark (eased toward).
var _stir := 0.0
var _gone := -1.0
var glow := GLOW

## A big trace is the same mark, larger, its glow wider and its motes more.
const BIG_SCALE := 1.7

func setup(id: String, p_game: Node = null, p_key := "s1") -> void:
	operator = id
	game = p_game
	key = p_key
	var big := RecruitCatalog.is_big(key)
	name = "Trace_" + id
	var path := MODEL % id
	if ResourceLoader.exists(path):
		var model := MeshInstance3D.new()
		model.mesh = TerraceDressing.kit_mesh(load(path))
		if id in DARKEN or id in RIME:
			var mark := StandardMaterial3D.new()
			mark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mark.cull_mode = BaseMaterial3D.CULL_DISABLED
			if id in DARKEN:
				mark.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
				mark.albedo_color = Color(0.55, 0.52, 0.5)
			else:
				mark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mark.albedo_color = Color(0.86, 0.93, 1.0, 0.5)
			# Only the mark itself (the cut, the scrape, the rime); her things
			# lying in it keep their own colours.
			var raw := TerraceDressing._first_mesh(load(path).instantiate())
			for surface in range(raw.get_surface_count() if raw != null else 0):
				var source := raw.surface_get_material(surface)
				var part := source.resource_name.get_slice(".", 0) if source != null else ""
				if part.ends_with("_cut") or part.ends_with("_scratch") or part.ends_with("_rime"):
					model.set_surface_override_material(surface, mark)
		if big: model.scale = Vector3.ONE * BIG_SCALE
		_model = model
		add_child(model)
	# A soft pool of light on the ground under it, not the mark's outline
	# (用户 2026-10-17: 像一根棍子).
	add_child(halo(HALO_SIZE * (1.6 if big else 1.0)))
	_shine = (get_node("Halo") as MeshInstance3D).material_override
	glow = glow_for(id)
	_add_column(big)
	_motes = CPUParticles3D.new()
	_motes.name = "Motes"
	_motes.amount = 10 if big else 5
	_motes.lifetime = 3.0
	_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_motes.emission_sphere_radius = 0.35
	_motes.direction = Vector3.UP
	_motes.spread = 25.0
	_motes.gravity = Vector3.ZERO
	_motes.initial_velocity_min = 0.08
	_motes.initial_velocity_max = 0.2
	var fade := Gradient.new()
	fade.set_color(0, Color(glow, 0.0))
	fade.add_point(0.35, Color(glow.lightened(0.2), 0.8))
	fade.set_color(fade.get_point_count() - 1, Color(glow, 0.0))
	_motes.color_ramp = fade
	var speck := QuadMesh.new()
	speck.size = Vector2(0.07, 0.07)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	speck.material = material
	_motes.mesh = speck
	_motes.position.y = 0.15
	_motes.preprocess = 3.0
	add_child(_motes)

## A faint column of her glow rising off the mark (BossVfx's shaft, held).
func _add_column(big: bool) -> void:
	_column = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = BossVfx.SHAFT_CODE
	_column.shader = shader
	_column.set_shader_parameter("noise_tex", BossVfx.tex("noise"))
	_column.set_shader_parameter("colour", glow)
	var tube := CylinderMesh.new()
	var r := COLUMN.x * (1.4 if big else 1.0)
	tube.top_radius = r * 0.55
	tube.bottom_radius = r
	tube.height = COLUMN.y * (1.3 if big else 1.0)
	tube.cap_top = false
	tube.cap_bottom = false
	tube.radial_segments = 16
	var node := MeshInstance3D.new()
	node.name = "Column"
	node.mesh = tube
	node.material_override = _column
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position.y = tube.height * 0.5
	add_child(node)

## Picked up: the motes stream into her, a ring of her light goes out, and the
## mark fades over FADE seconds before it is freed.
func collect(by: Node3D = null) -> void:
	if _gone >= 0.0: return
	_gone = 0.0
	if game is GameManager:
		var fx := BossVfx.make(game, global_position)
		var to := (by.global_position - global_position) if is_instance_valid(by) else Vector3.UP
		to.y = 0.0
		fx.burst({"at": Vector3.UP * 0.2, "radius": 0.35, "amount": 22, "time": 0.6, "speed": [2.0, 3.5], "dir": (to.normalized() + Vector3.UP * 0.6).normalized(), "spread": 18.0,
			"gravity": Vector3.ZERO, "damping": 2.0, "size": BossVfx.P * 1.3, "additive": true, "colours": [glow.lightened(0.4), glow, Color(glow, 0.0)], "near_ok": true})
		fx.ring(1.4, 0.07, glow.lightened(0.4), glow, {"additive": true, "from_share": 0.1, "fade": 0.4, "sweep": 0.3})
		fx.glow(1.6, glow, 0.9, 0.5)
	if is_instance_valid(_motes): _motes.emitting = false

func _process(delta: float) -> void:
	_time += delta
	var target := 0.0
	if game is GameManager and is_instance_valid(game.player):
		var d := Vector2(game.player.global_position.x - global_position.x, game.player.global_position.z - global_position.z).length()
		target = clampf(1.0 - d / STIR_REACH, 0.0, 1.0)
	_stir = move_toward(_stir, target, delta * 1.5)
	var out := 1.0
	if _gone >= 0.0:
		_gone += delta
		out = clampf(1.0 - _gone / FADE, 0.0, 1.0)
		if is_instance_valid(_model):
			_model.position.y = -0.06 * (1.0 - out)
			_model.scale.y = maxf(0.05, out) * (BIG_SCALE if RecruitCatalog.is_big(key) else 1.0)
		if _gone >= FADE:
			queue_free()
			return
	var breath := 0.5 + 0.5 * sin(_time * TAU / BREATH)
	var lift := (1.0 + _stir * (STIR_GAIN - 1.0)) * out
	if _shine != null:
		_shine.albedo_color = glow * lerpf(PULSE.x, PULSE.y, breath) * lift
	if _column != null:
		_column.set_shader_parameter("gain", lerpf(COLUMN_GAIN.x, COLUMN_GAIN.y, breath) * lift)
		_column.set_shader_parameter("flow", -_time * 0.25)
	if is_instance_valid(_motes):
		_motes.speed_scale = 1.0 + _stir * 1.5
