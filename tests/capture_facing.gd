extends SceneTree
## Screenshots of Lappland walking each diagonal by keys (evidence/facing-*.png).
var rig: Node
var game: GameManager
func _initialize() -> void: call_deferred("run")
func step(count: int = 10) -> void:
	for i in range(count): await process_frame
func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null
func run() -> void:
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(15)
	game = find_game(rig)
	await game.start_contract("city")
	game._clear_field()
	for keys in [["move_down", "move_left"], ["move_down", "move_right"], ["move_up", "move_left"], ["move_up", "move_right"]]:
		game.player.teleport(ContinuousWorldMap.ENTRY_POSITION)
		for k in keys: Input.action_press(k)
		await step(90)
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var at := game.screen_point(game.player.global_position)
		image.get_region(Rect2i(Vector2i(at) - Vector2i(80, 110), Vector2i(160, 160))).save_png("res://../evidence/facing-" + "-".join(keys) + ".png")
		for k in keys: Input.action_release(k)
		await step(10)
	quit()
