class_name Enemy
extends Node3D

## Body centre above the ground it stands on.
const GROUND_LIFT := 0.65

## Perception and anchored guard squads drive idle/chase/return states.
## Movement follows NavigationAgent3D with terrain-checked final steps.
## Ordinary attacks read through poses, facing and sounds; elites telegraph.

signal died(enemy: Enemy)

const CHASE_REPATH_INTERVAL := 0.3
const CHASE_REPATH_DISTANCE_SQ := 2.25
const PICK_LAYER := 4  # bit 3, dedicated to mouse-picking raycasts

var elite: bool = false
## An outpost leader or a bounty target: a boss bar on the HUD and a map mark.
var boss := false
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
## 损伤 gauges and damage over time (属性伤害与地区装备策划案 v1.1 §5, §6).
var elements := ElementState.new()
## Its elemental resistances, from its region, rank and kind (Elements.enemy_resists).
var _eres: Dictionary = {}
## 侵蚀爆发's permanent DEF cut, 15% a stack (3 at most).
var corr_stacks := 0
## Bursts waiting for the next tick, so a burst's own damage never runs inside the hit that filled it.
var _pending_bursts: Array[String] = []
## Relics that act on the first hit against an enemy (冻土绊索).
var hit_by_player := false
var move_speed: float = 2.1
var game: GameManager
enum Behavior { NORMAL, GUARD, PATROL }
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
## 威胁值 patrols (ThreatMeter): which wave it came with (0 = not a patrol); it
## wanders the floor, chases what it sees, and wanders on from where it lost her.
var patrol_wave := 0
## Called in by a boss or warden mid-fight (用户 2026-10-20): it drops nothing.
var called_in := false
var _wander_target := Vector3.INF
var _wander_time := 0.0
## 萨卡兹哨兵 (ThreatMeter): "watch" until it sees her; then "run" to a
## reachable spot with its "!" up; then "hold" there SENTINEL_HOLD s without
## running; then "watch" again. It never attacks.
var sentinel_mode := "watch"
var _hold_left := 0.0
var _run_time := 0.0
var _run_target := Vector3.INF

const ANIM_FRAME_TIME := 0.25

var _sprite: Sprite3D
var _seen_yaw := 0.0
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
## The sheet it is drawn with: its own type, or the one it borrows (装备扩充 §2.1).
var art_type := "thug"
## The sheet it is drawn from: its own eight-direction boards once they are in
## (art/install_n2_boards.py), otherwise art_type's. Sounds stay on art_type.
var sheet_type := "thug"
var attack_profile: Dictionary = {}
## Melee / projectile / ground casters: those that hold range (shoot or cast).
var keeps_distance := false
var _tint := Color.WHITE
# 装备扩充策划案 §2.1 / §7 mechanics.
var stun_timer := 0.0
var silence_timer := 0.0
var barrier_hp := 0.0
var _barrier_broken := false
## The barrier's look, shared with every other shield (BarrierFx).
var _shell: BarrierFx
var provoked := false
var herd := -1
var mimic_kind := ""
var _attack_count := 0
var _combo_left := 0
var _phased := false
## Which segment of a combo is winding up (寻仇者: thrust, back-cut, thrust).
var _combo_index := 0
## The ground warning of the attack under way: "circle" (pending_warning_*),
## "lane" (from attack_origin along attack_direction) or "" (none).
var warn_shape := ""
var warn_width := 0.0
var warn_length := 0.0
## 新敌人攻击案 §一第 6/7 条: the light ring round an unstoppable windup and
## the grey × over a silenced head.
var _outline: MeshInstance3D
var _silence_mark: Sprite3D
var _trail_timer := 0.0
var _chip_timer := 0.0
var _annihilating := false
var _special := ""
var _lasso_cd := 2.0
var _backstep_cd := 0.0
var _run_timer := 0.0
var _since_attack := 0.0
var _charge_travelled := 0.0
var _charge_hit := false
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
## While charging, every enemy but the sniper keeps turning to face Lappland at
## this rate, and strikes where it faces when the windup ends (用户 2026-10-07).
const WINDUP_TURN_DEG := 270.0
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
	attack_profile = EnemyAttacks.PROFILES[enemy_type]
	art_type = EnemyAttacks.art_type(enemy_type)
	elite = EnemyAttacks.is_elite_type(enemy_type)
	sheet_type = enemy_type if FieldArt.has_directional(enemy_type) else art_type
	# Elites without boards of their own keep the old single elite picture.
	directional = FieldArt.has_directional(sheet_type) and (not elite or sheet_type == enemy_type)
	has_walk = directional and FieldArt.has_walk(sheet_type)
	ranged = attack_profile.shape == "projectile"
	keeps_distance = ranged or str(attack_profile.shape) in ["ground", "lob"]
	# The tint only told borrowed sheets apart; its own art needs none.
	_tint = Color.WHITE if own_art() else attack_profile.get("tint", Color.WHITE)
	home_position = global_position
	perception_radius = 17.0 if art_type == "ice_hunter" else (14.0 if keeps_distance or attack_profile.get("alarm", false) else 10.0)
	name = attack_profile.name
	var stats: Dictionary = EnemyAttacks.STATS[enemy_type]
	max_health = float(stats.hp)
	health = max_health
	atk = float(stats.atk)
	defense = float(stats.def)
	res = float(stats.res)
	damage_kind = str(stats.kind)
	move_speed = (1.2 if elite else (2.4 if keeps_distance else 2.1)) * float(attack_profile.get("slow", 1.0))
	# 家族灭迹人 is quick in the dark (叙拉古敌人设计案 §三第 6 条: 1.1×).
	if attack_profile.get("stealth", false): move_speed = 2.3
	# 家族专用轿车 keeps to its lane's mouth: out on its charge and straight back.
	if attack_profile.get("roadblock", false):
		leash_radius = 0.6
		perception_radius = 8.0
	if attack_profile.has("barrier"): barrier_hp = max_health * float(attack_profile.barrier)
	_base_color = Color(0.65, 0.15, 0.12) if elite else (Color(0.25, 0.45, 1.0) if ranged else Color(0.8, 0.25, 0.18))
	_build_visual()
	_build_pick_area()
	_build_navigation()
	add_to_group("enemies")
	if attack_profile.get("alarm", false): add_to_group("sentinels")

func _build_visual() -> void:
	var height := 2.2 if elite else 1.8
	_sprite = Sprite3D.new()
	if directional: _sprite.texture = FieldArt.enemy_dir_pose(sheet_type, dir_column, 0)
	elif elite: _sprite.texture = FieldArt.enemy(game.region_id, true, false)
	else: _sprite.texture = FieldArt.enemy_pose(int(EnemyAttacks.PROFILES[art_type].row), 0)
	# Own boards are baked at the enemy's own height; "scale" only enlarged a borrowed sheet.
	_sprite.pixel_size = (height / _sprite.texture.get_height() if elite and not directional else PIXEL) * (1.0 if own_art() else float(attack_profile.get("scale", 1.0)))
	_sprite.modulate = _tint
	if attack_profile.has("barrier"):
		_shell = BarrierFx.new()
		_shell.colour = attack_profile.get("barrier_color", Color("9fc8ff"))
		_shell.size = 1.2 if elite else 1.0
		add_child(_shell)
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_art_base_y = height * 0.43 - 0.65 if elite and not directional else -0.55
	# Side-view cells centre the body at x=28, directional cells at x=32.
	if directional or not elite: _sprite.offset = Vector2(0 if directional else 4, 19)
	_sprite.position.y = _art_base_y
	_sprite.add_to_group("upright_sprites")
	# Sprites keep to their own render layer; a soft contact shadow under
	# its feet lands on the ground only (场景渲染统一改造案_v1 §4.6).
	_sprite.layers = LapplandAnimator3D.SPRITE_LAYER
	add_child(_sprite)
	var contact := Decal.new()
	var reach := 1.3 * (1.35 if elite else 1.0) * (1.0 if own_art() else float(attack_profile.get("scale", 1.0)))
	contact.size = Vector3(reach, 0.6, reach)
	contact.cull_mask = 1
	contact.texture_albedo = LapplandAnimator3D._contact_texture()
	add_child(contact)
	contact.position = Vector3(0, -0.65, 0)
	# Its life bar is the HUD's (界面策划案 §2.6). The old 3D bar it carried
	# showed itself again on every hit, so elites wore two bars.
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
	_outline = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(64, 64) * _sprite.pixel_size
	quad.center_offset = Vector3(_sprite.offset.x, _sprite.offset.y, 0.0) * _sprite.pixel_size
	_outline.mesh = quad
	var ring := ShaderMaterial.new()
	ring.shader = OUTLINE_SHADER
	_outline.material_override = ring
	_outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_outline.visible = false
	add_child(_outline)
	_silence_mark = Sprite3D.new()
	_silence_mark.texture = _silence_texture()
	_silence_mark.pixel_size = PIXEL
	_silence_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_silence_mark.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_silence_mark.no_depth_test = true
	_silence_mark.render_priority = 6
	_silence_mark.position.y = height + 0.4
	_silence_mark.visible = false
	add_child(_silence_mark)
	if attack_profile.has("incite"):
		_incite_mark = Sprite3D.new()
		_incite_mark.texture = _incite_texture()
		_incite_mark.pixel_size = PIXEL
		_incite_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_incite_mark.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_incite_mark.no_depth_test = true
		_incite_mark.render_priority = 6
		_incite_mark.position.y = height + 0.4
		_incite_mark.visible = false
		add_child(_incite_mark)
		_incite_cd = randf_range(2.0, 5.0)
	if attack_profile.get("roadblock", false):
		for i in range(2):
			var lamp := EnemyAttackVfx.part(self, Vector3.ZERO, Vector3.ONE * 3 * PIXEL, Color("fff6dc"))
			lamp.material_override.no_depth_test = true
			lamp.material_override.render_priority = 5
			lamp.visible = false
			_headlights.append(lamp)

const OUTLINE_SHADER := preload("res://game/sprite_outline.gdshader")
static var _silence_tex: ImageTexture
static var _incite_tex: ImageTexture

## 煽动's mark: a thin dark red ring, 9×9 (no words).
static func _incite_texture() -> ImageTexture:
	if _incite_tex == null:
		var image := Image.create(9, 9, false, Image.FORMAT_RGBA8)
		for x in range(9):
			for y in range(9):
				var d := Vector2(x - 4, y - 4).length()
				if d > 3.0 and d <= 4.2: image.set_pixel(x, y, Color("8a1c22"))
		_incite_tex = ImageTexture.create_from_image(image)
	return _incite_tex

## 3×3 grey ×.
static func _silence_texture() -> ImageTexture:
	if _silence_tex == null:
		var image := Image.create(3, 3, false, Image.FORMAT_RGBA8)
		for point in [Vector2i(0, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(0, 2), Vector2i(2, 2)]: image.set_pixelv(point, Color("9a9a9a"))
		_silence_tex = ImageTexture.create_from_image(image)
	return _silence_tex

## Its size against 暴徒's (FIGURES), for own boards; borrowed sheets stay 1.
func figure_scale() -> float:
	if not own_art(): return 1.0
	return clampf(float(EnemyAttacks.FIGURE_HEIGHTS.get(enemy_type, EnemyAttacks.BASE_FIGURE)) / EnemyAttacks.BASE_FIGURE, 0.75, 1.25)

func _advance_animation(delta: float) -> void:
	_bob_time += delta
	# The view turned (GameManager.camera_yaw): the way it faces in the world
	# is another column, or the other side, on screen now.
	if is_instance_valid(game) and game.camera_yaw != _seen_yaw and is_instance_valid(_sprite) and is_instance_valid(game.camera):
		_seen_yaw = game.camera_yaw
		var facing := -global_basis.z
		facing.y = 0.0
		if facing.length_squared() > 0.0001:
			if directional: _turn_to(facing.normalized(), true)
			else: _sprite.flip_h = facing.dot(game.camera.global_basis.x) < 0
	# Distance stepped since the previous tick decides walking vs standing.
	walking = _stepped > 0.0005
	# Backing up plays the walk board backwards.
	walk_distance += _stepped * (-1.0 if attack_phase == "reverse" else 1.0)
	_stepped = 0.0
	if directional or not elite:
		_update_attack_visual()
		return
	if is_instance_valid(_sprite):
		_sprite.position.y = _art_base_y + (0.025 if preparing_attack else 0.045) * sin(_bob_time * (4 if preparing_attack else 10))
		_sync_outline()
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
	# Generous to click: from the feet (-0.65) to a little over the head, and
	# wider than the figure, so a click on any of its drawn body lands.
	var width := (1.7 if own_art() else (2.2 if elite else 1.7)) * figure_scale()
	var top := maxf(head_height(), 1.0) + 0.25
	box_shape.size = Vector3(width, top + 0.65, width)
	shape.shape = box_shape
	shape.position.y = (top - 0.65) * 0.5
	area.add_child(shape)
	add_child(area)
	_pick_area = area

func _build_navigation() -> void:
	_nav_agent = NavigationAgent3D.new()
	_nav_agent.radius = (0.72 if own_art() else (1.0 if elite else 0.72)) * figure_scale()
	_nav_agent.height = (1.0 if own_art() else (1.4 if elite else 1.0)) * figure_scale()
	_nav_agent.path_desired_distance = 0.5
	_nav_agent.target_desired_distance = 0.5
	add_child(_nav_agent)

## 家族灭迹人's stealth (叙拉古敌人设计案 §二新增第 1 条): unseen past
## STEALTH_FAINT, a faint outline nearer, wholly seen within STEALTH_SHOW, while
## it attacks, and for STEALTH_HOLD after it was hit. Unseen it cannot be
## clicked (single-target attacks have nothing to pick).
const STEALTH_SHOW := 3.0
const STEALTH_FAINT := 6.0
const STEALTH_HOLD := 3.0
var _pick_area: Area3D
var _revealed := 0.0
var _splash_timer := 0.0
## Her heading as it reads it (where she last moved), for coming at her from behind.
var her_heading := Vector3.ZERO
var _her_last := Vector3.INF

## A reckoning's 灭迹人 does not wait to see her: it knows where she is.
func hunts() -> bool:
	return attack_profile.get("stealth", false) and patrol_wave > 0

## Behind her and to the side it is already on (§三第 6 条: 绕到玩家侧后方),
## EnemyAttacks.ERASER_FLANK_GAP from her. With no heading yet, from where it is.
func flank_point(player_position: Vector3) -> Vector3:
	var from_her := global_position - player_position
	from_her.y = 0.0
	var back := -her_heading if her_heading.length_squared() > 0.01 else (from_her.normalized() if from_her.length_squared() > 0.01 else Vector3.BACK)
	var side := back.cross(Vector3.UP)
	var aim := (back + side * (1.0 if from_her.dot(side) >= 0.0 else -1.0) * 0.8).normalized()
	return game.world_map.nearest_walkable(player_position + aim * EnemyAttacks.ERASER_FLANK_GAP)

func _read_heading(player_position: Vector3) -> void:
	if _her_last != Vector3.INF:
		var moved := player_position - _her_last
		moved.y = 0.0
		if moved.length_squared() > 0.0001: her_heading = (her_heading * 0.8 + moved.normalized() * 0.2).normalized()
	_her_last = player_position

func stealthed() -> bool:
	if not attack_profile.get("stealth", false) or _dead: return false
	if _revealed > 0.0 or attack_phase != "idle": return false
	return _flat_distance(global_position, game.player.global_position) > STEALTH_SHOW

func _tick_stealth(delta: float) -> void:
	if not attack_profile.get("stealth", false) or not is_instance_valid(_sprite): return
	_revealed = maxf(0.0, _revealed - delta)
	var hidden := stealthed()
	var faint := hidden and _flat_distance(global_position, game.player.global_position) <= STEALTH_FAINT
	_sprite.modulate.a = 0.15 if faint else (0.0 if hidden else 1.0)
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED if hidden else SpriteBase3D.ALPHA_CUT_DISCARD
	if is_instance_valid(_pick_area): _pick_area.collision_layer = 0 if hidden else PICK_LAYER
	_read_heading(game.player.global_position)
	# Far off in the rain, all there is of it is a splash where it steps (§二新增第 1 条).
	_splash_timer = maxf(0.0, _splash_timer - delta)
	if hidden and not faint and walking and _splash_timer <= 0.0 and str(game.world_map.weather) == "rain":
		_splash_timer = EnemyAttacks.ERASER_SPLASH_EVERY
		EnemyAttackVfx.spawn(game, Vector3(global_position.x, game.ground_y(global_position) + 0.04, global_position.z), -global_basis.z, "splash")

func _physics_process(delta: float) -> void:
	if _dead or (is_instance_valid(game) and not game.simulation_active()): return
	if not is_instance_valid(game) or not is_instance_valid(game.player): return
	_tick_stealth(delta)
	if hitstop_remaining > 0:
		hitstop_remaining = maxf(0, hitstop_remaining - delta)
		return
	silence_timer = maxf(0.0, silence_timer - delta)
	if is_instance_valid(_silence_mark): _silence_mark.visible = silenced()
	if is_instance_valid(_incite_mark): _incite_mark.visible = attack_phase == "incite"
	if stun_timer > 0.0:
		stun_timer = maxf(0.0, stun_timer - delta)
		_tick_statuses(delta)
		return
	_advance_animation(delta)
	_tick_statuses(delta)
	if _dead: return
	_tick_specials(delta)
	if _dead: return
	_sync_shell()
	_attack_timer = maxf(0, _attack_timer - delta)
	_rearm_timer = maxf(0, _rearm_timer - delta)
	var player_position: Vector3 = game.player.global_position
	if attack_profile.get("alarm", false):
		_tick_sentinel(delta, player_position)
		return
	if attack_profile.get("roadblock", false):
		_tick_roadblock(delta, player_position)
		return
	if behavior == Behavior.GUARD:
		if not is_instance_valid(guard_post):
			if state == State.CHASING: begin_return()
		elif state == State.CHASING and (not guard_post.active or _flat_distance(global_position, guard_post.global_position) > guard_post.leash_radius):
			begin_return()
	elif behavior == Behavior.PATROL:
		if state == State.IDLE and _rearm_timer <= 0 and (hunts() or _can_perceive(player_position)):
			begin_chase()
		elif state == State.CHASING:
			if hunts() or _can_perceive(player_position):
				_last_seen_position = player_position
				_lost_sight_time = 0
			else:
				_lost_sight_time += delta
				if _lost_sight_time >= sight_memory: _resume_patrol()
	else:
		if state == State.IDLE and _rearm_timer <= 0 and (provoked or not attack_profile.get("neutral", false)) and _can_perceive(player_position):
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
	if behavior == Behavior.PATROL and state == State.IDLE:
		_wander(delta)
		return
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
	if behavior == Behavior.GUARD or hunts() or _can_perceive(player_position):
		_last_seen_position = player_position
	var target := _last_seen_position
	# 残影: for a moment it goes for the afterimage and does not swing.
	if _decoy_time > 0.0:
		_decoy_time -= delta
		_move_toward_target(_decoy_point, delta)
		return
	# Unseen, a 灭迹人 goes round to come at her from behind.
	if stealthed() and hunts(): target = flank_point(player_position)
	var distance := _flat_distance(global_position, player_position)
	var desired_distance := float(attack_profile.reach) - (2.0 if keeps_distance else 0.3)
	if attack_phase == "idle" and _try_special(distance, visible_player): return
	if attack_phase == "idle":
		# Ranged enemies must navigate around cover even inside firing range.
		if distance > desired_distance or not visible_player or target != _last_seen_position:
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

## 疾影's 残影 draws it to `point` for `seconds`.
var _decoy_point := Vector3.ZERO
var _decoy_time := 0.0

func decoy(point: Vector3, seconds: float) -> void:
	if _dead or boss: return
	_decoy_point = point
	_decoy_time = seconds

## 萨卢佐家族的旧徽记: elites pick her out from further off.
const CREST_SIGHT := 1.5

func _can_perceive(point: Vector3) -> bool:
	# 林隐 / 无声 (前缀放大与特效阶等案 §3): she slips out of sight.
	if game.player != null and game.player.families != null and game.player.families.concealed_from(_flat_distance(global_position, point)): return false
	var reach := perception_radius * (CREST_SIGHT if elite and game.player != null and game.player.equipped_effect("saluzzo_crest") else 1.0) * game.feud_sight(self)
	return _flat_distance(global_position, point) <= reach and _flat_distance(home_position, point) <= leash_radius and game.line_of_sight(global_position, point)

## force: its post has woken, so it turns back even on the way home.
func begin_chase(force: bool = false) -> void:
	# Seen or hit, a sentinel on watch runs; mid-run or holding, nothing changes.
	if attack_profile.get("alarm", false):
		if not _dead and sentinel_mode == "watch": _spot()
		return
	if _dead: return
	if not force and (state == State.RETURNING or _rearm_timer > 0): return
	# One guard up wakes its whole post (用户 2026-10-18).
	if not force and behavior == Behavior.GUARD and is_instance_valid(guard_post) and not guard_post.active:
		guard_post._activate()
		return
	_rearm_timer = 0
	if attack_profile.get("neutral", false) and not provoked: return
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

func configure_patrol(wave: int) -> void:
	behavior = Behavior.PATROL
	patrol_wave = wave
	# No home to keep to: anywhere on the floor is its ground.
	leash_radius = 1.0e6
	add_to_group("patrols")

## A wanderer (GameManager._spawn_wanderers): a patrol's walk with none of a
## patrol's wave (its drops are an ordinary enemy's; the minimap leaves it out).
func configure_wander() -> void:
	behavior = Behavior.PATROL
	leash_radius = 1.0e6
	add_to_group("wanderers")

func _resume_patrol() -> void:
	state = State.IDLE
	_cancel_attack()
	home_position = global_position
	_wander_target = Vector3.INF
	_rearm_timer = 0.6
	_repath_timer = 0

## Walks from waypoint to waypoint (GameManager.patrol_waypoint), a new one on
## arrival or after a while stuck.
func _wander(delta: float) -> void:
	_wander_time += delta
	if _wander_target == Vector3.INF or _flat_distance(global_position, _wander_target) < 0.8 or _wander_time > 20.0:
		_wander_target = game.patrol_waypoint(global_position)
		_wander_time = 0.0
	_move_toward_target(_wander_target, delta)

const SIGNAL_BEAT := 0.4
const SIGNAL_RECOVER := 0.4

## Its red "!" is up (and the meter fills faster): from seeing her to the end of its hold.
func alerted() -> bool:
	return attack_profile.get("alarm", false) and not _dead and sentinel_mode != "watch"

func _tick_sentinel(delta: float, player_position: Vector3) -> void:
	match sentinel_mode:
		"watch":
			state = State.IDLE
			if _can_perceive(player_position): _spot()
		"run":
			_run_time += delta
			if _flat_distance(global_position, _run_target) < 0.8 or _run_time > 15.0:
				sentinel_mode = "hold"
				state = State.IDLE
				_hold_left = ThreatMeter.SENTINEL_HOLD
				home_position = global_position
			elif _run_time < ThreatMeter.SENTINEL_STARTLE:
				var to_her := player_position - global_position
				to_her.y = 0.0
				if to_her.length_squared() > 0.0001: _face(to_her.normalized(), delta)
			else:
				_move_toward_target(_run_target, delta)
		"hold":
			_hold_left -= delta
			# Signalling toward her while she is about.
			var to_her := player_position - global_position
			to_her.y = 0.0
			if to_her.length_squared() > 0.0001: _face(to_her.normalized(), delta)
			if _hold_left <= 0.0: sentinel_mode = "watch"

## 家族专用轿车 (§三第 7 条) idles in its slot, nose out, and never chases: with
## her within CAR_SIGHT ahead of its nose it winds up, charges out along the
## nose, and backs straight in again (the "reverse" phase).
func _tick_roadblock(delta: float, player_position: Vector3) -> void:
	if attack_phase != "idle":
		_tick_attack(delta)
		return
	global_position = home_position
	if nose.length_squared() > 0.01: _face(nose, delta)
	_update_attack_visual()
	if _attack_timer > 0.0: return
	var ahead := nose.normalized() if nose.length_squared() > 0.01 else -global_basis.z
	var offset := player_position - global_position
	offset.y = 0.0
	var along := offset.dot(ahead)
	if along < 0.0 or along > EnemyAttacks.CAR_SIGHT or absf(offset.cross(ahead).y) > EnemyAttacks.CAR_SIGHT_WIDTH: return
	if not game.line_of_sight(global_position, player_position): return
	state = State.CHASING
	_begin_telegraphed_attack()

func _spot() -> void:
	sentinel_mode = "run"
	state = State.CHASING
	_run_time = 0.0
	_run_target = _run_spot(game.player.global_position)
	_repath_timer = 0.0
	_last_destination = Vector3.INF
	game.on_sentinel_spotted(self)

## Of 16 directions at three distances, the walkable spot the navmesh can
## reach from here that lies farthest from her.
func _run_spot(player_position: Vector3) -> Vector3:
	var rid: RID = game.world_map.navigation_map_rid()
	var from := NavigationServer3D.map_get_closest_point(rid, global_position)
	var best := global_position
	var best_gap := -1.0
	for reach in [ThreatMeter.SENTINEL_RUN_MAX, (ThreatMeter.SENTINEL_RUN_MIN + ThreatMeter.SENTINEL_RUN_MAX) * 0.5, ThreatMeter.SENTINEL_RUN_MIN]:
		for i in range(16):
			var spot: Vector3 = game.world_map.nearest_walkable(global_position + Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 16.0) * reach)
			if _flat_distance(spot, global_position) < ThreatMeter.SENTINEL_RUN_MIN * 0.6: continue
			var to := NavigationServer3D.map_get_closest_point(rid, spot)
			var path := NavigationServer3D.map_get_path(rid, from, to, true)
			if path.is_empty() or path[-1].distance_to(to) > 1.0: continue
			var gap := _flat_distance(spot, player_position)
			if gap > best_gap:
				best_gap = gap
				best = spot
	return best

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
		_step_toward(direction.normalized(), minf(delta, direction.length() / current_speed()))

func _cancel_attack() -> void:
	preparing_attack = false
	_windup_remaining = 0
	attack_phase = "idle"
	_phase_remaining = 0
	_lock_flash = 0
	for marker in _warning_markers:
		if is_instance_valid(marker): marker.queue_free()
	_warning_markers.clear()
	if (directional or not elite) and is_instance_valid(_sprite): _update_attack_visual()

## The top of the figure as drawn, above its origin: the painted pixels of
## its current pose, not a fixed height, so a tall one (恫吓者) wears its life
## bar (and a sentinel its red "!") over its head, not on its face (用户 2026-10-17). Read
## once per sheet from the first pose shown.
static var _tops := {}
## The point just over its head in the world: the sprite faces the camera, so
## its top is up the camera's up axis from the sprite's centre, not straight up.
func head_point(gap: float = 0.0) -> Vector3:
	var up := game.camera.global_basis.y if is_instance_valid(game) and is_instance_valid(game.camera) else Vector3.UP
	if not is_instance_valid(_sprite) or _sprite.texture == null: return global_position + Vector3.UP * (1.9 + gap)
	return global_position + Vector3.UP * _sprite.position.y + up * (head_height() - _sprite.position.y + gap)

func head_height() -> float:
	if not is_instance_valid(_sprite) or _sprite.texture == null: return 1.9
	var key := sheet_type + ("@d" if directional else "") + "@%.4f" % _sprite.pixel_size
	if not _tops.has(key):
		var image := _sprite.texture.get_image()
		var first := 0
		if image != null:
			var found := false
			for y in range(image.get_height()):
				for x in range(image.get_width()):
					if image.get_pixel(x, y).a > 0.5:
						found = true
						break
				if found: break
				first += 1
			# From the cell's centre (where the sprite sits) up to the topmost
			# painted texel.
			_tops[key] = (image.get_height() * 0.5 - first + _sprite.offset.y) * _sprite.pixel_size
		else:
			_tops[key] = 2.4
	return _sprite.position.y + float(_tops[key])

func _step_toward(direction: Vector3, delta: float) -> void:
	var candidate := global_position + direction * current_speed() * (1.0 - status_value("slow")) * delta
	if is_instance_valid(game) and game.world_map.is_navigation_ready():
		var closest := NavigationServer3D.map_get_closest_point(game.world_map.navigation_map_rid(), candidate)
		closest.y = game.ground_y(closest) + GROUND_LIFT
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

var _in_combo := false
var _windup_total := 1.0
## 家族角头's 近身一掌 is the attack under way (EnemyAttacks profile "close").
var close_strike := false
## 家族专用轿车: the way its nose points out of its slot (GameManager._spawn_car).
var nose := Vector3.ZERO
var _reverse_from := Vector3.ZERO
var _headlights: Array[MeshInstance3D] = []
## 家族术师's 煽动 (attack_phase "incite"): time left, hits taken, time to the next.
var _incite_left := 0.0
var _incite_hits := 0
var _incite_cd := 0.0
var _incite_mark: Sprite3D

## Shown on the ground before it lands: elites, ground casts and lobs.
func telegraphs() -> bool:
	return elite or str(attack_profile.shape) in ["ground", "lob", "circle"]

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
	# 家族专用轿车 cannot turn in its slot: it charges the way its nose points.
	if attack_profile.get("roadblock", false) and nose.length_squared() > 0.01:
		attack_direction = nose.normalized()
		_locked_target = global_position + attack_direction * float(attack_profile.reach)
		_face(attack_direction, 1.0)
	_special = ""
	# 家族角头 with her close by: 近身一掌 instead of the cigar (§三第 5 条).
	close_strike = attack_profile.has("close") and not _in_combo and _flat_distance(global_position, game.player.global_position) <= float(attack_profile.close.trigger)
	if not _in_combo:
		_combo_index = 0
		if attack_profile.has("combo"): _combo_left = int(attack_profile.combo) - 1 + (1 if _phased else 0)
	var segment := current_segment()
	_windup_remaining = 0.45 if _in_combo else float(segment.windup)
	_windup_total = _windup_remaining
	_pending_damage = atk * float(segment.damage) * (1.0 + game.pressure / EnemyAttacks.PRESSURE_DIVISOR) * game.enemy_attack_multiplier() * game.feud_damage(self)
	warn_shape = ""
	pending_warning_position = _locked_target if telegraphs() else attack_origin
	pending_warning_radius = float(segment.get("radius", 0.0))
	var rim := unstoppable_now()
	if str(segment.shape) in ["charge", "lane"] and telegraphs():
		# A strip from its feet: 欺凌者's charge, 寻仇者's thrust. It holds still,
		# so the strike goes where the strip points.
		warn_shape = "lane"
		warn_width = float(segment.width)
		warn_length = float(segment.reach)
		pending_warning_position = attack_origin + attack_direction * warn_length * 0.5
		pending_warning_radius = warn_length * 0.5
		_warning_markers.append(game.spawn_warning_lane(attack_origin, attack_origin + attack_direction * warn_length, _windup_remaining, warn_width, warn_length, rim))
	elif str(segment.shape) == "self":
		warn_shape = "circle"
		pending_warning_position = attack_origin
		_warning_markers.append(game.spawn_warning_area(pending_warning_position, pending_warning_radius, _windup_remaining, rim))
	elif telegraphs() and str(segment.shape) != "lob":
		# A bottle's landing is only marked once it is thrown (§三第 8 条).
		warn_shape = "circle"
		_warning_markers.append(game.spawn_warning_area(pending_warning_position, pending_warning_radius, _windup_remaining, rim))
	for marker in _warning_markers: marker.hitstop_owner = self
	if rim and attack_profile.has("stun_every"): game.sound.play("stun_hum")
	_update_attack_visual()

## The attack this windup belongs to: the profile itself, or a combo segment
## of it (寻仇者). A segment fills in only what differs from the profile.
func current_segment() -> Dictionary:
	if close_strike:
		var palm: Dictionary = attack_profile.duplicate()
		palm.merge(attack_profile.close, true)
		return palm
	var segments: Array = attack_profile.get("segments", [])
	if segments.is_empty(): return attack_profile
	var segment: Dictionary = attack_profile.duplicate()
	segment.merge(segments[_combo_index % segments.size()], true)
	return segment

## `keep`: a tracking windup following whoever it first turned on.
func _lock_direction(keep: bool = false) -> void:
	if not keep: _aim_civilian = null
	if keep: _locked_target = _aim_civilian.global_position if is_instance_valid(_aim_civilian) else game.player.global_position
	else: _locked_target = _aim_target()
	attack_direction = _locked_target - global_position
	attack_direction.y = 0
	attack_direction = attack_direction.normalized() if attack_direction.length_squared() > 0.001 else Vector3.RIGHT
	_face(attack_direction, 1.0)

var _aim_civilian: Node3D
## Its blow goes at her; on 扎罗's piazza a 叙拉古平民 within its reach may
## take it instead, on BossCatalog.CIVILIAN_TARGET_CHANCE (用户 2026-10-20).
func _aim_target() -> Vector3:
	var her_at := game.player.global_position
	if attack_profile.get("neutral", false) or attack_profile.get("roadblock", false): return her_at
	var reach := float(attack_profile.get("reach", 1.5)) + 0.3
	for c in get_tree().get_nodes_in_group("civilians"):
		if c == self or not is_instance_valid(c) or c._dead or c.fleeing or _flat_distance(c.global_position, global_position) > reach: continue
		if game.rng.randf() < BossCatalog.CIVILIAN_TARGET_CHANCE:
			_aim_civilian = c
			return c.global_position
		break
	return her_at

## Each 平民 its blow reaches: 血债, and it cringes and runs.
func _strike_civilians() -> void:
	for c in get_tree().get_nodes_in_group("civilians"):
		if c == self or not is_instance_valid(c) or c._dead: continue
		if threatens(c.global_position): c.struck()

## One step of turning toward her (WINDUP_TURN_DEG). No longer used in a
## windup (用户 2026-10-14: 敌人不能甩枪); kept for whatever turns between attacks.
func _turn_toward_player(delta: float) -> void:
	var to := game.player.global_position - global_position
	to.y = 0
	if to.length_squared() < 0.001: return
	var turn := attack_direction.signed_angle_to(to.normalized(), Vector3.UP)
	var limit := deg_to_rad(WINDUP_TURN_DEG) * delta
	attack_direction = attack_direction.rotated(Vector3.UP, clampf(turn, -limit, limit)).normalized()
	_locked_target = global_position + attack_direction * to.length()
	_face(attack_direction, 1.0)

func _tick_attack(delta: float) -> void:
	if attack_phase == "windup":
		var previous := _attack_elapsed
		_attack_elapsed += delta
		_windup_remaining = maxf(0, _windup_total - _attack_elapsed)
		if not _aim_locked:
			# Track only before the 0.7s boundary, then hold that last direction
			# for the entire 0.5s reaction window, including the firing tick.
			if previous < float(attack_profile.track): _lock_direction(true)
			if _attack_elapsed >= float(attack_profile.track):
				_aim_locked = true
				# The only read on the sniper: make the lock unmissable.
				_lock_flash = 0.20
		# 用户 2026-10-14: 敌人不能甩枪 — no turning during the windup: it strikes
		# the way it faced when it began, and its red ground stays where it was
		# laid. Only the sniper's track-then-lock (above) follows her, and it
		# locks well before the shot.
		if _windup_remaining <= 0.1 and not _cue_played:
			_cue_played = true
			var cue := _cue_name()
			if cue != "": game.sound.play(cue)
		_update_attack_visual()
		_lock_flash = maxf(0, _lock_flash - delta)
		if _windup_remaining <= 0:
			if _special == "lasso": _resolve_lasso()
			else: _resolve_attack()
	elif attack_phase == "strike":
		_phase_remaining = maxf(0, _phase_remaining - delta)
		if str(attack_profile.shape) == "charge" and _special == "":
			_advance_charge(delta)
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
		if _phase_remaining <= 0:
			attack_phase = "idle"
			# The car backs straight into its slot, nose still out (§三第 7 条).
			if attack_profile.get("roadblock", false) and _flat_distance(global_position, home_position) > 0.05:
				attack_phase = "reverse"
				_phase_remaining = EnemyAttacks.CAR_REVERSE_TIME
				_reverse_from = global_position
		_update_attack_visual()
	elif attack_phase == "reverse":
		_phase_remaining = maxf(0, _phase_remaining - delta)
		var next := _reverse_from.lerp(home_position, 1.0 - _phase_remaining / EnemyAttacks.CAR_REVERSE_TIME)
		_stepped += _flat_distance(next, global_position)
		global_position = next
		if _phase_remaining <= 0:
			global_position = home_position
			attack_phase = "idle"
		_update_attack_visual()
	elif attack_phase == "incite":
		_incite_left -= delta
		var to_her := game.player.global_position - global_position
		to_her.y = 0.0
		if to_her.length_squared() > 0.0001: _face(to_her.normalized(), delta)
		game.add_debt(float(attack_profile.incite) * minf(delta, _incite_left + delta))
		if _incite_left <= 0.0: _end_incite()
		_update_attack_visual()

func _resolve_attack() -> void:
	if _dead or state != State.CHASING or attack_phase != "windup": return
	_strike_civilians()
	preparing_attack = false
	attack_phase = "strike"
	_phase_remaining = STRIKE_TIME
	# Interval is the wait after the strike, so a cycle is windup + interval.
	_attack_timer = float(attack_profile.interval) * (0.75 if status_value("haste") > 0.0 else 1.0)
	_attack_count += 1
	_since_attack = 0.0
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
				if shot != null:
					shot.shooter = self
					if attack_profile.get("reckoning_arts", false) and shot_kind() == "arts": shot.make_arts()
			else:
				EnemyAttackVfx.spawn(game, global_position, forward, "wood")
		if art_type == "ice_hunter":
			EnemyAttackVfx.spawn(game, _muzzle, attack_direction, "muzzle")
			game.sound.play("enemy_ice_hunter", true)
		if attack_profile.has("haste_bounce") and not silenced(): _haste_nearest()
	elif str(attack_profile.shape) == "charge":
		_charge_travelled = 0.0
		_charge_hit = false
		_phase_remaining = float(attack_profile.reach) / CHARGE_SPEED + 0.05
	elif str(attack_profile.shape) == "lob":
		_throw_bottle()
	elif telegraphs():
		var stunning := _stuns_this_attack()
		if in_warning(game.player.global_position) and game.line_of_sight(global_position, game.player.global_position):
			var before := game.player.hp
			game.player.take_damage(_pending_damage, damage_kind, self)
			if stunning and game.player.hp < before: game.player.apply_control("stun", attack_direction, 0.0, float(attack_profile.get("stun", 0.8)))
		_telegraph_vfx(stunning)
		# The next segment of a combo is marked the moment this one lands and
		# strikes 0.45 s later (新敌人攻击案 §六第 3 条).
		if _combo_left > 0 and not silenced() and state == State.CHASING:
			_combo_left -= 1
			_combo_index += 1
			attack_phase = "idle"
			_in_combo = true
			_begin_telegraphed_attack()
			_in_combo = false
	else:
		_try_melee_hit()
		if enemy_type == "shield":
			EnemyAttackVfx.spawn(game, attack_origin + attack_direction * 0.7 + Vector3.UP * 0.5, attack_direction, "shield_flash")
		elif enemy_type == "slug_volatile":
			var claws := attack_origin + attack_direction * 1.2
			claws.y = 0.07
			if game.line_of_sight(attack_origin, claws): EnemyAttackVfx.spawn(game, claws, attack_direction, "claw_cracks")
		elif str(attack_profile.shape) == "sector":
			var fx := EnemyAttackVfx.spawn(game, attack_origin + Vector3.UP * 0.2, attack_direction, "sector", float(attack_profile.reach), float(attack_profile.angle))
			fx.owner_enemy = self
		elif str(attack_profile.shape) == "ice":
			var swing := EnemyAttackVfx.spawn(game, attack_origin + Vector3.UP * 0.2, attack_direction, "thrust", float(attack_profile.reach))
			swing.owner_enemy = self
			var impact := attack_origin + attack_direction * float(attack_profile.reach)
			# Do not show cracks on the far side of a wall.
			if game.line_of_sight(attack_origin, impact):
				impact.y = game.ground_y(impact) + 0.08
				EnemyAttackVfx.spawn(game, impact, attack_direction, "ice")
		elif str(attack_profile.shape) == "lane" and art_type != "slug":
			var thrust := EnemyAttackVfx.spawn(game, global_position + Vector3.UP * 0.2, attack_direction, "thrust", float(attack_profile.reach) - float(attack_profile.dash))
			thrust.owner_enemy = self

## What its shots deal: 家族弩手's bolts are arts in the 清算时刻 (§三第 3 条).
func shot_kind() -> String:
	if attack_profile.get("reckoning_arts", false) and game.reckoning(): return "arts"
	return damage_kind

func threatens(point: Vector3) -> bool:
	if attack_phase in ["incite", "reverse"]: return false
	if _special == "lasso" or str(attack_profile.shape) == "charge":
		var lane := point - attack_origin
		lane.y = 0
		var along := lane.dot(attack_direction)
		return along >= 0.0 and along <= (9.6 if _special == "lasso" else float(attack_profile.reach) + 0.6) and absf(lane.cross(attack_direction).y) <= float(attack_profile.get("width", 1.2)) * 0.5 + 0.3
	if telegraphs(): return in_warning(point)
	if ranged:
		var offset := point - global_position
		offset.y = 0
		return offset.dot(attack_direction) >= 0 and offset.length() <= float(attack_profile.reach) and absf(offset.cross(attack_direction).y) < 0.7
	return EnemyAttacks.contains(attack_profile, attack_origin, attack_direction, point)

## Inside the red ground of the attack under way.
func in_warning(point: Vector3) -> bool:
	if warn_shape == "lane":
		var offset := point - attack_origin
		offset.y = 0
		var along := offset.dot(attack_direction)
		return along >= 0.0 and along <= warn_length and absf(offset.cross(attack_direction).y) <= warn_width * 0.5
	return _flat_distance(point, pending_warning_position) <= pending_warning_radius

## What a telegraphed strike leaves on the ground (新敌人攻击案 §四).
func _telegraph_vfx(stunning: bool) -> void:
	var ground := Vector3(pending_warning_position.x, game.ground_y(pending_warning_position) + 0.08, pending_warning_position.z)
	match enemy_type:
		"armed": EnemyAttackVfx.spawn(game, ground, attack_direction, "ground_shock", pending_warning_radius)
		"greytail_lord": EnemyAttackVfx.spawn(game, ground, attack_direction, "ground_shock_purple", pending_warning_radius)
		"breacher": EnemyAttackVfx.spawn(game, ground, attack_direction, "ground_shock_big" if stunning else "ground_shock", pending_warning_radius)
		"caster": EnemyAttackVfx.spawn(game, ground, attack_direction, "crystal_spikes", pending_warning_radius)
		"distorted_caster": EnemyAttackVfx.spawn(game, ground, attack_direction, "rune", pending_warning_radius)
		"family_capo": EnemyAttackVfx.spawn(game, ground, attack_direction, "ember_ring", pending_warning_radius)
		"shattered_champion": EnemyAttackVfx.spawn(game, ground + Vector3.UP * 0.2, attack_direction if _combo_index % 2 == 0 else -attack_direction, "splinter_arc", pending_warning_radius)
		"avenger":
			if warn_shape == "lane": EnemyAttackVfx.spawn(game, attack_origin + Vector3.UP * 0.2, attack_direction, "slash_line", warn_length)
			else: EnemyAttackVfx.spawn(game, attack_origin + Vector3.UP * 0.2, attack_direction, "slash_arc", pending_warning_radius)

## 燃烧瓶投掷者: the bottle flies 0.6 s to where she stands now; the red circle
## goes down with the throw and stays until it lands.
func _throw_bottle() -> void:
	var target := game.player.global_position
	target.y = game.ground_y(target)
	pending_warning_position = target
	var landing := game.spawn_warning_area(target, pending_warning_radius, Molotov.FLIGHT)
	var bottle := Molotov.new()
	bottle.game = game
	bottle.source = self
	bottle.start = global_position + Vector3.UP * 0.4
	bottle.target = target
	bottle.radius = pending_warning_radius
	bottle.damage = _pending_damage
	bottle.kind = damage_kind
	bottle.fire_time = 0.0 if silenced() else float(attack_profile.get("fire_time", 3.0))
	# 火区每次 0.2: a fifth of an unweighted hit, whatever the bottle itself weighs.
	bottle.fire_damage = _pending_damage / maxf(float(attack_profile.damage), 0.01) * 0.2
	bottle.warning = landing
	game.add_child(bottle)

## Its own release cue when there is one (enemy_<id>, 新敌人攻击案 §五), else the
## sheet it borrows; the old elite has none.
func _cue_name() -> String:
	var own := "enemy_" + enemy_type
	if is_instance_valid(game.sound) and game.sound.streams.has(own): return own
	return "" if elite else "enemy_" + art_type

func _try_melee_hit() -> void:
	if _hit_this_attack: return
	var length := float(attack_profile.reach)
	if attack_profile.has("dash"): length = length - float(attack_profile.dash) + _dash_travelled
	if EnemyAttacks.contains(attack_profile, attack_origin, attack_direction, game.player.global_position, length) and game.line_of_sight(attack_origin, game.player.global_position) and game.line_of_sight(global_position, game.player.global_position):
		_hit_this_attack = true
		var before := game.player.hp
		game.player.take_damage(_pending_damage, damage_kind, self)
		if attack_profile.has("knockback") and game.player.hp < before: game.player.apply_control("knockback", attack_direction, float(attack_profile.knockback), 0.3)
		if art_type == "thug" and game.player.hp < before:
			var point := game.player.global_position
			point.y = game.ground_y(point) + 0.07
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
	candidate.y = game.ground_y(candidate) + GROUND_LIFT
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
		var before := game.player.hp
		game.player.take_damage(_pending_damage, damage_kind, self)
		# 岩角兽's horn butt shoves her back (用户 2026-10-11: 低头用角顶).
		if attack_profile.has("knockback") and game.player.hp < before: game.player.apply_control("knockback", attack_direction, float(attack_profile.knockback), 0.3)
	attack_phase = "contact"
	_phase_remaining = CONTACT_TIME
	var point := global_position + attack_direction * (contact_distance() - 0.3)
	point.y = 0.4
	var kind := "bite" if art_type == "slug" else "stab"
	if enemy_type == "shell_vine": kind = "vine_burst"
	elif enemy_type == "rock_hornbeast": kind = "horn_arc"
	var fx := EnemyAttackVfx.spawn(game, point, attack_direction, kind)
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
	if (elite and not directional) or not is_instance_valid(_sprite): return
	match attack_phase:
		"windup": pose_frame = 1 if _attack_elapsed < START_TIME else 2
		"strike", "contact": pose_frame = 3
		"recovery": pose_frame = 4
		_: pose_frame = 0
	# A combo's second cut winds up from the RECOVER pose (寻仇者's back-cut,
	# 木裂战士's turn): that row is the second segment (新敌人攻击案 §三第 10/14 条).
	if attack_phase == "windup" and _combo_index % 2 == 1: pose_frame = 4
	# The sixth row: 纠察官's lasso throw, 歪曲施法者's glide.
	var extra: String = EnemyN2Data.EXTRA_ROW.get(sheet_type, "")
	if extra == "lasso" and _special == "lasso" and attack_phase == "windup": pose_frame = 5
	if extra == "incite" and attack_phase == "incite": pose_frame = 5
	# 近身一掌 has no frames of its own: START to wind up, RECOVER for the backhand.
	if close_strike and attack_phase != "idle": pose_frame = 1 if attack_phase == "windup" else 4
	var gliding := extra == "glide" and attack_phase == "idle" and walking and gliding_now()
	if gliding: pose_frame = 5
	# 萨卡兹哨兵 (N3 board): START for its startle, CHARGE / STRIKE alternating
	# through the hold (signalling), RECOVER as the hold runs out, IDLE on watch.
	if attack_profile.get("alarm", false):
		pose_frame = 0
		if sentinel_mode == "run" and _run_time < ThreatMeter.SENTINEL_STARTLE: pose_frame = 1
		elif sentinel_mode == "hold": pose_frame = 4 if _hold_left < SIGNAL_RECOVER else 2 + int(_hold_left / SIGNAL_BEAT) % 2
	var walk_frame := posmod(int(walk_distance * WALK_FRAMES_PER_UNIT), 4)
	if has_walk and walking and attack_phase in ["idle", "reverse"] and not gliding: _sprite.texture = FieldArt.enemy_walk_pose(sheet_type, dir_column, walk_frame)
	elif directional: _sprite.texture = FieldArt.enemy_dir_pose(sheet_type, dir_column, pose_frame)
	else: _sprite.texture = FieldArt.enemy_pose(int(EnemyAttacks.PROFILES[art_type].row), pose_frame)
	_sprite.position.y = _art_base_y
	if directional: _sprite.flip_h = false
	_sprite.offset.x = 0 if directional else (-4 if _sprite.flip_h else 4)
	if attack_phase == "windup" and pose_frame == 2:
		_sprite.position.y += PIXEL if int(_attack_elapsed * 24) % 2 else 0.0
	elif attack_phase == "idle" and state in [State.CHASING, State.RETURNING] and not (has_walk and walking) and pose_frame != 5:
		# The walk frames carry their own step bob; only bob the idle pose.
		_sprite.position.y += 0.025 * sin(_bob_time * 10)
	if sheet_type == "slug" and attack_phase == "strike":
		_sprite.position.y += sin((1.0 - _phase_remaining / STRIKE_TIME) * PI) * 0.3
	var recoil := float(attack_profile.get("recoil", 0.0))
	if attack_phase == "contact":
		# The bite / stab lands: shove 1 texel into the target on alternate ticks.
		_sprite.offset.x += (1.0 if int(_phase_remaining * 60) % 2 else 0.0) * (-1.0 if _sprite.flip_h else 1.0)
	elif sheet_type == "slug" and attack_phase == "recovery" and _contacted and recoil > 0:
		_sprite.position.y += sin(clampf(_recoil_travelled / recoil, 0, 1) * PI) * 0.2
	var flashing := preparing_attack and (_windup_remaining <= 0.1 or _lock_flash > 0)
	_glint.visible = flashing
	_glint.scale = Vector3.ONE * (3.0 if sheet_type == "ice_hunter" and _lock_flash > 0 else 1.0)
	_breath.visible = sheet_type == "ice_warrior" and preparing_attack and pose_frame == 2
	var right := game.camera.global_basis.x if is_instance_valid(game.camera) else Vector3.RIGHT
	var up := game.camera.global_basis.y if is_instance_valid(game.camera) else Vector3.UP
	var facing := -1.0 if _sprite.flip_h else 1.0
	# Directional sheets carry their own weapon tip per column; no mirroring.
	var dir_tip: Vector2 = FieldArt.dir_tips(sheet_type)[dir_column] if directional else Vector2.ZERO
	if directional: facing = 1.0
	if ranged:
		var tip: Vector2 = dir_tip if directional else MUZZLE_TEXELS.get(art_type, Vector2(22, -12))
		# Same screen spot as the painted tip, but reached with sideways offset
		# plus real height only: the shot's ground track stays on the shooter's
		# row instead of drifting north with the camera's up axis.
		var flat_right := Vector3(right.x, 0, right.z).normalized()
		_muzzle = global_position + Vector3.DOWN * 0.55 + flat_right * tip.x * facing * PIXEL + Vector3.UP * (-tip.y * PIXEL / maxf(up.y, 0.1))
		var cue: Vector2 = (tip * 0.55 if directional else SCOPE_TEXELS) if _lock_flash > 0 else tip
		_glint.global_position = global_position + Vector3.DOWN * 0.55 + right * cue.x * facing * PIXEL - up * cue.y * PIXEL
	else:
		var tip := Vector2(-7, -36) if art_type == "thug" else (Vector2(-3, -31) if art_type == "ice_warrior" else Vector2(-9, -13))
		if directional: tip = dir_tip
		if sheet_type == "slug":
			tip = Vector2(2, -3)
			_glint.visible = preparing_attack and (flashing or sin(_attack_elapsed * (16 + _attack_elapsed * 50)) > 0.4)
			_glint.material_override.albedo_color = Color("ffd875")
		_glint.global_position = global_position + Vector3.DOWN * 0.55 + right * tip.x * facing * PIXEL - up * tip.y * PIXEL
	_breath.global_position = global_position + Vector3.DOWN * 0.55 + right * facing * 0.55 + up * 1.15
	_sync_headlights(dir_tip, right, up)
	_sync_outline()

## 家族专用轿车's two round lamps (§三第 7 条: START 车头灯亮), a 3×3 white dot
## each on the painted bumper, lit from its windup until it is back in its slot.
## Not drawn when the nose faces away from the camera.
func _sync_headlights(tip: Vector2, right: Vector3, up: Vector3) -> void:
	if _headlights.is_empty(): return
	var lit := attack_phase != "idle" and not dir_column in [3, 4, 5]
	var apart: float = [3.0, 1.5, 0.0, 0.0, 0.0, 0.0, 0.0, 1.5][dir_column]
	for i in range(_headlights.size()):
		var lamp := _headlights[i]
		lamp.visible = lit and (i == 0 or apart > 0.0)
		lamp.global_position = global_position + Vector3.DOWN * 0.55 + right * (tip.x + apart * (1.0 if i == 0 else -1.0)) * PIXEL - up * tip.y * PIXEL

func headlights_on() -> bool:
	return _headlights.any(func(lamp): return lamp.visible)

## The light ring round the body while an unstoppable attack winds up.
func _sync_outline() -> void:
	if not is_instance_valid(_outline): return
	_outline.visible = attack_phase == "windup" and unstoppable_now() and _sprite.texture != null
	if not _outline.visible: return
	var texture := _sprite.texture
	var material := _outline.material_override as ShaderMaterial
	var region := Rect2(Vector2.ZERO, texture.get_size())
	var sheet: Texture2D = texture
	if texture is AtlasTexture:
		sheet = (texture as AtlasTexture).atlas
		region = (texture as AtlasTexture).region
	var sheet_size := sheet.get_size()
	material.set_shader_parameter("atlas", sheet)
	material.set_shader_parameter("region", Vector4(region.position.x / sheet_size.x, region.position.y / sheet_size.y, region.size.x / sheet_size.x, region.size.y / sheet_size.y))
	material.set_shader_parameter("cell", region.size)
	material.set_shader_parameter("flip", _sprite.flip_h)
	var quad := _outline.mesh as QuadMesh
	quad.size = region.size * _sprite.pixel_size
	quad.center_offset = Vector3(_sprite.offset.x, _sprite.offset.y, 0.0) * _sprite.pixel_size
	_outline.position = _sprite.position

## Applies this enemy's defence or resistance to a hit and returns the damage
## actually dealt (what lifesteal heals from). `pierce` ignores that share of
## defence (破甲刃纹, 致命瞄点). `quiet` hides the number (burn ticks too small
## to read would only add noise).
func take_hit(damage: float, kind: String = "phys", crit: bool = false, pierce: float = 0.0, quiet: bool = false) -> float:
	if attack_profile.get("stealth", false): _revealed = STEALTH_HOLD
	if _dead: return 0.0
	if attack_phase == "incite":
		_incite_hits += 1
		if _incite_hits >= EnemyAttacks.INCITE_BREAK_HITS: _end_incite()
	if attack_profile.has("front_guard") and is_instance_valid(game) and is_instance_valid(game.player) and _facing_point(game.player.global_position):
		damage *= 1.0 - float(attack_profile.front_guard)
	var dealt := CombatStats.mitigate(damage, kind, effective_defense() * (1.0 - clampf(pierce, 0.0, 1.0)), res_against(kind))
	dealt *= 1.0 + status_value("fragile")
	health -= dealt
	_on_elemental(kind, dealt)
	if barrier_hp > 0.0:
		barrier_hp -= dealt
		if barrier_hp <= 0.0: _break_barrier()
	if attack_profile.has("enrage_run"): _run_timer = float(attack_profile.enrage_run)
	if attack_profile.has("neutral") and not provoked: _provoke_herd()
	if attack_profile.has("phase") and not _phased and health > 0.0 and health < max_health * float(attack_profile.phase):
		_phased = true
		atk *= 1.6
	if attack_profile.has("annihilate") and not _annihilating and health > 0.0 and health < max_health * float(attack_profile.annihilate):
		_annihilating = true
		atk *= 1.5
	_flash()
	if is_instance_valid(game) and not quiet:
		DamageNumber.spawn(game, global_position + Vector3.UP * (0.6 if elite else 0.2), str(roundi(dealt)) + ("!" if crit else ""), "crit" if crit else kind, crit)
	if health <= 0.0:
		_dead = true
		_cancel_attack()
		remove_from_group("enemies")
		remove_from_group("guards")
		if is_instance_valid(game):
			if attack_profile.has("death_blast") and not silenced():
				game.spawn_hazard(global_position, float(attack_profile.death_blast), 1.0, 0.0, atk * 1.5, "phys", true, null)
				game.sound.play("fuse_hiss")
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
	var cut := status_value("def_down") + Elements.BURST.corr.def_down * corr_stacks + Elements.ROT_DEF * rot_stacks()
	return defense * (1.0 - clampf(cut, 0.0, 1.0))

# --- Elements (属性伤害与地区装备策划案 v1.1) ---------------------------------------

## The resistance a hit of `kind` meets: 法抗 for arts, its own for an element
## or bleeding.
func res_against(kind: String) -> float:
	if Elements.is_element(kind) or kind == "bleed": return elem_res(kind)
	return effective_res()

func elem_res(kind: String) -> float:
	if _eres.is_empty():
		var region := game.region_id if is_instance_valid(game) else ""
		_eres = Elements.enemy_resists(region, elite, boss or self is Boss)
	return float(_eres.get(kind, 0.0))

## The life a gauge has to take before it bursts.
func gauge_threshold() -> float:
	return max_health * Elements.threshold_share(elite, boss or self is Boss)

func _on_elemental(kind: String, dealt: float) -> void:
	if not Elements.is_element(kind): return
	var mult := game.player.elements.fill_mult() if is_instance_valid(game) and is_instance_valid(game.player) and game.player.elements != null else 1.0
	if elements.fill(kind, dealt * mult, gauge_threshold(), burst_cooldown()): _pending_bursts.append(kind)

## Her 爆发 family's 阶等 (0 without one), and the cooldown it shortens at (4).
func _burst_tier() -> int:
	if not is_instance_valid(game) or not is_instance_valid(game.player) or game.player.families == null: return 0
	return game.player.families.tier("burst")

func burst_cooldown() -> float:
	return Elements.BURST_COOLDOWN - (PrefixFamilies.BURST_COOLDOWN_CUT if _burst_tier() >= 4 else 0.0)

## A damage over time from her (Player._proc_dots): `total` over `seconds`.
func apply_dot(dot: String, total: float, seconds: float) -> void:
	if _dead or not Elements.DOTS.has(dot): return
	if dot == "rot": _rot_stacks = mini(Elements.ROT_STACKS, _rot_stacks + 1)
	elements.apply_dot(dot, total, seconds, str(Elements.DOTS[dot][0]))

var _rot_stacks := 0
func rot_stacks() -> int:
	return _rot_stacks if elements.has_dot("rot") else 0

func _tick_elements(delta: float) -> void:
	for kind in _pending_bursts.duplicate():
		_pending_bursts.erase(kind)
		_burst(kind)
		if _dead: return
	if elements.dots.is_empty() and elements.gauges.is_empty() and elements.cooldowns.is_empty(): return
	if not elements.has_dot("rot"): _rot_stacks = 0
	if elements.has_dot("frost"): apply_status("slow", 0.6, Elements.FROST_SLOW)
	for due in elements.tick(delta, gauge_threshold()):
		var damage := float(due.damage)
		if str(due.dot) == "bleed" and walking: damage *= 1.0 + Elements.BLEED_MOVING
		var dealt := take_hit(damage, str(due.kind), false, 0.0, true)
		if _dead: return
		if str(due.dot) == "necro" and elements.fill("necro", dealt, gauge_threshold(), burst_cooldown()): _pending_bursts.append("necro")

## A full gauge (§5.1). The 爆发 family spreads it at (6) and repeats its
## damage at half at (8).
func _burst(kind: String) -> void:
	if _dead or not is_instance_valid(game): return
	var family := _burst_tier()
	if family >= 6:
		for node in get_tree().get_nodes_in_group("enemies"):
			var other := node as Enemy
			if other == null or other == self or other._dead or other.game != game: continue
			if _flat_distance(other.global_position, global_position) > 3.0: continue
			if other.elements.fill(kind, other.gauge_threshold() * PrefixFamilies.BURST_SPREAD, other.gauge_threshold(), other.burst_cooldown()): other._pending_bursts.append(kind)
	_burst_once(kind, 1.0)
	if family >= 8 and not _dead: _burst_once(kind, PrefixFamilies.BURST_ECHO)

func _burst_once(kind: String, scale: float) -> void:
	if _dead or not is_instance_valid(game): return
	var t := gauge_threshold() * scale
	var big := self is Boss or boss
	var spec: Dictionary = Elements.BURST[kind]
	CombatVfx.spawn(game, global_position, Vector3.FORWARD, "spark", 0, true)
	if is_instance_valid(game.player) and game.player.elements != null: game.player.elements.on_enemy_burst(self, kind)
	match kind:
		"burn":
			apply_status("res_down", float(spec.secs), float(spec.res_down))
			_burst_hit(t * float(spec.damage), "burn")
		"cold":
			if big: apply_status("slow", float(spec.boss_secs), float(spec.boss_slow))
			else:
				var secs := float(spec.elite_freeze) if elite else float(spec.freeze)
				stun(secs)
				# 碎冰 (萨米 signature) reads it on the next hit.
				apply_status("frozen", secs, 1.0)
			_burst_hit(0.0, "cold")
		"corr":
			corr_stacks = mini(int(spec.stacks), corr_stacks + 1)
			_burst_hit(t * float(spec.damage), "phys")
		"nerve":
			if big: apply_status("slow", 3.0, 0.3)
			else: stun(float(spec.elite_stun) if elite else float(spec.stun))
			_burst_hit(t * float(spec.damage), "true")
		"necro":
			apply_status("weaken", float(spec.secs), float(spec.weaken))
			elements.apply_dot("necro_burst", t * float(spec.tick) * float(spec.secs), float(spec.secs), "arts")

## The burst's own number, big in its element's colour.
func _burst_hit(damage: float, kind: String) -> void:
	var dealt := take_hit(damage, kind, false, 0.0, true) if damage > 0.0 else 0.0
	if is_instance_valid(game): DamageNumber.spawn(game, global_position + Vector3.UP * 0.6, str(roundi(dealt)) if dealt > 0.0 else Elements.NAMES[kind], _burst_colour_kind(kind), true)

func _burst_colour_kind(kind: String) -> String:
	return kind if DamageNumber.COLORS.has(kind) else "true"

func effective_res() -> float:
	return res - status_value("res_down") + (50.0 if barrier_up() else 0.0)

## 灰尾's barrier (用户 2026-10-11): no absorption, only 法抗 +50 while it holds.
func barrier_up() -> bool:
	return barrier_hp > 0.0 and not silenced()

func _break_barrier() -> void:
	barrier_hp = 0.0
	if _barrier_broken: return
	_barrier_broken = true
	move_speed *= 1.4
	if _shell != null: _shell.shatter()
	if is_instance_valid(game): game.sound.play("barrier_break")
	if is_instance_valid(_sprite): _sprite.modulate = _rest_tint()
	if is_instance_valid(game): CombatVfx.spawn(game, global_position, Vector3.FORWARD, "spark", 0, true)

func status_value(status: String) -> float:
	return float(statuses[status].value) if statuses.has(status) else 0.0

## A stronger or equal application refreshes; a weaker one never shortens a stronger one.
func apply_status(status: String, seconds: float, value: float) -> void:
	if _dead: return
	if statuses.has(status) and float(statuses[status].value) > value and float(statuses[status].time) > 0.0: return
	if status == "burn" and not statuses.has("burn"): _burn_tick = 0.5
	statuses[status] = {"time": seconds, "value": value}

## 噤声印记: an ordinary enemy loses the attack it is winding up and cannot
## start another for `seconds`. Elites keep their telegraphed strike unless
## `include_elites` (精神摧毁 reaches them for a shorter time). Nothing breaks
## an attack that is 不可打断 (用户 2026-10-11).
func interrupt(seconds: float, include_elites: bool = false) -> void:
	if _dead or unstoppable_now(): return
	_end_incite()
	if elite and not include_elites: return
	if attack_phase == "windup": _cancel_attack()
	_attack_timer = maxf(_attack_timer, seconds)

## True while an attack that cannot be broken is under way: 欺凌者's charge,
## 粉碎攻坚手's third blow, a boss's heavy strike (装备扩充策划案 §7.2).
func unstoppable_now() -> bool:
	if not attack_phase in ["windup", "strike", "contact"]: return false
	if bool(attack_profile.get("unstoppable", false)) or boss: return true
	return _stuns_this_attack() and _special == ""

func _stuns_this_attack() -> bool:
	if not attack_profile.has("stun_every") or silenced(): return false
	var every := int(attack_profile.stun_every)
	# During the windup the count has not moved yet; after the strike it has.
	var number := _attack_count + (1 if attack_phase == "windup" else 0)
	return number > 0 and number % every == 0

## Stunned: does nothing for `seconds` (装备 effects). Breaks a windup.
func stun(seconds: float) -> void:
	if _dead or unstoppable_now(): return
	stun_timer = maxf(stun_timer, seconds * (0.5 if boss else 1.0))
	_end_incite()
	if attack_phase == "windup": _cancel_attack()

## Shoved `distance` along `direction` (bosses only a little).
func push(direction: Vector3, distance: float) -> void:
	if _dead or not is_instance_valid(game) or not is_instance_valid(game.world_map): return
	# The car is not pushed out of its slot (§三第 7.1 节第 7 条).
	if attack_profile.get("roadblock", false): return
	var left := distance * (0.3 if boss or unstoppable_now() else 1.0)
	direction.y = 0
	if direction.length_squared() < 0.0001: return
	direction = direction.normalized()
	while left > 0.0001:
		var step := minf(0.08, left)
		if not _try_step(direction, step): return
		left -= step

## 精神摧毁: its special abilities stop working for `seconds`.
func silence(seconds: float) -> void:
	silence_timer = maxf(silence_timer, seconds)
	_end_incite()
	if is_instance_valid(_sprite): _sprite.modulate = _rest_tint()

func silenced() -> bool:
	return silence_timer > 0.0

## Whether `point` is in front of it (120°): the side a shield faces.
func _facing_point(point: Vector3) -> bool:
	var to := point - global_position
	to.y = 0
	var forward := attack_direction if attack_direction.length_squared() > 0.001 else -global_basis.z
	forward.y = 0
	if to.length_squared() < 0.0001 or forward.length_squared() < 0.0001: return true
	return to.normalized().dot(forward.normalized()) >= cos(deg_to_rad(60.0))

# --- New behaviours (装备扩充策划案 §2.1) -------------------------------------------

const CHARGE_SPEED := 14.0

func _tick_specials(delta: float) -> void:
	_lasso_cd = maxf(0.0, _lasso_cd - delta)
	if attack_phase != "incite": _incite_cd = maxf(0.0, _incite_cd - delta)
	_backstep_cd = maxf(0.0, _backstep_cd - delta)
	_run_timer = maxf(0.0, _run_timer - delta)
	_since_attack += delta
	_chip_timer -= delta
	if _chip_timer <= 0.0:
		var ground := Vector3(global_position.x, 0.12, global_position.z)
		# 染污躯壳 running: snow kicked up; 歪曲施法者 gliding: a pale streak.
		if _run_timer > 0.0 and walking:
			_chip_timer = 0.2
			EnemyAttackVfx.spawn(game, ground, -global_basis.z, "snow_puff")
		elif gliding_now() and walking:
			_chip_timer = 0.06
			EnemyAttackVfx.spawn(game, ground + Vector3.UP * 0.1, -global_basis.z, "glide_trail")
		elif _annihilating:
			# 自我泯灭: it sheds a splinter every 0.3 s.
			_chip_timer = 0.3
			EnemyAttackVfx.spawn(game, global_position + Vector3.UP * 0.4, -global_basis.z, "wood_chip")
	if _annihilating:
		take_hit(max_health * 0.04 * delta, "true", false, 0.0, true)

## 歪曲施法者 glides once it has gone `glide` seconds without attacking.
func gliding_now() -> bool:
	return attack_profile.has("glide") and not silenced() and _since_attack >= float(attack_profile.glide)

## Drawn from its own boards rather than a borrowed, tinted sheet.
func own_art() -> bool:
	return directional and EnemyN2Data.TIPS.has(sheet_type)

## Speed now: 染污躯壳 running, 歪曲施法者 gliding, haste.
func current_speed() -> float:
	var speed := move_speed
	if behavior == Behavior.PATROL and state == State.IDLE: speed *= 0.7
	if _run_timer > 0.0: speed *= 2.0
	if gliding_now(): speed *= 3.0
	if status_value("haste") > 0.0: speed *= 1.3
	return speed

## The lasso, the step back: specials that replace an ordinary attack. True
## when one started (or moved it) this tick.
func _try_special(distance: float, visible_player: bool) -> bool:
	if silenced() or not visible_player: return false
	if attack_profile.has("incite") and patrol_wave == 0 and _incite_cd <= 0.0 and _attack_timer <= 0.0 and distance <= float(attack_profile.reach):
		_begin_incite()
		return true
	if attack_profile.has("lasso") and _lasso_cd <= 0.0 and distance > 5.0 and distance < 9.0 and _attack_timer <= 0.0:
		_lasso_cd = 7.0
		preparing_attack = true
		attack_phase = "windup"
		_special = "lasso"
		attack_origin = global_position
		_attack_elapsed = 0
		_aim_locked = true
		_hit_this_attack = false
		_cue_played = false
		_lock_direction()
		_windup_total = 0.6
		_windup_remaining = 0.6
		# No red line: an ordinary physical throw reads by the rope whirling
		# over its head (新敌人攻击案 §六第 1 条).
		warn_shape = ""
		_update_attack_visual()
		return true
	if attack_profile.has("backstep") and _backstep_cd <= 0.0 and distance < float(attack_profile.backstep):
		_backstep_cd = 4.0
		var away := global_position - game.player.global_position
		away.y = 0
		push(away.normalized() if away.length_squared() > 0.001 else Vector3.BACK, 2.5)
		return true
	return false

## 煽动 (§三第 4 条): it stops, one hand up and one at her, and the 血债 rises
## while it lasts; a dark red ring over its head says to hit it first.
func _begin_incite() -> void:
	attack_phase = "incite"
	_special = "incite"
	preparing_attack = false
	_incite_left = EnemyAttacks.INCITE_TIME
	_incite_hits = 0
	_incite_cd = EnemyAttacks.INCITE_TIME + EnemyAttacks.INCITE_COOLDOWN
	_update_attack_visual()

func _end_incite() -> void:
	if attack_phase != "incite": return
	_cancel_attack()
	_special = ""
	_incite_cd = EnemyAttacks.INCITE_COOLDOWN
	_attack_timer = maxf(_attack_timer, 0.6)

func inciting() -> bool:
	return attack_phase == "incite"

func _resolve_lasso() -> void:
	preparing_attack = false
	attack_phase = "recovery"
	_phase_remaining = 0.4
	_special = ""
	for marker in _warning_markers:
		if is_instance_valid(marker): marker.queue_free()
	_warning_markers.clear()
	var offset := game.player.global_position - attack_origin
	offset.y = 0
	var along := offset.dot(attack_direction)
	var caught := along > 0.0 and along < 9.6 and absf(offset.cross(attack_direction).y) < 0.6 and game.line_of_sight(global_position, game.player.global_position)
	var hand := global_position + Vector3.UP * 0.3
	var reach := along if caught else 9.6
	var rope := EnemyAttackVfx.spawn(game, hand, attack_direction, "rope", reach)
	rope.owner_enemy = self
	game.sound.play("rope_whip")
	if caught:
		game.player.take_damage(atk * 0.3, damage_kind, self)
		game.player.apply_control("pull", -attack_direction, maxf(0.0, along - 1.5), 0.4)

func _advance_charge(delta: float) -> void:
	var reach := float(attack_profile.reach)
	var amount := minf(reach - _charge_travelled, CHARGE_SPEED * delta)
	# A puff of dust behind it every 0.05 s.
	_trail_timer -= delta
	if _trail_timer <= 0.0:
		_trail_timer = 0.05
		EnemyAttackVfx.spawn(game, Vector3(global_position.x, 0.15, global_position.z), attack_direction, "dust")
	while amount > 0.0001:
		if not _charge_hit and _flat_distance(global_position, game.player.global_position) <= 1.0:
			_charge_hit = true
			game.player.take_damage(_pending_damage, damage_kind, self)
			game.player.apply_control("knockback", attack_direction, float(attack_profile.get("knockback", 2.0)), 0.3)
		var step := minf(0.1, amount)
		if not _try_step(attack_direction, step):
			# Into a wall: it staggers (撞墙硬直), the signboard sparking.
			CombatVfx.spawn(game, global_position + attack_direction * 0.5 + Vector3.UP * 0.6, -attack_direction, "spark", 0, true)
			attack_phase = "recovery"
			_phase_remaining = float(attack_profile.recovery) + 1.0
			return
		_charge_travelled += step
		amount -= step
	if _charge_travelled >= reach - 0.001: _phase_remaining = 0.0

## 陷落雪祀: its ice orb skips on to the nearest other enemy and hastens it.
func _haste_nearest() -> void:
	var best: Enemy = null
	var best_distance := 6.0
	for node in get_tree().get_nodes_in_group("enemies"):
		var other := node as Enemy
		if other == null or other == self or other.game != game or other._dead: continue
		var d := _flat_distance(other.global_position, global_position)
		if d < best_distance:
			best = other
			best_distance = d
	if best == null: return
	best.apply_status("haste", 4.0, 1.0)
	var link := EnemyAttackVfx.spawn(game, global_position + Vector3.UP * 0.4, best.global_position - global_position, "haste_link", best_distance)
	link.target_enemy = best
	game.sound.play("haste_bell")

## 岩角兽: hit one and the whole herd comes.
func _provoke_herd() -> void:
	provoked = true
	if herd < 0 or not is_instance_valid(game): return
	for node in get_tree().get_nodes_in_group("enemies"):
		var other := node as Enemy
		if other != null and other.herd == herd and other.game == game and not other.provoked:
			other.provoked = true
			other.begin_chase()

func _tick_statuses(delta: float) -> void:
	_tick_elements(delta)
	if _dead or statuses.is_empty(): return
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
			_sprite.modulate = _rest_tint()
	)

## Its resting colour (the borrowed sheet's tint until its own art is in).
func _rest_tint() -> Color:
	return _tint

## The barrier shell stands on its feet while the barrier holds, cracked once
## half of it is gone (用户 2026-10-11: 加一个有裂纹的屏障).
func _sync_shell() -> void:
	if _shell == null or not is_instance_valid(_sprite): return
	if barrier_up():
		_shell.cracked = barrier_hp < max_health * float(attack_profile.barrier) * 0.5
		_shell.follow(Vector3(_sprite.position.x, _sprite.position.y, _sprite.position.z))
	elif not _barrier_broken: _shell.hide_shell()
