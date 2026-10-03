class_name BaseMap
extends Node3D

## Rhodes Island home base: one continuous, walkable map built from the static
## pixel assemblies in art/rhodes/ (exported by art/rhodes/export_runtime.py).
##
## Each room comes with three layers that reproduce the assembly 1:1 at the
## game camera (ortho size 24 over 360 px, pitch atan(16/10)):
##   ground  - one flat quad: floor, decals, light pools, wall tops.
##             15 px per unit across, 12.7 px per unit down the screen.
##   facade  - the north wall face, a camera-facing billboard standing on the
##             wall line.
##   sprites - one billboard per prop, standing on its feet so it occludes and
##             is occluded by Lappland. Overhead items (hoists, beams) skip the
##             depth test and always draw on top.
## Facades and overhead items cut a checkerboard hole around Lappland while
## they cover her (world/base_see_through.gdshaderinc).
## The layout is authored with x growing east (screen right). With the game's
## camera, screen right is world -X, so every layout x is mirrored.
## The base sits far from the field origin so it never overlaps a field map.

const DATA_DIR := "res://art/rhodes_runtime/"
const ROOMS := ["hall", "warehouse", "medical", "store", "armory"]
const ORIGIN := Vector3(0, 0, -400)
const EAST := -1.0
const PX := 1.0 / 15.0
const GROUND_PX_PER_UNIT := 12.7
## Lappland's billboard pivots 0.96 above her feet, so it depth-sorts as if
## she stood ~1.5 units further south. Props pivot at the same height and
## shift their image down to match; sorting then compares feet with feet.
const SORT_PIVOT_Y := 0.96
const PIVOT_SCREEN_PX := SORT_PIVOT_Y * 0.5300 * 15.0  # 0.53 = cos(58°), the screen rise per unit height
const INTERACT_RANGE := 3.0
const SEE_THROUGH := preload("res://world/base_see_through.gdshader")
const SEE_THROUGH_OVERHEAD := preload("res://world/base_see_through_overhead.gdshader")
const FLOOR_SHADER := preload("res://world/base_floor.gdshader")
## The game camera never yaws or pitches, so a quad turned to this basis once
## is a billboard (same orientation Sprite3D's billboard mode produces).
static var CAMERA_BASIS := Basis.looking_at(Vector3(0, -16, 10).normalized(), Vector3.UP)
const PLAYER_Y := 0.7

var interactables: Array[Dictionary] = []  # {id, kind, label, position}
var spawns := {}
var rooms := {}
var _navigation: NavigationRegion3D
var _textures := {}
## Lappland; occluders cut a see-through hole around her (see base_see_through.gdshaderinc).
var player: Node3D
var _see_through: Array[ShaderMaterial] = []
## Per room: what dims with its lights, and sprites grouped by their export tag.
## {room_id: {"shaders": [ShaderMaterial] (floor, decals, north wall, overhead), "sprites": [Sprite3D], "groups": {name: [Sprite3D]}}}
var room_visuals := {}
## Entering the warehouse lights it in steps and raises the personal-storage shelves.
var warehouse_reveal: RoomReveal

func _process(_delta: float) -> void:
	if not is_instance_valid(player): return
	var center := player.global_position + Vector3(0, 0.31, 0)  # body origin 0.65 + 0.31 = sprite centre
	for material in _see_through:
		material.set_shader_parameter("player_center", center)

func _ready() -> void:
	position = ORIGIN
	_navigation = NavigationRegion3D.new()
	add_child(_navigation)
	_build_backdrop()
	for key in ROOMS:
		var path: String = DATA_DIR + "room_%s.json" % key
		if not FileAccess.file_exists(path):
			push_warning("Base room data missing: " + path)
			continue
		var room: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		rooms[key] = room
		_build_room(room)
	var nav_mesh := NavigationMesh.new()
	nav_mesh.agent_height = 1.5
	nav_mesh.agent_radius = 0.75
	nav_mesh.agent_max_climb = 0.5
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	_navigation.navigation_mesh = nav_mesh
	_navigation.bake_navigation_mesh(false)
	if rooms.has("warehouse"):
		warehouse_reveal = RoomReveal.new()
		warehouse_reveal.setup(self, "warehouse", "shelf:")
		add_child(warehouse_reveal)
	set_active(false)

## Layout coordinates (x east, z north, ground units) to a global position.
func to_world(x: float, z: float, y: float = 0.0) -> Vector3:
	return ORIGIN + Vector3(EAST * x, y, z)

func set_active(active: bool) -> void:
	visible = active
	_navigation.enabled = active
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	# Every return starts with the warehouse dark and its shelves stowed.
	if active and warehouse_reveal: warehouse_reveal.reset()

func spawn_point(name: String) -> Vector3:
	var p: Array = spawns.get(name, spawns.get("arrival", [64.0, -53.0]))
	return to_world(p[0], p[1], PLAYER_Y)

## Keeps a 640×360 view from showing the void past the outer walls.
## Half a screen is 320 px = 21.3 units across and 180 px ≈ 14.2 units down the ground.
func clamp_camera(target: Vector3) -> Vector3:
	var local := target - ORIGIN
	var east := EAST * local.x
	var bounds := _bounds()
	east = clampf(east, bounds.position.x + 21.3, maxf(bounds.position.x + 21.3, bounds.end.x - 21.3))
	local.z = clampf(local.z, bounds.position.y + 13.6, maxf(bounds.position.y + 13.6, bounds.end.y - 6.0))
	return ORIGIN + Vector3(EAST * east, local.y, local.z)

var _cached_bounds := Rect2()
## Layout-space extent of all ground quads: x east, y = z north.
func _bounds() -> Rect2:
	if _cached_bounds.has_area(): return _cached_bounds
	for room in rooms.values():
		var g: Dictionary = room.ground
		var r := Rect2(g.x, g.z - g.h_px / GROUND_PX_PER_UNIT, g.w_px * PX, g.h_px / GROUND_PX_PER_UNIT)
		_cached_bounds = r if not _cached_bounds.has_area() else _cached_bounds.merge(r)
	return _cached_bounds

func navigation_map_rid() -> RID:
	return _navigation.get_navigation_map()

## Whether a global position stands on the room's floor (layout rectangle from its origin and size).
func room_contains(room_id: String, global: Vector3, margin: float = 0.0) -> bool:
	var room: Dictionary = rooms.get(room_id, {})
	if room.is_empty(): return false
	var x := (global.x - ORIGIN.x) / EAST
	var z := global.z - ORIGIN.z
	return x > room.origin[0] + margin and x < room.origin[0] + room.size[0] - margin 		and z < room.origin[1] - margin and z > room.origin[1] - room.size[1] + margin

## Room lights in strips across the room. `edges` are the layout x of the
## west edges of strips 0, 1 and 2 (strip 0 is the easternmost), `levels` the
## light level of strips 0..3. Floors, walls and overhead items do this per
## pixel (base_room_light.gdshaderinc); props take the level of the strip they stand in.
func set_room_bands(room_id: String, edges: Array, levels: Array) -> void:
	var visuals: Dictionary = room_visuals.get(room_id, {})
	if visuals.is_empty(): return
	visuals.bands = [edges, levels]  # for props and decals added later
	for material: ShaderMaterial in visuals.shaders: _light_material(material, edges, levels)
	for sprite: Sprite3D in visuals.sprites: _light_sprite(sprite, edges, levels)

func _light_material(material: ShaderMaterial, edges: Array, levels: Array) -> void:
	var world_edges := Vector3.ZERO
	for k in range(3): world_edges[k] = ORIGIN.x + EAST * float(edges[k])
	material.set_shader_parameter("band_edges", world_edges)
	material.set_shader_parameter("band_sign", EAST)
	material.set_shader_parameter("band_levels", Vector4(levels[0], levels[1], levels[2], levels[3]))

func _light_sprite(sprite: Sprite3D, edges: Array, levels: Array) -> void:
	var strip := 0
	for k in range(3):
		if sprite.position.x * EAST < float(edges[k]): strip = k + 1
	var level: float = levels[strip]
	sprite.modulate = Color(level, level, level)

## A prop added at run time (a receiving crate, a staging pallet): a billboard
## standing on its feet at layout (x, z), lit like the rest of the room. Moving
## it later is the caller's business; it keeps the light of where it was added.
func add_prop(room_id: String, texture: Texture2D, x: float, z: float, lift_px: float = 0.0) -> Sprite3D:
	var sprite := _billboard(texture, x, z, lift_px)
	get_node(NodePath(room_id)).add_child(sprite)
	var visuals: Dictionary = room_visuals[room_id]
	visuals.sprites.append(sprite)
	if visuals.has("bands"): _light_sprite(sprite, visuals.bands[0], visuals.bands[1])
	return sprite

## Removes a prop added with add_prop().
func remove_prop(room_id: String, sprite: Sprite3D) -> void:
	room_visuals[room_id].sprites.erase(sprite)
	sprite.queue_free()

## Puts a billboard's image bottom on the feet at (x, z) again after its texture
## or lift changed (same placement as _billboard()).
func place_billboard(sprite: Sprite3D, x: float, z: float, lift_px: float = 0.0) -> void:
	sprite.position = Vector3(EAST * x, SORT_PIVOT_Y, z)
	sprite.offset = Vector2(0, sprite.texture.get_height() * 0.5 + lift_px - PIVOT_SCREEN_PX)

## A flat image on the floor of a room, in front of everything on the ground
## layer, that dims with the room's lights. `x` is its centre and `z_front` its
## south edge, in layout units. Returns the mesh: hide it with `visible`, swap
## frames with its material's "tex" shader parameter.
func add_floor_decal(room_id: String, texture: Texture2D, x: float, z_front: float) -> MeshInstance3D:
	var w := texture.get_width() * PX
	var d := texture.get_height() / GROUND_PX_PER_UNIT
	var mesh := _ground_quad(texture, x - w * 0.5, z_front + d, w, d)
	mesh.position.y = 0.003  # just above the floor quad
	get_node(NodePath(room_id)).add_child(mesh)
	var material: ShaderMaterial = mesh.material_override
	var visuals: Dictionary = room_visuals[room_id]
	visuals.shaders.append(material)
	if visuals.has("bands"): _light_material(material, visuals.bands[0], visuals.bands[1])
	return mesh

func texture_at(path: String) -> Texture2D: return _texture(path)

## The closest station within reach of `position`, or an empty dictionary.
func station_near(position: Vector3) -> Dictionary:
	var best := {}
	var best_distance := INTERACT_RANGE
	for station in interactables:
		var offset: Vector3 = station.position - position
		offset.y = 0
		if offset.length() < best_distance:
			best_distance = offset.length()
			best = station
	return best

func station(id: String) -> Dictionary:
	for entry in interactables:
		if entry.id == id: return entry
	return {}

func _build_backdrop() -> void:
	var backdrop := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(700, 400)
	backdrop.mesh = plane
	backdrop.position = Vector3(EAST * 86.0, -0.05, -20.0)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("0b0c0d")
	backdrop.material_override = material
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(backdrop)

func _build_room(room: Dictionary) -> void:
	var root := Node3D.new()
	root.name = room.id
	add_child(root)
	var visuals := {"shaders": [], "sprites": [], "groups": {}}
	room_visuals[room.id] = visuals
	var ground: Dictionary = room.ground
	var w: float = ground.w_px * PX
	var d: float = ground.h_px / GROUND_PX_PER_UNIT
	var floor_mesh := _ground_quad(_texture(ground.tex), ground.x, ground.z, w, d)
	visuals.shaders.append(floor_mesh.material_override)
	root.add_child(floor_mesh)
	_add_floor_collider(ground.x, ground.z, w, d)
	var facade: Dictionary = room.facade
	# The north wall hides whatever stands behind it (the rooms beyond its doors).
	var wall := _see_through_quad(_texture(facade.tex), facade.x + facade.w_px * PX * 0.5, facade.z, 0.0, false, ORIGIN.z + facade.z)
	visuals.shaders.append(wall.material_override)
	root.add_child(wall)
	for entry in room.sprites:
		if entry.overhead:
			var hanging := _see_through_quad(_texture(entry.tex), entry.x, entry.z, entry.lift_px, true, -INF)
			visuals.shaders.append(hanging.material_override)
			root.add_child(hanging)
		else:
			var sprite := _billboard(_texture(entry.tex), entry.x, entry.z, entry.lift_px)
			if entry.has("role"): sprite.set_meta("role", entry.role)  # e.g. "cells": redrawn at run time
			visuals.sprites.append(sprite)
			if entry.has("group"):
				if not visuals.groups.has(entry.group): visuals.groups[entry.group] = []
				visuals.groups[entry.group].append(sprite)
			root.add_child(sprite)
		if entry.has("collide"):
			var size: Array = entry.collide
			_add_box(entry.x - size[0] * 0.5, entry.z - size[1] * 0.5, entry.x + size[0] * 0.5, entry.z + size[1] * 0.5)
	for box in room.colliders:
		_add_box(box[0], box[1], box[2], box[3])
	for entry in room.interactables:
		interactables.append({"id": entry.id, "kind": entry.kind, "label": entry.label,
			"room": room.id, "position": to_world(entry.x, entry.z, PLAYER_Y)})
	for key in room.spawns:
		spawns[key] = room.spawns[key]

func _texture(path: String) -> Texture2D:
	if _textures.has(path): return _textures[path]
	# Loaded from the PNG bytes so the generated folder needs no import step.
	var image := Image.new()
	image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
	var texture := ImageTexture.create_from_image(image)
	_textures[path] = texture
	return texture

func _ground_quad(texture: Texture2D, x: float, z: float, w: float, d: float) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [[0.0, 0.0], [1.0, 0.0], [1.0, 1.0], [0.0, 0.0], [1.0, 1.0], [0.0, 1.0]]
	for c in corners:
		tool.set_uv(Vector2(c[0], c[1]))
		tool.set_normal(Vector3.UP)
		tool.add_vertex(Vector3(EAST * (x + c[0] * w), 0.0, z - c[1] * d))
	var mesh := MeshInstance3D.new()
	mesh.mesh = tool.commit()
	var material := ShaderMaterial.new()
	material.shader = FLOOR_SHADER
	material.set_shader_parameter("tex", texture)
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh

func _billboard(texture: Texture2D, x: float, z: float, lift_px: float) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.pixel_size = PX
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.double_sided = true
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.position = Vector3(EAST * x, SORT_PIVOT_Y, z)
	# Bottom edge on the feet (raised by lift for hanging items), corrected for the pivot height.
	sprite.offset = Vector2(0, texture.get_height() * 0.5 + lift_px - PIVOT_SCREEN_PX)
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	return sprite

## A billboard drawn with the see-through shader. Placed exactly like _billboard():
## pivot at SORT_PIVOT_Y above the feet, image bottom on the feet (+ lift).
func _see_through_quad(texture: Texture2D, x: float, z: float, lift_px: float, overhead: bool, occludes_north_of: float) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(texture.get_width(), texture.get_height()) * PX
	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = SEE_THROUGH_OVERHEAD if overhead else SEE_THROUGH
	material.set_shader_parameter("tex", texture)
	material.set_shader_parameter("occludes_north_of", maxf(occludes_north_of, -100000.0))
	if overhead: material.render_priority = 20
	mesh.material_override = material
	_see_through.append(material)
	var rise := (texture.get_height() * 0.5 + lift_px - PIVOT_SCREEN_PX) * PX
	mesh.transform = Transform3D(CAMERA_BASIS, Vector3(EAST * x, SORT_PIVOT_Y, z) + CAMERA_BASIS.y * rise)
	return mesh

func _add_floor_collider(x: float, z: float, w: float, d: float) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w, 1.0, d)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(EAST * (x + w * 0.5), -0.5, z - d * 0.5)
	_navigation.add_child(body)

## A prop footprint added at run time (a newly built rack). Navigation is rebaked
## on the next frame, once however many were added.
func add_runtime_collider(x0: float, z0: float, x1: float, z1: float) -> void:
	_add_box(x0, z0, x1, z1)
	if not _rebake_queued:
		_rebake_queued = true
		_rebake.call_deferred()

var _rebake_queued := false
func _rebake() -> void:
	_rebake_queued = false
	_navigation.bake_navigation_mesh(false)

## Wall or prop footprint in layout coordinates [x0, z0] - [x1, z1].
func _add_box(x0: float, z0: float, x1: float, z1: float) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(absf(x1 - x0), 2.0, absf(z1 - z0))
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(EAST * (x0 + x1) * 0.5, 1.0, (z0 + z1) * 0.5)
	_navigation.add_child(body)
