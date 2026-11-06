extends SceneTree
## A5 probe (agent-written): what the four imported cargo_panel textures load as.

func _initialize() -> void:
	for n in ["diff", "rough", "nor_gl", "nor_dx"]:
		var t := load("res://textures/cargo_panel/rusty_metal_sheet_%s_1k.png" % n) as Texture2D
		var img := t.get_image()
		print("TEX ", n, " ", t.get_width(), "x", t.get_height(), " mipmaps ", img.has_mipmaps(), " format ", img.get_format(), " compressed ", img.is_compressed())
	quit(0)
