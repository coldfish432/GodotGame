extends SceneTree
## Screenshots of the loading screen (用户 2026-10-23): the frame after the
## click, and frames drawn mid-build by the map's stages:
## evidence/loading_0.png, loading_1.png … Not part of run_all (no checks).
var shots := 0
func _initialize() -> void: call_deferred("run")
func shot() -> void:
	root.get_texture().get_image().save_png("res://../evidence/loading_%d.png" % shots)
	shots += 1
func run() -> void:
	SystemScreens.settings["ui_motion"] = false
	SystemScreens.settings.story_guide = false
	SystemScreens.settings.tutorial_step = TutorialCard.STEPS.size()
	SystemScreens.settings.tutorial_tips = false
	var rig: Node = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	for i in range(15): await process_frame
	var game: GameManager = rig.find_children("*", "GameManager", true, false)[0]
	var screens := SystemScreens.new()
	screens.game = game
	var layer := CanvasLayer.new()
	layer.layer = 30
	root.add_child(layer)
	layer.add_child(screens)
	game.system_screens = screens
	for i in range(5): await process_frame
	var t0 := Time.get_ticks_msec()
	game.start_contract("city")
	print("start_contract returned after %d ms" % (Time.get_ticks_msec() - t0))
	await RenderingServer.frame_post_draw
	print("first frame drawn after %d ms, progress %.2f" % [Time.get_ticks_msec() - t0, screens._progress])
	shot()
	var hook: Callable = game.world_map.progress_hook
	var n := [0]
	game.world_map.progress_hook = func(stage):
		hook.call(stage)
		n[0] += 1
		if n[0] % 5 == 0:
			print("stage %d at %d ms, progress %.2f" % [n[0], Time.get_ticks_msec() - t0, screens._progress])
			shot()
	while game.transitioning: await process_frame
	print("floor ready after %d ms" % (Time.get_ticks_msec() - t0))
	quit(0)
