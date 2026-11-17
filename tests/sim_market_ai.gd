extends SceneTree
## 罗德岛运营与资产管理策划案 §7.2 sim_market_ai: one seed (DOWNFALL_SIM_SEED)
## for 180 days, a day at a time. Checks: no book pinned at its bounds for
## long, the cycle swings both ways by itself, firms are rarely restructured,
## no faction lives at the bottom of its cash. One process per seed.
const T0 := 1791972000
func _init() -> void:
	MarketState.tz_override = 0
	var seed_value := int(OS.get_environment("DOWNFALL_SIM_SEED")) if OS.has_environment("DOWNFALL_SIM_SEED") else 1
	var days := int(OS.get_environment("DOWNFALL_SIM_DAYS")) if OS.has_environment("DOWNFALL_SIM_DAYS") else 180
	var m := MarketState.new()
	m.start(T0, seed_value)
	var pinned := {}
	var e_min := 0.0
	var e_max := 0.0
	var restructured := {}
	var broke := {}
	var t0 := Time.get_ticks_msec()
	for d in range(days):
		m.advance_to(T0 + (d + 1) * 86400)
		e_min = minf(e_min, m.econ.e)
		e_max = maxf(e_max, m.econ.e)
		for b: MarketState.Book in m.books.values():
			if b.i <= 0.06 or b.i >= 19.0: pinned[b.id] = int(pinned.get(b.id, 0)) + 1
		for id in m.firms.firms:
			if int(m.firms.firms[id].restructured) > T0 + d * 86400: restructured[id] = true
		for f in m.actors.factions:
			var a: Dictionary = m.actors.factions[f]
			var liquid := float(a.cash) - float(a.debt)
			for firm in a.shares: liquid += float(a.shares[firm]) * m.firms.share_price_lmd(str(firm), m)
			if liquid < float(FactionAICatalog.info(str(f)).cash) * 0.03: broke[f] = int(broke.get(f, 0)) + 1
	var stuck := pinned.keys().filter(func(k): return int(pinned[k]) > 10)
	var poor := broke.keys().filter(func(k): return int(broke[k]) > days / 3)
	var ok := stuck.is_empty() and e_min < -0.05 and e_max > 0.05 and restructured.size() <= 5 and poor.is_empty()
	print("SIM seed=%d days=%d ms=%d E[%.2f, %.2f] stuck=%s restructured=%s poor=%s swire=%.1f %s" % [seed_value, days, Time.get_ticks_msec() - t0, e_min, e_max, str(stuck), str(restructured.keys()), str(poor), m.stock_price("swire"), "OK" if ok else "FAIL"])
	quit(0 if ok else 1)
