extends SceneTree
## Engine screenshots of the construction sites and built parts
## (基建设施修订案_v1_1.md §三): evidence/rhodes-engine/works-<site>-<state>.png,
## each site unbuilt on a new base, then built with every facility at its top.
var game: GameManager
const VIEWS := {"hub": ["hall", 104.0, -24.0], "exchange": ["hall", 27.0, -18.0], "outfit": ["hall", 80.0, -10.0],
	"store": ["store", 9.0, 1.0], "workshop": ["workshop", -20.0, -1.0], "lab": ["lab", 146.0, -51.0], "warehouse": ["warehouse", -14.0, -24.0],
	"drone": ["warehouse", -8.0, -38.0]}
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
	await frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../evidence/rhodes-engine/works-" + label + ".png")
func place(view: Array) -> void:
	game.player.teleport(game.base_map.to_world(view[1], view[2], BaseMap.PLAYER_Y))
	game.camera.global_position = game.camera_target() + GameManager.CAMERA_OFFSET
func run() -> void:
	var rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await frames(20)
	game = find_game(rig)
	var only := OS.get_environment("WORKS_VIEW")
	for state in ["site", "built"]:
		if state == "built":
			game.base.max_facilities()
			game.base.drone = true
			game.base.console = true
			await frames(4)
		for key in VIEWS:
			if not only.is_empty() and key != only: continue
			place(VIEWS[key])
			await create_timer(0.6).timeout
			await shot("%s-%s" % [key, state])
	quit()
