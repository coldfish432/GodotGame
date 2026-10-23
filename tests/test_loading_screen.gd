extends SceneTree
## 加载界面 (用户 2026-10-23: 点了就立刻切到加载界面并读条): the screen is up on
## the very next frame, before the floor is built; the map's stages move the
## bar; it fills and goes once the floor is ready. Same for the next floor.
var game: GameManager
var screens: SystemScreens
var failures := 0
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool, detail: Variant = null) -> void:
	print(("PASS " if passed else "FAIL ") + label + ("" if detail == null else "  %s" % [detail]))
	if not passed: failures += 1
func run() -> void:
	SystemScreens.settings.story_guide = false
	SystemScreens.settings.tutorial_step = TutorialCard.STEPS.size()
	SystemScreens.settings.tutorial_tips = false
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	screens = SystemScreens.new()
	screens.game = game
	root.add_child(screens)
	game.system_screens = screens
	await step(3)
	var stages := [0]
	game.world_map.progress_hook = Callable()
	game.start_contract("mine")
	check("the click puts the loading screen up at once", screens._loading.visible and game.transitioning)
	check("…before the floor is built", not is_instance_valid(game.world_map._generated_root), game.world_map._generated_root)
	var hook: Callable = game.world_map.progress_hook
	check("the map's stages drive the bar", hook.is_valid())
	game.world_map.progress_hook = func(stage):
		stages[0] += 1
		hook.call(stage)
	await process_frame
	var seen := 0.0
	for i in range(600):
		seen = maxf(seen, screens._progress)
		if not game.transitioning: break
		await process_frame
	check("the bar moved while the floor was built", stages[0] >= 5 and seen > 0.5, [stages[0], seen])
	check("the floor is ready", not game.in_base and is_instance_valid(game.world_map._generated_root))
	check("the hook is let go", not game.world_map.progress_hook.is_valid())
	for i in range(240):
		if not screens._loading.visible: break
		await process_frame
	check("it fills to 100% and goes", not screens._loading.visible and screens._progress >= 1.0, screens._progress)
	# The next floor.
	game.advance(0)
	check("the next floor's screen is up at once too", screens._loading.visible and screens._progress < 0.2, screens._progress)
	for i in range(600):
		if not game.transitioning and not screens._loading.visible: break
		await process_frame
	check("…and goes once floor 2 is ready", game.floor_number == 2 and not screens._loading.visible)
	print("FAILURES %d" % failures)
	quit(1 if failures > 0 else 0)
