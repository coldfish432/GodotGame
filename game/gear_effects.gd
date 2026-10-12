class_name GearEffects
extends RefCounted

## Enemy-exclusive and set effects (装备扩充策划案_v1_0.md §5–§6). Each worn
## exclusive carries one fixed effect id (SpecialGear.GEAR[...].fx); sets give
## their 2- and 3-piece bonuses. Effects hang on the six trigger points: hit,
## kill, evade (dodge), hurt, signature, idle (§1, 用户 2026-10-11). One per
## Player; the Player calls the hooks and reads the bonuses.
##
## Damage these deal is proc damage: no lifesteal, no further procs (§4.4).

var player: Player
# Timed buffs: name -> seconds left; stacks: name -> count.
var timers := {}
var stacks := {}
var cooldowns := {}
var since_attack := 0.0
var since_hurt := 0.0
var _idle_barrier_given := false
var _streak_target: Enemy
var _streak := 0
var _hit_count := 0
var _hurt_times: Array[float] = []
var _clock := 0.0
var mark_target: Enemy
var mark_time := 0.0
var last_stand_used := false
var force_crit := false
var idle_strike_ready := false
var temp_shield := 0.0
var temp_shield_time := 0.0
var _zones: Array[Dictionary] = []
var _pending: Array[Dictionary] = []
var _in_proc := false

func _init(p_player: Player) -> void:
	player = p_player

# --- What is worn -------------------------------------------------------------

func count(fx_id: String) -> int:
	var n := 0
	for item in player.equipped.values():
		if item == null or item.special.is_empty(): continue
		if str(SpecialGear.GEAR.get(item.special, {}).get("fx", "")) == fx_id: n += 1
	return n

func has(fx_id: String) -> bool:
	return count(fx_id) > 0

func set_pieces(set_id: String) -> int:
	var n := 0
	for item in player.equipped.values():
		if item == null or item.special.is_empty(): continue
		if str(SpecialGear.GEAR.get(item.special, {}).get("set_id", "")) == set_id: n += 1
	return n

func set_bonus(set_id: String, pieces: int) -> bool:
	return set_pieces(set_id) >= pieces

func active(name: String) -> bool:
	return float(timers.get(name, 0.0)) > 0.0

func _start(name: String, seconds: float) -> void:
	timers[name] = maxf(float(timers.get(name, 0.0)), seconds)

func _ready_cd(name: String) -> bool:
	return float(cooldowns.get(name, 0.0)) <= 0.0

func _use_cd(name: String, seconds: float) -> void:
	cooldowns[name] = seconds

func reset() -> void:
	timers.clear()
	stacks.clear()
	cooldowns.clear()
	_zones.clear()
	_pending.clear()
	mark_target = null
	force_crit = false
	idle_strike_ready = false
	temp_shield = 0.0
	temp_shield_time = 0.0
	_hurt_times.clear()
	since_attack = 0.0
	since_hurt = 0.0
	_idle_barrier_given = false
	last_stand_used = false

func reset_segment() -> void:
	last_stand_used = false
	_zones.clear()
	_pending.clear()

# --- Static bonuses (set 2-piece) ----------------------------------------------

func static_sheet() -> Dictionary:
	var sheet := {}
	if set_bonus("inspectors", 2): sheet["def"] = float(sheet.get("def", 0.0)) + 40.0
	if set_bonus("grey_order", 2): sheet["res"] = float(sheet.get("res", 0.0)) + 8.0
	if set_bonus("clean_snow", 2): sheet["arts_pct"] = float(sheet.get("arts_pct", 0.0)) + 0.15
	if set_bonus("fire_watch", 2):
		sheet["def"] = float(sheet.get("def", 0.0)) + 40.0
		sheet["hp_pct"] = float(sheet.get("hp_pct", 0.0)) + 0.08
	return sheet

# --- Live bonuses the Player reads ---------------------------------------------

func aspd_bonus() -> float:
	var bonus := 12.0 * int(stacks.get("kill_aspd", 0)) * (1 if active("kill_aspd") else 0)
	bonus += 20.0 * int(stacks.get("kill_aspd_big", 0)) * (1 if active("kill_aspd_big") else 0)
	if active("haste"): bonus += 15.0
	if active("rage"): bonus += 15.0
	if set_bonus("nameless", 2) and player.hp_ratio() < 0.5: bonus += 12.0
	return bonus

func atk_pct() -> float:
	return 0.30 if active("rage") else 0.0

func def_pct() -> float:
	var pct := 0.50 if active("low_hp_def") else 0.0
	pct += 0.15 * int(stacks.get("def_stack", 0)) * (1 if active("def_stack") else 0)
	return pct

func move_mult() -> float:
	var m := 1.0
	if active("sprint"): m += 0.40
	if active("last_stand"): m += 0.30
	if active("barrier_break"): m += 0.30
	if active("haste"): m += 0.25
	if active("mark_reward"): m += 0.15
	if has("idle_strike") and since_attack >= 5.0: m += 0.30
	return m

## Extra crit chance against `target` (plus a forced crit).
func crit_bonus(target: Enemy) -> float:
	var bonus := 0.0
	if not is_instance_valid(target): return bonus
	var ratio := target.health / maxf(target.max_health, 1.0)
	if has("hit_low_crit") and ratio < 0.35: bonus += 0.25
	if set_bonus("warrant", 2) and ratio < 0.5: bonus += 0.10
	return bonus

## Consumes the "next attack crits" from 绞盘护腕 / 猎人的耐心.
func take_forced_crit() -> bool:
	if not force_crit: return false
	force_crit = false
	return true

func damage_mult(target: Enemy) -> float:
	if not is_instance_valid(target): return 1.0
	var ratio := target.health / maxf(target.max_health, 1.0)
	var m := 1.0
	if has("hit_execute_bonus") and ratio < 0.30: m *= 1.30
	if has("hit_fresh_bonus") and ratio > 0.80: m *= 1.50
	return m

## What a hit about to land on her becomes (before defences); 0 means blocked.
func incoming(amount: float, attacker: Enemy) -> float:
	if set_bonus("inspectors", 2) and randf() < 0.10: amount *= 0.5
	if has("hurt_front_block") and is_instance_valid(attacker) and randf() < 0.20:
		var to := attacker.global_position - player.global_position
		to.y = 0
		var facing := -player.global_basis.z
		facing.y = 0
		if to.length_squared() > 0.001 and facing.length_squared() > 0.001 and to.normalized().dot(facing.normalized()) > 0.3: amount *= 0.4
	if active("last_stand"): amount *= 0.5
	if active("inspect_guard"): amount *= 0.8
	return amount

## Signature damage multiplier: 无名者 3-piece spends its stacks here.
func spend_signature_bonus() -> float:
	if not set_bonus("nameless", 3): return 1.0
	var n := int(stacks.get("relay", 0))
	stacks["relay"] = 0
	return 1.0 + 0.30 * n

# --- Hooks ---------------------------------------------------------------------

func on_attack() -> void:
	since_attack = 0.0

func on_hit(target: Enemy, _raw: float) -> void:
	if _in_proc or not is_instance_valid(target) or target._dead: return
	_in_proc = true
	if idle_strike_ready:
		idle_strike_ready = false
		player._deal(target, player.arts_power() * 0.8, "arts", false, 0.0, false)
	if has("hit_fourth"):
		if target == _streak_target: _streak += 1
		else:
			_streak_target = target
			_streak = 1
		if _streak >= 4:
			_streak = 0
			player._deal(target, player.attack_power() * 0.4, "phys", false, 0.0, false)
	if has("hit_third_stun"):
		_hit_count += 1
		if _hit_count >= 3:
			_hit_count = 0
			if is_instance_valid(target) and not target._dead: target.stun(0.4 if target.elite else 0.8)
	if set_bonus("warrant", 3) and is_instance_valid(target) and not target._dead:
		mark_target = target
		mark_time = 4.0
	_in_proc = false

func on_kill(enemy: Enemy) -> void:
	if not is_instance_valid(player.game) or enemy == null: return
	var game := player.game
	var at := enemy.global_position
	if has("kill_aspd_stack"):
		stacks["kill_aspd"] = mini(3, int(stacks.get("kill_aspd", 0)) + 1)
		timers["kill_aspd"] = 4.0
	if has("kill_aspd_stack_big"):
		stacks["kill_aspd_big"] = mini(3, int(stacks.get("kill_aspd_big", 0)) + 1)
		timers["kill_aspd_big"] = 5.0
	if has("kill_haste"): _start("haste", 4.0)
	if has("kill_barrier"):
		var amount := player.max_hp * 0.10
		if temp_shield_time <= 0.0 or temp_shield < amount:
			player.shield += maxf(0.0, amount - temp_shield)
			temp_shield = amount
		temp_shield_time = 5.0
	if has("kill_explode") and randf() < 0.25:
		_pending.append({"at": 0.8, "pos": at, "radius": 2.0, "damage": player.arts_power() * 1.5, "kind": "arts"})
		_disc(at, 2.0, Color(1.0, 0.45, 0.2, 0.35), 0.8)
	if has("kill_fire"):
		_zones.append({"pos": at, "radius": 1.3, "time": 3.0, "tick": 0.5, "damage": player.arts_power() * 0.15, "kind": "fire"})
		_disc(at, 1.3, Color(1.0, 0.5, 0.15, 0.3), 3.0)
	if has("kill_gold"):
		if enemy.elite or randf() < 0.10:
			game._drop_at(at, [{"item": MaterialCatalog.create(Economy.GOLD_ID, 1, game.region_id)}], 0.6)
	if has("kill_extra_material") and randf() < 0.10:
		game._drop_at(at, [{"item": LootTables._enemy_material(enemy.enemy_type, game.loot_ctx())}], 0.6)
	if set_bonus("nameless", 3): stacks["relay"] = mini(3, int(stacks.get("relay", 0)) + 1)
	if enemy == mark_target and mark_time > 0.0:
		mark_target = null
		_start("mark_reward", 3.0)
		player.heal(player.max_hp * 0.03)

func on_evade(start: Vector3, end: Vector3) -> void:
	if has("evade_next_crit") and _ready_cd("evade_crit"):
		force_crit = true
		_use_cd("evade_crit", 3.0)
	if has("evade_next_crit_long") and _ready_cd("evade_crit_long"):
		force_crit = true
		_start("crit_window", 4.0)
		_use_cd("evade_crit_long", 6.0)
	if has("evade_ram") and is_instance_valid(player.game):
		var path := end - start
		path.y = 0
		for enemy in player._enemies_near_segment(start, end, 1.0):
			player._deal(enemy, player.attack_power() * 0.6, "phys", false, 0.0, false)
			if is_instance_valid(enemy) and not enemy._dead: enemy.push(path.normalized() if path.length_squared() > 0.001 else Vector3.FORWARD, 1.5)

## After damage has landed on her (amount > 0).
func on_hurt(amount: float, _attacker: Enemy) -> void:
	since_hurt = 0.0
	_idle_barrier_given = false
	if amount <= 0.0 or not is_instance_valid(player.game): return
	if has("hurt_shards") and randf() < 0.20: _burst(player.global_position, 2.0, player.arts_power() * 0.6, "arts")
	if has("hurt_shockwave") and _ready_cd("shockwave") and randf() < 0.20:
		_use_cd("shockwave", 3.0)
		_burst(player.global_position, 1.6, player.attack_power() * 0.6, "phys")
	if has("low_hp_def") and player.hp_ratio() < 0.35 and _ready_cd("low_hp_def"):
		_use_cd("low_hp_def", 60.0)
		_start("low_hp_def", 5.0)
	if has("hurt_half_rage") and player.hp_ratio() <= 0.5 and _ready_cd("rage"):
		_use_cd("rage", 12.0)
		_start("rage", 6.0)
	if has("hurt_def_stack"):
		stacks["def_stack"] = mini(3, (int(stacks.get("def_stack", 0)) if active("def_stack") else 0) + 1)
		timers["def_stack"] = 3.0
	if has("hurt_sprint") and _ready_cd("sprint"):
		_use_cd("sprint", 5.0)
		_start("sprint", 2.0)
	if has("hurt_last_stand") and not last_stand_used and player.hp_ratio() < 0.30:
		last_stand_used = true
		_start("last_stand", 3.0)
	if set_bonus("grey_order", 2) and player.hp_ratio() < 0.5 and _ready_cd("grey_barrier"):
		_use_cd("grey_barrier", 20.0)
		player.shield += player.max_hp * 0.20
	if set_bonus("fire_watch", 3):
		_hurt_times.append(_clock)
		while not _hurt_times.is_empty() and _clock - _hurt_times[0] > 2.0: _hurt_times.pop_front()
		if _hurt_times.size() >= 3 and _ready_cd("quake"):
			_use_cd("quake", 8.0)
			_hurt_times.clear()
			_burst(player.global_position, 2.5, player.attack_power() * 1.2, "phys", true)

## Her shield ran out (absorbed to zero).
func on_shield_broken() -> void:
	if has("idle_barrier"): _start("barrier_break", 3.0)
	if set_bonus("grey_order", 3):
		_burst(player.global_position, 2.5, player.arts_power() * 1.2, "arts", false, 1.0)

## The signature went off toward `direction`; `first` is the first enemy it
## meets (may be null).
func on_signature(direction: Vector3, first: Enemy) -> void:
	if not is_instance_valid(player.game): return
	var game := player.game
	if has("signature_spike") and is_instance_valid(first) and not first._dead:
		_disc(first.global_position, 0.8, Color(1.0, 0.6, 0.3, 0.4), 0.4)
		player._deal(first, player.arts_power() * 0.8, "arts", false, 0.0, false)
	if has("signature_shards"):
		var hit := 0
		for enemy in _enemies_in_cone(direction, 6.0, 30.0):
			if hit >= 3: break
			player._deal(enemy, player.attack_power() * 0.25, "phys", false, 0.0, false)
			hit += 1
	if has("signature_chain") and is_instance_valid(first) and not first._dead:
		var from := first
		var done := {first.get_instance_id(): true}
		var damage := player.arts_power() * 1.5
		for jump in range(2):
			damage *= 0.85
			var next := _nearest(from.global_position, 3.5, done)
			if next == null: break
			done[next.get_instance_id()] = true
			CombatVfx.spawn(game, next.global_position, next.global_position - from.global_position, "spark", 0, true)
			player._deal(next, damage, "arts", false, 0.0, false)
			from = next
	if set_bonus("inspectors", 3) and _ready_cd("inspect"):
		_use_cd("inspect", 8.0)
		_start("inspect_guard", 3.0)
		for enemy in _enemies_near(player.global_position, 3.0): enemy.stun(0.5)
	if set_bonus("clean_snow", 3) and _ready_cd("snow"):
		_use_cd("snow", 10.0)
		_zones.append({"pos": player.global_position, "radius": 3.0, "time": 4.0, "tick": 0.5, "damage": 0.0, "kind": "snow", "follow": true})
		_disc(player.global_position, 3.0, Color(0.9, 0.95, 1.0, 0.25), 4.0)

func tick(delta: float) -> void:
	_clock += delta
	since_attack += delta
	since_hurt += delta
	for name in timers.keys():
		timers[name] = float(timers[name]) - delta
		if float(timers[name]) <= 0.0:
			timers.erase(name)
			if name in ["kill_aspd", "kill_aspd_big", "def_stack"]: stacks.erase(name)
	for name in cooldowns.keys():
		cooldowns[name] = float(cooldowns[name]) - delta
		if float(cooldowns[name]) <= 0.0: cooldowns.erase(name)
	if mark_time > 0.0:
		mark_time -= delta
		if mark_time <= 0.0: mark_target = null
	if force_crit and timers.has("crit_window") == false and has("evade_next_crit_long") and not has("evade_next_crit"):
		force_crit = false
	if temp_shield_time > 0.0:
		temp_shield_time -= delta
		if temp_shield_time <= 0.0:
			player.shield = maxf(0.0, player.shield - temp_shield)
			temp_shield = 0.0
	if has("idle_barrier") and since_hurt >= 8.0 and not _idle_barrier_given:
		_idle_barrier_given = true
		player.shield = maxf(player.shield, player.max_hp * 0.15)
	if has("idle_strike") and since_attack >= 5.0: idle_strike_ready = true
	for i in range(_pending.size() - 1, -1, -1):
		_pending[i].at = float(_pending[i].at) - delta
		if float(_pending[i].at) <= 0.0:
			var p: Dictionary = _pending[i]
			_pending.remove_at(i)
			_burst(p.pos, float(p.radius), float(p.damage), str(p.kind))
	for i in range(_zones.size() - 1, -1, -1):
		var zone: Dictionary = _zones[i]
		zone.time = float(zone.time) - delta
		zone.tick = float(zone.tick) - delta
		if bool(zone.get("follow", false)): zone.pos = player.global_position
		if float(zone.tick) <= 0.0:
			zone.tick = 0.5
			for enemy in _enemies_near(zone.pos, float(zone.radius)):
				if str(zone.kind) == "fire": player._deal(enemy, float(zone.damage), "arts", false, 0.0, false)
				elif str(zone.kind) == "snow": enemy.apply_status("slow", 0.6, 0.30)
			if str(zone.kind) == "snow": player.heal(player.max_hp * 0.02 * 0.5)
		if float(zone.time) <= 0.0: _zones.remove_at(i)

# --- Helpers -------------------------------------------------------------------

func _enemies_near(at: Vector3, radius: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	if not is_instance_valid(player.game): return out
	for node in player.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.game != player.game or enemy._dead: continue
		if Vector2(enemy.global_position.x - at.x, enemy.global_position.z - at.z).length() <= radius: out.append(enemy)
	return out

func _enemies_in_cone(direction: Vector3, reach: float, half_angle: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	var aim := Vector3(direction.x, 0, direction.z).normalized()
	for enemy in _enemies_near(player.global_position, reach):
		var offset := enemy.global_position - player.global_position
		offset.y = 0
		if offset.length() < 0.05 or aim.dot(offset.normalized()) >= cos(deg_to_rad(half_angle)): out.append(enemy)
	out.sort_custom(func(a, b): return a.global_position.distance_to(player.global_position) < b.global_position.distance_to(player.global_position))
	return out

func _nearest(at: Vector3, radius: float, skip: Dictionary) -> Enemy:
	var best: Enemy = null
	var best_d := radius
	for enemy in _enemies_near(at, radius):
		if skip.has(enemy.get_instance_id()): continue
		var d := Vector2(enemy.global_position.x - at.x, enemy.global_position.z - at.z).length()
		if d <= best_d:
			best = enemy
			best_d = d
	return best

## Damage to every enemy around `at`; `push` shoves them out, `stun` stuns.
func _burst(at: Vector3, radius: float, damage: float, kind: String, push: bool = false, stun: float = 0.0) -> void:
	if not is_instance_valid(player.game): return
	CombatVfx.spawn(player.game, Vector3(at.x, 0.09, at.z), Vector3.FORWARD, "burst", 0, true)
	for enemy in _enemies_near(at, radius):
		player._deal(enemy, damage, kind, false, 0.0, false)
		if not is_instance_valid(enemy) or enemy._dead: continue
		if push:
			var away := enemy.global_position - at
			away.y = 0
			enemy.push(away.normalized() if away.length_squared() > 0.001 else Vector3.FORWARD, 1.5)
		if stun > 0.0: enemy.stun(stun)

## A flat coloured disc on the ground for `seconds` (zones, fuses).
func _disc(at: Vector3, radius: float, colour: Color, seconds: float) -> void:
	if not is_instance_valid(player.game): return
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = 0.02
	cylinder.radial_segments = 24
	mesh.mesh = cylinder
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = colour
	material.no_depth_test = true
	mesh.material_override = material
	player.game.add_child(mesh)
	mesh.global_position = Vector3(at.x, 0.06, at.z)
	var tween := mesh.create_tween()
	tween.tween_interval(maxf(0.05, seconds))
	tween.tween_callback(mesh.queue_free)
