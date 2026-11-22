extends SceneTree
## 剑气骨骼移植策划案 §4: the release's interrupt paths A7 never tested, and
## edges at attack-speed rate r = 1.5. Through res://game/main.tscn and real
## input (Input.parse_input_event + root.push_input under --headless), same
## harness as test_wave_state_machine. Interrupts arrive on the 3rd unfrozen
## STARTUP tick (well before frame 6), so each must leave READY, no wave:
##   I1 loss of control (Player.apply_control "stun")  -> READY, no wave, charge kept
##   I2 operator swap (set_operator)                    -> READY, no wave (swap clears charge, as before)
##   I3 leaving the floor (GameManager._advance_floor, the exit path) -> READY, no wave
##   I4 death (take_damage lethal)                      -> READY, no wave
##   E1 at r = 1.5: a dodge on scaled frame 5 keeps the charge; on frame 6 the wave is out
## Run: ./scripts/run-test.sh test_wave_interrupts.gd 60 300
const DESIGN_FPS := 30.0           # phase table, at playback rate 1
const PHYSICS_HZ := 60.0           # project default (brief "Pinned engine")
const BASE_COOLDOWN := 0.7         # r4: r = max(1, 0.7 / current_cooldown())
const LANDED_SPAWN_OFFSET := 16    # r5: 12 unfrozen + 4 hitstop ticks on a landed release
const RIG_PARTS := ["Body", "ArmBack", "ArmFront"]
const TOL := 1e-4

var rig: Node
var game: GameManager
var p: Player
var failures := 0
var passes := 0

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

# ---- real input (same helpers as tests/test_a7_pins.gd) -----------------------
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

# ---- reading the game ----------------------------------------------------------
func waves() -> int:
	var n := 0
	for node in game.get_children():
		if node is SwordWave and not node.is_queued_for_deletion(): n += 1
	return n

func clear_waves() -> void:
	for node in game.get_children():
		if node is SwordWave: node.queue_free()

func state_name(value: int) -> String:
	return str(Player.WaveState.keys()[value])

func rig_player() -> AnimationPlayer:
	return p.get_node("WaveRig/AnimationPlayer") as AnimationPlayer

func billboard() -> Sprite3D:
	return p.get_node("WaveRig/Billboard") as Sprite3D

func viewport() -> SubViewport:
	return p.get_node("WaveRig/Viewport") as SubViewport

## One record per tick, read after the physics tick and the process frame.
func sample() -> Dictionary:
	var ap := rig_player()
	return {
		"state": state_name(p.wave_state), "frame": p.wave_frame, "time": p._wave_time,
		"anim": String(ap.current_animation), "pos": ap.current_animation_position if ap.current_animation != &"" else -1.0,
		"hitstop": p.hitstop_remaining, "waves": waves(), "charge": p.sword_charge,
		"sprite": p._sprite.visible, "billboard": billboard().visible, "swing": p.swing_remaining,
		"update": viewport().render_target_update_mode, "cooldown": p._attack_cooldown, "action": p._sprite.action_name,
	}

## Smallest count of unfrozen ticks after which the state machine's frame
## reaches `design_frame` at rate r (frame = floor(n * r * 30 / 60)).
func ticks_to(design_frame: int, r: float) -> int:
	var n := 1
	while floori(n * r * DESIGN_FPS / PHYSICS_HZ + 0.0001) < design_frame: n += 1
	return n

func spawn_enemy(life: float) -> Enemy:
	var at := p.global_position + Vector3(2, 0, 0)
	var enemy := game._spawn_enemy(at, true, false)
	enemy.global_position = at
	enemy.max_health = maxf(life, 1000000.0)
	enemy.health = life
	enemy.set_physics_process(false)
	return enemy

## Fixture: back on the open spot where the field case started (the dodges
## carry her toward walls, and a wall between her and the enemy blocks the
## swing), full charge, a fresh dodge, the attack cooldown run out.
var field_origin := Vector3.ZERO

func arm() -> void:
	clear_waves()
	for i in range(120):
		if p._attack_cooldown <= 0.0 and p.wave_state == Player.WaveState.READY: break
		await step()
	p.teleport(field_origin)
	await step(2)
	p.sword_charge = p.wave_hits_needed()
	p.stamina = 100.0
	p._dash_cooldown = 0.0
	await step(2)

## Real click on the enemy; returns the click tick's record (state STARTUP),
## or {} if no release started within 8 ticks.
func click_release(enemy: Enemy) -> Dictionary:
	mouse(enemy.global_position, true)
	for i in range(8):
		await step()
		if i == 0: mouse(enemy.global_position, false)
		if p.wave_state != Player.WaveState.READY: return sample()
	mouse(enemy.global_position, false)
	print("  (no release) player %s enemy %s in_range %s target %s cooldown %.3f charge %d busy %s sim %s" % [p.global_position, enemy.global_position,
		p.is_target_in_range(enemy), p.attack_target, p._attack_cooldown, p.sword_charge, game.hands_busy(), game.simulation_active()])
	print("  (no release) hitstop %.3f dash %.3f control %.3f shadow %s kit_busy %s sight %s dead %s state %s swing %.3f move_target %s" % [p.hitstop_remaining, p.dash_remaining,
		p.control_timer, p.shadow_active, p.kit != null and p.kit.busy(), game.line_of_sight(p.global_position, enemy.global_position), enemy._dead,
		state_name(p.wave_state), p.swing_remaining, p._has_move_target])
	return {}

## Records every tick from the click until READY (or `limit` ticks).

func into_startup(enemy: Enemy) -> bool:
	await arm()
	p._attack_cooldown = 0.0  # fixture: a swap can leave the cooldown running past arm()'s wait
	var rec := await click_release(enemy)
	if rec.is_empty(): return false
	await step(3)
	return p.wave_state == Player.WaveState.STARTUP

func after_interrupt(tag: String, waves0: int, expect_charge: int) -> void:
	await step(40)
	check("%s -> READY, rig hidden, sprite shown" % tag, p.wave_state == Player.WaveState.READY and not billboard().visible and p._sprite.visible, state_name(p.wave_state))
	check("%s -> no wave spawned" % tag, waves() == waves0, "%d -> %d" % [waves0, waves()])
	if expect_charge >= 0: check("%s -> charge %d" % [tag, expect_charge], p.sword_charge == expect_charge, str(p.sword_charge))

func run() -> void:
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(10)
	game = find_game(rig)
	game.fixed_map_seed = 1729
	game.seed_rng(1729)
	await game.start_contract("mine")
	game._clear_field()
	await step(3)
	p = game.player
	p.set_operator("lappland")
	var item := Item.create("Wave test sword", Item.Category.WEAPON, 2, 1)
	item.modifiers = [ItemModifier.trigger_mod(ItemModifier.Trigger.SWORD_WAVE)]
	p.equip(item)
	field_origin = p.global_position
	var enemy := spawn_enemy(100000000.0)
	await step(3)

	# I1 loss of control
	check("I1 setup: release in STARTUP", await into_startup(enemy))
	var w := waves()
	p.control_immune = 0.0
	check("I1 stun applied", p.apply_control("stun", Vector3.ZERO, 0.0, 0.5))
	await after_interrupt("I1 stun in STARTUP", w, p.wave_hits_needed())

	# I2 operator swap (set_operator -> reset_combat_state clears the charge, as it did before)
	await step(60)
	check("I2 setup: release in STARTUP", await into_startup(enemy))
	w = waves()
	p.set_operator("amiya_guard")
	await after_interrupt("I2 operator swap in STARTUP", w, -1)
	p.set_operator("lappland")
	p.equip(item)

	# I3 leaving the floor: a new floor resets the floor state mid-release
	await step(30)
	check("I3 setup: release in STARTUP", await into_startup(enemy))
	w = waves()
	var frame_before := p.wave_frame
	# Nothing left to swing at, so a STARTUP after the change can only be the old release.
	enemy.queue_free()
	p.attack_target = null
	# The real floor change (taking an exit): start_contract only runs from the
	# base and returns at once in the field (game/game_manager.gd:1046).
	await game._advance_floor(game.route_node.y if "route_node" in game else 0)
	p = game.player
	# Read on the floor change itself, before any new swing can start: with the
	# charge still full (a floor change keeps it) she may auto-swing into a new
	# release on the new floor, which is not the old one surviving.
	var tgt = p._wave_pending.get("target")
	var tgt_name: String = str(tgt.name) if is_instance_valid(tgt) else "none"
	print("  I3 old release at frame %d (target freed); right after the floor change: state %s frame %d charge %d, release target %s (old enemy freed: %s)" % [frame_before, state_name(p.wave_state), p.wave_frame, p.sword_charge, tgt_name, not is_instance_valid(enemy)])
	# A STARTUP whose target is a live new-floor enemy is a NEW release she auto-swung into;
	# the old one (whose target was freed) must have been reset.
	var same_target: bool = is_instance_valid(tgt) and is_instance_valid(enemy) and tgt == enemy
	print("  I3 target is the old enemy: %s; old enemy queued for deletion: %s" % [same_target, is_instance_valid(enemy) and enemy.is_queued_for_deletion()])
	var new_release: bool = p.wave_state != Player.WaveState.READY and is_instance_valid(tgt) and not same_target
	check("I3 new floor mid-release -> READY, rig hidden, sprite shown", p.wave_state == Player.WaveState.READY and not billboard().visible and p._sprite.visible and not new_release, state_name(p.wave_state))
	game._clear_field()
	await step(5)
	check("I3 no wave on the new floor", waves() == 0, str(waves()))
	field_origin = p.global_position
	enemy = spawn_enemy(100000000.0)
	await step(3)

	# E1 edges at r = 1.5 (attack speed through a real weapon affix, as D10a)
	var fast := Item.create("Wave test sword fast", Item.Category.WEAPON, 2, 1)
	fast.modifiers = [ItemModifier.trigger_mod(ItemModifier.Trigger.SWORD_WAVE), ItemModifier.stat_mod(ItemModifier.Stat.ATTACK_SPEED_PCT, 0.5)]
	p.equip(fast)
	await step(3)
	var r := p.animation_rate()
	check("E1 setup: r > 1 (%.3f)" % r, r > 1.01)
	for f in [5, 6]:
		await step(60)
		await arm()
		var rec := await click_release(enemy)
		check("E1 f%d setup: release started" % f, not rec.is_empty())
		w = waves()
		# The dodge must be read on the tick whose advance lands on frame f: at
		# r = 1.5 a tick moves 0.75 design frames, so wait until the NEXT tick's
		# frame is f, then press (the press is read on that next tick).
		var dt := 1.0 / PHYSICS_HZ
		for i in range(200):
			if p.wave_state == Player.WaveState.READY: break
			if floori((p._wave_time + dt * p._wave_rate) * DESIGN_FPS + 0.0001) >= f: break
			await step()
		dash_key(true)
		await step()
		dash_key(false)
		var most := waves()
		var charge_after := p.sword_charge
		for i in range(40):
			await step()
			most = maxi(most, waves())
		if f == 5: check("E1 r=%.2f dodge read on f5: no wave, charge kept" % r, most == w and charge_after == p.wave_hits_needed(), "waves %d->%d charge %d" % [w, most, charge_after])
		else: check("E1 r=%.2f dodge read on f6: the wave is out, charge 0" % r, most >= w + 1 and charge_after == 0, "waves %d->%d charge %d" % [w, most, charge_after])
	p.equip(item)

	# I4 death, last: it ends the run
	await step(60)
	check("I4 setup: release in STARTUP", await into_startup(enemy))
	w = waves()
	p.invulnerable = false
	p.invuln_timer = 0.0
	p.take_damage(1.0e9, "true")
	await step(5)
	check("I4 death in STARTUP -> READY", p.wave_state == Player.WaveState.READY, state_name(p.wave_state))
	check("I4 no wave after death", waves() == w, "%d -> %d" % [w, waves()])

	print("TEST_WAVE_INTERRUPTS: %d passed / %d failed" % [passes, failures])
	rig.queue_free()
	await step(3)
	quit(1 if failures else 0)
