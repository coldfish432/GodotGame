class_name PixelArt
extends RefCounted

## Tiny original pixel-sprite drawing helpers — plain rectangles baked into
## an Image/ImageTexture at runtime, no external asset files, matching the
## rest of this project's "everything is code-generated" approach.

static func new_image(width: int, height: int) -> Image:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	return image

static func fill_rect(image: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	var width := image.get_width()
	var height := image.get_height()
	for py in range(y, y + h):
		if py < 0 or py >= height:
			continue
		for px in range(x, x + w):
			if px < 0 or px >= width:
				continue
			image.set_pixel(px, py, color)

static func outline(image: Image, color: Color) -> void:
	# Adds a 1px outline on every transparent pixel that borders an opaque one.
	var width := image.get_width()
	var height := image.get_height()
	var original := image.duplicate()
	var offsets: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	for y in range(height):
		for x in range(width):
			if original.get_pixel(x, y).a > 0.0:
				continue
			for offset in offsets:
				var nx := x + offset.x
				var ny := y + offset.y
				if nx < 0 or nx >= width or ny < 0 or ny >= height:
					continue
				if original.get_pixel(nx, ny).a > 0.0:
					image.set_pixel(x, y, color)
					break

static func to_texture(image: Image) -> ImageTexture:
	return ImageTexture.create_from_image(image)
