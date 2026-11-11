extends SceneTree
## HitSpark state test: A6 Effect A rules A1-A4 as carried into the game by
## GPU粒子特效推广策划案 v0.6 §3 P0b (one shared burst for every operator hit,
## spawned by OperatorVfx.hit 0.4 above the struck enemy; her sword wave, a
## ranged hit, now brings one too; enemy-to-player hits still bring none). The real game (game/main.tscn), the real loop and real
## left-mouse events, as in tests/test_lappland_input.gd. It never calls the
## trigger (Player._hit_spark), CombatVfx.spawn, attack() or attack_direction().
## Every HitSpark is seen through SceneTree.node_added / node_removed, wherever
## it appears; at the instant it is added every enemy's position is snapshotted.
## Landed hits are counted from enemy health drops. Headless the one-shot
## emitters read emitting == false from frame 1 (r1 b), so the test counts
## nodes and reads positions and the root's own clock instead.
## Run: ./scripts/run-test.sh test_hit_spark_state.gd 60 600

const SCENE := "res://effects/hit_spark.tscn"
const FREE_AFTER := 0.55
const LONGEST_LIFE := 0.45
const FRAME := 1.0 / 60.0
const TOLERANCE := 0.01

var rig: Node
var game: GameManager
var failures := 0
## One entry per HitSpark ever added: node, id, parent, pos, added/removed
## process frame, the enemies' positions at that instant, the root's clock.
var sparks: Array[Dictionary] = []
var _by_id: Dictionary = {}
## Enemy instance id -> process frame it left the tree.
var enemy_gone: Dictionary = {}
## Enemies whose health drops are accounted against sparks, and their last health.
var watched: Array[Enemy] = []
var last_health: Dictionary = {}
var counted_gone: Dictionary = {}
## Lappland's sword waves (projectiles): which enemies each has struck so far.
var waves: Array = []
var wave_seen: Dictionary = {}
## Health drops caused by a projectile, and those that came with a HitSpark.
var projectile_hits := 0
var projectile_sparks := 0
var _seen := 0
var mismatches: Array[String] = []
var age_went_back := false

func _initialize() -> void: call_deferred("run")

func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
		account()

func check(label: String, passed: bool) -> void:
	print(("PASS " if passed else "FAIL ") + label)
	if not passed: failures += 1

func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null

func _on_added(node: Node) -> void:
	if node is SwordWave: waves.append(node)
	if node.scene_file_path != SCENE: return
	var at: Dictionary = {}
	# A dying enemy may already have left the "enemies" group: the watched ones too.
	for e in get_nodes_in_group("enemies") + watched:
		if is_instance_valid(e) and e is Enemy: at[e.get_instance_id()] = (e as Enemy).global_position
	var entry := {"node": node, "id": node.get_instance_id(), "parent": node.get_parent(),
		"pos": (node as Node3D).global_position, "added": Engine.get_process_frames(),
		"removed": -1, "enemies": at, "age": 0.0}
	sparks.append(entry)
	_by_id[entry.id] = entry

func _on_removed(node: Node) -> void:
	var id := node.get_instance_id()
	if _by_id.has(id): _by_id[id].removed = Engine.get_process_frames()
	elif node is Enemy: enemy_gone[id] = Engine.get_process_frames()

func alive() -> Array:
	return sparks.filter(func(s): return s.removed < 0)

## Each step: every new HitSpark must sit (±0.01) on a watched enemy whose
## health dropped this step, and every watched enemy whose health dropped must
## have exactly one new HitSpark on it. The live ones' own clocks never go back.
func account() -> void:
	var dropped: Dictionary = {}
	for e in watched:
		var id := e.get_instance_id() if is_instance_valid(e) else -1
		if id == -1: continue
		var now := e.health
		if now < float(last_health.get(id, now)) - 0.0001: dropped[id] = float(last_health[id]) - now
		last_health[id] = now
	# A watched enemy freed this step (a killing blow) dropped to nothing.
	for id in last_health.keys():
		if enemy_gone.has(id) and not counted_gone.has(id):
			counted_gone[id] = true
			dropped[id] = INF
	var hits_on: Dictionary = {}
	for i in range(_seen, sparks.size()):
		var s: Dictionary = sparks[i]
		var best := -1
		var best_d := INF
		for id in s.enemies:
			var e_at: Vector3 = s.enemies[id]
			var d: float = minf(e_at.distance_to(s.pos), (e_at + Vector3.UP * 0.4).distance_to(s.pos))
			if d < best_d:
				best_d = d
				best = id
		s["enemy"] = best
		s["offset"] = best_d
		if best_d > TOLERANCE: mismatches.append("spark %d is %.4f from the nearest enemy" % [i, best_d])
		elif not dropped.has(best): mismatches.append("spark %d on enemy %d whose health did not drop" % [i, best])
		hits_on[best] = int(hits_on.get(best, 0)) + 1
	_seen = sparks.size()
	# Enemies a sword wave (a projectile, not a melee hit) struck this step.
	var shot: Dictionary = {}
	for w in waves:
		if not is_instance_valid(w): continue
		for id in (w as SwordWave).hit_ids:
			var key := str(w.get_instance_id()) + ":" + str(id)
			if wave_seen.has(key): continue
			wave_seen[key] = true
			shot[id] = true
	if not dropped.is_empty() or not hits_on.is_empty():
		var p := game.player
		print("TRACE frame ", Engine.get_process_frames(), " drops ", dropped, " sparks ", hits_on, " projectile ", shot.keys(), " pose ", p._sprite.action_name)
	for id in dropped:
		if shot.has(id):
			# A projectile hit (her sword wave): v0.6 gives it a HitSpark too.
			projectile_hits += 1
			projectile_sparks += int(hits_on.get(id, 0))
			if int(hits_on.get(id, 0)) < 1: mismatches.append("frame %d enemy %d: projectile hit with %d sparks" % [Engine.get_process_frames(), id, int(hits_on.get(id, 0))])
		elif int(hits_on.get(id, 0)) != 1: mismatches.append("frame %d enemy %d: health -%.1f with %d sparks" % [Engine.get_process_frames(), id, float(dropped[id]), int(hits_on.get(id, 0))])
	for s in alive():
		if not is_instance_valid(s.node): continue
		var age: float = s.node.get("_age")
		if age + 0.000001 < float(s.age): age_went_back = true
		s.age = age

func watch(e: Enemy) -> void:
	watched.append(e)
	last_health[e.get_instance_id()] = e.health

## Stop accounting (before the test itself frees its dummies).
func unwatch() -> void:
	watched.clear()
	last_health.clear()

## Real mouse events, the way the window delivers them. Input.parse_input_event
## feeds the Input singleton (the game polls Input.is_mouse_button_pressed).
## Under --headless the display server drops the window dispatch of those
## events (measured: GameManager._input never saw them, its pointer stayed at
## (0,0); the same failure as test_lappland_input's 0 hits), so the same event
## object is also pushed into the root window, in its own coordinates, and
## travels the production chain: root Window -> SubViewportContainer ->
## SubViewport -> GameManager._input (pointer) -> pointer_step -> lock -> swing.
func send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	if DisplayServer.get_name() == "headless": root.push_input(event, true)

## The pointer onto a world point, through the production viewport.
func hover(point: Vector3) -> Vector2:
	var screen := game.camera.unproject_position(point) * root.get_visible_rect().size / game.get_viewport().get_visible_rect().size
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else 0
	send(motion)
	return screen

func mouse(point: Vector3, pressed: bool) -> void:
	var screen := hover(point)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = screen
	event.global_position = screen
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	send(event)
	await step(1)

## Hold the left button on `enemy` for `frames`, re-asserting the pointer.
func hold_on(enemy: Enemy, frames: int, until_gone := false) -> void:
	var point := enemy.global_position
	await mouse(point, true)
	for i in range(frames):
		if is_instance_valid(enemy): point = enemy.global_position
		elif until_gone: break
		hover(point)
		await step()
	await mouse(point, false)

## A still dummy at `offset` from her (fixture, as the input suites do).
func dummy(offset: Vector3, life: float) -> Enemy:
	var p := game.player
	var e := game._spawn_enemy(p.global_position + offset, false, false)
	e.global_position = p.global_position + offset
	e.max_health = life
	e.health = life
	e.defense = 0
	e.res = 0
	e.set_physics_process(false)
	return e

## Its life on its own clock (the root's _age, last read before it went), so the
## check holds whatever the frame rate (run_all runs without --fixed-fps).
func lifetime(s: Dictionary) -> float:
	return float(s.age) + FRAME

func run() -> void:
	node_added.connect(_on_added)
	node_removed.connect(_on_removed)
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(10)
	game = find_game(rig)
	game.fixed_map_seed = 1729
	game.base.recruit(Operators.LAPPLAND)
	game.choose_operator(Operators.LAPPLAND)
	var p := game.player
	await game.start_contract("mine")
	await step(30)
	# --- A1: nothing on scene load (rig, base, field, 30 frames after) ---
	check("A1 no HitSpark from loading the game, the base and the field + 30 frames", sparks.is_empty())
	check("field is running with Lappland", game.simulation_active() and p.operator_id == Operators.LAPPLAND)
	game._clear_field()
	await step(3)
	var origin := p.global_position

	# --- A1 basic hit + Lappland's cross onto a second enemy ---
	var first := dummy(Vector3(2, 0, 0), 1000000)
	var second := dummy(Vector3(2, 0, 1.2), 1000000)
	watch(first)
	watch(second)
	await step(3)
	var before := sparks.size()
	await hold_on(first, 150)
	var lapp: Array = sparks.slice(before)
	var on_first := lapp.filter(func(s): return s.enemy == first.get_instance_id())
	var on_second := lapp.filter(func(s): return s.enemy == second.get_instance_id())
	var worst := 0.0
	for s in lapp: worst = maxf(worst, float(s.offset))
	print("LAPPLAND sparks on first ", on_first.size(), " on second (cross) ", on_second.size(), " worst offset ", worst,
		" hp first ", first.health, " second ", second.health)
	check("A1 held mouse on an enemy lands >= 3 hits, one HitSpark each", on_first.size() >= 3)
	check("A1 each HitSpark at the struck enemy's global_position at that instant (<= 0.01)", not lapp.is_empty() and worst <= TOLERANCE)
	check("A1/A4 every HitSpark is a child of the GameManager, never of an enemy", lapp.all(func(s): return s.parent == game))
	var same_frame := false
	for c in on_second:
		for b in on_first:
			if b.added == c.added: same_frame = true
	check("A1 Lappland's cross cut adds a HitSpark on the second enemy, same frame as the blow", on_second.size() >= 1 and same_frame)
	check("A1 sparks match landed melee hits frame by frame so far (no extra, none missing)", mismatches.is_empty())
	print("PROJECTILE hits ", projectile_hits, " with sparks ", projectile_sparks)
	check("P0b her sword wave (a ranged hit) struck and made its HitSpark", projectile_hits >= 1 and projectile_sparks >= projectile_hits)

	# --- A1: a left click on empty ground swings nothing and sparks nothing ---
	await step(40)
	var count := sparks.size()
	var hp1 := first.health
	var hp2 := second.health
	var cooldown_before := p._attack_cooldown
	await mouse(origin + Vector3(0, 0, -2.5), true)
	await step(2)
	await mouse(origin + Vector3(0, 0, -2.5), false)
	await step(30)
	check("a left click on empty ground walks her there",
		p._has_move_target or p.global_position.distance_to(origin) > 0.3)
	check("A1 the ground click swings nothing, damages nothing, makes no HitSpark", sparks.size() == count and first.health == hp1 and second.health == hp2 and p._attack_cooldown < cooldown_before)

	# --- A1: an enemy hitting her makes no HitSpark ---
	unwatch()
	first.queue_free()
	second.queue_free()
	await step(5)
	var brute := game._spawn_enemy(p.global_position + Vector3(2.0, 0, 0), false, false)
	watch(brute)
	var hp_before := p.hp
	count = sparks.size()
	var struck := false
	var lowest := hp_before
	for i in range(900):
		await step()
		lowest = minf(lowest, p.hp)
		if p.hp < hp_before - 0.001:
			struck = true
			await step(20)
			break
	print("ENEMY HIT player hp ", hp_before, " lowest ", lowest, " now ", p.hp, " enemy hp ", brute.health if is_instance_valid(brute) else -1.0)
	check("A1 enemy-to-player hit lands (player HP drops)", struck)
	check("A1 enemy-to-player hit makes no HitSpark", sparks.size() == count)
	unwatch()
	if is_instance_valid(brute): brute.queue_free()
	await step(5)

	# --- A4: a 1-HP enemy dies on a real held-mouse hit ---
	p.clear_move_target()
	await step(40)
	var victim := dummy(Vector3(2, 0, 0), 1.0)
	var victim_id := victim.get_instance_id()
	watch(victim)
	await step(3)
	before = sparks.size()
	await hold_on(victim, 120, true)
	await step(45)
	var kill: Array = sparks.slice(before).filter(func(s): return s.enemy == victim_id)
	var k: Dictionary = kill[0] if kill.size() == 1 else {}
	print("KILL sparks ", kill.size(), " enemy gone at ", enemy_gone.get(victim_id, -1), " spark ", k.get("added", -1), "->", k.get("removed", -1))
	check("A4 the killing hit makes one HitSpark and the enemy is freed", kill.size() == 1 and enemy_gone.has(victim_id))
	check("A4 the HitSpark outlives its freed enemy and runs its full life",
		not k.is_empty() and k.parent == game and int(k.removed) > int(enemy_gone.get(victim_id, 1 << 30)) and lifetime(k) >= LONGEST_LIFE)
	unwatch()

	# --- A2: Amiya's stage-2 double cut, two landed hits inside 0.45 s ---
	# Switching who deploys is fixture setup (choose_operator only works at the base).
	p.set_operator(Operators.AMIYA_GUARD)
	p.clear_move_target()
	await step(40)
	var target := dummy(Vector3(2, 0, 0), 1000000)
	watch(target)
	await step(3)
	before = sparks.size()
	await hold_on(target, 180)
	await step(45)
	var amiya: Array = sparks.slice(before)
	var pair: Array = []
	for i in range(amiya.size() - 1):
		var a: Dictionary = amiya[i]
		var b: Dictionary = amiya[i + 1]
		if float(int(b.added) - int(a.added)) * FRAME < LONGEST_LIFE:
			pair = [a, b]
			break
	print("AMIYA sparks ", amiya.size(), " added frames ", amiya.map(func(s): return s.added))
	check("A1 Amiya's held cuts make HitSparks on her target", amiya.size() >= 3 and amiya.all(func(s): return s.enemy == target.get_instance_id()))
	check("A2 two landed hits inside 0.45 s found", pair.size() == 2)
	if pair.size() == 2:
		var a: Dictionary = pair[0]
		var b: Dictionary = pair[1]
		print("A2 pair: first ", a.added, "->", a.removed, " second ", b.added, "->", b.removed, " gap ", (int(b.added) - int(a.added)) * FRAME, " s")
		check("A2 two distinct HitSpark nodes, both alive when the second is added", a.id != b.id and int(a.removed) > int(b.added))
		check("A2 the first is not restarted or cut off: full life, freed before the second", lifetime(a) >= LONGEST_LIFE and lifetime(a) <= FREE_AFTER + FRAME + 0.0001 and int(a.removed) < int(b.removed))
	check("A2 no HitSpark's own clock ever went back (never restarted)", not age_went_back)
	unwatch()
	target.queue_free()
	await step(5)

	# --- A3 over every HitSpark the test saw ---
	await step(40)
	var longest := 0.0
	var shortest := INF
	for s in sparks:
		if int(s.removed) >= 0:
			longest = maxf(longest, lifetime(s))
			shortest = minf(shortest, lifetime(s))
	print("A3 sparks ", sparks.size(), " lifetimes ", shortest, "..", longest, " s; alive now ", alive().size())
	check("A3 every HitSpark freed itself, none left", not sparks.is_empty() and alive().is_empty())
	check("A3 each freed within 0.55 s + one frame, and not before 0.45 s", longest <= FREE_AFTER + FRAME + 0.0001 and shortest >= LONGEST_LIFE)
	check("A1 over the whole run every HitSpark matched one landed hit and every landed hit had one", mismatches.is_empty())
	for m in mismatches.slice(0, 10): print("  MISMATCH ", m)
	print("HIT_SPARK_STATE: %d failures" % failures)
	rig.queue_free()
	await create_timer(0.3).timeout
	quit(1 if failures else 0)
