class_name GmFacilities
extends RefCounted

## GameManager's base work (罗德岛基地玩法策划案; 基建设施修订案 v1.1): the
## second deck's farm, canteen and lift (势力特供策划案_v0_2 §三–§六), the
## order board's deliveries, abandons and rerolls, and the facilities —
## their gates, connecting, construction and upgrades. The base's own state
## is BaseState (GameManager.base).

var game: GameManager

func _init(owner: GameManager) -> void:
	game = owner

func farm_changed() -> void:
	game.save_base()
	if is_instance_valid(game.base_map): game.base_map.set_farm(game.provisions)

func _tick_kitchen() -> void:
	var done := game.provisions.tick()
	if done.is_empty(): return
	for job in done: game.broadcast("PRTS：食堂做好了 %s ×%d。" % [job.output, int(job.count)])
	game.save_base(not game.in_base)

## The 补给 for this contract: max HP and regeneration on the sheet, attack
## and attack speed as a lasting hex beside the flasks'. "" takes it off.
func _apply_meal(meal_id: String) -> void:
	game.run_meal = meal_id if Provisions.MEALS.has(meal_id) else ""
	if not is_instance_valid(game.player): return
	game.player.clear_hex("meal")
	var m: Dictionary = Provisions.MEALS.get(game.run_meal, {})
	var hex := {}
	for key in ["atk", "aspd"]:
		if m.has(key): hex[key] = float(m[key])
	if not hex.is_empty(): game.player.add_hex("meal", hex, -1.0)
	game.player._recompute_stats()

func meal_tier() -> int:
	return int(Provisions.MEALS.get(game.run_meal, {}).get("tier", 0))

## The lift between the decks.
func ride_lift(to_deck: int) -> void:
	if not game.in_base or game.transitioning or not to_deck in [1, 2]: return
	game.close_modal()
	game.deck = to_deck
	if to_deck == 2: game.story_note("lift")
	game.base_map.set_deck(to_deck)
	game.player.clear_move_target()
	game.player.teleport(game.base_map.spawn_point("deck2" if to_deck == 2 else "deck_lift"))
	game.camera.global_position = game.camera_target() + game.camera_offset()

## Delivery (§3.8): only from the warehouse proper (the shelves and their
## 整理箱) or the pack and safe bag; not from the PRTS mail or what she wears.
func deliverable_items() -> Array[Item]:
	var out: Array[Item] = []
	out.append_array(game.stash)
	out.append_array(game.inventory.items)
	out.append_array(game.safe_bag.items)
	return out

func _hand_over(item: Item) -> bool:
	if game.base.take_from_shelf(item): return true
	if game.inventory.items.has(item): game.inventory.remove(item)
	elif game.safe_bag.items.has(item): game.safe_bag.remove(item)
	else: return false
	return true

## Hands `item` to the order in `slot` (all of it, or what the order still
## needs from a stack); the order pays when it is complete.
func deliver_to_order(slot: int, item: Item) -> bool:
	if not game.in_base or not deliverable_items().has(item) or not game.base.orders.matches(slot, item): return false
	var result := game.base.orders.deliver(slot, item)
	# A stack bigger than the order needs stays where it was, smaller.
	if item.is_stackable() and int(result.used) < item.quantity: item.set_quantity(item.quantity - int(result.used))
	else: _hand_over(item)
	var text := BaseCatalog.order_text(game.base.orders.slots[slot].id)
	if result.done:
		game.gold += int(result.gold)
		game.story_note("order")
		game.set_message("订单完成：%s  ·  龙门币 +%s" % [text, Economy.format(result.gold)])
	else: game.set_message("已交付 %s ×%d：%s 还差 %d" % [item.item_name, int(result.used), text, game.base.orders.remaining(slot)])
	game.save_base()
	return true

func abandon_order(slot: int) -> bool:
	if not game.in_base or not game.base.orders.abandon(slot): return false
	game.set_message("已放弃订单：下次结算后补上新订单。")
	game.save_base()
	return true

## The free order reroll. reroll_available is never set true now (BaseState),
## so this always returns false.
func reroll_order(slot: int) -> bool:
	if not game.in_base or not game.base.reroll_available or not game.base.orders.reroll(slot, game.rng_base): return false
	game.base.reroll_available = false
	game.set_message("订单已刷新。")
	game.save_base()
	return true

## The facility's next level (BaseCatalog.FACILITIES): gold, then materials.
## `remote` is the 基建总控台 (or its quick button): only connected facilities.
func facility_refusal(id: String, remote := false) -> String:
	if remote and not game.base.is_connected_to_hub(id): return "未接入"
	var lost := dept_refusal(id)
	if not lost.is_empty(): return lost
	var gate := gate_refusal(id)
	if not gate.is_empty(): return gate
	var refusal := game.base.facility_refusal(id, game.gold)
	return refusal if not refusal.is_empty() else game.materials_refusal(facility_cost(id))

## 失散干员 (失散干员与主线流程策划案 v0.2 §4.2): the department waits for
## whoever runs it ("" once she is back, or for a department nobody runs).
func dept_refusal(dept: String) -> String:
	var id := game.base.dept_missing(dept)
	return "" if id.is_empty() else "负责干员 %s 失散" % LostCatalog.name_of(id)

## A faction relation a facility's building waits for ("" once met or built).
func gate_refusal(id: String) -> String:
	var gate: Dictionary = BaseCatalog.FACILITIES[id].get("gate", {})
	if gate.is_empty() or game.base.facility_level(id) >= 1: return ""
	if game.exchange.rank(str(gate.faction)) >= int(gate.rank): return ""
	return "需要%s关系 %s" % [FactionCatalog.name_of(str(gate.faction)), Exchange.rank_name(int(gate.rank))]

func connect_refusal(id: String) -> String:
	if not id in BaseCatalog.connectable(): return "无效"
	if game.base.is_connected_to_hub(id): return "已接入"
	if not game.base.hub_built(): return "需要基建总控台"
	var gate := gate_refusal(id)
	if not gate.is_empty(): return gate
	if game.gold < int(BaseCatalog.CONNECT_COST.price): return "龙门币不足"
	return game.materials_refusal(BaseCatalog.connect_materials(id))

func connect_facility(id: String) -> bool:
	if not game.in_base or not connect_refusal(id).is_empty(): return false
	game.consume_materials(BaseCatalog.connect_materials(id))
	game.gold -= int(BaseCatalog.CONNECT_COST.price)
	game.base.connect_facility(id)
	game.save_base()
	game.set_message("%s已接入基建总控台。" % BaseCatalog.facility_name(id))
	return true

func facility_cost(id: String) -> Dictionary:
	return BaseCatalog.facility_step(id, game.base.facility_level(id) + 1).get("materials", {})

## How many base upgrades could be bought right now from the hub (the 基建 marker).
func construction_ready() -> int:
	var n := 0
	for id in BaseCatalog.FACILITY_ORDER:
		if facility_refusal(id, true).is_empty() or connect_refusal(id).is_empty(): n += 1
	for refusal in [game.upgrade_refusal("pack"), game.upgrade_refusal("safe"), game.camp_upgrade_refusal()]:
		if refusal.is_empty(): n += 1
	return n

func upgrade_facility(id: String, remote := false) -> bool:
	if not game.in_base or not BaseCatalog.FACILITIES.has(id) or not facility_refusal(id, remote).is_empty(): return false
	var step := BaseCatalog.facility_step(id, game.base.facility_level(id) + 1)
	game.consume_materials(step.materials)
	game.gold -= int(step.price)
	var level := game.base.raise_facility(id)
	game.save_base()
	game.set_message("%s升到 Lv%d：%s。" % [BaseCatalog.facility_name(id), level, step.opens])
	return true

## Stations with something to do get a yellow marker (§5.2).
func station_needs_attention(id: String) -> bool:
	match id:
		"outbound": return is_instance_valid(game.warehouse_view) and game.warehouse_view.orders_fillable()
		"reception": return game.base.report_unread or game.base.any_injured()
		"exchange": return not game.market.flash.is_empty() or not game.swan_popup.is_empty()
	return false
