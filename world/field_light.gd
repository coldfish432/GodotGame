class_name FieldLight
extends RefCounted

## Field lighting (地图表现调研_光照贴图构图.md §2–3). A light texture over the
## whole map, baked when the floor is generated: the region's ambient (cool,
## and dark in the mine — 暗黑 IV's "return to darkness"), plus every static
## lamp splatted in warm. Every field shader multiplies by it through
## world/field_light.gdshaderinc, and adds a warm glow that follows Lappland
## so the ground she stands on is always readable (恐怖黎明 was faulted for
## areas too dark to play).
##
## Stored at half strength in an 8-bit texture (LIGHT_SCALE): pools of lamp
## light go above 1.
const CELL := 0.5
const LIGHT_SCALE := 2.0
const WHITE := preload("res://art/kit/textures/white_1px.png")

## ambient, the glow around Lappland (colour, radius).
const REGIONS := {
	"mine": {"ambient": Color(0.72, 0.74, 0.86), "player": Color(0.45, 0.36, 0.22), "player_radius": 8.0},
	"city": {"ambient": Color(0.96, 0.97, 1.02), "player": Color(0.25, 0.2, 0.12), "player_radius": 7.0},
	# Cold white-blue under an overcast sky; the warm fires are the reprieve
	# (暗黑 IV 碎峰岭: frigid palette against warm settlements).
	"snow": {"ambient": Color(0.8, 0.86, 1.0), "player": Color(0.28, 0.22, 0.14), "player_radius": 7.0, "snow": 1.0},
}

var origin := Vector2.ZERO
var columns := 0
var rows := 0
var texture: ImageTexture
## The lamps baked this floor: {"at": Vector3, "color": Color, "radius": float}.
var lights: Array[Dictionary] = []

static func region(region_id: String) -> Dictionary:
	return REGIONS.get(region_id, REGIONS.city)

func build(map: Node3D, lamp_list: Array[Dictionary]) -> void:
	lights = lamp_list
	origin = map.SPINE_MIN - Vector2(36, 36)
	var size: Vector2 = (map.SPINE_MAX + Vector2(36, 36)) - origin
	columns = ceili(size.x / CELL)
	rows = ceili(size.y / CELL)
	var ambient: Color = region(map.region_id).ambient
	var buffer := PackedFloat32Array()
	buffer.resize(columns * rows * 3)
	for i in range(columns * rows):
		buffer[i * 3] = ambient.r
		buffer[i * 3 + 1] = ambient.g
		buffer[i * 3 + 2] = ambient.b
	for lamp in lights:
		var at: Vector3 = lamp.at
		var colour: Color = lamp.color
		var radius: float = lamp.radius
		var cx := int((at.x - origin.x) / CELL)
		var cz := int((at.z - origin.y) / CELL)
		var span := ceili(radius / CELL)
		for z in range(maxi(0, cz - span), mini(rows, cz + span + 1)):
			for x in range(maxi(0, cx - span), mini(columns, cx + span + 1)):
				var p := origin + Vector2(x + 0.5, z + 0.5) * CELL
				var d := p.distance_to(Vector2(at.x, at.z)) / radius
				if d >= 1.0: continue
				# Light falls off over a step in height: a lamp in a corridor
				# lights its floor, not the top of the bank beside it.
				var rise := absf(map._surface.top_at(p) - at.y + 1.0)
				# Smooth to zero at the rim: no edge, no ring.
				var reach := (1.0 - d * d) * (1.0 - d * d) * clampf(1.0 - maxf(rise - 1.2, 0.0) / 2.4, 0.15, 1.0)
				var i := (z * columns + x) * 3
				buffer[i] += colour.r * reach
				buffer[i + 1] += colour.g * reach
				buffer[i + 2] += colour.b * reach
	var bytes := PackedByteArray()
	bytes.resize(buffer.size())
	for i in range(buffer.size()):
		bytes[i] = clampi(int(buffer[i] / LIGHT_SCALE * 255.0 + 0.5), 0, 255)
	var image := Image.create_from_data(columns, rows, false, Image.FORMAT_RGB8, bytes)
	texture = ImageTexture.create_from_image(image)
	apply(map.region_id)

## Light at x/z (for tests), in the shader's units.
func light_at(point: Vector2) -> Color:
	if texture == null: return Color.WHITE
	var x := clampi(int((point.x - origin.x) / CELL), 0, columns - 1)
	var z := clampi(int((point.y - origin.y) / CELL), 0, rows - 1)
	var c := texture.get_image().get_pixel(x, z)
	return Color(c.r * LIGHT_SCALE, c.g * LIGHT_SCALE, c.b * LIGHT_SCALE)

func apply(region_id: String) -> void:
	RenderingServer.global_shader_parameter_set("field_light", texture)
	RenderingServer.global_shader_parameter_set("field_light_rect", Vector4(origin.x, origin.y, columns * CELL, rows * CELL))
	var glow: Color = region(region_id).player
	RenderingServer.global_shader_parameter_set("field_player_light", Vector4(glow.r, glow.g, glow.b, float(region(region_id).player_radius)))
	RenderingServer.global_shader_parameter_set("field_snow", float(region(region_id).get("snow", 0.0)))

## Back to unlit (the base, camps): a white pixel over everything, no glow.
static func clear() -> void:
	RenderingServer.global_shader_parameter_set("field_light", WHITE)
	RenderingServer.global_shader_parameter_set("field_light_rect", Vector4(-100000, -100000, 200000, 200000))
	RenderingServer.global_shader_parameter_set("field_player_light", Vector4.ZERO)
	RenderingServer.global_shader_parameter_set("field_snow", 0.0)
