class_name LapplandAnimator3D
extends AnimatedSprite3D

## Eight-direction walk driver for a billboarded sprite in the 3D world.
##
## The sheet's directions are authored in screen space (row 0 faces the
## viewer), so "south" means "toward the camera", not "toward world -Z".
## Movement is therefore projected onto the camera's horizontal right/forward
## axes before picking a row — if the camera yaw ever changes, the facing
## follows it instead of desyncing from what the player sees.
##
## LapplandSpriteAnimator.gd next to this file is the original 2D version
## (AnimatedSprite2D + CharacterBody2D); this one is what downfall-godot uses.

const DIRECTIONS: Array[String] = [
	"east", "southeast", "south", "southwest",
	"west", "northwest", "north", "northeast",
]

## One texel per rendered pixel at the game's 640x360 internal resolution
## (orthogonal camera size 24 over 360 px => 1 world unit = 15 px).
## Rows of the walk sheet drawn facing the wrong way, shown as the mirrored
## opposite instead: the southeast row is painted facing down-left (it is
## nearly a copy of southwest), so moving down-right showed her looking
## down-left (用户 2026-10-06).
const MIRRORED := {"southeast": "southwest"}

const PIXEL_SIZE := 0.06
const CELL_TEXELS := 32.0
## Distance from the body's origin down to the feet — matches the player's
## 1.3-tall capsule so the sprite stands on the ground rather than in it.
const FOOT_DROP := 0.65

@export var body_path: NodePath = NodePath("..")
@export_range(0.0, 45.0, 0.5) var turn_hysteresis_degrees := 6.0
@export_range(0.01, 0.3, 0.01) var turn_step_seconds := 0.07

const COMBAT_ROWS := ["south", "southwest", "west", "northwest", "north"]
## Combat cells are larger so the swords are not clipped. Each cell shares a
## walk frame's centre and foot line, so switching sheets does not move her.
const COMBAT_CELL := 64
const ACTIONS := {"attack_1": [0, 3], "attack_2": [3, 3], "attack_3": [6, 4], "wave": [10, 3], "hurt": [13, 1]}
var action_time := 0.0
var action_duration := 0.0
var action_name := ""
## Playback multiplier for the current action (attack speed); 1 = 12 FPS.
var action_rate := 1.0
var _body: CharacterBody3D
var _facing_index := 2 # south
var _turn_timer := 0.0
var _forced_direction := Vector3.ZERO

func _ready() -> void:
	_body = get_node_or_null(body_path) as CharacterBody3D
	sprite_frames = preload("res://godot_assets/Lappland8DirWalk32.tres").duplicate()
	_build_combat_frames()
	pixel_size = PIXEL_SIZE
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# Hard-edged sheet (alpha was thresholded when it was downscaled), so
	# discard rather than blend — keeps depth sorting sane against the world.
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	position.y = CELL_TEXELS * PIXEL_SIZE * 0.5 - FOOT_DROP
	_play_idle()

## Point the sprite at a world direction for one frame regardless of velocity —
## used when the player swings at a target they are not walking toward.
func face_world_direction(direction: Vector3) -> void:
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		_forced_direction = direction.normalized()

func _process(delta: float) -> void:
	if not is_instance_valid(_body):
		return

	if _body is Player:
		var player := _body as Player
		if (is_instance_valid(player.game) and not (player.game.simulation_active() or player.game.base_walk_active())) or player.hitstop_remaining > 0:
			speed_scale = 0
			return
		speed_scale = 1
	if action_duration > 0:
		action_time += delta
		if action_time < action_duration:
			if action_name != "dash": frame = mini(sprite_frames.get_frame_count(animation) - 1, int(action_time * 12 * action_rate))
			return
		cancel_action()
	flip_h = false
	var direction := _forced_direction
	_forced_direction = Vector3.ZERO
	var walking := false
	if direction == Vector3.ZERO:
		direction = Vector3(_body.velocity.x, 0.0, _body.velocity.z)
		walking = direction.length_squared() > 0.01

	if direction.length_squared() < 0.0001:
		_turn_timer = 0.0
		_play_idle()
		return

	_update_facing(_screen_angle(direction), delta)
	if walking:
		var walk_name := "walk_" + _sheet_direction(_facing_index)
		if animation != walk_name or not is_playing():
			play(walk_name)
	else:
		_play_idle()

## The sheet row for a facing, flipping the sprite for mirrored rows.
func _sheet_direction(index: int) -> String:
	var name := DIRECTIONS[index]
	flip_h = MIRRORED.has(name)
	return MIRRORED.get(name, name)

## World direction -> angle in the sheet's screen-space convention
## (x right, y down, so south == +PI/2).
func _screen_angle(direction: Vector3) -> float:
	var camera := get_viewport().get_camera_3d()
	var right := Vector3.RIGHT
	var forward := Vector3.FORWARD
	if is_instance_valid(camera):
		var basis := camera.global_transform.basis
		var flat_right := Vector3(basis.x.x, 0.0, basis.x.z)
		# Looking straight down collapses the camera's forward axis onto the
		# ground plane's normal; its up axis still points "screen up" there.
		var flat_forward := Vector3(-basis.z.x, 0.0, -basis.z.z)
		if flat_forward.length_squared() < 0.0001:
			flat_forward = Vector3(basis.y.x, 0.0, basis.y.z)
		if flat_right.length_squared() > 0.0001 and flat_forward.length_squared() > 0.0001:
			right = flat_right.normalized()
			forward = flat_forward.normalized()
	return atan2(-direction.dot(forward), direction.dot(right))

## Same hysteresis/step-through-neighbours turning as the 2D original: the
## facing walks around the compass one row at a time instead of snapping, and
## only commits once the angle is clearly past the halfway point.
func _update_facing(angle: float, delta: float) -> void:
	var candidate := posmod(roundi(angle / (PI / 4.0)), 8)
	if candidate == _facing_index:
		_turn_timer = 0.0
		return

	var current_angle := float(_facing_index) * PI / 4.0
	var delta_angle := absf(wrapf(angle - current_angle, -PI, PI))
	if delta_angle < (PI / 8.0) + deg_to_rad(turn_hysteresis_degrees):
		return

	_turn_timer -= delta
	if _turn_timer <= 0.0:
		var clockwise_steps := posmod(candidate - _facing_index, 8)
		var turn_step := 1 if clockwise_steps <= 4 else -1
		_facing_index = posmod(_facing_index + turn_step, 8)
		_turn_timer = turn_step_seconds

func _play_idle() -> void:
	var idle_name := "idle_" + _sheet_direction(_facing_index)
	if animation != idle_name:
		play(idle_name)
		stop()
		frame = 0

func _build_combat_frames() -> void:
	var sheet := preload("res://godot_assets/lappland_combat_64.png")
	for row in range(COMBAT_ROWS.size()):
		for action in ACTIONS:
			var animation_name: String = action + "_" + COMBAT_ROWS[row]
			sprite_frames.add_animation(animation_name)
			sprite_frames.set_animation_speed(animation_name, 12)
			sprite_frames.set_animation_loop(animation_name, false)
			for column in range(ACTIONS[action][0], ACTIONS[action][0] + ACTIONS[action][1]):
				var texture := AtlasTexture.new()
				texture.atlas = sheet
				texture.region = Rect2(column * COMBAT_CELL, row * COMBAT_CELL, COMBAT_CELL, COMBAT_CELL)
				sprite_frames.add_frame(animation_name, texture)

func _start_action(action: String, rate: float = 1.0) -> void:
	var index := _facing_index
	flip_h = index in [0, 1, 7]
	if index == 0: index = 4
	elif index == 1: index = 3
	elif index == 7: index = 5
	var direction_name := DIRECTIONS[index]
	action_name = action
	action_time = 0
	action_rate = maxf(rate, 0.01)
	action_duration = float(ACTIONS[action][1]) / (12.0 * action_rate)
	animation = action + "_" + direction_name
	stop()
	frame = 0

func play_attack(direction: Vector3, stage: int, wave: bool, rate: float = 1.0) -> void:
	_facing_index = posmod(roundi(_screen_angle(direction) / (PI / 4)), 8)
	_start_action("wave" if wave else "attack_" + str(stage + 1), rate)

func play_hurt() -> void:
	if action_name == "dash": return
	_start_action("hurt")

func start_dash(direction: Vector3) -> void:
	cancel_action()
	_facing_index = posmod(roundi(_screen_angle(direction) / (PI / 4)), 8)
	animation = "walk_" + _sheet_direction(_facing_index)
	stop()
	frame = 1
	modulate = CombatVfx.BLUE
	action_name = "dash"
	action_time = 0
	action_duration = Player.DASH_INVULN_DURATION

func cancel_action() -> void:
	action_duration = 0
	action_time = 0
	action_name = ""
	action_rate = 1.0
	flip_h = false
	modulate = Color.WHITE
