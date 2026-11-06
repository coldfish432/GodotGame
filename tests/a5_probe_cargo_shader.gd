extends SceneTree
## A5 probe (agent-written): does the hand-written cargo_panel shader parse, and
## which uniforms and groups does it declare? Reads the file; never edits it.

func _initialize() -> void:
	var shader := load("res://shaders/cargo_panel.gdshader") as Shader
	var list := shader.get_shader_uniform_list(true)
	var count := 0
	for u in list:
		print("UNIFORM ", u.name, " type ", u.type, " hint ", u.hint, " '", u.hint_string, "' usage ", u.usage)
		if u.usage & PROPERTY_USAGE_GROUP == 0: count += 1
	print("UNIFORM COUNT ", count)
	quit(0 if count == 7 else 1)
