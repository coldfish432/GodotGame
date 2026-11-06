extends SceneTree
## A5 probe (agent-written): what the imported 3x1 grey texture loads as.

func _initialize() -> void:
	var t := load("res://textures/hint_experiment/greys_3x1.png") as Texture2D
	var img := t.get_image()
	var row := []
	for x in range(img.get_width()):
		var c := img.get_pixel(x, 0)
		row.append([roundi(c.r * 255), roundi(c.g * 255), roundi(c.b * 255)])
	print("GREYS ", img.get_width(), "x", img.get_height(), " format ", img.get_format(), " mipmaps ", img.has_mipmaps(), " compressed ", img.is_compressed(), " texels ", row)
	quit(0 if row == [[64, 64, 64], [128, 128, 128], [192, 192, 192]] else 1)
