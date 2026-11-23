extends SceneTree
## 交易所统一行情修订案 v0.3 §7: 30 days of the unified market. Writes
## evidence/sim_unified.txt: each line's range, the plans started, what pumps
## and hoards made, faction cash and home help. Not in run_all (about 2 min).
const T0 := 1791972000
func _initialize() -> void: call_deferred("run")
func run() -> void:
	BaseState.time_scale = 1
	MarketState.tz_override = 0
	var seed_value := int(OS.get_environment("SIM_SEED")) if OS.get_environment("SIM_SEED") != "" else 7
	var days := int(OS.get_environment("SIM_DAYS")) if OS.get_environment("SIM_DAYS") != "" else 30
	var m := MarketState.new()
	m.start(T0, seed_value)
	if OS.get_environment("SIM_PLANS") == "0": m.plans.enabled = false
	var lo := {}
	var hi := {}
	var at_edge := {}
	var helps := {}
	var gaps := 0.0
	var samples := 0
	for f in m.actors.factions: helps[f] = 0
	var t0 := Time.get_ticks_msec()
	for hour in range(days * 24):
		var cash_before := {}
		for f in m.actors.factions: cash_before[f] = float(m.actors.factions[f].cash)
		m.advance_to(T0 + (hour + 1) * 3600)
		for cat in m.lines:
			var i := m.index(str(cat))
			lo[cat] = minf(float(lo.get(cat, INF)), i)
			hi[cat] = maxf(float(hi.get(cat, -INF)), i)
			if i < 0.4 or i > 2.5: at_edge[cat] = int(at_edge.get(cat, 0)) + 1
			var qlo := INF
			var qhi := -INF
			for q in m.quotes_of(str(cat)):
				qlo = minf(qlo, m.index(str(q)))
				qhi = maxf(qhi, m.index(str(q)))
			gaps += qhi / qlo - 1.0
			samples += 1
	var out: Array[String] = []
	out.append("unified market, %d days, seed %d, plans %s, %.1f s" % [days, seed_value, "on" if m.plans.enabled else "off", (Time.get_ticks_msec() - t0) / 1000.0])
	out.append("lines (min / max / now / hours past 0.4–2.5):")
	for cat in m.lines:
		out.append("  %-10s %.3f / %.3f / %.3f / %d" % [cat, lo[cat], hi[cat], m.index(str(cat)), int(at_edge.get(cat, 0))])
	out.append("mean gap between a pack's books: %.2f%%" % (gaps / samples * 100.0))
	out.append("plans started: %s" % str(m.plans.stats))
	for k in m.plans.returns:
		var r: Array = m.plans.returns[k]
		out.append("  %s mean return %+.1f%% over %d" % [k, float(r[0]) / maxf(1.0, float(r[1])) * 100.0, int(r[1])])
	for pid in m.plans.by_pid: out.append("  %s %s" % [pid, str(m.plans.by_pid[pid])])
	out.append("factions (cash now / start):")
	for f in m.actors.factions:
		var a: Dictionary = m.actors.factions[f]
		out.append("  %-10s cash %.2f  worth %.2f" % [f, float(a.cash) / maxf(float(a.start), 1.0), m.actors.worth(m, str(f)) / maxf(float(a.start), 1.0)])
	var plan_news := 0
	for n in m.news:
		if str(n.id) == "": plan_news += 1
	out.append("plan headlines in the last %d news: %d" % [m.news.size(), plan_news])
	var text := "\n".join(out)
	print(text)
	var file := FileAccess.open("res://../evidence/sim_unified%s.txt" % OS.get_environment("SIM_TAG"), FileAccess.WRITE)
	file.store_string(text + "\n")
	file.close()
	quit(0)
