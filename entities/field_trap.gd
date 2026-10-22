class_name FieldTrap
extends Node3D

## A trap on the floor (密室与陷阱修订案_v1 §2.2, 用户 2026-10-17: 能致死、扣固定
## 数值、涨威胁值). It goes off once when she steps over it: a fixed blow
## (true damage, so armour and evasion do not change it; a shield still
## takes it), and the 威胁值 rises. Seen if looked for: a region's own small
## thing on the ground, no name, not on the minimap.
##
## 用户 2026-10-22 (优化陷阱的表现形式和效果，可以换建模):
## - A heavy trap has a fuse: it gives itself away the moment it is stepped on
##   (rock grit falling and a shadow spreading, a lid rattling and hissing, ice
##   cracking out, a slab grinding) and its blow lands FUSE seconds later on
##   whoever is still within its reach — a dodge out of it takes no blow, but
##   the 威胁值 has risen all the same.
## - A light trap strikes at once and holds her a moment: the jaws hold, the
##   current numbs, the wire trips, the spikes throw her off.
## - Each region's trap has its own blow on screen, and once sprung it is
##   swapped for its sprung model (trap_<region>_<kind>_sprung): the jaws shut,
##   the lid thrown off, the ice in floes, the rocks heaped.
## - Armed, it glints now and then when she is near (TELL_REACH): a spark off
##   the cable, light off the jaw's teeth, grit trickling down.
## - Foes on her trail spring it too and take its blow; that raises no 威胁值.

## kind -> its reach, its blow, the 威胁值 it adds, its fuse.
const KINDS := {
	"heavy": {"radius": 1.5, "damage": 600.0, "threat": 8.0, "fuse": 0.5},
	"light": {"radius": 0.8, "damage": 300.0, "threat": 4.0, "fuse": 0.0},
}
## The blow lands on whoever is within this share of its reach when the fuse ends.
const FUSE_REACH := 1.1
## What each region's trap does besides its blow: stun (seconds she is held),
## knock (metres she is thrown off), cold (寒冷 added), threat (威胁值 on top:
## the wire's bell rings), tell (how it glints when she is near).
const EFFECTS := {
	"mine_heavy": {"tell": "grit"},
	"mine_light": {"stun": 0.9, "tell": "glint"},
	"city_heavy": {"tell": "steam"},
	"city_light": {"stun": 0.6, "tell": "spark"},
	"snow_heavy": {"cold": 15.0, "tell": "glitter"},
	"snow_light": {"knock": 1.6, "tell": "glitter"},
	"siracusa_heavy": {"tell": "grit"},
	"siracusa_light": {"stun": 0.6, "threat": 4.0, "tell": "glint"},
}
## The model per region and kind (art/kit/trap_<region>_<kind>[_sprung].glb).
const MODEL := "res://art/kit/trap_%s_%s.glb"
const SPRUNG := "res://art/kit/trap_%s_%s_sprung.glb"
## Within this of her an armed trap glints, every TELL_EVERY seconds or so.
const TELL_REACH := 4.5
const TELL_EVERY := Vector2(1.6, 3.2)
## Its colours per region: dust and debris, the hot core of its blow.
const COLOURS := {
	"mine": {"dust": Color("8a7c6c"), "dark": Color("3a3028"), "hot": Color("ffd08a")},
	"city": {"dust": Color("c8ccd0"), "dark": Color("3a3a3c"), "hot": Color("b8e0ff")},
	"snow": {"dust": Color("dcecf0"), "dark": Color("2a3e4a"), "hot": Color("e8f8ff")},
	"siracusa": {"dust": Color("b0a088"), "dark": Color("4a4034"), "hot": Color("ffd890")},
}

var game: GameManager
var kind := "light"
var region := "mine"
var spent := false
## Seconds left on a heavy trap's fuse once stepped on (<0 when not lit).
var fuse := -1.0
## Whether she sprang it (the 威胁值 rose), or a foe did.
var by_player := false
var _tell_wait := 0.0
var _look: MeshInstance3D
var _shadow: MeshInstance3D
var _rng := RandomNumberGenerator.new()

func setup(p_game: GameManager, p_kind: String, p_region: String) -> void:
	game = p_game
	kind = p_kind
	region = FieldCatalog.art_region(p_region) if p_region != "siracusa" else p_region
	_look = MeshInstance3D.new()
	_look.name = "Look"
	_look.mesh = TerraceDressing.kit_mesh(load(MODEL % [region, kind]))
	add_child(_look)
	_rng.randomize()
	_tell_wait = _rng.randf_range(TELL_EVERY.x, TELL_EVERY.y)

func radius() -> float:
	return float(KINDS[kind].radius)

func effect() -> Dictionary:
	return EFFECTS.get(region + "_" + kind, {})

func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

## Called each physics frame while the floor runs.
func check(player: Player) -> void:
	if fuse >= 0.0:
		_burn(player, get_physics_process_delta_time())
		return
	if spent: return
	var near := is_instance_valid(player) and _flat(player.global_position, global_position) <= radius()
	if near and not player.invulnerable and player.invuln_timer <= 0.0:
		spring(player)
		return
	if not near:
		for e in _chasers():
			if _flat(e.global_position, global_position) <= radius():
				spring(null)
				return
	if is_instance_valid(player) and _flat(player.global_position, global_position) < TELL_REACH:
		_tell_wait -= get_physics_process_delta_time()
		if _tell_wait <= 0.0:
			_tell_wait = _rng.randf_range(TELL_EVERY.x, TELL_EVERY.y)
			_tell()

## Foes on her trail (not those standing about or going home).
func _chasers() -> Array:
	var out := []
	if not is_instance_valid(game) or not game.is_inside_tree(): return out
	for e in game.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e._dead and e.state == Enemy.State.CHASING: out.append(e)
	return out

## Set off, by her (`player`) or by a foe (null). A heavy trap lights its fuse;
## a light one strikes now.
func spring(player: Player) -> void:
	if spent: return
	spent = true
	by_player = player != null
	if by_player:
		game.trap_sprung(float(KINDS[kind].threat) + float(effect().get("threat", 0.0)))
	if float(KINDS[kind].fuse) > 0.0:
		fuse = float(KINDS[kind].fuse)
		_warn()
	else:
		_strike()

func _burn(player: Player, delta: float) -> void:
	fuse -= delta
	var t := 1.0 - fuse / float(KINDS[kind].fuse)
	# What moves while the fuse burns: the lid rattles, the slab grinds down.
	if region == "city": _look.rotation = Vector3(sin(t * 60.0) * 0.03, 0.0, cos(t * 47.0) * 0.03)
	elif region == "siracusa": _look.position.y = -0.05 * t
	if is_instance_valid(_shadow):
		var s := lerpf(0.35, 1.0, t)
		_shadow.scale = Vector3(s, 1.0, s)
		(_shadow.material_override as StandardMaterial3D).albedo_color.a = 0.55 * t
	if fuse <= 0.0:
		fuse = -1.0
		if is_instance_valid(_shadow): _shadow.queue_free()
		_look.rotation = Vector3.ZERO
		_look.position.y = 0.0
		_strike()

## The blow: on her if she is within reach, on every foe within it, and on screen.
func _strike() -> void:
	var reach := radius() * (FUSE_REACH if float(KINDS[kind].fuse) > 0.0 else 1.0)
	var blow := float(KINDS[kind].damage) * Scaling.tier_coef(game.floor_number)
	var player := game.player
	if is_instance_valid(player) and _flat(player.global_position, global_position) <= reach and not player.invulnerable and player.invuln_timer <= 0.0:
		# Written at tier Ⅰ, × the floor's 档位系数 (复利数值改造清单 E).
		player.take_damage(blow, "true")
		var fx := effect()
		if fx.has("stun"): player.apply_control("stun", Vector3.ZERO, 0.0, float(fx.stun))
		if fx.has("knock"):
			var away := player.global_position - global_position
			player.apply_control("knockback", away if away.length() > 0.05 else Vector3.FORWARD, float(fx.knock), 0.2)
		if fx.has("cold") and game.features != null: game.features.add("cold", float(fx.cold))
		game.sound.play("hurt")
	for e in _foes_within(reach):
		e.take_hit(blow, "true")
	game.sound.play("hit")
	_show_blow()
	# Sprung, it is spent: its sprung model takes its place.
	var sprung := SPRUNG % [region, kind]
	if ResourceLoader.exists(sprung): _look.mesh = TerraceDressing.kit_mesh(load(sprung))
	else: _look.position.y -= 0.03

func _foes_within(reach: float) -> Array:
	var out := []
	for e in game.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e._dead and _flat(e.global_position, global_position) <= reach: out.append(e)
	return out

# --- On screen ------------------------------------------------------------------

func _colours() -> Dictionary:
	return COLOURS.get(region, COLOURS.mine)

func _fx() -> BossVfx:
	return BossVfx.make(game, global_position)

## A soft dark pool spreading on the ground under what is coming down.
func _make_shadow() -> void:
	_shadow = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * radius() * 2.2
	_shadow.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = BossVfx.soft_texture()
	mat.albedo_color = Color(0.0, 0.0, 0.0, 0.0)
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_shadow.material_override = mat
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow.position.y = BossVfx.GROUND + 0.01
	add_child(_shadow)

## A heavy trap's fuse is lit: it gives itself away.
func _warn() -> void:
	var fx := _fx()
	var c := _colours()
	var f := float(KINDS[kind].fuse)
	match region:
		"mine":
			_make_shadow()
			# Grit trickling down from the roof, then the rocks themselves.
			fx.burst({"at": Vector3.UP * 3.2, "radius": radius() * 0.6, "amount": 18, "time": 0.6, "speed": [0.2, 0.6], "dir": Vector3.DOWN, "spread": 10.0,
				"gravity": Vector3(0, -9.0, 0), "size": BossVfx.P * 1.0, "tints": [c.dark, c.dust], "colours": [Color.WHITE, Color.WHITE, Color(1, 1, 1, 0.6)], "explosive": 0.3, "near_ok": true})
			for k in range(6):
				var a := TAU * k / 6.0 + _rng.randf_range(-0.4, 0.4)
				var r := _rng.randf_range(0.5, radius() * 0.85)
				var w := _rng.randf_range(0.14, 0.24)
				var rock := fx._piece(BossVfx._crystal_mesh(w, w * 1.3, c.dark.lightened(0.25), c.dust), Vector3(cos(a) * r, 3.6, sin(a) * r),
					{"vel": Vector3(0, -3.0, 0), "grav": 24.0, "life": f + 0.35, "fade": 0.3, "delay": _rng.randf_range(0.0, 0.08)})
				rock.basis = Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.RIGHT, PI)
		"city":
			for k in range(3):
				fx.dust(Vector3(_rng.randf_range(-0.3, 0.3), 0.1, _rng.randf_range(-0.3, 0.3)), c.dust, 4, 0.25, k * 0.15, 1.6)
		"snow":
			for k in range(7):
				var a := TAU * k / 7.0 + _rng.randf_range(-0.3, 0.3)
				fx.crack(Vector3(cos(a), 0, sin(a)), radius() * _rng.randf_range(0.7, 1.05), c.hot, Color(0.7, 0.9, 1.0))
			fx.glow(radius(), Color(0.5, 0.75, 0.9), 0.35, f + 0.1, 0.0, Vector3.ZERO, 0.8)
		"siracusa":
			fx.dust(Vector3.UP * 0.05, c.dust, 8, radius() * 0.6, 0.0, 0.4)
			fx.chips(Vector3.UP * 0.05, 8, radius() * 0.6, c.dust, 1.2)
	game.sound.play("charge")

## The blow on screen, its region's own.
func _show_blow() -> void:
	var fx := _fx()
	var c := _colours()
	var r := radius()
	match region + "_" + kind:
		"mine_heavy":
			fx.dust(Vector3.UP * 0.2, c.dust, 18, r * 0.8, 0.0, 1.4)
			fx.chips(Vector3.UP * 0.1, 18, r * 0.7, c.dust, 3.0)
			BossVfx.shake(game, 7.0, 10)
		"mine_light":
			fx.sparks(Vector3.UP * 0.25, Color("ffc070"), Color("fff0c0"), 12, 3.0)
			fx.chips(Vector3.UP * 0.05, 6, 0.3, c.dust, 1.5)
			BossVfx.shake(game, 3.0, 5)
		"city_heavy":
			fx.dust(Vector3.UP * 0.1, c.dust, 16, 0.4, 0.0, 2.6)
			fx.chips(Vector3.UP * 0.1, 12, 0.4, c.dark.lightened(0.3), 3.5)
			fx.sparks(Vector3(0.6, 0.1, -0.3), Color("ffc070"), Color("fff0c0"), 10, 3.5, Vector3(1, 1, -0.5).normalized(), 40.0)
			BossVfx.shake(game, 6.0, 9)
		"city_light":
			# The current: blue-white sparks, a flash, a ring of arcs.
			fx.sparks(Vector3(0.85, 0.1, 0.1), Color("6ab8ff"), Color("f0f8ff"), 26, 5.0, Vector3.UP, 85.0)
			fx.glow(1.6, Color("8ac8ff"), 1.1, 0.35)
			fx.ring(0.9, 0.08, Color("e0f4ff"), Color("4a9aff"), {"additive": true, "from_share": 0.2, "fade": 0.25, "sweep": 0.08})
			fx.halo(Vector3(0.85, 0.4, 0.1), 1.2, Color("8ac8ff"), 0.9, 0.25)
			BossVfx.shake(game, 3.0, 6)
		"snow_heavy":
			fx.splat(r * 0.75, Color("0e1c26"), Color("3a5868"), {"spread": 0.25, "hold": 1.2, "dry": 1.0})
			fx.burst({"at": Vector3.UP * 0.1, "radius": r * 0.5, "amount": 22, "time": 0.7, "speed": [1.5, 3.5], "spread": 50.0, "gravity": Vector3(0, -9.0, 0),
				"size": BossVfx.P * 1.2, "tints": [Color("e8f4fa"), Color("a8c4d4"), Color("6a8c9e")], "colours": [Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)]})
			fx.dust(Vector3.UP * 0.2, c.dust, 12, r * 0.6, 0.05, 1.0)
			BossVfx.shake(game, 6.0, 9)
		"snow_light":
			for k in range(7):
				var a := TAU * k / 7.0 + _rng.randf_range(-0.3, 0.3)
				var at := Vector3(cos(a), 0.0, sin(a)) * _rng.randf_range(0.35, 0.75)
				var tall := _rng.randf_range(0.35, 0.7)
				var spike := fx._piece(BossVfx._crystal_mesh(maxf(BossVfx.P * 3.0, tall * 0.22), tall, Color("9cc8dc"), Color("f0faff")), at,
					{"delay": k * 0.02, "life": 0.7, "fade": 0.3, "from": Vector3(0.6, 0.02, 0.6), "to": Vector3.ONE, "grow": 0.12})
				spike.basis = Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3(sin(a), 0, -cos(a)), -0.35)
			fx.burst({"at": Vector3.UP * 0.1, "radius": 0.5, "amount": 14, "time": 0.5, "speed": [1.0, 2.5], "spread": 60.0, "gravity": Vector3(0, -9.0, 0),
				"size": BossVfx.P, "additive": true, "colours": [Color("f0faff"), Color("9cc8dc"), Color(0.6, 0.8, 0.9, 0.0)], "near_ok": true})
			BossVfx.shake(game, 3.0, 5)
		"siracusa_heavy":
			fx.dust(Vector3.UP * 0.1, c.dust, 16, r * 0.6, 0.0, 1.2)
			fx.chips(Vector3.UP * 0.1, 16, r * 0.6, c.dust, 2.5)
			BossVfx.shake(game, 6.0, 9)
		"siracusa_light":
			# The wire snaps and the bell rings: rings of its sound going out.
			fx.sparks(Vector3(0.7, 0.2, 0.0), Color("ffc070"), Color("fff0c0"), 8, 2.5)
			for k in range(3):
				fx.ring(1.4 + k * 0.5, 0.04, Color("ffe0a0"), Color("c89030"), {"additive": true, "from_share": 0.15, "fade": 0.5, "sweep": 0.35, "delay": k * 0.22})
			fx.dust(Vector3.UP * 0.05, c.dust, 6, 0.4, 0.05, 0.6)
			BossVfx.shake(game, 2.0, 4)

## Armed, with her near: it glints, as such things do.
func _tell() -> void:
	var fx := _fx()
	var c := _colours()
	match str(effect().get("tell", "")):
		"spark":
			fx.sparks(Vector3(0.9, 0.08, 0.1), Color("ffc070"), Color("fffbe0"), 4, 1.6)
			fx.glow(0.5, Color("ffc070"), 0.5, 0.18, 0.0, Vector3(0.9, 0, 0.1))
		"glint":
			fx.burst({"at": Vector3(_rng.randf_range(-0.3, 0.3), 0.12, _rng.randf_range(-0.15, 0.15)), "amount": 1, "time": 0.35, "speed": [0.0, 0.0], "gravity": Vector3.ZERO,
				"size": BossVfx.P * 4.0, "additive": true, "soft": true, "colours": [Color(1, 1, 0.9, 0.0), Color(1, 1, 0.9, 0.9), Color(1, 1, 0.9, 0.0)], "near_ok": true})
		"glitter":
			fx.burst({"at": Vector3.UP * 0.05, "radius": radius() * 0.6, "amount": 4, "time": 0.6, "speed": [0.0, 0.1], "gravity": Vector3.ZERO, "explosive": 0.4,
				"size": BossVfx.P * 1.2, "additive": true, "colours": [Color(0.9, 1, 1, 0.0), Color(0.9, 1, 1, 0.8), Color(0.9, 1, 1, 0.0)], "near_ok": true})
		"grit":
			fx.burst({"at": Vector3.UP * 2.5, "radius": radius() * 0.4, "amount": 5, "time": 0.55, "speed": [0.1, 0.3], "dir": Vector3.DOWN, "spread": 8.0,
				"gravity": Vector3(0, -9.0, 0), "size": BossVfx.P * 0.9, "tints": [c.dark, c.dust], "colours": [Color.WHITE, Color.WHITE, Color(1, 1, 1, 0.4)], "explosive": 0.2, "near_ok": true})
		"steam":
			fx.dust(Vector3(0.35, 0.05, 0.0), c.dust, 2, 0.1, 0.0, 0.6)
