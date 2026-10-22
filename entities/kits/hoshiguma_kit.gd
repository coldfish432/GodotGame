class_name HoshigumaKit
extends OperatorKit
## 星熊 · 铁卫 · 盾 (干员寻访策划案 §4.4).
## - Basic: two shield bashes, then a ram that knocks the enemy back.
## - 战术装甲: a share of blows is blocked outright, and a block lifts her
##   attack for a few seconds.
## - Space 力之锯: she plants the shield toward the cursor for a few seconds,
##   rooted, taking far less from the front while the shield's edge saws
##   through the fan ahead of her.
## - 鬼族 (talent): more life. 精英 2: 战意 / 荆棘 / 业火 (斩业星熊).

const COMBO := [1.0, 1.0, 1.4]
## Her old +30% DEF is in her build now (Operators.STAT_MULT, 复利数值改造清单 I).
const BASE_DEF := 0.0
const BLOCK_CHANCE := 0.15
const BLOCK_ATK := 0.2
const BLOCK_SECONDS := 5.0
const RAM_PUSH := 1.0
const SAW_SECONDS := 4.0
const SAW_TICK := 0.3
const SAW_RADIUS := 3.0
const SAW_HALF_ANGLE := 60.0
const SAW_FRONT := 0.5
const KARMA_SECONDS := 5.0

var saw_timer := 0.0
var saw_direction := Vector3.FORWARD
var block_timer := 0.0
var karma_timer := 0.0
var karma_used := false
## Tests set this to 0 or 1 to decide the block roll; −1 rolls.
var block_roll := -1.0
var _saw_clock := 0.0
var _saw_art: CombatVfx

func _init(p: Player) -> void:
	super(p, "hoshiguma")

func cooldown_total() -> float:
	return value("saw", 1) if rank("saw") > 0 else 12.0

func rooted() -> bool: return saw_timer > 0.0
func busy() -> bool: return saw_timer > 0.0
func hp_pct() -> float: return talent(0)

func def_pct() -> float:
	var pct := BASE_DEF + value("hannya")
	if player.hp_ratio() < 0.5: pct += value("oni")
	if saw_timer > 0.0 and transmuter("saw") == "saw_will": pct += 0.8
	return pct

func atk_pct() -> float:
	var pct := 0.0
	if block_timer > 0.0: pct += value("armour", 1) if rank("armour") > 0 else BLOCK_ATK
	if saw_timer > 0.0 and transmuter("saw") == "saw_will": pct += 0.4
	return pct

func status_text() -> String:
	return "力之锯 %.1f" % saw_timer if saw_timer > 0.0 else ""

func swing(direction: Vector3, target: Enemy, stage: int, lands: bool, multiplier: float, crit: bool, crit_factor: float) -> void:
	play("attack_" + str(stage + 1), direction, 0.0, player.animation_rate())
	var at := foot(player.global_position)
	if stage == 2: fx(at, direction, "ram", 1, 0.18, "ground", 32 * CombatVfx.PIXEL * 0.5 + 0.3, 0.05)
	else: fx(at, direction, "bash", 1, 0.12, "ground", 1.3, 0.04)
	if is_instance_valid(game()): game().sound.play("hit")
	if not lands: return
	var raw := player.attack_power() * float(COMBO[stage]) * multiplier * crit_factor * player.form_factor(1) * player.target_multiplier(target)
	basic_hit(target, raw, "phys", crit, player.physical_pierce(), "spark", direction)
	if stage == 2 and alive(target): target.push(direction, value("ram") if rank("ram") > 0 else RAM_PUSH)
	if alive(target): target.hitstop_remaining = maxf(target.hitstop_remaining, 0.05 if stage == 2 else 0.03)
	player.hitstop_remaining = 0.05 if stage == 2 else 0.03

func cast(point: Vector3) -> bool:
	saw_direction = Vector3(point.x - player.global_position.x, 0, point.z - player.global_position.z)
	if saw_direction.length_squared() < 0.01: saw_direction = -player.global_basis.z
	saw_direction = saw_direction.normalized()
	face(saw_direction)
	saw_timer = SAW_SECONDS
	_saw_clock = 0.0
	player.clear_target()
	player.clear_move_target()
	begin_cast(cooldown_total(), saw_direction)
	play("saw", saw_direction, SAW_SECONDS)
	if is_instance_valid(_saw_art): _saw_art.queue_free()
	if is_instance_valid(game()):
		_saw_art = CombatVfx.painted(game(), foot(player.global_position), saw_direction, tex("saw"), 3, INF, "ground", 40 * CombatVfx.PIXEL * 0.5 + 0.3, 0.05, 12.0, false)
	return true

func tick(delta: float) -> void:
	super(delta)
	block_timer = maxf(0.0, block_timer - delta)
	karma_timer = maxf(0.0, karma_timer - delta)
	if saw_timer <= 0.0: return
	saw_timer = maxf(0.0, saw_timer - delta)
	_saw_clock += delta
	while _saw_clock >= SAW_TICK:
		_saw_clock -= SAW_TICK
		_saw_cut()
	if saw_timer <= 0.0: _end_saw()

func _saw_cut() -> void:
	var scale := value("saw") if rank("saw") > 0 else 0.6
	for enemy in enemies_near(player.global_position, SAW_RADIUS, saw_direction, SAW_HALF_ANGLE):
		skill_hit(enemy, skill_power() * scale, "phys")
		if is_instance_valid(enemy) and is_instance_valid(game()):
			CombatVfx.painted(game(), enemy.global_position, Vector3.FORWARD, tex("saw_spark"), 2, 0.12, "billboard", 0.0, 0.5)
	if is_instance_valid(game()): game().sound.play("hit")

func _end_saw() -> void:
	saw_timer = 0.0
	if is_instance_valid(_saw_art): _saw_art.queue_free()
	_saw_art = null
	if is_instance_valid(player._sprite) and player._sprite.action_name == "saw": player._sprite.cancel_action()
	player.swing_remaining = 0.0
	player.stats_changed.emit()

## 战术装甲: the blow never lands.
func before_hit(kind: String, _attacker: Enemy) -> bool:
	if kind == "true": return false
	var chance := value("armour") if rank("armour") > 0 else BLOCK_CHANCE
	var roll := block_roll if block_roll >= 0.0 else randf()
	if roll >= chance: return false
	block_timer = BLOCK_SECONDS
	if saw_timer <= 0.0: play("block", -player.global_basis.z)
	if is_instance_valid(game()):
		CombatVfx.painted(game(), player.global_position, Vector3.FORWARD, tex("block"), 2, 0.2, "billboard", 0.0, 0.2)
		DamageNumber.spawn(game(), player.global_position, "抵挡", "shield")
	return true

## Planted, the shield takes most of what comes from the front.
func mitigate(amount: float, _kind: String, attacker: Enemy) -> float:
	if saw_timer <= 0.0 or not alive(attacker): return amount
	var to := attacker.global_position - player.global_position
	to.y = 0
	if to.length_squared() > 0.0001 and saw_direction.dot(to.normalized()) > 0.2:
		amount *= 1.0 - (value("saw_front") if rank("saw_front") > 0 else SAW_FRONT)
	return amount

## 荆棘: what strikes her is struck back.
func on_hurt(_amount: float, attacker: Enemy) -> void:
	if transmuter("saw") == "saw_thorns" and alive(attacker):
		attacker.take_hit(player.attack_power(), "phys")

## 业火: once a segment, for a few seconds after life runs out she does not fall.
func survive_lethal() -> bool:
	if transmuter("saw") != "saw_karma": return false
	if karma_timer <= 0.0:
		if karma_used: return false
		karma_used = true
		karma_timer = KARMA_SECONDS
	player.hp = 1.0
	player.stats_changed.emit()
	return true

func reset_segment() -> void:
	karma_used = false

func interrupt() -> void:
	if saw_timer > 0.0: _end_saw()

func reset() -> void:
	super()
	block_timer = 0.0
	karma_timer = 0.0
	karma_used = false
