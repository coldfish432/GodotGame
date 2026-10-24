extends SceneTree
## Trade packs (交易所交易包修订案_v1_0.md): packing by value and one-key
## packing, unpacking by points, 可露希尔's 代售 by anchor, the migration.
var game: GameManager
var failures := 0
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool) -> void:
	print(("PASS " if passed else "FAIL ") + label)
	if not passed: failures += 1

func stash_add(item: Item) -> Item:
	game.base.shelf.append(item)
	return item

func gear(category: int, value: int, rarity: int = 0) -> Item:
	var item := Item.create("测试装备%d" % value, category as Item.Category, 1, 2)
	item.value = value
	item.rarity = rarity
	return item

## The least spill any choice of whole units can reach for one pack (small pools).
func best_spill(units: Array, face: int) -> int:
	var best := 1 << 30
	for mask in range(1, 1 << units.size()):
		var total := 0
		for i in range(units.size()):
			if mask & (1 << i): total += int(units[i])
		if total >= face: best = mini(best, total - face)
	return best

func run() -> void:
	MarketState.tz_override = 0
	BaseState.frozen_clock = 1791972000
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	game.fixed_market_seed = 77
	root.add_child(game)
	await step(8)
	game.rng.seed = 77
	game.gold = 500000
	# --- The packs ------------------------------------------------------------------
	check("twelve packs, one per category", Packs.ORDER.size() == 12 and Packs.PACKS.size() == 12)
	var cats := {}
	for pack in Packs.ORDER:
		cats[Packs.category_of(pack)] = true
		check("%s is a material of its category" % pack, MaterialCatalog.MATERIALS.has(pack) and FactionCatalog.material_category(pack) == Packs.category_of(pack)
			and MaterialCatalog.create(pack, 1).unit_value == Packs.face(pack))
	check("every market category has a pack", FactionCatalog.CATEGORIES.keys().all(func(c): return cats.has(c)))
	check("gear, contraband and crop packs do not open", not Packs.can_open("武器包") and not Packs.can_open("违禁品包") and not Packs.can_open("作物包") and Packs.can_open("建材包"))
	# 作物包 (用户 2026-10-23): crops go one way, at about delivery price.
	check("crops go into 作物包, 补给 into 医疗包", Packs.pack_for(FactionCatalog.category_of(MaterialCatalog.create("舰载麦", 1))) == "作物包"
		and Packs.pack_for(FactionCatalog.category_of(MaterialCatalog.create("舰内口粮", 1))) == "医疗包")
	check("nobody sells 作物包", FactionCatalog.ORDER.all(func(f): return not FactionCatalog.packs_sold(f).has("作物包")))
	for f in FactionCatalog.trading():
		var p := FactionCatalog.preference(f, "crop")
		if p > 0.0: check("%s takes crops below its medical rate: %.2f" % [f, p], p < 1.0 and not FactionCatalog.info(f).get("field_only", false))
	check("a pack is never packed again; 赤金 and flasks neither", not Packs.packable(MaterialCatalog.create("建材包", 1)) and not Packs.packable(MaterialCatalog.create(Economy.GOLD_ID, 1)))
	check("势力特供 do not go into packs", not Packs.packable(MaterialCatalog.create("高能燃料", 1)))
	var insured := gear(Item.Category.WEAPON, 100)
	insured.insured = true
	check("insured gear does not go into packs", not Packs.packable(insured))
	check("特产 do (原矿 into 违禁品包)", Packs.packable(FieldCatalog.exclusive("mine")) and FactionCatalog.category_of(FieldCatalog.exclusive("mine")) == "contraband")
	# --- One-key packing picks: as little spill as the best whole-unit choice ---
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var worst := 0
	for trial in range(40):
		var pool: Array = []
		var units: Array = []
		for k in range(rng.randi_range(4, 9)):
			var g := gear(Item.Category.WEAPON, rng.randi_range(20, 260))
			pool.append(g)
			units.append(g.value)
		var plan := Packs.auto_pick("武器包", pool, 1)
		if int(plan.packs) == 0: continue
		worst = maxi(worst, int(plan.overflow) - best_spill(units, Packs.face("武器包")))
	check("one-key spill is within 5 points of the best: worst +%d" % worst, worst <= 5)
	var top := gear(Item.Category.WEAPON, 500, 2)
	check("one-key packing leaves top-quality gear alone", int(Packs.auto_pick("武器包", [top], 1).packs) == 0 and int(Packs.auto_pick("武器包", [top], 1, false).packs) == 1)
	# --- Packing at the 加工部 ------------------------------------------------------
	var bolts := stash_add(MaterialCatalog.create("螺栓", 20))       # ★1, 4 points each
	var plates := stash_add(MaterialCatalog.create("金属板", 20))    # ★2, 8 points each
	check("the most packs from the shelf: %d" % Packs.max_packs("建材包", game.stash), Packs.max_packs("建材包", game.stash) == (20 * 4 + 20 * 8) / 100)
	var lmd := game.gold
	check("one-key packing queues the packs and charges %d each" % Packs.PACK_LMD, game.pack_quick("建材包", 2) and game.gold == lmd - 2 * Packs.PACK_LMD and game.workshop.jobs.size() == 1)
	check("it took the cheap bolts first and spilled little: %d 金属板 left" % plates.quantity, not game.stash.has(bolts) and plates.quantity >= 20 - 16)
	var packed := game.material_count("建材包")
	BaseState.clock_offset += 300
	game._tick_workshop()
	check("the packs go straight into the warehouse (仓库修订)", game.material_count("建材包") == packed + 2)
	game.workshop.jobs.clear()
	var a := stash_add(gear(Item.Category.ARMOR, 300))
	var b := stash_add(gear(Item.Category.ARMOR, 150))
	var c := stash_add(gear(Item.Category.ARMOR, 50))
	check("by hand: pieces fill packs in order, the spill is lost, the rest stays", game.pack_manual("防具包", [a, b, c]) and not game.stash.has(a) and not game.stash.has(b) and game.stash.has(c))
	game.workshop.jobs.clear()
	check("not enough for one pack refuses", game.pack_refusal("饰品包", 1) == "货不够")
	# --- Unpacking ------------------------------------------------------------------
	var list := Packs.open_list("寒地物资包")
	check("寒地物资包 opens into 帆布, not 特产 or 萨米 goods", list.has("帆布") and not list.has("鞣制兽皮") and not list.has("林地草药"))
	check("no 特供, crops or packs on any list", Packs.ORDER.all(func(p): return Packs.open_list(p).all(func(id): return not FactionSpecials.is_special(id) and not Packs.is_pack(id) and str(MaterialCatalog.MATERIALS[id].get("source", "")) != "farm")))
	stash_add(MaterialCatalog.create("建材包", 2))
	var pick := {"金属板": 11}       # 9 points each (8 × 1.1, up)
	check("a pick costs value × 1.1 in points: %d" % Packs.pick_cost("建材包", pick), Packs.pick_cost("建材包", pick) == 99)
	check("more than the pack refuses", game.unpack_refusal("建材包", {"金属板": 12}) == "点数不足")
	var plates_before := game.material_count("金属板")
	var packs_before := game.material_count("建材包")
	check("opening one pack puts the pick in the warehouse", game.unpack("建材包", pick) and game.material_count("建材包") == packs_before - 1 and game.material_count("金属板") == plates_before + 11)
	check("the point left waits for the next pack of its kind", int(game.workshop.points.get("build", 0)) == 1 and game.open_points("建材包") == 101)
	check("gear packs never open", game.unpack_refusal("武器包", {}) == "拆不开")
	# Packing then opening always loses.
	var value_in := 0
	var pool2: Array = []
	for id in ["螺栓", "金属板", "钉子"]:
		var s := MaterialCatalog.create(id, 20)
		pool2.append(s)
		value_in += Packs.points(s)
	var made := Packs.auto_pick("建材包", pool2, 99)
	var points_back := int(made.packs) * Packs.face("建材包")
	var used := 0
	for item in made.take: used += Packs.unit_points(item) * int(made.take[item])
	check("the round trip loses: %d in, %d out at best" % [used, floori(points_back / Packs.OPEN_COST)], floori(points_back / Packs.OPEN_COST) < used)
	# --- 可露希尔's 代售 ------------------------------------------------------------
	var cs := game.consign
	game.base.ship_at = "萨米"
	game.voyage.sailing = {}
	check("at the base the market is where the ship lies", cs.anchor_here() == "萨米")
	game.voyage.sailing = {"to": "龙门", "start": BaseState.now(), "due": BaseState.now() + 3600}
	check("under way it is shut", cs.anchor_here() == "" and cs.goods("").is_empty())
	game.voyage.sailing = {}
	var shelf := cs.goods("萨米")
	check("萨米 sells its own gear only", shelf.filter(func(e): return e.kind == "gear").all(func(e): return Item.from_data(e.item).origin_region == "snow"))
	check("never the top quality or a named piece", shelf.filter(func(e): return e.kind == "gear").all(func(e): var it := Item.from_data(e.item); return it.rarity < 2 and it.named_kind().is_empty()))
	check("its 特产 is there", shelf.any(func(e): return e.kind == "specialty" and Item.from_data(e.item).effect == "frozen_relic"))
	check("its factions' goods are there", shelf.any(func(e): return e.kind == "loose" and Item.from_data(e.item).material_id == "林地草药"))
	check("卡西米尔 has no map: no gear, its 特供 instead", cs.goods("卡西米尔").all(func(e): return e.kind != "gear") and cs.goods("卡西米尔").any(func(e): return e.kind == "special"))
	check("the shelf stays within the hour", cs.goods("萨米") == shelf)
	BaseState.clock_offset += 3600
	check("and restocks on the next", cs.goods("萨米") != shelf)
	var wheat := MaterialCatalog.create("舰载麦", 6)
	var near := cs.sell_quote("龙门", wheat) / float(Economy.direct_price(wheat))
	check("she pays for crops about what delivery does: ×%.2f" % near, near > 0.9 and near < 1.1)
	check("龙门 is in 龙门币, the rest in 赤金", Consignment.currency("龙门") == "lmd" and Consignment.currency("萨米") == "gold")
	check("she takes loose goods and gear, never packs", Consignment.takes(MaterialCatalog.create("帆布", 2)) and Consignment.takes(gear(Item.Category.WEAPON, 50)) and not Consignment.takes(MaterialCatalog.create("建材包", 1)))
	# Prices follow the packs' books there.
	var canvas := MaterialCatalog.create("代糖", 4)
	game.market.books["sami:medical"].i = 1.0
	var p1 := cs.sell_quote("萨米", canvas)
	game.market.books["sami:medical"].i = 1.5
	check("loose prices follow the local pack book: %.2f → %.2f" % [p1, cs.sell_quote("萨米", canvas)], cs.sell_quote("萨米", canvas) > p1 * 1.4)
	game.market.books["sami:medical"].i = 1.0
	check("叙拉古 has no exchange faction: everyone's average", cs.index("叙拉古", "medical") > 0.0)
	check("buying costs more than selling", cs.buy_quote("萨米", {"kind": "loose", "item": canvas.to_data()}) > cs.sell_quote("萨米", canvas))
	# Buying and selling at the base.
	game.base.ship_at = "龙门"
	var goods := cs.goods("龙门")
	var i := goods.find(goods.filter(func(e): return e.kind == "loose")[0])
	lmd = game.gold
	check("buying at the base pays 龙门币 in 龙门", game.consign_buy(i) and game.gold < lmd and cs.goods("龙门")[i].sold)
	check("a sold entry cannot be bought again", cs.buy_refusal("龙门", i) == "已售出")
	var sell_me := MaterialCatalog.create("糖", 5)
	game.inventory.add_stack(sell_me)
	lmd = game.gold
	var offer := game.consign_offer(sell_me)
	check("selling to her pays 龙门币: %s" % offer, not offer.is_empty() and game.consign_sell(sell_me) and game.gold > lmd)
	# In a camp: the map's market, whatever the ship does.
	await game.start_contract("snow")
	await step(4)
	game.voyage.sailing = {"to": "龙门", "start": BaseState.now(), "due": BaseState.now() + 3600}
	check("in a camp the market is the map's, even under way", game.consign.anchor_here() == "萨米")
	game.voyage.sailing = {}
	game.give_gold_bars(200)
	var camp_goods := game.consign.goods("萨米")
	var gi := camp_goods.find(camp_goods.filter(func(e): return e.kind == "gear")[0]) if camp_goods.any(func(e): return e.kind == "gear") else -1
	var bars := game.gold_bars()
	var want := Consignment.whole("gold", game.consign.buy_quote("萨米", camp_goods[gi]), true) if gi >= 0 else 0
	check("gear is a new source: bought for whole bars from the pack", gi >= 0 and game.consign_buy(gi) and game.gold_bars() == bars - want)
	game.settle(true)
	await step(2)
	# --- Keys, tabs, migration ------------------------------------------------------
	check("one-key packing has its key (P)", Keybinds.ids().has("quick_pack"))
	game.open_station("workshop")
	game.menu.open_quick_pack()
	check("P opens no window over the workshop (its page has the form)", not is_instance_valid(game.menu.quick_pack_panel))
	game.close_modal()
	game.open_station("stash")
	game.menu.open_quick_pack()
	check("P opens the window over the warehouse console", is_instance_valid(game.menu.quick_pack_panel))
	game.menu.close_quick_pack()
	game.close_modal()
	check("可露希尔's 代售 is the second tab at the base and in a camp", EventScreens.CLOSURE_TABS_BASE[1] == "代售" and EventScreens.CLOSURE_TABS_CAMP[1] == "代售")
	var old := MaterialCatalog.create("工业补给箱", 1)
	game.base.shelf.append(old)
	game._migrate_trade_crates()
	check("an old trade crate becomes a 建材包 where it lies", old.material_id == "建材包" and game.base.shelf.has(old) and old.unit_value == Packs.face("建材包"))
	var ex := game.exchange
	ex.packs_version = 0
	ex.forwards.append({"id": 9001, "dir": "deliver", "faction": "lungmen", "material": "螺栓", "count": 5, "k": 30.0, "margin": 50.0, "opening": 50.0,
		"lev": 1, "currency": "lmd", "expires": game.market.t + 3600, "opened": game.market.t, "warned": false, "auto": 0.0})
	ex.cfds.append({"id": 9002, "underlying": "kazimierz:trade", "issuer": "karlan", "dir": 1, "lev": 1, "margin": 5.0, "opening": 5.0, "notional": 5.0,
		"entry": 100.0, "currency": "gold", "opened": game.market.t, "tp": 0.0, "sl": 0.0, "warned": false, "auto": 0.0})
	ex.watch.assign(["kazimierz:trade", "fx"])
	var acct := ex.gold_account
	lmd = game.gold
	ex.migrate_packs()
	check("migration closes loose forwards at today's price, no default", ex.forwards.is_empty() and game.gold >= lmd and not ex.history.any(func(h): return h.kind == "default" and h.what.begins_with("螺栓")))
	check("CFDs on the old 贸易品 books give the margin back", ex.cfds.is_empty() and absf(ex.gold_account - acct - 5.0) < 0.01)
	check("the watch list keeps live books only", ex.watch == ["fx"])
	check("it runs once", ex.packs_version == 1)
	var copy := Exchange.new()
	copy.load_data({"gold_account": 1.0})
	check("an old account loads as unmigrated, a new one as packs", copy.packs_version == 0)
	print("TEST_PACKS: %d failures" % failures)
	quit(1 if failures > 0 else 0)
