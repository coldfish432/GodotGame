extends AnimatedSprite2D
## Eight-direction, four-frame walking animation driver for a CharacterBody2D parent.
## Direction changes select the neighboring facing animation; the previous facing is held while idle.

const DIRECTIONS: Array[String] = [
	"east", "southeast", "south", "southwest",
	"west", "northwest", "north", "northeast",
]

@export var body_path: NodePath = NodePath("..")
@export_range(0.0, 45.0, 0.5) var turn_hysteresis_degrees := 6.0
@export_range(0.01, 0.3, 0.01) var turn_step_seconds := 0.07

var _body: CharacterBody2D
var _facing_index := 2 # south
var _turn_timer := 0.0

func _ready() -> void:
	_body = get_node_or_null(body_path) as CharacterBody2D
	sprite_frames = preload("res://godot_assets/Lappland8DirWalk.tres")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	play("idle_south")
	stop()
	frame = 0

func _process(delta: float) -> void:
	if not is_instance_valid(_body):
		return

	var velocity := _body.velocity
	if velocity.length_squared() < 0.01:
		_turn_timer = 0.0
		var idle_name := "idle_" + DIRECTIONS[_facing_index]
		if animation != idle_name:
			play(idle_name)
			stop()
			frame = 0
		return

	var angle := velocity.angle()
	var candidate := posmod(roundi(angle / (PI / 4.0)), 8)
	if candidate != _facing_index:
		var current_angle := float(_facing_index) * PI / 4.0
		var delta_angle := absf(wrapf(angle - current_angle, -PI, PI))
		if delta_angle >= (PI / 8.0) + deg_to_rad(turn_hysteresis_degrees):
			_turn_timer -= delta
			if _turn_timer <= 0.0:
				var clockwise_steps := posmod(candidate - _facing_index, 8)
				var turn_step := 1 if clockwise_steps <= 4 else -1
				_facing_index = posmod(_facing_index + turn_step, 8)
				_turn_timer = turn_step_seconds
	else:
		_turn_timer = 0.0

	var walk_name := "walk_" + DIRECTIONS[_facing_index]
	if animation != walk_name or not is_playing():
		play(walk_name)
