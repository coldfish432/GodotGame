extends SceneTree
## A5 probe (agent-written): is the normal path alive, and how much relief does
## this map carry? Renders normal_map_check.tscn's GL panel at normal_strength
## 0, 1 and 2 under each light (real renderer, no --headless), and measures the
## source map's tilt. Writes nothing but its log.

func _initialize() -> void: call_deferred("run")

func frame(rect: Rect2i) -> Image:
	for i in range(10): await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img.get_region(rect)

func delta(a: Image, b: Image) -> Vector2:
	var total := 0.0
	var worst := 0.0
	for y in range(a.get_height()):
		for x in range(a.get_width()):
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			total += (absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b)) * 255.0 / 3.0
			worst = maxf(worst, maxf(absf(p.r - q.r), maxf(absf(p.g - q.g), absf(p.b - q.b))) * 255.0)
	return Vector2(total / float(a.get_width() * a.get_height()), worst)

func run() -> void:
	var src := Image.load_from_file(ProjectSettings.globalize_path("res://textures/cargo_panel/rusty_metal_sheet_nor_gl_1k.png"))
	src.convert(Image.FORMAT_RGB8)
	var tilt := 0.0
	var steep := 0
	var n := 0
	for y in range(0, 1024, 2):
		for x in range(0, 1024, 2):
			var c := src.get_pixel(x, y)
			var v := Vector3(c.r * 2.0 - 1.0, c.g * 2.0 - 1.0, c.b * 2.0 - 1.0).normalized()
			var deg := rad_to_deg(acos(clampf(v.z, -1.0, 1.0)))
			tilt += deg
			if deg > 10.0: steep += 1
			n += 1
	print("SOURCE TILT mean %.2f deg, %.2f%% of texels tilted > 10 deg" % [tilt / n, 100.0 * steep / n])
	var scene := (load("res://tests/normal_map_check.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var panel := scene.get_node("Panel_GL") as MeshInstance3D
	var m := panel.material_override as ShaderMaterial
	var cam := scene.get_node("Camera3D") as Camera3D
	var a := cam.unproject_position(panel.global_transform * Vector3(-0.54, 0.54, 0.05))
	var b := cam.unproject_position(panel.global_transform * Vector3(0.54, -0.54, 0.05))
	var rect := Rect2i(Vector2i(ceili(a.x), ceili(a.y)), Vector2i(floori(b.x - a.x), floori(b.y - a.y)))
	for light in ["Sun", "RakingLight"]:
		(scene.get_node("Sun") as Light3D).visible = light == "Sun"
		(scene.get_node("RakingLight") as Light3D).visible = light == "RakingLight"
		var shots := {}
		for s in [0.0, 1.0, 2.0]:
			m.set_shader_parameter("normal_strength", s)
			shots[s] = await frame(rect)
		var d1 := delta(shots[0.0], shots[1.0])
		var d2 := delta(shots[0.0], shots[2.0])
		print("STRENGTH %s: 0 vs 1 mean %.3f max %.0f; 0 vs 2 mean %.3f max %.0f" % [light, d1.x, d1.y, d2.x, d2.y])
	m.set_shader_parameter("normal_strength", 1.0)
	quit(0)
