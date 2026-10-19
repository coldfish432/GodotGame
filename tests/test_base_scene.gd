extends SceneTree

## Walkable Rhodes Island base: data loads, every station is reachable and
## opens its menu, contracts leave and return through the right spawn.

var game: GameManager
var failures := 0
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool) -> void:
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label)
func flat(v: Vector3) -> Vector2: return Vector2(v.x, v.z)

func run() -> void:
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	await step(8)
	var base := game.base_map
	check("all six rooms load (加工部 a room of its own)", base.rooms.size() == 6)
	check("twelve stations: the exported ones (no scan gate), the exchange, 人事部 and 加工站", base.interactables.size() == 12 and not base.station("exchange").is_empty()
		and not base.station("personnel").is_empty() and not base.station("workshop").is_empty())
	check("the departure cluster: 整备台 and 后勤柜台 either side of the lift, arrival at it (基地布局调研_v2)",
		flat(base.station("workbench").position).distance_to(flat(base.station("lift").position)) < 18.0
		and flat(base.station("logistics").position).distance_to(flat(base.station("lift").position)) < 18.0
		and flat(base.spawn_point("arrival")).distance_to(flat(base.station("lift").position)) < 4.0)
	check("boot spawns at the hall arrival point", flat(game.player.global_position).distance_to(flat(base.spawn_point("arrival"))) < 0.1)
	check("base is walkable, no menu", game.base_walk_active() and not game.menu.visible and not game.simulation_active())
	# 站点总览 (用户 2026-10-18): closed until its key opens it; the settings pick its stations.
	check("the station overview starts closed, its key is Tab", not BaseHud.panel_open() and Keybinds.short_label("toggle_stations") == "Tab")
	game.toggle_station_panel()
	SystemScreens.set_setting("station_hidden", ["exchange", "workshop"])
	var listed: Array = BaseHud.shown_stations().map(func(e): return e[1])
	check("its key opens it, listing only the stations kept (%d)" % listed.size(), BaseHud.panel_open() and listed.size() == BaseHud.STATIONS.size() - 2
		and not "exchange" in listed and "contracts" in listed)
	game.toggle_station_panel()
	SystemScreens.set_setting("station_hidden", [])
	check("and closes it again", not BaseHud.panel_open())

	var rid := base.navigation_map_rid()
	NavigationServer3D.map_force_update(rid)
	var start := game.player.global_position
	for station in base.interactables:
		var path := NavigationServer3D.map_get_path(rid, start, station.position, true)
		var reach := path.size() > 0 and flat(path[path.size() - 1]).distance_to(flat(station.position)) < BaseMap.INTERACT_RANGE - 0.5
		check("path from arrival reaches " + station.id, reach)
	var death_path := NavigationServer3D.map_get_path(rid, base.spawn_point("death"), base.station("reception").position, true)
	check("recovery bed connects to medical reception", death_path.size() > 0 and flat(death_path[death_path.size() - 1]).distance_to(flat(base.station("reception").position)) < 2.5)

	# Props are solid: every station sits on a collider. The dispatch spot is
	# the middle of the command ring (基地建模改造案_v1): she walks in from the
	# south, and walking on north stops at the ring's north console.
	var space := game.get_world_3d().direct_space_state
	for station in base.interactables:
		if station.id in ["lift", "outbound", "pharmacy", "exchange", "personnel", "dispatch", "workshop"]: continue  # walk-up spots (the terminals until their art), not props
		var query := PhysicsPointQueryParameters3D.new()
		query.position = Vector3(station.position.x, 1.0, station.position.z)
		query.collision_mask = 1
		check(station.id + " prop has a collider", not space.intersect_point(query).is_empty())
	var console: Vector3 = base.station("dispatch").position
	game.player.teleport(console + Vector3(1.6, 0, 0))  # beside the hologram's emitter
	await step(2)
	for i in range(60):
		game.player.velocity = Vector3(0, 0, 5)
		game.player.move_and_slide()
		await physics_frame
	check("walking north off the dais is blocked by its desk", game.player.global_position.z < console.z + BaseMap.RING_RADIUS - 1.0)
	game.player.teleport(base.spawn_point("arrival"))
	await step(2)

	# Every room is modelled (基地建模改造案_v1): no pixel floor, facade or prop
	# billboards anywhere (markers and the carried icon draw over everything).
	var billboards := 0
	for id in base.rooms:
		billboards += base.get_node(id).find_children("*", "Sprite3D", true, false).filter(func(s): return not s.no_depth_test and s.name != "Closure").size()
	var kit_rooms: Array = base.rooms.keys().filter(func(id): return base.get_node(id).get_children().any(func(c): return str(c.get_meta("model", "")).begins_with("wall_panel")))
	check("all six rooms are modelled, no pixel billboards left (%d)" % billboards, kit_rooms.size() == 6 and billboards == 0)
	var hall := base.get_node("hall")
	var models := {}
	for c in hall.get_children(): if c.has_meta("model"): models[c.get_meta("model")] = int(models.get(c.get_meta("model"), 0)) + 1
	check("the hall is modelled: walls, the bridge, the lift gate, the dais, the exchange floor, the 整备台 and the lounge", int(models.get("wall_panel", 0)) > 20 and models.get("bridge_wall") == 1
		and models.get("lift_gate") == 1 and models.get("command_dais") == 1
		and models.get("holo_screen_frame") == 1 and models.get("trading_post") == 1 and int(models.get("trader_desk", 0)) >= 4
		and models.get("armory_bench") == 1 and int(models.get("sofa", 0)) >= 4
		and hall.get_node_or_null("MarketHologram") != null and hall.get_node_or_null("QuoteRing") != null
		and hall.find_children("*", "Sprite3D", false, false).filter(func(s): return not s.no_depth_test).is_empty())
	if models.get("command_dais") != 1: print("   models: ", models)
	# 不要虚化，直接遮挡 (用户 2026-10-18): walls stay whole and simply hide her.
	check("no checkerboard cut and no silhouette: kit pieces have no player hole", base._see_through_kit.all(func(m): return not m.shader.code.contains("player_center"))
		and base.find_children("*", "", true, false).all(func(n): return not str(n.name).contains("Silhouette")))
	# The sand table (基地建模改造案_v1 §八): Terra as a hologram, the ship over
	# where Rhodes Island is; it sails to the region a contract is run in.
	check("the hall's sand table shows Terra and the ship", models.get("holo_table") == 1 and hall.get_node_or_null("HoloTerra") != null and base.ship_marker != null)
	check("the sand table models the sea and divides the regions", hall.get_node_or_null("HoloOcean") != null and hall.get_node("HoloOcean").multimesh.instance_count > 0 and hall.get_node_or_null("HoloBorders") != null and hall.get_node("HoloBorders").multimesh.instance_count > 0 and hall.get_node_or_null("HoloWildBorders") != null)
	var at_lungmen := base.ship_marker.position
	base.set_ship_at("萨米")
	check("the ship marker moves to the north-west for Sami", base.ship_place == "萨米" and base.ship_marker.position.z > at_lungmen.z and base.ship_marker.position.x > at_lungmen.x)
	check("a contract's region sets where the ship is", TerraMap.place_for_region("snow") == "萨米" and TerraMap.place_for_region("mine") == "切尔诺伯格" and TerraMap.place_for_region("siracusa") == "叙拉古")
	base.set_ship_at(game.base.ship_at)
	check("the hall has its own light", base.light != null and base.light.light_at(Vector2(base.to_world(64, -24).x, base.to_world(64, -24).z)).r > 0.8)

	# Actually walk: a move order through the base navigation moves the body.
	var before := game.player.global_position
	game.player.set_move_target(before + Vector3(0, 0, 6))
	await step(40)
	check("move order walks in the base", game.player.global_position.distance_to(before) > 2.0)
	game.player.clear_move_target()

	# Really walk there through the doors, colliders included (no teleport).
	for id in ["store", "reception"]:
		game.player.teleport(base.spawn_point("arrival"))
		await step(2)
		var goal: Vector3 = base.station(id).position
		game.player.set_move_target(goal)
		var frames := 0
		while frames < 2400 and flat(game.player.global_position).distance_to(flat(goal)) > BaseMap.INTERACT_RANGE - 0.2:
			await physics_frame
			frames += 1
		check("Lappland walks from arrival to " + id + " (%.1fs)" % (frames / 60.0), game.nearby_station().get("id", "") == id)
		game.player.clear_move_target()

	for kind_station in [["stash", "仓管台"], ["workbench", "整备台"], ["reception", "医疗部"], ["logistics", "后勤柜台"], ["store", "可露希尔的商店"]]:
		var station := base.station(kind_station[0])
		game.player.teleport(station.position)
		await step(1)
		check(kind_station[0] + " is the nearby station", game.nearby_station().get("id", "") == kind_station[0])
		game._base_interact()
		check(kind_station[0] + " opens its station menu", game.modal == "station" and game.menu.visible and _has_label(game.menu, kind_station[1]))
		check("station menu blocks base walking", not game.base_walk_active())
		game.close_modal()
		await step(1)
	game.player.teleport(base.to_world(30.0, -26.0, BaseMap.PLAYER_Y))  # on the main street
	await step(1)
	game._base_interact()
	check("E away from stations opens nothing", game.modal.is_empty())

	# Walking into the warehouse: lights clunk on bank by bank from the door with
	# pauses, each lit bank opens its hatches, and shelves rise slowly once on screen.
	var reveal := base.warehouse_reveal
	var shelves: Array[MeshInstance3D] = []
	for name in base.room_visuals.warehouse.racks:
		# Built racks only: slot 0 of each zone at the start (B5 adds the other eight slots, hidden until built).
		if str(name).ends_with(":0"): shelves.append(base.room_visuals.warehouse.racks[name].node)
	var built := reveal.built_shelves()
	var idx: Array = built.map(func(s): return reveal._shelves.find(s))  # signal indices of the built racks
	check("36 rack slots, each a rack model with a hatch and two leaves; four built, twelve cells on each front rack",
		reveal._shelves.size() == 36 and built.size() == 4 and shelves.size() == 4 and RoomReveal.HATCH_FRAMES == 6
		and reveal._shelves.all(func(s): return s.hatch_mesh != null and s.rack.leaves.size() == 2)
		and built.all(func(s): return s.rack.cells.size() == 12))
	check("built shelves sit in the two far banks", built.map(func(s): return s.bank) == [2, 2, 3, 3])
	var floor_light: ShaderMaterial = base.room_visuals.warehouse.shaders[0]
	var events := []
	reveal.bank_lit.connect(func(k): events.append("bank%d" % k))
	reveal.hatch_opening.connect(func(i): events.append("hatch%d" % i))
	reveal.shelf_rising.connect(func(i): events.append("rise%d" % i))
	game.player.teleport(base.spawn_point("arrival"))
	await step(2)
	var idle: Vector4 = floor_light.get_shader_parameter("band_levels")
	check("warehouse is dim (not black), hatches shut and shelves stowed while Lappland is in the hall",
		reveal.lit_banks() == 0 and idle.is_equal_approx(Vector4.ONE * RoomReveal.IDLE) and RoomReveal.IDLE >= 0.3
		and shelves.all(func(s): return not s.visible) and built.all(func(s): return s.frame == 0))
	game.player.teleport(base.station("stash").position)  # just inside the east door
	var lit_steps := []
	var frames := 0
	while frames < 900 and reveal.t < reveal.lights_time:
		await process_frame
		frames += 1
		if lit_steps.is_empty() or lit_steps.back()[0] != reveal.lit_banks(): lit_steps.append([reveal.lit_banks(), reveal.t])
	var counts := lit_steps.map(func(e): return e[0])
	var one: Array = reveal.bank_levels(1)
	check("after the first bank, the rest are not dark: they catch its light, less with distance: %s" % [one],
		one[0] == 1.0 and one[1] > one[2] and one[2] > one[3] and one[3] > RoomReveal.IDLE)
	var brighter := true
	for n in range(1, 5):
		for k in range(4): brighter = brighter and reveal.bank_levels(n)[k] >= reveal.bank_levels(n - 1)[k]
	check("each bank brightens the whole room a step, never darkens any part", brighter)
	check("banks light one after another with a flicker each: %s" % [counts], counts.filter(func(c): return c > 0).max() == 4 and _flickers(counts) == 4)
	var gaps := []
	for k in range(1, 4): gaps.append(reveal.bank_time(k) - reveal.bank_time(k - 1))
	check("a pause between banks (%.2fs), all lit in %.2fs" % [RoomReveal.BANK_PAUSE, reveal.lights_time], gaps.all(func(g): return g >= 0.4) and reveal.lights_time >= 1.3)
	check("each bank announces itself once, in order: %s" % [events], events.filter(func(e): return e.begins_with("bank")) == ["bank0", "bank1", "bank2", "bank3"])
	await step(60)
	check("hatches open once their bank is lit, even off screen", built.all(func(s): return s.frame == 5))
	check("shelves wait while they are off screen from the door", shelves.all(func(s): return not s.visible))
	game.player.teleport(base.to_world(-40.0, -30.0, BaseMap.PLAYER_Y))
	await step(4)
	check("shelves start rising as they come into view, nearest the door first", events.has("rise%d" % idx[0]))
	check("the far bank waits", not events.has("rise%d" % idx[2]) and not events.has("rise%d" % idx[3]))
	game.player.teleport(base.to_world(-50.0, -30.0, BaseMap.PLAYER_Y))
	frames = 0
	while frames < 900 and not reveal.settled():
		await process_frame
		frames += 1
	check("all shelves up once the far end is on screen", reveal.settled())
	check("a shelf takes %.1fs to rise, slow start and stop" % RoomReveal.SHELF_RISE, RoomReveal.SHELF_RISE >= 1.0)
	check("shelves start in order, nearest the door first", events.find("rise%d" % idx[0]) < events.find("rise%d" % idx[1]) and events.find("rise%d" % idx[2]) < events.find("rise%d" % idx[3]))
	var whole := shelves.all(func(s): return s.visible and is_zero_approx(s.position.y))
	var leaves_up := built.all(func(s): return s.rack.leaves.all(func(l): return l.transform.basis.y.dot(Vector3.UP) < 0.2))
	check("every shelf ends standing on the deck, its hatch leaves stood up", whole and leaves_up)
	check("props are lit fully at the end", base.room_visuals.warehouse.sprites.all(func(s): return s.modulate == Color(1, 1, 1)))
	game.player.teleport(base.spawn_point("arrival"))
	frames = 0
	while frames < 900 and not reveal.stowed():
		await process_frame
		frames += 1
	check("leaving stows the shelves, shuts the hatches and darkens the warehouse again",
		reveal.lit_banks() == 0 and shelves.all(func(s): return not s.visible) and built.all(func(s): return s.frame == 0))

	game.open_station("contracts")
	await game.start_contract("mine")
	check("contract hides and disables the base", not game.in_base and not base.visible and not base._navigation.enabled)
	check("contract starts at the field entry", flat(game.player.global_position).distance_to(flat(ContinuousWorldMap.ENTRY_POSITION)) < 1.0)
	game.settle(true)
	await step(2)
	check("extraction returns to the hall arrival", game.in_base and base.visible and flat(game.player.global_position).distance_to(flat(base.spawn_point("arrival"))) < 0.1)
	await game.start_contract("city")
	game.player.hp = 0
	await step(2)
	check("death returns to the medical recovery bed", game.in_base and flat(game.player.global_position).distance_to(flat(base.spawn_point("death"))) < 0.1)
	game.open_station("report")
	check("medical report lists the recovery", _has_label(game.menu, "回收明细"))
	game.close_modal()
	var south := base.to_world(30.0, -54.0, BaseMap.PLAYER_Y)
	game.player.teleport(south)
	check("camera stays inside the hall near its south edge", game.camera_target().z > south.z + 5.0)
	# A dash in the hall leaves afterimages that fade, not ghosts that stay
	# (用户 2026-10-07).
	game.player.stamina = 100
	game.player._dash_cooldown = 0
	Input.action_press("dash")
	await physics_frame
	await physics_frame
	Input.action_release("dash")
	var ghosts := func(): return game.get_children().filter(func(n): return n is CombatVfx and n.kind == "ghost").size()
	var made: int = ghosts.call()
	for i in range(60): await process_frame
	check("dash afterimages in the base fade (%d made)" % made, made > 0 and ghosts.call() == 0)
	print("BASE SCENE FAILURES: %d" % failures)
	quit(1 if failures else 0)

## Counts banks that went on, off for the flicker, and on again: ..., k-1, k, k-1, k, ...
func _flickers(counts: Array) -> int:
	var n := 0
	for i in range(2, counts.size()):
		if counts[i] == counts[i - 2] and counts[i - 1] == counts[i] - 1: n += 1
	return n

func _ascending(a: Array) -> bool:
	for i in range(1, a.size()):
		if a[i] <= a[i - 1]: return false
	return true

func _close(a: Array, b: Array) -> bool:
	if a.size() != b.size(): return false
	for i in range(a.size()):
		if absf(a[i] - b[i]) > 0.005: return false
	return true

func _has_label(node: Node, text: String) -> bool:
	if node is Label and node.text == text: return true
	for child in node.get_children():
		if _has_label(child, text): return true
	return false
