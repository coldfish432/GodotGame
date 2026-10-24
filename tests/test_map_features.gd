extends SceneTree

## 地图特色 (地图特色策划案_v1_0.md, 用户 2026-10-19): 源石污染, 血债 and 寒冷 as
## one kind of meter; the depth step every 20 floors; 萨米's fires; the sealer,
## the shower and the camp's 处理; 血债 apart from the 威胁值 with its reckoning;
## the base kits.

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
	rules()
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 5150
	root.add_child(game)
	await step(8)
	await _snow()
	await _mine()
	await _siracusa()
	await _kits()
	_drops()
	print("MAP FEATURES RESULT: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await step(2)
	quit(1 if failures else 0)

func rules() -> void:
	check("every 20 floors one step faster: ×1.0 / ×1.1 / ×1.2 / ×1.3", is_equal_approx(FeatureCatalog.depth_mult(1), 1.0) and is_equal_approx(FeatureCatalog.depth_mult(20), 1.0)
		and is_equal_approx(FeatureCatalog.depth_mult(21), 1.1) and is_equal_approx(FeatureCatalog.depth_mult(41), 1.2) and is_equal_approx(FeatureCatalog.depth_mult(61), 1.3))
	check("two steps, 60 and 90", FeatureCatalog.tier(59.9) == 0 and FeatureCatalog.tier(60) == 1 and FeatureCatalog.tier(89.9) == 1 and FeatureCatalog.tier(90) == 2)
	check("寒冷 60: move −10%, stamina −30%", is_equal_approx(FeatureCatalog.cold_move(60), 0.9) and is_equal_approx(FeatureCatalog.cold_stamina(60), 0.7) and is_equal_approx(FeatureCatalog.cold_aspd(60), 1.0) and not FeatureCatalog.cold_stops_regen(60))
	check("寒冷 90: move −20%, attack speed −15%, no regeneration, 0.1% a second", is_equal_approx(FeatureCatalog.cold_move(90), 0.8) and is_equal_approx(FeatureCatalog.cold_aspd(90), 0.85)
		and FeatureCatalog.cold_stops_regen(90) and is_equal_approx(FeatureCatalog.cold_drain(90), 0.001))
	check("each region its own: mine 污染, 叙拉古 血债, 萨米 寒冷, 龙门 none", FeatureCatalog.feature_of("mine") == "contamination" and FeatureCatalog.feature_of("siracusa") == "debt"
		and FeatureCatalog.feature_of("snow") == "cold" and FeatureCatalog.feature_of("city") == "")
	check("fire numbers (用户 2026-10-19): −3 a second within 4.5 m", is_equal_approx(FeatureCatalog.FIRE_WARM, 3.0) and is_equal_approx(FeatureCatalog.FIRE_RADIUS, 4.5) and is_equal_approx(FeatureCatalog.COLD_RATE, 0.1))
	var m := FeatureMeter.new()
	m.kits = {"cold": ["sami_lining", 3]}
	check("a tier 3 kit takes 36% off its feature's growth on a tier 3 floor, depth on top", is_equal_approx(m.growth_mult("cold", 25), 1.1 * 0.64) and is_equal_approx(m.growth_mult("debt", 25), 1.1))
	m.kits = {"cold": ["sami_lining", 1]}
	check("a tier 1 kit there loses 5% a tier short (30% → 20%)", is_equal_approx(m.growth_mult("cold", 25), 1.1 * 0.8))
	m.add("cold", 150.0)
	check("a meter tops out at 100", is_equal_approx(m.value("cold"), 100.0))
	m.enter_camp()
	check("a camp's fire clears the cold", m.value("cold") == 0.0)
	check("赔偿金 starts at 2 赤金", m.camp_debt_price() == 2)
	m.add("debt", 95.0)
	check("血债 at 90 calls a reckoning", m.reckoning_due(0.1))
	m.reckoning_sent()
	check("a reckoning takes 20 off and waits 90 s", is_equal_approx(m.value("debt"), 75.0) and is_equal_approx(m.reckon_wait, 90.0) and m.reckonings == 1)
	m.add("debt", 20.0)
	check("no second one inside 90 s", not m.reckoning_due(10.0) and m.reckoning_due(80.0))
	check("the mask goes anywhere; the lining only to 萨米", "dust_mask" in FeatureCatalog.kits_for("city") and "sami_lining" in FeatureCatalog.kits_for("snow")
		and not "sami_lining" in FeatureCatalog.kits_for("mine") and not "broker_letter" in FeatureCatalog.kits_for("snow"))

func _snow() -> void:
	await game.start_contract("snow")
	check("萨米 shows 寒冷 on the HUD", game.shown_features() == ["cold"])
	var camps := game.get_tree().get_nodes_in_group("loot_containers").filter(func(b): return b.game == game and b.kind == "camp").size()
	check("two or three fires along the path, one by a 冰原营地 at most (%d fires, %d camps)" % [game.fires.size(), camps], game.fires.size() >= 2 and game.fires.size() <= 3 + mini(camps, 1) + 1)
	var apart := true
	for a in game.fires:
		for b in game.fires:
			if a != b and a.global_position.distance_to(b.global_position) < FeatureCatalog.FIRE_RADIUS * 2.0 - 0.01: apart = false
	check("no two fires share their warmth", apart)
	check("they start cold", game.fires.all(func(f): return not f.lit()))
	check("a fire has its model", game.fires[0].has_node("Model"))
	check("寒冷 starts at 0 and rises 0.10 a second", game.features.value("cold") == 0.0 and is_equal_approx(game.cold_rate(), 0.1))
	game.player.global_position = game.fires[0].global_position + Vector3(20, 0, 20)
	game._tick_features(100.0)
	check("100 s out in the cold: 10", is_equal_approx(game.features.value("cold"), 10.0), game.features.value("cold"))
	game.route_index = 2
	check("the deep route adds 0.05", is_equal_approx(game.cold_rate(), 0.15))
	game.route_index = 0
	game.floor_number = 21
	check("from floor 21 it is ×1.1", is_equal_approx(game.cold_rate(), 0.11))
	game.floor_number = 1
	# At a fire.
	var fire: FirePit = game.fires[0]
	game.player.global_position = fire.global_position + Vector3(1.0, 0, 0)
	for item in game.inventory.items.duplicate(): game.inventory.remove(item)
	check("without fuel the fire offers nothing", game.interaction_prompt() == "" and game.near_fire() == fire)
	game.inventory.add_stack(MaterialCatalog.create("木板", 2))
	game.inventory.add_stack(MaterialCatalog.create("固体燃料", 1))
	check("with fuel in the pack, E", game.interaction_prompt() != "" and game.pack_fuels() == {"木板": 2, "固体燃料": 1})
	game._interact()
	check("E opens the picker of what to burn", game.modal == "fuel" and game.fuel_fire == fire)
	var rows: Array = game.menu.stage.find_children("*", "Button", true, false).filter(func(b): return b.has_meta("fuel"))
	check("one row per fuel in the pack", rows.size() == 2, rows.size())
	game.close_modal()
	check("she picks which: a plank burns 60 s", game.burn_fuel("木板", fire) and fire.lit() and is_equal_approx(fire.burn_left, 60.0) and game.pack_fuels()["木板"] == 1)
	check("solid fuel adds 120", game.burn_fuel("固体燃料", fire) and is_equal_approx(fire.burn_left, 180.0) and not game.pack_fuels().has("固体燃料"))
	check("a lit fire warms: −3 a second within its radius", game.warm_fire() == fire and is_equal_approx(game.cold_rate(), -3.0))
	game._tick_features(2.0)
	check("the cold falls by the fire (10 → 4)", is_equal_approx(game.features.value("cold"), 4.0), game.features.value("cold"))
	game.player.global_position = fire.global_position + Vector3(FeatureCatalog.FIRE_RADIUS + 0.5, 0, 0)
	check("just outside it rises again", game.warm_fire() == null and game.cold_rate() > 0.0)
	fire.feed(500.0)
	check("a fire holds at most 300 s", is_equal_approx(fire.burn_left, FeatureCatalog.FIRE_MAX) and not game.burn_fuel("木板", fire))
	fire.burn(301.0)
	check("burnt out, it is cold and can be lit again", not fire.lit() and game.burn_fuel("木板", fire) and fire.lit())
	# The cold on her.
	var plain_aspd := game.player.current_aspd()
	game.features.values.cold = 92.0
	game._tick_features(0.0)
	check("冻僵 slows her attacks", game.player.cold >= 90.0 and game.player.current_aspd() < plain_aspd)
	check("…and stops regeneration, draining 0.1% a second", game.player.regen_rate() < 0.0 and is_equal_approx(game.player.regen_rate(), -game.player.max_hp * 0.001))
	game.features.values.cold = 50.0
	var can := FeatureCatalog.create_supply("自热罐头")
	game.inventory.add_stack(can)
	check("a 自热罐头 takes 30 off", game.use_supply(can) and is_equal_approx(game.features.value("cold"), 20.0))
	game.features.values.cold = 70.0
	game._enter_camp()
	check("a camp clears the cold", game.features.value("cold") == 0.0 and game.player.cold == 0.0)
	game.menu.camp_tab = 6
	game.menu.show_camp()
	var supply_rows: Array = game.menu.stage.find_children("*", "Button", true, false).filter(func(b): return b.has_meta("supply"))
	check("可露希尔 in a camp sells the field supplies and solid fuel", supply_rows.size() == FeatureCatalog.CAMP_SUPPLIES.size())
	game.inventory.add_stack(MaterialCatalog.create(Economy.GOLD_ID, 5))
	var bars := game.gold_available()
	check("a 自热罐头 for 2 赤金", game.closure_buy_supply("自热罐头") and game.gold_available() == bars - 2)
	game.menu.camp_tab = 0
	game.settle(true)
	check("settlement clears every meter", game.features.value("cold") == 0.0 and game.player.cold == 0.0)

func _mine() -> void:
	game.force_shower = true
	await game.start_contract("mine")
	game.force_shower = false
	check("the mine shows 污染", game.shown_features() == ["contamination"])
	game.floor_number = 21
	check("contamination is ×1.1 from floor 21", is_equal_approx(game.contamination_rate(), 0.022))
	game.floor_number = 1
	for item in game.inventory.items.duplicate(): game.inventory.remove(item)
	var ore := FieldCatalog.exclusive("mine")
	game.inventory.try_add(ore)
	var price := Economy.price(ore)
	check("an unsealed ore adds 0.06", is_equal_approx(game.contamination_rate(), 0.08))
	var sealer := FeatureCatalog.create_supply("源石矿封装器")
	game.inventory.add_stack(sealer)
	check("the sealer seals it", game.use_supply(sealer) and ore.effect == GameManager.SEALED_ORE and ore.item_name == FeatureCatalog.SEALED_ORE_NAME)
	check("简易封装: 0.01 a second, price unchanged", is_equal_approx(game.contamination_rate(), 0.03) and Economy.price(ore) == price)
	check("the sealer is used up", not game.inventory.items.any(func(i): return i.material_id == "源石矿封装器"))
	check("with no ore to seal it does nothing", not game.use_supply(FeatureCatalog.create_supply("源石矿封装器")))
	var order := OrderBoard.new()
	order.slots = [{"id": "eng_raw_ore", "state": "open", "delivered": []}]
	check("a sealed ore still fills the raw-ore order", order.matches(0, ore))
	check("and it is still ore to 源石之心", game.player.ore_count() == 1)
	var ore2 := FieldCatalog.exclusive("mine")
	game.inventory.try_add(ore2)
	game.inventory.add_stack(FeatureCatalog.create_supply("源石矿封装器"))
	check("right click on the ore with a sealer carried seals it too", game.seal_with_sealer(ore2) and ore2.effect == GameManager.SEALED_ORE)
	# The shower.
	check("a 净化喷淋点 on this floor, with its model", is_instance_valid(game.shower) and game.shower.has_node("Model"))
	game.run_contamination = 40.0
	game.player.global_position = game.shower.global_position + Vector3(1.0, 0, 0)
	check("E at it", game.interaction_prompt() != "")
	game._interact()
	check("E starts the shower", game.shower_progress == 0.0)
	game._tick_features(1.0)
	game._tick_features(1.0)
	check("not done before 3 s", game.shower_progress > 0.0 and is_equal_approx(game.run_contamination, 40.0))
	game._tick_features(1.1)
	check("3 s: −25, and it is spent", is_equal_approx(game.run_contamination, 15.0) and game.shower.used and game.interaction_prompt() != "E")
	game._start_shower()
	game._tick_features(4.0)
	check("a spent shower does nothing", is_equal_approx(game.run_contamination, 15.0))
	# The camp's 处理.
	game.run_contamination = 50.0
	game.inventory.add_stack(MaterialCatalog.create(Economy.GOLD_ID, 10))
	game._enter_camp()
	var dose := game.run_contamination
	var bars := game.gold_available()
	check("营地处理: −30 for 3 赤金", game.camp_cleanse() and is_equal_approx(game.run_contamination, dose - 30.0) and game.gold_available() == bars - 3)
	check("once a camp", not game.camp_cleanse() and game.camp_cleanse_refusal() == "已处理")
	game.menu.camp_tab = 7
	game.menu.show_camp()
	var service: Array = game.menu.stage.find_children("*", "Button", true, false).filter(func(b): return b.has_meta("service"))
	check("处理 lists only what has a value (污染, no 血债 here)", service.size() == 1 and service[0].get_meta("service") == "cleanse")
	game.menu.camp_tab = 0
	game.settle(true)

func _siracusa() -> void:
	# 仓库修订: what came home is still in her bags (an ore would show 污染); put it away.
	game.store_all_carried()
	await game.start_contract("siracusa")
	check("叙拉古 shows 血债", game.shown_features() == ["debt"])
	var expected := clampf(game.floor_enemies().size() * float(ThreatMeter.SECONDS_PER_ENEMY.siracusa) / ThreatMeter.TARGET_WAVES, ThreatMeter.FILL_MIN, ThreatMeter.FILL_MAX)
	check("the 威胁值 fills at full speed in 叙拉古 now", is_equal_approx(game.threat.fill_seconds, expected), [game.threat.fill_seconds, expected])
	game.features.values.debt = 0.0
	game.add_debt(10.0)
	check("血债 at half the old weight", is_equal_approx(game.features.value("debt"), 5.0))
	var threat_before := game.threat.value
	game.add_debt(10.0)
	check("and it never touches the 威胁值", is_equal_approx(game.threat.value, threat_before))
	game.features.values.debt = 0.0
	game.floor_number = 41
	game.add_debt(10.0)
	check("deeper it grows faster (×1.2 on floor 41)", is_equal_approx(game.features.value("debt"), 6.0))
	game.floor_number = 1
	var crest := FieldCatalog.exclusive("siracusa")
	game.player.equip(crest)
	game.features.values.debt = 0.0
	game.add_debt(10.0)
	check("the Saluzzo crest worn: +25%", is_equal_approx(game.features.value("debt"), 6.25))
	game.unequip_to_pack(crest)
	game.features.values.debt = 0.0
	game.threat.value = 0.0
	var soldier: Enemy = game._spawn_enemy(game.player.global_position + Vector3(30, 0, 30), false, false, "family_soldier")
	await step(2)
	check("below 60 the families are as they were", is_equal_approx(game.feud_damage(soldier), 1.0) and is_equal_approx(game.feud_sight(soldier), 1.0))
	game.features.values.debt = 65.0
	check("仇家 (60): family hits +15%, sight +30%", is_equal_approx(game.feud_damage(soldier), 1.15) and is_equal_approx(game.feud_sight(soldier), 1.3))
	game.features.values.debt = 95.0
	game._tick_features(0.1)
	var reckoning := game.get_tree().get_nodes_in_group("reckoning").filter(func(e): return e.game == game and not e._dead)
	check("清算 (90): the families come, an eraser among them", reckoning.size() == ThreatMeter.PATROL_SIZE + 1 and reckoning.any(func(e): return e.enemy_type == "family_eraser"), reckoning.size())
	check("they take 20 of the 血债", is_equal_approx(game.features.value("debt"), 75.0) and game.reckoning())
	check("a reckoning is not a 威胁值 patrol", game.threat.wave == 0)
	var letter := FeatureCatalog.create_supply("中间人信物")
	game.inventory.add_stack(letter)
	check("a 中间人信物 takes 20 off", game.use_supply(letter) and is_equal_approx(game.features.value("debt"), 55.0))
	game.inventory.add_stack(MaterialCatalog.create(Economy.GOLD_ID, 10))
	game._enter_camp()
	var bars := game.gold_available()
	check("赔偿金: −10 for 2 赤金", game.camp_pay_debt() and is_equal_approx(game.features.value("debt"), 45.0) and game.gold_available() == bars - 2)
	check("the next one costs 3", game.features.camp_debt_price() == 3 and game.camp_pay_debt() and game.gold_available() == bars - 5)
	check("血债 is kept from floor to floor (no camp clears it)", is_equal_approx(game.features.value("debt"), 35.0))
	game.settle(true)
	check("gone at settlement", game.features.value("debt") == 0.0)

func _kits() -> void:
	game.gold = 280000
	game.base.set_facility("store", 1)
	var kit_price := FeatureCatalog.kit_price("sami_lining", game.deepest_tier())
	check("a plain kit for 龙门币: %d" % kit_price, game.buy_kit("sami_lining") and game.base.kits == {"sami_lining@1": 1} and game.gold == 280000 - kit_price)
	check("the refined one waits for 商店 Lv3", not game.buy_kit("sami_lining_plus") and game.kit_refusal("sami_lining_plus") == "商店 Lv3")
	game.base.set_facility("store", 3)
	check("at Lv3 it is sold", game.buy_kit("sami_lining_plus"))
	game.buy_kit("dust_mask")
	game.buy_kit("broker_letter")
	check("both of a kind ticked: only the refined one goes", game.chosen_kits("snow").has("sami_lining_plus") and not game.chosen_kits("snow").has("sami_lining"))
	check("the mask goes too, the letter does not", game.chosen_kits("snow").has("dust_mask") and not game.chosen_kits("snow").has("broker_letter"))
	game.toggle_kit("sami_lining", "snow")
	check("ticking the plain one unticks the refined", game.chosen_kits("snow").has("sami_lining") and not game.chosen_kits("snow").has("sami_lining_plus"))
	game.toggle_kit("dust_mask", "snow")
	check("a kit can be left behind", not game.chosen_kits("snow").has("dust_mask"))
	game.request_contract("snow")
	check("with kits in stock the departure card shows them", game.modal == "station" and game.menu.stage.find_children("*", "Button", true, false).any(func(b): return b.has_meta("kit")))
	game.close_modal()
	var copy := BaseState.new()
	copy.load_data(JSON.parse_string(JSON.stringify(game.base.to_data())), {})
	check("the kits are saved", copy.kits == game.base.kits)
	await game.start_contract("snow")
	check("one taken at departure, the others stay", game.base.kit_stock("sami_lining") == 0 and game.base.kit_stock("sami_lining_plus") == 1 and game.base.kit_stock("dust_mask") == 1)
	check("寒冷 grows 30% slower on this contract", is_equal_approx(game.cold_rate(), 0.07) and game.features.kits == {"cold": ["sami_lining", 1]})
	game.settle(true)
	await game.start_contract("snow")
	check("next time both defaults again: the refined lining and the mask", game.features.kits == {"cold": ["sami_lining_plus", 1], "contamination": ["dust_mask", 1]} and is_equal_approx(game.cold_rate(), 0.05))
	game.settle(true)
	check("…and the stock is spent", game.base.kits.is_empty() or game.base.kits.has("broker_letter@1") and game.base.kits.size() == 1)

func _drops() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var cans := 0
	var sealers := 0
	var letters := 0
	for i in range(400):
		var ctx := {"region": "snow", "depth": 3, "reward": 1.0, "rng": rng, "pity": {"rare_gear": 0.0, "rare_material": 0.0}, "set_seen": {}}
		for drop in LootTables.container_drops("camp", ctx):
			if drop.has("item") and drop.item.material_id == "自热罐头": cans += 1
		ctx.region = "mine"
		for drop in LootTables.container_drops("ore_vein", ctx):
			if drop.has("item") and drop.item.material_id == "源石矿封装器": sealers += 1
		ctx.region = "siracusa"
		for drop in LootTables.container_drops("safe", ctx):
			if drop.has("item") and drop.item.material_id == "中间人信物": letters += 1
	check("冰原营地 keep 自热罐头 (~30%%: %d/400)" % cans, cans > 80 and cans < 160)
	check("ore veins keep sealers (~20%%: %d/400)" % sealers, sealers > 50 and sealers < 115)
	check("叙拉古 safes keep a 中间人信物 (~15%%: %d/400)" % letters, letters > 30 and letters < 95)
