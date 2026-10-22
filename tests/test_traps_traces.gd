extends SceneTree

## 陷阱 (密室与陷阱修订案_v1 §2.2) and 踪迹点 (干员寻访策划案 §13), 用户 2026-10-17:
## a trap's fixed blow that can kill and raises the 威胁值, traps crowding a
## vault's wall, and a trace left at a dead end now and then, fewer on floors
## shallow for her operator.

var game: GameManager
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool, detail: Variant = null) -> void:
	checks += 1
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label + ("" if detail == null or passed else "  %s" % str(detail)))

func run() -> void:
	check("a trace on 20% of floors at her depth", is_equal_approx(RecruitCatalog.trace_chance(5, 5), 0.2))
	check("fewer on floors shallower than that", RecruitCatalog.trace_chance(1, 6) < RecruitCatalog.trace_chance(5, 6) and RecruitCatalog.trace_chance(1, 40) >= 0.2 * RecruitCatalog.TRACE_FLOOR - 0.0001)
	# Repeats (用户 2026-10-17): a small one found again adds nothing, a big one half.
	var state := BaseState.new()
	var who: String = RecruitCatalog.in_region("mine")[0]
	var gains := [state.add_trace(who, "s1"), state.add_trace(who, "s1"), state.add_trace(who, "b1"), state.add_trace(who, "b1")]
	check("traces: new small +1, repeat small 0, new big +2, repeat big +1 %s" % [gains], gains == [1, 0, 2, 1] and state.clues(who) == 4)
	var copy := BaseState.new()
	copy.load_data(state.to_data(), {})
	check("the traces found survive a save", copy.found_before(who, "s1") and copy.found_before(who, "b1") and not copy.found_before(who, "s2"))
	check("a higher operator is suited deeper", RecruitCatalog.suited_floor(0, 1) == 1 and RecruitCatalog.suited_floor(2, 1) > RecruitCatalog.suited_floor(0, 10))
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 2718
	root.add_child(game)
	await step(8)
	game.world_map.force_vault = 1
	await game.start_contract("mine")
	await step(4)
	var mouth: Vector2 = game.world_map.vault_mouth
	check("4 to 7 traps on a floor (%d)" % game.traps.size(), game.traps.size() >= 4 and game.traps.size() <= 7)
	var near := game.traps.filter(func(t): return Vector2(t.global_position.x, t.global_position.z).distance_to(mouth) <= game.VAULT_TRAP_REACH).size()
	check("half or more crowd the vault's wall (%d)" % near, near >= ceili(game.traps.size() * 0.5))
	check("none behind the wall", game.traps.all(func(t): return not game.world_map.vault_hidden(Vector2(t.global_position.x, t.global_position.z))))
	for e in game.floor_enemies(): e.global_position += Vector3(300, 0, 300)
	# A heavy trap under her, the light one the farthest from it, the rest out of
	# the way: traps crowd the vault's wall, and a step off one must not land on another.
	var trap: FieldTrap = game.traps[0]
	var light: FieldTrap = game.traps.slice(1).reduce(func(a, b): return b if b.global_position.distance_to(trap.global_position) > a.global_position.distance_to(trap.global_position) else a)
	for other in game.traps:
		if other != trap and other != light: other.global_position += Vector3(300, 0, 300)
	var off := trap.global_position.direction_to(light.global_position)
	off = Vector3(-off.x, 0, -off.z).normalized() * 4.0
	trap.kind = "heavy"
	# Ungeared she has 600 HP, which a heavy trap's 600 takes whole: dress her
	# in the Rhodes issue so the blow can be measured.
	var kit_rng := RandomNumberGenerator.new()
	kit_rng.seed = 2718
	# Prefixes off: one like 受到伤害 +x% would change the measured blow.
	for piece in GearCatalog.rhodes_kit(kit_rng, game.player.operator_id):
		piece.prefixes.clear()
		game.player.equip(piece)
	game.player.hp = game.player.max_hp
	game.player.shield = 0.0
	game.threat.value = 0.0
	var hp := game.player.hp
	game.player.teleport(trap.global_position)
	await step(2)
	# 用户 2026-10-22: a heavy trap gives itself away, its blow lands after its fuse.
	check("a heavy trap lights its fuse: no blow yet, the 威胁值 up by 8", trap.fuse > 0.0 and absf(hp - game.player.hp) < 1.0 and absf(game.threat.value - 8.0) < 0.3, [trap.fuse, hp, game.player.hp, game.threat.value])
	await step(40)
	# Its fixed 600 × the floor's 档位系数 (复利数值改造清单 E; 1 on floor 1).
	var blow := float(FieldTrap.KINDS.heavy.damage) * Scaling.tier_coef(game.floor_number)
	check("then it strikes once for its fixed %d" % roundi(blow), absf(hp - game.player.hp - blow) < 1.0, [hp, game.player.hp, game.player.max_hp])
	check("and its sprung model takes its place", (trap.get_node("Look") as MeshInstance3D).mesh != TerraceDressing.kit_mesh(load(FieldTrap.MODEL % [trap.region, "heavy"])))
	var after := game.player.hp
	game.player.teleport(trap.global_position + off)
	await step(1)
	game.player.teleport(trap.global_position)
	await step(2)
	# Out of combat she regains a little meanwhile; no second blow lands.
	check("sprung, it is spent", trap.spent and game.player.hp >= after - 0.5, [after, game.player.hp])
	# Out of a lit fuse before it ends: no blow.
	var dodge: FieldTrap = FieldTrap.new()
	dodge.setup(game, "heavy", "mine")
	game.world_map._generated_root.add_child(dodge)
	dodge.global_position = trap.global_position + off * 2.0
	game.traps.append(dodge)
	game.player.hp = game.player.max_hp
	game.player.teleport(dodge.global_position)
	await step(2)
	game.player.teleport(dodge.global_position + off)
	var whole := game.player.hp
	await step(40)
	check("stepped out of a lit fuse, she takes no blow", dodge.spent and game.player.hp >= whole - 1.0, [whole, game.player.hp])
	# A foe on her trail springs one, takes its blow, and the 威胁值 stays.
	var foe: Enemy = game.floor_enemies()[0]
	var lure: FieldTrap = FieldTrap.new()
	lure.setup(game, "light", "mine")
	game.world_map._generated_root.add_child(lure)
	lure.global_position = dodge.global_position + off * 2.0
	game.traps.append(lure)
	var threat_before := game.threat.value
	var foe_hp := foe.health
	foe.state = Enemy.State.CHASING
	foe.global_position = lure.global_position
	await step(2)
	check("a foe on her trail springs it and takes its blow, the 威胁值 unchanged", lure.spent and not lure.by_player and foe.health < foe_hp and absf(game.threat.value - threat_before) < 0.5, [lure.spent, foe_hp, foe.health, game.threat.value, threat_before])
	foe.global_position += Vector3(300, 0, 300)
	light.kind = "light"
	game.player.invulnerable = true
	game.player.teleport(light.global_position)
	await step(2)
	check("a dash's invulnerability passes over it", not light.spent)
	game.player.invulnerable = false
	game.player.hp = 100.0
	await step(2)
	check("it can kill", (not is_instance_valid(light) or light.spent) and (game.player.hp <= 0.0 or not game.settlement_view.is_empty()))
	await step(4)
	# Traces.
	game.base.recruit_clues.clear()
	game.force_trace = true
	game.world_map.force_vault = 0
	await game.start_contract("mine")
	await step(4)
	check("a trace is left at a dead end for one she is seeking", is_instance_valid(game.trace_point) and game.trace_point.operator in RecruitCatalog.in_region("mine"))
	if is_instance_valid(game.trace_point):
		var id := game.trace_point.operator
		var worth := RecruitCatalog.trace_value(game.trace_point.key, false)
		game.player.teleport(game.trace_point.global_position + Vector3(0.8, 0, 0))
		await step(2)
		check("its prompt is the E key's (no name over it)", game.interaction_prompt() == "踪迹")
		game._interact()
		await step(1)
		check("picked up, her traces rise by what it is worth (%d)" % worth, game.base.clues(id) == worth and not is_instance_valid(game.trace_point))
	game.settle(true)
	await step(2)
	for id in RecruitCatalog.in_region("mine"): game.base.recruit_clues[id] = RecruitCatalog.CLUES_NEEDED
	await game.start_contract("mine")
	await step(4)
	check("no trace once every trace here is in", not is_instance_valid(game.trace_point))
	game.force_trace = false
	print("TRAPS TRACES RESULT: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await step(2)
	quit(1 if failures else 0)
