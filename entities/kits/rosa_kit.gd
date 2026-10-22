class_name RosaKit
extends OperatorKit
## 早露 · 攻城手 · 远程武器 (干员寻访策划案 §4.2, §9 第 6 条).
## - Basic: bolts from her siege launcher; the third of a combo is the charged
##   bolt, which goes through everyone on its line.
## - 深入骨髓 (越重越疼): against elites, bosses and heavily armoured enemies her
##   bolts ignore part of their defence and hit harder.
## - Space 雪崩击: a fan of harpoons toward the cursor; each pins the first
##   enemy it meets, which then takes damage every second while held.

const REACH := 7.0  # 用户 2026-10-20: 远程数值和攻击范围小一点
const INTERVAL := 1.25
## 用户 2026-10-20: 射程很值钱，远程的倍率要比近战低 (about 70% of a blade's
## damage a second; 拉普兰德 is 1.0 / 1.0 / 1.3 every 0.7 s).
const COMBO := [0.8, 0.8, 1.3]
## 深入骨髓 before 精英 1.
const HEAVY_IGNORE := 0.2
const HEAVY_BONUS := 0.2
const HARPOONS := 4
const FAN := 40.0
const PIN_SECONDS := 4.0
const PIN_DOT := 0.3
const SPLIT_SCALE := 0.4
## 分裂射击 only jumps to an enemy standing close by: at most half a body's
## width (0.45) between their edges, about 1.35 centre to centre; anyone
## further is left alone (用户 2026-10-20: 连锁攻击设定固定范围，差不多半个身位).
const SPLIT_REACH := 1.35
const PULL := 2.0
const BURST_SCALE := 1.5
const BURST_RADIUS := 2.0
## The charged bolt winds up this long before it flies, a glow gathering at
## the launcher (用户 2026-10-20: 重箭发射前蓄力不明显), and is drawn larger.
const CHARGE_TIME := 0.35
const CHARGED_ART := 2.2

var pins: Array[Dictionary] = []

func _init(p: Player) -> void:
	super(p, "rosa")

func ranged() -> bool: return true
func reach() -> float: return REACH
func interval_factor() -> float: return INTERVAL

func cooldown_total() -> float:
	return value("avalanche", 1) if rank("avalanche") > 0 else 12.0

## Heavy armour is a tag on the enemy's profile now (复利数值改造清单 E,
## 用户 2026-10-20), not a DEF figure, which grows with the floor.
func heavy(enemy: Enemy) -> bool:
	return enemy.elite or enemy.boss or bool(enemy.attack_profile.get("heavy", false))

func swing(direction: Vector3, target: Enemy, stage: int, lands: bool, multiplier: float, crit: bool, crit_factor: float) -> void:
	var charged := stage == 2
	play("attack_3" if charged else "attack_1", direction, 0.0, player.animation_rate())
	if not lands or not is_instance_valid(game()): return
	var scale := float(COMBO[stage]) * (1.0 + value("siege_bolt") if charged else 1.0)
	var factor := multiplier * crit_factor * player.form_factor(1)
	if not charged:
		_release(direction, target, scale * factor, crit, false)
		return
	var aim := target.global_position - player.global_position
	var glow := _charge_glow(aim)
	await game().get_tree().create_timer(CHARGE_TIME, false).timeout
	if is_instance_valid(glow): glow.queue_free()
	if not is_instance_valid(player) or player.kit != self or player.hp <= 0.0 or not is_instance_valid(game()): return
	_release(aim, target if alive(target) else null, scale * factor, crit, true)

## The wind-up on her: an ice-white glow swelling at the launcher's mouth and
## a ring on the ground closing in on her feet.
func _charge_glow(aim: Vector3) -> Node3D:
	var holder := Node3D.new()
	player.add_child(holder)
	var flat := Vector3(aim.x, 0, aim.z)
	flat = flat.normalized() if flat.length_squared() > 0.0001 else -player.global_basis.z
	var orb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.44
	orb.mesh = sphere
	orb.material_override = CombatVfx.material(Color("e8f6ff"), 0.95)
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(orb)
	orb.global_position = player.global_position + flat * 0.6 + Vector3(0, 0.75, 0)
	orb.scale = Vector3.ONE * 0.2
	var halo := MeshInstance3D.new()
	var outer := SphereMesh.new()
	outer.radius = 0.45
	outer.height = 0.9
	halo.mesh = outer
	halo.material_override = CombatVfx.material(Color("8fd3ff"), 0.4)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	orb.add_child(halo)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	ring.mesh = torus
	ring.material_override = CombatVfx.material(Color("bfe6ff"), 0.7)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(ring)
	ring.global_position = foot(player.global_position) + Vector3(0, 0.03, 0)
	ring.scale = Vector3(1.8, 1.0, 1.8)
	var tween := holder.create_tween().set_parallel(true)
	tween.tween_property(orb, "scale", Vector3.ONE * 1.3, CHARGE_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(ring, "scale", Vector3(0.35, 1.0, 0.35), CHARGE_TIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	return holder

func _release(direction: Vector3, target: Enemy, scale: float, crit: bool, charged: bool) -> void:
	game().sound.play("hit")
	var from := player.global_position
	var aim := target.global_position - from if is_instance_valid(target) and not charged else direction
	fx(foot(from), aim, "muzzle", 2, 0.18 if charged else 0.12, "ground", 0.9, 0.3)
	var hit := func(enemy: Enemy, shot: OperatorShot) -> void: _bolt_hit(enemy, scale, crit, shot.direction, true)
	var shot := OperatorShot.new()
	shot.art_scale = CHARGED_ART if charged else 1.0
	shot.game = game()
	shot.direction = Vector3(aim.x, 0, aim.z).normalized() if Vector2(aim.x, aim.z).length_squared() > 0.0001 else -player.global_basis.z
	shot.reach = REACH + 2.0
	shot.texture = tex("bolt_charged") if charged else tex("bolt")
	shot.on_hit = hit
	shot.target = null if charged else target
	shot.pierce = charged
	game().add_child(shot)
	shot.global_position = from

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
		for other in enemies_near(from, SPLIT_REACH):
			if other == enemy: continue
			var hit := func(e: Enemy, shot: OperatorShot) -> void: _bolt_hit(e, scale * SPLIT_SCALE, false, shot.direction, false)
			var split := OperatorShot.fire(game(), from, other.global_position - from, SPLIT_REACH + 1.0, tex("bolt"), hit, other)
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
