class_name LinKit
extends OperatorKit
## 林 · 阵法术师 · 源石技艺 (干员寻访策划案 §4.6).
## - Basic: an arts array bursts under the target, hitting everyone on it;
##   the third of a combo is the large array.
## - 琉璃璧 (计出万全): a glass barrier takes every small blow; one heavy blow
##   shatters it, blasting and stunning those around her, and it grows back.
## - 韬光: being struck may shorten her skill's cooldown.
## - Space 流光乍裂: a burst of power; while it runs the barrier is far harder
##   to break, and every enemy she brings down shatters it and it reforms.

const REACH := 7.0
const INTERVAL := 1.15
const COMBO := [0.8, 0.8, 1.3]
const RADIUS := 1.5
const BIG_RADIUS := 2.2
const THRESHOLD := 0.10
const REGROW := 8.0
const SHATTER_SCALE := 1.2
const SHATTER_RADIUS := 3.0
const SHATTER_STUN := 1.0
const SURGE_ATK := 0.5
const SURGE_SECONDS := 7.0
const SURGE_GLASS := 3.0
const TAOGUANG_REFUND := 0.5

var glass_up := true
var regrow_timer := 0.0
var surge_timer := 0.0
var _shell: CombatVfx

func _init(p: Player) -> void:
	super(p, "lin")

func ranged() -> bool: return true
func reach() -> float: return REACH
func interval_factor() -> float: return INTERVAL
func cooldown_total() -> float: return 18.0

func atk_pct() -> float:
	return (value("surge") if rank("surge") > 0 else SURGE_ATK) if surge_timer > 0.0 else 0.0

func evasion_bonus() -> float:
	return 0.2 if transmuter("surge") == "lin_shelter" else 0.0

func status_text() -> String:
	return "流光乍裂 %.1f" % surge_timer if surge_timer > 0.0 else ""

## The single blow, after mitigation, past which the barrier breaks.
func threshold() -> float:
	var share := value("glass") if rank("glass") > 0 else THRESHOLD
	share *= 1.0 + talent(0)
	if transmuter("surge") == "lin_glass": share *= 1.6
	if surge_timer > 0.0: share *= SURGE_GLASS
	return player.max_hp * share

func swing(direction: Vector3, target: Enemy, stage: int, lands: bool, multiplier: float, crit: bool, crit_factor: float) -> void:
	play("attack_" + str(stage + 1), direction, 0.0, player.animation_rate())
	if not lands: return
	if is_instance_valid(game()): game().sound.play("hit")
	var big := stage == 2
	var radius := (BIG_RADIUS if big else RADIUS) * (1.0 + (value("surge_reach") if surge_timer > 0.0 else 0.0))
	var centre := target.global_position
	fx(foot(centre), Vector3.FORWARD, "array_big" if big else "array", 3, 0.25, "ground", 0.0, 0.05).scale = Vector3.ONE * (radius / (BIG_RADIUS if big else RADIUS))
	var raw := player.attack_power() * float(COMBO[stage]) * (1.0 + value("array")) * multiplier * crit_factor * player.form_factor(1)
	var struck := enemies_near(centre, radius, Vector3.ZERO, 180.0, false)
	if not target in struck: struck.push_front(target)
	for enemy in struck:
		basic_hit(enemy, raw * player.target_multiplier(enemy), "arts", crit, 0.0, "spark")
		if transmuter("surge") == "lin_linglong" and alive(enemy): enemy.stun(0.3)

func cast(_point: Vector3) -> bool:
	surge_timer = value("surge", 1) if rank("surge") > 0 else SURGE_SECONDS
	play("surge", -player.global_basis.z, 0.6)
	begin_cast(cooldown_total())
	fx(foot(player.global_position), Vector3.FORWARD, "surge", 3, 0.35, "ground", 0.0, 0.06)
	if not glass_up: _regrow()
	return true

## Every blow that reaches her: the barrier takes it, or breaks on it.
func mitigate(amount: float, kind: String, _attacker: Enemy) -> float:
	if not glass_up or amount <= 0.0 or kind == "true": return amount
	if amount > threshold():
		_shatter()
		return amount
	if is_instance_valid(game()): DamageNumber.spawn(game(), player.global_position, str(roundi(amount)), "shield")
	return 0.0

func on_hurt(_amount: float, _attacker: Enemy) -> void:
	if rank("taoguang") > 0 and randf() < value("taoguang"): refund(TAOGUANG_REFUND)

func on_kill(_enemy: Enemy) -> void:
	if surge_timer <= 0.0: return
	if glass_up: _shatter()
	_regrow()

func _shatter() -> void:
	glass_up = false
	regrow_timer = value("glass", 1) if rank("glass") > 0 else REGROW
	if is_instance_valid(_shell): _shell.queue_free()
	_shell = null
	if surge_timer <= 0.0: play("shatter", -player.global_basis.z)
	fx(foot(player.global_position), Vector3.FORWARD, "shatter", 3, 0.3, "ground", 0.0, 0.07)
	if is_instance_valid(game()):
		for i in range(3):
			CombatVfx.painted(game(), player.global_position + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8)), Vector3.FORWARD, frame_of("shard", 3, i), 1, 0.3, "billboard", 0.0, 0.5)
		game().sound.play("barrier_break")
	var scale := value("shatter_power") if rank("shatter_power") > 0 else SHATTER_SCALE
	for enemy in enemies_near(player.global_position, SHATTER_RADIUS, Vector3.ZERO, 180.0, false):
		skill_hit(enemy, player.attack_power() * scale * player.wave_multiplier(), "arts")
		if alive(enemy): enemy.stun(SHATTER_STUN)
	player.stats_changed.emit()

func _regrow() -> void:
	glass_up = true
	regrow_timer = 0.0
	fx(foot(player.global_position), Vector3.FORWARD, "regen", 2, 0.3, "ground", 0.0, 0.06)
	_show_shell()

func _show_shell() -> void:
	if is_instance_valid(_shell) or not is_instance_valid(game()): return
	_shell = fx_on_her("shell", 2, INF, "ground", 0.06, 3.0)

func tick(delta: float) -> void:
	super(delta)
	if surge_timer > 0.0: surge_timer = maxf(0.0, surge_timer - delta)
	if not glass_up:
		regrow_timer = maxf(0.0, regrow_timer - delta)
		if regrow_timer <= 0.0: _regrow()
	elif not is_instance_valid(_shell): _show_shell()

func reset() -> void:
	super()
	surge_timer = 0.0
	glass_up = true
	regrow_timer = 0.0
