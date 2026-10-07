class_name Enemy
extends Node3D

## Perception and anchored guard squads drive idle/chase/return states.
## Movement follows NavigationAgent3D with terrain-checked final steps.
## Ordinary attacks read through poses, facing and sounds; elites telegraph.

signal died(enemy: Enemy)

const CHASE_REPATH_INTERVAL := 0.3
const CHASE_REPATH_DISTANCE_SQ := 2.25
const PICK_LAYER := 4  # bit 3, dedicated to mouse-picking raycasts

var elite: bool = false
var ranged: bool = false
var health: float = 3.0
## Combat stats from EnemyAttacks.STATS (局内构筑与数值策划案 §6).
var max_health: float = 3.0
var atk: float = 0.0
var defense: float = 0.0
var res: float = 0.0
var damage_kind := "phys"
## Timed statuses relics put on enemies: name -> {"time": s, "value": x}.
## burn (value = arts damage per tick), slow / def_down (fractions), res_down (points).
var statuses: Dictionary = {}
var _burn_tick := 0.0
## Relics that act on the first hit against an enemy (冻土绊索).
var hit_by_player := false
var _health_bar: EnemyHealthBar
var move_speed: float = 2.1
var game: GameManager
enum Behavior { NORMAL, GUARD }
enum State { IDLE, CHASING, RETURNING }
var behavior := Behavior.NORMAL
var state := State.IDLE
var home_position := Vector3.ZERO
var guard_post: Node3D
var perception_radius := 10.0
var leash_radius := 22.0
var sight_memory := 3.0
var _lost_sight_time := 0.0
var _last_seen_position := Vector3.ZERO
var _rearm_timer := 0.0
var _warning_markers: Array[Node] = []
var _state_label: Label3D

const ANIM_FRAME_TIME := 0.25

var _sprite: Sprite3D
var _walk_frames: Array[ImageTexture] = []
var _anim_timer: float = ANIM_FRAME_TIME
var _anim_frame: int = 0
var _base_color: Color
var _nav_agent: NavigationAgent3D
var _attack_timer: float = 0.0
var preparing_attack: bool = false
var _repath_timer: float = 0.0
var _last_destination: Vector3 = Vector3.INF

var _windup_remaining: float = 0.0
var pending_warning_position: Vector3
var pending_warning_radius: float = 0.0
var _pending_damage: float = 0.0
var hitstop_remaining := 0.0
var _dead := false
var _locked_target := Vector3.ZERO
var _bob_time := 0.0
var _art_base_y := 0.0
var enemy_type := "thug"
var attack_profile: Dictionary = {}
var attack_direction := Vector3.RIGHT
var attack_origin := Vector3.ZERO
var attack_phase := "idle"
var pose_frame := 0
## True when this enemy has an eight-direction sheet: frames are picked per
## facing column (S, SW, W, NW, N, NE, E, SE) instead of flipping a side view.
var directional := false
var dir_column := 0
## Screen angle (0 = east, +90 = south) at the centre of each sheet column.
const COLUMN_ANGLES := [90.0, 135.0, 180.0, 225.0, 270.0, 315.0, 0.0, 45.0]
## 8-way screen sector (east, south-east, south ... north-east) -> sheet column.
const SECTOR_COLUMNS := [6, 7, 0, 1, 2, 3, 4, 5]
const TURN_HYSTERESIS_DEG := 6.0
## Walk frames advance with distance walked, not time: one 4-frame cycle
## (two steps) per world unit, so feet do not slide and stop when she stops.
const WALK_FRAMES_PER_UNIT := 4.0
var walking := false
var has_walk := false
var walk_distance := 0.0
var _stepped := 0.0
var _phase_remaining := 0.0
var _attack_elapsed := 0.0
var _dash_travelled := 0.0
var _contacted := false
var _recoil_travelled := 0.0
var _hit_this_attack := false
var _cue_played := false
var _aim_locked := false
var _lock_flash := 0.0
var _glint: MeshInstance3D
var _breath: MeshInstance3D
var _muzzle := Vector3.ZERO
## Ranged enemies hold the crossbow / rifle painted in their pose; there is no
## overlaid weapon. These are the painted muzzle tips in the charge pose, in
## texels from the foot-line centre (x toward facing, negative y = up). Shots
## and the release flash start there; the hunter's lock glint sits on the scope.
const MUZZLE_TEXELS := {"crossbow": Vector2(22, -12), "crossbow_leader": Vector2(23, -12), "ice_hunter": Vector2(23, -10)}
const SCOPE_TEXELS := Vector2(12, -12)
const STRIKE_TIME := 0.10
## A lunge stops when it reaches the player instead of passing through, holds
## the connecting pose, then springs back. It reaches her with whatever is in
## front: the slug's jaws (body contact) or the brawler's extended blade.
const CONTACT_DISTANCE := 0.8
const CONTACT_TIME := 0.12
const RECOIL_TIME := 0.18
const START_TIME := 0.12
const PIXEL := 1.0 / 15.0

func setup(p_game: GameManager, p_elite: bool, p_ranged: bool, type: String = "") -> void:
	game = p_game
	enemy_type = EnemyAttacks.default_type(game.region_id, p_elite, p_ranged) if type.is_empty() else type
	if not EnemyAttacks.PROFILES.has(enemy_type): enemy_type = EnemyAttacks.default_type(game.region_id, p_elite, p_ranged)
	if game.region_id == "mine" and enemy_type == "elite": enemy_type = "thug"
	attack_profile = EnemyAttacks.PROFILES[enemy_type]
	elite = enemy_type == "elite"
	directional = not elite and FieldArt.has_directional(enemy_type)
	has_walk = directional and FieldArt.has_walk(enemy_type)
	ranged = attack_profile.shape == "projectile"
	home_position = global_position
	perception_radius = 17.0 if enemy_type == "ice_hunter" else (14.0 if ranged else 10.0)
	name = attack_profile.name
	var stats: Dictionary = EnemyAttacks.STATS[enemy_type]
	max_health = float(stats.hp)
	health = max_health
	atk = float(stats.atk)
	defense = float(stats.def)
	res = float(stats.res)
	damage_kind = str(stats.kind)
	move_speed = 1.2 if elite else (2.4 if ranged else 2.1)
	_base_color = Color(0.65, 0.15, 0.12) if elite else (Color(0.25, 0.45, 1.0) if ranged else Color(0.8, 0.25, 0.18))
	_build_visual()
	_build_pick_area()
	_build_navigation()
	add_to_group("enemies")

func _build_visual() -> void:
	var height := 2.2 if elite else 1.8
	_sprite = Sprite3D.new()
	if elite: _sprite.texture = FieldArt.enemy(game.region_id, true, false)
	else: _sprite.texture = FieldArt.enemy_dir_pose(enemy_type, dir_column, 0) if directional else FieldArt.enemy_pose(int(attack_profile.row), 0)
	_sprite.pixel_size = height / _sprite.texture.get_height() if elite else PIXEL
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_art_base_y = height * 0.43 - 0.65 if elite else -0.55
	# Side-view cells centre the body at x=28, directional cells at x=32.
	if not elite: _sprite.offset = Vector2(0 if directional else 4, 19)
	_sprite.position.y = _art_base_y
	add_child(_sprite)
	_state_label = Label3D.new()
	_state_label.position.y = height + 0.15
	_state_label.font_size = 24
	_state_label.pixel_size = 0.012
	_state_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_state_label)
	_health_bar = EnemyHealthBar.new()
	_health_bar.position.y = height + 0.02
	add_child(_health_bar)
	_health_bar.visible = false  # drawn by the HUD instead (界面策划案 §2.6)
	_glint = EnemyAttackVfx.part(self, Vector3.ZERO, Vector3.ONE * PIXEL, Color.WHITE)
	_glint.material_override.no_depth_test = true
	_glint.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glint.material_override.render_priority = 5
	_glint.visible = false
	_breath = EnemyAttackVfx.part(self, Vector3.ZERO, Vector3(2 * PIXEL, PIXEL, PIXEL), Color("d1e6eb"))
	_breath.material_override.no_depth_test = true
	_breath.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_breath.material_override.render_priority = 4
	_breath.visible = false

func _advance_animation(delta: float) -> void:
	_bob_time += delta
	# Distance stepped since the previous tick decides walking vs standing.
	walking = _stepped > 0.0005
	walk_distance += _stepped
	_stepped = 0.0
	if not elite:
		_update_attack_visual()
		return
	if is_instance_valid(_sprite):
		_sprite.position.y = _art_base_y + (0.025 if preparing_attack else 0.045) * sin(_bob_time * (4 if preparing_attack else 10))
	if _walk_frames.size() < 2:
		return
	_anim_timer -= delta
	if _anim_timer <= 0.0:
		_anim_timer = ANIM_FRAME_TIME
		_anim_frame = (_anim_frame + 1) % _walk_frames.size()
		_sprite.texture = _walk_frames[_anim_frame]

func _build_pick_area() -> void:
	var area := Area3D.new()
	area.collision_layer = PICK_LAYER
	area.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	var size := 1.4 if elite else 1.0
	box_shape.size = Vector3.ONE * size
	shape.shape = box_shape
	area.add_child(shape)
	add_child(area)

func _build_navigation() -> void:
	_nav_agent = NavigationAgent3D.new()
	_nav_agent.radius = 1.0 if elite else 0.72
	_nav_agent.height = 1.4 if elite else 1.0
	_nav_agent.path_desired_distance = 0.5
	_nav_agent.target_desired_distance = 0.5
	add_child(_nav_agent)

func _physics_process(delta: float) -> void:
	if _dead or (is_instance_valid(game) and not game.simulation_active()): return
	if not is_instance_valid(game) or not is_instance_valid(game.player): return
	if hitstop_remaining > 0:
		hitstop_remaining = maxf(0, hitstop_remaining - delta)
		return
	_advance_animation(delta)
	_tick_statuses(delta)
	if _dead: return
	_attack_timer = maxf(0, _attack_timer - delta)
	_rearm_timer = maxf(0, _rearm_timer - delta)
	_update_state_label()
	var player_position: Vector3 = game.player.global_position
	if behavior == Behavior.GUARD:
		if not is_instance_valid(guard_post):
			if state == State.CHASING: begin_return()
		elif state == State.CHASING and (not guard_post.active or _flat_distance(global_position, guard_post.global_position) > guard_post.leash_radius):
			begin_return()
	else:
		if state == State.IDLE and _rearm_timer <= 0 and _can_perceive(player_position):
			begin_chase()
		elif state == State.CHASING:
			if _flat_distance(player_position, home_position) > leash_radius or _flat_distance(global_position, home_position) > leash_radius:
				begin_return()
			elif _can_perceive(player_position):
				_last_seen_position = player_position
				_lost_sight_time = 0
			else:
				_lost_sight_time += delta
				if _lost_sight_time >= sight_memory: begin_return()
	if state == State.RETURNING:
		if _flat_distance(global_position, home_position) <= 0.3:
			global_position = home_position
			state = State.IDLE
			_rearm_timer = 0.6
			_repath_timer = 0
		else:
			_move_toward_target(home_position, delta)
		return
	if state != State.CHASING: return
	var visible_player := game.line_of_sight(global_position, player_position)
	if behavior == Behavior.GUARD or _can_perceive(player_position):
		_last_seen_position = player_position
	var target := _last_seen_position
	var distance := _flat_distance(global_position, player_position)
	var desired_distance := float(attack_profile.reach) - (2.0 if ranged else 0.3)
	if attack_phase == "idle":
		# Ranged enemies must navigate around cover even inside firing range.
		if distance > desired_distance or not visible_player:
			_move_toward_target(target, delta)
		elif distance > 0.01:
			_face((player_position - global_position).normalized(), delta)
	if attack_phase != "idle":
		_tick_attack(delta)
	else:
		if distance <= float(attack_profile.reach) and _attack_timer <= 0 and visible_player:
			_begin_telegraphed_attack()

func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _can_perceive(point: Vector3) -> bool:
	return _flat_distance(global_position, point) <= perception_radius and _flat_distance(home_position, point) <= leash_radius and game.line_of_sight(global_position, point)

func begin_chase() -> void:
	if _dead or state == State.RETURNING or _rearm_timer > 0: return
	state = State.CHASING
	_last_seen_position = game.player.global_position
	_lost_sight_time = 0
	_repath_timer = 0

func begin_return() -> void:
	if _dead or state == State.RETURNING: return
	state = State.RETURNING
	_cancel_attack()
	_repath_timer = 0
	_last_destination = Vector3.INF
	_attack_timer = 0.6

func configure_guard(post: Node3D) -> void:
	behavior = Behavior.GUARD
	guard_post = post
	home_position = global_position
	name = "守卫_" + name
	add_to_group("guards")

func _move_toward_target(target: Vector3, delta: float) -> void:
	_repath_timer -= delta
	if _repath_timer <= 0 or target.distance_squared_to(_last_destination) > CHASE_REPATH_DISTANCE_SQ:
		_nav_agent.target_position = target
		_last_destination = target
		_repath_timer = CHASE_REPATH_INTERVAL
	# Poll before is_navigation_finished: this refreshes a newly assigned path.
	var next := _nav_agent.get_next_path_position()
	if _nav_agent.is_navigation_finished():
		if not game.line_of_sight(global_position, target): return
		next = target
	var direction := next - global_position
	direction.y = 0
	if direction.length_squared() > 0.0001:
		_step_toward(direction.normalized(), minf(delta, direction.length() / move_speed))

func _cancel_attack() -> void:
	preparing_attack = false
	_windup_remaining = 0
	attack_phase = "idle"
	_phase_remaining = 0
	_lock_flash = 0
	for marker in _warning_markers:
		if is_instance_valid(marker): marker.queue_free()
	_warning_markers.clear()
	if not elite and is_instance_valid(_sprite): _update_attack_visual()

func _update_state_label() -> void:
	if not is_instance_valid(_state_label): return
	_state_label.visible = _flat_distance(global_position, game.player.global_position) < 23
	match state:
		State.IDLE:
			_state_label.text = "守卫" if behavior == Behavior.GUARD else ""
			_state_label.modulate = Color("ddbb70")
		State.CHASING:
			_state_label.text = "!"
			_state_label.modulate = Color("ef745c")
		State.RETURNING:
			_state_label.text = "归位"
			_state_label.modulate = Color("8fc6df")

func _step_toward(direction: Vector3, delta: float) -> void:
	var candidate := global_position + direction * move_speed * (1.0 - status_value("slow")) * delta
	if is_instance_valid(game) and game.world_map.is_navigation_ready():
		var closest := NavigationServer3D.map_get_closest_point(game.world_map.navigation_map_rid(), candidate)
		closest.y = global_position.y
		# A finished/stale path must never turn into a straight-line wall cut.
		if closest.distance_to(candidate) > 0.5 or not game.world_map._is_open(closest.x, closest.z, -0.3): return
		if not game.line_of_sight(global_position, closest): return
		candidate = closest
	_stepped += Vector2(candidate.x - global_position.x, candidate.z - global_position.z).length()
	global_position = candidate
	_face(direction, delta)

func _face(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 0.0001:
		return
	var target_transform := global_transform.looking_at(global_position + direction, Vector3.UP)
	global_transform.basis = global_transform.basis.slerp(target_transform.basis, clampf(14.0 * delta, 0.0, 1.0))
	if not is_instance_valid(_sprite) or not is_instance_valid(game.camera): return
	if directional: _turn_to(direction, delta >= 1.0)
	else: _sprite.flip_h = direction.dot(game.camera.global_basis.x) < 0

## Pick the sheet column facing `direction` as seen on screen. Turning only
## commits once the angle is clearly past the sector edge (no flicker while
## chasing along a diagonal); `snap` skips that for locked attack directions.
func _turn_to(direction: Vector3, snap: bool) -> void:
	var basis := game.camera.global_basis
	var right := Vector3(basis.x.x, 0, basis.x.z).normalized()
	var forward := Vector3(-basis.z.x, 0, -basis.z.z)
	if forward.length_squared() < 0.0001: forward = Vector3(basis.y.x, 0, basis.y.z)
	forward = forward.normalized()
	var angle := rad_to_deg(atan2(-direction.dot(forward), direction.dot(right)))
	var column: int = SECTOR_COLUMNS[posmod(roundi(angle / 45.0), 8)]
	if column == dir_column: return
	if not snap and absf(wrapf(angle - COLUMN_ANGLES[dir_column], -180.0, 180.0)) < 22.5 + TURN_HYSTERESIS_DEG: return
	dir_column = column
	_update_attack_visual()

func _begin_telegraphed_attack() -> void:
	if _dead or state != State.CHASING or attack_phase != "idle": return
	preparing_attack = true
	attack_phase = "windup"
	attack_origin = global_position
	_attack_elapsed = 0
	_dash_travelled = 0
	_contacted = false
	_recoil_travelled = 0
	_hit_this_attack = false
	_cue_played = false
	_aim_locked = not attack_profile.has("track")
	_lock_flash = 0
	_lock_direction()
	_windup_remaining = float(attack_profile.windup)
	_pending_damage = atk * float(attack_profile.damage) * (1.0 + game.pressure / EnemyAttacks.PRESSURE_DIVISOR) * game.enemy_attack_multiplier()
	pending_warning_position = game.player.global_position if elite else attack_origin
	pending_warning_radius = float(attack_profile.get("radius", 0.0))
	if elite:
		_warning_markers.append(game.spawn_warning_area(pending_warning_position, pending_warning_radius, _windup_remaining))
		for marker in _warning_markers: marker.hitstop_owner = self
	else:
		_update_attack_visual()

func _lock_direction() -> void:
	_locked_target = game.player.global_position
	attack_direction = _locked_target - global_position
	attack_direction.y = 0
	attack_direction = attack_direction.normalized() if attack_direction.length_squared() > 0.001 else Vector3.RIGHT
	_face(attack_direction, 1.0)

func _tick_attack(delta: float) -> void:
	if attack_phase == "windup":
		var previous := _attack_elapsed
		_attack_elapsed += delta
		_windup_remaining = maxf(0, float(attack_profile.windup) - _attack_elapsed)
		if not _aim_locked:
			# Track only before the 0.7s boundary, then hold that last direction
			# for the entire 0.5s reaction window, including the firing tick.
			if previous < float(attack_profile.track): _lock_direction()
			if _attack_elapsed >= float(attack_profile.track):
				_aim_locked = true
				# The only read on the sniper: make the lock unmissable.
				_lock_flash = 0.20
		if _windup_remaining <= 0.1 and not _cue_played:
			_cue_played = true
			if not elite: game.sound.play("enemy_" + enemy_type)
		_update_attack_visual()
		_lock_flash = maxf(0, _lock_flash - delta)
		if _windup_remaining <= 0: _resolve_attack()
	elif attack_phase == "strike":
		_phase_remaining = maxf(0, _phase_remaining - delta)
		if attack_profile.has("dash"):
			_advance_lunge(delta)
			_try_melee_hit()
		if attack_phase == "strike" and _phase_remaining <= 0:
			attack_phase = "recovery"
			_phase_remaining = float(attack_profile.recovery)
		_update_attack_visual()
	elif attack_phase == "contact":
		_phase_remaining = maxf(0, _phase_remaining - delta)
		if _phase_remaining <= 0:
			attack_phase = "recovery"
			_phase_remaining = float(attack_profile.recovery)
		_update_attack_visual()
	elif attack_phase == "recovery":
		_phase_remaining = maxf(0, _phase_remaining - delta)
		if _contacted: _advance_recoil(delta)
		if _phase_remaining <= 0: attack_phase = "idle"
		_update_attack_visual()

func _resolve_attack() -> void:
	if _dead or state != State.CHASING or attack_phase != "windup": return
	preparing_attack = false
	attack_phase = "strike"
	_phase_remaining = STRIKE_TIME
	# Interval is the wait after the strike, so a cycle is windup + interval.
	_attack_timer = float(attack_profile.interval)
	for marker in _warning_markers:
		if is_instance_valid(marker): marker.queue_free()
	_warning_markers.clear()
	_update_attack_visual()
	if ranged:
		var count := int(attack_profile.shots)
		for index in range(count):
			var angle := deg_to_rad((index - 1) * 20.0) if count == 3 else 0.0
			# Aim from the painted muzzle itself, so the shot lands on the locked
			# point rather than running parallel beside it.
			var aim := _locked_target - _muzzle
			aim.y = 0
			aim = aim.normalized() if aim.length_squared() > 0.001 else attack_direction
			var forward := aim.rotated(Vector3.UP, angle)
			# Cover between the shoulder and muzzle must also stop a shot.
			if game.line_of_sight(global_position, _muzzle):
				var shot := game.launch_enemy_projectile(_muzzle, _muzzle + forward, _pending_damage, str(attack_profile.projectile), float(attack_profile.reach))
				if shot != null: shot.shooter = self
			else:
				EnemyAttackVfx.spawn(game, global_position, forward, "wood")
		if enemy_type == "ice_hunter":
			EnemyAttackVfx.spawn(game, _muzzle, attack_direction, "muzzle")
			game.sound.play("enemy_ice_hunter", true)
	elif elite:
		if _flat_distance(game.player.global_position, pending_warning_position) <= pending_warning_radius and game.line_of_sight(global_position, game.player.global_position):
			game.player.take_damage(_pending_damage, damage_kind, self)
	else:
		_try_melee_hit()
		if enemy_type == "thug":
			var fx := EnemyAttackVfx.spawn(game, attack_origin + Vector3.UP * 0.2, attack_direction, "sector", float(attack_profile.reach))
			fx.owner_enemy = self
		elif enemy_type == "ice_warrior":
			var swing := EnemyAttackVfx.spawn(game, attack_origin + Vector3.UP * 0.2, attack_direction, "thrust", float(attack_profile.reach))
			swing.owner_enemy = self
			var impact := attack_origin + attack_direction * float(attack_profile.reach)
			# Do not show cracks on the far side of a wall.
			if game.line_of_sight(attack_origin, impact):
				impact.y = 0.08
				EnemyAttackVfx.spawn(game, impact, attack_direction, "ice")
		elif enemy_type == "brawler":
			var thrust := EnemyAttackVfx.spawn(game, global_position + Vector3.UP * 0.2, attack_direction, "thrust", float(attack_profile.reach) - float(attack_profile.dash))
			thrust.owner_enemy = self

func threatens(point: Vector3) -> bool:
	if elite: return _flat_distance(point, pending_warning_position) <= pending_warning_radius
	if ranged:
		var offset := point - global_position
		offset.y = 0
		return offset.dot(attack_direction) >= 0 and offset.length() <= float(attack_profile.reach) and absf(offset.cross(attack_direction).y) < 0.7
	return EnemyAttacks.contains(attack_profile, attack_origin, attack_direction, point)

func _try_melee_hit() -> void:
	if _hit_this_attack: return
	var length := float(attack_profile.reach)
	if attack_profile.has("dash"): length = length - float(attack_profile.dash) + _dash_travelled
	if EnemyAttacks.contains(attack_profile, attack_origin, attack_direction, game.player.global_position, length) and game.line_of_sight(attack_origin, game.player.global_position) and game.line_of_sight(global_position, game.player.global_position):
		_hit_this_attack = true
		var before := game.player.hp
		game.player.take_damage(_pending_damage, damage_kind, self)
		if enemy_type == "thug" and game.player.hp < before:
			var point := game.player.global_position
			point.y = 0.07
			EnemyAttackVfx.spawn(game, point, attack_direction, "cuts")

func _advance_lunge(delta: float) -> void:
	if _contacted: return
	var amount := minf(float(attack_profile.dash) - _dash_travelled, float(attack_profile.dash) * delta / STRIKE_TIME)
	while amount > 0.0001:
		if _touching_player():
			_begin_contact()
			return
		var step := minf(0.08, amount)
		if not _try_step(attack_direction, step): return
		_dash_travelled += step
		amount -= step
		_try_melee_hit()
	if _touching_player(): _begin_contact()

## Short swept steps validate navigation AND terrain. Never snap a lunge or
## recoil to a disconnected polygon or slide around a corner mid-attack.
func _try_step(direction: Vector3, step: float) -> bool:
	var candidate := global_position + direction * step
	if not game.world_map.is_navigation_ready(): return false
	var closest := NavigationServer3D.map_get_closest_point(game.world_map.navigation_map_rid(), candidate)
	closest.y = candidate.y
	if closest.distance_to(candidate) > 0.18 or not game.world_map._has_clearance(Vector2(candidate.x, candidate.z)) or not game.line_of_sight(global_position, candidate): return false
	global_position = candidate
	return true

## The lunging body has reached the player: she is ahead, inside the strip's
## width (plus her body), and within contact range.
func _touching_player() -> bool:
	var offset := game.player.global_position - global_position
	offset.y = 0
	var along := offset.dot(attack_direction)
	return along > -0.05 and along <= contact_distance() and absf(offset.cross(attack_direction).y) <= float(attack_profile.width) * 0.5 + 0.3

func contact_distance() -> float:
	return maxf(CONTACT_DISTANCE, float(attack_profile.reach) - float(attack_profile.dash))

func _begin_contact() -> void:
	_contacted = true
	# Reaching her is the hit, even where the swept strip has not caught up.
	if not _hit_this_attack and game.line_of_sight(global_position, game.player.global_position):
		_hit_this_attack = true
		game.player.take_damage(_pending_damage, damage_kind, self)
	attack_phase = "contact"
	_phase_remaining = CONTACT_TIME
	var point := global_position + attack_direction * (contact_distance() - 0.3)
	point.y = 0.4
	var fx := EnemyAttackVfx.spawn(game, point, attack_direction, "bite" if enemy_type == "slug" else "stab")
	fx.owner_enemy = self

func _advance_recoil(delta: float) -> void:
	var total := float(attack_profile.get("recoil", 0.0))
	var amount := minf(total - _recoil_travelled, total * delta / RECOIL_TIME)
	while amount > 0.0001:
		var step := minf(0.08, amount)
		if not _try_step(-attack_direction, step):
			_recoil_travelled = total
			return
		_recoil_travelled += step
		amount -= step

func _update_attack_visual() -> void:
	if elite or not is_instance_valid(_sprite): return
	match attack_phase:
		"windup": pose_frame = 1 if _attack_elapsed < START_TIME else 2
		"strike", "contact": pose_frame = 3
		"recovery": pose_frame = 4
		_: pose_frame = 0
	var walk_frame := posmod(int(walk_distance * WALK_FRAMES_PER_UNIT), 4)
	if has_walk and walking and attack_phase == "idle": _sprite.texture = FieldArt.enemy_walk_pose(enemy_type, dir_column, walk_frame)
	elif directional: _sprite.texture = FieldArt.enemy_dir_pose(enemy_type, dir_column, pose_frame)
	else: _sprite.texture = FieldArt.enemy_pose(int(attack_profile.row), pose_frame)
	_sprite.position.y = _art_base_y
	if directional: _sprite.flip_h = false
	_sprite.offset.x = 0 if directional else (-4 if _sprite.flip_h else 4)
	if attack_phase == "windup" and pose_frame == 2:
		_sprite.position.y += PIXEL if int(_attack_elapsed * 24) % 2 else 0.0
	elif attack_phase == "idle" and state in [State.CHASING, State.RETURNING] and not (has_walk and walking):
		# The walk frames carry their own step bob; only bob the idle pose.
		_sprite.position.y += 0.025 * sin(_bob_time * 10)
	if enemy_type == "slug" and attack_phase == "strike":
		_sprite.position.y += sin((1.0 - _phase_remaining / STRIKE_TIME) * PI) * 0.3
	var recoil := float(attack_profile.get("recoil", 0.0))
	if attack_phase == "contact":
		# The bite / stab lands: shove 1 texel into the target on alternate ticks.
		_sprite.offset.x += (1.0 if int(_phase_remaining * 60) % 2 else 0.0) * (-1.0 if _sprite.flip_h else 1.0)
	elif enemy_type == "slug" and attack_phase == "recovery" and _contacted and recoil > 0:
		_sprite.position.y += sin(clampf(_recoil_travelled / recoil, 0, 1) * PI) * 0.2
	var flashing := preparing_attack and (_windup_remaining <= 0.1 or _lock_flash > 0)
	_glint.visible = flashing
	_glint.scale = Vector3.ONE * (3.0 if enemy_type == "ice_hunter" and _lock_flash > 0 else 1.0)
	_breath.visible = enemy_type == "ice_warrior" and preparing_attack and pose_frame == 2
	var right := game.camera.global_basis.x if is_instance_valid(game.camera) else Vector3.RIGHT
	var up := game.camera.global_basis.y if is_instance_valid(game.camera) else Vector3.UP
	var facing := -1.0 if _sprite.flip_h else 1.0
	# Directional sheets carry their own weapon tip per column; no mirroring.
	var dir_tip: Vector2 = EnemyDirectionalData.TIPS[enemy_type][dir_column] if directional else Vector2.ZERO
	if directional: facing = 1.0
	if ranged:
		var tip: Vector2 = dir_tip if directional else MUZZLE_TEXELS.get(enemy_type, Vector2(22, -12))
		# Same screen spot as the painted tip, but reached with sideways offset
		# plus real height only: the shot's ground track stays on the shooter's
		# row instead of drifting north with the camera's up axis.
		var flat_right := Vector3(right.x, 0, right.z).normalized()
		_muzzle = global_position + Vector3.DOWN * 0.55 + flat_right * tip.x * facing * PIXEL + Vector3.UP * (-tip.y * PIXEL / maxf(up.y, 0.1))
		var cue: Vector2 = (tip * 0.55 if directional else SCOPE_TEXELS) if _lock_flash > 0 else tip
		_glint.global_position = global_position + Vector3.DOWN * 0.55 + right * cue.x * facing * PIXEL - up * cue.y * PIXEL
	else:
		var tip := Vector2(-7, -36) if enemy_type == "thug" else (Vector2(-3, -31) if enemy_type == "ice_warrior" else Vector2(-9, -13))
		if directional: tip = dir_tip
		if enemy_type == "slug":
			tip = Vector2(2, -3)
			_glint.visible = preparing_attack and (flashing or sin(_attack_elapsed * (16 + _attack_elapsed * 50)) > 0.4)
			_glint.material_override.albedo_color = Color("ffd875")
		_glint.global_position = global_position + Vector3.DOWN * 0.55 + right * tip.x * facing * PIXEL - up * tip.y * PIXEL
	_breath.global_position = global_position + Vector3.DOWN * 0.55 + right * facing * 0.55 + up * 1.15

## Applies this enemy's defence or resistance to a hit and returns the damage
## actually dealt (what lifesteal heals from). `pierce` ignores that share of
## defence (破甲刃纹, 致命瞄点). `quiet` hides the number (burn ticks too small
## to read would only add noise).
func take_hit(damage: float, kind: String = "phys", crit: bool = false, pierce: float = 0.0, quiet: bool = false) -> float:
	if _dead: return 0.0
	var dealt := CombatStats.mitigate(damage, kind, effective_defense() * (1.0 - clampf(pierce, 0.0, 1.0)), effective_res())
	health -= dealt
	_flash()
	if is_instance_valid(game) and not quiet:
		DamageNumber.spawn(game, global_position + Vector3.UP * (0.6 if elite else 0.2), str(roundi(dealt)) + ("!" if crit else ""), "crit" if crit else kind, crit)
	if is_instance_valid(_health_bar): _health_bar.set_ratio(health / maxf(max_health, 1.0))
	if health <= 0.0:
		_dead = true
		_cancel_attack()
		remove_from_group("enemies")
		remove_from_group("guards")
		if is_instance_valid(game):
			game.spawn_enemy_drops(self)
		died.emit(self)
		queue_free()
	elif is_instance_valid(game) and state != State.RETURNING:
		# Being hit is also perception, but cannot pull enemies beyond home.
		if behavior == Behavior.GUARD and is_instance_valid(guard_post):
			guard_post.alert_from_hit()
		elif _flat_distance(home_position, game.player.global_position) <= leash_radius:
			begin_chase()
	return dealt

func effective_defense() -> float:
	return defense * (1.0 - clampf(status_value("def_down"), 0.0, 1.0))

func effective_res() -> float:
	return res - status_value("res_down")

func status_value(status: String) -> float:
	return float(statuses[status].value) if statuses.has(status) else 0.0

## A stronger or equal application refreshes; a weaker one never shortens a stronger one.
func apply_status(status: String, seconds: float, value: float) -> void:
	if _dead: return
	if statuses.has(status) and float(statuses[status].value) > value and float(statuses[status].time) > 0.0: return
	if status == "burn" and not statuses.has("burn"): _burn_tick = 0.5
	statuses[status] = {"time": seconds, "value": value}

## 噤声印记: an ordinary enemy loses the attack it is winding up and cannot
## start another for `seconds`. Elites keep their telegraphed strike.
func interrupt(seconds: float) -> void:
	if _dead or elite: return
	if attack_phase == "windup": _cancel_attack()
	_attack_timer = maxf(_attack_timer, seconds)

func _tick_statuses(delta: float) -> void:
	if statuses.is_empty(): return
	if statuses.has("burn"):
		_burn_tick -= delta
		if _burn_tick <= 0.0:
			_burn_tick += 0.5
			take_hit(float(statuses.burn.value), "arts", false, 0.0, false)
			if _dead: return
	for status in statuses.keys():
		statuses[status].time = float(statuses[status].time) - delta
		if float(statuses[status].time) <= 0.0:
			statuses.erase(status)
			if status == "burn": _burn_tick = 0.0

func _flash() -> void:
	if not is_instance_valid(_sprite):
		return
	_sprite.modulate = Color(3.0, 3.0, 3.0)
	var tween := create_tween()
	tween.tween_interval(0.08)
	tween.tween_callback(func() -> void:
		if is_instance_valid(_sprite):
			_sprite.modulate = Color.WHITE
	)
