extends SceneTree
## Tuning run for 势力与交易所策划案 §15 (no checks; prints a table): three
## traders on the 龙门币/赤金 CFD over 24 real hours of market.
##   attentive: acts on news touching the rate within three ticks, 3×, takes 3% / cuts 2%
##   idle:      one position a day, held
##   random:    a random side every 30 minutes, closed after 30
## Profit is before the daily cap; the cap row shows what the day lets through.
## Run: Godot --headless --path . -s tests/sim_exchange.gd  (DOWNFALL_SIM_SEEDS=n)
var game: GameManager
func _initialize() -> void: call_deferred("run")

func run() -> void:
	MarketState.tz_override = 0
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	for i in range(6): await process_frame
	var seeds := int(OS.get_environment("DOWNFALL_SIM_SEEDS")) if OS.get_environment("DOWNFALL_SIM_SEEDS") != "" else 3
	var totals := {"attentive": 0.0, "idle": 0.0, "random": 0.0}
	for s in range(seeds):
		for who in totals.keys():
			totals[who] += _day(who, 1000 + s)
	print("strategy    profit per hour (龙门币, before the cap), %d seeds" % seeds)
	for who in totals:
		print("%-10s  %+8.0f" % [who, totals[who] / seeds / 24.0])
	print("cap per day: 10,000 + half of the day's contract rewards")
	quit()

## One trader's 24 hours; returns the profit before the cap.
func _day(who: String, seed_value: int) -> float:
	var market := MarketState.new()
	market.start(2000000000, seed_value)
	var ex := Exchange.new()
	game.market = market
	game.exchange = ex
	ex.setup(game, market)
	ex.relations = {"karlan": Exchange.RANK_AT[3], "kazimierz": Exchange.RANK_AT[3]}
	game.gold = 1000000
	var start_gold := float(game.gold)
	# Lambdas capture by value: the headline time goes through a dictionary.
	var seen := {"at": -1, "count": 0, "market": "", "dir": 0}
	var tradable := ex.cfd_underlyings()
	# The attentive trader reads the headline's arrows (§6.1).
	market.on_news = func(headline: Dictionary, _ev: Dictionary):
		var moves: Dictionary = headline.get("moves", {})
		for m in moves:
			if m in tradable:
				seen.at = market.t
				seen.count += 1
				seen.market = m
				seen.dir = int(moves[m])
				return
	var t0 := market.t
	var opened := -1
	var entry_price := 0.0
	var last_price := market.price("fx")
	while market.t < t0 + 86400:
		market.advance_to(market.t + 2)
		var p := market.price("fx")
		match who:
			"attentive":
				if int(seen.at) >= 0 and market.t - int(seen.at) >= 6 and ex.cfds.size() < 3:
					# Six seconds after the headline: follow the way it moved.
					var m: String = seen.market
					var now := market.price(m)
					var dir := int(seen.dir)
					var margin := 15000.0 if Exchange.cfd_currency(m) == "lmd" else 15.0
					if ex.open_cfd(m, dir, 3, margin):
						var c: Dictionary = ex.cfds[-1]
						ex.set_cfd_limits(c.id, now * (1.0 + 0.12 * dir), now * (1.0 - 0.06 * dir))
						c["sim_opened"] = market.t
					seen.at = -1
				for c in ex.cfds.duplicate():
					if market.t - int(c.get("sim_opened", market.t)) > 7200: ex.close_cfd(c.id)
			"idle":
				if ex.cfds.is_empty() and opened < 0:
					ex.open_cfd("fx", 1 if market.rng.randf() < 0.5 else -1, 3, 15000.0)
					opened = market.t
			"random":
				if ex.cfds.is_empty() and posmod(market.t - t0, 1800) < 2:
					ex.open_cfd("fx", 1 if market.rng.randf() < 0.5 else -1, 3, 15000.0)
					opened = market.t
				if not ex.cfds.is_empty() and market.t - opened >= 1800: ex.close_cfd(ex.cfds[-1].id)
		last_price = p
	for c in ex.cfds.duplicate(): ex.close_cfd(c.id)
	if who == "attentive": print("  seed %d: %d rate headlines, %d trades" % [seed_value, int(seen.count), ex.history.filter(func(h): return h.kind == "cfd").size()])
	if who == "attentive":
		for h in ex.history:
			if h.kind in ["closed", "liquidated"]: print("    %s %s %.0f" % [h.kind, h.what, float(h.amount)])
	return float(game.gold) - start_gold + ex.gold_account * Economy.GOLD_BAR_LMD
