extends SceneTree
## 罗德岛时间缩放策划案 v0.2: the Rhodes clock runs × 8 on the real one (§3);
## insurance, crops, her restocks, voyages and parcels keep real time (§4.1);
## offline at most one real day is caught up (§5); a trading day pays ÷ 8
## (§6.3); research runs its written hours (§6.2); old saves go on (§6.5).
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

func run() -> void:
	MarketState.tz_override = 0
	BaseState.frozen_clock = T0
	BaseState.clock_offset = 0
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	game.fixed_market_seed = 77
	root.add_child(game)
	await step(8)
	game.seed_rng(77)
	check("the scale is 8 (拍板 1)", BaseState.TIME_SCALE == 8 and BaseState.time_scale == 8)
	_clocks()
	_real_things()
	_catch_up()
	_saves()
	_daily()
	_research()
	_market()
	print("TIME SCALE FAILURES: %d" % failures)
	BaseState.frozen_clock = 0
	BaseState.clock_offset = 0
	BaseState.rhodes_offset = 0
	quit(1 if failures > 0 else 0)

func _clocks() -> void:
	var r0 := BaseState.real_now()
	var h0 := BaseState.now()
	BaseState.clock_offset += 3600
	check("an hour of real time is 8 Rhodes hours", BaseState.real_now() - r0 == 3600 and BaseState.now() - h0 == 8 * 3600, BaseState.now() - h0)
	var before := BaseState.now()
	BaseState.set_time_scale(1)
	check("changing the scale does not move the clock", BaseState.now() == before)
	BaseState.clock_offset += 60
	check("at scale 1 a real minute is a Rhodes minute", BaseState.now() - before == 60)
	BaseState.set_time_scale(8)
	before = BaseState.now()
	BaseState.rhodes_offset += 86400
	check("rhodes_offset moves only the Rhodes clock", BaseState.now() - before == 86400 and BaseState.real_now() == r0 + 3660)
	BaseState.rhodes_offset -= 86400
	check("countdowns are in real time: 8 Rhodes hours ahead is 1 real hour", BaseState.real_left(BaseState.now() + 8 * 3600) == 3600)

func _real_things() -> void:
	var base := game.base
	# Insurance: real time only (§4.1).
	var blade := MaterialCatalog.create("异铁", 1)
	base.queue_insured(blade, 2 * 3600)
	BaseState.rhodes_offset += 5 * 86400
	check("insurance does not come on Rhodes time", base.tick_insurance().is_empty())
	BaseState.clock_offset += 2 * 3600 + 1
	check("insurance comes after its real hours", base.tick_insurance().has(blade))
	# Crops: real time only.
	base.set_facility("farm", 1)
	var p := game.provisions
	p.plot(0)
	p._state().plots[0] = {"crop": "舰载麦", "at": BaseState.real_now()}
	BaseState.rhodes_offset += 3 * 86400
	check("a crop does not grow on Rhodes time", p.growth(0) == 0.0 and p.seconds_left(0) == 2 * 3600, [p.growth(0), p.seconds_left(0)])
	BaseState.clock_offset += 3600
	check("half grown after a real hour", is_equal_approx(p.growth(0), 0.5), p.growth(0))
	BaseState.clock_offset += 3600
	check("ripe after its two real hours", p.ripe(0))
	p._state().plots[0] = {}
	# 可露希尔特供 and the 代售 shelf: real hours.
	base.closure_restock_at = 0
	base.closure_left(str(BaseCatalog.CLOSURE_LINE[0]))
	var left := base.closure_restock_in()
	BaseState.rhodes_offset += 86400
	check("her base restock keeps real time", base.closure_restock_in() == left and left == BaseCatalog.RESTOCK_SECONDS, [left, base.closure_restock_in()])
	var consign_left := game.consign.restock_in()
	BaseState.rhodes_offset += 86400
	check("the 代售 shelf restocks on the real hour", game.consign.restock_in() == consign_left)
	# Voyages: on the real clock.
	var v := game.voyage
	v.sailing = {"from": "a", "to": VoyageCatalog.ANCHORS[1], "mode": "standard", "start": BaseState.real_now(), "due": BaseState.real_now() + 3600, "fuel": false}
	BaseState.rhodes_offset += 3 * 86400
	v.tick(BaseState.real_now())
	check("a voyage does not arrive on Rhodes time", v.is_sailing())
	BaseState.clock_offset += 3601
	game.voyage.tick(BaseState.real_now())
	check("a voyage arrives after its real hours", not v.is_sailing())
	# 企鹅物流: a parcel's due is real.
	game.exchange.shipments = [{"id": 1, "faction": "penguin", "item": {}, "due": BaseState.real_now() + 7200}]
	BaseState.rhodes_offset += 86400
	check("a parcel is not delivered on Rhodes time", not game.exchange.shipments.is_empty())
	game.exchange.shipments.clear()
	# 远期, the wave and the swans: their real lengths (× scale on the Rhodes clock).
	check("forward terms are real lengths", Exchange.TERMS[0] * BaseState.time_scale == 8 * 3600)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var w := EconomyCycle._wave_len(rng)
	check("a cycle wave is 20–40 real days", w >= 20.0 * 86400 * 8 and w <= 40.0 * 86400 * 8, w / 86400.0)
	var m := game.market
	var total := 0.0
	var saved := m.swan.duplicate()
	for i in range(3000):
		m._schedule_swan()
		total += float(int(m.swan.at) - m.t)
	m.swan = saved
	check("black swans about 21 real days apart", absf(total / 3000.0 / (MarketState.SWAN_MEAN * 8) - 1.0) < 0.08, total / 3000.0 / 86400.0 / 8.0)

func _catch_up() -> void:
	var day := 86400 * 8
	var rows := [[3600, 8 * 3600, 0], [8 * 3600, 64 * 3600, 0], [86400, day, 0], [3 * 86400, day, 2 * day]]
	for r in rows:
		var split := BaseState.catch_up_split(int(r[0]) * 8)
		check("away %.0f real hours: catch up %d, stand still %d" % [r[0] / 3600.0, r[1], r[2]], int(split[0]) == int(r[1]) and int(split[1]) == int(r[2]), split)
	# A real day away is simulated in coarse steps, the last real hour in 16 s steps.
	var m := game.market
	m.advance_to(BaseState.now())
	var steps := [0]
	var sizes := {}
	var keep := m.on_step
	m.on_step = func(_t, dt):
		steps[0] += 1
		sizes[dt] = true
	BaseState.clock_offset += 2
	m.advance_to(BaseState.now())
	check("online: a 2 s real tick is one 16 s step", steps[0] == 1 and sizes.has(16), [steps[0], sizes.keys()])
	steps[0] = 0
	var t0 := Time.get_ticks_msec()
	var at := m.t
	# 用户 2026-11-20 加读条: the hook gets the share done, rising, at least every 50 ms of work.
	var shares := []
	m.progress_hook = func(done: float): shares.append(done)
	m.advance_to(at + day)
	m.progress_hook = Callable()
	var ms := Time.get_ticks_msec() - t0
	var rising := true
	for i in range(1, shares.size()): rising = rising and shares[i] >= shares[i - 1]
	check("the catch-up bar is told how far it is, rising, within 0–1", shares.size() >= maxi(1, ms / 200) and rising and shares.front() >= 0.0 and shares.back() <= 1.0 and shares.back() > 0.8, [shares.size(), ms, shares.slice(0, 3), shares.back() if not shares.is_empty() else -1])
	print("INFO catch-up of 8 Rhodes days: %d steps, %d ms" % [steps[0], ms])
	check("a real day of catch-up is at most about 3,300 steps", steps[0] <= 3400 and m.t == at + day, steps[0])
	check("no step is coarser than 900 s", sizes.keys().all(func(k): return int(k) <= 900), sizes.keys())
	m.on_step = keep
	# Bring the clock up to the market again.
	BaseState.rhodes_offset += m.t - BaseState.now()

func _saves() -> void:
	var before := BaseState.now()
	var data := BaseState.clock_data()
	BaseState.load_clock(data)
	check("the clock saves and loads without a jump", BaseState.now() == before)
	# Offline an hour: the saved clock comes back 8 Rhodes hours on.
	BaseState.clock_offset += 3600
	BaseState.load_clock(data)
	check("an hour away comes back 8 Rhodes hours on", BaseState.now() - before == 8 * 3600, BaseState.now() - before)
	# An old one-to-one save: Rhodes = real − stall; real-clock stamps + stall.
	var keep := [BaseState.anchor_real, BaseState.anchor_rhodes, BaseState.stall, BaseState.born]
	BaseState.load_clock({"stall": 5000})
	check("an old save's clock goes on from real − stall", BaseState.now() == BaseState.real_now() - 5000 and BaseState.legacy_stall == 5000)
	check("an old save's real-clock stamps move by its stall", BaseState.legacy_to_real(1000) == 6000 and BaseState.legacy_to_real(0) == 0)
	var base := BaseState.new()
	var saved := game.base.to_data()
	saved.erase("clock_v")
	saved["stall"] = 5000
	var crop_at := BaseState.real_now() - 6000
	saved["farm"] = {"plots": [{"crop": "舰载麦", "at": crop_at - 5000}], "kitchen": [], "next_job": 1, "meal": "", "mailed": ""}
	base.load_data(saved, {})
	check("an old save's crop keeps its real sowing time", int(base.farm.plots[0].at) == crop_at, [base.farm.plots[0].at, crop_at])
	var old_forward := {"expires": BaseState.now() + 3600}
	var ex_data := game.exchange.to_data()
	ex_data["forwards"] = [old_forward]
	ex_data["shipments"] = [{"id": 9, "faction": "penguin", "item": {}, "due": 1000}]
	var ex := game.exchange
	var keep_ex := ex.to_data()
	ex.load_data(ex_data)
	check("an old forward keeps its real time left", int(ex.forwards[0].expires) - BaseState.now() == 3600 * 8)
	check("an old parcel goes on the real clock", int(ex.shipments[0].due) == 6000)
	BaseState.legacy_stall = -1
	ex.load_data(keep_ex)
	BaseState.legacy_stall = -1
	BaseState.anchor_real = keep[0]
	BaseState.anchor_rhodes = keep[1]
	BaseState.stall = keep[2]
	BaseState.born = keep[3]

func _daily() -> void:
	var ex := game.exchange
	var fin := ex.fin
	for f in ["exchange", "workshop", "warehouse", "canteen", "hub"]: game.base.set_facility(f, 1)
	game.gold = 50000000
	var at8 := fin.need_lmd("workshop")
	BaseState.set_time_scale(1)
	var at1 := fin.need_lmd("workshop")
	var paid0 := fin.paid_total
	fin.carry = {}
	ex._new_day()
	var one_day := fin.paid_total - paid0
	BaseState.set_time_scale(8)
	check("a trading day's upkeep is ÷ 8", is_equal_approx(at8 * 8.0, at1), [at8, at1])
	fin.carry = {}
	paid0 = fin.paid_total
	for i in range(8): ex._new_day()
	var eight := fin.paid_total - paid0
	check("8 trading days cost what one did at scale 1 (±3%)", absf(float(eight) / maxf(1.0, one_day) - 1.0) < 0.03, [eight, one_day])
	check("a trading day eats the roster ÷ 8 in rations", is_equal_approx(fin.daily_rations(), fin.rations() / 8.0))
	BaseState.set_time_scale(1)
	var rate1 := fin.demand_rate("lmd")
	BaseState.set_time_scale(8)
	check("deposit rates a trading day are ÷ 8", is_equal_approx(fin.demand_rate("lmd") * 8.0, rate1))

func _research() -> void:
	check("research runs its written hours (× 0.2 taken off)", ResearchCatalog.seconds("logistics_1") == 3600, ResearchCatalog.seconds("logistics_1"))
	check("its time shows in real minutes", ResearchCatalog.duration_text("logistics_1") == "7 分钟", ResearchCatalog.duration_text("logistics_1"))

func _market() -> void:
	var m := game.market
	var t := m.t
	check("Rhodes and real time map back", absi(MarketState.rhodes_of(MarketState.real_of(t)) - t) <= 8)
	check("a date shows as the Rhodes day", MarketState.stamp(BaseState.born).begins_with("第 1 日"), MarketState.stamp(BaseState.born))
	# Seasonal events: the real calendar (拍板 4). A date a real day ahead is 8 Rhodes days ahead.
	var real_ahead := BaseState.real_now() + 86400
	check("a real date a day ahead is 8 Rhodes days ahead", absi(MarketState.rhodes_of(real_ahead) - BaseState.now() - 8 * 86400) <= 1)
