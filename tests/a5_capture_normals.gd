extends SceneTree
## A5 (agent-written): renders res://tests/normal_map_check.tscn (CHANGE-BRIEF.md
## F8) with one cargo_panel material per normal map: GL, DX as imported, DX
## with Invert Y. Needs a real renderer (no --headless):
##   ../Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/a5_capture_normals.gd
## Two light setups, reported apart (brief revision "加掠射光"): the review
## light (Sun) and the raking light from above (RakingLight), never both on.
## The three-panel frame is kept for eyes. The numbers come from one panel at one
## place: Panel_GL's mesh wears each material in turn, so sampling phase and
## position are the same in all three frames and only the normal map differs.

const OUT := "res://evidence/a5/normal-map-check/"
const MAPS := ["GL", "DX_raw", "DX_fixed"]

func _initialize() -> void: call_deferred("run")

func face_rect(camera: Camera3D, panel: MeshInstance3D) -> Rect2i:
	# The front face (z = +0.05), shrunk by 10% so edges and bevels stay out.
	var a := camera.unproject_position(panel.global_transform * Vector3(-0.54, 0.54, 0.05))
	var b := camera.unproject_position(panel.global_transform * Vector3(0.54, -0.54, 0.05))
	return Rect2i(Vector2i(ceili(a.x), ceili(a.y)), Vector2i(floori(b.x - a.x), floori(b.y - a.y)))

func frame() -> Image:
	for i in range(10): await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img

func measure(scene: Node, light: String) -> Dictionary:
	(scene.get_node("Sun") as Light3D).visible = light == "Sun"
	(scene.get_node("RakingLight") as Light3D).visible = light == "RakingLight"
	var panel := scene.get_node("Panel_GL") as MeshInstance3D
	var own := panel.material_override
	var tag := "review" if light == "Sun" else "raking"
	var overview: Image = await frame()
	overview.save_png(OUT + "normal-map-check-%s.png" % tag)
	var rect := face_rect(scene.get_node("Camera3D") as Camera3D, panel)
	var frames := {}
	for n in MAPS:
		panel.material_override = (scene.get_node("Panel_" + n) as MeshInstance3D).material_override
		var img: Image = await frame()
		frames[n] = img.get_region(rect)
		frames[n].save_png(OUT + "same-place-%s-%s.png" % [tag, n])
	panel.material_override = own
	var out := {"light": light, "rect": str(rect), "mean_abs_delta_vs_gl": {}, "max_abs_delta_vs_gl": {}}
	for n in MAPS:
		var a: Image = frames.GL
		var b: Image = frames[n]
		var total := 0.0
		var worst := 0.0
		for y in range(rect.size.y):
			for x in range(rect.size.x):
				var p := a.get_pixel(x, y)
				var q := b.get_pixel(x, y)
				total += (absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b)) * 255.0 / 3.0
				worst = maxf(worst, maxf(absf(p.r - q.r), maxf(absf(p.g - q.g), absf(p.b - q.b))) * 255.0)
		out.mean_abs_delta_vs_gl[n] = total / float(rect.size.x * rect.size.y)
		out.max_abs_delta_vs_gl[n] = worst
		print("%s light, %s vs GL: mean |delta| %.3f levels, max %.0f, over %s" % [tag, n, out.mean_abs_delta_vs_gl[n], worst, rect.size])
	return out

func run() -> void:
	var scene := (load("res://tests/normal_map_check.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var result := {"renderer": RenderingServer.get_current_rendering_method(), "driver": RenderingServer.get_current_rendering_driver_name(),
		"adapter": RenderingServer.get_video_adapter_name(), "setups": []}
	var failed := 0
	for light in ["Sun", "RakingLight"]:
		var m: Dictionary = await measure(scene, light)
		result.setups.append(m)
		# Fixed DX may differ from GL only by what the imports differ by (about one
		# level); the raw DX map must differ by more.
		var ok: bool = m.mean_abs_delta_vs_gl.GL == 0.0 and m.max_abs_delta_vs_gl.DX_fixed <= 2.0 \
			and m.max_abs_delta_vs_gl.DX_raw > m.max_abs_delta_vs_gl.DX_fixed and m.mean_abs_delta_vs_gl.DX_fixed < m.mean_abs_delta_vs_gl.DX_raw
		m["pass"] = ok
		if not ok: failed += 1
		print("NORMAL CAPTURE %s: %s" % [light, "PASS" if ok else "FAIL"])
	var f := FileAccess.open(OUT + "measurement.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(result, "\t"))
	f.close()
	quit(1 if failed > 0 else 0)
