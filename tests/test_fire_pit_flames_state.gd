extends SceneTree
## Effect B `fire_pit_flames` state test (CHANGE-BRIEF.md B1-B6, prompts/plan-5.md).
## The real game (game/main.tscn), the real loop, a real Sami floor. Fuel goes on
## only through the real E key and a real left click on the fuel picker's row
## (GameManager._interact -> fuel modal -> Button.pressed -> burn_fuel -> feed);
## fuel burns only through GameManager._physics_process -> _tick_features -> burn.
## The test never calls feed(), burn(), _set_lit() or _show_fuel().
## A monitor on process_frame samples every FirePit every frame and checks
## emitting == (burn_left > 0), amount_ratio == 0.3 + 0.7*clamp(burn_left/120),
## amount == 24 / 10, and records 0 -> >0 and >0 -> 0 edges.
## Run: ./scripts/run-test.sh test_fire_pit_flames_state.gd 60 600

const SEED := 2026
const PIT_INDEX := 1
const AMOUNTS := {"Flames": 24, "Embers": 10}
const EPS := 0.0001

var rig: Node
var game: GameManager
var failures := 0
## FirePit instance id -> last sampled burn_left.
var last_burn: Dictionary = {}
## FirePit instance id -> its first sample {frame, burn_left, emitting, ratio}.
var first_seen: Dictionary = {}
## FirePit instance id -> process frame it entered the tree.
var added_at: Dictionary = {}
var edges: Array[Dictionary] = []
var violations: Array[String] = []
var samples := 0
var lit_samples := 0
var ratios_seen: Dictionary = {}

func _initialize() -> void: call_deferred("run")

func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame

func check(label: String, passed: bool, detail: Variant = null) -> void:
	print(("PASS " if passed else "FAIL ") + label + ("" if detail == null else "  [%s]" % str(detail)))
	if not passed: failures += 1

func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null

static func mapping(burn_left: float) -> float:
	return 0.3 + 0.7 * clampf(burn_left / 120.0, 0.0, 1.0)

func emitters(pit: FirePit) -> Array[GPUParticles3D]:
	var out: Array[GPUParticles3D] = []
	var fx := pit.get_node_or_null("FirePitFlames")
	if fx == null: return out
	for name in ["Flames", "Embers"]:
		var p := fx.get_node_or_null(name) as GPUParticles3D
		if p != null: out.append(p)
	return out

func state(pit: FirePit) -> Dictionary:
	var ps := emitters(pit)
	return {"burn_left": pit.burn_left, "emitting": ps.map(func(p): return p.emitting),
		"ratio": ps.map(func(p): return p.amount_ratio), "amount": ps.map(func(p): return p.amount),
		"processing": ps.map(func(p): return p.can_process())}

func _on_added(node: Node) -> void:
	if node is FirePit: added_at[node.get_instance_id()] = Engine.get_process_frames()

## Every frame, every FirePit in the tree.
func _monitor() -> void:
	for node in get_nodes_in_group("fire_pits"):
		var pit := node as FirePit
		if pit == null or not is_instance_valid(pit) or not pit.is_inside_tree(): continue
		var id := pit.get_instance_id()
		var ps := emitters(pit)
		var b := pit.burn_left
		samples += 1
		if ps.size() != 2:
			violations.append("frame %d pit %d has %d emitters" % [Engine.get_process_frames(), id, ps.size()])
			continue
		var want := mapping(b)
		for p in ps:
			if p.emitting != (b > 0.0): violations.append("frame %d %s emitting %s at burn_left %.4f" % [Engine.get_process_frames(), p.name, p.emitting, b])
			if absf(p.amount_ratio - want) > EPS: violations.append("frame %d %s amount_ratio %.5f, mapping %.5f (burn_left %.4f)" % [Engine.get_process_frames(), p.name, p.amount_ratio, want, b])
			if p.amount != int(AMOUNTS[str(p.name)]): violations.append("frame %d %s amount %d" % [Engine.get_process_frames(), p.name, p.amount])
		if b > 0.0:
			lit_samples += 1
			ratios_seen[snappedf(ps[0].amount_ratio, 0.001)] = true
		if not first_seen.has(id):
			first_seen[id] = {"frame": Engine.get_process_frames(), "burn_left": b, "emitting": ps.map(func(p): return p.emitting), "ratio": ps.map(func(p): return p.amount_ratio)}
		var before := float(last_burn.get(id, b))
		if before <= 0.0 and b > 0.0 or before > 0.0 and b <= 0.0:
			edges.append({"pit": id, "frame": Engine.get_process_frames(), "from": before, "to": b, "emitting": ps.map(func(p): return p.emitting), "ratio": ps.map(func(p): return p.amount_ratio)})
		last_burn[id] = b

## Input.parse_input_event feeds the Input singleton, which GameManager polls
## (is_action_just_pressed). A mouse event is also pushed into the root window
## (headless drops the window dispatch; same as test_hit_spark_state.gd) so it
## reaches the GUI Button.
## The headless display server never flushes the Input buffer (its
## process_events is empty; measured: E and Esc did nothing), so the test
## flushes it the way a windowed DisplayServer does once per frame.
func send(event: InputEvent, to_gui := false) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	if to_gui: root.push_input(event, true)

func key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.keycode = code
		e.pressed = pressed
		send(e)
		await step(1)

## A real left click at the centre of `control` on screen.
func click(control: Control) -> void:
	var at := control.get_global_transform_with_canvas() * (control.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	send(motion, true)
	await step(1)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.position = at
		e.global_position = at
		e.pressed = pressed
		e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		send(e, true)
		await step(1)

## E at the pit, then a click on the picker's row for `fuel`. Returns the row found.
func feed_by_hand(pit: FirePit, fuel: String) -> bool:
	await key(KEY_E)
	if game.modal != "fuel" or game.fuel_fire != pit:
		print("E did not open the fuel picker for this pit: modal '%s'" % game.modal)
		return false
	var rows: Array = game.menu.stage.find_children("*", "Button", true, false).filter(func(b): return b.get_meta("fuel", "") == fuel)
	if rows.is_empty():
		print("no picker row for ", fuel)
		return false
	await click(rows[0])
	await step(1)
	return game.modal.is_empty()

func keep_safe() -> void:
	if is_instance_valid(game.player): game.player.hp = game.player.max_hp

func run() -> void:
	node_added.connect(_on_added)
	process_frame.connect(_monitor)
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(10)
	game = find_game(rig)
	game.fixed_map_seed = SEED
	game.seed_rng(SEED)
	await game.start_contract("snow")
	await step(30)
	var fires := game.fires.filter(func(f): return is_instance_valid(f))
	print("FLOOR region %s floor %d fires %d simulation_active %s modal '%s' display %s" % [game.region_id, game.floor_number, fires.size(), game.simulation_active(), game.modal, DisplayServer.get_name()])
	check("a real Sami floor with fires, the field running", game.region_id == "snow" and fires.size() >= 1 and game.simulation_active())
	var pit: FirePit = fires[mini(PIT_INDEX, fires.size() - 1)]
	var fx := pit.get_node_or_null("FirePitFlames") as Node3D
	check("the pit holds one FirePitFlames instance and no CPUParticles3D",
		fx != null and fx.scene_file_path == "res://effects/fire_pit_flames.tscn" and pit.find_children("*", "CPUParticles3D", true, false).is_empty()
		and pit.find_children("*", "GPUParticles3D", true, false).size() == 2)
	check("model and Glow kept", pit.has_node("Model") and pit.has_node("Glow"))
	var s0 := state(pit)
	check("cold pit: burn_left 0, not emitting, ratio 0.3", s0.burn_left == 0.0 and s0.emitting == [false, false] and s0.ratio.all(func(r): return absf(r - 0.3) < EPS), s0)

	# Fixture: no enemies, her beside the pit, fuel in the pack.
	game._clear_field()
	await step(2)
	game.player.teleport(game.world_map.nearest_walkable(pit.global_position + Vector3(1.2, 0, 0)))
	game.inventory.add_stack(MaterialCatalog.create("木板", 1))
	game.inventory.add_stack(MaterialCatalog.create("固体燃料", 1))
	game.inventory.add_stack(MaterialCatalog.create("木板", 1))
	await step(3)
	print("PROMPT '%s' near_fire %s" % [game.interaction_prompt(), game.near_fire() == pit])

	# --- B1 + B3 (feed): a plank by E + click, 0 -> 60 ---
	var edge_count := edges.size()
	var fed := await feed_by_hand(pit, "木板")
	var s1 := state(pit)
	var rise: Array = edges.slice(edge_count).filter(func(e): return e.pit == pit.get_instance_id() and e.from <= 0.0)
	print("B1 after plank: ", s1, " edges ", rise)
	check("B1 E + click on the plank row fed the fire through the real path (burn_left ~60)", fed and absf(s1.burn_left - 60.0) < 0.1, s1.burn_left)
	check("B1 the sample where burn_left went 0 -> >0 already has both emitters emitting", rise.size() == 1 and rise[0].emitting == [true, true], rise)
	check("B3 (feed) amount_ratio = mapping(burn_left) at ~60 (~0.65) on both", s1.ratio.all(func(r): return absf(r - mapping(s1.burn_left)) < EPS and absf(r - 0.65) < 0.002), s1.ratio)
	print("HEADLESS emitting read back on continuous GPU emitters right after lighting: ", s1.emitting)

	# --- B3 (burn): ~10 s of the real physics loop ---
	var before_burn: float = s1.burn_left
	for i in range(600):
		keep_safe()
		await step()
	var s2 := state(pit)
	print("B3 after 600 frames: ", s2)
	check("B3 (burn) the physics loop burned ~10 s (simulation_active)", absf((before_burn - s2.burn_left) - 10.0) < 0.2, before_burn - s2.burn_left)
	check("B3 (burn) amount_ratio followed: = mapping(%.3f) and moved off 0.65" % s2.burn_left, s2.ratio.all(func(r): return absf(r - mapping(s2.burn_left)) < EPS) and absf(s2.ratio[0] - 0.65) > 0.05, s2.ratio)
	check("B3 amount unchanged 24 / 10", s2.amount == [24, 10], s2.amount)

	# --- B4 (tree paused) ---
	paused = true
	await step(60)
	var s3 := state(pit)
	print("B4 paused 60 frames: ", s3)
	check("B4 tree paused: burn_left frozen", s3.burn_left == s2.burn_left, [s2.burn_left, s3.burn_left])
	check("B4 tree paused: emitting and amount_ratio unchanged", s3.emitting == [true, true] and s3.ratio == s2.ratio, [s2.ratio, s3.ratio])
	check("B4 tree paused: both emitters stop processing (can_process false)", s3.processing == [false, false], s3.processing)
	var frozen := pit.burn_left
	await step(30)
	check("B4 tree paused: still exactly frozen 30 frames later", pit.burn_left == frozen)
	paused = false
	await step(2)

	# --- B4 (a real menu modal: Esc -> pause menu) ---
	await key(KEY_ESCAPE)
	var menu_kind := game.modal
	var sim := game.simulation_active()
	var s4a := state(pit)
	var b_open := pit.burn_left
	await step(60)
	var s4 := state(pit)
	print("B4 menu '%s' simulation_active %s 60 frames: %s" % [menu_kind, sim, s4])
	check("B4 Esc opened a real menu modal and simulation_active() went false; tree not paused", not menu_kind.is_empty() and not sim and not paused, [menu_kind, sim])
	check("B4 menu: burn_left frozen", s4.burn_left == b_open, [b_open, s4.burn_left])
	check("B4 menu: emitting / amount_ratio unchanged (constant ratio)", s4.emitting == [true, true] and s4.ratio == s4a.ratio, [s4a.ratio, s4.ratio])
	check("B4 menu: the GPU nodes keep processing", s4.processing == [true, true], s4.processing)
	await key(KEY_ESCAPE)
	await step(2)
	check("Esc closed the menu, the field runs again", game.modal.is_empty() and game.simulation_active(), game.modal)

	# --- B5 (pit hidden): the loop keeps burning, presentation keeps following ---
	pit.visible = false
	var s5a := state(pit)
	for i in range(600):
		keep_safe()
		await step()
	var s5 := state(pit)
	print("B5 pit hidden 600 frames: ", s5)
	check("B5 pit hidden: burn_left still falls in the loop", s5a.burn_left - s5.burn_left > 9.0, [s5a.burn_left, s5.burn_left])
	check("B5 pit hidden: emitting true and amount_ratio = mapping(burn_left), changed while hidden", s5.emitting == [true, true] and absf(s5.ratio[0] - mapping(s5.burn_left)) < EPS and absf(s5.ratio[0] - s5a.ratio[0]) > 0.04, [s5a.ratio, s5.ratio])
	pit.visible = true
	await step(1)
	var s5b := state(pit)
	check("B5 shown again: the current ratio", absf(s5b.ratio[0] - mapping(s5b.burn_left)) < EPS and s5b.emitting == [true, true], s5b)

	# --- B2: burn to 0 in the loop ---
	edge_count = edges.size()
	var guard := 0
	while pit.burn_left > 0.0 and guard < 60 * 70:
		keep_safe()
		await step()
		guard += 1
	var fall: Array = edges.slice(edge_count).filter(func(e): return e.pit == pit.get_instance_id() and e.to <= 0.0)
	print("B2 out after %d frames, edges %s" % [guard, fall])
	check("B2 burned out in the loop", pit.burn_left == 0.0)
	check("B2 the sample where burn_left reached 0 has both emitters stopped", fall.size() == 1 and fall[0].emitting == [false, false], fall)
	await step(140)
	var s6 := state(pit)
	check("B2 2.3 s later: still not emitting, burn_left 0, ratio 0.3", s6.burn_left == 0.0 and s6.emitting == [false, false] and absf(s6.ratio[0] - 0.3) < EPS, s6)

	# --- B1 (relight) + B3 (>= 120) + B5 (effect root hidden) ---
	fx.visible = false
	edge_count = edges.size()
	game._clear_field()
	game.player.teleport(game.world_map.nearest_walkable(pit.global_position + Vector3(1.2, 0, 0)))
	await step(2)
	var fed2 := await feed_by_hand(pit, "固体燃料")
	var s7 := state(pit)
	var rise2: Array = edges.slice(edge_count).filter(func(e): return e.pit == pit.get_instance_id() and e.from <= 0.0)
	print("B1 relight (effect hidden): ", s7, " edges ", rise2)
	check("B1 relight by E + click (solid fuel, 0 -> ~120) with the effect root hidden", fed2 and absf(s7.burn_left - 120.0) < 0.1, s7.burn_left)
	check("B1 relight: emitting on the 0 -> >0 sample", rise2.size() == 1 and rise2[0].emitting == [true, true], rise2)
	check("B3/B5 at ~120 while hidden: ratio = mapping (~1.0)", s7.ratio.all(func(r): return absf(r - mapping(s7.burn_left)) < EPS) and s7.ratio[0] > 0.99, s7.ratio)
	var fed3 := await feed_by_hand(pit, "木板")
	var s8 := state(pit)
	print("B3 plank on a lit fire: ", s8)
	check("B3 (feed, lit fire) a plank on top -> ~180, ratio clamps at 1.0", fed3 and absf(s8.burn_left - 180.0) < 0.2 and s8.ratio.all(func(r): return absf(r - 1.0) < EPS), s8)
	fx.visible = true
	await step(1)
	check("B5 effect root shown again: emitting at the current ratio", state(pit).emitting == [true, true] and absf(state(pit).ratio[0] - 1.0) < EPS)

	# --- B6: a fire lit at floor load (rest-stop campfire) ---
	# Fixture: the route map's next column is made of rest nodes (as test_route_map.gd
	# does); then the real advance() builds the floor, which feeds its campfire 300 s.
	game._ensure_route()
	var c := game.route_node.x + 1
	for node in game.route_map.cols[c]:
		node.kind = "rest"
		node.exit = false
		node.mark = ""
	await game.advance(0)
	await step(5)
	var rest := game.rest_fire
	print("B6 floor %d route_kind %s rest_fire %s" % [game.floor_number, game.route_kind, rest])
	check("B6 a rest-stop floor with its campfire", game.route_kind == "rest" and is_instance_valid(rest))
	if is_instance_valid(rest):
		var first: Dictionary = first_seen.get(rest.get_instance_id(), {})
		var added := int(added_at.get(rest.get_instance_id(), -1))
		print("B6 campfire added at frame %d, first sample %s" % [added, first])
		check("B6 the campfire's first sampled frame (same or next frame after it entered the tree): burn_left 300, both emitting, ratio 1.0",
			not first.is_empty() and int(first.frame) - added <= 1 and absf(float(first.burn_left) - 300.0) < 0.1 and first.emitting == [true, true]
			and (first.ratio as Array).all(func(r): return absf(r - 1.0) < EPS), first)

	# --- Whole run ---
	print("MONITOR samples %d lit %d distinct ratios %d edges %d violations %d" % [samples, lit_samples, ratios_seen.size(), edges.size(), violations.size()])
	for v in violations.slice(0, 10): print("  VIOLATION ", v)
	check("B3 every frame, every pit: emitting == (burn_left > 0), amount_ratio == mapping (±1e-4), amount 24/10", violations.is_empty() and samples > 1000)
	check("B3 amount_ratio took many values while lit (feeding and burning)", ratios_seen.size() >= 3, ratios_seen.size())
	print("FIRE_PIT_FLAMES_STATE: %d failures" % failures)
	process_frame.disconnect(_monitor)
	rig.queue_free()
	await create_timer(0.3).timeout
	quit(1 if failures else 0)
