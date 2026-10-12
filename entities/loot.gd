class_name Loot
extends Node3D

## A drop on the ground, done the Grim Dawn way (用户 2026-10-10): the item's
## own icon pops out of whatever dropped it and lands nearby, and its name
## floats above it on a plate (drawn by Hud, which also handles the click).
## Nothing is picked up by walking over it — click the name, she walks there
## and takes it (GameManager.request_pickup), 赤金 included.
##
## Ported from DownfallPrototype.Loot; `item == null` (an old plain gold pile)
## is turned into a 赤金 stack on spawn so every drop is a real item.

var game: GameManager
var item: Item
var gold_value: int = 1
var pickup_delay := 0.0
var is_search_point := false
## Vault spoils stay sealed until the vault's guardian is dead, so the room is
## a fight rather than a free pickup at the end of a long walk.
var sealed := false

## The pop: from where it dropped (`from`, set by the spawner) in an arc to
## this node's resting position.
const FLY_SECONDS := 0.35
const FLY_HEIGHT := 1.1
## Ground icons are the inventory icons halved until they fit this many texels.
const GROUND_ICON_TEXELS := 20
var from := Vector3.INF
var _rest := Vector3.ZERO
var _fly := 0.0
var _sprite: Sprite3D

static var _ground_cache := {}

func _ready() -> void:
	add_to_group("loot")
	if item == null and not is_search_point:
		item = MaterialCatalog.create(Economy.GOLD_ID, maxi(1, gold_value), game.region_id if is_instance_valid(game) else "")
	if is_search_point:
		_build_search_point()
		return
	_sprite = Sprite3D.new()
	_sprite.texture = ground_texture(item)
	_sprite.pixel_size = CombatVfx.PIXEL
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.position.y = _sprite.texture.get_height() * CombatVfx.PIXEL * 0.5
	add_child(_sprite)
	var shadow := MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = 0.28
	disk.bottom_radius = 0.28
	disk.height = 0.01
	shadow.mesh = disk
	shadow.material_override = CombatVfx.material(CombatVfx.SHADOW, 0.35)
	shadow.position.y = -0.08
	add_child(shadow)
	if is_notable(): _add_beam(item.rarity_color())

func _build_search_point() -> void:
	add_to_group("search_points")
	var mesh := MeshInstance3D.new()
	var chest := BoxMesh.new()
	chest.size = Vector3(1.25, 0.8, 0.85)
	mesh.mesh = chest
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("827357")
	mesh.material_override = mat
	add_child(mesh)
	var label := Label3D.new()
	label.text = "补给箱"
	label.position.y = 1.1
	label.font_size = 24
	label.pixel_size = 0.01
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

## The item's inventory icon at ground size: halved (box filter) until it is
## at most GROUND_ICON_TEXELS on its long side, alpha kept hard. Falls back to
## a small rarity-coloured chip for an item without an icon.
static func ground_texture(of: Item) -> Texture2D:
	var source := ItemIcons.texture_for(of)
	var key := source.resource_path if source != null else "chip:" + of.rarity_color().to_html()
	if _ground_cache.has(key): return _ground_cache[key]
	var image: Image
	if source == null:
		image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
		image.fill(CombatVfx.SHADOW)
		image.fill_rect(Rect2i(1, 1, 6, 6), of.rarity_color())
	else:
		image = source.get_image().duplicate()
		if image.is_compressed(): image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		# Premultiply so transparent texels do not darken the edges, average
		# down (the walk sheets' BOX treatment), then make alpha hard again.
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var c := image.get_pixel(x, y)
				image.set_pixel(x, y, Color(c.r * c.a, c.g * c.a, c.b * c.a, c.a))
		while maxi(image.get_width(), image.get_height()) > GROUND_ICON_TEXELS and mini(image.get_width(), image.get_height()) >= 4:
			image.shrink_x2()
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var c := image.get_pixel(x, y)
				if c.a < 0.5: image.set_pixel(x, y, Color(0, 0, 0, 0))
				else: image.set_pixel(x, y, Color(c.r / c.a, c.g / c.a, c.b / c.a, 1.0).clamp())
	var texture := ImageTexture.create_from_image(image)
	_ground_cache[key] = texture
	return texture

## Rare equipment, special gear and ★4+ materials get a light beam (掉落物策划案 §6).
func is_notable() -> bool:
	if item == null: return false
	if not item.special.is_empty() or not item.exclusive_region.is_empty(): return true
	if not item.material_id.is_empty(): return MaterialCatalog.star(item.material_id) >= 4
	return item.is_equippable() and item.rarity >= 2

func _add_beam(color: Color) -> void:
	var beam := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	var tall := not item.special.is_empty()
	shape.top_radius = 0.06
	shape.bottom_radius = 0.12
	shape.height = 5.0 if tall else 3.0
	beam.mesh = shape
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color = Color(color, 0.45)
	glow.emission_enabled = true
	glow.emission = color
	beam.material_override = glow
	beam.position.y = shape.height * 0.5
	add_child(beam)
	if is_instance_valid(game) and game.sound != null: game.sound.play("build")

## Whether it has finished popping out and can be taken.
func landed() -> bool:
	return _fly >= FLY_SECONDS or from == Vector3.INF

func _process(delta: float) -> void:
	if is_instance_valid(game) and not game.simulation_active(): return
	pickup_delay -= delta
	if from == Vector3.INF or _fly >= FLY_SECONDS: return
	if _fly == 0.0: _rest = global_position
	_fly = minf(FLY_SECONDS, _fly + delta)
	var t := _fly / FLY_SECONDS
	var at := from.lerp(_rest, t)
	at.y = lerpf(from.y, _rest.y, t) + sin(t * PI) * FLY_HEIGHT
	global_position = at if t < 1.0 else _rest

## Taken by the player, who has walked to it. False (and it stays) when the
## pack has no room; a partly taken stack keeps the rest on the ground.
func collect() -> bool:
	if sealed or item == null or not is_instance_valid(game): return false
	if game.try_collect(item):
		queue_free()
		return true
	if item.is_stackable() and item.quantity <= 0:
		queue_free()
		return true
	return false
