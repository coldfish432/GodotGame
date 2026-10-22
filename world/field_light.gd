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
	# A darker night than it was (用户 2026-10-16: 龙门加霓虹灯), so the signs
	# and their colours carry the street.
	"city": {"ambient": Color(0.84, 0.86, 0.94), "player": Color(0.25, 0.2, 0.12), "player_radius": 7.0},
	# 龙门城区 · 下城 (改造案 v1.1 §1.3): a cold blue-grey wet night, a shade
	# darker than the upper city; the warmth in windows and red lanterns.
	"city_lower": {"ambient": Color(0.62, 0.68, 0.82), "player": Color(0.25, 0.2, 0.12), "player_radius": 7.0},
	# Cold white-blue under an overcast sky; the warm fires are the reprieve
	# (暗黑 IV 碎峰岭: frigid palette against warm settlements).
	"snow": {"ambient": Color(0.8, 0.86, 1.0), "player": Color(0.28, 0.22, 0.14), "player_radius": 7.0, "snow": 1.0},
	# 叙拉古 (叙拉古方案 §3.4; 改造案 v1.1 §2: 黄昏到夜晚): dusk going to night,
	# the warmth all in the wall lanterns, string lights and windows; darker
	# still in the rain.
	"siracusa": {"ambient": Color(0.58, 0.62, 0.76), "player": Color(0.28, 0.21, 0.13), "player_radius": 7.0},
	"siracusa_rain": {"ambient": Color(0.5, 0.55, 0.7), "player": Color(0.28, 0.21, 0.13), "player_radius": 7.0},
	# 罗德岛基地 (基地建模改造案_v1): a lit ship interior, cool and even, the
	# ceiling lamps adding pools; only a faint glow round the operator.
	"rhodes": {"ambient": Color(0.92, 0.95, 1.0), "player": Color(0.12, 0.12, 0.12), "player_radius": 5.0},
}

## The light's key for a floor: its region, Siracusa's weather, Lungmen's
## upper or lower city.
static func key(map: Node3D) -> String:
	if str(map.get("city_variant")) == "lower": return "city_lower"
	return str(map.region_id) + ("_rain" if str(map.get("weather")) == "rain" else "")

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
	_sync_rig(map)
	origin = map.SPINE_MIN - Vector2(36, 36)
	var size: Vector2 = (map.SPINE_MAX + Vector2(36, 36)) - origin
	columns = ceili(size.x / CELL)
	rows = ceili(size.y / CELL)
	var ambient: Color = region(key(map)).ambient
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
	apply(key(map))

## The same light over a fixed rectangle (the base, which has no terrain):
## `rect` in world x/z, lamps as in build().
func build_area(rect: Rect2, region_id: String, lamp_list: Array[Dictionary]) -> void:
	lights = lamp_list
	origin = rect.position
	columns = ceili(rect.size.x / CELL)
	rows = ceili(rect.size.y / CELL)
	var ambient: Color = region(region_id).ambient
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
				var reach := (1.0 - d * d) * (1.0 - d * d)
				var i := (z * columns + x) * 3
				buffer[i] += colour.r * reach
				buffer[i + 1] += colour.g * reach
				buffer[i + 2] += colour.b * reach
	var bytes := PackedByteArray()
	bytes.resize(buffer.size())
	for i in range(buffer.size()):
		bytes[i] = clampi(int(buffer[i] / LIGHT_SCALE * 255.0 + 0.5), 0, 255)
	texture = ImageTexture.create_from_image(Image.create_from_data(columns, rows, false, Image.FORMAT_RGB8, bytes))
	apply(region_id)

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

# --- Real lights (场景渲染统一改造案_v1 S3) ----------------------------------------
## The shaders no longer read the light texture: every lamp is an OmniLight
## (the texture is still baked for light_at and its tests). Lamps whose
## light cannot reach within RIG_REACH of her are off, and no more than
## RIG_LIMIT stay on (Lungmen's neon streets went to 44 fps); the nearest
## RIG_SHADOWS cast shadows, re-picked every RIG_PICK seconds.
const RIG_REACH := 30.0
const RIG_LIMIT := 32
const RIG_SHADOWS := 4
const RIG_PICK := 0.5
## Her feet, set by GameManager every frame in the field.
static var focus := Vector3.ZERO
var rig: LightRig

func _sync_rig(map: Node3D) -> void:
	var root: Node = map.get("_generated_root")
	if root == null: return
	if is_instance_valid(rig): rig.queue_free()
	rig = LightRig.new()
	rig.name = "FieldLights"
	root.add_child(rig)
	for lamp in lights:
		var c: Color = lamp.color
		var peak := maxf(c.r, maxf(c.g, c.b))
		if peak <= 0.01: continue
		var o := OmniLight3D.new()
		o.light_color = Color(c.r / peak, c.g / peak, c.b / peak)
		# The light texture added about the lamp's colour to the surface at its
		# centre, smooth to nothing at its radius: matched by energy ~ peak.
		o.omni_range = float(lamp.radius) * 1.15
		o.light_energy = clampf(peak * 1.6, 0.25, 1.6)
		o.omni_attenuation = 1.3
		o.light_specular = 0.3
		o.shadow_blur = 1.5
		o.position = lamp.at   # the generated root and the rig sit at the origin
		rig.add_child(o)
	rig.pick()

## The lights' Node: switches far lamps off and gives the near ones shadows.
class LightRig extends Node3D:
	var _wait := 0.0
	func _process(delta: float) -> void:
		_wait -= delta
		if _wait > 0.0: return
		_wait = FieldLight.RIG_PICK
		pick()
	func pick() -> void:
		var at := FieldLight.focus
		var near: Array = []
		for o in get_children():
			var light := o as OmniLight3D
			if light == null: continue
			var d := light.global_position.distance_to(at)
			light.visible = false
			light.shadow_enabled = false
			# Ranked by how near its pool's edge comes to her.
			if d < FieldLight.RIG_REACH + light.omni_range: near.append([d - light.omni_range * 0.5, light])
		near.sort_custom(func(a, b): return a[0] < b[0])
		for i in range(mini(FieldLight.RIG_LIMIT, near.size())): (near[i][1] as OmniLight3D).visible = true
		for i in range(mini(FieldLight.RIG_SHADOWS, near.size())):
			(near[i][1] as OmniLight3D).shadow_enabled = true
	## Tint for a self-lit sprite at `p`, as BaseMap.light_tint.
	func tint_at(p: Vector3, ambient: Color, pull: float) -> Color:
		var sum := Color(0, 0, 0)
		var weight := 0.0
		for o in get_children():
			var light := o as OmniLight3D
			if light == null or not light.visible: continue
			var d := light.global_position.distance_to(p)
			if d >= light.omni_range: continue
			var w := light.light_energy * pow(1.0 - d / light.omni_range, 2.0)
			sum += light.light_color * w
			weight += w
		if weight <= 0.0: return ambient
		return ambient.lerp(sum / weight, clampf(weight * pull, 0.0, pull))

## Back to unlit (the base, camps): a white pixel over everything, no glow.
static func clear() -> void:
	RenderingServer.global_shader_parameter_set("field_light", WHITE)
	RenderingServer.global_shader_parameter_set("field_light_rect", Vector4(-100000, -100000, 200000, 200000))
	RenderingServer.global_shader_parameter_set("field_player_light", Vector4.ZERO)
	RenderingServer.global_shader_parameter_set("field_snow", 0.0)
