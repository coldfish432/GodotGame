extends SceneTree
## A7 Step 5, plan step 4: structure + state test for Lappland's release
## (CHANGE-BRIEF.md "The state machine", "The two clocks", "The phase table",
## revisions r3, r4, r5). Agent, 2026-11-22.
##
## Run: ./scripts/run-test.sh test_wave_state_machine.gd 60
## (one physics tick and one process frame per step; nothing waits on audio).
##
## Static part (S*): the code's state table against the brief's constants and
## against the rig's AnimationPlayer resource; one-authority source checks.
## Dynamic part (D*): res://game/main.tscn, the real game loop and real input
## (Input.parse_input_event, also pushed into the root window under
## --headless, as tests/test_a7_pins.gd does). The test never calls
## _wave_begin, _tick_wave, _wave_to_ready or attack_direction; it only
## writes fixture values the pins also write (charge, stamina, dash cooldown,
## enemy health) and equips a weapon for the r > 1 case.
##
## Expected values are the brief's, written here as constants.

# ---- the brief's constants ---------------------------------------------------
const RIG_SCENE := "res://animations/lappland_wave_rig.tscn"
const NPC_SCENE := "res://animations/npc_idle.tscn"
const BRIEF_STATES := ["READY", "STARTUP", "ACTIVE", "RECOVERY"]
const BRIEF_CLIPS := {"READY": "RESET", "STARTUP": "wave_release", "ACTIVE": "wave_release", "RECOVERY": "wave_release"}
const BRIEF_TRANSITIONS := [["STARTUP", 6, "ACTIVE"], ["ACTIVE", 10, "RECOVERY"], ["RECOVERY", 20, "READY"]]
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
func record_release(enemy: Enemy, limit: int = 120) -> Array:
	var log: Array = []
	var first := await click_release(enemy)
	if first.is_empty(): return log
	log.append(first)
	for i in range(limit):
		await step()
		log.append(sample())
		if log[-1].state == "READY": break
	return log

## Per tick after the click: unfrozen count (a tick is frozen when hitstop was
## left over from the tick before), and where each state change happened.
func analyse(log: Array) -> Dictionary:
	var unfrozen := [0]
	var frozen := 0
	var changes := {}
	for k in range(1, log.size()):
		var was_frozen: bool = float(log[k - 1].hitstop) > 0.0
		if was_frozen: frozen += 1
		unfrozen.append(int(unfrozen[k - 1]) + (0 if was_frozen else 1))
		if log[k].state != log[k - 1].state: changes[log[k - 1].state + ">" + log[k].state] = k
	return {"unfrozen": unfrozen, "frozen": frozen, "changes": changes}

## D2-D7 on one recorded release that ends by itself (no swing after it).
func check_release(tag: String, log: Array, r: float, charge_full: int, waves_before: int) -> void:
	if log.size() < 3:
		check("%s release recorded" % tag, false, "log size %d" % log.size())
		return
	var a := analyse(log)
	var changes: Dictionary = a.changes
	var unfrozen: Array = a.unfrozen
	var order: Array = [log[0].state]
	for k in range(1, log.size()):
		if log[k].state != order[-1]: order.append(log[k].state)
	print("%s r=%.4f frozen=%d changes=%s order=%s" % [tag, r, a.frozen, str(changes), str(order)])
	# D2: states in order from the click tick.
	check("%s D2 states in order STARTUP -> ACTIVE -> RECOVERY -> READY from the click tick" % tag, order == ["STARTUP", "ACTIVE", "RECOVERY", "READY"], str(order))
	# D5/D4: each transition after the brief's frame count of unfrozen ticks.
	for t in BRIEF_TRANSITIONS:
		var key: String = t[0] + ">" + t[2]
		var k: int = changes.get(key, -1)
		var want := ticks_to(int(t[1]), r)
		check("%s D4 %s after %d unfrozen ticks (frame %d at rate %.3f)" % [tag, key, want, t[1], r],
			k > 0 and int(unfrozen[k]) == want, "tick %d, unfrozen %s" % [k, str(unfrozen[k]) if k > 0 else "-"])
	# D3/D4/D6/D7 every tick.
	var clip_ok := true
	var clock_ok := true
	var sight_ok := true
	var lock_ok := true
	var update_ok := true
	var startup_ok := true
	var detail := ""
	for k in range(log.size()):
		var s: Dictionary = log[k]
		var wave_state: bool = s.state != "READY"
		if s.anim != BRIEF_CLIPS[s.state]:
			if clip_ok: detail += "tick %d state %s anim '%s'; " % [k, s.state, s.anim]
			clip_ok = false
		if wave_state:
			var t_expected: float = int(unfrozen[k]) * r / PHYSICS_HZ
			var ok: bool = absf(float(s.pos) - float(s.time)) < TOL and absf(float(s.time) - t_expected) < TOL \
				and int(s.frame) == floori(float(s.time) * DESIGN_FPS + 0.0001) and floori(float(s.pos) * DESIGN_FPS + 0.0001) == int(s.frame)
			if not ok and clock_ok: detail += "tick %d pos %.5f time %.5f expected %.5f frame %d; " % [k, s.pos, s.time, t_expected, s.frame]
			clock_ok = clock_ok and ok
		if s.sprite == wave_state or s.billboard != wave_state: sight_ok = false
		if (s.update == SubViewport.UPDATE_ALWAYS) != wave_state: update_ok = false
		if s.state == "RECOVERY" and float(s.swing) <= 0.0: lock_ok = false
		if s.state == "STARTUP" and (int(s.waves) != waves_before or int(s.charge) != charge_full): startup_ok = false
	check("%s D3 the clip is wave_release in STARTUP/ACTIVE/RECOVERY and RESET in READY (current_animation)" % tag, clip_ok, detail)
	check("%s D4 every wave tick: clip position == state machine time == unfrozen ticks x r / 60, floor(position x 30) == wave_frame" % tag, clock_ok, detail)
	check("%s D6 operator sprite hidden and Billboard shown in every wave state, the reverse in READY" % tag, sight_ok)
	check("%s D6b rig viewport draws (UPDATE_ALWAYS) only during the release" % tag, update_ok)
	check("%s D7 swing_remaining > 0 through RECOVERY" % tag, lock_ok)
	check("%s D5 STARTUP: no wave, charge unchanged (%d)" % [tag, charge_full], startup_ok)
	var k_active: int = changes.get("STARTUP>ACTIVE", -1)
	if k_active > 0:
		check("%s D5 on the ACTIVE-entry tick: one wave out, charge 0" % tag,
			int(log[k_active].waves) == waves_before + 1 and int(log[k_active].charge) == 0 and int(log[k_active - 1].waves) == waves_before,
			"waves %d -> %d, charge %d" % [log[k_active - 1].waves, log[k_active].waves, log[k_active].charge])
	check("%s D7b move lock set on the click to 20/(30 r) s" % tag, absf(float(log[0].swing) - 20.0 / (DESIGN_FPS * r)) < TOL, "%.5f" % log[0].swing)

func run() -> void:
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(10)
	game = find_game(rig)
	game.fixed_map_seed = 1729
	game.seed_rng(1729)
	p = game.player

	# ================= static: S1-S6 ===========================================
	var keys: Array = Player.WaveState.keys()
	check("S1 WaveState is exactly READY, STARTUP, ACTIVE, RECOVERY (brief state table rows)", keys == BRIEF_STATES, str(keys))

	var ap := rig_player()
	var clips_ok := true
	var clips_detail := ""
	for state in Player.WAVE_CLIPS:
		var want: String = BRIEF_CLIPS.get(state_name(state), "?")
		var got := String(Player.WAVE_CLIPS[state])
		if got != want or not ap.has_animation(got):
			clips_ok = false
			clips_detail += "%s: %s (brief %s, exists %s); " % [state_name(state), got, want, ap.has_animation(got)]
	check("S2 every clip the code requests exists on the live rig and matches the brief's state table", clips_ok and Player.WAVE_CLIPS.size() == BRIEF_STATES.size(), clips_detail)

	var table: Array = []
	for t in Player.WAVE_TRANSITIONS: table.append([state_name(t[0]), int(t[1]), state_name(t[2])])
	check("S3 the code's transitions are the brief's: STARTUP@6->ACTIVE, ACTIVE@10->RECOVERY, RECOVERY@20->READY", table == BRIEF_TRANSITIONS, str(table))
	var clip := ap.get_animation(&"wave_release")
	var keyed_ok := clip != null
	var keyed_detail := ""
	if clip != null:
		for t in BRIEF_TRANSITIONS:
			var at := float(t[1]) / DESIGN_FPS
			if at > clip.length + TOL:
				keyed_ok = false
				keyed_detail += "f%d past length; " % t[1]
			for track in range(clip.get_track_count()):
				var found := false
				for key in range(clip.track_get_key_count(track)):
					if absf(clip.track_get_key_time(track, key) - at) < 0.5 / DESIGN_FPS: found = true
				if not found:
					keyed_ok = false
					keyed_detail += "%s has no key at f%d; " % [str(clip.track_get_path(track)), t[1]]
	check("S3b each transition frame lies in wave_release and every track has a key there", keyed_ok, keyed_detail)

	print("S4 note: there is no AnimationTree (brief: \"No AnimationTree\"), so the AnimationTree checks "
		+ "(advance_expression_base_node set, each transition's advance_mode) do not apply; asserting there is none.")
	var trees := game.find_children("*", "AnimationTree", true, false).size() + p.find_children("*", "AnimationTree", true, false).size()
	var rig_scene := (load(RIG_SCENE) as PackedScene).instantiate()
	trees += rig_scene.find_children("*", "AnimationTree", true, false).size()
	rig_scene.free()
	check("S4 no AnimationTree in the game, the player or the rig scene", trees == 0, str(trees))

	var wave_rig := p.get_node_or_null("WaveRig")
	check("S5 the player's rig is an instance of %s (not built in code)" % RIG_SCENE, wave_rig != null and wave_rig.scene_file_path == RIG_SCENE, wave_rig.scene_file_path if wave_rig else "missing")
	check("S5b rig clock is ANIMATION_CALLBACK_MODE_PROCESS_MANUAL, no autoplay", ap.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL and ap.autoplay == "")
	check("S5c Billboard is in upright_sprites (brief r3)", billboard().is_in_group("upright_sprites"))

	# S6: one authority, by source.
	var player_src := FileAccess.get_file_as_string("res://entities/player.gd")
	var callers := {}
	var blocks := player_src.split("\nfunc ")
	var call := RegEx.create_from_string("_wave_player\\.(play|advance|seek|stop)\\(")
	for block in blocks:
		if call.search(block) != null: callers[block.get_slice("(", 0)] = true
	# _build_wave_rig is the state machine starting in READY: it plays RESET once
	# at build (brief state table; added in Step 5 plan step 5, user: "Yes, allow it").
	check("S6 the rig AnimationPlayer's play/advance/seek/stop are called only from the wave state machine",
		not callers.is_empty() and callers.keys().all(func(c): return c in ["_build_wave_rig", "_wave_begin", "_tick_wave", "_wave_to_ready"]), str(callers.keys()))
	var others: Array = []
	var player_sprite_visible := RegEx.create_from_string("(player|\\bp)\\._sprite\\.visible")
	var scripts := _scripts("res://")
	for path in scripts:
		if path == "res://entities/player.gd": continue
		var text := FileAccess.get_file_as_string(path)
		# Enemies and bosses have their own `_sprite`; only the player's counts.
		if "lappland_wave_rig" in text or "_wave_player" in text or "_wave_billboard" in text or "_wave_rig_root" in text or player_sprite_visible.search(text) != null:
			others.append(path)
	check("S6b no other script (outside tests/, previews/) touches the rig or the operator sprite's visible (%d scripts read)" % scripts.size(), others.is_empty(), str(others))
	var npc_writers: Array = []
	for path in scripts:
		var text := FileAccess.get_file_as_string(path)
		if path != "res://art/field_art.gd" and "npc_idle.tscn" in text: npc_writers.append(path + " (instances npc_idle.tscn)")
	for pair in [["res://art/field_art.gd", "static func npc_idle"], ["res://world/continuous_world_map.gd", "func _set_piece"], ["res://world/base_map.gd", "func _add_closure"]]:
		var body := _function_body(FileAccess.get_file_as_string(pair[0]), pair[1])
		if body.is_empty() or ".frame" in body: npc_writers.append("%s %s" % [pair[0], "missing" if body.is_empty() else "writes .frame"])
	check("S6c NpcIdle.frame has no second writer: FieldArt.npc_idle, _set_piece and _add_closure never write .frame; only field_art.gd instances the scene", npc_writers.is_empty(), str(npc_writers))

	# ================= S7: NPC idles from the scene ============================
	var closure := game.base_map.get_node_or_null("store/Closure")
	var closure_ap: AnimationPlayer = closure.get_node_or_null("AnimationPlayer") if closure else null
	check("S7 base 可露希尔 is a Sprite3D from %s playing idle (current_animation)" % NPC_SCENE,
		closure is Sprite3D and closure.scene_file_path == NPC_SCENE and closure_ap != null and closure_ap.current_animation == &"idle")

	# ================= field ===================================================
	await game.start_contract("mine")
	game._clear_field()
	await step(3)
	p = game.player
	p.set_operator("lappland")

	var piece: Node3D = game.world_map._set_piece("A7 squad fixture", p.global_position + Vector3(-6, 0, 6), Color.WHITE, game.world_map.ENCOUNTER_MODELS["squad"], "squad")
	var phases: Array = []
	var npc_ok := true
	for child in piece.get_children():
		if not child is Sprite3D: continue
		var fap := child.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if fap == null or child.scene_file_path != NPC_SCENE or fap.current_animation != &"idle":
			npc_ok = false
			continue
		var pos := fap.current_animation_position
		phases.append(pos)
		# Seeked to a cell start (k/3 s), and the frame shows that cell.
		if absf(pos * 3.0 - roundf(pos * 3.0)) > TOL or int(child.frame) != roundi(pos * 3.0) % 4: npc_ok = false
	print("S7 squad phases ", phases)
	check("S7b field squad: 3 figures from the scene, each seeked once to a cell start that its frame shows", npc_ok and phases.size() == 3, str(phases))
	check("S7c field squad does not breathe in step (phases differ)", phases.size() == 3 and not (phases[0] == phases[1] and phases[1] == phases[2]), str(phases))
	piece.queue_free()
	await step(2)

	var item := Item.create("A7 state sword", Item.Category.WEAPON, 2, 1)
	item.modifiers = [ItemModifier.trigger_mod(ItemModifier.Trigger.SWORD_WAVE)]
	p.equip(item)
	await step(3)
	field_origin = p.global_position
	check("D0 Lappland in the field, simulation running", p.operator_id == "lappland" and game.simulation_active())

	# ================= D1: rest ================================================
	var rest := sample()
	var reset := ap.get_animation(&"RESET")
	var pose_ok := reset != null
	if reset != null:
		for track in range(reset.get_track_count()):
			var path := reset.track_get_path(track)
			var node := (ap.get_node(ap.root_node) as Node).get_node_or_null(NodePath(path.get_concatenated_names()))
			if node == null or node.get(path.get_concatenated_subnames()) != reset.track_get_key_value(track, 0): pose_ok = false
	print("D1 at rest: current_animation '%s' (nothing has been played yet at start)" % rest.anim)
	check("D1 READY at start: Billboard hidden, sprite shown, viewport not drawing, rig at the RESET pose",
		rest.state == "READY" and not rest.billboard and rest.sprite and rest.update == SubViewport.UPDATE_DISABLED and pose_ok)

	# ================= D2-D7: a release that ends by itself, r = 1 ===========
	await arm()
	var full := p.wave_hits_needed()
	var r1 := maxf(1.0, BASE_COOLDOWN / p.current_cooldown())
	check("D2a rate r == 1 for the base case (current_cooldown %.3f)" % p.current_cooldown(), absf(r1 - 1.0) < TOL)
	var before := waves()
	var log := await record_release(spawn_enemy(1.0))   # the release's hit kills it: no swing follows
	check_release("[r=1]", log, r1, full, before)
	var a1 := analyse(log)
	var k_active: int = a1.changes.get("STARTUP>ACTIVE", -1)
	check("D5b landed release: the wave leaves %d ticks after the click (12 unfrozen + 4 hitstop, brief r5)" % LANDED_SPAWN_OFFSET, k_active == LANDED_SPAWN_OFFSET, "%d (frozen %d)" % [k_active, a1.frozen])
	check("D3b back in READY the rig plays RESET", not log.is_empty() and log[-1].anim == "RESET")
	await step(30)

	# ================= D8: a dodge in each wave state → READY ================
	for target_state in ["STARTUP", "ACTIVE", "RECOVERY"]:
		await arm()
		var waves_at := waves()
		var enemy := spawn_enemy(1000000.0)
		var first := await click_release(enemy)
		var reached := not first.is_empty()
		for i in range(60):
			if not reached or state_name(p.wave_state) == target_state: break
			await step()
		var in_state: bool = state_name(p.wave_state) == target_state
		var frame_at := p.wave_frame
		dash_key(true)
		await step()
		dash_key(false)
		var after := sample()
		# Waves can leave the scene (range, walls) within the window: count the most seen.
		var most_waves: int = after.waves
		for i in range(30):
			await step()
			most_waves = maxi(most_waves, waves())
		var later := sample()
		later.waves = most_waves
		var wave_kept: bool = target_state == "STARTUP"
		print("D8 dodge in %s at frame %d: state now %s, waves %d -> %d, charge %d" % [target_state, frame_at, after.state, waves_at, later.waves, later.charge])
		check("D8 dodge in %s (frame %d) -> READY, sprite back, rig hidden, RESET" % [target_state, frame_at],
			reached and in_state and after.state == "READY" and after.sprite and not after.billboard and after.anim == "RESET")
		if wave_kept:
			check("D8 dodge in STARTUP: no wave, charge kept (%d)" % full, int(later.waves) == waves_at and int(later.charge) == full, "waves %d charge %d" % [later.waves, later.charge])
		else:
			check("D8 dodge in %s: the wave is already out, charge spent" % target_state, int(later.waves) == waves_at + 1 and int(later.charge) == 0, "waves %d charge %d" % [later.waves, later.charge])
		enemy.queue_free()
		await step(60)

	# ================= D9: a swing in RECOVERY → READY (brief r3) ============
	await arm()
	var sturdy := spawn_enemy(1000000.0)
	var rlog: Array = []
	var start := await click_release(sturdy)   # the target stays locked: the next swing comes on cooldown
	if not start.is_empty():
		rlog.append(start)
		for i in range(80):
			await step()
			rlog.append(sample())
			if rlog[-1].state == "READY": break
	var last: Dictionary = rlog[-1] if not rlog.is_empty() else {}
	var prev: Dictionary = rlog[-2] if rlog.size() >= 2 else {}
	var swung := not last.is_empty() and not prev.is_empty() and float(last.cooldown) > float(prev.cooldown) + TOL
	print("D9 recovery cut: prev state %s frame %d, swing on that tick %s, action '%s'" % [prev.get("state", "-"), prev.get("frame", -1), swung, last.get("action", "")])
	check("D9 a new swing during RECOVERY (frame < 20) ends it: READY on the swing's tick, sprite back playing the swing",
		swung and prev.get("state", "") == "RECOVERY" and int(prev.get("frame", 99)) < 20 and last.get("state", "") == "READY"
		and last.sprite and not last.billboard and str(last.action).begins_with("attack_"))
	mouse(sturdy.global_position, false)
	sturdy.queue_free()
	# A ground click replaces the lock (no further swings at it).
	mouse(p.global_position + Vector3(0, 0, -0.1), true)
	await step()
	mouse(p.global_position + Vector3(0, 0, -0.1), false)
	await step(90)

	# ================= D10: r > 1 (brief r4) =================================
	var fast := Item.create("A7 fast sword", Item.Category.WEAPON, 2, 1)
	fast.modifiers = [ItemModifier.trigger_mod(ItemModifier.Trigger.SWORD_WAVE), ItemModifier.stat_mod(ItemModifier.Stat.ATTACK_SPEED_PCT, 0.5)]
	p.equip(fast)
	await step(3)
	await arm()
	var r_fast := maxf(1.0, BASE_COOLDOWN / p.current_cooldown())
	check("D10a attack speed raised through a weapon affix: r = %.4f > 1 (current_cooldown %.4f)" % [r_fast, p.current_cooldown()], r_fast > 1.0 + TOL)
	before = waves()
	var flog := await record_release(spawn_enemy(1.0))
	check_release("[r=%.2f]" % r_fast, flog, r_fast, p.wave_hits_needed(), before)

	print("TEST_WAVE_STATE_MACHINE: %d passed / %d failed" % [passes, failures])
	rig.queue_free()
	await step(3)
	quit(1 if failures else 0)

## Every .gd under `dir`, outside tests/, previews/ and .godot/.
func _scripts(dir: String) -> Array:
	var found: Array = []
	var d := DirAccess.open(dir)
	if d == null: return found
	for sub in d.get_directories():
		if sub.begins_with(".") or (dir == "res://" and sub in ["tests", "previews", "logs", "evidence"]): continue
		found.append_array(_scripts(dir.path_join(sub)))
	for file in d.get_files():
		if file.ends_with(".gd"): found.append(dir.path_join(file))
	return found

## The text of one function: from its header to the next top-level declaration.
func _function_body(source: String, header: String) -> String:
	var at := source.find(header)
	if at < 0: return ""
	var lines := source.substr(at).split("\n")
	var body := lines[0]
	for i in range(1, lines.size()):
		var line: String = lines[i]
		if not line.is_empty() and not line.begins_with("\t") and not line.begins_with(" ") and not line.begins_with("#"): break
		body += "\n" + line
	return body
