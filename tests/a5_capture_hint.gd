extends SceneTree
## A5 (agent-written): the hint experiment capture (CHANGE-BRIEF.md, Hint
## experiment predictions). Needs a real renderer: run WITHOUT --headless,
##   ../Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/a5_capture_hint.gd
## Renders res://tests/hint_experiment.tscn, reads the root viewport, samples
## the centre of each texel on both quads and compares with the brief's
## predictions (±2 per channel). Writes evidence/a5/hint-experiment/.

const OUT := "res://evidence/a5/hint-experiment/"
const PREDICTED := {"QuadWithSourceColor": [64, 128, 192], "QuadWithoutSourceColor": [137, 188, 225]}
const TOLERANCE := 2

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var scene := (load("res://tests/hint_experiment.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	for i in range(30): await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	img.save_png(OUT + "hint-experiment.png")
	var camera := scene.get_node("Camera3D") as Camera3D
	var env := (scene.get_node("WorldEnvironment") as WorldEnvironment).environment
	var result := {
		"engine": Engine.get_version_info().string,
		"renderer": RenderingServer.get_current_rendering_method(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"image_size": str(img.get_size()),
		"tonemap_mode": env.tonemap_mode, "tonemap_exposure": env.tonemap_exposure,
		"glow": env.glow_enabled, "fog": env.fog_enabled, "adjustment": env.adjustment_enabled,
		"ssao": env.ssao_enabled, "ssil": env.ssil_enabled, "ssr": env.ssr_enabled,
		"samples": [],
	}
	var failed := 0
	for quad_name in PREDICTED:
		var quad := scene.get_node(quad_name) as MeshInstance3D
		var size := (quad.mesh as QuadMesh).size
		for k in range(3):
			# Texel k's centre is at u = (k + 0.5) / 3, v = 0.5.
			var local := Vector3((float(k) + 0.5) / 3.0 * size.x - size.x * 0.5, 0.0, 0.0)
			var at := camera.unproject_position(quad.global_transform * local)
			var pixel := Vector2i(floori(at.x), floori(at.y))
			var c := img.get_pixelv(pixel)
			var rgb := [roundi(c.r * 255), roundi(c.g * 255), roundi(c.b * 255)]
			var want: int = PREDICTED[quad_name][k]
			var ok := rgb.all(func(v): return absi(v - want) <= TOLERANCE)
			if not ok: failed += 1
			result.samples.append({"quad": quad_name, "texel": k, "pixel": str(pixel), "rgb8": rgb, "predicted": want, "within_2": ok})
			print("%s %s texel %d at %s: %s, predicted %d" % ["PASS" if ok else "FAIL", quad_name, k, pixel, rgb, want])
	var f := FileAccess.open(OUT + "measurement.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(result, "\t"))
	f.close()
	print("HINT EXPERIMENT: %d samples, %d outside ±%d" % [result.samples.size(), failed, TOLERANCE])
	quit(1 if failed > 0 else 0)
