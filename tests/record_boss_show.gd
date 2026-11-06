extends SceneTree

## Not a test — a real-time clip of one boss's set pieces (Boss演出策划案_v0_2):
## the first intro, each phase change, a few ordinary blows (the body's motion),
## the fall; then, on a fresh meeting, the short intro and her fall. Prints
## "MARK <frame> <label>" so stills can be cut at the right frames.
## Pick the boss with BOSS_REC=<region>:<floor>, e.g. mine:60. Run with Movie Maker:
##   set BOSS_REC=mine:60
##   godot --path downfall-godot --script res://tests/record_boss_show.gd
##        --audio-driver Dummy --resolution 1280x720 --fixed-fps 30
##        --write-movie <dir>/frame.png

var rig: Node
var game: GameManager

func _initialize() -> void: call_deferred("run")

func step(count: int = 1) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func mark(label: String) -> void:
	print("MARK %d %s" % [Engine.get_frames_drawn(), label])

func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null

func near(at: Vector3, reach: float) -> Vector3:
	for i in range(8):
		var want := at + Vector3(cos(TAU * i / 8.0), 0, sin(TAU * i / 8.0)) * reach
		var got := game.world_map.nearest_walkable(want)
		if Vector2(got.x - want.x, got.z - want.z).length() < 1.0 and absf(got.y - at.y) < 1.0: return got
	return game.world_map.nearest_walkable(at + Vector3(reach, 0, 0))

## Frames until `cond` or `cap`.
func until(cond: Callable, cap: int) -> void:
	for i in range(cap):
		if cond.call(): return
		await step(1)

func run() -> void:
	var spec := OS.get_environment("BOSS_REC").split(":")
	var region := spec[0] if spec.size() > 0 and spec[0] != "" else "mine"
	var floor := int(spec[1]) if spec.size() > 1 else 60
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(10)
	game = find_game(rig)
	game.fixed_map_seed = 1729
	await game.start_contract(region)
	game.floor_number = floor - 1
	await game.advance(0)
	await step(6)
	game.base.boss_intro_seen.clear()
	var player := game.player
	var figure: Boss = game.outpost_boss
	game.camera.size = 24
	# She stands at the edge, looking in; then walks in.
	var edge := game.arena.centre + (player.global_position - game.arena.centre).normalized() * (BossCatalog.ARENA_RADIUS + 3.0)
	player.teleport(game.world_map.nearest_walkable(edge) + Vector3.UP * 0.7)
	await step(30)
	mark("before")
	player.invulnerable = true
	player.teleport(near(figure.global_position, 6.0) + Vector3.UP * 0.7)
	await step(2)
	mark("intro_start")
	await until(func(): return is_instance_valid(game.boss_show) and game.boss_show.playing == "", 200)
	mark("intro_end")
	# A few blows: the squash of the wind-up, the lunge, the steps.
	await step(150)
	mark("blows")
	for share in BossCatalog.phase_marks(figure.tier) if figure.lives == 1 else [0.0]:
		if not is_instance_valid(figure) or figure._dead: break
		player.teleport(near(figure.global_position, 4.0) + Vector3.UP * 0.7)
		if figure.lives > 1:
			figure.take_hit(figure.max_health * 5.0, "true")
			mark("rebirth")
		else:
			figure.health = figure.max_health * (float(share) + 0.005)
			figure.take_hit(figure.max_health * 0.02, "true")
			mark("phase_%d" % figure.phase)
		await step(110)
	await step(60)
	mark("fall")
	figure.take_hit(figure.max_health * 50.0, "true")
	await until(func(): return game.outpost_cleared, 300)
	mark("fall_done")
	await step(70)
	rig.queue_free()
	await create_timer(0.3).timeout
	quit()
