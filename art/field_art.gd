class_name FieldArt
extends RefCounted

const ENEMIES = preload("res://art/field/enemies_v1.png")
const ENEMY_ATTACKS = preload("res://art/field/enemy_attacks_64.png")
const PROPS = preload("res://art/field/props_v1.png")
const GROUND = preload("res://art/field/ground_v1.png")
const SCENE_GROUPS = preload("res://art/field/scene_groups_v2.png")
const BACKGROUNDS = {
	"mine": preload("res://art/field/surface_mine_v2.png"),
	"city": preload("res://art/field/surface_city_v2.png"),
	"snow": preload("res://art/field/surface_snow_v2.png"),
}
const BACKGROUND_SHADER = preload("res://art/terrain_background.gdshader")
static var _frames := {}

static func frame(texture: Texture2D, columns: int, rows: int, column: int, row: int) -> AtlasTexture:
	var key := "%s/%d/%d" % [texture.resource_path, column, row]
	if _frames.has(key): return _frames[key]
	var image := texture.get_image()
	var start := Vector2i(floori(float(image.get_width()) * column / columns), floori(float(image.get_height()) * row / rows))
	var end := Vector2i(floori(float(image.get_width()) * (column + 1) / columns), floori(float(image.get_height()) * (row + 1) / rows))
	var cell := image.get_region(Rect2i(start, end - start))
	var content := cell.get_used_rect()
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(content.position + start, content.size)
	atlas.filter_clip = true
	_frames[key] = atlas
	return atlas

static func enemy(region: String, elite: bool, ranged: bool) -> AtlasTexture:
	return frame(ENEMIES, 3, 3, 2 if elite else (1 if ranged else 0), ["mine", "city", "snow"].find(FieldCatalog.art_region(region)))

## Eight-direction sheets baked by art/prepare_enemy_directional.py. Columns
## S, SW, W, NW, N, NE, E, SE; rows idle, startup, charge, strike, recovery.
## Enemies without a board yet keep the side-view sheet (enemy_pose).
## The new enemies' sheets (art/install_n2_boards.py, EnemyN2Data) play the same way.
## A boss's 84 px badge for the intro band (Sol B3), or null until it is in.
static func boss_badge(figure_id: String) -> Texture2D:
	var path := "res://ui/art/boss_%s_badge.png" % figure_id
	return load(path) if ResourceLoader.exists(path) else null

static func has_directional(enemy_type: String) -> bool:
	return dir_tips(enemy_type).size() == 8 and ResourceLoader.exists(_directional_path(enemy_type))

## Each column's charge-pose weapon tip, in texels from the foot-line centre.
static func dir_tips(enemy_type: String) -> Array:
	if EnemyDirectionalData.TIPS.has(enemy_type): return EnemyDirectionalData.TIPS[enemy_type]
	return EnemyN2Data.TIPS.get(enemy_type, [])

static func _directional_path(enemy_type: String) -> String:
	return "res://art/field/enemy_dir_%s_64.png" % enemy_type

static func enemy_dir_pose(enemy_type: String, column: int, pose: int) -> AtlasTexture:
	# Asked for every frame by every enemy: by sheet, then column and pose as
	# one int, kept in _frames so they go with it (no key string each call).
	var sheet: Dictionary = _sheet(&"enemy_dir", enemy_type)
	var key := column * 1024 + pose
	if not sheet.has(key):
		var atlas := AtlasTexture.new()
		atlas.atlas = load(_directional_path(enemy_type))
		atlas.region = Rect2(column * 64, pose * 64, 64, 64)
		atlas.filter_clip = true
		sheet[key] = atlas
	return sheet[key]

## _frames' table for one kind of sheet and one enemy type.
static func _sheet(kind: StringName, enemy_type: String) -> Dictionary:
	var kinds: Dictionary = _frames.get(kind, {})
	if kinds.is_empty(): _frames[kind] = kinds
	var sheet: Dictionary = kinds.get(enemy_type, {})
	if sheet.is_empty(): kinds[enemy_type] = sheet
	return sheet

## Eight-direction walk sheets: same columns, rows are the four walk frames
## (contact A, pass A, contact B, pass B). Anchored exactly like the attack sheet.
static func has_walk(enemy_type: String) -> bool:
	return (EnemyDirectionalData.WALK.has(enemy_type) or EnemyN2Data.WALK.has(enemy_type)) and ResourceLoader.exists(_walk_path(enemy_type))

static func _walk_path(enemy_type: String) -> String:
	return "res://art/field/enemy_walk_%s_64.png" % enemy_type

static func enemy_walk_pose(enemy_type: String, column: int, frame: int) -> AtlasTexture:
	var sheet: Dictionary = _sheet(&"enemy_walk", enemy_type)
	var key := column * 1024 + frame
	if not sheet.has(key):
		var atlas := AtlasTexture.new()
		atlas.atlas = load(_walk_path(enemy_type))
		atlas.region = Rect2(column * 64, frame * 64, 64, 64)
		atlas.filter_clip = true
		sheet[key] = atlas
	return sheet[key]

static func enemy_pose(row: int, pose: int) -> AtlasTexture:
	var sheet: Dictionary = _sheet(&"enemy_pose", "")
	var key := row * 1024 + pose
	if not sheet.has(key):
		var atlas := AtlasTexture.new()
		atlas.atlas = ENEMY_ATTACKS
		atlas.region = Rect2(pose * 64, row * 64, 64, 64)
		atlas.filter_clip = true
		sheet[key] = atlas
	return sheet[key]

static func prop(parent: Node3D, region: String, index: int, position: Vector3, height: float, flip: bool = false) -> Sprite3D:
	return _make_prop(parent, frame(PROPS, 4, 3, index, ["mine", "city", "snow"].find(FieldCatalog.art_region(region))), position, height, flip)

static func scene_prop(parent: Node3D, region: String, index: int, position: Vector3, height: float, flip: bool = false) -> Sprite3D:
	var row := ["mine", "city", "snow"].find(FieldCatalog.art_region(region))
	var key := "scene_group/%d/%d" % [row, index]
	if not _frames.has(key):
		var image := SCENE_GROUPS.get_image()
		# Authored gutters of this generated atlas are not evenly spaced in Y.
		# Crop at the actual empty bands to preserve rubble/snow at the feet.
		var ys := [0, 465, 834, 1254]
		var start := Vector2i(image.get_width() * index / 3, ys[row])
		var end := Vector2i(image.get_width() * (index + 1) / 3, ys[row + 1])
		var cell := image.get_region(Rect2i(start, end - start))
		var content := cell.get_used_rect()
		var atlas := AtlasTexture.new()
		atlas.atlas = SCENE_GROUPS
		atlas.region = Rect2(content.position + start, content.size)
		atlas.filter_clip = true
		_frames[key] = atlas
	return _make_prop(parent, _frames[key], position, height, flip)

static func _make_prop(parent: Node3D, texture: Texture2D, position: Vector3, height: float, flip: bool) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.name = "FieldProp"
	sprite.texture = texture
	sprite.pixel_size = height / sprite.texture.get_height()
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.no_depth_test = false
	sprite.shaded = false
	sprite.flip_h = flip
	# Keep the lower edge at the authored ground anchor, including when the
	# billboard turns toward an overview camera. The old height * .43 offset
	# floated the sprite foot above and in front of the sampled ground.
	sprite.offset.y = sprite.texture.get_height() * 0.5
	parent.add_child(sprite)
	sprite.position = position
	sprite.add_to_group("field_props")
	return sprite

## NPC idles from art/characters/npc/prepare_npc.py: 4 frames side by side,
## feet 2 px above the frame bottom, 3 fps.
const NPC_IDLES := {
	"melee": "res://art/characters/npc/npc_squad_melee_idle.png",
	"sniper": "res://art/characters/npc/npc_squad_sniper_idle.png",
	"logistics": "res://art/characters/npc/npc_squad_logistics_idle.png",
	"trader": "res://art/characters/npc/npc_cannot_idle.png",
	"closure": "res://art/characters/npc/npc_closure_idle.png",
}
const NPC_FRAMES := 4
const NPC_FEET_PX := 2

## An NPC's idle billboard at the game's sprite scale (1/15 unit a texel),
## playing. Its origin is under the feet.
static func npc_idle(kind: String) -> AnimatedSprite3D:
	var sheet: Texture2D = load(NPC_IDLES[kind])
	var w := sheet.get_width() / NPC_FRAMES
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", 3.0)
	frames.set_animation_loop("default", true)
	for i in range(NPC_FRAMES):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * w, 0, w, sheet.get_height())
		frames.add_frame("default", atlas)
	var sprite := AnimatedSprite3D.new()
	sprite.name = "Npc"
	sprite.sprite_frames = frames
	sprite.pixel_size = 1.0 / 15.0
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	sprite.offset.y = sheet.get_height() * 0.5 - NPC_FEET_PX
	sprite.play("default")
	return sprite

static func background_material(region: String) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = BACKGROUND_SHADER
	region = FieldCatalog.art_region(region)
	material.set_shader_parameter("background_tex", BACKGROUNDS[region])
	material.set_shader_parameter("world_scale", 12.0)
	material.set_shader_parameter("brightness", 0.82 if region != "snow" else 0.72)
	return material

## Hand-painted swatches from Sol (城市贴图美术需求_v1.md): the slot is in
## place before the art is. Null until the file is delivered; every user
## falls back to the procedural look it has now.
const PAINTED_DIR := "res://art/kit/textures/painted/"
## Regions whose walkable floor is Sol's painted <region>_floor.png (缺图补全美术需求_v1.md
## M1), drawn instead of the old atlas. 萨米 keeps its old floor (用户 2026-10-26:
## 还是用左面的吧，用旧图); Sol's snow_floor.png stays in painted/, unused.
const PAINTED_FLOORS := ["mine"]
## How far the painted floor leans to the path's vertex colour, and how much
## darker it lies off the walked path.
const FLOOR_PATH := 0.22
const FLOOR_OFF_PATH := 0.72
## Sol's floors are painted darker than the lit path they replace (the mine's
## light is dim): lifted so the walkable ground still reads at a glance.
const FLOOR_GAIN := {"mine": 1.9, "snow": 1.0}

static func painted(name: String) -> Texture2D:
	var path := PAINTED_DIR + name + ".png"
	return load(path) if ResourceLoader.exists(path) else null

## Per floor look (FieldLight.key): the ground's gain and how wet it is.
const GROUND_LOOK := {
	"city_lower": {"ground_gain": 0.88, "wet": 1.0},
	"siracusa": {"ground_gain": 0.72},
	"siracusa_rain": {"ground_gain": 0.68, "wet": 0.7},
}

static func terrain_material(region: String, look := "") -> ShaderMaterial:
	var ground: Dictionary = GROUND_LOOK.get(look if not look.is_empty() else region, {})
	# One Shader for every floor (its code never changes; the material and its
	# parameters are still per floor), kept in _frames to be released with it.
	var shader: Shader = _frames.get(&"terrain_shader")
	if shader == null:
		shader = Shader.new()
		shader.code = """shader_type spatial;
render_mode cull_disabled;
uniform sampler2D atlas : source_color, filter_linear;
uniform sampler2D background_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float world_scale = 12.0;
uniform float region = 0.0;
// Painted road (C1) and the pavement along the kerb (C2), when delivered.
uniform bool painted = false;
// Mipmapped: at the follow camera a metre is ~30 screen pixels against the
// swatch's 43, and unfiltered the grain broke up into noise.
uniform sampler2D road_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D kerb_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// Sol's asphalt is painted darker than the road it replaces; lifted to match.
uniform float road_gain = 1.75;
uniform float kerb_gain = 0.92;
// COLOR.a above which the road surface runs; below it is the kerb strip.
// 叙拉古 sets it below zero: one paving from kerb to kerb.
uniform float kerb_edge = 0.92;
uniform float road_scale = 6.0;
// How far the painted road is pulled to flat grey (Sol's asphalt patches read
// as camouflage at the game's zoom).
uniform float road_flat = 0.45;
uniform float kerb_scale = 3.0;
// The floor's material (龙门城区与叙拉古地图改造案 v1.1): the ground a shade
// darker (ground_gain), and wet — the whole street a little glossier, and
// puddles in slow patches, darker and nearly mirror.
uniform float ground_gain = 1.0;
uniform float wet = 0.0;
// Sol's painted floor (PAINTED_FLOORS): tiled as it is, a little of the path's
// vertex colour over it, darker off the walked path.
uniform bool own_floor = false;
uniform sampler2D floor_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float floor_scale = 5.0;
uniform float floor_path = 0.22;
uniform float floor_off = 0.72;
uniform float floor_gain = 1.0;
varying vec3 world_position;
float wet_hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float wet_noise(vec2 p) {
 vec2 i = floor(p);
 vec2 f = fract(p);
 f = f * f * (3.0 - 2.0 * f);
 return mix(mix(wet_hash(i), wet_hash(i + vec2(1.0, 0.0)), f.x), mix(wet_hash(i + vec2(0.0, 1.0)), wet_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
#include "res://art/terrain_sampling.gdshaderinc"
#include "res://world/field_light.gdshaderinc"
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 if (painted) {
  // COLOR.a runs 0 at the kerb to 1 some 1.4 m into the road: that strip
  // is the pavement, hard-edged like the rest of the pixel art.
  // Sol's patches read as camouflage at the game's zoom: halfway to flat.
  vec3 asphalt = mix(texture(road_tex, world_position.xz / road_scale).rgb, vec3(0.2, 0.215, 0.23), road_flat) * road_gain;
  vec3 slabs = texture(kerb_tex, world_position.xz / kerb_scale).rgb * kerb_gain;
  // The district's road colour (CityDressing.ROAD_TINTS) carried in COLOR.rgb.
  ALBEDO = mix(slabs, asphalt * COLOR.rgb / 0.3, step(kerb_edge, COLOR.a)) * UV2.x;
  ALBEDO = field_lit_px(ALBEDO, world_position, FRAGCOORD.xy);
 } else if (own_floor) {
  vec3 f = texture(floor_tex, world_position.xz / floor_scale).rgb * floor_gain;
  float into = region == 1.0 ? 1.0 : COLOR.a;
  vec3 walked = mix(f, COLOR.rgb * (0.6 + 0.8 * dot(f, vec3(0.3, 0.59, 0.11))), floor_path);
  ALBEDO = mix(f * floor_off, walked, into) * UV2.x;
  ALBEDO = field_lit_px(ALBEDO, world_position, FRAGCOORD.xy);
 } else {
 vec2 tile = fract(world_position.xz / 5.0);
 vec2 coord = vec2((region + mix(0.002, 0.998, tile.x)) / 3.0, mix(0.002, 0.998, tile.y));
 vec3 tex = texture(atlas, coord).rgb;
 float grain = dot(tex, vec3(0.3, 0.59, 0.11));
 vec3 debris = surface_texture(world_position.xz);
 vec3 road = COLOR.rgb * mix(0.85, 1.1, grain);
 // Vertex alpha carries distance into the road, not transparency: debris
 // softens the join while the walkable corridor keeps its readable value.
 // The city keeps no darkened rim: its kerbs are flush (COLOR.a still marks
 // the pavement strip for the painted road).
 float into_road = region == 1.0 ? 1.0 : COLOR.a;
 ALBEDO = mix(debris * 0.70, mix(road, debris * 0.85, 0.32), into_road);
 // Terrace light from TerrainSurface: tier, cliff-foot shadow, cliff lip.
 ALBEDO *= UV2.x;
 ALBEDO = field_lit_px(ALBEDO, world_position, FRAGCOORD.xy);
 }
 float puddle = wet * smoothstep(0.62, 0.7, wet_noise(world_position.xz / 3.5) * 0.7 + wet_noise(world_position.xz / 1.3) * 0.3);
 ALBEDO *= ground_gain * mix(1.0, 0.72, puddle);
 ROUGHNESS = mix(mix(0.95, 0.6, wet), 0.12, puddle);
 SPECULAR = mix(mix(0.2, 0.35, wet), 0.6, puddle);
}
"""
		_frames[&"terrain_shader"] = shader
	var material := ShaderMaterial.new()
	material.shader = shader
	# 叙拉古 lays Lungmen's paving slabs wall to wall (叙拉古方案 §2.1: 石板路，
	# 宽街也是石板): its road is the pavement texture, tinted by family.
	# Its own paving (叙拉古贴图美术需求_v1.md S1; a stand-in until Sol's) when
	# there is one, else Lungmen's pavement slabs.
	var stone := region == "siracusa"
	var own := painted(region + "_road") if stone else null
	region = FieldCatalog.art_region(region)
	material.set_shader_parameter("atlas", GROUND)
	material.set_shader_parameter("background_tex", BACKGROUNDS[region])
	material.set_shader_parameter("region", float(["mine", "city", "snow"].find(region)))
	var road := painted(region + ("_pavement" if stone else "_road"))
	var kerb := painted(region + "_pavement")
	if own != null:
		road = own
		kerb = own
		material.set_shader_parameter("road_scale", 6.0)
		material.set_shader_parameter("kerb_scale", 6.0)
		material.set_shader_parameter("road_flat", 0.0)
		material.set_shader_parameter("kerb_edge", -1.0)
	elif stone:
		material.set_shader_parameter("road_scale", 3.0)
		material.set_shader_parameter("road_flat", 0.15)
	var floor := painted(region + "_floor") if region in PAINTED_FLOORS else null
	if floor != null:
		material.set_shader_parameter("own_floor", true)
		material.set_shader_parameter("floor_tex", floor)
		material.set_shader_parameter("floor_path", FLOOR_PATH)
		material.set_shader_parameter("floor_off", FLOOR_OFF_PATH)
		material.set_shader_parameter("floor_gain", float(FLOOR_GAIN.get(region, 1.0)))
	if road != null and kerb != null:
		material.set_shader_parameter("painted", true)
		material.set_shader_parameter("road_tex", road)
		material.set_shader_parameter("kerb_tex", kerb)
	for key in ground: material.set_shader_parameter(key, ground[key])
	return material

static func ground_material(region: String) -> ShaderMaterial:
	var shader: Shader = _frames.get(&"ground_shader")
	if shader == null:
		shader = Shader.new()
		shader.code = """shader_type spatial;
render_mode cull_back;
uniform sampler2D atlas : source_color, filter_nearest;
uniform float region = 0.0;
uniform float brightness = 0.8;
void fragment() {
 vec2 tile = fract(UV * 10.0);
 vec2 atlas_uv = vec2((region + mix(0.002, 0.998, tile.x)) / 3.0, mix(0.002, 0.998, tile.y));
 ALBEDO = texture(atlas, atlas_uv).rgb * brightness;
 ROUGHNESS = 1.0;
}
"""
		_frames[&"ground_shader"] = shader
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("atlas", GROUND)
	material.set_shader_parameter("region", float(["mine", "city", "snow"].find(FieldCatalog.art_region(region))))
	return material
