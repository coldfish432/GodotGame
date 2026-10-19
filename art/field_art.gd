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
static func has_directional(enemy_type: String) -> bool:
	return dir_tips(enemy_type).size() == 8 and ResourceLoader.exists(_directional_path(enemy_type))

## Each column's charge-pose weapon tip, in texels from the foot-line centre.
static func dir_tips(enemy_type: String) -> Array:
	if EnemyDirectionalData.TIPS.has(enemy_type): return EnemyDirectionalData.TIPS[enemy_type]
	return EnemyN2Data.TIPS.get(enemy_type, [])

static func _directional_path(enemy_type: String) -> String:
	return "res://art/field/enemy_dir_%s_64.png" % enemy_type

static func enemy_dir_pose(enemy_type: String, column: int, pose: int) -> AtlasTexture:
	var key := "enemy_dir/%s/%d/%d" % [enemy_type, column, pose]
	if not _frames.has(key):
		var atlas := AtlasTexture.new()
		atlas.atlas = load(_directional_path(enemy_type))
		atlas.region = Rect2(column * 64, pose * 64, 64, 64)
		atlas.filter_clip = true
		_frames[key] = atlas
	return _frames[key]

## Eight-direction walk sheets: same columns, rows are the four walk frames
## (contact A, pass A, contact B, pass B). Anchored exactly like the attack sheet.
static func has_walk(enemy_type: String) -> bool:
	return (EnemyDirectionalData.WALK.has(enemy_type) or EnemyN2Data.WALK.has(enemy_type)) and ResourceLoader.exists(_walk_path(enemy_type))

static func _walk_path(enemy_type: String) -> String:
	return "res://art/field/enemy_walk_%s_64.png" % enemy_type

static func enemy_walk_pose(enemy_type: String, column: int, frame: int) -> AtlasTexture:
	var key := "enemy_walk/%s/%d/%d" % [enemy_type, column, frame]
	if not _frames.has(key):
		var atlas := AtlasTexture.new()
		atlas.atlas = load(_walk_path(enemy_type))
		atlas.region = Rect2(column * 64, frame * 64, 64, 64)
		atlas.filter_clip = true
		_frames[key] = atlas
	return _frames[key]

static func enemy_pose(row: int, pose: int) -> AtlasTexture:
	var key := "enemy_pose/%d/%d" % [row, pose]
	if not _frames.has(key):
		var atlas := AtlasTexture.new()
		atlas.atlas = ENEMY_ATTACKS
		atlas.region = Rect2(pose * 64, row * 64, 64, 64)
		atlas.filter_clip = true
		_frames[key] = atlas
	return _frames[key]

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

static func painted(name: String) -> Texture2D:
	var path := PAINTED_DIR + name + ".png"
	return load(path) if ResourceLoader.exists(path) else null

static func terrain_material(region: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D atlas : source_color, filter_nearest;
uniform sampler2D background_tex : source_color, filter_nearest_mipmap, repeat_disable;
uniform float world_scale = 12.0;
uniform float region = 0.0;
// Painted road (C1) and the pavement along the kerb (C2), when delivered.
uniform bool painted = false;
// Mipmapped: at the follow camera a metre is ~30 screen pixels against the
// swatch's 43, and unfiltered the grain broke up into noise.
uniform sampler2D road_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D kerb_tex : source_color, filter_nearest_mipmap, repeat_enable;
// Sol's asphalt is painted darker than the road it replaces; lifted to match.
uniform float road_gain = 1.75;
uniform float kerb_gain = 0.92;
uniform float road_scale = 6.0;
// How far the painted road is pulled to flat grey (Sol's asphalt patches read
// as camouflage at the game's zoom).
uniform float road_flat = 0.45;
uniform float kerb_scale = 3.0;
varying vec3 world_position;
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
  ALBEDO = mix(slabs, asphalt * COLOR.rgb / 0.3, step(0.92, COLOR.a)) * UV2.x;
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
 ROUGHNESS = 1.0;
}
"""
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
	elif stone:
		material.set_shader_parameter("road_scale", 3.0)
		material.set_shader_parameter("road_flat", 0.15)
	if road != null and kerb != null:
		material.set_shader_parameter("painted", true)
		material.set_shader_parameter("road_tex", road)
		material.set_shader_parameter("kerb_tex", kerb)
	return material

static func ground_material(region: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded;
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
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("atlas", GROUND)
	material.set_shader_parameter("region", float(["mine", "city", "snow"].find(FieldCatalog.art_region(region))))
	return material
