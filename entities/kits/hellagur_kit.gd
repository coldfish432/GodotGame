class_name HellagurKit
extends OperatorKit
## 赫拉格 · 武者 · 刃 (干员寻访策划案 §4.1, §9 第 7 条).
## - Basic: three cuts (slash, return cut, iai); every landed hit heals him
##   (饮刃). Flasks and self-regeneration heal him only half (用户 2026-10-16).
## - 月盈星亏 (talent): attack speed rises with the life he has lost.
## - Space 月相: each press steps to the next phase and opens it — 新月 (the
##   next cut is a heavy two-hit cleave) → 弦月 (double cuts and evasion for a
##   while) → 满月 (wide sweeps over several enemies for a while).
## - 坚忍 (tree): once a segment a lethal hit leaves him on 1 life.

const COMBO := [1.0, 1.0, 1.3]
## PRTS 武者: 每次攻击回复生命. Before the 饮刃 node has a rank.
const HIT_HEAL := 0.015
const NEWMOON_SCALE := 1.75
const NEWMOON_GAP := 0.1
const HALF_SCALE := 0.8
const HALF_GAP := 0.08
const HALF_ATK := 0.4
const HALF_EVASION := 0.25
const FULL_ATK := 0.6
const FULL_TARGETS := 3
const FULL_RADIUS := 4.2
const FULL_HALF_ANGLE := 75.0
const PHASE_SECONDS := 6.0
const PHASES := ["新月", "弦月", "满月"]
## He loses this much life for the talent's full attack speed (PRTS: 50%).
const TALENT_LOSS := 0.5

var phase_next := 0
var newmoon_armed := false
var half_timer := 0.0
var full_timer := 0.0
var tenacity_used := 0
var _pending: Array[Dictionary] = []
var _marker: CombatVfx

func _init(p: Player) -> void:
	super(p, "hellagur")

func cooldown_total() -> float:
	return value("moon", 1) if rank("moon") > 0 else 6.0

func moon_scale() -> float:
	return value("moon", 0) if rank("moon") > 0 else 1.0

func potion_factor() -> float: return 0.5
func regen_factor() -> float: return 0.5

func aspd_bonus() -> float:
	return talent(0) * clampf((1.0 - player.hp_ratio()) / TALENT_LOSS, 0.0, 1.0)

func atk_pct() -> float:
	if half_timer > 0.0: return HALF_ATK
	if full_timer > 0.0: return FULL_ATK
	return 0.0

func evasion_bonus() -> float:
	return maxf(HALF_EVASION, value("half_guard")) if half_timer > 0.0 else 0.0

func status_text() -> String:
	if newmoon_armed: return PHASES[0]
	if half_timer > 0.0: return "%s %.1f" % [PHASES[1], half_timer]
	if full_timer > 0.0: return PHASES[2] if transmuter("moon") == "moon_full" else "%s %.1f" % [PHASES[2], full_timer]
	return ""

## Life back from one landed hit (饮刃).
func hit_heal() -> float:
	return player.max_hp * (value("drink") if rank("drink") > 0 else HIT_HEAL)

func cast(_point: Vector3) -> bool:
	var phase := phase_next
	# 满月常驻: a press during the endless full moon ends it and starts 弦月.
	if transmuter("moon") == "moon_full" and full_timer > 0.0: phase = 1
	newmoon_armed = false
	half_timer = 0.0
	full_timer = 0.0
	match phase:
		0: newmoon_armed = true
		1: half_timer = PHASE_SECONDS
		2: full_timer = INF if transmuter("moon") == "moon_full" else PHASE_SECONDS
	phase_next = (phase + 1) % 3
	if phase_next == 0 and transmuter("moon") == "moon_full": phase_next = 1
	begin_cast(cooldown_total())
	_show_marker(phase)
	return true

func _show_marker(phase: int) -> void:
	if is_instance_valid(_marker): _marker.queue_free()
	_marker = null
	var sheet := tex("phase")
	if sheet == null or not is_instance_valid(game()): return
	var frame := AtlasTexture.new()
	frame.atlas = sheet
	frame.region = Rect2(phase * 9, 0, 9, 9)
	_marker = CombatVfx.painted(player, player.global_position, Vector3.FORWARD, frame, 1, INF, "billboard", 0.0, 1.35, 0.0, false)

func _phase_running() -> bool:
	return newmoon_armed or half_timer > 0.0 or full_timer > 0.0

func tick(delta: float) -> void:
	super(delta)
	if half_timer > 0.0: half_timer = maxf(0.0, half_timer - delta)
	if full_timer > 0.0 and full_timer < INF: full_timer = maxf(0.0, full_timer - delta)
	if not _phase_running() and is_instance_valid(_marker):
		_marker.queue_free()
		_marker = null
	for i in range(_pending.size() - 1, -1, -1):
		var cut: Dictionary = _pending[i]
		cut.at -= delta
		if cut.at > 0.0: continue
		_pending.remove_at(i)
		_cut(cut.target, cut.raw, cut.crit, cut.direction)

func swing(direction: Vector3, target: Enemy, stage: int, lands: bool, multiplier: float, crit: bool, crit_factor: float) -> void:
	var rate := player.animation_rate()
	var at := foot(player.global_position)
	var factor := multiplier * crit_factor * player.form_factor(1)
	if is_instance_valid(game()): game().sound.play("hit")
	if newmoon_armed and lands:
		newmoon_armed = false
		play("newmoon", direction, 0.0, rate)
		fx(at, direction, "newmoon", 1, 0.2, "ground", 60 * CombatVfx.PIXEL * 0.5, 0.05)
		var raw := player.attack_power() * NEWMOON_SCALE * moon_scale() * factor * player.target_multiplier(target)
		_cut(target, raw, crit, direction)
		_pending.append({"at": NEWMOON_GAP, "target": target, "raw": raw, "crit": crit, "direction": direction})
		_stop(target, 0.06)
		if is_instance_valid(game()): game().start_sword_shake()
		return
	if half_timer > 0.0:
		play("halfmoon", direction, 0.0, rate)
		fx(at, direction, "halfmoon_a", 1, 0.12, "ground", 1.2, 0.04)
		fx(at, direction, "halfmoon_b", 1, 0.16, "ground", 1.5, 0.05)
		if not lands: return
		var raw := player.attack_power() * HALF_SCALE * moon_scale() * factor * player.target_multiplier(target)
		_cut(target, raw, crit, direction)
		_pending.append({"at": HALF_GAP, "target": target, "raw": raw, "crit": crit, "direction": direction})
		_stop(target, 0.03)
		return
	if full_timer > 0.0:
		play("fullmoon", direction, 0.0, rate)
		fx(at, direction, "fullmoon", 1, 0.22, "ground", 1.8, 0.04)
		var most := int(value("full_reach")) if rank("full_reach") > 0 else FULL_TARGETS
		var struck := enemies_near(player.global_position, FULL_RADIUS, direction, FULL_HALF_ANGLE)
		if lands and not target in struck: struck.push_front(target)
		for i in range(mini(most, struck.size())):
			var enemy: Enemy = struck[i]
			_cut(enemy, player.attack_power() * float(COMBO[stage]) * moon_scale() * factor * player.target_multiplier(enemy), crit, direction)
		if not struck.is_empty(): _stop(struck[0], 0.04)
		return
	play("attack_" + str(stage + 1), direction, 0.0, rate)
	match stage:
		0: fx(at, direction, "cut_1", 1, 0.12, "ground", 1.5, 0.04)
		1: fx(at, direction, "cut_2", 1, 0.12, "ground", 1.5, 0.05)
		_: fx(at, direction, "iai", 1, 0.16, "ground", 1.3, 0.05)
	if not lands: return
	var scale := float(COMBO[stage]) * (1.0 + value("iai") if stage == 2 else 1.0)
	_cut(target, player.attack_power() * scale * factor * player.target_multiplier(target), crit, direction)
	_stop(target, 0.05 if stage == 2 else 0.03)

## One landed cut: the shared hit pipeline, then 饮刃's life back.
func _cut(target: Enemy, raw: float, crit: bool, direction: Vector3) -> void:
	if not alive(target): return
	basic_hit(target, raw, "phys", crit, player.physical_pierce(), "spark", direction)
	player.heal(hit_heal())
	if is_instance_valid(game()):
		CombatVfx.painted(player, player.global_position, Vector3.FORWARD, tex("drain"), 2, 0.2, "billboard", 0.0, 0.9)

func _stop(target: Enemy, seconds: float) -> void:
	if alive(target): target.hitstop_remaining = maxf(target.hitstop_remaining, seconds)
	player.hitstop_remaining = seconds

## 弦月反击: an evaded blow during 弦月 is answered at once.
func on_evade(attacker: Enemy) -> void:
	if half_timer <= 0.0 or transmuter("moon") != "moon_counter" or not alive(attacker): return
	if flat(attacker.global_position - player.global_position) > FULL_RADIUS: return
	var direction := attacker.global_position - player.global_position
	play("halfmoon", direction)
	_cut(attacker, player.attack_power() * HALF_SCALE * moon_scale() * player.target_multiplier(attacker), false, direction)

## 坚忍: once a segment (twice with 坚忍延长) a lethal blow leaves him on 1.
func survive_lethal() -> bool:
	if rank("tenacity") <= 0: return false
	var longer := transmuter("moon") == "moon_tenacity"
	if tenacity_used >= (2 if longer else 1): return false
	tenacity_used += 1
	player.hp = 1.0
	player.invuln_timer = value("tenacity") * (3.0 if longer else 1.0)
	player.stats_changed.emit()
	return true

func reset_segment() -> void:
	tenacity_used = 0

func interrupt() -> void:
	_pending.clear()

func reset() -> void:
	super()
	phase_next = 0
	newmoon_armed = false
	half_timer = 0.0
	full_timer = 0.0
	tenacity_used = 0
	if is_instance_valid(_marker): _marker.queue_free()
	_marker = null
