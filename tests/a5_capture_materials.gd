extends SceneTree
## A5 (agent-written): side-by-side capture of the two cargo_panel materials in
## res://tests/material_review.tscn, under the review light and the raking light
## separately (CHANGE-BRIEF.md revisions). Needs a real renderer (no --headless):
##   ../Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/a5_capture_materials.gd
## Records each panel's front-face mean and 99th-percentile brightness; the
## pictures are for the human check.

const OUT := "res://evidence/a5/material-review/"

func _initialize() -> void: call_deferred("run")

func face_rect(camera: Camera3D, panel: MeshInstance3D) -> Rect2i:
	var a := camera.unproject_position(panel.global_transform * Vector3(-0.54, 0.54, 0.05))
	var b := camera.unproject_position(panel.global_transform * Vector3(0.54, -0.54, 0.05))
	return Rect2i(Vector2i(ceili(a.x), ceili(a.y)), Vector2i(floori(b.x - a.x), floori(b.y - a.y)))

func stats(img: Image) -> Dictionary:
	var values := PackedFloat32Array()
	var rgb := Vector3.ZERO
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c := img.get_pixel(x, y)
			rgb += Vector3(c.r, c.g, c.b) * 255.0
			values.append((0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * 255.0)
	values.sort()
	var n := values.size()
	return {"mean_rgb8": [snappedf(rgb.x / n, 0.01), snappedf(rgb.y / n, 0.01), snappedf(rgb.z / n, 0.01)],
		"mean_luma8": snappedf(rgb.dot(Vector3(0.2126, 0.7152, 0.0722)) / n, 0.01), "p99_luma8": snappedf(values[int(n * 0.99)], 0.01)}

func run() -> void:
	var scene := (load("res://tests/material_review.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var camera := scene.get_node("Camera3D") as Camera3D
	var result := {"renderer": RenderingServer.get_current_rendering_method(), "driver": RenderingServer.get_current_rendering_driver_name(),
		"adapter": RenderingServer.get_video_adapter_name(), "setups": {}}
	for light in ["Sun", "RakingLight"]:
		(scene.get_node("Sun") as Light3D).visible = light == "Sun"
		(scene.get_node("RakingLight") as Light3D).visible = light == "RakingLight"
		for i in range(30): await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		var tag := "review" if light == "Sun" else "raking"
		img.save_png(OUT + "material-review-%s.png" % tag)
		result.setups[tag] = {}
		for n in ["PanelA_Mild", "PanelB_Weathered"]:
			var s := stats(img.get_region(face_rect(camera, scene.get_node(n))))
			result.setups[tag][n] = s
			print("%s light, %s: mean RGB %s, mean luma %.2f, p99 luma %.2f" % [tag, n, s.mean_rgb8, s.mean_luma8, s.p99_luma8])
	var f := FileAccess.open(OUT + "measurement.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(result, "\t"))
	f.close()
	quit(0)
