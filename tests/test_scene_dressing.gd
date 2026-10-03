extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void: call_deferred("run")

func check(label: String, passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label)

func run() -> void:
	var game := GameManager.new()
	game.save_enabled = false
	game.start_at_base = true
	root.add_child(game)
	await process_frame
	game.fixed_map_seed = 1729
	for region in ["mine", "city", "snow"]:
		await game.start_contract(region)
		game.open_modal("scene-test")
		await process_frame
		await process_frame
		var map := game.world_map
		var dressing: Node3D = map._generated_root.get_node("SceneDressing")
		# Build a spatial index from the actual rendered triangles, independently
		# of height_at(). This catches wrong billboard feet and hover on slopes.
		var surface: MeshInstance3D = map._generated_root.get_node("RaisedTerrain")
		var faces := surface.mesh.get_faces()
		var origin: Vector2 = map.SPINE_MIN - Vector2(36, 36)
		var triangles := {}
		for i in range(0, faces.size(), 3):
			var center := (faces[i] + faces[i + 1] + faces[i + 2]) / 3.0
			var key := Vector2i(((Vector2(center.x, center.z) - origin) / TerrainSurface.CELL).floor())
			if not triangles.has(key): triangles[key] = []
			triangles[key].append([faces[i], faces[i + 1], faces[i + 2]])
		var misplaced := 0
		var hovering := 0
		var props := 0
		var roles := {}
		var max_error := 0.0
		for node in get_nodes_in_group("field_props"):
			if not node is Sprite3D: continue
			var sprite: Sprite3D = node
			props += 1
			roles[sprite.get_meta("scene_role", -1)] = true
			var p := sprite.global_position
			# Billboard AABBs deliberately expand into a conservative cube;
			# inspect the actual quad vertices to find its local lower edge.
			var foot_y := INF
			for vertex in sprite.generate_triangle_mesh().get_faces(): foot_y = minf(foot_y, vertex.y)
			if map._is_open(p.x, p.z, 1.5): misplaced += 1
			var key := Vector2i(((Vector2(p.x, p.z) - origin) / TerrainSurface.CELL).floor())
			var found := false
			for tri in triangles.get(key, []):
				var hit = Geometry3D.ray_intersects_triangle(Vector3(p.x, 100, p.z), Vector3.DOWN, tri[0], tri[1], tri[2])
				if hit == null: continue
				found = true
				var error: float = absf(p.y - hit.y - 0.035)
				max_error = maxf(max_error, error)
				if error > 0.08 or absf(foot_y) > 0.001:
					hovering += 1
					if hovering <= 2: print("  ground diagnostic ", sprite.get_aabb(), " texture=", sprite.texture.get_size(), " offset=", sprite.offset, " mesh_error=", error)
				break
			if not found:
				hovering += 1
				if hovering <= 2: print("  no triangle under ", p, " key ", key)
		check(region + " multiple scene compositions and visible props (%d groups / %d props)" % [dressing.get_meta("composition_count"), props], dressing.get_meta("composition_count") >= 15 and props >= 15)
		check(region + " varied regional objects rather than one repeated prop", roles.size() >= 3)
		check(region + " object anchors leave the playable corridor clear", misplaced == 0)
		check(region + " billboard feet match rendered ground triangles (worst %.5f)" % max_error, hovering == 0)
		check(region + " scenery adds no collision bodies or navigation blockers", dressing.find_children("*", "CollisionObject3D", true, false).is_empty())
		game.close_modal()
		game.settle(true)
	game.queue_free()
	await create_timer(0.4).timeout
	print("SCENE RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
