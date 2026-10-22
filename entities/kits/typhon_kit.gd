class_name TyphonKit
extends OperatorKit
## 提丰 · 攻城手 · 远程武器 (干员寻访策划案 §4.7, §9 第 6 条: 远程武器).
## - Basic: one heavy arrow, slow. Shots in a row on the same target ignore
##   more and more of its defence (锐如兽牙); 8 s without shooting clears it.
## - 重如沼泥: her first arrow on each enemy hits hard and mires it.
## - Space 永恒狩猎: mark the enemy at the cursor; her next attacks become
##   arrow rain falling on it, each round stunning it briefly.

const REACH := 7.5  # 用户 2026-10-20: 远程数值和攻击范围小一点
const INTERVAL := 1.4
## 用户 2026-10-20: 射程很值钱 — about 65% of a blade's damage a second
## before 重如沼泥 and 锐如兽牙.
const ARROW_SCALE := 1.0
const MIRE_BONUS := 0.4
const MIRE_SLOW := 0.8
const MIRE_SECONDS := 3.0
## 锐如兽牙 before 精英 1: a little of it, so the passive is there at once.
const FANG_PER := 0.05
const FANG_CAP := 0.25
const FANG_RESET := 8.0
const STEADY_MAX := 5
const HUNT_ROUNDS := 5
const HUNT_ARROWS := 3
const HUNT_STUN := 0.4
const HUNT_DROP := 0.3
const HUNT_WIDE := 2.5
const TWIN_SCALE := 0.6
const PICK_RADIUS := 2.5

var hunt_target: Enemy
var hunt_left := 0
var fang_target: Enemy
var fang_stacks := 0
var since_shot := 0.0
var _mired := {}
var _mark_art: CombatVfx
var _drops: Array[Dictionary] = []

func _init(p: Player) -> void:
	super(p, "typhon")

func ranged() -> bool: return true
func reach() -> float: return REACH + value("long_shot")
func interval_factor() -> float: return INTERVAL

func cooldown_total() -> float:
	return value("hunt", 1) if rank("hunt") > 0 else 14.0

func status_text() -> String:
	return "永恒狩猎 %d" % hunt_left if hunt_left > 0 else ""

func fang_per() -> float:
	return maxf(FANG_PER, talent(0))

func fang_cap() -> float:
	return maxf(FANG_CAP, talent(1)) + (0.3 if transmuter("hunt") == "hunt_fang" else 0.0)

func swing(direction: Vector3, target: Enemy, stage: int, lands: bool, multiplier: float, crit: bool, crit_factor: float) -> void:
	since_shot = 0.0
	if hunt_left > 0 and alive(hunt_target):
		play("hunt", direction, 0.0, player.animation_rate())
		_rain_round()
		return
	play("attack_" + str(stage + 1), direction, 0.0, player.animation_rate())
	if not lands or not is_instance_valid(game()): return
	if is_instance_valid(game()): game().sound.play("hit")
	# 锐如兽牙: the same target again sharpens the next arrow.
	if target == fang_target: fang_stacks += 1
	else:
		fang_target = target
		fang_stacks = 1
	var first := not _mired.has(target.get_instance_id())
	var factor := multiplier * crit_factor * player.form_factor(1)
	_shoot(target, factor, crit, first)
	if transmuter("hunt") == "hunt_twin":
		for other in enemies_near(player.global_position, reach()):
			if other != target:
				_shoot(other, factor * TWIN_SCALE, crit, not _mired.has(other.get_instance_id()), false)
				break

func _shoot(target: Enemy, factor: float, crit: bool, first: bool, main: bool = true) -> void:
	var stacks := fang_stacks if main else 1
	var from := player.global_position
	var arrow := tex("arrow_heavy") if first else tex("arrow")
	var hit := func(enemy: Enemy, _shot: OperatorShot) -> void:
		if not alive(enemy): return
		var mire := first and not _mired.has(enemy.get_instance_id())
		var steady := 1.0 + value("steady") * mini(STEADY_MAX, stacks)
		var raw := player.attack_power() * ARROW_SCALE * factor * steady * player.target_multiplier(enemy)
		if mire: raw *= 1.0 + (value("mire") if rank("mire") > 0 else MIRE_BONUS)
		var pierce := clampf(player.physical_pierce() + minf(fang_cap(), fang_per() * stacks), 0.0, 1.0)
		basic_hit(enemy, raw, "phys", crit, pierce, "spark")
		if mire and alive(enemy):
			_mired[enemy.get_instance_id()] = true
			enemy.apply_status("slow", MIRE_SECONDS, MIRE_SLOW)
			fx_on(enemy, "mire", 2, MIRE_SECONDS, "ground", 0.05, 4.0)
		if main and alive(enemy) and is_instance_valid(game()):
			CombatVfx.painted(game(), enemy.global_position, Vector3.FORWARD, frame_of("pierce", 5, mini(5, stacks) - 1), 1, 0.4, "billboard", 0.0, 1.1)
	OperatorShot.fire(game(), from, target.global_position - from, reach() + 2.0, arrow, hit, target)

## One round of 永恒狩猎: arrows fall on the mark (and round it, 箭雨扩大).
func _rain_round() -> void:
	hunt_left -= 1
	if is_instance_valid(game()): game().sound.play("hit")
	for i in range(HUNT_ARROWS):
		var spot := hunt_target.global_position + Vector3(randf_range(-0.4, 0.4), 0, randf_range(-0.4, 0.4))
		if is_instance_valid(game()):
			CombatVfx.painted(game(), spot + Vector3.UP * 1.2, Vector3.FORWARD, tex("rain_arrow"), 1, HUNT_DROP, "billboard", 0.0, 0.0)
		_drops.append({"at": HUNT_DROP + 0.05 * i, "spot": spot, "stun": i == 0})
	if hunt_left <= 0: _end_hunt(false)

func _land_drop(drop: Dictionary) -> void:
	if not alive(hunt_target) and transmuter("hunt") != "hunt_wide": return
	var scale := value("hunt") if rank("hunt") > 0 else 0.6
	var struck: Array[Enemy] = []
	if alive(hunt_target): struck.append(hunt_target)
	if transmuter("hunt") == "hunt_wide":
		var centre: Vector3 = hunt_target.global_position if alive(hunt_target) else drop.spot
		for enemy in enemies_near(centre, HUNT_WIDE, Vector3.ZERO, 180.0, false):
			if not enemy in struck: struck.append(enemy)
	for enemy in struck:
		skill_hit(enemy, skill_power() * scale, "phys", randf() < player.crit_rate())
		if drop.stun and alive(enemy): enemy.stun(value("hunt_stun") if rank("hunt_stun") > 0 else HUNT_STUN)
	fx(foot(drop.spot), Vector3.FORWARD, "rain_hit", 3, 0.2, "ground", 0.0, 0.05)

func cast(point: Vector3) -> bool:
	var target := enemy_at(point, PICK_RADIUS, reach())
	if target == null: return false
	hunt_target = target
	hunt_left = HUNT_ROUNDS + int(value("hunt_count"))
	face(target.global_position - player.global_position)
	play("hunt", target.global_position - player.global_position)
	begin_cast(cooldown_total(), target)
	player.lock_target(target)
	if is_instance_valid(_mark_art): _mark_art.queue_free()
	_mark_art = fx_on(target, "mark", 2, INF, "ground", 0.06, 3.0)
	return true

func _end_hunt(clear_drops: bool) -> void:
	hunt_left = 0
	if clear_drops: _drops.clear()
	if is_instance_valid(_mark_art): _mark_art.queue_free()
	_mark_art = null
	player.stats_changed.emit()

func tick(delta: float) -> void:
	super(delta)
	since_shot += delta
	if since_shot >= FANG_RESET:
		fang_stacks = 0
		fang_target = null
	if hunt_left > 0 and not alive(hunt_target): _end_hunt(false)
	for i in range(_drops.size() - 1, -1, -1):
		_drops[i].at -= delta
		if _drops[i].at > 0.0: continue
		var drop: Dictionary = _drops[i]
		_drops.remove_at(i)
		_land_drop(drop)
	if hunt_left <= 0 and _drops.is_empty(): hunt_target = null

func reset() -> void:
	super()
	_end_hunt(true)
	hunt_target = null
	fang_stacks = 0
	fang_target = null
	_mired.clear()

func reset_segment() -> void:
	_mired.clear()
