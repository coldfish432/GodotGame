extends SceneTree
## 主基地快捷栏 (用户 2026-11-06): the bar on a new save (locked slots), a
## locked key's message, and Pause → 按键 with the 基地站点 column.
var game: GameManager
func _initialize() -> void: call_deferred("run")
func step(n: int = 10) -> void:
	for i in range(n): await process_frame
func shot(label: String) -> void:
	await step(6)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/base-hotkeys-" + label + ".png")
func run() -> void:
	var rig: Node = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(15)
	for n in rig.find_children("*", "GameManager", true, false): game = n
	game.base.start_locked()
	for id in ["exchange", "lab", "farm", "canteen"]: game.base.facilities[id] = 0
	game.use_base_hotkey("exchange")
	await shot("bar")
	game.toggle_panel("pause")
	game.menu.pause_page = 2
	BaseScreens.pause(game.menu)
	await shot("keys")
	quit()
