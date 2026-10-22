class_name SantallaKit
extends OperatorKit
## 寒檀 · 扩散术师 · 源石技艺 (干员寻访策划案 §4.8).
## - Basic: three ice orbs; the third is large and splashes, chilling.
## - 生于冰寒: after a while in a fight her attack rises; stuns on her last
##   half as long (精英 2's 抗控扩展 halves knockback and pulls too).
## - Space 女巫之泪: for a while icicles keep falling near the cursor, each
##   hurting and chilling whoever it lands on. She can fight on meanwhile.

const REACH := 6.5  # 用户 2026-10-20: 远程数值和攻击范围小一点
const COMBO := [0.75, 0.75, 1.0]  # 用户 2026-10-20: 远程数值和攻击范围小一点
const SPLASH := 0.5
const SPLASH_RADIUS := 1.8
const CHILL := 0.2
const CHILL_SECONDS := 1.0
const COLD_SECONDS := 8.0
const COLD_ATK := 0.12
const STUN_SHARE := 0.5
const TEARS_SECONDS := 10.0
const TEARS_GAP := 0.35
const TEARS_SCATTER := 2.5
const TEARS_RADIUS := 1.2
const TEARS_DROP := 0.25
const TEARS_SEEK := 3.5
const FREEZE_CHILLS := 3
const FREEZE_WINDOW := 3.0
const FREEZE_SECONDS := 1.5

var engaged := 0.0
var tears_timer := 0.0
var tears_aim := Vector3.ZERO
## Off in tests: the aim then stays where the skill was cast.
var follow_pointer := true
var _tears_clock := 0.0
var _drops: Array[Dictionary] = []
var _chills := {}
var _aura: CombatVfx

func _init(p: Player) -> void:
	super(p, "santalla")

func ranged() -> bool: return true
func reach() -> float: return REACH
func cooldown_total() -> float: return 20.0

func cold() -> bool: return engaged >= COLD_SECONDS

func atk_pct() -> float:
	return (value("cold_power") if rank("cold_power") > 0 else COLD_ATK) if cold() else 0.0

func res_bonus() -> float:
	return talent(1) + value("frost_ward")

func control_factor(kind: String) -> float:
	if kind == "stun": return 1.0 - maxf(STUN_SHARE, talent(0))
	return 0.5 if transmuter("tears") == "tears_ward" else 1.0

func status_text() -> String:
	return "女巫之泪 %.1f" % tears_timer if tears_timer > 0.0 else ""

func swing(direction: Vector3, target: Enemy, stage: int, lands: bool, multiplier: float, crit: bool, crit_factor: float) -> void:
	play("attack_" + str(stage + 1), direction, 0.0, player.animation_rate())
	if not lands or not is_instance_valid(game()): return
	game().sound.play("hit")
	var big := stage == 2
	var raw_scale := float(COMBO[stage]) * multiplier * crit_factor * player.form_factor(1)
	var hit := func(enemy: Enemy, _shot: OperatorShot) -> void:
		if not alive(enemy): return
		var centre := enemy.global_position
		basic_hit(enemy, player.arts_power() * raw_scale * player.target_multiplier(enemy), "arts", crit, 0.0, "spark")
		chill(enemy)
		if not big: return
		fx(foot(centre), Vector3.FORWARD, "splash", 2, 0.2, "ground", 0.0, 0.05)
		var splash := value("orb") if rank("orb") > 0 else SPLASH
		for other in enemies_near(centre, SPLASH_RADIUS, Vector3.ZERO, 180.0, false):
			if other == enemy: continue
			player.land_hit(other, player.arts_power() * raw_scale * splash * player.target_multiplier(other), "arts", false)
			chill(other)
	var from := player.global_position
	var shot := OperatorShot.fire(game(), from, target.global_position - from, REACH + 2.0, tex("orb_big") if big else tex("orb"), hit, target)
	shot.frames = 2
	shot.speed = 16.0

## 寒冷: slowed for a moment; with 冻结, the third chill in a short while freezes.
func chill(enemy: Enemy) -> void:
	if not alive(enemy): return
	enemy.apply_status("slow", CHILL_SECONDS, value("chill") if rank("chill") > 0 else CHILL)
	if is_instance_valid(game()): CombatVfx.painted(game(), enemy.global_position, Vector3.FORWARD, tex("chill"), 2, 0.4, "billboard", 0.0, 0.9)
	if transmuter("tears") != "tears_freeze": return
	var key := enemy.get_instance_id()
	var times: Array = _chills.get(key, [])
	times = times.filter(func(t): return engaged_clock - float(t) <= FREEZE_WINDOW)
	times.append(engaged_clock)
	if times.size() >= FREEZE_CHILLS:
		enemy.stun(FREEZE_SECONDS)
		times.clear()
	_chills[key] = times

var engaged_clock := 0.0

func cast(point: Vector3) -> bool:
	tears_timer = value("tears", 1) if rank("tears") > 0 else TEARS_SECONDS
	tears_aim = point
	_tears_clock = 0.0
	play("tears", point - player.global_position, 0.5)
	begin_cast(cooldown_total(), point - player.global_position)
	return true

func tick(delta: float) -> void:
	super(delta)
	engaged_clock += delta
	engaged = engaged + delta if player.combat_timer < Player.OUT_OF_COMBAT else 0.0
	if cold() and not is_instance_valid(_aura): _aura = fx_on_her("aura", 2, INF, "ground", 0.05, 2.0)
	elif not cold() and is_instance_valid(_aura):
		_aura.queue_free()
		_aura = null
	if tears_timer > 0.0:
		tears_timer = maxf(0.0, tears_timer - delta)
		if follow_pointer and is_instance_valid(game()) and game().is_inside_tree(): tears_aim = game()._skill_aim()
		_tears_clock += delta
		var gap := maxf(0.1, TEARS_GAP - value("tears_rate"))
		while _tears_clock >= gap:
			_tears_clock -= gap
			_drop_icicle()
	for i in range(_drops.size() - 1, -1, -1):
		_drops[i].at -= delta
		if _drops[i].at > 0.0: continue
		var drop: Dictionary = _drops[i]
		_drops.remove_at(i)
		_land(drop.spot)

func _drop_icicle() -> void:
	var spot := tears_aim + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(0.0, TEARS_SCATTER)
	if transmuter("tears") == "tears_seek":
		var near := enemies_near(tears_aim, TEARS_SEEK, Vector3.ZERO, 180.0, false)
		if not near.is_empty(): spot = near[0].global_position
	spot.y = tears_aim.y
	if is_instance_valid(game()):
		CombatVfx.painted(game(), spot + Vector3.UP * 1.4, Vector3.FORWARD, frame_of("icicle", 3, randi() % 3), 1, TEARS_DROP, "billboard", 0.0, 0.0)
	_drops.append({"at": TEARS_DROP, "spot": spot})

func _land(spot: Vector3) -> void:
	fx(foot(spot), Vector3.FORWARD, "icicle_hit", 3, 0.24, "ground", 0.0, 0.05)
	var scale := value("tears") if rank("tears") > 0 else 0.6
	for enemy in enemies_near(spot, TEARS_RADIUS, Vector3.ZERO, 180.0, false):
		skill_hit(enemy, skill_power("arts") * scale, "arts")
		chill(enemy)

func reset() -> void:
	super()
	tears_timer = 0.0
	engaged = 0.0
	_drops.clear()
	_chills.clear()
	if is_instance_valid(_aura): _aura.queue_free()
	_aura = null
