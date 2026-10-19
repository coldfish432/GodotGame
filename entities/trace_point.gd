class_name TracePoint
extends Node3D

## A 踪迹 left on the floor by one of the region's operators (干员寻访策划案 §13,
## 用户 2026-10-17: 整体冒幽幽的光，不明显也不可以隐藏): her own mark on the
## ground in the ground's own tones (art/kit/trace_<id>.glb), picked up with E.
## It glows faintly all the time: the mark breathes a pale light, a few motes
## drift up off it, and its glow is baked into the floor's light round it
## (GameManager, GLOW_RADIUS). No name, not on the minimap.

const MODEL := "res://art/kit/trace_%s.glb"
## The glow: its colour, its strength in the light map, how far it reaches.
const GLOW := Color(0.45, 0.85, 0.7)
const GLOW_GAIN := 0.35
const GLOW_RADIUS := 2.6
## The mark's own light breathes between these, over BREATH seconds.
const PULSE := Vector2(0.18, 0.4)
const BREATH := 3.2
const HALO_SIZE := 1.8

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
var _time := 0.0

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
			model.material_override = mark
		if big: model.scale = Vector3.ONE * BIG_SCALE
		add_child(model)
	# A soft pool of light on the ground under it, not the mark's outline
	# (用户 2026-10-17: 像一根棍子).
	add_child(halo(HALO_SIZE * (1.6 if big else 1.0)))
	_shine = (get_node("Halo") as MeshInstance3D).material_override
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
	fade.set_color(0, Color(GLOW, 0.0))
	fade.add_point(0.35, Color(GLOW, 0.7))
	fade.set_color(fade.get_point_count() - 1, Color(GLOW, 0.0))
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

func _process(delta: float) -> void:
	_time += delta
	if _shine != null:
		var breath := 0.5 + 0.5 * sin(_time * TAU / BREATH)
		_shine.albedo_color = GLOW * lerpf(PULSE.x, PULSE.y, breath)
