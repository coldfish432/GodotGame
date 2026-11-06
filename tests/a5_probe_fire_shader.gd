extends SceneTree
## A5 probe (agent-written): does the hand-written fire shader parse, and
## which uniforms does it declare? Reads the file; never edits it.

func _initialize() -> void:
	var shader := load("res://shaders/burning_bottle_fire.gdshader") as Shader
	var list := shader.get_shader_uniform_list()
	for u in list:
		print("UNIFORM ", u.name, " type ", u.type, " hint ", u.hint, " '", u.hint_string, "'")
	print("UNIFORM COUNT ", list.size())
	quit(0 if list.size() == 5 else 1)
