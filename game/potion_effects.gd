class_name PotionEffects
extends RefCounted

## What the 特供 and regional flasks do once drunk (药剂与商人界面策划案 §2–§3),
## read from BaseCatalog.POTIONS[type].fx. Timed stat changes go through the
## player's hexes ("potion_<type>"; positive shares are buffs), the side effect
## follows the main one (Tarkov-style: it starts when the boost ends). The rest
## are timers the game asks about: cold and threat at half rate, kills without
## 血债, a shorter sight for enemies, a slow heal, and the 强心针 that is never
## drunk — it fires by itself on a killing blow, once a contract.

const EMERGENCY_HEAL := 0.25
const EMERGENCY_REGEN_LOCK := 30.0

var game: GameManager
var cold_half := 0.0
var debt_block := 0.0
var quiet := 0.0
var shield_left := 0.0
var shield_amount := 0.0
var regen_share := 0.0
var regen_left := 0.0
var regen_lock := 0.0
var emergency_used := false
## Side effects waiting for their boost to end: [seconds to wait, hex id, values, seconds].
var _pending: Array = []

func reset() -> void:
	cold_half = 0.0
	debt_block = 0.0
	quiet = 0.0
	shield_left = 0.0
	shield_amount = 0.0
	regen_share = 0.0
	regen_left = 0.0
	regen_lock = 0.0
	emergency_used = false
	_pending.clear()
	if is_instance_valid(game) and is_instance_valid(game.player):
		for id in game.player.hexes.keys():
			if str(id).begins_with("potion_"): game.player.hexes.erase(id)

## True when the flask is one this applies (it has an fx and is not drunk by hand).
static func handles(type: String) -> bool:
	return BaseCatalog.POTIONS.has(type) and BaseCatalog.POTIONS[type].has("fx")

static func drinkable(type: String) -> bool:
	return not (handles(type) and BaseCatalog.POTIONS[type].fx.get("auto", false))

## Drinks one: applies everything in its fx and returns the line to show.
func apply(type: String) -> String:
	var p: Dictionary = BaseCatalog.POTIONS[type]
	var fx: Dictionary = p.fx
	var player := game.player
	if fx.has("hex"):
		var id := "potion_" + type
		player.add_hex(id, fx.hex, float(fx.secs))
		_pending = _pending.filter(func(e): return e[1] != id + "_after")
		if fx.has("after"): _pending.append([float(fx.secs), id + "_after", fx.after, float(fx.after_secs)])
	if fx.has("cold"): game.features.reduce("cold", float(fx.cold))
	if fx.has("cold_half"): cold_half = maxf(cold_half, float(fx.cold_half))
	if fx.has("debt"): game.features.reduce("debt", float(fx.debt))
	if fx.has("debt_block"): debt_block = maxf(debt_block, float(fx.debt_block))
	if fx.has("contamination"): game.run_contamination = maxf(0.0, game.run_contamination - float(fx.contamination))
	if fx.has("quiet"): quiet = maxf(quiet, float(fx.quiet))
	if fx.has("shield"):
		_drop_shield()
		shield_amount = player.max_hp * float(fx.shield)
		player.shield += shield_amount
		shield_left = float(fx.shield_secs)
	if fx.has("cleanse"): _cleanse(float(fx.cleanse))
	if fx.has("charge"):
		if player.is_amiya(): player.shadow_cooldown *= 0.5
		else: player.add_charge(int(fx.charge))
	if fx.has("hp_cost"): player.hp = maxf(1.0, player.hp * (1.0 - float(fx.hp_cost)))
	if fx.has("regen_share"):
		regen_share = float(fx.regen_share)
		regen_left = float(fx.regen_secs)
	player.stats_changed.emit()
	return "%s：%s" % [str(p.name), str(p.text)]

func tick(delta: float) -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.player): return
	var player := game.player
	cold_half = maxf(0.0, cold_half - delta)
	debt_block = maxf(0.0, debt_block - delta)
	quiet = maxf(0.0, quiet - delta)
	if shield_left > 0.0:
		shield_left -= delta
		if shield_left <= 0.0: _drop_shield()
	if regen_left > 0.0:
		regen_left -= delta
		player.heal(player.max_hp * regen_share * delta, false, false)
	if regen_lock > 0.0:
		regen_lock -= delta
		if regen_lock <= 0.0: player.regen_blocked = false
	for entry in _pending:
		entry[0] = float(entry[0]) - delta
		if float(entry[0]) <= 0.0: player.add_hex(str(entry[1]), entry[2], float(entry[3]))
	_pending = _pending.filter(func(e): return float(e[0]) > 0.0)

func cold_mult() -> float:
	return 0.5 if cold_half > 0.0 else 1.0

func threat_mult() -> float:
	return 0.5 if quiet > 0.0 else 1.0

func sight_mult() -> float:
	return 0.7 if quiet > 0.0 else 1.0

## 应急强心针: a killing blow with one in the pack (or safe bag) leaves her at 1
## life plus a quarter of her maximum, uses it up, and stops self-regeneration
## for 30 seconds. Once a contract.
func emergency_save(player: Player) -> bool:
	if emergency_used or not is_instance_valid(game) or game.in_base: return false
	var shot: Item = null
	for item in game.inventory.items + game.safe_bag.items:
		if item.is_potion() and item.potion_type == "L": shot = item
	if shot == null: return false
	if shot.quantity > 1: shot.set_quantity(shot.quantity - 1)
	else:
		game.inventory.remove(shot)
		game.safe_bag.remove(shot)
	emergency_used = true
	player.hp = 1.0 + player.max_hp * EMERGENCY_HEAL
	player.regen_blocked = true
	regen_lock = EMERGENCY_REGEN_LOCK
	game.notice("应急强心针生效")
	player.stats_changed.emit()
	return true

## 广谱解毒剂: stun ends, slows come off, and new control is shrugged off for `secs`.
func _cleanse(secs: float) -> void:
	var player := game.player
	player.control_immune = maxf(player.control_immune, secs)
	if player.control_timer > 0.0: player.control_timer = 0.0
	for id in player.hexes.keys():
		if str(id).begins_with("potion_"): continue
		var entry: Dictionary = player.hexes[id]
		if float(entry.get("move", 0.0)) < 0.0 or float(entry.get("aspd", 0.0)) < 0.0: player.hexes.erase(id)

func _drop_shield() -> void:
	if shield_amount > 0.0 and is_instance_valid(game) and is_instance_valid(game.player):
		game.player.shield = maxf(0.0, game.player.shield - shield_amount)
	shield_amount = 0.0
	shield_left = 0.0
