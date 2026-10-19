extends SceneTree

## The crew walking the base (BaseCrew, art/characters/crew/CR_brief_v1.md).
## Sol's CR1/CR2 sheets are in (2026-10-18), so the crew themselves walk.
## Shots in evidence/rhodes-engine/.

var failures := 0
var game: GameManager
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool) -> void:
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label)
func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null

func run() -> void:
	var missing := BaseCrew.CREW.filter(func(id): return LapplandAnimator3D.sheet(id, "walk") == null)
	check("the crew are known to the animator", BaseCrew.CREW.all(func(id): return id in LapplandAnimator3D.CREW))
	check("only crew with sheets walk", BaseCrew.pool().size() == BaseCrew.CREW.size() - missing.size())
	check("all 15 crew and the Doctor have their sheets", missing.is_empty() and LapplandAnimator3D.has_sheets("doctor"))
	var rig: Node = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(20)
	game = find_game(rig)
	var crew: BaseCrew = game.base_map.crew
	for i in range(30):
		if not crew.walkers.is_empty(): break
		await step(5)
	check("seven of the crew spawn", crew.walkers.size() == BaseCrew.COUNT)
	var start := crew.walkers.map(func(w): return (w.body as Node3D).global_position)
	var moved := 0
	var walked := false
	for t in range(20):
		await create_timer(1.0).timeout
		for w in crew.walkers:
			var sprite := (w.body as Node).get_child(0) as AnimatedSprite3D
			if str(sprite.animation).begins_with("walk_") and sprite.is_playing(): walked = true
	var off := 0
	for i in range(crew.walkers.size()):
		var at: Vector3 = (crew.walkers[i].body as Node3D).global_position
		if at.distance_to(start[i]) > 2.0: moved += 1
		var on := NavigationServer3D.map_get_closest_point(game.base_map.navigation_map_rid(), at)
		if Vector2(on.x - at.x, on.z - at.z).length() > 0.3:
			off += 1
	check("they walk somewhere in 20 s (%d of %d moved)" % [moved, crew.walkers.size()], moved >= 4)
	check("the walk cycle plays", walked)
	check("every one is on the nav mesh", off == 0)
	# A look at the hall with them in it.
	var w: Node3D = crew.walkers[0].body
	game.player.teleport(w.global_position + Vector3(2, 0, 2))
	game.camera.global_position = game.camera_target() + GameManager.CAMERA_OFFSET
	await step(12)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/rhodes-engine/base-crew.png")
	# Walking the base as the Doctor (基地形象).
	SystemScreens.settings.base_look = "doctor"
	game.refresh_look()
	await step(5)
	check("the Doctor walks the base when picked", game.base_look() == "doctor")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/rhodes-engine/base-doctor.png")
	SystemScreens.settings.base_look = ""
	print("BASE CREW FAILURES: %d" % failures)
	quit(1 if failures else 0)
