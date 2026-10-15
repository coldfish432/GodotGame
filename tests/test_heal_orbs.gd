extends SceneTree
## 用户 2026-10-14: 敌人概率掉落治疗球立即回复血量 — healing orbs (HealOrb):
## they come out of fallen enemies at LootTables.HEAL_ORBS odds, drift to her
## when she is near, and heal the moment they touch her.
var game: GameManager
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func step(count: int = 1) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func check(label: String, passed: bool, seen: Variant = null) -> void:
	checks += 1
	if not passed:
		failures += 1
		if seen != null: print("   seen: ", seen)
	print(("PASS " if passed else "FAIL ") + label)

func orbs() -> Array:
	return get_nodes_in_group("heal_orbs").filter(func(o): return not o.is_queued_for_deletion())

func run() -> void:
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	await step(3)
	await game.start_contract("mine")
	await step(3)
	game._clear_field()
	await step(2)
	var p := game.player
	var at := p.global_position
	p.hp = p.max_hp * 0.5
	var orb := HealOrb.new()
	orb.game = game
	orb.fraction = 0.1
	game.add_child(orb)
	orb.global_position = game.world_map.nearest_walkable(at + Vector3(2.0, 0, 0))
	var before := p.hp
	await step(4)
	check("an orb out of her reach stays put", orbs().size() == 1 and is_equal_approx(p.hp, before))
	p.teleport(orb.global_position + Vector3(-2.0, 0, 0))
	for i in range(90):
		await step(1)
		if orbs().is_empty(): break
	check("near her it drifts to her and is taken", orbs().is_empty())
	# (Her own healing bonus applies, as to any heal.)
	var expected := minf(p.max_hp, before + p.max_hp * 0.1 * (1.0 + float(p.stats.get("heal_pct", 0.0))))
	check("it heals a tenth of her life at once", p.hp >= expected - 0.5 and p.hp <= expected + p.max_hp * 0.01, [before, p.hp, expected])
	# The odds over many kills.
	var normal := 0
	var elite := 0
	for i in range(400):
		var e := game._spawn_enemy(at + Vector3(4, 0, 0), false, false, "thug")
		game._drop_heal_orbs(e)
		e.queue_free()
		normal += orbs().size()
		for o in orbs(): o.queue_free()
		await process_frame
	for i in range(200):
		var e := game._spawn_enemy(at + Vector3(4, 0, 0), true, false, "armed")
		game._drop_heal_orbs(e)
		e.queue_free()
		elite += orbs().size()
		for o in orbs(): o.queue_free()
		await process_frame
	check("normal enemies drop an orb about a fifth of the time", absf(normal / 400.0 - LootTables.HEAL_ORBS.normal.chance) < 0.07, normal)
	check("elites usually drop two", elite / 200.0 > 1.2, elite)
	print("HEAL ORBS RESULT: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
