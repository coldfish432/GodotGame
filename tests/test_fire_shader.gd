extends SceneTree

## A5 burning-bottle fire (CHANGE-BRIEF.md R1–R7, F1–F5): the flame quad's
## `fire_remaining` uniform, driven by FireFlame from GroundHazard.lasting.
## Every fire comes from a real 燃烧瓶投掷者 throwing a real Molotov through the
## running game loop; pause and the loot window are opened with injected keys
## (Esc, E). The test never calls the driver's update: it only reads the
## material, from an observer with process_priority / process_physics_priority
## 100 (after the hazard at 0 and the driver at 10).
## Run at 30, 60 and 144 fps: ./scripts/run-test.sh test_fire_shader.gd <fps>

const SHADER_PATH := "res://shaders/burning_bottle_fire.gdshader"
const EPS := 1e-5
const PHYS_HZ := 60.0

var game: GameManager
var p: Player
var failures := 0
var checks := 0
var origin := Vector3(0, 0.7, -22)
var fps := 60.0
var obs: Observer

## Records every GroundHazard it sees, each physics step and each frame.
class Observer extends Node:
	var game: GameManager
	var pstep := 0
	var pclock := 0.0
	var frames := 0
	var pclock_frames := 0.0
	var records := {}   # instance id -> Dictionary

	func _init() -> void:
		process_priority = 100
		process_physics_priority = 100

	func value_of(mat: ShaderMaterial) -> float:
		var v: Variant = mat.get_shader_parameter("fire_remaining")
		return -1.0 if v == null else float(v)

	func _physics_process(delta: float) -> void:
		pstep += 1
		pclock += delta
		for node in get_tree().get_nodes_in_group("ground_hazards"):
			var h := node as GroundHazard
			if h == null: continue
			var id := h.get_instance_id()
			if not records.has(id):
				var flame := h.get_node_or_null("Flame") as FireFlame
				var mat: ShaderMaterial = (flame.material_override as ShaderMaterial) if flame != null else null
				records[id] = {"hazard": h, "source_id": h.source.get_instance_id() if is_instance_valid(h.source) else 0,
					"flame": flame, "has_flame": flame != null, "mat": mat,
					"initial": flame.initial_lasting if flame != null else 0.0,
					"birth_step": pstep, "birth_lasting": h.lasting, "birth_fuse": h.fuse,
					"birth_value": value_of(mat) if mat != null else -1.0,
					"phys": [], "gtime": 0.0, "terminal_step": -1, "terminal_value": -1.0, "terminal_gtime": 0.0,
					"proc": [], "proc_first": -1.0, "proc_first_frame": -1, "proc_gone": -1.0, "proc_gone_frame": -1,
					"proc_first_value": -1.0}
				continue
			var r: Dictionary = records[id]
			if not r.has_flame or r.terminal_step >= 0: continue
			if game.simulation_active(): r.gtime += delta
			var v := value_of(r.mat)
			r.phys.append([pstep, h.lasting, v, r.gtime])
			if h.lasting <= 0.0:
				r.terminal_step = pstep
				r.terminal_value = v
				r.terminal_gtime = r.gtime

	func _process(delta: float) -> void:
		frames += 1
		pclock_frames += delta
		for id in records:
			var r: Dictionary = records[id]
			if not r.has_flame: continue
			if is_instance_valid(r.hazard) and not r.hazard.is_queued_for_deletion() and r.hazard.is_inside_tree():
				var v := value_of(r.mat)
				if r.proc_first < 0.0:
					r.proc_first = pclock_frames
					r.proc_first_frame = frames
					r.proc_first_value = v
				r.proc.append([frames, r.hazard.lasting, v])
			elif r.proc_first >= 0.0 and r.proc_gone < 0.0:
				r.proc_gone = pclock_frames
				r.proc_gone_frame = frames

func _initialize() -> void: call_deferred("run")

func check(label: String, passed: bool, seen: Variant = null) -> void:
	checks += 1
	if not passed and seen != null: print("   seen: ", seen)
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label)

func frames_n(n: int) -> void:
	for i in range(n): await process_frame

func steps(n: int) -> void:
	var target := obs.pstep + n
	while obs.pstep < target: await process_frame

func press(keycode: Key) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = keycode
	down.keycode = keycode
	down.pressed = true
	Input.parse_input_event(down)
	await frames_n(2)
	var up := down.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	await frames_n(2)

func reset() -> void:
	game._clear_field()
	await frames_n(3)
	p.reset_stats()
	p.teleport(origin)
	p.invulnerable = true

func sides() -> Array:
	var out := []
	for side in [Vector3(5, 0, 0), Vector3(-5, 0, 0), Vector3(0, 0, 5), Vector3(0, 0, -5), Vector3(4, 0, 3), Vector3(-4, 0, 3), Vector3(4, 0, -3), Vector3(-4, 0, -3)]:
		if game.line_of_sight(origin + side, origin): out.append(side)
	return out

func spawn_thrower(offset: Vector3) -> Enemy:
	var e := game._spawn_enemy(origin + offset, false, false, "thrower")
	e.set_physics_process(false)
	return e

## Lets the thrower's own AI chase, wind up and throw once; it is held still
## once its bottle is in the air so it does not throw a second.
func let_throw(e: Enemy, max_steps: int = 900) -> bool:
	e.set_physics_process(true)
	e.begin_chase()
	var start := obs.pstep
	while obs.pstep - start < max_steps:
		for child in game.get_children():
			if child is Molotov and child.source == e:
				e.set_physics_process(false)
				return true
		await process_frame
	e.set_physics_process(false)
	return false

func fire_of(e: Enemy) -> Dictionary:
	for id in obs.records:
		if obs.records[id].source_id == e.get_instance_id() and obs.records[id].has_flame: return obs.records[id]
	return {}

func hazards_of(id: int) -> Array:
	return obs.records.values().filter(func(r): return r.source_id == id)

func wait_fire(e: Enemy, max_steps: int = 120) -> Dictionary:
	var start := obs.pstep
	while obs.pstep - start < max_steps:
		var r := fire_of(e)
		if not r.is_empty(): return r
		await process_frame
	return {}

func wait_gone(r: Dictionary, max_steps: int = 1200) -> void:
	var start := obs.pstep
	while obs.pstep - start < max_steps and r.proc_gone < 0.0: await process_frame
	await frames_n(2)

func run() -> void:
	_shader_interface()
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	await frames_n(4)
	await game.start_contract("city")
	p = game.player
	p.set_physics_process(false)
	p._sprite.set_process(false)
	SystemScreens.settings["auto_potion"] = ""
	obs = Observer.new()
	obs.game = game
	root.add_child(obs)
	await reset()
	# The render rate --fixed-fps set: frames per 240 physics steps at 60 Hz
	# (the command line does not show engine options to the script).
	var f0 := obs.frames
	var s0 := obs.pstep
	await steps(240)
	fps = roundf(PHYS_HZ * (obs.frames - f0) / float(obs.pstep - s0))
	print("FIRE SHADER: %d frames per %d physics steps -> %d fps; physics_ticks_per_second=%d, time_scale=%.2f" % [obs.frames - f0, obs.pstep - s0, int(fps), Engine.physics_ticks_per_second, Engine.time_scale])
	print("   after start: modal='%s' simulation_active=%s region=%s" % [game.modal, game.simulation_active(), game.region_id])
	check("the field is running after start_contract (no modal)", game.simulation_active(), game.modal)
	await _one_fire()
	await _two_fires()
	await _pause_and_loot()
	await _time_scale(0.5, 361)
	await _time_scale(2.0, 91)
	await _not_fires()
	await _floor_change()
	print("FIRE SHADER RESULT @%dfps: %d checks, %d failures" % [int(fps), checks, failures])
	Engine.time_scale = 1.0
	obs.queue_free()
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)

# --- The shader's interface (names/types from the uniform list, defaults from the source) ---

func _shader_interface() -> void:
	var shader := load(SHADER_PATH) as Shader
	check("the fire shader loads", shader != null)
	if shader == null: return
	var list := {}
	for u in shader.get_shader_uniform_list():
		list[u.name] = u
		print("   UNIFORM %s type %d hint %d '%s'" % [u.name, u.type, u.hint, u.hint_string])
	# Since 2026-10-30 the flames are spread tongues (酒精火), not the brief's one quad:
	# only fire_remaining keeps the brief's name, range and default.
	var fr: Dictionary = list.get("fire_remaining", {})
	var parts: PackedStringArray = str(fr.get("hint_string", "")).split(",")
	check("uniform fire_remaining: float, hint_range(0.0, 1.0, 0.01)", fr.get("type") == TYPE_FLOAT and fr.get("hint") == PROPERTY_HINT_RANGE
		and parts.size() >= 3 and is_zero_approx(float(parts[0])) and is_equal_approx(float(parts[1]), 1.0) and is_equal_approx(float(parts[2]), 0.01), fr)
	var source := FileAccess.get_file_as_string(SHADER_PATH)
	check("source default fire_remaining = 1.0", source.contains("uniform float fire_remaining : hint_range(0.0, 1.0, 0.01) = 1.0;"))
	check("a tongue is only drawn while fire_remaining > 0 (source)", source.contains("step(0.0001, r)") and source.contains("ALPHA = clamp(body * alive"))

# --- R1, R2, R3: one fire through its whole life ---

func _one_fire() -> void:
	var side: Array = sides()
	check("a throwing spot with a clear line", not side.is_empty())
	if side.is_empty(): return
	var t := spawn_thrower(side[0])
	check("the thrower throws by itself (chase, wind-up, throw)", await let_throw(t))
	var r := await wait_fire(t)
	check("its bottle lands and leaves a fire with a Flame", not r.is_empty())
	if r.is_empty(): return
	var flame: FireFlame = r.flame
	check("R1: the driver cached the initial lasting 3.0 before any countdown", is_equal_approx(r.initial, 3.0) and is_equal_approx(r.birth_lasting, 3.0), [r.initial, r.birth_lasting])
	check("R1: fire_remaining is 1.0 on the physics step the fire appears", absf(r.birth_value - 1.0) < EPS, r.birth_value)
	await frames_n(1)
	# At 30 fps two physics steps run before a frame: the first frame can already
	# show the second step's countdown. Within one frame period of 1.0, as R3.
	check("R1: …and on the first frame it is drawn (1.0 within one frame period, 1/%d s)" % int(fps),
		r.proc_first_value <= 1.0 + EPS and r.proc_first_value >= 1.0 - (1.0 / fps) / r.initial - EPS, r.proc_first_value)
	print("   R1 @%dfps: first frame value %.6f" % [int(fps), r.proc_first_value])
	var rad: float = r.hazard.radius
	var mm := flame.multimesh
	var inside := mm != null and mm.instance_count >= 6 and mm.use_custom_data
	if inside:
		for i in range(mm.instance_count):
			var o := mm.get_instance_transform(i).origin
			inside = inside and Vector2(o.x, o.z).length() <= rad + EPS
	check("the flame is its own ShaderMaterial on the shared shader: tongues spread inside the radius, 0.04 above the ground, no shadow",
		flame.material_override is ShaderMaterial and (flame.material_override as ShaderMaterial).shader == load(SHADER_PATH)
		and inside and is_equal_approx(flame.position.y, 0.04) and flame.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		mm.instance_count if mm != null else -1)
	check("the Decal scorch is still there beside it", r.hazard._disc != null and r.hazard._disc.visible and r.hazard._disc.get_parent() == r.hazard)
	await wait_gone(r)
	_check_curve(r, "R3 @1.0")
	var births: int = r.terminal_step - r.birth_step
	check("R2: the last physics sample before the free reads 0.0", r.terminal_step > 0 and absf(r.terminal_value) < EPS, r.terminal_value)
	check("R2: hazard and Flame are gone afterwards", not is_instance_valid(r.hazard) and not is_instance_valid(r.flame))
	check("R3: it lasts 181 physics steps (first step with lasting <= 0)", births == 181, births)
	check("R3: …3.016667 game seconds of physics delta", absf(r.terminal_gtime - 181.0 / PHYS_HZ) < 1e-6, r.terminal_gtime)
	var seen: float = r.proc_gone - r.proc_first
	check("R3: seen by the _process observer for 3.016667 s ± one frame (1/%d s)" % int(fps), absf(seen - 181.0 / PHYS_HZ) <= 1.0 / fps + 1e-6, seen)
	print("   R3 @%dfps: steps %d, game s %.6f, observed %.6f s over %d frames" % [int(fps), births, r.terminal_gtime, seen, r.proc_gone_frame - r.proc_first_frame])
	t.queue_free()
	await reset()

func _check_curve(r: Dictionary, label: String) -> void:
	var follows := true
	var monotone := true
	var last := 2.0
	var mid := -1.0
	var mid_t := -1.0
	for s in r.phys:
		var want := clampf(s[1] / r.initial, 0.0, 1.0)
		if absf(s[2] - want) > EPS: follows = false
		if s[2] > last + EPS: monotone = false
		last = s[2]
		if mid < 0.0 and s[3] >= 1.5 - 1e-9:
			mid = s[2]
			mid_t = s[3]
	var proc_follows := true
	var skip: Array = r.get("skip_frames", [])
	for s in r.proc:
		if not skip.is_empty() and s[0] >= skip[0] and s[0] <= skip[1]: continue
		if absf(s[2] - clampf(s[1] / r.initial, 0.0, 1.0)) > EPS: proc_follows = false
	check("%s: every physics step fire_remaining == clamp(lasting / initial, 0, 1)" % label, follows and r.phys.size() > 0, r.phys.size())
	check("%s: …and every frame" % label, proc_follows and r.proc.size() > 0, r.proc.size())
	check("%s: it never rises" % label, monotone)
	check("%s: 0.5 at 1.5 game seconds (±1e-5 + one step / initial)" % label, mid >= 0.0 and absf(mid - 0.5) <= EPS + (1.0 / PHYS_HZ) * Engine.time_scale / r.initial, [mid_t, mid])

# --- R4, R7: a second bottle while the first burns ---

func _two_fires() -> void:
	var side: Array = sides()
	var a := spawn_thrower(side[0])
	var b := spawn_thrower(side[1] if side.size() > 1 else side[0] + Vector3(0, 0, 1))
	a.set_physics_process(true)
	a.begin_chase()
	var a_start := obs.pstep
	await steps(60)
	var b_threw: bool = await let_throw(b)
	# A was left running so it throws by itself; stop it once its bottle is up.
	var a_threw := hazards_of(a.get_instance_id()).size() > 0
	for child in game.get_children():
		if child is Molotov and child.source == a: a_threw = true
	a.set_physics_process(false)
	var ra := await wait_fire(a, 60)
	var rb := await wait_fire(b, 60)
	check("two throwers 60 steps apart both throw", a_threw and b_threw and not ra.is_empty() and not rb.is_empty(), [a_threw, b_threw])
	if ra.is_empty() or rb.is_empty():
		a.queue_free()
		b.queue_free()
		await reset()
		return
	var gap: int = rb.birth_step - ra.birth_step
	print("   R4: fires born %d physics steps apart (%.4f s); A thrower started at step %d" % [gap, gap / PHYS_HZ, a_start])
	check("R4: a new bottle makes a new hazard, not a restart of the old one", ra.hazard != rb.hazard and gap > 0, gap)
	check("R4: the new fire starts at 1.0", absf(rb.birth_value - 1.0) < EPS, rb.birth_value)
	# At the step where B is 30 steps old, both against their own ages.
	await steps(31)
	var at: int = rb.birth_step + 30
	var va := -1.0
	var vb := -1.0
	for s in ra.phys:
		if s[0] == at: va = s[2]
	for s in rb.phys:
		if s[0] == at: vb = s[2]
	var age_a: int = at - ra.birth_step
	var want_a := (3.0 - age_a / PHYS_HZ) / 3.0
	var want_b := (3.0 - 30.0 / PHYS_HZ) / 3.0
	check("R7: at one step A = (3 − its age)/3 and B = (3 − 0.5)/3 = 5/6, each on its own clock",
		absf(va - want_a) <= EPS + 1.0 / PHYS_HZ / 3.0 and absf(vb - want_b) <= EPS + 1.0 / PHYS_HZ / 3.0, [age_a, va, want_a, vb, want_b])
	if gap == 60: check("R7: with the 1.0 s gap that is 0.5 and 5/6", absf(va - 0.5) <= EPS + 1.0 / 180.0 and absf(vb - 5.0 / 6.0) <= EPS + 1.0 / 180.0, [va, vb])
	check("R4: the old fire was not reset or extended: initial 3.0 and a curve that never rose", is_equal_approx(ra.initial, 3.0) and ra.phys.all(func(s): return s[1] <= 3.0 - (s[0] - ra.birth_step) / PHYS_HZ + 1e-6))
	var ma: ShaderMaterial = ra.mat
	var mb: ShaderMaterial = rb.mat
	check("R7: two material instances (ids %d, %d) on one Shader" % [ma.get_instance_id(), mb.get_instance_id()], ma != mb and ma.get_instance_id() != mb.get_instance_id() and ma.shader == mb.shader)
	var b_before := float(mb.get_shader_parameter("fire_remaining"))
	# The test's own write to A: the frames before the next physics step show it,
	# so the per-frame curve check skips exactly those frames.
	var write_frame := obs.frames + 1
	ma.set_shader_parameter("fire_remaining", 0.123)
	check("R7/F1: writing A's material leaves B's alone", is_equal_approx(float(mb.get_shader_parameter("fire_remaining")), b_before))
	await steps(1)
	ra["skip_frames"] = [write_frame, obs.frames]
	print("   R7: frames %d–%d show the test's own 0.123 on A and are left out of A's per-frame check" % [write_frame, obs.frames])
	var ha: GroundHazard = ra.hazard
	check("…and the driver puts A back to its own state next step", is_instance_valid(ha) and absf(float(ma.get_shader_parameter("fire_remaining")) - clampf(ha.lasting / 3.0, 0.0, 1.0)) < EPS)
	await wait_gone(rb)
	_check_curve(ra, "R4 A")
	_check_curve(rb, "R4 B")
	check("R4: A goes out first, each after its own 181 steps", ra.terminal_step < rb.terminal_step and ra.terminal_step - ra.birth_step == 181 and rb.terminal_step - rb.birth_step == 181,
		[ra.terminal_step - ra.birth_step, rb.terminal_step - rb.birth_step])
	check("R4: both end at 0.0", absf(ra.terminal_value) < EPS and absf(rb.terminal_value) < EPS)
	a.queue_free()
	b.queue_free()
	await reset()

# --- R5: the pause menu freezes it, a box's window does not ---

func _pause_and_loot() -> void:
	var side: Array = sides()
	var box := LootContainer.new()
	box.game = game
	box.kind = "construction"
	game.add_child(box)
	box.global_position = origin + Vector3(1.0, 0, 0)
	var t := spawn_thrower(side[0])
	await let_throw(t)
	var r := await wait_fire(t)
	check("R5: a fire to pause", not r.is_empty())
	if r.is_empty(): return
	await steps(20)
	await press(KEY_ESCAPE)
	print("   after Esc: modal='%s' simulation_active=%s" % [game.modal, game.simulation_active()])
	var paused := game.modal == "pause" and not game.simulation_active()
	check("R5: Esc (injected key) opens the pause menu and stops the field", paused, game.modal)
	if not paused:
		print("   STOP: headless key injection did not reach the game; not replaced by a direct call.")
		return
	var h: GroundHazard = r.hazard
	var held_lasting := h.lasting
	var held_value := float(r.mat.get_shader_parameter("fire_remaining"))
	var held_gtime: float = r.gtime
	var from := obs.pstep
	await steps(30)
	check("R5: 30 physics steps in the pause menu: lasting and fire_remaining do not move", obs.pstep - from >= 30 and h.lasting == held_lasting
		and float(r.mat.get_shader_parameter("fire_remaining")) == held_value and r.gtime == held_gtime, [obs.pstep - from, held_lasting, h.lasting, held_value])
	await press(KEY_ESCAPE)
	check("R5: Esc again closes it", game.modal == "" and game.simulation_active(), game.modal)
	await steps(5)
	check("R5: …and the fire counts on from where it stood", h.lasting < held_lasting and float(r.mat.get_shader_parameter("fire_remaining")) < held_value)
	await press(KEY_E)
	print("   after E: modal='%s' looting=%s simulation_active=%s" % [game.modal, is_instance_valid(game.looting), game.simulation_active()])
	var looting := game.modal == "inventory" and game.hands_busy()
	check("R5: E (injected key) by the box opens its window", looting, game.modal)
	var before := h.lasting
	var v_before := float(r.mat.get_shader_parameter("fire_remaining"))
	await steps(20)
	check("R5: with a box's window open the field runs and the fire burns down", looting and game.simulation_active() and h.lasting < before
		and float(r.mat.get_shader_parameter("fire_remaining")) < v_before)
	await press(KEY_ESCAPE)
	check("…Esc closes the window", game.modal == "")
	await wait_gone(r)
	_check_curve(r, "R5 pause")
	check("R5: paused steps are not game time: still 181 counting steps and 3.016667 game s", r.terminal_step - r.birth_step == 181 + _paused_steps(r) and absf(r.terminal_gtime - 181.0 / PHYS_HZ) < 1e-6,
		[r.terminal_step - r.birth_step, _paused_steps(r), r.terminal_gtime])
	check("R5: ends at 0.0", absf(r.terminal_value) < EPS)
	t.queue_free()
	box.queue_free()
	await reset()

## Physics steps where the fire's lasting did not move (the pause).
func _paused_steps(r: Dictionary) -> int:
	var n := 0
	var prev := 3.0
	for s in r.phys:
		if s[1] == prev: n += 1
		prev = s[1]
	return n

# --- R5: Engine.time_scale ---

func _time_scale(scale: float, want_steps: int) -> void:
	Engine.time_scale = scale
	var side: Array = sides()
	var t := spawn_thrower(side[0])
	await let_throw(t, int(900 / scale))
	var r := await wait_fire(t, int(120 / scale))
	check("time_scale %.1f: a fire" % scale, not r.is_empty())
	if r.is_empty():
		Engine.time_scale = 1.0
		return
	await wait_gone(r, int(1200 / scale))
	var n: int = r.terminal_step - r.birth_step
	var wall: float = (r.proc_gone_frame - r.proc_first_frame) / fps
	print("   time_scale %.1f: steps %d, game s %.6f, wall %.4f s (%d frames)" % [scale, n, r.terminal_gtime, wall, r.proc_gone_frame - r.proc_first_frame])
	check("R5 time_scale %.1f: %d physics steps to the first lasting <= 0" % [scale, want_steps], n == want_steps, n)
	check("R5 time_scale %.1f: about 3.0 game seconds (3.0 ≤ t < 3.0 + one scaled step)" % scale, r.terminal_gtime >= 3.0 - 1e-9 and r.terminal_gtime < 3.0 + scale / PHYS_HZ + 1e-9, r.terminal_gtime)
	check("R5 time_scale %.1f: %.3f wall seconds ± one frame" % [scale, want_steps / PHYS_HZ], absf(wall - want_steps / PHYS_HZ) <= 1.0 / fps + 1e-6, wall)
	_check_curve(r, "time_scale %.1f" % scale)
	check("time_scale %.1f: ends at 0.0" % scale, absf(r.terminal_value) < EPS)
	Engine.time_scale = 1.0
	t.queue_free()
	await reset()

# --- F2: hazards that are not fires get no flame ---

func _not_fires() -> void:
	var slug := game._spawn_enemy(origin + Vector3(0.5, 0, 0.5), false, false, "slug_volatile")
	slug.set_physics_process(false)
	# Its blast is spawned with no source (enemy.gd death_blast): find it by time.
	var before := obs.pstep
	slug.take_hit(99999.0, "true")
	await frames_n(3)
	var blast: Array = obs.records.values().filter(func(r): return r.birth_step > before and r.birth_fuse > 0.0)
	var bh: GroundHazard = blast[0].hazard if not blast.is_empty() else null
	check("F2: 高能源石虫's fused blast has no Flame, keeps its Warning", bh != null and bh.fuse > 0.0 and bh.lasting == 0.0 and not bh.has_node("Flame") and bh.has_node("Warning"),
		[bh != null, bh.has_node("Flame") if bh != null else null])
	var rite := game.spawn_hazard(origin + Vector3(-2, 0, 0), 1.6, 1.0, 0.0, 10.0, "arts", false, null)
	await frames_n(1)
	check("F2: a fuse > 0, lasting 0 hazard (a last rite's parameters) has no Flame", not rite.has_node("Flame") and rite.has_node("Warning"))
	await reset()
	var side: Array = sides()
	var t := spawn_thrower(side[0])
	t.silence(60.0)
	var threw: bool = await let_throw(t)
	await steps(60)
	var none := hazards_of(t.get_instance_id())
	check("F2: a silenced thrower's bottle leaves no fire at all", threw and none.is_empty(), [threw, none.size()])
	t.queue_free()
	await reset()

# --- R6: the floor ends mid-fire ---

func _floor_change() -> void:
	var side: Array = sides()
	var t := spawn_thrower(side[0])
	await let_throw(t)
	var r := await wait_fire(t)
	check("R6: a fire before the floor changes", not r.is_empty())
	if r.is_empty(): return
	var start := obs.pstep
	while obs.pstep - start < 300 and float(r.mat.get_shader_parameter("fire_remaining")) > 0.7: await process_frame
	var left := float(r.mat.get_shader_parameter("fire_remaining"))
	var floor_before := game.floor_number
	# Take a line that leads to a fighting floor (an event room has no field to
	# throw the next bottle on); which lines those are differs from run to run.
	game._ensure_route()
	var rows := RouteMap.next_rows(game.route_map, game.route_node)
	var line := 0
	for i in range(rows.size()):
		if str(RouteMap.node_at(game.route_map, Vector2i(game.route_node.x + 1, int(rows[i]))).get("kind", "")) != "event":
			line = i
			break
	await game.advance(line)
	await frames_n(3)
	print("   R6: changed floor %d -> %d (%s) at fire_remaining %.4f" % [floor_before, game.floor_number, game.route_kind, left])
	check("R6: the floor changed through the real route (advance)", game.floor_number == floor_before + 1, [floor_before, game.floor_number])
	check("R6: hazard and Flame are gone with the floor, no fade-out, no 0.0 sample", not is_instance_valid(r.hazard) and not is_instance_valid(r.flame) and r.terminal_step < 0, [left, r.terminal_step])
	check("R6: it was cut short near 0.7", left <= 0.7 and left > 0.6, left)
	# The next floor: its own wave out of the way, then a new bottle.
	origin = p.global_position
	await reset()
	var side2: Array = sides()
	check("R6: a throwing spot on the new floor", not side2.is_empty())
	if side2.is_empty(): return
	var t2 := spawn_thrower(side2[0])
	await let_throw(t2)
	var r2 := await wait_fire(t2)
	check("R6: the next fire caches its own 3.0 and starts at 1.0", not r2.is_empty() and is_equal_approx(r2.initial, 3.0) and absf(r2.birth_value - 1.0) < EPS)
	if not r2.is_empty(): await wait_gone(r2)
	t2.queue_free()
	await reset()
