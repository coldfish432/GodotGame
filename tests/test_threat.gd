extends SceneTree

## 威胁值 (用户 2026-10-14, ThreatMeter): the meter fills by itself, a full one
## sends a patrol and empties; each patrol on a floor is stronger; a new floor
## keeps 30% and starts the patrols over; 萨卡兹哨兵 add a large share unless
## killed first; patrols wander and chase, drop only rare gear, rarely.

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
	_meter()
	await _rising()
	await _patrols()
	await _drops()
	await _sentinels()
	await _next_floor()
	await _extraction()
	print("THREAT RESULT: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await step(2)
	quit(1 if failures else 0)

func kill(enemy) -> void:
	if is_instance_valid(enemy) and not enemy._dead: enemy.take_hit(99999999.0, "true")

func of_game(group: String) -> Array:
	return game.get_tree().get_nodes_in_group(group).filter(func(n): return n.get("game") == game and not n.get("_dead"))

## Keeps her alive and out of the way while enemies run.
func shelter() -> void:
	game.player.hp = game.player.max_hp

func _meter() -> void:
	var m := ThreatMeter.new()
	check("a full meter reports full and starts again from empty", not m.add(60.0) and m.add(45.0) and m.value == 0.0)
	m.value = 50.0
	m.wave = 3
	m.next_floor()
	check("the next floor keeps 30% of what had not filled, and patrols start over", is_equal_approx(m.value, 15.0) and m.wave == 0)
	var s1 := ThreatMeter.strength(1)
	var s3 := ThreatMeter.strength(3)
	check("each wave is stronger exponentially", is_equal_approx(s3.x / s1.x, pow(ThreatMeter.PATROL_GROWTH, 2)) and s1.x > 1.0 and s1.y > 1.0)
	check("rare gear is a low chance, a little more each wave, capped", ThreatMeter.rare_chance(1, false) <= 0.05 and ThreatMeter.rare_chance(4, false) > ThreatMeter.rare_chance(1, false) and ThreatMeter.rare_chance(99, false) == ThreatMeter.RARE_CHANCE_MAX)

func _rising() -> void:
	await game.start_contract("mine")
	await step(2)
	check("a new contract starts with an empty meter", game.threat.value < 0.5 and game.threat.wave == 0)
	var expected := clampf(game.floor_enemies().size() * float(ThreatMeter.SECONDS_PER_ENEMY.mine) / ThreatMeter.TARGET_WAVES, ThreatMeter.FILL_MIN, ThreatMeter.FILL_MAX)
	check("the floor's fill time follows its enemies: 2–3 patrols over a full clear", is_equal_approx(game.threat.fill_seconds, expected) and is_equal_approx(game.threat.per_second() * game.threat.fill_seconds, ThreatMeter.FULL), [game.threat.fill_seconds, expected])
	var m := ThreatMeter.new()
	m.plan_floor("snow", 45)
	var small := m.fill_seconds
	m.plan_floor("mine", 30)
	check("a bigger, slower floor fills more slowly", small > m.fill_seconds and small <= ThreatMeter.FILL_MAX and m.fill_seconds >= ThreatMeter.FILL_MIN)
	var before := game.threat.value
	for i in range(30):
		shelter()
		await step()
	check("it fills by itself in the field", game.threat.value > before)
	game.open_modal("pause")
	before = game.threat.value
	await step(10)
	check("a menu that stops the field stops it", is_equal_approx(game.threat.value, before))
	game.close_modal()
	game.encounter = "trader"
	game.world_map.encounter_node.visible = true
	game.modal = "trader"
	before = game.threat.value
	await step(10)
	check("it keeps rising while she shops with 坎诺特", game.threat.value > before)
	game.close_modal()
	game.encounter = "squad"
	game.player.teleport(game.world_map.encounter_node.global_position)
	await step(2)
	before = game.threat.value
	await step(10)
	check("it does not rise near the Rhodes squad", is_equal_approx(game.threat.value, before) and not game.threat_rising())
	game.encounter = ""
	game.in_camp = true
	check("nor in a camp", not game.threat_rising())
	game.in_camp = false

func _patrols() -> void:
	game.player.teleport(ContinuousWorldMap.ENTRY_POSITION)
	await step(2)
	var kills_before: int = (game.run_kills as Dictionary).values().reduce(func(a, b): return a + b, 0)
	game.threat.value = ThreatMeter.FULL - 0.001
	await step(2)
	var first := of_game("patrols")
	check("a full meter sends a patrol and empties", first.size() == ThreatMeter.PATROL_SIZE and game.threat.value < 1.0 and game.threat.wave == 1, [first.size(), game.threat.value])
	check("the patrol enters away from her", first.all(func(e): return Vector2(e.global_position.x - game.player.global_position.x, e.global_position.z - game.player.global_position.z).length() >= ThreatMeter.SPAWN_MIN - 3.0))
	check("PRTS logs it", game.prts_log.any(func(l): return "巡逻队" in str(l)))
	var start: Array = first.map(func(e): return e.global_position)
	for i in range(90):
		shelter()
		await step()
	var moved := 0
	for i in range(first.size()):
		if is_instance_valid(first[i]) and first[i].global_position.distance_to(start[i]) > 0.5: moved += 1
	check("it wanders the floor on its own", moved >= 1, moved)
	# She walks into its sight.
	var scout: Enemy = first[0]
	game.player.teleport(game.world_map.nearest_walkable(scout.global_position + Vector3(2.5, 0, 0)))
	for i in range(6):
		shelter()
		await step()
	check("it chases what it sees", scout.state == Enemy.State.CHASING)
	for e in first: kill(e)
	await step(2)
	var kills_after: int = (game.run_kills as Dictionary).values().reduce(func(a, b): return a + b, 0)
	check("patrol kills count as kills", kills_after - kills_before >= ThreatMeter.PATROL_SIZE)
	game.player.teleport(ContinuousWorldMap.ENTRY_POSITION)
	await step(2)
	var hp := []
	for w in range(2):
		game.threat.value = ThreatMeter.FULL - 0.001
		await step(2)
		var wave := of_game("patrols")
		hp.append(wave.map(func(e): return e.atk / EnemyAttacks.STATS[e.enemy_type].atk))
		for e in wave: kill(e)
		await step(2)
	check("the next patrol on the floor is stronger", (hp[1] as Array).max() > (hp[0] as Array).max(), hp)
	check("the third wave brings an elite", game.threat.wave == 3 and hp[1].size() == ThreatMeter.PATROL_SIZE + 1)

func _drops() -> void:
	var loot_before: Array = game.get_children().filter(func(c): return c is Loot)
	var caches_before := of_game("relic_caches").size()
	var drops := 0
	for i in range(40):
		var e := game._spawn_enemy(ContinuousWorldMap.ENTRY_POSITION + Vector3(30, 0, 0), false, false)
		e.configure_patrol(1)
		var count := game.get_children().filter(func(c): return c is Loot).size()
		kill(e)
		drops += game.get_children().filter(func(c): return c is Loot).size() - count
	await step(2)
	var new_loot: Array = game.get_children().filter(func(c): return c is Loot and not loot_before.has(c))
	check("patrols drop no ordinary loot: only rare gear, and rarely", new_loot.all(func(l): return l.item != null and l.item.is_equippable() and l.item.rarity == 2) and drops <= 10, drops)
	check("patrols never leave a combat cache", of_game("relic_caches").size() == caches_before)
	var gear := game._rare_gear()
	# value_base: before prefixes and roll quality (装备前缀策划案 §2.5).
	check("the rare piece is graded by the floor", gear.rarity == 2 and gear.value_base == roundi((10 + game.floor_number * 4) * 3 * float(GearCatalog.BASES[gear.base_id].get("value", 1.0))), [gear.value_base, game.floor_number])

## 用户 2026-10-14: seen her -> red "!" and the meter fills faster -> runs to a
## reachable spot -> stands there a while, not running -> if it sees her again,
## another spot. It never attacks.
func _sentinels() -> void:
	# 用户 2026-10-14: 刷新少一点，每一层限定最多一个，巡逻敌人不刷.
	var floors := 0
	var most := 0
	for i in range(200):
		for e in of_game("sentinels"): e.free()
		game._spawn_sentinels()
		var n := of_game("sentinels").size()
		most = maxi(most, n)
		if n > 0: floors += 1
	check("at most one sentinel a floor, on about SENTINEL_CHANCE of floors", most == 1 and absf(floors / 200.0 - ThreatMeter.SENTINEL_CHANCE) < 0.12, [most, floors])
	var pooled := false
	for region in EnemyAttacks.REGION_POOLS:
		for slot in EnemyAttacks.REGION_POOLS[region]:
			if EnemyAttacks.REGION_POOLS[region][slot].has("sentinel"): pooled = true
	check("patrols never bring a sentinel (it is in no region pool)", not pooled and of_game("patrols").all(func(e): return e.enemy_type != "sentinel"))
	while of_game("sentinels").is_empty(): game._spawn_sentinels()
	var sentinels := of_game("sentinels")
	check("萨卡兹哨兵 keep watch beside the path", sentinels.size() == 1)
	if sentinels.is_empty(): return
	var post: Enemy = sentinels[0]
	# Her own floor rate first, far from every sentinel.
	game.player.teleport(ContinuousWorldMap.ENTRY_POSITION)
	await step(2)
	check("no sentinel is alerted before it sees her", game.alerted_sentinels() == 0 and post.sentinel_mode == "watch" and not post.alerted())
	game.threat.value = 0.0
	await step(30)
	var calm := game.threat.value
	var start := post.global_position
	game.player.teleport(beside(post))
	await step(3)
	check("seeing her puts up its ! and it runs", post.alerted() and post.sentinel_mode == "run" and post._run_target.distance_to(start) >= ThreatMeter.SENTINEL_RUN_MIN * 0.6)
	check("PRTS logs the alarm", game.prts_log.any(func(l): return "警报" in str(l)))
	var rid := game.world_map.navigation_map_rid()
	var goal := NavigationServer3D.map_get_closest_point(rid, post._run_target)
	var path := NavigationServer3D.map_get_path(rid, NavigationServer3D.map_get_closest_point(rid, start), goal, true)
	check("its spot is one it can reach", not path.is_empty() and path[-1].distance_to(goal) <= 1.0)
	game.threat.value = 0.0
	await step(30)
	var boosted := game.threat.value
	check("while its ! is up the meter fills faster", boosted > calm * (1.0 + ThreatMeter.SENTINEL_BOOST * 0.8), [calm, boosted])
	var attacked := false
	for i in range(60 * 16):
		shelter()
		await step()
		if post.attack_phase != "idle" or post.preparing_attack: attacked = true
		if post.sentinel_mode == "hold": break
	check("it reaches its spot and stands there", post.sentinel_mode == "hold" and post.alerted(), post.sentinel_mode)
	# Standing: she walks right up and it does not run.
	var held := post.global_position
	game.player.teleport(beside(post))
	for i in range(120):
		shelter()
		await step()
		if post.attack_phase != "idle" or post.preparing_attack: attacked = true
	check("while it holds it does not run", post.sentinel_mode == "hold" and post.global_position.distance_to(held) < 0.3)
	# The hold over and her still in sight: another spot.
	for i in range(int(ThreatMeter.SENTINEL_HOLD * 60)):
		shelter()
		await step()
		if post.sentinel_mode == "run": break
	check("after the hold, seeing her again, it runs to another spot", post.sentinel_mode == "run" and post._run_target.distance_to(held) >= ThreatMeter.SENTINEL_RUN_MIN * 0.6,
		[post.sentinel_mode, post._run_target.distance_to(held), post.global_position.distance_to(game.player.global_position)])
	check("it never attacks", not attacked and EnemyAttacks.STATS.sentinel.atk == 0.0 and EnemyAttacks.PROFILES.sentinel.shape == "none")
	var before := game.alerted_sentinels()
	kill(post)
	await step(2)
	check("killed, its ! and the faster fill end", game.alerted_sentinels() == before - 1)

## A walkable spot a few steps from `enemy` that it can see: nearest_walkable
## alone can land her on another terrace, out of its sight.
func beside(enemy: Enemy) -> Vector3:
	for reach in [2.0, 3.0, 4.0, 5.0]:
		for i in range(12):
			var spot := game.world_map.nearest_walkable(enemy.global_position + Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 12.0) * reach)
			var flat := Vector2(spot.x - enemy.global_position.x, spot.z - enemy.global_position.z).length()
			if flat < 6.0 and game.line_of_sight(enemy.global_position, spot): return spot
	return enemy.global_position

func _next_floor() -> void:
	game.threat.value = 40.0
	game.threat.wave = 3
	await game.advance(0)
	await step(2)
	check("the next floor keeps 30% and starts the patrols over", game.threat.value < 40.0 * ThreatMeter.CARRY + 1.0 and game.threat.value >= 40.0 * ThreatMeter.CARRY and game.threat.wave == 0, game.threat.value)
	game.settle(true)
	await step(2)

## The random extraction (用户 2026-10-14): a green zone like any extraction:
## standing in it runs a bar, hits do not break it, stepping out does.
func _extraction() -> void:
	await game.start_contract("mine")
	await step(2)
	game._random_extraction_available = true
	game.world_map.exit_node.visible = true
	var zone: Vector3 = game.world_map.exit_node.global_position
	# What an extraction floor dresses it with (TerraceDressing._place_extraction).
	var dressing: TerraceDressing = game.world_map.terrace_dressing
	var root := Node3D.new()
	game.world_map._generated_root.add_child(root)
	dressing._place_extraction(root)
	var flare: Node3D = root.find_child("SignalFlare", false, false)
	check("it is marked by the green signal flare and its smoke, no disc", flare != null and root.find_child("FlareSmoke", false, false) != null
		and game.world_map.exit_node.mesh == null and Vector2(flare.position.x - zone.x, flare.position.z - zone.z).length() < 0.1)
	game.player.teleport(game.world_map.nearest_walkable(zone))
	await step(2)
	check("no E to press: standing in it is enough", game.interaction_prompt().is_empty() and game.in_extraction_zone())
	var meter := game.threat.value
	for i in range(60):
		shelter()
		await step()
	check("standing in it runs the extraction", game.extract_progress > 0.8 and not game.in_base, game.extract_progress)
	check("the threat meter keeps rising meanwhile", game.threat.value > meter)
	var before := game.extract_progress
	game.player.take_damage(50.0)
	await step(2)
	check("a hit does not break it", game.extract_progress > before)
	game.player.teleport(game.world_map.nearest_walkable(zone + Vector3(FieldCatalog.EXTRACT_RADIUS + 4.0, 0, 0)))
	await step(2)
	check("stepping out starts it over", game.extract_progress < 0.0 or not game.in_extraction_zone())
	game.player.teleport(game.world_map.nearest_walkable(zone))
	for i in range(int(FieldCatalog.EXTRACT_SECONDS * 60) + 30):
		shelter()
		await step()
		if game.in_base: break
	check("the full bar extracts", game.in_base and game.settlement_view.extracted)
