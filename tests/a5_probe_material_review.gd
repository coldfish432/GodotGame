extends SceneTree
## A5 probe (agent-written): reads back res://tests/material_review.tscn.

func _initialize() -> void:
	var scene := (load("res://tests/material_review.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var sun := scene.get_node("Sun") as DirectionalLight3D
	print("SUN rotation_degrees ", sun.rotation_degrees, " energy ", sun.light_energy, " color ", sun.light_color)
	var env := (scene.get_node("WorldEnvironment") as WorldEnvironment).environment
	print("ENV tonemap ", env.tonemap_mode, " exposure ", env.tonemap_exposure, " ambient ", env.ambient_light_source, " ", env.ambient_light_color, " ", env.ambient_light_energy,
		" ssao ", env.ssao_enabled, " ssil ", env.ssil_enabled, " ssr ", env.ssr_enabled, " glow ", env.glow_enabled, " fog ", env.fog_enabled, " adj ", env.adjustment_enabled)
	for n in ["PanelA_Mild", "PanelB_Weathered"]:
		var mi := scene.get_node(n) as MeshInstance3D
		var m := mi.material_override as ShaderMaterial
		print("PANEL ", n, " at ", mi.position, " size ", (mi.mesh as BoxMesh).size, " material ", m.resource_path, " shader ", m.shader.resource_path,
			" normal ", (m.get_shader_parameter("normal_tex") as Texture2D).resource_path.get_file())
		for k in ["uv_scale", "tint_color", "roughness_scale", "normal_strength"]: print("   ", k, " = ", m.get_shader_parameter(k))
	quit(0)
