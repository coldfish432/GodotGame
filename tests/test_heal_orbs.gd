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
	orb.global_position = game.world_map.nearest_walkable(at + Vector3(4.0, 0, 0))
	var placed := orb.global_position
	var before := p.hp
	await step(30)
	check("an orb out of her reach stays put", orbs().size() == 1 and p.hp < before + p.max_hp * 0.02 and orb.global_position.distance_to(Vector3(placed.x, game.ground_y(placed), placed.z)) < 0.05, [placed, orb.global_position, before, p.hp])
	p.teleport(orb.global_position + Vector3(-2.0, 0, 0))
	for i in range(90):
		await step(1)
		if orbs().is_empty(): break
	check("near her it drifts to her and is taken", orbs().is_empty())
	# (Her own healing bonus applies, as to any heal.)
	var expected := minf(p.max_hp, before + p.max_hp * 0.1 * (1.0 + float(p.stats.get("heal_pct", 0.0))))
	check("it heals a tenth of her life at once", p.hp >= expected - 0.5 and p.hp <= expected + p.max_hp * 0.01, [before, p.hp, expected])
	# 用户 2026-10-15: 治疗球会飞，角色吃不到 — the dropper sets an orb's place
	# after add_child, and _ready took its landing spot then: the world origin,
	# so every dropped orb flew off there. Dropped by a real kill on the flat,
	# on a ramp and on a terrace, it lands by the body on the ground there and
	# she takes it walking up.
	var spots := {"flat": at}
	var ramps: Array[Dictionary] = game.world_map.ramp_midpoints()
	if not ramps.is_empty():
		var ramp: Dictionary = ramps[0]
		spots["ramp"] = Vector3(ramp.point.x, 0.0, ramp.point.y)
		var top: Vector2 = ramp.point + ramp.up * 7.0
		spots["terrace"] = Vector3(top.x, 0.0, top.y)
	check("the map has a ramp and a terrace to try", spots.size() == 3)
	for spot in spots:
		var site: Vector3 = game.world_map.nearest_walkable(spots[spot])
		site.y = game.ground_y(site)
		p.teleport(site + Vector3(0, 0, 9.0))
		p.hp = p.max_hp * 0.5
		var e := game._spawn_enemy(site, true, false, "armed")
		e.global_position = site
		for i in range(60):
			game._drop_heal_orbs(e)
			if not orbs().is_empty(): break
		e.queue_free()
		await step(30)
		var landed := orbs()
		var low := true
		var near := true
		for o in landed:
			var flat := Vector2(o.global_position.x - site.x, o.global_position.z - site.z)
			near = near and flat.length() < 1.6
			low = low and absf(o.global_position.y - game.ground_y(o.global_position)) < 0.05
		check("on the %s the orb lands by the body, not off at the origin" % spot, not landed.is_empty() and near, [site, landed.map(func(o): return o.global_position)])
		check("on the %s it rests on the ground there" % spot, not landed.is_empty() and low, [landed.map(func(o): return [o.global_position.y, game.ground_y(o.global_position)])])
		var hp_before := p.hp
		# She steps onto the body: orbs land up to 1.2 m (1.6 m after
		# nearest_walkable) from it on any side, so a spot 1.5 m off left the
		# far one of an elite's two up to 2.7 m away, beyond ATTRACT.
		p.teleport(site)
		for i in range(90):
			await step(1)
			if orbs().is_empty(): break
		check("on the %s she takes it" % spot, orbs().is_empty() and p.hp > hp_before, [orbs().size(), hp_before, p.hp])
		for o in orbs(): o.queue_free()
		await process_frame
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
	check("normal enemies drop an orb at the table's rate", absf(normal / 400.0 - LootTables.HEAL_ORBS.normal.chance) < 0.07, normal)
	var e_orbs: Dictionary = LootTables.HEAL_ORBS.elite
	check("elites drop orbs at the table's rate", absf(elite / 200.0 - e_orbs.chance * e_orbs.count) < 0.12, elite)
	print("HEAL ORBS RESULT: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
