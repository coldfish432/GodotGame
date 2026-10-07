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
	check("all five rooms load", base.rooms.size() == 5)
	check("ten stations exported", base.interactables.size() == 10)
	check("boot spawns at the hall arrival point", flat(game.player.global_position).distance_to(flat(base.spawn_point("arrival"))) < 0.1)
	check("base is walkable, no menu", game.base_walk_active() and not game.menu.visible and not game.simulation_active())

	var rid := base.navigation_map_rid()
	NavigationServer3D.map_force_update(rid)
	var start := game.player.global_position
	for station in base.interactables:
		var path := NavigationServer3D.map_get_path(rid, start, station.position, true)
		var reach := path.size() > 0 and flat(path[path.size() - 1]).distance_to(flat(station.position)) < BaseMap.INTERACT_RANGE - 0.5
		check("path from arrival reaches " + station.id, reach)
	var death_path := NavigationServer3D.map_get_path(rid, base.spawn_point("death"), base.station("reception").position, true)
	check("recovery bed connects to medical reception", death_path.size() > 0 and flat(death_path[death_path.size() - 1]).distance_to(flat(base.station("reception").position)) < 2.5)

	# Props are solid: every station sits on a collider, and walking into the
	# dispatch console from the south stops at its front edge.
	var space := game.get_world_3d().direct_space_state
	for station in base.interactables:
		if station.id in ["lift", "outbound", "pharmacy", "decon"]: continue  # walk-up spots, not props
		var query := PhysicsPointQueryParameters3D.new()
		query.position = Vector3(station.position.x, 1.0, station.position.z)
		query.collision_mask = 1
		check(station.id + " prop has a collider", not space.intersect_point(query).is_empty())
	var console: Vector3 = base.station("dispatch").position
	game.player.teleport(console + Vector3(0, 0, -3.5))
	await step(2)
	for i in range(60):
		game.player.velocity = Vector3(0, 0, 5)
		game.player.move_and_slide()
		await physics_frame
	check("walking into the console is blocked", game.player.global_position.z < console.z - 0.5)
	game.player.teleport(base.spawn_point("arrival"))
	await step(2)

	# North walls and the overhead layer turn see-through around Lappland.
	var overhead := 0
	for room in base.rooms.values():
		for s in room.sprites: if s.overhead: overhead += 1
	check("every facade and overhead item uses the see-through shader", base._see_through.size() == base.rooms.size() + overhead)
	game.player.teleport(base.to_world(7.47, 1.6, BaseMap.PLAYER_Y))  # inside the store doorway, behind the hall wall
	await step(2)
	var hall_wall: ShaderMaterial = base._see_through[0]
	var center: Vector3 = hall_wall.get_shader_parameter("player_center")
	check("hall wall cuts a hole while Lappland is behind it", center.distance_to(game.player.global_position + Vector3(0, 0.31, 0)) < 0.01 and center.z > hall_wall.get_shader_parameter("occludes_north_of"))
	game.player.teleport(base.spawn_point("arrival"))
	await step(2)
	check("hall wall is solid while she is in the hall", hall_wall.get_shader_parameter("player_center").z < hall_wall.get_shader_parameter("occludes_north_of"))

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
	game.player.teleport(base.spawn_point("arrival"))
	await step(1)
	game._base_interact()
	check("E away from stations opens nothing", game.modal.is_empty())

	# Walking into the warehouse: lights clunk on bank by bank from the door with
	# pauses, each lit bank opens its hatches, and shelves rise slowly once on screen.
	var reveal := base.warehouse_reveal
	var shelves: Array[Sprite3D] = []
	for name in base.room_visuals.warehouse.groups:
		# Built racks only: slot 0 of each zone at the start (B5 adds the other eight slots, hidden until built).
		if str(name).begins_with("shelf:") and str(name).ends_with(":0"): shelves.append_array(base.room_visuals.warehouse.groups[name])
	var hatches: Array = reveal._shelves.map(func(s): return s.hatch)
	var built := reveal.built_shelves()
	var idx: Array = built.map(func(s): return reveal._shelves.find(s))  # signal indices of the built racks
	check("36 rack slots with a hatch each; four built, twelve sprites", reveal._shelves.size() == 36 and built.size() == 4 and shelves.size() == 12
		and hatches.all(func(h): return h != null) and reveal.hatch_frames.size() == 6)
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
	var whole := shelves.all(func(s): return s.visible and s.region_rect.size == s.texture.get_size() 		and is_equal_approx(s.offset.y, s.texture.get_height() * 0.5 + s.get_meta("lift_px") - BaseMap.PIVOT_SCREEN_PX))
	check("every shelf ends standing exactly where the assembly put it", whole)
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
	game.player.teleport(base.spawn_point("arrival"))
	check("camera stays inside the hall near its south edge", game.camera_target().z > base.spawn_point("arrival").z + 5.0)
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
