class_name Player
extends CharacterBody3D

## Ported from the player-facing half of DownfallPrototype (movement toward a
## click-set target, dash, weapons, hp/stamina, gravity). GameManager owns
## input interpretation (raycasting the pointer against enemies/ground) and
## calls set_move_target()/attack() here — see game/game_manager.gd.
##
## Stats, the damage pipeline and every relic hook follow
## 局内构筑与数值策划案_v1_0.md: §3 stat model, §4 damage order, §5 Lappland,
## §10 the relics themselves (data in game/relic_catalog.gd).

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
const BASE_BLADE_COOLDOWN := 0.42
const MIN_ATTACK_SPEED := CombatStats.ASPD_MIN / 100.0
const MIN_BLADE_COOLDOWN := 0.1
const ARRIVE_THRESHOLD := 0.25
const GRAVITY := -9.81
const BASE_POTION_CAPACITY := 3
## Melee hits are ATK × these per combo stage; the third is the heavy one.
const COMBO_SCALES := [1.0, 1.0, 1.3]
const METRONOME_FINISHER := 1.9
## The sword wave is arts damage: 法术攻击力 × this.
const WAVE_SCALE := 1.5
const WAVE_HITS := 3
const OUT_OF_COMBAT := 5.0

var hp: float = 2400.0
var max_hp: float = 2400.0
var stamina: float = 100.0
## Generic "伤害 +X%" (relic dmg_pct); conditional multipliers sit on top.
var damage_bonus: float = 1.0
var invulnerable: bool = false
var equipped: Dictionary = {}  # Item.Category -> Item
## The summed sheet from equipment, relics and resonance (CombatStats.KEYS).
var stats: Dictionary = CombatStats.empty()
## Damage absorbed before HP (坚壁 resonance, 铁血).
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
var counter_timer := 0.0
var stationary_time := 0.0
var _gild_ward_used := false
var combo_step := 0
var combo_idle := 0.0
var sword_charge := 0
var charge_idle := 0.0
var hitstop_remaining := 0.0
var dash_remaining := 0.0
var _dash_buffered := false
var _navigation: NavigationAgent3D

# Relic runtime state (all cleared at settlement; per-segment ones on a new segment).
var hurt_timer := 0.0       # 发条护腕: seconds since taking damage window
var haste_timer := 0.0      # 迅捷 2: after a dodge
var shadow_timer := 0.0     # 无影连斩: after a dodge
var bash_timer := 0.0       # 盾反: after a block or shield absorb
var gale_stacks := 0        # 风切
var gale_timer := 0.0
var trophy_aspd := 0.0      # 狩猎本能, this segment
var perfect_ready := false  # 时机感
var undying_used := false   # 不屈之誓, this segment
var brooch_ready := true    # 防蚀胸针, this segment
var invuln_timer := 0.0
var _in_burst := false      # 矿脉共振 never chains
var _ore_seen := -1

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
	counter_timer = maxf(0, counter_timer - delta)
	_tick_relic_timers(delta)
	stationary_time = 0.0 if velocity.length_squared() > 0.3 else stationary_time + delta
	if is_instance_valid(game) and game.simulation_active():
		var ore := ore_count()
		if ore != _ore_seen:
			_ore_seen = ore
			_recompute_stats()
		if has_build("crystal_blade"): hp -= max_hp * 0.005 * delta
	if has_build("rest") and combat_timer >= OUT_OF_COMBAT:
		heal(max_hp * 0.025 * delta)
	regen_timer -= delta
	if regen_timer <= 0.0:
		regen_timer = HP_REGEN_INTERVAL
		if hp < max_hp and not has_build("rest") and not regen_blocked:
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
	haste_timer = maxf(0, haste_timer - delta)
	shadow_timer = maxf(0, shadow_timer - delta)
	bash_timer = maxf(0, bash_timer - delta)
	invuln_timer = maxf(0, invuln_timer - delta)
	if gale_stacks > 0:
		gale_timer -= delta
		if gale_timer <= 0: gale_stacks = 0

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
	var perfect := has_build("perfect") and _strike_imminent()
	move_and_collide(direction.normalized() * DASH_IMPULSE)
	if is_instance_valid(game):
		for i in range(3):
			CombatVfx.afterimage(game, _sprite, start.lerp(global_position, float(i) / 3.0), 0.2 + i * 0.2)
	if school_tier("swift") >= 2: haste_timer = 2.5
	if has_build("shadow_chain"): shadow_timer = 2.0
	if perfect:
		perfect_ready = true
		stamina = minf(100.0, stamina + 25.0)
		if is_instance_valid(game): DamageNumber.spawn(game, global_position, "完美闪避", "evade")
	if has_build("afterimage") and is_instance_valid(game):
		for enemy in _enemies_near_segment(start, global_position, 1.0):
			_deal(enemy, attack_power() * 1.2, "phys", false, 0.0, false)

## 时机感: an enemy is within 0.35 s of landing an attack that reaches her.
func _strike_imminent() -> bool:
	if not is_instance_valid(game): return false
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy.game != game or not enemy.preparing_attack or enemy._windup_remaining > 0.35: continue
		var reach := float(enemy.attack_profile.get("reach", 2.5)) + 1.0
		if Vector2(enemy.global_position.x - global_position.x, enemy.global_position.z - global_position.z).length() <= reach: return true
	for child in game.get_children():
		if child is EnemyProjectile and child.global_position.distance_to(global_position) < 2.5: return true
	return false

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
	if combo_idle >= 0.9: combo_step = 0
	if sword_charge > 0 and sword_charge < wave_hits_needed():
		charge_idle += delta
		if charge_idle >= 4.0: clear_charge()
	if dash_remaining > 0:
		dash_remaining = maxf(0, dash_remaining - delta)
		if dash_remaining == 0: invulnerable = false

func has_sword_wave() -> bool:
	if has_build("wolf_fang"): return true
	return _weapon_has_wave()

func _weapon_has_wave() -> bool:
	var item: Item = equipped.get(Item.Category.WEAPON)
	if item == null: return false
	for mod in item.modifiers:
		if mod.trigger == ItemModifier.Trigger.SWORD_WAVE: return true
	return false

## Hits it takes to fill the wave: 3, or 2 with the 狼魂 resonance.
func wave_hits_needed() -> int:
	return 2 if school_tier("wolf") >= 2 else WAVE_HITS

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
	# attack_multiplier() spends one-shot build bonuses (counter), and
	# combat_timer gates ambush: a swing that damages nothing must not spend them.
	var hit := lands or release
	var first_strike := combat_timer >= OUT_OF_COMBAT
	var multiplier := attack_multiplier() if hit else 0.0
	var crit := hit and _roll_crit(stage, first_strike)
	var crit_factor := _crit_factor(crit, first_strike)
	if hit and perfect_ready:
		crit_factor *= 1.5
		perfect_ready = false
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
			if has_build("twin_wave"):
				for side in [-1.0, 1.0]:
					_spawn_wave(direction.rotated(Vector3.UP, deg_to_rad(20.0 * side)), wave_damage * 0.5, crit, true)
			CombatVfx.spawn(game, foot, direction, "burst", 0, true)
			game.start_sword_shake()
	if lands:
		var stop := 0.05 if release or stage == 2 else 0.03
		var raw := attack_power() * stage_scale(stage) * multiplier * target_multiplier(target) * crit_factor
		var pierce := physical_pierce(crit)
		var executable := not target.elite and has_build("executioner")
		_deal(target, raw, "phys", crit, pierce, true)
		_melee_riders(target, raw, crit, pierce)
		if executable and not target._dead and target.health / maxf(target.max_health, 1.0) < 0.15:
			target.take_hit(target.health + 1.0, "true")
		target.hitstop_remaining = maxf(target.hitstop_remaining, stop)
		hitstop_remaining = stop
		on_hit()
		if is_instance_valid(game): CombatVfx.spawn(game, target.global_position, direction, "spark")
		if crit and has_build("moon_blades") and randf() < 0.35:
			_spawn_wave(direction, arts_power() * WAVE_SCALE * wave_multiplier() * 0.5, false, true)
		if has_sword_wave() and not release:
			sword_charge = mini(wave_hits_needed(), sword_charge + 1)
			charge_idle = 0
			if sword_charge == wave_hits_needed() and is_instance_valid(game): game.sound.play("charge")
			stats_changed.emit()

## Everything a landed melee hit carries besides itself. These are proc damage:
## no lifesteal and no further procs (RoR2's proc-coefficient rule, §4.4).
func _melee_riders(target: Enemy, raw: float, crit: bool, pierce: float) -> void:
	if has_build("gale"):
		gale_stacks = mini(10, gale_stacks + 1)
		gale_timer = 2.0
	if has_build("frost_trap") and not target.hit_by_player: target.apply_status("slow", 3.0, 0.4)
	target.hit_by_player = true
	if target._dead: return
	if school_tier("wolf") >= 4: _deal(target, arts_power() * 0.2, "arts", false, 0.0, false)
	if has_build("crystal_blade"): _deal(target, arts_power() * 0.18, "arts", false, 0.0, false)
	if has_build("shield_bash") and bash_timer > 0:
		bash_timer = 0
		_deal(target, defense_value() * 1.5, "phys", false, 0.0, false)
	if has_build("broad_blade") and is_instance_valid(game):
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
	if has_build("pierce_sigil"):
		wave.width_scale = 1.6
		wave.range_bonus = 3.0
	wave.position = global_position
	game.add_child(wave)

## Deals a hit and returns what landed. `direct` hits feed lifesteal.
func _deal(target: Enemy, raw: float, kind: String, crit: bool, pierce: float = 0.0, direct: bool = true) -> float:
	if not is_instance_valid(target) or target._dead: return 0.0
	if kind == "arts": raw *= 1.0 + float(stats.get("arts_dmg_pct", 0.0))
	var dealt := target.take_hit(raw, kind, crit, pierce)
	if direct and dealt > 0.0: heal(dealt * lifesteal())
	if kind == "arts" and has_build("ore_flux"): target.apply_status("res_down", 4.0, 20.0)
	return dealt

## Called by a sword wave for each enemy it passes through.
func on_wave_hit(enemy: Enemy, dealt: float, wave: SwordWave) -> void:
	if dealt > 0.0: heal(dealt * lifesteal())
	if not is_instance_valid(enemy): return
	if has_build("ore_flux"): enemy.apply_status("res_down", 4.0, 20.0)
	if has_build("ember_wave"): enemy.apply_status("burn", 4.0, arts_power() * 0.10 * (1.0 + float(stats.get("arts_dmg_pct", 0.0))))
	if has_build("silence"):
		if enemy.elite: enemy.apply_status("res_down", 5.0, 15.0)
		else: enemy.interrupt(2.0)
	if has_build("snow_howl") and enemy.elite: enemy.apply_status("def_down", 5.0, 0.3)

## Per-target multiplier for a wave about to hit `enemy` (its arts bonus is
## applied in _deal / here, its resistance in Enemy.take_hit).
func wave_bonus_against(enemy: Enemy) -> float:
	var bonus := target_multiplier(enemy) * (1.0 + float(stats.get("arts_dmg_pct", 0.0)))
	if has_build("snow_howl") and enemy.elite: bonus *= 1.6
	return bonus

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
## `attacker` is who to answer when 坚壁 4 retaliates.
func take_damage(amount: float, kind: String = "phys", attacker: Enemy = null) -> void:
	if invulnerable or invuln_timer > 0.0:
		return
	combat_timer = 0.0
	if kind == "phys" and randf() < evasion():
		if is_instance_valid(game): DamageNumber.spawn(game, global_position, "闪避", "evade")
		return
	if has_build("brooch") and brooch_ready:
		brooch_ready = false
		_after_block()
		if is_instance_valid(game): DamageNumber.spawn(game, global_position, "抵挡", "shield")
		message_requested.emit("防蚀胸针抵挡了本区段的第一次伤害")
		return
	amount = CombatStats.mitigate(amount, kind, defense_value(), resistance())
	var reduction := 0.25 if equipped_effect("riot_shield") else 0.0
	if has_build("pack_plate") and is_instance_valid(game):
		reduction += minf(0.25, floorf(game.inventory.occupied_cells() / 10.0) * 0.05)
	var blocked := false
	if has_build("brace") and stationary_time >= 0.8 and stamina >= 15:
		stamina -= 15
		reduction += 0.6
		blocked = true
	if has_build("last_light") and is_instance_valid(game) and game.is_extraction_floor(): reduction += 0.25
	if has_build("lone_wolf") and nearby_enemy_count(6.0) == 1: reduction += 0.2
	amount *= 1.0 - minf(CombatStats.REDUCTION_CAP, reduction)
	amount *= 1.0 + float(stats.get("taken_pct", 0.0))
	if has_build("unsealed"): amount *= 1.15
	if has_build("deep"): amount *= 1.1
	if has_build("last_light") and is_instance_valid(game) and not game.is_extraction_floor(): amount *= 1.1
	if has_build("counter"): counter_timer = 3.0
	if blocked: _after_block()
	if school_tier("bulwark") >= 4 and is_instance_valid(attacker) and not attacker._dead:
		attacker.take_hit(defense_value() * 0.8, "phys")
	if shield > 0.0 and amount > 0.0:
		var absorbed := minf(shield, amount)
		shield -= absorbed
		amount -= absorbed
		_after_block()
		if is_instance_valid(game): DamageNumber.spawn(game, global_position, str(roundi(absorbed)), "shield")
	if amount <= 0.0:
		stats_changed.emit()
		return
	hurt_timer = 5.0
	if has_build("gild_guard") and not _gild_ward_used and is_instance_valid(game) and game.has_gilded() and hp - amount <= 0:
		_gild_ward_used = true
		message_requested.emit("回收承诺：化解致命攻击（本区段已消耗）")
		return
	if has_build("undying") and not undying_used and hp - amount <= 0:
		undying_used = true
		hp = max_hp * 0.5
		invuln_timer = 1.5
		message_requested.emit("不屈之誓：撑住了致命一击（本区段已消耗）")
		stats_changed.emit()
		return
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

func _after_block() -> void:
	if has_build("shield_bash"): bash_timer = 3.0
	if has_build("counter"): counter_timer = 3.0

func _has_low_hp_ward() -> bool:
	for item in equipped.values():
		if item == null:
			continue
		for mod in item.modifiers:
			if mod.trigger == ItemModifier.Trigger.LOW_HP_SHIELD_ONCE_PER_FLOOR:
				return true
	return false

func reset_floor_state() -> void:
	reset_combat_state(false)
	_low_hp_ward_used_this_floor = false
	_gild_ward_used = false
	undying_used = false
	brooch_ready = true
	trophy_aspd = 0.0
	shield = max_hp * 0.15 if school_tier("bulwark") >= 2 else 0.0

## Healing scales with 治疗效果. With 铁血, healing past full becomes shield.
func heal(amount: float, show: bool = false) -> void:
	if amount <= 0.0: return
	amount *= 1.0 + float(stats.get("heal_pct", 0.0))
	var room := maxf(0.0, max_hp - hp)
	hp = minf(max_hp, hp + amount)
	if amount > room and has_build("iron_blood"):
		shield = minf(max_hp * 0.2, shield + amount - room)
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
	haste_timer = 0
	shadow_timer = 0
	bash_timer = 0
	gale_stacks = 0
	trophy_aspd = 0
	perfect_ready = false
	undying_used = false
	brooch_ready = true
	invuln_timer = 0
	shield = 0
	_recompute_stats()
	hp = max_hp
	invulnerable = false
	stamina = 100
	combat_timer = 6
	counter_timer = 0
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
	if is_instance_valid(game): CombatStats.add(sheet, RelicCatalog.stat_sheet(game.builds))
	stats = sheet
	var hp_pct := float(sheet.hp_pct)
	if has_build("ore_hoarder"): hp_pct += minf(0.3, ore_count() * 0.06)
	max_hp = maxf(1.0, (CombatStats.BASE.hp + _buff_max_hp_bonus + float(sheet.hp)) * (1.0 + hp_pct) * (1.0 - condition_hp_penalty))
	damage_bonus = 1.0 + _buff_damage_bonus + float(sheet.dmg_pct)
	move_speed = BASE_MOVE_SPEED * maxf(0.3, 1.0 + float(sheet.move_pct))
	# 攻速 divides the interval (明日方舟: interval / (攻速 / 100)), so stacking it
	# never reaches zero; interval modifiers (builds, relics) scale it directly.
	attack_speed = clampf(CombatStats.BASE.aspd + float(sheet.aspd), CombatStats.ASPD_MIN, CombatStats.ASPD_MAX) / 100.0
	blade_cooldown = maxf(MIN_BLADE_COOLDOWN, BASE_BLADE_COOLDOWN * (1.0 + float(sheet.interval_pct)) / attack_speed)
	gold_gain_multiplier = 1.0 + float(sheet.gold_pct)
	potion_capacity = maxi(0, BASE_POTION_CAPACITY + int(sheet.potion_cap))
	hp = minf(hp, max_hp)
	stats_changed.emit()

func has_build(id: String) -> bool:
	return is_instance_valid(game) and game.builds.has(id)

func school_tier(school: String) -> int:
	if not is_instance_valid(game): return 0
	return RelicCatalog.tier(RelicCatalog.school_counts(game.builds), school)

func equipped_effect(effect: String) -> bool:
	for item in equipped.values():
		if item != null and item.effect == effect: return true
	return false

func ore_count() -> int:
	return game.count_effect("raw_ore") if is_instance_valid(game) else 0

func hp_ratio() -> float:
	return clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)

## 攻击力 right now: (base + flat) × (1 + every +X%, static and conditional,
## added together the way 明日方舟 stacks one layer), plus 重甲誓约's share of defence.
func attack_power() -> float:
	var pct := float(stats.get("atk_pct", 0.0))
	if has_build("nutrient"): pct += 0.25 * hp_ratio()
	if school_tier("blood") >= 4 and hp_ratio() < 0.5: pct += 0.25
	if school_tier("ore") >= 4: pct += 0.06 * mini(5, ore_count())
	var value := (CombatStats.BASE.atk + float(stats.get("atk", 0.0))) * maxf(0.1, 1.0 + pct)
	if has_build("heavy_oath"): value += defense_value() * 0.3
	return value

func arts_power() -> float:
	var pct := float(stats.get("arts_pct", 0.0))
	if school_tier("ore") >= 4: pct += 0.06 * mini(5, ore_count())
	return (CombatStats.BASE.arts + float(stats.get("arts", 0.0))) * maxf(0.1, 1.0 + pct)

func defense_value() -> float:
	var flat := CombatStats.BASE.def + float(stats.get("def", 0.0))
	if has_build("crystal_armor") and ore_count() > 0: flat += 60.0
	return flat * maxf(0.0, 1.0 + float(stats.get("def_pct", 0.0)))

func resistance() -> float:
	return minf(CombatStats.RES_CAP, CombatStats.BASE.res + float(stats.get("res", 0.0)))

func crit_rate() -> float:
	return clampf(CombatStats.BASE.crit + float(stats.get("crit", 0.0)), 0.0, CombatStats.CRIT_CAP)

func crit_damage() -> float:
	return CombatStats.BASE.crit_dmg + float(stats.get("crit_dmg", 0.0))

func lifesteal() -> float:
	return clampf(float(stats.get("lifesteal", 0.0)), 0.0, CombatStats.LIFESTEAL_CAP)

func evasion() -> float:
	return clampf(float(stats.get("evasion", 0.0)), 0.0, CombatStats.EVASION_CAP)

## Self-regeneration per second (paid out every HP_REGEN_INTERVAL).
func regen_rate() -> float:
	return (CombatStats.BASE.regen + float(stats.get("regen", 0.0))) * (1.0 + float(stats.get("regen_pct", 0.0))) + max_hp * float(stats.get("regen_max_pct", 0.0))

## 攻速 right now, with every timed or conditional bonus.
func current_aspd() -> float:
	var aspd := CombatStats.BASE.aspd + float(stats.get("aspd", 0.0)) + trophy_aspd
	aspd += gale_stacks * 4.0
	if haste_timer > 0.0: aspd += 30.0
	if has_build("clockwork") and hurt_timer > 0.0: aspd += 40.0
	if has_build("frenzy"): aspd += 60.0 * clampf((1.0 - hp_ratio()) / 0.7, 0.0, 1.0)
	if school_tier("blood") >= 4 and hp_ratio() < 0.5: aspd += 20.0
	if has_build("gin_cup") and is_instance_valid(game): aspd += minf(40.0, floorf(game.run_gold / 50.0) * 5.0)
	return clampf(aspd, CombatStats.ASPD_MIN, CombatStats.ASPD_MAX)

func current_cooldown() -> float:
	return maxf(MIN_BLADE_COOLDOWN, BASE_BLADE_COOLDOWN * (1.0 + float(stats.get("interval_pct", 0.0))) / (current_aspd() / 100.0))

func stage_scale(stage: int) -> float:
	if stage == 2 and has_build("metronome"): return METRONOME_FINISHER
	return COMBO_SCALES[clampi(stage, 0, 2)]

func physical_pierce(crit: bool) -> float:
	var pierce := 0.4 if has_build("armor_break") else 0.0
	if crit and has_build("weak_point"): pierce += 0.3
	return minf(1.0, pierce)

func _roll_crit(stage: int, first_strike: bool) -> bool:
	if perfect_ready or shadow_timer > 0.0: return true
	if stage == 2 and school_tier("blade") >= 4: return true
	if first_strike and school_tier("hunter") >= 4: return true
	return randf() < crit_rate()

func _crit_factor(crit: bool, first_strike: bool) -> float:
	if not crit: return 0.8 if has_build("eagle_edge") else 1.0
	return crit_damage() + (0.5 if first_strike and school_tier("hunter") >= 4 else 0.0)

func wave_multiplier() -> float:
	var multiplier := 1.0 + float(stats.get("wave_pct", 0.0))
	if has_build("wolf_fang"): multiplier *= 1.25 if _weapon_has_wave() else 0.8
	if has_build("empty_safe") and is_instance_valid(game) and game.safe_bag.items.is_empty(): multiplier *= 1.5
	return multiplier

## Conditional damage multipliers that do not depend on the target. Spends the
## one-shot 折刃扣 bonus, so it is only called for a swing that lands.
func attack_multiplier() -> float:
	var multiplier := damage_bonus
	if equipped_effect("frozen_relic"): multiplier *= 1.4
	if not is_instance_valid(game): return multiplier
	if has_build("unsealed") and game.run_gildings == 0: multiplier *= 1.45
	if has_build("deep"): multiplier *= 1.0 + minf(0.48, (game.floor_number - 1) * 0.08)
	if has_build("last_light") and not game.is_extraction_floor(): multiplier *= 1.2
	if has_build("counter"):
		if counter_timer > 0:
			multiplier *= 2.0
			counter_timer = 0.0
	if has_build("ambush") and combat_timer >= OUT_OF_COMBAT: multiplier *= 2.0
	if has_build("lone_wolf") and nearby_enemy_count(6.0) == 1: multiplier *= 1.45
	if has_build("obsession"): multiplier *= 1.0 + minf(0.5, floorf(game.current_contamination() / 10.0) * 0.05)
	return multiplier

## Multipliers that depend on who is being hit.
func target_multiplier(enemy: Enemy) -> float:
	if not is_instance_valid(enemy): return 1.0
	var multiplier := 1.0
	var ratio := enemy.health / maxf(enemy.max_health, 1.0)
	if has_build("executioner"): multiplier *= 1.0 + 0.5 * (1.0 - clampf(ratio, 0.0, 1.0))
	if has_build("hunter_mark") and ratio > 0.9: multiplier *= 1.5
	if enemy.elite: multiplier *= 1.0 + float(stats.get("elite_pct", 0.0))
	if has_build("frost_trap") and enemy.status_value("slow") > 0.0: multiplier *= 1.2
	return multiplier

func on_hit() -> void:
	if has_build("ore_heart"):
		heal(max_hp * minf(0.04, ore_count() * 0.01))

## Called by GameManager whenever an enemy dies.
func on_kill(enemy: Enemy) -> void:
	if not is_instance_valid(game) or enemy == null: return
	if has_build("trophy") and enemy.elite:
		heal(max_hp * 0.2, true)
		trophy_aspd += 10.0
	if has_build("vein_burst") and not _in_burst and randf() < 0.3:
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
