class_name AttackCursor
## The pointer over an enemy's hit box (用户 2026-10-14: 鼠标移到敌人判定框上
## 变攻击箭头). Sol's art goes in ART when it arrives; until then a red
## arrow with a dark rim is drawn here.
const ART := "res://ui/art/cursor_attack.png"
const SIZE := 32
const HOTSPOT := Vector2(1, 1)
## The arrow's outline, tip at the hotspot.
const ARROW := [Vector2(1, 1), Vector2(1, 24), Vector2(7, 18), Vector2(11, 28), Vector2(15, 26), Vector2(11, 17), Vector2(19, 17)]

static var _texture: Texture2D

static func texture() -> Texture2D:
	if _texture != null: return _texture
	if ResourceLoader.exists(ART):
		_texture = load(ART)
		return _texture
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var polygon := PackedVector2Array(ARROW)
	for y in range(SIZE):
		for x in range(SIZE):
			var at := Vector2(x + 0.5, y + 0.5)
			if Geometry2D.is_point_in_polygon(at, polygon):
				image.set_pixel(x, y, AK.RED)
	# A one-pixel dark rim so it reads on snow and on stone.
	var rim := image.duplicate() as Image
	for y in range(SIZE):
		for x in range(SIZE):
			if image.get_pixel(x, y).a > 0.0: continue
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + o
				if n.x >= 0 and n.y >= 0 and n.x < SIZE and n.y < SIZE and image.get_pixelv(n).a > 0.0:
					rim.set_pixel(x, y, AK.INK)
					break
	_texture = ImageTexture.create_from_image(rim)
	return _texture
