class_name StatusPost
extends Node
## The full-screen status look (GPU粒子特效推广策划案 v0.6 §7 P5): one quad on
## the camera (world/status_post.gdshader) drawn over the figures and under the
## warning circles (render priority STATUS_PRIORITY < CombatMarker's 20) and
## the HUD, plus the Environment's saturation and contrast. Every state feeds
## the same layer and they add up (用户裁决 8). Field only; the base shows none.
## Each level eases in and out over about EASE seconds.

const SHADER := preload("res://world/status_post.gdshader")
const STATUS_PRIORITY := 15
const EASE := 1.0
const LOW_LIFE_FROM := 0.3

var game: GameManager
var quad: MeshInstance3D
var material: ShaderMaterial
var levels := {"contamination": 0.0, "cold": 0.0, "debt": 0.0, "threat": 0.0, "low_life": 0.0, "whiteout": 0.0}
var _clock := 0.0
var _env: Environment
var _base := {}

static func create(owner: GameManager) -> StatusPost:
	var post := StatusPost.new()
	post.name = "StatusPost"
	post.game = owner
	owner.add_child(post)
	return post

func _ready() -> void:
	quad = MeshInstance3D.new()
	quad.name = "StatusPass"
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2, 2)
	quad.mesh = mesh
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.render_priority = STATUS_PRIORITY
	quad.material_override = material
	quad.extra_cull_margin = 16384.0
	quad.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad.visible = false
	if is_instance_valid(game.camera): game.camera.add_child(quad)

## A meter's look for its value: faint below the first stage, marked at 60,
## heavy at 90 (the 60 / 90 stages of contamination, cold and debt).
static func staged(value: float) -> float:
	if value < 60.0: return 0.25 * value / 60.0
	if value < 90.0: return 0.5 + 0.15 * (value - 60.0) / 30.0
	return 0.8 + 0.2 * clampf((value - 90.0) / 10.0, 0.0, 1.0)

## The target level of each state right now.
func targets() -> Dictionary:
	var out := {"contamination": 0.0, "cold": 0.0, "debt": 0.0, "threat": 0.0, "low_life": 0.0, "whiteout": 0.0}
	if game.in_base or not is_instance_valid(game.player): return out
	var region := game.region_id
	if region == "mine": out.contamination = staged(game.features.value("contamination"))
	if region == "siracusa": out.debt = staged(game.features.value("debt"))
	var weather := game.field_weather
	if region == "snow":
		var shown: float = weather.shown_cold if is_instance_valid(weather) else game.features.value("cold")
		var blizzard: float = weather.blizzard if is_instance_valid(weather) else 0.0
		out.cold = clampf(staged(shown) + 0.2 * blizzard, 0.0, 1.0)
		var gust: float = weather.gust if is_instance_valid(weather) else 0.0
		out.whiteout = blizzard * 0.22 + gust * blizzard * 0.15
	if game.threat != null: out.threat = clampf(game.threat.value / ThreatMeter.FULL, 0.0, 1.0) * 0.8
	var life := game.player.hp / maxf(1.0, game.player.max_hp)
	if life < LOW_LIFE_FROM: out.low_life = clampf((LOW_LIFE_FROM - life) / LOW_LIFE_FROM, 0.0, 1.0)
	return out

func _process(delta: float) -> void:
	if not is_instance_valid(quad) or not is_instance_valid(game): return
	_clock += delta
	var aim := targets()
	var k := 1.0 - exp(-delta * 3.0 / EASE)
	var any := false
	for key in levels:
		levels[key] = lerpf(float(levels[key]), float(aim[key]), k) if absf(float(levels[key]) - float(aim[key])) > 0.0005 else float(aim[key])
		material.set_shader_parameter(key, levels[key])
		if float(levels[key]) > 0.002: any = true
	var debt_tier := game.features.tier("debt") if game.region_id == "siracusa" else 0
	material.set_shader_parameter("debt_rate", [0.8, 1.1, 1.4][clampi(debt_tier, 0, 2)])
	material.set_shader_parameter("clock", _clock)
	quad.visible = any and not game.in_base
	_adjust()

## Cold and low life drain the colour a little; threat lifts the contrast.
func _adjust() -> void:
	var env: Environment = game.world_environment.environment if is_instance_valid(game.world_environment) else null
	if env != _env:
		_restore()
		_env = env
		if env != null: _base = {"saturation": env.adjustment_saturation, "contrast": env.adjustment_contrast}
	if _env == null or game.in_base: return
	_env.adjustment_saturation = float(_base.saturation) * (1.0 - 0.25 * float(levels.cold) - 0.25 * float(levels.low_life) - 0.08 * float(levels.contamination))
	_env.adjustment_contrast = float(_base.contrast) * (1.0 + 0.08 * float(levels.threat))

func _restore() -> void:
	if _env != null and not _base.is_empty():
		_env.adjustment_saturation = float(_base.saturation)
		_env.adjustment_contrast = float(_base.contrast)

func _exit_tree() -> void:
	_restore()
