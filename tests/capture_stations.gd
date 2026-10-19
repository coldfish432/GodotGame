extends SceneTree
## The base's station overview (用户 2026-10-18: 不常驻，快捷键开启，设置里自定义):
## closed, opened with two stations left out, and Pause → 设置 → 基地.
var game: GameManager
func _initialize() -> void: call_deferred("run")
func step(n: int = 10) -> void:
	for i in range(n): await process_frame
func shot(label: String) -> void:
	await step(6)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/stations-" + label + ".png")
func run() -> void:
	var rig: Node = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(15)
	for n in rig.find_children("*", "GameManager", true, false): game = n
	SystemScreens.settings.station_panel = false
	SystemScreens.settings.station_hidden = []
	await shot("closed")
	game.toggle_station_panel()
	SystemScreens.set_setting("station_hidden", ["exchange", "workshop"])
	await shot("open")
	game.toggle_panel("pause")
	game.menu.pause_page = 1
	game.menu.settings_tab = 3
	BaseScreens.pause(game.menu)
	await shot("settings")
	SystemScreens.settings.station_panel = false
	SystemScreens.settings.station_hidden = []
	quit()
