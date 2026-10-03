extends SceneTree

## Not a test — walks Lappland through every room of the Rhodes Island base
## for Movie Maker. Real navigation and colliders (no teleports): arrival →
## dispatch console → store → warehouse → armory → logistics → medical
## reception → central recovery ward. At each station she presses E and the
## station's menu stays up for a moment. Run with:
##   godot --path downfall-godot --script res://tests/record_base_tour.gd
##        --rendering-method gl_compatibility --audio-driver Dummy
##        --resolution 1280x720 --fixed-fps 30 --write-movie ../evidence/rhodes-engine/base-tour.avi

const STOPS := [
	["dispatch", "调度台"], ["store", "商店"], ["stash", "仓储区"], ["workbench", "整备室"],
	["logistics", "后勤柜台"], ["reception", "医疗部"], ["ward", "回收病房"],
]
const MAX_LEG_FRAMES := 30 * 40

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
	await frames(30)
	for stop in STOPS:
		var goal: Vector3
		if stop[0] == "ward":
			goal = game.base_map.spawn_point("death")
		else:
			goal = game.base_map.station(stop[0]).position + Vector3(0, 0, -1.6)  # stand just south of the prop
		await walk_to(goal, stop[0])
		if stop[0] == "ward":
			await frames(45)
			continue
		await frames(10)
		game._base_interact()
		await frames(50)
		game.close_modal()
		await frames(10)
	await frames(30)
	quit()

func walk_to(goal: Vector3, id: String) -> void:
	game.player.set_move_target(goal)
	var n := 0
	var last := game.player.global_position
	var stuck := 0
	while n < MAX_LEG_FRAMES:
		await process_frame
		n += 1
		var here := game.player.global_position
		if id != "ward" and game.nearby_station().get("id", "") == id and Vector2(here.x - goal.x, here.z - goal.z).length() < 1.0: break
		if Vector2(here.x - goal.x, here.z - goal.z).length() < 0.4: break
		stuck = stuck + 1 if here.distance_to(last) < 0.01 else 0
		last = here
		if stuck > 45:
			push_warning("tour stalled on the way to " + id)
			break
	game.player.clear_move_target()
