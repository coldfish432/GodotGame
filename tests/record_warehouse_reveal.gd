extends SceneTree

## Not a test — records the warehouse entry for Movie Maker: Lappland walks
## from the hall through the west door and stops (lights clunk on bank by bank), along
## the forklift lane to the racks (shelves rise as they come on screen), waits,
## then walks back out (shelves sink, hatches shut, lights dim). Real
## navigation and colliders. Run with:
##   godot --path downfall-godot --script res://tests/record_warehouse_reveal.gd
##        --rendering-method gl_compatibility --audio-driver Dummy
##        --resolution 1280x720 --fixed-fps 60 --write-movie <dir>/frame.png
## Record PNG frames, not .avi: Godot's AVI is MJPEG, and its compression noise
## crawls over the pixel art as the view scrolls, which looks like shimmering.
## Then: ffmpeg -framerate 60 -i <dir>/frame%08d.png -c:v libx264 -crf 14 -pix_fmt yuv420p out.mp4

const LEGS := [[-4.0, -26.0, 1.7], [-44.0, -26.0, 1.0], [-52.0, -26.0, 2.5], [8.0, -26.0, 1.5]]  # layout x, z, seconds to hold after arriving

var rig: Node
var game: GameManager

func _initialize() -> void: call_deferred("run")

func frames(n: int) -> void:
	for i in range(n): await process_frame

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
	await frames(20)
	game = find_game(rig)
	game.player.teleport(game.base_map.to_world(8.0, -26.0, BaseMap.PLAYER_Y))
	game.camera.global_position = game.camera_target() + GameManager.CAMERA_OFFSET
	await frames(30)
	for leg in LEGS:
		var goal := game.base_map.to_world(leg[0], leg[1], BaseMap.PLAYER_Y)
		game.player.set_move_target(goal)
		var n := 0
		while n < 60 * 30 and Vector2(game.player.global_position.x - goal.x, game.player.global_position.z - goal.z).length() > 0.6:
			await process_frame
			n += 1
		game.player.clear_move_target()
		await create_timer(leg[2]).timeout  # game time, so the pause is the same at any --fixed-fps
	quit()
