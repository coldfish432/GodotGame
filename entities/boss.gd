class_name Boss
extends Enemy

## A region boss (floors 20, 40 …) or a warden (floors 10, 30 …), Boss与守卫者策划案_v1_0.md.
## It is an Enemy for everything she does to it (hits, statuses, drops, the
## HUD) but runs its own fight: phases at life shares, a move list that grows
## with the tier, ground it leaves behind, and the fairness rules of §3.3
## (hit caps, short untouchable phase changes, no build-breaking debuffs).
## Every number is in BossCatalog.

## Ground warnings are drawn white-rimmed (cannot be interrupted).
const RIM := true
## How far apart what it calls in stands, from each other, it and her.
const SUMMON_APART := 2.5
## The wait between two moves, before swiftness and the enrage.
const GAP := {"boss": 0.7, "warden": 0.9}
## A ranged warden stops closing in at this distance.
const KEEP := {"skullshatterer": 6.0, "hollow_snowpriest": 7.0, "father_agnir": 7.0}
const WARDEN_SIGHT := 12.0
const WARDEN_LEASH := 22.0
const STRIKE_POSE := 0.12
const RECOVER_POSE := 0.3
const COMBO_WINDUP := 0.45
## Between moves it turns toward her this fast, so getting behind its shield is a real move.
const TURN_DEG := 120.0
const ZONE_TICK := 0.5
const ZONE_COLOURS := {"contamination": Color(0.95, 0.55, 0.2, 0.35), "sand": Color(0.86, 0.74, 0.5, 0.35), "cold": Color(0.75, 0.9, 1.0, 0.35),
	"smoke": Color(0.5, 0.5, 0.55, 0.45), "blood": Color(0.55, 0.1, 0.13, 0.35), "safe": Color(0.55, 0.95, 0.85, 0.45)}

var figure_id := ""
var rank := "boss"
var tier := 1
var fig: Dictionary = {}
var phase := 1
var life := 1
var lives := 1
var engaged := false
var affixes: Array = []
## The warden's two guards (blessed, absolved).
var guards: Array[Enemy] = []
var fight_time := 0.0
var invuln := 0.0
var _out_time := 0.0
var _marks: Array = []
var _summon_marks: Array = []
var _rampage_marks: Array = []
var _rebarrier := false
var _revived := false
var _rampaging := false
var _cooldowns := {}
var _gap := 0.0
## The move under way: its segments (a combo is several), which one, and what
## its start worked out (targets, markers).
var _move: Dictionary = {}
var _segments: Array = []
var _seg := 0
var _windup := 0.0
var _ctx: Dictionary = {}
var _markers: Array[Node] = []
var _pose_left := 0.0
## Kneeling / lying down (爱国者, 扎罗) or roaring at a phase change.
var down_left := 0.0
var roar_left := 0.0
var _after_down := ""
var _later: Array = []
var zones: Array = []
var summoned: Array[Enemy] = []
var _channel: Dictionary = {}
## 扎罗's 溶血骇惧 on her: time on it, and what she has taken off him since.
var curse: Dictionary = {}
var reckoning_left := 0.0
var _shred := 0
var _close_time := 0.0
var _family_time := 0.0
var _aura_time := 0.0
var _quake_time := 0.0
var _storm_time := 0.0
var storm_steps := 0
var _storm_tick := 0.0
var _blood_time := 0.0
var _hidden := false

func setup_boss(p_game: GameManager, id: String, p_tier: int) -> void:
	figure_id = id
	fig = BossCatalog.figure(id)
	rank = str(fig.rank)
	tier = maxi(1, p_tier)
	# Borrow an existing board until Sol's art lands, as every new enemy has.
	setup(p_game, true, false, str(fig.art))
	enemy_type = id
	name = str(fig.name)
	elite = true
	boss = true
	ranged = false
	keeps_distance = false
	attack_profile = {"name": fig.name, "attack": "", "shape": "none", "reach": 3.0, "windup": 1.0, "interval": 1.0, "recovery": RECOVER_POSE, "elite": true, "damage": 1.0}
	max_health = float(fig.hp) * BossCatalog.hp_mult(rank, tier)
	health = max_health
	atk = float(fig.atk) * BossCatalog.atk_mult(rank, tier)
	defense = float(fig.def)
	res = float(fig.res)
	damage_kind = str(fig.kind)
	move_speed = float(fig.get("speed", 1.2))
	lives = int(fig.get("lives", 1))
	affixes = BossCatalog.roll_affixes(rank, tier, str(fig.region), game.floor_number)
	if affixes.has("swift"): move_speed *= 1.0 + BossCatalog.SWIFT_SPEED
	perception_radius = WARDEN_SIGHT
	leash_radius = WARDEN_LEASH
	if FieldArt.has_directional(id):
		# Its own boards (Sol B1): baked at its own height, no tint, no scale.
		sheet_type = id
		art_type = id
		directional = true
		has_walk = FieldArt.has_walk(id)
		_tint = Color.WHITE
		if is_instance_valid(_sprite):
			_sprite.texture = FieldArt.enemy_dir_pose(id, dir_column, 0)
			_sprite.pixel_size = PIXEL
			_sprite.modulate = _tint
	else:
		_tint = fig.get("tint", Color.WHITE)
		if is_instance_valid(_sprite):
			_sprite.modulate = _tint
			_sprite.pixel_size *= float(fig.get("scale", 1.0))
		if is_instance_valid(_outline): _outline.scale = Vector3.ONE * float(fig.get("scale", 1.0))
	_reset_fight()
	add_to_group("bosses")

## Called by GameManager once the depth and relic multipliers are on max_health.
func finish_setup() -> void:
	health = max_health
	_raise_start_barrier()

func _reset_fight() -> void:
	phase = 1
	life = 1
	fight_time = 0.0
	# 扎罗's first life has no marks: its end is the phase change.
	_marks = BossCatalog.phase_marks(tier) if lives == 1 else []
	_summon_marks = BossCatalog.SUMMON_AT.duplicate() if _has_move("summon") or affixes.has("rally") else []
	_rampage_marks = (BossCatalog.RAMPAGE_AT.get(mini(tier, 3), []) as Array).duplicate() if figure_id == "eikthyrnir" else []
	_rebarrier = tier >= BossCatalog.SAND_REBARRIER_TIER and figure_id == "rat_king" or affixes.has("bulwark")
	_revived = false
	_cooldowns = {}
	_gap = 1.0
	_shred = 0
	storm_steps = 0
	_storm_time = 0.0
	_blood_time = 0.0
	_family_time = 8.0
	_quake_time = BossCatalog.QUAKE_EVERY
	reckoning_left = 0.0
	curse = {}
	_channel = {}

func _raise_start_barrier() -> void:
	var share := float(fig.get("barrier", 0.0))
	if affixes.has("bulwark"): share = maxf(share, BossCatalog.BULWARK)
	if share > 0.0: _raise_barrier(share, fig.get("barrier_color", Color("9fc8ff")))

## A shell of `share` of its life (EnemyAttacks' barrier: 法抗 +50 while it holds).
func _raise_barrier(share: float, colour: Color = Color("cfe8ff")) -> void:
	attack_profile["barrier"] = share
	barrier_hp = max_health * share
	_barrier_broken = false
	if _shell == null:
		_shell = BarrierFx.new()
		_shell.size = 1.2 * float(fig.get("scale", 1.0))
		add_child(_shell)
	_shell.colour = colour

## Its outline while it winds up a move it will not break off (用户 2026-10-19:
## 改为红色或者暗红色描边): dark red, brighter red as the soft enrage climbs.
const OUTLINE_DARK := Color("8a1c22")
const OUTLINE_BRIGHT := Color("e8463a")

func outline_colour() -> Color:
	return OUTLINE_DARK.lerp(OUTLINE_BRIGHT, enrage() / BossCatalog.ENRAGE_CAP)

func _sync_outline() -> void:
	super._sync_outline()
	if is_instance_valid(_outline) and _outline.visible:
		(_outline.material_override as ShaderMaterial).set_shader_parameter("colour", outline_colour())

## Its own board's row for what it is doing now, or -1 for the shared five.
func pose_row() -> int:
	var poses: Dictionary = BossCatalog.POSES.get(figure_id, {})
	if poses.is_empty(): return -1
	if down_left > 0.0: return int(poses.get("down", -1))
	if roar_left > 0.0: return int(poses.get("roar", poses.get("down", -1)))
	var moves: Dictionary = poses.get("moves", {})
	if not _channel.is_empty(): return int(moves.get(str(_channel.move.id), -1))
	if not _move.is_empty():
		if _rampaging: return int(moves.get("rampage", -1))
		return int(moves.get(str(_move.id), -1))
	return -1

func _update_attack_visual() -> void:
	super._update_attack_visual()
	if not own_art() or not is_instance_valid(_sprite): return
	_own_pose()
	# The outline was traced from the shared row's frame; trace the one shown.
	_sync_outline()

func _own_pose() -> void:
	var poses: Dictionary = BossCatalog.POSES.get(figure_id, {})
	var row := pose_row()
	if row >= 0:
		_sprite.texture = FieldArt.enemy_dir_pose(sheet_type, dir_column, row)
		return
	if attack_phase != "idle": return
	var frame := posmod(int(walk_distance * WALK_FRAMES_PER_UNIT), 4)
	# 爱国者's 毁灭姿态 walks and stands on the second half of his walk board.
	if poses.has("walk2") and phase >= 2:
		_sprite.texture = FieldArt.enemy_walk_pose(sheet_type, dir_column, int(poses.walk2) + (frame if walking else 0))
	# 扎罗 lies in his IDLE; up on his second life he stands on a walk frame.
	elif poses.has("stand") and phase >= 2 and not walking:
		_sprite.texture = FieldArt.enemy_walk_pose(sheet_type, dir_column, int(poses.stand))

func _has_move(shape: String) -> bool:
	for move in BossCatalog.moves_for(figure_id, tier, 3):
		if str(move.shape) == shape: return true
	return false

# --- Queries -----------------------------------------------------------------------

## A region boss she is fighting: the threat meter stands still meanwhile (Q5).
func in_fight() -> bool:
	return rank == "boss" and engaged and not _dead

func centre() -> Vector3:
	if rank == "boss" and is_instance_valid(game) and is_instance_valid(game.arena): return game.arena.centre
	return home_position

## 源石祭坛's pulse on it (7-18): a stack of attack for a while.
var shrine_stacks := 0
var _shrine_left := 0.0
func empower() -> void:
	shrine_stacks = mini(BossCatalog.SHRINE_STACKS, shrine_stacks + 1)
	_shrine_left = BossCatalog.SHRINE_TIME

func her() -> Player:
	return game.player

func taken_mult() -> float:
	var taken: Array = fig.get("taken", [1.0, 1.0, 1.0])
	var mult := float(taken[clampi(phase - 1, 0, taken.size() - 1)])
	if _rampaging: mult *= BossCatalog.RAMPAGE_TAKEN
	for zone in zones:
		if str(zone.colour) == "smoke" and _inside(zone, global_position): mult *= float(zone.taken)
	return mult

## What its shield takes off a hit now: only from in front (120°), by phase.
func shield_share() -> float:
	var guard: Array = fig.get("front_guard", [])
	if guard.is_empty() or not is_instance_valid(game) or not is_instance_valid(game.player): return 0.0
	var share := float(guard[clampi(phase - 1, 0, guard.size() - 1)])
	if share <= 0.0 or not _facing_point(game.player.global_position): return 0.0
	return share

func dealt_mult() -> float:
	var dealt: Array = fig.get("dealt", [1.0, 1.0, 1.0])
	return float(dealt[clampi(phase - 1, 0, dealt.size() - 1)])

## Attack speed from swiftness, the warden's last stand, 清算时刻 and the enrage.
func speed_mult() -> float:
	var mult := 1.0
	if affixes.has("swift"): mult /= 1.0 - BossCatalog.SWIFT_INTERVAL
	if rank == "warden" and health < max_health * BossCatalog.LAST_STAND_AT: mult *= 1.0 + BossCatalog.LAST_STAND_ASPD
	if reckoning_left > 0.0: mult *= 1.0 + BossCatalog.RECKONING_ASPD
	return mult * (1.0 + enrage())

## The soft enrage (§3.5): nothing before ENRAGE_AFTER, then a step every ENRAGE_EVERY.
func enrage() -> float:
	if rank != "boss" or fight_time < BossCatalog.ENRAGE_AFTER: return 0.0
	return minf(BossCatalog.ENRAGE_CAP, BossCatalog.ENRAGE_STEP * (1 + floori((fight_time - BossCatalog.ENRAGE_AFTER) / BossCatalog.ENRAGE_EVERY)))

## The share of the curse bar left (0 when there is no curse).
func curse_left() -> float:
	if curse.is_empty(): return 0.0
	return clampf(1.0 - float(curse.dealt) / maxf(1.0, float(curse.need)), 0.0, 1.0)

func phase_count() -> int:
	return 1 + BossCatalog.phase_marks(tier).size() if lives == 1 else (3 if tier >= 3 else 2)

# --- Taking hits ---------------------------------------------------------------------

func take_hit(damage: float, kind: String = "phys", crit: bool = false, pierce: float = 0.0, quiet: bool = false) -> float:
	if _dead or invuln > 0.0 or down_left > 0.0 or roar_left > 0.0: return 0.0
	if not engaged: _engage()
	if not _channel.is_empty():
		_channel.hits = int(_channel.hits) + 1
		if int(_channel.hits) >= int(_channel.breaks): _end_channel(false)
	damage *= 1.0 - shield_share()
	var dealt := CombatStats.mitigate(damage * taken_mult(), kind, effective_defense() * (1.0 - clampf(pierce, 0.0, 1.0)), res_against(kind))
	dealt *= 1.0 + status_value("fragile")
	_on_elemental(kind, dealt)
	if not curse.is_empty():
		curse.dealt = float(curse.dealt) + dealt
		if float(curse.dealt) >= float(curse.need): _lift_curse()
	var before := health
	health -= dealt
	if barrier_hp > 0.0:
		barrier_hp -= dealt
		if barrier_hp <= 0.0: _break_barrier()
	_flash()
	if is_instance_valid(game) and not quiet:
		DamageNumber.spawn(game, global_position + Vector3.UP * 0.8, str(roundi(dealt)) + ("!" if crit else ""), "crit" if crit else kind, crit)
	if health <= 0.0:
		if life < lives:
			health = 1.0
			_go_down("next_life")
		elif tier >= BossCatalog.REVIVE_TIER and figure_id == "patriot" and not _revived:
			_revived = true
			health = 1.0
			_go_down("revive")
		else:
			_die()
		return dealt
	_crossed(before / max_health, health / max_health)
	return dealt

## Life shares passed on this hit: summons, 自我泯灭, a phase change.
func _crossed(was: float, now: float) -> void:
	for share in _summon_marks.duplicate():
		if was > share and now <= share:
			_summon_marks.erase(share)
			_call_help()
	for share in _rampage_marks.duplicate():
		if was > share and now <= share:
			_rampage_marks.erase(share)
			_later.append({"t": 0.0, "f": "rampage"})
	for share in _marks.duplicate():
		if was > share and now <= share:
			_marks.erase(share)
			_next_phase()
			break
	if _rebarrier and was > 0.5 and now <= 0.5:
		_rebarrier = false
		_raise_barrier(maxf(float(fig.get("barrier", 0.0)), BossCatalog.BULWARK), fig.get("barrier_color", Color("cfe8ff")))

func _die() -> void:
	_dead = true
	_cancel_move()
	_clear_ground()
	if affixes.has("last_rite") and is_instance_valid(game):
		game.spawn_hazard(global_position, BossCatalog.LAST_RITE_RADIUS, BossCatalog.LAST_RITE_FUSE, 0.0, _raw(1.5), "phys", false, null)
	# Its help leaves with it (§3.4: 援军一起撤退).
	for e in summoned:
		if is_instance_valid(e) and not e._dead: e.queue_free()
	if is_instance_valid(game) and is_instance_valid(game.player):
		game.player.clear_hex("boss_shred")
	remove_from_group("enemies")
	remove_from_group("guards")
	if is_instance_valid(game): game.spawn_enemy_drops(self)
	died.emit(self)
	queue_free()

func stun(seconds: float) -> void:
	if affixes.has("steadfast") or down_left > 0.0 or roar_left > 0.0: return
	if not _move.is_empty(): return
	super.stun(seconds)

func push(direction: Vector3, distance: float) -> void:
	if figure_id == "zaro" and phase == 1: return
	super.push(direction, distance * 0.5)

func _exit_tree() -> void:
	_clear_ground()
	if is_instance_valid(game) and is_instance_valid(game.player):
		for id in ["boss_shred", "boss_awe", "boss_curse", "boss_zone", "boss_grenade"]: game.player.clear_hex(id)

# --- The fight's frame ---------------------------------------------------------------

func _engage() -> void:
	if engaged: return
	engaged = true
	state = State.CHASING
	if rank == "boss" and is_instance_valid(game): game.on_boss_engaged(self)

func _physics_process(delta: float) -> void:
	if _dead or not is_instance_valid(game) or not game.simulation_active(): return
	if not is_instance_valid(game.player): return
	if hitstop_remaining > 0:
		hitstop_remaining = maxf(0, hitstop_remaining - delta)
		return
	silence_timer = maxf(0.0, silence_timer - delta)
	_advance_animation(delta)
	_tick_statuses(delta)
	if _dead: return
	_sync_shell()
	_tick_ground(delta)
	if not engaged:
		var near := _flat_distance(game.player.global_position, centre()) <= BossCatalog.ARENA_RADIUS if rank == "boss" else _flat_distance(game.player.global_position, global_position) <= WARDEN_SIGHT
		if near and game.line_of_sight(global_position, game.player.global_position): _engage()
		return
	if _leash(delta): return
	fight_time += delta
	if _shrine_left > 0.0:
		_shrine_left -= delta
		if _shrine_left <= 0.0: shrine_stacks = 0
	_tick_auras(delta)
	_tick_curse(delta)
	_tick_field(delta)
	_tick_later(delta)
	if _dead: return
	if down_left > 0.0:
		down_left -= delta
		if down_left <= 0.0: _get_up()
		return
	if roar_left > 0.0:
		roar_left -= delta
		if roar_left <= 0.0: _end_roar()
		return
	invuln = maxf(0.0, invuln - delta)
	if not _channel.is_empty():
		_tick_channel(delta)
		return
	if not _move.is_empty():
		_tick_move(delta)
		return
	if _pose_left > 0.0:
		_pose_left -= delta
		if _pose_left <= 0.0:
			attack_phase = "recovery" if attack_phase == "strike" else "idle"
			_pose_left = RECOVER_POSE if attack_phase == "recovery" else 0.0
			_attack_elapsed = 0.0
		return
	if stun_timer > 0.0:
		stun_timer = maxf(0.0, stun_timer - delta)
		return
	for id in _cooldowns.keys(): _cooldowns[id] = maxf(0.0, float(_cooldowns[id]) - delta)
	_gap = maxf(0.0, _gap - delta * speed_mult())
	var distance := _flat_distance(global_position, game.player.global_position)
	var seen := game.line_of_sight(global_position, game.player.global_position)
	if _gap <= 0.0 and seen:
		var move := _choose(distance)
		if not move.is_empty():
			_start(move)
			return
	_close_in(delta, distance, seen)

## She has left: a boss waits at home and, after LEASH_SECONDS, is whole again (Q4);
## a warden past its leash simply walks home.
func _leash(delta: float) -> bool:
	if rank == "warden":
		if _flat_distance(game.player.global_position, home_position) > WARDEN_LEASH:
			engaged = false
			_cancel_move()
			begin_return()
			_move_toward_target(home_position, delta)
			return true
		return false
	if _flat_distance(game.player.global_position, centre()) <= BossCatalog.ARENA_RADIUS + 1.0:
		_out_time = 0.0
		return false
	_out_time += delta
	if _move.is_empty() and down_left <= 0.0 and roar_left <= 0.0:
		if _flat_distance(global_position, home_position) > 0.5: _move_toward_target(home_position, delta)
	if _out_time >= BossCatalog.LEASH_SECONDS: reset_whole()
	return true

## Back to its start: whole, first phase, its ground and help gone.
func reset_whole() -> void:
	_cancel_move()
	_clear_ground()
	for e in summoned:
		if is_instance_valid(e) and not e._dead: e.queue_free()
	summoned.clear()
	engaged = false
	_out_time = 0.0
	down_left = 0.0
	roar_left = 0.0
	invuln = 0.0
	_rampaging = false
	health = max_health
	shrine_stacks = 0
	_reset_fight()
	_raise_start_barrier()
	global_position = Vector3(home_position.x, global_position.y, home_position.z)
	if is_instance_valid(game) and is_instance_valid(game.arena): game.arena.reset()
	if is_instance_valid(game): game.on_boss_reset(self)

func _close_in(delta: float, distance: float, seen: bool) -> void:
	_turn_toward_her(delta)
	if figure_id == "zaro" and phase == 1:
		_face_her(delta)
		return
	var keep := float(KEEP.get(figure_id, 1.6))
	# Skullshatterer hops back when she has stayed close.
	if figure_id == "skullshatterer":
		_close_time = _close_time + delta if distance < 2.2 else 0.0
		if _close_time >= 3.0 and float(_cooldowns.get("hop", 0.0)) <= 0.0:
			_close_time = 0.0
			_cooldowns["hop"] = 6.0
			var away := global_position - game.player.global_position
			away.y = 0.0
			_charge_to(global_position + away.normalized() * 3.0)
			return
	if distance > keep or not seen:
		var target := game.player.global_position
		if rank == "boss":
			var off := target - centre()
			off.y = 0.0
			if off.length() > BossCatalog.ARENA_RADIUS - 1.0: target = centre() + off.normalized() * (BossCatalog.ARENA_RADIUS - 1.0)
		_move_toward_target(target, delta)
	else:
		_face_her(delta)

## Its facing (what the shield covers) swings toward her at TURN_DEG a second.
func _turn_toward_her(delta: float) -> void:
	var to := game.player.global_position - global_position
	to.y = 0.0
	if to.length_squared() < 0.0001: return
	var turn := attack_direction.signed_angle_to(to.normalized(), Vector3.UP)
	var limit := deg_to_rad(TURN_DEG) * delta
	attack_direction = attack_direction.rotated(Vector3.UP, clampf(turn, -limit, limit)).normalized()

func _face_her(delta: float) -> void:
	var to := game.player.global_position - global_position
	to.y = 0.0
	if to.length_squared() > 0.0001: _face(to.normalized(), delta)

func current_speed() -> float:
	return move_speed * (1.15 if figure_id == "patriot" and phase >= 2 else 1.0) * (1.3 if status_value("haste") > 0.0 else 1.0)

# --- Choosing and running a move -----------------------------------------------------

## The first big move that is ready, else a ready one in range (one with a
## cooldown before the ones without, so the special moves come round).
func _choose(distance: float) -> Dictionary:
	var ready := []
	for move in BossCatalog.moves_for(figure_id, tier, phase):
		if str(move.shape) in ["summon", "family", "sandstorm", "backstep"]: continue
		if move.get("once", false) and _cooldowns.has(str(move.id)): continue
		if float(_cooldowns.get(str(move.id), 0.0)) > 0.0: continue
		var span: Array = move.get("range", [0.0, 99.0])
		if distance < float(span[0]) or distance > float(span[1]): continue
		# 爱国者 sets off a 源石祭坛 she stands by, on a chance; raises more while under the cap.
		if str(move.shape) == "shrine_call":
			if is_instance_valid(game.arena) and game.arena.shrine_over(game.player.global_position) != null and game.rng.randf() < float(move.chance): return move
			continue
		if str(move.shape) == "raise_shrine" and (not is_instance_valid(game.arena) or game.arena.region != "mine" or game.arena.raised.size() >= BossCatalog.SHRINE_RAISED_MAX): continue
		if bool(move.get("big", false)): return move
		ready.append(move)
	if ready.is_empty(): return {}
	var special := ready.filter(func(m): return float(m.get("cd", 0.0)) > 0.0)
	var pool: Array = special if not special.is_empty() and game.rng.randf() < 0.6 else ready
	return pool[game.rng.randi() % pool.size()]

func _start(move: Dictionary) -> void:
	_move = move
	if move.has("combo"):
		_segments = []
		for seg in move.combo:
			var s: Dictionary = move.duplicate()
			s.erase("combo")
			s.merge(seg, true)
			_segments.append(s)
	elif move.has("follow"):
		var first: Dictionary = move.duplicate()
		first.erase("follow")
		var second: Dictionary = move.duplicate()
		second.erase("follow")
		second.merge(move.follow, true)
		_segments = [first, second]
	elif str(move.shape) == "dashes":
		_segments = []
		for i in range(int(move.count)):
			var dash: Dictionary = move.duplicate()
			dash.shape = "charge"
			dash.windup = float(move.mark) if i == 0 else float(move.windup)
			dash.big = false
			_segments.append(dash)
	elif str(move.shape) == "blink":
		_segments = []
		for i in range(1 + int(move.get("repeat", 0))): _segments.append(move)
	else:
		_segments = [move]
	_seg = 0
	_begin_segment(false)

func _begin_segment(chained: bool) -> void:
	var seg: Dictionary = _segments[_seg]
	_ctx = {}
	_clear_markers()
	var w := float(seg.get("windup", 1.0))
	if chained and str(seg.shape) != "charge": w = COMBO_WINDUP
	_windup = w * BossCatalog.windup_mult(rank, tier)
	attack_phase = "windup"
	preparing_attack = true
	_attack_elapsed = 0.0
	attack_origin = global_position
	_lock_toward(_aim_point(seg))
	_lay_warning(seg)
	_update_attack_visual()

## Where a blow goes: at her, or — a 叙拉古平民 within its reach, on a chance —
## at the 平民 (用户 2026-10-20). Only swings, thrusts and pounces turn aside.
func _aim_point(seg: Dictionary) -> Vector3:
	var her_at := game.player.global_position
	if not str(seg.shape) in ["sector", "lane", "charge"]: return her_at
	var reach := float(seg.get("reach", 2.0)) + 0.3
	for c in get_tree().get_nodes_in_group("civilians"):
		if not is_instance_valid(c) or c._dead or c.fleeing or _flat_distance(c.global_position, global_position) > reach: continue
		if game.rng.randf() < BossCatalog.CIVILIAN_TARGET_CHANCE: return c.global_position
		break
	return her_at

## The 平民 a blow of its lands on: 血债 for each, and it cringes and runs.
func _strike_civilians_by(seg: Dictionary) -> void:
	for c in get_tree().get_nodes_in_group("civilians"):
		if not is_instance_valid(c) or c._dead: continue
		var at: Vector3 = c.global_position
		var struck := false
		match str(seg.shape):
			"sector": struck = EnemyAttacks.contains({"shape": "sector", "reach": seg.reach, "angle": seg.angle}, attack_origin, attack_direction, at)
			"lane": struck = _in_lane(at, attack_origin, _ctx.get("end", attack_origin), float(seg.width))
			"charge": struck = _in_lane(at, attack_origin, global_position, float(seg.width))
			"self": struck = _flat_distance(at, global_position) <= float(seg.radius)
		if struck: c.struck()

func _lock_toward(point: Vector3) -> void:
	attack_direction = point - global_position
	attack_direction.y = 0.0
	attack_direction = attack_direction.normalized() if attack_direction.length_squared() > 0.001 else Vector3.RIGHT
	_face(attack_direction, 1.0)

func _tick_move(delta: float) -> void:
	_attack_elapsed += delta
	var seg: Dictionary = _segments[_seg]
	# A crosshair follows her until it locks (投戟, 终傅); 投戟's red strip with it.
	if _ctx.has("crosshair") and is_instance_valid(_ctx.crosshair) and _attack_elapsed < _windup - float(seg.get("lock", 0.4)):
		var her_at := game.player.global_position
		(_ctx.crosshair as Node3D).global_position = Vector3(her_at.x, game.ground_y(her_at) + 0.05, her_at.z)
		_ctx.target = her_at
		if _ctx.has("path"): _aim_path(_ctx.path, her_at, seg)
	if _attack_elapsed < _windup: return
	_clear_markers()
	_resolve(seg)
	if _dead or _move.is_empty(): return
	_seg += 1
	if _seg < _segments.size():
		_begin_segment(true)
		return
	_finish_move()

func _finish_move() -> void:
	_cooldowns[str(_move.id)] = float(_move.get("cd", 0.0))
	_move = {}
	_segments = []
	_rampaging = false
	_set_hidden(false)
	preparing_attack = false
	attack_phase = "strike"
	_pose_left = STRIKE_POSE
	_gap = float(GAP[rank])

func _cancel_move() -> void:
	_clear_markers()
	_move = {}
	_segments = []
	_ctx = {}
	_rampaging = false
	_set_hidden(false)
	preparing_attack = false
	attack_phase = "idle"
	_pose_left = 0.0

func _clear_markers() -> void:
	for marker in _markers:
		if is_instance_valid(marker): marker.queue_free()
	_markers.clear()

func _mark_area(at: Vector3, radius: float, life_time: float) -> void:
	var marker := game.spawn_warning_area(at, radius, life_time, RIM)
	marker.hitstop_owner = self
	_markers.append(marker)

func _mark_lane(from: Vector3, to: Vector3, width: float, life_time: float) -> void:
	var marker := game.spawn_warning_lane(from, to, life_time, width, from.distance_to(to), RIM)
	if marker == null: return
	marker.hitstop_owner = self
	_markers.append(marker)

## The red ground each move lays at the start of its windup.
func _lay_warning(seg: Dictionary) -> void:
	var her_at := game.player.global_position
	var me := global_position
	match str(seg.shape):
		"self":
			_mark_area(me, float(seg.radius), _windup)
		"front_circle":
			_ctx.at = me + attack_direction * float(seg.offset)
			_mark_area(_ctx.at, float(seg.radius), _windup)
		"lane", "charge":
			var end := me + attack_direction * float(seg.reach)
			_ctx.end = end
			_mark_lane(me, end, float(seg.width), _windup)
		"ground", "curse":
			_ctx.at = her_at
			if seg.has("triple"):
				var spots := []
				for i in range(3):
					var angle := TAU * i / 3.0 + game.rng.randf() * 0.5
					spots.append(her_at + Vector3(cos(angle), 0.0, sin(angle)) * float(seg.triple))
				_ctx.spots = spots
				for spot in spots: _mark_area(spot, float(seg.radius), _windup)
			else:
				_mark_area(her_at, float(seg.radius), _windup)
		"hurl":
			_ctx.at = her_at
			_mark_area(her_at, float(seg.radius), _windup)
		"lob_line":
			var spots := []
			for i in range(int(seg.count)):
				spots.append(me.lerp(her_at, float(i + 1) / float(seg.count)))
			_ctx.spots = spots
			for i in range(spots.size()): _mark_area(spots[i], float(seg.radius), _windup + float(seg.gap) * i)
		"mines":
			var spots := [her_at]
			for i in range(int(seg.count) - 1): spots.append(_arena_point(3.0))
			_ctx.spots = spots
			for spot in spots: _mark_area(spot, float(seg.radius), _windup)
		"cross":
			_ctx.at = me
			_ctx.lanes = _cross_lanes(me, attack_direction, float(seg.arm))
			# 唱沙: the red arrow over its head first (the windup itself), then the cross.
			for lane in _ctx.lanes: _mark_lane(lane[0], lane[1], float(seg.width), _windup)
		"safe_zones":
			var spots := []
			for i in range(int(seg.count)): spots.append(_arena_point(BossCatalog.SAFE_RADIUS + 1.0, spots, 4.5))
			_ctx.spots = spots
			_mark_area(centre(), BossCatalog.ARENA_RADIUS + 1.0, _windup)
			for spot in spots: _markers.append(_disc(spot, BossCatalog.SAFE_RADIUS, ZONE_COLOURS.safe, 30))
		"lanes":
			_ctx.lanes = _lane_set(seg)
			for lane in _ctx.lanes: _mark_lane(lane[0], lane[1], float(seg.width), _windup)
		"blink":
			var away := her_at - me
			away.y = 0.0
			var behind := her_at + (away.normalized() if away.length_squared() > 0.01 else Vector3.BACK) * float(seg.gap)
			_ctx.at = game.world_map.nearest_walkable(behind)
			_mark_area(_ctx.at, float(seg.radius), _windup)
			_set_hidden(true)
		"javelin", "sniper":
			_ctx.target = her_at
			var crosshair := game.spawn_warning_area(her_at, 0.6, _windup, RIM)
			crosshair.hitstop_owner = self
			_ctx.crosshair = crosshair
			_markers.append(crosshair)
			# 投戟: the spear's whole flight in red, turning with her until it locks (用户 2026-10-20).
			if str(seg.shape) == "javelin":
				var path := game.spawn_warning_lane(me, me + attack_direction * float(seg.reach), _windup, float(seg.width), float(seg.reach), RIM)
				if path != null:
					path.hitstop_owner = self
					_ctx.path = path
					_markers.append(path)
		"raise_shrine":
			var taken := []
			if is_instance_valid(game.arena):
				for node in game.arena.shrines(): taken.append(node.global_position)
			var spots := []
			for i in range(int(seg.count)):
				var spot := _arena_point(2.0, taken, BossCatalog.SHRINE_APART)
				spots.append(spot)
				taken.append(spot)
			_ctx.spots = spots
			for spot in spots: _mark_area(spot, 1.2, _windup)
		"shrine_call":
			# The shrine's own reach in red, then it pulses.
			_ctx.node = game.arena.shrine_over(her_at) if is_instance_valid(game.arena) else null
			if _ctx.node != null: _mark_area((_ctx.node as Node3D).global_position, BossCatalog.SHRINE_RADIUS, _windup)
		"channel":
			pass

## 投戟's strip, re-aimed from its feet toward `at`.
func _aim_path(path: Node3D, at: Vector3, seg: Dictionary) -> void:
	if not is_instance_valid(path): return
	var dir := at - global_position
	dir.y = 0.0
	if dir.length_squared() < 0.01: return
	dir = dir.normalized()
	var mid := global_position + dir * float(seg.reach) * 0.5
	path.global_position = Vector3(mid.x, game.ground_y(mid) + 0.05, mid.z)
	path.basis = Basis.looking_at(dir)

## Two strips through `at` (a cross); 唱沙 at tier 2 lands an × 0.8 s after.
func _cross_lanes(at: Vector3, direction: Vector3, arm: float) -> Array:
	var side := direction.cross(Vector3.UP).normalized()
	return [[at - direction * arm, at + direction * arm], [at - side * arm, at + side * arm]]

## The strips of 鼠潮 (parallel across the arena), 萨米之熵 (out from its feet)
## or 群狼 (in from the edge).
func _lane_set(seg: Dictionary) -> Array:
	var out := []
	var c := centre()
	var r := BossCatalog.ARENA_RADIUS
	var spin := game.rng.randf() * TAU
	# 鼠潮 runs out of the market's alley mouths (Boss战场地策划案 §4.2).
	if str(seg.mode) == "parallel" and figure_id == "rat_king" and is_instance_valid(game.arena):
		var mouths := game.arena.mouths()
		for i in range(mini(int(seg.count), mouths.size())):
			var from: Vector3 = mouths.pop_at(game.rng.randi() % mouths.size())
			var through := c + Vector3(game.rng.randf_range(-2.5, 2.5), 0.0, game.rng.randf_range(-2.5, 2.5))
			out.append([from, from + (through - from).normalized() * r * 2.0])
		return out
	match str(seg.mode):
		"parallel":
			var along := Vector3(cos(spin), 0.0, sin(spin))
			var side := along.cross(Vector3.UP)
			var spacing := float(seg.width) * 2.0
			for i in range(int(seg.count)):
				var off := (i - (int(seg.count) - 1) * 0.5) * spacing
				out.append([c + side * off - along * r, c + side * off + along * r])
		"radial":
			for i in range(int(seg.count)):
				var a := spin + TAU * i / float(seg.count)
				out.append([global_position, global_position + Vector3(cos(a), 0.0, sin(a)) * r])
		"edge":
			for i in range(int(seg.count)):
				var a := spin + TAU * i / float(seg.count)
				var from := c + Vector3(cos(a), 0.0, sin(a)) * r
				var through := c + Vector3(cos(a + PI * 0.5), 0.0, sin(a + PI * 0.5)) * game.rng.randf_range(0.0, 3.0)
				out.append([from, from + (through - from).normalized() * r * 2.0])
	return out

## A walkable spot in the arena, `edge` in from its rim and `apart` from `others`.
func _arena_point(edge: float, others: Array = [], apart: float = 0.0) -> Vector3:
	var best := centre()
	for attempt in range(24):
		var a := game.rng.randf() * TAU
		var d := game.rng.randf_range(1.0, BossCatalog.ARENA_RADIUS - edge)
		var spot := game.world_map.nearest_walkable(centre() + Vector3(cos(a), 0.0, sin(a)) * d)
		if others.all(func(o): return _flat_distance(o, spot) >= apart):
			return spot
		best = spot
	return best

func _set_hidden(hide: bool) -> void:
	_hidden = hide
	if is_instance_valid(_sprite): _sprite.visible = not hide

# --- Landing ---------------------------------------------------------------------------

## What one hit is worth before her defences: ATK × the move, the phase's
## damage, the floor's pressure and the relic multiplier.
func _raw(mult: float) -> float:
	return atk * mult * dealt_mult() * (1.0 + BossCatalog.SHRINE_ATK * shrine_stacks) * (1.0 + game.pressure / EnemyAttacks.PRESSURE_DIVISOR) * game.enemy_attack_multiplier()

## Hits her once with `seg`'s damage (capped, §3.3) and its after-effects.
func _hit_her(seg: Dictionary, mult: float = -1.0) -> void:
	var p := game.player
	var cap := p.max_hp * (BossCatalog.BIG_CAP if bool(seg.get("big", false)) else BossCatalog.HIT_CAP)
	var raw := minf(_raw(float(seg.get("damage", 1.0)) if mult < 0.0 else mult), cap)
	var before := p.hp
	p.take_damage(raw, str(seg.get("kind", damage_kind)), self)
	_after_hit(seg, p.hp < before)

func _after_hit(seg: Dictionary, landed: bool) -> void:
	if not landed: return
	var p := game.player
	if seg.has("cold"):
		# 冻结: a cold hit while she is already frozen stiff.
		if game.features.tier("cold") >= 2: p.apply_control("stun", attack_direction, 0.0, BossCatalog.FREEZE)
		game.features.add("cold", float(seg.cold) * game.features.growth_mult("cold", game.floor_number))
	if seg.has("hex"):
		var hex: Dictionary = seg.hex
		p.add_hex("boss_" + str(seg.id), hex, float(hex.get("time", 5.0)))
	if seg.has("shred"):
		_shred = mini(_shred + 1, int(seg.shred_max))
		p.add_hex("boss_shred", {"def": -float(seg.shred) * _shred}, -1.0)

## A shot of this boss reached her (EnemyProjectile).
func on_shot_hit(shot: EnemyProjectile, landed: bool) -> void:
	if shot.has_meta("seg"): _after_hit(shot.get_meta("seg"), landed)

func _in_lane(point: Vector3, from: Vector3, to: Vector3, width: float) -> bool:
	var line := to - from
	line.y = 0.0
	var length := line.length()
	if length < 0.01: return false
	var dir := line / length
	var off := point - from
	off.y = 0.0
	var along := off.dot(dir)
	return along >= 0.0 and along <= length and absf(off.cross(dir).y) <= width * 0.5 + 0.2

## A big move breaks the cover it sweeps (and it stays broken, Q6).
func _break_cover(seg: Dictionary) -> void:
	if not is_instance_valid(game.arena) or not bool(seg.get("big", false)): return
	match str(seg.shape):
		"safe_zones":
			var spots: Array = _ctx.get("spots", [])
			game.arena.break_cover(func(p, _r): return not spots.any(func(s): return _flat_distance(p, s) <= BossCatalog.SAFE_RADIUS))
		"lanes":
			var lanes: Array = _ctx.get("lanes", [])
			var width := float(seg.width)
			game.arena.break_cover(func(p, r): return lanes.any(func(l): return _in_lane(p, l[0], l[1], width + 2.0 * r)))
		"mines":
			var spots: Array = _ctx.get("spots", [])
			game.arena.break_cover(func(p, r): return spots.any(func(s): return _flat_distance(p, s) <= float(seg.radius) + r))
		"dashes", "charge":
			game.arena.break_cover(func(p, r): return _in_lane(p, attack_origin, global_position, float(seg.get("width", 1.0)) + 2.0 * r))

func _resolve(seg: Dictionary) -> void:
	_break_cover(seg)
	var her_at := game.player.global_position
	var me := global_position
	match str(seg.shape):
		"sector":
			if EnemyAttacks.contains({"shape": "sector", "reach": seg.reach, "angle": seg.angle}, attack_origin, attack_direction, her_at) and game.line_of_sight(me, her_at): _hit_her(seg)
		"self":
			if _flat_distance(her_at, me) <= float(seg.radius): _hit_her(seg)
		"front_circle":
			if _flat_distance(her_at, _ctx.at) <= float(seg.radius): _hit_her(seg)
			if figure_id == "eikthyrnir" and tier >= 5: _hammer_the_fire(_ctx.at, float(seg.radius))
		"lane":
			if _in_lane(her_at, attack_origin, _ctx.end, float(seg.width)): _hit_her(seg)
		"charge":
			_charge_to(_ctx.end)
			if _in_lane(her_at, attack_origin, global_position, float(seg.width)) or _flat_distance(her_at, global_position) <= 1.0: _hit_her(seg)
		"ground":
			var spots: Array = _ctx.get("spots", [_ctx.at])
			for spot in spots:
				if _flat_distance(her_at, spot) <= float(seg.radius):
					_hit_her(seg)
					break
			if seg.has("zone"): _add_zone(_zone_from(seg, _ctx.at))
			# 沙狱 on a 医疗符文 buries it.
			if str(seg.id) == "prison" and is_instance_valid(game.arena): game.arena.bury_runes(_ctx.at, float(seg.radius))
		"curse":
			if _flat_distance(her_at, _ctx.at) <= float(seg.radius): _lay_curse(seg)
		"hurl":
			if _flat_distance(her_at, _ctx.at) <= float(seg.radius): _hit_her(seg)
			var from: Vector3 = _ctx.at
			_mark_return_lane(from, seg)
		"lob_line":
			var spots: Array = _ctx.spots
			for i in range(spots.size()):
				_later.append({"t": float(seg.gap) * i, "f": "blast", "at": spots[i], "seg": seg})
		"mines":
			for spot in _ctx.spots: _blast(spot, seg)
		"cross":
			_cross_hit(_ctx.lanes, seg)
			if seg.get("double", false):
				var tilted := _cross_lanes(_ctx.at, attack_direction.rotated(Vector3.UP, PI * 0.25), float(seg.arm))
				for lane in tilted: _mark_lane(lane[0], lane[1], float(seg.width), 0.8)
				_later.append({"t": 0.8, "f": "cross", "lanes": tilted, "seg": seg})
		"safe_zones":
			var safe: bool = (_ctx.spots as Array).any(func(s): return _flat_distance(her_at, s) <= BossCatalog.SAFE_RADIUS)
			if not safe and _flat_distance(her_at, centre()) <= BossCatalog.ARENA_RADIUS + 1.0: _hit_her(seg)
		"lanes":
			var hit := false
			for lane in _ctx.lanes:
				if not hit and _in_lane(her_at, lane[0], lane[1], float(seg.width)):
					hit = true
					_hit_her(seg)
				if seg.has("zone"): _add_zone({"shape": "lane", "from": lane[0], "to": lane[1], "width": float(seg.width), "time": float(seg.zone.time), "feature": seg.zone.get("feature", ""), "rate": float(seg.zone.get("rate", 0.0)), "colour": "cold"})
		"projectile":
			_shoot(seg)
		"blink":
			_set_hidden(false)
			global_position = Vector3(_ctx.at.x, global_position.y, _ctx.at.z)
			global_position.y = game.ground_y(global_position) + GROUND_LIFT
			if _flat_distance(her_at, global_position) <= float(seg.radius): _hit_her(seg)
		"smoke":
			_add_zone({"shape": "circle", "at": me, "radius": float(seg.radius), "time": float(seg.time), "taken": float(seg.taken), "colour": "smoke"})
		"bless":
			for g in guards:
				if is_instance_valid(g) and not g._dead: g.apply_status("haste", float(seg.time), 1.0)
		"channel":
			_channel = {"move": seg, "left": float(seg.time), "hits": 0, "breaks": int(seg.get("breaks", 2))}
		"javelin", "sniper":
			var target: Vector3 = _ctx.get("target", her_at)
			var dir := target - me
			dir.y = 0.0
			dir = dir.normalized() if dir.length_squared() > 0.001 else attack_direction
			var end := me + dir * float(seg.reach)
			var width := float(seg.get("width", 1.0))
			if _in_lane(her_at, me, end, width) and game.line_of_sight(me, her_at): _hit_her(seg)
			if seg.has("zone"): _add_zone(_zone_from(seg, target))
		"summon":
			_call_help()
		"raise_shrine":
			if is_instance_valid(game.arena):
				for spot in _ctx.spots: game.arena.raise_shrine(spot)
		"shrine_call":
			if _ctx.get("node") != null and is_instance_valid(game.arena): game.arena.fire_shrine(_ctx.node)
	_strike_civilians_by(seg)
	BossVfx.play(game, self, seg, _ctx)
	if not str(seg.shape) in ["channel"]:
		game.sound.play("enemy_breacher")

func _floor_at(at: Vector3) -> Vector3:
	return Vector3(at.x, game.ground_y(at) + 0.08, at.z)

## A strip from where the hammer fell back to its hand, 0.6 s on (雷锤).
func _mark_return_lane(from: Vector3, seg: Dictionary) -> void:
	var back := float(seg.get("back", 0.6))
	var marker := game.spawn_warning_lane(from, global_position, back, float(seg.width), from.distance_to(global_position), RIM)
	if marker != null: marker.hitstop_owner = self
	_later.append({"t": back, "f": "return", "from": from, "seg": seg})

func _cross_hit(lanes: Array, seg: Dictionary) -> void:
	var her_at := game.player.global_position
	# The sand comes up where the red was.
	for lane in lanes:
		var from: Vector3 = lane[0]
		var to: Vector3 = lane[1]
		BossVfx.sand_strip(game, from, to, float(seg.width))
	for lane in lanes:
		if _in_lane(her_at, lane[0], lane[1], float(seg.width)):
			_hit_her(seg)
			return

func _blast(at: Vector3, seg: Dictionary) -> void:
	if _flat_distance(game.player.global_position, at) <= float(seg.radius): _hit_her(seg)
	BossVfx._explosion(BossVfx.make(game, _floor_at(at)), float(seg.radius), BossVfx.colours(figure_id))

## Runs along a charge as far as the ground lets it.
func _charge_to(end: Vector3) -> void:
	var dir := end - global_position
	dir.y = 0.0
	var left := dir.length()
	if left < 0.01: return
	dir /= left
	while left > 0.0:
		var step := minf(0.25, left)
		if not _try_step(dir, step): break
		left -= step

func _shoot(seg: Dictionary) -> void:
	var count := int(seg.get("shots", 1))
	var cap := game.player.max_hp * BossCatalog.HIT_CAP
	var bounces := int(seg.get("bounce", 1))
	for b in range(bounces):
		if b == 0:
			_fire_shots(seg, count, minf(_raw(float(seg.damage)), cap))
		else:
			var dmg := minf(_raw(float(seg.damage)) * pow(1.0 - float(seg.get("bounce_cut", 0.0)), b), cap)
			_later.append({"t": float(seg.get("bounce_gap", 0.6)) * b, "f": "shots", "seg": seg, "count": count, "damage": dmg})

func _fire_shots(seg: Dictionary, count: int, damage: float) -> void:
	var origin := global_position + Vector3.UP * 0.4
	var aim := game.player.global_position - origin
	aim.y = 0.0
	aim = aim.normalized() if aim.length_squared() > 0.001 else attack_direction
	for i in range(count):
		var angle := deg_to_rad((i - (count - 1) * 0.5) * 20.0) if count > 1 and str(seg.id) != "burst" else 0.0
		var forward := aim.rotated(Vector3.UP, angle)
		var shot := game.launch_enemy_projectile(origin, origin + forward, damage, str(seg.get("projectile", "arrow")), float(seg.reach))
		if shot == null: continue
		shot.shooter = self
		shot.speed = float(seg.get("speed", shot.speed))
		shot.set_meta("seg", seg)
		if str(seg.id) == "burst" and i > 0:
			shot.global_position -= forward * 0.8 * i

## 溶血骇惧 (§7): her attack speed down and a drain that grows, until she has
## taken `break` of its life off it.
func _lay_curse(seg: Dictionary) -> void:
	curse = {"time": 0.0, "dealt": 0.0, "need": max_health * float(seg["break"]), "ramp": float(seg.ramp), "drain": float(seg.drain), "tick": ZONE_TICK}
	game.player.add_hex("boss_curse", seg.hex, -1.0)

func _lift_curse() -> void:
	curse = {}
	if is_instance_valid(game.player): game.player.clear_hex("boss_curse")

func _tick_curse(delta: float) -> void:
	if curse.is_empty(): return
	curse.time = float(curse.time) + delta
	curse.tick = float(curse.tick) - delta
	if float(curse.tick) <= 0.0:
		curse.tick = ZONE_TICK
		var share := float(curse.drain) * clampf(float(curse.time) / float(curse.ramp), 0.0, 1.0)
		if share > 0.0: game.player.take_damage(game.player.max_hp * share * ZONE_TICK, "true", self)

func _tick_channel(delta: float) -> void:
	var seg: Dictionary = _channel.move
	_channel.left = float(_channel.left) - delta
	attack_phase = "windup"
	if seg.has("debt"): game.add_debt(float(seg.debt) * delta)
	if float(_channel.left) <= 0.0: _end_channel(true)

## 狂暴怒嗥 / 赦罪 ends; done (not broken) 赦罪 heals the guards.
func _end_channel(done: bool) -> void:
	var seg: Dictionary = _channel.get("move", {})
	_channel = {}
	if done and seg.has("heal"):
		for g in guards:
			if is_instance_valid(g) and not g._dead: g.health = minf(g.max_health, g.health + g.max_health * float(seg.heal))
	if not seg.is_empty():
		_cooldowns[str(seg.id)] = float(seg.get("cd", 0.0))
	attack_phase = "idle"
	_gap = float(GAP[rank])

# --- Phases ------------------------------------------------------------------------------

func _next_phase() -> void:
	_cancel_move()
	phase += 1
	if figure_id == "patriot" and phase == 2:
		_go_down("")
	else:
		_roar()
	if figure_id == "eikthyrnir":
		_later.append({"t": BossCatalog.ROAR_TIME, "f": "rampage"})
		if tier >= 5: _raise_barrier(BossCatalog.FROST_ARMOUR)

## The phase-change roar: untouchable a moment, and she is shoved off its feet.
func _roar() -> void:
	roar_left = BossCatalog.ROAR_TIME
	attack_phase = "windup"
	_attack_elapsed = 0.0
	_mark_area(global_position, BossCatalog.ROAR_RADIUS, BossCatalog.ROAR_TIME)

func _end_roar() -> void:
	_clear_markers()
	attack_phase = "idle"
	var away := game.player.global_position - global_position
	away.y = 0.0
	if away.length() <= BossCatalog.ROAR_RADIUS: game.player.apply_control("knockback", away.normalized() if away.length_squared() > 0.01 else Vector3.BACK, BossCatalog.ROAR_PUSH, 0.3)
	BossVfx.roar(game, global_position, figure_id, BossCatalog.ROAR_RADIUS)
	_gap = 0.4

## Kneeling (爱国者) or lying down (扎罗): untouchable for DOWN_TIME, then up.
func _go_down(after: String) -> void:
	_cancel_move()
	_lift_curse()
	_after_down = after
	down_left = BossCatalog.DOWN_TIME
	if is_instance_valid(_sprite): _sprite.modulate = _tint.darkened(0.4)
	_mark_area(global_position, BossCatalog.ROAR_RADIUS, BossCatalog.DOWN_TIME)

func _get_up() -> void:
	_clear_markers()
	if is_instance_valid(_sprite): _sprite.modulate = _tint
	match _after_down:
		"next_life":
			life += 1
			phase = 2
			health = max_health
			_marks = [0.25] if tier >= 3 else []
			_summon_marks = BossCatalog.SUMMON_AT.duplicate() if _has_move("summon") else []
			# 扎罗's second life brings a 家族灭迹人 from tier 4 (§7).
			if figure_id == "zaro" and tier >= 4: _call_eraser()
		"revive":
			health = max_health * BossCatalog.REVIVE_SHARE
	_after_down = ""
	# The kneel ends in an originium pulse round it (爱国者).
	if figure_id == "patriot":
		if _flat_distance(game.player.global_position, global_position) <= BossCatalog.ROAR_RADIUS:
			_hit_her({"id": "pulse", "damage": 0.8})
		BossVfx.shrine_pulse(game, global_position, BossCatalog.ROAR_RADIUS)
	else:
		_end_roar()
	_gap = 0.4

# --- Help ------------------------------------------------------------------------------

## The tier-4 summon (or the warden's 援军) at the next life share.
func _call_help() -> void:
	var types: Array = []
	var boost := 0.0
	for move in BossCatalog.moves_for(figure_id, tier, 3):
		if str(move.shape) == "summon":
			types = move.types
			boost = float(move.get("boost", 0.0))
	if types.is_empty() and affixes.has("rally"):
		var pool: Dictionary = EnemyAttacks.REGION_POOLS.get(game.region_id, {})
		for i in range(BossCatalog.RALLY_COUNT): types.append(pool.normal[i % pool.normal.size()])
	summoned = summoned.filter(func(e): return is_instance_valid(e) and not e._dead)
	for type in types:
		if summoned.size() >= BossCatalog.SUMMON_CAP: break
		var e := _summon(str(type), false)
		if boost > 0.0: e.atk *= 1.0 + boost

func _call_eraser() -> void:
	_summon("family_eraser", true)

## One called in (用户 2026-10-20): at a random spot of the arena clear of
## everyone already standing and of her, after her at once, and carrying
## nothing when it falls.
func _summon(type: String, elite: bool) -> Enemy:
	var taken := [game.player.global_position, global_position]
	for other in game.floor_enemies(): taken.append(other.global_position)
	var e := game._spawn_enemy(_arena_point(BossCatalog.EDGE_GAP, taken, SUMMON_APART), elite, false, type)
	e.called_in = true
	BossVfx.arrival(game, e.global_position, figure_id)
	e.home_position = centre()
	e.leash_radius = BossCatalog.ARENA_RADIUS + 4.0
	e.begin_chase(true)
	summoned.append(e)
	return e

## 扎罗's first life: two 家族士兵 every 20 s, never more than six standing.
func _tick_family(delta: float) -> void:
	_family_time -= delta
	if _family_time > 0.0: return
	for move in BossCatalog.moves_for(figure_id, tier, phase):
		if str(move.shape) != "family": continue
		_family_time = float(move.every)
		summoned = summoned.filter(func(e): return is_instance_valid(e) and not e._dead)
		var family := summoned.filter(func(e): return e.enemy_type == "family_soldier").size()
		for i in range(int(move.count)):
			if family >= int(move.cap): break
			_summon("family_soldier", false)
			family += 1

# --- What it does round itself, and the field ------------------------------------------

func _tick_auras(delta: float) -> void:
	var her_at := game.player.global_position
	var d := _flat_distance(her_at, global_position)
	var aura: Dictionary = fig.get("aura", {})
	if not aura.is_empty() and phase >= int(aura.phase) and d <= float(aura.radius):
		var feature := str(aura.feature)
		if aura.has("rate"):
			game.features.add(feature, float(aura.rate) * delta * game.features.growth_mult(feature, game.floor_number))
		else:
			_aura_time -= delta
			if _aura_time <= 0.0:
				_aura_time = float(aura.every)
				game.features.add(feature, float(aura.pulse) * game.features.growth_mult(feature, game.floor_number))
	if fig.has("debt_rate"):
		game.add_debt(float(fig.debt_rate) * delta * (BossCatalog.BLOOD_MOON if figure_id == "zaro" and tier >= 5 else 1.0))
	if figure_id == "zaro":
		if phase >= 2 and d <= BossCatalog.AWE_RADIUS: game.player.add_hex("boss_awe", {"aspd": BossCatalog.AWE_ASPD}, 0.3)
		if phase == 1: _tick_family(delta)
		if reckoning_left > 0.0:
			reckoning_left -= delta
			if reckoning_left <= 0.0: game.features.reduce("debt", FeatureCatalog.RECKONING_PAYOFF)
	if affixes.has("quake"):
		_quake_time -= delta
		if _quake_time <= 0.0:
			_quake_time = BossCatalog.QUAKE_EVERY
			var at := global_position
			game.spawn_warning_area(at, BossCatalog.QUAKE_RADIUS, BossCatalog.QUAKE_WINDUP, RIM)
			_later.append({"t": BossCatalog.QUAKE_WINDUP, "f": "blast", "at": at, "seg": {"id": "quake", "radius": BossCatalog.QUAKE_RADIUS, "damage": 1.0}})

## 清算时刻 on a boss floor (Q6): 扎罗 takes it himself instead of a squad coming.
func begin_reckoning() -> void:
	reckoning_left = BossCatalog.RECKONING_TIME
	if is_instance_valid(_sprite): _sprite.modulate = Color("c04050")
	_later.append({"t": BossCatalog.RECKONING_TIME, "f": "tint"})

func reckoning_active() -> bool:
	return reckoning_left > 0.0

## Tier 5 on: 鼠王's sandstorm closes the arena in; 扎罗's blood marks.
func _tick_field(delta: float) -> void:
	if figure_id == "rat_king" and tier >= 5:
		var storm: Dictionary = {}
		for move in BossCatalog.MOVES.rat_king:
			if str(move.shape) == "sandstorm": storm = move
		_storm_time += delta
		# The next ring of sand shows on the ground `warn` s before it fills.
		if storm_steps < int(storm.times) and _storm_time >= float(storm.every) - float(storm.warn) and _storm_time - delta < float(storm.every) - float(storm.warn):
			_warn_ring(BossCatalog.ARENA_RADIUS - float(storm.step) * (storm_steps + 1), float(storm.step), float(storm.warn))
		if storm_steps < int(storm.times) and _storm_time >= float(storm.every):
			_storm_time = 0.0
			storm_steps += 1
			_add_zone({"shape": "ring", "at": centre(), "radius": BossCatalog.ARENA_RADIUS - float(storm.step) * storm_steps, "time": 9999.0, "colour": "sand"})
		if storm_steps > 0:
			var inner := BossCatalog.ARENA_RADIUS - float(storm.step) * storm_steps
			var d := _flat_distance(game.player.global_position, centre())
			if d > inner and d <= BossCatalog.ARENA_RADIUS + 1.0:
				_storm_tick -= delta
				if _storm_tick <= 0.0:
					_storm_tick = ZONE_TICK
					_hit_her({"id": "sandstorm", "damage": 0.15, "kind": "arts"})
	if figure_id == "zaro" and tier >= 5 and phase >= 2:
		_blood_time += delta
		if _blood_time >= BossCatalog.BLOOD_MARK_EVERY:
			_blood_time = 0.0
			_add_zone({"shape": "circle", "at": global_position - attack_direction * 1.5, "radius": float(BossCatalog.BLOOD_MARK.radius), "time": float(BossCatalog.BLOOD_MARK.time), "family_taken": float(BossCatalog.BLOOD_MARK.taken), "colour": "blood"})

## Where its hammer falls near a lit fire, the fire loses FIRE_HAMMER_COST s.
func _hammer_the_fire(at: Vector3, radius: float) -> void:
	for fire in game.fires:
		if is_instance_valid(fire) and fire.lit() and _flat_distance(fire.global_position, at) <= radius + FeatureCatalog.FIRE_RADIUS:
			fire.burn(BossCatalog.FIRE_HAMMER_COST)

func _tick_later(delta: float) -> void:
	var due := []
	for entry in _later:
		entry.t = float(entry.t) - delta
		if float(entry.t) <= 0.0: due.append(entry)
	for entry in due:
		_later.erase(entry)
		match str(entry.f):
			"blast": _blast(entry.at, entry.seg)
			"cross": _cross_hit(entry.lanes, entry.seg)
			"shots": _fire_shots(entry.seg, int(entry.count), float(entry.damage))
			"return":
				var seg: Dictionary = entry.seg
				if _in_lane(game.player.global_position, entry.from, global_position, float(seg.width)): _hit_her(seg, _raw(float(seg.back_damage)))
			"rampage": _rampage()
			"tint":
				if is_instance_valid(_sprite): _sprite.modulate = _tint

## 自我泯灭 (§6): a cold burst, three charges at her taking a fifth of the
## damage, and a burst again.
func _rampage() -> void:
	if _dead or down_left > 0.0 or roar_left > 0.0: return
	_cancel_move()
	var burst := {"id": "rampage", "shape": "self", "radius": BossCatalog.RAMPAGE_BURST.radius, "windup": 0.6, "damage": 0.5, "cold": BossCatalog.RAMPAGE_BURST.cold}
	var combo := [burst]
	for i in range(BossCatalog.RAMPAGE_DASHES): combo.append({"shape": "charge", "reach": 6.0, "width": 1.4, "windup": 0.6, "damage": 1.0})
	combo.append(burst)
	_start({"id": "rampage", "shape": "self", "cd": 0.0, "combo": combo})
	_rampaging = true
	# The first one runs through the 木裂 totem (Boss战场地策划案 §4.3).
	if is_instance_valid(game.arena): game.arena.break_totem()

# --- Ground it leaves ------------------------------------------------------------------

## Ground from a move: [radius, time, tick (damage on its ATK every 0.5 s), …].
func _zone_from(seg: Dictionary, at: Vector3) -> Dictionary:
	var z: Dictionary = seg.zone
	var colour := "sand" if z.has("hex") else ("contamination" if str(z.get("feature", "")) == "contamination" else "cold")
	return {"shape": "circle", "at": at, "radius": float(z.get("radius", 2.0)), "time": float(z.time), "damage": float(z.get("tick", 0.0)),
		"feature": str(z.get("feature", "")), "rate": float(z.get("rate", 0.0)), "hex": z.get("hex", {}), "colour": colour, "id": str(seg.id)}

## Discs round the ring between `inner` and `inner + width`, as the warning.
func _warn_ring(inner: float, width: float, life_time: float) -> void:
	var r := inner + width * 0.5
	var count := ceili(TAU * r / (width * 1.6))
	for i in range(count):
		var a := TAU * i / count
		game.spawn_warning_area(centre() + Vector3(cos(a), 0.0, sin(a)) * r, width * 0.6, life_time, RIM)

func _add_zone(zone: Dictionary) -> void:
	zone["tick_left"] = ZONE_TICK
	if str(zone.shape) == "ring":
		zone["mesh"] = _ring(zone.at, float(zone.radius), BossCatalog.ARENA_RADIUS + 1.0, ZONE_COLOURS[zone.colour])
	elif str(zone.shape) == "circle":
		zone["mesh"] = _disc(zone.at, float(zone.radius), ZONE_COLOURS[zone.colour], 2)
	else:
		zone["mesh"] = _strip(zone.from, zone.to, float(zone.width), ZONE_COLOURS[zone.colour])
	zones.append(zone)

func _inside(zone: Dictionary, point: Vector3) -> bool:
	if str(zone.shape) == "ring": return _flat_distance(point, zone.at) > float(zone.radius)
	if str(zone.shape) == "circle": return _flat_distance(point, zone.at) <= float(zone.radius)
	return _in_lane(point, zone.from, zone.to, float(zone.width))

func _tick_ground(delta: float) -> void:
	if zones.is_empty(): return
	var her_at := game.player.global_position
	for zone in zones.duplicate():
		zone.time = float(zone.time) - delta
		if float(zone.time) <= 0.0:
			if is_instance_valid(zone.mesh): zone.mesh.queue_free()
			zones.erase(zone)
			continue
		if zone.has("family_taken"):
			for e in summoned:
				if is_instance_valid(e) and not e._dead and _inside(zone, e.global_position): e.apply_status("fragile", 0.3, -float(zone.family_taken))
		if not _inside(zone, her_at): continue
		if not str(zone.get("feature", "")).is_empty() and float(zone.get("rate", 0.0)) > 0.0:
			game.features.add(zone.feature, float(zone.rate) * delta * game.features.growth_mult(zone.feature, game.floor_number))
		if not (zone.get("hex", {}) as Dictionary).is_empty(): game.player.add_hex("boss_zone", zone.hex, 0.3)
		if float(zone.get("damage", 0.0)) > 0.0:
			zone.tick_left = float(zone.tick_left) - delta
			if float(zone.tick_left) <= 0.0:
				zone.tick_left = ZONE_TICK
				_hit_her({"id": str(zone.get("id", "zone")), "damage": float(zone.damage), "kind": "arts"})

func _clear_ground() -> void:
	for zone in zones:
		if is_instance_valid(zone.get("mesh")): zone.mesh.queue_free()
	zones.clear()
	_clear_markers()
	_later.clear()

func _disc(at: Vector3, radius: float, colour: Color, priority: int) -> MeshInstance3D:
	var disc := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = 0.02
	cylinder.radial_segments = 32
	disc.mesh = cylinder
	disc.material_override = _flat_material(colour, priority)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	game.add_child(disc)
	disc.global_position = Vector3(at.x, game.ground_y(at) + 0.05, at.z)
	return disc

func _strip(from: Vector3, to: Vector3, width: float, colour: Color) -> MeshInstance3D:
	var strip := MeshInstance3D.new()
	var box := BoxMesh.new()
	var length := maxf(0.1, Vector2(to.x - from.x, to.z - from.z).length())
	box.size = Vector3(width, 0.02, length)
	strip.mesh = box
	strip.material_override = _flat_material(colour, 2)
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	game.add_child(strip)
	var mid := (from + to) * 0.5
	strip.global_position = Vector3(mid.x, game.ground_y(mid) + 0.05, mid.z)
	var dir := to - from
	dir.y = 0.0
	if dir.length_squared() > 0.001: strip.basis = Basis.looking_at(dir.normalized())
	return strip

## The sand wall: a band from `inner` out to `outer`.
func _ring(at: Vector3, inner: float, outer: float, colour: Color) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	var tube := TorusMesh.new()
	tube.inner_radius = inner
	tube.outer_radius = outer
	tube.rings = 48
	ring.mesh = tube
	ring.material_override = _flat_material(colour, 2)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.scale = Vector3(1.0, 0.01, 1.0)
	game.add_child(ring)
	ring.global_position = Vector3(at.x, game.ground_y(at) + 0.05, at.z)
	return ring

static func _flat_material(colour: Color, priority: int) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = colour
	# Depth-tested and never writing depth: flat on the ground, so whoever stands
	# in it is drawn over it (用户 2026-10-20: 还是在人物上一层).
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.render_priority = priority
	return material
