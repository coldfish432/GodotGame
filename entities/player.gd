class_name Player
extends CharacterBody3D

## Ported from the player-facing half of DownfallPrototype (movement toward a
## click-set target, dash, weapons, hp/stamina, gravity). GameManager owns
## input interpretation (raycasting the pointer against enemies/ground) and
## calls set_move_target()/attack() here — see game/game_manager.gd.
##
## Stats, the damage pipeline and the relic effects follow
## 局内构筑与数值策划案_v1_0.md: §3 stat model, §4 damage order, §5 Lappland,
## §10 the relics (data in game/relic_catalog.gd). Relics are read through
## `fx`, their summed effect parameters, never by id. Effects that deal damage
## of their own come from special equipment triggers (SpecialGear).

signal died
signal message_requested(text: String)
signal stats_changed


## 5.5 since 2026-10-13 (用户: 角色基础移速偏慢，调快10%).
const BASE_MOVE_SPEED := 5.5
const DASH_IMPULSE := 2.8
const DASH_INVULN_DURATION := 0.28
## 1.5 s between dodges (用户 2026-10-10: 闪避添加cd), on top of the stamina cost.
const DASH_COOLDOWN := 1.5
const DASH_STAMINA_COST := 25.0
## 8 stamina a second (用户 2026-10-10: 降低体力恢复速率; was 18): a dodge's 25
## takes about 3 s to earn back, a full bar about 12.5 s.
const STAMINA_REGEN := 8.0
const HP_REGEN_INTERVAL := 5.0
const BLADE_RANGE := 3.4
## 0.7 s between swings (用户 2026-10-03: 0.42 was too fast; ATK left at 600).
const BASE_BLADE_COOLDOWN := 0.7
## A combo continues while the next swing comes within this long of the last.
## It must outlast the interval, or slow attack speed could never reach stage 3.
const COMBO_WINDOW := 1.2
const MIN_ATTACK_SPEED := CombatStats.ASPD_MIN / 100.0
const MIN_BLADE_COOLDOWN := 0.1
const ARRIVE_THRESHOLD := 0.25
const GRAVITY := -9.81
## Height difference past which an enemy is on another terrace and cannot be hit
## by a swing (one tier is ContinuousWorldMap.TIER).
const TIER_REACH := 1.6
const BASE_POTION_CAPACITY := 3
## Melee hits are ATK × these per combo stage; the third is the heavy one.
const COMBO_SCALES := [1.0, 1.0, 1.3]
## The sword wave is arts damage: 法术攻击力 × this.
const WAVE_SCALE := 1.5
const WAVE_HITS := 3
const OUT_OF_COMBAT := 5.0
## Relic effect constants (the per-relic sizes are in RelicCatalog fx).
const HIT_STACK_MAX := 10
const HIT_STACK_SECONDS := 3.0
const WAVE_STACK_MAX := 10
const BUILD_ATK_SECONDS := 60.0
const BUILD_ASPD_SECONDS := 40.0
const HURT_STACK_MAX := 10
const ELITE_STACK_MAX := 15
const ALTAR_MAX := 10
const LINGER_SECONDS := 100.0
const CROWD_SECONDS := 30.0
const CROWD_COOLDOWN := 60.0
## Amiya (Guard), 阿米娅攻击动作与特效设计案 §五 with the 2026-10-09 changes:
## every hit is arts damage off ATK (术战者); stage 2 is 奔夜's double cut.
const AMIYA_COMBO := [[1.0], [0.55, 0.55], [1.3]]
const AMIYA_SECOND_CUT := 0.08
## The stage-3 thrust stays in place (用户 2026-10-10: 前戳不位移).
## 影霄·绝影 as an active skill like 剑圣's Q (Alpha Strike, 用户 2026-10-09):
## Space on an enemy near the cursor. She vanishes (body hidden, untouchable)
## and strikes SHADOW_STRIKES times, each bouncing to the nearest enemy she has
## not struck yet; with nobody fresh she strikes again for SHADOW_REPEAT_SCALE
## (the LoL wiki's Alpha Strike rules). Damage lands on each strike, in real
## time (用户 2026-10-09: 实时结算), not as LoL's marks detonating on return.
## Every landed basic cut shortens the cooldown by SHADOW_REFUND.
const SHADOW_RANGE := 6.0
const SHADOW_PICK_RADIUS := 2.0
const SHADOW_STRIKES := 4
const SHADOW_BOUNCE_RANGE := 4.0
const SHADOW_STRIKE_SCALE := 1.0
const SHADOW_REPEAT_SCALE := 0.25
const SHADOW_COOLDOWN := 8.0
const SHADOW_REFUND := 1.0
const SHADOW_FIRST := 0.06
const SHADOW_GAP := 0.1

var hp: float = 2400.0
var max_hp: float = 2400.0
var stamina: float = 100.0
## Generic "伤害 +X%" (dmg_pct); conditional multipliers sit on top.
var damage_bonus: float = 1.0
var invulnerable: bool = false
var equipped: Dictionary = {}  # Item.Category -> Item
## The summed sheet from equipment and relics (CombatStats.KEYS).
var stats: Dictionary = CombatStats.empty()
## Summed relic effect parameters (RelicCatalog.fx_sum).
var fx: Dictionary = {}
## Damage absorbed before HP (活木甲, special armour soaks).
var shield := 0.0

# Derived from the sheet — see _recompute_stats().
var move_speed: float = BASE_MOVE_SPEED
var blade_cooldown: float = BASE_BLADE_COOLDOWN
var attack_speed: float = 1.0
var gold_gain_multiplier: float = 1.0
## Flask healing from the old capacity stat (relics, affixes): ±20% a point.
var potion_heal_multiplier: float = 1.0

var _buff_max_hp_bonus: float = 0.0
var _buff_damage_bonus: float = 0.0
var _low_hp_ward_used_this_floor: bool = false

var _move_target: Vector3 = Vector3.ZERO
var _has_move_target: bool = false
var _attack_cooldown: float = 0.0
## A swing roots her until its animation ends (用户 2026-10-07: no attacking
## on the move). Move orders given meanwhile wait; a dodge cancels the swing.
var swing_remaining: float = 0.0
var _dash_cooldown: float = 0.0
var regen_timer: float = HP_REGEN_INTERVAL
## Set at departure from the base's medical state (基地玩法策划案 §4): injury and
## contamination take this share of max HP for the whole contract, and heavy
## contamination stops self-regeneration. Cleared on settlement.
var condition_hp_penalty := 0.0
var regen_blocked := false
## Contamination right now (GameManager feeds it every frame): it cuts max HP
## and regeneration live (局内节奏与目标策划案 §6 D).
var contamination := 0.0

var _sprite: LapplandAnimator3D
var game: GameManager
var combat_timer := 6.0
var stationary_time := 0.0
var combo_step := 0
var combo_idle := 0.0
var sword_charge := 0
var charge_idle := 0.0
var hitstop_remaining := 0.0
var dash_remaining := 0.0
var _dash_buffered := false
var _navigation: NavigationAgent3D

# Relic runtime state. Per-contract values clear at settlement; per-segment
# ones in reset_floor_state().
var hurt_timer := 0.0       # 冰结的躯壳
var engage_timer := 0.0     # 疗养体验卡 / 特供卡
var since_wave := 0.0       # "噤声" / 鸣脊兽: time without releasing a wave
var hit_stacks := 0         # 轰鸣之手
var hit_stack_timer := 0.0
var avenge_ready := false   # 赏善郎
var evade_timer := 0.0      # 《光耀卡西米尔》 / 《归来》
var wave_count := 0         # 《拳经三问》, this contract
var wave_burst_timer := 0.0 # 绿叶菜罐头 / 叙拉古人的愤怒
var _auto_charge := 0.0     # 香草沙士汽水 / 迷梦香精
var hurt_stacks := 0        # 老磨盘, this segment
var blocks_left := 0        # 皇族金胸针 / 药枚, this segment
var segment_time := 0.0     # 古堡的子嗣
var guard_timer := 0.0      # 霜牡的肩甲
var guard_cooldown := 0.0
var dance_timer := 0.0      # 雪牝的护手
var dance_cooldown := 0.0
var death_full_used := false   # 复还之手, this segment
var death_cling_used := false  # "时光之末", this contract
var elite_kills := 0        # 米诺斯颂诗 / Friston.P, this contract
var altar_stacks := 0       # 圆石祭坛, this contract
var invuln_timer := 0.0
var bash_timer := 0.0       # 反击塔盾 (special gear)
var _in_burst := false      # 共振矿芯 never chains
## Who she is (Operators). Set at the base; Amiya's state below.
var operator_id := Operators.LAPPLAND
var _pending_cuts: Array[Dictionary] = []
var shadow_active := false
var shadow_cooldown := 0.0
var shadow_primary: Enemy
var shadow_target: Enemy
var shadow_strikes := 0
var _shadow_strikes_total := SHADOW_STRIKES
var _shadow_hit_ids := {}
var _shadow_multiplier := 1.0
var _shadow_clock := 0.0
var _shadow_next := 0.0
## Growth (精英化与加点策划案_v0_2.md): skill-tree state that lives in the field.
var gear_fx: GearEffects
var wolf_timer := 0.0        # 狼魂 running
var wolf_waves := 0          # waves toward the next 狼魂
var sundial_timer := 0.0     # 日晷: evasion after stage 3
var step_timer := 0.0        # 影步: crit after a dodge
var nightrun_timer := 0.0    # 奔夜: arts evasion after stage 2
var fury_timer := 0.0        # 青色怒火 doubled after 绝影
var shadow_kill_stacks := 0  # 每击败一个敌人
var shadow_true := false     # 接下来的伤害类型变为真实
## Loss of control (装备扩充策划案 §7.1, 用户 2026-10-11): stun, knockback, pull.
var control_kind := ""
var control_timer := 0.0
var control_immune := 0.0
var _control_velocity := Vector3.ZERO
var _stun_times: Array[float] = []
var _clock := 0.0
var _stun_mark: Label3D
## Her shields (活木甲, 灰尾屏障坠, 灰色秩序 …) show the shared barrier shell.
var _shell: BarrierFx
## The largest the current shield has been, so the shell cracks at half of it.
var _shield_peak := 0.0

func _ready() -> void:
	game = get_parent() as GameManager
	_navigation = NavigationAgent3D.new()
	# Measured in 3D from her origin: on a ramp the navmesh lies up to half a
	# metre off her height, and at 0.45 she could stand on a waypoint and never
	# reach it, rocking in place.
	_navigation.path_desired_distance = 0.8
	_navigation.target_desired_distance = ARRIVE_THRESHOLD
	add_child(_navigation)
	gear_fx = GearEffects.new(self)
	_build_visual()
	collision_layer = 2
	collision_mask = 1
	_recompute_stats()
	hp = max_hp

func _build_visual() -> void:
	# Eight-direction Lappland sprite sheet (godot_assets/) on a billboard;
	# the animator picks the row from velocity and drives its own frames, so
	# unlike the enemies there is no manual texture-swap timer here. The body
	# still look_at()s its heading — that only feeds attack direction now,
	# since a billboard ignores the node's rotation.
	_sprite = LapplandAnimator3D.new()
	_sprite.character = operator_id
	add_child(_sprite)
	add_child(PlayerAura.new())
	_stun_mark = Label3D.new()
	_stun_mark.text = "✦ ✦ ✦"
	_stun_mark.font_size = 28
	_stun_mark.pixel_size = 0.012
	_stun_mark.modulate = Color("f5c000")
	_stun_mark.outline_size = 6
	_stun_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_stun_mark.no_depth_test = true
	_stun_mark.position.y = 1.55
	_stun_mark.visible = false
	add_child(_stun_mark)
	_shell = BarrierFx.new()
	_shell.colour = Color("bfe8ff")
	# Her sprite is smaller than an enemy's; 0.8 keeps the circle around her.
	_shell.size = 0.8
	add_child(_shell)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.3
	shape.shape = capsule
	add_child(shape)

func is_amiya() -> bool:
	return operator_id == Operators.AMIYA_GUARD

## Her growth (BaseState keeps it). Null outside a game (bare tests).
func progress() -> OperatorProgress:
	if not is_instance_valid(game): return null
	return game.base.progress_for(operator_id)

## Rank of a skill-tree node (0 when she has none, or outside a game).
func rank(node_id: String) -> int:
	var p := progress()
	return p.rank(node_id) if p != null else (1 if SkillTrees.node(operator_id, node_id).get("type", "") == "signature" else 0)

func transmuter(group: String) -> String:
	var p := progress()
	return p.transmuter(group) if p != null else ""

func elite_stage() -> int:
	var p := progress()
	return p.elite if p != null else 0

func module_level() -> int:
	var p := progress()
	return p.module_level if p != null else 0

## Why she cannot wear `item` (精英化与加点策划案 §7), "" when she can.
func equip_refusal(item: Item) -> String:
	return Progression.refusal(item, progress())

## Her weapon's form ("blade" when bare or unknown).
func weapon_form() -> String:
	var weapon: Item = equipped.get(Item.Category.WEAPON)
	if weapon == null: return "blade"
	var data: Dictionary = SpecialGear.GEAR.get(weapon.special, {}) if not weapon.special.is_empty() else GearCatalog.base(weapon.base_id)
	var form := str(data.get("form", "blade"))
	return form if GearCatalog.FORMS.has(form) else "blade"

func form_factor(index: int) -> float:
	return float(GearCatalog.FORMS[weapon_form()][index])

## Switch operator (base only). Charge and combo belong to whoever swings.
func set_operator(id: String) -> void:
	if not Operators.valid(id): id = Operators.LAPPLAND
	if id == operator_id: return
	operator_id = id
	reset_combat_state()
	if is_instance_valid(_sprite): _sprite.set_character(id)
	stats_changed.emit()

func set_move_target(target: Vector3) -> void:
	_move_target = target
	_has_move_target = true
	if is_instance_valid(_navigation): _navigation.target_position = target

func clear_move_target() -> void:
	_has_move_target = false

## The enemy a left click locked onto (用户 2026-10-07): she walks until it is
## within her weapon's reach, stops, and attacks it until it dies or another
## order (right click, ground click, keys, a menu) replaces it. Melee and
## ranged alike; only this enemy is attacked.
var attack_target: Enemy

func lock_target(enemy: Enemy) -> void:
	if not is_instance_valid(enemy) or enemy._dead: return
	attack_target = enemy

func clear_target() -> void:
	attack_target = null

func has_target() -> bool:
	return is_instance_valid(attack_target) and not attack_target._dead and attack_target.is_inside_tree() and (not is_instance_valid(game) or attack_target.game == game)

## Reach of the equipped weapon: blades BLADE_RANGE; ranged bases carry their
## own "range" (RANGED_RANGE when unset).
const RANGED_RANGE := 9.0
func weapon_range() -> float:
	if not is_ranged_weapon():
		var reach := BLADE_RANGE * form_factor(2)
		# 影落とす時針: the third stage reaches further.
		if not is_amiya() and combo_step == 2: reach *= 1.0 + 0.08 * rank("shadow_hand")
		return reach
	var weapon: Item = equipped.get(Item.Category.WEAPON)
	return float(GearCatalog.base(weapon.base_id).get("range", RANGED_RANGE))

## Each physics frame with a lock: attack when in reach and in sight, else
## walk toward it (re-pathing as it moves).
func _follow_target() -> void:
	if not has_target():
		attack_target = null
		return
	var target := attack_target
	var sight := not is_instance_valid(game) or game.line_of_sight(global_position, target.global_position)
	if is_target_in_range(target) and sight:
		_has_move_target = false
		attack(target)
		return
	if not _has_move_target or _move_target.distance_to(target.global_position) > 0.4:
		set_move_target(target.global_position)

## Half-angle of the fan an air swing reaches (60° each side of the aim).
const SWING_HALF_ANGLE := 60.0

## The nearest living enemy an air swing toward `direction` reaches: within
## blade range, inside the fan, in line of sight. Null when there is none.
func enemy_in_swing(direction: Vector3) -> Enemy:
	if not is_instance_valid(game): return null
	var aim := Vector3(direction.x, 0, direction.z).normalized()
	var best: Enemy = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.game != game or enemy._dead or not is_target_in_range(enemy): continue
		var offset := enemy.global_position - global_position
		offset.y = 0
		var distance := offset.length()
		if distance > 0.05 and aim.dot(offset / distance) < cos(deg_to_rad(SWING_HALF_ANGLE * form_factor(3))): continue
		if not game.line_of_sight(global_position, enemy.global_position): continue
		if distance < best_distance:
			best = enemy
			best_distance = distance
	return best

## Crossbows and guns (装备策划案 §2.4) — none drop yet.
func is_ranged_weapon() -> bool:
	var weapon: Item = equipped.get(Item.Category.WEAPON)
	if weapon == null or weapon.base_id.is_empty(): return false
	return str(GearCatalog.base(weapon.base_id).get("form", "")) in GearCatalog.RANGED_FORMS

func is_target_in_range(enemy: Enemy) -> bool:
	if not is_instance_valid(enemy):
		return false
	var offset := enemy.global_position - global_position
	# A terrace above or below is out of reach, however close it looks.
	if absf(offset.y) > TIER_REACH: return false
	offset.y = 0.0
	return offset.length() <= weapon_range()

func f(key: String) -> float:
	return float(fx.get(key, 0.0))

func _physics_process(delta: float) -> void:
	if is_instance_valid(game) and not (game.simulation_active() or game.base_walk_active()):
		return
	_tick_combat(delta)
	_tick_amiya(delta)
	if is_instance_valid(_shell):
		if shield > 0.5:
			_shield_peak = maxf(_shield_peak, shield)
			_shell.cracked = shield < _shield_peak * 0.5
			_shell.follow(Vector3(0, -LapplandAnimator3D.FOOT_DROP, 0))
		else:
			_shield_peak = 0.0
			if _shell.visible: _shell.shatter()
	if _tick_control(delta): return
	_attack_cooldown -= delta
	_dash_cooldown -= delta
	swing_remaining = maxf(0.0, swing_remaining - delta)
	# A dodge interrupts everything (用户 2026-10-10: 闪避时打断所有动作),
	# including a hit's freeze frames: a press that can dodge ends the freeze
	# at once. One that cannot yet (stamina, cooldown) is latched as before.
	# At a box's window her hands are busy: no dodge, no steps, no swings.
	var busy := is_instance_valid(game) and game.hands_busy()
	if Input.is_action_just_pressed("dash") and not busy: _dash_buffered = true
	if _dash_buffered and can_dash(): hitstop_remaining = 0.0
	if hitstop_remaining > 0.0:
		hitstop_remaining = maxf(0.0, hitstop_remaining - delta)
		return
	combat_timer += delta
	_tick_relic_timers(delta)
	stationary_time = 0.0 if velocity.length_squared() > 0.3 else stationary_time + delta
	if is_instance_valid(game) and game.simulation_active():
		_tick_relics_in_field(delta)
	regen_timer -= delta
	if regen_timer <= 0.0:
		regen_timer = HP_REGEN_INTERVAL
		var rate := regen_rate()
		# Positive regeneration waits until she is out of combat; contamination's
		# drain does not wait, but never takes the last point (§6 D, A2).
		if rate < 0.0: hp = maxf(minf(hp, 1.0), hp + rate * HP_REGEN_INTERVAL)
		elif hp < max_hp and not regen_blocked and combat_timer >= OUT_OF_COMBAT:
			heal(rate * HP_REGEN_INTERVAL)

	var move_vec := Vector3.ZERO if busy else _key_move_vector()
	if busy:
		_has_move_target = false
		attack_target = null
	elif move_vec != Vector3.ZERO:
		# Keys take over from a clicked destination or a locked enemy.
		_has_move_target = false
		attack_target = null
	else:
		_follow_target()
	if move_vec == Vector3.ZERO and _has_move_target:
		var to_target := _move_target - global_position
		to_target.y = 0.0
		if to_target.length() <= ARRIVE_THRESHOLD:
			_has_move_target = false
		else:
			var direction := to_target
			if is_instance_valid(_navigation) and not _navigation.is_navigation_finished():
				direction = _navigation.get_next_path_position() - global_position
				direction.y = 0
			move_vec = direction.normalized()

	var dash_pressed := _dash_buffered
	_dash_buffered = false
	if dash_pressed and can_dash():
		_start_dash(move_vec if move_vec.length_squared() > 0.01 else -global_transform.basis.z)
	if swing_remaining > 0.0 or shadow_active: move_vec = Vector3.ZERO

	if is_on_floor():
		velocity.y = -2.0
	else:
		velocity.y += GRAVITY * delta
	var speed := move_speed * (gear_fx.move_mult() if gear_fx != null else 1.0)
	velocity.x = move_vec.x * speed
	velocity.z = move_vec.z * speed
	move_and_slide()

	var regen := (STAMINA_REGEN + float(stats.get("stamina_regen", 0.0))) * (1.0 + float(stats.get("stamina_regen_pct", 0.0)))
	if equipped_effect("frozen_relic"):
		regen *= 0.6
	stamina = minf(100.0, stamina + regen * delta)
	if move_vec.length_squared() > 0.01:
		look_at(global_position + move_vec, Vector3.UP)

	if hp <= 0.0:
		died.emit()

## WASD / arrow keys as a direction on the ground, screen-relative: W walks
## toward the top of the screen whatever the camera yaw.
func _key_move_vector() -> Vector3:
	if not InputMap.has_action("move_up"): return Vector3.ZERO
	var keys := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if keys == Vector2.ZERO: return Vector3.ZERO
	var right := Vector3.RIGHT
	var down := Vector3.BACK
	var camera := get_viewport().get_camera_3d()
	if is_instance_valid(camera):
		var basis := camera.global_transform.basis
		var flat_right := Vector3(basis.x.x, 0.0, basis.x.z)
		var flat_up := Vector3(-basis.z.x, 0.0, -basis.z.z)
		if flat_up.length_squared() < 0.0001: flat_up = Vector3(basis.y.x, 0.0, basis.y.z)
		if flat_right.length_squared() > 0.0001 and flat_up.length_squared() > 0.0001:
			right = flat_right.normalized()
			down = -flat_up.normalized()
	return (right * keys.x + down * keys.y).normalized()

func _tick_relic_timers(delta: float) -> void:
	hurt_timer = maxf(0, hurt_timer - delta)
	engage_timer = maxf(0, engage_timer - delta)
	evade_timer = maxf(0, evade_timer - delta)
	wave_burst_timer = maxf(0, wave_burst_timer - delta)
	invuln_timer = maxf(0, invuln_timer - delta)
	bash_timer = maxf(0, bash_timer - delta)
	guard_timer = maxf(0, guard_timer - delta)
	guard_cooldown = maxf(0, guard_cooldown - delta)
	dance_timer = maxf(0, dance_timer - delta)
	dance_cooldown = maxf(0, dance_cooldown - delta)
	wolf_timer = maxf(0, wolf_timer - delta)
	sundial_timer = maxf(0, sundial_timer - delta)
	step_timer = maxf(0, step_timer - delta)
	nightrun_timer = maxf(0, nightrun_timer - delta)
	fury_timer = maxf(0, fury_timer - delta)
	if gear_fx != null: gear_fx.tick(delta)
	since_wave += delta
	segment_time += delta
	if hit_stacks > 0:
		hit_stack_timer -= delta
		if hit_stack_timer <= 0: hit_stacks = 0

## Relic effects that tick in the field: drains, auto charge, crowd triggers.
func _tick_relics_in_field(delta: float) -> void:
	if f("drain") > 0.0: hp -= max_hp * f("drain") * delta
	if f("auto_charge") > 0.0 and (has_sword_wave() or is_amiya()):
		_auto_charge += f("auto_charge") * delta
		while _auto_charge >= 1.0:
			_auto_charge -= 1.0
			add_charge(1)
	if f("crowd_regen") > 0.0 and nearby_enemy_count(4.0) >= 3: heal(f("crowd_regen") * delta)
	if f("crowd_guard") > 0.0 and guard_cooldown <= 0.0 and nearby_enemy_count(3.0) >= 2:
		guard_timer = CROWD_SECONDS
		guard_cooldown = CROWD_COOLDOWN
		message_requested.emit("霜牡的肩甲：攻击力与防御 +40%，持续 30 秒")
	if f("crowd_dance") > 0.0 and dance_cooldown <= 0.0 and nearby_enemy_count(3.0) >= 3:
		dance_timer = CROWD_SECONDS
		dance_cooldown = CROWD_COOLDOWN
		message_requested.emit("雪牝的护手：攻速 +80、闪避 50%，持续 30 秒")

# --- Loss of control (装备扩充策划案 §7.1) ----------------------------------------

const TENACITY := 2.0
const STUN_CAP := 1.0
const STUN_WINDOW := 10.0

func is_controlled() -> bool:
	return control_timer > 0.0

## Stun / knockback / pull from an enemy hit. Dodge invulnerability and 绝影
## ignore it; after any control ends she is immune for TENACITY seconds; within
## STUN_WINDOW a second stun is halved and a third ignored. Returns whether it took.
func apply_control(kind: String, direction: Vector3, distance: float, seconds: float) -> bool:
	if invulnerable or invuln_timer > 0.0 or shadow_active or control_immune > 0.0 or control_timer > 0.0: return false
	direction.y = 0
	var duration := seconds
	if kind == "stun":
		while not _stun_times.is_empty() and _clock - _stun_times[0] > STUN_WINDOW: _stun_times.pop_front()
		if _stun_times.size() >= 2: return false
		duration = minf(STUN_CAP, seconds) * (0.5 if _stun_times.size() == 1 else 1.0)
		_stun_times.append(_clock)
		_control_velocity = Vector3.ZERO
	else:
		duration = maxf(0.05, seconds)
		_control_velocity = (direction.normalized() if direction.length_squared() > 0.0001 else Vector3.ZERO) * (distance / duration)
	interrupt_actions_for("失控")
	control_kind = kind
	control_timer = duration
	# Shoved or dragged: a 0.15 s afterimage where she stood (新敌人攻击案 §一第 8 条).
	if kind != "stun" and is_instance_valid(game) and is_instance_valid(_sprite) and _sprite.sprite_frames != null:
		var ghost := CombatVfx.afterimage(game, _sprite, global_position, 0.5, Color("f0e6dc"))
		ghost.duration = 0.15
	if is_instance_valid(_stun_mark): _stun_mark.visible = kind == "stun"
	return true

## Each physics tick while controlled: displacement, then the timer. True means
## nothing else happens this tick.
func _tick_control(delta: float) -> bool:
	_clock += delta
	control_immune = maxf(0.0, control_immune - delta)
	if control_timer <= 0.0: return false
	control_timer = maxf(0.0, control_timer - delta)
	if _control_velocity.length_squared() > 0.0001: move_and_collide(_control_velocity * delta)
	velocity = Vector3.ZERO
	if is_instance_valid(_stun_mark) and _stun_mark.visible: _stun_mark.rotation.z += delta * 4.0
	var regen := (STAMINA_REGEN + float(stats.get("stamina_regen", 0.0))) * (1.0 + float(stats.get("stamina_regen_pct", 0.0)))
	stamina = minf(100.0, stamina + regen * delta)
	if control_timer <= 0.0:
		control_kind = ""
		_control_velocity = Vector3.ZERO
		control_immune = TENACITY
		if is_instance_valid(_stun_mark): _stun_mark.visible = false
	if hp <= 0.0: died.emit()
	return true

# --- Stats ---------------------------------------------------------------------

func dash_cost() -> float:
	return maxf(0.0, DASH_STAMINA_COST + float(stats.get("dash_cost", 0.0)))

func can_dash() -> bool:
	return stamina >= dash_cost() and _dash_cooldown <= 0.0 and control_timer <= 0.0

## Everything she is doing stops for a dodge: the swing and its animation,
## Amiya's follow-up cut and 绝影 (she reappears where she is), the attack
## lock and move order, hit freeze, and any container she is opening.
func interrupt_actions() -> void:
	interrupt_actions_for("闪避")

## The same list for a dodge and for loss of control (用户 2026-10-10 / 10-11).
func interrupt_actions_for(reason: String) -> void:
	swing_remaining = 0.0
	hitstop_remaining = 0.0
	combo_step = 0
	_pending_cuts.clear()
	if shadow_active: _end_shadow(false)
	attack_target = null
	_has_move_target = false
	if is_instance_valid(_sprite): _sprite.cancel_action()
	if is_instance_valid(game): game.cancel_channels(reason)

func _start_dash(direction: Vector3) -> void:
	if not can_dash(): return
	interrupt_actions()
	stamina -= dash_cost()
	_dash_cooldown = maxf(0.15, DASH_COOLDOWN * (1.0 + float(stats.get("dash_cd_pct", 0.0))))
	invulnerable = true
	dash_remaining = DASH_INVULN_DURATION
	_sprite.start_dash(direction)
	var start := global_position
	move_and_collide(direction.normalized() * DASH_IMPULSE)
	if is_instance_valid(game):
		for i in range(3):
			CombatVfx.afterimage(game, _sprite, start.lerp(global_position, float(i) / 3.0), 0.2 + i * 0.2)
	if has_trigger(ItemModifier.Trigger.AFTERIMAGE) and is_instance_valid(game):
		for enemy in _enemies_near_segment(start, global_position, 1.0):
			_deal(enemy, attack_power() * 1.2, "phys", false, 0.0, false)
	if rank("shadow_step") > 0: step_timer = 1.5
	if gear_fx != null: gear_fx.on_evade(start, global_position)

func _enemies_near_segment(from: Vector3, to: Vector3, radius: float) -> Array[Enemy]:
	var found: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy.game != game or enemy._dead or absf(enemy.global_position.y - from.y) > TIER_REACH: continue
		var point := Vector3(enemy.global_position.x, from.y, enemy.global_position.z)
		if point.distance_to(Geometry3D.get_closest_point_to_segment(point, from, to)) <= radius: found.append(enemy)
	return found

func nearby_enemy_count(radius: float) -> int:
	var count := 0
	if not is_instance_valid(game): return 0
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy.game == game and not enemy._dead and Vector2(enemy.global_position.x - global_position.x, enemy.global_position.z - global_position.z).length() <= radius:
			count += 1
	return count

func _tick_combat(delta: float) -> void:
	combo_idle += delta
	if combo_idle >= maxf(COMBO_WINDOW, current_cooldown() + 0.5): combo_step = 0
	if sword_charge > 0 and sword_charge < wave_hits_needed():
		charge_idle += delta
		if charge_idle >= 4.0: clear_charge()
	if dash_remaining > 0:
		dash_remaining = maxf(0, dash_remaining - delta)
		if dash_remaining == 0: invulnerable = false

## Whether Lappland has a sword wave to charge (weapon affix). Amiya has no
## charge: her 绝影 is an active skill on a cooldown.
## 剑气 is hers (用户 2026-10-04, 精英化案 §8.1): no affix needed. The old 剑气
## affix is now 剑气强化 (+25% wave damage), read in _recompute_stats.
func has_sword_wave() -> bool:
	return not is_amiya()

## Whether any worn item carries this special-equipment trigger (SpecialGear).
func has_trigger(trigger: ItemModifier.Trigger) -> bool:
	for item in equipped.values():
		if item == null: continue
		for mod in item.modifiers:
			if mod.trigger == trigger: return true
	return false

func wave_hits_needed() -> int:
	return 1 if wolf_timer > 0.0 else WAVE_HITS

func add_charge(amount: int) -> void:
	# Charge gains (relics) shorten Amiya's cooldown instead.
	if is_amiya():
		refund_shadow(amount)
		return
	if not has_sword_wave() or amount <= 0: return
	var before := sword_charge
	sword_charge = mini(wave_hits_needed(), sword_charge + amount)
	charge_idle = 0
	if sword_charge == wave_hits_needed() and before < sword_charge and is_instance_valid(game):
		game.sound.play("charge")
	stats_changed.emit()

func clear_charge() -> void:
	sword_charge = 0
	charge_idle = 0
	stats_changed.emit()

func reset_combat_state(clear_stacks: bool = true) -> void:
	if clear_stacks: clear_charge()
	combo_step = 0
	combo_idle = 0
	hitstop_remaining = 0
	dash_remaining = 0
	_dash_buffered = false
	invulnerable = false
	_pending_cuts.clear()
	_end_shadow()
	if is_instance_valid(_sprite): _sprite.cancel_action()

func attack(target: Enemy) -> void:
	if not is_instance_valid(target) or target._dead or not is_target_in_range(target): return
	if is_instance_valid(game) and (target.game != game or not game.line_of_sight(global_position, target.global_position)): return
	attack_direction(_get_attack_direction(target), target)

## Ground clicks swing at the air (用户 2026-10-07): a melee swing still lands
## on the nearest enemy within reach in front of her, or releases a stored
## wave; one that reaches nobody is a whiff and never charges. A ranged weapon
## cannot swing at nothing — it needs a target.
func attack_direction(direction: Vector3, target: Enemy = null) -> void:
	if _attack_cooldown > 0 or hitstop_remaining > 0 or dash_remaining > 0 or shadow_active or control_timer > 0.0: return
	if is_instance_valid(game) and not game.simulation_active(): return
	if not is_instance_valid(target) and is_ranged_weapon(): return
	direction.y = 0
	if direction.length_squared() < 0.001: direction = -global_basis.z
	direction = direction.normalized()
	if not is_instance_valid(target): target = enemy_in_swing(direction)
	var release := has_sword_wave() and sword_charge >= wave_hits_needed()
	var stage := combo_step
	var lands := is_instance_valid(target) and not target._dead and is_target_in_range(target) and (not is_instance_valid(game) or game.line_of_sight(global_position, target.global_position))
	# attack_multiplier() spends 赏善郎's one-shot bonus: a swing that damages
	# nothing must not spend it.
	var hit := lands or release
	if hit and combat_timer >= OUT_OF_COMBAT and f("engage_aspd") > 0.0: engage_timer = 10.0
	var multiplier := attack_multiplier() if hit else 0.0
	var crit_chance := crit_rate() + (gear_fx.crit_bonus(target) if gear_fx != null else 0.0)
	if step_timer > 0.0:
		crit_chance += 0.10 * rank("shadow_step")
		if hit: step_timer = 0.0
	var crit := hit and ((gear_fx != null and gear_fx.take_forced_crit()) or randf() < crit_chance)
	var crit_factor := crit_damage() if crit else 1.0
	if hit:
		combat_timer = 0
		if gear_fx != null: gear_fx.on_attack()
	_attack_cooldown = current_cooldown()
	combo_idle = 0
	combo_step = 0 if release else (combo_step + 1) % 3
	look_at(global_position + direction, Vector3.UP)
	if is_amiya():
		_amiya_swing(direction, target, stage, lands, multiplier, crit, crit_factor)
		return
	_sprite.play_attack(direction, stage, release, animation_rate())
	swing_remaining = _sprite.action_duration
	if is_instance_valid(game):
		game.sound.play("hit")
		var foot := Vector3(global_position.x, 0.09, global_position.z)
		CombatVfx.spawn(game, foot, direction, "slash", stage, release).speed_up(animation_rate())
		if release:
			clear_charge()
			var wave_damage := arts_power() * SkillTrees.wave_scale(rank("wave")) * wave_multiplier() * multiplier * crit_factor
			if gear_fx != null: wave_damage *= gear_fx.spend_signature_bonus()
			match transmuter("wave"):
				"wave_pack":
					for side in [-1.0, 0.0, 1.0]: _spawn_wave(direction.rotated(Vector3.UP, deg_to_rad(20.0 * side)), wave_damage * 0.45, crit, side != 0.0)
				_: _spawn_wave(direction, wave_damage, crit, false)
			if gear_fx != null: gear_fx.on_signature(direction, enemy_in_swing(direction) if target == null else target)
			if has_trigger(ItemModifier.Trigger.TWIN_WAVE):
				for side in [-1.0, 1.0]:
					_spawn_wave(direction.rotated(Vector3.UP, deg_to_rad(20.0 * side)), wave_damage * 0.5, crit, true)
			CombatVfx.spawn(game, foot, direction, "burst", 0, true)
			game.start_sword_shake()
	if release: _on_wave_released()
	if lands:
		var stop := 0.05 if release or stage == 2 else 0.03
		var raw := attack_power() * stage_scale(stage) * form_factor(1) * multiplier * target_multiplier(target) * crit_factor
		var pierce := physical_pierce()
		# 狼魂: her blades strike as arts while it runs (PRTS: 伤害类型变为法术).
		var kind := "arts" if wolf_timer > 0.0 else "phys"
		_deal(target, raw, kind, crit, pierce if kind == "phys" else 0.0, true)
		_melee_riders(target, raw, crit, pierce)
		_after_landed(target, raw, stage)
		_try_execute(target)
		target.hitstop_remaining = maxf(target.hitstop_remaining, stop)
		hitstop_remaining = stop
		if is_instance_valid(game): CombatVfx.spawn(game, target.global_position, direction, "spark")
		if crit and has_trigger(ItemModifier.Trigger.MOON_WAVE) and randf() < 0.35:
			_spawn_wave(direction, arts_power() * WAVE_SCALE * wave_multiplier() * 0.5, false, true)
		if f("hit_stack_atk") > 0.0:
			hit_stacks = mini(HIT_STACK_MAX, hit_stacks + 1)
			hit_stack_timer = HIT_STACK_SECONDS
		if not release:
			add_charge(1 + (int(f("finisher_charge")) if stage == 2 else 0))

## What every landed basic hit adds from the tree and gear: 日晷 and its
## modifier on stage 3, 精神摧毁, 狼魂's extra target, the gear hit effects.
func _after_landed(target: Enemy, raw: float, stage: int) -> void:
	if not is_instance_valid(target): return
	if gear_fx != null: gear_fx.on_hit(target, raw)
	if target._dead: return
	if not is_amiya():
		if stage == 2 and rank("sundial") > 0: sundial_timer = 4.0
		if stage == 2 and rank("shadow_hand") > 0: target.apply_status("slow", 2.0, 0.06 * rank("shadow_hand"))
		var mind := SkillTrees.mind_break(elite_stage(), module_level())
		if float(mind[0]) > 0.0:
			target.silence(float(mind[1]) if target.elite or target.boss else float(mind[0]))
			if float(mind[2]) > 0.0: target.apply_status("fragile", 6.0, float(mind[2]))
		if wolf_timer > 0.0 and rank("extra_target") > 0 and is_instance_valid(game):
			for node in get_tree().get_nodes_in_group("enemies"):
				var other := node as Enemy
				if other == target or other == null or other.game != game or other._dead: continue
				if _flat(other.global_position - global_position) <= 4.0:
					_deal(other, attack_power() * SkillTrees.extra_target(rank("extra_target")), "arts", false, 0.0, false)
					break

## After a wave leaves: 拳经三问 counts it, 绿叶菜罐头 opens its window, and the
## "噤声" / 鸣脊兽 build-ups start over. Waves count toward 狼魂 (not those
## released during it, or it would chain).
func _on_wave_released() -> void:
	if not is_amiya() and rank("wolf_spirit") > 0 and wolf_timer <= 0.0:
		wolf_waves += 1
		if wolf_waves >= int(SkillTrees.wolf_spirit(rank("wolf_spirit"))[0]):
			wolf_waves = 0
			wolf_timer = 6.0
			stats_changed.emit()
	wave_count = mini(WAVE_STACK_MAX, wave_count + 1)
	if f("wave_burst_atk") > 0.0: wave_burst_timer = 1.0
	since_wave = 0.0

## 扼喉之手 / 溃决之手: an ordinary enemy under the line dies on the hit.
func _try_execute(target: Enemy) -> void:
	if f("execute") <= 0.0 or not is_instance_valid(target) or target._dead or target.elite: return
	if target.health / maxf(target.max_health, 1.0) < f("execute"):
		target.take_hit(target.health + 1.0, "true")

## What a landed melee hit carries besides itself (special equipment). These
## are proc damage: no lifesteal and no further procs (§4.4).
func _melee_riders(target: Enemy, raw: float, crit: bool, pierce: float) -> void:
	target.hit_by_player = true
	if target._dead: return
	if has_trigger(ItemModifier.Trigger.ARTS_EDGE): _deal(target, arts_power() * 0.18, "arts", false, 0.0, false)
	if has_trigger(ItemModifier.Trigger.SHIELD_BASH) and bash_timer > 0:
		bash_timer = 0
		_deal(target, defense_value() * 1.5, "phys", false, 0.0, false)
	if has_trigger(ItemModifier.Trigger.CLEAVE) and is_instance_valid(game):
		for node in get_tree().get_nodes_in_group("enemies"):
			var other := node as Enemy
			if other == target or other.game != game or other._dead: continue
			if Vector2(other.global_position.x - target.global_position.x, other.global_position.z - target.global_position.z).length() <= 1.8:
				_deal(other, raw * 0.5, "phys", crit, pierce, false)

func _spawn_wave(direction: Vector3, damage: float, crit: bool, extra: bool) -> void:
	if not is_instance_valid(game): return
	var wave := SwordWave.new()
	wave.direction = direction
	wave.damage = damage
	wave.crit = crit
	wave.extra = extra
	wave.position = global_position
	# 远程攻击不再降低攻击力: the flight decay shrinks 20% a rank.
	wave.decay = SwordWave.BASE_DECAY * maxf(0.0, 1.0 - 0.2 * rank("no_decay"))
	match transmuter("wave"):
		"wave_fang":
			wave.width_scale *= 1.6
			wave.range_bonus += 4.0
			wave.damage *= 0.8
		"wave_hound":
			wave.homing = true
			wave.range_bonus -= SwordWave.RANGE * 0.3
	game.add_child(wave)

## Deals a hit and returns what landed. `direct` hits feed lifesteal.
func _deal(target: Enemy, raw: float, kind: String, crit: bool, pierce: float = 0.0, direct: bool = true) -> float:
	if not is_instance_valid(target) or target._dead: return 0.0
	if kind == "arts": raw *= 1.0 + float(stats.get("arts_dmg_pct", 0.0))
	elif kind == "phys": raw *= 1.0 + float(stats.get("phys_dmg_pct", 0.0))
	var dealt := target.take_hit(raw, kind, crit, pierce)
	if direct and dealt > 0.0: heal(dealt * lifesteal())
	return dealt

## Called by a sword wave for each enemy it passes through.
func on_wave_hit(enemy: Enemy, dealt: float, _wave: SwordWave) -> void:
	if dealt > 0.0: heal(dealt * lifesteal())
	if not is_instance_valid(enemy): return
	if has_trigger(ItemModifier.Trigger.EMBER): enemy.apply_status("burn", 4.0, arts_power() * 0.10 * (1.0 + float(stats.get("arts_dmg_pct", 0.0))))
	_try_execute(enemy)

## Per-target multiplier for a wave about to hit `enemy` (its arts bonus is
## applied here, its resistance in Enemy.take_hit).
func wave_bonus_against(enemy: Enemy) -> float:
	return target_multiplier(enemy) * (1.0 + float(stats.get("arts_dmg_pct", 0.0)))

## How much faster than authored the swing plays. Only ever speeds up: at or
## below base speed the 12 FPS swing already fits inside the interval.
func animation_rate() -> float:
	return maxf(1.0, BASE_BLADE_COOLDOWN / current_cooldown())

func _get_attack_direction(target: Enemy) -> Vector3:
	if is_instance_valid(target):
		var dir := target.global_position - global_position
		dir.y = 0
		if dir.length_squared() > 0.01: return dir.normalized()
	return -global_transform.basis.z

## kind: "phys" (minus defence), "arts" (scaled by resistance) or "true".
## `attacker` lets 墙眼 tell ranged hits apart and 尖刺重铠 answer.
func take_damage(amount: float, kind: String = "phys", attacker: Enemy = null) -> void:
	if invulnerable or invuln_timer > 0.0:
		return
	combat_timer = 0.0
	if (kind == "phys" and randf() < evasion()) or (kind == "arts" and randf() < arts_evasion()):
		_on_evade()
		if is_instance_valid(game): DamageNumber.spawn(game, global_position, "闪避", "evade")
		return
	if blocks_left > 0:
		blocks_left -= 1
		_on_block()
		if is_instance_valid(game): DamageNumber.spawn(game, global_position, "抵挡", "shield")
		return
	if gear_fx != null: amount = gear_fx.incoming(amount, attacker)
	amount = CombatStats.mitigate(amount, kind, defense_value(), resistance())
	var reduction := 0.25 if equipped_effect("riot_shield") else 0.0
	if is_instance_valid(attacker) and attacker.ranged: reduction -= f("ranged_taken")
	amount *= 1.0 - minf(CombatStats.REDUCTION_CAP, reduction)
	amount *= 1.0 + float(stats.get("taken_pct", 0.0))
	if has_trigger(ItemModifier.Trigger.THORNS) and is_instance_valid(attacker) and not attacker._dead:
		attacker.take_hit(defense_value() * 0.8, "phys")
	if shield > 0.0 and amount > 0.0:
		var absorbed := minf(shield, amount)
		shield -= absorbed
		amount -= absorbed
		if shield <= 0.0 and gear_fx != null: gear_fx.on_shield_broken()
		if has_trigger(ItemModifier.Trigger.SHIELD_BASH): bash_timer = 3.0
		if is_instance_valid(game): DamageNumber.spawn(game, global_position, str(roundi(absorbed)), "shield")
	if amount <= 0.0:
		stats_changed.emit()
		return
	hurt_timer = 5.0
	if f("hurt_stack_aspd") > 0.0: hurt_stacks = mini(HURT_STACK_MAX, hurt_stacks + 1)
	if hp - amount <= 0.0 and _survive_lethal(): return
	if not _low_hp_ward_used_this_floor and _has_low_hp_ward() and (hp - amount) / max_hp < 0.3:
		_low_hp_ward_used_this_floor = true
		message_requested.emit("临界护盾化解了这次伤害")
		return
	if is_instance_valid(game):
		game.sound.play("hurt")
		DamageNumber.spawn(game, global_position, str(roundi(amount)), "hurt")
	hp -= amount
	if gear_fx != null: gear_fx.on_hurt(amount, attacker)
	if is_instance_valid(_sprite): _sprite.play_hurt()
	message_requested.emit("受到伤害！观察敌人的蓄力姿势与武器方向，及时侧移或闪避。")
	stats_changed.emit()

## 复还之手 (once a segment, back to full) then "时光之末" (once a contract, 1 life).
func _survive_lethal() -> bool:
	if f("death_full") > 0.0 and not death_full_used:
		death_full_used = true
		hp = max_hp
		invuln_timer = 1.0
		message_requested.emit("复还之手：受到致命伤时回满生命（本区段已用）")
		stats_changed.emit()
		return true
	if f("death_cling") > 0.0 and not death_cling_used:
		death_cling_used = true
		hp = 1.0
		invuln_timer = 2.0
		message_requested.emit("\"时光之末\"：保留 1 点生命（本合同已用）")
		stats_changed.emit()
		return true
	return false

func _on_evade() -> void:
	if f("evade_atk") > 0.0: evade_timer = 6.0
	if f("avenge") > 0.0: avenge_ready = true

func _on_block() -> void:
	if f("avenge") > 0.0: avenge_ready = true

func _has_low_hp_ward() -> bool:
	for item in equipped.values():
		if item == null:
			continue
		for mod in item.modifiers:
			if mod.trigger == ItemModifier.Trigger.LOW_HP_SHIELD_ONCE_PER_FLOOR:
				return true
	return false

## Entering a segment: the per-segment relics reset, the opening ones fire.
func reset_floor_state() -> void:
	reset_combat_state(false)
	_low_hp_ward_used_this_floor = false
	death_full_used = false
	hurt_stacks = 0
	segment_time = 0.0
	blocks_left = int(f("segment_blocks"))
	shield = max_hp * f("segment_shield")
	if gear_fx != null: gear_fx.reset_segment()
	if f("altar") > 0.0 and altar_stacks < ALTAR_MAX and randf() < f("altar"):
		altar_stacks += 1
		message_requested.emit("圆石祭坛：攻击力与防御 +5%%（%d 层）" % altar_stacks)
	_recompute_stats()
	if f("segment_charge") > 0.0: add_charge(int(f("segment_charge")))

## Healing scales with 治疗效果.
func heal(amount: float, show: bool = false) -> void:
	if amount <= 0.0: return
	amount *= 1.0 + float(stats.get("heal_pct", 0.0))
	hp = minf(max_hp, hp + amount)
	if show and is_instance_valid(game): DamageNumber.spawn(game, global_position, "+%d" % roundi(amount), "heal")
	stats_changed.emit()

func apply_buff(hp_bonus: float, damage_bonus_add: float) -> void:
	_buff_max_hp_bonus += hp_bonus
	_buff_damage_bonus += damage_bonus_add
	_recompute_stats()
	hp = max_hp  # a fresh buff tops off the new max, same as before equipment existed

func reset_stats() -> void:
	reset_combat_state()
	_buff_max_hp_bonus = 0.0
	_buff_damage_bonus = 0.0
	equipped.clear()  # settle() re-equips what she set out with and brought back.
	hurt_timer = 0
	engage_timer = 0
	since_wave = 0
	hit_stacks = 0
	avenge_ready = false
	evade_timer = 0
	wave_count = 0
	wave_burst_timer = 0
	_auto_charge = 0
	hurt_stacks = 0
	blocks_left = 0
	segment_time = 0
	guard_timer = 0
	guard_cooldown = 0
	dance_timer = 0
	dance_cooldown = 0
	death_full_used = false
	death_cling_used = false
	elite_kills = 0
	altar_stacks = 0
	invuln_timer = 0
	bash_timer = 0
	shield = 0
	shadow_cooldown = 0.0
	if gear_fx != null: gear_fx.reset()
	wolf_timer = 0.0
	wolf_waves = 0
	sundial_timer = 0.0
	step_timer = 0.0
	nightrun_timer = 0.0
	fury_timer = 0.0
	control_timer = 0.0
	control_kind = ""
	control_immune = 0.0
	_stun_times.clear()
	if is_instance_valid(_stun_mark): _stun_mark.visible = false
	_recompute_stats()
	hp = max_hp
	invulnerable = false
	stamina = 100
	combat_timer = 6
	_attack_cooldown = 0
	swing_remaining = 0.0
	_dash_cooldown = 0
	regen_timer = HP_REGEN_INTERVAL

func equip(item: Item) -> Item:
	if item == null or not item.is_equippable():
		return null
	var previous: Item = equipped.get(item.category)
	if item.category == Item.Category.WEAPON and previous != item: clear_charge()
	equipped[item.category] = item
	_recompute_stats()
	return previous

func unequip(category: Item.Category) -> Item:
	var item: Item = equipped.get(category)
	if item != null:
		if category == Item.Category.WEAPON: clear_charge()
		equipped.erase(category)
		_recompute_stats()
	return item

const MODIFIER_KEYS := {
	ItemModifier.Stat.MAX_HP_PCT: "hp_pct", ItemModifier.Stat.MOVE_SPEED_PCT: "move_pct",
	ItemModifier.Stat.BLADE_COOLDOWN_PCT: "interval_pct", ItemModifier.Stat.GOLD_GAIN_PCT: "gold_pct",
	ItemModifier.Stat.POTION_CAPACITY_FLAT: "potion_cap", ItemModifier.Stat.ATK_PCT: "atk_pct",
	ItemModifier.Stat.ARTS_PCT: "arts_pct", ItemModifier.Stat.DEF_FLAT: "def", ItemModifier.Stat.RES_FLAT: "res",
	ItemModifier.Stat.CRIT_RATE: "crit", ItemModifier.Stat.CRIT_DMG: "crit_dmg",
}

func _recompute_stats() -> void:
	var sheet := CombatStats.empty()
	for item in equipped.values():
		if item == null:
			continue
		CombatStats.add(sheet, CombatStats.power_stats(item.category, item.power))
		for mod in item.modifiers:
			# The old 剑气 affix is 剑气强化 now: +25% wave damage on a weapon.
			if mod.trigger == ItemModifier.Trigger.SWORD_WAVE and item.category == Item.Category.WEAPON: sheet.wave_pct += 0.25
			if mod.trigger != ItemModifier.Trigger.NONE: continue
			if mod.stat == ItemModifier.Stat.ATTACK_SPEED_PCT:
				# Attack speed affixes were authored as +10% rate; on the 100-point
				# scale that is +10 攻速, the same interval.
				sheet.aspd += mod.amount * 100.0
			elif MODIFIER_KEYS.has(mod.stat):
				sheet[MODIFIER_KEYS[mod.stat]] += mod.amount
	if is_instance_valid(game):
		CombatStats.add(sheet, RelicCatalog.stat_sheet(game.builds))
		fx = RelicCatalog.fx_sum(game.builds)
	else:
		fx = {}
	# Growth: attribute points, the module, 精英 2's resistance (精英化案 §3, §5, §8).
	var p := progress()
	if p != null:
		CombatStats.add(sheet, p.attribute_sheet())
		if p.module_level > 0: CombatStats.add(sheet, SkillTrees.MODULES[operator_id].stats)
		if p.elite >= 2: sheet.res += Progression.E2_RES
	if gear_fx != null: CombatStats.add(sheet, gear_fx.static_sheet())
	stats = sheet
	var hp_pct := float(sheet.hp_pct) + f("elite_hp_stack") * mini(ELITE_STACK_MAX, elite_kills) + _axe_and_route_bonus()
	max_hp = maxf(1.0, (CombatStats.BASE.hp + _buff_max_hp_bonus + float(sheet.hp)) * maxf(0.1, 1.0 + hp_pct) * (1.0 - condition_hp_penalty))
	damage_bonus = 1.0 + _buff_damage_bonus + float(sheet.dmg_pct)
	move_speed = BASE_MOVE_SPEED * maxf(0.3, 1.0 + float(sheet.move_pct))
	# 攻速 divides the interval (明日方舟: interval / (攻速 / 100)), so stacking it
	# never reaches zero; interval modifiers scale it directly.
	attack_speed = clampf(CombatStats.BASE.aspd + float(sheet.aspd), CombatStats.ASPD_MIN, CombatStats.ASPD_MAX) / 100.0
	blade_cooldown = maxf(MIN_BLADE_COOLDOWN, BASE_BLADE_COOLDOWN * (1.0 + float(sheet.interval_pct)) / attack_speed)
	gold_gain_multiplier = 1.0 + float(sheet.gold_pct)
	potion_heal_multiplier = maxf(0.2, 1.0 + BaseCatalog.POTION_HEAL_PER_CAP * float(sheet.potion_cap))
	hp = minf(hp, max_hp)
	stats_changed.emit()

## 登天斧 fades with depth; 统帅肖像's extra share needs the deep route. Both
## count toward ATK and max life.
func _axe_and_route_bonus() -> float:
	if not is_instance_valid(game): return 0.0
	var bonus := 0.0
	if f("axe") > 0.0: bonus += maxf(0.0, f("axe") - 0.10 * (game.floor_number - 1))
	if f("route_bonus") > 0.0 and game.route_index == 2: bonus += f("route_bonus")
	return bonus

func has_build(id: String) -> bool:
	return is_instance_valid(game) and game.builds.has(id)

func equipped_effect(effect: String) -> bool:
	for item in equipped.values():
		if item != null and item.effect == effect: return true
	return false

func ore_count() -> int:
	return game.count_effect("raw_ore") if is_instance_valid(game) else 0

func hp_ratio() -> float:
	return clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)

func full_hp() -> bool:
	return hp >= max_hp - 0.5

## 攻击力 right now: (base + flat) × (1 + every +X%, static and conditional,
## added together the way 明日方舟 stacks one layer).
func attack_power() -> float:
	var pct := float(stats.get("atk_pct", 0.0))
	pct += f("full_hp_atk") * hp_ratio()
	pct += f("build_atk") * minf(1.0, since_wave / BUILD_ATK_SECONDS)
	pct += f("hit_stack_atk") * hit_stacks
	if wave_burst_timer > 0.0: pct += f("wave_burst_atk")
	if evade_timer > 0.0: pct += f("evade_atk")
	pct += f("wave_stack_atk") * wave_count
	if f("lone_atk") > 0.0 and nearby_enemy_count(6.0) == 1: pct += f("lone_atk")
	if guard_timer > 0.0: pct += 0.40
	pct += 0.05 * altar_stacks
	pct += _axe_and_route_bonus()
	pct += _growth_atk_pct()
	if gear_fx != null: pct += gear_fx.atk_pct()
	return (CombatStats.BASE.atk + float(stats.get("atk", 0.0))) * maxf(0.1, 1.0 + pct)

## 狼魂's ATK while it runs, 青色怒火 (doubled during and just after 绝影),
## 每击败一个敌人 stacks during 绝影.
func _growth_atk_pct() -> float:
	var pct := 0.0
	if wolf_timer > 0.0: pct += float(SkillTrees.wolf_spirit(rank("wolf_spirit"))[1])
	if is_amiya():
		pct += _cyan_fury()
		if shadow_active: pct += SkillTrees.kill_stack(rank("kill_stack")) * shadow_kill_stacks
	return pct

func _cyan_fury() -> float:
	if not is_amiya(): return 0.0
	var fury := SkillTrees.cyan_fury(elite_stage(), module_level())
	return fury * (2.0 if shadow_active or fury_timer > 0.0 else 1.0)

func arts_power() -> float:
	var pct := float(stats.get("arts_pct", 0.0))
	return (CombatStats.BASE.arts + float(stats.get("arts", 0.0))) * maxf(0.1, 1.0 + pct)

func defense_value() -> float:
	var flat := CombatStats.BASE.def + float(stats.get("def", 0.0))
	if f("linger") > 0.0 and segment_time >= LINGER_SECONDS: flat += 300.0
	var pct := float(stats.get("def_pct", 0.0)) + 0.05 * altar_stacks
	if f("full_def") > 0.0 and full_hp(): pct += 0.20
	if guard_timer > 0.0: pct += 0.40
	pct += _cyan_fury()
	if gear_fx != null: pct += gear_fx.def_pct()
	return flat * maxf(0.0, 1.0 + pct)

func resistance() -> float:
	var res := CombatStats.BASE.res + float(stats.get("res", 0.0))
	if f("linger") > 0.0 and segment_time >= LINGER_SECONDS: res += 30.0
	if shadow_active and rank("kill_stack") > 0: res += 20.0 * shadow_kill_stacks
	if f("full_def") > 0.0 and full_hp(): res += 10.0
	return minf(CombatStats.RES_CAP, res)

func crit_rate() -> float:
	return clampf(CombatStats.BASE.crit + float(stats.get("crit", 0.0)), 0.0, CombatStats.CRIT_CAP)

func crit_damage() -> float:
	return CombatStats.BASE.crit_dmg + float(stats.get("crit_dmg", 0.0))

func lifesteal() -> float:
	return clampf(float(stats.get("lifesteal", 0.0)), 0.0, CombatStats.LIFESTEAL_CAP)

func evasion() -> float:
	var value := float(stats.get("evasion", 0.0)) + (0.5 if dance_timer > 0.0 else 0.0)
	if sundial_timer > 0.0: value += float(SkillTrees.sundial(rank("sundial"))[0])
	return clampf(value, 0.0, CombatStats.EVASION_CAP if dance_timer <= 0.0 else 0.75)

func arts_evasion() -> float:
	var value := float(stats.get("evasion_arts", 0.0)) + (0.5 if dance_timer > 0.0 else 0.0)
	if nightrun_timer > 0.0: value += 0.15
	return clampf(value, 0.0, CombatStats.EVASION_CAP if dance_timer <= 0.0 else 0.75)

## Self-regeneration per second (paid out every HP_REGEN_INTERVAL).
func regen_rate() -> float:
	return (CombatStats.BASE.regen + float(stats.get("regen", 0.0))) * (1.0 + float(stats.get("regen_pct", 0.0))) + max_hp * float(stats.get("regen_max_pct", 0.0)) 		- contamination * BaseCatalog.CONTAMINATION_REGEN_PER_POINT

## Injury and contamination: recomputes max HP when the cut moves.
func set_condition(injured: bool, contamination_now: float) -> void:
	contamination = contamination_now
	var penalty := BaseCatalog.hp_penalty(contamination_now, injured)
	if absf(penalty - condition_hp_penalty) < 0.0005: return
	condition_hp_penalty = penalty
	_recompute_stats()
	hp = minf(hp, max_hp)

## 攻速 right now, with every timed or conditional bonus.
func current_aspd() -> float:
	var aspd := CombatStats.BASE.aspd + float(stats.get("aspd", 0.0))
	if hurt_timer > 0.0: aspd += f("hurt_aspd")
	if engage_timer > 0.0: aspd += f("engage_aspd")
	aspd += f("build_aspd") * minf(1.0, since_wave / BUILD_ASPD_SECONDS)
	aspd += f("hurt_stack_aspd") * hurt_stacks
	aspd += f("low_hp_aspd") * clampf((1.0 - hp_ratio()) / 0.7, 0.0, 1.0)
	if hp_ratio() < 0.25: aspd += f("critical_aspd")
	if full_hp(): aspd += f("full_aspd")
	if f("gold_aspd") > 0.0 and is_instance_valid(game): aspd += f("gold_aspd") * minf(10.0, floorf(game.gold_bars() / 5.0))
	aspd += f("elite_aspd_stack") * mini(ELITE_STACK_MAX, elite_kills)
	if dance_timer > 0.0: aspd += 80.0
	# 狂暴攻势: the second and third stages of an unbroken combo come faster.
	if not is_amiya() and combo_step >= 1: aspd += 4.0 * rank("frenzy")
	if gear_fx != null: aspd += gear_fx.aspd_bonus()
	return clampf(aspd, CombatStats.ASPD_MIN, CombatStats.ASPD_MAX)

func current_cooldown() -> float:
	return maxf(MIN_BLADE_COOLDOWN, BASE_BLADE_COOLDOWN * form_factor(0) * (1.0 + float(stats.get("interval_pct", 0.0))) / (current_aspd() / 100.0))

func stage_scale(stage: int) -> float:
	var scale: float = COMBO_SCALES[clampi(stage, 0, 2)]
	# 日晷: the third stage, the hour hand's sweep, hits harder.
	if stage == 2 and not is_amiya(): scale *= 1.0 + float(SkillTrees.sundial(rank("sundial"))[1])
	return scale

func physical_pierce() -> float:
	return clampf(float(stats.get("def_ignore", 0.0)), 0.0, 1.0)

func wave_multiplier() -> float:
	return 1.0 + float(stats.get("wave_pct", 0.0))

## Conditional damage multipliers that do not depend on the target. Spends
## 赏善郎's one-shot bonus, so it is only called for a swing that lands.
func attack_multiplier() -> float:
	var multiplier := damage_bonus
	if equipped_effect("frozen_relic"): multiplier *= 1.4
	if avenge_ready:
		multiplier *= 1.0 + f("avenge")
		avenge_ready = false
	return multiplier

## Multipliers that depend on who is being hit.
func target_multiplier(enemy: Enemy) -> float:
	if not is_instance_valid(enemy): return 1.0
	var multiplier := 1.0
	var ratio := clampf(enemy.health / maxf(enemy.max_health, 1.0), 0.0, 1.0)
	multiplier *= 1.0 + f("wounded_dmg") * (1.0 - ratio)
	if enemy.elite: multiplier *= 1.0 + float(stats.get("elite_pct", 0.0))
	if gear_fx != null: multiplier *= gear_fx.damage_mult(enemy)
	return multiplier

## Called by GameManager whenever an enemy dies.
func on_kill(enemy: Enemy) -> void:
	if not is_instance_valid(game) or enemy == null: return
	if f("kill_heal") > 0.0: heal(f("kill_heal"))
	if f("kill_charge") > 0.0:
		add_charge(int(f("kill_charge")))
		stamina = minf(100.0, stamina + 10.0)
	if enemy.elite:
		elite_kills += 1
		if f("elite_hp_stack") > 0.0: _recompute_stats()
	if gear_fx != null: gear_fx.on_kill(enemy)
	if shadow_active and is_amiya():
		if rank("kill_stack") > 0: shadow_kill_stacks = mini(3, shadow_kill_stacks + 1)
		if rank("true_after_kill") > 0: shadow_true = true
	if has_trigger(ItemModifier.Trigger.VEIN_BURST) and not _in_burst and randf() < 0.3:
		_in_burst = true
		var centre := enemy.global_position
		CombatVfx.spawn(game, Vector3(centre.x, 0.09, centre.z), Vector3.FORWARD, "burst", 0, true)
		for node in get_tree().get_nodes_in_group("enemies"):
			var other := node as Enemy
			if other == enemy or other.game != game or other._dead: continue
			if Vector2(other.global_position.x - centre.x, other.global_position.z - centre.z).length() <= 2.5:
				_deal(other, arts_power(), "arts", false, 0.0, false)
		_in_burst = false

# --- Amiya (Guard) --------------------------------------------------------------

func _amiya_swing(direction: Vector3, target: Enemy, stage: int, lands: bool, multiplier: float, crit: bool, crit_factor: float) -> void:
	_sprite.play_attack(direction, stage, false, animation_rate())
	swing_remaining = _sprite.action_duration
	if is_instance_valid(game):
		game.sound.play("hit")
		var foot := Vector3(global_position.x, 0.09, global_position.z)
		CombatVfx.spawn(game, foot, direction, "amiya_slash", stage).speed_up(animation_rate())
	if not lands: return
	var stop := 0.05 if stage == 2 else 0.03
	var cuts: Array = AMIYA_COMBO[stage].duplicate()
	# 影霄·奔夜: stage 2's double cut hits harder; 二连击 may add a third.
	var factor := multiplier * target_multiplier(target) * crit_factor * form_factor(1)
	if stage == 1:
		factor *= 1.0 + SkillTrees.nightrun(rank("nightrun"))
		if rank("nightrun") > 0: nightrun_timer = 2.0
		if randf() < 0.08 * rank("double_cut"): cuts.append(0.55)
	_amiya_cut(target, attack_power() * float(cuts[0]) * factor, crit, direction)
	target.hitstop_remaining = maxf(target.hitstop_remaining, stop)
	hitstop_remaining = stop
	for i in range(1, cuts.size()):
		_pending_cuts.append({"at": AMIYA_SECOND_CUT * i, "target": target, "direction": direction, "crit": crit,
			"raw": attack_power() * float(cuts[i]) * factor})

## One landed combo cut: arts damage, the melee riders, and 绝影's cooldown
## shortened by SHADOW_REFUND (剑圣 Q: every basic attack cuts the cooldown).
func _amiya_cut(target: Enemy, raw: float, crit: bool, direction: Vector3) -> void:
	if not is_instance_valid(target) or target._dead: return
	_deal(target, raw, "arts", crit, 0.0, true)
	_melee_riders(target, raw, crit, 0.0)
	_after_landed(target, raw, 0)
	_try_execute(target)
	if is_instance_valid(game): CombatVfx.spawn(game, target.global_position, direction, "amiya_spark")
	if f("hit_stack_atk") > 0.0:
		hit_stacks = mini(HIT_STACK_MAX, hit_stacks + 1)
		hit_stack_timer = HIT_STACK_SECONDS
	refund_shadow(1)

## Cooldown shortened by `hits` refunds (basic cuts; relic "charge" gains).
func refund_shadow(hits: int) -> void:
	if hits <= 0 or shadow_cooldown <= 0.0: return
	shadow_cooldown = maxf(0.0, shadow_cooldown - (SHADOW_REFUND + 0.1 * rank("quilon")) * hits)
	if shadow_cooldown == 0.0 and is_instance_valid(game): game.sound.play("charge")
	stats_changed.emit()

func shadow_ready() -> bool:
	return is_amiya() and shadow_cooldown <= 0.0 and not shadow_active

func _tick_amiya(delta: float) -> void:
	if hitstop_remaining > 0.0: return
	if shadow_cooldown > 0.0 and not shadow_active:
		shadow_cooldown = maxf(0.0, shadow_cooldown - delta)
		if shadow_cooldown == 0.0: stats_changed.emit()
	for i in range(_pending_cuts.size() - 1, -1, -1):
		var cut: Dictionary = _pending_cuts[i]
		cut.at -= delta
		if cut.at > 0.0: continue
		_pending_cuts.remove_at(i)
		_amiya_cut(cut.target, cut.raw, cut.crit, cut.direction)
	if not shadow_active: return
	_shadow_clock += delta
	while shadow_active and _shadow_clock >= _shadow_next:
		# Step the clock first, so one strike can never stall the loop.
		_shadow_next += SHADOW_GAP
		_shadow_strike()

## The enemy 绝影 would take from a cast aimed at `point`: the living one
## nearest the point within SHADOW_PICK_RADIUS, in SHADOW_RANGE of her and in
## sight. Null means the cast does nothing.
func shadow_target_at(point: Vector3) -> Enemy:
	if not is_instance_valid(game): return null
	var best: Enemy = null
	var best_distance := SHADOW_PICK_RADIUS
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.game != game or enemy._dead: continue
		if _flat(enemy.global_position - global_position) > SHADOW_RANGE: continue
		var distance := _flat(enemy.global_position - point)
		if distance > best_distance or not game.line_of_sight(global_position, enemy.global_position): continue
		best = enemy
		best_distance = distance
	return best

func _flat(offset: Vector3) -> float:
	return Vector2(offset.x, offset.z).length()

## 影霄·绝影, cast like 剑圣's Q (Alpha Strike, 用户 2026-10-09): on a target
## near the cursor, she vanishes and strikes it, then bounces to fresh enemies
## nearby — SHADOW_STRIKES in all — untouchable throughout, and reappears
## beside the first target. Returns whether it went off.
func cast_shadow(point: Vector3) -> bool:
	if not shadow_ready() or dash_remaining > 0.0 or hitstop_remaining > 0.0: return false
	if is_instance_valid(game) and not game.simulation_active(): return false
	var target := shadow_target_at(point)
	if target == null: return false
	shadow_active = true
	invulnerable = true
	shadow_cooldown = float(SkillTrees.shadow(rank("shadow"))[1])
	shadow_kill_stacks = 0
	shadow_true = false
	shadow_primary = target
	shadow_target = null
	shadow_strikes = 0
	_shadow_hit_ids.clear()
	_shadow_strikes_total = SHADOW_STRIKES + (1 if has_trigger(ItemModifier.Trigger.TWIN_WAVE) else 0)
	match transmuter("shadow"):
		"shadow_ten": _shadow_strikes_total += 2
		"shadow_flash": _shadow_strikes_total = 1
	_shadow_multiplier = attack_multiplier() * (gear_fx.spend_signature_bonus() if gear_fx != null else 1.0)
	if gear_fx != null: gear_fx.on_signature(target.global_position - global_position, target)
	_shadow_clock = 0.0
	_shadow_next = SHADOW_FIRST
	_pending_cuts.clear()
	combo_step = 0
	combat_timer = 0.0
	attack_target = target
	_has_move_target = false
	_on_wave_released()
	if is_instance_valid(game): game.sound.play("hit")
	# Her body vanishes for the whole skill: only blade flashes show on the
	# enemies she strikes, and she reappears at the end.
	_sprite.visible = false
	stats_changed.emit()
	return true

## Who the next strike hits: the first is the cast target; after that the
## nearest enemy within SHADOW_BOUNCE_RANGE of the last one that she has not
## struck yet. With nobody fresh she strikes the first target again at
## SHADOW_REPEAT_SCALE. Null ends the skill early.
func _shadow_next_target() -> Array:
	if shadow_strikes == 0:
		return [shadow_primary, 1.0] if _alive(shadow_primary) else [null, 0.0]
	var from: Vector3 = shadow_target.global_position if _alive(shadow_target) else global_position
	var best: Enemy = null
	var best_distance := SHADOW_BOUNCE_RANGE + (2.0 if transmuter("shadow") == "shadow_moon" else 0.0)
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.game != game or enemy._dead or _shadow_hit_ids.has(enemy.get_instance_id()): continue
		var distance := _flat(enemy.global_position - from)
		if distance > best_distance or not game.line_of_sight(from, enemy.global_position): continue
		best = enemy
		best_distance = distance
	if best != null: return [best, 1.0]
	if _alive(shadow_primary): return [shadow_primary, SHADOW_REPEAT_SCALE]
	return [null, 0.0]

## Untyped on purpose: a struck enemy can be freed between strikes, and a
## freed object cannot be passed through an `Enemy` parameter.
func _alive(enemy) -> bool:
	return is_instance_valid(enemy) and not enemy._dead

func _shadow_strike() -> void:
	if shadow_strikes >= _shadow_strikes_total:
		_end_shadow()
		return
	var pick := _shadow_next_target()
	var target: Enemy = pick[0]
	if target == null:
		_end_shadow()
		return
	_shadow_blink_to(target)
	var fresh := not _shadow_hit_ids.has(target.get_instance_id())
	_shadow_hit_ids[target.get_instance_id()] = true
	shadow_strikes += 1
	var crit := randf() < crit_rate()
	if is_instance_valid(game):
		# The strike itself: one bright blade flash across the enemy.
		var across := (global_position - target.global_position).cross(Vector3.UP)
		across = across.normalized() if across.length_squared() > 0.001 else Vector3.RIGHT
		CombatVfx.spawn(game, target.global_position, across.rotated(Vector3.UP, deg_to_rad(randf_range(20.0, 50.0))), "flurry")
		CombatVfx.spawn(game, target.global_position, target.global_position - global_position, "strike_flash")
		game.sound.play("hit")
	_shadow_damage(target, 1.0 if fresh else SHADOW_REPEAT_SCALE, crit)
	if shadow_strikes >= _shadow_strikes_total and is_instance_valid(game):
		if _alive(target): CombatVfx.spawn(game, Vector3(target.global_position.x, 0.09, target.global_position.z), target.global_position - global_position, "finisher")
		game.start_sword_shake()

func _shadow_damage(target: Enemy, scale_by: float, crit: bool) -> void:
	var scale := float(SkillTrees.shadow(rank("shadow"))[0])
	var kind := "true" if shadow_true else "arts"
	match transmuter("shadow"):
		"shadow_ten": scale *= 0.7
		"shadow_flash":
			scale *= 3.5
			kind = "true"
	var raw := attack_power() * SHADOW_STRIKE_SCALE * scale * scale_by * wave_multiplier() * _shadow_multiplier * target_multiplier(target) * (crit_damage() if crit else 1.0)
	_deal(target, raw, kind, crit, 0.0, true)
	on_wave_hit(target, 0.0, null)

## Appear beside `target` (on the side she came from), facing it.
func _shadow_blink_to(target: Enemy) -> void:
	var start := global_position
	var away := start - target.global_position
	away.y = 0
	away = away.normalized() if away.length_squared() > 0.01 else Vector3.BACK
	var land := target.global_position + away * 0.9
	if is_instance_valid(game): land.y = game.ground_y(land) + start.y - game.ground_y(start)
	else: land.y = start.y
	if is_instance_valid(game) and _flat(land - start) > 0.3:
		CombatVfx.spawn(game, Vector3(start.x, game.ground_y(start) + 0.09, start.z), land - start, "blink").stretch(_flat(land - start))
	global_position = land
	velocity = Vector3.ZERO
	shadow_target = target
	look_at(global_position - away, Vector3.UP)
	_sprite.play_attack(-away, 0, true, 1.0)
	_sprite.hold_action(SHADOW_GAP + 0.05)
	swing_remaining = SHADOW_GAP

## She reappears beside the first target (剑圣 Q) when it still stands; a
## dodge cutting it short leaves her where she is.
func _end_shadow(return_to_primary := true) -> void:
	if not shadow_active: return
	shadow_active = false
	fury_timer = 3.0
	shadow_kill_stacks = 0
	shadow_true = false
	if return_to_primary and _alive(shadow_primary) and shadow_target != shadow_primary: _shadow_blink_to(shadow_primary)
	if is_instance_valid(_sprite): _sprite.visible = true
	shadow_target = null
	shadow_primary = null
	if dash_remaining <= 0.0: invulnerable = false
	swing_remaining = 0.0
	if is_instance_valid(_sprite): _sprite.cancel_action()
	stats_changed.emit()

func teleport(position: Vector3) -> void:
	# A y under the ground there is a height above it (ContinuousWorldMap.on_ground).
	if is_instance_valid(game):
		var ground: float = game.ground_y(position)
		if position.y < ground - 0.01: position.y += ground
	global_position = position
	velocity = Vector3.ZERO
	_has_move_target = false
	attack_target = null

# --- Comparison (装备与背包界面调研 §5.1 / §5.14) ---------------------------------

## The numbers the inventory compares, as they stand now.
func snapshot() -> Dictionary:
	return {"hp": max_hp, "atk": attack_power(), "arts": arts_power(), "def": defense_value(),
		"res": resistance(), "aspd": attack_speed * 100.0, "crit": crit_rate(), "crit_dmg": crit_damage(), "move": move_speed}

## What wearing `item` would do: {before, after} snapshots. Swaps the slot
## directly and restores it, so nothing else (life, sword charge) is touched.
func preview_equip(item: Item) -> Dictionary:
	var before := snapshot()
	if item == null or not item.is_equippable(): return {"before": before, "after": before}
	var kept_hp := hp
	var previous: Item = equipped.get(item.category)
	equipped[item.category] = item
	_recompute_stats()
	var after := snapshot()
	if previous != null: equipped[item.category] = previous
	else: equipped.erase(item.category)
	_recompute_stats()
	hp = kept_hp
	return {"before": before, "after": after}
