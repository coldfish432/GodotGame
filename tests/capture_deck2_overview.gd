extends SceneTree
## The whole second deck (势力特供策划案_v0_2 §三): three shots along it at a
## wide but normal zoom, evidence/rhodes-engine/deck2-overview-<k>.png, which
## tools/blender/base/stitch_deck2.py puts side by side into deck2-overview.png.
## 农业部 at Lv4 with every basin sown at some stage, 食堂 at Lv3.
## The camera is held at each spot (the game is paused while it shoots).
const SIZE := 82.0
const SPOTS := [Vector2(300.0, -22.0), Vector2(374.0, -22.0), Vector2(448.0, -22.0)]
## The deck runs z 13 … −56: this middle with SIZE keeps both edges in.
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
func run() -> void:
	var rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await frames(20)
	game = find_game(rig)
	game.base.set_facility("farm", 6)
	game.base.set_facility("canteen", 3)
	game.base.connect_facility("farm")
	game.base.connect_facility("canteen")
	var now := BaseState.now()
	var crops := ["舰载麦", "块茎薯", "温室豆", "闪耀作物", "闪耀作物·变种"]
	game.base.farm.plots.resize(Provisions.BASINS)
	for i in range(Provisions.BASINS):
		var crop: String = crops[(i * 7) % crops.size()]
		var age: float = float(Provisions.CROPS[crop].hours) * 3600.0 * [0.2, 0.5, 0.8, 1.2][i % 4]
		game.base.farm.plots[i] = {"crop": crop, "at": now - int(age)}
	game.base_map.set_farm(game.provisions)
	game.ride_lift(2)
	await frames(10)
	game.camera_size_goal = SIZE
	game.camera.size = SIZE
	await frames(10)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.player.visible = false
	game._base_prompt.visible = false
	var offset := game.camera_offset()
	for k in range(SPOTS.size()):
		var at: Vector3 = game.base_map.to_world(SPOTS[k].x, SPOTS[k].y, BaseMap.PLAYER_Y)
		game.player.global_position = at
		game.camera.global_position = at + offset
		await frames(4)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../evidence/rhodes-engine/deck2-overview-%d.png" % k)
	quit()
