extends SceneTree

## Renders res://art/models/asset_preview.tscn through its game-style camera
## (orthographic, size 24, offset (0, 16, -10) like GameManager) and through a
## second, closer perspective view from the cliff's front, and saves both to
## a3/screenshots/. Needs a window (not --headless).

func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.size = Vector2i(1600, 900)
	var scene: Node3D = load("res://art/models/asset_preview.tscn").instantiate()
	root.add_child(scene)
	for i in range(10): await process_frame
	_save("claude-godot-preview-gamecam.png")

	var cam: Camera3D = scene.get_node("Camera3D")
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 50.0
	cam.position = Vector3(-2.0, 6.0, 13.0)
	cam.look_at(Vector3(-0.5, 0.8, -2.0), Vector3.UP)
	for i in range(10): await process_frame
	_save("claude-godot-preview-front.png")
	quit()

func _save(file: String) -> void:
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://").path_join("a3/screenshots").path_join(file)
	image.save_png(path)
	print("SAVED ", path, " ", image.get_size())
