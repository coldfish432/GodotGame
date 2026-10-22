extends SceneTree
## Engine screenshots of Rhodes' second deck (势力特供策划案_v0_2 §三–§五):
## evidence/rhodes-engine/deck2-*.png — 农业部's swirl part built and part
## a site, crops at every stage with the shining ones lit, 食堂, the lobby
## with the lift, and the farm, canteen and lift screens.
## DOWNFALL_DECK2=empty shows both rooms before anything is built.
var game: GameManager
func _initialize() -> void: call_deferred("run")
func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null
func frames(n: int) -> void:
	for i in range(n): await process_frame
func shot(label: String) -> void:
	await frames(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/rhodes-engine/deck2-" + label + ".png")
func stand(x: float, z: float) -> void:
	game.player.teleport(game.base_map.to_world(x, z, BaseMap.PLAYER_Y))
	game.camera.global_position = game.camera_target() + game.camera_offset()
	await frames(6)
func run() -> void:
	var rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await frames(20)
	game = find_game(rig)
	game.gold = 500000
	var empty := OS.get_environment("DOWNFALL_DECK2") == "empty"
	if not empty:
		game.base.set_facility("farm", 6)
		game.base.set_facility("canteen", 1)
		var now := BaseState.now()
		var crops := ["舰载麦", "块茎薯", "温室豆", "闪耀作物", "闪耀作物·变种"]
		for i in range(18):
			var crop: String = crops[i % crops.size()]
			# A spread of ages: some just sown, some ripe.
			var age: float = float(Provisions.CROPS[crop].hours) * 3600.0 * [0.1, 0.45, 0.8, 1.2][i % 4]
			game.base.farm.plots.resize(18)
			game.base.farm.plots[i] = {"crop": crop, "at": now - int(age)}
		game.base_map.set_farm(game.provisions)
	game.ride_lift(2)
	await frames(10)
	await stand(470.0, -18.0)
	await shot("farm" if not empty else "farm-empty")
	await stand(349.0, -9.0)
	await shot("canteen" if not empty else "canteen-empty")
	await stand(384.0, -14.0)
	await shot("lobby")
	if not empty:
		game.open_station("farm")
		await create_timer(1.0).timeout
		await shot("farm-screen")
		game.close_modal()
		game.open_station("canteen")
		await create_timer(1.0).timeout
		await shot("canteen-screen")
		game.close_modal()
		game.open_station("lift")
		await create_timer(1.0).timeout
		await shot("lift-screen")
	quit()
