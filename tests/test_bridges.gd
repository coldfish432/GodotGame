extends SceneTree

## Rock bridges (用户 2026-10-13: 下面的路从上面的路下面穿过，形成有高度差的不连
## 在一起的回路). Sweeps snowfield seeds and checks every bridge built: the deck
## stands two tiers over the road it crosses, the navmesh carries a walk over
## the deck and a walk along the road beneath it, the two do not join where
## they cross, ground queries tell the deck from the road by the asker's
## height, and real bodies neither fall off the deck nor climb onto it.

## Daily runs sweep fewer floors; DOWNFALL_FULL=1 (run_all.ps1 -Full) the lot.
var SEEDS := 24 if OS.get_environment("DOWNFALL_FULL") == "1" else 12

var failures := 0

func _initialize() -> void: call_deferred("run")

func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame

func check(label: String, passed: bool) -> void:
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label)

func path_length(points: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, points.size()): total += points[i - 1].distance_to(points[i])
	return total

func run() -> void:
	var map := ContinuousWorldMap.new()
	root.add_child(map)
	var with_bridge := 0
	var built := 0
	var low_rise := 0
	var deck_nav := 0
	var under_nav := 0
	var over_walks := 0
	var under_walks := 0
	var joined := 0
	var layered := 0
	var falls := 0
	var climbs := 0
	var rays := 0
	var notes: Array[String] = []
	for i in range(SEEDS):
		map.region_id = "snow"
		var seed_value := (i + 1) * 7919
		map.generate(seed_value, 1)
		if map.bridges.is_empty(): continue
		with_bridge += 1
		var nav := map.navigation_map_rid()
		# The baked mesh reaches the server a few frames later.
		var probe: Dictionary = map.bridges[0]
		for frame in range(240):
			await step()
			var seen := NavigationServer3D.map_get_closest_point(nav, Vector3(probe.centre.x, float(probe.top) + 0.3, probe.centre.y))
			if seen != Vector3.ZERO: break
		for bridge in map.bridges:
			built += 1
			var top: float = bridge.top
			var base: float = bridge.base
			var centre: Vector2 = bridge.centre
			var axis: Vector2 = bridge.axis
			var across := axis.orthogonal()
			var tag := "seed %d bridge at (%.1f, %.1f) span %.1f" % [seed_value, centre.x, centre.y, float(bridge.span)]
			if top - base < 4.0:
				low_rise += 1
				notes.append(tag + " rise %.2f" % (top - base))
			# Ground queries by height.
			if is_equal_approx(map.ground_height(centre, top + 0.6), top) and absf(map.ground_height(centre, base + 0.6) - base) < 0.01: layered += 1
			else: notes.append(tag + " ground_height not layered")
			# The navmesh has a floor on the deck and one under it.
			var on_deck := NavigationServer3D.map_get_closest_point(nav, Vector3(centre.x, top + 0.3, centre.y))
			if absf(on_deck.y - top) < 0.6 and Vector2(on_deck.x, on_deck.z).distance_to(centre) < 1.0: deck_nav += 1
			else: notes.append(tag + " deck nav %s" % on_deck)
			var under := NavigationServer3D.map_get_closest_point(nav, Vector3(centre.x, base + 0.3, centre.y))
			if absf(under.y - base) < 0.6 and Vector2(under.x, under.z).distance_to(centre) < 1.5: under_nav += 1
			else: notes.append(tag + " under nav %s" % under)
			# Over: stub to stub across the deck, never dropping off it.
			var reach := float(bridge.span) * 0.5 + map.DECK_OVERLAP + 2.5
			var a3 := Vector3(centre.x - axis.x * reach, top + 0.3, centre.y - axis.y * reach)
			var b3 := Vector3(centre.x + axis.x * reach, top + 0.3, centre.y + axis.y * reach)
			var over := NavigationServer3D.map_get_path(nav, a3, b3, true)
			var lowest := INF
			for p in over: lowest = minf(lowest, p.y)
			if over.size() >= 2 and path_length(over) <= a3.distance_to(b3) * 1.3 + 1.0 and lowest > top - 0.5: over_walks += 1
			else: notes.append(tag + " over path %d pts %.1f m lowest %.2f" % [over.size(), path_length(over), lowest])
			# Under: along the lower corridor through the arch.
			var lower_dir: Vector2 = bridge.under
			var u0 := centre - lower_dir * 7.0
			var u1 := centre + lower_dir * 7.0
			var c3 := Vector3(u0.x, map.ground_height(u0) + 0.3, u0.y)
			var d3 := Vector3(u1.x, map.ground_height(u1) + 0.3, u1.y)
			var below := NavigationServer3D.map_get_path(nav, c3, d3, true)
			var highest := -INF
			for p in below: highest = maxf(highest, p.y)
			if below.size() >= 2 and path_length(below) <= c3.distance_to(d3) * 1.4 + 2.0 and highest < top - 2.0: under_walks += 1
			else: notes.append(tag + " under path %d pts %.1f m highest %.2f" % [below.size(), path_length(below), highest])
			# Where they cross they do not join: deck to road is the long way round.
			var down := NavigationServer3D.map_get_path(nav, Vector3(centre.x, top + 0.3, centre.y), Vector3(centre.x, base + 0.3, centre.y), true)
			if down.size() >= 2 and path_length(down) < 20.0:
				joined += 1
				notes.append(tag + " deck joins the road below in %.1f m" % path_length(down))
			# Rays: down onto the deck, up from the road into its underside.
			var space := map.get_world_3d().direct_space_state
			var hit_down := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(centre.x, top + 5.0, centre.y), Vector3(centre.x, base - 1.0, centre.y)))
			var hit_up := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(centre.x, base + 0.5, centre.y), Vector3(centre.x, top + 3.0, centre.y)))
			if not hit_down.is_empty() and absf(hit_down.position.y - top) < 0.05 and not hit_up.is_empty() and hit_up.position.y > base + 3.0: rays += 1
			else: notes.append(tag + " rays %s / %s" % [hit_down.get("position"), hit_up.get("position")])
			# A body walking sideways off the deck is held by its wall.
			var body := CharacterBody3D.new()
			var shape := CollisionShape3D.new()
			var capsule := CapsuleShape3D.new()
			capsule.radius = 0.35
			capsule.height = 1.4
			shape.shape = capsule
			shape.position.y = 0.7
			body.add_child(shape)
			map.add_child(body)
			body.global_position = Vector3(centre.x, top + 0.05, centre.y)
			for frame in range(60):
				body.velocity = Vector3(across.x, -2.0, across.y) * 4.0
				body.velocity.y = -2.0 if body.is_on_floor() else body.velocity.y - 0.5
				body.move_and_slide()
				await physics_frame
			if body.global_position.y < top - 0.3:
				falls += 1
				notes.append(tag + " body fell off to %.2f" % body.global_position.y)
			# One on the road walking at the cliff under the deck stays on the road.
			body.global_position = Vector3(centre.x, base + 0.05, centre.y)
			body.velocity = Vector3.ZERO
			for frame in range(60):
				body.velocity = Vector3(axis.x * 4.0, -2.0, axis.y * 4.0)
				body.move_and_slide()
				await physics_frame
			if body.global_position.y > base + 1.0:
				climbs += 1
				notes.append(tag + " body climbed to %.2f" % body.global_position.y)
			body.queue_free()
	for other in ["mine", "city"]:
		map.region_id = other
		map.generate(4421, 1)
		check("no bridges in the %s" % other, map.bridges.is_empty())
	for note in notes: print("  " + note)
	print("bridges: %d on %d/%d snow seeds" % [built, with_bridge, SEEDS])
	check("a bridge on at least a third of snowfield floors (%d/%d)" % [with_bridge, SEEDS], with_bridge * 3 >= SEEDS)
	check("every deck stands two tiers over the road it crosses", low_rise == 0)
	check("ground height tells the deck from the road by the asker's height", layered == built)
	check("the navmesh has a floor on every deck and under it", deck_nav == built and under_nav == built)
	check("every deck carries a walk from stub to stub", over_walks == built)
	check("the road under every deck stays walkable through the arch", under_walks == built)
	check("no deck joins the road below where they cross", joined == 0)
	check("rays land on the deck and stop at its underside", rays == built)
	check("no body walks off a deck's side", falls == 0)
	check("no body on the road climbs onto a deck", climbs == 0)
	print("BRIDGES RESULT: %d failures" % failures)
	quit(1 if failures > 0 else 0)
