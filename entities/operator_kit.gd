class_name OperatorKit
extends RefCounted
## How a recruit fights (干员寻访策划案 §4, §9, R2): her basic combo, her Space
## skill on a cooldown, her signature passive and her three 精英 2 transmuters.
## Lappland and Amiya keep their own code in Player; every recruit is one of
## these, made by make() when she is chosen. Player asks the kit at fixed
## points (swing, cast, tick, incoming damage, stat bonuses), so the answers
## below are the neutral ones and each kit overrides what it changes.

var player: Player
var id := ""
## Seconds until Space works again.
var cooldown := 0.0
## Damage multiplier the current skill took at cast (attack, signature gear).
var skill_mult := 1.0

static var _textures := {}

static func make(operator_id: String, p: Player) -> OperatorKit:
	match operator_id:
		"hellagur": return HellagurKit.new(p)
		"hoshiguma": return HoshigumaKit.new(p)
		"typhon": return TyphonKit.new(p)
		"rosa": return RosaKit.new(p)
		"lin": return LinKit.new(p)
		"santalla": return SantallaKit.new(p)
		"texas": return TexasKit.new(p)
	return null

func _init(p: Player, operator_id: String = "") -> void:
	player = p
	id = operator_id

# --- What she is ------------------------------------------------------------------

func ranged() -> bool: return false
## Her reach; 0 keeps the weapon's.
func reach() -> float: return 0.0
func interval_factor() -> float: return 1.0
func atk_pct() -> float: return 0.0
func def_pct() -> float: return 0.0
func res_bonus() -> float: return 0.0
func hp_pct() -> float: return 0.0
func aspd_bonus() -> float: return 0.0
func evasion_bonus() -> float: return 0.0
func move_mult() -> float: return 1.0
## Flasks and self-regeneration (赫拉格's 饮刃 halves them).
func potion_factor() -> float: return 1.0
func regen_factor() -> float: return 1.0
## Loss of control she takes, as a share of its time ("stun") or travel.
func control_factor(_kind: String) -> float: return 1.0
## True while her skill keeps her in place / stops basic attacks.
func rooted() -> bool: return false
func busy() -> bool: return false
func cooldown_total() -> float: return 10.0
func skill_ready() -> bool: return cooldown <= 0.0 and not busy()
## A short running-state line for the HUD ("" when nothing runs).
func status_text() -> String: return ""

# --- What she does ----------------------------------------------------------------

func swing(_direction: Vector3, _target: Enemy, _stage: int, _lands: bool, _multiplier: float, _crit: bool, _crit_factor: float) -> void:
	pass

func cast(_point: Vector3) -> bool: return false

func tick(delta: float) -> void:
	if cooldown > 0.0 and not busy():
		cooldown = maxf(0.0, cooldown - delta)
		if cooldown == 0.0:
			player.stats_changed.emit()
			if is_instance_valid(game()): game().sound.play("charge")

## Relic "charge" gains and similar shorten the cooldown, a second each.
func refund(seconds: float) -> void:
	if seconds <= 0.0 or cooldown <= 0.0: return
	cooldown = maxf(0.0, cooldown - seconds)
	if cooldown == 0.0 and is_instance_valid(game()): game().sound.play("charge")
	player.stats_changed.emit()

## Before mitigation: true takes the whole hit away (星熊's 战术装甲).
func before_hit(_kind: String, _attacker: Enemy) -> bool: return false
## After mitigation, before shields: what is left of the hit (林's 琉璃璧).
func mitigate(amount: float, _kind: String, _attacker: Enemy) -> float: return amount
func on_hurt(_amount: float, _attacker: Enemy) -> void: pass
func on_evade(_attacker: Enemy) -> void: pass
func survive_lethal() -> bool: return false
func on_kill(_enemy: Enemy) -> void: pass
## A dodge or loss of control: whatever she was holding stops.
func interrupt() -> void: pass
func reset_combat() -> void: interrupt()
func reset_segment() -> void: pass
func reset() -> void:
	interrupt()
	cooldown = 0.0

# --- Helpers ------------------------------------------------------------------------

func game() -> GameManager:
	return player.game

func rank(node_id: String) -> int:
	return player.rank(node_id)

func transmuter(group: String) -> String:
	return player.transmuter(group)

## A tree node's value at her rank (SkillTrees values), 0 without a rank.
func value(node_id: String, index: int = 0) -> float:
	return SkillTrees.value(id, node_id, rank(node_id), index)

## Her talent's value by elite stage and module level (SkillTrees TALENTS).
func talent(index: int = 0) -> float:
	return SkillTrees.talent_value(id, player.elite_stage(), player.module_level(), index)

func tex(name: String) -> Texture2D:
	var path := "res://godot_assets/%s_vfx_%s.png" % [id, name]
	if not _textures.has(path): _textures[path] = load(path) if ResourceLoader.exists(path) else null
	return _textures[path]

## One cell of a painted strip of `frames` cells.
func frame_of(name: String, frames: int, index: int) -> AtlasTexture:
	var sheet := tex(name)
	if sheet == null: return null
	var frame := AtlasTexture.new()
	frame.atlas = sheet
	var w := sheet.get_width() / maxi(1, frames)
	frame.region = Rect2(clampi(index, 0, frames - 1) * w, 0, w, sheet.get_height())
	return frame

## A painted effect riding on an enemy (marks, pins), freed with it.
func fx_on(enemy: Node3D, name: String, frames: int, seconds: float, mount: String = "ground", height: float = 0.05, fps: float = 6.0) -> CombatVfx:
	if not is_instance_valid(enemy) or not is_instance_valid(game()): return null
	var art := CombatVfx.painted(enemy, foot(enemy.global_position), Vector3.FORWARD, tex(name), frames, seconds, mount, 0.0, height, fps, false)
	art.game = game()
	return art

## Ground height under a point plus a hair, where flat effects lie.
func foot(point: Vector3) -> Vector3:
	if not is_instance_valid(game()): return point
	return Vector3(point.x, game().ground_y(point) + 0.09, point.z)

func fx(point: Vector3, direction: Vector3, name: String, frames: int = 1, seconds: float = 0.15, mount: String = "ground", ahead: float = 0.0, height: float = 0.05, fps: float = 0.0, fade: bool = true) -> CombatVfx:
	if not is_instance_valid(game()): return null
	return CombatVfx.painted(game(), point, direction, tex(name), frames, seconds, mount, ahead, height, fps, fade)

## The same, riding on her (rings round her feet, marks over her head).
func fx_on_her(name: String, frames: int, seconds: float, mount: String = "ground", height: float = 0.05, fps: float = 0.0, fade: bool = false) -> CombatVfx:
	if not is_instance_valid(game()): return null
	var art := CombatVfx.painted(player, player.global_position + Vector3(0, -LapplandAnimator3D.FOOT_DROP, 0), Vector3.FORWARD, tex(name), frames, seconds, mount, 0.0, height, fps, fade)
	return art

func flat(offset: Vector3) -> float:
	return Vector2(offset.x, offset.z).length()

func alive(enemy) -> bool:
	return is_instance_valid(enemy) and not enemy._dead

## Living enemies within `radius` of `centre` on her terrace, nearest first;
## with `aim`, only those inside the fan of `half_angle` degrees round it.
func enemies_near(centre: Vector3, radius: float, aim: Vector3 = Vector3.ZERO, half_angle: float = 180.0, need_sight: bool = true) -> Array[Enemy]:
	var found: Array[Enemy] = []
	if not is_instance_valid(game()): return found
	var flat_aim := Vector3(aim.x, 0, aim.z)
	var use_aim := flat_aim.length_squared() > 0.0001 and half_angle < 180.0
	if use_aim: flat_aim = flat_aim.normalized()
	var pairs: Array = []
	for node in player.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.game != game() or enemy._dead: continue
		if absf(enemy.global_position.y - centre.y) > Player.TIER_REACH: continue
		var offset := enemy.global_position - centre
		offset.y = 0
		var distance := offset.length()
		if distance > radius: continue
		if use_aim and distance > 0.05 and flat_aim.dot(offset / distance) < cos(deg_to_rad(half_angle)): continue
		if need_sight and not game().line_of_sight(centre, enemy.global_position): continue
		pairs.append([distance, enemy])
	pairs.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for pair in pairs: found.append(pair[1])
	return found

## The living enemy nearest `point` within `pick` of it and `range_limit` of
## her, in her sight. Null when there is none.
func enemy_at(point: Vector3, pick: float, range_limit: float) -> Enemy:
	var best: Enemy = null
	var best_distance := pick
	for enemy in enemies_near(player.global_position, range_limit):
		var distance := flat(enemy.global_position - point)
		if distance <= best_distance:
			best = enemy
			best_distance = distance
	return best

## A landed basic hit: damage, the melee riders, gear hit effects, execute,
## 轰鸣之手 stacks and a spark. Returns what landed.
func basic_hit(target: Enemy, raw: float, kind: String, crit: bool, pierce: float = 0.0, spark: String = "spark", direction: Vector3 = Vector3.FORWARD) -> float:
	if not alive(target): return 0.0
	var dealt := player.land_hit(target, raw, kind, crit, pierce)
	if is_instance_valid(target):
		fx(target.global_position, direction, spark, 2, 0.12, "ground", 0.0, 0.3)
	return dealt

## A skill hit: skill damage bonuses ride in `raw` already (skill_power());
## it feeds lifesteal and the on-signature-hit relics like 绝影's strikes.
func skill_hit(target: Enemy, raw: float, kind: String, crit: bool = false) -> float:
	if not alive(target): return 0.0
	raw *= player.target_multiplier(target) * (player.crit_damage() if crit else 1.0)
	var dealt := player._deal(target, raw, kind, crit, 0.0, true)
	if is_instance_valid(target): player.on_wave_hit(target, 0.0, null)
	return dealt

## ATK × skill damage × what the cast took.
func skill_power() -> float:
	return player.attack_power() * player.wave_multiplier() * skill_mult

## Common cast bookkeeping: cooldown (技能冷却 applies), the skill relics
## (噤声 build-ups, 拳经三问), signature gear, combat and the order queue.
func begin_cast(total: float, toward: Variant = null) -> void:
	cooldown = total * player.skill_cd_factor()
	skill_mult = player.attack_multiplier() * (player.gear_fx.spend_signature_bonus() if player.gear_fx != null else 1.0)
	if player.gear_fx != null:
		var target: Enemy = toward if toward is Enemy and alive(toward) else null
		var direction: Vector3 = (target.global_position - player.global_position) if target != null else (toward if toward is Vector3 else -player.global_basis.z)
		player.gear_fx.on_signature(direction, target)
	player.combat_timer = 0.0
	player.combo_step = 0
	player._on_wave_released()
	if is_instance_valid(game()): game().sound.play("hit")
	player.stats_changed.emit()

## Play one of her actions toward `direction` and stand still for it.
func play(action: String, direction: Vector3, hold: float = 0.0, rate: float = 1.0) -> void:
	var sprite := player._sprite
	if not is_instance_valid(sprite): return
	sprite.play_action(action, direction, rate)
	if hold > 0.0: sprite.hold_action(hold)
	player.swing_remaining = maxf(player.swing_remaining, sprite.action_duration)

func face(direction: Vector3) -> void:
	direction.y = 0
	if direction.length_squared() > 0.0001: player.look_at(player.global_position + direction.normalized(), Vector3.UP)
