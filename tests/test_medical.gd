extends SceneTree

## B4 of 基地玩法策划案_v1_0.md: contamination, injury, the pharmacy and the
## medical bay's stations (§4).

var failures := 0
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool) -> void:
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label)

func run() -> void:
	rules()
	await through_game()
	print("MEDICAL FAILURES: %d" % failures)
	quit(1 if failures else 0)

func rules() -> void:
	check("tiers: 39 none, 40 light, 70 medium, 100 heavy", BaseCatalog.contamination_tier(39) == 0 and BaseCatalog.contamination_tier(40) == 1
		and BaseCatalog.contamination_tier(70) == 2 and BaseCatalog.contamination_tier(100) == 3)
	var base := BaseState.new()
	base.contamination = 75
	base.injured = true
	check("injury and medium contamination add up but cap at 40%%: %.2f" % base.hp_penalty(), is_equal_approx(base.hp_penalty(), 0.40))
	base.contamination = 45
	check("injury plus light contamination: 35%", is_equal_approx(base.hp_penalty(), 0.35))
	base.contamination = 50
	base.free_potions = 0
	var report := base.settle_medical(12.0, false)
	check("settlement: decay 5 then this run's dose (50 -> 57), injury cleared, free flasks reissued",
		is_equal_approx(base.contamination, 57) and not base.injured and base.free_potions == BaseCatalog.FREE_POTIONS and report.contamination_after == 57 and base.report_unread)
	base.contamination = 3
	base.settle_medical(0.0, true)
	check("contamination never goes below 0; a death leaves an injury", base.contamination == 0 and base.injured)
	base.contamination = 98
	base.settle_medical(30.0, false)
	check("and never above 100", base.contamination == 100)
	check("decon price: 150 龙门币 per point, at least 1000", BaseCatalog.decon_price(2) == 1000 and BaseCatalog.decon_price(18) == 2700 and BaseCatalog.decon_price(0) == 0)
	check("the inhibitor needs R2; a standard flask is free while the free issue lasts", base.potion_price("C") == -1 and base.potion_price("B") == 600 and base.potion_price("A") == 0)
	base.free_potions = 0
	check("after the free issue a standard flask costs 300", base.potion_price("A") == BaseCatalog.POTION_A_PRICE)
	base.prestige = 60
	check("at R2 it is sold", base.potion_price("C") == 1000)
	var copy := BaseState.new()
	base.free_potions = 1
	copy.load_data(JSON.parse_string(JSON.stringify(base.to_data())), {})
	check("save keeps contamination, injury, the free issue left and the report", copy.contamination == base.contamination and copy.injured == base.injured
		and copy.free_potions == 1 and copy.report_unread)

func through_game() -> void:
	var game := GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	await step(8)
	for id in ["pharmacy", "decon"]:
		check(id + " station exported", not game.base_map.station(id).is_empty())

	# Contamination in the field.
	await game.start_contract("city")
	check("no contamination in the city on a normal route", game.contamination_rate() == 0.0 and not game.contamination_visible())
	game.settle(true)
	await game.start_contract("mine")
	check("the mine adds 0.02/s and shows on the HUD", is_equal_approx(game.contamination_rate(), 0.02) and game.contamination_visible())
	game.inventory.try_add(FieldCatalog.exclusive("mine"))
	game.safe_bag.try_add(FieldCatalog.exclusive("mine"))
	check("each ore adds 0.06/s, safe bag included", is_equal_approx(game.contamination_rate(), 0.14))
	game.route_index = 2
	check("the deep route adds 0.02/s", is_equal_approx(game.contamination_rate(), 0.16))
	game._tick_medical(100.0)
	check("a dose builds up over time (100 s -> 16)", is_equal_approx(game.run_contamination, 16.0))
	var start := game.base.contamination
	game.settle(true)
	check("settlement: decay first (to no lower than 0), then the dose: %.1f" % game.base.contamination, is_equal_approx(game.base.contamination, maxf(start - 5, 0) + 16))
	game.base.contamination = 35
	await game.start_contract("mine")
	game.message = ""
	game._tick_medical(300.0)
	check("crossing 40 in the field is announced: " + game.message, "轻度" in game.message)
	game.settle(true)

	# Departure applies injury and contamination for the whole contract.
	game.base.contamination = 75
	game.base.injured = true
	await game.start_contract("snow")
	var plain := CombatStats.BASE.hp
	check("departure: max HP down 40%% (injury + medium, capped): %.1f" % game.player.max_hp, is_equal_approx(game.player.max_hp, plain * 0.6) and game.player.hp <= game.player.max_hp)
	game.player.hp = 1
	game.potions = 1
	game._use_potion()
	check("medium contamination cuts potion healing by a quarter (960 -> 720)", is_equal_approx(game.player.hp, 721.0))
	game.player.hp = -1
	await step(2)
	check("death: injury stays, max HP back to normal at the base", game.base.injured and is_equal_approx(game.player.max_hp, plain) and game.player.condition_hp_penalty == 0.0)
	game.base.contamination = 100
	game.base.injured = false
	await game.start_contract("snow")
	check("heavy contamination stops self-regeneration", game.player.regen_blocked and is_equal_approx(game.player.max_hp, plain * 0.7))
	game.settle(true)
	check("extraction clears the injury and the regen block", not game.base.injured and not game.player.regen_blocked)

	# Pharmacy (药剂进背包): flasks are pack items bought one at a time.
	game.base.contamination = 0
	game.gold = 10000
	game.base.prestige = 0
	game.inventory.items.clear()
	game.safe_bag.items.clear()
	game.base.free_potions = 3
	check("the inhibitor is locked below R2", not game.buy_potion("C"))
	check("a free standard flask goes into the pack", game.buy_potion("A") and game.gold == 10000 and game.base.free_potions == 2 and game.potions == 1)
	check("a gel costs 600 and takes a cell", game.buy_potion("B") and game.gold == 9400 and game.inventory.occupied_cells() == 2)
	game.base.prestige = 60
	check("at R2 the inhibitor costs 1000", game.buy_potion("C") and game.gold == 8400)
	await game.start_contract("city")
	check("departure adds the free flasks still owed (1 + 1 + 1 bought, + 2 issued)", game.potions == 5 and game.base.free_potions == 0)
	check("orders never take a flask", not game.base.orders.slots.any(func(o): return o != null and game.carried_potions().any(func(x): return game.base.orders.matches(game.base.orders.slots.find(o), x))))
	game.player.hp = 5
	game.run_contamination = 10
	for f in game.carried_potions().filter(func(x): return x.potion_type == "A"):
		game.inventory.remove(f)
	game._use_potion()
	check("Q drinks a gel before the inhibitor; the gel heals nothing at once", is_equal_approx(game.player.hp, 5) and game._slow_heal_left > 0 and game.potions == 1)
	game._tick_medical(3.0)
	check("gel heals over 6 s (half after 3 s)", is_equal_approx(game.player.hp, 845.0))
	game._tick_medical(10.0)
	check("and stops at 1680 in total", is_equal_approx(game.player.hp, 1685.0))
	game.player.hp = 5
	game.run_contamination = 10
	game._use_potion()
	check("inhibitor: heals 480, cleanses 6, halves accrual for 30 s", is_equal_approx(game.player.hp, 485) and is_equal_approx(game.run_contamination, 4) and game._suppress_timer == 30.0 and game.potions == 0)
	game.region_id = "mine"
	check("while suppressed the mine adds half (0.01/s)", is_equal_approx(game.contamination_rate(), 0.01))
	game.region_id = "city"
	game._use_potion()
	check("no flask, nothing happens", game.potions == 0 and is_equal_approx(game.player.hp, 485))
	var full := BaseCatalog.create_potion("A")
	game.inventory.try_add(full)
	game.player.hp = game.player.max_hp
	game._use_potion()
	check("at full health a standard flask is kept", game.potions == 1)
	game.player.hp = 100
	check("a flask in the pack can be drunk directly (right click)", game.drink(full) and game.potions == 0 and game.player.hp > 100)
	game.builds.assign(["\"剑锤\""])
	game.player._recompute_stats()
	check("\"剑锤\" cuts flask healing by 20%", is_equal_approx(game.player.potion_heal_multiplier, 0.8))
	game.builds.clear()
	game.player._recompute_stats()
	game.settle(true)
	check("after the contract three flasks are issued free again", game.base.free_potions == BaseCatalog.FREE_POTIONS)

	# Front desk, injury treatment, the gate.
	var view := game.medical_view
	game.base.injured = true
	game.base.report_unread = true
	await step(2)
	check("desk shows the alert while a report is unread or an injury untreated", view._reception.texture == view.tex.reception_alert)
	game.open_station("report")
	check("opening the report marks it read", not game.base.report_unread)
	game.close_modal()
	game.gold = 3000
	check("injury treatment costs 3000", game.treat_injury() and game.gold == 0 and not game.base.injured)
	await step(2)
	check("desk back to idle", view._reception.texture == view.tex.reception_idle)
	game.base.contamination = 52
	await step(2)
	check("gate is red at 40 and above", view.gate_red() and view._gate.material_override.get_shader_parameter("tex") == view.tex.gate_red)
	check("the reading names value, tier and effect: " + view.reading(), view.reading() == "检测门：污染 52 · 轻度：生命上限 −10%")
	var gate: Dictionary = game.base_map.station("decon")
	game.player.teleport(gate.position)
	await step(3)
	game.message = ""
	game.player.teleport(game.base_map.to_world(view._gate_x + 1.2, view._gate_z, BaseMap.PLAYER_Y))
	await step(3)
	check("walking through the gate gives the reading for free", game.message == view.reading())
	game.gold = 10000
	check("decontaminate to 39: 13 points, 1950 龙门币", game.decontaminate(39) and game.gold == 8050 and game.base.contamination == 39)
	await step(2)
	check("gate turns green", not view.gate_red() and view._gate.material_override.get_shader_parameter("tex") == view.tex.gate_green)
	check("decontaminate to 0: 39 points, 5850 龙门币", game.decontaminate(0) and game.gold == 2200 and game.base.contamination == 0)
	check("nothing to treat at 0", not game.decontaminate(0))
	for kind in ["pharmacy", "decon", "report"]:
		game.open_station(kind)
		check(kind + " menu opens", game.modal == "station" and game.menu.visible)
		game.close_modal()
	game.queue_free()
	await step(2)
