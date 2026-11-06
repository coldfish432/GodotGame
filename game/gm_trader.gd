class_name GmTrader
extends RefCounted

## GameManager's 坎诺特 (坎诺特商店策划案): his stock, rerolls, buying and
## selling in 赤金, and 购回 (用户 2026-10-27): what was sold to a shop can be
## bought back at the price it fetched. Who stands at the encounter spot
## (_roll_encounter, _open_encounter) stays on GameManager.

var game: GameManager
## His stock this floor: eight slots and the news's extras, {"kind": "relic"/"item", "relic": Dictionary,
## "item": Item, "price": 赤金, "sold": bool}. Rolled when he is first met.
var trader_stock: Array[Dictionary] = []
var trader_rerolls := 0
## 课题 商队联络: 坎诺特 already stood on this contract.
var _trader_met := false
## 幸运硬币 / 假面舞会面具 pay once per encounter, on first meeting.
var _encounter_greeted := false
## What was sold at each shop, until she leaves the floor or the base:
## shop key ("cannot", "post:<faction>", "consign:<anchor>") -> [{item, price, currency, shown, undo}].
var buyback := {}

func _init(owner: GameManager) -> void:
	game = owner

## 锈蚀的铁锤 halves what he asks (商店中购买道具所需源石锭-50%).
func _trader_discount(price: int) -> int:
	return maxi(1, ceili(price * (1.0 - minf(0.9, game.player.f("shop_discount")))))

## Eight slots (§2): two relics, three of the region's gear, two flasks, one
## special slot (25% special gear, else more gear).
func _roll_trader_stock() -> void:
	trader_stock.clear()
	var relics := RelicCatalog.roll_offers(game.region_id, game.builds, "device", game.rng_trade, FieldCatalog.TRADER_RELICS)
	for relic in relics:
		trader_stock.append({"kind": "relic", "relic": relic, "price": _trader_discount(int(FieldCatalog.TRADER_RELIC_PRICES[relic.rarity])), "sold": false})
	for i in range(FieldCatalog.TRADER_GEAR):
		trader_stock.append(_trader_gear_slot(_roll_trader_gear()))
	for i in range(FieldCatalog.TRADER_POTIONS):
		# Any flask but the 强心针, the regional ones too (药剂与商人界面策划案 §1);
		# the restoratives still come up most.
		var roll := game.rng_trade.randf()
		var type: String = "A" if roll < 0.35 else ("B" if roll < 0.55 else FieldCatalog.TRADER_POTION_POOL[game.rng_trade.randi() % FieldCatalog.TRADER_POTION_POOL.size()])
		trader_stock.append({"kind": "item", "item": BaseCatalog.create_potion(type, Economy.tier_of(game.floor_number)), "price": _trader_discount(FieldCatalog.trader_potion_price(type)), "sold": false})
	var special := SpecialGear.roll(game.region_id, game.floor_number, game.rng_trade) if game.rng_trade.randf() < FieldCatalog.TRADER_SPECIAL_CHANCE else _roll_trader_gear()
	trader_stock.append(_trader_gear_slot(special))
	# 坎诺特 sometimes has an enemy exclusive of this region (装备扩充策划案 §1.1).
	if game.rng_trade.randf() < FieldCatalog.TRADER_EXCLUSIVE_CHANCE:
		var ids := SpecialGear.GEAR.keys().filter(func(id): return SpecialGear.kind(id) == "exclusive" and str(SpecialGear.GEAR[id].region) == game.region_id)
		if not ids.is_empty():
			var exclusive := SpecialGear.create(ids[game.rng_trade.randi_range(0, ids.size() - 1)], game.floor_number, game.rng_trade)
			exclusive.origin_region = game.region_id
			trader_stock[trader_stock.size() - 1] = _trader_gear_slot(exclusive)
	# The news brings him more goods (kannot_stock).
	for i in range(maxi(0, int(game.field_add("kannot_stock")))): trader_stock.append(_trader_gear_slot(_roll_trader_gear()))

func _roll_trader_gear() -> Item:
	for attempt in range(40):
		var item := FieldCatalog.roll_item(game.region_id, game.floor_number, game.rng_trade, 0.0)
		if item.is_equippable() and item.exclusive_region.is_empty() and item.special.is_empty(): return item
	return FieldCatalog.roll_item(game.region_id, game.floor_number, game.rng_trade, 0.0)

func _trader_gear_slot(item: Item) -> Dictionary:
	return {"kind": "item", "item": item, "price": _trader_discount(maxi(1, ceili(item.value * FieldCatalog.TRADER_GEAR_MARKUP / 10.0))), "sold": false}

func trader_reroll_cost() -> int:
	var cost := FieldCatalog.TRADER_REROLL_BASE + FieldCatalog.TRADER_REROLL_STEP * trader_rerolls
	return maxi(1, cost - 1) if game.base.researched("trader_odds") else cost

func trader_reroll() -> bool:
	if game.encounter != "trader" or game.gold_bars() < trader_reroll_cost(): return false
	game.spend_gold_bars(trader_reroll_cost())
	trader_rerolls += 1
	_roll_trader_stock()
	return true

func trader_buy_refusal(slot: int) -> String:
	if game.encounter != "trader" or slot < 0 or slot >= trader_stock.size(): return "没有这件"
	var entry: Dictionary = trader_stock[slot]
	if entry.sold: return "已售出"
	if game.gold_bars() < int(entry.price): return "赤金不足"
	if entry.kind == "relic" and game.builds.has(entry.relic.id): return "已拥有"
	if entry.kind == "item" and not game.inventory.can_take(entry.item): return "背包放不下"
	return ""

func trader_buy(slot: int) -> bool:
	if not trader_buy_refusal(slot).is_empty(): return false
	var entry: Dictionary = trader_stock[slot]
	game.spend_gold_bars(int(entry.price))
	entry.sold = true
	if entry.kind == "relic":
		var enemy_hp_before := game.player.f("enemy_hp")
		game.builds.append(entry.relic.id)
		game.relic_floors[entry.relic.id] = game.floor_number
		game.player._recompute_stats()
		game._rescale_enemy_life(enemy_hp_before, game.player.f("enemy_hp"))
		game.set_message("获得藏品 %s — %s" % [entry.relic.name, entry.relic.effect])
	else:
		game.inventory.add_stack(entry.item)
		game.set_message("买下 %s" % entry.item.display_name())
	game.save_base(true)
	return true

## What he pays for `item` in 赤金 (§3: 交付价 × 50%), or 0 when he will not buy it:
## gear and materials only — no flasks, no 原矿, nothing insured, no 赤金.
func trader_offer(item: Item) -> int:
	if item == null or item.is_potion() or item.insured or item.effect in ["raw_ore", GameManager.SEALED_ORE, VoyageCatalog.CARGO_EFFECT] or item.material_id == Economy.GOLD_ID or GearCatalog.bound(item): return 0
	if FactionRewards.is_badge(item.material_id): return 0
	return maxi(1, floori(item.value * FieldCatalog.TRADER_BUYBACK / 10.0 * game.field_mult("kannot_buy") * (FactionRewards.COUNCIL_PAY if FactionRewards.badge_on(game, "lungmen") else 1.0)))

func trader_sell(item: Item) -> bool:
	if game.encounter != "trader" or not game.carried_items().has(item) or trader_offer(item) <= 0: return false
	var pay := trader_offer(item)
	game.inventory.remove(item)
	game.safe_bag.remove(item)
	if game.player.equipped.get(item.category) == item: game.player.unequip(item.category)
	game._give_gold_bars(pay)
	_record_sale("cannot", item, pay, "gold", str(pay))
	game.save_base(true)
	game.set_message("卖给坎诺特：%s，赤金 +%d" % [item.display_name(), pay])
	return true

func _record_sale(shop: String, item: Item, price: float, currency: String, shown: String, undo: Dictionary = {}) -> void:
	if not buyback.has(shop): buyback[shop] = []
	buyback[shop].append({"item": item, "price": price, "currency": currency, "shown": shown, "undo": undo})

func buyback_list(shop: String) -> Array:
	return buyback.get(shop, [])

func buyback_refusal(shop: String, index: int) -> String:
	var list := buyback_list(shop)
	if index < 0 or index >= list.size(): return "—"
	var entry: Dictionary = list[index]
	var cur := str(entry.currency)
	var price := float(entry.price)
	if cur == "gold" and game.gold_available() < int(price): return "赤金不足"
	if cur == "lmd" and game.gold < ceili(price): return "龙门币不足"
	if not cur in ["gold", "lmd"] and game.exchange.balance(cur) < price: return "余额不足"
	if not game.inventory.can_take(entry.item): return "背包已满"
	return ""

## Buys entry `index` back at what it fetched, into the pack.
func buy_back(shop: String, index: int) -> bool:
	if not buyback_refusal(shop, index).is_empty(): return false
	var entry: Dictionary = buyback[shop][index]
	var cur := str(entry.currency)
	if cur == "gold":
		if not game._pay_gold(int(entry.price)): return false
	elif not game.exchange.pay(cur, float(entry.price)): return false
	buyback[shop].remove_at(index)
	var item: Item = entry.item
	game.inventory.add_stack(item)
	var undo: Dictionary = entry.undo
	for f in undo.get("relations", {}): game.exchange.add_relation(f, -int(undo.relations[f]))
	if not str(undo.get("market", "")).is_empty(): game.market.add_pressure(str(undo.market), -float(undo.value))
	if undo.has("faction"): game.exchange.recent_sales[undo.faction] = maxf(0.0, float(game.exchange.recent_sales.get(undo.faction, 0.0)) - float(undo.value))
	game.save_base(not game.in_base)
	game.set_message("购回 %s" % item.display_name())
	return true
