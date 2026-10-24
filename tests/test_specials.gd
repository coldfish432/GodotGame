extends SceneTree
## 势力特供策划案_v0_2: the faction specials — each sold by one faction from a
## relation rank, used up in one department — and the second deck: 农业部's
## swirl of basins growing in real time, 食堂's kitchen and 补给, the meal's
## effect on a contract and on the Rhodes squads, 企鹅物流's cold chain, the
## lift, the rooms and their construction.
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

func later(seconds: int) -> void:
	BaseState.clock_offset += seconds

func rank(faction: String, r: int) -> void:
	game.exchange.relations[faction] = int(Exchange.RANK_AT[r])

func give(material: String, count: int) -> void:
	var left := count
	while left > 0:
		var stack := MaterialCatalog.create(material, left)
		left -= stack.quantity
		game.base.shelf.append(stack)

func run() -> void:
	MarketState.tz_override = 0
	BaseState.frozen_clock = 1791972000
	_geometry()
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	game.fixed_market_seed = 77
	root.add_child(game)
	await step(8)
	game.rng.seed = 5
	game.gold = 5000000
	_catalog()
	_voyage_fuel()
	_rumor_ears()
	_workshop_flux()
	_research_patent()
	_medical_moss()
	_farm()
	_kitchen_and_meals()
	await _contract_meal_and_squad()
	await _field_slip_and_guide()
	_save()
	await _scene()
	print("SPECIALS RESULT: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await step(2)
	quit(1 if failures else 0)

# --- The swirl (§4.1) ---------------------------------------------------------------------

func _geometry() -> void:
	var cells := {}
	var overlap := false
	for i in range(Provisions.SWIRL_BASINS):
		var r := Provisions.basin_rect(i)
		if not (r.size == Vector2(1, 4) or r.size == Vector2(4, 1)): overlap = true
		for x in range(int(r.position.x), int(r.end.x)):
			for z in range(int(r.position.y), int(r.end.y)):
				if cells.has(Vector2i(x, z)): overlap = true
				cells[Vector2i(x, z)] = i
	# Cells by their lower corner: the lamp's is (−0.5, −0.5) → (−1, −1) after floor.
	var cells2 := {}
	for i in range(Provisions.SWIRL_BASINS):
		var r := Provisions.basin_rect(i)
		for x in range(roundi(r.position.x + 0.5), roundi(r.end.x + 0.5)):
			for z in range(roundi(r.position.y + 0.5), roundi(r.end.y + 0.5)):
				cells2[Vector2i(x, z)] = i
	var empty := [Vector2i(0, 0), Vector2i(-2, 1), Vector2i(1, 2), Vector2i(2, -1), Vector2i(-1, -2)]
	check("24 basins of 1×4, no overlap, 96 tiles; the lamp and four single tiles inside stay free (RimWorld's room)",
		not overlap and cells2.size() == 96 and empty.all(func(c): return not cells2.has(c)), cells2.size())
	var inside := cells2.keys().all(func(c): return absi(c.x) <= 5 and absi(c.y) <= 5)
	var corners := [Vector2i(-5, 5), Vector2i(5, 5), Vector2i(5, -5), Vector2i(-5, -5)]
	check("all inside the 11×11 room, its corners free", inside and corners.all(func(c): return not cells2.has(c)))
	# The swirl: each group is the last turned 90° about the lamp.
	var turned := true
	for i in range(Provisions.GROUP):
		var a := Provisions.basin_rect(i).get_center()
		var b := Provisions.basin_rect(i + Provisions.GROUP).get_center()
		if not b.is_equal_approx(Vector2(a.y, -a.x)): turned = false
	check("group 2 is group 1 turned a quarter about the lamp (a swirl)", turned)
	var same := true
	for i in range(Provisions.SWIRL_BASINS):
		if Provisions.basin_rect(i) != Provisions.basin_rect(i + Provisions.SWIRL_BASINS * 2) or Provisions.swirl_of(i + Provisions.SWIRL_BASINS * 2) != 2: same = false
	check("three swirls of the same 24, 72 basins (用户: 可以多放几组水培)", same and Provisions.BASINS == 72)

# --- §二 ---------------------------------------------------------------------------------

func _catalog() -> void:
	var sold := true
	for m in FactionSpecials.ITEMS:
		if not MaterialCatalog.MATERIALS.has(m) or not ItemIcons.MATERIALS.has(m): sold = false
		var f := FactionSpecials.faction_of(m)
		if f != "penguin" and not m in FactionCatalog.info(f).get("sells", []): sold = false
	check("every special is a material with an icon, on its own faction's shelf", sold)
	check("seven departments plus the farm: voyage, exchange, workshop, medical, lab, warehouse, field",
		FactionSpecials.ITEMS.values().map(func(e): return e[2]).filter(func(d): return d != "farm").size() == 7)
	rank("karlan", 2)
	var q := game.exchange.quote_buy("karlan", "高能燃料")
	check("below its rank a special is not sold: %s" % q.why, not q.ok and q.why == "需要关系 R3")
	rank("karlan", 3)
	check("from R3 喀兰 sells 高能燃料", game.exchange.quote_buy("karlan", "高能燃料").ok)
	check("plain goods need no rank", game.exchange.quote_buy("karlan", "帆布").ok)
	rank("rat", 2)
	rank("lungmen", 2)
	var before := game.exchange.relation("lungmen")
	game.exchange.credit("lmd", 100000.0)
	check("buying 下城区耳目 from the rat king", game.exchange.buy_material("rat", "下城区耳目", 1))
	check("costs 5 relation with 龙门商会", game.exchange.relation("lungmen") == before - FactionSpecials.RAT_RIVAL_COST, [before, game.exchange.relation("lungmen")])
	var leaked := false
	for f in FactionCatalog.ORDER:
		for m in FactionSpecials.plain_shelf(f) + game.exchange.forward_materials(f):
			if FactionSpecials.is_special(m): leaked = true
	check("no special in flash sales or forwards (they skip the rank)", not leaked)
	check("specials are not bought back; crops are their own goods, 补给 medical",
		FactionCatalog.material_category("高能燃料") == "" and FactionCatalog.material_category("舰载麦") == "crop" and FactionCatalog.material_category("食堂便当") == "medical")
	# 用户 2026-10-23: a basin of Rhodes' own crops delivers for about its seed × 1.25.
	for crop in ["舰载麦", "块茎薯", "温室豆"]:
		var c: Dictionary = Provisions.CROPS[crop]
		var margin := float(Economy.direct_price(MaterialCatalog.create(crop, 1)) * int(c.yield)) / float(c.seed_lmd) - 1.0
		check("%s pays about 25%% a basin: %+.1f%%" % [crop, margin * 100.0], absf(margin - 0.25) < 0.02)
	rank("sami", 2)
	check("萨米 barters no 冰原苔 below R3", game.barter_count(MaterialCatalog.create("帆布", 5), "萨米冰原苔") == 0)
	rank("penguin", 1)
	check("企鹅专递单 needs 企鹅物流 R2", game.slip_refusal() == "需要关系 R2")
	rank("penguin", 2)
	var slips := game.material_count("企鹅专递单")
	var gold := game.gold
	check("bought for 龙门币, delivered into the warehouse (仓库修订)", game.buy_slip() and game.gold == gold - FactionSpecials.SLIP_PRICE and game.material_count("企鹅专递单") == slips + 1)

func _voyage_fuel() -> void:
	var v := game.voyage
	var to := "萨米" if v.place() != "萨米" else "龙门"
	var standard := v.voyage_cost(to, "standard")
	check("with 高能燃料 全速 costs what 标准 does", v.voyage_cost(to, "fast", true) == standard, [v.voyage_cost(to, "fast", true), standard])
	check("and takes a quarter less time", absi(v.voyage_seconds(to, "fast", true) - roundi(v.voyage_seconds(to, "fast") * FactionSpecials.FUEL_TIME)) <= 1)
	check("not without one", v.voyage_refusal(to, "fast", true).begins_with("缺少"))
	give("高能燃料", 1)
	check("sailing on it uses it up", game.sail(to, "fast", true) and game.material_count("高能燃料") == 0 and bool(v.sailing.fuel))
	later(v.voyage_seconds(to, "fast", true) + 5)
	v.tick(BaseState.now())

func _rumor_ears() -> void:
	game.market.fire("C2")
	var headline: Dictionary = game.market.news.filter(func(n): return n.id == "C2")[-1]
	check("a rumor waits to be settled", headline.status == "待证实")
	# The one bought from the rat king went straight into the warehouse (仓库修订).
	for it in game.base.shelf.filter(func(i): return i.material_id == "下城区耳目"): game.base.remove_item(it)
	check("耳目 needs one in the warehouse", game.peek_refusal(headline).begins_with("缺少"))
	give("下城区耳目", 1)
	var truth := bool(game._rumor_of(headline).rumor.truth)
	check("下城区耳目 tells whether it is true before it settles", game.peek_rumor(headline) and headline.peek == ("属实" if truth else "不实") and game.material_count("下城区耳目") == 0)
	check("once a rumor", game.peek_refusal(headline) == "无法查证")

func _workshop_flux() -> void:
	var output: String = Workshop.RECIPES.keys()[0]
	for id in Workshop.cost_of(output, 4): give(id, int(Workshop.cost_of(output, 4)[id]))
	check("a job starts", game.workshop_start(output, 4))
	var job: Dictionary = game.workshop.jobs[-1]
	var by := 0
	for id in job.byproducts: by += int(job.byproducts[id])
	var left := int(job.due) - BaseState.now()
	give("高纯源岩助熔剂", 1)
	check("助熔剂 on it", game.use_flux(job))
	var by_after := 0
	for id in job.byproducts: by_after += int(job.byproducts[id])
	check("doubles its byproducts (one drawn if it had none): %d → %d" % [by, by_after], by_after == maxi(1, by) * 2)
	check("and cuts the rest of its time to 70%", absi(int(job.due) - BaseState.now() - roundi(left * FactionSpecials.FLUX_TIME)) <= 1)
	give("高纯源岩助熔剂", 1)
	check("once a job", game.flux_refusal(job) == "已使用")
	game.workshop.jobs.clear()

func _research_patent() -> void:
	game.base.set_facility("lab", 1)
	var id := ""
	for key in ResearchCatalog.NODES:
		if game.research.refusal(key).is_empty():
			id = key
			break
	if id.is_empty():
		for key in ResearchCatalog.NODES:
			if game.research.refusal(key).begins_with("缺少"):
				var cost: Dictionary = ResearchCatalog.materials(key)
				for m in cost: give(m, int(cost[m]))
				if game.research.refusal(key).is_empty():
					id = key
					break
	check("a research can start", not id.is_empty() and game.research.start(id), id)
	var left := game.research.seconds_left(id)
	give("骑士工坊专利授权", 1)
	check("专利授权 halves the rest of its time", game.use_patent(id) and absi(game.research.seconds_left(id) - roundi(left * 0.5)) <= 1)
	check("once a project", game.patent_refusal(id) == "已使用")
	game.base.research.active.clear()

func _medical_moss() -> void:
	game.base.injuries = {game.base.operator: 3, Operators.LAPPLAND: 1}
	give("萨米冰原苔", 1)
	var gold := game.gold
	check("萨米冰原苔 cures everyone, free", game.moss_cure() and game.base.injuries.is_empty() and game.gold == gold and game.material_count("萨米冰原苔") == 0)
	check("not with no one hurt", game.moss_refusal() == "无人负伤")

# --- 农业部 (§四) ---------------------------------------------------------------------------

func _farm() -> void:
	var p := game.provisions
	check("no basins before 农业部 is built", p.basins() == 0 and p.sow_refusal(0, "舰载麦") == "需要农业部升级")
	game.base.set_facility("farm", 1)
	check("Lv1: two groups of six", p.basins() == 12)
	game.base.set_facility("farm", 6)
	check("Lv6: all 72 in three swirls", p.basins() == 72)
	var gold := game.gold
	check("sowing Rhodes' own wheat costs its seed in 龙门币: %d" % int(Provisions.CROPS["舰载麦"].seed_lmd), p.sow(0, "舰载麦") and game.gold == gold - int(Provisions.CROPS["舰载麦"].seed_lmd))
	check("a sown basin takes nothing more", p.sow_refusal(0, "块茎薯") == "已种植")
	check("half way after an hour", absf(p.growth(0) - 0.0) < 0.01)
	later(3600)
	check("it grows in real time: half way after one of two hours", absf(p.growth(0) - 0.5) < 0.01 and not p.ripe(0))
	later(3600 * 100)
	check("ripe, and still ripe days later (nothing withers)", p.ripe(0))
	var shelf_before := game.material_count("舰载麦")
	check("harvest: six units to the warehouse", p.harvest(0) == 6 and game.material_count("舰载麦") == shelf_before + 6 and p.plot(0).is_empty())
	rank("rhine", 2)
	check("闪耀作物 needs 莱茵生命 R3 or a seed", p.sow_refusal(1, "闪耀作物") == "需要莱茵生命关系 R3")
	rank("rhine", 3)
	check("from R3 莱茵 sells the seed, R5 the variant", game.exchange.quote_buy("rhine", "闪耀作物种子").ok and not game.exchange.quote_buy("rhine", "闪耀作物·变种种子").ok)
	give("闪耀作物种子", 2)
	check("a seed sows a basin", p.sow(1, "闪耀作物") and game.material_count("闪耀作物种子") == 1)
	check("sow all fills the empty basins it can (one seed left)", p.sow_all("闪耀作物") == 1)
	check("sow all with wheat fills the other 70", p.sow_all("舰载麦") == 70)
	later(3600 * 8)
	check("everything ripe after 8 h", p.ripe_count() == 72)
	# 72 basins' worth needs room: the warehouse upgraded (仓库修订: capacity by 仓储部 level).
	game.base.set_facility("warehouse", BaseCatalog.WAREHOUSE_CELLS.size() - 1)
	var got := p.harvest_all()
	check("harvest all: 70 × 6 wheat + 2 × 3 闪耀作物", got == 70 * 6 + 2 * 3, got)
	check("the shining crops are in the warehouse", game.material_count("闪耀作物") == 6)

# --- 食堂 (§五) ----------------------------------------------------------------------------

func _kitchen_and_meals() -> void:
	var p := game.provisions
	check("no kitchen before 食堂", p.kitchen_slots() == 0 and p.cook_refusal("舰内口粮") == "需要食堂 Lv1")
	game.base.set_facility("canteen", 1)
	check("Lv1: one queue; 闪耀定食 waits for Lv2", p.kitchen_slots() == 1 and p.cook_refusal("闪耀定食") == "需要食堂 Lv2")
	var wheat := game.material_count("舰载麦")
	check("cooking 舰内口粮 ×2 takes 8 wheat", p.cook("舰内口粮", 2) and game.material_count("舰载麦") == wheat - 8)
	check("one queue is full", p.cook_refusal("舰内口粮") == "队列已满")
	later(19 * 60)
	check("not done in 19 minutes", p.tick().is_empty())
	later(60)
	check("done in 20: two rations in the warehouse", p.tick().size() == 1 and game.material_count("舰内口粮") == 2)
	game.base.set_facility("canteen", 3)
	check("Lv3: two queues", p.kitchen_slots() == 2)
	give("闪耀作物·变种", 2)
	give("温室豆", 4)
	check("变种盛宴 at Lv3", p.cook("变种盛宴"))
	later(3 * 3600)
	p.tick()
	check("a 变种盛宴 cooked", game.material_count("变种盛宴") == 1)
	check("eating one for the next contract", p.eat("舰内口粮") and p.meal() == "舰内口粮" and game.material_count("舰内口粮") == 1)
	check("another replaces it", p.eat("变种盛宴") and p.meal() == "变种盛宴")
	rank("penguin", 1)
	check("the cold chain needs 企鹅物流 R2", p.mail_refusal("舰内口粮") == "需要企鹅物流关系 R2")
	rank("penguin", 2)
	var gold := game.gold
	check("企鹅物流 carries one to the squads", p.mail("舰内口粮") and p.mailed() == "舰内口粮" and game.gold == gold - Provisions.MAIL_LMD)
	check("one at a time", p.mail_refusal("舰内口粮") == "已有寄出的补给")

# --- A contract (§5.3, §六) -----------------------------------------------------------------

func _contract_meal_and_squad() -> void:
	game._apply_meal("")
	var plain_hp := game.player.max_hp
	await game.start_contract("snow")
	await step(2)
	check("the meal goes with her and the plate clears", game.run_meal == "变种盛宴" and game.provisions.meal().is_empty())
	check("变种盛宴: max HP +12%%: %.0f → %.0f" % [plain_hp, game.player.max_hp], game.player.max_hp > plain_hp * 1.10)
	check("attack +10%, speed +5% as a lasting hex", is_equal_approx(game.player.hex("atk"), 0.10) and is_equal_approx(game.player.hex("aspd"), 0.05) and float(game.player.hexes.meal.time) < 0.0)
	# 3+: more squads; 2+: a step cheaper; 4: two services.
	var met := 0
	for i in range(3000):
		game._roll_encounter()
		if game.encounter == "squad": met += 1
	check("squads on ~40%% of floors with 3 or better (%d/3000)" % met, absf(met / 3000.0 - Provisions.SQUAD_CHANCE) < 0.03)
	var lows := 0
	for i in range(200):
		game._roll_encounter()
		if game.squad_mult < 1.0: lows += 1
	check("the price a step lower (×0.9–1.4)", lows > 0 and game.squad_mult <= 1.41)
	game._clear_field()
	game.encounter = "squad"
	game.encounter_used = false
	game.squad_uses = 0
	game.world_map.encounter_node.visible = true
	game.player.teleport(game.world_map.encounter_position)
	game.run_gold = 200
	var a := Item.create("补给测试刀", Item.Category.WEAPON, 2, 1, 2.0)
	a.value = 50
	var b := Item.create("补给测试甲", Item.Category.ARMOR, 2, 2, 2.0)
	b.value = 50
	game.inventory.try_add(a)
	game.inventory.try_add(b)
	check("4: the squad serves twice", game.squad_max_uses() == 2 and game.squad_insure(a) and not game.encounter_used and game.squad_insure(b) and game.encounter_used)
	check("its 补给 service stays open while one is mailed", game.squad_extras() and game.interaction_prompt() == "罗德岛小队")
	check("the mailed 补给 is eaten there and replaces the canteen's", game.squad_supply() and game.run_meal == "舰内口粮" and game.provisions.mailed().is_empty() and game.player.hex("atk") == 0.0)
	check("then the squad has nothing more", not game.squad_extras())
	game.settle(true)
	await step(2)
	check("settling takes the meal off", game.run_meal.is_empty() and not game.player.hexes.has("meal"))

func _field_slip_and_guide() -> void:
	await game.start_contract("snow")
	await step(2)
	game._clear_field()
	game.inventory.items.clear()
	game.safe_bag.items.clear()
	game.inventory.add_stack(MaterialCatalog.create("企鹅专递单", 1))
	var things: Array[Item] = []
	for i in range(4):
		var m := MaterialCatalog.create(["碳", "螺栓", "电线", "胶带"][i], 3)
		game.inventory.add_stack(m)
		things.append(m)
	game.encounter = ""
	check("专递 needs a squad or a camp", game.parcel_refusal() == "需要罗德岛小队或营地")
	game.encounter = "squad"
	game.encounter_used = true
	game.world_map.encounter_node.visible = true
	game.player.teleport(game.world_map.encounter_position)
	check("a used squad still takes a parcel", game.parcel_refusal().is_empty() and game.squad_extras())
	check("the slip itself is not sent", not game.parcel_items().any(func(i): return i.material_id == "企鹅专递单"))
	# Fill the warehouse but one cell: 仓库修订 — what the base brings in goes
	# into the warehouse even over capacity (no staging any more).
	var room := game.base.capacity() - game.base.shelf_count()
	for i in range(maxi(0, room - 1)): game.base.shelf.append(MaterialCatalog.create("木板", 1))
	var before := {}
	for m in things: before[m.material_id] = game.material_count(m.material_id) - game.carried_count(m.material_id)
	var sent := game.parcel_send(things)
	var home: bool = things.all(func(m): return game.material_count(m.material_id) == int(before[m.material_id]) + 3)
	check("four things home for one slip, all into the warehouse (%s)" % str(sent), int(sent.shelf) + int(sent.receiving) == 4 and int(sent.staging) == 0 and home)
	check("the slip is used and the pack is empty", game.carried_count("企鹅专递单") == 0 and game.inventory.items.is_empty())
	check("not without another", game.parcel_refusal() == "需要企鹅专递单")
	game.inventory.add_stack(MaterialCatalog.create("残党向导", 2))
	check("残党向导 is used from the pack", game.usable_special(game.inventory.items[0]) and game.use_guide())
	check("this floor's vault and trace show", game.guide_active() and game.carried_count("残党向导") == 1)
	check("once a floor", game.guide_refusal() == "本层已使用")
	game.floor_number += 1
	check("not on the next until used again", not game.guide_active())
	game.settle(true)
	await step(2)

func _save() -> void:
	game.base.farm.plots[3] = {"crop": "温室豆", "at": 12345}
	game.base.farm.meal = "食堂便当"
	var data := game.base.to_data()
	var copy := BaseState.new()
	copy.load_data(JSON.parse_string(JSON.stringify(data)), {})
	check("the farm, kitchen and meals are saved", copy.farm.plots[3].crop == "温室豆" and int(copy.farm.plots[3].at) == 12345 and copy.farm.meal == "食堂便当"
		and copy.facility_level("farm") == game.base.facility_level("farm"))
	var old := BaseState.new()
	old.load_data({}, {})
	check("an old save has neither room built and an empty farm", old.facility_level("farm") == 0 and old.facility_level("canteen") == 0 and old.farm.plots.is_empty())

# --- The second deck (§三) ------------------------------------------------------------------

func _scene() -> void:
	var map := game.base_map
	check("the second deck's rooms are built", map.rooms.has("deck2") and map.rooms.has("farm") and map.rooms.has("mess") and map.rooms.has("galley"))
	check("the second deck keeps the first's outline, the rest sealed", BaseMap.DECK2_ROOMS.size() == 12 and BaseMap.SEALED_DOORS.size() == 4)
	check("农业部 is the east wing, its two rooms open into one", map.rooms.has("farm2") and map.room_contains("farm", map.to_world(470.0, -20.0)) and BaseMap.FARM_CENTRES.size() == 3)
	check("its stations: the farm and canteen terminals, the lifts", not map.station("farm").is_empty() and not map.station("canteen").is_empty()
		and not map.station("lift2").is_empty())
	check("the gate is the lift to the second deck, the old lift spot has no E (用户 2026-10-23)", str(map.station("lift").kind) == "lift" and map.station("deck_lift").is_empty())
	check("72 basins in twelve groups of six", map.farm_basins.size() == 12 and map.farm_basins.all(func(g): return g.size() == 6))
	check("construction sites for both rooms", BaseWorks.POSTS.has("farm") and BaseWorks.POSTS.has("canteen") and BaseCatalog.FACILITY_ORDER.has("farm") and BaseCatalog.FACILITY_ORDER.has("canteen"))
	game.ride_lift(2)
	await step(2)
	check("the lift takes her to the second deck", game.deck == 2 and map.room_contains("deck2", game.player.global_position))
	game.ride_lift(1)
	await step(2)
	check("and back to the hall", game.deck == 1 and map.room_contains("hall", game.player.global_position))
	var p := game.provisions
	game.base.farm.plots[5] = {"crop": "闪耀作物", "at": BaseState.now() - 9 * 3600}
	map.set_farm(p)
	check("a ripe 闪耀作物 basin glows", is_instance_valid(map._crops[5].get("light")) and str(map._crops[5].piece.get_meta("model")) == "crop_shine_ripe")
	game.base.farm.plots[5] = {"crop": "闪耀作物", "at": BaseState.now()}
	map.set_farm(p)
	check("a young one does not", not map._crops[5].has("light") and str(map._crops[5].piece.get_meta("model")) == "crop_shine")
	for station in ["farm", "canteen", "lift"]:
		game.open_station(station)
		await step(2)
		check("the %s screen opens" % station, game.modal == "station" and game.menu.visible)
		game.close_modal()
