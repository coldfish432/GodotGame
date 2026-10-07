extends SceneTree

## The 2026-10-05/06 rule revisions: 经济修订案 (赤金 / 龙门币), 药剂进背包,
## 保全系统修订案 (no gilding, delayed insurance, the Rhodes squad), 撤离与营地修订案
## (camps every ten floors, random extraction, hidden difficulty) and
## 坎诺特商店策划案. Each section below is one document.

var game: GameManager
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool, detail: Variant = null) -> void:
	checks += 1
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label + ("" if detail == null or passed else "  %s" % str(detail)))

func run() -> void:
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 4242
	root.add_child(game)
	await step(8)
	await _economy()
	await _protection()
	await _camps()
	await _trader()
	await _escape()
	print("REVISIONS RESULT: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await step(2)
	quit(1 if failures else 0)

# --- 经济修订案 ---------------------------------------------------------------

func _economy() -> void:
	check("a new save starts with 6,000 龙门币", Economy.STARTING_LMD == 6000 and game.gold == 6000)
	check("龙门币 is formatted with thousands separators", Economy.format(90000) == "90,000" and Economy.format(-1500) == "-1,500" and Economy.format(12) == "12")
	var bar := MaterialCatalog.create(Economy.GOLD_ID, 99)
	check("赤金 is a ★3 material that stacks to 10", MaterialCatalog.star(Economy.GOLD_ID) == 3 and bar.max_stack == 10 and bar.quantity == 10 and bar.category == Item.Category.MATERIAL)
	check("one 赤金 sells for 1000 龙门币 (its 交付价)", Economy.price(MaterialCatalog.create(Economy.GOLD_ID, 1)) == Economy.GOLD_BAR_LMD)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var total := 0
	for i in range(4000): total += Economy.bars_from_reward(12.0, rng)
	check("old reward units become 赤金 at 10 : 1 on average", absf(total / 4000.0 - 1.2) < 0.05, total / 4000.0)
	var lo := 999999
	var hi := 0
	for i in range(400):
		var r := Economy.contract_reward(1, rng)
		lo = mini(lo, r)
		hi = maxi(hi, r)
		if r % 10 != 0: lo = -1
	check("one floor pays 800–1200 in steps of 10", lo >= 800 and hi <= 1200 and hi > lo, [lo, hi])
	check("no floors, no reward", Economy.contract_reward(0, rng) == 0)

	await game.start_contract("city")
	await step(2)
	game._clear_field()
	game.inventory.items.clear()
	game.safe_bag.items.clear()
	game.run_gold = 23
	check("赤金 carried is counted across stacks", game.gold_bars() == 23 and game.inventory.items.filter(func(x): return x.material_id == Economy.GOLD_ID).size() == 3)
	game.safe_bag.add_stack(MaterialCatalog.create(Economy.GOLD_ID, 5))
	check("the safe bag's 赤金 counts too", game.gold_bars() == 28)
	check("spending takes the pack first", game.spend_gold_bars(25) and game.inventory.count_material(Economy.GOLD_ID) == 0 and game.safe_bag.count_material(Economy.GOLD_ID) == 3)
	check("spending more than she carries takes nothing", not game.spend_gold_bars(4) and game.gold_bars() == 3)
	game.run_gold = 0
	check("add_gold puts 赤金 in the pack", game.add_gold(4) == 4 and game.gold_bars() == 4)
	# Ground drops from the loot tables arrive as 赤金 items, not as a balance.
	game._drop_at(game.player.global_position + Vector3(4, 0, 0), [{"gold": 30}], 0.1)
	await step(1)
	var drops := get_nodes_in_group("loot").filter(func(n): return n.item != null and n.item.material_id == Economy.GOLD_ID)
	check("a gold drop lands as a 赤金 stack on the ground", drops.size() == 1 and drops[0].item.quantity == 3, drops.size())
	# Extraction: 赤金 comes home as an item, the contract pays 龙门币 per floor.
	var before := game.gold
	game.settle(true)
	await step(2)
	var reward := game.gold - before
	check("extracting from floor 1 pays one floor's 800–1200 龙门币", reward >= 800 and reward <= 1200, reward)
	var crated := func(): return game.base.all_items().filter(func(x): return x.material_id == Economy.GOLD_ID).reduce(func(n, x): return n + x.quantity, 0)
	check("赤金 found on the contract comes home in a receiving crate", game.gold_bars() == 0 and crated.call() == 4, crated.call())
	await game.start_contract("city")
	await step(2)
	game._clear_field()
	before = game.gold
	game.run_gold = 7
	game.player.hp = -1
	await step(2)
	check("death pays no contract reward", game.in_base and game.gold == before)
	check("and loses the 赤金 that was in the pack", game.gold_bars() == 0 and crated.call() == 4)
	# A version 2 save holds 资金: it loads as 龙门币 ×100.
	game.save_path = "user://revisions_TEST_ONLY.json"
	var v2 := {"version": 2, "gold": 87, "base": {}, "loadout": [], "active_contract": false, "settlement": [], "rng_state": "1"}
	var file := FileAccess.open(game.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(v2))
	file.close()
	game.load_base()
	check("a version 2 save's 资金 loads as 龙门币 ×100", game.gold == 8700)
	game.save_enabled = true
	game.save_base()
	game.gold = 1
	game.load_base()
	check("a version 3 save keeps 龙门币 as is", game.gold == 8700)
	game.save_enabled = false
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(game.save_path + suffix): DirAccess.remove_absolute(game.save_path + suffix)

# --- 保全系统修订案 -------------------------------------------------------------

func _protection() -> void:
	check("gilding is gone from the game", not game.has_method("gild_item") and not "gilded" in Item.new())
	game.gold = 50000
	await game.start_contract("snow")
	await step(2)
	game._clear_field()
	game.inventory.items.clear()
	game.safe_bag.items.clear()
	var blade := Item.create("小队测试刀", Item.Category.WEAPON, 2, 1, 2.0)
	blade.value = 118
	var vest := Item.create("小队测试甲", Item.Category.ARMOR, 2, 2, 2.0)
	vest.value = 40
	var ore := MaterialCatalog.create("碳", 5)
	game.inventory.try_add(blade)
	game.inventory.try_add(vest)
	game.inventory.try_add(ore)
	game.run_gold = 30
	game.encounter = "squad"
	game.encounter_used = false
	game.squad_mult = 1.2
	game.world_map.encounter_node.visible = true
	check("the squad's price is 价值 × 倍率 ÷ 10 in 赤金, rounded up", game.squad_price(blade) == 15 and game.squad_price(vest) == 5)
	check("away from the squad nothing is offered", game.squad_refusal(blade, "insure") == "小队不在附近")
	game.player.teleport(game.world_map.encounter_position)
	check("only equipment", game.squad_refusal(ore, "insure") == "只收装备" and not game.squad_insure(ore))
	game.run_gold = 4
	check("not without the 赤金", game.squad_refusal(vest, "insure") == "赤金不足")
	game.run_gold = 30
	check("insure: pays 赤金, insures, uses the squad up", game.squad_insure(blade) and blade.insured and game.gold_bars() == 15 and game.encounter_used)
	check("one service per squad", not game.squad_send_home(vest) and not game.squad_insure(vest))
	game.encounter_used = false
	var staged := game.base.staging.size()
	check("send home: the item leaves her for staging at once", game.squad_send_home(blade) and not game.carried_items().has(blade)
		and game.base.location_of(blade) == "staging" and game.base.staging.size() == staged + 1)
	check("an insured item can be sent; its insurance lapses", not blade.insured and game.gold_bars() == 0)
	game.encounter_used = false
	game.run_gold = 10
	game.player.equip(vest)
	game.inventory.remove(vest)
	check("equipped gear can be sent home too", game.squad_send_home(vest) and game.player.equipped.get(Item.Category.ARMOR) == null and game.base.location_of(vest) == "staging")
	game.open_modal("squad")
	game.menu.show_squad()
	check("the squad menu opens", game.menu.visible)
	game.close_modal()
	# A squad turns up on about 30% of floors.
	var met := 0
	for i in range(3000):
		game._roll_encounter()
		if game.encounter == "squad": met += 1
	check("a squad stands on ~30%% of floors (%d/3000)" % met, absf(met / 3000.0 - FieldCatalog.SQUAD_CHANCE) < 0.03, met)
	game.encounter = "squad"
	game._build_world()
	var shown_with: bool = game.world_map.encounter_node.visible == (game.encounter != "")
	check("its marker shows exactly when someone is there", shown_with)
	game.settle(true)
	await step(2)

# --- 撤离与营地修订案 -------------------------------------------------------------

func _camps() -> void:
	# Random extraction: at most one per ten floors, on 4–6, 1/6 each, 1/2 in all.
	var hits := {}
	var blocks := 6000
	var doubled := false
	for b in range(blocks):
		var found := 0
		for f in range(1, 11):
			game.floor_number = b * 10 + f
			game._roll_random_extraction()
			if game.is_extraction_floor():
				hits[f] = int(hits.get(f, 0)) + 1
				found += 1
		if found > 1: doubled = true
	var share := func(f: int) -> float: return int(hits.get(f, 0)) / float(blocks)
	check("never more than one random extraction in a block of ten", not doubled)
	check("only floors 4, 5 and 6 ever have one", hits.keys().all(func(f): return f in [4, 5, 6]), hits)
	check("each of floors 4–6 carries 1/6", [4, 5, 6].all(func(f): return absf(share.call(f) - 1.0 / 6.0) < 0.015), [share.call(4), share.call(5), share.call(6)])
	check("50% of blocks have one", absf((share.call(4) + share.call(5) + share.call(6)) - 0.5) < 0.02)

	# Hidden difficulty: by floor, plus the route for that floor only; kills do nothing.
	await game.start_contract("mine")
	await step(2)
	check("floor 1 starts at difficulty 0", game.pressure == 0.0)
	game.floor_number = 11
	game.route_index = 2
	check("floor 11 on the dangerous route: 3.5 × 10 + 5 = 40", is_equal_approx(game.difficulty(), 40.0))
	game.route_index = 0
	check("the safe route takes 3 off (32)", is_equal_approx(game.difficulty(), 32.0))
	game.floor_number = 1
	game._build_world()
	var before: float = game.pressure
	var victim: Enemy = game._spawn_enemy(game.player.global_position + Vector3(3, 0, 0), false, false)
	victim.take_hit(999999.0)
	await step(2)
	check("a kill does not raise it", game.pressure == before)

	# The camp after floor 10.
	game._clear_field()
	game.inventory.items.clear()
	game.safe_bag.items.clear()
	game.base.camp_upgraded = false
	game.floor_number = 10
	game.route_index = 2
	var dose: float = game.run_contamination
	await game.advance(1)
	check("advancing from floor 10 enters camp 10|11", game.in_camp and game.modal == "camp" and game.floor_number == 10)
	check("the camp is unlocked for this region only", game.base.camp_unlocked("mine", 10) and not game.base.camp_unlocked("city", 10) and game.base.unlocked_camps("mine") == [10])
	check("an unupgraded camp adds contamination", game.run_contamination > dose)
	check("no squad or 坎诺特 in a camp, and nothing to fight", get_nodes_in_group("enemies").is_empty() and not is_instance_valid(game.world_map.encounter_node))
	game.run_gold = 12
	check("可露希尔's flasks cost the pharmacy price in 赤金, rounded up", game.closure_potion_price("A") == 1 and game.closure_potion_price("B") == 1)
	check("buying one puts it in the pack", game.closure_buy_potion("B") and game.potions == 1 and game.gold_bars() == 11)
	var bolts := MaterialCatalog.create("螺栓", 12)
	var ore := FieldCatalog.exclusive("mine")
	var blade := Item.create("营地刀", Item.Category.WEAPON, 2, 1, 1.0)
	game.inventory.try_add(bolts)
	game.inventory.try_add(ore)
	game.inventory.try_add(blade)
	check("寄存 takes materials only, never special ones", game.deposit_refusal(blade) == "只收材料" and game.deposit_refusal(ore) == "特殊材料不能寄存")
	var fee := game.deposit_fee(bolts)
	check("the fee is 20% of the 交付价 in 赤金, rounded up", fee == maxi(1, ceili(Economy.price(bolts) * 0.2 / 1000.0)))
	check("deposited materials go straight to staging", game.deposit_item(bolts) and game.base.location_of(bolts) == "staging" and game.gold_bars() == 11 - fee)
	var gold_before := game.gold
	check("可露希尔 buys 赤金 for 1000 龙门币 each", game.sell_gold_bars(3) and game.gold == gold_before + 3000 and game.gold_bars() == 8 - fee)
	check("not more than she carries", not game.sell_gold_bars(99))
	game.inventory.remove(ore)
	game.close_modal()
	check("closing anything in a camp comes back to the camp screen", game.modal == "camp")
	await game.leave_camp()
	await step(2)
	check("leaving the camp walks into floor 11 by the route chosen before it", not game.in_camp and game.floor_number == 11 and game.route_index == 1)
	# An upgraded camp does not add contamination.
	game.base.camp_upgraded = true
	game.floor_number = 20
	dose = game.run_contamination
	await game.advance(0)
	check("an upgraded camp adds no contamination", game.in_camp and game.run_contamination == dose)
	var lmd := game.gold
	game.camp_extract()
	await step(2)
	var reward := game.gold - lmd
	check("extracting at camp 20|21 from floor 1 pays 20 floors (16,000–24,000)", game.in_base and reward >= 16000 and reward <= 24000, reward)

	# Starting from an unlocked camp.
	await game.start_contract("mine", 20)
	await step(2)
	check("a contract can start in an unlocked camp", game.in_camp and game.floor_number == 20 and game.start_floor == 21 and game.modal == "camp")
	await game.leave_camp()
	await step(2)
	check("and goes on to the floor after it", game.floor_number == 21 and not game.in_camp)
	check("difficulty there is the depth's own (3.5 × 20 − 3)", is_equal_approx(game.pressure, 67.0))
	lmd = game.gold
	game.settle(true)
	await step(2)
	reward = game.gold - lmd
	check("the reward counts only the floors walked this time (one)", reward >= 800 and reward <= 1200, reward)
	await game.start_contract("city", 10)
	await step(2)
	check("a locked camp is not a start point (city has none)", not game.in_camp and game.floor_number == 1)
	game.settle(true)
	await step(2)

	# 可露希尔 at the base: the same counter, paid from storage.
	game.base.shelf.append(MaterialCatalog.create(Economy.GOLD_ID, 6))
	game.inventory.items.clear()
	lmd = game.gold
	check("at the base she sells 赤金 from the shelves too", game.gold_available() >= 6 and game.sell_gold_bars(2) and game.gold == lmd + 2000)
	check("and sells flasks for 赤金 into the pack", game.closure_buy_potion("A") and game.potions == 1)
	game.open_station("store")
	check("the store station opens", game.menu.visible)
	game.close_modal()

# --- 坎诺特商店策划案 ----------------------------------------------------------

func _trader() -> void:
	var squads := 0
	var traders := 0
	for i in range(4000):
		game._roll_encounter()
		if game.encounter == "squad": squads += 1
		elif game.encounter == "trader": traders += 1
	check("坎诺特 on ~20%% of floors, squads still ~30%%, never both (%d / %d)" % [traders, squads], absf(traders / 4000.0 - 0.2) < 0.025 and absf(squads / 4000.0 - 0.3) < 0.025)
	await game.start_contract("city")
	await step(2)
	game._clear_field()
	game.inventory.items.clear()
	game.safe_bag.items.clear()
	game.encounter = "trader"
	game.trader_stock.clear()
	game.world_map.encounter_node.visible = true
	game.run_gold = 60
	game.builds.assign(["幸运硬币"])
	game.player._recompute_stats()
	game._encounter_greeted = false
	game._open_encounter()
	check("meeting him opens his shop and 幸运硬币 pays 2 赤金", game.modal == "trader" and game.gold_bars() == 62)
	game._open_encounter()
	check("the coin pays once per encounter", game.gold_bars() == 62)
	var stock := game.trader_stock
	check("eight slots: two relics, then gear, two flasks, one special slot", stock.size() == 8 and stock[0].kind == "relic" and stock[1].kind == "relic"
		and stock.slice(2, 5).all(func(e): return e.item.is_equippable()) and stock[5].item.is_potion() and stock[6].item.is_potion())
	check("relics cost their 集成战略 shop price (8 / 12 / 16 赤金)", int(stock[0].price) == [8, 12, 16][stock[0].relic.rarity])
	check("gear costs 价值 × 150% ÷ 10, rounded up", int(stock[2].price) == maxi(1, ceili(stock[2].item.value * 1.5 / 10.0)))
	var relic_id: String = stock[0].relic.id
	check("buying a relic takes it at once", game.trader_buy(0) and game.builds.has(relic_id) and game.gold_bars() == 62 - int(stock[0].price))
	check("a sold slot cannot be bought again", game.trader_buy_refusal(0) == "已售出")
	var bars := game.gold_bars()
	check("buying gear puts it in the pack", game.trader_buy(2) and game.inventory.items.has(stock[2].item) and game.gold_bars() == bars - int(stock[2].price))
	bars = game.gold_bars()
	var cost := game.trader_reroll_cost()
	check("refresh costs 3, then 6, and rolls a new shelf", cost == 3 and game.trader_reroll() and game.trader_reroll_cost() == 6 and game.gold_bars() == bars - 3 and not game.trader_stock[0].sold)
	var blade := Item.create("卖掉的刀", Item.Category.WEAPON, 2, 1, 1.0)
	blade.value = 40
	game.inventory.try_add(blade)
	bars = game.gold_bars()
	check("he buys gear at 交付价 × 50%", game.trader_offer(blade) == 2 and game.trader_sell(blade) and not game.carried_items().has(blade) and game.gold_bars() == bars + 2)
	var flask := BaseCatalog.create_potion("A")
	var insured := Item.create("投保的甲", Item.Category.ARMOR, 1, 1, 1.0)
	insured.insured = true
	check("not flasks, 原矿, insured gear or 赤金", game.trader_offer(flask) == 0 and game.trader_offer(FieldCatalog.exclusive("mine")) == 0
		and game.trader_offer(insured) == 0 and game.trader_offer(MaterialCatalog.create(Economy.GOLD_ID, 5)) == 0)
	game.builds.assign(["锈蚀的铁锤"])
	game.player._recompute_stats()
	game.trader_stock.clear()
	game._roll_trader_stock()
	check("锈蚀的铁锤 halves his relic prices", int(game.trader_stock[0].price) == [4, 6, 8][game.trader_stock[0].relic.rarity])
	game.menu.show_trader()
	check("the shop menu opens", game.menu.visible)
	game.builds.clear()
	game.player._recompute_stats()
	game.close_modal()
	game.settle(true)
	await step(2)

## Esc goes back one level; with nothing open it pauses (用户 2026-10-06).
func _escape() -> void:
	if not game.in_base:
		game.settle(true)
		await step(2)
	game.close_modal()
	check("Esc in the base opens pause", (func(): game.go_back(); return game.modal == "pause").call())
	game.go_back()
	check("Esc again resumes", game.modal.is_empty())
	game.open_station("contracts")
	game._pending_start_camp = 0
	game.menu.show_departure("city")
	game.menu.back_to = func(): game.open_station("contracts")
	game.go_back()
	check("Esc from departure returns to the dispatch board", game.modal == "station" and game.menu._station == "contracts")
	game.go_back()
	check("Esc from a station closes it", game.modal.is_empty())
	await game.start_contract("city")
	await step(2)
	game.toggle_panel("inventory")
	game.go_back()
	check("Esc closes the inventory", game.modal.is_empty() and not game._inventory_panel.visible)
	game.go_back()
	check("Esc in the field pauses", game.modal == "pause")
	game.go_back()
	check("and resumes", game.modal.is_empty())
	game.floor_number = 10
	game._enter_camp()
	game.go_back()
	check("Esc in a camp pauses over it", game.modal == "pause")
	game.go_back()
	check("closing pause returns to the camp", game.modal == "camp")
