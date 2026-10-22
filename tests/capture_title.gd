extends SceneTree
## Screenshot of the title screen (界面美术与布局策划案 v2 §7.1): evidence/title.png.
## Not part of run_all (no checks).
func _initialize() -> void: call_deferred("run")
func run() -> void:
	SystemScreens.settings["ui_motion"] = false
	var rig: Node = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	for i in range(15): await process_frame
	var screens := SystemScreens.new()
	var layer := CanvasLayer.new()
	layer.layer = 30
	root.add_child(layer)
	layer.add_child(screens)
	for i in range(5): await process_frame
	screens.show_title()
	for i in range(10): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/title.png")
	quit(0)
