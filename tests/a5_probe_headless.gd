extends SceneTree
## A5 probe (agent-written, 2026-10-30): what a headless run on this machine
## can observe about shaders, materials and frame timing. Prints facts only.

const CODE := """shader_type spatial;
render_mode unshaded;
uniform float probe_amount : hint_range(0.0, 1.0) = 0.25;
uniform vec4 probe_colour : source_color = vec4(1.0, 0.5, 0.0, 1.0);
void fragment() { ALBEDO = probe_colour.rgb * probe_amount; }
"""

var _process_frames := 0
var _physics_frames := 0
var _game_time := 0.0

func _initialize() -> void:
	print("FACT renderer method: ", RenderingServer.get_current_rendering_method())
	print("FACT driver: ", RenderingServer.get_current_rendering_driver_name())
	print("FACT adapter: '", RenderingServer.get_video_adapter_name(), "'")
	var shader := Shader.new()
	shader.code = CODE
	var names := []
	for u in shader.get_shader_uniform_list():
		names.append([u.name, u.type, u.hint, u.hint_string])
	print("FACT uniform list: ", names)
	var d = RenderingServer.shader_get_parameter_default(shader.get_rid(), "probe_amount")
	print("FACT shader_get_parameter_default(probe_amount): ", d)
	var mat := ShaderMaterial.new()
	mat.shader = shader
	print("FACT material get before set: ", mat.get_shader_parameter("probe_amount"))
	mat.set_shader_parameter("probe_amount", 2.0)
	print("FACT hint_range value set 2.0 from code, read back: ", mat.get_shader_parameter("probe_amount"))
	mat.set_shader_parameter("not_declared", 0.7)
	print("FACT undeclared name set 0.7, read back: ", mat.get_shader_parameter("not_declared"))
	var broken := Shader.new()
	broken.code = CODE.replace("= 0.25;", "= 0.25")
	print("FACT uniform list of shader missing a semicolon: ", broken.get_shader_uniform_list().size())

func _physics_process(delta: float) -> bool:
	_physics_frames += 1
	return false

func _process(delta: float) -> bool:
	_process_frames += 1
	_game_time += delta
	if _process_frames == 144:
		print("FACT after 144 process frames: game time %.6f s, physics ticks %d, physics_ticks_per_second %d" % [_game_time, _physics_frames, Engine.physics_ticks_per_second])
		quit(0)
	return false
