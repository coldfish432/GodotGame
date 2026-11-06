extends SceneTree
## A5 material audit (agent-written). Pins the tables in MATERIALS.md: the two
## cargo_panel materials and the two hint-experiment materials, each shader's
## samplers and hints (read from the source text), the uniform list, the import
## settings of every bound texture (read with ConfigFile), and the lights and
## Environment of the scenes they appear in. Prints curl_ratio for each normal
## map's source file under both green conventions (tests/normal_map_check.gd).
##   ./scripts/run-test.sh test_materials.gd 60
## Headless uses a dummy renderer: nothing here shows what the GPU draws.

const NMC := preload("res://tests/normal_map_check.gd")

const CARGO_SHADER := "res://shaders/cargo_panel.gdshader"
const HINT_SHADER := "res://shaders/hint_experiment.gdshader"
const MILD := "res://materials/cargo_panel_mild.tres"
const WEATHERED := "res://materials/cargo_panel_weathered.tres"
const TEX := "res://textures/cargo_panel/rusty_metal_sheet_%s_1k.png"
const GREYS := "res://textures/hint_experiment/greys_3x1.png"
const DX_FIXED := "res://textures/cargo_panel/rusty_metal_sheet_nor_dx_1k_inverty.png"

## Sampler name -> hints, exactly as written in the shader source.
const SAMPLER_HINTS := {
	CARGO_SHADER: {
		"albedo_tex": ["source_color", "filter_linear_mipmap", "repeat_enable"],
		"roughness_tex": ["filter_linear_mipmap", "repeat_enable"],
		"normal_tex": ["hint_normal", "filter_linear_mipmap", "repeat_enable"],
	},
	HINT_SHADER: {
		"tex_color": ["source_color", "filter_nearest", "repeat_disable"],
		"tex_raw": ["filter_nearest", "repeat_disable"],
	},
}

## Non-sampler uniforms: [type, hint text in the source, default in the source].
const SOURCE_UNIFORMS := {
	CARGO_SHADER: {
		"uv_scale": ["float", "hint_range(0.25, 8.0, 0.25)", "1.0"],
		"tint_color": ["vec4", "source_color", "vec4(1.0, 1.0, 1.0, 1.0)"],
		"roughness_scale": ["float", "hint_range(0.0, 2.0, 0.05)", "1.0"],
		"normal_strength": ["float", "hint_range(0.0, 2.0, 0.05)", "1.0"],
	},
	HINT_SHADER: {
		"use_source_color": ["bool", "", "true"],
	},
}

## get_shader_uniform_list(), in order: [name, Variant type, hint_string or null].
## Group entries (usage PROPERTY_USAGE_GROUP) are listed with type -1.
const UNIFORM_LIST := {
	CARGO_SHADER: [
		["albedo_tex", TYPE_OBJECT, null], ["roughness_tex", TYPE_OBJECT, null], ["normal_tex", TYPE_OBJECT, null],
		["Surface", -1, null], ["uv_scale", TYPE_FLOAT, [0.25, 8.0, 0.25]], ["tint_color", TYPE_COLOR, null],
		["Response", -1, null], ["roughness_scale", TYPE_FLOAT, [0.0, 2.0, 0.05]], ["normal_strength", TYPE_FLOAT, [0.0, 2.0, 0.05]],
	],
	HINT_SHADER: [
		["tex_color", TYPE_OBJECT, null], ["tex_raw", TYPE_OBJECT, null], ["use_source_color", TYPE_BOOL, null],
	],
}

## Material -> every uniform it sets and every texture it binds.
var MATERIALS := {
	MILD: {"albedo_tex": TEX % "diff", "roughness_tex": TEX % "rough", "normal_tex": TEX % "nor_gl",
		"uv_scale": 1.0, "tint_color": Color(1, 1, 1, 1), "roughness_scale": 0.65, "normal_strength": 0.35},
	WEATHERED: {"albedo_tex": TEX % "diff", "roughness_tex": TEX % "rough", "normal_tex": TEX % "nor_gl",
		"uv_scale": 1.0, "tint_color": Color(0.8, 0.7, 0.6, 1), "roughness_scale": 1.35, "normal_strength": 1.2},
	"res://tests/hint_experiment.tscn::Material_with_hint": {"tex_color": GREYS, "tex_raw": GREYS, "use_source_color": true},
	"res://tests/hint_experiment.tscn::Material_without_hint": {"tex_color": GREYS, "tex_raw": GREYS, "use_source_color": false},
}

## Texture -> [compress/mode, compress/normal_map, mipmaps/generate,
## process/normal_map_invert_y, detect_3d/compress_to].
var IMPORTS := {
	TEX % "diff": [0, 2, true, false, 0],
	TEX % "rough": [0, 2, true, false, 0],
	TEX % "nor_gl": [2, 1, true, false, 0],
	TEX % "nor_dx": [2, 1, true, false, 0],
	DX_FIXED: [2, 1, true, true, 0],
	GREYS: [0, 2, false, false, 0],
}

var failures := 0


func check(label: String, ok: bool, detail := "") -> void:
	if not ok: failures += 1
	print("%s %s%s" % ["PASS" if ok else "FAIL", label, ("  (" + detail + ")") if detail != "" else ""])


func same(a: Variant, b: Variant) -> bool:
	if typeof(a) == TYPE_FLOAT or typeof(b) == TYPE_FLOAT:
		return typeof(a) in [TYPE_FLOAT, TYPE_INT] and typeof(b) in [TYPE_FLOAT, TYPE_INT] and is_equal_approx(float(a), float(b))
	if a is Color and b is Color: return (a as Color).is_equal_approx(b)
	if a is Vector3 and b is Vector3: return (a as Vector3).distance_to(b) < 1e-3
	return typeof(a) == typeof(b) and a == b


func near3(a: Vector3, b: Vector3) -> bool:
	return a.distance_to(b) < 1e-3


func read_text(path: String) -> String:
	return FileAccess.get_file_as_string(path)


## Uniform declarations in the source: name -> [type, hint text, default text].
func source_uniforms(path: String) -> Dictionary:
	var out := {}
	var re := RegEx.create_from_string("(?m)^\\s*uniform\\s+(\\w+)\\s+(\\w+)\\s*(?::\\s*([^=;]+?))?\\s*(?:=\\s*([^;]+?))?\\s*;")
	for m in re.search_all(read_text(path)):
		out[m.get_string(2)] = [m.get_string(1), m.get_string(3).strip_edges(), m.get_string(4).strip_edges()]
	return out


## "shader_parameter/<name>" keys written in each resource section of a .tres/.tscn,
## keyed by section ("resource" or the sub_resource id).
func written_parameters(path: String) -> Dictionary:
	var out := {}
	var section := ""
	var head := RegEx.create_from_string("^\\[(sub_resource|resource)(?:.*id=\"([^\"]+)\")?")
	for line in read_text(path).split("\n"):
		if line.begins_with("["):
			var m := head.search(line)
			section = "" if m == null else (m.get_string(2) if m.get_string(1) == "sub_resource" else "resource")
			continue
		if section != "" and line.begins_with("shader_parameter/"):
			if not out.has(section): out[section] = []
			out[section].append(line.substr(17).split(" ")[0])
	return out


func _initialize() -> void:
	var mild := load(MILD) as ShaderMaterial
	var weathered := load(WEATHERED) as ShaderMaterial
	var review := (load("res://tests/material_review.tscn") as PackedScene).instantiate()
	var normals := (load("res://tests/normal_map_check.tscn") as PackedScene).instantiate()
	var hint := (load("res://tests/hint_experiment.tscn") as PackedScene).instantiate()
	root.add_child(review)
	root.add_child(normals)
	root.add_child(hint)
	var by_name := {
		MILD: mild, WEATHERED: weathered,
		"res://tests/hint_experiment.tscn::Material_with_hint": (hint.get_node("QuadWithSourceColor") as MeshInstance3D).material_override,
		"res://tests/hint_experiment.tscn::Material_without_hint": (hint.get_node("QuadWithoutSourceColor") as MeshInstance3D).material_override,
	}

	print("--- textured shader: both materials")
	check("mild shader is %s" % CARGO_SHADER, mild.shader.resource_path == CARGO_SHADER, mild.shader.resource_path)
	check("weathered shader is %s" % CARGO_SHADER, weathered.shader.resource_path == CARGO_SHADER, weathered.shader.resource_path)
	check("mild and weathered share one Shader resource", mild.shader == weathered.shader)
	check("mild and weathered are separate ShaderMaterials", mild != weathered)
	check("material_review PanelA_Mild wears %s" % MILD, (review.get_node("PanelA_Mild") as MeshInstance3D).material_override.resource_path == MILD)
	check("material_review PanelB_Weathered wears %s" % WEATHERED, (review.get_node("PanelB_Weathered") as MeshInstance3D).material_override.resource_path == WEATHERED)
	var hint_with: ShaderMaterial = by_name["res://tests/hint_experiment.tscn::Material_with_hint"]
	var hint_without: ShaderMaterial = by_name["res://tests/hint_experiment.tscn::Material_without_hint"]
	check("both hint materials use %s" % HINT_SHADER, hint_with.shader.resource_path == HINT_SHADER and hint_without.shader.resource_path == HINT_SHADER)
	check("hint materials are separate ShaderMaterials", hint_with != hint_without)

	print("--- sampler hints, from the source text")
	for shader_path in SAMPLER_HINTS:
		var decl := source_uniforms(shader_path)
		var samplers := []
		for n in decl: if decl[n][0] == "sampler2D": samplers.append(n)
		check("%s declares samplers %s" % [shader_path.get_file(), SAMPLER_HINTS[shader_path].keys()], samplers == SAMPLER_HINTS[shader_path].keys(), str(samplers))
		for n in SAMPLER_HINTS[shader_path]:
			var hints := []
			if decl.has(n):
				for h in (decl[n][1] as String).split(","): hints.append(h.strip_edges())
			check("%s %s hints %s" % [shader_path.get_file(), n, SAMPLER_HINTS[shader_path][n]], hints == SAMPLER_HINTS[shader_path][n], str(hints))
		for n in SOURCE_UNIFORMS[shader_path]:
			var want: Array = SOURCE_UNIFORMS[shader_path][n]
			check("%s %s declared %s : %s = %s" % [shader_path.get_file(), n, want[0], want[1], want[2]], decl.get(n, []) == want, str(decl.get(n, [])))

	print("--- uniform list from get_shader_uniform_list()")
	for shader_path in UNIFORM_LIST:
		var got := []
		for u in (load(shader_path) as Shader).get_shader_uniform_list(true):
			var grouped: bool = int(u.usage) & PROPERTY_USAGE_GROUP
			got.append([u.name, -1 if grouped else int(u.type), u.hint_string])
		var want: Array = UNIFORM_LIST[shader_path]
		check("%s uniform list has %d entries" % [shader_path.get_file(), want.size()], got.size() == want.size(), str(got))
		for i in range(mini(got.size(), want.size())):
			var ok: bool = got[i][0] == want[i][0] and got[i][1] == want[i][1]
			if ok and want[i][2] != null:
				var parts: PackedStringArray = str(got[i][2]).split(",")
				ok = parts.size() == 3
				for k in range(3): ok = ok and is_equal_approx(float(parts[k]), want[i][2][k])
			check("%s uniform %d is %s type %d %s" % [shader_path.get_file(), i, want[i][0], want[i][1], "" if want[i][2] == null else str(want[i][2])], ok, str(got[i]))

	print("--- material uniform values and texture paths")
	var written := {MILD: written_parameters(MILD).get("resource", []), WEATHERED: written_parameters(WEATHERED).get("resource", [])}
	var hint_written := written_parameters("res://tests/hint_experiment.tscn")
	written["res://tests/hint_experiment.tscn::Material_with_hint"] = hint_written.get("Material_with_hint", [])
	written["res://tests/hint_experiment.tscn::Material_without_hint"] = hint_written.get("Material_without_hint", [])
	for key in MATERIALS:
		var mat: ShaderMaterial = by_name[key]
		var want: Dictionary = MATERIALS[key]
		var names := []
		for u in mat.shader.get_shader_uniform_list(): names.append(u.name)
		var w: Array = written[key]
		w.sort()
		var wk: Array = want.keys()
		wk.sort()
		check("%s writes exactly %s" % [key.get_file(), wk], w == wk, str(w))
		for n in w: check("%s parameter %s is a declared uniform" % [key.get_file(), n], n in names)
		for n in want:
			var v: Variant = mat.get_shader_parameter(n)
			if want[n] is String:
				var p: String = (v as Texture2D).resource_path if v is Texture2D else str(v)
				check("%s %s binds %s" % [key.get_file(), n, (want[n] as String).get_file()], p == want[n], p)
			else:
				check("%s %s = %s" % [key.get_file(), n, want[n]], same(v, want[n]), str(v))
	var nm_want := {"Panel_GL": TEX % "nor_gl", "Panel_DX_raw": TEX % "nor_dx", "Panel_DX_fixed": DX_FIXED}
	for node_name in nm_want:
		var m := (normals.get_node(node_name) as MeshInstance3D).material_override as ShaderMaterial
		var t := m.get_shader_parameter("normal_tex") as Texture2D
		check("normal_map_check %s: %s, normal_tex %s, other values 1.0/white" % [node_name, CARGO_SHADER.get_file(), nm_want[node_name].get_file()],
			m.shader.resource_path == CARGO_SHADER and t.resource_path == nm_want[node_name]
			and same(m.get_shader_parameter("uv_scale"), 1.0) and same(m.get_shader_parameter("roughness_scale"), 1.0)
			and same(m.get_shader_parameter("normal_strength"), 1.0) and same(m.get_shader_parameter("tint_color"), Color(1, 1, 1, 1)))

	print("--- import settings, read with ConfigFile")
	for tex_path in IMPORTS:
		var cfg := ConfigFile.new()
		var err := cfg.load(tex_path + ".import")
		var want: Array = IMPORTS[tex_path]
		var got := [cfg.get_value("params", "compress/mode"), cfg.get_value("params", "compress/normal_map"),
			cfg.get_value("params", "mipmaps/generate"), cfg.get_value("params", "process/normal_map_invert_y"),
			cfg.get_value("params", "detect_3d/compress_to")]
		check("%s.import mode=%d normal_map=%d mipmaps=%s invert_y=%s compress_to=%d" % [tex_path.get_file(), want[0], want[1], want[2], want[3], want[4]],
			err == OK and got == want, str(got))
	for key in [MILD, WEATHERED]:
		var mat := by_name[key] as ShaderMaterial
		for n in ["albedo_tex", "roughness_tex"]:
			var cfg := ConfigFile.new()
			cfg.load((mat.get_shader_parameter(n) as Texture2D).resource_path + ".import")
			check("%s %s texture imported with normal_map=2 (not a normal map)" % [key.get_file(), n], cfg.get_value("params", "compress/normal_map") == 2)
		var cfgn := ConfigFile.new()
		cfgn.load((mat.get_shader_parameter("normal_tex") as Texture2D).resource_path + ".import")
		check("%s normal_tex texture imported with normal_map=1, invert_y=false" % key.get_file(),
			cfgn.get_value("params", "compress/normal_map") == 1 and cfgn.get_value("params", "process/normal_map_invert_y") == false)
	check("nor_dx_1k_inverty.png is byte-identical to nor_dx_1k.png (only the import differs)",
		FileAccess.get_sha256(DX_FIXED) == FileAccess.get_sha256(TEX % "nor_dx"), FileAccess.get_sha256(DX_FIXED).left(12))
	var greys := Image.load_from_file(ProjectSettings.globalize_path(GREYS))
	var texels := []
	for x in range(greys.get_width()): texels.append(greys.get_pixel(x, 0).r8)
	check("greys_3x1.png source texels are 64, 128, 192", texels == [64, 128, 192], str(texels))

	print("--- lights and environment")
	for pair in [["material_review", review], ["normal_map_check", normals]]:
		var scene: Node = pair[1]
		var env := (scene.get_node("WorldEnvironment") as WorldEnvironment).environment
		check("%s env Linear tonemap, exposure 1.0" % pair[0], env.tonemap_mode == Environment.TONE_MAPPER_LINEAR and is_equal_approx(env.tonemap_exposure, 1.0))
		check("%s env background colour 0.18 grey" % pair[0], env.background_mode == Environment.BG_COLOR and env.background_color.is_equal_approx(Color(0.18, 0.18, 0.18)))
		check("%s env ambient Color(1,1,1) energy 0.2, reflected light disabled" % pair[0],
			env.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR and env.ambient_light_color.is_equal_approx(Color.WHITE)
			and is_equal_approx(env.ambient_light_energy, 0.2) and env.reflected_light_source == Environment.REFLECTION_SOURCE_DISABLED)
		check("%s env SSR/SSAO/SSIL/SDFGI/glow/fog/volumetric fog/adjustment all off" % pair[0],
			not (env.ssr_enabled or env.ssao_enabled or env.ssil_enabled or env.sdfgi_enabled or env.glow_enabled or env.fog_enabled or env.volumetric_fog_enabled or env.adjustment_enabled))
		var sun := scene.get_node("Sun") as DirectionalLight3D
		var rake := scene.get_node("RakingLight") as DirectionalLight3D
		print("INFO %s Sun rotation_degrees %s direction (local -Z) %s; RakingLight rotation_degrees %s direction (local -Z) %s" % [pair[0], sun.rotation_degrees, -sun.basis.z, rake.rotation_degrees, -rake.basis.z])
		check("%s Sun white, energy 1.0, rotation_degrees (-35,-30,0), on" % pair[0],
			sun.light_color.is_equal_approx(Color.WHITE) and is_equal_approx(sun.light_energy, 1.0) and near3(sun.rotation_degrees, Vector3(-35, -30, 0)) and sun.visible)
		check("%s RakingLight white, energy 1.0, rotation_degrees (-75,0,0), off by default" % pair[0],
			rake.light_color.is_equal_approx(Color.WHITE) and is_equal_approx(rake.light_energy, 1.0) and near3(rake.rotation_degrees, Vector3(-75, 0, 0)) and not rake.visible)
		var lights := scene.find_children("*", "Light3D", true, false)
		check("%s has exactly 2 lights" % pair[0], lights.size() == 2, str(lights.size()))
	var henv := (hint.get_node("WorldEnvironment") as WorldEnvironment).environment
	check("hint_experiment env Linear, exposure 1.0, black background, ambient and reflected light disabled",
		henv.tonemap_mode == Environment.TONE_MAPPER_LINEAR and is_equal_approx(henv.tonemap_exposure, 1.0)
		and henv.background_color.is_equal_approx(Color.BLACK) and henv.ambient_light_source == Environment.AMBIENT_SOURCE_DISABLED
		and henv.reflected_light_source == Environment.REFLECTION_SOURCE_DISABLED)
	check("hint_experiment env post-processing all off",
		not (henv.ssr_enabled or henv.ssao_enabled or henv.ssil_enabled or henv.sdfgi_enabled or henv.glow_enabled or henv.fog_enabled or henv.volumetric_fog_enabled or henv.adjustment_enabled))
	check("hint_experiment has no lights (render_mode unshaded)", hint.find_children("*", "Light3D", true, false).is_empty()
		and read_text(HINT_SHADER).contains("render_mode unshaded;"))

	# The base Environment (GameManager.base_environment()); the cargo_panel crates left the base 2026-10-30.
	check("base_map no longer puts cargo_panel on the hall crates", not (load("res://world/base_map.gd") as GDScript).get_script_constant_map().has("CARGO_PANEL"))
	var gm := load("res://game/game_manager.gd") as GDScript
	var benv: Environment = gm.base_environment()
	print("INFO base_environment tonemap %d exposure %.2f white %.1f ambient %s x%.2f ssao %s ssil %s glow %s fog %s adjustment %s" % [
		benv.tonemap_mode, benv.tonemap_exposure, benv.tonemap_white, benv.ambient_light_color, benv.ambient_light_energy,
		benv.ssao_enabled, benv.ssil_enabled, benv.glow_enabled, benv.fog_enabled, benv.adjustment_enabled])
	check("base_environment ACES, exposure 1.0, white 8.0",
		benv.tonemap_mode == Environment.TONE_MAPPER_ACES and is_equal_approx(benv.tonemap_exposure, 1.0) and is_equal_approx(benv.tonemap_white, 8.0))
	check("base_environment SSAO, SSIL, glow, fog, adjustment all on",
		benv.ssao_enabled and benv.ssil_enabled and benv.glow_enabled and benv.fog_enabled and benv.adjustment_enabled)
	check("base sun energy BASE_SUN 0.15", same(gm.get_script_constant_map().get("BASE_SUN"), 0.15))
	check("base sun rotation_degrees (-50,-30,0) in game_manager.gd source", read_text("res://game/game_manager.gd").contains("sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)"))

	print("--- normal maps: curl_ratio of each source file (directx=false / directx=true)")
	var curls := {}
	for tex_path in [TEX % "nor_gl", TEX % "nor_dx", DX_FIXED]:
		var img := Image.load_from_file(ProjectSettings.globalize_path(tex_path))
		var gl: float = NMC.curl_ratio(img, false)
		var dx: float = NMC.curl_ratio(img, true)
		curls[tex_path] = [gl, dx]
		print("CURL_RATIO source %-40s directx=false %.4f  directx=true %.4f" % [tex_path.get_file(), gl, dx])
	check("nor_gl source fits the GL convention better (false < true)", curls[TEX % "nor_gl"][0] < curls[TEX % "nor_gl"][1])
	check("nor_dx source fits the DX convention better (true < false)", curls[TEX % "nor_dx"][1] < curls[TEX % "nor_dx"][0])
	var fixed_img := (load(DX_FIXED) as Texture2D).get_image()
	var fgl: float = NMC.curl_ratio(fixed_img, false)
	var fdx: float = NMC.curl_ratio(fixed_img, true)
	print("CURL_RATIO imported %-38s directx=false %.4f  directx=true %.4f" % [DX_FIXED.get_file(), fgl, fdx])
	check("nor_dx_1k_inverty as imported (invert_y) fits the GL convention (false < true)", fgl < fdx)

	# Roughness: how much of the map the weathered material's 1.35 pushes past the clamp.
	var rough := Image.load_from_file(ProjectSettings.globalize_path(TEX % "rough"))
	var n := 0
	var over := 0
	var total := 0.0
	for y in range(0, rough.get_height(), 4):
		for x in range(0, rough.get_width(), 4):
			var r := rough.get_pixel(x, y).r
			total += r
			n += 1
			if r * 1.35 > 1.0: over += 1
	print("INFO rough source mean R %.3f; texels clamped at 1.0 under roughness_scale 1.35: %.1f%%" % [total / n, 100.0 * over / n])

	print("RESULT %s, %d failure(s)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
