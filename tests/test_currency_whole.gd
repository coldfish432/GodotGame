extends SceneTree
## 货币精简与取整修订案 v1.0: she holds 龙门币 and 赤金 bars only, both whole;
## the foreign currencies are quotes. What she is paid is rounded (四舍五入),
## what she pays is rounded up (拍板 Q2). An old save's 赤金 account, foreign
## balances, 赤金 deposits and 赤金存单 are paid out once (§3.5).
var game: GameManager
var failures := 0
const T0 := 1791972000
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool, detail: Variant = null) -> void:
	print(("PASS " if passed else "FAIL ") + label + ("" if passed or detail == null else "  " + str(detail)))
	if not passed: failures += 1

func shelf_bars() -> int:
	var n := 0
	for item in game.base.stock():
		if item.material_id == Economy.GOLD_ID: n += item.quantity
	return n

func run() -> void:
	MarketState.tz_override = 0
	BaseState.frozen_clock = T0
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	game.fixed_market_seed = 33
	root.add_child(game)
	await step(8)
	game.seed_rng(33)
	var ex := game.exchange
	game.base.set_facility("exchange", 1)
	# --- Whole amounts ---------------------------------------------------------------
	check("the rounding rules: paid rounded half up, paying rounded up",
		Exchange.credit_whole("lmd", 2.5) == 3 and Exchange.credit_whole("lmd", 2.49) == 2 and Exchange.pay_whole("lmd", 2.01) == 3 and Exchange.pay_whole("lmd", 2.0) == 2
		and Exchange.credit_whole("gold", 0.5) == 1 and Exchange.pay_whole("gold", 0.1) == 1)
	check("a foreign amount is 龙门币 at the live rate", Exchange.credit_whole("col", 10.0) == roundi(Exchange.live_lmd("col", 10.0)) and Exchange.pay_whole("col", 10.0) == ceili(Exchange.live_lmd("col", 10.0) - 0.0001))
	var all_whole := true
	for cur in ["lmd", "gold"] + Currencies.foreign():
		for x in [0.3, 1.7, 12.345, 999.5]:
			var s := Exchange.format_money(str(cur), x)
			if "." in s.replace(",", "") or not (s.ends_with("龙门币") or s.ends_with("赤金")): all_whole = false
	check("every amount shows whole, in 龙门币 or 赤金 only", all_whole)
	# --- The deposits: 龙门币 only, whole ------------------------------------------------
	game.gold = 100000
	check("a 赤金 deposit is refused", not ex.fin.deposit("gold", 5.0) and not ex.fin.open_term("gold", 5.0, 1))
	check("a 龙门币 deposit is whole", ex.fin.deposit("lmd", 1000.4) and int(ex.fin.demand.lmd) == 1000 and game.gold == 99000)
	ex.fin.demand.lmd = 1000000
	ex.fin._deposit_interest()
	check("a day's interest is whole", typeof(ex.fin.demand.lmd) == TYPE_INT and int(ex.fin.demand.lmd) == 1000000 + roundi(1000000 * ex.fin.demand_rate("lmd")))
	ex.fin.demand.lmd = 0
	# --- The old save -----------------------------------------------------------------
	var lmd_before := game.gold
	var bars_before := shelf_bars()
	var old := ex.to_data()
	old.erase("money_version")
	old["gold_account"] = 10.6
	old["fx_accounts"] = {"col": 100.0}
	old["finance"]["demand"] = {"lmd": 100.4, "gold": 2.0}
	old["finance"]["terms"] = [{"id": 1, "cur": "gold", "amount": 1.0, "rate": 0.001, "days": 3, "due": ex.fin.today() + 3}, {"id": 2, "cur": "lmd", "amount": 500.6, "rate": 0.001, "days": 3, "due": ex.fin.today() + 3}]
	old["securities"]["cert"] = 3.0
	ex.load_data(JSON.parse_string(JSON.stringify(old)))
	check("an old save loads unmigrated", ex.money_version == 0)
	ex.migrate_money()
	var fx_lmd := roundi(Exchange.live_lmd("col", 100.0))
	check("its 金券 become whole 龙门币 at the live rate (%d)" % fx_lmd, game.gold == lmd_before + fx_lmd, game.gold - lmd_before)
	check("its 赤金 account, deposits and 存单 become 17 bars in the warehouse (10.6 + 2 + 1 + 3)", shelf_bars() == bars_before + 17, shelf_bars() - bars_before)
	check("its 龙门币 deposits are whole and stay", int(ex.fin.demand.lmd) == 100 and ex.fin.terms.size() == 1 and int(ex.fin.terms[0].amount) == 501)
	check("nothing of the old monies is left", not ex.fin.demand.has("gold") and is_zero_approx(ex.securities.cert) and ex.money_version == 1)
	var gold_now := game.gold
	ex.migrate_money()
	check("it runs once", game.gold == gold_now)
	check("the new save has no foreign balance or 赤金 account", not ex.to_data().has("gold_account") and not ex.to_data().has("fx_accounts") and int(ex.to_data().money_version) == 1)
	# --- Field: the post pays whole -----------------------------------------------------
	check("可露希尔's changer is whole bars", ex.convert_lmd(true, 3, true) == ceili(3 * Economy.fx * (1.0 + Economy.closure_spread) - 0.0001) and ex.convert_lmd(false, 3, true) == roundi(3 * Economy.fx * (1.0 - Economy.closure_spread)))
	print("TEST_CURRENCY_WHOLE: %d failures" % failures)
	quit(1 if failures > 0 else 0)
