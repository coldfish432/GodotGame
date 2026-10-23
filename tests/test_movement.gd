extends SceneTree

## Movement: right-click's set_move_target()/arrival, and the pointer-glue
## helpers GameManager derives right-click "move here" and left-click
## "target/attack" from. Actual mouse-driven picking is smoke-tested only —
## headless mode has no real viewport geometry for a ray to click through.

const Game = preload("res://game/game_manager.gd")

var game: Node3D
var results: Array[Dictionary] = []
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame

func check(id: String, passed: bool, observation: Dictionary) -> void:
	results.append({"id": id, "status": "PASS" if passed else "FAIL", "observed": observation})
	if not passed:
		failures += 1
	print(JSON.stringify(results.back()))

func run() -> void:
	game = Game.new()
	game.start_at_base = false
	game.save_enabled = false
	root.add_child(game)
	await step(6)

	check("boot", is_instance_valid(game.player) and game.floor_number == 1 and game.player.hp == CombatStats.BASE.hp,
		{"floor": game.floor_number, "hp": game.player.hp})

	# --- set_move_target: the real right-click destination.
	var start_pos: Vector3 = game.player.global_position
	game.player.set_move_target(start_pos + Vector3(6.0, 0.0, 0.0))
	await step(40)
	var moved_distance: float = game.player.global_position.distance_to(start_pos)
	check("move-to-target-works", moved_distance > 2.0, {"moved": moved_distance})

	await step(60)  # let it arrive (6 units at 5 units/s well within this window)
	var settled_distance: float = game.player.global_position.distance_to(start_pos + Vector3(6.0, 0.0, 0.0))
	check("move-to-target-arrives-and-stops", settled_distance < 0.3, {"distance_to_target": settled_distance})

	# --- Pointer glue: smoke-test only, headless has no real click geometry.
	var ground: Vector3 = game._get_pointer_ground()
	var pointed: Enemy = game._get_enemy_under_pointer()
	check("pointer-helpers-dont-crash", ground is Vector3, {"ground": str(ground), "pointed_enemy_found": is_instance_valid(pointed)})

	# --- Dash: instant impulse + stamina cost, independent of any move target.
	game.player.teleport(ContinuousWorldMap.ENTRY_POSITION)
	var stamina_before: float = game.player.stamina
	var pos_before_dash: Vector3 = game.player.global_position
	game.player.set_move_target(game.player.global_position + Vector3(5.0, 0.0, 0.0))
	Input.action_press("dash")
	await step(1)
	Input.action_release("dash")
	await step(2)
	var dash_moved: float = game.player.global_position.distance_to(pos_before_dash)
	check("dash-costs-stamina-and-moves", game.player.stamina <= stamina_before - 24.0 and dash_moved > 1.0,
		{"stamina_before": stamina_before, "stamina_after": game.player.stamina, "moved": dash_moved})

	# --- No keyboard walking (用户 2026-10-22: 移除 wasd 移动方式): WASD and the
	# arrows are not movement keys any more; she stands still under them.
	var camera: Camera3D = game.get_viewport().get_camera_3d()
	var screen_right := Vector3(camera.global_basis.x.x, 0, camera.global_basis.x.z).normalized()
	var screen_down := -Vector3(-camera.global_basis.z.x, 0, -camera.global_basis.z.z).normalized()
	check("no-movement-actions", not InputMap.has_action("move_up") and not InputMap.has_action("move_right") and Keybinds.info("move_up").is_empty(), {})
	game.player.teleport(ContinuousWorldMap.ENTRY_POSITION)
	await step(2)
	game.player.clear_move_target()
	var still_from: Vector3 = game.player.global_position
	for code in [KEY_W, KEY_D, KEY_RIGHT]:
		var press := InputEventKey.new()
		press.physical_keycode = code
		press.keycode = code
		press.pressed = true
		Input.parse_input_event(press)
	await step(30)
	for code in [KEY_W, KEY_D, KEY_RIGHT]:
		var release := InputEventKey.new()
		release.physical_keycode = code
		release.keycode = code
		release.pressed = false
		Input.parse_input_event(release)
	var key_drift: float = Vector2(game.player.global_position.x - still_from.x, game.player.global_position.z - still_from.z).length()
	check("wasd-and-arrows-do-not-walk", key_drift < 0.05, {"drift": key_drift})
	var player: Player = game.player

	player.teleport(ContinuousWorldMap.ENTRY_POSITION)
	await step(2)
	player._attack_cooldown = 0.0
	player.attack_direction(screen_right)
	var rooted_at: Vector3 = player.global_position
	player.set_move_target(rooted_at + screen_down * 5.0)
	await step(5)
	var mid: float = Vector2(player.global_position.x - rooted_at.x, player.global_position.z - rooted_at.z).length()
	await step(40)
	var later: float = Vector2(player.global_position.x - rooted_at.x, player.global_position.z - rooted_at.z).length()
	check("move-order-waits-for-the-swing", mid < 0.05 and later > 1.5, {"mid": mid, "later": later})

	player.teleport(ContinuousWorldMap.ENTRY_POSITION)
	await step(2)
	player._attack_cooldown = 0.0
	player._dash_cooldown = 0.0
	player.stamina = 100.0
	player.attack_direction(screen_right)
	var before_dodge: Vector3 = player.global_position
	Input.action_press("dash")
	await step(1)
	Input.action_release("dash")
	await step(2)
	var dodged: float = player.global_position.distance_to(before_dodge)
	check("dodge-cancels-the-swing", player.swing_remaining == 0.0 and dodged > 1.0, {"dodged": dodged})

	# A slanting dodge into a wall slides along it (用户 2026-10-20: 斜街闪避撞墙).
	player.teleport(ContinuousWorldMap.ENTRY_POSITION)
	await step(2)
	player._dash_cooldown = 0.0
	player.stamina = 100.0
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(1.0, 3.0, 12.0)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	game.add_child(wall)
	wall.global_position = player.global_position + Vector3(1.4, 0.5, 0)
	await physics_frame
	await physics_frame
	var slide_from: Vector3 = player.global_position
	player._start_dash(Vector3(1, 0, -1))
	var slid := Vector2(player.global_position.x - slide_from.x, player.global_position.z - slide_from.z)
	wall.queue_free()
	check("slanting-dodge-slides-along-a-wall", slid.length() > 1.6 and slid.x < 0.95, {"slid": slid})

	# Down-right faces down-right: the sheet's southeast row is drawn facing
	# down-left, so that facing shows the southwest row mirrored.
	var sprite: LapplandAnimator3D = game.player._sprite
	sprite._facing_index = LapplandAnimator3D.DIRECTIONS.find("southeast")
	sprite._play_idle()
	check("southeast-shows-mirrored-southwest", sprite.animation == &"idle_southwest" and sprite.flip_h,
		{"animation": str(sprite.animation), "flip": sprite.flip_h})
	sprite._facing_index = LapplandAnimator3D.DIRECTIONS.find("northwest")
	sprite._play_idle()
	check("northwest-shows-mirrored-northeast", sprite.animation == &"idle_northeast" and sprite.flip_h,
		{"animation": str(sprite.animation), "flip": sprite.flip_h})
	sprite._facing_index = LapplandAnimator3D.DIRECTIONS.find("northeast")
	sprite._play_idle()
	check("northeast-is-not-flipped", sprite.animation == &"idle_northeast" and not sprite.flip_h,
		{"animation": str(sprite.animation), "flip": sprite.flip_h})
	sprite._facing_index = LapplandAnimator3D.DIRECTIONS.find("southwest")
	sprite._play_idle()
	check("southwest-is-not-flipped", sprite.animation == &"idle_southwest" and not sprite.flip_h,
		{"animation": str(sprite.animation), "flip": sprite.flip_h})
	# Standing still loops a two-frame breathing pose, not the walk's frozen mid-stride frame.
	var idle_frames := sprite.sprite_frames
	var walk_first: AtlasTexture = idle_frames.get_frame_texture(&"walk_south", 0)
	var idle_first: AtlasTexture = idle_frames.get_frame_texture(&"idle_south", 0)
	check("idle-breathes-in-a-loop", sprite.is_playing() and idle_frames.get_frame_count(&"idle_south") == 2
		and idle_frames.get_animation_loop(&"idle_south") and idle_first.atlas != walk_first.atlas,
		{"playing": sprite.is_playing(), "frames": idle_frames.get_frame_count(&"idle_south")})

	var report := {
		"scope": "downfall-godot movement tests (move-to-target, arrival, pointer glue, dash)",
		"engine": Engine.get_version_info().string,
		"created_at": Time.get_datetime_string_from_system(true),
		"results": results,
		"failures": failures,
	}
	var evidence_dir := ProjectSettings.globalize_path("res://../evidence")
	DirAccess.make_dir_recursive_absolute(evidence_dir)
	var file := FileAccess.open(evidence_dir + "/downfall-test-movement-" + str(Time.get_unix_time_from_system()) + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("DOWNFALL TEST_MOVEMENT: %d checks / %d failures" % [results.size(), failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
