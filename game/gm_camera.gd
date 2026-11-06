class_name GmCamera
extends RefCounted

## GameManager's follow camera: zoom, turn and tilt (用户 2026-10-20), the
## smooth follow snapped to whole pixels, the boss blow's shake, the cave's
## cut-away and the sprites kept on their feet at any tilt. The view's numbers
## the rest of the game reads (camera_yaw, camera_pitch and their goals,
## camera_size_goal) stay on GameManager; this holds the rig's own state.

var game: GameManager
## The camera's smooth follow position. What is rendered is this snapped to
## whole screen pixels (see _snap_to_pixels).
var _follow := Vector3.ZERO
var _snapped := Vector3.INF
## The tilt the sprites were last set for.
var _sprites_pitch := GameManager.CAMERA_PITCH
var dragging := false
var _cut_amount := 0.0
## A boss's heavy blow (start_impact_shake).
var _impact_frames := 0
var _impact_total := 1
var _impact_pixels := 0.0

func _init(owner: GameManager) -> void:
	game = owner

## Mouse motion while the middle button drags turns and tilts the view.
func drag_input(event: InputEvent) -> void:
	if dragging and event is InputEventMouseMotion:
		game.camera_yaw_goal -= event.relative.x * GameManager.CAMERA_DRAG_TURN
		tilt(event.relative.y * GameManager.CAMERA_DRAG_TURN)

## The wheel and the drag start only where no panel took the press.
func unhandled_input(event: InputEvent) -> void:
	if not game.camera_control_active(): return
	if event.is_action_pressed("camera_zoom_in"): zoom(-1)
	elif event.is_action_pressed("camera_zoom_out"): zoom(1)
	elif event.is_action_pressed("camera_drag"): dragging = true

## One wheel notch closer (-1) or further out (1).
func zoom(steps: int) -> void:
	game.camera_size_goal = clampf(game.camera_size_goal + steps * GameManager.CAMERA_ZOOM_STEP, GameManager.CAMERA_SIZE_MIN, GameManager.CAMERA_SIZE_MAX)

## Steeper (positive radians) or lower, within the limits.
func tilt(radians: float) -> void:
	game.camera_pitch_goal = clampf(game.camera_pitch_goal + radians, GameManager.CAMERA_PITCH_MIN, GameManager.CAMERA_PITCH_MAX)

## Turn to the next 45° mark on that side (1 or -1).
func turn(side: int) -> void:
	var mark := game.camera_yaw_goal / GameManager.CAMERA_TURN_STEP
	game.camera_yaw_goal = (floorf(mark + 0.001) + 1.0 if side > 0 else ceilf(mark - 0.001) - 1.0) * GameManager.CAMERA_TURN_STEP

func reset_view() -> void:
	# The short way round to the default view.
	game.camera_yaw_goal = game.camera_yaw - wrapf(game.camera_yaw, -PI, PI)
	game.camera_size_goal = GameManager.CAMERA_SIZE
	game.camera_pitch_goal = GameManager.CAMERA_PITCH

## Where the camera sits from the point it looks at, tilted and turned with the view.
func offset() -> Vector3:
	var reach := GameManager.CAMERA_OFFSET.length()
	return Vector3(0.0, reach * sin(game.camera_pitch), -reach * cos(game.camera_pitch)).rotated(Vector3.UP, game.camera_yaw)

## A billboard shows its height above the ground cos(tilt) as tall on screen,
## so at another tilt than 58° its image would float above its feet or sink
## below them. Each sprite in "upright_sprites" is moved on its image by that
## difference (its height measured once, its own ground under it); each
## upright figure in "upright_figures" (BILLBOARD_FIXED_Y) is stretched by
## 1 / cos(tilt) to draw the same pixels.
func _keep_sprites_upright() -> void:
	var pitch := game.camera_pitch
	if is_equal_approx(pitch, GameManager.CAMERA_PITCH) and is_equal_approx(_sprites_pitch, GameManager.CAMERA_PITCH): return
	_sprites_pitch = pitch
	var rise := cos(GameManager.CAMERA_PITCH) - cos(pitch)
	BaseMap.pivot_screen_px = BaseMap.SORT_PIVOT_Y * cos(pitch) * 15.0
	var tree := game.get_tree()
	for node in tree.get_nodes_in_group("upright_sprites"):
		var sprite := node as SpriteBase3D
		if sprite == null or not sprite.is_inside_tree(): continue
		if not sprite.has_meta("upright_height"): sprite.set_meta("upright_height", sprite.global_position.y - game.ground_y(sprite.global_position))
		var shift: float = float(sprite.get_meta("upright_height")) * rise / sprite.pixel_size
		sprite.offset.y += shift - float(sprite.get_meta("upright_shift", 0.0))
		sprite.set_meta("upright_shift", shift)
	for node in tree.get_nodes_in_group("upright_figures"):
		(node as Node3D).scale.y = 1.0 / cos(pitch)

## The turn, reset and tilt keys, then the drag let go.
func keys() -> void:
	if game.camera_control_active():
		if Input.is_action_just_pressed("camera_turn_left"): turn(1)
		if Input.is_action_just_pressed("camera_turn_right"): turn(-1)
		if Input.is_action_just_pressed("camera_reset"): reset_view()
		if Input.is_action_just_pressed("camera_tilt_up"): tilt(GameManager.CAMERA_TILT_STEP)
		if Input.is_action_just_pressed("camera_tilt_down"): tilt(-GameManager.CAMERA_TILT_STEP)
	if dragging and not Input.is_action_pressed("camera_drag"): dragging = false

## The cave's cut-away round her (cutaway.gdshaderinc field_cut): opens over
## CUT_EASE seconds while rock stands between her and the camera, closes as
## gently once it does not (用户 2026-10-21: 挡视野时突然消失).
func ease_cutaway(delta: float) -> void:
	var want := 0.0
	var world_map := game.world_map
	if not game.in_base and is_instance_valid(world_map) and is_instance_valid(world_map.terrace_dressing):
		var away := Vector2(offset().x, offset().z)
		if away.length() > 0.01 and world_map.terrace_dressing.rock_before(game.player.global_position, away.normalized(), game.camera_pitch): want = 1.0
	var next := move_toward(_cut_amount, want, delta / GameManager.CUT_EASE)
	if next == _cut_amount: return
	_cut_amount = next
	RenderingServer.global_shader_parameter_set("field_cut", _cut_amount)

## (Her own blows never shake the camera, 用户 2026-10-20: 挥砍抖动也删掉.)
## A heavier shake for a boss's blow landing: `pixels` at first, over `frames`.
## A bigger one already running is not cut short.
func start_impact_shake(pixels: float, frames: int) -> void:
	# 震屏强度 (Boss演出策划案_v0_2 §1.4): 0, half or full.
	pixels *= clampf(float(SystemScreens.settings.get("shake_strength", 1.0)), 0.0, 1.0)
	if pixels <= 0.0: return
	if _impact_frames > 0 and _impact_pixels * _impact_frames / _impact_total >= pixels: return
	_impact_pixels = pixels
	_impact_frames = frames
	_impact_total = frames

## The frame's camera work, at the end of GameManager._process.
func process(delta: float) -> void:
	var camera := game.camera
	if not is_instance_valid(camera): return
	# Anything that placed the camera directly (spawns, captures) restarts the follow from there.
	if not camera.global_position.is_equal_approx(_snapped): _follow = camera.global_position - offset()
	var blend := minf(1, GameManager.CAMERA_EASE * delta)
	game.camera_yaw = lerpf(game.camera_yaw, game.camera_yaw_goal, blend) if absf(game.camera_yaw_goal - game.camera_yaw) > 0.0005 else game.camera_yaw_goal
	camera.size = lerpf(camera.size, game.camera_size_goal, blend) if absf(game.camera_size_goal - camera.size) > 0.005 else game.camera_size_goal
	game.camera_pitch = lerpf(game.camera_pitch, game.camera_pitch_goal, blend) if absf(game.camera_pitch_goal - game.camera_pitch) > 0.0005 else game.camera_pitch_goal
	_keep_sprites_upright()
	camera.global_basis = Basis.looking_at(-offset(), Vector3.UP)
	# She stays in the middle while the view turns: the follow eases the
	# point looked at, the offset turns round it.
	_follow = _follow.lerp(game.camera_target(), minf(1, GameManager.CAMERA_FOLLOW_SPEED * delta))
	_snapped = _snap_to_pixels(_follow + offset())
	camera.global_position = _snapped

	camera.h_offset = 0.0
	camera.v_offset = 0.0
	# A boss's heavy blow (BossVfx): a few pixels, dying away, both ways.
	if _impact_frames > 0 and game.simulation_active():
		var texel := camera.size / game.get_viewport().get_visible_rect().size.y
		var k := float(_impact_frames) / float(maxi(1, _impact_total))
		camera.h_offset += (1.0 if _impact_frames % 2 else -1.0) * _impact_pixels * k * texel
		camera.v_offset = (1.0 if (_impact_frames / 2) % 2 else -1.0) * _impact_pixels * 0.6 * k * texel
		_impact_frames -= 1

## The world renders at a low resolution and is scaled up with nearest-neighbour
## filtering, and every floor, prop and sprite rounds to that pixel grid on its
## own. With the camera at a fractional pixel offset, each of them crosses to
## the next pixel at a different moment as the camera moves, so props nudge a
## pixel against the floor and each other: the scene wobbles while it scrolls.
## Moving the camera only in whole screen pixels (across and up the screen;
## depth does not matter for an orthographic view) keeps every object's
## rounding fixed, so the scene moves as one piece.
func _snap_to_pixels(position: Vector3) -> Vector3:
	var viewport_height := game.get_viewport().get_visible_rect().size.y
	if viewport_height <= 0.0: return position
	var camera := game.camera
	var pixel := camera.size / viewport_height
	var basis := camera.global_basis
	var across := roundf(position.dot(basis.x) / pixel) * pixel
	var up := roundf(position.dot(basis.y) / pixel) * pixel
	return basis.x * across + basis.y * up + basis.z * position.dot(basis.z)
