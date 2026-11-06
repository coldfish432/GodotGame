class_name GmMedical
extends RefCounted

## GameManager's medical side (§4; 药剂与商人界面策划案): the flasks she carries,
## drinking them by hand or from the auto slot, the gel and the inhibitor,
## contamination's dose and rate, the departure's medical state, and the
## pharmacy and injury treatment at the base. The state is read by name
## through GameManager (RunSave, the HUD).

const AUTO_POTION_GAP := 0.5     # between two flasks of one run of drinking

var game: GameManager
var _slow_heal_left := 0.0       # 缓释凝胶: health still to come
var _slow_heal_rate := 0.0
var _suppress_timer := 0.0       # 抑制喷剂: contamination accrues at half rate meanwhile
var _potion_heal_factor := 1.0   # 1 − contamination's potion penalty, kept live
## The auto-potion slot (Hotbar.AUTO): on below the low threshold, off at the high one.
var _auto_drinking := false
var _auto_potion_gap := 0.0
var _announced_tier := 0

func _init(owner: GameManager) -> void:
	game = owner

func carried_potions() -> Array[Item]:
	var out: Array[Item] = []
	for container in [game.inventory, game.safe_bag]:
		for item: Item in container.items:
			if item.is_potion(): out.append(item)
	return out

## Flasks carried, counting every one in a stack; "" counts all kinds.
func potion_count(type: String = "") -> int:
	var total := 0
	for item in carried_potions():
		if type == "" or item.potion_type == type: total += item.quantity
	return total

func _set_standard_potions(count: int) -> void:
	for item in carried_potions():
		game.inventory.remove(item)
		game.safe_bag.remove(item)
	for i in range(maxi(count, 0)):
		if game.inventory.add_stack(BaseCatalog.create_potion("A")) > 0: break

## The free 标准急救剂 for this contract go into the pack (what does not fit stays
## issued for next time).
func _issue_free_potions() -> void:
	# The departure camp's tier (复利数值改造清单 E); 医疗部 5 阶 adds one.
	var bonus := int(game.research.free_potion_tier_bonus()) if game.research != null and game.research.has_method("free_potion_tier_bonus") else 0
	var tier := mini(Scaling.TIER_MAX, Scaling.tier_of(game.start_floor) + bonus)
	while game.base.free_potions > 0 and game.inventory.add_stack(BaseCatalog.create_potion("A", tier)) == 0:
		game.base.free_potions -= 1

## Of the flasks she carries of `type`, the highest tier (pack before safe bag).
func _best_potion(type: String, carried: Array[Item]) -> Item:
	var pick: Item = null
	for item in carried:
		if item.potion_type == type and (pick == null or item.grade > pick.grade): pick = item
	return pick

## The best flask to drink now (AI driver): the first kind by POTION_ORDER,
## its highest tier. At full health only the inhibitor is worth drinking (it
## also cleanses).
func _use_potion() -> void:
	var carried := carried_potions()
	if carried.is_empty(): return
	var pick: Item = null
	for type in GameManager.POTION_ORDER:
		pick = _best_potion(type, carried)
		if pick != null: break
	if game.player.full_hp() and pick.potion_type != "C":
		pick = _best_potion("C", carried)
		if pick == null: return
	drink(pick)

## A hotbar flask slot: the highest tier of `type` she carries (_best_potion).
## Nothing happens when she has none of that kind.
func use_potion_type(type: String) -> bool:
	var pick := _best_potion(type, carried_potions())
	return drink(pick) if pick != null else false

## Drinks one flask she carries (a hotbar slot, or right click in the pack).
func drink(item: Item) -> bool:
	if game.in_base or item == null or not item.is_potion() or not game.carried_items().has(item): return false
	if game.player.is_controlled(): return false
	# 应急强心针 is never drunk: it fires by itself on a killing blow.
	if not PotionEffects.drinkable(item.potion_type):
		game.notice("应急强心针放在背包里就会生效")
		return false
	if item.quantity > 1: item.set_quantity(item.quantity - 1)
	else:
		game.inventory.remove(item)
		game.safe_bag.remove(item)
	var type := item.potion_type
	# A fixed amount for its tier, no bonus of any kind (复利数值改造清单 E);
	# only an operator's own trait (赫拉格: 30%) changes it.
	if PotionEffects.handles(type):
		game.set_message(game.potion_fx.apply(type))
		game.save_base_soon(true)
		return true
	var amount := BaseCatalog.potion_heal(type) * Scaling.tier_coef(game.floor_number) * game.player.potion_heal_multiplier
	match type:
		"B":
			# A new gel replaces what was left of the last one.
			_slow_heal_left = amount
			_slow_heal_rate = amount / BaseCatalog.POTION_B_SECONDS
			game.set_message("缓释凝胶：%.0f 秒内回复 %d 生命" % [BaseCatalog.POTION_B_SECONDS, roundi(amount)])
		"C":
			game.player.heal(amount, true, false)
			game.run_contamination -= BaseCatalog.POTION_C_CLEANSE
			_suppress_timer = BaseCatalog.POTION_C_SUPPRESS_SECONDS
			game.set_message("抑制喷剂：回复 %d 生命，污染 −%d，%d 秒内累积减半" % [roundi(amount), int(BaseCatalog.POTION_C_CLEANSE), int(BaseCatalog.POTION_C_SUPPRESS_SECONDS)])
		_:
			game.player.heal(amount, true, false)
			game.set_message("标准急救剂：回复 %d 生命" % roundi(amount))
	game.save_base_soon(true)
	return true

## Below the low threshold she starts drinking the auto slot's kind, one flask
## after another, until life is at or above the high one (用户 2026-10-15). A
## gel waits for the last gel to finish, since a new one replaces it.
func _tick_auto_potion(delta: float) -> void:
	_auto_potion_gap = maxf(0.0, _auto_potion_gap - delta)
	var action := Hotbar.auto_potion()
	if action == "" or game.in_base:
		_auto_drinking = false
		return
	var limits := Hotbar.auto_thresholds()
	var ratio := game.player.hp_ratio()
	if ratio < limits[0]: _auto_drinking = true
	if ratio >= limits[1] or game.player.full_hp(): _auto_drinking = false   # the cap may sit below the high mark
	if not _auto_drinking or _auto_potion_gap > 0.0: return
	var type: String = Hotbar.ACTIONS[action].potion
	if type == "B" and _slow_heal_left > 0.0: return
	if use_potion_type(type): _auto_potion_gap = AUTO_POTION_GAP

## Contamination right now: this contract's dose so far. It starts from 0 at
## every departure and is gone at settlement (用户 2026-10-15: 污染不带出局外).
func current_contamination() -> float:
	return clampf(game.run_contamination, 0.0, BaseCatalog.CONTAMINATION_MAX)

## Contamination per second at this moment of a contract.
func contamination_rate() -> float:
	if game.in_base: return 0.0
	var rate := 0.0
	if game.region_id == "mine": rate += BaseCatalog.CONTAMINATION_MINE
	if game.route_deep(): rate += BaseCatalog.CONTAMINATION_DEEP_ROUTE
	rate += game.count_effect("raw_ore") * BaseCatalog.CONTAMINATION_PER_ORE
	rate += game.count_effect(GameManager.SEALED_ORE) * FeatureCatalog.SEALED_ORE_RATE
	rate += game.count_effect("dirty") * GameManager.CONTAMINATION_PER_DIRTY
	if _suppress_timer > 0.0: rate *= 0.5
	rate *= game.potion_fx.contam_mult()
	return rate * field_feature_rate("mine") * maxf(0.0, 1.0 + float(game.player.stats.get("contam_pct", 0.0))) * game.features.growth_mult("contamination", game.floor_number) * (game.player.elements.feature_mult("contamination") if game.player.elements != null else 1.0)

## The news on a feature's growth (feature_rate), on its own map only.
func field_feature_rate(map: String) -> float:
	return game.field_mult("feature_rate") if game.region_id == map else 1.0

## Shown on the field HUD only when it is moving or could: the mine, the deep
## route, or ore in the pack.
func contamination_visible() -> bool:
	return not game.in_base and (game.region_id == "mine" or game.route_deep() or game.count_effect("raw_ore") > 0 or game.count_effect(GameManager.SEALED_ORE) > 0)

## At departure: the flask effects, the dose and the gel reset; injury and
## contamination set max HP, potion healing and self-regeneration
## (kept live by _tick_medical).
func _apply_medical_state() -> void:
	game.player.regen_blocked = false
	game.potion_fx.game = game
	game.potion_fx.reset()
	game.run_contamination = 0.0
	game.player.cold = 0.0
	game.player.condition_hp_penalty = -1.0   # force the recompute
	game.player.set_condition(game.base.injured, current_contamination())
	_potion_heal_factor = 1.0 - BaseCatalog.contamination_potion_penalty(current_contamination())
	_suppress_timer = 0.0
	_slow_heal_left = 0.0
	_announced_tier = 0

func _tick_medical(delta: float) -> void:
	game.potion_fx.tick(delta)
	if _slow_heal_left > 0.0:
		var heal_step := minf(_slow_heal_left, _slow_heal_rate * delta)
		_slow_heal_left -= heal_step
		game.player.heal(heal_step, false, false)
	_suppress_timer = maxf(0.0, _suppress_timer - delta)
	# In a camp the flat dose on arrival stands for the whole stay.
	if not game.in_camp: game.run_contamination += contamination_rate() * delta
	# Contamination works live (§6 D): max HP, regeneration and potion healing.
	game.player.set_condition(game.base.injured, current_contamination())
	_potion_heal_factor = 1.0 - BaseCatalog.contamination_potion_penalty(current_contamination())
	var tier := BaseCatalog.contamination_tier(current_contamination())
	if tier > _announced_tier and tier > 0:
		game.set_message("污染升到 %d（%s）" % [roundi(current_contamination()), BaseCatalog.CONTAMINATION_TIER_NAMES[tier]])
	_announced_tier = maxi(_announced_tier, tier)

## Pharmacy (药剂进背包): one flask straight into the pack for the next contract.
## 标准急救剂 are free while this contract's free issue lasts.
func buy_potion(type: String) -> bool:
	if not game.in_base or not BaseCatalog.POTIONS.has(type): return false
	var price := potion_price(type)
	if price < 0 or game.gold < price: return false
	var flask := BaseCatalog.create_potion(type, game.deepest_tier())
	if game.inventory.add_stack(flask) > 0:
		game.notice("背包空间不足：药剂要占一格。")
		return false
	game.gold -= price
	if type == "A" and price == 0: game.base.free_potions -= 1
	game.save_base()
	return true

## The pharmacy's price at the deepest camp's tier (v1.1 §4.1); 0 while the
## free issue lasts, -1 before the rank allows it.
func potion_price(type: String) -> int:
	var price := game.base.potion_price(type)
	return Economy.tiered(price, game.deepest_tier()) if price > 0 else price

## Treatment: × the income index of the floor she fell on (v1.1 §4.1); 医疗部 2 阶 halves it.
func injury_price(id: String) -> int:
	var tier := int(game.base.injuries.get(id, 1)) if (game.base.injuries.get(id, 1) is int or game.base.injuries.get(id, 1) is float) else 1
	var price := Economy.tiered(BaseCatalog.INJURY_TREATMENT, tier)
	return price / 2 if game.base.researched("injury_fee") else price

## Treats one operator's injury (the one who deploys next by default).
func treat_injury(id: String = "") -> bool:
	if id.is_empty(): id = game.base.operator
	if not game.in_base or not game.base.injuries.has(id) or game.gold < injury_price(id): return false
	game.gold -= injury_price(id)
	game.base.injuries.erase(id)
	game.save_base()
	game.set_message("%s的重伤已治愈。" % Operators.display_name(id))
	return true
