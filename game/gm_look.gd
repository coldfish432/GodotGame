class_name GmLook
extends RefCounted

## The scene's look (场景渲染统一改造案_v1 §4.4): the sun, the environments of
## the base and of each region's field, the outline pass and her own light.
## The base is lit by its lamps (BaseMap lights), graded as one scene and
## outlined like the sprites. The nodes (sun, world_environment, outline_pass)
## stay on GameManager, where the rest of the game reads them.

const OUTLINE_SHADER := preload("res://world/outline_post.gdshader")
const FIELD_SUN := 1.2
const BASE_SUN := 0.15
## Each region's field light (场景渲染统一改造案_v1 S3), keyed like FieldLight.key:
## ambient energy (its colour is FieldLight.REGIONS' ambient), the sun's colour
## and energy, the fog's colour and density, the background. Then its filter
## (改造案 v1.1: 滤镜), each optional: contrast, saturation, brightness, and
## `grade` [shadows, highlights] — the colour black and white are taken to,
## per channel (adjustment_color_correction).
const FIELD_LOOK := {
	"mine": {"ambient": 0.42, "sun": Color(0.74, 0.8, 1.0), "sun_energy": 0.22, "fog": Color(0.2, 0.22, 0.3), "fog_density": 0.006, "bg": Color(0.03, 0.03, 0.04)},
	"city": {"ambient": 0.34, "sun": Color(0.6, 0.68, 0.9), "sun_energy": 0.12, "fog": Color(0.12, 0.14, 0.2), "fog_density": 0.005, "bg": Color(0.02, 0.02, 0.035)},
	# 下城: wet and cold, a shade darker; blue shadows, warm-yellow highlights
	# so the windows and lanterns stand out.
	"city_lower": {"ambient": 0.38, "sun": Color(0.56, 0.64, 0.86), "sun_energy": 0.1, "fog": Color(0.13, 0.16, 0.22), "fog_density": 0.009, "bg": Color(0.015, 0.02, 0.03),
		"contrast": 1.1, "saturation": 0.9, "brightness": 1.0, "grade": [Color(0.0, 0.015, 0.05), Color(1.0, 0.95, 0.82)]},
	"snow": {"ambient": 0.5, "sun": Color(0.85, 0.9, 1.0), "sun_energy": 0.45, "fog": Color(0.66, 0.72, 0.82), "fog_density": 0.008, "bg": Color(0.5, 0.55, 0.62)},
	# 叙拉古 at dusk going to night (§2): the sun low and orange; violet-blue
	# shadows, amber highlights; colder again in the rain.
	"siracusa": {"ambient": 0.54, "sun": Color(1.0, 0.74, 0.56), "sun_energy": 0.12, "fog": Color(0.17, 0.17, 0.24), "fog_density": 0.007, "bg": Color(0.02, 0.02, 0.04),
		"contrast": 1.08, "saturation": 0.86, "grade": [Color(0.0, 0.005, 0.04), Color(1.0, 0.93, 0.8)]},
	"siracusa_rain": {"ambient": 0.42, "sun": Color(0.7, 0.68, 0.84), "sun_energy": 0.18, "fog": Color(0.2, 0.22, 0.3), "fog_density": 0.012, "bg": Color(0.03, 0.035, 0.05),
		"contrast": 1.08, "saturation": 0.9, "grade": [Color(0.0, 0.01, 0.05), Color(0.97, 0.95, 0.88)]},
}
## In the field her self-lit sprite takes the nearby lamps' colour and stands
## on its contact shadow, as in the base (BaseMap._tint_sprites).
const FIELD_TINT := Color(0.96, 0.97, 1.0)

var game: GameManager
var _field_environment: Environment
var _base_environment: Environment
var _field_environments := {}
var _player_light: OmniLight3D

func _init(owner: GameManager) -> void:
	game = owner

## The world environment and the outline pass (on the camera), made once in
## _ready right after the camera and the sun.
func build(camera: Camera3D) -> void:
	var world_environment := WorldEnvironment.new()
	game.world_environment = world_environment
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = ProceduralSkyMaterial.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_field_environment = environment
	_base_environment = base_environment()
	world_environment.environment = environment
	game.add_child(world_environment)
	var outline_pass := MeshInstance3D.new()
	game.outline_pass = outline_pass
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	outline_pass.mesh = quad
	var outline_material := ShaderMaterial.new()
	outline_material.shader = OUTLINE_SHADER
	outline_pass.material_override = outline_material
	outline_pass.extra_cull_margin = 16384.0
	outline_pass.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	outline_pass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	outline_pass.visible = false
	camera.add_child(outline_pass)

## 罗德岛舰内: cool, even, the lamps and screens carrying the light.
static func base_environment() -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02, 0.025, 0.03)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.66, 0.72)
	e.ambient_light_energy = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.0
	e.tonemap_white = 8.0
	e.ssao_enabled = true
	e.ssao_radius = 1.4
	e.ssao_intensity = 2.2
	e.ssao_power = 1.4
	e.ssil_enabled = true
	e.ssil_intensity = 0.8
	e.glow_enabled = true
	e.glow_intensity = 0.55
	e.glow_hdr_threshold = 1.0
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	e.fog_enabled = true
	e.fog_light_color = Color(0.32, 0.38, 0.46)
	e.fog_density = 0.004
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.06
	e.adjustment_saturation = 1.08
	return e

static func field_environment(look_key: String) -> Environment:
	var look: Dictionary = FIELD_LOOK.get(look_key, FIELD_LOOK.city)
	var e := base_environment()
	e.background_color = look.bg
	e.ambient_light_color = FieldLight.region(look_key).ambient
	e.ambient_light_energy = look.ambient
	e.ssao_radius = 2.0
	e.ssao_intensity = 1.8
	e.ssil_intensity = 0.6
	e.fog_light_color = look.fog
	e.fog_density = look.fog_density
	e.adjustment_contrast = float(look.get("contrast", e.adjustment_contrast))
	e.adjustment_saturation = float(look.get("saturation", e.adjustment_saturation))
	e.adjustment_brightness = float(look.get("brightness", e.adjustment_brightness))
	if look.has("grade"): e.adjustment_color_correction = grade_texture(look.grade[0], look.grade[1])
	return e

## A per-channel curve from `shadows` at black to `highlights` at white,
## straight through grey between.
static func grade_texture(shadows: Color, highlights: Color) -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.set_color(0, shadows)
	gradient.set_color(1, highlights)
	var mid := Color(0.5, 0.5, 0.5) + (shadows + highlights - Color.WHITE) * 0.5
	mid.a = 1.0
	gradient.add_point(0.5, mid)
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture

## Swaps the environment, the sun, the outline and her own light for the base
## or the field (the region read off the floor just built).
func apply(base_look: bool) -> void:
	var world_environment := game.world_environment
	if not is_instance_valid(world_environment): return
	var sun := game.sun
	sun.light_energy = BASE_SUN
	sun.light_color = Color.WHITE
	game.outline_pass.visible = true
	if base_look:
		world_environment.environment = _base_environment
	else:
		var world_map := game.world_map
		var look_key := FieldLight.key(world_map) if is_instance_valid(world_map) else game.region_id
		if not _field_environments.has(look_key): _field_environments[look_key] = field_environment(look_key)
		world_environment.environment = _field_environments[look_key]
		var look: Dictionary = FIELD_LOOK.get(look_key, FIELD_LOOK.city)
		sun.light_energy = look.sun_energy
		sun.light_color = look.sun
	_update_player_light(base_look)

## A boss fight's look over the region's (Boss演出策划案_v0_2 §1.4): the filter
## `dim` darker, the ambient and the sun pulled `k` toward `tint`. (0, _, 0) is
## the region's own again. The cached environments are put back as they were.
var _shade_base := {}
func boss_shade(dim: float, tint: Color, k: float, ambient: float = 1.0) -> void:
	var world_environment := game.world_environment
	if not is_instance_valid(world_environment) or world_environment.environment == null or game.in_base: return
	var e := world_environment.environment
	var key := e.get_instance_id()
	if absf(dim) <= 0.0005 and k <= 0.0005 and absf(ambient - 1.0) <= 0.001:
		if _shade_base.has(key):
			var b: Dictionary = _shade_base[key]
			e.adjustment_brightness = b.brightness
			e.ambient_light_color = b.ambient
			e.ambient_light_energy = b.energy
			game.sun.light_color = b.sun
			_shade_base.erase(key)
		return
	if not _shade_base.has(key): _shade_base[key] = {"brightness": e.adjustment_brightness, "ambient": e.ambient_light_color, "sun": game.sun.light_color, "energy": e.ambient_light_energy}
	var base: Dictionary = _shade_base[key]
	# Negative dims brighten (龙门's arena, 用户 2026-11-05: 整个场景都太黑了).
	e.adjustment_brightness = float(base.brightness) * (1.0 - clampf(dim, -0.35, 0.4))
	e.ambient_light_color = (base.ambient as Color).lerp(tint, clampf(k, 0.0, 1.0))
	game.sun.light_color = (base.sun as Color).lerp(tint, clampf(k, 0.0, 1.0) * 0.6)
	# Light on the scene only: sprites are unshaded and keep their own brightness.
	e.ambient_light_energy = float(base.energy) * clampf(ambient, 0.2, 3.0)

func tint_in_field() -> void:
	var player := game.player
	if game.in_base or player._sprite == null: return
	var world_map := game.world_map
	var dressing: TerraceDressing = world_map.terrace_dressing if is_instance_valid(world_map) else null
	var rig: FieldLight.LightRig = dressing.field_light.rig if dressing != null and dressing.field_light != null else null
	player._sprite.scene_tint = rig.tint_at(player.global_position, FIELD_TINT, 0.28) if is_instance_valid(rig) else FIELD_TINT
	if is_instance_valid(player._sprite.contact_shadow): player._sprite.contact_shadow.visible = true

## The warm glow round her in the field (FieldLight.REGIONS' "player"), now a
## light that walks with her; none in the base.
func _update_player_light(base_look: bool) -> void:
	var player := game.player
	if not is_instance_valid(player): return
	if not is_instance_valid(_player_light):
		_player_light = OmniLight3D.new()
		_player_light.name = "OwnLight"
		_player_light.omni_attenuation = 1.4
		_player_light.light_specular = 0.2
		player.add_child(_player_light)
		_player_light.position = Vector3(0, 1.6, 0)
	var world_map := game.world_map
	var region := FieldLight.region(FieldLight.key(world_map) if is_instance_valid(world_map) else game.region_id)
	var glow: Color = region.player
	var peak := maxf(glow.r, maxf(glow.g, glow.b))
	_player_light.visible = not base_look and peak > 0.0
	if peak > 0.0:
		_player_light.light_color = Color(glow.r / peak, glow.g / peak, glow.b / peak)
		_player_light.light_energy = peak * 2.4
		_player_light.omni_range = float(region.player_radius) * 1.2
