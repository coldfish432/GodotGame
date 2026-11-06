class_name GmCamp
extends RefCounted

## GameManager's 可露希尔 counter (撤离与营地修订案 §1–3; 药剂与商人界面策划案 §1):
## her flasks in 赤金 in a camp or at the base, a camp's draw of her 特供,
## 寄存 to the base, buying 赤金 for 龙门币, and the camp upgrade. Entering,
## building and leaving a camp stay on GameManager (the floor flow).

var game: GameManager
## A camp's counter: A and B, and CAMP_SPECIALS of her 特供 her base store stocks.
var camp_closure_stock := {}

func _init(owner: GameManager) -> void:
	game = owner

func camp_label(depth: int) -> String:
	return "营地 %d|%d" % [depth, depth + 1]

## 赤金 she can pay with here: what she carries in a camp, the base's storage too at home.
func gold_available() -> int:
	return game.material_count(Economy.GOLD_ID) if game.in_base else game.gold_bars()

func _pay_gold(bars: int) -> bool:
	if game.in_base: return game.consume_materials({Economy.GOLD_ID: bars}) if bars > 0 else true
	return game.spend_gold_bars(bars)

## 可露希尔's flasks in 赤金 (v1.1 §2.3): 赤金 does not split, so one bar buys
## as many flasks as the pharmacy's 龙门币 price fits into the live rate, at
## least one. The tier is the camp's (or the deepest camp's at the base).
func closure_potion_price(type: String) -> int:
	var p: Dictionary = BaseCatalog.POTIONS[type]
	if game.base.facility_level("store") < int(p.store): return -1
	# The dearer 特供 cost as many bars as their 龙门币 price needs (at least one).
	return maxi(1, ceili(_closure_lmd(type) / maxf(1.0, Economy.bar_lmd())))

func _closure_lmd(type: String) -> float:
	return float(Economy.tiered(BaseCatalog.POTION_A_PRICE if type == "A" else int(BaseCatalog.POTIONS[type].get("price", 1000)), closure_potion_tier()))

## What 可露希尔 shows: at the base her 特供 line; in a camp A and B and the
## three 特供 this camp drew (药剂与商人界面策划案 §1).
func closure_goods() -> Array:
	if game.in_camp: return ["A", "B"] + camp_closure_stock.keys().filter(func(k): return not k in ["A", "B"])
	return BaseCatalog.CLOSURE_LINE.duplicate()

## Bottles of `type` she has left (-1: no limit). The base shelf refills every
## hour (BaseState.closure_left); a camp's draw is what it is.
func closure_stock_left(type: String) -> int:
	if type in ["A", "B"]: return -1
	if game.in_camp: return int(camp_closure_stock.get(type, 0))
	return game.base.closure_left(type)

func _roll_camp_closure() -> void:
	camp_closure_stock = {}
	var open: Array = BaseCatalog.CLOSURE_LINE.filter(func(k): return game.base.facility_level("store") >= int(BaseCatalog.POTIONS[k].store))
	for i in range(mini(BaseCatalog.CAMP_SPECIALS, open.size())):
		var k: String = open[game.rng_trade.randi() % open.size()]
		open.erase(k)
		camp_closure_stock[k] = int(BaseCatalog.POTIONS[k].cap)

func closure_potion_tier() -> int:
	return Economy.tier_of(game.floor_number + 1) if game.in_camp else game.deepest_tier()

func closure_potion_bundle(type: String) -> int:
	var bars := maxi(1, closure_potion_price(type))
	return maxi(1, floori(bars * Economy.bar_lmd() / maxf(1.0, _closure_lmd(type))))

## Flasks from 可露希尔, into the pack (in a camp, or at her base counter): one
## bar's bundle; whatever does not fit stays with her and is not charged.
func closure_buy_potion(type: String) -> bool:
	if not (game.in_camp or game.in_base) or not BaseCatalog.POTIONS.has(type): return false
	var price := closure_potion_price(type)
	if price < 0 or gold_available() < price: return false
	var stock := closure_stock_left(type)
	if stock == 0:
		game.notice("售罄，等可露希尔补货")
		return false
	var flask := BaseCatalog.create_potion(type, closure_potion_tier())
	var bundle := mini(closure_potion_bundle(type), flask.max_stack)
	if stock > 0: bundle = mini(bundle, stock)
	flask.set_quantity(bundle)
	var left := game.inventory.add_stack(flask)
	if left >= bundle:
		game.notice("背包空间不足：药剂要占一格。")
		return false
	if left > 0: game.notice("背包放不下的 %d 瓶留在了可露希尔那里。" % left)
	if stock > 0:
		if game.in_camp: camp_closure_stock[type] = stock - (bundle - left)
		else: game.base.closure_stock[type] = stock - (bundle - left)
	_pay_gold(price)
	if game.in_base: game.story_note("store_potion")
	game.save_base(not game.in_base)
	return true

## 寄存 (§3): materials only, no special (regional) ones and no flasks; the fee is
## 20% of the 交付价, in 赤金, rounded up, at least one.
func deposit_fee(item: Item) -> int:
	return maxi(1, ceili(Economy.price(item) * FieldCatalog.DEPOSIT_FEE * game.research.deposit_fee_factor() / Economy.bar_lmd())) if item != null else 0

func deposit_refusal(item: Item) -> String:
	if not game.in_camp: return "不在营地"
	if item == null or not (game.inventory.items.has(item) or game.safe_bag.items.has(item)): return "不在背包里"
	if item.category != Item.Category.MATERIAL or item.is_potion(): return "只收材料"
	if not item.exclusive_region.is_empty() or not item.effect.is_empty(): return "特殊材料不能寄存"
	var others := game.gold_bars() - (item.quantity if item.material_id == Economy.GOLD_ID else 0)
	if others < deposit_fee(item): return "赤金不足"
	return ""

func deposit_item(item: Item) -> bool:
	if not deposit_refusal(item).is_empty(): return false
	var fee := deposit_fee(item)
	game.inventory.remove(item)
	game.safe_bag.remove(item)
	game.spend_gold_bars(fee)
	item.carried_in = false
	game.base.receive_to_staging(item)
	game.save_base(true)
	game.set_message("已寄存 %s：送到基地仓库。" % item.display_name())
	return true

## 可露希尔 buys 赤金 for 龙门币 at the live rate less her spread (§1.3).
func sell_gold_bars(bars: int) -> bool:
	if not (game.in_camp or game.in_base) or bars <= 0 or gold_available() < bars: return false
	_pay_gold(bars)
	var paid := bars * Economy.closure_bar_price()
	game.gold += paid
	game.save_base(not game.in_base)
	game.set_message("卖出赤金 ×%d：龙门币 +%s" % [bars, Economy.format(paid)])
	return true

## The camp upgrade (基地建设, not per region): camps stop adding contamination.
func camp_upgrade_refusal() -> String:
	if game.base.camp_upgraded: return "已升级"
	if game.gold < BaseCatalog.CAMP_UPGRADE_PRICE: return "龙门币不足"
	return game.materials_refusal(BaseCatalog.CAMP_UPGRADE_MATERIALS)

func buy_camp_upgrade() -> bool:
	if not game.in_base or not camp_upgrade_refusal().is_empty(): return false
	game.consume_materials(BaseCatalog.CAMP_UPGRADE_MATERIALS)
	game.gold -= BaseCatalog.CAMP_UPGRADE_PRICE
	game.base.camp_upgraded = true
	game.save_base()
	game.set_message("营地升级完成：在营地停留不再累积污染。")
	return true
