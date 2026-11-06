extends SceneTree
## 势力声望解锁策划案 v0.1 (用户 2026-11-02 拍板): prices by rank and the shelf
## floor, specials off their door, 冷漠, where each faction starts, the gifts
## on first reaching a rank, the 崇敬 goods, the 崇拜 badges and the posts.
var game: GameManager
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool, detail: Variant = "") -> void:
	checks += 1
	print(("PASS " if passed else "FAIL ") + label + ("" if passed or str(detail).is_empty() else "  [%s]" % str(detail)))
	if not passed: failures += 1

func rank(faction: String, r: int) -> void:
	game.exchange.relations[faction] = int(Exchange.RANK_AT[r])

func near(a: float, b: float, tol: float = 0.011) -> bool:
	return absf(a - b) <= tol * maxf(absf(b), 1.0)

func run() -> void:
	MarketState.tz_override = 0
	BaseState.frozen_clock = 1791972000
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	game.fixed_market_seed = 77
	root.add_child(game)
	await step(8)
	game.seed_rng(5)
	game.gold = 5000000
	_prices()
	_cold()
	_specials()
	_start()
	_gifts()
	_badges()
	_goods()
	await _floor_kits()
	_posts()
	_save()
	print("FACTION REWARDS RESULT: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await step(2)
	quit(1 if failures else 0)

# --- §2.1 ----------------------------------------------------------------------------------

func _prices() -> void:
	var ex := game.exchange
	var plate := MaterialCatalog.create("金属板", 1)
	rank("kazimierz", 1)
	var mid_buy := float(ex.quote_buy("kazimierz", "螺栓").unit)
	var mid_sell := float(ex.quote_sell(plate, "kazimierz", false).net)
	rank("kazimierz", 5)
	var top_sell := float(ex.quote_sell(plate, "kazimierz", false).net)
	check("崇拜 pays 5% more than 中立", near(top_sell, mid_sell * 1.05), [mid_sell, top_sell])
	rank("kazimierz", 0)
	check("冷漠 pays 5% less", near(float(ex.quote_sell(plate, "kazimierz", false).net), mid_sell * 0.95))
	check("and asks 5% more", near(float(ex.quote_buy("kazimierz", "螺栓").unit), mid_buy * 1.05))
	# The floor: the discount stops at its own bid × 1.01, and never lifts a price.
	var ok := true
	var bad := []
	for f in FactionCatalog.trading():
		for m in FactionSpecials.plain_shelf(f):
			if not MaterialCatalog.MATERIALS.has(m) or Packs.is_pack(m): continue
			rank(f, 1)
			var mid := ex.quote_buy(f, m)
			rank(f, 5)
			var q := ex.quote_buy(f, m)
			var s := ex.quote_sell(MaterialCatalog.create(m, 1), f, false)
			if not (q.ok and mid.ok): continue
			if float(q.unit) > float(mid.unit) + 0.001 or (s.ok and float(q.unit) < minf(float(mid.unit), float(s.net) * 1.01) - 0.01):
				ok = false
				bad.append([f, m, mid.unit, q.unit, s.get("net", 0)])
		rank(f, 1)
	check("at 崇拜: never above 中立's price, never below its own bid × 1.01", ok, bad)
	# A wide spread (鼠王 10%) leaves the discount whole.
	rank("rat", 1)
	var rat_mid := float(ex.quote_buy("rat", "装置").unit)
	rank("rat", 5)
	check("鼠王 at 崇拜: 装置 12% off", near(float(ex.quote_buy("rat", "装置").unit), rat_mid * 0.88), [rat_mid, ex.quote_buy("rat", "装置").unit])
	rank("rat", 1)

# --- §2.5 ----------------------------------------------------------------------------------

func _cold() -> void:
	rank("lungmen", 0)
	check("冷漠 opens no forwards", game.exchange.forward_refusal("lungmen", 1) == "需要关系 中立")
	rank("lungmen", 1)
	check("中立 does", game.exchange.forward_refusal("lungmen", 1).is_empty())

# --- §2.2 ----------------------------------------------------------------------------------

func _specials() -> void:
	var ex := game.exchange
	rank("karlan", 3)
	check("a special at its door: full price", ex.special_mult("karlan", "高能燃料") == 1.0)
	rank("karlan", 4)
	check("one rank above: −10%", near(ex.special_mult("karlan", "高能燃料"), 0.9, 0.0001))
	rank("karlan", 5)
	check("two above: −20%", near(ex.special_mult("karlan", "高能燃料"), 0.8, 0.0001))
	rank("penguin", 2)
	var slip := game.slip_price()
	rank("penguin", 4)
	check("企鹅专递单 two ranks up: −20%%: %d" % game.slip_price(), game.slip_price() == roundi(FactionSpecials.SLIP_PRICE * 0.8) and slip == FactionSpecials.SLIP_PRICE)
	rank("penguin", 1)
	rank("karlan", 1)

# --- §2.6 ----------------------------------------------------------------------------------

func _start() -> void:
	var fresh := Exchange.new()
	fresh.load_data({})
	check("a new account starts by each faction's attitude: 喀兰/萨米 友好, 龙门 中立, 乌萨斯/整合 冷漠",
		fresh.rank("karlan") == 2 and fresh.rank("sami") == 2 and fresh.rank("lungmen") == 1 and fresh.rank("ursus") == 0 and fresh.rank("reunion") == 0, fresh.relations)
	check("…and gets no gift for where it starts", fresh.rank_gifts.get("karlan", []) == [2] and fresh.rank_gifts.get("ursus", []).is_empty())
	var old := Exchange.new()
	old.load_data({"relations": {"karlan": 2000, "ursus": 30}, "relation_scale": Exchange.RELATION_SCALE})
	check("an old save is raised to the start, never lowered", old.relation("karlan") == 2000 and old.relation("sami") == 500 and old.relation("ursus") == 30)

# --- §2.4 ----------------------------------------------------------------------------------

func _gifts() -> void:
	var ex := game.exchange
	ex.rank_gifts.erase("ursus")
	ex.relations["ursus"] = Exchange.RANK_AT[2] - 1
	var plain: Array = FactionSpecials.plain_shelf("ursus").filter(func(m): return MaterialCatalog.MATERIALS.has(m))
	plain.sort_custom(func(a, b): return MaterialCatalog.create(a, 1).unit_value < MaterialCatalog.create(b, 1).unit_value)
	var before := {}
	for m in plain.slice(0, 2): before[m] = game.material_count(m)
	ex.add_relation("ursus", 1)
	check("友好 sends its two cheapest goods ×5", before.keys().all(func(m): return game.material_count(m) == int(before[m]) + FactionRewards.FRIEND_COUNT), before)
	var flux := game.material_count("高纯源岩助熔剂")
	ex.add_relation("ursus", Exchange.RANK_AT[3] - Exchange.RANK_AT[2])
	check("尊敬 sends its special", game.material_count("高纯源岩助熔剂") == flux + 1)
	var account := ex.gold_account
	ex.add_relation("ursus", Exchange.RANK_AT[4] - Exchange.RANK_AT[3])
	check("崇敬 sends 30,000 龙门币 worth in its currency (赤金账户)", ex.gold_account > account)
	ex.add_relation("ursus", Exchange.RANK_AT[5])
	check("崇拜 sends its badge", game.material_count("矿场主事铭牌") == 1 and ex.rank_gifts.ursus == [2, 3, 4, 5])
	ex.relations["ursus"] = Exchange.RANK_AT[3]
	ex.add_relation("ursus", Exchange.RANK_AT[5])
	check("winning a rank back sends nothing again", game.material_count("矿场主事铭牌") == 1)
	# A higher door: 卡西米尔's patent comes at 崇敬, 莱茵's 变种种子 at 崇拜 — once each.
	check("骑士工坊专利授权 waits for its door", not FactionRewards.gift("kazimierz", 3).has("骑士工坊专利授权") and FactionRewards.gift("kazimierz", 4).has("骑士工坊专利授权"))
	for pair in [["kazimierz", "骑士工坊专利授权"], ["rhine", "闪耀作物·变种种子"]]:
		var f: String = pair[0]
		var m: String = pair[1]
		var held := game.material_count(m)
		var hits := 0
		for r in range(2, 6): hits += int(FactionRewards.gift(f, r).get(m, 0))
		ex.rank_gifts.erase(f)
		ex.relations[f] = 0
		ex.add_relation(f, Exchange.RELATION_MAX)
		ex.relations[f] = 0
		ex.add_relation(f, Exchange.RELATION_MAX)
		check("%s is sent once, however often the ranks are won" % m, hits == 1 and game.material_count(m) == held + 1, [hits, game.material_count(m) - held])
		ex.relations[f] = Exchange.RANK_AT[1]
	check("龙门商会's 尊敬 brings 玄纹墨", FactionRewards.gift("lungmen", 3).has("玄纹墨"))

# --- §三 badges -----------------------------------------------------------------------------

func _badges() -> void:
	rank("ursus", 5)
	check("the badge works in the warehouse at 崇拜", FactionRewards.badge_on(game, "ursus"))
	var slots := game.workshop_slots()
	rank("ursus", 4)
	check("still at 崇敬", FactionRewards.badge_on(game, "ursus") and game.workshop_slots() == slots)
	rank("ursus", 3)
	check("not below 崇敬: 加工部 loses its queue", not FactionRewards.badge_on(game, "ursus") and game.workshop_slots() == slots - 1)
	check("badges are not sold", FactionCatalog.category_of(MaterialCatalog.create("矿场主事铭牌", 1)).is_empty() and game.trader_offer(MaterialCatalog.create("矿场主事铭牌", 1)) == 0)
	rank("ursus", 1)
	game.base.receive(MaterialCatalog.create("喀兰贸易金卡", 1))
	rank("karlan", 5)
	if game.voyage.place() != FactionRewards.KARLAN_PORT: check("喀兰贸易金卡: 谢拉格 is free", game.voyage.voyage_cost(FactionRewards.KARLAN_PORT, "standard") == 0)
	game.base.receive(MaterialCatalog.create("骑士竞技场赞助证", 1))
	rank("kazimierz", 5)
	check("骑士竞技场赞助证 halves the CFD fee", near(game.exchange.cfd_fee(), Exchange.CFD_FEE * 0.5, 0.0001))
	game.base.receive(MaterialCatalog.create("莱茵合作研究员证", 1))
	rank("rhine", 5)
	check("莱茵合作研究员证: crops −20%", game.provisions.grow_seconds("舰载麦") == roundi(2 * 3600 * 0.8))
	for f in ["karlan", "kazimierz", "rhine"]: rank(f, 1)

# --- §三 goods ------------------------------------------------------------------------------

func _goods() -> void:
	var ex := game.exchange
	rank("lungmen", 3)
	check("崇敬 goods wait for 崇敬", ex.quote_buy("lungmen", "近卫局通行证").why == "需要关系 崇敬")
	rank("lungmen", 4)
	check("then its shelf sells them", ex.quote_buy("lungmen", "近卫局通行证").ok)
	check("every good and badge is a material with an icon", (FactionRewards.GOODS.keys() + FactionRewards.BADGES.values()).all(func(m): return MaterialCatalog.MATERIALS.has(m) and ItemIcons.MATERIALS.has(m)))
	check("every good is on its faction's shelf (企鹅物流 at its desk)", FactionRewards.GOODS.keys().all(func(m): return FactionRewards.GOODS[m][0] == "penguin" or m in FactionCatalog.info(FactionRewards.GOODS[m][0]).sells))
	rank("rhine", 4)
	game.base.set_facility("exchange", 1)
	ex.credit("col", 100000.0)
	var flasks := game.base.stock().filter(func(i): return i.potion_type == "rhine").size()
	check("莱茵实验抑制剂 arrives as a flask", ex.buy_material("rhine", "莱茵实验抑制剂", 1) and game.base.stock().filter(func(i): return i.potion_type == "rhine").size() == flasks + 1)
	rank("rhine", 1)
	rank("penguin", 3)
	check("加急专递单 from 崇敬", game.express_refusal() == "需要关系 崇敬")
	rank("penguin", 4)
	var express := game.material_count(FactionRewards.EXPRESS)
	check("bought at 企鹅物流's desk", game.buy_express() and game.material_count(FactionRewards.EXPRESS) == express + 1)
	var wait := game._queue_insured(Item.create("测试刀", Item.Category.WEAPON, 1, 2, 1.0))
	check("an insured piece comes back in half the time (%d s)" % wait, wait <= FieldCatalog.INSURANCE_DELAY_SECONDS.y / 2 + 1 and game.material_count(FactionRewards.EXPRESS) == express)
	rank("penguin", 1)
	check("冰原熏肉 is eaten like a meal", Provisions.MEALS.has("冰原熏肉") and Provisions.BOUGHT_MEALS.has("冰原熏肉"))

func _floor_kits() -> void:
	await game.start_contract("city")
	await step(2)
	game.inventory.add_stack(MaterialCatalog.create("近卫局通行证", 2))
	game.inventory.add_stack(MaterialCatalog.create("矿场勘探图", 1))
	game._use_floor_kits()
	check("on a 龙门 floor the pass is used, one of two", game.floor_kit_on("近卫局通行证") and game.carried_count("近卫局通行证") == 1)
	check("the mine's survey map is kept", not game.floor_kit_on("矿场勘探图") and game.carried_count("矿场勘探图") == 1)
	game.floor_kits = {"残党暗号": 1}
	var wave := game.threat.wave
	var enemies := game.get_children().filter(func(n): return n is Enemy).size()
	game._spawn_patrol()
	check("残党暗号 turns the first patrol away", game.floor_kits["残党暗号"] == 2 and game.get_children().filter(func(n): return n is Enemy).size() == enemies and game.threat.wave == wave + 1)
	game.floor_kits = {}
	game.potion_fx.apply("rhine")
	check("莱茵实验抑制剂 stops contamination", game.potion_fx.contam_mult() == 0.0 and game.contamination_rate() == 0.0)
	game.run_contamination = 50.0
	game.potion_fx.tick(61.0)
	check("…and takes 20 off at the end", near(game.run_contamination, 30.0, 0.001) and game.potion_fx.contam_mult() == 1.0)
	game.settle(true)
	await step(2)

# --- §四 -------------------------------------------------------------------------------------

func _posts() -> void:
	rank("ursus", 2)
	check("posts below 尊敬 carry their shelf", FactionRewards.post_extra("ursus", 2).is_empty())
	rank("ursus", 3)
	check("from 尊敬 two more", FactionRewards.post_extra("ursus", 3).size() == 2 and game.exchange.quote_buy("ursus", "异铁组").ok)
	check("posts come more often by rank", FactionRewards.POST_ODDS[4] > FactionRewards.POST_ODDS[2] and FactionRewards.POST_ODDS[2] > FactionRewards.POST_ODDS[1])
	rank("ursus", 1)

func _save() -> void:
	var data := game.exchange.to_data()
	var copy := Exchange.new()
	copy.game = game
	copy.load_data(JSON.parse_string(JSON.stringify(data)))
	check("the gifts sent are saved", (copy.rank_gifts.get("ursus", []) as Array).size() == 4)
