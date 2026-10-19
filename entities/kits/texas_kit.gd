class_name TexasKit
extends OperatorKit
## 德克萨斯 · 尖兵 (干员寻访策划案 §9.1).
## - Basic: three quick one-handed cuts, standing her ground (用户 2026-10-16:
##   普攻不突进).
## - 战术快递 (talent): her skill hits harder; 急件: after 剑雨 lands she runs
##   faster for a moment.
## - Space 剑雨: swords fall in a ring round her, two waves of arts damage,
##   the first stunning. 精英 2: wider / three waves / 剑雨滂沱 (缄默德克萨斯
##   技能 3: after the waves, swords keep falling on up to 4 enemies a second).

const INTERVAL := 0.8
const COMBO := [0.8, 0.8, 1.1]
const RADIUS := 3.5
const WAVE_GAP := 0.25
const STUN := 1.5
const EXPRESS_SKILL := 0.10
const EXPRESS_SPEED := 0.2
const EXPRESS_SECONDS := 3.0
const STORM_SECONDS := 4.0
const STORM_TARGETS := 4
const STORM_SCALE := 0.5
const STORM_STUN := 0.2

var waves_left := 0
var _wave_clock := 0.0
var _first_wave := true
var express_timer := 0.0
var storm_timer := 0.0
var _storm_clock := 0.0
var _dash_art: CombatVfx

func _init(p: Player) -> void:
	super(p, "texas")

func interval_factor() -> float: return INTERVAL
func busy() -> bool: return waves_left > 0
func rooted() -> bool: return waves_left > 0

func cooldown_total() -> float:
	return value("rain", 1) if rank("rain") > 0 else 10.0

func aspd_bonus() -> float: return value("vanguard")

func move_mult() -> float:
	return 1.0 + (value("express") if rank("express") > 0 else EXPRESS_SPEED) if express_timer > 0.0 else 1.0

func radius() -> float:
	return RADIUS * (1.4 if transmuter("rain") == "rain_wide" else 1.0)

## 战术快递: skill damage on top of the gear's.
func skill_scale() -> float:
	return (value("rain") if rank("rain") > 0 else 1.4) * (1.0 + maxf(EXPRESS_SKILL, talent(0)))

func swing(direction: Vector3, target: Enemy, stage: int, lands: bool, multiplier: float, crit: bool, crit_factor: float) -> void:
	play("attack_" + str(stage + 1), direction, 0.0, player.animation_rate())
	var at := foot(player.global_position)
	fx(at, direction, "cut_" + str(stage + 1), 1, 0.12, "ground", 1.4, 0.04 + stage * 0.005)
	if is_instance_valid(game()): game().sound.play("hit")
	if not lands: return
	var raw := player.attack_power() * float(COMBO[stage]) * multiplier * crit_factor * player.form_factor(1) * player.target_multiplier(target)
	basic_hit(target, raw, "phys", crit, player.physical_pierce(), "spark", direction)
	refund(value("quickdraw"))
	if alive(target): target.hitstop_remaining = maxf(target.hitstop_remaining, 0.03)
	player.hitstop_remaining = 0.03

func cast(_point: Vector3) -> bool:
	waves_left = 3 if transmuter("rain") == "rain_triple" else 2
	_wave_clock = 0.0
	_first_wave = true
	player.clear_move_target()
	play("rain", -player.global_basis.z, WAVE_GAP * waves_left + 0.2)
	begin_cast(cooldown_total())
	var at := foot(player.global_position)
	fx(at, Vector3.FORWARD, "rain_ring", 2, WAVE_GAP * waves_left + 0.2, "ground", 0.0, 0.05).scale = Vector3.ONE * radius() / RADIUS
	if is_instance_valid(game()):
		for i in range(10):
			var angle := TAU * i / 10.0 + randf_range(-0.2, 0.2)
			var spot := player.global_position + Vector3(cos(angle), 0, sin(angle)) * randf_range(0.8, radius())
			CombatVfx.painted(game(), spot + Vector3.UP * 0.8, Vector3.FORWARD, frame_of("rain_sword", 3, i % 3), 1, WAVE_GAP + 0.1, "billboard", 0.0, 0.0)
	return true

func _wave() -> void:
	waves_left -= 1
	var hit_any := false
	for enemy in enemies_near(player.global_position, radius(), Vector3.ZERO, 180.0, false):
		skill_hit(enemy, skill_power() * skill_scale(), "arts", randf() < player.crit_rate())
		hit_any = true
		if is_instance_valid(enemy): fx(enemy.global_position, Vector3.FORWARD, "rain_hit", 2, 0.15, "ground", 0.0, 0.3)
		if _first_wave and alive(enemy): enemy.stun(STUN + value("rain_stun"))
		if rank("rain_breath") > 0: player.stamina = minf(100.0, player.stamina + value("rain_breath"))
	_first_wave = false
	if is_instance_valid(game()):
		game().sound.play("hit")
		game().start_sword_shake()
	if hit_any:
		express_timer = EXPRESS_SECONDS
		if not is_instance_valid(_dash_art): _dash_art = fx_on_her("dash", 2, INF, "ground", 0.05, 8.0)
	if waves_left <= 0:
		player.swing_remaining = 0.0
		if transmuter("rain") == "rain_storm":
			storm_timer = STORM_SECONDS
			_storm_clock = 0.0

func _storm() -> void:
	var near := enemies_near(player.global_position, radius(), Vector3.ZERO, 180.0, false)
	for i in range(mini(STORM_TARGETS, near.size())):
		var enemy: Enemy = near[i]
		if is_instance_valid(game()): CombatVfx.painted(game(), enemy.global_position + Vector3.UP * 0.6, Vector3.FORWARD, frame_of("rain_sword", 3, i % 3), 1, 0.15, "billboard", 0.0, 0.0)
		skill_hit(enemy, skill_power() * skill_scale() * STORM_SCALE, "arts")
		if alive(enemy): enemy.stun(STORM_STUN)

func tick(delta: float) -> void:
	super(delta)
	if waves_left > 0:
		_wave_clock -= delta
		while waves_left > 0 and _wave_clock <= 0.0:
			_wave_clock += WAVE_GAP
			_wave()
	if storm_timer > 0.0:
		storm_timer = maxf(0.0, storm_timer - delta)
		_storm_clock -= delta
		if _storm_clock <= 0.0:
			_storm_clock += 1.0
			_storm()
	if express_timer > 0.0:
		express_timer = maxf(0.0, express_timer - delta)
		if express_timer <= 0.0 and is_instance_valid(_dash_art):
			_dash_art.queue_free()
			_dash_art = null

func interrupt() -> void:
	waves_left = 0

func reset() -> void:
	super()
	storm_timer = 0.0
	express_timer = 0.0
	if is_instance_valid(_dash_art): _dash_art.queue_free()
	_dash_art = null
