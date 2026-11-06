extends SceneTree
## A5 probe (agent-written): where the base's "crate" kit pieces stand, which room
## each is in, and whether the crate mesh has UVs and tangents for cargo_panel.

const MODELS := ["crate", "crate_stack", "crate_medium_sealed", "crate_large_sealed", "crate_small_sealed"]
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var game := GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	for i in range(8):
		await physics_frame
		await process_frame
	var base := game.base_map
	var found := []
	var stack := [base as Node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is MeshInstance3D and n.has_meta("model") and str(n.get_meta("model")) in MODELS: found.append(n)
	print("CRATES ", found.size())
	for mi in found:
		var over: Material = mi.get_surface_override_material(0)
		print("CRATE ", mi.get_meta("model"), " ", mi.get_path(), " at ", mi.global_position, " scale ", mi.global_basis.get_scale(),
			" surface0 ", over.resource_path if over and over.resource_path != "" else (over.shader.resource_path if over else "-"),
			" surface1 ", mi.get_surface_override_material(1).shader.resource_path if mi.mesh.get_surface_count() > 1 and mi.get_surface_override_material(1) else "-")
	var seen := {}
	for mi in found:
		if seen.has(mi.get_meta("model")): continue
		seen[mi.get_meta("model")] = true
		print("MODEL ", mi.get_meta("model"))
		var mesh: Mesh = mi.mesh
		var aabb := mesh.get_aabb()
		print("AABB ", aabb)
		for s in range(mesh.get_surface_count()):
			var arr := mesh.surface_get_arrays(s)
			var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var tan = arr[Mesh.ARRAY_TANGENT]
			var lo := Vector2(INF, INF); var hi := Vector2(-INF, -INF)
			for u in uv:
				lo = Vector2(minf(lo.x, u.x), minf(lo.y, u.y)); hi = Vector2(maxf(hi.x, u.x), maxf(hi.y, u.y))
			var mat := mesh.surface_get_material(s)
			print("SURFACE ", s, " verts ", (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), " uv ", uv.size(), " range ", lo, "..", hi,
				" tangents ", tan != null and (tan as PackedFloat32Array).size() > 0, " material ", mat.resource_name if mat else "-",
				" override ", mi.get_surface_override_material(s).shader.resource_path if mi.get_surface_override_material(s) else "-")
	quit(0)
