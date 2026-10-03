class_name CharacterSprites
extends RefCounted

const _Art = preload("res://art/pixel_art.gd")

## Original, procedurally-drawn pixel character sprites — blocky rectangle
## silhouettes distinguished only by color/accessory, not likenesses of any
## specific character. Each is a small (16x20) 2-frame walk/idle cycle;
## Player/Enemy swap textures on a timer rather than using an AnimatedSprite,
## keeping this a plain data-generation module with no scene-tree state.

const WIDTH := 16
const HEIGHT := 20
const OUTLINE_COLOR := Color(0.05, 0.05, 0.08)

static func humanoid_walk_frames(body_color: Color, skin_color: Color, accent_color: Color = Color(0, 0, 0, 0)) -> Array[ImageTexture]:
	return [_humanoid_frame(body_color, skin_color, accent_color, 0), _humanoid_frame(body_color, skin_color, accent_color, 1)]

static func slug_frames(body_color: Color) -> Array[ImageTexture]:
	return [_slug_frame(body_color, 0), _slug_frame(body_color, 3)]

static func _humanoid_frame(body_color: Color, skin_color: Color, accent_color: Color, leg_shift: int) -> ImageTexture:
	var image := _Art.new_image(WIDTH, HEIGHT)
	var limb_color := body_color.darkened(0.35)
	_Art.fill_rect(image, 6, 0, 4, 5, skin_color)                      # head
	_Art.fill_rect(image, 4, 5, 8, 7, body_color)                      # torso
	_Art.fill_rect(image, 2, 6, 2, 5, limb_color)                      # left arm
	_Art.fill_rect(image, 12, 6, 2, 5, limb_color)                     # right arm
	_Art.fill_rect(image, 5 - leg_shift, 12, 3, 8, limb_color)         # left leg
	_Art.fill_rect(image, 9 + leg_shift, 12, 3, 8, limb_color)         # right leg
	if accent_color.a > 0.0:
		_Art.fill_rect(image, 13, 3, 2, 2, accent_color)               # a small held/worn accent
	_Art.outline(image, OUTLINE_COLOR)
	return _Art.to_texture(image)

static func _slug_frame(body_color: Color, squish: int) -> ImageTexture:
	var image := _Art.new_image(WIDTH, HEIGHT)
	var body_height := 10 - squish
	var top := HEIGHT - body_height - 2
	_Art.fill_rect(image, 1, top, WIDTH - 2, body_height, body_color)
	_Art.fill_rect(image, 3, top - 3, 3, 3, body_color.lightened(0.25))
	_Art.fill_rect(image, WIDTH - 6, top - 3, 3, 3, body_color.lightened(0.25))
	_Art.outline(image, OUTLINE_COLOR)
	return _Art.to_texture(image)
