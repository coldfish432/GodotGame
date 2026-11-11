class_name FieldWeather
extends Node3D
## The weather of a field floor, drawn (GPU粒子特效推广策划案 v0.6 §5).
## Presentation only: it reads the cold, the fires, the lamps and the figures
## and writes shader globals, particle ratios and the fog; nothing it does
## changes play. One per floor, a child of the world map (gone with it).
##
## Snow (萨米):
##   the cold shown is smoothed (§5.5): a stage change (0 / 60 / 90) takes
##   about STAGE_TIME seconds to come through; entering or loading a floor shows
##   the cold as it is at once;
##   lying snow (field_snow_cover) 0.15 at cold 0 up to 1 at 90 (§5.3);
##   footprints of her and the nearest TRAIL_FIGURES enemies, filled in again
##   faster the harder it snows (trail texture, R = game time a foot passed);
##   lit fires melt a ring (field_fire_*);
##   a blizzard from cold 90, over below 85 (§5.4): occlusion from light at 90
##   to medium at 100 (fog toward white, level snow, flakes past the lens,
##   gusts), the same over the whole view;
##   snow kicked up at her feet as she walks.
## Rain (叙拉古雨夜): puddles placed by the floor's seed, filling from 0.4 to 1
## over PUDDLE_RISE seconds of rain; every surface wet; the nearest lamps
## seen in the puddles. 龙门下城: always wet, full puddles, no rain on them.
## Every floor: a heightfield the particles land on (glass, grit, rain, snow).

const STAGE_TIME := 5.0
const COVER_LOW := 0.15
const BLIZZARD_ON := 90.0
const BLIZZARD_OFF := 85.0
const PUDDLE_START := 0.4
const PUDDLE_RISE := 90.0
const TRAIL_SIZE := 64.0
const TRAIL_RES := 256
const TRAIL_RECENTRE := 16.0
const TRAIL_FIGURES := 40
const TRAIL_STEP := 0.2
const TRAIL_UPLOAD := 0.05
const KICK := preload("res://effects/snow_kick.tscn")
const KICK_EVERY := 0.3
const LAMP_EVERY := 0.25
## How white the fog gets at a full blizzard, and how much thicker.
const FOG_WHITE := Color(0.88, 0.9, 0.94)
const FOG_WHITE_SHARE := 0.85
const FOG_DENSITY_ADD := 0.045

var game: GameManager
var map: Node3D
var snow := false
var rain := false
var lower := false
var shown_cold := 0.0
var cover := 0.0
var blizzard_on := false
var blizzard := 0.0
var gust := 0.0
var puddle_fill := PUDDLE_START
var rain_strength := 1.0
var snow_strength := 1.0
var clock := 0.0
var collider: GPUParticlesCollisionHeightField3D
var trail_origin := Vector2.ZERO
var _trail_image: Image
var _trail_texture: ImageTexture
var _trail_dirty := false
var _trail_wait := 0.0
var _last_stamp := {}
var _kick_wait := 0.0
var _lamp_wait := 0.0
var _gust_wait := 10.0
var _gust_age := -1.0
var _env: Environment
var _base_fog_colour := Color.BLACK
var _base_fog_density := 0.0
var _puddle := Vector4.ZERO
var _rng := RandomNumberGenerator.new()
## The last value set on each shader global (tests read these; headless cannot read globals back).
var pushed := {}

static func create(owner: GameManager, world_map: Node3D) -> FieldWeather:
	var w := FieldWeather.new()
	w.name = "FieldWeather"
	w.game = owner
	w.map = world_map
	world_map.add_child(w)
	return w

func _ready() -> void:
	collider = GPUParticlesCollisionHeightField3D.new()
	collider.name = "ParticleGround"
	collider.size = Vector3(56, 24, 48)
	collider.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_512
	collider.follow_camera_enabled = true
	collider.update_mode = GPUParticlesCollisionHeightField3D.UPDATE_MODE_WHEN_MOVED
	# Ground and props, not the figures.
	collider.cull_mask = 1
	add_child(collider)
	_configure()

var _configured := ""

## What this floor is (snow / rain / 下城) and its seed; re-read if the floor's
## region or look is only settled after the map entered the tree.
func _configure() -> void:
	var key := FieldLight.key(map)
	var env: Environment = game.world_environment.environment if is_instance_valid(game.world_environment) else null
	_configured = "%s|%s|%d" % [game.region_id, key, env.get_instance_id() if env != null else 0]
	if _env != null and _env != env:
		_env.fog_light_color = _base_fog_colour
		_env.fog_density = _base_fog_density
	_env = env
	if _env != null:
		_base_fog_colour = _env.fog_light_color
		_base_fog_density = _env.fog_density
	snow = game.region_id == "snow"
	rain = key.ends_with("_rain")
	lower = key == "city_lower"
	var seed_value := int(map.get("seed_value")) if map.get("seed_value") != null else 0
	_rng.seed = hash([seed_value, game.floor_number, "weather"])
	rain_strength = _rng.randf_range(0.5, 1.0)
	_puddle = Vector4(_rng.randf_range(-500.0, 500.0), _rng.randf_range(-500.0, 500.0), _rng.randf_range(0.0, TAU), 0.0)
	puddle_fill = PUDDLE_START
	if snow and _trail_image == null: _setup_trail()
	snap()

## Shows the weather as it is now with no easing (a floor entered or loaded).
func snap() -> void:
	shown_cold = _cold()
	blizzard_on = shown_cold >= BLIZZARD_ON
	blizzard = _blizzard_target()
	cover = cover_for(shown_cold)
	_push(0.0)

func _cold() -> float:
	return game.features.value("cold") if snow else 0.0

## Lying snow for a (shown) cold value.
static func cover_for(cold: float) -> float:
	return COVER_LOW + (1.0 - COVER_LOW) * clampf(cold / 90.0, 0.0, 1.0)

## How far the blizzard occludes, 0 none, light 0.4 at cold 90, medium 1 at 100.
func _blizzard_target() -> float:
	if not blizzard_on: return 0.0
	return 0.4 + 0.6 * clampf((shown_cold - BLIZZARD_ON) / 10.0, 0.0, 1.0)

func _process(delta: float) -> void:
	if not is_instance_valid(game): return
	var env: Environment = game.world_environment.environment if is_instance_valid(game.world_environment) else null
	if _configured != "%s|%s|%d" % [game.region_id, FieldLight.key(map), env.get_instance_id() if env != null else 0]: _configure()
	var running := game.simulation_active()
	if running: clock += delta
	_global("field_time", clock)
	var ease := 1.0 - exp(-delta * 3.0 / STAGE_TIME)
	if snow:
		var cold := _cold()
		if cold >= BLIZZARD_ON: blizzard_on = true
		elif cold < BLIZZARD_OFF: blizzard_on = false
		shown_cold += (cold - shown_cold) * ease
		cover = cover_for(shown_cold)
		blizzard += (_blizzard_target() - blizzard) * ease
		_tick_gust(delta, running)
		var growth: float = game.map_features.cold_growth()
		snow_strength = clampf(0.35 + 0.65 * growth / (FeatureCatalog.COLD_RATE + FeatureCatalog.COLD_DEEP), 0.35, 1.0)
		if running:
			_stamp_trails()
			_kick(delta)
		_trail_wait -= delta
		if _trail_dirty and _trail_wait <= 0.0:
			_trail_wait = TRAIL_UPLOAD
			_trail_dirty = false
			_trail_texture.update(_trail_image)
	if rain and running: puddle_fill = minf(1.0, puddle_fill + delta * (1.0 - PUDDLE_START) / PUDDLE_RISE)
	_lamp_wait -= delta
	if _lamp_wait <= 0.0:
		_lamp_wait = LAMP_EVERY
		_push_lamps()
	_push(delta)

## Globals, the falling layers and the fog, from the state above.
func _push(_delta: float) -> void:
	if snow:
		_global("field_snow", float(FieldLight.region("snow").get("snow", 1.0)) * (0.45 + 0.55 * cover))
		_global("field_snow_cover", cover)
		var fill := lerpf(60.0, 12.0, maxf(clampf((snow_strength - 0.35) / 0.65, 0.0, 1.0) * 0.5, blizzard))
		_global("field_trail_rect", Vector4(trail_origin.x, trail_origin.y, TRAIL_SIZE, fill))
		_push_fires()
	_global("field_wet", (0.75 * rain_strength) if rain else (0.55 if lower else 0.0))
	_puddle.w = puddle_fill if rain else 0.0
	_global("field_puddle", _puddle)
	var weather := _weather()
	if weather != null:
		weather.intensity = snow_strength if snow else (rain_strength if rain else 1.0)
		weather.blizzard = clampf(blizzard * (1.0 + 0.5 * gust), 0.0, 1.0)
		weather.apply()
	if _env != null and snow:
		var w := clampf(blizzard * (1.0 + 0.4 * gust), 0.0, 1.0)
		_env.fog_light_color = _base_fog_colour.lerp(FOG_WHITE, w * FOG_WHITE_SHARE)
		_env.fog_density = _base_fog_density + FOG_DENSITY_ADD * w

func _weather() -> WeatherFx:
	var dressing = map.get("terrace_dressing")
	if dressing == null or not is_instance_valid(dressing): return null
	var w = dressing.weather
	return w as WeatherFx if is_instance_valid(w) else null

## Gusts in a blizzard: every 8–15 s a 2 s wall of snow sweeps across.
func _tick_gust(delta: float, running: bool) -> void:
	if blizzard <= 0.05:
		gust = 0.0
		_gust_age = -1.0
		return
	if not running: return
	if _gust_age >= 0.0:
		_gust_age += delta
		gust = sin(clampf(_gust_age / 2.0, 0.0, 1.0) * PI)
		if _gust_age >= 2.0:
			_gust_age = -1.0
			gust = 0.0
			_gust_wait = _rng.randf_range(8.0, 15.0)
	else:
		_gust_wait -= delta
		if _gust_wait <= 0.0: _gust_age = 0.0

func _push_fires() -> void:
	var lit: Array = []
	for fire in game.map_features.fires:
		if is_instance_valid(fire) and fire.is_inside_tree() and fire.lit(): lit.append(fire)
	var focus := FieldLight.focus
	lit.sort_custom(func(a, b): return a.global_position.distance_squared_to(focus) < b.global_position.distance_squared_to(focus))
	for i in range(4):
		var v := Vector4.ZERO
		if i < lit.size():
			var at: Vector3 = lit[i].global_position
			v = Vector4(at.x, at.y, at.z, FeatureCatalog.FIRE_RADIUS * 1.2)
		_global("field_fire_%d" % i, v)

## The four lamps nearest her, for their images in the puddles.
func _push_lamps() -> void:
	var lamps: Array = []
	if rain or lower:
		var dressing = map.get("terrace_dressing")
		var fl = dressing.field_light if dressing != null and is_instance_valid(dressing) else null
		var rig: FieldLight.LightRig = fl.rig if fl != null and is_instance_valid(fl.rig) else null
		if rig != null:
			var to := rig.global_transform
			var focus := FieldLight.focus
			for i in range(rig._at.size()):
				var at := to * rig._at[i]
				var d := at.distance_to(focus)
				if d < 26.0: lamps.append([d, at, rig._color[i], rig._energy[i], rig._range[i]])
			lamps.sort_custom(func(a, b): return a[0] < b[0])
	for i in range(4):
		var pos := Vector4.ZERO
		var tint := Vector4.ZERO
		if i < lamps.size():
			var l: Array = lamps[i]
			var at: Vector3 = l[1]
			var c: Color = l[2]
			pos = Vector4(at.x, at.y, at.z, clampf(float(l[3]), 0.0, 4.0))
			tint = Vector4(c.r, c.g, c.b, float(l[4]))
		_global("field_lamp_%d" % i, pos)
		_global("field_lamp_tint_%d" % i, tint)

# --- Footprints -------------------------------------------------------------------

func _setup_trail() -> void:
	_trail_image = Image.create(TRAIL_RES, TRAIL_RES, false, Image.FORMAT_RF)
	_trail_image.fill(Color(0, 0, 0, 0))
	_trail_texture = ImageTexture.create_from_image(_trail_image)
	_global("field_trail", _trail_texture)
	var focus := _focus()
	trail_origin = Vector2(focus.x, focus.z) - Vector2.ONE * TRAIL_SIZE * 0.5

func _focus() -> Vector3:
	return game.player.global_position if is_instance_valid(game.player) else Vector3.ZERO

## The figures leaving tracks: her, then the enemies nearest her.
func trail_figures() -> Array:
	var out: Array = []
	if is_instance_valid(game.player) and game.player.is_inside_tree(): out.append(game.player)
	var focus := _focus()
	var near: Array = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e._dead or not e.is_inside_tree(): continue
		near.append([e.global_position.distance_squared_to(focus), e])
	near.sort_custom(func(a, b): return a[0] < b[0])
	for i in range(mini(TRAIL_FIGURES, near.size())): out.append(near[i][1])
	return out

func _stamp_trails() -> void:
	var focus := _focus()
	var centre := trail_origin + Vector2.ONE * TRAIL_SIZE * 0.5
	if Vector2(focus.x, focus.z).distance_to(centre) > TRAIL_RECENTRE: _recentre(Vector2(focus.x, focus.z))
	var seen := {}
	for figure in trail_figures():
		var id: int = figure.get_instance_id()
		seen[id] = true
		var at := Vector2(figure.global_position.x, figure.global_position.z)
		var last: Vector2 = _last_stamp.get(id, at + Vector2.ONE * 10.0)
		if at.distance_to(last) < TRAIL_STEP: continue
		_last_stamp[id] = at
		stamp(at)
	for id in _last_stamp.keys():
		if not seen.has(id): _last_stamp.erase(id)

## One footprint (2×2 texels, ~0.5 m, softened in the shader) at `at`, stamped with the game time.
func stamp(at: Vector2) -> void:
	var px := (at - trail_origin) / TRAIL_SIZE * TRAIL_RES
	var x0 := int(floor(px.x - 0.5))
	var y0 := int(floor(px.y - 0.5))
	for y in range(y0, y0 + 2):
		for x in range(x0, x0 + 2):
			if x < 0 or y < 0 or x >= TRAIL_RES or y >= TRAIL_RES: continue
			_trail_image.set_pixel(x, y, Color(maxf(clock, 0.001), 0, 0, 1))
	_trail_dirty = true

func track_at(at: Vector2) -> float:
	var px := (at - trail_origin) / TRAIL_SIZE * TRAIL_RES
	var x := int(px.x)
	var y := int(px.y)
	if x < 0 or y < 0 or x >= TRAIL_RES or y >= TRAIL_RES: return 0.0
	return _trail_image.get_pixel(x, y).r

## Moves the trail window to centre on `focus` by whole texels, keeping the tracks.
func _recentre(focus: Vector2) -> void:
	var texel := TRAIL_SIZE / TRAIL_RES
	var target := focus - Vector2.ONE * TRAIL_SIZE * 0.5
	var shift := Vector2i(roundi((target.x - trail_origin.x) / texel), roundi((target.y - trail_origin.y) / texel))
	if shift == Vector2i.ZERO: return
	var moved := Image.create(TRAIL_RES, TRAIL_RES, false, Image.FORMAT_RF)
	moved.fill(Color(0, 0, 0, 0))
	moved.blit_rect(_trail_image, Rect2i(shift, Vector2i(TRAIL_RES, TRAIL_RES)).intersection(Rect2i(0, 0, TRAIL_RES, TRAIL_RES)), Vector2i(maxi(-shift.x, 0), maxi(-shift.y, 0)))
	_trail_image = moved
	trail_origin += Vector2(shift) * texel
	_trail_dirty = true

func _kick(delta: float) -> void:
	_kick_wait -= delta
	if _kick_wait > 0.0 or not is_instance_valid(game.player): return
	var p := game.player
	if Vector2(p.velocity.x, p.velocity.z).length() < 0.8: return
	_kick_wait = KICK_EVERY
	OneShotFx.spawn(KICK, game, Vector3(p.global_position.x, game.ground_y(p.global_position), p.global_position.z), 6)

func _exit_tree() -> void:
	_global("field_wet", 0.0)
	_global("field_puddle", Vector4.ZERO)
	_global("field_snow_cover", 0.0)
	_global("field_trail_rect", Vector4.ZERO)
	for i in range(4):
		_global("field_fire_%d" % i, Vector4.ZERO)
		_global("field_lamp_%d" % i, Vector4.ZERO)
	if _env != null:
		_env.fog_light_color = _base_fog_colour
		_env.fog_density = _base_fog_density

func _global(name: String, value: Variant) -> void:
	pushed[name] = value
	RenderingServer.global_shader_parameter_set(name, value)
