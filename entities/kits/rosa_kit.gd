class_name RosaKit
extends OperatorKit
## 早露 · 攻城手 · 远程武器 (干员寻访策划案 §4.2, §9 第 6 条).
## - Basic: bolts from her siege launcher; the third of a combo is the charged
##   bolt, which goes through everyone on its line.
## - 深入骨髓 (越重越疼): against elites, bosses and heavily armoured enemies her
##   bolts ignore part of their defence and hit harder.
## - Space 雪崩击: a fan of harpoons toward the cursor; each pins the first
##   enemy it meets, which then takes damage every second while held.

const REACH := 9.0
const INTERVAL := 1.25
const COMBO := [1.4, 1.4, 2.2]
## Defence at or above this counts as heavy armour (重量 ≥3 in PRTS).
const HEAVY_DEF := 400.0
## 深入骨髓 before 精英 1.
const HEAVY_IGNORE := 0.2
const HEAVY_BONUS := 0.2
const HARPOONS := 4
const FAN := 40.0
const PIN_SECONDS := 4.0
const PIN_DOT := 0.3
const SPLIT_SCALE := 0.4
const PULL := 2.0
const BURST_SCALE := 1.5
const BURST_RADIUS := 2.0

var pins: Array[Dictionary] = []

func _init(p: Player) -> void:
	super(p, "rosa")

func ranged() -> bool: return true
func reach() -> float: return REACH
func interval_factor() -> float: return INTERVAL

func cooldown_total() -> float:
	return value("avalanche", 1) if rank("avalanche") > 0 else 12.0

func heavy(enemy: Enemy) -> bool:
	return enemy.elite or enemy.boss or enemy.defense >= HEAVY_DEF

func swing(direction: Vector3, target: Enemy, stage: int, lands: bool, multiplier: float, crit: bool, crit_factor: float) -> void:
	var charged := stage == 2
	play("attack_3" if charged else "attack_1", direction, 0.0, player.animation_rate())
	if not lands or not is_instance_valid(game()): return
	game().sound.play("hit")
	var from := player.global_position
	fx(foot(from), direction, "muzzle", 2, 0.12, "ground", 0.9, 0.3)
	var scale := float(COMBO[stage]) * (1.0 + value("siege_bolt") if charged else 1.0)
	var factor := multiplier * crit_factor * player.form_factor(1)
	var hit := func(enemy: Enemy, shot: OperatorShot) -> void: _bolt_hit(enemy, scale * factor, crit, shot.direction, true)
	var shot := OperatorShot.fire(game(), from, target.global_position - from, REACH + 2.0, tex("bolt_charged") if charged else tex("bolt"), hit, null if charged else target)
	shot.pierce = charged

## A bolt landing: 深入骨髓 on the heavy ones, 重矢's slow, 分裂射击.
func _bolt_hit(enemy: Enemy, scale: float, crit: bool, direction: Vector3, can_split: bool) -> void:
	if not alive(enemy): return
	var raw := player.attack_power() * scale * player.target_multiplier(enemy)
	var pierce := player.physical_pierce()
	if heavy(enemy):
		pierce += maxf(HEAVY_IGNORE, talent(0))
		raw *= 1.0 + maxf(HEAVY_BONUS, talent(1))
		if is_instance_valid(game()): CombatVfx.painted(game(), enemy.global_position, Vector3.FORWARD, tex("armorbreak"), 2, 0.2, "billboard", 0.0, 0.7)
	basic_hit(enemy, raw, "phys", crit, clampf(pierce, 0.0, 1.0), "spark", direction)
	if rank("bolt_slow") > 0 and alive(enemy): enemy.apply_status("slow", 1.5, value("bolt_slow"))
	if can_split and transmuter("avalanche") == "rosa_split" and is_instance_valid(enemy) and is_instance_valid(game()):
		var from := enemy.global_position
		var count := 0
		for other in enemies_near(from, 5.0):
			if other == enemy: continue
			var hit := func(e: Enemy, shot: OperatorShot) -> void: _bolt_hit(e, scale * SPLIT_SCALE, false, shot.direction, false)
			var split := OperatorShot.fire(game(), from, other.global_position - from, 6.0, tex("bolt"), hit, other)
			split.hit_ids[enemy.get_instance_id()] = true
			count += 1
			if count >= 2: break

func cast(point: Vector3) -> bool:
	var aim := Vector3(point.x - player.global_position.x, 0, point.z - player.global_position.z)
	if aim.length_squared() < 0.01: aim = -player.global_basis.z
	aim = aim.normalized()
	face(aim)
	play("volley", aim, 0.5)
	begin_cast(cooldown_total(), aim)
	var count := HARPOONS + int(value("harpoon_more"))
	var scale := value("avalanche") if rank("avalanche") > 0 else 1.0
	for i in range(count):
		var turn := deg_to_rad(-FAN * 0.5 + FAN * i / maxf(1.0, count - 1.0))
		var hit := func(enemy: Enemy, _shot: OperatorShot) -> void: _harpoon_hit(enemy, scale)
		OperatorShot.fire(game(), player.global_position, aim.rotated(Vector3.UP, turn), REACH + 1.0, tex("harpoon"), hit)
	return true

func _harpoon_hit(enemy: Enemy, scale: float) -> void:
	if not alive(enemy): return
	skill_hit(enemy, skill_power() * scale, "phys", randf() < player.crit_rate())
	if not alive(enemy): return
	if transmuter("avalanche") == "rosa_pull":
		var back := player.global_position - enemy.global_position
		back.y = 0
		if back.length() > 1.2: enemy.push(back.normalized(), minf(PULL, back.length() - 1.0))
	var seconds := PIN_SECONDS + value("pin_time")
	enemy.apply_status("slow", seconds, 1.0)
	for pin in pins:
		if pin.enemy == enemy:
			pin.left = seconds
			return
	pins.append({"enemy": enemy, "left": seconds, "tick": 1.0, "art": fx_on(enemy, "pinned", 2, INF, "ground", 0.06, 6.0)})

func tick(delta: float) -> void:
	super(delta)
	for i in range(pins.size() - 1, -1, -1):
		var pin: Dictionary = pins[i]
		pin.left -= delta
		pin.tick -= delta
		var enemy = pin.enemy
		if alive(enemy) and pin.tick <= 0.0 and pin.left > -0.001:
			pin.tick += 1.0
			skill_hit(enemy, player.attack_power() * (value("pin_dot") if rank("pin_dot") > 0 else PIN_DOT) * player.wave_multiplier(), "phys")
		if pin.left > 0.0 and alive(enemy): continue
		pins.remove_at(i)
		if is_instance_valid(pin.art): pin.art.queue_free()
		if transmuter("avalanche") == "rosa_burst" and is_instance_valid(enemy):
			var centre: Vector3 = enemy.global_position
			fx(foot(centre), Vector3.FORWARD, "pinned", 2, 0.25, "ground", 0.0, 0.06)
			for other in enemies_near(centre, BURST_RADIUS, Vector3.ZERO, 180.0, false):
				skill_hit(other, skill_power() * BURST_SCALE, "phys")

func reset() -> void:
	super()
	for pin in pins:
		if is_instance_valid(pin.art): pin.art.queue_free()
	pins.clear()
