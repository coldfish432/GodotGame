extends SceneTree
## A7 Step 5, plan step 5: edge tests for Lappland's release (CHANGE-BRIEF.md
## "The phase table", evidence split row "Interrupt one frame before, on, and
## after each boundary"; r3, r4, r5). Agent, 2026-11-22.
##
## Run: ./scripts/run-test.sh test_wave_edges.gd 60
##
## res://game/main.tscn, seed 1729 + seed_rng, the real loop and real input
## (Input.parse_input_event, also pushed into the root window under
## --headless, as tests/test_a7_pins.gd does). Never calls _wave_begin,
## _tick_wave, _wave_to_ready or attack_direction. Fixture writes only:
## charge, stamina, dash cooldown, enemy health, teleport, equip.
##
## Each case: a release at r = 1 on a 1-HP enemy (the release's own hit kills
## it, so no later swing cuts the recovery). That hit lands, so the release
## starts with hitstop; frozen ticks are counted explicitly (a tick is frozen
## when hitstop was left over from the tick before) and the dodge is sent so
## that it is read on the first tick of design frame F, i.e. the tick on which
## the state machine's frame becomes F (unfrozen ticks = 2F at 60 Hz, r = 1).
## Within that tick the game reads the dodge press, then advances the release
## (and spawns on f6), then starts the dodge: "on f6" therefore means the wave
## is already out.

const DESIGN_FPS := 30.0
const PHYSICS_HZ := 60.0
const FULL := 3                     # WAVE_HITS: a full charge
const TOL := 1e-4
## Brief phase table, per input frame: does the wave leave, is the charge kept.
## f20/f21: the release has already ended on its own (READY at f20) when the
## dodge starts; the dodge is then an ordinary dodge.
const CASES := [
	{"f": 5, "wave": false, "note": "last STARTUP frame: dodge cancels, no wave, charge kept"},
	{"f": 6, "wave": true, "note": "ACTIVE opens: wave out on this tick, then the dodge"},
	{"f": 7, "wave": true, "note": "ACTIVE: wave already out"},
	{"f": 9, "wave": true, "note": "last ACTIVE frame: wave out, dodge cuts the rest"},
	{"f": 10, "wave": true, "note": "RECOVERY opens: dodge cuts recovery"},
	{"f": 11, "wave": true, "note": "RECOVERY: dodge cuts recovery"},
	{"f": 19, "wave": true, "note": "last RECOVERY frame: dodge cuts recovery"},
	{"f": 20, "wave": true, "note": "end: the release ends on this tick (READY), then the dodge"},
	{"f": 21, "wave": true, "note": "after the end: already READY, an ordinary dodge"},
]

var rig: Node
var game: GameManager
var p: Player
var failures := 0
var passes := 0
var field_origin := Vector3.ZERO
var table: Array = []

func _initialize() -> void: call_deferred("run")

func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame

func check(label: String, passed: bool, detail: String = "") -> void:
	print(("PASS " if passed else "FAIL ") + label + ("" if detail.is_empty() else "  [" + detail + "]"))
	if passed: passes += 1
	else: failures += 1

func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null

func send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	if DisplayServer.get_name() == "headless": root.push_input(event, true)

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

func dash_key(pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = &"dash"
	event.pressed = pressed
	send(event)

func waves() -> int:
	var n := 0
	for node in game.get_children():
		if node is SwordWave and not node.is_queued_for_deletion(): n += 1
	return n

func clear_waves() -> void:
	for node in game.get_children():
		if node is SwordWave: node.queue_free()

func state_name() -> String:
	return str(Player.WaveState.keys()[p.wave_state])

func rig_player() -> AnimationPlayer:
	return p.get_node("WaveRig/AnimationPlayer") as AnimationPlayer

func arm() -> void:
	clear_waves()
	for i in range(150):
		if p._attack_cooldown <= 0.0 and p.wave_state == Player.WaveState.READY and p.dash_remaining <= 0.0: break
		await step()
	p.teleport(field_origin)
	await step(2)
	p.sword_charge = p.wave_hits_needed()
	p.stamina = 100.0
	p._dash_cooldown = 0.0
	await step(2)

func one_case(c: Dictionary) -> void:
	var f: int = c.f
	await arm()
	var at := p.global_position + Vector3(2, 0, 0)
	var enemy := game._spawn_enemy(at, true, false)
	enemy.global_position = at
	enemy.max_health = 1000000.0
	enemy.health = 1.0   # the release's hit kills it: no later swing
	enemy.set_physics_process(false)
	await step()
	var waves_before := waves()
	# The click.
	mouse(enemy.global_position, true)
	var clicked := false
	for i in range(8):
		await step()
		if i == 0: mouse(enemy.global_position, false)
		if p.wave_state != Player.WaveState.READY:
			clicked = true
			break
	if not clicked:
		mouse(enemy.global_position, false)
		check("f%d release started" % f, false)
		return
	var r := maxf(1.0, 0.7 / p.current_cooldown())
	var want_unfrozen := ceili(f * PHYSICS_HZ / (DESIGN_FPS * r) - 0.0001)   # first tick of frame f
	var unfrozen := 0
	var frozen := 0
	var last_hitstop := p.hitstop_remaining
	var spawn_pos_ok := true
	var spawn_detail := ""
	var state_before_press := ""
	var frame_before_press := -1
	var ticks := 0
	# Advance until the next tick is the first tick of frame f; send the dodge
	# before that tick.
	while unfrozen < want_unfrozen - 1 and ticks < 200:
		await step()
		ticks += 1
		if last_hitstop > 0.0: frozen += 1
		else: unfrozen += 1
		last_hitstop = p.hitstop_remaining
		# The f6 spawn tick, when it is not the dodge tick: clip position == frame / 30.
		if unfrozen == ceili(6 * PHYSICS_HZ / (DESIGN_FPS * r) - 0.0001) and last_hitstop <= 0.0:
			var pos := rig_player().current_animation_position
			spawn_pos_ok = state_name() == "ACTIVE" and p.wave_frame == 6 and absf(pos - p.wave_frame / DESIGN_FPS) < TOL
			spawn_detail = "state %s frame %d pos %.6f" % [state_name(), p.wave_frame, pos]
	state_before_press = state_name()
	frame_before_press = p.wave_frame
	var dodge_ok := last_hitstop <= 0.0
	dash_key(true)
	await step()
	ticks += 1
	unfrozen += 1
	dash_key(false)
	var dodged := p.dash_remaining > 0.0 or p.invulnerable
	var state_after := state_name()
	var frame_tick := p.wave_frame
	var anim_after := String(rig_player().current_animation)
	var sprite_after := p._sprite.visible
	var most := waves()
	for i in range(30):
		await step()
		most = maxi(most, waves())
	var charge_after := p.sword_charge
	var wave_out: bool = most > waves_before
	var expect_wave: bool = c.wave
	var observed := "frozen %d, before press %s f%d; after dodge %s, dodged %s, waves +%d, charge %d, anim %s, sprite %s" % [
		frozen, state_before_press, frame_before_press, state_after, dodged, most - waves_before, charge_after, anim_after, sprite_after]
	print("f%d (%s): %s" % [f, c.note, observed])
	table.append({"f": f, "expect": ("wave out, charge 0" if expect_wave else "no wave, charge 3") + ", READY", "observed": observed})
	check("f%d dodge read on the first tick of frame %d (unfrozen tick %d, %d frozen before it)" % [f, f, want_unfrozen, frozen], dodge_ok and unfrozen == want_unfrozen and dodged)
	check("f%d -> READY, sprite shown, rig plays RESET" % f, state_after == "READY" and sprite_after and anim_after == "RESET")
	if expect_wave:
		check("f%d the wave is out (1) and the charge spent (0)" % f, most - waves_before == 1 and charge_after == 0, "waves +%d charge %d" % [most - waves_before, charge_after])
	else:
		check("f%d no wave, charge kept (%d)" % [f, FULL], most == waves_before and charge_after == FULL, "waves +%d charge %d" % [most - waves_before, charge_after])
	if f == 5:
		check("f5 the press came during STARTUP (frame 4 before it)", state_before_press == "STARTUP" and frame_before_press == 4)
	elif f == 20:
		check("f20 the press came in RECOVERY at frame 19; the release ended on that tick by itself", state_before_press == "RECOVERY" and frame_before_press == 19)
	elif f == 21:
		check("f21 the release had already ended (READY) before the press", state_before_press == "READY")
	if f > 6:
		check("f%d at the f6 spawn tick: clip position == wave_frame / 30 (within 1e-4)" % f, spawn_pos_ok, spawn_detail)
	if is_instance_valid(enemy): enemy.queue_free()
	await step(40)

func run() -> void:
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(10)
	game = find_game(rig)
	game.fixed_map_seed = 1729
	game.seed_rng(1729)
	p = game.player
	check("E0 at start the rig's READY clip is playing: current_animation == RESET", String(rig_player().current_animation) == "RESET", String(rig_player().current_animation))

	await game.start_contract("mine")
	game._clear_field()
	await step(3)
	p = game.player
	p.set_operator("lappland")
	var item := Item.create("A7 edge sword", Item.Category.WEAPON, 2, 1)
	item.modifiers = [ItemModifier.trigger_mod(ItemModifier.Trigger.SWORD_WAVE)]
	p.equip(item)
	await step(3)
	field_origin = p.global_position
	check("E1 Lappland in the field at r = 1 (current_cooldown %.3f)" % p.current_cooldown(), p.operator_id == "lappland" and game.simulation_active() and absf(maxf(1.0, 0.7 / p.current_cooldown()) - 1.0) < TOL)

	for c in CASES: await one_case(c)

	print("CASE TABLE")
	for row in table: print("  f%d | expected: %s | observed: %s" % [row.f, row.expect, row.observed])
	print("TEST_WAVE_EDGES: %d passed / %d failed" % [passes, failures])
	rig.queue_free()
	await step(3)
	quit(1 if failures else 0)
