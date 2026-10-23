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
	# Life is set by hand here; the default auto slot (急救剂) would drink.
	SystemScreens.settings["auto_potion"] = ""
	rules()
	await through_game()
	print("MEDICAL FAILURES: %d" % failures)
	quit(1 if failures else 0)

func rules() -> void:
	check("tiers (用户 2026-10-15): 59 none, 60 medium, 89 medium, 90 heavy", BaseCatalog.contamination_tier(59) == 0 and BaseCatalog.contamination_tier(60) == 1
		and BaseCatalog.contamination_tier(89) == 1 and BaseCatalog.contamination_tier(90) == 2 and BaseCatalog.contamination_tier(100) == 2)
	check("below 60 contamination does nothing", BaseCatalog.contamination_hp_cut(59) == 0.0 and BaseCatalog.contamination_regen_factor(59) == 1.0 and BaseCatalog.contamination_potion_penalty(59) == 0.0 and BaseCatalog.contamination_drain(59) == 0.0)
	check("60: max HP −15%, regeneration halved", BaseCatalog.contamination_hp_cut(60) == 0.15 and BaseCatalog.contamination_regen_factor(60) == 0.5 and BaseCatalog.contamination_potion_penalty(60) == 0.0 and BaseCatalog.contamination_drain(60) == 0.0)
	check("90: max HP −30%, no regeneration, 0.1% lost a second, potions −25%", BaseCatalog.contamination_hp_cut(90) == 0.30 and BaseCatalog.contamination_regen_factor(90) == 0.0 and BaseCatalog.contamination_potion_penalty(90) == 0.25 and BaseCatalog.contamination_drain(90) == 0.001)
	check("injury and heavy contamination add up but cap at 40%", is_equal_approx(BaseCatalog.hp_penalty(95, true), 0.40))
	var base := BaseState.new()
	base.injured = true
	check("at the base only the injury counts (污染不带出局外): 25%", is_equal_approx(base.hp_penalty(), 0.25))
	base.free_potions = 0
	var report := base.settle_medical(false)
	check("settlement: an untreated injury stays (博士主角叙事修订案 §5), free flasks reissued, report unread",
		base.injured and base.free_potions == BaseCatalog.FREE_POTIONS and not report.injured and base.report_unread)
	base.injured = false
	base.settle_medical(true)
	check("a death injures the operator who fell", base.injured and base.injured_operators() == [base.operator] and str(base.medical_report.operator) == base.operator)
	base.operator = Operators.AMIYA_GUARD
	check("another operator is not injured by it", not base.injured and base.any_injured() and is_equal_approx(base.hp_penalty(), 0.0))
	base.settle_medical(true)
	check("both can be injured at once", base.injured_operators().size() == 2 and Operators.LAPPLAND in base.injured_operators() and Operators.AMIYA_GUARD in base.injured_operators())
	var legacy := BaseState.new()
	legacy.load_data({"injured": true, "operator": Operators.AMIYA_GUARD}, {})
	check("an old save's single injury goes to whoever deploys", legacy.injured_operators() == [Operators.AMIYA_GUARD])
	check("the base keeps no contamination at all", not "contamination" in base and not base.to_data().has("contamination"))
	check("the inhibitor needs 商店 Lv3; a standard flask is free while the free issue lasts", base.potion_price("C") == -1 and base.potion_price("B") == 600 and base.potion_price("A") == 0)
	base.free_potions = 0
	check("after the free issue a standard flask costs 300", base.potion_price("A") == BaseCatalog.POTION_A_PRICE)
	base.set_facility("store", 3)
	check("at 商店 Lv3 it is sold", base.potion_price("C") == 1000)
	var copy := BaseState.new()
	base.free_potions = 1
	copy.load_data(JSON.parse_string(JSON.stringify(base.to_data())), {})
	check("save keeps each injury, the free issue left and the report", copy.injured_operators() == base.injured_operators()
		and copy.free_potions == 1 and copy.report_unread)

func through_game() -> void:
	var game := GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	await step(8)
	check("pharmacy station exported", not game.base_map.station("pharmacy").is_empty())
	check("no scan-gate station any more", game.base_map.station("decon").is_empty())

	# 基地形象 (用户 2026-10-15): the base walker is a setting; the field is always the deployed operator.
	SystemScreens.settings.base_look = Operators.AMIYA_GUARD
	game.choose_operator(Operators.LAPPLAND)
	check("the base shows the picked look while Lappland deploys", game.player._sprite.character == Operators.AMIYA_GUARD and game.player.operator_id == Operators.LAPPLAND)
	await game.start_contract("snow")
	check("the field shows whoever deploys", game.player._sprite.character == Operators.LAPPLAND)
	game.settle(true)
	check("back at the base the look returns", game.player._sprite.character == Operators.AMIYA_GUARD)
	SystemScreens.settings.base_look = ""
	game.refresh_look()
	check("an empty look follows the deployed operator", game.player._sprite.character == Operators.LAPPLAND)

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
	game.settle(true)
	check("settlement drops the dose: nothing is carried out (污染不带出局外)", game.run_contamination == 0.0 and game.current_contamination() == 0.0)
	await game.start_contract("mine")
	check("every contract starts clean", game.current_contamination() == 0.0)
	game.run_contamination = 55.0
	game.message = ""
	game._tick_medical(300.0)
	check("crossing 60 in the field is announced: " + game.message, "中度" in game.message)
	game.settle(true)

	# Injury applies for the whole contract; contamination stacks on it live.
	game.base.injured = true
	await game.start_contract("snow")
	var plain := CombatStats.BASE.hp
	# Max HP stays; the cut blocks the top of the bar (用户 2026-10-15: 保留原生命上限).
	check("departure with an injury: max HP kept, life capped at 75%%: %.1f" % game.player.hp, is_equal_approx(game.player.max_hp, plain) and is_equal_approx(game.player.life_cap(), plain * 0.75) and game.player.hp <= plain * 0.75 + 0.01)
	game.player.heal(99999)
	check("healing stops at the cap, which counts as full", is_equal_approx(game.player.hp, plain * 0.75) and game.player.full_hp())
	game.player.hp = plain
	check("nothing sets life above the cap", is_equal_approx(game.player.hp, plain * 0.75))
	game.run_contamination = 92.0
	await step(2)
	check("plus heavy contamination: life capped at 60%% (40%% at most): %.1f" % game.player.hp, is_equal_approx(game.player.max_hp, plain) and is_equal_approx(game.player.life_cap(), plain * 0.6) and game.player.hp <= plain * 0.6 + 0.01)
	# 复利数值改造清单 E: no bonus or penalty touches a flask, contamination
	# included. Ungeared (600 HP) the cap would hide the 960, so a buff lifts it.
	game.player.apply_buff(4000.0, 0.0)
	game.player.hp = 1
	game.potions = 1
	game._use_potion()
	check("heavy contamination no longer cuts potion healing (960 in full)", is_equal_approx(game.player.hp, 1.0 + BaseCatalog.potion_heal("A", 1)))
	game.player.hp = -1
	await step(2)
	check("death: injury stays, max HP back to normal at the base", game.base.injured and is_equal_approx(game.player.max_hp, plain) and game.player.condition_hp_penalty == 0.0)
	game.base.injured = false
	await game.start_contract("snow")
	game.run_contamination = 100.0
	await step(2)
	check("100 contamination: life capped at 70%, no regeneration, 0.1% of max HP lost a second", is_equal_approx(game.player.max_hp, plain) and is_equal_approx(game.player.life_cap(), plain * 0.7) and is_equal_approx(game.player.regen_rate(), -0.001 * game.player.max_hp))
	# The drain does not wait for the end of combat, and never takes the last point.
	game.player.hp = 30.0
	game.player.combat_timer = 0.0
	game.player.regen_timer = 0.01
	await step(2)
	check("negative regeneration drains even in combat", game.player.hp < 30.0 and game.player.hp >= 1.0)
	game.player.hp = 1.5   # the drain is 0.1% of max HP a second, about 1.7
	game.player.regen_timer = 0.01
	await step(2)
	check("the drain stops at 1 HP", is_equal_approx(game.player.hp, 1.0))
	game.base.injured = true
	game.settle(true)
	check("extraction keeps an untreated injury", game.base.injured and not game.player.regen_blocked)
	game.base.injured = false

	# Live contamination (局内节奏与目标策划案 §6 D) and per-second out-of-combat regeneration (A2, 用户 2026-10-14).
	await game.start_contract("mine")
	var fresh := game.player.max_hp
	game.run_contamination = 20.0
	await step(2)
	check("20 gained in the field changes nothing yet", is_equal_approx(game.player.life_cap(), fresh))
	game.run_contamination = 60.0
	await step(2)
	check("reaching 60 in the field caps life at once (85%) and halves regeneration", is_equal_approx(game.player.max_hp, fresh) and absf(game.player.life_cap() - fresh * 0.85) < 1.0 and game.player.hp <= fresh * 0.85 + 0.01 and absf(game.player.regen_rate() - 0.0005 * game.player.max_hp) < 0.01)
	game.player.hp = 500.0
	game.player.combat_timer = 1.0
	game.player.regen_timer = 0.01
	await step(2)
	check("no regeneration within 5 s of combat", is_equal_approx(game.player.hp, 500.0))
	game.player.combat_timer = 6.0
	game.player.regen_timer = 0.01
	await step(2)
	check("regeneration resumes out of combat, one second's worth a tick", game.player.hp > 500.0 and game.player.hp <= 500.0 + game.player.regen_rate() + 0.1)
	game.settle(true)

	# Pharmacy (药剂进背包): flasks are pack items bought one at a time.
	game.gold = 10000
	game.base.set_facility("store", 1)
	game.inventory.items.clear()
	game.safe_bag.items.clear()
	game.base.free_potions = 3
	check("the inhibitor is locked below 商店 Lv3", not game.buy_potion("C"))
	check("a free standard flask goes into the pack", game.buy_potion("A") and game.gold == 10000 and game.base.free_potions == 2 and game.potions == 1)
	check("a gel costs 600 and takes a cell", game.buy_potion("B") and game.gold == 9400 and game.inventory.occupied_cells() == 2)
	game.base.set_facility("store", 3)
	check("at Lv3 the inhibitor costs 1000", game.buy_potion("C") and game.gold == 8400)
	await game.start_contract("city")
	check("departure adds the free flasks still owed (1 + 1 + 1 bought, + 2 issued)", game.potions == 5 and game.base.free_potions == 0)
	# 用户 2026-10-17: 药剂可堆叠 — one kind shares a cell.
	var stack_a: Array = game.carried_potions().filter(func(x): return x.potion_type == "A")
	check("the three standard flasks are one stack in one cell", stack_a.size() == 1 and stack_a[0].quantity == 3 and stack_a[0].value == stack_a[0].unit_value * 3)
	var hp_full := game.player.hp
	game.player.hp = 5
	check("drinking one takes one off the stack", game.drink(stack_a[0]) and stack_a[0].quantity == 2 and game.inventory.items.has(stack_a[0]) and game.potions == 4)
	game.player.hp = hp_full
	var loose := BaseCatalog.create_potion("A")
	check("a picked-up flask joins the stack", game.inventory.add_stack(loose) == 0 and stack_a[0].quantity == 3 and game.potions == 5)
	check("a flask saved one per cell stacks after loading", Item.from_data({"name": "标准急救剂", "potion": "A", "value": 30}).max_stack == BaseCatalog.POTION_STACK)
	check("orders never take a flask", not game.base.orders.slots.any(func(o): return o != null and game.carried_potions().any(func(x): return game.base.orders.matches(game.base.orders.slots.find(o), x))))
	# Room for a gel's 1680 above her ungeared 600 HP.
	game.player.apply_buff(2000.0, 0.0)
	game.player.hp = 5
	game.run_contamination = 10
	for f in game.carried_potions().filter(func(x): return x.potion_type == "A"):
		game.inventory.remove(f)
	game._use_potion()
	check("Q drinks a gel before the inhibitor; the gel heals nothing at once", is_equal_approx(game.player.hp, 5) and game._slow_heal_left > 0 and game.potions == 1)
	game._tick_medical(3.0)
	check("gel heals over 6 s (half after 3 s)", is_equal_approx(game.player.hp, 5.0 + BaseCatalog.potion_heal("B", 1) * 0.5))
	game._tick_medical(10.0)
	check("and stops at 1680 in total", is_equal_approx(game.player.hp, 5.0 + BaseCatalog.potion_heal("B", 1)))
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
	# 复利数值改造清单 E: relics no longer change flask healing (the old 药剂容量).
	check("\"剑锤\" leaves flask healing alone", is_equal_approx(game.player.potion_heal_multiplier, 1.0))
	game.builds.clear()
	game.player._recompute_stats()
	game.settle(true)
	check("after the contract three flasks are issued free again", game.base.free_potions == BaseCatalog.FREE_POTIONS)

	# Front desk and injury treatment; the scan gate is scenery only.
	var view := game.medical_view
	game.base.injured = true
	game.base.report_unread = true
	await step(2)
	check("desk shows the alert while a report is unread or an injury untreated", view._reception.visible)
	game.open_station("report")
	check("opening the report marks it read", not game.base.report_unread)
	game.close_modal()
	game.gold = 3000
	check("injury treatment costs 3000", game.treat_injury() and game.gold == 0 and not game.base.injured)
	await step(2)
	check("desk back to idle", not view._reception.visible)
	check("the gate stands, scenery only", view._gate != null and view._gate.visible)
	check("and treating contamination is gone", not game.has_method("decontaminate"))
	for kind in ["pharmacy", "report"]:
		game.open_station(kind)
		check(kind + " menu opens", game.modal == "station" and game.menu.visible)
		game.close_modal()
	game.queue_free()
	await step(2)
