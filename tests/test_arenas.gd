extends SceneTree

## Boss战场地策划案_v1_0.md (用户 2026-10-19): a boss floor is its arena and
## nothing else; the way out is shut until the boss falls; cover the big moves
## break stays broken; each region's device from its original stage.

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
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 4242
	root.add_child(game)
	await step(8)
	await _layout()
	await _mine()
	await _city()
	await _snow()
	await _siracusa()
	print("ARENAS RESULT: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await step(2)
	quit(1 if failures else 0)

func kill(enemy) -> void:
	if is_instance_valid(enemy) and not enemy._dead: enemy.take_hit(99999999.0, "true")

func nodes(group: String) -> Array:
	return game.get_tree().get_nodes_in_group(group).filter(func(n): return n.get("game") == game)

func go_to(region: String, floor: int) -> void:
	if game.in_base or game.region_id != region:
		if not game.in_base:
			game.settle(true)
			await step(2)
		await game.start_contract(region)
		await step(2)
	game.floor_number = floor - 1
	await game.advance(0)
	await step(4)

func into_arena() -> void:
	game.player.teleport(game.world_map.nearest_walkable(game.arena.centre + Vector3(0, 0, -6.0)))
	game.player.invuln_timer = 0.0
	await step(4)

# --- The floor -------------------------------------------------------------------------

func _layout() -> void:
	await go_to("city", 10)
	check("a warden floor keeps its ordinary map", not game.world_map.boss_layout and not is_instance_valid(game.arena))
	for region in ["mine", "city", "snow", "siracusa"]:
		await go_to(region, 20)
		var map := game.world_map
		check("%s floor 20 is an arena floor" % region, map.boss_layout and is_instance_valid(game.arena))
		check("%s: the arena is 13 m round" % region, is_equal_approx(map.arena_radius, BossCatalog.ARENA_RADIUS))
		check("%s: one tier throughout, no bridges" % region, Array(map.levels).all(func(l): return l == 0) and map.bridges.is_empty())
		check("%s: the boss is the only foe on the floor" % region, game.floor_enemies().size() == 1 and game.floor_enemies()[0] == game.outpost_boss, game.floor_enemies().size())
		check("%s: no boxes, posts, traps or traces" % region, nodes("loot_containers").is_empty() and nodes("guard_posts").is_empty() and game.traps.is_empty() and not is_instance_valid(game.trace_point))
		check("%s: no 坎诺特 or squad" % region, game.encounter.is_empty())
		check("%s: the boss stands in the arena" % region, game.arena.inside(game.outpost_boss.global_position))
		var marker: Vector3 = map.route_nodes[0].global_position
		check("%s: the route markers are past the shut gate" % region, not game.arena.inside(marker) and not game.arena.exit_open() and not game.line_of_sight(game.arena.centre + Vector3.UP, game.arena.gate.global_position + Vector3(0, 0, 1.0)))
		check("%s: it has its cover" % region, game.arena.standing_cover() >= 2)

# --- 矿区 ------------------------------------------------------------------------------------

func _mine() -> void:
	await go_to("mine", 20)
	var figure := game.outpost_boss
	var arena := game.arena
	check("矿区 has its 源石祭坛 and three 干扰地雷", is_instance_valid(arena.shrine) and arena.mines.size() == 3)
	# She arms a mine with E.
	var mine: Dictionary = arena.mines[0]
	game.player.teleport(mine.node.global_position + Vector3(0.8, 0, 0))
	await step(2)
	check("standing by a mine, E is offered", game.interaction_prompt() == "干扰地雷", game.interaction_prompt())
	game._interact()
	check("E arms it", mine.armed)
	# 爱国者 steps on it.
	await into_arena()
	figure._engage()
	figure.global_position = Vector3(mine.node.global_position.x, figure.global_position.y, mine.node.global_position.z)
	var hp := figure.health
	await step(3)
	check("he sets it off: hurt, and fragile for 15 s", mine.spent and figure.health < hp and is_equal_approx(figure.status_value("fragile"), BossCatalog.MINE_FRAGILE))
	# The shrine pulses on whoever is by it.
	figure.global_position = Vector3(arena.shrine.global_position.x + 1.0, figure.global_position.y, arena.shrine.global_position.z)
	game.player.teleport(arena.shrine.global_position + Vector3(-1.0, 0, 0))
	game.player.hp = game.player.max_hp
	game.player.invuln_timer = 0.0
	arena.shrine_time = 0.05
	var her := game.player.hp
	var contamination := game.features.value("contamination")
	await step(4)
	check("the pulse hits her for 12% of her life", her - game.player.hp >= game.player.max_hp * BossCatalog.SHRINE_HIT * 0.9, [her, game.player.hp])
	check("…and raises her contamination", game.features.value("contamination") >= contamination + BossCatalog.SHRINE_CONTAM * 0.9)
	check("…and empowers him", figure.shrine_stacks == 1)
	# 用户 2026-10-20: he raises more at random spots, and sets one off at once with her by it.
	figure._cancel_move()
	var raise := BossCatalog.move_at(BossCatalog.MOVES.patriot.filter(func(m): return m.id == "raise_shrine")[0], 4)
	figure._start(raise)
	check("raising shrines marks their spots first", figure._markers.size() == 2 and arena.raised.is_empty())
	for i in range(int(figure._windup * 60.0) + 6): await step(1)
	check("…then two more 源石祭坛 stand, apart from the rest", arena.raised.size() == 2 and arena.shrines().size() == 3 and _apart(arena.shrines(), BossCatalog.SHRINE_APART - 0.5))
	var far: Node3D = arena.raised[0].node
	var away := far.global_position - arena.shrine.global_position
	away.y = 0.0
	game.player.teleport(far.global_position + away.normalized())
	game.player.hp = game.player.max_hp
	game.player.invuln_timer = 0.0
	arena.raised[0].time = 99.0
	figure._cancel_move()
	figure._start(BossCatalog.MOVES.patriot.filter(func(m): return m.id == "shrine_call")[0])
	check("with her by one, he can call it: its reach goes red first", figure._markers.size() == 1 and figure._ctx.node == far)
	her = game.player.hp
	for i in range(int(figure._windup * 60.0) + 6): await step(1)
	check("…and it pulses at once, its count starting over", her > game.player.hp and float(arena.raised[0].time) > BossCatalog.SHRINE_EVERY - 1.0, [her, game.player.hp, arena.raised[0].time])
	figure._cancel_move()
	figure.reset_whole()
	await step(2)
	check("a reset takes the raised ones away", arena.raised.is_empty() and arena.shrines().size() == 1)
	# The big move breaks cover; a reset does not mend it (Q6).
	figure.tier = 3
	var before := arena.standing_cover()
	figure._ctx = {"spots": [arena.centre + Vector3(0, 0, 9.0)]}
	figure._break_cover({"shape": "safe_zones", "big": true})
	check("源石爆发 breaks the cover outside the safe circles", arena.standing_cover() < before, [before, arena.standing_cover()])
	var left := arena.standing_cover()
	figure.reset_whole()
	await step(2)
	check("broken cover stays broken after a reset", arena.standing_cover() == left)
	check("…while the mines are back", arena.mines.all(func(m): return not m.spent and not m.armed))
	# Its fall opens the gate.
	await into_arena()
	kill(figure)
	await step(3)
	check("its fall opens the way out", arena.exit_open() and game.outpost_cleared)

# --- 龙门 ------------------------------------------------------------------------------------

func _city() -> void:
	await go_to("city", 20)
	var arena := game.arena
	check("龙门 has three 医疗符文 and four alley mouths", arena.runes.size() == 3 and arena.mouths().size() == 4)
	var rune: Dictionary = arena.runes[0]
	game.player.teleport(rune.node.global_position)
	game.player.hp = game.player.max_hp * 0.5
	var hp := game.player.hp
	await step(30)
	check("a rune heals her", game.player.hp > hp + game.player.max_hp * 0.005, [hp, game.player.hp])
	arena.bury_runes(rune.node.global_position, 1.0)
	check("沙狱 buries it", arena.rune_under(rune.node.global_position).is_empty())
	var figure := game.outpost_boss
	figure.tier = 3
	var stampede: Dictionary = BossCatalog.moves_for("rat_king", 3, 3).filter(func(m): return m.id == "stampede")[0]
	var lanes := figure._lane_set(stampede)
	var mouths := arena.mouths()
	check("鼠潮 runs out of the alley mouths", lanes.size() == 3 and lanes.all(func(l): return mouths.any(func(m): return m.distance_to(l[0]) < 0.5)))

# --- 萨米 ------------------------------------------------------------------------------------

func _snow() -> void:
	await go_to("snow", 20)
	var arena := game.arena
	check("萨米 has two fires in the arena, the first lit", game.fires.size() == 2 and game.fires[0].lit() and not game.fires[1].lit() and game.fires.all(func(f): return arena.inside(f.global_position)))
	check("…and the 木裂 totem", not arena.totem.is_empty())
	var figure := game.outpost_boss
	await into_arena()
	figure._engage()
	figure._rampage()
	await step(2)
	check("the first 自我泯灭 breaks the totem", arena.totem.is_empty())
	check("…leaving fissured ice that chills", figure.zones.any(func(z): return str(z.get("feature", "")) == "cold"))

# --- 叙拉古 ----------------------------------------------------------------------------------

func _siracusa() -> void:
	await go_to("siracusa", 20)
	var arena := game.arena
	var townsfolk := nodes("civilians")
	check("叙拉古 has six 平民 round the piazza", townsfolk.size() == BossCatalog.CIVILIANS)
	check("…who are not foes", game.floor_enemies().size() == 1)
	check("…and the fountain, which never breaks", arena.cover.any(func(c): return c.kind == "fountain" and c.unbreakable))
	var debt := game.features.value("debt")
	var one: Civilian = townsfolk[0]
	check("…drawn from their own board (B2 v5)", one.directional and one.has_walk and one.sheet_type == "civilian" and one._tint == Color.WHITE)
	one.take_hit(500.0, "phys")
	check("her blow on one adds 5 血债", is_equal_approx(game.features.value("debt") - debt, BossCatalog.CIVILIAN_DEBT * game.features.growth_mult("debt", game.floor_number) * game.voyage.debt_mult("siracusa")), game.features.value("debt") - debt)
	check("…and it runs", one.fleeing and not one._dead)
	await step(6)
	check("…after cringing a moment, arms over its head", one._sprite.texture == FieldArt.enemy_dir_pose("civilian", one.dir_column, Civilian.FLINCH) and one.current_speed() == 0.0)
	await step(int((Civilian.FLEE_MAX + 1.0) * 60.0))
	check("…out of the piazza", not is_instance_valid(one) or one._dead)
	# 用户 2026-10-20: the rest wander the piazza, near where they stood.
	var rest: Array = nodes("civilians").filter(func(c): return not c.fleeing)
	check("the others amble about the piazza", rest.any(func(c): return c._flat_distance(c.global_position, c.home) > 0.5 or c.wandering), rest.map(func(c): return c._flat_distance(c.global_position, c.home)))
	check("…never leaving it", rest.all(func(c): return arena.inside(c.global_position)))
	# 扎罗's blow lands on one: it runs, and the 血债 is not hers.
	var figure := game.outpost_boss
	var two: Civilian = rest[0]
	two.global_position = figure.global_position + Vector3(1.5, 0, 0)
	figure.attack_origin = figure.global_position
	figure.attack_direction = Vector3.RIGHT
	debt = game.features.value("debt")
	figure._strike_civilians_by({"shape": "sector", "reach": 2.6, "angle": 120.0})
	check("扎罗's claw on a 平民 sends it running", two.fleeing)
	var one_debt := BossCatalog.CIVILIAN_DEBT * game.features.growth_mult("debt", game.floor_number) * game.voyage.debt_mult("siracusa")
	check("…and adds 血债 as hers would", is_equal_approx(game.features.value("debt") - debt, one_debt), game.features.value("debt") - debt)
	# The family's blows too.
	var three: Civilian = rest[1]
	var soldier: Enemy = game._spawn_enemy(three.global_position + Vector3(-1.0, 0, 0), false, false, "family_soldier")
	soldier.set_physics_process(false)
	soldier.attack_origin = soldier.global_position
	soldier.attack_direction = Vector3.RIGHT
	soldier.attack_phase = "windup"
	soldier._strike_civilians()
	check("…and a family soldier's, 血债 too", three.fleeing and is_equal_approx(game.features.value("debt") - debt, one_debt * 2.0), game.features.value("debt") - debt)

func _apart(nodes_list: Array, gap: float) -> bool:
	for i in range(nodes_list.size()):
		for j in range(i + 1, nodes_list.size()):
			var a: Vector3 = nodes_list[i].global_position
			var b: Vector3 = nodes_list[j].global_position
			if Vector2(a.x - b.x, a.z - b.z).length() < gap: return false
	return true
