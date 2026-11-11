class_name BossShow
extends Node

## The bosses' set pieces (Boss演出策划案_v0_2, 用户 2026-11-04: 都先按你推荐来,
## 成品出再改; 扎罗血雾改黑雾): the intro, each phase change, the fall, her fall
## and the reset — the camera, the scene's look, the HUD's band and flash,
## the boss's own effects, and the husk it leaves.
##
## Fair by construction (§1.1): while it plays the boss stands untouchable and
## idle (Boss.staging_left), she cannot be hurt, and her hands are held only
## through an intro (GameManager.hands_busy). Any key skips an intro.
## Timings in BossShowCatalog. Off for the old suites (BossShow.enabled = false).

const C := preload("res://game/boss_show_catalog.gd")
const DISSOLVE := preload("res://world/sprite_dissolve.gdshader")

static var enabled := true

var game: GameManager
var boss: Boss
## Real seconds her hands are still held (an intro).
var lock_left := 0.0
## The HUD's band (0 out .. 1 in) and its goal; the flash colour and its age.
var band := 0.0
var band_goal := 0.0
var flash_colour := Color(1, 1, 1, 0)
var flash_age := 9.0
## The life shares whose tick broke (the HUD draws the shards): [share, age].
var shatters: Array = []
## What is playing, and its own clock (game seconds).
var playing := ""
var _t := 0.0
var _steps: Array = []
## The camera: from, to and when; back to her when `_focus_to` is null.
var _focus_from := Vector3.ZERO
var _focus_goal: Variant = null
var _focus_age := 0.0
var _focus_time := 0.6
## Freeze and slow motion left, in real seconds (each frame's delta ÷ time_scale,
## so a capture at a fixed frame rate sees the same frames).
var _freeze_left := 0.0
var _slow_left := 0.0
var _slowing := false
## The scene's look: now and goal (dim, tint, k) and the lamps'.
var _shade := {"dim": 0.0, "tint": Color.WHITE, "k": 0.0, "ambient": 1.0}
var _shade_from := {"dim": 0.0, "tint": Color.WHITE, "k": 0.0, "ambient": 1.0}
var _shade_goal := {"dim": 0.0, "tint": Color.WHITE, "k": 0.0, "ambient": 1.0}
var _shade_age := 9.0
var _lamps: Dictionary = {}
var stage := -1
## The husk a boss leaves (爱国者's stays), its params' tween, and when it ends.
var _husk: MeshInstance3D
var _on_done: Callable
## The intro band's badge, loaded when the intro starts: a texture first loaded
## inside the HUD's _draw stayed white (2026-11-04 recordings).
var badge: Texture2D

static func of(manager: GameManager) -> BossShow:
	if not is_instance_valid(manager): return null
	if is_instance_valid(manager.boss_show): return manager.boss_show
	var show := BossShow.new()
	show.name = "BossShow"
	show.game = manager
	manager.add_child(show)
	manager.boss_show = show
	return show

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	_unshade_now()

## Her hands are held (an intro).
func locked() -> bool:
	return lock_left > 0.0

## Where the camera looks instead of her, or null.
func focus() -> Variant:
	if _focus_goal == null and _focus_age >= _focus_time: return null
	var to: Vector3 = _focus_goal if _focus_goal != null else game.player.global_position
	var k := clampf(_focus_age / maxf(0.01, _focus_time), 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	return _focus_from.lerp(to, k)

func _look_at(point: Variant, seconds: float) -> void:
	var now: Variant = focus()
	_focus_from = now if now != null else game.player.global_position
	_focus_goal = point
	_focus_age = 0.0
	_focus_time = seconds

# --- The intro (§1.2, §2.4, §3.4, §4.4, §5.4) ----------------------------------------------

func intro(figure: Boss) -> void:
	boss = figure
	badge = FieldArt.boss_badge(figure.figure_id)
	var key := "%s:%d" % [game.region_id, figure.tier]
	var first := not game.base.boss_intro_seen.has(key)
	game.base.boss_intro_seen[key] = true
	var full := first
	var quiet := not first and not bool(SystemScreens.settings.get("boss_intro", true))
	_begin("intro")
	var length := C.FIRST_INTRO if full else (0.4 if quiet else C.AGAIN_INTRO)
	figure.staging_left = length
	if not quiet: lock_left = length
	_guard_her(length)
	var d := Callable(self, "_intro_" + figure.figure_id)
	if full:
		_look_at(figure.global_position, C.PAN)
		_shade_to({"dim": _intro_dim(figure, 0.18), "tint": Color(0.2, 0.2, 0.25), "k": 0.25}, C.PAN)
		_at(C.PAN, func(): if d.is_valid(): d.call(true))
		_at(C.BAND_IN, func():
			band_goal = 1.0
			_sfx("boss_warning_band"))
		_at(C.BAND_OUT, func():
			band_goal = 0.0
			_look_at(null, C.PAN_BACK))
	else:
		_shade_to({"dim": _intro_dim(figure, 0.2), "tint": Color(0.2, 0.2, 0.25), "k": 0.2}, 0.3)
		_at(0.05, func(): if d.is_valid(): d.call(false))
		if not quiet:
			band_goal = 1.0
			_at(0.5, func(): band_goal = 0.0)
	_at(length, func():
		set_stage(0)
		_end())

## A sound now or after `delay` (FieldAudio; silent until the file is in).
func _sfx(cue: String, delay: float = 0.0) -> void:
	if delay <= 0.0:
		if game.sound != null: game.sound.play(cue)
		return
	_after(delay, func(): if is_instance_valid(game) and game.sound != null: game.sound.play(cue))

## A boss's rehearsed effects (Boss.rehearse), drawn a few frames by a camera of
## their own far under the floor, then freed: their pipelines are compiled
## before the fight needs them, and nothing shows on her screen.
const WARM_TIME := 0.35
func warm_up(at: Vector3, nodes: Array) -> void:
	var main := game.get_viewport()
	var view := SubViewport.new()
	view.name = "WarmUp"
	view.size = Vector2i(160, 90)
	view.world_3d = main.world_3d
	view.msaa_3d = main.msaa_3d
	view.screen_space_aa = main.screen_space_aa
	view.use_taa = main.use_taa
	view.use_debanding = main.use_debanding
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var cam := Camera3D.new()
	cam.projection = game.camera.projection
	cam.size = 12.0
	cam.cull_mask = game.camera.cull_mask
	cam.environment = game.camera.environment
	view.add_child(cam)
	add_child(view)
	cam.global_position = at + Vector3(0.0, 9.0, -7.0)
	cam.look_at(at, Vector3.UP)
	var ids: Array = nodes.filter(func(n): return is_instance_valid(n)).map(func(n): return n.get_instance_id())
	get_tree().create_timer(WARM_TIME, false).timeout.connect(func():
		for id in ids:
			var n := instance_from_id(id)
			if is_instance_valid(n): n.queue_free()
		if is_instance_valid(view): view.queue_free())

## The intro's dim, from this boss's first stage (龙门's arena starts brighter than the street).
func _intro_dim(figure: Boss, extra: float) -> float:
	var stages: Array = C.STAGES.get(figure.figure_id, [])
	return extra + minf(0.0, float(stages[0].dim) if not stages.is_empty() else 0.0)

func _guard_her(seconds: float) -> void:
	if is_instance_valid(game.player): game.player.invuln_timer = maxf(game.player.invuln_timer, seconds)

## Any key or click skips the rest of an intro: what was still to come plays at once.
func _input(event: InputEvent) -> void:
	if playing != "intro" or lock_left <= 0.0: return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed)
	if not pressed: return
	get_viewport().set_input_as_handled()
	skip()

func skip() -> void:
	if playing != "intro": return
	var left := _steps.duplicate()
	_steps.clear()
	for s in left: (s.f as Callable).call()
	lock_left = 0.0
	band_goal = 0.0
	if is_instance_valid(boss): boss.staging_left = 0.0
	_focus_goal = null
	_focus_age = _focus_time
	if playing == "intro": _end()

# --- Phases (§1.2, §2.6, §3.6, §4.6, §5.6) -------------------------------------------------

## `share`: the tick on the bar that broke (or -1 for a life's end).
func phase(figure: Boss, n: int, share: float) -> void:
	boss = figure
	_freeze(C.PHASE_FREEZE)
	_flash(BossVfx.colours(figure.figure_id).main, C.FLASH_ALPHA)
	if share >= 0.0:
		shatters.append([share, 0.0])
		_sfx("boss_bar_shatter")
	var d := Callable(self, "_phase_" + figure.figure_id)
	if d.is_valid(): d.call(n)
	var hold := BossCatalog.DOWN_TIME if figure.down_left > 0.0 else BossCatalog.ROAR_TIME
	_after(hold, func(): if is_instance_valid(boss) and not boss._dead: set_stage(n - 1))

## 扎罗's first life spent: down, into black mist, and a wolf stands up out of it.
func rebirth(figure: Boss) -> void:
	boss = figure
	_freeze(C.PHASE_FREEZE)
	_flash(C.MIST, C.FLASH_ALPHA)
	_zaro_rebirth(figure)
	_sfx("zaro_bell")
	_sfx("zaro_black_mist", 0.5)
	_sfx("zaro_howl", 1.9)
	_after(BossCatalog.DOWN_TIME, func(): if is_instance_valid(boss) and not boss._dead: set_stage(1))

## A warden's last stand (30%): a small roar.
func last_stand(figure: Boss) -> void:
	BossVfx.roar(game, figure.global_position, figure.figure_id, 1.6)

# --- The fall (§1.2, §2.7, §3.7, §4.7, §5.7, §6) -------------------------------------------

## The boss is down: frozen, slowed, then it goes its own way; `done` drops
## the loot and frees it (Boss._finish_die).
func finale(figure: Boss, done: Callable) -> void:
	boss = figure
	_on_done = done
	_begin("finale")
	var warden := figure.rank == "warden"
	_freeze(C.WARDEN_FREEZE if warden else C.KILL_FREEZE)
	if not warden: _slow_left = C.SLOW_TIME
	_disarm(figure)
	# Its last pose (B3): 爱国者 standing, 鼠王 on the cane, 木裂 on one knee, 扎罗 down.
	if (C.SHOW_ROWS.get(figure.figure_id, {}) as Dictionary).has("dies"):
		figure.show_row_name = "dies"
		figure._update_attack_visual()
	_sfx("boss_final_blow")
	if not warden: _after(C.FINALE * 0.6, func(): if is_instance_valid(game) and game.music != null: game.music.boss_sting("down"))
	_husk = husk_of(figure)
	figure.hide_figure()
	var d := Callable(self, "_fall_" + figure.figure_id)
	if d.is_valid(): d.call(figure)
	var length := C.WARDEN_FINALE if warden else C.FINALE
	if not warden: _at(0.2, func(): _flash(Color.WHITE, 0.0))
	_at(length, func():
		set_stage(-1)
		var f := _on_done
		_on_done = Callable()
		if f.is_valid(): f.call()
		_end())

## Her fall in a boss fight: its winning pose, then the fall is settled.
func victory(figure: Boss, done: Callable) -> void:
	boss = figure
	_on_done = done
	_begin("victory")
	figure.show_row_name = "victory"
	figure.staging_left = C.VICTORY + 1.0
	if game.music != null: game.music.boss_sting("win")
	if figure.figure_id == "zaro": BossVfx.roar(game, figure.global_position, "zaro", 2.0)
	_at(C.VICTORY, func():
		var f := _on_done
		_on_done = Callable()
		if f.is_valid(): f.call()
		_end())

## Home again whole: the look eases back (the bar refills on the HUD).
func reset(figure: Boss) -> void:
	if playing == "intro": skip()
	set_stage(-1)
	var c := BossVfx.colours(figure.figure_id)
	var fx := BossVfx.make(game, figure.global_position)
	fx.glow(1.6, c.main, 0.8, 0.8)
	fx.shaft(Vector3.ZERO, 0.8, 3.0, c.hot, 0.9, 0.8)

## A boss's chest comes up out of the ground in a shaft of its region's light (§1.2).
func chest_rise(chest: Node3D) -> void:
	var rest := chest.position.y
	chest.position.y = rest - 0.9
	var tween := chest.create_tween()
	tween.tween_interval(0.15 + 0.3 * get_tree().get_nodes_in_group("boss_chests").size())
	tween.tween_property(chest, "position:y", rest, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	chest.add_to_group("boss_chests")
	var colour: Color = BossVfx.colours(boss.figure_id).main if is_instance_valid(boss) else Color("b49ae8")
	var fx := _fx(chest.global_position)
	fx.shaft(Vector3.ZERO, 0.6, 3.2, colour, 1.0, 1.4)
	fx.dust(Vector3.UP * 0.1, Color("8a7c6c"), 8, 0.6)

# --- The scene's look ------------------------------------------------------------------------

## Phase stage `n` (0-based) of this boss's look, or -1 for the region's own.
func set_stage(n: int) -> void:
	stage = n
	var stages: Array = C.STAGES.get(boss.figure_id, []) if is_instance_valid(boss) else []
	if n < 0 or stages.is_empty():
		if is_instance_valid(boss) and boss.figure_id == "eikthyrnir" and not boss._dead: _storm(0.0)
		_haze(0.0)
		_shade_to({"dim": 0.0, "tint": Color.WHITE, "k": 0.0}, C.SHADE_EASE)
		_grade_lamps({})
		return
	var s: Dictionary = stages[mini(n, stages.size() - 1)]
	if boss.figure_id == "eikthyrnir": _storm(float(n))
	_haze(float(s.get("haze", 0.0)))
	_shade_to({"dim": float(s.dim), "tint": s.tint, "k": float(s.k), "ambient": float(s.get("ambient", 1.0))}, C.SHADE_EASE)
	_grade_lamps(s.get("lamps", {}))

func _shade_to(goal: Dictionary, seconds: float) -> void:
	_shade_from = _shade.duplicate()
	_shade_goal = goal
	_shade_age = 0.0
	_shade_time = maxf(0.01, seconds)
var _shade_time := 1.0

func _grade_lamps(lamps: Dictionary) -> void:
	_lamps = lamps
	var rig := _rig()
	if rig == null: return
	if lamps.is_empty() or not is_instance_valid(boss):
		rig.ungrade()
		return
	rig.grade_near(boss.centre(), BossCatalog.ARENA_RADIUS + 6.0, lamps.tint, float(lamps.k), float(lamps.mult))

## 萨米's snowfall (TerraceDressing.weather): harder by stage, a gust, and calm at his fall.
func _weather() -> WeatherFx:
	var world_map := game.world_map
	if not is_instance_valid(world_map) or world_map.terrace_dressing == null: return null
	var w: WeatherFx = world_map.terrace_dressing.weather
	return w if is_instance_valid(w) else null

func _storm(level: float) -> void:
	var w := _weather()
	if w == null: return
	w.emitting = true
	w.storm(level)

func _gust(seconds: float) -> void:
	var w := _weather()
	if w == null: return
	var before := w.storm_level()
	_storm(2.0)
	_after(seconds, func(): if _weather() != null: _storm(before))

func _calm() -> void:
	var w := _weather()
	if w == null: return
	_storm(0.0)
	w.emitting = false
	_after(4.0, func(): if _weather() != null: _weather().emitting = true)

## Sand blowing through the air round the camera (鼠王's phases): `level` 0 none, 1 light, 2 more.
var _sand: GPUParticles3D
func _haze(level: float) -> void:
	if level <= 0.0:
		if is_instance_valid(_sand):
			_sand.emitting = false
			var s := _sand
			_after(3.0, func(): if is_instance_valid(s): s.queue_free())
			_sand = null
		return
	if not is_instance_valid(_sand):
		var sand := CPUParticles3D.new()
		sand.name = "SandHaze"
		sand.local_coords = false
		sand.lifetime = 3.0
		sand.preprocess = 3.0
		sand.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		sand.emission_box_extents = Vector3(16.0, 1.2, 12.0)
		sand.direction = Vector3(1.0, 0.05, 0.25)
		sand.spread = 12.0
		sand.initial_velocity_min = 2.5
		sand.initial_velocity_max = 4.5
		sand.gravity = Vector3(0.6, -0.05, 0.0)
		sand.scale_amount_min = 0.6
		sand.scale_amount_max = 1.6
		var ramp := Gradient.new()
		ramp.set_color(0, Color(0.85, 0.72, 0.48, 0.0))
		ramp.add_point(0.3, Color(0.85, 0.72, 0.48, 0.5))
		ramp.set_color(ramp.get_point_count() - 1, Color(0.85, 0.72, 0.48, 0.0))
		sand.color_ramp = ramp
		var quad := QuadMesh.new()
		quad.size = Vector2(0.9, 0.3)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_texture = BossVfx.soft_texture()
		mat.vertex_color_use_as_albedo = true
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		quad.material = mat
		sand.mesh = quad
		sand.amount = 440
		_sand = GpuFx.from_cpu(sand, [1.2, 6.0, 0.05, 0.15], 24.0)
		game.add_child(_sand)
	# A fixed buffer; how much blows is the ratio (changing amount restarts it).
	_sand.amount_ratio = clampf(level / 2.0, 0.0, 1.0)
	_sand.emitting = true

func _rig() -> FieldLight.LightRig:
	var world_map := game.world_map
	if not is_instance_valid(world_map) or world_map.terrace_dressing == null: return null
	var fl = world_map.terrace_dressing.field_light
	return fl.rig if fl != null and is_instance_valid(fl.rig) else null

func _unshade_now() -> void:
	if is_instance_valid(game) and game.look != null: game.look.boss_shade(0.0, Color.WHITE, 0.0)
	var rig := _rig() if is_instance_valid(game) else null
	if rig != null: rig.ungrade()

# --- The loop --------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not is_instance_valid(game): return
	var real := delta / maxf(Engine.time_scale, 0.001)
	# Time: frozen, slow, or back (always restored, even if the field stopped).
	if _freeze_left > 0.0: _freeze_left = maxf(0.0, _freeze_left - real)
	elif _slow_left > 0.0: _slow_left = maxf(0.0, _slow_left - real)
	var scale := 1.0
	if _freeze_left > 0.0: scale = 0.02
	elif _slow_left > 0.0: scale = C.SLOW_SCALE
	if not is_equal_approx(Engine.time_scale, scale) and (scale < 1.0 or _slowing):
		Engine.time_scale = scale
	_slowing = scale < 1.0
	flash_age += real
	band = move_toward(band, band_goal, real / 0.25)
	for s in shatters: s[1] = float(s[1]) + real
	shatters = shatters.filter(func(s): return float(s[1]) < 0.7)
	if not game.simulation_active(): return
	lock_left = maxf(0.0, lock_left - real)
	_focus_age += real
	if _focus_goal == null and _focus_age >= _focus_time: _focus_age = _focus_time
	_shade_age += real
	var k := clampf(_shade_age / _shade_time, 0.0, 1.0)
	_shade = {"dim": lerpf(float(_shade_from.dim), float(_shade_goal.dim), k), "tint": (_shade_from.tint as Color).lerp(_shade_goal.tint, k), "k": lerpf(float(_shade_from.k), float(_shade_goal.k), k),
		"ambient": lerpf(float(_shade_from.get("ambient", 1.0)), float(_shade_goal.get("ambient", 1.0)), k)}
	var dim := float(_shade.dim)
	if is_instance_valid(boss) and boss.figure_id == "zaro" and boss.reckoning_active(): dim += C.RECKONING_DIM
	if game.look != null: game.look.boss_shade(dim, _shade.tint, float(_shade.k), float(_shade.ambient))
	_tick_zaro_lamps()
	if is_instance_valid(_sand) and is_instance_valid(game.player): _sand.global_position = game.player.global_position + Vector3(-6.0, 1.6, 0.0)
	# The boss went with its floor (a new floor, the way home): nothing is left playing.
	if not is_instance_valid(boss):
		if playing in ["intro", "victory"]:
			_steps.clear()
			_end()
		if stage != -1: set_stage(-1)
		_focus_goal = null
		_focus_age = _focus_time
	if playing == "": return
	_t += delta
	while not _steps.is_empty() and float(_steps[0].t) <= _t:
		var s: Dictionary = _steps.pop_front()
		(s.f as Callable).call()

func _begin(what: String) -> void:
	_steps.clear()
	_t = 0.0
	playing = what

func _end() -> void:
	playing = ""
	lock_left = 0.0

## A step `t` seconds into what is playing (kept in order).
func _at(t: float, f: Callable) -> void:
	_steps.append({"t": t, "f": f})
	_steps.sort_custom(func(a, b): return float(a.t) < float(b.t))

## Something later that is not part of a sequence (game time).
func _after(t: float, f: Callable) -> void:
	get_tree().create_timer(t, false).timeout.connect(f)

func _freeze(seconds: float) -> void:
	_freeze_left = maxf(_freeze_left, seconds)
	if _freeze_left > 0.0 and Engine.time_scale > 0.02:
		Engine.time_scale = 0.02
		_slowing = true

func _flash(colour: Color, alpha: float) -> void:
	flash_colour = Color(colour.r, colour.g, colour.b, alpha if alpha > 0.0 else C.FLASH_ALPHA)
	flash_age = 0.0

## The flash's opacity now.
func flash_alpha() -> float:
	return flash_colour.a * clampf(1.0 - flash_age / C.FLASH_TIME, 0.0, 1.0)

## 扎罗's string lights redden with 血债 while he is in the fight (§5.3, Q9).
func _tick_zaro_lamps() -> void:
	if not is_instance_valid(boss) or boss.figure_id != "zaro" or not boss.in_fight(): return
	var rig := _rig()
	if rig == null: return
	var debt := float(game.features.values.get("debt", 0.0)) if game.features != null else 0.0
	rig.grade_near(boss.centre(), BossCatalog.ARENA_RADIUS + 6.0, C.DEBT_LAMP, clampf(debt / C.DEBT_RED, 0.0, 1.0) * 0.85, 1.0)

# --- The husk (§1.3 溶/褪) ------------------------------------------------------------------

## The boss's last frame as its own billboard, for the dissolve.
func husk_of(e: Enemy) -> MeshInstance3D:
	var sprite := e._sprite
	if not is_instance_valid(sprite) or sprite.texture == null: return null
	var texture := sprite.texture
	var sheet := texture
	var region := Rect2(Vector2.ZERO, texture.get_size())
	if texture is AtlasTexture:
		sheet = (texture as AtlasTexture).atlas
		region = (texture as AtlasTexture).region
	var size := sheet.get_size()
	var mat := ShaderMaterial.new()
	mat.shader = DISSOLVE
	mat.set_shader_parameter("atlas", sheet)
	mat.set_shader_parameter("region", Vector4(region.position.x / size.x, region.position.y / size.y, region.size.x / size.x, region.size.y / size.y))
	mat.set_shader_parameter("cell", region.size)
	mat.set_shader_parameter("flip", sprite.flip_h)
	var look: Dictionary = C.FINALES.get(e.enemy_type, {})
	mat.set_shader_parameter("mode", int(look.get("mode", 0)))
	mat.set_shader_parameter("fade_colour", look.get("fade_colour", Color.GRAY))
	mat.set_shader_parameter("edge_colour", look.get("edge", Color.WHITE))
	var quad := QuadMesh.new()
	quad.size = region.size * sprite.pixel_size
	quad.center_offset = Vector3(sprite.offset.x, sprite.offset.y, 0.0) * sprite.pixel_size
	var node := MeshInstance3D.new()
	node.name = "BossHusk"
	node.mesh = quad
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.layers = sprite.layers
	var parent: Node = game.world_map if bool(look.get("stays", false)) and is_instance_valid(game.world_map) else game
	parent.add_child(node)
	node.global_position = sprite.global_position
	node.scale = sprite.scale
	node.add_to_group("boss_husks")
	return node

## The husk shows another row of its board (扎罗's last try to rise).
func _husk_row(look: Array, row_name: String) -> void:
	if not is_instance_valid(_husk): return
	var row := int((C.SHOW_ROWS.get(look[0], {}) as Dictionary).get(row_name, -1))
	if row < 0: return
	var texture := FieldArt.enemy_dir_pose(look[1], look[2], row)
	if not texture is AtlasTexture: return
	var region := (texture as AtlasTexture).region
	var size := (texture as AtlasTexture).atlas.get_size()
	(_husk.material_override as ShaderMaterial).set_shader_parameter("region", Vector4(region.position.x / size.x, region.position.y / size.y, region.size.x / size.x, region.size.y / size.y))

## A husk's shader parameter tweened over `seconds` (game time), after `delay`.
func _tween_husk(param: String, to: float, seconds: float, delay: float = 0.0) -> void:
	if not is_instance_valid(_husk): return
	var mat := _husk.material_override as ShaderMaterial
	var tween := _husk.create_tween()
	if delay > 0.0: tween.tween_interval(delay)
	tween.tween_method(func(v: float): mat.set_shader_parameter(param, v), float(mat.get_shader_parameter(param) if mat.get_shader_parameter(param) != null else 0.0), to, seconds)

## What a boss leaves on the ground a moment (Sol B3 props): 鼠王's cane, 木裂's
## hammer, 弑君者's knife; it fades after `life` s with a puff of `dust`.
func _prop(name: String, at: Vector3, life: float, dust: Color) -> void:
	var path := "res://art/field/boss_prop_%s_64.png" % name
	if not ResourceLoader.exists(path): return
	var s := Sprite3D.new()
	s.texture = load(path)
	s.pixel_size = Enemy.PIXEL
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.offset = Vector2(0, 29.5)
	s.layers = LapplandAnimator3D.SPRITE_LAYER
	game.add_child(s)
	s.global_position = Vector3(at.x + 0.35, game.ground_y(at) + 0.02, at.z + 0.1)
	var id := s.get_instance_id()
	_after(life, func():
		var p := instance_from_id(id) as Sprite3D
		if not is_instance_valid(p): return
		_fx(p.global_position).dust(Vector3.UP * 0.2, dust, 8, 0.3, 0.0, 0.8)
		var tween := p.create_tween()
		tween.tween_property(p, "modulate:a", 0.0, 0.3)
		tween.tween_callback(p.queue_free))

func _free_husk_later(seconds: float) -> void:
	var id := _husk.get_instance_id() if is_instance_valid(_husk) else 0
	_after(seconds, func():
		var h := instance_from_id(id) if id != 0 else null
		if is_instance_valid(h): h.queue_free())

## Its blows in the air and on the ground go with it; its help leaves in a puff.
func _disarm(figure: Boss) -> void:
	for node in get_tree().get_nodes_in_group("ground_hazards"):
		if node is GroundHazard and (node as GroundHazard).source == figure: node.queue_free()
	for node in game.get_children():
		if node is EnemyProjectile and (node as EnemyProjectile).shooter == figure: node.queue_free()
	for e in figure.summoned:
		if is_instance_valid(e) and not e._dead: BossVfx.arrival(game, e.global_position, figure.figure_id)

# --- Shared bits for the figures' own pieces ---------------------------------------------------

func _fx(at: Vector3) -> BossVfx:
	return BossVfx.make(game, Vector3(at.x, game.ground_y(at) + 0.01, at.z))

func _cracks(fx: BossVfx, n: int, reach: float, colour: Color, glow_colour: Color) -> void:
	for i in range(n):
		var a := TAU * i / n + randf() * 0.4
		fx.crack(Vector3(cos(a), 0, sin(a)), reach * randf_range(0.7, 1.1), colour, glow_colour)

func _mist(fx: BossVfx, at: Vector3, amount: int, radius: float, up: float, delay: float = 0.0, time: float = 1.2) -> void:
	fx.burst({"at": at, "radius": radius, "amount": amount, "time": time, "speed": [0.2 * up, 0.9 * up], "dir": Vector3.UP, "spread": 70.0, "gravity": Vector3(0, 0.15, 0),
		"size": BossVfx.P * 16.0, "flip": "smoke_8x8", "damping": 1.2, "near_ok": true, "delay": delay,
		"colours": [Color(C.MIST.r, C.MIST.g, C.MIST.b, 0.85), Color(C.MIST_EDGE.r, C.MIST_EDGE.g, C.MIST_EDGE.b, 0.6), Color(C.MIST.r, C.MIST.g, C.MIST.b, 0.0)]})

# --- 爱国者 (§2) ----------------------------------------------------------------------------

func _intro_patriot(full: bool) -> void:
	var c := BossVfx.colours("patriot")
	boss.show_row_name = "kneel"
	var stand := func():
		if not is_instance_valid(boss): return
		boss.show_row_name = ""
		var fx := _fx(boss.global_position)
		_cracks(fx, 7, 4.5, c.dark, c.main)
		fx.ring(3.2, BossVfx.P * 4.0, c.hot, Color(c.main.r, c.main.g, c.main.b, 0.0), {"fade": 0.4})
		fx.glow(3.0, c.main, 1.0, 0.7)
		fx.embers(Vector3.UP * 0.3, c.main, c.hot, 30, 2.5, 0.05, 1.4)
		fx.dust(Vector3.UP * 0.2, c.dust, 14, 1.2)
		BossVfx.shake(game, 6.0, 20)
		_sfx("patriot_halberd_plant")
		if is_instance_valid(game.arena): game.arena.wave_flag()
		if is_instance_valid(game.arena) and is_instance_valid(game.arena.shrine): BossVfx.shrine_rise(game, game.arena.shrine.global_position)
	if full:
		var fx0 := _fx(boss.global_position)
		fx0.dust(Vector3.UP * 0.1, c.dust, 8, 0.8)
		BossVfx.shake(game, 2.0, 6)
		_at(C.PAN + 0.25, func(): if is_instance_valid(boss): boss.show_row_name = "rise")
		_at(C.PAN + 0.55, stand)
	else:
		stand.call()

func _phase_patriot(n: int) -> void:
	var c := BossVfx.colours("patriot")
	var fx := _fx(boss.global_position)
	if n == 2:
		# Originium floods to him up the cracks and climbs him; he stands in 毁灭姿态.
		for i in range(10):
			var a := TAU * i / 10.0
			fx.crack(Vector3(cos(a), 0, sin(a)), 5.0, c.dark, c.main)
		fx.burst({"at": Vector3.UP * 0.2, "ring": [3.5, 5.0], "amount": 40, "time": 1.4, "speed": [0.2, 0.6], "radial": -3.5, "gravity": Vector3(0, 0.3, 0),
			"size": BossVfx.P * 1.2, "additive": true, "colours": [c.hot, c.main, Color(c.main.r, c.main.g, c.main.b, 0.0)], "near_ok": true})
		fx.splat(2.6, c.main, Color(c.main.r, c.main.g, c.main.b, 0.0), {"additive": true, "spread": 1.2, "hold": 0.6, "dry": 0.6})
		_after(1.5, func():
			if not is_instance_valid(boss): return
			var f2 := _fx(boss.global_position)
			f2.embers(Vector3.UP * 0.6, c.main, c.hot, 40, 1.4, 0.0, 1.6)
			if is_instance_valid(game.arena): game.arena.light_flag())
	else:
		_cracks(fx, 12, 9.0, c.dark, c.hot)
		fx.glow(6.0, c.main, 1.0, 1.0)
		if is_instance_valid(game.arena):
			for s in game.arena.shrines(): BossVfx.shrine_pulse(game, s.global_position, 1.2)
		BossVfx.shake(game, 5.0, 16)

## 不倒 (k≥5): the second kneel — the music would stop; its cracks flicker as it rises.
func patriot_revive(b: Boss) -> void:
	var c := BossVfx.colours("patriot")
	_freeze(C.PHASE_FREEZE)
	_flash(c.main, 0.2)
	var fx := _fx(b.global_position)
	for i in range(4): fx.glow(1.6, c.main, 0.9, 0.25, 0.45 * i)
	fx.embers(Vector3.UP * 0.4, c.main, c.hot, 24, 1.0, 0.8, 1.4)
	_shade_to({"dim": float(C.STAGES.patriot[2].dim) + 0.06, "tint": C.STAGES.patriot[2].tint, "k": 0.55}, 0.6)

## 站着熄灭: no fall; the lights on him go out from the feet up; he stays.
func _fall_patriot(b: Boss) -> void:
	var c := BossVfx.colours("patriot")
	var at := b.global_position
	var fx := _fx(at)
	# 用户 2026-11-05: 改为不变白 — he keeps his colours and only dims as his lights go out.
	_tween_husk("fade", float(C.FINALES.patriot.get("fade_to", 1.0)), 1.5, 0.15)
	for i in range(12):
		var h := 0.15 + 0.15 * i
		fx.burst({"at": Vector3(randf_range(-0.35, 0.35), h, randf_range(-0.2, 0.2)), "amount": 3, "time": 0.6, "speed": [0.2, 0.6], "spread": 80.0, "gravity": Vector3(0, -1.0, 0),
			"size": BossVfx.P * 1.4, "additive": true, "colours": [c.hot, c.main, Color(c.main.r, c.main.g, c.main.b, 0.0)], "near_ok": true, "delay": 0.15 + 0.11 * i})
	fx.dust(Vector3.UP * 0.1, c.dust, 10, 1.0, 0.3)
	if is_instance_valid(game.arena): game.arena.drop_flag()

# --- 鼠王 (§3) ------------------------------------------------------------------------------

func _intro_rat_king(full: bool) -> void:
	var c := BossVfx.colours("rat_king")
	var tap := func(i: int):
		if not is_instance_valid(boss): return
		var fx := _fx(boss.global_position)
		fx.ring(1.0 + 0.9 * i, BossVfx.P * 2.5, c.hot, Color(c.main.r, c.main.g, c.main.b, 0.0), {"fade": 0.3})
		fx.dust(Vector3.UP * 0.05, c.dust, 6, 0.4)
		BossVfx.shake(game, 1.0 + i, 5)
		_sfx("ratking_cane_tap")
	var appear := func():
		if not is_instance_valid(boss): return
		boss.set_shown(true)
		boss.show_row_name = "poised"
		var fx := _fx(boss.global_position)
		fx.burst({"at": Vector3.UP * 0.3, "radius": 0.5, "amount": 40, "time": 0.9, "speed": [1.0, 3.0], "dir": Vector3.UP, "spread": 25.0, "tangential": 6.0, "radial": 2.0,
			"gravity": Vector3(0, -1.5, 0), "size": BossVfx.P * 1.3, "colours": [c.hot, c.main, Color(c.dust.r, c.dust.g, c.dust.b, 0.0)], "near_ok": true})
		fx.dust(Vector3.UP * 0.3, c.dust, 16, 0.8, 0.0, 1.6)
	var settle := func():
		if not is_instance_valid(boss): return
		var fx := _fx(boss.global_position)
		fx.burst({"at": Vector3.UP * 2.5, "box": Vector3(5, 0.5, 5), "amount": 60, "time": 1.2, "speed": [0.1, 0.4], "dir": Vector3.DOWN, "spread": 20.0, "gravity": Vector3(0, -1.2, 0),
			"size": BossVfx.P * 1.0, "colours": [c.main, c.dust, Color(c.dust.r, c.dust.g, c.dust.b, 0.0)], "near_ok": true})
		fx.splat(1.4, c.main, Color(c.main.r, c.main.g, c.main.b, 0.0), {"spread": 0.4, "hold": 0.3, "dry": 0.6})
		boss.show_row_name = ""
		if boss.barrier_up() and boss._shell != null: boss._shell.visible = true
	if full:
		# A thread of sand runs to the middle, silent; a column; he is there.
		var fx0 := _fx(boss.global_position)
		var from := game.player.global_position - boss.global_position
		from.y = 0.0
		fx0.along_strip(from.limit_length(8.0), Vector3.ZERO, 0.5, {"amount": 4, "time": 0.6, "speed": [0.1, 0.3], "spread": 30.0, "gravity": Vector3.ZERO,
			"size": BossVfx.P * 1.0, "colours": [c.main, c.dust, Color(c.dust.r, c.dust.g, c.dust.b, 0.0)]})
		_at(C.PAN + 0.1, appear)
		for i in range(3): _at(C.PAN + 0.45 + 0.22 * i, tap.bind(i))
		_at(C.PAN + 1.15, settle)
	else:
		appear.call()
		tap.call(2)
		settle.call()

func _phase_rat_king(n: int) -> void:
	var c := BossVfx.colours("rat_king")
	var fx := _fx(boss.global_position)
	boss.show_row_name = "cane_across"
	_after(0.5, func(): if is_instance_valid(boss): boss.show_row_name = "")
	# The sand wall round the edge: a slow ring of grains turning about the arena.
	var centre := boss.centre()
	var edge := _fx(centre)
	edge.burst({"at": Vector3.UP * 0.4, "ring": [BossCatalog.ARENA_RADIUS - 1.0, BossCatalog.ARENA_RADIUS], "amount": 120, "time": 2.4, "speed": [0.1, 0.3], "tangential": 3.0,
		"gravity": Vector3.ZERO, "size": BossVfx.P * 1.2, "explosive": 0.4, "colours": [Color(c.main.r, c.main.g, c.main.b, 0.8), c.dust, Color(c.dust.r, c.dust.g, c.dust.b, 0.0)], "near_ok": true})
	# A gust of sand rolls out from him instead of a dark pool (用户 2026-11-05: 用轻微的风沙模拟变暗).
	fx.burst({"at": Vector3.UP * 0.4, "ring": [0.5, 1.0], "amount": 50, "time": 1.4, "speed": [2.0, 4.0], "flat": true, "dir": Vector3.RIGHT, "spread": 180.0,
		"radial": 2.0, "size": BossVfx.P * 16.0, "flip": "smoke_8x8", "near_ok": true,
		"colours": [Color(c.dust.r, c.dust.g, c.dust.b, 0.55), Color(c.main.r, c.main.g, c.main.b, 0.35), Color(c.dust.r, c.dust.g, c.dust.b, 0.0)]})
	BossVfx.sand_strip(game, boss.global_position + Vector3(-2.5, 0, 0), boss.global_position + Vector3(2.5, 0, 0), 1.0)

## 化沙离去: he goes down on the cane and pours away toward the edge, the cane last.
func _fall_rat_king(b: Boss) -> void:
	var c := BossVfx.colours("rat_king")
	var at := b.global_position
	var away := at - b.centre()
	away.y = 0.0
	away = away.normalized() if away.length_squared() > 0.01 else Vector3.RIGHT
	_tween_husk("amount", 1.0, 1.1, 0.2)
	_prop("prop_rat_king_cane", at, 1.6, c.main)
	var fx := _fx(at)
	fx.burst({"at": Vector3.UP * 0.3, "radius": 0.4, "amount": 60, "time": 1.4, "speed": [0.6, 1.6], "dir": away + Vector3.UP * 0.3, "spread": 25.0, "gravity": Vector3(0, -0.6, 0),
		"size": BossVfx.P * 1.2, "explosive": 0.3, "colours": [c.hot, c.main, Color(c.dust.r, c.dust.g, c.dust.b, 0.0)], "near_ok": true, "delay": 0.2})
	fx.splat(1.2, c.main, Color(c.main.r, c.main.g, c.main.b, 0.0), {"spread": 0.8, "hold": 0.4, "dry": 0.8, "delay": 0.3})
	_free_husk_later(1.6)

# --- 埃克提尔尼尔 (§4) ------------------------------------------------------------------------

func _intro_eikthyrnir(full: bool) -> void:
	var c := BossVfx.colours("eikthyrnir")
	var smash := func():
		if not is_instance_valid(boss): return
		boss.set_shown(true)
		boss.show_row_name = ""
		var fx := _fx(boss.global_position)
		for i in range(14):
			var a := TAU * i / 14.0
			fx.crystal(Vector3(cos(a), 0, sin(a)) * randf_range(1.3, 2.4), randf_range(0.5, 1.0), c.main.darkened(0.2), c.hot, 0.02 * i, 0.8)
		fx.ring(3.0, BossVfx.P * 4.0, c.hot, Color(c.main.r, c.main.g, c.main.b, 0.0), {"fade": 0.4})
		fx.dust(Vector3.UP * 0.2, c.dust, 20, 1.5, 0.0, 1.4)
		BossVfx.shake(game, 6.0, 20)
		_sfx("eik_hammer_slam")
		_gust(2.0)
	if full:
		_at(C.PAN, func():
			if is_instance_valid(game.arena): game.arena.crack_mound())
		_at(C.PAN + 0.3, func():
			if not is_instance_valid(boss): return
			if is_instance_valid(game.arena): game.arena.break_mound()
			boss.set_shown(true)
			boss.show_row_name = "break")
		_at(C.PAN + 0.55, func(): if is_instance_valid(boss): boss.show_row_name = "roar")
		_at(C.PAN + 0.75, smash)
	else:
		boss.set_shown(true)
		smash.call()

func _phase_eikthyrnir(n: int) -> void:
	var c := BossVfx.colours("eikthyrnir")
	var fx := _fx(boss.global_position)
	if n == 2:
		boss.show_row_name = "clutch"
		_after(0.7, func(): if is_instance_valid(boss) and boss.show_row_name == "clutch": boss.show_row_name = "")
		fx.burst({"at": Vector3.UP * 1.0, "radius": 0.6, "amount": 30, "time": 1.2, "speed": [0.2, 0.6], "spread": 90.0, "gravity": Vector3(0, -0.3, 0),
			"size": BossVfx.P * 1.0, "additive": true, "colours": [c.hot, c.main, Color(c.main.r, c.main.g, c.main.b, 0.0)], "near_ok": true})
		_gust(3.0)
	else:
		for i in range(10):
			var a := TAU * i / 10.0
			fx.crack(Vector3(cos(a), 0, sin(a)), 6.5, Color("1a2030"), c.main)
	boss.collapse = minf(1.0, boss.collapse + 0.34)

## 冻成冰像, then it breaks; the storm stops (§4.7).
func _fall_eikthyrnir(b: Boss) -> void:
	var c := BossVfx.colours("eikthyrnir")
	var at := b.global_position
	_tween_husk("fade", 1.0, 0.35)
	var fx := _fx(at)
	fx.burst({"at": Vector3.UP * 0.9, "radius": 0.5, "amount": 24, "time": 0.4, "speed": [0.1, 0.3], "spread": 90.0, "gravity": Vector3.ZERO,
		"size": BossVfx.P * 1.0, "additive": true, "colours": [c.hot, c.main, Color(c.main.r, c.main.g, c.main.b, 0.0)], "near_ok": true})
	_after(0.85, func():
		if is_instance_valid(_husk):
			var mat := _husk.material_override as ShaderMaterial
			mat.set_shader_parameter("edge", 0.02)
		_tween_husk("amount", 1.0, 0.25)
		_prop("prop_eikthyrnir_hammer", at, 1.5, Color("eef4f8"))
		var f2 := _fx(at)
		for i in range(10):
			var a := TAU * i / 10.0
			f2.crystal(Vector3(cos(a), 0, sin(a)) * randf_range(0.95, 1.4), randf_range(0.3, 0.6), c.main.darkened(0.1), c.hot, 0.0, 0.5)
		f2.chips(Vector3.UP * 0.8, 40, 0.4, Color("cfeefa"), 3.5)
		_sfx("eik_statue_break")
		BossVfx.shake(game, 4.0, 12)
		_calm())
	_free_husk_later(1.4)

# --- 扎罗 (§5, 黑雾) --------------------------------------------------------------------------

func _intro_zaro(full: bool) -> void:
	var c := BossVfx.colours("zaro")
	var wake := func():
		if not is_instance_valid(boss): return
		boss.asleep = false
		boss.show_row_name = "lift"
		var fx := _fx(boss.global_position)
		_mist(fx, Vector3.UP * 0.1, 26, 1.4, 0.6)
		fx.burst({"at": Vector3.UP * 0.05, "ring": [0.9, 1.2], "amount": 24, "time": 1.6, "speed": [0.6, 1.4], "flat": true, "dir": Vector3.RIGHT, "spread": 180.0,
			"radial": 1.2, "size": BossVfx.P * 18.0, "flip": "smoke_8x8", "near_ok": true,
			"colours": [Color(C.MIST.r, C.MIST.g, C.MIST.b, 0.8), Color(C.MIST_EDGE.r, C.MIST_EDGE.g, C.MIST_EDGE.b, 0.5), Color(0, 0, 0, 0.0)]})
		BossVfx.shake(game, 3.0, 10)
		_sfx("zaro_growl")
		_sfx("zaro_bell", 0.3)
		_after(0.5, func(): if is_instance_valid(boss): boss.show_row_name = "")
	if full:
		_shade_to({"dim": 0.4, "tint": Color(0.15, 0.1, 0.14), "k": 0.4}, C.PAN)
		_at(C.PAN + 0.2, func():
			if is_instance_valid(boss): boss.eyes_open = true)
		_at(C.PAN + 0.7, wake)
		_at(C.PAN + 1.0, func():
			if is_instance_valid(game.arena): game.arena.show_family_umbrellas())
	else:
		boss.eyes_open = true
		wake.call()

func _phase_zaro(n: int) -> void:
	var fx := _fx(boss.global_position)
	_mist(fx, Vector3.UP * 0.2, 20, 1.2, 0.8)
	if n >= 3 and is_instance_valid(game.arena): game.arena.wolf_eyes(true)

## Down; the body goes up as black mist; a standing wolf gathers out of it (§5.6).
func _zaro_rebirth(b: Boss) -> void:
	var at := boss.global_position
	var fx := _fx(at)
	_after(0.5, func():
		if not is_instance_valid(boss): return
		_husk = husk_of(boss)
		boss.hide_figure()
		var mat := _husk.material_override as ShaderMaterial if is_instance_valid(_husk) else null
		if mat != null:
			mat.set_shader_parameter("mode", 2)
			mat.set_shader_parameter("fade_colour", C.MIST)
			mat.set_shader_parameter("edge_colour", C.MIST_EDGE)
		_tween_husk("fade", 1.0, 0.25)
		_tween_husk("amount", 1.0, 0.6, 0.15)
		_free_husk_later(0.9)
		_mist(_fx(at), Vector3.UP * 0.4, 40, 0.8, 1.4, 0.1, 1.4))
	_after(1.2, func():
		if not is_instance_valid(boss): return
		var f2 := _fx(at)
		f2.burst({"at": Vector3.UP * 0.8, "ring": [1.8, 2.6], "amount": 36, "time": 0.8, "speed": [0.1, 0.3], "radial": -5.0, "gravity": Vector3.ZERO,
			"size": BossVfx.P * 14.0, "flip": "smoke_8x8", "near_ok": true,
			"colours": [Color(C.MIST.r, C.MIST.g, C.MIST.b, 0.0), Color(C.MIST.r, C.MIST.g, C.MIST.b, 0.8), Color(C.MIST_EDGE.r, C.MIST_EDGE.g, C.MIST_EDGE.b, 0.0)]}))
	_after(1.9, func():
		if not is_instance_valid(boss): return
		boss.set_shown(true)
		_mist(_fx(at), Vector3.UP * 0.1, 18, 1.0, 0.5))
	if is_instance_valid(game.arena): _after(0.0, func(): if is_instance_valid(game.arena): game.arena.tint_fountain(0.85))
	fx.glow(2.0, Color("2a1418"), 0.8, 0.8)

## 满盘皆输: down; one last try to rise fails; black mist spreads; the eyes go out.
func _fall_zaro(b: Boss) -> void:
	var at := b.global_position
	var look := [b.enemy_type, b.sheet_type, b.dir_column]
	if is_instance_valid(_husk): _husk.visible = true
	_after(0.45, func():
		if not is_instance_valid(_husk): return
		_husk_row(look, "struggle")
		var tween := _husk.create_tween()
		tween.tween_property(_husk, "position:y", _husk.position.y + 0.06, 0.18)
		tween.tween_property(_husk, "position:y", _husk.position.y, 0.12)
		tween.tween_callback(func(): _husk_row(look, "dies")))
	_tween_husk("fade", 1.0, 0.4, 0.75)
	_tween_husk("amount", 1.0, 0.6, 0.85)
	_after(0.85, func():
		var fx := _fx(at)
		_mist(fx, Vector3.UP * 0.2, 46, 0.6, 1.0, 0.0, 1.6)
		fx.burst({"at": Vector3.UP * 0.1, "ring": [0.5, 1.0], "amount": 30, "time": 1.4, "speed": [1.5, 3.0], "flat": true, "dir": Vector3.RIGHT, "spread": 180.0,
			"radial": 2.5, "size": BossVfx.P * 18.0, "flip": "smoke_8x8", "near_ok": true,
			"colours": [Color(C.MIST.r, C.MIST.g, C.MIST.b, 0.75), Color(C.MIST_EDGE.r, C.MIST_EDGE.g, C.MIST_EDGE.b, 0.45), Color(0, 0, 0, 0.0)]})
		if is_instance_valid(game.arena):
			game.arena.wolf_eyes(false)
			game.arena.tint_fountain(0.0))
	_free_husk_later(1.6)

# --- The wardens (§6) --------------------------------------------------------------------------

func warden_intro(figure: Boss) -> void:
	var c := BossVfx.colours(figure.figure_id)
	figure.show_row_name = "intro"
	var id := figure.get_instance_id()
	_after(0.8, func():
		var f := instance_from_id(id) as Boss
		if is_instance_valid(f) and f.show_row_name == "intro": f.show_row_name = "")
	var fx := _fx(figure.global_position)
	fx.ring(2.0, BossVfx.P * 3.0, c.hot, Color(c.main.r, c.main.g, c.main.b, 0.0), {"fade": 0.3})
	fx.glow(1.8, c.main, 0.8, 0.5)
	match figure.figure_id:
		"crownslayer": fx.dust(Vector3.UP * 0.4, c.dust, 18, 0.8, 0.0, 1.2)
		"skullshatterer": BossVfx._explosion(fx, 1.2, c)
		"hollow_snowpriest": fx.halo(Vector3.UP * 1.6, 1.2, c.hot, 0.8, 0.5)
		"father_agnir": fx.halo(Vector3.UP * 2.0, 1.0, c.hot, 0.9, 0.5)
	if is_instance_valid(game.look):
		var was := _shade_goal.duplicate()
		_shade_to({"dim": 0.12, "tint": Color(0.2, 0.2, 0.25), "k": 0.15}, 0.15)
		_after(0.3, func(): _shade_to(was if float(was.get("dim", 0.0)) > 0.0 else {"dim": 0.0, "tint": Color.WHITE, "k": 0.0}, 0.4))

func _fall_crownslayer(b: Boss) -> void:
	var c := BossVfx.colours("crownslayer")
	var fx := _fx(b.global_position)
	_tween_husk("amount", 1.0, 0.35, 0.35)
	_prop("prop_crownslayer_knife", b.global_position, 2.5, c.dust)
	fx.dust(Vector3.UP * 0.5, c.dust, 22, 0.8, 0.3, 1.0)
	fx.sparks(Vector3.UP * 0.1, c.main, c.hot, 6, 1.0, Vector3.UP, 40.0, 0.1)
	_free_husk_later(0.8)

func _fall_skullshatterer(b: Boss) -> void:
	var c := BossVfx.colours("skullshatterer")
	var fx := _fx(b.global_position)
	for i in range(3): fx.glow(0.6, c.main, 0.9, 0.08, 0.15 + 0.18 * i)
	fx.dust(Vector3.UP * 0.4, Color("8a8a90"), 8, 0.4, 0.65, 0.8)
	_tween_husk("fade", 0.6, 0.5, 0.2)
	_tween_husk("amount", 1.0, 0.3, 0.5)
	_free_husk_later(0.8)

func _fall_hollow_snowpriest(b: Boss) -> void:
	var c := BossVfx.colours("hollow_snowpriest")
	var fx := _fx(b.global_position)
	for i in range(3): fx.halo(Vector3.UP * 1.6, 0.8 - 0.2 * i, c.hot, 0.8, 0.07, 0.1 * i)
	_tween_husk("amount", 1.0, 0.5, 0.25)
	fx.burst({"at": Vector3.UP * 1.0, "radius": 0.4, "amount": 20, "time": 0.7, "speed": [0.1, 0.4], "spread": 80.0, "gravity": Vector3(0, -1.0, 0),
		"size": BossVfx.P * 1.0, "colours": [c.dust, Color("dceefa"), Color(1, 1, 1, 0.0)], "near_ok": true, "delay": 0.25})
	_free_husk_later(0.8)

func _fall_father_agnir(b: Boss) -> void:
	var c := BossVfx.colours("father_agnir")
	var fx := _fx(b.global_position)
	fx.halo(Vector3.UP * 2.0, 1.0, c.hot, 1.0, 0.12)
	fx.halo(Vector3.UP * 2.0, 0.6, c.hot, 0.6, 0.08, 0.2)
	_tween_husk("fade", 0.5, 0.3, 0.1)
	_tween_husk("amount", 1.0, 0.4, 0.35)
	_free_husk_later(0.8)
