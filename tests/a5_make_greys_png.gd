extends SceneTree
## A5 (agent-written): writes textures/hint_experiment/greys_3x1.png, a 3x1
## 8-bit RGB image with greys 64, 128, 192 (CHANGE-BRIEF.md, Hint experiment).
##   ../Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/a5_make_greys_png.gd

func _initialize() -> void:
	var img := Image.create_empty(3, 1, false, Image.FORMAT_RGB8)
	for x in range(3):
		var g := (64 * (x + 1)) / 255.0
		img.set_pixel(x, 0, Color(g, g, g))
	var err := img.save_png("res://textures/hint_experiment/greys_3x1.png")
	print("SAVED greys_3x1.png err ", err)
	quit(err)
