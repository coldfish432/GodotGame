extends SceneTree

## Film capture choreography for the final-project pitch (not shipped game code;
## lives only in an isolated clone). Drives the real main scene. Combat and
## walking come from AiDriver (tests/ai_driver.gd): it re-reads game state each
## tick and issues the same calls a click makes (Player.set_move_target,
## Player.attack, GameManager._interact). Labelled "scripted input" in the film.
## Every decision and every setup shortcut is logged to user://<clip>-inputs.jsonl.
##
## godot --path <clone> --script res://tests/capture_pitch_film.gd
##       --write-movie <out>.avi --fixed-fps 30 -- <clip> [seed]
## Clips: mine | regions | bridge | camp | base | title

const FPS := 30.0
var rig: Node
var game: GameManager
var clip := ""
var log_lines: PackedStringArray = []
var frame := 0
var driver: AiDriver

func _initialize() -> void: call_deferred("run")

func note(event: String, data: Dictionary = {}) -> void:
	data["frame"] = frame
	data["event"] = event
	log_lines.append(JSON.stringify(data))
	print("[pitch] ", JSON.stringify(data))

func frames(n: int) -> void:
	for i in range(n):
		await process_frame
		frame += 1

func seconds(s: float) -> void:
	await frames(int(round(s * FPS)))

func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null

func key(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)

func tap(code: Key) -> void:
	note("tap", {"key": OS.get_keycode_string(code)})
	key(code, true)
	await frames(2)
	key(code, false)
	await frames(1)

func click(at: Vector2) -> void:
	for pressed in [true, false]:
		var m := InputEventMouseMotion.new()
		m.position = at
		m.global_position = at
		Input.parse_input_event(m)
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = at
		e.global_position = at
		Input.parse_input_event(e)
		await frames(3)

func find_button(node: Node, text: String) -> BaseButton:
	if node is BaseButton and node.is_visible_in_tree():
		var label := str(node.text) if "text" in node else ""
		if label.contains(text) or str(node.get_meta("label", "")).contains(text): return node
	for child in node.get_children():
		var found := find_button(child, text)
		if found != null: return found
	return null

## A real mouse click on the visible button whose text contains `text`.
func click_button(text: String) -> bool:
	var b := find_button(root, text)
	if b == null:
		note("button_missing", {"text": text})
		return false
	var at: Vector2 = b.get_viewport().get_screen_transform() * b.get_global_rect().get_center()
	note("click", {"button": text, "window_xy": [at.x, at.y]})
	await click(at)
	return true

## Let AiDriver play for `s` seconds (or until `stop` returns true). A route
## choice is held on screen `route_hold` seconds before the driver takes it.
func play(s: float, stop: Callable = Callable(), route_hold: float = 3.0) -> void:
	var n := 0
	var held := 0
	while n < int(s * FPS):
		if stop.is_valid() and stop.call(): return
		if game.modal == "route" and held < int(route_hold * FPS):
			held += 1
		elif game.modal == "build" and held < int(2.5 * FPS):
			held += 1  # hold the relic choice so it is readable
		else:
			if game.modal in ["route", "build"]:
				note("driver_choice", {"modal": game.modal})
				held = 0
			driver.decide(game)
		await frames(1)
		n += 1

func boot(seed: int) -> void:
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await frames(20)
	game = find_game(rig)
	game.save_enabled = false
	if seed:
		game.fixed_map_seed = seed
		game.seed_rng(seed)
	driver = AiDriver.new()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	clip = args[0] if args.size() > 0 else "mine"
	var seed := int(args[1]) if args.size() > 1 else 2026
	I18n.set_language("en")  # English UI to match the English narration (the game ships both)
	SystemScreens.settings["language"] = "en"
	note("start", {"clip": clip, "seed": seed, "engine": Engine.get_version_info().string,
		"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method")),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"adapter": RenderingServer.get_video_adapter_name()})
	if clip == "title":
		await title()
	else:
		await boot(seed)
		match clip:
			"mine": await mine()
			"regions": await regions()
			"bridge": await bridge()
			"route": await route()
			"camp": await camp()
			"base": await base_tour()
	note("end")
	var f := FileAccess.open("user://%s-inputs.jsonl" % clip, FileAccess.WRITE)
	if f != null: f.store_string("\n".join(log_lines) + "\n")
	print("[pitch] log at ", ProjectSettings.globalize_path("user://%s-inputs.jsonl" % clip))
	if is_instance_valid(rig): rig.queue_free()
	await create_timer(0.3).timeout
	quit()

## B00 / B03 / B04: a mine floor fought by the driver, the route map on the way
## down, and the start of the next floor. No setup writes.
func mine() -> void:
	note("start_contract", {"region": "mine", "how": "GameManager.start_contract, what the dispatch console calls"})
	await game.start_contract("mine")
	await seconds(1.0)
	var first := game.floor_number
	await play(75.0, func(): return game.floor_number > first and not game.transitioning)
	note("floor_reached", {"floor": game.floor_number})
	await play(6.0)

## B02 / B06: a few seconds of play in each other region (city = 龙门, snow,
## Siracusa at night with rain). No setup writes.
func regions() -> void:
	for region in ["city", "snow", "siracusa"]:
		note("start_contract", {"region": region})
		await game.start_contract(region)
		await seconds(0.5)
		await play(12.0)
		note("settle_for_next_region", {"why": "ends the contract so the next region can start; not shown in the film"})
		game.settle(true)
		await seconds(1.0)

## B02: walking over a rock bridge, end a to end b of its deck. Setup: one
## teleport to end a (logged); enemies cleared so the walk is not interrupted.
func bridge() -> void:
	for map_seed in range(1001, 1040):
		game.fixed_map_seed = map_seed
		await game.start_contract("snow")
		var map := game.world_map
		if not map.bridges.is_empty() and map.bridges[0].has("centre"):
			var b: Dictionary = map.bridges[0]
			var c: Vector2 = b.centre
			var d: Vector2 = b.dir
			var a2: Vector2 = c - d * 8.0
			var b2: Vector2 = c + d * 8.0
			var top: float = b.top
			var start := map.nearest_walkable(Vector3(a2.x, top + 0.7, a2.y))
			var goal := map.nearest_walkable(Vector3(b2.x, top + 0.7, b2.y))
			game._clear_field()
			game.player.teleport(start)
			game.camera.global_position = game.player.global_position + game.camera_offset()
			note("setup_teleport", {"seed": map_seed, "to": [start.x, start.y, start.z], "goal": [goal.x, goal.y, goal.z], "why": "start at a bridge end; enemies cleared"})
			await seconds(1.0)
			var n := 0
			while n < int(12 * FPS) and game.player.global_position.distance_to(goal) > 1.0:
				driver._move_toward(game, game.player, goal)
				await frames(1)
				n += 1
			note("walk_done", {"at": [game.player.global_position.x, game.player.global_position.y, game.player.global_position.z]})
			await seconds(1.5)
			return
		game.settle(true)
	note("no_bridge_found")

## B04: the route map. Setup: one teleport next to the floor's descent marker
## (logged), standing in for clearing the floor. Then E at the marker, the
## route map held on screen, the driver's choice, and the next floor loading.
func route() -> void:
	await game.start_contract("mine")
	await seconds(1.0)
	var node: Node3D = game.world_map.route_nodes[0]
	var near := game.world_map.nearest_walkable(node.global_position + Vector3(3.0, 0, 3.0))
	game.player.teleport(near)
	game.camera.global_position = game.player.global_position + game.camera_offset()
	note("setup_teleport", {"to": [near.x, near.y, near.z], "why": "beside the descent marker, standing in for clearing the floor"})
	await seconds(1.0)
	var n := 0
	while n < int(10 * FPS) and game.player.global_position.distance_to(node.global_position) > 1.6:
		driver._move_toward(game, game.player, node.global_position)
		await frames(1)
		n += 1
	game.player.clear_move_target()
	await tap(KEY_E)
	await seconds(4.5)
	note("modal", {"modal": game.modal})
	if game.modal == "route":
		note("driver_choice", {"modal": "route", "call": "GameManager.advance(0)"})
		game.advance(0)
	await seconds(7.0)
	note("floor", {"floor": game.floor_number})

## B04: the camp at 10|11 and its fixed extraction, then the settlement.
## Setup: the camp is unlocked in memory, standing in for walking floors 1-10.
func camp() -> void:
	game.base.unlock_camp("mine", 10)
	note("setup_unlock_camp", {"region": "mine", "depth": 10, "why": "stands in for walking floors 1-10"})
	await game.start_contract("mine", 10)
	await seconds(2.0)
	var beacon: Vector3 = game.world_map.exit_node.global_position if is_instance_valid(game.world_map.exit_node) else game.player.global_position
	note("walk_to_extraction", {"to": [beacon.x, beacon.z]})
	var n := 0
	while n < int(25 * FPS) and game.player.global_position.distance_to(beacon) > 1.8:
		driver._move_toward(game, game.player, beacon)
		await frames(1)
		n += 1
	game.player.clear_move_target()
	await seconds(0.5)
	await tap(KEY_E)
	await seconds(2.0)
	if not game.in_base and game.in_camp:
		note("fallback_camp_extract", {"why": "E did not open the extraction; GameManager.camp_extract, what the beacon calls"})
		game.camp_extract()
	await seconds(9.0)

## B05: the base. Walk, then the exchange, the contract board and research.
## Setup: exchange and research facilities set built in memory (a fresh state
## has them unbuilt); screens opened through GameManager.open_station /
## open_exchange, which is what the station hotkey or E does.
func base_tour() -> void:
	await seconds(1.5)
	for id in ["dispatch", "workbench"]:
		var goal: Vector3 = game.base_map.station(id).position
		note("move_target", {"station": id})
		game.player.set_move_target(goal)
		var n := 0
		while n < int(15 * FPS) and Vector2(game.player.global_position.x - goal.x, game.player.global_position.z - goal.z).length() > 1.4:
			await frames(1)
			n += 1
		game.player.clear_move_target()
		await seconds(0.8)
	game.base.set_facility("exchange", 1)
	game.base.set_facility("research", 1)
	note("setup_facilities", {"built": ["exchange", "research"], "why": "fresh state has them unbuilt"})
	BaseScreens.dispatch_tab = 1
	note("open_station", {"id": "contracts", "tab": "board"})
	game.open_station("contracts")
	await seconds(4.0)
	game.close_modal()
	BaseScreens.dispatch_tab = 0
	note("open_exchange")
	game.open_exchange()
	await seconds(5.0)
	game.close_modal()
	note("open_station", {"id": "research"})
	game.open_station("research")
	await seconds(4.0)
	game.close_modal()
	await seconds(1.0)

## B09: the real launch path. The clone's config/name is changed, so its
## user:// (settings and save slots) is separate from the real game's.
## The main scene runs as the current scene, so the title shows, as in the exe.
func title() -> void:
	change_scene_to_file("res://game/main.tscn")
	await seconds(3.0)
	for pair in [["开始游戏", "Start"], ["新存档", "New save"]]:
		if find_button(root, pair[0]) != null: await click_button(pair[0])
		else: await click_button(pair[1])
		await seconds(1.5)
	await seconds(2.0)
	for t in ["确定", "OK"]:
		if find_button(root, t) != null:
			await click_button(t)
			await seconds(1.5)
			break
	await seconds(10.0)
	game = find_game(current_scene) if current_scene != null else null
	note("state", {"in_game": game != null, "in_base": game.in_base if game != null else false})
	await seconds(6.0)
