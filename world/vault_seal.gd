class_name VaultSeal
extends RefCounted

## The 密室 behind a stretch of the room's own edge (密室与陷阱修订案_v1 §2.1,
## 用户 2026-10-17: 整体是一体的，但是能看出来; 用攻击打开).
##
## The floor is generated, meshed and dressed as if the vault were not there
## (ContinuousWorldMap.vault_excluded), so the edge across its mouth is the
## same rock, face, rubble and lights as every other edge. Beside that, the
## patch of ground the vault would change is built dug (TerrainSurface.
## build_patch, the dressing again over the dug grids) and kept aside. When
## HITS blows land on the edge at the mouth, the sealed patch comes away
## (PatchSplit) and the dug one goes in; the navigation is baked again.
##
## The tells: the region's own at the foot of the edge (TELLS: a heap of fresh
## fall at the mine's face, and the like), and a faint glow (用户 2026-10-17:
## 密室也发幽幽的光) the same as a trace's: the tell breathes a pale light, motes
## seep from the face, and the glow is in the floor's light map until the edge
## breaks. No marker, no E prompt, nothing on the minimap until it is open.

const HITS := 3
## A swing lands on the edge from this far, in front of her.
const REACH := 2.4
## The tell at the mouth, per region look: a Blender model at the foot.
const TELLS := {"mine": "vault_tell_mine", "snow": "vault_tell_snow", "city": "vault_tell_city", "siracusa": "vault_tell_siracusa"}

var map: Node3D
var opened := false
var hits := 0
var bundle: TerrainSurface.Bundle
## The dug patch (terrain and its dressing) and the sealed one in the tree.
var _dug: Node3D
var _sealed: Node3D
var _tell: Node3D
var _shine: StandardMaterial3D
const GLOW_GAIN := 0.4
const GLOW_RADIUS := 3.4

## The glow's lamp for the floor's light map (GameManager bakes it with the rest).
func glow_lamp() -> Dictionary:
	var at: Vector2 = map.vault_mouth - map.vault_inward * 0.6
	return {"at": Vector3(at.x, map.ground_height(at) + 0.8, at.y), "color": TracePoint.GLOW * GLOW_GAIN, "radius": GLOW_RADIUS, "vault": true}

## On the floor's content pass: the patch, its dug terrain, and where the
## vault's spoils go (read on the dug ground).
func prepare(world: Node3D) -> void:
	map = world
	var surface: TerrainSurface = map._surface
	surface.find_patch()
	bundle = surface.build_patch()
	_dug = Node3D.new()
	_dug.name = "VaultDug"
	_dug.add_child(surface.bundle_nodes(bundle))
	surface.use_grids(true)
	var spot: Vector2 = map._safe_spot(map.vault_centre, map.vault_centre, 8.0)
	map.vault_position = map._grounded(spot, 0.5)
	surface.use_grids(false)
	if is_instance_valid(map.vault_node): map.vault_node.position = map.vault_position

## After the floor is dressed: the sealed patch's share of the terrain and the
## dressing taken into a node of its own, and the dressing built again over
## the dug grids with only the patch's share kept.
func prepare_dressing(dressing_roots: Array[Node]) -> void:
	var surface: TerrainSurface = map._surface
	var inside := Callable(self, "in_patch")
	_sealed = Node3D.new()
	_sealed.name = "VaultSealed"
	for name in ["WalkableTerrain", "RaisedTerrain", "ContourBanks", "TerrainBoundaryCollision"]:
		var node: Node = map._generated_root.get_node_or_null(name)
		if node != null: _sealed.add_child(PatchSplit.split_node(node, inside))
	var changed := Callable(self, "changes")
	for root in dressing_roots: _sealed.add_child(PatchSplit.split(root, changed))
	map._generated_root.add_child(_sealed)
	# The dug dressing: the same builders over the dug grids and lists.
	var kept := _use_dug_lists()
	surface.use_grids(true)
	map.vault_excluded = false
	var before: Array[Node] = map._generated_root.get_children()
	SceneDressing.new().build(map)
	var terrace := TerraceDressing.new()
	terrace.patch_only = true
	terrace.build(map)
	var room_only := Callable(self, "near_room")
	for node in map._generated_root.get_children():
		if node in before: continue
		var kept_part := PatchSplit.keep_only(node, changed)
		# Nothing of the outdoor dressing inside the room.
		PatchSplit.split(kept_part, room_only).free()
		_dug.add_child(kept_part)
	_dug.add_child(_build_room())
	surface.use_grids(false)
	map.vault_excluded = true
	_restore_lists(kept)
	_place_tell()

func in_patch(point: Vector2) -> bool:
	return map._surface.in_patch(point)

## The dressing swapped when the wall breaks: what stands where the vault
## changes the ground (CHANGE_REACH: about a building's depth past the dug edge).
const CHANGE_REACH := 12.0
func changes(point: Vector2) -> bool:
	return map._surface.vault_changes(point, CHANGE_REACH)

## The surface's lists with the patch's sealed share swapped for the dug one;
## returns the lists as they were.
func _use_dug_lists() -> Array:
	var surface: TerrainSurface = map._surface
	var kept := [surface.contour_edges, surface.cliff_cuts, surface.minimap_faces, surface.boundaries]
	surface.contour_edges = _outside_edges(surface.contour_edges, bundle.contour_edges)
	surface.cliff_cuts = _outside_edges(surface.cliff_cuts, bundle.cliff_cuts)
	surface.minimap_faces = _outside_polygons(surface.minimap_faces, bundle.minimap_faces)
	surface.boundaries = _outside_polygons(surface.boundaries, bundle.boundaries)
	return kept

func _restore_lists(kept: Array) -> void:
	var surface: TerrainSurface = map._surface
	surface.contour_edges = kept[0]
	surface.cliff_cuts = kept[1]
	surface.minimap_faces = kept[2]
	surface.boundaries = kept[3]

## `list` outside the patch, then `dug`.
func _outside_edges(list: Array[PackedFloat32Array], dug: Array[PackedFloat32Array]) -> Array[PackedFloat32Array]:
	var out: Array[PackedFloat32Array] = []
	for e in list:
		if not in_patch(Vector2((e[0] + e[2]) * 0.5, (e[1] + e[3]) * 0.5)): out.append(e)
	out.append_array(dug)
	return out

func _outside_polygons(list: Array[PackedVector2Array], dug: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for polygon in list:
		var middle := Vector2.ZERO
		for p in polygon: middle += p
		if not in_patch(middle / maxf(polygon.size(), 1.0)): out.append(polygon)
	out.append_array(dug)
	return out

## The tell at the foot of the edge across the mouth, on the room's side.
func _place_tell() -> void:
	var mouth: Vector2 = map.vault_mouth
	var inward: Vector2 = map.vault_inward
	var top: float = map._surface.rock_top_at(mouth + inward * 0.6)
	_sealed.add_child(_seep(mouth, inward, top))
	var look := FieldCatalog.art_region(str(map.region_id)) if str(map.region_id) != "siracusa" else "siracusa"
	if not TELLS.has(look): return
	var path: String = CityDressing.KIT + TELLS[look] + ".glb"
	if not ResourceLoader.exists(path): return
	var foot := mouth - inward * 0.5
	_tell = MeshInstance3D.new()
	_tell.name = "VaultTell"
	(_tell as MeshInstance3D).mesh = TerraceDressing.kit_mesh(load(path))
	_sealed.add_child(_tell)
	var across := Vector3(-inward.y, 0, inward.x)
	_tell.global_transform = Transform3D(Basis(across, Vector3.UP, Vector3(-inward.x, 0, -inward.y)), Vector3(foot.x, map.ground_height(foot), foot.y))
	var shine := TracePoint.halo(2.6)
	_shine = shine.material_override
	_tell.add_child(shine)
	var breath := shine.create_tween().set_loops()
	breath.tween_property(_shine, "albedo_color", TracePoint.GLOW * TracePoint.PULSE.y, TracePoint.BREATH * 0.5).set_trans(Tween.TRANS_SINE)
	breath.tween_property(_shine, "albedo_color", TracePoint.GLOW * TracePoint.PULSE.x, TracePoint.BREATH * 0.5).set_trans(Tween.TRANS_SINE)
	# Now and then a trickle of grit off the face above it.
	var grit := CPUParticles3D.new()
	grit.name = "VaultGrit"
	grit.amount = 5
	grit.lifetime = 1.6
	grit.explosiveness = 0.0
	grit.randomness = 0.8
	grit.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	grit.emission_box_extents = Vector3(0.7, 0.05, 0.1)
	grit.direction = Vector3.DOWN
	grit.spread = 8.0
	grit.gravity = Vector3(0, -6.0, 0)
	grit.initial_velocity_min = 0.2
	grit.initial_velocity_max = 0.6
	grit.scale_amount_min = 0.5
	grit.scale_amount_max = 1.0
	var speck := QuadMesh.new()
	speck.size = Vector2(0.05, 0.05)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.55, 0.5, 0.42)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	speck.material = material
	grit.mesh = speck
	_sealed.add_child(grit)
	grit.global_position = Vector3(mouth.x, top - 0.1, mouth.y) - Vector3(inward.x, 0, inward.y) * 0.15

## Faint motes seeping out of the face along the mouth, drifting up.
func _seep(mouth: Vector2, inward: Vector2, top: float) -> CPUParticles3D:
	var motes := CPUParticles3D.new()
	motes.name = "VaultSeep"
	motes.amount = 7
	motes.lifetime = 3.2
	motes.preprocess = 3.2
	motes.local_coords = false
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(map.vault_half_width * 0.8, 0.4, 0.1)
	motes.direction = Vector3.UP
	motes.spread = 20.0
	motes.gravity = Vector3.ZERO
	motes.initial_velocity_min = 0.06
	motes.initial_velocity_max = 0.18
	var fade := Gradient.new()
	fade.set_color(0, Color(TracePoint.GLOW, 0.0))
	fade.add_point(0.35, Color(TracePoint.GLOW, 0.65))
	fade.set_color(fade.get_point_count() - 1, Color(TracePoint.GLOW, 0.0))
	motes.color_ramp = fade
	var speck := QuadMesh.new()
	speck.size = Vector2(0.07, 0.07)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	speck.material = material
	motes.mesh = speck
	var across := Vector3(-inward.y, 0, inward.x)
	var ground: float = map.ground_height(mouth - inward * 0.3)
	motes.transform = Transform3D(Basis(across, Vector3.UP, Vector3(-inward.x, 0, -inward.y)), Vector3(mouth.x, ground + 0.5, mouth.y) - Vector3(inward.x, 0, inward.y) * 0.3)
	return motes

## Whether a swing from `from` heading `direction` reaches the edge at the mouth.
func in_reach(from: Vector3, direction: Vector3) -> bool:
	if opened: return false
	var mouth: Vector2 = map.vault_mouth
	var offset := Vector2(mouth.x - from.x, mouth.y - from.z)
	var across := Vector2(-map.vault_inward.y, map.vault_inward.x)
	if absf(offset.dot(across)) > map.vault_half_width or absf(offset.dot(map.vault_inward)) > REACH: return false
	return Vector2(direction.x, direction.z).normalized().dot(map.vault_inward) > 0.3

## Whether a click landing at `point` is on the edge at the mouth: its foot,
## its face or the rock top just behind (用户 2026-10-20: 左键点地面改为移动, so
## the wall is clicked the way an enemy is).
const CLICK_DEPTH := Vector2(-1.5, 4.0)
func aimed_at(point: Vector3) -> bool:
	if opened: return false
	var offset: Vector2 = Vector2(point.x, point.z) - map.vault_mouth
	var across := Vector2(-map.vault_inward.y, map.vault_inward.x)
	var depth: float = offset.dot(map.vault_inward)
	return absf(offset.dot(across)) <= map.vault_half_width + 0.6 and depth >= CLICK_DEPTH.x and depth <= CLICK_DEPTH.y

## Where she stands to strike it from `from`: on the open side of the mouth,
## as near her own line along it as the mouth allows.
func stand_point(from: Vector3) -> Vector3:
	var across := Vector2(-map.vault_inward.y, map.vault_inward.x)
	var side := clampf((Vector2(from.x, from.z) - map.vault_mouth).dot(across), -map.vault_half_width * 0.6, map.vault_half_width * 0.6)
	var at: Vector2 = map.vault_mouth + across * side - map.vault_inward * 1.2
	return Vector3(at.x, map.ground_height(at), at.y)

func inward() -> Vector3:
	return Vector3(map.vault_inward.x, 0, map.vault_inward.y)

## A swing landed. True when it broke through.
func strike() -> bool:
	if opened: return false
	hits += 1
	if hits < HITS: return false
	open()
	return true

func open() -> void:
	if opened: return
	opened = true
	# Out of the tree before the navigation is baked again below.
	if is_instance_valid(_sealed):
		_sealed.get_parent().remove_child(_sealed)
		_sealed.queue_free()
	_sealed = null
	map._generated_root.add_child(_dug)
	var surface: TerrainSurface = map._surface
	map.vault_excluded = false
	surface.use_grids(true)
	surface._open_grids = []
	surface._sealed_grids = []
	_use_dug_lists()
	map.minimap_faces = surface.minimap_faces
	map.terrain_edges = surface.boundaries
	map._generated_root.bake_navigation_mesh(false)
	# Its glow goes out of the light map.
	var terrace: TerraceDressing = map.terrace_dressing
	if terrace != null and terrace.field_light != null:
		var lit: Array[Dictionary] = []
		for lamp in terrace.lamps:
			if not lamp.get("vault", false): lit.append(lamp)
		lit.append_array(_room_lamps)
		terrace.lamps = lit
		terrace.field_light.build(map, terrace.lamps)
	if is_instance_valid(map.vault_node): map.vault_node.visible = true
	_dug = null

func wall_centre() -> Vector3:
	var mouth: Vector2 = map.vault_mouth
	return Vector3(mouth.x, map.ground_height(mouth), mouth.y)

## The floor is going: the dug patch was never added to it.
func release() -> void:
	if is_instance_valid(_dug) and _dug.get_parent() == null: _dug.free()
	_dug = null

# --- The room (用户 2026-10-17: 密室做成房间的样子; 固定大小，每张地图的密室样子
# 一致，家具摆放会变，整体模样不变) ------------------------------------------------

## Floor and walls per region look (tools/blender/kit/build_trap_kit.py ROOMS);
## the furniture is shared.
const ROOM_FLOOR := {"mine": "room_floor_mine", "snow": "room_floor_snow", "city": "room_floor_city", "siracusa": "room_floor_siracusa"}
const ROOM_WALL := {"mine": "room_wall_mine", "snow": "room_wall_snow", "city": "room_wall_city", "siracusa": "room_wall_siracusa"}
## What stands in the room, and how much of it: the set is fixed, where each
## piece stands is rolled among SLOTS.
const FURNITURE := ["room_shelf", "room_shelf", "room_crates", "room_crates", "room_table", "room_lantern", "room_lantern"]
## Footprints (x along the wall, z out from it) for their collision.
const FOOTPRINT := {"room_shelf": Vector2(1.5, 0.45), "room_crates": Vector2(1.5, 0.75), "room_table": Vector2(1.4, 0.8), "room_lantern": Vector2(0.3, 0.3)}
const ROOM_LAMP := Color(1.0, 0.72, 0.4) * 0.35
const PANEL := 2.0

var _room_lamps: Array[Dictionary] = []

## The room's centre on the ground (dug grids).
func room_centre() -> Vector2:
	var circle: Vector3 = map._open_circles[map._vault_room]
	return Vector2(circle.x, circle.y)

func in_room(point: Vector2) -> bool:
	var offset := (point - room_centre()).abs()
	return offset.x < map.VAULT_ROOM.x + 0.3 and offset.y < map.VAULT_ROOM.y + 0.3

## The room and the rock just round it: no outdoor dressing stands here (a
## house standing on the room's wall, a crag over it).
const ROOM_CLEAR := 4.0
func near_room(point: Vector2) -> bool:
	var offset := (point - room_centre()).abs()
	return offset.x < map.VAULT_ROOM.x + ROOM_CLEAR and offset.y < map.VAULT_ROOM.y + ROOM_CLEAR

func _look() -> String:
	return FieldCatalog.art_region(str(map.region_id)) if str(map.region_id) != "siracusa" else "siracusa"

## Built on the dug grids: the floor laid tile by tile, a panel along every
## 2 m of the walls but where the lane comes in, and the furniture against
## the walls in rolled slots.
func _build_room() -> Node3D:
	var room := Node3D.new()
	room.name = "VaultRoom"
	var centre := room_centre()
	var half: Vector2 = map.VAULT_ROOM
	var ground: float = map.ground_height(centre)
	var look := _look()
	var floor_mesh: Mesh = TerraceDressing.kit_mesh(load(CityDressing.KIT + ROOM_FLOOR[look] + ".glb"))
	var tiles: Array[Transform3D] = []
	var x := -half.x + PANEL * 0.5
	while x < half.x + 0.01:
		var z := -half.y + PANEL * 0.25
		while z < half.y + 0.5:
			tiles.append(Transform3D(Basis(), Vector3(centre.x + x, ground + 0.005, centre.y + z)))
			z += PANEL
		x += PANEL
	room.add_child(_multimesh("Floor", floor_mesh, tiles))
	# Walls: each side in 2 m panels, their room face inwards.
	var wall_mesh: Mesh = TerraceDressing.kit_mesh(load(CityDressing.KIT + ROOM_WALL[look] + ".glb"))
	var walls: Array[Transform3D] = []
	var slots: Array[Transform3D] = []
	for side: Vector2 in [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]:
		var along := Vector2(-side.y, side.x)
		var length: float = half.x * 2.0 if side.x == 0 else half.y * 2.0
		var depth: float = half.y if side.x == 0 else half.x
		var count := ceili(length / PANEL)
		for k in range(count):
			var t := -length * 0.5 + (k + 0.5) * length / count
			var edge := centre + side * depth + along * t
			# The lane comes in here: no panel.
			if map._surface.distance_near(edge + side * 0.8) >= 0.0: continue
			var inward := Vector3(-side.x, 0, -side.y)
			var basis := Basis(Vector3(along.x, 0, along.y), Vector3.UP, inward).scaled(Vector3(length / count / PANEL, 1, 1))
			walls.append(Transform3D(basis, Vector3(edge.x, ground, edge.y) + inward * 0.12))
			# A slot against this stretch of wall, clear of the lane's mouth.
			if map._surface.distance_near(edge + along * 1.2 + side * 0.8) < 0.0 and map._surface.distance_near(edge - along * 1.2 + side * 0.8) < 0.0:
				slots.append(Transform3D(Basis(Vector3(along.x, 0, along.y), Vector3.UP, inward), Vector3(edge.x, ground, edge.y) + inward * 0.55))
	room.add_child(_multimesh("Walls", wall_mesh, walls))
	# The furniture in rolled slots, never two in one.
	var roll := RandomNumberGenerator.new()
	roll.seed = map.seed_value ^ 0x7a01e
	for i in range(slots.size() - 1, 0, -1):
		var j := roll.randi_range(0, i)
		var swap := slots[i]
		slots[i] = slots[j]
		slots[j] = swap
	var placed := {}
	for k in range(mini(FURNITURE.size(), slots.size())):
		var name: String = FURNITURE[k]
		var at: Transform3D = slots[k]
		if not placed.has(name): placed[name] = [] as Array[Transform3D]
		(placed[name] as Array[Transform3D]).append(at)
		var size: Vector2 = FOOTPRINT[name]
		var body := StaticBody3D.new()
		body.name = "Block_" + name
		body.add_to_group("world_obstacle")
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(size.x, 1.6, size.y)
		shape.shape = box
		shape.position.y = 0.8
		body.add_child(shape)
		body.transform = at
		room.add_child(body)
		if name == "room_lantern":
			# Snow throws back far more of it.
			_room_lamps.append({"at": at.origin + Vector3.UP * 1.6, "color": ROOM_LAMP * (0.4 if _look() == "snow" else 1.0), "radius": 5.0})
	for name in placed:
		room.add_child(_multimesh(name, TerraceDressing.kit_mesh(load(CityDressing.KIT + name + ".glb")), placed[name]))
	map.vault_position = Vector3(centre.x, ground + 0.5, centre.y)
	if is_instance_valid(map.vault_node): map.vault_node.position = map.vault_position
	return room

func _multimesh(label: String, mesh: Mesh, list: Array[Transform3D]) -> MultiMeshInstance3D:
	var instance := MultiMeshInstance3D.new()
	instance.name = label
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = list.size()
	for i in range(list.size()): multimesh.set_instance_transform(i, list[i])
	instance.multimesh = multimesh
	return instance
