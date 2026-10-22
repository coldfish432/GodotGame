extends SceneTree
## The turnable, zoomable follow camera (用户 2026-10-20, after Grim Dawn): the
## wheel zooms within its limits, the turn keys go 45° a press, reset takes the
## short way back; clicks land where the pointer is at any turn and zoom, and
## a figure keeps its world facing while the view turns round it.
var game: GameManager
var failures := 0
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool, detail: Variant = null) -> void:
	print(("PASS " if passed else "FAIL ") + label + ("" if detail == null else " " + str(detail)))
	if not passed: failures += 1

## Let the eased yaw and size arrive.
func settle(yaw: float, size: float) -> void:
	game.camera_yaw_goal = yaw
	game.camera_size_goal = size
	await step(90)

## A ground point a few metres from her, clicked through the camera, comes back.
func pick_error(offset: Vector2) -> float:
	var p := game.player.global_position
	var at := Vector3(p.x + offset.x, 0.0, p.z + offset.y)
	at.y = game.ground_y(Vector3(at.x, p.y, at.z))
	game._pointer_position = game.camera.unproject_position(at)
	game._has_pointer_position = true
	var hit := game._get_pointer_ground()
	return Vector2(hit.x - at.x, hit.z - at.z).length()

func sweep(where: String) -> void:
	for turn in [0.0, PI / 4.0, PI / 2.0, PI, -PI * 0.75]:
		for size in [GameManager.CAMERA_SIZE_MIN, GameManager.CAMERA_SIZE, GameManager.CAMERA_SIZE_MAX]:
			# Each zoom at another tilt: low, the art's own, steep.
			var pitch: float = [GameManager.CAMERA_PITCH_MIN, GameManager.CAMERA_PITCH, GameManager.CAMERA_PITCH_MAX][[GameManager.CAMERA_SIZE_MIN, GameManager.CAMERA_SIZE, GameManager.CAMERA_SIZE_MAX].find(size)]
			game.camera_pitch_goal = pitch
			await settle(turn, size)
			var forward := -game.camera.global_basis.z
			var flat := Vector2(forward.x, forward.z).normalized()
			var label := "%s %d° size %d tilt %d°" % [where, roundi(rad_to_deg(turn)), size, roundi(rad_to_deg(pitch))]
			check(label + ": looks the turned way at its tilt", flat.distance_to(Vector2(sin(turn), cos(turn))) < 0.01 and absf(forward.y + sin(pitch)) < 0.01, {"flat": flat, "y": forward.y})
			check(label + ": zoomed to its size", absf(game.camera.size - size) < 0.01, game.camera.size)
			var worst := 0.0
			for offset in [Vector2(2.5, 0), Vector2(0, 2.5), Vector2(-2, -2), Vector2(1.5, -2.5)]:
				worst = maxf(worst, pick_error(offset))
			check(label + ": a click lands where the pointer is", worst < 0.25, worst)

func run() -> void:
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 2026
	root.add_child(game)
	await step(10)
	for id in ["camera_zoom_in", "camera_zoom_out", "camera_turn_left", "camera_turn_right", "camera_tilt_up", "camera_tilt_down", "camera_drag", "camera_reset"]:
		check("rebindable: " + id, InputMap.has_action(id) and not Keybinds.info(id).is_empty())
	check("the wheel zooms by default", Keybinds.short_label("camera_zoom_in") == "滚轮上" and Keybinds.short_label("camera_zoom_out") == "滚轮下")

	# Zoom stops at its limits.
	for i in range(20): game.zoom_camera(1)
	check("zoom out stops at the far limit", game.camera_size_goal == GameManager.CAMERA_SIZE_MAX)
	for i in range(20): game.zoom_camera(-1)
	check("zoom in stops at the near limit", game.camera_size_goal == GameManager.CAMERA_SIZE_MIN)
	# Turns go to the 45° marks; reset takes the short way.
	game.camera_yaw_goal = 0.3
	game.turn_camera(1)
	check("a turn key goes on to the next 45° mark", is_equal_approx(game.camera_yaw_goal, PI / 4.0), game.camera_yaw_goal)
	game.turn_camera(1)
	game.turn_camera(-1)
	game.turn_camera(-1)
	check("from a mark it goes a whole 45° either way", is_equal_approx(game.camera_yaw_goal, 0.0), game.camera_yaw_goal)
	game.camera_yaw_goal = 0.0
	for i in range(7): game.turn_camera(-1)
	await step(90)
	game.reset_camera_view()
	check("reset turns the short way back (45°, not 315°)", absf(game.camera_yaw_goal - game.camera_yaw + PI / 4.0) < 0.001, [game.camera_yaw, game.camera_yaw_goal])
	await step(90)
	check("reset is back at the default view and size", absf(wrapf(game.camera_yaw, -PI, PI)) < 0.001 and game.camera.size == GameManager.CAMERA_SIZE)
	# The tilt stops at 50° and 70°; reset brings back 58°.
	for i in range(10): game.tilt_camera(GameManager.CAMERA_TILT_STEP)
	check("tilting up stops at 70°", is_equal_approx(game.camera_pitch_goal, GameManager.CAMERA_PITCH_MAX))
	for i in range(10): game.tilt_camera(-GameManager.CAMERA_TILT_STEP)
	check("tilting down stops at 50°", is_equal_approx(game.camera_pitch_goal, GameManager.CAMERA_PITCH_MIN))
	await step(90)
	# Her feet stay where they were on screen: the image moved by the tilt's difference.
	var feet_sprite: LapplandAnimator3D = game.player._sprite
	var shift: float = feet_sprite.get_meta("upright_shift", 0.0)
	var expected: float = float(feet_sprite.get_meta("upright_height", 0.0)) * (cos(GameManager.CAMERA_PITCH) - cos(GameManager.CAMERA_PITCH_MIN)) / feet_sprite.pixel_size
	check("at 50° her image is moved down onto her feet", shift < -1.0 and is_equal_approx(shift, expected), [shift, expected])
	game.reset_camera_view()
	await step(90)
	check("reset brings back the 58° tilt and the image where it was drawn", is_equal_approx(game.camera_pitch, GameManager.CAMERA_PITCH) and absf(float(feet_sprite.get_meta("upright_shift", 0.0))) < 0.001)
	game.camera_yaw_goal = 0.0
	game.camera_yaw = 0.0

	# Facing keeps to the world while the view turns.
	var sprite: LapplandAnimator3D = game.player._sprite
	sprite._face_toward(Vector3.LEFT)
	var east_row := sprite._facing_index
	await settle(PI / 2.0, GameManager.CAMERA_SIZE)
	var turned := sprite._facing_index
	check("turned a quarter, she faces the same world way two rows on", posmod(turned - east_row, 8) in [2, 6] and turned == posmod(roundi(sprite._screen_angle(Vector3.LEFT) / (PI / 4.0)), 8), [east_row, turned])
	await settle(PI / 2.0 + 0.2, GameManager.CAMERA_SIZE)
	check("a small drag keeps the row", sprite._facing_index == turned)
	await settle(0.0, GameManager.CAMERA_SIZE)
	check("turned back, the first row again", sprite._facing_index == east_row)

	await sweep("base")
	game.camera_pitch_goal = GameManager.CAMERA_PITCH
	await settle(0.0, GameManager.CAMERA_SIZE)
	await game.start_contract("city")
	await step(10)
	await sweep("city")
	# An enemy standing still turns on screen with the view, not in the world.
	game.camera_pitch_goal = GameManager.CAMERA_PITCH
	await settle(0.0, GameManager.CAMERA_SIZE)
	var enemy := game._spawn_enemy(game.player.global_position + Vector3(4, 0, 0), false, false)
	await step(2)
	enemy.set_physics_process(false)
	enemy.global_basis = Basis.looking_at(Vector3.LEFT)
	enemy._seen_yaw = -1.0
	enemy._advance_animation(0.0)
	var before: Variant = enemy.dir_column if enemy.directional else enemy._sprite.flip_h
	await settle(PI / 2.0 if enemy.directional else PI, GameManager.CAMERA_SIZE)
	enemy._advance_animation(0.0)
	var after: Variant = enemy.dir_column if enemy.directional else enemy._sprite.flip_h
	check("a standing enemy shows its world facing from the turned view", before != after, [enemy.enemy_type, enemy.directional, before, after])
	enemy.queue_free()
	await settle(0.0, GameManager.CAMERA_SIZE)
	game.settle(true)
	await step(3)
	print("FAILURES %d" % failures)
	game.queue_free()
	await step(2)
	quit(1 if failures > 0 else 0)
