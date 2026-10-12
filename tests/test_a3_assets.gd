extends SceneTree

## Assignment 3: the three Blender assets as Godot imported them.
##
## Loads res://art/models/asset_preview.tscn and, for each asset instance,
## reads the imported meshes back: bounding box in the asset's own space,
## the scale and basis of every node on the way down, triangle count and each
## surface's albedo. These are compared with a3/CHANGE-BRIEF.md. Blender is
## Z-up and was exported +Y up, so Blender +Y is Godot -Z: the ramp must rise
## towards -Z and the cliff's front (Blender -Y) must face +Z.

const TOL := 0.02
const SCENE := "res://art/models/asset_preview.tscn"

## Expected bounds in the asset's local Godot space (x, y, z min and max),
## from the brief, its revisions, and the author's manual kerb edit.
const EXPECTED := {
	"cliff_wall_segment": {
		"min": Vector3(-1.47, 0.0, -0.90), "max": Vector3(1.47, 2.40, 0.30),
		"triangles": 116, "budget": 300, "colors": ["443c31", "5a4f40"],
	},
	"arched_ramp_segment": {
		"min": Vector3(-3.50, 0.0, -6.50), "max": Vector3(3.50, 2.47, 0.0),
		"triangles": 68, "budget": 200, "colors": ["988164", "6e6a60"],
	},
	"cliff_rubble_pile": {
		"min": Vector3(-0.736, 0.0, -0.627), "max": Vector3(0.736, 0.847, 0.627),
		"triangles": 180, "budget": 250, "colors": ["6b5e4c", "4f463a"],
	},
}

var failures := 0

func _initialize() -> void: call_deferred("run")

func check(label: String, passed: bool) -> void:
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label)

func near(a: Vector3, b: Vector3) -> bool:
	return (a - b).abs().x <= TOL and (a - b).abs().y <= TOL and (a - b).abs().z <= TOL

func run() -> void:
	var packed: PackedScene = load(SCENE)
	check("preview scene loads", packed != null)
	if packed == null:
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	for asset_name in EXPECTED:
		_check_asset(scene.get_node(asset_name), EXPECTED[asset_name])
	print("RESULT %s (%d failed)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)

func _check_asset(asset: Node3D, want: Dictionary) -> void:
	var label := String(asset.name)
	print("\n== %s  (placed at %s)" % [label, asset.position])
	var meshes: Array[MeshInstance3D] = []
	_collect(asset, meshes)
	check("%s: has mesh instances (%d)" % [label, meshes.size()], meshes.size() > 0)

	# Every node from the instance root down must carry no rotation or scale.
	var transforms_ok := true
	for node in [asset] + _descendants(asset):
		if node is Node3D:
			var basis: Basis = node.basis if node != asset else asset.basis
			print("  node %-28s scale %s  basis x%s y%s z%s" % [node.name, basis.get_scale(), basis.x, basis.y, basis.z])
			if not basis.is_equal_approx(Basis.IDENTITY): transforms_ok = false
	check("%s: every node scale 1, basis identity" % label, transforms_ok)

	var box := AABB()
	var first := true
	var triangles := 0
	var colors: Array[String] = []
	var points := PackedVector3Array()
	var to_asset := asset.global_transform.affine_inverse()
	for mi in meshes:
		var xf := to_asset * mi.global_transform
		for s in range(mi.mesh.get_surface_count()):
			var arrays := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			triangles += (indices.size() if indices.size() > 0 else verts.size()) / 3
			for v in verts:
				var p := xf * v
				points.append(p)
				if first:
					box = AABB(p, Vector3.ZERO)
					first = false
				else:
					box = box.expand(p)
			var mat := mi.get_active_material(s)
			if mat is BaseMaterial3D:
				colors.append((mat as BaseMaterial3D).albedo_color.to_html(false))
	var lo := box.position
	var hi := box.end
	print("  AABB min %s max %s size %s" % [lo, hi, box.size])
	print("  triangles %d  albedo %s" % [triangles, colors])
	check("%s: AABB min %s (want %s)" % [label, lo, want.min], near(lo, want.min))
	check("%s: AABB max %s (want %s)" % [label, hi, want.max], near(hi, want.max))
	check("%s: bottom on the ground (min y = 0)" % label, absf(lo.y) <= 0.001)
	check("%s: %d triangles = Blender count %d, within budget %d (< 500)" % [label, triangles, want.triangles, want.budget],
		triangles == want.triangles and triangles <= want.budget and triangles < 500)
	var all_colors := true
	for c in want.colors:
		var found := false
		for got in colors:
			if _color_close(got, c): found = true
		if not found: all_colors = false
	check("%s: albedo colours %s match brief %s (+-2/255)" % [label, colors, want.colors], all_colors)

	if label == "arched_ramp_segment":
		# F1: the high end must be at -Z. F4: the edge slope must stay under 19 deg.
		var high_z := 0.0
		var top_y := -1.0
		for p in points:
			if p.y > top_y - 0.001:
				if p.y > top_y + 0.001: high_z = p.z
				top_y = maxf(top_y, p.y)
		check("ramp: highest vertices at z %.2f (high end towards -Z)" % high_z, high_z < -6.0)
		var edge_low := INF
		var edge_high := -INF
		for p in points:
			# The road's side edge at x = +-3.4, top row only (not the kerbs' tops).
			if absf(absf(p.x) - 3.4) < 0.001 and p.y > 0.001:
				if absf(p.z) < 0.001: edge_low = minf(edge_low, p.y)
				if absf(p.z + 6.5) < 0.001: edge_high = maxf(edge_high, p.y)
		var slope := rad_to_deg(atan2(edge_high - edge_low, 6.5))
		check("ramp: edge slope %.2f deg <= 19 (game 2.2 / 6.5)" % slope, slope <= 19.0 and slope > 18.0)
	if label == "cliff_wall_segment":
		check("cliff: front (Blender -Y) faces +Z, protrudes <= 0.3", hi.z <= 0.3 + TOL and hi.z > 0.25)

func _color_close(a: String, b: String) -> bool:
	var ca := Color.html(a)
	var cb := Color.html(b)
	return absf(ca.r - cb.r) <= 2.0 / 255.0 and absf(ca.g - cb.g) <= 2.0 / 255.0 and absf(ca.b - cb.b) <= 2.0 / 255.0

func _collect(node: Node, out: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D: out.append(child)
		_collect(child, out)

func _descendants(node: Node) -> Array:
	var out := []
	for child in node.get_children():
		out.append(child)
		out.append_array(_descendants(child))
	return out
