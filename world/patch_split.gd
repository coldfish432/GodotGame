class_name PatchSplit
extends RefCounted

## Cuts the part of a built scene that lies over a patch of ground out into a
## node of its own (VaultSeal: the sealed rock and its dressing over a vault
## come away when the wall breaks; the dug version keeps only that part).
##
## - Big surfaces (terrain, swept cliff faces: an ArrayMesh more than BIG
##   across) are cut triangle by triangle, by each triangle's middle.
## - Collision of concave faces the same way.
## - Multimeshes by each instance's origin.
## - Anything else (a model, a light, particles) whole, by its origin.

const BIG := 8.0

## Moves everything of `root` over `inside` (a Callable on x/z) into a new
## node, returned (not in the tree); what is outside stays in `root`.
static func split(root: Node, inside: Callable) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Patch_" + root.name
	_split_children(root, inside, holder)
	return holder

## The same for one node itself (a terrain mesh, a collision body) and what
## hangs under it.
static func split_node(node: Node, inside: Callable) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Patch_" + node.name
	_split_one(node, node.get_parent(), inside, holder)
	return holder

## Keeps only what is over `inside` (returned, not in the tree); frees the rest.
static func keep_only(root: Node, inside: Callable) -> Node3D:
	var holder := split(root, inside)
	if root.get_parent() != null: root.get_parent().remove_child(root)
	root.free()
	return holder

## Where a node stands in the world, in the tree or not (a holder built aside
## keeps its parts at their world transforms under an identity parent).
static func _xf(node: Node3D) -> Transform3D:
	if node.is_inside_tree(): return node.global_transform
	var parent := node.get_parent() as Node3D
	return _xf(parent) * node.transform if parent != null else node.transform

static func _split_children(node: Node, inside: Callable, holder: Node3D) -> void:
	for child in node.get_children(): _split_one(child, node, inside, holder)

static func _split_one(child: Node, node: Node, inside: Callable, holder: Node3D) -> void:
	if child is MultiMeshInstance3D:
		_split_multimesh(child, inside, holder)
	elif child is MeshInstance3D and (child as MeshInstance3D).mesh is ArrayMesh and (child as MeshInstance3D).mesh.get_aabb().size.length() > BIG:
		_split_mesh(child, inside, holder)
		_split_children(child, inside, holder)
	elif child is StaticBody3D and _concave(child):
		_split_body(child, inside, holder)
	elif child is Node3D and child.get_child_count() > 0 and not (child is MeshInstance3D) and not (child is CollisionObject3D):
		_split_children(child, inside, holder)
	elif child is Node3D:
		var at: Vector3 = _xf(child as Node3D).origin
		if inside.call(Vector2(at.x, at.z)):
			var keep: Transform3D = _xf(child as Node3D)
			node.remove_child(child)
			holder.add_child(child)
			(child as Node3D).transform = keep

static func _split_multimesh(node: MultiMeshInstance3D, inside: Callable, holder: Node3D) -> void:
	var multimesh := node.multimesh
	if multimesh == null or multimesh.instance_count == 0: return
	var basis := _xf(node)
	var keep: Array[int] = []
	var take: Array[int] = []
	for i in range(multimesh.instance_count):
		var at := basis * multimesh.get_instance_transform(i).origin
		if inside.call(Vector2(at.x, at.z)): take.append(i)
		else: keep.append(i)
	if take.is_empty(): return
	var moved := MultiMeshInstance3D.new()
	moved.name = node.name
	moved.material_override = node.material_override
	moved.cast_shadow = node.cast_shadow
	moved.multimesh = _subset(multimesh, take)
	holder.add_child(moved)
	moved.transform = basis
	node.multimesh = _subset(multimesh, keep)

static func _subset(source: MultiMesh, indices: Array[int]) -> MultiMesh:
	var out := MultiMesh.new()
	out.transform_format = source.transform_format
	out.use_colors = source.use_colors
	out.use_custom_data = source.use_custom_data
	out.mesh = source.mesh
	out.instance_count = indices.size()
	for k in range(indices.size()):
		var i := indices[k]
		out.set_instance_transform(k, source.get_instance_transform(i))
		if source.use_colors: out.set_instance_color(k, source.get_instance_color(i))
		if source.use_custom_data: out.set_instance_custom_data(k, source.get_instance_custom_data(i))
	return out

## The triangles of every surface, sorted by where their middle lies.
static func _split_mesh(node: MeshInstance3D, inside: Callable, holder: Node3D) -> void:
	var mesh := node.mesh as ArrayMesh
	var basis := _xf(node)
	var keep_mesh := ArrayMesh.new()
	var take_mesh := ArrayMesh.new()
	for s in range(mesh.get_surface_count()):
		if mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			keep_mesh.add_surface_from_arrays(mesh.surface_get_primitive_type(s), mesh.surface_get_arrays(s))
			continue
		var arrays := mesh.surface_get_arrays(s)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := indices.size() if not indices.is_empty() else vertices.size()
		var keep := PackedInt32Array()
		var take := PackedInt32Array()
		for t in range(0, count, 3):
			var a := indices[t] if not indices.is_empty() else t
			var b := indices[t + 1] if not indices.is_empty() else t + 1
			var c := indices[t + 2] if not indices.is_empty() else t + 2
			var middle := basis * ((vertices[a] + vertices[b] + vertices[c]) / 3.0)
			var into := take if inside.call(Vector2(middle.x, middle.z)) else keep
			into.append(a)
			into.append(b)
			into.append(c)
		var material := mesh.surface_get_material(s)
		for pair in [[keep, keep_mesh], [take, take_mesh]]:
			var corners: PackedInt32Array = pair[0]
			if corners.is_empty(): continue
			var target: ArrayMesh = pair[1]
			target.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _pick(arrays, corners))
			if material != null: target.surface_set_material(target.get_surface_count() - 1, material)
	if take_mesh.get_surface_count() == 0: return
	node.mesh = keep_mesh
	var moved := MeshInstance3D.new()
	moved.name = node.name
	moved.mesh = take_mesh
	moved.material_override = node.material_override
	moved.cast_shadow = node.cast_shadow
	holder.add_child(moved)
	moved.transform = basis

## The per-vertex arrays at `corners`, unindexed.
static func _pick(arrays: Array, corners: PackedInt32Array) -> Array:
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	for kind in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
		var source = arrays[kind]
		if source == null: continue
		var picked = source.duplicate()
		picked.resize(corners.size())
		for k in range(corners.size()): picked[k] = source[corners[k]]
		out[kind] = picked
	var tangents = arrays[Mesh.ARRAY_TANGENT]
	if tangents != null and (tangents as PackedFloat32Array).size() > 0:
		var picked := PackedFloat32Array()
		picked.resize(corners.size() * 4)
		for k in range(corners.size()):
			for e in range(4): picked[k * 4 + e] = tangents[corners[k] * 4 + e]
		out[Mesh.ARRAY_TANGENT] = picked
	return out

static func _concave(body: StaticBody3D) -> bool:
	for child in body.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is ConcavePolygonShape3D: return true
	return false

## A body of concave faces: the faces over the patch go to a copy of it.
static func _split_body(body: StaticBody3D, inside: Callable, holder: Node3D) -> void:
	var basis := _xf(body)
	var moved: StaticBody3D = null
	for child in body.get_children():
		if not (child is CollisionShape3D) or not ((child as CollisionShape3D).shape is ConcavePolygonShape3D): continue
		var shape := (child as CollisionShape3D).shape as ConcavePolygonShape3D
		var faces := shape.get_faces()
		var keep := PackedVector3Array()
		var take := PackedVector3Array()
		var local := basis * (child as CollisionShape3D).transform
		for t in range(0, faces.size(), 3):
			var middle := local * ((faces[t] + faces[t + 1] + faces[t + 2]) / 3.0)
			var into := take if inside.call(Vector2(middle.x, middle.z)) else keep
			into.append(faces[t])
			into.append(faces[t + 1])
			into.append(faces[t + 2])
		if take.is_empty(): continue
		shape.set_faces(keep)
		if moved == null:
			moved = StaticBody3D.new()
			moved.name = body.name
			moved.collision_layer = body.collision_layer
			moved.collision_mask = body.collision_mask
			for group in body.get_groups(): moved.add_to_group(group)
			holder.add_child(moved)
			moved.transform = basis
		var copy := ConcavePolygonShape3D.new()
		copy.backface_collision = shape.backface_collision
		copy.set_faces(take)
		var holder_shape := CollisionShape3D.new()
		holder_shape.shape = copy
		holder_shape.transform = (child as CollisionShape3D).transform
		moved.add_child(holder_shape)
