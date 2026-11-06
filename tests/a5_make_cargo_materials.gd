extends SceneTree
## A5 (agent-written, one-off): saves the two cargo_panel materials of
## CHANGE-BRIEF.md "Material plan". Both share the hand-written shader and the
## same three textures (the GL normal map); they differ in tint, roughness and relief.

const SHADER := "res://shaders/cargo_panel.gdshader"
const TEX := "res://textures/cargo_panel/rusty_metal_sheet_%s_1k.png"
const MATERIALS := {
	"res://materials/cargo_panel_mild.tres": {"uv_scale": 1.0, "tint_color": Color(1, 1, 1, 1), "roughness_scale": 0.65, "normal_strength": 0.35},
	"res://materials/cargo_panel_weathered.tres": {"uv_scale": 1.0, "tint_color": Color(0.8, 0.7, 0.6, 1), "roughness_scale": 1.35, "normal_strength": 1.2},
}

func _initialize() -> void:
	var failed := 0
	for path in MATERIALS:
		var m := ShaderMaterial.new()
		m.shader = load(SHADER)
		m.set_shader_parameter("albedo_tex", load(TEX % "diff"))
		m.set_shader_parameter("roughness_tex", load(TEX % "rough"))
		m.set_shader_parameter("normal_tex", load(TEX % "nor_gl"))
		for k in MATERIALS[path]: m.set_shader_parameter(k, MATERIALS[path][k])
		var err := ResourceSaver.save(m, path)
		print("SAVED ", path, " err ", err)
		if err != OK: failed += 1
	quit(failed)
