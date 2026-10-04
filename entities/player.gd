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


const BASE_MOVE_SPEED := 5.0
const DASH_IMPULSE := 2.8
const DASH_INVULN_DURATION := 0.28
const DASH_COOLDOWN := 0.5
const DASH_STAMINA_COST := 25.0
const STAMINA_REGEN := 18.0
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
var potion_capacity: int = BASE_POTION_CAPACITY

var _buff_max_hp_bonus: float = 0.0
var _buff_damage_bonus: float = 0.0
var _low_hp_ward_used_this_floor: bool = false

var _move_target: Vector3 = Vector3.ZERO
var _has_move_target: bool = false
var _attack_cooldown: float = 0.0
var _dash_cooldown: float = 0.0
var regen_timer: float = HP_REGEN_INTERVAL
## Set at departure from the base's medical state (基地玩法策划案 §4): injury and
## contamination take this share of max HP for the whole contract, and heavy
## contamination stops self-regeneration. Cleared on settlement.
var condition_hp_penalty := 0.0
var regen_blocked := false

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

func _ready() -> void:
	game = get_parent() as GameManager
	_navigation = NavigationAgent3D.new()
	_navigation.path_desired_distance = 0.45
	_navigation.target_desired_distance = ARRIVE_THRESHOLD
	add_child(_navigation)
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
	add_child(_sprite)
	add_child(PlayerAura.new())
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.3
	shape.shape = capsule
	add_child(shape)

func set_move_target(target: Vector3) -> void:
	_move_target = target
	_has_move_target = true
	if is_instance_valid(_navigation): _navigation.target_position = target

func clear_move_target() -> void:
	_has_move_target = false

func is_target_in_range(enemy: Enemy) -> bool:
	if not is_instance_valid(enemy):
		return false
	var offset := enemy.global_position - global_position
	offset.y = 0.0
	var attack_range := BLADE_RANGE
	return offset.length() <= attack_range

func f(key: String) -> float:
	return float(fx.get(key, 0.0))

func _physics_process(delta: float) -> void:
	if is_instance_valid(game) and not (game.simulation_active() or game.base_walk_active()):
		return
	_tick_combat(delta)
	_attack_cooldown -= delta
	_dash_cooldown -= delta
	# Latch the press: a just_pressed that lands inside a hit's freeze frames
	# would otherwise be lost, and a dodge must never be eaten by a hit.
	if Input.is_action_just_pressed("dash"): _dash_buffered = true
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
		if hp < max_hp and not regen_blocked:
			heal(regen_rate() * HP_REGEN_INTERVAL)

	var move_vec := Vector3.ZERO
	if _has_move_target:
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
	if dash_pressed and stamina >= dash_cost() and _dash_cooldown <= 0.0:
		_start_dash(move_vec if move_vec.length_squared() > 0.01 else -global_transform.basis.z)

	if is_on_floor():
		velocity.y = -2.0
	else:
		velocity.y += GRAVITY * delta
	velocity.x = move_vec.x * move_speed
	velocity.z = move_vec.z * move_speed
	move_and_slide()

	var regen := (STAMINA_REGEN + float(stats.get("stamina_regen", 0.0))) * (1.0 + float(stats.get("stamina_regen_pct", 0.0)))
	if equipped_effect("frozen_relic"):
		regen *= 0.6
	stamina = minf(100.0, stamina + regen * delta)
	if move_vec.length_squared() > 0.01:
		look_at(global_position + move_vec, Vector3.UP)

	if hp <= 0.0:
		died.emit()

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
	since_wave += delta
	segment_time += delta
	if hit_stacks > 0:
		hit_stack_timer -= delta
		if hit_stack_timer <= 0: hit_stacks = 0

## Relic effects that tick in the field: drains, auto charge, crowd triggers.
func _tick_relics_in_field(delta: float) -> void:
	if f("drain") > 0.0: hp -= max_hp * f("drain") * delta
	if f("auto_charge") > 0.0 and has_sword_wave():
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

# --- Stats ---------------------------------------------------------------------

func dash_cost() -> float:
	return maxf(0.0, DASH_STAMINA_COST + float(stats.get("dash_cost", 0.0)))

func _start_dash(direction: Vector3) -> void:
	if stamina < dash_cost() or _dash_cooldown > 0 or hitstop_remaining > 0: return
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

func _enemies_near_segment(from: Vector3, to: Vector3, radius: float) -> Array[Enemy]:
	var found: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy.game != game or enemy._dead: continue
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

func has_sword_wave() -> bool:
	var item: Item = equipped.get(Item.Category.WEAPON)
	if item == null: return false
	for mod in item.modifiers:
		if mod.trigger == ItemModifier.Trigger.SWORD_WAVE: return true
	return false

## Whether any worn item carries this special-equipment trigger (SpecialGear).
func has_trigger(trigger: ItemModifier.Trigger) -> bool:
	for item in equipped.values():
		if item == null: continue
		for mod in item.modifiers:
			if mod.trigger == trigger: return true
	return false

func wave_hits_needed() -> int:
	return WAVE_HITS

func add_charge(amount: int) -> void:
	if not has_sword_wave() or amount <= 0: return
	var before := sword_charge
	sword_charge = mini(wave_hits_needed(), sword_charge + amount)
	charge_idle = 0
	if sword_charge == wave_hits_needed() and before < sword_charge and is_instance_valid(game): game.sound.play("charge")
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
	if is_instance_valid(_sprite): _sprite.cancel_action()

func attack(target: Enemy) -> void:
	if not is_instance_valid(target) or target._dead or not is_target_in_range(target): return
	if is_instance_valid(game) and (target.game != game or not game.line_of_sight(global_position, target.global_position)): return
	attack_direction(_get_attack_direction(target), target)

## Ground clicks can whiff or release a stored wave. Whiffs never charge.
func attack_direction(direction: Vector3, target: Enemy = null) -> void:
	if _attack_cooldown > 0 or hitstop_remaining > 0 or dash_remaining > 0: return
	if is_instance_valid(game) and not game.simulation_active(): return
	direction.y = 0
	if direction.length_squared() < 0.001: direction = -global_basis.z
	direction = direction.normalized()
	var release := has_sword_wave() and sword_charge >= wave_hits_needed()
	var stage := combo_step
	var lands := is_instance_valid(target) and not target._dead and is_target_in_range(target) and (not is_instance_valid(game) or game.line_of_sight(global_position, target.global_position))
	# attack_multiplier() spends 赏善郎's one-shot bonus: a swing that damages
	# nothing must not spend it.
	var hit := lands or release
	if hit and combat_timer >= OUT_OF_COMBAT and f("engage_aspd") > 0.0: engage_timer = 10.0
	var multiplier := attack_multiplier() if hit else 0.0
	var crit := hit and randf() < crit_rate()
	var crit_factor := crit_damage() if crit else 1.0
	if hit: combat_timer = 0
	_attack_cooldown = current_cooldown()
	combo_idle = 0
	combo_step = 0 if release else (combo_step + 1) % 3
	look_at(global_position + direction, Vector3.UP)
	_sprite.play_attack(direction, stage, release, animation_rate())
	if is_instance_valid(game):
		game.sound.play("hit")
		var foot := Vector3(global_position.x, 0.09, global_position.z)
		CombatVfx.spawn(game, foot, direction, "slash", stage, release).speed_up(animation_rate())
		if release:
			clear_charge()
			var wave_damage := arts_power() * WAVE_SCALE * wave_multiplier() * multiplier * crit_factor
			_spawn_wave(direction, wave_damage, crit, false)
			if has_trigger(ItemModifier.Trigger.TWIN_WAVE):
				for side in [-1.0, 1.0]:
					_spawn_wave(direction.rotated(Vector3.UP, deg_to_rad(20.0 * side)), wave_damage * 0.5, crit, true)
			CombatVfx.spawn(game, foot, direction, "burst", 0, true)
			game.start_sword_shake()
	if release: _on_wave_released()
	if lands:
		var stop := 0.05 if release or stage == 2 else 0.03
		var raw := attack_power() * stage_scale(stage) * multiplier * target_multiplier(target) * crit_factor
		var pierce := physical_pierce()
		_deal(target, raw, "phys", crit, pierce, true)
		_melee_riders(target, raw, crit, pierce)
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

## After a wave leaves: 拳经三问 counts it, 绿叶菜罐头 opens its window, and the
## "噤声" / 鸣脊兽 build-ups start over.
func _on_wave_released() -> void:
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
	equipped.clear()  # anything left equipped here wasn't gilded — GameManager
	# already pulled gilded equipped items into the stash before calling this.
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
	_recompute_stats()
	hp = max_hp
	invulnerable = false
	stamina = 100
	combat_timer = 6
	_attack_cooldown = 0
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
	potion_capacity = maxi(0, BASE_POTION_CAPACITY + int(sheet.potion_cap))
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
	return (CombatStats.BASE.atk + float(stats.get("atk", 0.0))) * maxf(0.1, 1.0 + pct)

func arts_power() -> float:
	var pct := float(stats.get("arts_pct", 0.0))
	return (CombatStats.BASE.arts + float(stats.get("arts", 0.0))) * maxf(0.1, 1.0 + pct)

func defense_value() -> float:
	var flat := CombatStats.BASE.def + float(stats.get("def", 0.0))
	if f("linger") > 0.0 and segment_time >= LINGER_SECONDS: flat += 300.0
	var pct := float(stats.get("def_pct", 0.0)) + 0.05 * altar_stacks
	if f("full_def") > 0.0 and full_hp(): pct += 0.20
	if guard_timer > 0.0: pct += 0.40
	return flat * maxf(0.0, 1.0 + pct)

func resistance() -> float:
	var res := CombatStats.BASE.res + float(stats.get("res", 0.0))
	if f("linger") > 0.0 and segment_time >= LINGER_SECONDS: res += 30.0
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
	return clampf(value, 0.0, CombatStats.EVASION_CAP if dance_timer <= 0.0 else 0.75)

func arts_evasion() -> float:
	var value := float(stats.get("evasion_arts", 0.0)) + (0.5 if dance_timer > 0.0 else 0.0)
	return clampf(value, 0.0, CombatStats.EVASION_CAP if dance_timer <= 0.0 else 0.75)

## Self-regeneration per second (paid out every HP_REGEN_INTERVAL).
func regen_rate() -> float:
	return (CombatStats.BASE.regen + float(stats.get("regen", 0.0))) * (1.0 + float(stats.get("regen_pct", 0.0))) + max_hp * float(stats.get("regen_max_pct", 0.0))

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
	if f("gold_aspd") > 0.0 and is_instance_valid(game): aspd += f("gold_aspd") * minf(10.0, floorf(game.run_gold / 50.0))
	aspd += f("elite_aspd_stack") * mini(ELITE_STACK_MAX, elite_kills)
	if dance_timer > 0.0: aspd += 80.0
	return clampf(aspd, CombatStats.ASPD_MIN, CombatStats.ASPD_MAX)

func current_cooldown() -> float:
	return maxf(MIN_BLADE_COOLDOWN, BASE_BLADE_COOLDOWN * (1.0 + float(stats.get("interval_pct", 0.0))) / (current_aspd() / 100.0))

func stage_scale(stage: int) -> float:
	return COMBO_SCALES[clampi(stage, 0, 2)]

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

func teleport(position: Vector3) -> void:
	global_position = position
	velocity = Vector3.ZERO
	_has_move_target = false

# --- Comparison (装备与背包界面调研 §5.1 / §5.14) ---------------------------------

## The numbers the inventory compares, as they stand now.
func snapshot() -> Dictionary:
	return {"rating": power_rating(), "hp": max_hp, "atk": attack_power(), "arts": arts_power(), "def": defense_value(),
		"res": resistance(), "aspd": attack_speed * 100.0, "crit": crit_rate(), "crit_dmg": crit_damage(), "move": move_speed}

## 战力: one number for a first glance, like Diablo IV's item power. It is the
## geometric mean of sustained offence and effective life, so offence and
## defence count alike.
func power_rating() -> int:
	var offence := attack_power() * attack_speed * (1.0 + crit_rate() * (crit_damage() - 1.0)) + arts_power() * 0.35
	var effective_life := max_hp * (1.0 + defense_value() / 400.0) / maxf(0.2, 1.0 - resistance() / 100.0)
	return roundi(sqrt(maxf(offence, 0.0) * maxf(effective_life, 0.0)) / 4.0)

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
