extends SceneTree

## 叙拉古's enemies in play (叙拉古敌人设计案_v1 §三, §四.1; Sol batch N4): their
## pool and sheets, the 血债 their falls add, the eraser that comes with each
## reckoning unseen, the intimidator stopping a piercing wave, and the car
## holding a cut lane until it is broken; the caster's 煽动, the crossbows' arts
## in the reckoning, the capo's 近身一掌, the eraser's rain splashes and its
## way round behind her, and the car's lamps and its backing into its slot.

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

func kill(enemy) -> void:
	if is_instance_valid(enemy) and not enemy._dead: enemy.take_hit(99999999.0, "true")

## Every floor enemy but the car, out of the way (off the navmesh, they stay put).
func clear_floor() -> void:
	for e in game.floor_enemies():
		if not e.attack_profile.get("roadblock", false): e.global_position += Vector3(200, 0, 200)

## A walkable spot `gap` from `from` that it can see.
func open_spot(from: Vector3, gap: float) -> Vector3:
	for i in range(16):
		var p: Vector3 = game.world_map.nearest_walkable(from + Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 16.0) * gap)
		if absf(Vector2(p.x - from.x, p.z - from.z).length() - gap) < 0.8 and game.line_of_sight(from, p): return p
	return from + Vector3(gap, 0, 0)

## Steps until `done` holds (at most `limit` frames); whether it did.
func until(done: Callable, limit: int) -> bool:
	for i in range(limit):
		if done.call(): return true
		await step(1)
	return done.call()

## The splashes the scene shows over `frames` frames.
func count_splashes(frames: int) -> int:
	var seen := {}
	for i in range(frames):
		await step(1)
		for child in game.get_children():
			if child is EnemyAttackVfx and child.kind == "splash": seen[child.get_instance_id()] = true
	return seen.size()

const N4 := ["family_soldier", "family_intimidator", "family_crossbow", "family_caster", "family_capo", "family_eraser", "family_car"]

func run() -> void:
	check("every N4 enemy has a profile, stats and its 8-direction and walk sheets", N4.all(func(id): return EnemyAttacks.PROFILES.has(id) and EnemyAttacks.STATS.has(id) and FieldArt.has_directional(id) and FieldArt.has_walk(id)))
	var pool: Dictionary = EnemyAttacks.REGION_POOLS.siracusa
	check("叙拉古's pool is its own family (no eraser, no car)", (pool.normal + pool.ranged + pool.elite).all(func(id): return str(id).begins_with("family_")) and not "family_eraser" in pool.elite and not "family_car" in pool.elite)
	# Roadblocks: on about half the floors, always on a cut edge.
	var map := ContinuousWorldMap.new()
	root.add_child(map)
	var seen := 0
	var cut := 0
	var seed_with := 0
	for i in range(12):
		map.region_id = "siracusa"
		map.generate((i + 1) * 104729, 1)
		if map.roadblock.is_empty(): continue
		seen += 1
		if map._cut_edge(int(map.roadblock.link)): cut += 1
		if seed_with == 0: seed_with = (i + 1) * 104729
	check("a roadblock on some floors (%d/12)" % seen, seen >= 2)
	check("always on a lane with no way round (%d/%d)" % [cut, seen], cut == seen)
	map.queue_free()
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = seed_with
	root.add_child(game)
	await step(8)
	await game.start_contract("siracusa")
	await step(6)
	check("the floor's own enemies are the families'", game.floor_enemies().filter(func(e): return e.enemy_type.begins_with("family_")).size() >= 6)
	var car := game._car
	check("the car waits in its lane's mouth, its body barring the way", is_instance_valid(car) and is_instance_valid(game._car_block))
	game.player.invulnerable = true
	var start := game.player.global_position
	# The car: lamps up as it winds up, out along its nose, then backs straight in.
	if is_instance_valid(car):
		var home := car.home_position
		var ahead := car.nose.normalized()
		check("idling in its slot, its lamps are dark", ahead.length() > 0.5 and not car.headlights_on())
		game.player.global_position = game.world_map.nearest_walkable(home + ahead * 5.5)
		var lit := false
		var out := 0.0
		var straight := true
		var backed := false
		var nose_out := true
		for i in range(420):
			await step(1)
			if car.attack_phase == "windup" and car.headlights_on(): lit = true
			var off := car.global_position - home
			off.y = 0.0
			out = maxf(out, off.length())
			if off.length() > 0.3 and off.normalized().dot(ahead) < 0.95: straight = false
			if car.attack_phase == "reverse":
				backed = true
				if car.attack_direction.dot(ahead) < 0.99: nose_out = false
			if backed and car.attack_phase == "idle": break
			# Keep her ahead of it until it has charged.
			if out < 0.5: game.player.global_position = game.world_map.nearest_walkable(home + ahead * 5.5)
		check("its lamps light as it winds up", lit)
		check("it charges out along its nose (%.1f m)" % out, out >= 3.0 and straight)
		check("then backs into its slot, nose still out", backed and nose_out and Vector2(car.global_position.x - home.x, car.global_position.z - home.z).length() < 0.1)
		check("back in its slot, its lamps go dark", car.attack_phase == "idle" and not car.headlights_on())
		game.player.global_position = start
		await step(2)
	# 血债: a soldier's fall adds its weight.
	game.features.values.debt = 0.0
	var soldier: Enemy = game._spawn_enemy(game.player.global_position + Vector3(20, 0, 20), false, false, "family_soldier")
	await step(2)
	kill(soldier)
	await step(2)
	check("a family soldier's fall adds 血债 at half its old weight (%.1f)" % game.features.value("debt"), absf(game.features.value("debt") - 1.5) < 0.2)
	var capo: Enemy = game._spawn_enemy(game.player.global_position + Vector3(20, 0, 24), true, false, "family_capo")
	var near: Enemy = game._spawn_enemy(capo.global_position + Vector3(1.0, 0, 0), false, false, "family_soldier")
	await step(2)
	game.features.values.debt = 0.0
	kill(near)
	await step(2)
	check("a fall beside a 角头 adds its 3 more (%.1f)" % game.features.value("debt"), absf(game.features.value("debt") - 4.5) < 0.2)
	kill(capo)
	await step(2)
	# Only the 血债 the enemies add from here on.
	game.threat.fill_seconds = 1.0e9
	clear_floor()
	# 家族术师's 煽动: +0.75 a second, broken by two hits.
	var caster: Enemy = game._spawn_enemy(open_spot(start, 6.0), false, true, "family_caster")
	await step(2)
	caster._incite_cd = 0.0
	caster.begin_chase()
	var began: bool = await until(func(): return caster.inciting(), 360)
	await step(1)
	check("a 家族术师 stops to incite, its dark red ring up", began and caster._incite_mark.visible)
	game.features.values.debt = 0.0
	var left := caster._incite_left
	await step(60)
	var expected := (left - caster._incite_left) * 0.75 * FeatureCatalog.DEBT_SCALE
	check("煽动 adds 0.375 血债 a second (%.2f for %.2f)" % [game.features.value("debt"), expected], caster.inciting() and expected > 0.15 and absf(game.features.value("debt") - expected) < 0.05)
	caster.take_hit(1.0, "true")
	check("one hit does not break it", caster.inciting())
	caster.take_hit(1.0, "true")
	var held := game.features.value("debt")
	await step(20)
	check("two hits break it off and the 血债 stops", not caster.inciting() and not caster._incite_mark.visible and absf(game.features.value("debt") - held) < 0.001)
	caster._incite_cd = 0.0
	caster._attack_timer = 0.0
	await until(func(): return caster.inciting(), 360)
	game.features.values.debt = 0.0
	caster._incite_left = 0.3
	await step(40)
	check("it stops by itself when its time is up (%.2f)" % game.features.value("debt"), not caster.inciting() and game.features.value("debt") <= 0.3 * 0.75 * FeatureCatalog.DEBT_SCALE + 0.02 and caster._incite_cd > EnemyAttacks.INCITE_COOLDOWN - 1.0)
	caster._incite_cd = 0.0
	caster.silence(3.0)
	check("silenced, it cannot incite", not caster._try_special(5.0, true))
	kill(caster)
	# 家族角头: 近身一掌 round its own feet when she is close, the cigar's ring on her when not.
	var close_capo: Enemy = game._spawn_enemy(open_spot(start, 1.2), true, false, "family_capo")
	await step(2)
	close_capo.begin_chase()
	await until(func(): return close_capo.attack_phase == "windup", 240)
	check("close by, the 角头 winds up 近身一掌 (0.7 s, r 1.6 round itself)", close_capo.close_strike and close_capo.warn_shape == "circle" and is_equal_approx(close_capo.pending_warning_radius, 1.6) and is_equal_approx(close_capo._windup_total, 0.7) and close_capo._flat_distance(close_capo.pending_warning_position, close_capo.global_position) < 0.05)
	check("近身一掌 hits at 1.0, not the cigar's 1.4", is_equal_approx(close_capo._pending_damage / (close_capo.atk * (1.0 + game.pressure / EnemyAttacks.PRESSURE_DIVISOR) * game.enemy_attack_multiplier()), 1.0))
	kill(close_capo)
	var far_capo: Enemy = game._spawn_enemy(open_spot(start, 6.0), true, false, "family_capo")
	await step(2)
	far_capo.begin_chase()
	await until(func(): return far_capo.attack_phase == "windup", 240)
	check("further off, its cigar's ring falls on her (r 1.7)", not far_capo.close_strike and is_equal_approx(far_capo.pending_warning_radius, 1.7) and far_capo._flat_distance(far_capo.pending_warning_position, game.player.global_position) < 0.3)
	kill(far_capo)
	# 家族弩手: physical bolts until the reckoning.
	var bow: Enemy = game._spawn_enemy(open_spot(start, 7.0), false, true, "family_crossbow")
	await step(2)
	check("before the reckoning a 家族弩手's bolts are physical", not game.reckoning() and bow.shot_kind() == "phys")
	# The reckoning brings an eraser, unseen.
	game._spawn_reckoning()
	await step(3)
	var erasers := game.floor_enemies().filter(func(e): return e.enemy_type == "family_eraser")
	check("the reckoning brings one 灭迹人", erasers.size() == 1 and erasers[0].patrol_wave > 0)
	if erasers.size() == 1:
		var eraser: Enemy = erasers[0]
		eraser.global_position = game.player.global_position + Vector3(9, 0, 0)
		await step(2)
		check("far off it is unseen and cannot be picked", eraser.stealthed() and eraser._sprite.modulate.a == 0.0 and eraser._pick_area.collision_layer == 0)
		eraser.take_hit(1.0, "true")
		await step(1)
		check("hit, it shows itself", not eraser.stealthed() and eraser._sprite.modulate.a == 1.0)
		# It hunts her without having seen her, round to her back.
		eraser._revealed = 0.0
		eraser.global_position = game.world_map.nearest_walkable(start + Vector3(0, 0, 30))
		eraser.state = Enemy.State.IDLE
		await step(3)
		check("the 灭迹人 hunts her without seeing her", eraser.state == Enemy.State.CHASING)
		eraser.her_heading = Vector3(1, 0, 0)
		var flank := eraser.flank_point(game.player.global_position) - game.player.global_position
		check("its way in is behind her and to one side (%s)" % str(flank), flank.x < -0.8 and absf(flank.z) > 0.4 and Vector2(flank.x, flank.z).length() < 4.0)
		# Far off in the rain, only splashes where it steps; none under a dry sky.
		game.world_map.weather = "rain"
		eraser._revealed = 0.0
		eraser.global_position = open_spot(start, 14.0)
		var wet: int = await count_splashes(60)
		check("unseen in the rain it leaves splashes (%d in 1 s)" % wet, wet >= 1 and wet <= 4 and eraser.stealthed())
		game.world_map.weather = "overcast"
		eraser._revealed = 0.0
		eraser.global_position = open_spot(start, 14.0)
		var dry: int = await count_splashes(60)
		check("under an overcast sky, none", dry == 0)
		eraser.global_position += Vector3(200, 0, 200)
	# 清算时刻: the crossbows' bolts turn to arts.
	check("in the reckoning its bolts are arts", game.reckoning() and bow.shot_kind() == "arts")
	bow.begin_chase()
	var bolt := [null]
	await until(func():
		for child in game.get_children():
			if child is EnemyProjectile and child.shooter == bow: bolt[0] = child
		return bolt[0] != null, 300)
	check("and a bolt it looses deals arts", bolt[0] != null and bolt[0].arts)
	kill(bow)
	var patrol_caster: Enemy = game._spawn_enemy(open_spot(start, 6.0), false, true, "family_caster")
	patrol_caster.configure_patrol(maxi(1, game.features.reckonings))
	patrol_caster._incite_cd = 0.0
	check("a reckoning's own 术师 never incites", not patrol_caster._try_special(5.0, true))
	kill(patrol_caster)
	# The intimidator stops a piercing wave.
	for e in game.floor_enemies(): e.global_position += Vector3(200, 0, 200)
	var origin := game.player.global_position
	var wall: Enemy = game._spawn_enemy(origin + Vector3(0, 0, 3), false, false, "family_intimidator")
	var behind: Enemy = game._spawn_enemy(origin + Vector3(0, 0, 6), false, false, "family_soldier")
	await step(2)
	var hp := behind.health
	var wave := SwordWave.new()
	wave.game = game
	wave.direction = Vector3(0, 0, 1)
	wave.damage = 10.0
	game.add_child(wave)
	wave.global_position = origin + Vector3(0, 0.5, 0)
	await step(30)
	check("a piercing wave stops at the 恫吓者", wall.health < wall.max_health and behind.health == hp)
	# Broken from close by, the car opens the lane and lets out three soldiers.
	if is_instance_valid(car):
		game.player.global_position = car.global_position + Vector3(2.0, 0, 0)
		var soldiers := game.floor_enemies().filter(func(e): return e.enemy_type == "family_soldier").size()
		kill(car)
		await step(3)
		check("broken, the car's block is gone", not is_instance_valid(game._car_block))
		check("broken close by, three soldiers get out", game.floor_enemies().filter(func(e): return e.enemy_type == "family_soldier").size() == soldiers + 3)
	print("SIRACUSA ENEMIES RESULT: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await step(2)
	quit(1 if failures else 0)
