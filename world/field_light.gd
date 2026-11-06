class_name FieldLight
extends RefCounted

## Field lighting (地图表现调研_光照贴图构图.md §2–3; 场景渲染统一改造案_v1 S3).
## Per region: the ambient (cool, and dark in the mine — 暗黑 IV's "return to
## darkness"; GmLook puts it on the Environment) and a warm glow that follows
## her (GmLook's player OmniLight), so the ground she stands on is always
## readable (恐怖黎明 was faulted for areas too dark to play). Every static lamp
## is a real light through LightRig. No light texture is baked or read
## (field_light.gdshaderinc's field_lit returns the colour as it is);
## light_at still works out the old 8-bit texel on demand, for tests.
##
## LIGHT_SCALE: the old texture stored light at half strength, since pools of
## lamp light go above 1; light_at keeps that quantisation.
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
## This floor's lamps: {"at": Vector3, "color": Color, "radius": float}.
var lights: Array[Dictionary] = []

static func region(region_id: String) -> Dictionary:
	return REGIONS.get(region_id, REGIONS.city)

## Sets this floor's lamps up as the LightRig and keeps what light_at needs.
## Nothing is baked: light_at works each texel out when asked.
func build(map: Node3D, lamp_list: Array[Dictionary]) -> void:
	lights = lamp_list
	_sync_rig(map)
	origin = map.SPINE_MIN - Vector2(36, 36)
	var size: Vector2 = (map.SPINE_MAX + Vector2(36, 36)) - origin
	columns = ceili(size.x / CELL)
	rows = ceili(size.y / CELL)
	_ambient = region(key(map)).ambient
	_lamps = lamp_list.duplicate()
	# The rock top as it stood at build (VaultSeal swaps the grids later and
	# builds again).
	_surface = map._surface
	_tops = _surface._top_grid
	_built = true
	apply(key(map))

## light_at over a fixed rectangle (the base, which has no terrain): `rect`
## in world x/z, lamps as in build(). Makes no LightRig.
func build_area(rect: Rect2, region_id: String, lamp_list: Array[Dictionary]) -> void:
	lights = lamp_list
	origin = rect.position
	columns = ceili(rect.size.x / CELL)
	rows = ceili(rect.size.y / CELL)
	_ambient = region(region_id).ambient
	_lamps = lamp_list.duplicate()
	_surface = null
	_built = true
	apply(region_id)

var _built := false
var _ambient := Color.WHITE
var _lamps: Array[Dictionary] = []
var _surface: TerrainSurface
var _tops := PackedFloat32Array()

## Light at x/z (for tests): ambient plus every lamp's reach summed for the
## texel holding `point`, quantised to 8 bits at LIGHT_SCALE as the old
## texture stored it.
func light_at(point: Vector2) -> Color:
	if not _built: return Color.WHITE
	var x := clampi(int((point.x - origin.x) / CELL), 0, columns - 1)
	var z := clampi(int((point.y - origin.y) / CELL), 0, rows - 1)
	var buffer := PackedFloat32Array([_ambient.r, _ambient.g, _ambient.b])
	var p := origin + Vector2(x + 0.5, z + 0.5) * CELL
	for lamp in _lamps:
		var at: Vector3 = lamp.at
		var colour: Color = lamp.color
		var radius: float = lamp.radius
		var cx := int((at.x - origin.x) / CELL)
		var cz := int((at.z - origin.y) / CELL)
		var span := ceili(radius / CELL)
		if z < maxi(0, cz - span) or z >= mini(rows, cz + span + 1) or x < maxi(0, cx - span) or x >= mini(columns, cx + span + 1): continue
		var d := p.distance_to(Vector2(at.x, at.z)) / radius
		if d >= 1.0: continue
		var reach := (1.0 - d * d) * (1.0 - d * d)
		if _surface != null:
			# Light falls off over a step in height: a lamp in a corridor
			# lights its floor, not the top of the bank beside it.
			var rise := absf(_top_at(p) - at.y + 1.0)
			# Smooth to zero at the rim: no edge, no ring.
			reach = (1.0 - d * d) * (1.0 - d * d) * clampf(1.0 - maxf(rise - 1.2, 0.0) / 2.4, 0.15, 1.0)
		buffer[0] += colour.r * reach
		buffer[1] += colour.g * reach
		buffer[2] += colour.b * reach
	var c := Color(_byte(buffer[0]) / 255.0, _byte(buffer[1]) / 255.0, _byte(buffer[2]) / 255.0)
	return Color(c.r * LIGHT_SCALE, c.g * LIGHT_SCALE, c.b * LIGHT_SCALE)

static func _byte(value: float) -> int:
	return clampi(int(value / LIGHT_SCALE * 255.0 + 0.5), 0, 255)

## TerrainSurface.top_at on the grid kept at build().
func _top_at(point: Vector2) -> float:
	if _tops.is_empty(): return _surface.ground_at(point)
	var s := _surface
	var cell := (point - s.origin) / TerrainSurface.CELL
	var x := clampi(int(floor(cell.x)), 0, s.columns - 1)
	var z := clampi(int(floor(cell.y)), 0, s.rows - 1)
	var fraction := (cell - Vector2(x, z)).clamp(Vector2.ZERO, Vector2.ONE)
	var ia := z * (s.columns + 1) + x
	var ha := _tops[ia]
	var hc := _tops[ia + s.columns + 2]
	if fraction.x >= fraction.y:
		return ha * (1.0 - fraction.x) + _tops[ia + 1] * (fraction.x - fraction.y) + hc * fraction.y
	return ha * (1.0 - fraction.y) + hc * fraction.x + _tops[ia + s.columns + 1] * (fraction.y - fraction.x)

## Sets the field globals. `texture` is never assigned now, so field_light is
## the white pixel; the shaders read only field_snow (and field_player, set by
## GameManager) today.
func apply(region_id: String) -> void:
	RenderingServer.global_shader_parameter_set("field_light", texture if texture != null else WHITE)
	RenderingServer.global_shader_parameter_set("field_light_rect", Vector4(origin.x, origin.y, columns * CELL, rows * CELL))
	var glow: Color = region(region_id).player
	RenderingServer.global_shader_parameter_set("field_player_light", Vector4(glow.r, glow.g, glow.b, float(region(region_id).player_radius)))
	RenderingServer.global_shader_parameter_set("field_snow", float(region(region_id).get("snow", 0.0)))

# --- Real lights (场景渲染统一改造案_v1 S3) ----------------------------------------
## Every lamp is lit by an OmniLight. Lamps whose light cannot reach within
## RIG_REACH of her are off, and no more than RIG_LIMIT stay on (Lungmen's
## neon streets went to 44 fps); the nearest RIG_SHADOWS cast shadows,
## re-picked every RIG_PICK seconds.
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
		# The old light texture added about the lamp's colour at its centre,
		# smooth to nothing at its radius: matched by energy ~ peak.
		rig.add_lamp(lamp.at, Color(c.r / peak, c.g / peak, c.b / peak), float(lamp.radius) * 1.15, clampf(peak * 1.6, 0.25, 1.6))
	rig.pick()

## The lights' Node: switches far lamps off and gives the near ones shadows.
## The lamps are kept as data (Lungmen has two thousand); the RIG_LIMIT on at
## once are a pool of OmniLights, each set to its lamp when picked.
class LightRig extends Node3D:
	var _wait := 0.0
	var _at := PackedVector3Array()
	var _color := PackedColorArray()
	var _range := PackedFloat32Array()
	var _energy := PackedFloat32Array()
	## The lamps on, in lamp order; and the pool light each is shown by.
	var _on := PackedInt32Array()
	var _shown := {}
	var _pool: Array[OmniLight3D] = []

	func add_lamp(at: Vector3, color: Color, reach: float, energy: float) -> void:
		_at.append(at)   # the generated root and the rig sit at the origin
		_color.append(color)
		_range.append(reach)
		_energy.append(energy)

	func _process(delta: float) -> void:
		_wait -= delta
		if _wait > 0.0: return
		_wait = FieldLight.RIG_PICK
		pick()

	func pick() -> void:
		var at := FieldLight.focus
		var to := global_transform if is_inside_tree() else transform
		var near: Array = []
		for i in range(_at.size()):
			var d := (to * _at[i]).distance_to(at)
			# Ranked by how near its pool's edge comes to her.
			if d < FieldLight.RIG_REACH + _range[i]: near.append([d - _range[i] * 0.5, i])
		near.sort_custom(func(a, b): return a[0] < b[0])
		var shadow := {}
		var on := PackedInt32Array()
		for k in range(mini(FieldLight.RIG_LIMIT, near.size())):
			on.append(near[k][1])
			shadow[near[k][1]] = k < FieldLight.RIG_SHADOWS
		on.sort()
		# Lamps still on keep their light; the rest of the pool is free.
		var kept := {}
		var free: Array[OmniLight3D] = []
		for lamp in _shown:
			if shadow.has(lamp): kept[lamp] = _shown[lamp]
			else: free.append(_shown[lamp])
		for light in _pool:
			if not kept.values().has(light) and not free.has(light): free.append(light)
		for lamp in on:
			var light: OmniLight3D = kept.get(lamp)
			if light == null:
				light = free.pop_back() if not free.is_empty() else _new_light()
				light.position = _at[lamp]
				light.light_color = _color[lamp]
				light.omni_range = _range[lamp]
				light.light_energy = _energy[lamp]
				kept[lamp] = light
			light.shadow_enabled = shadow[lamp]
			light.visible = true
		for light in free:
			light.visible = false
			light.shadow_enabled = false
		_on = on
		_shown = kept

	## A boss fight's lamps (BossShow): those within `radius` of `centre` pulled
	## `k` toward `tint` and their energy × `mult`; ungrade() puts them back.
	var _base_color := {}
	var _base_energy := {}
	func grade_near(centre: Vector3, radius: float, tint: Color, k: float, mult: float) -> void:
		var to := global_transform if is_inside_tree() else transform
		for i in range(_at.size()):
			if Vector2((to * _at[i]).x - centre.x, (to * _at[i]).z - centre.z).length() > radius: continue
			if not _base_color.has(i):
				_base_color[i] = _color[i]
				_base_energy[i] = _energy[i]
			_color[i] = (_base_color[i] as Color).lerp(tint, clampf(k, 0.0, 1.0))
			_energy[i] = float(_base_energy[i]) * mult
		_refresh()

	func ungrade() -> void:
		for i in _base_color:
			_color[i] = _base_color[i]
			_energy[i] = _base_energy[i]
		_base_color.clear()
		_base_energy.clear()
		_refresh()

	func _refresh() -> void:
		for lamp in _shown:
			var light: OmniLight3D = _shown[lamp]
			light.light_color = _color[lamp]
			light.light_energy = _energy[lamp]

	func _new_light() -> OmniLight3D:
		var o := OmniLight3D.new()
		o.omni_attenuation = 1.3
		o.light_specular = 0.3
		o.shadow_blur = 1.5
		add_child(o)
		_pool.append(o)
		return o

	## Tint for a self-lit sprite at `p`, as BaseMap.light_tint.
	func tint_at(p: Vector3, ambient: Color, pull: float) -> Color:
		var sum := Color(0, 0, 0)
		var weight := 0.0
		var to := global_transform if is_inside_tree() else transform
		for i in _on:
			var d := (to * _at[i]).distance_to(p)
			if d >= _range[i]: continue
			var w := _energy[i] * pow(1.0 - d / _range[i], 2.0)
			sum += _color[i] * w
			weight += w
		if weight <= 0.0: return ambient
		return ambient.lerp(sum / weight, clampf(weight * pull, 0.0, pull))

## Back to unlit (the base, camps): a white pixel over everything, no glow.
static func clear() -> void:
	RenderingServer.global_shader_parameter_set("field_light", WHITE)
	RenderingServer.global_shader_parameter_set("field_light_rect", Vector4(-100000, -100000, 200000, 200000))
	RenderingServer.global_shader_parameter_set("field_player_light", Vector4.ZERO)
	RenderingServer.global_shader_parameter_set("field_snow", 0.0)
