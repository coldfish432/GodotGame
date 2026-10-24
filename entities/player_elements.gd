class_name PlayerElements
extends RefCounted

## Her side of 属性伤害与地区装备策划案 v1.1: the elemental damage her hits
## add or convert and the damage over time they leave (§3.4, §6); the
## elemental share of what hits her, her five resistances under the depth's
## 压制 and her own 损伤 gauges (§4, §5.2); and the regional affixes and
## orange signatures that ask about the fight (§8). Player owns one and
## calls it from _deal, take_damage and the ticks.

var player: Player
var state := ElementState.new()
## 连续命中 (龙门 hands): the target hit last and how many times in a row.
var _chain_target: Enemy
var _chain_hits := 0
var _elite_kill_left := 0.0
var _dash_def_left := 0.0

const CROWD_RADIUS := 3.0
const CROWD_MAX := 5
const LONE_RADIUS := 5.0
const CHAIN_MAX := 5
const LOW_HP := 0.25
const ELITE_KILL_SECONDS := 6.0
const DASH_DEF_SECONDS := 1.0
const SPREAD_RADIUS := 3.0
const SHATTER := 0.80
const SHIELDWALL_AT := 0.35
const SHIELDWALL_CUT := 0.25
const CARRIER_AT := 60.0
const CARRIER_DEF := 0.20
const TREELINE_AT := 60.0
const TREELINE_EVASION := 0.08
const DEBT_AT := 60.0
const FIRSTBLOOD_REFUND := 0.30

func _init(p_player: Player) -> void:
	player = p_player

func s(key: String) -> float:
	return float(player.stats.get(key, 0.0))

func _game() -> GameManager:
	return player.game if is_instance_valid(player.game) else null

func _floor() -> int:
	return _game().floor_number if _game() != null else 1

# --- Resistances (§4) ---------------------------------------------------------------

## Her resistance to `kind` this floor: gear, minus the depth's 压制, within
## −50 and her cap (80, up to 90 with 抗性上限).
func res(kind: String) -> float:
	if kind == "necro" or kind == "arts": return player.resistance()
	var key: String = Elements.RES_KEY.get(kind, "")
	if key.is_empty(): return 0.0
	var cap := minf(Elements.RES_CAP_MAX, Elements.RES_CAP + s("res_cap"))
	return clampf(s(key) + s("res_all_elem") - Elements.penalty(_floor()), Elements.RES_MIN, cap)

## Before the 压制, for the stat panel's hover.
func res_gear(kind: String) -> float:
	var key: String = Elements.RES_KEY.get(kind, "")
	return 0.0 if key.is_empty() else s(key) + s("res_all_elem")

# --- Her hits (§3.4, §6) --------------------------------------------------------------

## What the regional affixes add to a hit on `target` (§8): one multiplier.
func damage_mult(target: Enemy) -> float:
	if not is_instance_valid(target): return 1.0
	var pct := 0.0
	if s("crowd_dmg") > 0.0: pct += s("crowd_dmg") * mini(CROWD_MAX, player.nearby_enemy_count(CROWD_RADIUS))
	if s("ambush_dmg") > 0.0 and not target.hit_by_player and target.state == Enemy.State.IDLE: pct += s("ambush_dmg")
	if s("chain_dmg") > 0.0 and target == _chain_target: pct += s("chain_dmg") * mini(CHAIN_MAX, _chain_hits)
	if s("full_hp_dmg") > 0.0 and target.health >= target.max_health - 0.5: pct += s("full_hp_dmg")
	if s("stunned_dmg") > 0.0 and target.stun_timer > 0.0: pct += s("stunned_dmg")
	if s("low_hp_dmg") > 0.0 and target.health < target.max_health * LOW_HP: pct += s("low_hp_dmg")
	if s("ore_atk") > 0.0 and player.ore_count() > 0: pct += s("ore_atk")
	var game := _game()
	if game != null:
		if s("debt_dmg") > 0.0 and game.features.value("debt") >= DEBT_AT: pct += s("debt_dmg")
		if s("sig_resonance") > 0.0: pct += 0.02 * floorf(game.current_contamination() / 10.0)
	if s("sig_shatter") > 0.0 and target.statuses.has("frozen"):
		target.statuses.erase("frozen")
		pct += SHATTER
	return 1.0 + pct

## After a direct hit of `raw` (her hit before the target's mitigation): the
## elemental parts it adds, then the damage over time it may leave. The parts
## are their own hits: no lifesteal, no further procs. Returns how much of
## `raw` was converted away from the hit itself (the caller deals the rest).
func convert_share() -> float:
	var total := 0.0
	for kind in Elements.KINDS: total += s(Elements.CONV_KEY[kind])
	return minf(Elements.CONV_CAP, total)

func on_hit(target: Enemy, raw: float, crit: bool) -> void:
	if not is_instance_valid(target) or target._dead: return
	if target == _chain_target: _chain_hits += 1
	else:
		_chain_target = target
		_chain_hits = 1
	var conv := convert_share()
	var conv_total := 0.0
	for kind in Elements.KINDS: conv_total += s(Elements.CONV_KEY[kind])
	for kind in Elements.KINDS:
		var share := s(Elements.ADD_KEY[kind])
		if conv_total > 0.0: share += s(Elements.CONV_KEY[kind]) / conv_total * conv
		if share <= 0.0: continue
		var part := raw * share * (1.0 + s(Elements.DMG_KEY[kind]))
		target.take_hit(part, kind, crit)
		if target._dead: return
	_proc_dots(target, raw)

func _proc_dots(target: Enemy, raw: float) -> void:
	var form := player.weapon_form()
	var proc := float(Elements.FORM_PROC.get(form, 1.0))
	for dot in Elements.DOT_CHANCE_KEY:
		var chance := s(Elements.DOT_CHANCE_KEY[dot]) * proc
		if chance <= 0.0 or randf() >= chance: continue
		var spec: Array = Elements.DOTS[dot]
		var element: String = Elements.DOT_ELEMENT[dot]
		var bonus := 1.0 + s("dot_pct") + s(Elements.DMG_KEY.get(element, ""))
		target.apply_dot(dot, raw * float(spec[2]) * bonus, float(spec[1]) * (1.0 + s("dot_dur_pct")))

## 损伤累积 +X% (the 爆发 family): the fill a gauge takes from her hits.
func fill_mult() -> float:
	return 1.0 + s("build_pct")

# --- Hits on her (§4, §5.2, §8) --------------------------------------------------------

## The hit after DEF / 法抗 / her elemental resistance: an enemy's elemental
## share (EnemyAttacks.ELEMENTS) leaves the hit's own kind and is cut by her
## resistance to that element, and fills her gauge.
func mitigate(amount: float, kind: String, attacker: Enemy) -> float:
	var spec: Dictionary = EnemyAttacks.ELEMENTS.get(attacker.enemy_type, {}) if is_instance_valid(attacker) else {}
	if is_instance_valid(attacker) and attacker.statuses.has("weaken"): amount *= 1.0 - attacker.status_value("weaken")
	if Elements.is_element(kind) or kind == "bleed":
		var hit := amount * Elements.multiplier(res(kind))
		_fill(kind, hit)
		return hit
	var element := str(spec.get("kind", ""))
	var share := float(spec.get("share", 0.0)) * Elements.enemy_share_mult(_floor()) if kind != "true" and not element.is_empty() else 0.0
	var main := CombatStats.mitigate(amount * (1.0 - share), kind, player.defense_value(), player.resistance())
	if share <= 0.0: return main
	var side := amount * share * Elements.multiplier(res(element))
	_fill(element, side)
	return main + side

## What the regional and signature affixes take off a hit (§8), as a multiplier.
func taken_mult(attacker: Enemy) -> float:
	var cut := 0.0
	if s("crowd_dr") > 0.0: cut += s("crowd_dr") * mini(CROWD_MAX, player.nearby_enemy_count(CROWD_RADIUS))
	if is_instance_valid(attacker):
		if s("melee_taken") < 0.0 and not attacker.keeps_distance: cut -= s("melee_taken")
		if s("elite_taken") < 0.0 and attacker.elite: cut -= s("elite_taken")
		if s("blast_taken") < 0.0 and (attacker._dead or attacker.enemy_type == "slug_volatile"): cut -= s("blast_taken")
		if s("back_taken") < 0.0 and _behind(attacker): cut -= s("back_taken")
	if s("sig_shieldwall") > 0.0 and player.hp_ratio() < SHIELDWALL_AT: cut += SHIELDWALL_CUT
	# 清算小队 hit less the more she resists bleeding: half her 流血抗性 (§4.3).
	if is_instance_valid(attacker) and attacker.is_in_group("reckoning"): cut += clampf(res("bleed"), 0.0, 100.0) / 200.0
	var game := _game()
	if game != null and s("sig_silence") > 0.0: cut += 0.03 * floorf(game.features.value("debt") / 30.0)
	return maxf(0.2, 1.0 - cut)

func _behind(attacker: Enemy) -> bool:
	var to := attacker.global_position - player.global_position
	to.y = 0.0
	var facing := -player.global_transform.basis.z
	facing.y = 0.0
	if to.length_squared() < 0.0001 or facing.length_squared() < 0.0001: return false
	return to.normalized().dot(facing.normalized()) < -0.3

## A hit of `raw` landed on her: the damage over time its enemy leaves.
func after_hurt(raw: float, attacker: Enemy) -> void:
	if not is_instance_valid(attacker): return
	var spec: Dictionary = EnemyAttacks.ELEMENTS.get(attacker.enemy_type, {})
	if not spec.has("dot") or randf() >= float(spec.get("chance", 0.0)): return
	var dot := str(spec.dot)
	var d: Array = Elements.DOTS[dot]
	state.apply_dot(dot, raw * float(d[2]), float(d[1]) * maxf(0.2, 1.0 + s("dot_taken_dur")), str(d[0]))

func _fill(kind: String, amount: float) -> void:
	if not kind in Elements.GAUGE_KINDS: return
	if state.fill(kind, amount, player.max_hp * Elements.HER_THRESHOLD, Elements.HER_COOLDOWN): _burst(kind)

## Her gauge is full (§5.2).
func _burst(kind: String) -> void:
	var spec: Dictionary = Elements.HER_BURST[kind]
	var game := _game()
	if game != null: DamageNumber.spawn(game, player.global_position, Elements.NAMES[kind], kind, true)
	match kind:
		"burn": player.take_damage(player.max_hp * float(spec.damage), "true")
		"cold": player.apply_control("stun", Vector3.ZERO, 0.0, float(spec.freeze) * maxf(0.0, 1.0 + s("freeze_taken")))
		"corr":
			var stacks := mini(int(spec.stacks), int(player.hexes.get("corr_burst", {}).get("stacks", 0)) + 1)
			player.add_hex("corr_burst", {"def": -float(spec.def_down) * stacks, "stacks": stacks}, -1.0)
		"nerve": player.apply_control("stun", Vector3.ZERO, 0.0, float(spec.stun))
		"necro": player.add_hex("necro_burst", {"atk": -float(spec.atk_down)}, float(spec.secs))

## A stun's length on her: 神经抗性 shortens every stun (§4.3).
func stun_factor() -> float:
	return clampf(1.0 - res("nerve") / 100.0, 0.2, 1.0)

# --- Panel hooks ------------------------------------------------------------------------

func def_pct() -> float:
	var pct := 0.0
	if _dash_def_left > 0.0: pct += s("dash_def")
	var game := _game()
	if game != null and s("sig_carrier") > 0.0 and game.current_contamination() >= CARRIER_AT: pct += CARRIER_DEF
	return pct

func evasion_bonus() -> float:
	var value := 0.0
	if s("lone_evasion") > 0.0:
		value += s("lone_evasion")
		if player.nearby_enemy_count(LONE_RADIUS) <= 1: value += s("lone_evasion")
	if s("sig_treeline") > 0.0 and player.cold >= TREELINE_AT: value += TREELINE_EVASION
	return value

func aspd_bonus() -> float:
	var value := 0.0
	if _elite_kill_left > 0.0: value += s("elite_kill_aspd") * 100.0
	if s("rot_full_aspd") > 0.0 and is_instance_valid(player.attack_target) and player.attack_target.rot_stacks() >= Elements.ROT_STACKS:
		value += s("rot_full_aspd") * 100.0
	return value

func skill_bonus() -> float:
	return s("lone_skill") if s("lone_skill") > 0.0 and player.nearby_enemy_count(LONE_RADIUS) <= 1 else 0.0

## 赤金 found (血的价钱: +2% each 10 血债).
func gold_mult() -> float:
	var game := _game()
	if game == null or s("sig_bloodprice") <= 0.0: return 1.0
	return 1.0 + 0.02 * floorf(game.features.value("debt") / 10.0)

## How fast a map feature rises on her (§4.3, §8): its regional affix and,
## for 寒冷 and 污染, half her resistance to the element.
func feature_mult(kind: String) -> float:
	match kind:
		"cold": return maxf(0.0, 1.0 + s("cold_pct")) * (1.0 - clampf(res("cold"), 0.0, 100.0) / 200.0)
		"contamination": return 1.0 - clampf(res("corr"), 0.0, 100.0) / 200.0
		"debt": return maxf(0.0, 1.0 + s("debt_pct"))
	return 1.0

# --- Events -----------------------------------------------------------------------------

func tick(delta: float) -> void:
	_elite_kill_left = maxf(0.0, _elite_kill_left - delta)
	_dash_def_left = maxf(0.0, _dash_def_left - delta)
	if s("fire_regen") > 0.0 and _game() != null and _game().warm_fire() != null: player.heal(player.max_hp * s("fire_regen") * delta)
	for due in state.tick(delta, player.max_hp * Elements.HER_THRESHOLD):
		var kind := str(due.kind)
		var hit := float(due.damage) * (Elements.multiplier(res(kind)) if kind != "arts" else maxf(1.0 - player.resistance() / 100.0, CombatStats.DAMAGE_FLOOR))
		if kind == "arts": _fill("necro", hit)
		elif Elements.is_element(kind): _fill(kind, hit)
		player.take_dot(hit, kind)

func on_kill(enemy: Enemy) -> void:
	if enemy == null: return
	if s("kill_heal") > 0.0: player.heal(player.max_hp * s("kill_heal"))
	if enemy.elite and s("elite_kill_aspd") > 0.0: _elite_kill_left = ELITE_KILL_SECONDS
	# 家族清算: bleeding passes to whoever stands near when it kills.
	if s("sig_reckoning") > 0.0 and enemy.elements.has_dot("bleed"):
		var left: Dictionary = enemy.elements.dots.bleed
		var total := float(left.per_tick) * float(left.left) / Elements.DOT_TICK
		for other in _near(enemy.global_position, SPREAD_RADIUS, enemy):
			other.apply_dot("bleed", total, float(left.left))

func on_dash() -> void:
	if s("dash_def") > 0.0: _dash_def_left = DASH_DEF_SECONDS

func on_evade() -> void:
	if s("sig_escort") > 0.0 and player.gear_fx != null: player.gear_fx.force_crit = true

## The skill went off; `first` is what it met first (猎手先机).
func on_signature(first: Enemy) -> void:
	if s("sig_firstblood") <= 0.0 or not is_instance_valid(first) or first.health < first.max_health - 0.5: return
	if player.kit != null: player.kit.refund(player.kit.cooldown * FIRSTBLOOD_REFUND)
	elif player.is_amiya(): player.shadow_cooldown *= 1.0 - FIRSTBLOOD_REFUND
	else: player.add_charge(1)

## An enemy's gauge burst (Enemy._burst): the signatures that answer it.
func on_enemy_burst(enemy: Enemy, kind: String) -> void:
	if kind == "corr" and s("sig_cascade") > 0.0:
		for other in _near(enemy.global_position, SPREAD_RADIUS, enemy): other.corr_stacks = mini(int(Elements.BURST.corr.stacks), other.corr_stacks + 1)
	if kind == "burn" and s("sig_blaze") > 0.0 and player.gear_fx != null:
		player.gear_fx.add_fire_zone(enemy.global_position, 2.5, 3.0, player.arts_power() * 0.15)

func _near(at: Vector3, radius: float, except: Enemy) -> Array[Enemy]:
	var out: Array[Enemy] = []
	if _game() == null: return out
	for node in player.get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e == except or e._dead or e.game != _game(): continue
		if Vector2(e.global_position.x - at.x, e.global_position.z - at.z).length() <= radius: out.append(e)
	return out

func reset() -> void:
	state.clear()
	_chain_target = null
	_chain_hits = 0
	_elite_kill_left = 0.0
	_dash_def_left = 0.0
