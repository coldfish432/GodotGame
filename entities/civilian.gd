class_name Civilian
extends Enemy

## 叙拉古平民 (IS-10; Boss战场地策划案 §4.4): townsfolk sheltering from the rain
## at the edge of 扎罗's piazza. They never attack and never fall. Each blow of
## hers, 扎罗's or the family's that reaches one (a sweep counts) adds BossCatalog.CIVILIAN_DEBT 血债,
## and it runs off out of the piazza. Neutral, so not one of the floor's enemies.
## Sol's own board (B2 v5, reduced by art/field/reduce_b2.py): IDLE and LOOK
## alternate while it shelters, FLINCH for FLINCH_TIME when struck, then the
## run board as it flees. The family soldier's stats carry it underneath.

const ART := "family_soldier"
const SHEET := "civilian"
const IDLE := 0
const LOOK := 1
const FLINCH := 2
const FLINCH_TIME := 0.5
## Each glance round lasts this long, out of every LOOK_EVERY seconds.
const LOOK_TIME := 0.9
const LOOK_EVERY := 3.2
const FLEE_SPEED := 3.2
const HIT_GAP := 0.6
## However the street runs, after this long fleeing it is gone.
const FLEE_MAX := 6.0

var arena: BossArena
var fleeing := false
var _flee_to := Vector3.ZERO
var _since_hit := 99.0
var _fled := 0.0
## Wandering the piazza (用户 2026-10-20): round where it first stood.
var home := Vector3.ZERO
var wandering := false
var _wander_to := Vector3.ZERO
var _rest := 0.0
var _walked := 0.0
const WANDER_MAX := 8.0

func setup_civilian(p_game: GameManager, p_arena: BossArena) -> void:
	arena = p_arena
	setup(p_game, false, false, ART)
	enemy_type = "civilian"
	name = "叙拉古平民"
	attack_profile = {"name": "叙拉古平民", "attack": "", "shape": "none", "reach": 0.0, "windup": 1.0, "interval": 1.0, "recovery": 0.0, "damage": 0.0, "neutral": true}
	atk = 0.0
	if FieldArt.has_directional(SHEET):
		sheet_type = SHEET
		has_walk = FieldArt.has_walk(SHEET)
	_tint = Color.WHITE
	# Each one glances round on its own beat.
	_bob_time = randf() * LOOK_EVERY
	if is_instance_valid(_sprite):
		_sprite.modulate = _tint
		_update_attack_visual()
	remove_from_group("guards")
	add_to_group("civilians")
	home = global_position
	_rest = randf_range(BossCatalog.CIVILIAN_REST.x, BossCatalog.CIVILIAN_REST.y)

func take_hit(_damage: float, _kind: String = "phys", _crit: bool = false, _pierce: float = 0.0, _quiet: bool = false) -> float:
	struck()
	return 0.0

## A blow lands on it, hers or 扎罗's or one of the family's (用户 2026-10-20:
## theirs add 血债 too): CIVILIAN_DEBT, then it cringes and runs.
func struck() -> void:
	if _dead or not is_instance_valid(game): return
	if _since_hit >= HIT_GAP:
		_since_hit = 0.0
		# Its 血债 is the raw weight times DEBT_SCALE in add_debt; this undoes the scale.
		game.add_debt(BossCatalog.CIVILIAN_DEBT / FeatureCatalog.DEBT_SCALE)
		_flash()
	_start_fleeing()

func _start_fleeing() -> void:
	if fleeing: return
	fleeing = true
	var best := global_position
	var far := -1.0
	for mouth in arena.mouths():
		var d := _flat_distance(mouth, game.player.global_position)
		if d > far:
			far = d
			best = mouth
	var out := best - arena.centre
	out.y = 0.0
	_flee_to = game.world_map.nearest_walkable(best + out.normalized() * 4.0)

func _physics_process(delta: float) -> void:
	if _dead or not is_instance_valid(game) or not game.simulation_active(): return
	_since_hit += delta
	_advance_animation(delta)
	if not fleeing:
		_wander(delta)
		return
	_fled += delta
	if _fled < FLINCH_TIME:
		_update_attack_visual()
		return
	_move_toward_target(_flee_to, delta)
	if _fled >= FLEE_MAX or _flat_distance(global_position, _flee_to) < 1.0 or not arena.inside(global_position, 3.0):
		_dead = true
		remove_from_group("enemies")
		queue_free()

## Rest a while, then amble to another spot near home, inside the piazza.
func _wander(delta: float) -> void:
	if not wandering:
		_rest -= delta
		if _rest > 0.0: return
		var a := randf() * TAU
		var spot := home + Vector3(cos(a), 0.0, sin(a)) * randf_range(1.0, BossCatalog.CIVILIAN_WANDER)
		if not arena.inside(spot, -1.5): spot = home
		_wander_to = game.world_map.nearest_walkable(spot)
		wandering = true
		_walked = 0.0
		return
	_walked += delta
	_move_toward_target(_wander_to, delta)
	# A spot it cannot reach: give up after WANDER_MAX and rest where it is.
	if _flat_distance(global_position, _wander_to) < 0.4 or _walked > WANDER_MAX:
		wandering = false
		_rest = randf_range(BossCatalog.CIVILIAN_REST.x, BossCatalog.CIVILIAN_REST.y)

func current_speed() -> float:
	if fleeing: return FLEE_SPEED if _fled >= FLINCH_TIME else 0.0
	return BossCatalog.CIVILIAN_WALK if wandering else 0.0

func _update_attack_visual() -> void:
	if sheet_type != SHEET or not is_instance_valid(_sprite):
		super._update_attack_visual()
		return
	if fleeing and _fled < FLINCH_TIME: _sprite.texture = FieldArt.enemy_dir_pose(sheet_type, dir_column, FLINCH)
	elif (fleeing or (wandering and walking)) and has_walk: _sprite.texture = FieldArt.enemy_walk_pose(sheet_type, dir_column, posmod(int(walk_distance * WALK_FRAMES_PER_UNIT), 4))
	else: _sprite.texture = FieldArt.enemy_dir_pose(sheet_type, dir_column, LOOK if fmod(_bob_time, LOOK_EVERY) < LOOK_TIME else IDLE)
	_sprite.position.y = _art_base_y
	_sprite.flip_h = false
	_sprite.offset.x = 0
