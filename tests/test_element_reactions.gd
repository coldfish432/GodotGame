extends SceneTree

## 元素反应策划案 v0.2: one ring a target, its parts by element; a full ring
## bursts alone when one element holds 70% or more, otherwise the two leading
## elements react (ten pairs), stronger the more even they are; one 4 s
## cooldown; the ring decays as a whole; her ring bursts as its leading kind;
## the 爆发 family's chain splits by the shares; the signatures read shares.

var game: GameManager
var checks := 0
var failures := 0
var origin := Vector3.ZERO

func _initialize() -> void: call_deferred("run")
func step(n: int = 2) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool, seen: Variant = null) -> void:
	checks += 1
	if not passed:
		failures += 1
		if seen != null: print("   seen: ", seen)
	print(("PASS " if passed else "FAIL ") + label)

func run() -> void:
	_ring()
	_outcomes()
	game = GameManager.new()
	game.start_at_base = false
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	await step(10)
	origin = ContinuousWorldMap.ENTRY_POSITION
	origin.y = 0.65
	game.player.set_physics_process(false)
	game.pressure = 0
	SystemScreens.settings["auto_potion"] = false
	await _thresholds()
	await _reactions()
	await _her()
	print("DOWNFALL TEST_ELEMENT_REACTIONS: %d checks / %d failures" % [checks, failures])
	game.queue_free()
	await step(2)
	quit(1 if failures else 0)

func _ring() -> void:
	var g := ElementState.new()
	check("parts of different elements add up on one ring", not g.fill("burn", 40.0, 100.0, 4.0) and not g.fill("cold", 30.0, 100.0, 4.0) and is_equal_approx(g.total(), 70.0))
	var ring := g.ring(100.0)
	check("the ring draws each element's arc in GAUGE_KINDS order", ring.arcs.size() == 2 and ring.arcs[0][0] == "burn" and is_equal_approx(ring.arcs[0][1], 0.4) and ring.arcs[1][0] == "cold", ring)
	var went := g.fill("corr", 30.0, 100.0, Elements.BURST_COOLDOWN)
	check("it goes off at the threshold and keeps the shares it held", went and is_equal_approx(float(g.last_shares.burn), 0.4) and is_equal_approx(float(g.last_shares.corr), 0.3) and g.last_kind == "burn", g.last_shares)
	check("one 4 s cooldown for the whole ring", is_equal_approx(Elements.BURST_COOLDOWN, 4.0) and g.cooling() and g.gauges.is_empty() and not g.fill("nerve", 500.0, 100.0, 4.0))
	g.tick(3.9, 100.0)
	check("…still cooling at 3.9 s", g.cooling())
	g.tick(0.2, 100.0)
	check("…and fills again after 4 s", not g.cooling() and not g.fill("nerve", 10.0, 100.0, 4.0) and g.total() > 0.0)
	var d := ElementState.new()
	d.fill("burn", 30.0, 100.0, 4.0)
	d.fill("cold", 10.0, 100.0, 4.0)
	d.tick(3.0, 100.0)
	d.tick(1.0, 100.0)
	check("the ring decays as a whole: 10% of the threshold a second, shares kept", is_equal_approx(d.total(), 30.0) and is_equal_approx(float(d.shares().burn), 0.75), [d.total(), d.shares()])
	var s := ElementState.new()
	check("连锁 splits its amount by the shares", not s.spill({"burn": 0.5, "nerve": 0.5}, 30.0, 100.0, 4.0) and is_equal_approx(float(s.gauges.burn), 15.0) and is_equal_approx(float(s.gauges.nerve), 15.0))

func _outcomes() -> void:
	check("70% of one element bursts alone", Elements.outcome({"burn": 0.7, "cold": 0.3}).get("pure", "") == "burn")
	var r := Elements.outcome({"cold": 0.5, "nerve": 0.5})
	check("50/50 reacts at k = 1.2", r.get("pair", "") == "cold+nerve" and is_equal_approx(float(r.k), 1.2), r)
	var r2 := Elements.outcome({"nerve": 0.6, "burn": 0.4})
	check("60/40 reacts at k ≈ 1.03, the pair named in GAUGE_KINDS order", r2.get("pair", "") == "burn+nerve" and r2.main == "nerve" and absf(float(r2.k) - (0.7 + 0.5 * 0.4 / 0.6)) < 1e-6, r2)
	var r3 := Elements.outcome({"burn": 0.4, "cold": 0.3, "corr": 0.3})
	check("a third element only fills: the two leading react", r3.get("pair", "") == "burn+cold" and absf(float(r3.k) - 1.075) < 1e-6, r3)
	var pairs := {}
	for a in Elements.GAUGE_KINDS:
		for b in Elements.GAUGE_KINDS:
			if a != b: pairs[Elements.pair_key(a, b)] = true
	check("ten pairs, each with a reaction", pairs.size() == 10 and pairs.keys().all(func(key): return Elements.REACTIONS.has(key)) and Elements.REACTIONS.size() == 10)

func enemy(type: String = "thug", at := Vector3(1.5, 0, 0)) -> Enemy:
	var e := game._spawn_enemy(origin + at, false, false, type)
	e.set_physics_process(false)
	return e

## Fills `e`'s ring with `split` (kind → share) straight, as dealt damage would.
func charge(e: Enemy, split: Dictionary) -> void:
	for kind in split: e.elements.fill(kind, e.gauge_threshold() * float(split[kind]) + 0.01, e.gauge_threshold(), e.burst_cooldown())
	e._pending_burst = e.elements.last_shares.duplicate()

func _thresholds() -> void:
	var growth := Scaling.floor_growth(game.floor_number) * game.contract_life()
	var thug := enemy("thug")
	var slug := enemy("slug")
	var elite := game._spawn_enemy(origin + Vector3(1.5, 0, 1.5), true, false, "elite")
	elite.set_physics_process(false)
	check("T is fixed by rank, not by life: a slug and a thug share it", is_equal_approx(thug.gauge_threshold(), slug.gauge_threshold()) and is_equal_approx(thug.gauge_threshold(), Elements.T0 * growth), [thug.gauge_threshold(), slug.gauge_threshold()])
	check("an elite's T is a normal one's (方舟 1000 / 1000)", is_equal_approx(elite.gauge_threshold(), thug.gauge_threshold()))
	check("a boss's T is twice", is_equal_approx(Elements.threshold(false, true, growth), 2.0 * thug.gauge_threshold()))
	thug.max_health *= 3.0
	check("…and more life does not move it", is_equal_approx(thug.gauge_threshold(), Elements.T0 * growth))
	check("the ring fills ×1 with the elemental damage dealt", is_equal_approx(Elements.GAUGE_FILL, 1.0))
	for e in [thug, slug, elite]: e.queue_free()
	await step()

func _reactions() -> void:
	var e := enemy()
	e.health = e.max_health * 100.0
	var before := e.health
	charge(e, {"burn": 0.5, "cold": 0.5})
	e._tick_elements(0.05)
	var t := e.gauge_threshold()
	var hit := before - e.health
	# 骤裂: T × 0.7 × 1.2 physical, half DEF ignored.
	var want := CombatStats.mitigate(t * 0.7 * 1.2, "phys", e.effective_defense() * 0.5, e.res_against("phys"))
	check("灼燃 + 寒冷 50/50: 骤裂 deals T × 0.7 × 1.2 physical past half DEF", absf(hit - want) < 1.0 and not e.statuses.has("frozen"), [hit, want])
	check("the ring cools 4 s after a reaction", e.elements.cooling() and absf(e.elements.cooldown_left - (Elements.BURST_COOLDOWN - 0.05)) < 1e-4, e.elements.cooldown_left)
	e.queue_free()
	var f := enemy()
	charge(f, {"cold": 0.5, "nerve": 0.5})
	f._tick_elements(0.05)
	check("寒冷 + 神经: 僵直 freezes 2.5 s", is_equal_approx(f.stun_timer, 2.5) and f.statuses.has("frozen"), f.stun_timer)
	f.queue_free()
	var c := enemy()
	charge(c, {"corr": 0.5, "nerve": 0.5})
	c._tick_elements(0.05)
	check("侵蚀 + 神经: 蚀神 lays two 降防 stacks", c.corr_stacks == 2, c.corr_stacks)
	c.queue_free()
	var x := enemy()
	charge(x, {"cold": 0.5, "corr": 0.5})
	x._tick_elements(0.05)
	check("寒冷 + 侵蚀: 脆化 makes it fragile 25% and slow", is_equal_approx(x.status_value("fragile"), 0.25) and is_equal_approx(x.status_value("slow"), 0.30))
	x.queue_free()
	var y := enemy()
	charge(y, {"burn": 0.5, "necro": 0.5})
	y._tick_elements(0.05)
	check("灼燃 + 凋亡: 焚身 burns as arts over 6 s and cuts 法抗 20", y.elements.has_dot("pyre") and is_equal_approx(y.status_value("res_down"), 20.0))
	y.queue_free()
	# 源石爆燃 reaches the enemies within 3 m.
	var centre := enemy("thug", Vector3(1.5, 0, 0))
	var near := enemy("thug", Vector3(3.0, 0, 0))
	var far := enemy("thug", Vector3(9.0, 0, 0))
	for m in [centre, near, far]: m.health = m.max_health * 100.0
	var near_before := near.health
	var far_before := far.health
	charge(centre, {"burn": 0.5, "corr": 0.5})
	centre._tick_elements(0.05)
	check("灼燃 + 侵蚀: 源石爆燃 hits within 3 m, not beyond", near.health < near_before and is_equal_approx(far.health, far_before), [near_before - near.health, far_before - far.health])
	for m in [centre, near, far]: m.queue_free()
	# A pure burst still is the v1.1 burst.
	var p := enemy()
	charge(p, {"cold": 0.8, "burn": 0.2})
	p._tick_elements(0.05)
	check("80% 寒冷 bursts alone: frozen 2 s", is_equal_approx(p.stun_timer, 2.0) and p.statuses.has("frozen"), p.stun_timer)
	p.queue_free()
	# The 侵蚀 signature answers a reaction that holds 30% 侵蚀.
	var pl := game.player
	pl.stats["sig_cascade"] = 1.0
	var a := enemy("thug", Vector3(1.5, 0, 0))
	var b := enemy("thug", Vector3(2.5, 0, 0))
	charge(a, {"burn": 0.6, "corr": 0.4})
	a._tick_elements(0.05)
	check("晶簇裂解 answers a reaction with 40% 侵蚀", b.corr_stacks == 1, b.corr_stacks)
	pl.stats["sig_cascade"] = 0.0
	a.queue_free()
	b.queue_free()
	await step()

func _her() -> void:
	var p := game.player
	p.invulnerable = false
	p.hp = p.max_hp
	p.elements.state.clear()
	var t := p.max_hp * Elements.HER_THRESHOLD
	p.elements._fill("nerve", t * 0.4)
	p.elements._fill("burn", t * 0.6 + 1.0)
	check("her ring is one ring too and bursts as its leading kind (灼燃: 12% life)", p.elements.state.cooling() and absf((p.max_hp - p.hp) - p.max_hp * 0.12) < 1.0, p.max_hp - p.hp)
	p.hp = p.max_hp
	p.elements.state.clear()
	await step()
