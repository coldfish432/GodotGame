extends SceneTree
## The snowfield's rebuilt props (2026-11-11: 倒伏的树像倒的电线杆子，石头太圆润) in
## real snow floors: for each kind, the nearest placed instance to the start is
## found among the dressing's MultiMeshes, the player put beside it, and two
## shots taken under the follow camera, HUD hidden: the game's zoom and a close
## one. Real renderer:
##   godot --path downfall-godot --script res://tests/capture_snow_props.gd --resolution 1280x720
## Writes ../evidence/snow_props/<kind>_<seed>_{far,near}.png.

const SEEDS := [2026, 3141, 5813]
const KINDS := {"log": "Accent_snow_log", "log_b": "Accent_snow_log_b", "boulders": "Accent_snow_boulders",
	"kerb": "RampKerbs_ramp_snow_rock_big", "drift": "Accent_snow_drift", "crag": "Crags_snow_crag_c"}
const OUT := "res://../evidence/snow_props/"

var rig: Node
var game: GameManager

func _initialize() -> void: call_deferred("run")

func step(count: int = 8) -> void:
	for i in range(count): await process_frame

func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null

## The placed instance of `prefix` closest to `near`, or null.
func nearest(prefix: String, near: Vector3) -> Variant:
	var best = null
	var best_d := INF
	for node in game.world_map.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := node as MultiMeshInstance3D
		if not String(mmi.name).begins_with(prefix): continue
		if prefix == "Accent_snow_log" and String(mmi.name) != "Accent_snow_log": continue
		for i in range(mmi.multimesh.instance_count):
			var at := (mmi.global_transform * mmi.multimesh.get_instance_transform(i)).origin
			var d := at.distance_to(near)
			if d < best_d:
				best_d = d
				best = at
	return best

func shot(at: Vector3, label: String) -> void:
	# Beside it, a little towards the camera, so the figure gives the scale.
	game.player.teleport(game.world_map.nearest_walkable(at + Vector3(2.5, 0, -2.0)))
	for size in [24.0, 11.0]:
		game.camera_size_goal = size
		game.camera.size = size
		game._hud.hide()
		var focus := at.lerp(game.player.global_position, 0.3)
		game.camera.global_position = focus + GameManager.CAMERA_OFFSET
		await step(10)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT + "%s_%s.png" % [label, "far" if size > 20.0 else "near"])

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step()
	game = find_game(rig)
	for map_seed in SEEDS:
		game.fixed_map_seed = map_seed
		await game.start_contract("snow")
		game.open_modal("capture")
		game._hud.hide()
		await step(20)
		var start := game.player.global_position
		var names := []
		for node in game.world_map.find_children("*", "MultiMeshInstance3D", true, false): names.append(String(node.name))
		print("SETS ", map_seed, " ", names.filter(func(n): return n.contains("snow")))
		for kind in KINDS:
			var at = nearest(KINDS[kind], start)
			if at == null:
				print("NONE ", kind, " ", map_seed)
				continue
			await shot(at, "%s_%d" % [kind, map_seed])
			print("SHOT ", kind, " ", map_seed, " ", at)
		game.close_modal()
		game.settle(true)
		await step(10)
	rig.queue_free()
	await create_timer(0.3).timeout
	quit()
