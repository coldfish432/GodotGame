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
## down-left (用户 2026-10-06). The northwest row turns her up-right or straight
## up, so moving up-left looked like facing north; it shows the northeast row
## mirrored (用户 2026-10-07). The combat sheet's northwest row is correct.
const MIRRORED := {"southeast": "southwest", "northwest": "northeast"}

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
## Amiya (Guard), Sol batch A1 (prepare_amiya_guard_atlas.py): combat columns
## 3/4/4/4/1 per A_brief_v1.md. Her walk rows all face the right way, so
## nothing is mirrored.
const AMIYA_ACTIONS := {"attack_1": [0, 3], "attack_2": [3, 4], "attack_3": [7, 4], "shadow": [11, 4], "hurt": [15, 1]}
## Per operator: sheets, action table, the signature's action and the rows
## shown mirrored.
const CHARACTERS := {
	"lappland": {"walk": "res://godot_assets/Lappland8DirWalk32.tres", "idle": "res://godot_assets/lappland_idle_32.png",
		"combat": "res://godot_assets/lappland_combat_64.png", "actions": ACTIONS, "signature": "wave", "mirrored": MIRRORED},
	"amiya_guard": {"walk": "res://godot_assets/amiya_guard_walk_32.png", "idle": "res://godot_assets/amiya_guard_idle_32.png",
		"combat": "res://godot_assets/amiya_guard_combat_64.png", "actions": AMIYA_ACTIONS, "signature": "shadow", "mirrored": {}},
	# The first recruits (prepare_operator_atlas.py; column tables from each
	# batch <CODE>1 manifest). Their walk rows all face the right way. A third
	# number loops the frames from that offset while the pose is held
	# (hold_action): 星熊's saw grind, 林's sustain, 寒檀's channel.
	"hellagur": {"walk": "res://godot_assets/hellagur_walk_32.png", "idle": "res://godot_assets/hellagur_idle_32.png",
		"combat": "res://godot_assets/hellagur_combat_64.png", "signature": "", "mirrored": {},
		"actions": {"attack_1": [0, 3], "attack_2": [3, 2], "attack_3": [5, 3], "thrust": [[13, 6, 7], 3], "pierce": [[13, 13, 6, 6, 7], 5], "newmoon": [8, 2], "halfmoon": [10, 3], "fullmoon": [13, 2], "hurt": [15, 1]}},
	"rosa": {"walk": "res://godot_assets/rosa_walk_32.png", "idle": "res://godot_assets/rosa_idle_32.png",
		"combat": "res://godot_assets/rosa_combat_64.png", "signature": "", "mirrored": {},
		"actions": {"attack_1": [0, 3], "attack_2": [0, 3], "attack_3": [3, 3], "volley": [6, 6], "hurt": [12, 1]}},
	"hoshiguma": {"walk": "res://godot_assets/hoshiguma_walk_32.png", "idle": "res://godot_assets/hoshiguma_idle_32.png",
		"combat": "res://godot_assets/hoshiguma_combat_64.png", "signature": "", "mirrored": {},
		"actions": {"attack_1": [0, 3], "attack_2": [3, 2], "attack_3": [5, 4], "saw": [9, 3, 1], "block": [13, 1], "hurt": [14, 1]}},
	"lin": {"walk": "res://godot_assets/lin_walk_32.png", "idle": "res://godot_assets/lin_idle_32.png",
		"combat": "res://godot_assets/lin_combat_64.png", "signature": "", "mirrored": {},
		"actions": {"attack_1": [0, 3], "attack_2": [3, 2], "attack_3": [5, 3], "surge": [8, 4, 2], "shatter": [12, 1], "hurt": [13, 1]}},
	"typhon": {"walk": "res://godot_assets/typhon_walk_32.png", "idle": "res://godot_assets/typhon_idle_32.png",
		"combat": "res://godot_assets/typhon_combat_64.png", "signature": "", "mirrored": {},
		"actions": {"attack_1": [0, 4], "attack_2": [0, 4], "attack_3": [0, 4], "hunt": [4, 5], "hurt": [9, 1]}},
	"santalla": {"walk": "res://godot_assets/santalla_walk_32.png", "idle": "res://godot_assets/santalla_idle_32.png",
		"combat": "res://godot_assets/santalla_combat_64.png", "signature": "", "mirrored": {},
		"actions": {"attack_1": [0, 2], "attack_2": [2, 1], "attack_3": [3, 3], "tears": [6, 3, 1], "hurt": [11, 1]}},
	"texas": {"walk": "res://godot_assets/texas_walk_32.png", "idle": "res://godot_assets/texas_idle_32.png",
		"combat": "res://godot_assets/texas_combat_64.png", "signature": "", "mirrored": {},
		"actions": {"attack_1": [0, 2], "attack_2": [2, 2], "attack_3": [4, 3], "rain": [7, 5], "hurt": [12, 1]}},
}
## The Doctor and the crew who walk the base (art/characters/crew/CR_brief_v1.md):
## walk and idle sheets only, baked by prepare_crew_atlas.py into
## godot_assets/crew/. Their rows all face the right way.
const CREW := ["doctor", "sharp", "stormeye", "pith", "touch", "tulip", "mechanist", "misery",
	"reserve_vanguard", "reserve_guard", "reserve_defender", "reserve_sniper", "reserve_caster",
	"reserve_medic", "reserve_supporter", "reserve_specialist",
	# ST1b (用户 2026-10-22: 补杜宾、凯尔希的行走精灵图): walk once their sheets are baked.
	"dobermann", "kaltsit"]
const CREW_CONFIG := {"actions": {}, "signature": "", "mirrored": {}}
const WALK_FPS := 8.0
var character := "lappland"
var actions: Dictionary = ACTIONS
var mirrored: Dictionary = MIRRORED
var signature_action := "wave"
var action_time := 0.0
var action_duration := 0.0
var action_name := ""
## Playback multiplier for the current action (attack speed); 1 = 12 FPS.
var action_rate := 1.0
## The light around her in the base (场景渲染统一改造案_v1 §4.6): the sprite
## stays self-lit and takes the place's colour as a tint (BaseMap.light_tint).
var scene_tint := Color.WHITE:
	set(value):
		scene_tint = value
		if action_name != "dash": modulate = value
## A soft shadow at her feet, shown where the scene is lit for real (the base).
var contact_shadow: Decal
var _body: CharacterBody3D
var _facing_index := 2 # south
var _turn_timer := 0.0
var _forced_direction := Vector3.ZERO
## The facing is a row on screen. When the view turns (GameManager.camera_yaw)
## the row turns with it, so she keeps facing the same way in the world: it is
## worked out from the row last set and where world east was on screen then,
## so a slow drag still turns her once it passes half a row.
var _facing_ref_index := 2
var _facing_ref_east := INF

func _ready() -> void:
	_body = get_node_or_null(body_path) as CharacterBody3D
	_load_character()
	pixel_size = PIXEL_SIZE
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# Hard-edged sheet (alpha was thresholded when it was downscaled), so
	# discard rather than blend — keeps depth sorting sane against the world.
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	position.y = CELL_TEXELS * PIXEL_SIZE * 0.5 - FOOT_DROP
	# Kept on her feet at any camera tilt (GameManager._keep_sprites_upright).
	add_to_group("upright_sprites")
	# Sprites sit on their own render layer so ground decals (the contact
	# shadow among them) never land on a sprite.
	layers = SPRITE_LAYER
	contact_shadow = Decal.new()
	contact_shadow.size = Vector3(1.3, 0.6, 1.3)
	contact_shadow.cull_mask = 1
	contact_shadow.texture_albedo = _contact_texture()
	contact_shadow.visible = false
	add_child(contact_shadow)
	contact_shadow.position = Vector3(0, -position.y + 0.1, 0)
	_play_idle()

const SPRITE_LAYER := 2
static var _contact: Texture2D

## A round shadow, darkest under the feet.
static func _contact_texture() -> Texture2D:
	if _contact == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in range(64):
			for x in range(64):
				var r := Vector2(x - 31.5, y - 31.5).length() / 31.5
				img.set_pixel(x, y, Color(0, 0, 0, clampf(1.0 - r, 0.0, 1.0) * 0.55))
		_contact = ImageTexture.create_from_image(img)
	return _contact

## One of an operator's sheets ("walk", "idle", "combat"), or null.
static func sheet(id: String, kind: String) -> Resource:
	var path := "res://godot_assets/crew/%s_%s_32.png" % [id, kind] if id in CREW 		else str(CHARACTERS.get(id, CHARACTERS.lappland).get(kind, ""))
	return load(path) if ResourceLoader.exists(path) else null

## Whether someone can be drawn: an operator, or a crew member whose walk and
## idle sheets have arrived.
static func has_sheets(id: String) -> bool:
	if CHARACTERS.has(id): return true
	return id in CREW and sheet(id, "walk") != null and sheet(id, "idle") != null

static func look_config(id: String) -> Dictionary:
	return CREW_CONFIG if id in CREW else CHARACTERS.get(id, CHARACTERS.lappland)

## Swap to another operator's sheets (picked at the base).
func set_character(id: String) -> void:
	if not has_sheets(id) or id == character: return
	character = id
	cancel_action()
	_load_character()
	_play_idle()

func _load_character() -> void:
	var config: Dictionary = look_config(character)
	actions = config.actions
	mirrored = config.mirrored
	signature_action = config.signature
	var walk := sheet(character, "walk")
	if walk is SpriteFrames: sprite_frames = (walk as SpriteFrames).duplicate()
	else: sprite_frames = _walk_frames_from(walk as Texture2D)
	_build_idle_frames()
	_build_combat_frames()

## A walk sheet laid out like lappland_8dir_walk_32.png: 4 columns, rows in
## IDLE_ROWS order, looping at 8 FPS.
func _walk_frames_from(walk: Texture2D) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for row in range(IDLE_ROWS.size()):
		var animation_name: String = "walk_" + IDLE_ROWS[row]
		frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, WALK_FPS)
		frames.set_animation_loop(animation_name, true)
		frames.add_animation("idle_" + IDLE_ROWS[row])
		for column in range(4):
			var texture := AtlasTexture.new()
			texture.atlas = walk
			texture.region = Rect2(column * CELL_TEXELS, row * CELL_TEXELS, CELL_TEXELS, CELL_TEXELS)
			frames.add_frame(animation_name, texture)
	return frames

## Point the sprite at a world direction for one frame regardless of velocity —
## used when the player swings at a target they are not walking toward.
func face_world_direction(direction: Vector3) -> void:
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		_forced_direction = direction.normalized()

func _process(delta: float) -> void:
	if not is_instance_valid(_body):
		return
	_follow_camera_turn()

	if _body is Player:
		var player := _body as Player
		if (is_instance_valid(player.game) and not (player.game.simulation_active() or player.game.base_walk_active())) or player.hitstop_remaining > 0:
			speed_scale = 0
			return
		speed_scale = 1
	if action_duration > 0:
		action_time += delta
		if action_time < action_duration:
			if action_name != "dash": frame = _action_frame()
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
	flip_h = mirrored.has(name)
	return mirrored.get(name, name)

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
		_remember_facing()
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
		_remember_facing()

func _face_toward(direction: Vector3) -> void:
	_facing_index = posmod(roundi(_screen_angle(direction) / (PI / 4)), 8)
	_remember_facing()

func _remember_facing() -> void:
	_facing_ref_index = _facing_index
	_facing_ref_east = _screen_angle(Vector3.RIGHT)

func _follow_camera_turn() -> void:
	if _facing_ref_east == INF:
		_remember_facing()
		return
	var turn := wrapf(_screen_angle(Vector3.RIGHT) - _facing_ref_east, -PI, PI)
	if absf(turn) > 0.0001: _facing_index = posmod(roundi((_facing_ref_index * PI / 4.0 + turn) / (PI / 4.0)), 8)

func _play_idle() -> void:
	var idle_name := "idle_" + _sheet_direction(_facing_index)
	if animation != idle_name or not is_playing():
		play(idle_name)

## Standing pose plus a one-texel breathing bob (prepare_lappland_idle.py),
## replacing the walk sheet's frozen mid-stride frame 0.
const IDLE_ROWS := ["south", "southwest", "west", "northwest", "north", "northeast", "east", "southeast"]
const IDLE_FPS := 2.0

func _build_idle_frames() -> void:
	var idle_sheet := sheet(character, "idle") as Texture2D
	for row in range(IDLE_ROWS.size()):
		var animation_name: String = "idle_" + IDLE_ROWS[row]
		sprite_frames.clear(animation_name)
		sprite_frames.set_animation_speed(animation_name, IDLE_FPS)
		sprite_frames.set_animation_loop(animation_name, true)
		for column in range(2):
			var texture := AtlasTexture.new()
			texture.atlas = idle_sheet
			texture.region = Rect2(column * CELL_TEXELS, row * CELL_TEXELS, CELL_TEXELS, CELL_TEXELS)
			sprite_frames.add_frame(animation_name, texture)

func _build_combat_frames() -> void:
	var combat_sheet := sheet(character, "combat") as Texture2D
	if combat_sheet == null: return
	for row in range(COMBAT_ROWS.size()):
		for action in actions:
			var animation_name: String = action + "_" + COMBAT_ROWS[row]
			sprite_frames.add_animation(animation_name)
			sprite_frames.set_animation_speed(animation_name, 12)
			sprite_frames.set_animation_loop(animation_name, false)
			# An entry is [first column, count] or, for poses taken from apart,
			# [[columns...], count] (赫拉格's thrusts: the blade raised high, then the iai thrust).
			var entry: Array = actions[action]
			var columns: Array = entry[0] if entry[0] is Array else range(int(entry[0]), int(entry[0]) + int(entry[1]))
			for column in columns:
				var texture := AtlasTexture.new()
				texture.atlas = combat_sheet
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
	action_duration = float(actions[action][1]) / (12.0 * action_rate)
	animation = action + "_" + direction_name
	stop()
	frame = 0

func play_attack(direction: Vector3, stage: int, wave: bool, rate: float = 1.0) -> void:
	_face_toward(direction)
	_start_action(signature_action if wave else "attack_" + str(stage + 1), rate)

## The frame for the action's clock: the last one held, or, for an action with
## a loop offset, its loop frames cycling.
func _action_frame() -> int:
	var count := sprite_frames.get_frame_count(animation)
	var index := int(action_time * 12 * action_rate)
	var entry: Array = actions.get(action_name, [])
	if entry.size() > 2 and index >= count:
		var from := int(entry[2])
		return from + (index - from) % maxi(1, count - from)
	return mini(count - 1, index)

## One of her named actions (an operator kit's skill pose), facing `direction`.
func play_action(action: String, direction: Vector3, rate: float = 1.0) -> void:
	if not actions.has(action): return
	if direction.length_squared() > 0.0001: _face_toward(direction)
	_start_action(action, rate)

## Hold a pose for `seconds` regardless of the action's frame count — the
## shadow strike lasts as long as its cuts, not its three or four frames.
func hold_action(seconds: float) -> void:
	if action_duration > 0: action_duration = maxf(action_duration, seconds)

func play_hurt() -> void:
	if action_name == "dash" or not actions.has("hurt"): return
	_start_action("hurt")

func start_dash(direction: Vector3) -> void:
	cancel_action()
	_face_toward(direction)
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
	modulate = scene_tint
