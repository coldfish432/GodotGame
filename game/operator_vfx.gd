class_name OperatorVfx
extends RefCounted

## The operators' own attack effects (用户 2026-10-20: 给角色也做攻击特效), laid
## over the painted swings and Sol's skill art with the same pieces the bosses
## use (BossVfx: ground bands and light, fluids, particles, flipbook dust). Each operator has her colours (PRTS: Lappland's pale blue
## arts, Amiya's crimson Chimera blade, Hellagur's blood-red edge, Hoshiguma's
## jade oni shield, Typhon's frost-white arrows, Rosa's rose-silver bolts,
## Lin's violet jade array, Santalla's ice, Texas's red sword rain).
## Like the bosses' effects, nothing covers anyone: what is at her feet or on a
## target is flat on the ground, and what stands up keeps clear of figures.
## Called from Player: swing() as she attacks, hit() when her blow lands
## (_deal), skill() when her Space skill goes off, finisher() for 绝影's last.
## No camera shake on hers (用户 2026-10-20: 角色不做震动).

const P := 1.0 / 15.0
const PALETTES := {
	"lappland": {"main": Color("8ec4ff"), "hot": Color("eef6ff"), "dark": Color("2a3a5a"), "dust": Color("b8c4d0")},
	"amiya_guard": {"main": Color("e0365a"), "hot": Color("ffc0d0"), "dark": Color("3a0e1a"), "dust": Color("8a5a66")},
	"hellagur": {"main": Color("c8282a"), "hot": Color("ffb0a0"), "dark": Color("2a0c0c"), "dust": Color("7a5a52")},
	"hoshiguma": {"main": Color("3ec48a"), "hot": Color("c8ffe0"), "dark": Color("123a28"), "dust": Color("8a8a7a")},
	"typhon": {"main": Color("a8d8ff"), "hot": Color("ffffff"), "dark": Color("2a3a4a"), "dust": Color("d8e4ec")},
	"rosa": {"main": Color("e88aaa"), "hot": Color("fff0f4"), "dark": Color("4a2a36"), "dust": Color("b8aab0")},
	"lin": {"main": Color("8a7aff"), "hot": Color("e8e4ff"), "dark": Color("2a2060"), "dust": Color("b0a8d8")},
	"santalla": {"main": Color("7ad8f4"), "hot": Color("f0fcff"), "dark": Color("1a4050"), "dust": Color("dcf0f8")},
	"texas": {"main": Color("e04848"), "hot": Color("ffd0c0"), "dark": Color("3a1414"), "dust": Color("8a6a62")},
}
## A blow lands on the same enemy at most this often with an effect.
const HIT_GAP := 0.07

static var _last_hit := {}

static func colours(operator_id: String) -> Dictionary:
	return PALETTES.get(operator_id, PALETTES.lappland)

static func _ok(player: Player) -> bool:
	return is_instance_valid(player) and is_instance_valid(player.game) and not player.game.in_base

static func _foot(game: GameManager, at: Vector3) -> Vector3:
	return Vector3(at.x, game.ground_y(at) + 0.01, at.z)

static func _edge(c: Dictionary) -> Color:
	return Color(c.main.r, c.main.g, c.main.b, 0.0)

## Her attack going out, in her own shape (用户 2026-10-20: 干员之间攻击模组和
## 特效做出差异): Lappland's paired blades, Amiya's single one-handed stroke,
## Hellagur's straight thrusts, Hoshiguma's shield, Texas's quick flicks, an
## arts circle for Lin and frost for Santalla, a bowstring for Typhon and a
## launcher's blast for Rosa.
static func swing(player: Player, direction: Vector3, stage: int, release: bool) -> void:
	if not _ok(player): return
	var game := player.game
	var id := player.operator_id
	var c := colours(id)
	var dir := Vector3(direction.x, 0.0, direction.z).normalized() if Vector2(direction.x, direction.z).length_squared() > 0.0001 else Vector3.FORWARD
	var fx := BossVfx.make(game, _foot(game, player.global_position))
	var reach := clampf(player.weapon_range(), 1.6, 3.2)
	match id:
		"amiya_guard": _one_hand(fx, c, dir, reach, stage)
		"hellagur": _hellagur(game, player, fx, c, dir, reach, stage)
		"hoshiguma": _shield(game, player, fx, c, dir, reach, stage)
		"texas": _quick_blade(fx, c, dir, reach, stage)
		"lin": _lin_cast(fx, c, dir, stage)
		"santalla": _frost_cast(fx, c, dir, stage)
		"typhon": _bowstring(fx, c, dir)
		"rosa": _launcher(fx, c, dir, stage)
		_: _twin_blades(fx, c, dir, reach, stage, release)

static func _half(c: Dictionary, alpha: float = 0.5) -> Color:
	return Color(c.main.r, c.main.g, c.main.b, alpha)

## Lappland: two blades, so every cut comes as a pair, the second a beat
## behind; the third (日晷) crosses them in an X surging ahead.
static func _twin_blades(fx: BossVfx, c: Dictionary, dir: Vector3, reach: float, stage: int, release: bool) -> void:
	var edge := _edge(c)
	if stage == 2:
		var side := dir.cross(Vector3.UP)
		for s in [1.0, -1.0]:
			var d := dir.rotated(Vector3.UP, deg_to_rad(10.0) * s)
			fx.beam(d, reach * 1.1, P * 6.0, c.hot, _half(c), {"start": 0.3, "sweep": 0.06, "hold": 0.08, "fade": 0.25, "at": side * 0.35 * s})
		fx.glow(reach * 1.1, c.main, 0.8, 0.3, 0.0, dir * reach * 0.6)
		for i in range(3):
			var ray := dir.rotated(Vector3.UP, deg_to_rad(-20.0 + 20.0 * i))
			fx.sparks(ray * reach + Vector3.UP * 0.2, c.main, c.hot, 5, 3.0, ray + Vector3.UP * 0.4, 40.0, 0.02 * i)
	else:
		var flip := stage == 1
		fx.arc(dir, reach, 120.0, P * 7.0, c.hot, _half(c), {"sweep": 0.08, "hold": 0.06, "fade": 0.25, "flip": flip, "mask": true, "tiling": Vector2(2.0, 0.6)})
		fx.arc(dir, reach * 0.78, 110.0, P * 5.0, c.main, edge, {"sweep": 0.08, "hold": 0.05, "fade": 0.22, "flip": flip, "delay": 0.05, "additive": true})
		fx.glow(reach, c.main, 0.6, 0.3, 0.0, dir * reach * 0.45)
	if release:
		# Her wave going out: a ring of light.
		fx.ring(1.4, P * 3.0, c.hot, edge, {"fade": 0.3})
		fx.glow(2.0, c.main, 0.7, 0.35)

## Amiya: one one-handed sword, one thin long stroke a swing (用户 2026-10-09);
## the second is the stroke back, the third her straight thrust.
static func _one_hand(fx: BossVfx, c: Dictionary, dir: Vector3, reach: float, stage: int) -> void:
	var edge := _edge(c)
	if stage == 2:
		fx.beam(dir, reach * 1.05, P * 5.0, c.hot, c.main, {"start": 0.35, "sweep": 0.05, "hold": 0.06, "fade": 0.2})
		fx.beam(dir, reach * 0.8, P * 2.0, c.hot, edge, {"start": 0.5, "sweep": 0.04, "hold": 0.04, "fade": 0.2, "additive": true})
		fx.sparks(dir * (reach + 0.3) + Vector3.UP * 0.3, c.main, c.hot, 8, 3.5, dir + Vector3.UP * 0.3, 30.0)
	else:
		fx.arc(dir, reach, 135.0, P * 5.0, c.hot, _half(c), {"sweep": 0.07, "hold": 0.06, "fade": 0.24, "flip": stage == 1, "mask": true, "tiling": Vector2(2.0, 0.6)})
	fx.glow(reach * 0.9, c.main, 0.6, 0.25, 0.0, dir * reach * 0.45)

## Hellagur: his combo is three straight thrusts (用户 2026-10-20), the first
## two quick stabs just left and right of the line, the third a long lunge of
## light running through everyone it takes. 月相's cuts keep their arcs.
static func _hellagur(_game: GameManager, player: Player, fx: BossVfx, c: Dictionary, dir: Vector3, reach: float, _stage: int) -> void:
	var kit := player.kit as HellagurKit
	match kit.stance() if kit != null else "thrust":
		"newmoon":
			fx.beam(dir, reach * 1.1, P * 12.0, c.hot, _half(c, 0.6), {"start": 0.2, "sweep": 0.05, "hold": 0.12, "fade": 0.3, "mask": true})
			fx.glow(reach * 1.2, c.main, 1.0, 0.35, 0.0, dir * reach * 0.6)
			fx.dust(dir * reach * 0.9 + Vector3.UP * 0.1, c.dust, 6, 0.5)
			return
		"halfmoon":
			fx.arc(dir, reach * 0.85, 90.0, P * 6.0, c.hot, _half(c), {"sweep": 0.05, "hold": 0.04, "fade": 0.18, "mask": true})
			fx.arc(dir, reach * 0.85, 90.0, P * 6.0, c.hot, _half(c), {"sweep": 0.05, "hold": 0.04, "fade": 0.18, "flip": true, "delay": 0.09, "mask": true})
			return
		"fullmoon":
			fx.arc(dir, reach * 1.25, 200.0, P * 10.0, c.hot, _half(c), {"sweep": 0.12, "hold": 0.08, "fade": 0.3, "mask": true, "tiling": Vector2(2.0, 0.6)})
			fx.glow(reach * 1.3, c.main, 0.8, 0.35, 0.0, dir * reach * 0.3)
			return
	# A thrust's light waits for the blade to come down (hellagur_thrust).

## 赫拉格's thrust striking (from HellagurKit once the raised blade comes
## down): two quick stabs just left and right of the line, the third a long
## lunge of light running through everyone it takes.
static func hellagur_thrust(player: Player, direction: Vector3, stage: int) -> void:
	if not _ok(player): return
	var game := player.game
	var c := colours(player.operator_id)
	var edge := _edge(c)
	var dir := Vector3(direction.x, 0.0, direction.z).normalized() if Vector2(direction.x, direction.z).length_squared() > 0.0001 else Vector3.FORWARD
	var fx := BossVfx.make(game, _foot(game, player.global_position))
	var reach := clampf(player.weapon_range(), 1.6, 3.2)
	var kit := player.kit as HellagurKit
	var side := dir.cross(Vector3.UP)
	if stage < 2:
		var off := side * (0.12 if stage == 0 else -0.12)
		fx.beam(dir, reach * 1.05, P * 7.0, c.hot, _half(c, 0.7), {"start": 0.35, "sweep": 0.035, "hold": 0.08, "fade": 0.2, "at": off})
		fx.beam(dir, reach * 0.85, P * 2.5, c.hot, edge, {"start": 0.5, "sweep": 0.03, "hold": 0.06, "fade": 0.18, "at": off, "additive": true})
		fx.glow(reach * 0.7, c.main, 0.7, 0.22, 0.0, dir * reach * 0.6)
		# A heavy blade: his front foot stamps, grit kicked up behind the lunge.
		fx.dust(dir * 0.3 + Vector3.UP * 0.05, c.dust, 5, 0.35, 0.0, 0.5)
		fx.chips(dir * (reach + 0.2) + Vector3.UP * 0.1, 6, 0.25, c.dust, 1.8)
		fx.halo(dir * (reach + 0.35) + Vector3.UP * 0.3 + off, 0.5, c.hot, 0.8, 0.14)
		fx.sparks(dir * (reach + 0.3) + Vector3.UP * 0.3, c.main, c.hot, 6, 3.5, dir + Vector3.UP * 0.2, 22.0)
		return
	var length := kit.pierce_length() if kit != null else reach + 1.2
	fx.beam(dir, length, P * 14.0, c.hot, _half(c, 0.75), {"start": 0.3, "sweep": 0.06, "hold": 0.16, "fade": 0.32})
	fx.beam(dir, length * 0.95, P * 5.0, c.hot, edge, {"start": 0.4, "sweep": 0.05, "hold": 0.14, "fade": 0.28, "additive": true})
	for s in [-1.0, 1.0]:
		fx.beam(dir, length * 0.6, P * 1.2, c.main, edge, {"start": 0.6, "sweep": 0.07, "hold": 0.02, "fade": 0.2, "at": side * 0.35 * s, "additive": true, "delay": 0.03})
	fx.glow(length * 0.8, c.main, 0.9, 0.35, 0.0, dir * length * 0.55)
	# The ground splits along the line and stone flies, as from a heavy blade.
	fx.crack(dir, length, Color(c.dark.r, c.dark.g, c.dark.b, 0.9), c.main)
	fx.dust(dir * 0.4 + Vector3.UP * 0.05, c.dust, 10, 0.6, 0.0, 0.6)
	for i in range(3):
		fx.chips(dir * length * (0.35 + 0.25 * i) + Vector3.UP * 0.1, 8, 0.3, c.dust, 2.4, 0.03 * i)
	# The tip bursts out past the last one it ran through.
	var tip := BossVfx.make(game, _foot(game, player.global_position + dir * (length + 0.3)))
	tip.ring(0.8, P * 3.0, c.hot, edge, {"from_share": 0.2, "fade": 0.3, "delay": 0.05})
	tip.sparks(Vector3.UP * 0.3, c.main, c.hot, 14, 5.0, dir + Vector3.UP * 0.3, 30.0, 0.05)

## Hoshiguma: a shield bash is a short wide fan of force, the ram a ring ahead.
static func _shield(game: GameManager, player: Player, fx: BossVfx, c: Dictionary, dir: Vector3, reach: float, stage: int) -> void:
	var edge := _edge(c)
	fx.arc(dir, reach * 0.75, 120.0, P * 9.0, c.hot, _half(c), {"sweep": 0.06, "hold": 0.08, "fade": 0.25})
	fx.glow(reach * 0.9, c.main, 0.6, 0.3, 0.0, dir * reach * 0.4)
	if stage == 2:
		var tip := BossVfx.make(game, _foot(game, player.global_position + dir * reach * 0.8))
		tip.ring(1.0, P * 3.0, c.hot, edge, {"fade": 0.3})
		tip.glow(1.4, c.main, 0.7, 0.3)
		tip.chips(Vector3.UP * 0.1, 12, 0.4, c.dust, 2.4)

## Texas: a fast sword, so short flicks gone almost before they show, each
## trailed by a faint echo; the third a straight cut across with sword-glints
## falling round its line (her 剑雨 in small).
static func _quick_blade(fx: BossVfx, c: Dictionary, dir: Vector3, reach: float, stage: int) -> void:
	var edge := _edge(c)
	if stage == 2:
		var side := dir.cross(Vector3.UP)
		var mid := dir * reach * 0.7
		for s in [1.0, -1.0]:
			fx.beam(side * s, reach * 0.8, P * 4.0, c.hot, _half(c, 0.6), {"start": 0.0, "sweep": 0.04, "hold": 0.05, "fade": 0.18, "at": mid})
		for i in range(3):
			var spot := mid + side * (-0.8 + 0.8 * i) + Vector3.UP * 1.4
			fx.sparks(spot, c.main, c.hot, 4, 5.0, Vector3.DOWN, 6.0, 0.04 + 0.03 * i)
		fx.glow(reach, c.main, 0.7, 0.25, 0.0, mid)
		return
	var flip := stage == 1
	fx.arc(dir, reach * 0.85, 80.0, P * 4.0, c.hot, _half(c, 0.55), {"sweep": 0.035, "hold": 0.03, "fade": 0.14, "flip": flip, "mask": true})
	fx.arc(dir, reach * 0.85, 80.0, P * 2.5, c.main, edge, {"sweep": 0.035, "hold": 0.02, "fade": 0.12, "flip": flip, "delay": 0.04, "additive": true})
	fx.sparks(dir * reach * 0.85 + Vector3.UP * 0.3, c.main, c.hot, 4, 4.5, dir.rotated(Vector3.UP, 0.8 if flip else -0.8), 20.0)

## Lin: a small jade-violet array turns before her hand as she casts.
static func _lin_cast(fx: BossVfx, c: Dictionary, dir: Vector3, stage: int) -> void:
	var edge := _edge(c)
	var at := dir * 0.7
	fx.ring(0.55, P * 1.5, c.hot, edge, {"from_share": 1.0, "fade": 0.3, "at": at})
	fx.ring(0.35, P * 1.0, c.main, edge, {"from_share": 1.0, "fade": 0.3, "at": at, "additive": true, "delay": 0.04})
	for a in [0.0, 120.0, 240.0]:
		fx.arc(Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(a)), 0.8, 60.0, P * 2.0, c.main, edge, {"sweep": 0.1, "hold": 0.05, "fade": 0.2, "at": at, "additive": true})
	fx.glow(1.0, c.main, 0.5, 0.3, 0.0, at)
	if stage == 2: fx.embers(Vector3.UP * 0.1, c.main, c.hot, 12, 0.9, 0.0, 0.6)

## Santalla: cold gathers round her, snow motes falling instead of rising.
static func _frost_cast(fx: BossVfx, c: Dictionary, dir: Vector3, stage: int) -> void:
	var edge := _edge(c)
	fx.ring(0.8, P * 2.0, c.hot, edge, {"from_share": 1.4, "fade": 0.35})
	fx.glow(1.1, c.main, 0.45, 0.35, 0.0, dir * 0.4)
	fx.burst({"at": dir * 0.5 + Vector3.UP * 1.2, "radius": 0.6, "amount": 10 if stage < 2 else 18, "time": 0.7, "speed": [0.2, 0.6], "dir": Vector3.DOWN, "spread": 30.0,
		"gravity": Vector3(0, -0.6, 0), "size": P * 1.0, "near_ok": true, "colours": [c.hot, c.dust, Color(c.main.r, c.main.g, c.main.b, 0.0)]})

## Typhon: the bowstring's snap — one long thin line of light off her bow.
static func _bowstring(fx: BossVfx, c: Dictionary, dir: Vector3) -> void:
	var edge := _edge(c)
	fx.beam(dir, 2.6, P * 1.5, c.hot, c.main, {"start": 0.5, "sweep": 0.03, "hold": 0.02, "fade": 0.12, "additive": true})
	fx.arc(-dir, 0.45, 70.0, P * 1.5, c.hot, edge, {"sweep": 0.03, "hold": 0.02, "fade": 0.12, "at": dir * 0.55, "additive": true})
	fx.sparks(dir * 0.9 + Vector3.UP * 0.5, c.main, c.hot, 5, 5.0, dir, 12.0)

## Rosa: a launcher's blast — a short wide flash, smoke and a kick of grit.
static func _launcher(fx: BossVfx, c: Dictionary, dir: Vector3, stage: int) -> void:
	var heavy := stage == 2
	fx.glow(1.6 if heavy else 1.2, c.main, 0.9 if heavy else 0.6, 0.22, 0.0, dir * 0.8)
	fx.beam(dir, 1.1, P * (7.0 if heavy else 5.0), c.hot, c.main, {"start": 0.5, "sweep": 0.03, "hold": 0.03, "fade": 0.14, "additive": true})
	fx.dust(dir * 0.9 + Vector3.UP * 0.3, c.dust, 6 if heavy else 3, 0.3)
	fx.dust(-dir * 0.3 + Vector3.UP * 0.05, c.dust, 4 if heavy else 2, 0.4)
	if heavy: fx.chips(-dir * 0.2 + Vector3.UP * 0.05, 8, 0.3, c.dust, 1.6)

## 林's great array (the third of her combo, 用户 2026-10-20): a wide circle
## of arts at `centre`, rings closing inward, pillars of jade glass rising
## round its rim, a pulse bursting a beat after and light lifting off it.
static func great_array(player: Player, centre: Vector3, radius: float) -> void:
	if not _ok(player): return
	var game := player.game
	var c := colours(player.operator_id)
	var edge := _edge(c)
	var fx := BossVfx.make(game, _foot(game, centre))
	fx.ring(radius, P * 3.0, c.hot, _half(c), {"from_share": 1.0, "hold": 0.25, "fade": 0.4})
	fx.ring(radius * 0.72, P * 2.0, c.main, edge, {"from_share": 1.3, "hold": 0.15, "fade": 0.4, "additive": true, "delay": 0.05})
	fx.ring(radius * 0.4, P * 1.5, c.hot, edge, {"from_share": 1.6, "hold": 0.1, "fade": 0.4, "additive": true, "delay": 0.1})
	for i in range(6):
		var spoke := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 6.0 + randf() * 0.2)
		fx.arc(spoke, radius * 0.86, 40.0, P * 2.0, c.main, edge, {"sweep": 0.14, "hold": 0.1, "fade": 0.3, "additive": true, "delay": 0.03 * i})
		fx.beam(spoke, radius * 0.55, P * 1.2, c.hot, edge, {"start": radius * 0.4, "sweep": 0.1, "hold": 0.1, "fade": 0.3, "additive": true, "delay": 0.05})
		fx.crystal(spoke * radius, 0.9 + randf() * 0.4, c.main, c.hot, 0.06 + 0.04 * i, 0.55)
	fx.glow(radius * 1.4, c.main, 1.1, 0.6)
	# A beat later the array bursts: a pulse out past the rim, motes rising.
	fx.ring(radius * 1.15, P * 4.0, c.hot, edge, {"from_share": 0.2, "fade": 0.35, "delay": 0.28})
	fx.glow(radius * 1.2, c.hot, 0.8, 0.35, 0.28)
	fx.embers(Vector3.UP * 0.1, c.main, c.hot, 36, radius * 0.9, 0.2, 1.0)
	fx.shaft(Vector3.ZERO, 0.6, 3.0, c.main, 0.9, 0.7, 0.2)

## Her blow landing on `target`: light and a ring on the ground under it, sparks
## thrown out round it (never over it), her own touch per operator.
static func hit(player: Player, target: Enemy, kind: String, crit: bool) -> void:
	if not _ok(player) or not is_instance_valid(target) or target.attack_profile.get("neutral", false): return
	var key := target.get_instance_id()
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_hit.get(key, -1.0)) < HIT_GAP: return
	_last_hit[key] = now
	if _last_hit.size() > 256: _last_hit.clear()
	var game := player.game
	var id := player.operator_id
	var c := colours(id)
	var edge := _edge(c)
	var at := target.global_position
	var fx := BossVfx.make(game, _foot(game, at))
	var from := at - player.global_position
	from.y = 0.0
	var dir := from.normalized() if from.length_squared() > 0.001 else Vector3.FORWARD
	var r := 1.2 if crit else 0.95
	fx.ring(r, P * (5.0 if crit else 3.5), c.hot, Color(c.main.r, c.main.g, c.main.b, 0.4), {"fade": 0.3})
	fx.glow(r * 1.8, c.main, 1.0 if crit else 0.75, 0.3)
	fx.sparks(Vector3.UP * 0.4, c.main, c.hot, 18 if crit else 12, 4.0, dir + Vector3.UP * 0.6, 55.0)
	match id:
		"hellagur":
			# A thrust goes through: a short streak out the far side of him.
			fx.beam(dir, 1.0, P * 3.0, c.hot, _half(c, 0.6), {"start": 0.2, "sweep": 0.04, "hold": 0.05, "fade": 0.2})
			fx.splat(0.6 if crit else 0.5, c.main, Color(c.dark.r, c.dark.g, c.dark.b, 0.85), {"at": dir * 0.6, "spread": 0.2, "hold": 0.4, "dry": 0.6})
		"amiya_guard":
			fx.splat(0.75 if crit else 0.6, c.main, Color(c.dark.r, c.dark.g, c.dark.b, 0.85), {"at": dir * 0.25, "spread": 0.2, "hold": 0.4, "dry": 0.6})
		"texas":
			# Fast cuts leave thin nicks across the target, not a pool.
			var nick := dir.cross(Vector3.UP).rotated(Vector3.UP, randf_range(-0.5, 0.5))
			for s in [1.0, -1.0]:
				fx.beam(nick * s, 0.6, P * 1.5, c.hot, _half(c, 0.6), {"start": 0.0, "sweep": 0.03, "hold": 0.04, "fade": 0.15, "additive": true})
		"rosa":
			fx.chips(Vector3.UP * 0.1, 10, 0.35, c.dust, 2.6)
			fx.dust(Vector3.UP * 0.2, c.dust, 4, 0.4)
		"santalla", "typhon":
			fx.splat(0.85, c.hot, Color(c.main.r, c.main.g, c.main.b, 0.3), {"spread": 0.25, "hold": 0.5, "dry": 0.6, "wobble": 0.02})
		"lin":
			fx.ring(r * 1.4, P * 2.5, c.main, edge, {"from_share": 1.0, "fade": 0.5, "additive": true})
			fx.ring(r * 0.8, P * 2.0, c.hot, edge, {"from_share": 1.0, "fade": 0.5, "additive": true, "delay": 0.05})
		"hoshiguma":
			fx.chips(Vector3.UP * 0.1, 8, 0.3, c.dust, 2.2)
	if kind == "arts": fx.embers(Vector3.UP * 0.2, c.main, c.hot, 6, 0.4, 0.0, 0.6)

## Her Space skill going off (aimed at `point`).
static func skill(player: Player, point: Vector3) -> void:
	if not _ok(player): return
	var game := player.game
	var id := player.operator_id
	var c := colours(id)
	var edge := _edge(c)
	var me := player.global_position
	var to := point - me
	to.y = 0.0
	var dir := to.normalized() if to.length_squared() > 0.001 else Vector3.FORWARD
	var fx := BossVfx.make(game, _foot(game, me))
	match id:
		"amiya_guard":
			fx.ring(1.8, P * 6.0, c.hot, Color(c.main.r, c.main.g, c.main.b, 0.5), {"fade": 0.4})
			fx.glow(2.6, c.main, 1.2, 0.45)
			fx.burst({"at": Vector3.UP * 0.1, "ring": [BossVfx.CLEAR, 1.6], "amount": 20, "time": 0.6, "speed": [1.0, 2.5], "dir": Vector3.UP, "spread": 40.0, "gravity": Vector3(0, 0.5, 0),
				"size": P * 1.0, "additive": true, "near_ok": true, "colours": [c.hot, c.main, Color(c.dark.r, c.dark.g, c.dark.b, 0.0)]})
		"hellagur":
			# 月相: a moon's ring opens round him, red light, petals of blood mist.
			fx.ring(2.4, P * 6.0, c.hot, Color(c.main.r, c.main.g, c.main.b, 0.5), {"fade": 0.5})
			fx.ring(1.6, P * 3.0, c.main, edge, {"delay": 0.08, "fade": 0.45, "additive": true})
			fx.arc(Vector3.FORWARD, 1.9, 300.0, P * 9.0, c.hot, Color(c.main.r, c.main.g, c.main.b, 0.4), {"sweep": 0.18, "hold": 0.15, "fade": 0.35, "mask": true})
			fx.glow(3.0, c.main, 1.2, 0.6)
			fx.splat(1.6, c.main, Color(c.dark.r, c.dark.g, c.dark.b, 0.6), {"spread": 0.3, "hold": 0.6, "dry": 0.8})
			fx.burst({"at": Vector3.UP * 0.2, "ring": [BossVfx.CLEAR, 2.0], "amount": 12, "time": 0.9, "speed": [0.3, 0.8], "dir": Vector3.UP, "spread": 50.0, "gravity": Vector3(0, 0.2, 0), "size": P * 12.0,
				"flip": "smoke_8x8", "near_ok": true, "colours": [Color(c.main.r, c.main.g, c.main.b, 0.7), Color(c.dark.r, c.dark.g, c.dark.b, 0.5), Color(c.dark.r, c.dark.g, c.dark.b, 0.0)]})
		"hoshiguma":
			# 力之锯: the shield bites the ground ahead, a wall of jade light.
			fx.arc(dir, 2.4, 100.0, P * 8.0, c.hot, edge, {"sweep": 0.1, "hold": 0.3, "fade": 0.4})
			fx.glow(2.4, c.main, 0.8, 0.5, 0.0, dir * 1.2)
			fx.chips(dir * 1.2 + Vector3.UP * 0.1, 18, 0.8, c.dust, 2.6)
			fx.dust(dir * 1.2 + Vector3.UP * 0.1, c.dust, 6, 0.8)
		"typhon", "santalla":
			var there := BossVfx.make(game, _foot(game, point))
			there.ring(2.2, P * 3.0, c.hot, edge, {"fade": 0.5})
			there.ring(1.4, P * 1.5, c.main, edge, {"from_share": 1.0, "fade": 0.6, "additive": true})
			there.glow(2.6, c.main, 0.8, 0.6)
			there.splat(2.0, c.hot, Color(c.main.r, c.main.g, c.main.b, 0.2), {"spread": 0.4, "hold": 1.0, "dry": 1.0, "wobble": 0.02})
			there.shaft(Vector3.ZERO, 0.6, 3.5, c.main, 1.0, 0.8)
			fx.glow(1.4, c.main, 0.6, 0.3)
		"rosa":
			# 雪崩击: harpoon streaks fanned toward the cursor.
			for i in range(5):
				var ray := dir.rotated(Vector3.UP, deg_to_rad(-30.0 + 15.0 * i))
				fx.beam(ray, 7.0, P * 2.5, c.hot, c.main, {"start": 0.6, "sweep": 0.12, "hold": 0.05, "fade": 0.3, "additive": true})
			fx.glow(1.6, c.main, 0.8, 0.3, 0.0, dir * 0.8)
			fx.sparks(dir * 1.0 + Vector3.UP * 0.5, c.main, c.hot, 16, 5.0, dir, 35.0)
		"lin":
			# 流光乍裂: a great array under her, light rising round it.
			fx.ring(2.6, P * 3.0, c.hot, edge, {"fade": 0.6})
			fx.ring(2.0, P * 1.5, c.main, edge, {"from_share": 1.0, "fade": 0.7, "additive": true})
			fx.ring(1.3, P * 1.5, c.main, edge, {"from_share": 1.0, "fade": 0.8, "additive": true, "delay": 0.1})
			fx.glow(3.0, c.main, 0.9, 0.7)
			fx.embers(Vector3.UP * 0.1, c.main, c.hot, 40, 2.4, 0.0, 1.2)
		"texas":
			# 剑雨: a red ring at the reach of the swords, light inside it.
			var r := 3.0
			var kit := player.kit
			if kit != null and kit.has_method("radius"): r = float(kit.radius())
			fx.ring(r, P * 4.0, c.hot, edge, {"from_share": 0.2, "fade": 0.45})
			fx.glow(r * 1.1, c.main, 0.7, 0.6)
			fx.sparks(Vector3.UP * 0.2, c.main, c.hot, 12, 4.0)
		_:
			fx.ring(1.6, P * 3.0, c.hot, edge, {"fade": 0.35})
			fx.glow(2.0, c.main, 0.7, 0.4)

## 绝影's last strike: a crimson cross burnt into the ground and a hard jolt.
static func finisher(player: Player, target: Enemy) -> void:
	if not _ok(player) or not is_instance_valid(target): return
	var game := player.game
	var c := colours(player.operator_id)
	var edge := _edge(c)
	var fx := BossVfx.make(game, _foot(game, target.global_position))
	for a in [45.0, -45.0]:
		var d := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(a))
		fx.beam(d, 1.8, P * 4.0, c.hot, c.main, {"start": -0.9, "sweep": 0.06, "hold": 0.2, "fade": 0.4})
	fx.ring(1.6, P * 4.0, c.hot, edge, {"fade": 0.4})
	fx.glow(2.4, c.main, 1.0, 0.5)
	fx.splat(1.0, c.main, Color(c.dark.r, c.dark.g, c.dark.b, 0.85), {"spread": 0.25, "hold": 0.8, "dry": 0.8})
