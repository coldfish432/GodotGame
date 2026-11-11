extends SceneTree
## The snow boss arena's cover stumps, rebuilt 2026-11-11 (snow_shapes,
## build_arena_props.arena_snow_stump): the arena from above and a close shot
## of each stump. Real renderer:
##   godot --path downfall-godot --script res://tests/capture_snow_stump.gd --resolution 1280x720
## Writes ../evidence/snow_props/stump_{arena,0,1}.png.
const OUT := "res://../evidence/snow_props/"
var rig: Node
var game: GameManager
func _initialize() -> void: call_deferred("run")
func step(count: int = 1) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null
func save(label: String) -> void:
	await step(6)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "stump_%s.png" % label)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(5)
	game = find_game(rig)
	game.fixed_map_seed = 1729
	await game.start_contract("snow")
	game.floor_number = 19
	await game.advance(0)
	await step(4)
	game.player.invulnerable = true
	game.player.teleport(game.world_map.nearest_walkable(game.arena.centre + Vector3(0, 0, -8.0)) + Vector3.UP * 0.7)
	game._hud.hide()
	game.set_process(false)
	game.camera.size = 34
	game.camera.global_position = game.arena.centre + GameManager.CAMERA_OFFSET * (34.0 / 14.0)
	await save("arena")
	var i := 0
	for entry in game.arena.cover:
		if not is_instance_valid(entry.body) or entry.kind != "cover": continue
		game.camera.size = 9
		game.camera.global_position = entry.at + GameManager.CAMERA_OFFSET * (9.0 / 14.0)
		await save(str(i))
		print("STUMP ", i, " ", entry.at)
		i += 1
	game.set_process(true)
	rig.queue_free()
	await create_timer(0.4).timeout
	quit()
